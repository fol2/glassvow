#!/usr/bin/env python3
"""Zero-row immediate post-kill consumer topology census for issue #421."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any, Callable

import post_v38_competing_structural_options as options
import post_v38_knob_identity as ledger
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-kill-consumer-topology-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-kill-consumer-topology-v1.json"
SOURCE = core.ROOT / "target-switch-observation-v1-source"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Kill-consumer topology mismatch: {label}")


def consumer_class(card: dict[str, Any]) -> str:
    card_type = str(card.get("type", ""))
    target = str(card.get("target", ""))
    if card_type == "attack" and target == "enemy":
        return "attack-enemy"
    if card_type == "attack" and target == "allEnemies":
        return "attack-allEnemies"
    if card_type == "skill":
        return "skill"
    if card_type == "power":
        return "power"
    return "unclassified"


def topology_events(
    row: dict[str, Any], cards: dict[str, Any],
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    """Classify the immediate next PLAY after the first attributable kill per turn."""
    trace = row["trajectory"]
    fights = row["fights"]
    found: list[dict[str, Any]] = []
    faults: list[dict[str, Any]] = []
    fight_ids = {
        int(event["fight"])
        for field in ("turns", "plays", "dies")
        for event in trace[field]
    }
    for fight in sorted(fight_ids):
        require(f"fight index {fight}", 0 <= fight < len(fights))
        if len(fights[fight]["enemies"]) < 2:
            continue
        events: list[tuple[int, int, dict[str, Any]]] = []
        events.extend(
            (int(event["event"]), 0, event)
            for event in trace["turns"] if int(event["fight"]) == fight
        )
        events.extend(
            (int(event["event"]), 1, event)
            for event in trace["plays"] if int(event["fight"]) == fight
        )
        events.extend(
            (int(event["event"]), 2, event)
            for event in trace["dies"] if int(event["fight"]) == fight
        )
        orders = [order for order, _, _ in events]
        require(f"unique event order in fight {fight}", len(orders) == len(set(orders)))
        turns: list[dict[str, Any]] = []
        current: dict[str, Any] | None = None
        for order, kind, event in sorted(events, key=lambda item: (item[0], item[1])):
            if kind == 0:
                current = {"turnEvent": order, "plays": [], "dies": []}
                turns.append(current)
            elif current is not None:
                current["plays" if kind == 1 else "dies"].append(event)
        for turn in turns:
            plays = sorted(turn["plays"], key=lambda event: int(event["event"]))
            dies = sorted(turn["dies"], key=lambda event: int(event["event"]))
            producer = next((
                play for play in plays
                if str(play["id"]) in cards
                and cards[str(play["id"])].get("type") == "attack"
                and cards[str(play["id"])].get("target") == "enemy"
            ), None)
            if producer is None:
                continue
            producer_order = int(producer["event"])
            producer_target = producer.get("targetIdx")
            require(
                f"producer target in fight {fight}",
                isinstance(producer_target, int) and not isinstance(producer_target, bool)
                and 0 <= producer_target < len(fights[fight]["enemies"]),
            )
            next_play = next(
                (play for play in plays if int(play["event"]) > producer_order), None,
            )
            resolution_end = (
                int(next_play["event"]) if next_play is not None else 1 << 60
            )
            target_deaths = [
                int(event["event"]) for event in dies
                if int(event["idx"]) == producer_target
                and producer_order < int(event["event"]) < resolution_end
            ]
            if not target_deaths:
                continue
            if next_play is None:
                found.append({
                    "fight": fight,
                    "turnEvent": int(turn["turnEvent"]),
                    "producerEvent": producer_order,
                    "deathEvent": target_deaths[0],
                    "producerCard": str(producer["id"]),
                    "producerTargetIdx": producer_target,
                    "consumerClass": "no-next-play",
                    "consumerEvent": None,
                    "consumerCard": None,
                })
                continue
            consumer_id = str(next_play["id"])
            if consumer_id not in cards:
                faults.append({
                    "fight": fight, "event": int(next_play["event"]),
                    "fault": "unknown-consumer-card", "id": consumer_id,
                })
                continue
            classification = consumer_class(cards[consumer_id])
            if classification == "unclassified":
                faults.append({
                    "fight": fight, "event": int(next_play["event"]),
                    "fault": "unclassified-consumer", "id": consumer_id,
                })
            if classification == "attack-enemy":
                target = next_play.get("targetIdx")
                if (not isinstance(target, int) or isinstance(target, bool)
                        or target < 0 or target >= len(fights[fight]["enemies"])):
                    faults.append({
                        "fight": fight, "event": int(next_play["event"]),
                        "fault": "invalid-consumer-target", "id": consumer_id,
                    })
                elif any(
                    int(event["idx"]) == target
                    and int(event["event"]) < int(next_play["event"])
                    for event in dies
                ):
                    faults.append({
                        "fight": fight, "event": int(next_play["event"]),
                        "fault": "dead-consumer-target", "id": consumer_id,
                    })
            found.append({
                "fight": fight,
                "turnEvent": int(turn["turnEvent"]),
                "producerEvent": producer_order,
                "deathEvent": target_deaths[0],
                "producerCard": str(producer["id"]),
                "producerTargetIdx": producer_target,
                "consumerClass": classification,
                "consumerEvent": int(next_play["event"]),
                "consumerCard": consumer_id,
            })
    return found, faults


def robust_keys(
    qualifying: set[tuple[int, int]], protocol: dict[str, Any],
) -> set[int]:
    cohort = protocol["cohort"]
    return {
        policy for policy in range(cohort["policyCount"])
        if sum((policy, seed) in qualifying for seed in cohort["simulationSeeds"])
        >= cohort["minimumRowsPerRobustPolicy"]
    }


def exact_inactive_keys(
    qualifying: set[tuple[int, int]], protocol: dict[str, Any],
) -> set[int]:
    cohort = protocol["cohort"]
    return {
        policy for policy in range(cohort["policyCount"])
        if not any((policy, seed) in qualifying for seed in cohort["simulationSeeds"])
    }


def robust_set(
    rows: dict[tuple[int, int], dict[str, Any]],
    protocol: dict[str, Any],
    predicate: Callable[[dict[str, Any]], bool],
) -> set[int]:
    return options.robust_set(rows, protocol, predicate)


def self_check() -> None:
    cards = {
        "a": {"type": "attack", "target": "enemy"},
        "sweep": {"type": "attack", "target": "allEnemies"},
        "skill": {"type": "skill", "target": "self"},
        "power": {"type": "power", "target": "self"},
    }
    row = {
        "fights": [{"enemies": ["x", "y"]}],
        "trajectory": {
            "turns": [
                {"fight": 0, "event": 1},
                {"fight": 0, "event": 10},
                {"fight": 0, "event": 20},
                {"fight": 0, "event": 30},
            ],
            "plays": [
                {"fight": 0, "event": 2, "id": "a", "targetIdx": 0},
                {"fight": 0, "event": 4, "id": "sweep", "targetIdx": None},
                {"fight": 0, "event": 11, "id": "a", "targetIdx": 0},
                {"fight": 0, "event": 13, "id": "skill", "targetIdx": None},
                {"fight": 0, "event": 21, "id": "a", "targetIdx": 0},
                {"fight": 0, "event": 23, "id": "power", "targetIdx": None},
                {"fight": 0, "event": 31, "id": "a", "targetIdx": 0},
                {"fight": 0, "event": 33, "id": "a", "targetIdx": 1},
            ],
            "dies": [
                {"fight": 0, "event": 3, "idx": 0},
                {"fight": 0, "event": 12, "idx": 0},
                {"fight": 0, "event": 22, "idx": 0},
                {"fight": 0, "event": 32, "idx": 0},
            ],
        },
    }
    events, faults = topology_events(row, cards)
    require("topology self-check faults", not faults)
    require(
        "topology classes",
        [event["consumerClass"] for event in events]
        == ["attack-allEnemies", "skill", "power", "attack-enemy"],
    )


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the kill-consumer topology summary")
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

    observation_head = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=SOURCE, check=True,
        text=True, capture_output=True,
    ).stdout.strip()
    require("observation source head", observation_head == immutable["observationSourceHead"])
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
    require("output plan identity", output["planSha256"] == trace["planSha256"])
    require("plan arm", plan["arm"] == "target-death-trace-explicit-null")
    require("plan protocol identity", plan["protocolSha256"] == trace["identityProtocolSha256"])
    cohort = protocol["cohort"]
    require("plan rows", len(plan["rows"]) == cohort["rows"])
    require("output rows", len(output["rows"]) == cohort["rows"])
    require(
        "cached-row ceiling",
        len(output["rows"]) <= protocol["budget"]["maximumCachedObservationRowsRead"],
    )

    rows: dict[tuple[int, int], dict[str, Any]] = {}
    policy_snapshots: dict[int, set[str]] = {}
    for spec, row in zip(plan["rows"], output["rows"]):
        require("trace arm", spec.get("arm") == "cohand-telemetry-explicit-null")
        require("trace capture", spec.get("captureTrace") is True)
        require("trace explicit null", spec.get("explicitNull") is True)
        key = (int(spec["policyIndex"]), int(spec["seed"]))
        require(f"unique row {key}", key not in rows)
        require(f"seed {key}", int(row["seed"]) == key[1])
        rows[key] = row
        policy_snapshots.setdefault(key[0], set()).add(core.canonical(row["policy"]))
    require("complete rectangle", len(rows) == cohort["rows"])
    require(
        "one policy snapshot per identity",
        len(policy_snapshots) == cohort["policyCount"]
        and all(len(snapshots) == 1 for snapshots in policy_snapshots.values()),
    )

    cards = content["cards"]
    source_classes = {
        "attack-allEnemies": sorted(
            card_id for card_id, card in cards.items()
            if card.get("type") == "attack" and card.get("target") == "allEnemies"
        ),
        "skill": sorted(
            card_id for card_id, card in cards.items() if card.get("type") == "skill"
        ),
        "power": sorted(
            card_id for card_id, card in cards.items() if card.get("type") == "power"
        ),
    }
    require("source consumer classes", source_classes == protocol["sourceConsumerClasses"])
    row_events: dict[tuple[int, int], list[dict[str, Any]]] = {}
    semantic_faults: list[dict[str, Any]] = []
    for key, row in rows.items():
        events, faults = topology_events(row, cards)
        row_events[key] = events
        semantic_faults.extend({"policyIndex": key[0], "seed": key[1], **fault}
                               for fault in faults)
    require(
        "mutually exclusive event classes",
        all(event["consumerClass"] in protocol["completeConsumerPartition"]
            for events in row_events.values() for event in events),
    )

    scoreline = robust_set(
        rows, protocol,
        lambda row: bool(options.ordered_pairs(row, {"chisel"}, {"executioner"})),
    )
    afterimage = robust_set(
        rows, protocol,
        lambda row: options.cohand.simultaneous_cohand(row, "defend", "guardedStrike"),
    )
    require("Scoreline anchor", scoreline == set(protocol["anchors"]["scoreline"]["policies"]))
    require("Afterimage anchor", afterimage == set(protocol["anchors"]["afterimage"]["policies"]))
    reaper = set(protocol["anchors"]["reaperBell"]["policies"])
    target_transfer = set(protocol["anchors"]["targetTransfer"]["policies"])
    closed_kill_relay = set(protocol["anchors"]["closedKillRelay"]["policies"])

    fault_rows = sum(
        row.get("outcome") in ("stall", "error") or bool(row.get("error"))
        for row in rows.values()
    )
    gates = protocol["gates"]
    assessments: list[dict[str, Any]] = []
    for candidate in protocol["candidateClasses"]:
        candidate_id = str(candidate["id"])
        qualifying = {
            key for key, events in row_events.items()
            if any(event["consumerClass"] == candidate_id for event in events)
        }
        active = robust_keys(qualifying, protocol)
        inactive = exact_inactive_keys(qualifying, protocol)
        ambiguous = set(range(cohort["policyCount"])) - active - inactive
        viable = {
            policy for policy in active
            if any((policy, seed) in qualifying
                   and rows[(policy, seed)].get("outcome") == "win"
                   for seed in cohort["simulationSeeds"])
        }
        events = [
            event for rows_events in row_events.values() for event in rows_events
            if event["consumerClass"] == candidate_id
        ]
        producers = {str(event["producerCard"]) for event in events}
        consumers = {str(event["consumerCard"]) for event in events}
        pairs = {(str(event["producerCard"]), str(event["consumerCard"]))
                 for event in events}
        separations = {
            "scoreline": options.separation(active, scoreline),
            "afterimage": options.separation(active, afterimage),
            "reaperBell": options.separation(active, reaper),
            "targetTransfer": options.separation(active, target_transfer),
            "closedKillRelay": options.separation(active, closed_kill_relay),
        }

        def two_sided(result: dict[str, Any]) -> bool:
            return (
                result["candidateOnlyPolicies"] >= gates["minimumCandidateOnlyPolicies"]
                and result["anchorOnlyPolicies"] >= gates["minimumAnchorOnlyPolicies"]
                and result["jaccard"] <= gates["maximumAnchorJaccard"]
            )

        def one_sided(result: dict[str, Any]) -> bool:
            return (
                result["candidateOnlyPolicies"] >= gates["minimumCandidateOnlyPolicies"]
                and result["jaccard"] <= gates["maximumClosedFamilyJaccard"]
            )

        checks = {
            "activeSupport": len(active) >= gates["minimumActivePolicies"],
            "inactiveSupport": len(inactive) >= gates["minimumExactInactivePolicies"],
            "viableSupport": len(viable) >= gates["minimumViablePolicies"],
            "producerBreadth": len(producers) >= gates["minimumDistinctProducers"],
            "consumerBreadth": len(consumers) >= candidate["minimumDistinctConsumers"],
            "pairBreadth": len(pairs) >= gates["minimumDistinctPairs"],
            "scorelineSeparation": two_sided(separations["scoreline"]),
            "afterimageSeparation": two_sided(separations["afterimage"]),
            "reaperBellSeparation": one_sided(separations["reaperBell"]),
            "targetTransferSeparation": one_sided(separations["targetTransfer"]),
            "closedKillRelaySeparation": one_sided(separations["closedKillRelay"]),
            "semanticValidity": not semantic_faults,
            "reliability": fault_rows <= gates["maximumBaselineFaultRows"],
        }
        max_jaccard = max(value["jaccard"] for value in separations.values())
        margin = min(
            len(active) - gates["minimumActivePolicies"],
            len(inactive) - gates["minimumExactInactivePolicies"],
        )
        assessments.append({
            "id": candidate_id,
            "eligible": all(checks.values()),
            "checks": checks,
            "counts": {
                "activePolicies": len(active),
                "exactInactivePolicies": len(inactive),
                "ambiguousPolicies": len(ambiguous),
                "viablePolicies": len(viable),
                "qualifyingRows": len(qualifying),
                "qualifyingTurns": len(events),
                "distinctProducers": len(producers),
                "distinctConsumers": len(consumers),
                "distinctPairs": len(pairs),
            },
            "sourceBreadth": {
                "producerCards": sorted(producers),
                "consumerCards": sorted(consumers),
                "pairs": sorted([list(pair) for pair in pairs]),
            },
            "separation": separations,
            "selectionMetrics": {
                "viablePolicies": len(viable),
                "supportMargin": margin,
                "distinctPairs": len(pairs),
                "maximumAnchorJaccard": max_jaccard,
            },
            "policySets": {
                "active": sorted(active),
                "exactInactive": sorted(inactive),
                "ambiguous": sorted(ambiguous),
                "viable": sorted(viable),
            },
        })

    closed_control = {
        key for key, events in row_events.items()
        if any(event["consumerClass"] == "attack-enemy" for event in events)
    }
    control_active = robust_keys(closed_control, protocol)
    require(
        "closed attack-enemy control rows",
        len(closed_control) == protocol["closedControl"]["qualifyingRows"],
    )
    require(
        "closed attack-enemy control policies",
        control_active == set(protocol["closedControl"]["activePolicies"]),
    )
    eligible = [assessment for assessment in assessments if assessment["eligible"]]
    eligible.sort(key=lambda assessment: (
        -assessment["selectionMetrics"]["viablePolicies"],
        -assessment["selectionMetrics"]["supportMargin"],
        -assessment["selectionMetrics"]["distinctPairs"],
        assessment["selectionMetrics"]["maximumAnchorJaccard"],
        assessment["id"],
    ))
    selected = eligible[0]["id"] if eligible else None
    elapsed = time.monotonic() - started
    if elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        outcome_class = "inconclusive"
        boundary = 3
        decision = "record-kill-consumer-topology-inconclusive-at-cap"
        selected = None
    elif selected is not None:
        outcome_class = "success"
        boundary = 1
        decision = f"freeze-{selected}-kill-consumer-for-contract"
    else:
        outcome_class = "futility"
        boundary = 2
        decision = "close-immediate-post-kill-consumer-topology"
    ledger_after = ledger.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)

    event_counts = {
        class_id: sum(event["consumerClass"] == class_id
                      for events in row_events.values() for event in events)
        for class_id in protocol["completeConsumerPartition"]
    }
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "outcomeClass": outcome_class,
        "decisionBoundary": boundary,
        "decision": decision,
        "selectedClass": selected,
        "eligibleClasses": [assessment["id"] for assessment in eligible],
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "assessments": assessments,
        "closedControl": {
            "id": "attack-enemy",
            "qualifyingRows": len(closed_control),
            "activePolicies": len(control_active),
            "policySet": sorted(control_active),
        },
        "partitionEventCounts": event_counts,
        "sourceConsumerClasses": source_classes,
        "semanticFaults": semantic_faults,
        "baselineFaultRows": fault_rows,
        "cachedObservationRowsRead": len(rows),
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
        "selectedClass": selected,
        "eligibleClasses": [assessment["id"] for assessment in eligible],
        "newSimulatorObservationRows": 0,
    }))


if __name__ == "__main__":
    main()
