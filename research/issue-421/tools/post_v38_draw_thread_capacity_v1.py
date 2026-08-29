#!/usr/bin/env python3
"""Zero-row exact-card-instance draw-thread capacity audit for issue #421."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any, Callable

import post_v38_competing_structural_options as options
import post_v38_knob_identity as ledger
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-draw-thread-capacity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-draw-thread-capacity-v1.json"
SOURCE = core.ROOT / "target-switch-observation-v1-source"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Draw-thread capacity mismatch: {label}")


def reward_draw_cards(content: dict[str, Any]) -> list[str]:
    reward_ids = {
        str(card_id)
        for pool in content["cardPools"].values()
        for card_id in pool
    }
    reward_ids.update(
        str(unlock).removeprefix("card:")
        for deed in content["deeds"].values()
        for unlock in deed.get("unlocks", [])
        if str(unlock).startswith("card:")
    )

    def draws_immediately(card: dict[str, Any]) -> bool:
        return any(
            (effect.get("kind") == "draw" and int(effect.get("n", 0)) > 0)
            or (effect.get("kind") == "special" and int(effect.get("draw", 0)) > 0)
            for effect in card.get("effects", [])
        )

    return sorted(
        card_id for card_id in reward_ids
        if card_id in content["cards"] and draws_immediately(content["cards"][card_id])
    )


def draw_thread_events(
    row: dict[str, Any], cards: dict[str, Any], producer_ids: set[str],
) -> tuple[list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]]]:
    """Return qualifying exact-uid sequences, all producer resolutions and faults."""
    trace = row["trajectory"]
    qualifying: list[dict[str, Any]] = []
    exposures: list[dict[str, Any]] = []
    faults: list[dict[str, Any]] = []
    fight_ids = {
        int(event["fight"])
        for field in ("turns", "plays", "draws")
        for event in trace[field]
    }
    for fight in sorted(fight_ids):
        events: list[tuple[int, int, dict[str, Any]]] = []
        events.extend(
            (int(event["event"]), 0, event)
            for event in trace["turns"] if int(event["fight"]) == fight
        )
        events.extend(
            (int(event["event"]), 1, event)
            for event in trace["draws"] if int(event["fight"]) == fight
        )
        events.extend(
            (int(event["event"]), 2, event)
            for event in trace["plays"] if int(event["fight"]) == fight
        )
        orders = [order for order, _, _ in events]
        require(f"unique event order in fight {fight}", len(orders) == len(set(orders)))
        turns: list[dict[str, Any]] = []
        current: dict[str, Any] | None = None
        for order, kind, event in sorted(events, key=lambda item: (item[0], item[1])):
            if kind == 0:
                current = {"turnEvent": order, "draws": [], "plays": []}
                turns.append(current)
            elif current is not None:
                current["draws" if kind == 1 else "plays"].append(event)

        for turn in turns:
            plays = sorted(turn["plays"], key=lambda event: int(event["event"]))
            draws = sorted(turn["draws"], key=lambda event: int(event["event"]))
            paid = False
            for producer in plays:
                producer_id = str(producer["id"])
                if paid or producer_id not in producer_ids:
                    continue
                producer_order = int(producer["event"])
                next_play = next(
                    (play for play in plays if int(play["event"]) > producer_order), None,
                )
                resolution_end = int(next_play["event"]) if next_play is not None else 1 << 60
                produced_draws = [
                    draw for draw in draws
                    if producer_order < int(draw["event"]) < resolution_end
                ]
                if not produced_draws:
                    continue
                draw_uids = [int(draw["uid"]) for draw in produced_draws]
                if len(draw_uids) != len(set(draw_uids)):
                    faults.append({
                        "fight": fight,
                        "turnEvent": int(turn["turnEvent"]),
                        "producerEvent": producer_order,
                        "fault": "duplicate-draw-uid-in-resolution",
                    })
                    continue
                for draw in produced_draws:
                    if str(draw["id"]) not in cards:
                        faults.append({
                            "fight": fight,
                            "event": int(draw["event"]),
                            "fault": "unknown-drawn-card",
                            "id": str(draw["id"]),
                        })
                exposure = {
                    "fight": fight,
                    "turnEvent": int(turn["turnEvent"]),
                    "producerEvent": producer_order,
                    "producerCard": producer_id,
                    "producerUid": int(producer["uid"]),
                    "drawEvents": [int(draw["event"]) for draw in produced_draws],
                    "drawCards": [str(draw["id"]) for draw in produced_draws],
                    "drawUids": draw_uids,
                    "consumerEvent": int(next_play["event"]) if next_play is not None else None,
                    "consumerCard": str(next_play["id"]) if next_play is not None else None,
                    "consumerUid": int(next_play["uid"]) if next_play is not None else None,
                }
                exposures.append(exposure)
                if next_play is None or int(next_play["uid"]) not in set(draw_uids):
                    continue
                matching_draw = next(
                    draw for draw in produced_draws
                    if int(draw["uid"]) == int(next_play["uid"])
                )
                if str(matching_draw["id"]) != str(next_play["id"]):
                    faults.append({
                        "fight": fight,
                        "event": int(next_play["event"]),
                        "fault": "draw-play-card-id-mismatch",
                        "drawCard": str(matching_draw["id"]),
                        "playCard": str(next_play["id"]),
                    })
                    continue
                if int(producer["uid"]) == int(next_play["uid"]):
                    faults.append({
                        "fight": fight,
                        "event": int(next_play["event"]),
                        "fault": "producer-consumer-uid-alias",
                    })
                    continue
                qualifying.append(exposure)
                paid = True
    return qualifying, exposures, faults


def robust_keys(keys: set[tuple[int, int]], protocol: dict[str, Any]) -> set[int]:
    cohort = protocol["cohort"]
    return {
        policy for policy in range(cohort["policyCount"])
        if sum((policy, seed) in keys for seed in cohort["simulationSeeds"])
        >= cohort["minimumRowsPerRobustPolicy"]
    }


def exact_inactive_keys(keys: set[tuple[int, int]], protocol: dict[str, Any]) -> set[int]:
    cohort = protocol["cohort"]
    return {
        policy for policy in range(cohort["policyCount"])
        if not any((policy, seed) in keys for seed in cohort["simulationSeeds"])
    }


def robust_set(
    rows: dict[tuple[int, int], dict[str, Any]],
    protocol: dict[str, Any],
    predicate: Callable[[dict[str, Any]], bool],
) -> set[int]:
    return options.robust_set(rows, protocol, predicate)


def self_check() -> None:
    cards = {
        "thread": {"type": "skill"},
        "new": {"type": "attack"},
        "old": {"type": "skill"},
    }
    row = {
        "trajectory": {
            "turns": [{"fight": 0, "event": 1}, {"fight": 0, "event": 20}],
            "draws": [
                {"fight": 0, "event": 3, "id": "new", "uid": 9},
                {"fight": 0, "event": 22, "id": "new", "uid": 10},
            ],
            "plays": [
                {"fight": 0, "event": 2, "id": "thread", "uid": 4},
                {"fight": 0, "event": 4, "id": "new", "uid": 9},
                {"fight": 0, "event": 21, "id": "thread", "uid": 5},
                {"fight": 0, "event": 23, "id": "old", "uid": 6},
            ],
        },
    }
    qualifying, exposures, faults = draw_thread_events(row, cards, {"thread"})
    require("self-check faults", not faults)
    require("self-check exposure count", len(exposures) == 2)
    require("self-check qualifying count", len(qualifying) == 1)
    require("self-check exact uid", qualifying[0]["consumerUid"] == 9)


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the draw-thread capacity summary")
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
    require("plan arm", plan["arm"] == "target-death-trace-explicit-null")
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

    producers = reward_draw_cards(content)
    require("source producer set", producers == protocol["producerCards"])
    row_events: dict[tuple[int, int], list[dict[str, Any]]] = {}
    row_exposures: dict[tuple[int, int], list[dict[str, Any]]] = {}
    semantic_faults: list[dict[str, Any]] = []
    for key, row in rows.items():
        events, exposures, faults = draw_thread_events(row, content["cards"], set(producers))
        row_events[key] = events
        row_exposures[key] = exposures
        semantic_faults.extend(
            {"policyIndex": key[0], "seed": key[1], **fault} for fault in faults
        )

    qualifying = {key for key, events in row_events.items() if events}
    exposed = {key for key, events in row_exposures.items() if events}
    active = robust_keys(qualifying, protocol)
    producer_active = robust_keys(exposed, protocol)
    inactive = exact_inactive_keys(qualifying, protocol)
    ambiguous = set(range(cohort["policyCount"])) - active - inactive
    exposure_only = producer_active - active
    viable = {
        policy for policy in active
        if any((policy, seed) in qualifying and rows[(policy, seed)].get("outcome") == "win"
               for seed in cohort["simulationSeeds"])
    }
    all_events = [event for events in row_events.values() for event in events]
    producer_breadth = {str(event["producerCard"]) for event in all_events}
    consumer_breadth = {str(event["consumerCard"]) for event in all_events}
    consumer_types = {content["cards"][card_id]["type"] for card_id in consumer_breadth}
    pairs = {
        (str(event["producerCard"]), str(event["consumerCard"])) for event in all_events
    }

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
    separations = {
        "scoreline": options.separation(active, scoreline),
        "afterimage": options.separation(active, afterimage),
    }
    gates = protocol["gates"]

    def separated(result: dict[str, Any]) -> bool:
        return (
            result["candidateOnlyPolicies"] >= gates["minimumCandidateOnlyPolicies"]
            and result["anchorOnlyPolicies"] >= gates["minimumAnchorOnlyPolicies"]
            and result["jaccard"] <= gates["maximumAnchorJaccard"]
        )

    fault_rows = sum(
        row.get("outcome") in ("stall", "error") or bool(row.get("error"))
        for row in rows.values()
    )
    checks = {
        "activeSupport": len(active) >= gates["minimumActivePolicies"],
        "inactiveSupport": len(inactive) >= gates["minimumExactInactivePolicies"],
        "viableSupport": len(viable) >= gates["minimumViablePolicies"],
        "producerReachability": len(producer_active) >= gates["minimumProducerActivePolicies"],
        "exposureOnlySupport": len(exposure_only) >= gates["minimumExposureOnlyPolicies"],
        "producerBreadth": len(producer_breadth) >= gates["minimumDistinctProducers"],
        "consumerBreadth": len(consumer_breadth) >= gates["minimumDistinctConsumers"],
        "consumerTypeBreadth": len(consumer_types) >= gates["minimumDistinctConsumerTypes"],
        "pairBreadth": len(pairs) >= gates["minimumDistinctPairs"],
        "scorelineSeparation": separated(separations["scoreline"]),
        "afterimageSeparation": separated(separations["afterimage"]),
        "semanticValidity": len(semantic_faults) <= gates["maximumSemanticFaults"],
        "reliability": fault_rows <= gates["maximumBaselineFaultRows"],
    }
    elapsed = time.monotonic() - started
    if elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        outcome_class = "inconclusive"
        boundary = 3
        decision = "record-draw-thread-capacity-inconclusive-at-cap"
    elif all(checks.values()):
        outcome_class = "success"
        boundary = 1
        decision = "freeze-immediate-draw-thread-for-identity-preflight"
    else:
        outcome_class = "futility"
        boundary = 2
        decision = "close-immediate-draw-thread-at-zero-row-capacity"
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
        "checks": checks,
        "counts": {
            "activePolicies": len(active),
            "exactInactivePolicies": len(inactive),
            "ambiguousPolicies": len(ambiguous),
            "viablePolicies": len(viable),
            "producerActivePolicies": len(producer_active),
            "exposureOnlyPolicies": len(exposure_only),
            "qualifyingRows": len(qualifying),
            "exposedRows": len(exposed),
            "qualifyingTurns": len(all_events),
            "exposureTurns": sum(len(events) for events in row_exposures.values()),
            "distinctProducers": len(producer_breadth),
            "distinctConsumers": len(consumer_breadth),
            "distinctConsumerTypes": len(consumer_types),
            "distinctPairs": len(pairs),
        },
        "policySets": {
            "active": sorted(active),
            "exactInactive": sorted(inactive),
            "ambiguous": sorted(ambiguous),
            "viable": sorted(viable),
            "producerActive": sorted(producer_active),
            "exposureOnly": sorted(exposure_only),
        },
        "sourceBreadth": {
            "producerCards": sorted(producer_breadth),
            "consumerCards": sorted(consumer_breadth),
            "consumerTypes": sorted(consumer_types),
            "pairs": sorted([list(pair) for pair in pairs]),
        },
        "separation": separations,
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
        "counts": summary["counts"],
        "newSimulatorObservationRows": 0,
    }))


if __name__ == "__main__":
    main()
