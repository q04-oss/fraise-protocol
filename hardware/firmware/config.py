"""
config.py — Fraise NFC Device Configuration

All runtime settings are loaded from environment variables (set in /etc/fraise.env
on the device). No secrets are hardcoded here.

Device identity:
  Each physical device has a unique DEVICE_PRIVATE_KEY — an Ethereum EOA that holds
  DEVICE_ROLE on FraiseNFC. Signatures are produced off-chain for anti-replay
  attestations. The key is stored in the secure enclave or hardware security module
  where available.
"""

import os

# ── RPC ──────────────────────────────────────────────────────────────────────

# Optimism mainnet RPC endpoint (e.g. Alchemy or Infura)
RPC_URL: str = os.environ["FRAISE_RPC_URL"]

# ── Contract addresses (set after deployment) ─────────────────────────────────

NFC_CONTRACT: str = os.environ["FRAISE_NFC_CONTRACT"]        # FraiseNFC proxy
TIME_CREDITS_CONTRACT: str = os.environ.get(               # FraiseTimeCredits
    "FRAISE_TIME_CREDITS_CONTRACT", ""
)

# ── Device identity ───────────────────────────────────────────────────────────

# Ethereum private key for this device (holds DEVICE_ROLE on FraiseNFC)
# Must be generated once per device and stored securely — never logged.
DEVICE_PRIVATE_KEY: str = os.environ["FRAISE_DEVICE_PRIVATE_KEY"]

# ── NFC hardware ──────────────────────────────────────────────────────────────

# GPIO pin for PN532 or RC522 reader (SPI/I2C)
NFC_RESET_PIN: int = int(os.environ.get("FRAISE_NFC_RESET_PIN", "20"))
NFC_IRQ_PIN: int = int(os.environ.get("FRAISE_NFC_IRQ_PIN", "16"))

# NFC polling interval in milliseconds
NFC_POLL_MS: int = int(os.environ.get("FRAISE_NFC_POLL_MS", "500"))

# ── Anti-replay ───────────────────────────────────────────────────────────────

# Mirrors MIN_SCAN_INTERVAL on-chain (300 seconds). Local check avoids
# wasting gas on a transaction that will revert.
LOCAL_COOLDOWN_SECONDS: int = int(os.environ.get("FRAISE_LOCAL_COOLDOWN", "300"))

# ── Logging ───────────────────────────────────────────────────────────────────

LOG_LEVEL: str = os.environ.get("FRAISE_LOG_LEVEL", "INFO")
