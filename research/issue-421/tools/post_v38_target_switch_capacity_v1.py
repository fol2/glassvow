#!/usr/bin/env python3
"""Zero-row actual target-switch capacity audit for issue #421."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any, Callable

import post_v38_competing_structural_options as options
import post_v38_knob_identity as ledger
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-target-switch-capacity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-target-switch-capacity-v1.json"
SOURCE = core.ROOT / "target-switch-observation-v1-source"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Target-switch capacity mismatch: {label}")


def classified_pairs(
    row: dict[str, Any], cards: dict[str, Any],
) -> list[dict[str, Any]]:
    """Classify the first two single-target Attacks in each eligible turn."""
    found: list[dict[str, Any]] = []
    trace = row["trajectory"]
    fights = row["fights"]
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
        turn_event: int | None = None
        first: dict[str, Any] | None = None
        intervening_deaths: set[int] = set()
        complete = True
        for order, kind, event in sorted(events, key=lambda item: (item[0], item[1])):
            if kind == 0:
                turn_event = order
                first = None
                intervening_deaths = set()
                complete = False
                continue
            if kind == 2:
                if first is not None and not complete:
                    intervening_deaths.add(int(event["idx"]))
                continue
            require(f"play before turn in fight {fight}", turn_event is not None)
            card_id = str(event["id"])
            require(f"known card {card_id}", card_id in cards)
            card = cards[card_id]
            if card.get("type") != "attack" or card.get("target") != "enemy":
                continue
            target = event.get("targetIdx")
            require(
                f"single-target index at fight {fight} event {order}",
                isinstance(target, int) and not isinstance(target, bool)
                and 0 <= target < len(fights[fight]["enemies"]),
            )
            if complete:
                continue
            if first is None:
                first = {"event": order, "id": card_id, "targetIdx": target}
                intervening_deaths = set()
                continue
            first_target = int(first["targetIdx"])
            first_died = first_target in intervening_deaths
            if target == first_target and first_died:
                classification = "invalid-dead-target-reuse"
            elif target == first_target:
                classification = "same-target"
            elif first_died:
                classification = "forced-death-change"
            else:
                classification = "deliberate-switch"
            found.append({
                "fight": fight,
                "turnEvent": turn_event,
                "firstEvent": int(first["event"]),
                "secondEvent": order,
                "firstCard": str(first["id"]),
                "secondCard": card_id,
                "firstTargetIdx": first_target,
                "secondTargetIdx": target,
                "classification": classification,
            })
            complete = True
    return found


def has_classification(
    row: dict[str, Any], cards: dict[str, Any], classification: str,
) -> bool:
    return any(pair["classification"] == classification
               for pair in classified_pairs(row, cards))


def robust_set(
    rows: dict[tuple[int, int], dict[str, Any]],
    protocol: dict[str, Any],
    predicate: Callable[[dict[str, Any]], bool],
) -> set[int]:
    return options.robust_set(rows, protocol, predicate)


def exact_inactive_set(
    rows: dict[tuple[int, int], dict[str, Any]],
    protocol: dict[str, Any],
    predicate: Callable[[dict[str, Any]], bool],
) -> set[int]:
    return options.exact_inactive_set(rows, protocol, predicate)


def self_check() -> None:
    cards = {
        "a": {"type": "attack", "target": "enemy"},
        "b": {"type": "attack", "target": "enemy"},
        "sweep": {"type": "attack", "target": "allEnemies"},
        "skill": {"type": "skill", "target": "self"},
    }
    row = {
        "fights": [
            {"enemies": ["x", "y", "z"]},
            {"enemies": ["x"]},
        ],
        "trajectory": {
            "turns": [
                {"fight": 0, "event": 1},
                {"fight": 0, "event": 10},
                {"fight": 0, "event": 20},
                {"fight": 0, "event": 30},
                {"fight": 1, "event": 1},
            ],
            "plays": [
                {"fight": 0, "event": 2, "id": "a", "targetIdx": 0},
                {"fight": 0, "event": 3, "id": "skill", "targetIdx": None},
                {"fight": 0, "event": 4, "id": "b", "targetIdx": 1},
                {"fight": 0, "event": 5, "id": "a", "targetIdx": 2},
                {"fight": 0, "event": 11, "id": "a", "targetIdx": 0},
                {"fight": 0, "event": 13, "id": "b", "targetIdx": 1},
                {"fight": 0, "event": 21, "id": "a", "targetIdx": 2},
                {"fight": 0, "event": 22, "id": "sweep", "targetIdx": None},
                {"fight": 0, "event": 23, "id": "b", "targetIdx": 2},
                {"fight": 0, "event": 31, "id": "a", "targetIdx": 0},
                {"fight": 0, "event": 33, "id": "b", "targetIdx": 2},
                {"fight": 1, "event": 2, "id": "a", "targetIdx": 0},
                {"fight": 1, "event": 3, "id": "b", "targetIdx": 0},
            ],
            "dies": [
                {"fight": 0, "event": 12, "idx": 0},
                {"fight": 0, "event": 32, "idx": 1},
            ],
        },
    }
    pairs = classified_pairs(row, cards)
    require("four eligible pairs", len(pairs) == 4)
    require("deliberate switch", pairs[0]["classification"] == "deliberate-switch")
    require("first pair only", pairs[0]["secondEvent"] == 4)
    require("forced death", pairs[1]["classification"] == "forced-death-change")
    require("same target", pairs[2]["classification"] == "same-target")
    require("irrelevant death", pairs[3]["classification"] == "deliberate-switch")


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the target-switch capacity summary")
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

    head = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=SOURCE, check=True,
        text=True, capture_output=True,
    ).stdout.strip()
    require("observation source head", head == immutable["observationSourceHead"])
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
    require("plan protocol", plan["protocolSha256"] == trace["identityProtocolSha256"])
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
    source_single_target_attacks = sorted(
        card_id for card_id, card in cards.items()
        if card.get("type") == "attack" and card.get("target") == "enemy"
    )
    require(
        "source single-target Attack identities",
        source_single_target_attacks == protocol["sourceAnchors"]["singleTargetAttacks"],
    )
    row_pairs = {key: classified_pairs(row, cards) for key, row in rows.items()}
    semantic_faults = [
        {"policyIndex": key[0], "seed": key[1], **pair}
        for key, pairs in row_pairs.items()
        for pair in pairs if pair["classification"] == "invalid-dead-target-reuse"
    ]
    actual = lambda row: has_classification(row, cards, "deliberate-switch")
    context = lambda row: bool(classified_pairs(row, cards))
    target_change = lambda row: any(
        pair["classification"] in {"deliberate-switch", "forced-death-change"}
        for pair in classified_pairs(row, cards)
    )
    same_target = lambda row: has_classification(row, cards, "same-target")
    active = robust_set(rows, protocol, actual)
    inactive = exact_inactive_set(rows, protocol, actual)
    ambiguous = set(range(cohort["policyCount"])) - active - inactive
    context_active = robust_set(rows, protocol, context)
    target_change_active = robust_set(rows, protocol, target_change)
    same_target_active = robust_set(rows, protocol, same_target)
    context_only = context_active - active
    death_alias_only = target_change_active - active
    viable = {
        policy for policy in active
        if any(actual(rows[(policy, seed)])
               and rows[(policy, seed)].get("outcome") == "win"
               for seed in cohort["simulationSeeds"])
    }
    require(
        "upper-bound context consistency",
        len(context_active) == protocol["anchors"]["upperBoundContext"]["activePolicies"],
    )

    scoreline = robust_set(
        rows, protocol,
        lambda row: bool(options.ordered_pairs(row, {"chisel"}, {"executioner"})),
    )
    afterimage = robust_set(
        rows, protocol,
        lambda row: options.cohand.simultaneous_cohand(row, "defend", "guardedStrike"),
    )
    require(
        "Scoreline anchor",
        len(scoreline) == protocol["anchors"]["scoreline"]["activePolicies"],
    )
    require(
        "Afterimage anchor",
        len(afterimage) == protocol["anchors"]["afterimage"]["activePolicies"],
    )

    actual_pairs = [
        pair for pairs in row_pairs.values() for pair in pairs
        if pair["classification"] == "deliberate-switch"
    ]
    all_pairs = [pair for pairs in row_pairs.values() for pair in pairs]
    first_cards = {pair["firstCard"] for pair in actual_pairs}
    second_cards = {pair["secondCard"] for pair in actual_pairs}
    card_pairs = {(pair["firstCard"], pair["secondCard"]) for pair in actual_pairs}
    transitions = {
        (pair["firstTargetIdx"], pair["secondTargetIdx"]) for pair in actual_pairs
    }
    scoreline_separation = options.separation(active, scoreline)
    afterimage_separation = options.separation(active, afterimage)
    fault_rows = sum(
        row.get("outcome") in ("stall", "error") or bool(row.get("error"))
        for row in rows.values()
    )
    gates = protocol["gates"]

    def separated(result: dict[str, Any]) -> bool:
        return (
            result["candidateOnlyPolicies"] >= gates["minimumCandidateOnlyPolicies"]
            and result["anchorOnlyPolicies"] >= gates["minimumAnchorOnlyPolicies"]
            and result["jaccard"] <= gates["maximumAnchorJaccard"]
        )

    checks = {
        "activeSupport": len(active) >= gates["minimumActivePolicies"],
        "inactiveSupport": len(inactive) >= gates["minimumExactInactivePolicies"],
        "viableSupport": len(viable) >= gates["minimumViablePolicies"],
        "contextNotSufficient": len(context_only) >= gates["minimumContextOnlyPolicies"],
        "firstCardBreadth": len(first_cards) >= gates["minimumDistinctFirstCards"],
        "secondCardBreadth": len(second_cards) >= gates["minimumDistinctSecondCards"],
        "cardPairBreadth": len(card_pairs) >= gates["minimumDistinctCardPairs"],
        "targetTransitionBreadth": len(transitions) >=
            gates["minimumDistinctTargetTransitions"],
        "scorelineSeparation": separated(scoreline_separation),
        "afterimageSeparation": separated(afterimage_separation),
        "semanticValidity": not semantic_faults,
        "reliability": fault_rows <= gates["maximumBaselineFaultRows"],
    }
    elapsed = time.monotonic() - started
    if elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        outcome_class = "inconclusive"
        boundary = 3
        decision = "record-target-switch-capacity-inconclusive-at-cap"
    elif all(checks.values()):
        outcome_class = "success"
        boundary = 1
        decision = "freeze-target-transfer-for-identity-preflight"
    else:
        outcome_class = "futility"
        boundary = 2
        decision = "close-target-transfer-at-zero-row-capacity"
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
            "upperBoundContextPolicies": len(context_active),
            "contextOnlyPolicies": len(context_only),
            "targetIndexChangePolicies": len(target_change_active),
            "deathAliasOnlyPolicies": len(death_alias_only),
            "sameTargetPolicies": len(same_target_active),
            "upperBoundRows": sum(bool(pairs) for pairs in row_pairs.values()),
            "upperBoundTurns": len(all_pairs),
            "qualifyingRows": sum(actual(row) for row in rows.values()),
            "qualifyingTurns": len(actual_pairs),
            "sameTargetTurns": sum(
                pair["classification"] == "same-target" for pair in all_pairs
            ),
            "forcedDeathChangeTurns": sum(
                pair["classification"] == "forced-death-change" for pair in all_pairs
            ),
            "semanticFaultPairs": len(semantic_faults),
            "distinctFirstCards": len(first_cards),
            "distinctSecondCards": len(second_cards),
            "distinctCardPairs": len(card_pairs),
            "distinctTargetTransitions": len(transitions),
            "baselineFaultRows": fault_rows,
        },
        "sourceBreadth": {
            "sourceSingleTargetAttacks": source_single_target_attacks,
            "observedFirstCards": sorted(first_cards),
            "observedSecondCards": sorted(second_cards),
            "observedCardPairs": sorted([list(pair) for pair in card_pairs]),
            "observedTargetTransitions": sorted([list(pair) for pair in transitions]),
        },
        "separation": {
            "scoreline": scoreline_separation,
            "afterimage": afterimage_separation,
        },
        "policySets": {
            "active": sorted(active),
            "exactInactive": sorted(inactive),
            "ambiguous": sorted(ambiguous),
            "viable": sorted(viable),
            "upperBoundContext": sorted(context_active),
            "contextOnly": sorted(context_only),
            "targetIndexChange": sorted(target_change_active),
            "deathAliasOnly": sorted(death_alias_only),
            "sameTarget": sorted(same_target_active),
        },
        "semanticFaults": semantic_faults,
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
        "activePolicies": len(active),
        "exactInactivePolicies": len(inactive),
        "contextOnlyPolicies": len(context_only),
        "newSimulatorObservationRows": 0,
    }))


if __name__ == "__main__":
    main()
