#!/usr/bin/env python3
"""Existing-policy natural capacity check for #421 positive-overkill Facet salvage."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any

import post_843e899_terminal_hit_precision_capacity_v1 as common
import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-843e899-positive-overkill-capacity-v1.json"
SUMMARY = core.ROOT / "summaries/post-843e899-positive-overkill-capacity-v1.json"
common.BASELINE = core.ROOT / "positive-overkill-capacity-v1-baseline-source"
common.CANDIDATE = core.ROOT / "positive-overkill-capacity-v1-source"
common.PROBE = "res://tools/research_421_positive_overkill_capacity_probe.gd"
common.PREFIX = "positiveOverkill"


def seconds_left(deadline: float) -> int:
    remaining = int(deadline - time.monotonic())
    if remaining < 1:
        raise TimeoutError("positive-overkill capacity reached its wall-time cap")
    return remaining


common.seconds_left = seconds_left


def source_identity(protocol: dict[str, Any]) -> dict[str, Any]:
    result = common.source_identity(protocol)
    result["runnerSha256"] = core.file_sha(Path(__file__))
    return result


def static_faults() -> list[str]:
    candidate = common.CANDIDATE
    combat = (candidate / "domain/rules/combat.gd").read_text()
    sim = (candidate / "tools/balance_sim.gd").read_text()
    baseline_sim = (common.BASELINE / "tools/balance_sim.gd").read_text()
    checks = (
        ("baseline telemetry absent", common.PREFIX not in baseline_sim),
        ("producer knob cardinality", combat.count("_research421_excess_producer") == 4),
        ("consumer knob cardinality", combat.count("_research421_excess_consumer") == 4),
        ("configuration interface cardinality",
         combat.count("configure_research421_positive_overkill") == 1),
        ("mediator key cardinality",
         combat.count("research421PositiveOverkillIntrinsic") == 2),
        ("direct telemetry cardinality",
         combat.count('"t": &"research421PositiveOverkill"') == 5),
        ("capacity telemetry branch cardinality",
         sim.count('kind == "research421PositiveOverkill"') == 1),
        ("eligible-card counter cardinality",
         sim.count('"positiveOverkillEligibleCards"') == 1),
        ("no policy implementation", "research421" not in
         (candidate / "tools/balance_policy.gd").read_text().lower()),
        ("no persistent combat field", "research421" not in
         (candidate / "domain/state/combat_state.gd").read_text().lower()),
        ("no persistent run field", "research421" not in
         (candidate / "domain/state/run_state.gd").read_text().lower()),
    )
    return [label for label, passed in checks if not passed]


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite positive-overkill capacity summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    immutable = protocol["immutableInputs"]
    actual_source = source_identity(protocol)
    common.require("immutable source identity drift", actual_source == {
        key: immutable[key] for key in actual_source
    })
    ledger_before = identity.ledger_identity()
    common.require("ledger freeze drift", ledger_before == protocol["ledgerFreeze"])
    source_gate_faults = static_faults()
    baseline_rows = common.cohort_rows(protocol, False)
    candidate_rows = common.cohort_rows(protocol, True)
    common.require("row budget drift", len(baseline_rows) + len(candidate_rows)
                   == protocol["budget"]["newScientificSimulatorObservationRows"])

    started = time.monotonic()
    deadline = started + protocol["budget"]["maximumWallTimeSeconds"]
    plans: dict[str, str] = {}
    outputs: dict[str, str] = {}
    execution_error = ""
    analysis: dict[str, Any] = {}
    faults = list(source_gate_faults)
    completed_rows = 0
    if not source_gate_faults:
        try:
            baseline, plans["baseline"], outputs["baseline"] = common.run_probe(
                common.BASELINE, baseline_rows, "current-main", protocol_sha,
                immutable["godotBinaryPath"], deadline,
            )
            candidate, plans["producerOnly"], outputs["producerOnly"] = common.run_probe(
                common.CANDIDATE, candidate_rows, "producer-only-A", protocol_sha,
                immutable["godotBinaryPath"], deadline,
            )
            completed_rows = len(baseline["rows"]) + len(candidate["rows"])
            analysis, analysis_faults = common.analyse(protocol, baseline, candidate)
            faults.extend(analysis_faults)
        except (OSError, subprocess.SubprocessError, TimeoutError, RuntimeError) as error:
            execution_error = str(error)

    ledger_after = identity.ledger_identity()
    if ledger_after != ledger_before:
        faults.append("append-only ledger changed")
    elapsed = time.monotonic() - started
    checks_pass = bool(analysis) and all(analysis["checks"].values())
    if execution_error or elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        outcome = "inconclusive"
        decision = "record-positive-overkill-capacity-inconclusive-at-cap"
        boundary = 3
    elif faults or not checks_pass:
        outcome = "futility"
        decision = "close-positive-overkill-and-terminal-hit-precision-advance-to-cross-turn-hold"
        boundary = 2
    else:
        outcome = "success"
        decision = "freeze-positive-overkill-facet-salvage-for-crn-first-look"
        boundary = 1

    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "outcomeClass": outcome,
        "decision": decision,
        "decisionBoundary": boundary,
        "claimBoundary": protocol["claimBoundary"],
        "authority": protocol["decisionRules"][outcome + "Authority"],
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "sourceIdentity": actual_source,
        "sourceGateFaults": source_gate_faults,
        "faults": faults,
        "executionError": execution_error,
        "analysis": analysis,
        "planSha256": plans,
        "outputSha256": outputs,
        "GodotProcesses": len(outputs),
        "observedRows": completed_rows,
        "newSimulatorObservationRows": completed_rows,
        "newLedgerRows": ledger_after["records"] - ledger_before["records"],
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "wallTimeSeconds": elapsed,
        "maximumModelContextTokensDuringExecutionAndDecision": 0,
        "archiveHeadPreserved": immutable["repositoryRefs"][
            "refs/remotes/origin/research/issue-421-post-reshuffle-frontier-evidence"
        ],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "outcomeClass": outcome,
        "decision": decision,
        "faults": len(faults),
        "checks": analysis.get("checks", {}),
        "counts": analysis.get("counts", {}),
        "rows": completed_rows,
        "wallTimeSeconds": round(elapsed, 3),
    }, sort_keys=True))


if __name__ == "__main__":
    main()
