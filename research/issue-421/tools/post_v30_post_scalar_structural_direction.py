#!/usr/bin/env python3
"""Zero-row selection of the post-acquisition structural representation."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v30-post-scalar-structural-direction-v1.json"
SUMMARY = core.ROOT / "summaries/post-v30-post-scalar-structural-direction-v1.json"
SOURCE = core.ROOT / "post-scalar-structural-v1-source"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Post-scalar structural direction mismatch: {label}")


def git(*args: str) -> str:
    return subprocess.run(
        ["git", *args], cwd=SOURCE, check=True, text=True, capture_output=True,
    ).stdout.strip()


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite post-scalar structural direction")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    error = ""
    evaluated: dict[str, Any] = {}
    selected: list[str] = []
    ledger_before: dict[str, Any] = {}
    ledger_after: dict[str, Any] = {}
    try:
        immutable = protocol["immutableInputs"]
        require("runner", core.file_sha(Path(__file__)) == immutable["runnerSha256"])
        require("task capsule", core.file_sha(core.ROOT / "task-capsule.json") ==
                immutable["taskCapsuleSha256"])
        require("source commit", git("rev-parse", "HEAD") == immutable["sourceCommit"])
        require("source status", git("status", "--porcelain") == "")
        for relative, expected in immutable["sourceSha256"].items():
            require(f"source {relative}", core.file_sha(SOURCE / relative) == expected)
        for relative, anchors in protocol["sourceAnchors"].items():
            source = (SOURCE / relative).read_text()
            for anchor in anchors:
                require(f"anchor {relative}: {anchor}", source.count(anchor) == 1)
        for relative, expected in immutable["evidenceSha256"].items():
            require(f"evidence {relative}", core.file_sha(core.ROOT / relative) == expected)
        ledger_before = identity.ledger_identity()
        require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
        required = protocol["eligibilityFields"]
        for option in protocol["options"]:
            failures = [field for field in required if not bool(option["attributes"][field])]
            evaluated[option["id"]] = {
                "eligible": not failures,
                "failedFields": failures,
                "attributes": option["attributes"],
            }
            if not failures:
                selected.append(option["id"])
        require("partition identities", sorted(evaluated) ==
                sorted(protocol["expectedOptionIds"]))
        ledger_after = identity.ledger_identity()
        require("zero-row ledger identity", ledger_after == ledger_before)
    except (FileNotFoundError, json.JSONDecodeError, KeyError, TypeError,
            ValueError, RuntimeError, subprocess.CalledProcessError) as caught:
        error = str(caught)

    elapsed = time.monotonic() - started
    if elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        error = "post-scalar structural direction exceeded wall-time cap"
    if error:
        boundary, outcome = 3, "inconclusive"
        decision = "record-post-scalar-structural-direction-inconclusive"
    elif len(selected) == 1:
        boundary, outcome = 1, "success"
        decision = f"freeze-{selected[0]}-for-design"
    elif not selected:
        boundary, outcome = 2, "futility"
        decision = "record-post-scalar-structural-direction-unavailable"
    else:
        boundary, outcome = 3, "inconclusive"
        decision = "record-post-scalar-structural-direction-ambiguous"
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": boundary,
        "decision": decision,
        "outcomeClass": outcome,
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "evaluated": evaluated,
        "selected": selected,
        "executionError": error,
        "newSimulatorObservationRows": 0,
        "newSupportRows": 0,
        "newCausalRows": 0,
        "newLedgerRows": 0,
        "GodotProcesses": 0,
        "protectedSeedRows": ledger_after.get(
            "protectedSeedRows", ledger_before.get("protectedSeedRows", 0),
        ),
        "maximumModelContextTokens": 0,
        "wallTimeSeconds": elapsed,
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "authority": protocol["decisionRules"][f"{outcome}Authority"],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS",
        "decisionBoundary": boundary,
        "decision": decision,
        "summarySha256": core.file_sha(SUMMARY),
    }))


if __name__ == "__main__":
    main()
