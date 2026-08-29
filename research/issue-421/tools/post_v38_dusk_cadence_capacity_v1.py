#!/usr/bin/env python3
"""Zero-row capacity audit for the issue #421 Dusk cadence primitive."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any, Callable

import post_v38_competing_structural_options as options
import post_v38_knob_identity as ledger
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-dusk-cadence-capacity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-dusk-cadence-capacity-v1.json"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Dusk cadence capacity mismatch: {label}")


def turn_plays(row: dict[str, Any], cards: dict[str, Any]) -> list[list[tuple[str, str]]]:
    turns: list[list[tuple[str, str]]] = []
    trace = row["trajectory"]
    fights = {int(event["fight"]) for field in ("turns", "plays")
              for event in trace[field]}
    for fight in sorted(fights):
        events: list[tuple[int, int, dict[str, Any]]] = []
        events.extend((int(event["event"]), 0, event)
                      for event in trace["turns"] if int(event["fight"]) == fight)
        events.extend((int(event["event"]), 1, event)
                      for event in trace["plays"] if int(event["fight"]) == fight)
        current: list[tuple[str, str]] | None = None
        for _, kind, event in sorted(events, key=lambda item: (item[0], item[1])):
            if kind == 0:
                current = []
                turns.append(current)
                continue
            require(f"play before turn in fight {fight}", current is not None)
            card_id = str(event["id"])
            require(f"unknown card {card_id}", card_id in cards)
            current.append((card_id, str(cards[card_id].get("type", ""))))
    return turns


def cadence_patterns(row: dict[str, Any], cards: dict[str, Any]) -> list[tuple[str, str, str]]:
    found: list[tuple[str, str, str]] = []
    for plays in turn_plays(row, cards):
        streak: list[tuple[str, str]] = []
        for card_id, card_type in plays:
            if card_type not in {"attack", "skill"}:
                streak.clear()
                continue
            if streak and streak[-1][1] == card_type:
                streak = [(card_id, card_type)]
            else:
                streak.append((card_id, card_type))
            if len(streak) >= 3:
                found.append(tuple(item[0] for item in streak[-3:]))
                break
    return found


def self_check() -> None:
    cards = {
        "a": {"type": "attack"},
        "s": {"type": "skill"},
        "p": {"type": "power"},
    }
    row = {"trajectory": {
        "turns": [
            {"fight": 0, "event": 1},
            {"fight": 0, "event": 10},
            {"fight": 1, "event": 1},
        ],
        "plays": [
            {"fight": 0, "event": 2, "id": "a"},
            {"fight": 0, "event": 3, "id": "s"},
            {"fight": 0, "event": 4, "id": "a"},
            {"fight": 0, "event": 11, "id": "a"},
            {"fight": 0, "event": 12, "id": "a"},
            {"fight": 0, "event": 13, "id": "s"},
            {"fight": 0, "event": 14, "id": "a"},
            {"fight": 1, "event": 2, "id": "a"},
            {"fight": 1, "event": 3, "id": "p"},
            {"fight": 1, "event": 4, "id": "s"},
            {"fight": 1, "event": 5, "id": "a"},
        ],
    }}
    require("cadence self-check", cadence_patterns(row, cards) ==
            [("a", "s", "a"), ("a", "s", "a")])


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


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the Dusk cadence capacity summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    immutable = protocol["immutableInputs"]
    require("runner SHA", core.file_sha(Path(__file__)) == immutable["runnerSha256"])
    self_check()
    require("task capsule SHA", core.file_sha(core.ROOT / immutable["taskCapsulePath"]) ==
            immutable["taskCapsuleSha256"])
    for path, expected in immutable["researchFileSha256"].items():
        require(f"research file {path}", core.file_sha(core.ROOT / path) == expected)

    repository = Path(immutable["repositoryPath"])
    for ref, expected in immutable["repositoryRefs"].items():
        actual = subprocess.run(
            ["git", "rev-parse", ref], cwd=repository, check=True,
            text=True, capture_output=True,
        ).stdout.strip()
        require(f"repository ref {ref}", actual == expected)
    for name, expected in immutable["sourceSha256"].items():
        blob = subprocess.run(
            ["git", "show", f"{immutable['sourceHead']}:{name}"], cwd=repository,
            check=True, capture_output=True,
        ).stdout
        require(f"source {name}", core.sha(blob) == expected)

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
    cohort = protocol["cohort"]
    require("plan rows", len(plan["rows"]) == cohort["rows"])
    require("output rows", len(output["rows"]) == cohort["rows"])
    require("cached-row ceiling", len(output["rows"]) <=
            protocol["budget"]["maximumCachedObservationRowsRead"])

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
    require("one policy snapshot per identity",
            len(policy_snapshots) == cohort["policyCount"] and
            all(len(snapshots) == 1 for snapshots in policy_snapshots.values()))

    cards = content["cards"]
    predicate = lambda row: bool(cadence_patterns(row, cards))
    active = robust_set(rows, protocol, predicate)
    inactive = exact_inactive_set(rows, protocol, predicate)
    ambiguous = set(range(cohort["policyCount"])) - active - inactive
    viable = {
        policy for policy in active
        if any(predicate(rows[(policy, seed)]) and
               rows[(policy, seed)].get("outcome") == "win"
               for seed in cohort["simulationSeeds"])
    }
    scoreline = robust_set(
        rows, protocol,
        lambda row: bool(options.ordered_pairs(row, {"chisel"}, {"executioner"})),
    )
    afterimage = robust_set(
        rows, protocol,
        lambda row: options.cohand.simultaneous_cohand(row, "defend", "guardedStrike"),
    )
    require("Scoreline anchor", len(scoreline) ==
            protocol["anchors"]["scoreline"]["activePolicies"])
    require("Afterimage anchor", len(afterimage) ==
            protocol["anchors"]["afterimage"]["activePolicies"])

    all_patterns = [pattern for row in rows.values()
                    for pattern in cadence_patterns(row, cards)]
    first_cards = {pattern[0] for pattern in all_patterns}
    middle_cards = {pattern[1] for pattern in all_patterns}
    final_cards = {pattern[2] for pattern in all_patterns}
    distinct_patterns = set(all_patterns)
    orientation_counts = {
        "attack-skill-attack": sum(
            cards[pattern[0]]["type"] == "attack" for pattern in all_patterns
        ),
        "skill-attack-skill": sum(
            cards[pattern[0]]["type"] == "skill" for pattern in all_patterns
        ),
    }
    scoreline_separation = options.separation(active, scoreline)
    afterimage_separation = options.separation(active, afterimage)
    fault_rows = sum(
        row.get("outcome") in ("stall", "error") or bool(row.get("error"))
        for row in rows.values()
    )
    gates = protocol["gates"]

    def separated(result: dict[str, Any]) -> bool:
        return (result["candidateOnlyPolicies"] >= gates["minimumCandidateOnlyPolicies"]
                and result["anchorOnlyPolicies"] >= gates["minimumAnchorOnlyPolicies"]
                and result["jaccard"] <= gates["maximumAnchorJaccard"])

    checks = {
        "activeSupport": len(active) >= gates["minimumActivePolicies"],
        "inactiveSupport": len(inactive) >= gates["minimumExactInactivePolicies"],
        "viableSupport": len(viable) >= gates["minimumViablePolicies"],
        "firstCardBreadth": len(first_cards) >= gates["minimumDistinctCardsPerPosition"],
        "middleCardBreadth": len(middle_cards) >= gates["minimumDistinctCardsPerPosition"],
        "finalCardBreadth": len(final_cards) >= gates["minimumDistinctCardsPerPosition"],
        "patternBreadth": len(distinct_patterns) >= gates["minimumDistinctCardTriples"],
        "bothOrientations": all(count >= gates["minimumRowsPerOrientation"]
                                for count in orientation_counts.values()),
        "scorelineSeparation": separated(scoreline_separation),
        "afterimageSeparation": separated(afterimage_separation),
        "reliability": fault_rows <= gates["maximumBaselineFaultRows"],
    }
    elapsed = time.monotonic() - started
    if elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        outcome_class = "inconclusive"
        boundary = 3
        decision = "record-dusk-cadence-capacity-inconclusive-at-cap"
    elif all(checks.values()):
        outcome_class = "success"
        boundary = 1
        decision = "freeze-dusk-cadence-for-identity-preflight"
    else:
        outcome_class = "futility"
        boundary = 2
        decision = "close-dusk-cadence-at-zero-row-capacity"
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
            "qualifyingRows": sum(predicate(row) for row in rows.values()),
            "qualifyingTurns": len(all_patterns),
            "distinctFirstCards": len(first_cards),
            "distinctMiddleCards": len(middle_cards),
            "distinctFinalCards": len(final_cards),
            "distinctCardTriples": len(distinct_patterns),
            "baselineFaultRows": fault_rows,
        },
        "orientationCounts": orientation_counts,
        "sourceBreadth": {
            "firstCards": sorted(first_cards),
            "middleCards": sorted(middle_cards),
            "finalCards": sorted(final_cards),
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
        },
        "cachedObservationRowsRead": len(rows),
        "newSimulatorObservationRows": 0,
        "newLedgerRows": 0,
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "elapsedSeconds": round(elapsed, 6),
        "claimBoundary": "Natural policy-capacity and anchor-separation proxy only; no implementation, mediator, payoff, causal, package-admission, detector, product or P9 claim.",
        "authority": protocol["decisionRules"][f"{outcome_class}Authority"],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": outcome_class.upper(),
        "decision": decision,
        "activePolicies": len(active),
        "inactivePolicies": len(inactive),
        "newSimulatorObservationRows": 0,
    }))


if __name__ == "__main__":
    main()
