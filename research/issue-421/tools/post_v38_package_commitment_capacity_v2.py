#!/usr/bin/env python3
"""Corrected entrypoint for the frozen package-commitment capacity audit."""

from pathlib import Path

import post_v38_package_commitment_capacity as audit
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-package-commitment-capacity-v2.json"
SUMMARY = core.ROOT / "summaries/post-v38-package-commitment-capacity-v2.json"


if __name__ == "__main__":
    protocol, _ = core.load_protocol(PROTOCOL)
    if core.file_sha(Path(__file__)) != protocol["immutableInputs"]["entrypointSha256"]:
        raise RuntimeError("package-commitment v2 entrypoint SHA drifted")
    audit.PROTOCOL = PROTOCOL
    audit.SUMMARY = SUMMARY
    audit.main()
