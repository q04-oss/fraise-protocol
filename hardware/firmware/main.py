"""
main.py — Fraise NFC Device Firmware Entry Point

Flow:
  1. NFCReader polls for a tag every NFC_POLL_MS milliseconds.
  2. When a tag is detected, AntiReplayCache checks the local cooldown.
  3. If allowed, DeviceSigner broadcasts FraiseNFC.recordScan() on-chain.
  4. The transaction hash is logged; the on-chain event is the source of truth.

The beneficiary address is resolved from the tag's NFC UID. In Phase 1 the
device operator maps tag UIDs to wallet addresses in a local config file.
In Phase 2 this lookup will be replaced by an on-chain FraiseIdentity query.

To run:
  python -m firmware.main
"""

import logging
import sys
import time
from pathlib import Path

# Allow running from the hardware/ directory
sys.path.insert(0, str(Path(__file__).parent.parent))

from firmware.anti_replay import AntiReplayCache
from firmware.config import LOG_LEVEL, NFC_POLL_MS
from firmware.signer import DeviceSigner
from nfc.reader import NFCReader
from nfc.tag import TagPayload, read_tag_payload

logging.basicConfig(
    level=getattr(logging, LOG_LEVEL, logging.INFO),
    format="%(asctime)s [%(levelname)s] %(name)s — %(message)s",
)
logger = logging.getLogger("fraise.main")

# ── Phase 1: static tag → (payload, beneficiary) mapping ─────────────────────
# In production, load from /etc/fraise/tag_map.json.
# Format: { "uid_hash_hex": { "beneficiary": "0x...", "variety_id": "...", "farm_id": "..." } }

import json
import os

TAG_MAP_PATH = os.environ.get("FRAISE_TAG_MAP", "/etc/fraise/tag_map.json")


def load_tag_map() -> dict:
    try:
        with open(TAG_MAP_PATH) as f:
            return json.load(f)
    except FileNotFoundError:
        logger.warning("No tag map found at %s — running without beneficiary lookup", TAG_MAP_PATH)
        return {}


def main() -> None:
    tag_map = load_tag_map()
    reader = NFCReader()
    reader.init()
    cache = AntiReplayCache()
    signer = DeviceSigner()

    logger.info("Fraise NFC device started — address=%s", signer.address)

    poll_interval = NFC_POLL_MS / 1000.0

    while True:
        try:
            uid_hash = reader.read_tag(timeout_seconds=poll_interval)
            if uid_hash is None:
                continue

            uid_hex = uid_hash.hex()
            logger.debug("Tag read — uid=%s", uid_hex)

            # Local anti-replay check (mirrors on-chain MIN_SCAN_INTERVAL)
            if not cache.is_allowed(uid_hash):
                remaining = cache.remaining(uid_hash)
                logger.info("Tag on cooldown — uid=%s remaining=%.1fs", uid_hex, remaining)
                continue

            entry = tag_map.get(uid_hex)
            if entry is None:
                logger.warning("Unknown tag — uid=%s (not in tag map)", uid_hex)
                continue

            beneficiary = entry["beneficiary"]
            variety_id = bytes.fromhex(entry["variety_id"])
            farm_id = bytes.fromhex(entry["farm_id"])

            tx_hash = signer.record_scan(uid_hash, variety_id, farm_id, beneficiary)
            if tx_hash:
                success = signer.wait_for_receipt(tx_hash)
                if success:
                    logger.info(
                        "Scan recorded — uid=%s beneficiary=%s tx=%s",
                        uid_hex, beneficiary, tx_hash,
                    )
                else:
                    logger.error("Scan reverted — uid=%s tx=%s", uid_hex, tx_hash)

        except KeyboardInterrupt:
            logger.info("Shutting down")
            break
        except Exception as exc:  # noqa: BLE001
            logger.error("Unexpected error — %s", exc, exc_info=True)
            time.sleep(1)


if __name__ == "__main__":
    main()
