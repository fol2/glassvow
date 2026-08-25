#!/usr/bin/env python3
"""Reconstruct the s009 exam catalogue without touching live H39 content."""
from __future__ import annotations

import argparse
import json
import sys
import tempfile
from copy import deepcopy
from pathlib import Path
from typing import Any

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

from balance_content_doe import canonical_json_bytes, get_path, set_path  # noqa: E402
from balance_seed_contract import (  # noqa: E402
    LIVE_REL,
    REPO,
    file_sha256,
    read_json,
    sha256_bytes,
)

FINALISTS_REL = "docs/balance/data/458/finalists.json"
CANDIDATE_ID = "s009"
H39_FILE_SHA = "a0d608a5142d2e3aab799cdf33d3163922b402c2aaf2a895e46e096399b56cf1"
EXAM_FILE_SHA = "5b3504f133a7e180f20426a8f28c5f2685c9d00d4e3c93c39a432a1a859ea448"
EXAM_SEMANTIC_SHA = "6359c4958039d37fc05df5bd9487fac12c4cb3b0e8ee4c4f287d87d876b89fc3"
EXAM_COMMIT = "b30b290813d88109c5b9bc34354babefdc406f8d"


def _s009_row(finalists: dict[str, Any]) -> dict[str, Any]:
    for row in finalists.get("orderedFinalists", []):
        if str(row.get("id")) == CANDIDATE_ID:
            return row
    raise ValueError(f"{FINALISTS_REL} has no ordered finalist {CANDIDATE_ID}")


def reconstruct_catalogue(base: Any, finalists: dict[str, Any]) -> tuple[Any, list[dict[str, Any]]]:
    row = _s009_row(finalists)
    content = deepcopy(base)
    applied: list[dict[str, Any]] = []
    for patch in row["numericPatch"]:
        path = str(patch["path"])
        before = get_path(content, path)
        expected = patch["before"]
        if before != expected:
            raise ValueError(f"live H39 mismatch at {path}: {before!r} != {expected!r}")
        set_path(content, path, patch["after"])
        applied.append({"path": path, "before": before, "after": patch["after"]})
    texts = row["intendedHydratedUpdates"]["content/full-content.json"]
    for path, text in texts.items():
        set_path(content, str(path), str(text))
        applied.append({"path": path, "text": text})
    return content, applied


def catalogue_bytes(content: Any) -> bytes:
    return (json.dumps(content, ensure_ascii=False, indent=2) + "\n").encode()


def reconstruct(repo: Path = REPO) -> dict[str, Any]:
    live = repo / LIVE_REL
    live_sha = file_sha256(live)
    if live_sha != H39_FILE_SHA:
        raise ValueError(f"live {LIVE_REL} is {live_sha}, not H39 {H39_FILE_SHA}")
    base = read_json(live)
    finalists = read_json(repo / FINALISTS_REL)
    content, applied = reconstruct_catalogue(base, finalists)
    blob = catalogue_bytes(content)
    identity = {
        "candidate": CANDIDATE_ID,
        "examCommit": EXAM_COMMIT,
        "livePath": str(live),
        "liveFileSha256": live_sha,
        "fileSha256": sha256_bytes(blob),
        "semanticSha256": sha256_bytes(canonical_json_bytes(content)),
        "bytes": len(blob),
        "applied": len(applied),
    }
    if identity["fileSha256"] != EXAM_FILE_SHA:
        raise ValueError(
            f"reconstructed s009 file SHA {identity['fileSha256']} != exam {EXAM_FILE_SHA}"
        )
    if identity["semanticSha256"] != EXAM_SEMANTIC_SHA:
        raise ValueError(
            f"reconstructed s009 semantic SHA {identity['semanticSha256']} != exam {EXAM_SEMANTIC_SHA}"
        )
    if file_sha256(live) != H39_FILE_SHA:
        raise ValueError("reconstruction mutated live content/full-content.json")
    identity["examFileSha256"] = EXAM_FILE_SHA
    identity["examSemanticSha256"] = EXAM_SEMANTIC_SHA
    identity["liveUnchanged"] = True
    return {"identity": identity, "blob": blob, "content": content}


def write_catalogue(path: Path, blob: bytes, live: Path) -> None:
    if path.resolve() == live.resolve():
        raise ValueError("refusing to write s009 onto live content/full-content.json")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(blob)


def self_test() -> int:
    live = REPO / LIVE_REL
    before = live.read_bytes()
    packet = reconstruct()
    identity = packet["identity"]
    assert identity["fileSha256"] == EXAM_FILE_SHA
    assert identity["semanticSha256"] == EXAM_SEMANTIC_SHA
    assert identity["liveFileSha256"] == H39_FILE_SHA
    assert live.read_bytes() == before
    with tempfile.TemporaryDirectory(prefix="glassvow-489-s009-") as temp:
        out = Path(temp) / "s009-full-content.json"
        write_catalogue(out, packet["blob"], live)
        assert file_sha256(out) == EXAM_FILE_SHA
        try:
            write_catalogue(live, packet["blob"], live)
        except ValueError as exc:
            assert "refusing" in str(exc)
        else:
            raise AssertionError("reconstruction must refuse to overwrite live content")
    assert live.read_bytes() == before
    print("balance s009 reconstruct self-test OK")
    print(json.dumps({k: identity[k] for k in (
        "candidate", "examCommit", "liveFileSha256", "fileSha256", "semanticSha256",
        "bytes", "liveUnchanged",
    )}, indent=2, sort_keys=True))
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--out", type=Path, help="write the temporary s009 catalogue here")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.self_test:
        return self_test()
    packet = reconstruct()
    if args.out is not None:
        write_catalogue(args.out, packet["blob"], REPO / LIVE_REL)
    print(json.dumps(packet["identity"], indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (KeyError, OSError, TypeError, ValueError) as exc:
        print(f"balance_s009_reconstruct: {exc}", file=sys.stderr)
        raise SystemExit(2) from exc
