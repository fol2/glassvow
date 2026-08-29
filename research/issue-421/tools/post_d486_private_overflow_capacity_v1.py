#!/usr/bin/env python3
"""Existing-policy natural-capacity check for #421 Ember overflow."""

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


PROTOCOL = core.ROOT / "protocols/post-d486-private-overflow-capacity-v1.json"
SUMMARY = core.ROOT / "summaries/post-d486-private-overflow-capacity-v1.json"
PROBE = "res://tools/research_421_ember_overflow_capacity_probe.gd"
common.BASELINE = core.ROOT / "post-d486-private-overflow-v1-baseline"
common.CANDIDATE = core.ROOT / "post-d486-private-overflow-v1-source"
common.PROBE = PROBE
common.PREFIX = "emberOverflow"


def git_lines(path: Path, *args: str) -> list[str]:
    return subprocess.run(
        ["git", *args], cwd=path, check=True, text=True, capture_output=True,
    ).stdout.splitlines()


def seconds_left(deadline: float) -> int:
    remaining = int(deadline - time.monotonic())
    if remaining < 1:
        raise TimeoutError("private-overflow capacity reached its wall-time cap")
    return remaining


common.seconds_left = seconds_left


def source_identity(protocol: dict[str, Any]) -> dict[str, Any]:
    result = common.source_identity(protocol)
    result["baselineStatus"] = git_lines(common.BASELINE, "status", "--porcelain=v1")
    result["candidateStatus"] = git_lines(common.CANDIDATE, "status", "--porcelain=v1")
    result["runnerSha256"] = core.file_sha(Path(__file__))
    result["probeSha256"] = core.file_sha(
        common.CANDIDATE / "tools/research_421_ember_overflow_capacity_probe.gd")
    return result


def static_faults(protocol: dict[str, Any]) -> list[str]:
    candidate = common.CANDIDATE
    combat = (candidate / "domain/rules/combat.gd").read_text()
    player = (candidate / "domain/state/player_combatant.gd").read_text()
    sim = (candidate / "tools/balance_sim.gd").read_text()
    baseline_sim = (common.BASELINE / "tools/balance_sim.gd").read_text()
    direct = json.loads((core.ROOT / protocol["directIdentitySummaryPath"]).read_text())
    direct_source = direct["sourceIdentity"]["candidateSha256"]
    checks = (
        ("baseline telemetry absent", common.PREFIX not in baseline_sim),
        ("direct identity decision preserved",
         direct.get("decision") == "freeze-private-overflow-heavy-blow-for-natural-capacity"),
        ("direct combat source preserved",
         core.file_sha(candidate / "domain/rules/combat.gd")
         == direct_source["domain/rules/combat.gd"]),
        ("direct player source preserved",
         core.file_sha(candidate / "domain/state/player_combatant.gd")
         == direct_source["domain/state/player_combatant.gd"]),
        ("sole tracked candidate surfaces",
         git_lines(candidate, "diff", "--name-only") == [
             "domain/rules/combat.gd", "domain/state/player_combatant.gd",
             "tools/balance_sim.gd",
         ]),
        ("clean candidate diff", not common.git(candidate, "diff", "--check")),
        ("producer knob cardinality", combat.count("_research421_overflow_producer") == 3),
        ("consumer knob cardinality", combat.count("_research421_overflow_consumer") == 4),
        ("configuration interface cardinality",
         combat.count("configure_research421_ember_overflow") == 1),
        ("direct telemetry cardinality", combat.count("research421EmberOverflow") == 6),
        ("private marker cardinality", player.count("research421_ember_overflow") == 1),
        ("lifecycle helper cardinality", combat.count("_expire_research421_overflow") == 4),
        ("capacity telemetry branch cardinality",
         sim.count('kind == "research421EmberOverflow"') == 1),
        ("eligible consumer recorder cardinality",
         sim.count('"emberOverflowEligibleConsumers"') == 1),
        ("unavailable expiry recorder cardinality",
         sim.count('"emberOverflowUnavailableExpiries"') == 1),
        ("final-open recorder cardinality",
         sim.count('"emberOverflowFinalOpenMarks"') == 1),
        ("no policy implementation", "research421" not in
         (candidate / "tools/balance_policy.gd").read_text().lower()),
        ("no persistent combat surface", "research421" not in
         (candidate / "domain/state/combat_state.gd").read_text().lower()),
        ("no persistent run surface", "research421" not in
         (candidate / "domain/state/run_state.gd").read_text().lower()),
        ("private marker omitted from projection",
         "research421" not in player.split("func to_dict", 1)[1]),
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
    total: Counter[str] = Counter()
    seeds_per_policy = len(protocol["cohort"]["simulationSeeds"])
    for index, (base, observed) in enumerate(zip(base_rows, candidate_rows, strict=True)):
        policy = int(observed.get("research421PolicyIndex", -1))
        if policy != index // seeds_per_policy:
            faults.append(f"row {index}: policy identity/order")
        if observed.get("research421FactorAvailable") is not True \
                or observed.get("research421Configured") is not True \
                or observed.get("research421Producer") is not True \
                or observed.get("research421Consumer") is not False:
            faults.append(f"row {index}: A-only factor identity")
        if common.normalise(base) != common.normalise(observed):
            faults.append(f"row {index}: current-main path/result/RNG identity")

        metrics = common.research_metrics(observed)
        producer = metrics.get("emberOverflowProducer", 0)
        mediator = metrics.get("emberOverflowMediatorSet", 0)
        eligible = metrics.get("emberOverflowEligibleConsumers", 0)
        exact = metrics.get("emberOverflowEligibleConsumer_heavyBlow", 0)
        unavailable = metrics.get("emberOverflowUnavailableExpiries", 0)
        after_eligible = metrics.get("emberOverflowExpiryAfterEligible", 0)
        final_open = metrics.get("emberOverflowFinalOpenMarks", 0)
        expiry = metrics.get("emberOverflowExpiry", 0)
        requested = metrics.get("emberOverflowRequested", 0)
        lost = metrics.get("emberOverflowLost", 0)
        if producer != mediator:
            faults.append(f"row {index}: producer/mediator cardinality")
        if mediator != eligible + unavailable + final_open:
            faults.append(f"row {index}: mediator disposition partition")
        if expiry != unavailable + after_eligible:
            faults.append(f"row {index}: expiry disposition partition")
        if eligible != exact:
            faults.append(f"row {index}: exact consumer attribution")
        if producer > lost or lost > requested:
            faults.append(f"row {index}: positive overflow attribution")
        if metrics.get("emberOverflowMediatorSetWhileMarked", 0) != 0:
            faults.append(f"row {index}: non-stacking attribution")
        for forbidden in ("Consumer", "MediatorConsumed", "Payoff"):
            if metrics.get(f"emberOverflow{forbidden}", 0) != 0:
                faults.append(f"row {index}: A-only emitted {forbidden}")
        for key, value in metrics.items():
            if value < 0:
                faults.append(f"row {index}: negative telemetry {key}")
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
        "baselineFaultRows": baseline_fault_rows,
        "producerMarks": total.get("emberOverflowProducer", 0),
        "eligibleConsumers": total.get("emberOverflowEligibleConsumers", 0),
        "unavailableExpiries": total.get("emberOverflowUnavailableExpiries", 0),
        "finalOpenMarks": total.get("emberOverflowFinalOpenMarks", 0),
    }
    gates = protocol["gates"]
    identity_faults = [fault for fault in faults if "identity" in fault]
    semantic_faults = [fault for fault in faults if "identity" not in fault]
    checks = {
        "exactIdentity": len(identity_faults) <= gates["maximumIdentityMismatches"],
        "semanticAttribution": len(semantic_faults) <= gates["maximumSemanticFaults"],
        "activeSupport": counts["activePolicies"] >= gates["minimumActivePolicies"],
        "inactiveSupport": counts["exactInactivePolicies"]
        >= gates["minimumExactInactivePolicies"],
        "viableSupport": counts["viablePolicies"] >= gates["minimumViablePolicies"],
        "exposureSupport": counts["exposureActivePolicies"]
        >= gates["minimumExposureActivePolicies"],
        "baselineReliability": baseline_fault_rows <= gates["maximumBaselineFaultRows"],
    }
    return {
        "counts": counts,
        "checks": checks,
        "policySets": {
            "exposureActive": exposure_active, "active": active,
            "exactInactive": inactive, "ambiguous": ambiguous, "viable": viable,
        },
        "telemetryTotals": dict(sorted(total.items())),
    }, faults


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite private-overflow capacity summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    preflight_path = core.ROOT / protocol["mechanicalPreflight"]["summaryPath"]
    common.require("mechanical preflight unavailable", preflight_path.is_file())
    preflight = json.loads(preflight_path.read_text())
    common.require(
        "mechanical preflight not green",
        preflight.get("decision") == "authorise-first-scientific-capacity-look"
        and preflight.get("protocolSha256") == protocol_sha
        and preflight.get("runnerSha256")
        == protocol["mechanicalPreflight"]["runnerSha256"],
    )
    immutable = protocol["immutableInputs"]
    actual_source = source_identity(protocol)
    common.require("immutable source identity drift", actual_source == {
        key: immutable[key] for key in actual_source
    })
    ledger_before = identity.ledger_identity()
    common.require("ledger freeze drift", ledger_before == protocol["ledgerFreeze"])
    source_gate_faults = static_faults(protocol)
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
        decision = "record-private-overflow-capacity-inconclusive-at-cap"
        boundary = 3
    elif faults or not checks_pass:
        outcome = "futility"
        decision = "close-private-overflow-heavy-blow-representation-and-continue-causal-enumeration"
        boundary = 2
    else:
        outcome = "success"
        decision = "freeze-private-overflow-heavy-blow-for-crn-first-look"
        boundary = 1

    summary = {
        "schemaVersion": 1, "issue": 421, "outcomeClass": outcome,
        "decision": decision, "decisionBoundary": boundary,
        "claimBoundary": protocol["claimBoundary"],
        "authority": protocol["decisionRules"][outcome + "Authority"],
        "protocolSha256": protocol_sha, "runnerSha256": core.file_sha(Path(__file__)),
        "mechanicalPreflightSha256": core.file_sha(preflight_path),
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
        "archiveHeadsPreserved": {
            "843e899": immutable["repositoryRefs"][
                "refs/remotes/origin/research/issue-421-post-reshuffle-frontier-evidence"],
            "d486289": immutable["repositoryRefs"][
                "refs/remotes/origin/research/issue-421-post-843e899-family-ladder-evidence"],
        },
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "outcomeClass": outcome, "decision": decision, "faults": len(faults),
        "checks": analysis.get("checks", {}), "counts": analysis.get("counts", {}),
        "rows": completed_rows, "wallTimeSeconds": round(elapsed, 3),
    }, sort_keys=True))


if __name__ == "__main__":
    main()
