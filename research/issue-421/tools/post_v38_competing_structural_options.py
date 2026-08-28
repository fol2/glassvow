#!/usr/bin/env python3
"""Zero-row competing structural-mechanism audit for issue #421."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any, Callable

import post_v38_cohand_opportunity_decomposition as cohand
import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-competing-structural-options-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-competing-structural-options-v1.json"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Competing structural-options mismatch: {label}")


def main_blob(path: str) -> bytes:
    return subprocess.run(
        ["git", "show", f"HEAD:{path}"], cwd=core.SOURCE,
        check=True, capture_output=True,
    ).stdout


def ordered_pairs(
    row: dict[str, Any], producers: set[str], consumers: set[str],
) -> set[tuple[str, str]]:
    found: set[tuple[str, str]] = set()
    for plays in cohand.grouped(row, "plays").values():
        for index, producer in enumerate(plays):
            if str(producer["id"]) not in producers:
                continue
            for consumer in plays[index + 1:]:
                if str(consumer["id"]) in consumers:
                    found.add((str(producer["id"]), str(consumer["id"])))
    return found


def robust_set(
    rows: dict[tuple[int, int], dict[str, Any]],
    protocol: dict[str, Any],
    predicate: Callable[[dict[str, Any]], bool],
) -> set[int]:
    cohort = protocol["cohort"]
    return {
        policy_index for policy_index in range(cohort["policyCount"])
        if sum(predicate(rows[(policy_index, seed)])
               for seed in cohort["simulationSeeds"])
        >= cohort["minimumRowsPerRobustPolicy"]
    }


def exact_inactive_set(
    rows: dict[tuple[int, int], dict[str, Any]],
    protocol: dict[str, Any],
    predicate: Callable[[dict[str, Any]], bool],
) -> set[int]:
    cohort = protocol["cohort"]
    return {
        policy_index for policy_index in range(cohort["policyCount"])
        if not any(predicate(rows[(policy_index, seed)])
                   for seed in cohort["simulationSeeds"])
    }


def separation(candidate: set[int], anchor: set[int]) -> dict[str, Any]:
    union = candidate | anchor
    return {
        "candidateOnlyPolicies": len(candidate - anchor),
        "anchorOnlyPolicies": len(anchor - candidate),
        "crossActivePolicies": len(candidate & anchor),
        "jaccard": len(candidate & anchor) / len(union) if union else 1.0,
    }


def source_sets(content: dict[str, Any]) -> dict[str, list[str]]:
    cards = content["cards"]
    self_loss = []
    recovery = []
    weak = []
    repeated_hit = []
    for card_id, card in cards.items():
        effects = card.get("effects", [])
        if any(effect.get("kind") == "loseHp" for effect in effects):
            self_loss.append(card_id)
        if any(
            effect.get("kind") == "heal"
            or (effect.get("kind") == "status"
                and effect.get("who") == "self"
                and effect.get("id") == "regen")
            or (effect.get("kind") == "special"
                and effect.get("id") in {"leech", "devour"})
            for effect in effects
        ):
            recovery.append(card_id)
        if any(
            effect.get("kind") == "status"
            and effect.get("who") in {"target", "allEnemies"}
            and effect.get("id") == "weak"
            for effect in effects
        ):
            weak.append(card_id)
        if card.get("type") == "attack" and any(
            effect.get("kind") == "dmg" and int(effect.get("times", 1)) > 1
            for effect in effects
        ):
            repeated_hit.append(card_id)
    return {
        "selfLoss": sorted(self_loss),
        "recovery": sorted(recovery),
        "weak": sorted(weak),
        "repeatedHit": sorted(repeated_hit),
    }


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the competing-options summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    immutable = protocol["immutableInputs"]
    require("runner SHA", core.file_sha(Path(__file__)) == immutable["runnerSha256"])
    require("source commit", subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=core.SOURCE, check=True,
        text=True, capture_output=True,
    ).stdout.strip() == immutable["sourceCommit"])
    for path, expected in immutable["sourceSha256"].items():
        require(f"source {path}", core.sha(main_blob(path)) == expected)
    for path, expected in immutable["fileSha256"].items():
        require(path, core.file_sha(core.ROOT / path) == expected)

    ledger_before = identity.ledger_identity()
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
    require("current-main content identity",
            core.sha(main_blob("content/full-content.json")) == trace["contentSha256"])
    cohort = protocol["cohort"]
    require("plan row count", len(plan["rows"]) == cohort["rows"])
    require("output row count", len(output["rows"]) == cohort["rows"])
    require("cached-row ceiling", len(output["rows"]) <=
            protocol["budget"]["maximumCachedObservationRowsRead"])
    rows: dict[tuple[int, int], dict[str, Any]] = {}
    for spec, row in zip(plan["rows"], output["rows"]):
        require("trace arm", spec.get("arm") == "cohand-telemetry-explicit-null")
        require("trace capture", spec.get("captureTrace") is True)
        require("trace explicit null", spec.get("explicitNull") is True)
        key = (int(spec["policyIndex"]), int(spec["seed"]))
        require(f"unique row {key}", key not in rows)
        require(f"seed identity {key}", int(row["seed"]) == key[1])
        rows[key] = row
    require("complete rectangle", len(rows) == cohort["rows"])

    derived_sets = source_sets(content)
    require("source-derived card sets", derived_sets == protocol["sourceCardSets"])
    predicates: dict[str, Callable[[dict[str, Any]], bool]] = {
        "voluntary-loss-recovery": lambda row: bool(ordered_pairs(
            row, set(derived_sets["selfLoss"]), set(derived_sets["recovery"]))),
        "weak-mend-persistence": lambda row: bool(ordered_pairs(
            row, set(derived_sets["weak"]), set(derived_sets["recovery"]))),
        "recovery-repeated-hit": lambda row: bool(ordered_pairs(
            row, set(derived_sets["recovery"]), set(derived_sets["repeatedHit"]))),
    }
    require("option catalogue", sorted(predicates) ==
            sorted(option["id"] for option in protocol["options"]))

    scoreline = robust_set(
        rows, protocol,
        lambda row: bool(ordered_pairs(row, {"chisel"}, {"executioner"})),
    )
    afterimage = robust_set(
        rows, protocol,
        lambda row: cohand.simultaneous_cohand(row, "defend", "guardedStrike"),
    )
    require("Scoreline anchor", len(scoreline) ==
            protocol["anchors"]["scoreline"]["activePolicies"])
    require("Afterimage anchor", len(afterimage) ==
            protocol["anchors"]["afterimage"]["activePolicies"])
    fault_rows = sum(
        row.get("outcome") in ("stall", "error") or bool(row.get("error"))
        for row in rows.values()
    )
    gates = protocol["gates"]
    assessments = []
    for option in protocol["options"]:
        option_id = str(option["id"])
        predicate = predicates[option_id]
        active = robust_set(rows, protocol, predicate)
        inactive = exact_inactive_set(rows, protocol, predicate)
        ambiguous = set(range(cohort["policyCount"])) - active - inactive
        viable = {
            policy_index for policy_index in active
            if any(predicate(rows[(policy_index, seed)])
                   and rows[(policy_index, seed)].get("outcome") == "win"
                   for seed in cohort["simulationSeeds"])
        }
        pairs: set[tuple[str, str]] = set()
        producers = set(derived_sets[option["producerSet"]])
        consumers = set(derived_sets[option["consumerSet"]])
        for row in rows.values():
            pairs.update(ordered_pairs(row, producers, consumers))
        producer_cards = sorted({pair[0] for pair in pairs})
        consumer_cards = sorted({pair[1] for pair in pairs})
        separations = {
            "scoreline": separation(active, scoreline),
            "afterimage": separation(active, afterimage),
        }

        def separated(result: dict[str, Any]) -> bool:
            return (result["candidateOnlyPolicies"] >=
                    gates["minimumCandidateOnlyPolicies"]
                    and result["anchorOnlyPolicies"] >=
                    gates["minimumAnchorOnlyPolicies"]
                    and result["jaccard"] <= gates["maximumAnchorJaccard"])

        gate_results = {
            "active": len(active) >= gates["minimumPotentialActivePolicies"],
            "inactive": len(inactive) >= gates["minimumExactInactivePolicies"],
            "viable": len(viable) >= gates["minimumViablePolicies"],
            "sourceBreadth": (
                len(producer_cards) >= option["minimumDistinctProducerCards"]
                and len(consumer_cards) >= option["minimumDistinctConsumerCards"]
                and len(pairs) >= option["minimumDistinctPairs"]
            ),
            "scorelineSeparation": separated(separations["scoreline"]),
            "afterimageSeparation": separated(separations["afterimage"]),
            "reliability": fault_rows <= gates["maximumBaselineFaultRows"],
        }
        assessments.append({
            "id": option_id,
            "definition": option,
            "counts": {
                "potentialActivePolicies": len(active),
                "exactInactivePolicies": len(inactive),
                "ambiguousPolicies": len(ambiguous),
                "viablePolicies": len(viable),
                "distinctProducerCards": len(producer_cards),
                "distinctConsumerCards": len(consumer_cards),
                "distinctPairs": len(pairs),
                "baselineFaultRows": fault_rows,
            },
            "sourceBreadth": {
                "producerCards": producer_cards,
                "consumerCards": consumer_cards,
                "pairs": [list(pair) for pair in sorted(pairs)],
            },
            "separation": separations,
            "gateResults": gate_results,
            "eligible": all(gate_results.values()),
            "policySets": {
                "potentialActive": sorted(active),
                "exactInactive": sorted(inactive),
                "ambiguous": sorted(ambiguous),
                "viable": sorted(viable),
            },
        })

    eligible = [assessment["id"] for assessment in assessments
                if assessment["eligible"]]
    elapsed = time.monotonic() - started
    if elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        boundary = 3
        outcome_class = "inconclusive"
        decision = "record-competing-structural-options-inconclusive-at-cap"
        selected = None
    elif len(eligible) == 1:
        boundary = 1
        outcome_class = "success"
        selected = eligible[0]
        decision = f"freeze-{selected}-for-identity-preflight"
    elif not eligible:
        boundary = 2
        outcome_class = "futility"
        selected = None
        decision = "close-competing-structural-option-catalogue"
    else:
        boundary = 3
        outcome_class = "inconclusive"
        selected = None
        decision = "record-nondiscriminating-structural-options-at-cap"
    ledger_after = identity.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": boundary,
        "decision": decision,
        "outcomeClass": outcome_class,
        "selectedOption": selected,
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "sourceCardSets": derived_sets,
        "assessments": assessments,
        "eligibleOptions": eligible,
        "anchors": {
            "scoreline": sorted(scoreline),
            "afterimage": sorted(afterimage),
        },
        "traceIdentity": {
            "rows": len(rows),
            "identitySummarySha256": trace["identitySummarySha256"],
            "pathRngPolicyResultExact": True,
        },
        "newSimulatorObservationRows": 0,
        "cachedObservationRowsRead": len(rows),
        "newLedgerRows": 0,
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "maximumModelContextTokens": 0,
        "wallTimeSeconds": elapsed,
        "factorDisposition": protocol["factorDisposition"],
        "authority": protocol["decisionRules"][f"{outcome_class}Authority"],
    }
    SUMMARY.parent.mkdir(parents=True, exist_ok=True)
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS",
        "decision": decision,
        "decisionBoundary": boundary,
        "selectedOption": selected,
        "eligibleOptions": eligible,
        "newSimulatorObservationRows": 0,
        "summarySha256": core.file_sha(SUMMARY),
    }))


if __name__ == "__main__":
    main()
