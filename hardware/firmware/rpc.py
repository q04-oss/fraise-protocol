"""
rpc.py — Read-only on-chain queries for the Fraise NFC device.

Used for:
  - Checking whether a tag is currently on cooldown on-chain (before broadcasting)
  - Resolving FraiseIdentity labels to wallet addresses (Phase 2)
  - Reading currentBalance to display tier info on a connected display

All reads are view calls — no gas, no signing.
"""

import logging
from typing import Optional

from web3 import Web3

from config import NFC_CONTRACT, RPC_URL

logger = logging.getLogger(__name__)

# Minimal ABI fragments for read-only calls
NFC_READ_ABI = [
    {
        "inputs": [{"internalType": "bytes32", "name": "tagId", "type": "bytes32"}],
        "name": "lastScanAt",
        "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
        "stateMutability": "view",
        "type": "function",
    },
    {
        "inputs": [],
        "name": "MIN_SCAN_INTERVAL",
        "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
        "stateMutability": "view",
        "type": "function",
    },
]

IDENTITY_READ_ABI = [
    {
        "inputs": [{"internalType": "string", "name": "label", "type": "string"}],
        "name": "getWallet",
        "outputs": [{"internalType": "address", "name": "", "type": "address"}],
        "stateMutability": "view",
        "type": "function",
    },
]

TIME_CREDITS_READ_ABI = [
    {
        "inputs": [{"internalType": "address", "name": "user", "type": "address"}],
        "name": "currentBalance",
        "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
        "stateMutability": "view",
        "type": "function",
    },
    {
        "inputs": [{"internalType": "address", "name": "user", "type": "address"}],
        "name": "getTier",
        "outputs": [{"internalType": "uint8", "name": "", "type": "uint8"}],
        "stateMutability": "view",
        "type": "function",
    },
]


class ChainReader:
    """Read-only interface to the Fraise Protocol contracts."""

    def __init__(
        self,
        identity_address: Optional[str] = None,
        time_credits_address: Optional[str] = None,
    ) -> None:
        self._w3 = Web3(Web3.HTTPProvider(RPC_URL))
        self._nfc = self._w3.eth.contract(
            address=Web3.to_checksum_address(NFC_CONTRACT),
            abi=NFC_READ_ABI,
        )
        self._identity = None
        self._time_credits = None

        if identity_address:
            self._identity = self._w3.eth.contract(
                address=Web3.to_checksum_address(identity_address),
                abi=IDENTITY_READ_ABI,
            )
        if time_credits_address:
            self._time_credits = self._w3.eth.contract(
                address=Web3.to_checksum_address(time_credits_address),
                abi=TIME_CREDITS_READ_ABI,
            )

    def is_tag_on_cooldown(self, tag_id: bytes) -> bool:
        """Check on-chain whether the tag is still within MIN_SCAN_INTERVAL."""
        try:
            last_scan = self._nfc.functions.lastScanAt(tag_id).call()
            if last_scan == 0:
                return False
            min_interval = self._nfc.functions.MIN_SCAN_INTERVAL().call()
            current = self._w3.eth.get_block("latest")["timestamp"]
            return (current - last_scan) < min_interval
        except Exception as exc:  # noqa: BLE001
            logger.warning("is_tag_on_cooldown RPC failed — %s", exc)
            return False

    def resolve_label(self, label: str) -> Optional[str]:
        """Resolve a fraise.box label to a wallet address (Phase 2)."""
        if self._identity is None:
            return None
        try:
            addr = self._identity.functions.getWallet(label).call()
            return addr if addr != "0x" + "0" * 40 else None
        except Exception as exc:  # noqa: BLE001
            logger.warning("resolve_label RPC failed — label=%s error=%s", label, exc)
            return None

    def get_balance_seconds(self, wallet: str) -> Optional[int]:
        """Return a user's current time credit balance in seconds."""
        if self._time_credits is None:
            return None
        try:
            return self._time_credits.functions.currentBalance(
                Web3.to_checksum_address(wallet)
            ).call()
        except Exception as exc:  # noqa: BLE001
            logger.warning("get_balance_seconds RPC failed — %s", exc)
            return None
