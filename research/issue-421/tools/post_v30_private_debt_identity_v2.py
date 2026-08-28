#!/usr/bin/env python3
"""Versioned private-debt identity execution after exact mechanical preflight."""

from __future__ import annotations

import json
from pathlib import Path

import post_v30_private_debt_identity as v1
import research as core


PROTOCOL = core.ROOT / "protocols/post-v30-private-debt-identity-v2.json"
SUMMARY = core.ROOT / "summaries/post-v30-private-debt-identity-v2.json"
PROTOTYPE = core.ROOT / "private-debt-identity-v2-source"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Private-debt identity v2 mismatch: {label}")


def main() -> None:
    protocol, _ = core.load_protocol(PROTOCOL)
    provenance = protocol["v2Provenance"]
    require("immutable v1 runner", core.file_sha(
        core.ROOT / provenance["baseRunnerPath"],
    ) == provenance["baseRunnerSha256"])
    preflight_path = core.ROOT / provenance["preflightSummaryPath"]
    require("preflight summary identity", core.file_sha(preflight_path) ==
            provenance["preflightSummarySha256"])
    preflight = json.loads(preflight_path.read_text())
    require("preflight decision", preflight["decision"] ==
            "admit-private-debt-identity-v2-execution")
    require("preflight zero-row boundary", all(preflight[key] == 0 for key in (
        "wholeRunRows", "capacityRows", "supportRows", "causalRows",
        "newSimulatorObservationRows", "newLedgerRows", "GodotProcesses",
        "protectedSeedRows",
    )))

    v1.PROTOCOL = PROTOCOL
    v1.SUMMARY = SUMMARY
    v1.PROTOTYPE = PROTOTYPE
    v1.DIRECT_PROBE = PROTOTYPE / "tools/research_421_private_debt_probe.gd"
    v1.__file__ = __file__
    v1.main()


if __name__ == "__main__":
    main()
