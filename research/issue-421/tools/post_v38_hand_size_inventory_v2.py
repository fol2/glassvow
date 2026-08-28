#!/usr/bin/env python3
"""Correct one pre-estimand hash typo and run the frozen hand-size audit."""

import copy
from pathlib import Path

import post_v38_hand_size_inventory as audit
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-hand-size-inventory-v2.json"
SUMMARY = core.ROOT / "summaries/post-v38-hand-size-inventory-v2.json"


if __name__ == "__main__":
    revision, revision_sha = core.load_protocol(PROTOCOL)
    if core.file_sha(Path(__file__)) != revision["entrypointSha256"]:
        raise RuntimeError("hand-size inventory v2 entrypoint SHA drifted")
    base_path = core.ROOT / revision["baseProtocol"]["path"]
    base, base_sha = core.load_protocol(base_path)
    if base_sha != revision["baseProtocol"]["sha256"]:
        raise RuntimeError("hand-size inventory v1 protocol drifted")
    if core.file_sha(Path(audit.__file__)) != revision["auditCoreSha256"]:
        raise RuntimeError("hand-size inventory audit core drifted")
    correction = revision["onlyCorrection"]
    packet = base["immutableGitEvidence"]["issue525HandSizePositiveControl"]
    if packet["sha256"] != correction["from"]:
        raise RuntimeError("hand-size inventory correction source drifted")
    effective = copy.deepcopy(base)
    effective["immutableGitEvidence"]["issue525HandSizePositiveControl"]["sha256"] = \
        correction["to"]
    original_load = core.load_protocol

    def load_protocol(path: Path):
        return (effective, revision_sha) if Path(path) == PROTOCOL else original_load(path)

    audit.PROTOCOL = PROTOCOL
    audit.SUMMARY = SUMMARY
    core.load_protocol = load_protocol
    audit.main()
