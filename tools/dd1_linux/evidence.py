"""Lossless transport for complete B1 inert records; never execution authority.

pack/unpack are offline byte operations. Output must be new. Compression grants
no raw-budget credit; byte count and SHA256 are checked before decoded delivery.
"""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import zlib

MAX_RAW = 64 * 1024 * 1024


def pack(raw):
    if len(raw) > MAX_RAW:
        raise ValueError("evidence exceeds transport bound")
    zipped = zlib.compress(raw, 9)
    return dict(schema="DD1-B1-LOSSLESS-1", raw_bytes=len(raw),
        raw_sha256=hashlib.sha256(raw).hexdigest(), compressed_bytes=len(zipped),
        compressed_sha256=hashlib.sha256(zipped).hexdigest(),
        encoding="zlib+base64", data=base64.b64encode(zipped).decode())


def unpack(packet):
    if packet.get("schema") != "DD1-B1-LOSSLESS-1" or packet.get("encoding") != "zlib+base64":
        raise ValueError("unsupported evidence transport")
    size = packet.get("raw_bytes")
    if type(size) is not int or not 0 <= size <= MAX_RAW:
        raise ValueError("invalid evidence size")
    compressed = base64.b64decode(packet["data"], validate=True)
    if len(compressed) != packet["compressed_bytes"] or hashlib.sha256(compressed).hexdigest() != packet["compressed_sha256"]:
        raise ValueError("compressed evidence changed")
    decoder = zlib.decompressobj()
    raw = decoder.decompress(compressed, size + 1)
    if not decoder.eof or decoder.unconsumed_tail or decoder.unused_data or len(raw) != size:
        raise ValueError("truncated, excessive, or trailing evidence")
    if hashlib.sha256(raw).hexdigest() != packet["raw_sha256"]:
        raise ValueError("decoded evidence changed")
    return raw


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("pack", "unpack"))
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    data = args.input.read_bytes()
    result = (json.dumps(pack(data), sort_keys=True, separators=(",", ":")) + "\n").encode() if args.operation == "pack" else unpack(json.loads(data))
    with args.output.open("xb") as target:
        target.write(result)
    print(json.dumps(dict(bytes=len(result), sha256=hashlib.sha256(result).hexdigest())))
