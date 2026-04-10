"""
signer.py — Ethereum transaction signer for Fraise NFC devices.

Builds and signs raw transactions that call FraiseNFC.recordScan().
Uses eth_account for signing — no external wallet dependency.

Security notes:
  - DEVICE_PRIVATE_KEY is loaded once at import from config; never stored in logs.
  - Nonce is fetched fresh per transaction to avoid replay.
  - Gas is estimated on-chain; a buffer is added to avoid out-of-gas reverts.
"""

import logging
from typing import Optional

from eth_account import Account
from eth_account.signers.local import LocalAccount
from web3 import Web3

from config import DEVICE_PRIVATE_KEY, NFC_CONTRACT, RPC_URL

logger = logging.getLogger(__name__)

# ABI fragment for recordScan — only what we need to encode the call
RECORD_SCAN_ABI = [
    {
        "inputs": [
            {"internalType": "bytes32", "name": "tagId", "type": "bytes32"},
            {"internalType": "bytes32", "name": "varietyId", "type": "bytes32"},
            {"internalType": "bytes32", "name": "farmId", "type": "bytes32"},
            {"internalType": "address", "name": "beneficiary", "type": "address"},
        ],
        "name": "recordScan",
        "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
        "stateMutability": "nonpayable",
        "type": "function",
    }
]


class DeviceSigner:
    """Signs and broadcasts FraiseNFC.recordScan() transactions."""

    def __init__(self) -> None:
        self._w3 = Web3(Web3.HTTPProvider(RPC_URL))
        self._account: LocalAccount = Account.from_key(DEVICE_PRIVATE_KEY)
        self._contract = self._w3.eth.contract(
            address=Web3.to_checksum_address(NFC_CONTRACT),
            abi=RECORD_SCAN_ABI,
        )
        logger.info("DeviceSigner ready — address=%s", self._account.address)

    @property
    def address(self) -> str:
        return self._account.address

    def record_scan(
        self,
        tag_id: bytes,
        variety_id: bytes,
        farm_id: bytes,
        beneficiary: str,
    ) -> Optional[str]:
        """
        Broadcast a recordScan transaction.

        Args:
            tag_id:      32-byte NFC tag UID (keccak256 of raw UID).
            variety_id:  32-byte variety identifier.
            farm_id:     32-byte farm identifier.
            beneficiary: Ethereum address of the wallet to credit.

        Returns:
            Transaction hash (hex string) or None on failure.
        """
        try:
            nonce = self._w3.eth.get_transaction_count(self._account.address, "pending")
            chain_id = self._w3.eth.chain_id

            tx = self._contract.functions.recordScan(
                tag_id, variety_id, farm_id, Web3.to_checksum_address(beneficiary)
            ).build_transaction(
                {
                    "from": self._account.address,
                    "nonce": nonce,
                    "chainId": chain_id,
                }
            )

            # Estimate gas with a 20% buffer
            estimated = self._w3.eth.estimate_gas(tx)
            tx["gas"] = int(estimated * 1.2)

            signed = self._account.sign_transaction(tx)
            tx_hash = self._w3.eth.send_raw_transaction(signed.raw_transaction)

            logger.info(
                "recordScan broadcast — tag=%s beneficiary=%s tx=%s",
                tag_id.hex(),
                beneficiary,
                tx_hash.hex(),
            )
            return tx_hash.hex()

        except Exception as exc:  # noqa: BLE001
            logger.error("recordScan failed — %s", exc)
            return None

    def wait_for_receipt(self, tx_hash: str, timeout: int = 60) -> bool:
        """Block until the transaction is mined. Returns True on success."""
        try:
            receipt = self._w3.eth.wait_for_transaction_receipt(
                tx_hash, timeout=timeout
            )
            success = receipt["status"] == 1
            if not success:
                logger.warning("Transaction reverted — tx=%s", tx_hash)
            return success
        except Exception as exc:  # noqa: BLE001
            logger.error("Receipt timeout — tx=%s error=%s", tx_hash, exc)
            return False
