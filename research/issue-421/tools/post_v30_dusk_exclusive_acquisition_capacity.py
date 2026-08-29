#!/usr/bin/env python3
"""Zero-new-row ChoiceScreen policy-selection capacity gate for issue #421."""

from __future__ import annotations

import json
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import post_v38_novaflare_nonreward_capacity as scoring
import research as core


PROTOCOL = core.ROOT / "protocols/post-v30-dusk-exclusive-acquisition-capacity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v30-dusk-exclusive-acquisition-capacity-v1.json"
PILOT = core.ROOT / "dusk-acquisition-identity-v1-source/tools/balance_pilot.gd"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"ChoiceScreen capacity mismatch: {label}")


def cache_object(digest: str) -> dict[str, Any]:
    path = core.CACHE / f"{digest}.json"
    require(f"cache {digest} exists", path.is_file())
    require(f"cache {digest} identity", core.file_sha(path) == digest)
    value = json.loads(path.read_text())
    require(f"cache {digest} JSON type", isinstance(value, dict))
    return value


def verify_file(path: str, digest: str) -> None:
    file_path = core.ROOT / path
    require(f"{path} exists", file_path.is_file())
    require(f"{path} identity", core.file_sha(file_path) == digest)


def scores(policy: dict[str, Any], cards: dict[str, Any]) -> dict[str, float]:
    return {
        card_id: scoring.card_score(policy, card_id, cards[card_id])
        for card_id in ("executioner", "guardedStrike")
    }


def decision(policy: dict[str, Any], cards: dict[str, Any]) -> tuple[str, dict[str, float]]:
    values = scores(policy, cards)
    best = "executioner" if values["executioner"] >= values["guardedStrike"] \
        else "guardedStrike"
    return (best if values[best] >= float(policy["cardDecline"]) else ""), values


def verify_inputs(protocol: dict[str, Any]) -> dict[str, Any]:
    immutable = protocol["immutableInputs"]
    require("runner identity", core.file_sha(Path(__file__)) == immutable["runnerSha256"])
    require("task capsule identity", core.file_sha(core.ROOT / "task-capsule.json") ==
            immutable["taskCapsuleSha256"])
    require("scoring helper identity", core.file_sha(Path(scoring.__file__)) ==
            immutable["scoringHelperSha256"])
    require("prototype Pilot identity", core.file_sha(PILOT) == immutable["pilotSha256"])
    pilot = PILOT.read_text()
    for anchor in protocol["selectorContract"]["sourceAnchors"]:
        require(f"Pilot anchor {anchor}", anchor in pilot)
    for path, digest in protocol["evidenceSha256"].items():
        verify_file(path, digest)
    return {
        "sourceCommit": immutable["sourceCommit"],
        "taskCapsuleSha256": immutable["taskCapsuleSha256"],
        "scoringHelperSha256": immutable["scoringHelperSha256"],
        "pilotSha256": immutable["pilotSha256"],
        "runnerSha256": immutable["runnerSha256"],
    }


def analyse(protocol: dict[str, Any]) -> tuple[dict[str, Any], dict[str, Any]]:
    cache = {name: cache_object(digest)
             for name, digest in protocol["cacheObjects"].items()}
    require("cache object count", len(cache) == protocol["budget"]["maximumCacheObjectsRead"])
    baseline_plan = cache["baselinePlan"]
    baseline_output = cache["baselineOutput"]
    direct_plan = cache["directPlan"]
    direct_output = cache["directOutput"]
    content = cache["content"]
    require("baseline output plan", baseline_output["planSha256"] ==
            protocol["cacheObjects"]["baselinePlan"])
    require("direct output plan", direct_output["planSha256"] ==
            protocol["cacheObjects"]["directPlan"])
    for label, output in (("baseline", baseline_output), ("direct", direct_output)):
        content_identity = output["contentIdentity"]
        require(f"{label} source commit", content_identity["commit"] ==
                protocol["immutableInputs"]["sourceCommit"])
        require(f"{label} content", content_identity["contentFileSha256"] ==
                protocol["cacheObjects"]["content"])
        require(f"{label} Godot identity", content_identity["godot"] ==
                protocol["immutableInputs"]["outputGodotIdentity"])
        require(f"{label} stage identity", content_identity["stage"] ==
                protocol["immutableInputs"]["stageIdentity"])
    cohort = protocol["cohort"]
    require("baseline plan cardinality", len(baseline_plan["rows"]) == cohort["rows"])
    require("baseline output cardinality", len(baseline_output["rows"]) == cohort["rows"])
    require("direct plan cardinality", len(direct_plan["rows"]) ==
            protocol["directAnchors"]["rows"])
    require("direct output cardinality", len(direct_output["rows"]) ==
            protocol["directAnchors"]["rows"])
    cards = content["cards"]
    require("consumer definitions", {
        card_id: cards[card_id] for card_id in ("executioner", "guardedStrike")
    } == protocol["selectorContract"]["consumerDefinitions"])

    direct_by_id = {str(row["id"]): row for row in direct_output["rows"]}
    require("direct identities", set(direct_by_id) == {
        str(row["id"]) for row in direct_plan["rows"]
    })
    for spec in direct_plan["rows"]:
        row = direct_by_id[str(spec["id"])]
        choice, values = decision(row["policy"], cards)
        require(f"{spec['id']} Scoreline score", values["executioner"] ==
                float(row["scorelineScore"]))
        require(f"{spec['id']} Afterimage score", values["guardedStrike"] ==
                float(row["afterimageScore"]))
        require(f"{spec['id']} decline threshold", float(row["cardDecline"]) ==
                float(row["policy"]["cardDecline"]))
        if row["aspect"] == "duskblade" and row["acquisition"] == "pilot":
            require(f"{spec['id']} selector decision", row["choice"] == choice)

    policies: dict[int, dict[str, Any]] = {}
    outcomes: dict[int, list[str]] = {}
    seen_seeds: dict[int, set[int]] = {}
    faults = 0
    for spec, row in zip(baseline_plan["rows"], baseline_output["rows"]):
        policy_index = int(spec["policyIndex"])
        require("baseline arm", spec.get("acquisition", "") == "")
        require("baseline policy root", int(spec["policyRoot"]) == cohort["policyRoot"])
        require("baseline aspect", spec["aspect"] == row["aspect"] == cohort["aspect"])
        require("baseline Vow", int(spec["vow"]) == int(row["vow"]) == cohort["vow"])
        require("baseline seed", int(spec["seed"]) == int(row["seed"]))
        canonical_policy = core.canonical(row["policy"])
        if policy_index in policies:
            require(f"policy {policy_index} identity",
                    canonical_policy == core.canonical(policies[policy_index]))
        else:
            policies[policy_index] = row["policy"]
            outcomes[policy_index] = []
            seen_seeds[policy_index] = set()
        outcomes[policy_index].append(str(row["outcome"]))
        seen_seeds[policy_index].add(int(spec["seed"]))
        faults += int(bool(row.get("error")) or row.get("outcome") in ("stall", "error"))
    require("complete policy repertoire", set(policies) == set(range(cohort["policyCount"])))
    require("complete policy cohorts", all(
        len(values) == len(cohort["simulationSeeds"]) for values in outcomes.values()
    ))
    require("complete policy seed identities", all(
        seeds == set(cohort["simulationSeeds"]) for seeds in seen_seeds.values()
    ))

    choices: dict[str, set[int]] = {"executioner": set(), "guardedStrike": set(), "decline": set()}
    score_rows: dict[int, dict[str, Any]] = {}
    ties: set[int] = set()
    for policy_index, policy in policies.items():
        selected, values = decision(policy, cards)
        label = selected or "decline"
        choices[label].add(policy_index)
        if values["executioner"] == values["guardedStrike"]:
            ties.add(policy_index)
        score_rows[policy_index] = {
            "executioner": values["executioner"],
            "guardedStrike": values["guardedStrike"],
            "cardDecline": float(policy["cardDecline"]),
            "decision": label,
            "marginToAlternative": abs(values["executioner"] - values["guardedStrike"]),
            "marginToDecline": max(values.values()) - float(policy["cardDecline"]),
        }

    viable = {
        name: {policy for policy in members if "win" in outcomes[policy]}
        for name, members in choices.items()
    }
    gates = protocol["gates"]
    gate_results = {
        "executionerSupport": len(choices["executioner"]) >= gates["minimumPoliciesPerChoice"],
        "guardedStrikeSupport": len(choices["guardedStrike"]) >= gates["minimumPoliciesPerChoice"],
        "declineSupport": len(choices["decline"]) >= gates["minimumDeclinePolicies"],
        "executionerViability": len(viable["executioner"]) >=
            gates["minimumViablePoliciesPerDecision"],
        "guardedStrikeViability": len(viable["guardedStrike"]) >=
            gates["minimumViablePoliciesPerDecision"],
        "declineViability": len(viable["decline"]) >=
            gates["minimumViablePoliciesPerDecision"],
        "noOrderTies": len(ties) <= gates["maximumTiedPolicies"],
        "reliability": faults <= gates["maximumBaselineFaultRows"],
    }
    result = {
        "counts": {
            "executionerPolicies": len(choices["executioner"]),
            "guardedStrikePolicies": len(choices["guardedStrike"]),
            "declinePolicies": len(choices["decline"]),
            "executionerViablePolicies": len(viable["executioner"]),
            "guardedStrikeViablePolicies": len(viable["guardedStrike"]),
            "declineViablePolicies": len(viable["decline"]),
            "tiedPolicies": len(ties),
            "baselineFaultRows": faults,
        },
        "policySets": {
            **{name: sorted(values) for name, values in choices.items()},
            **{f"{name}Viable": sorted(values) for name, values in viable.items()},
            "ties": sorted(ties),
        },
        "policyScores": {str(key): value for key, value in sorted(score_rows.items())},
        "gateResults": gate_results,
        "eligible": all(gate_results.values()),
    }
    preflight = {
        "status": "PASS",
        "cacheObjectsVerified": len(cache),
        "directScoreAnchorsExact": True,
        "directSelectorAnchorsExact": True,
        "policyIdentities": len(policies),
        "cachedWholeRunRowsRead": len(baseline_output["rows"]),
        "cachedDirectRowsRead": len(direct_output["rows"]),
    }
    return preflight, result


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite completed ChoiceScreen capacity")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    observed_inputs: dict[str, Any] = {}
    preflight: dict[str, Any] = {"status": "UNRESOLVED"}
    capacity: dict[str, Any] = {}
    ledger_before: dict[str, Any] = {}
    ledger_after: dict[str, Any] = {}
    error = ""
    try:
        observed_inputs = verify_inputs(protocol)
        ledger_before = identity.ledger_identity()
        require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
        preflight, capacity = analyse(protocol)
        ledger_after = identity.ledger_identity()
        require("zero-row ledger identity", ledger_after == ledger_before)
    except (FileNotFoundError, json.JSONDecodeError, KeyError, TypeError,
            ValueError, RuntimeError) as caught:
        error = str(caught)
    elapsed = time.monotonic() - started
    if not error and elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        error = "ChoiceScreen capacity exceeded its wall-time ceiling"

    if error:
        boundary, outcome = 3, "inconclusive"
        decision_name = "record-choice-screen-capacity-inconclusive"
    elif capacity["eligible"]:
        boundary, outcome = 1, "success"
        decision_name = "freeze-choice-screen-capacity-for-enabled-support-panel"
    else:
        boundary, outcome = 2, "futility"
        decision_name = "close-choice-screen-selector-at-capacity"
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": boundary,
        "decision": decision_name,
        "outcomeClass": outcome,
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "observedInputs": observed_inputs,
        "preflight": preflight,
        "capacity": capacity,
        "executionError": error,
        "newSimulatorObservationRows": 0,
        "newIdentityObservationRows": 0,
        "newSupportRows": 0,
        "newCausalRows": 0,
        "newLedgerRows": 0,
        "GodotProcesses": 0,
        "protectedSeedRows": ledger_after.get(
            "protectedSeedRows", ledger_before.get("protectedSeedRows", 0),
        ),
        "maximumModelContextTokens": 0,
        "wallTimeSeconds": elapsed,
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "authority": protocol["decisionRules"][f"{outcome}Authority"],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS",
        "decisionBoundary": boundary,
        "decision": decision_name,
        "newSimulatorObservationRows": 0,
        "summarySha256": core.file_sha(SUMMARY),
    }))


if __name__ == "__main__":
    main()
