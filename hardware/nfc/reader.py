"""
reader.py — NFC tag reader abstraction for PN532 / RC522 over SPI.

Wraps the low-level board library so the rest of the firmware can stay
hardware-agnostic. Swap this file to support a different NFC chip.

Dependencies:
  - adafruit-circuitpython-pn532 (SPI mode)
  - RPi.GPIO or gpiozero for reset pin

Hardware wiring (default, Raspberry Pi):
  MOSI → GPIO 10 (SPI0 MOSI)
  MISO → GPIO 9  (SPI0 MISO)
  SCLK → GPIO 11 (SPI0 CLK)
  CS   → GPIO 8  (SPI0 CE0)
  RST  → GPIO 20 (configurable via FRAISE_NFC_RESET_PIN)
  IRQ  → GPIO 16 (configurable via FRAISE_NFC_IRQ_PIN)
"""

import hashlib
import logging
import time
from typing import Optional

logger = logging.getLogger(__name__)


class NFCReader:
    """
    Hardware-level NFC tag reader.

    Usage:
        reader = NFCReader()
        reader.init()
        uid_hash = reader.read_tag()   # blocks until a tag is presented
    """

    def __init__(self) -> None:
        self._pn532 = None

    def init(self) -> None:
        """
        Initialise the PN532 over SPI.
        Raises RuntimeError if the hardware is not detected.
        """
        try:
            import board  # type: ignore[import-not-found]
            import busio  # type: ignore[import-not-found]
            import digitalio  # type: ignore[import-not-found]
            from adafruit_pn532.spi import PN532_SPI  # type: ignore[import-not-found]

            from config import NFC_IRQ_PIN, NFC_RESET_PIN

            spi = busio.SPI(board.SCK, board.MOSI, board.MISO)
            cs = digitalio.DigitalInOut(board.CE0)
            reset = digitalio.DigitalInOut(getattr(board, f"D{NFC_RESET_PIN}"))

            self._pn532 = PN532_SPI(spi, cs, reset=reset, debug=False)
            ic, ver, rev, support = self._pn532.firmware_version
            logger.info("PN532 firmware v%d.%d", ver, rev)
            self._pn532.SAM_configuration()

        except ImportError:
            # Running on a development machine — use a simulated reader
            logger.warning("NFC hardware libraries not found — using simulator")
            self._pn532 = None

    def read_tag(self, timeout_seconds: float = 1.0) -> Optional[bytes]:
        """
        Poll for an ISO14443A tag.

        Returns the keccak256 hash of the raw UID as 32 bytes, or None on timeout.
        Using a hash of the UID prevents raw hardware IDs from appearing on-chain.
        """
        if self._pn532 is None:
            return self._simulate_read()

        uid = self._pn532.read_passive_target(timeout=timeout_seconds)
        if uid is None:
            return None

        uid_hash = hashlib.sha3_256(bytes(uid)).digest()
        logger.debug("Tag detected — uid_hex=%s", bytes(uid).hex())
        return uid_hash

    def _simulate_read(self) -> Optional[bytes]:
        """Dev-mode stub — returns None (no tag present)."""
        time.sleep(0.1)
        return None
