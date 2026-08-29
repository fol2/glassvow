#!/usr/bin/env python3
"""Existing-policy natural capacity check for #421 intent history."""

from __future__ import annotations

import json
import subprocess
import time
from collections import Counter
from pathlib import Path
from typing import Any

import post_843e899_terminal_hit_precision_capacity_v1 as common
import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-843e899-intent-history-capacity-v1.json"
SUMMARY = core.ROOT / "summaries/post-843e899-intent-history-capacity-v1.json"
PROBE = core.ROOT / "research_421_intent_history_capacity_probe_v1.gd"
common.BASELINE = core.ROOT / "intent-history-capacity-v1-baseline-source"
common.CANDIDATE = core.ROOT / "intent-history-capacity-v1-source"
common.PROBE = str(PROBE)
common.PREFIX = "intentHistory"


def seconds_left(deadline: float) -> int:
    remaining = int(deadline - time.monotonic())
    if remaining < 1:
        raise TimeoutError("intent-history capacity reached its wall-time cap")
    return remaining


common.seconds_left = seconds_left


def source_identity(protocol: dict[str, Any]) -> dict[str, Any]:
    result = common.source_identity(protocol)
    result["runnerSha256"] = core.file_sha(Path(__file__))
    result["probeSha256"] = core.file_sha(PROBE)
    return result


def static_faults() -> list[str]:
    candidate = common.CANDIDATE
    combat = (candidate / "domain/rules/combat.gd").read_text()
    sim = (candidate / "tools/balance_sim.gd").read_text()
    baseline_sim = (common.BASELINE / "tools/balance_sim.gd").read_text()
    direct = core.ROOT / "intent-history-v1-source"
    checks = (
        ("baseline telemetry absent", common.PREFIX not in baseline_sim),
        ("direct combat source preserved",
         core.file_sha(candidate / "domain/rules/combat.gd")
         == core.file_sha(direct / "domain/rules/combat.gd")),
        ("direct combat diff preserved",
         common.git(candidate, "diff", "--", "domain/rules/combat.gd")
         == common.git(direct, "diff", "--", "domain/rules/combat.gd")),
        ("sole candidate surfaces", common.git(candidate, "diff", "--name-only").splitlines()
         == ["domain/rules/combat.gd", "tools/balance_sim.gd"]),
        ("clean candidate diff", not common.git(candidate, "diff", "--check")),
        ("producer knob cardinality", combat.count("_research421_intent_producer") == 4),
        ("consumer knob cardinality", combat.count("_research421_intent_consumer") == 4),
        ("configuration interface cardinality",
         combat.count("configure_research421_intent_history") == 1),
        ("direct telemetry cardinality", combat.count('"research421IntentHistory"') == 1),
        ("capacity telemetry branch cardinality",
         sim.count('kind == "research421IntentHistory"') == 1),
        ("eligible response recorder cardinality",
         sim.count("func _record_intent_history_response") == 1),
        ("residual marker census cardinality",
         sim.count('enemy.flags.has("_research421IntentHistory")') == 1),
        ("no policy implementation", "research421" not in
         (candidate / "tools/balance_policy.gd").read_text().lower()),
        ("no persistent combat field", "research421" not in
         (candidate / "domain/state/combat_state.gd").read_text().lower()),
        ("no persistent run field", "research421" not in
         (candidate / "domain/state/run_state.gd").read_text().lower()),
    )
    return [label for label, passed in checks if not passed]


def analyse(
    protocol: dict[str, Any], baseline: dict[str, Any], candidate: dict[str, Any]
) -> tuple[dict[str, Any], list[str]]:
    faults: list[str] = []
    base_rows = baseline["rows"]
    candidate_rows = candidate["rows"]
    policy_rows: dict[int, list[dict[str, Any]]] = {
        index: [] for index in range(protocol["cohort"]["policyCount"])
    }
    cards: Counter[str] = Counter()
    moves: Counter[str] = Counter()
    total: Counter[str] = Counter()
    seeds_per_policy = len(protocol["cohort"]["simulationSeeds"])
    for index, (base, observed) in enumerate(zip(base_rows, candidate_rows, strict=True)):
        policy = int(observed.get("research421PolicyIndex", -1))
        if policy != index // seeds_per_policy:
            faults.append(f"row {index}: policy order")
        if observed.get("research421FactorAvailable") is not True \
                or observed.get("research421Configured") is not True \
                or observed.get("research421Producer") is not True \
                or observed.get("research421Consumer") is not False:
            faults.append(f"row {index}: A-only factor identity")
        if common.normalise(base) != common.normalise(observed):
            faults.append(f"row {index}: current-main path/result/RNG identity")

        metrics = common.research_metrics(observed)
        producer = metrics.get("intentHistoryProducer", 0)
        mediator = metrics.get("intentHistoryMediatorSet", 0)
        expiry = metrics.get("intentHistoryExpiry", 0)
        residual = metrics.get("intentHistoryResidualMarkers", 0)
        consumer_disabled = metrics.get("intentHistoryExpiryConsumerDisabled", 0)
        eligible = metrics.get("intentHistoryEligibleCards", 0)
        final = metrics.get("intentHistoryFinalResponses", 0)
        if producer != mediator:
            faults.append(f"row {index}: producer/mediator cardinality")
        if producer != expiry + residual:
            faults.append(f"row {index}: expiry/residual partition")
        if consumer_disabled != eligible + final:
            faults.append(f"row {index}: response disposition partition")
        if metrics.get("intentHistoryAiBoundaryKeyFault", 0) != 0:
            faults.append(f"row {index}: private key crossed AI boundary")
        if metrics.get("intentHistoryTelemetryFault", 0) != 0:
            faults.append(f"row {index}: telemetry attribution")
        for forbidden in ("Consumer", "MediatorConsume", "Payoff", "Requested", "Realised"):
            if metrics.get(f"intentHistory{forbidden}", 0) != 0:
                faults.append(f"row {index}: A-only emitted {forbidden}")
        row_card_total = 0
        row_move_total = 0
        for key, value in metrics.items():
            if value < 0:
                faults.append(f"row {index}: negative telemetry {key}")
            if key.startswith("intentHistoryEligibleCard_"):
                card = key.removeprefix("intentHistoryEligibleCard_")
                cards[card] += value
                row_card_total += value
            elif key.startswith("intentHistoryEligibleMove_"):
                move = key.removeprefix("intentHistoryEligibleMove_")
                moves[move] += value
                row_move_total += value
        if row_card_total != eligible or row_move_total != eligible:
            faults.append(f"row {index}: eligible identity attribution")
        total.update(metrics)
        policy_rows[policy].append({
            "seed": observed["seed"], "producer": producer,
            "eligible": eligible, "outcome": observed.get("outcome"),
            "error": observed.get("error", ""),
        })

    minimum = protocol["cohort"]["minimumRowsPerRobustPolicy"]
    exposure_active: list[int] = []
    active: list[int] = []
    inactive: list[int] = []
    ambiguous: list[int] = []
    viable: list[int] = []
    for policy, rows in policy_rows.items():
        exposure_rows = sum(row["producer"] > 0 for row in rows)
        eligible_rows = sum(row["eligible"] > 0 for row in rows)
        if exposure_rows >= minimum:
            exposure_active.append(policy)
        if eligible_rows >= minimum:
            active.append(policy)
            if any(row["eligible"] > 0 and row["outcome"] == "win" for row in rows):
                viable.append(policy)
        elif eligible_rows == 0:
            inactive.append(policy)
        else:
            ambiguous.append(policy)

    baseline_fault_rows = sum(
        row.get("outcome") in ("stall", "error") or bool(row.get("error"))
        for row in base_rows
    )
    counts = {
        "exposureActivePolicies": len(exposure_active),
        "activePolicies": len(active),
        "exactInactivePolicies": len(inactive),
        "ambiguousPolicies": len(ambiguous),
        "viablePolicies": len(viable),
        "distinctEligibleCards": len(cards),
        "distinctEligibleMoves": len(moves),
        "baselineFaultRows": baseline_fault_rows,
        "producerWindows": total.get("intentHistoryProducer", 0),
        "eligibleCards": total.get("intentHistoryEligibleCards", 0),
        "finalResponses": total.get("intentHistoryFinalResponses", 0),
        "residualMarkers": total.get("intentHistoryResidualMarkers", 0),
    }
    gates = protocol["gates"]
    identity_faults = [fault for fault in faults if "identity" in fault]
    semantic_faults = [fault for fault in faults if "identity" not in fault]
    checks = {
        "exactIdentity": len(identity_faults) <= gates["maximumIdentityMismatches"],
        "semanticAttribution": len(semantic_faults) <= gates["maximumSemanticFaults"],
        "activeSupport": counts["activePolicies"] >= gates["minimumActivePolicies"],
        "inactiveSupport": counts["exactInactivePolicies"] >= gates["minimumExactInactivePolicies"],
        "viableSupport": counts["viablePolicies"] >= gates["minimumViablePolicies"],
        "exposureSupport": counts["exposureActivePolicies"] >= gates["minimumExposureActivePolicies"],
        "cardBreadth": counts["distinctEligibleCards"] >= gates["minimumDistinctEligibleCards"],
        "moveBreadth": counts["distinctEligibleMoves"] >= gates["minimumDistinctEligibleMoves"],
        "baselineReliability": baseline_fault_rows <= gates["maximumBaselineFaultRows"],
    }
    return {
        "counts": counts,
        "checks": checks,
        "policySets": {
            "exposureActive": exposure_active, "active": active,
            "exactInactive": inactive, "ambiguous": ambiguous, "viable": viable,
        },
        "eligibleCardCounts": dict(sorted(cards.items())),
        "eligibleMoveCounts": dict(sorted(moves.items())),
        "telemetryTotals": dict(sorted(total.items())),
    }, faults


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite intent-history capacity summary")
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
            common.require("baseline probe identity",
                           baseline.get("probeSha256") == immutable["probeSha256"])
            candidate, plans["producerOnly"], outputs["producerOnly"] = common.run_probe(
                common.CANDIDATE, candidate_rows, "producer-only-A", protocol_sha,
                immutable["godotBinaryPath"], deadline,
            )
            common.require("candidate probe identity",
                           candidate.get("probeSha256") == immutable["probeSha256"])
            completed_rows = len(baseline["rows"]) + len(candidate["rows"])
            analysis, analysis_faults = analyse(protocol, baseline, candidate)
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
        decision = "record-intent-history-capacity-inconclusive-at-cap"
        boundary = 3
    elif faults or not checks_pass:
        outcome = "futility"
        decision = "close-intent-history-and-advance-to-private-counter-tag-transform"
        boundary = 2
    else:
        outcome = "success"
        decision = "freeze-intent-history-for-crn-first-look"
        boundary = 1

    summary = {
        "schemaVersion": 1, "issue": 421, "outcomeClass": outcome,
        "decision": decision, "decisionBoundary": boundary,
        "claimBoundary": protocol["claimBoundary"],
        "authority": protocol["decisionRules"][outcome + "Authority"],
        "protocolSha256": protocol_sha, "runnerSha256": core.file_sha(Path(__file__)),
        "sourceIdentity": actual_source, "sourceGateFaults": source_gate_faults,
        "faults": faults, "executionError": execution_error, "analysis": analysis,
        "planSha256": plans, "outputSha256": outputs,
        "GodotProcesses": len(outputs), "observedRows": completed_rows,
        "newSimulatorObservationRows": completed_rows,
        "newLedgerRows": ledger_after["records"] - ledger_before["records"],
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "ledgerBefore": ledger_before, "ledgerAfter": ledger_after,
        "wallTimeSeconds": elapsed,
        "maximumModelContextTokensDuringExecutionAndDecision": 0,
        "archiveHeadPreserved": immutable["repositoryRefs"][
            "refs/remotes/origin/research/issue-421-post-reshuffle-frontier-evidence"
        ],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "outcomeClass": outcome, "decision": decision, "faults": len(faults),
        "checks": analysis.get("checks", {}), "counts": analysis.get("counts", {}),
        "rows": completed_rows, "wallTimeSeconds": round(elapsed, 3),
    }, sort_keys=True))


if __name__ == "__main__":
    main()
