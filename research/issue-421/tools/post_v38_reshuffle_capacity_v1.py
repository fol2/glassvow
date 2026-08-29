#!/usr/bin/env python3
"""Zero-row first-RESHUFFLE to immediate-next-PLAY capacity audit for #421."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_competing_structural_options as options
import post_v38_knob_identity as ledger
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-reshuffle-capacity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-reshuffle-capacity-v1.json"
SOURCE = core.ROOT / "reshuffle-observation-v1-source"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Reshuffle capacity mismatch: {label}")


def turn_opportunities(
    row: dict[str, Any], cards: dict[str, Any],
) -> tuple[list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]]]:
    trace = row["trajectory"]
    found: list[dict[str, Any]] = []
    exposures: list[dict[str, Any]] = []
    faults: list[dict[str, Any]] = []
    fight_ids = {
        int(event["fight"])
        for field in ("turns", "reshuffles", "plays")
        for event in trace[field]
    }
    for fight in sorted(fight_ids):
        if fight < 0 or fight >= len(row["fights"]):
            faults.append({"fight": fight, "fault": "fight-range"})
            continue
        turns = sorted(
            (event for event in trace["turns"] if int(event["fight"]) == fight),
            key=lambda event: int(event["event"]),
        )
        reshuffles = sorted(
            (event for event in trace["reshuffles"] if int(event["fight"]) == fight),
            key=lambda event: int(event["event"]),
        )
        plays = sorted(
            (event for event in trace["plays"] if int(event["fight"]) == fight),
            key=lambda event: int(event["event"]),
        )
        orders = [
            int(event["event"])
            for events in (turns, reshuffles, plays)
            for event in events
        ]
        if len(orders) != len(set(orders)):
            faults.append({"fight": fight, "fault": "event-order-collision"})
            continue
        allocated: set[int] = set()
        for index, turn in enumerate(turns):
            start = int(turn["event"])
            end = int(turns[index + 1]["event"]) if index + 1 < len(turns) else 1 << 60
            turn_reshuffles = [
                event for event in reshuffles if start < int(event["event"]) < end
            ]
            allocated.update(int(event["event"]) for event in turn_reshuffles)
            if not turn_reshuffles:
                continue
            producer = turn_reshuffles[0]
            producer_order = int(producer["event"])
            consumer = next(
                (event for event in plays if producer_order < int(event["event"]) < end),
                None,
            )
            exposure = {
                "fight": fight,
                "turnEvent": start,
                "turnNumber": int(turn["n"]),
                "producerEvent": producer_order,
                "reshuffleCount": int(producer["n"]),
                "turnReshuffles": len(turn_reshuffles),
                "nonStackingAliases": len(turn_reshuffles) - 1,
            }
            exposures.append(exposure)
            if consumer is None:
                continue
            card_id = str(consumer["id"])
            if card_id not in cards:
                faults.append({
                    "fight": fight, "event": int(consumer["event"]),
                    "fault": "unknown-consumer", "id": card_id,
                })
                continue
            found.append({
                **exposure,
                "consumerEvent": int(consumer["event"]),
                "consumerCard": card_id,
                "consumerType": str(cards[card_id].get("type", "")),
                "consumerTarget": str(cards[card_id].get("target", "")),
            })
        missing = {int(event["event"]) for event in reshuffles} - allocated
        for order in sorted(missing):
            faults.append({"fight": fight, "event": order, "fault": "outside-turn"})
    return found, exposures, faults


def robust_keys(keys: set[tuple[int, int]], protocol: dict[str, Any]) -> set[int]:
    cohort = protocol["cohort"]
    return {
        policy for policy in range(cohort["policyCount"])
        if sum((policy, seed) in keys for seed in cohort["simulationSeeds"])
        >= cohort["minimumRowsPerRobustPolicy"]
    }


def exact_inactive_keys(
    keys: set[tuple[int, int]], protocol: dict[str, Any],
) -> set[int]:
    cohort = protocol["cohort"]
    return {
        policy for policy in range(cohort["policyCount"])
        if not any((policy, seed) in keys for seed in cohort["simulationSeeds"])
    }


def self_check() -> None:
    cards = {"a": {"type": "attack", "target": "enemy"}}
    row = {
        "fights": [{"enemies": ["x"]}],
        "trajectory": {
            "turns": [
                {"fight": 0, "event": 1, "n": 1},
                {"fight": 0, "event": 20, "n": 2},
            ],
            "reshuffles": [
                {"fight": 0, "event": 3, "n": 5},
                {"fight": 0, "event": 4, "n": 2},
                {"fight": 0, "event": 22, "n": 4},
            ],
            "plays": [{"fight": 0, "event": 5, "id": "a", "uid": 1}],
        },
    }
    found, exposures, faults = turn_opportunities(row, cards)
    require("self-check faults", not faults)
    require("self-check exposures", len(exposures) == 2)
    require("self-check qualifying", len(found) == 1)
    require("self-check aliases", found[0]["nonStackingAliases"] == 1)


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the reshuffle capacity summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    immutable = protocol["immutableInputs"]
    require("runner SHA", core.file_sha(Path(__file__)) == immutable["runnerSha256"])
    self_check()
    require(
        "task capsule SHA",
        core.file_sha(core.ROOT / immutable["taskCapsulePath"])
        == immutable["taskCapsuleSha256"],
    )
    for path, expected in immutable["researchFileSha256"].items():
        require(f"research file {path}", core.file_sha(core.ROOT / path) == expected)

    repository = Path(immutable["repositoryPath"])
    for ref, expected in immutable["repositoryRefs"].items():
        actual = subprocess.run(
            ["git", "rev-parse", ref], cwd=repository, check=True,
            text=True, capture_output=True,
        ).stdout.strip()
        require(f"repository ref {ref}", actual == expected)
    for path, expected in immutable["sourceSha256"].items():
        blob = subprocess.run(
            ["git", "show", f"{immutable['sourceHead']}:{path}"], cwd=repository,
            check=True, capture_output=True,
        ).stdout
        require(f"source {path}", core.sha(blob) == expected)
    source_head = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=SOURCE, check=True,
        text=True, capture_output=True,
    ).stdout.strip()
    require("observation source head", source_head == immutable["observationSourceHead"])
    for path, expected in immutable["observationSourceSha256"].items():
        require(f"observation source {path}", core.file_sha(SOURCE / path) == expected)
    patch = subprocess.run(
        ["git", "diff", "--cached", "--binary"], cwd=SOURCE,
        check=True, capture_output=True,
    ).stdout
    require("observation patch SHA", core.sha(patch) == immutable["sourcePatchSha256"])

    ledger_before = ledger.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    trace = protocol["trace"]
    plan_path = core.CACHE / f"{trace['planSha256']}.json"
    output_path = core.CACHE / f"{trace['outputSha256']}.json"
    content_path = core.CACHE / f"{trace['contentSha256']}.json"
    require("plan SHA", core.file_sha(plan_path) == trace["planSha256"])
    require("output SHA", core.file_sha(output_path) == trace["outputSha256"])
    require("content SHA", core.file_sha(content_path) == trace["contentSha256"])
    plan = json.loads(plan_path.read_text())
    output = json.loads(output_path.read_text())
    content = json.loads(content_path.read_text())
    require("plan arm", plan["arm"] == "reshuffle-trace-explicit-null")
    require("plan protocol identity", plan["protocolSha256"] == trace["identityProtocolSha256"])
    require("output plan identity", output["planSha256"] == trace["planSha256"])
    cohort = protocol["cohort"]
    require("plan rows", len(plan["rows"]) == cohort["rows"])
    require("output rows", len(output["rows"]) == cohort["rows"])
    require(
        "cached-row ceiling",
        len(output["rows"]) <= protocol["budget"]["maximumCachedObservationRowsRead"],
    )

    rows: dict[tuple[int, int], dict[str, Any]] = {}
    snapshots: dict[int, set[str]] = {}
    for spec, row in zip(plan["rows"], output["rows"]):
        require("row arm", spec.get("arm") == "cohand-telemetry-explicit-null")
        require("trace capture", spec.get("captureTrace") is True)
        require("explicit null", spec.get("explicitNull") is True)
        key = (int(spec["policyIndex"]), int(spec["seed"]))
        require(f"unique row {key}", key not in rows)
        require(f"seed identity {key}", int(row["seed"]) == key[1])
        rows[key] = row
        snapshots.setdefault(key[0], set()).add(core.canonical(row["policy"]))
    require("complete rectangle", len(rows) == cohort["rows"])
    require(
        "policy identity",
        len(snapshots) == cohort["policyCount"]
        and all(len(values) == 1 for values in snapshots.values()),
    )

    row_events: dict[tuple[int, int], list[dict[str, Any]]] = {}
    row_exposures: dict[tuple[int, int], list[dict[str, Any]]] = {}
    semantic_faults: list[dict[str, Any]] = []
    for key, row in rows.items():
        events, exposures, faults = turn_opportunities(row, content["cards"])
        row_events[key] = events
        row_exposures[key] = exposures
        semantic_faults.extend(
            {"policyIndex": key[0], "seed": key[1], **fault} for fault in faults
        )

    qualifying = {key for key, events in row_events.items() if events}
    exposed = {key for key, events in row_exposures.items() if events}
    active = robust_keys(qualifying, protocol)
    exposure_active = robust_keys(exposed, protocol)
    inactive = exact_inactive_keys(qualifying, protocol)
    ambiguous = set(range(cohort["policyCount"])) - active - inactive
    exposure_only = exposure_active - active
    viable = {
        policy for policy in active
        if any(
            (policy, seed) in qualifying and rows[(policy, seed)].get("outcome") == "win"
            for seed in cohort["simulationSeeds"]
        )
    }
    all_events = [event for events in row_events.values() for event in events]
    all_exposures = [event for events in row_exposures.values() for event in events]
    cards = content["cards"]
    consumer_ids = {event["consumerCard"] for event in all_events}
    source_breadth = {
        "distinctConsumers": len(consumer_ids),
        "distinctConsumerTypes": len({str(cards[card].get("type", "")) for card in consumer_ids}),
        "distinctConsumerTargets": len({str(cards[card].get("target", "")) for card in consumer_ids}),
        "distinctPositiveCounts": len({event["reshuffleCount"] for event in all_exposures}),
        "nonStackingAliasEvents": sum(event["nonStackingAliases"] for event in all_exposures),
    }
    anchor_sets: dict[str, set[int]] = {
        "scoreline": set(protocol["anchors"]["scoreline"]["policies"]),
        "afterimage": set(protocol["anchors"]["afterimage"]["policies"]),
    }
    for name in ("drawThread", "duplicateCopy"):
        anchor = protocol["anchors"][name]
        summary = json.loads((core.ROOT / anchor["summaryPath"]).read_text())
        require(f"{name} outcome", summary["outcomeClass"] == "futility")
        anchor_sets[name] = set(summary["policySets"]["active"])
        require(f"{name} active set", sorted(anchor_sets[name]) == anchor["policies"])
    separation = {
        name: options.separation(active, anchor)
        for name, anchor in anchor_sets.items()
    }
    gates = protocol["gates"]
    separation_checks = {
        name: (
            result["candidateOnlyPolicies"] >= gates["minimumCandidateOnlyPolicies"]
            and result["anchorOnlyPolicies"] >= gates["minimumAnchorOnlyPolicies"]
            and result["jaccard"] <= gates["maximumAnchorJaccard"]
        )
        for name, result in separation.items()
    }
    baseline_faults = sum(
        row.get("outcome") in ("stall", "error") or bool(row.get("error"))
        for row in rows.values()
    )
    counts = {
        "qualifyingRows": len(qualifying),
        "qualifyingTurns": len(all_events),
        "exposedRows": len(exposed),
        "exposureTurns": len(all_exposures),
        "activePolicies": len(active),
        "exactInactivePolicies": len(inactive),
        "ambiguousPolicies": len(ambiguous),
        "exposureActivePolicies": len(exposure_active),
        "exposureOnlyPolicies": len(exposure_only),
        "viablePolicies": len(viable),
    }
    checks = {
        "activeSupport": counts["activePolicies"] >= gates["minimumActivePolicies"],
        "inactiveSupport": counts["exactInactivePolicies"] >= gates["minimumExactInactivePolicies"],
        "viableSupport": counts["viablePolicies"] >= gates["minimumViablePolicies"],
        "exposureSupport": counts["exposureActivePolicies"] >= gates["minimumExposureActivePolicies"],
        "exposureOnlySupport": counts["exposureOnlyPolicies"] >= gates["minimumExposureOnlyPolicies"],
        "consumerBreadth": source_breadth["distinctConsumers"] >= gates["minimumDistinctConsumers"],
        "consumerTypeBreadth": source_breadth["distinctConsumerTypes"] >= gates["minimumDistinctConsumerTypes"],
        "consumerTargetBreadth": source_breadth["distinctConsumerTargets"] >= gates["minimumDistinctConsumerTargets"],
        "semanticValidity": len(semantic_faults) <= gates["maximumSemanticFaults"],
        "reliability": baseline_faults <= gates["maximumBaselineFaultRows"],
        **{f"{name}Separation": passed for name, passed in separation_checks.items()},
    }
    elapsed = time.monotonic() - started
    if elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        outcome_class, boundary = "inconclusive", 3
        decision = "record-reshuffle-capacity-inconclusive-at-cap"
    elif all(checks.values()):
        outcome_class, boundary = "success", 1
        decision = "freeze-reshuffle-echo-for-direct-identity"
    else:
        outcome_class, boundary = "futility", 2
        decision = "close-reshuffle-echo-at-zero-row-capacity"
    ledger_after = ledger.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "outcomeClass": outcome_class,
        "decisionBoundary": boundary,
        "decision": decision,
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "counts": counts,
        "policySets": {
            "active": sorted(active),
            "exactInactive": sorted(inactive),
            "ambiguous": sorted(ambiguous),
            "exposureActive": sorted(exposure_active),
            "exposureOnly": sorted(exposure_only),
            "viable": sorted(viable),
        },
        "sourceBreadth": source_breadth,
        "separation": separation,
        "checks": checks,
        "semanticFaults": semantic_faults,
        "baselineFaultRows": baseline_faults,
        "cachedObservationRowsRead": len(output["rows"]),
        "newSimulatorObservationRows": 0,
        "newLedgerRows": 0,
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "maximumModelContextTokens": 0,
        "wallTimeSeconds": round(elapsed, 6),
        "claimBoundary": protocol["claimBoundary"],
        "authority": protocol["decisionRules"][f"{outcome_class}Authority"],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": outcome_class.upper(),
        "decision": decision,
        "activePolicies": counts["activePolicies"],
        "exactInactivePolicies": counts["exactInactivePolicies"],
        "viablePolicies": counts["viablePolicies"],
        "newSimulatorObservationRows": 0,
    }))


if __name__ == "__main__":
    main()
