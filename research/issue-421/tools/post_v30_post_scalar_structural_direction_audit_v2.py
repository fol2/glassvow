#!/usr/bin/env python3
"""Mechanical v2 entrypoint for the post-scalar semantic audit."""

from pathlib import Path

import post_v30_post_scalar_structural_direction_audit as audit
import research as core


PROTOCOL = core.ROOT / "protocols/post-v30-post-scalar-structural-direction-audit-v2.json"
SUMMARY = core.ROOT / "summaries/post-v30-post-scalar-structural-direction-audit-v2.json"


def main() -> None:
    protocol, _ = core.load_protocol(PROTOCOL)
    if core.file_sha(Path(__file__)) != protocol["immutableInputs"]["entrypointSha256"]:
        raise RuntimeError("post-scalar direction audit v2 entrypoint mismatch")
    audit.false = False
    audit.PROTOCOL = PROTOCOL
    audit.SUMMARY = SUMMARY
    audit.main()


if __name__ == "__main__":
    main()
