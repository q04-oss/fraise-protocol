"""
anti_replay.py — Local cooldown cache for NFC tag scans.

Purpose:
  Mirrors the on-chain MIN_SCAN_INTERVAL guard (300 seconds) in firmware.
  This prevents the device from broadcasting a transaction that will revert
  on-chain, saving gas and reducing latency feedback to the user.

Design:
  - In-memory dict keyed by tag_id (bytes). Restarts clear the cache,
    which is acceptable — the on-chain guard is the authoritative source.
  - Thread-safe: uses threading.Lock so the NFC polling loop and any
    background flush goroutines don't race.
"""

import threading
import time
from typing import Dict

from config import LOCAL_COOLDOWN_SECONDS


class AntiReplayCache:
    """Tracks per-tag scan timestamps to enforce the local cooldown."""

    def __init__(self, cooldown_seconds: int = LOCAL_COOLDOWN_SECONDS) -> None:
        self._cooldown = cooldown_seconds
        self._last_seen: Dict[bytes, float] = {}
        self._lock = threading.Lock()

    def is_allowed(self, tag_id: bytes) -> bool:
        """
        Returns True if the tag may be scanned now.
        Updates the last-seen timestamp when returning True.
        """
        now = time.monotonic()
        with self._lock:
            last = self._last_seen.get(tag_id)
            if last is not None and (now - last) < self._cooldown:
                return False
            self._last_seen[tag_id] = now
            return True

    def remaining(self, tag_id: bytes) -> float:
        """Seconds until the tag is scannable again (0 if already allowed)."""
        now = time.monotonic()
        with self._lock:
            last = self._last_seen.get(tag_id)
            if last is None:
                return 0.0
            elapsed = now - last
            return max(0.0, self._cooldown - elapsed)

    def clear(self) -> None:
        """Remove all entries (e.g. on device restart or admin reset)."""
        with self._lock:
            self._last_seen.clear()
