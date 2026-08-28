#!/usr/bin/env python3
"""Zero-row observability gate for multi-enemy card Shatter capacity."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v30-shatter-card-capacity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v30-shatter-card-capacity-v1.json"
TRACE_SOURCE = core.ROOT / "lantern-art-identity-source"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Shatter card-capacity mismatch: {label}")


def main_blob(path: str) -> bytes:
    return subprocess.run(
        ["git", "show", f"HEAD:{path}"], cwd=core.SOURCE,
        check=True, capture_output=True,
    ).stdout


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite Shatter card-capacity summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    immutable = protocol["immutableInputs"]
    require("runner SHA", core.file_sha(Path(__file__)) == immutable["runnerSha256"])
    require("task capsule SHA", core.file_sha(core.ROOT / "task-capsule.json") ==
            immutable["taskCapsuleSha256"])
    require("source commit", subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=core.SOURCE, check=True,
        text=True, capture_output=True,
    ).stdout.strip() == immutable["sourceCommit"])
    require("trace source commit", subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=TRACE_SOURCE, check=True,
        text=True, capture_output=True,
    ).stdout.strip() == immutable["sourceCommit"])

    sources: dict[str, str] = {}
    for path, expected_sha in immutable["currentMainSourceSha256"].items():
        blob = main_blob(path)
        require(f"{path} SHA", core.sha(blob) == expected_sha)
        sources[f"main:{path}"] = blob.decode()
    for path, expected_sha in immutable["traceSourceSha256"].items():
        trace_path = TRACE_SOURCE / path
        require(f"trace {path} SHA", core.file_sha(trace_path) == expected_sha)
        sources[f"trace:{path}"] = trace_path.read_text()
    for assertion in protocol["sourceAssertions"]:
        require(assertion["id"], assertion["contains"] in sources[assertion["path"]])

    evidence: dict[str, dict[str, Any]] = {}
    for name, spec in protocol["priorEvidence"].items():
        path = core.ROOT / spec["path"]
        require(f"{name} SHA", core.file_sha(path) == spec["sha256"])
        evidence[name] = json.loads(path.read_text())
        require(f"{name} decision", evidence[name]["decision"] == spec["decision"])
    require("selected topology", evidence["topology"]["selectedRepresentation"]["id"] ==
            protocol["selectedRepresentation"]["id"])
    require("eligible cache authority", evidence["lanternCapacity"]["execution"]
            ["manifests"]["capacity"]["outputSha256"] ==
            immutable["eligibleCacheSha256"])

    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    available = set(protocol["sourceTraceProjection"]["availableFields"])
    required = set(protocol["eventParser"]["requiredFields"])
    missing = sorted(required - available)
    elapsed = time.monotonic() - started
    if elapsed > float(protocol["budget"]["maximumWallTimeSeconds"]):
        outcome, boundary = "inconclusive", 3
    elif missing:
        outcome, boundary = "futility", 2
    else:
        # Immutable current-main cannot reach this branch; support remains unopened.
        outcome, boundary = "inconclusive", 3

    decision = {
        "futility": "close-multi-enemy-card-shatter-on-observability-gate",
        "inconclusive": "record-multi-enemy-card-shatter-capacity-inconclusive-at-cap",
    }[outcome]
    ledger_after = identity.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    summary: dict[str, Any] = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": boundary,
        "decision": decision,
        "outcomeClass": outcome,
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "selectedRepresentation": protocol["selectedRepresentation"],
        "sourceTraceProjection": protocol["sourceTraceProjection"],
        "eventParser": protocol["eventParser"],
        "missingRequiredFields": missing,
        "registeredCapacityGates": protocol["gates"],
        "eligibleCache": {
            "sha256": immutable["eligibleCacheSha256"],
            "filesRead": 0,
            "supportRowsRead": 0,
            "reason": "Source observability gate runs before cache access.",
        },
        "execution": {
            "traceFilesRead": 0,
            "cacheFilesRead": 0,
            "newSimulatorObservationRows": 0,
            "newLedgerRows": 0,
            "protectedSeedRows": ledger_after["protectedSeedRows"],
            "maximumModelContextTokens": 0,
            "wallTimeSeconds": elapsed,
        },
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "authority": protocol["decisionRules"][f"{outcome}Authority"],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS",
        "decisionBoundary": boundary,
        "decision": decision,
        "missingRequiredFields": missing,
        "cacheFilesRead": 0,
        "newSimulatorObservationRows": 0,
        "summarySha256": core.file_sha(SUMMARY),
    }))


if __name__ == "__main__":
    main()
