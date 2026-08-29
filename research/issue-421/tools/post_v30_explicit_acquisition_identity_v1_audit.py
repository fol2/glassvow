#!/usr/bin/env python3
"""Zero-row forensic classification of explicit-acquisition identity v1."""

from __future__ import annotations

import json
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v30-explicit-acquisition-identity-v1-audit.json"
SUMMARY = core.ROOT / "summaries/post-v30-explicit-acquisition-identity-v1-audit.json"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Explicit acquisition v1 audit mismatch: {label}")


def cache(digest: str) -> dict[str, Any]:
    path = core.CACHE / f"{digest}.json"
    require(f"cache {digest}", path.is_file() and core.file_sha(path) == digest)
    value = json.loads(path.read_text())
    require(f"cache {digest} type", isinstance(value, dict))
    return value


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite explicit acquisition v1 audit")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    immutable = protocol["immutableInputs"]
    require("runner identity", core.file_sha(Path(__file__)) == immutable["runnerSha256"])
    for relative, expected in immutable["evidenceSha256"].items():
        require(f"evidence {relative}", core.file_sha(core.ROOT / relative) == expected)

    source = protocol["sourceEvidence"]
    probe_path = core.ROOT / source["probePath"]
    sim_path = core.ROOT / source["simPath"]
    require("probe identity", core.file_sha(probe_path) == source["probeSha256"])
    require("sim identity", core.file_sha(sim_path) == source["simSha256"])
    probe = probe_path.read_text()
    sim = sim_path.read_text()
    require("typed trailing factor", sim.count(
        'dusk_acquisition_choice: String = "") -> Dictionary:'
    ) == 1)
    require("typed factor validation", sim.count(
        'assert(dusk_acquisition_choice in ["", "off", "executioner", "guardedStrike"])'
    ) == 1)
    require("faulty omitted binding", probe.count(
        '\t\t\tfalse, false, {}, null, false, false)\n'
    ) == 1)
    require("faulty off binding", probe.count(
        '\t\tfalse, false, {}, null, false, false, str(spec["acquisition"]))\n'
    ) == 1)

    artifacts = protocol["executionArtifacts"]
    direct = cache(artifacts["directOutputSha256"])
    sentinel_plan = cache(artifacts["sentinelPlanSha256"])
    sentinel = cache(artifacts["sentinelOutputSha256"])
    require("direct cardinality", len(direct["rows"]) == artifacts["directValidRows"])
    require("sentinel plan identity", sentinel["planSha256"] ==
            artifacts["sentinelPlanSha256"])
    require("sentinel planned cardinality", len(sentinel_plan["rows"]) ==
            artifacts["sentinelAttemptedRows"])
    require("sentinel output cardinality", len(sentinel["rows"]) ==
            artifacts["sentinelAttemptedRows"])
    empty_rows = sum(row == {} for row in sentinel["rows"])
    require("all sentinel positions empty", empty_rows == artifacts["sentinelEmptyRows"])
    require("omitted arm encoding", all(
        "acquisition" not in row for row in sentinel_plan["rows"][:16]
    ))
    require("off arm encoding", all(
        row.get("acquisition") == "off" for row in sentinel_plan["rows"][16:]
    ))

    v1_summary = json.loads((core.ROOT / protocol["v1SummaryPath"]).read_text())
    require("v1 direct pass", v1_summary["directControls"]["status"] == "PASS")
    require("v1 error classification", v1_summary["executionError"] ==
            "Explicit acquisition identity mismatch: sentinel row schema")
    require("v1 no enabled rows", v1_summary["enabledWholeRunRows"] == 0)

    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    elapsed = time.monotonic() - started
    require("wall-time cap", elapsed <= protocol["budget"]["maximumWallTimeSeconds"])
    ledger_after = identity.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": 0,
        "decision": "classify-v1-as-empty-output-call-binding-failure",
        "outcomeClass": "mechanical-harness-failure",
        "scientificIdentityDecision": "not reached",
        "reason": protocol["finding"],
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "v1DirectValidRows": len(direct["rows"]),
        "v1SentinelAttemptedRows": len(sentinel["rows"]),
        "v1SentinelValidObservationRows": 0,
        "v1SentinelEmptyPositions": empty_rows,
        "newSimulatorObservationRows": 0,
        "newGodotProcesses": 0,
        "newLedgerRows": 0,
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "maximumModelContextTokens": 0,
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "wallTimeSeconds": elapsed,
        "authority": protocol["decisionRules"]["mechanicalAuthority"],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS",
        "decision": summary["decision"],
        "scientificIdentityDecision": "not reached",
        "summarySha256": core.file_sha(SUMMARY),
    }))


if __name__ == "__main__":
    main()
