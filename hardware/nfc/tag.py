"""
tag.py — NFC tag data encoder / decoder.

Tags written by Fraise devices store a compact NDEF payload:
  - variety_id:  32-byte keccak256 of the variety slug (e.g. "gariguette")
  - farm_id:     32-byte keccak256 of the farm identifier
  - schema_ver:  1 byte — allows forward-compatible format changes

Total payload: 65 bytes, well within NTAG213 (144 bytes usable).

The tag_id used on-chain is the keccak256 of the NFC chip's hardware UID —
it is NOT stored on the tag itself (the reader derives it from the RF layer).
"""

import hashlib
import struct
from dataclasses import dataclass
from typing import Optional

SCHEMA_VERSION = 1
PAYLOAD_SIZE = 65  # 32 + 32 + 1


@dataclass
class TagPayload:
    variety_id: bytes  # 32 bytes
    farm_id: bytes     # 32 bytes
    schema_ver: int = SCHEMA_VERSION

    def __post_init__(self) -> None:
        if len(self.variety_id) != 32:
            raise ValueError("variety_id must be 32 bytes")
        if len(self.farm_id) != 32:
            raise ValueError("farm_id must be 32 bytes")

    def encode(self) -> bytes:
        """Serialise to bytes for NDEF write."""
        return self.variety_id + self.farm_id + struct.pack("B", self.schema_ver)

    @classmethod
    def decode(cls, data: bytes) -> "TagPayload":
        """Parse raw NDEF payload bytes."""
        if len(data) < PAYLOAD_SIZE:
            raise ValueError(f"Payload too short: {len(data)} < {PAYLOAD_SIZE}")
        variety_id = data[:32]
        farm_id = data[32:64]
        schema_ver = struct.unpack("B", data[64:65])[0]
        return cls(variety_id=variety_id, farm_id=farm_id, schema_ver=schema_ver)


def make_variety_id(slug: str) -> bytes:
    """Derive the on-chain variety_id from a human-readable slug."""
    return hashlib.sha3_256(slug.encode()).digest()


def make_farm_id(farm_slug: str) -> bytes:
    """Derive the on-chain farm_id from a human-readable farm slug."""
    return hashlib.sha3_256(farm_slug.encode()).digest()


def write_tag(writer, payload: TagPayload) -> bool:
    """
    Write a TagPayload to an NFC tag via the provided writer object.
    writer must expose a write_ndef(data: bytes) -> bool method.
    Returns True on success.
    """
    return writer.write_ndef(payload.encode())


def read_tag_payload(raw_ndef: bytes) -> Optional[TagPayload]:
    """Parse NDEF data from a tag. Returns None if the data is invalid."""
    try:
        return TagPayload.decode(raw_ndef)
    except (ValueError, struct.error):
        return None
