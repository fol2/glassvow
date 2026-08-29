#!/usr/bin/env python3
"""Natural-capacity screen for the issue #421 Afterimage order control."""

from __future__ import annotations

import json
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import post_v38_afterimage_order_identity_v1 as order
import post_v38_fight_local_identity as v1
import post_v38_knob_identity as ledger
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-afterimage-order-capacity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-afterimage-order-capacity-v1.json"
SOURCE = order.CANDIDATE
PROBE = order.CANDIDATE_PROBE
ARMS = ("current", "ward-before-edge")


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(label)


def rows(protocol: dict[str, Any]) -> list[dict[str, Any]]:
    cohort = protocol["cohort"]
    return [
        {
            "id": f"afterimage-order-capacity-{arm}-{policy_index}-{seed}",
            "mode": "whole-run",
            "aspect": cohort["aspect"],
            "vow": cohort["vow"],
            "seed": seed,
            "policyRoot": cohort["policyRoot"],
            "policyIndex": policy_index,
            "research421": order.settings("ward-base-5", arm),
        }
        for arm in ARMS
        for policy_index in range(cohort["policyCount"])
        for seed in cohort["simulationSeeds"]
    ]


def _n(row: dict[str, Any], key: str) -> int:
    return int(row.get("packageEvents", {}).get(key, 0))


def metrics(
    current_rows: list[dict[str, Any]],
    enabled_rows: list[dict[str, Any]],
    seeds: list[int],
    protocol: dict[str, Any],
) -> tuple[dict[str, Any], list[str]]:
    faults: list[str] = []
    active_by_policy: dict[int, set[int]] = {}
    drawn_by_policy: dict[int, set[int]] = {}
    current_active_rows = 0
    enabled_active_rows = 0
    current_payoffs = 0
    enabled_payoffs = 0
    intervention_rows = 0
    intervention_events = 0
    uncovered_intervention_events = 0
    gained_active_rows = 0
    lost_active_rows = 0
    guarded_drawn_rows = 0
    guarded_played_rows = 0
    guarded_offered_rows = 0
    guarded_draws = 0
    guarded_plays = 0
    guarded_offers = 0
    additional_stall_or_error = 0
    policy_mismatches = 0
    for index, (current, enabled) in enumerate(zip(current_rows, enabled_rows)):
        policy_index = index // len(seeds)
        seed = seeds[index % len(seeds)]
        current_payoff = _n(current, "afterimagePayoffEvents")
        enabled_payoff = _n(enabled, "afterimagePayoffEvents")
        current_active_rows += int(current_payoff > 0)
        enabled_active_rows += int(enabled_payoff > 0)
        current_payoffs += current_payoff
        enabled_payoffs += enabled_payoff
        if enabled_payoff > 0:
            active_by_policy.setdefault(policy_index, set()).add(seed)
        if current_payoff == 0 and enabled_payoff > 0:
            gained_active_rows += 1
        if current_payoff > 0 and enabled_payoff == 0:
            lost_active_rows += 1

        interventions = _n(enabled, "afterimageOrderInterventionEvents")
        intervention_events += interventions
        intervention_rows += int(interventions > 0)
        uncovered_intervention_events += max(0, interventions - enabled_payoff)
        if _n(current, "afterimageOrderInterventionEvents") != 0:
            faults.append(f"{policy_index}-{seed}:current-intervention")

        for arm, row in (("current", current), ("enabled", enabled)):
            producer = _n(row, "afterimageProducerEvents")
            mediator_set = _n(row, "afterimageMediatorSetEvents")
            consumer = _n(row, "afterimageConsumerEvents")
            mediator_consume = _n(row, "afterimageMediatorConsumeEvents")
            payoff = _n(row, "afterimagePayoffEvents")
            requested = _n(row, "afterimagePayoffRequested")
            realised = _n(row, "afterimagePayoffRealised")
            producer_ward = _n(row, "afterimageProducerWard")
            stored_ward = _n(row, "afterimageStoredWard")
            if producer != mediator_set:
                faults.append(f"{policy_index}-{seed}:{arm}-producer-set")
            if not (consumer == mediator_consume == payoff):
                faults.append(f"{policy_index}-{seed}:{arm}-consumer-payoff")
            if not (0 <= stored_ward <= producer * 5 and stored_ward <= producer_ward):
                faults.append(f"{policy_index}-{seed}:{arm}-stored-value")
            if not (0 <= requested <= payoff * 5 and realised == requested):
                faults.append(f"{policy_index}-{seed}:{arm}-payoff-value")
            if any(str(key).startswith("scoreline") and int(value) != 0
                   for key, value in row.get("packageEvents", {}).items()):
                faults.append(f"{policy_index}-{seed}:{arm}-scoreline-event")

        offered = _n(enabled, "guardedStrikeOffered")
        drawn = _n(enabled, "guardedStrikeDrawn")
        played = _n(enabled, "guardedStrikePlayed")
        guarded_offers += offered
        guarded_draws += drawn
        guarded_plays += played
        guarded_offered_rows += int(offered > 0)
        guarded_drawn_rows += int(drawn > 0)
        guarded_played_rows += int(played > 0)
        if drawn > 0:
            drawn_by_policy.setdefault(policy_index, set()).add(seed)
        if interventions > 0 and (drawn <= 0 or played <= 0):
            faults.append(f"{policy_index}-{seed}:intervention-without-consumer-reachability")

        if enabled.get("outcome") in ("stall", "error") \
                and enabled.get("outcome") != current.get("outcome"):
            additional_stall_or_error += 1
        if enabled.get("policy") != current.get("policy"):
            policy_mismatches += 1

    robust_active = sorted(
        policy for policy, active_seeds in active_by_policy.items()
        if active_seeds == set(seeds)
    )
    robust_drawn = sorted(
        policy for policy, drawn_seeds in drawn_by_policy.items()
        if drawn_seeds == set(seeds)
    )
    floor = protocol["supportFloor"]
    integrity_ok = (
        not faults
        and additional_stall_or_error == 0
        and policy_mismatches == 0
    )
    full_capacity = (
        integrity_ok
        and len(robust_active) >= floor["robustActivePolicies"]
        and enabled_active_rows >= floor["activeRows"]
        and enabled_payoffs >= floor["payoffEvents"]
        and intervention_rows >= floor["interventionRows"]
        and gained_active_rows >= floor["gainedActiveRows"]
        and lost_active_rows == 0
        and uncovered_intervention_events == 0
    )
    acquisition_ceiling = (
        guarded_drawn_rows < floor["activeRows"]
        or len(robust_drawn) < floor["robustActivePolicies"]
    )
    acquisition_only = (
        integrity_ok
        and not full_capacity
        and intervention_rows >= floor["minimumNaturalWitnessRows"]
        and gained_active_rows >= floor["minimumNaturalWitnessRows"]
        and enabled_payoffs > current_payoffs
        and lost_active_rows == 0
        and uncovered_intervention_events == 0
        and acquisition_ceiling
    )
    result = {
        "currentActiveRows": current_active_rows,
        "enabledActiveRows": enabled_active_rows,
        "currentPayoffEvents": current_payoffs,
        "enabledPayoffEvents": enabled_payoffs,
        "interventionRows": intervention_rows,
        "interventionEvents": intervention_events,
        "uncoveredInterventionEvents": uncovered_intervention_events,
        "gainedActiveRows": gained_active_rows,
        "lostActiveRows": lost_active_rows,
        "activePolicies": sorted(active_by_policy),
        "robustActivePolicies": robust_active,
        "robustActivePolicyCount": len(robust_active),
        "guardedStrikeOfferedRows": guarded_offered_rows,
        "guardedStrikeOffers": guarded_offers,
        "guardedStrikeDrawnRows": guarded_drawn_rows,
        "guardedStrikeDraws": guarded_draws,
        "guardedStrikePlayedRows": guarded_played_rows,
        "guardedStrikePlays": guarded_plays,
        "robustGuardedStrikeDrawnPolicies": robust_drawn,
        "robustGuardedStrikeDrawnPolicyCount": len(robust_drawn),
        "additionalStallOrErrorRows": additional_stall_or_error,
        "policyIdentityMismatchRows": policy_mismatches,
        "acquisitionCeilingObserved": acquisition_ceiling,
        "fullCapacityPassed": full_capacity,
        "acquisitionOnlyPassed": acquisition_only,
    }
    if additional_stall_or_error:
        faults.append("additional-stall-or-error")
    if policy_mismatches:
        faults.append("policy-identity")
    return result, sorted(set(faults))


def append_observations(
    protocol_sha: str,
    observed: list[dict[str, Any]],
    protocol: dict[str, Any],
) -> int:
    cohort = protocol["cohort"]
    per_arm = cohort["policyCount"] * len(cohort["simulationSeeds"])
    db = core.open_ledger()
    prefix = f"{protocol_sha}:afterimage-order-capacity:"
    existing = db.execute(
        "SELECT COUNT(*) FROM records WHERE identity LIKE ?", (prefix + "%",)
    ).fetchone()[0]
    require("capacity ledger identities already exist", existing == 0)
    created = datetime.now(timezone.utc).isoformat(timespec="seconds")
    try:
        db.execute("BEGIN IMMEDIATE")
        for index, row in enumerate(observed):
            arm_index = index // per_arm
            within = index % per_arm
            policy_index = within // len(cohort["simulationSeeds"])
            seed = cohort["simulationSeeds"][within % len(cohort["simulationSeeds"])]
            arm = ARMS[arm_index]
            payload = {
                "schemaVersion": 1,
                "issue": 421,
                "protocolSha256": protocol_sha,
                "stage": "afterimage-order-capacity",
                "arm": arm,
                "policyRoot": cohort["policyRoot"],
                "policyIndex": policy_index,
                "seed": seed,
                "row": row,
            }
            payload_json = core.canonical(payload)
            db.execute(
                "INSERT INTO records(kind, identity, payload_sha256, payload_json, created_utc) "
                "VALUES (?, ?, ?, ?, ?)",
                ("observation", f"{prefix}{arm}:{policy_index}:{seed}",
                 core.sha(payload_json.encode()), payload_json, created),
            )
        db.commit()
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()
    return len(observed)


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the Afterimage order capacity summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    immutable = protocol["immutableInputs"]
    require("runner SHA drift", core.file_sha(Path(__file__)) == immutable["runnerSha256"])
    require("identity protocol drift", core.file_sha(order.PROTOCOL) ==
            immutable["identityProtocolSha256"])
    require("identity summary drift", core.file_sha(order.SUMMARY) ==
            immutable["identitySummarySha256"])
    identity_summary = json.loads(order.SUMMARY.read_text())
    require("identity gate not passed", identity_summary.get("outcomeClass") == "success")
    require("task capsule drift", core.file_sha(core.ROOT / immutable["taskCapsulePath"]) ==
            immutable["taskCapsuleSha256"])

    repository = Path(immutable["repositoryPath"])
    for ref, expected in immutable["repositoryRefs"].items():
        actual = subprocess.run(
            ["git", "rev-parse", ref], cwd=repository, check=True,
            text=True, capture_output=True,
        ).stdout.strip()
        require(f"repository ref drift: {ref}", actual == expected)
    head = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=SOURCE, check=True,
        text=True, capture_output=True,
    ).stdout.strip()
    require("source commit drift", head == immutable["sourceCommit"])
    for name, expected in immutable["sourceSha256"].items():
        require(f"source {name} drift", core.file_sha(SOURCE / name) == expected)

    godot = immutable["godotBinaryPath"]
    require("Godot binary drift", core.file_sha(Path(godot)) == immutable["godotBinarySha256"])
    version = subprocess.run(
        [godot, "--version"], check=True, text=True, capture_output=True,
    ).stdout.strip()
    require("Godot version drift", version == immutable["godotVersion"])
    content_path = core.CACHE / f"{immutable['contentSha256']}.json"
    require("content drift", core.file_sha(content_path) == immutable["contentSha256"])
    ledger_before = ledger.ledger_identity()
    require("ledger freeze drift", ledger_before == protocol["ledgerFreeze"])

    planned = rows(protocol)
    require("row budget", len(planned) == protocol["budget"]["maximumSimulatorRows"])
    plan = {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "arm": "afterimage-order-capacity-fixed-plan",
        "content": str(content_path),
        "rows": planned,
    }
    started = time.monotonic()
    cap = protocol["budget"]["maximumWallTimeSeconds"]
    execution_error = ""
    output: dict[str, Any] = {}
    plan_sha = ""
    output_sha = ""
    try:
        output, plan_sha, output_sha = v1.run_probe(SOURCE, PROBE, plan, godot, cap)
    except (RuntimeError, subprocess.TimeoutExpired, OSError) as error:
        execution_error = str(error)
    observed = output.get("rows", [])
    result: dict[str, Any] = {}
    faults: list[str] = []
    ledger_error = ""
    appended = 0
    if not execution_error and len(observed) == len(planned):
        per_arm = len(observed) // len(ARMS)
        result, faults = metrics(
            observed[:per_arm], observed[per_arm:],
            protocol["cohort"]["simulationSeeds"], protocol,
        )
        try:
            appended = append_observations(protocol_sha, observed, protocol)
        except Exception as error:
            ledger_error = str(error)
    elif not execution_error:
        execution_error = f"incomplete output: {len(observed)} of {len(planned)} rows"

    ledger_after = ledger.ledger_identity()
    elapsed = time.monotonic() - started
    ledger_ok = (
        not ledger_error
        and appended == protocol["budget"]["maximumNewLedgerRows"]
        and ledger_after["records"] == ledger_before["records"] + appended
        and ledger_after["lastSequence"] == ledger_before["lastSequence"] + appended
        and ledger_after["protectedSeedRows"] == ledger_before["protectedSeedRows"]
        and ledger_after["sqliteIntegrity"] == "ok"
    )
    if not ledger_ok and not execution_error:
        faults.append("ledger-append-contract")

    if execution_error or ledger_error or elapsed > cap:
        outcome_class = "inconclusive"
        boundary = 3
        decision = "record-afterimage-order-capacity-inconclusive-at-cap"
    elif result.get("fullCapacityPassed") and ledger_ok:
        outcome_class = "success"
        boundary = 1
        decision = "admit-afterimage-order-to-smallest-crn-panel"
    elif result.get("acquisitionOnlyPassed") and ledger_ok:
        outcome_class = "acquisition-only"
        boundary = 2
        decision = "close-natural-afterimage-at-capacity-and-authorise-commitment-fallback"
    else:
        outcome_class = "futility"
        boundary = 2
        decision = "close-afterimage-order-at-capacity"

    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "protocolSha256": protocol_sha,
        "outcomeClass": outcome_class,
        "decisionBoundary": boundary,
        "decision": decision,
        "metrics": result,
        "faults": sorted(set(faults)),
        "elapsedSeconds": round(elapsed, 6),
        "observedRows": len(observed),
        "newLedgerRows": ledger_after["records"] - ledger_before["records"],
        "ledgerAppendError": ledger_error,
        "executionError": execution_error,
        "outputs": {
            "planSha256": plan_sha,
            "outputSha256": output_sha,
        },
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "claimBoundary": "Natural activation and bottleneck classification only; no causal endpoint, package, candidate, detector, product or P9 claim.",
    }
    SUMMARY.write_text(core.canonical(summary) + "\n")
    print(json.dumps({
        "status": outcome_class.upper(),
        "decision": decision,
        "rows": len(observed),
        "ledgerRows": summary["newLedgerRows"],
    }, sort_keys=True))


if __name__ == "__main__":
    main()
