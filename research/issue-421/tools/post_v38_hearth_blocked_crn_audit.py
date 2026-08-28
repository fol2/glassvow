#!/usr/bin/env python3
"""Zero-row audit of the frozen Hearth blocked-CRN decision for #421."""

from __future__ import annotations

import json
import time
from pathlib import Path
from typing import Any

import post_v38_hearth_payoff_identity as payoff_identity
import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-hearth-blocked-crn-audit-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-hearth-blocked-crn-audit-v1.json"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Hearth blocked CRN audit mismatch: {label}")


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the Hearth blocked CRN audit")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    for relative, expected in protocol["immutableInputs"].items():
        require(relative, core.file_sha(core.ROOT / relative) == expected)
    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])

    experiment = json.loads((core.ROOT / protocol["experimentSummary"]).read_text())
    require("experiment boundary", experiment["decisionBoundary"] == 3)
    require("experiment decision", experiment["decision"]
            == "record-hearth-blocked-crn-inconclusive-at-cap")
    require("experiment execution error", experiment["execution"]["executionError"]
            == "Hearth blocked CRN mismatch: H1Q1 trace schema")
    require("experiment row cap", experiment["execution"]["newSimulatorObservationRows"]
            == protocol["budget"]["experimentNewSimulatorObservationRows"])

    faults: dict[str, list[str]] = {}
    outputs: dict[str, dict[str, Any]] = {}
    for cell, manifest in experiment["execution"]["cells"].items():
        output_sha = str(manifest["outputSha256"])
        output_path = core.CACHE / f"{output_sha}.json"
        require(f"{cell} output SHA", core.file_sha(output_path) == output_sha)
        output = json.loads(output_path.read_text())
        require(f"{cell} plan identity", output["planSha256"]
                == manifest["planSha256"])
        outputs[cell] = output
        faults[cell] = payoff_identity.trace_schema_faults(output["rows"])
    require("cached read cap", sum(len(output["rows"]) for output in outputs.values())
            == protocol["budget"]["cachedObservationRowsRead"])
    require("exact fault census", faults == protocol["expectedFaults"])

    row = outputs["H1Q1"]["rows"][138]
    fight = row["fights"][19]
    event = row["trajectory"]["hearthFights"][19]
    observed = {
        "cell": "H1Q1",
        "rowIndex": 138,
        "seed": row["seed"],
        "policyIndex": 34,
        "fightIndex": 19,
        "fightResult": fight["result"],
        "owned": event["owned"],
        "terminalEmbers": event["terminalEmbers"],
        "capturedProc": event["proc"],
        "branchPredicateFromFrozenRow": (
            fight["result"] == "win" and event["owned"] is True
            and int(event["terminalEmbers"]) > 0
        ),
    }
    require("fault localisation", observed == protocol["expectedObservation"])

    ledger_after = identity.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    elapsed = time.monotonic() - started
    require("wall-time ceiling", elapsed <= protocol["budget"]["maximumWallTimeSeconds"])
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": 1,
        "decision": "confirm-hearth-crn-inconclusive-observation-contract-stop",
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "experimentProtocolSha256": protocol["immutableInputs"][
            "protocols/post-v38-hearth-blocked-crn-v1.json"],
        "experimentSummarySha256": protocol["immutableInputs"][
            "summaries/post-v38-hearth-blocked-crn-v1.json"],
        "faults": faults,
        "faultObservation": observed,
        "interpretation": {
            "experimentDecision": "Boundary 3 is exact: one H1Q1 row violates the preregistered proc observation contract.",
            "causalDecision": "Unavailable. The frozen first look stopped before fitting, and no cached endpoint is promoted post hoc.",
            "rootCauseBoundary": "The cached row localises a contradiction between branch-predicate fields and queue-derived proc telemetry, but lacks the per-fight queue and HP transition needed to distinguish branch execution from observation loss without a new experiment.",
            "rerun": "Forbidden by the experiment protocol; no repair, reinterpretation or repeat was performed."
        },
        "cachedObservationRowsRead": protocol["budget"]["cachedObservationRowsRead"],
        "newSimulatorObservationRows": 0,
        "newLedgerRows": 0,
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "maximumModelContextTokens": 0,
        "wallTimeSeconds": elapsed,
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "authority": protocol["decisionRules"]["successAuthority"]
    }
    SUMMARY.parent.mkdir(parents=True, exist_ok=True)
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS",
        "decision": summary["decision"],
        "newSimulatorObservationRows": 0,
        "summarySha256": core.file_sha(SUMMARY)
    }))


if __name__ == "__main__":
    main()
