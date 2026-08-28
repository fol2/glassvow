#!/usr/bin/env python3
"""Zero-row event/shop capacity screen for deed-unlocked Novaflare."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any, Callable

import post_v38_action_grammar_inventory as trace
import post_v38_knob_identity as identity
import post_v38_novaflare_capacity as nova
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-novaflare-nonreward-capacity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-novaflare-nonreward-capacity-v1.json"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Novaflare non-reward capacity mismatch: {label}")


def main_blob(path: str) -> bytes:
    return subprocess.run(
        ["git", "show", f"HEAD:{path}"], cwd=core.SOURCE,
        check=True, capture_output=True,
    ).stdout


def weight(policy: dict[str, Any], group: str, key: str) -> float:
    return float(policy[group][key])


def status_value(policy: dict[str, Any], status_id: str, n: int) -> float:
    if status_id == "poison":
        return float(n * (n + 1)) * weight(policy, "status", "poisonDusk")
    if status_id == "vulnerable":
        return float(n) * weight(policy, "status", "vulnerableDusk")
    if status_id == "weak":
        return float(n) * weight(policy, "status", "weak")
    if status_id == "str":
        return float(n) * weight(policy, "status", "str")
    if status_id in ("dex", "metallicize"):
        return float(n) * weight(policy, "status", "dex")
    if status_id == "regen":
        return float(n) * weight(policy, "status", "regen")
    if status_id == "venomous":
        return weight(policy, "status", "venomousDusk")
    if status_id == "ritual":
        return float(n) * weight(policy, "status", "ritual")
    if status_id in ("barricade", "energized"):
        return weight(policy, "status", "barricade")
    if status_id == "beacon":
        return weight(policy, "status", "beaconDusk")
    if status_id in ("nightsight", "emberflow"):
        return weight(policy, "status", "nightsight")
    return 0.0


def special_value(policy: dict[str, Any], special_id: str) -> float:
    if special_id == "catalyst":
        return weight(policy, "special", "catalystDusk")
    if special_id == "shatterEcho":
        return weight(policy, "special", "shatterEchoDusk")
    if special_id in ("execute", "momentum"):
        return weight(policy, "special", "execute")
    if special_id in ("leech", "devour", "phantom"):
        return weight(policy, "special", "leech")
    if special_id in ("doubleBlock", "flawless", "emberNova"):
        return weight(policy, "special", "doubleBlock")
    if special_id in ("pyreTithe", "emberdance"):
        return weight(policy, "special", "pyreTithe")
    return weight(policy, "special", "fallback")


def card_score(policy: dict[str, Any], card_id: str, card: dict[str, Any]) -> float:
    score = float(policy["card"]["rarity"].get(card.get("rarity", "starter"), 0.0))
    score -= float(card.get("cost", 0))
    for effect in card.get("effects", []):
        kind = str(effect.get("kind", ""))
        n = float(effect.get("n", 0))
        if kind == "dmg":
            score += n * float(effect.get("times", 1))
        elif kind in ("block", "heal"):
            score += n * weight(policy, "card", "blockHeal")
        elif kind in ("draw", "energy"):
            score += n * weight(policy, "card", "drawEnergy")
        elif kind == "chip":
            score += n * weight(policy, "card", "chipDusk")
        elif kind == "ember":
            score += n * weight(policy, "card", "ember")
        elif kind == "loseHp":
            score -= n * weight(policy, "card", "loseHp")
        elif kind == "status":
            score += status_value(policy, str(effect.get("id", "")), int(n))
        elif kind == "special":
            score += special_value(policy, str(effect.get("id", "")))
    if card.get("type") == "power":
        score += weight(policy, "card", "power")
    score += float(card.get("chip", 0)) * weight(policy, "card", "chipDusk")
    if card_id in ("eclipseSlash", "chisel", "warCry", "limitBreak",
                   "resonantLance", "executioner"):
        score += weight(policy, "card", "aspectBonus")
    return score


def robust_policies(
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


def assess(
    block: str,
    selector: set[int],
    opportunity: Callable[[dict[str, Any]], bool],
    rows: dict[tuple[int, int], dict[str, Any]],
    protocol: dict[str, Any],
    scoreline: set[int],
    afterimage: set[int],
    baseline_faults: int,
) -> dict[str, Any]:
    cohort = protocol["cohort"]
    robust_opportunity = robust_policies(rows, protocol, opportunity)
    zero_opportunity = {
        policy_index for policy_index in range(cohort["policyCount"])
        if not any(opportunity(rows[(policy_index, seed)])
                   for seed in cohort["simulationSeeds"])
    }
    active = selector & robust_opportunity
    inactive = (set(range(cohort["policyCount"])) - selector) | zero_opportunity
    ambiguous = set(range(cohort["policyCount"])) - active - inactive
    viable = {
        policy_index for policy_index in active
        if any(opportunity(rows[(policy_index, seed)])
               and rows[(policy_index, seed)].get("outcome") == "win"
               for seed in cohort["simulationSeeds"])
    }
    separations = {
        "scoreline": nova.separation(active, scoreline),
        "afterimage": nova.separation(active, afterimage),
    }
    counts = {
        "selectorPolicies": len(selector),
        "robustOpportunityPolicies": len(robust_opportunity),
        "zeroOpportunityPolicies": len(zero_opportunity),
        "potentialActivePolicies": len(active),
        "exactInactivePolicies": len(inactive),
        "ambiguousPolicies": len(ambiguous),
        "viablePotentialActivePolicies": len(viable),
        "baselineFaultRows": baseline_faults,
    }
    gates = protocol["gates"]

    def separated(result: dict[str, Any]) -> bool:
        return (result["candidateOnlyPolicies"] >= gates["minimumCandidateOnlyPolicies"]
                and result["anchorOnlyPolicies"] >= gates["minimumAnchorOnlyPolicies"]
                and result["jaccard"] <= gates["maximumAnchorJaccard"])

    gate_results = {
        "selectorSupport": counts["selectorPolicies"] >= gates["minimumSelectorPolicies"],
        "channelOpportunity": counts["robustOpportunityPolicies"] >=
            gates["minimumRobustOpportunityPolicies"],
        "potentialActive": counts["potentialActivePolicies"] >=
            gates["minimumPotentialActivePolicies"],
        "inactivity": counts["exactInactivePolicies"] >= gates["minimumInactivePolicies"],
        "viability": counts["viablePotentialActivePolicies"] >=
            gates["minimumViablePotentialActivePolicies"],
        "scorelineSeparation": separated(separations["scoreline"]),
        "afterimageSeparation": separated(separations["afterimage"]),
        "reliability": baseline_faults <= gates["maximumBaselineFaultRows"],
    }
    return {
        "block": block,
        "counts": counts,
        "separation": separations,
        "gateResults": gate_results,
        "passes": all(gate_results.values()),
        "policySets": {
            "selector": sorted(selector),
            "robustOpportunity": sorted(robust_opportunity),
            "zeroOpportunity": sorted(zero_opportunity),
            "potentialActive": sorted(active),
            "exactInactive": sorted(inactive),
            "ambiguous": sorted(ambiguous),
            "viablePotentialActive": sorted(viable),
        },
    }


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the Novaflare non-reward summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    require("runner SHA", core.file_sha(Path(__file__)) ==
            protocol["immutableInputs"]["runnerSha256"])
    require("source commit", subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=core.SOURCE, check=True,
        text=True, capture_output=True,
    ).stdout.strip() == protocol["immutableInputs"]["sourceCommit"])
    blobs = {
        path: main_blob(path) for path in protocol["immutableInputs"]["sourceSha256"]
    }
    for path, expected_sha in protocol["immutableInputs"]["sourceSha256"].items():
        require(f"{path} SHA", core.sha(blobs[path]) == expected_sha)
    rewards_text = blobs["domain/rules/rewards.gd"].decode()
    pilot_text = blobs["tools/balance_pilot.gd"].decode()
    sim_text = blobs["tools/balance_sim.gd"].decode()
    require("event source", 'op.has("pickCard")' in rewards_text
            and "roll_event_cards(run" in rewards_text)
    require("event choice count", '"pickCard": 5' in blobs["content/full-content.json"].decode())
    require("event bypasses decline", '"card":\n\t\t\tfor pending_card: Variant' in sim_text)
    require("shop source", 'for tier: String in ["common", "common", "uncommon", "uncommon", "rare"]'
            in rewards_text)
    require("shop strict ratio", "if ratio > best_ratio:" in pilot_text)
    require("shop threshold", "var best_ratio: float = shop_min_ratio" in pilot_text)
    require("generic combat discriminator only",
            'score += float(loss) * _w("combat", "loss")' in pilot_text
            and "novaflare" not in pilot_text)
    for name, spec in protocol["priorEvidence"].items():
        path = core.ROOT / spec["path"]
        require(f"{name} SHA", core.file_sha(path) == spec["sha256"])
        require(f"{name} decision", json.loads(path.read_text())["decision"] ==
                spec["decision"])
    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])

    baseline_path = core.CACHE / f"{protocol['baseline']['outputSha256']}.json"
    trace_path = core.CACHE / f"{protocol['traceEvidence']['outputSha256']}.json"
    content_path = core.CACHE / f"{protocol['baseline']['contentSha256']}.json"
    require("baseline output SHA", core.file_sha(baseline_path) ==
            protocol["baseline"]["outputSha256"])
    require("trace output SHA", core.file_sha(trace_path) ==
            protocol["traceEvidence"]["outputSha256"])
    require("content SHA", core.file_sha(content_path) ==
            protocol["baseline"]["contentSha256"])
    baseline_output = json.loads(baseline_path.read_text())
    trace_output = json.loads(trace_path.read_text())
    content = json.loads(content_path.read_text())
    require("current-main content SHA", core.sha(blobs["content/full-content.json"]) ==
            protocol["baseline"]["contentSha256"])
    require("baseline plan SHA", baseline_output["planSha256"] ==
            protocol["baseline"]["planSha256"])
    require("trace plan SHA", trace_output["planSha256"] ==
            protocol["traceEvidence"]["planSha256"])
    candidate = protocol["candidate"]
    require("Novaflare definition", content["cards"]["novaflare"] ==
            candidate["definition"])
    require("spendthrift unlocks", content["deeds"]["spendthrift"]["unlocks"] ==
            candidate["spendthriftUnlocks"])

    cohort = protocol["cohort"]
    baseline_rows = {
        (int(row["policyIndex"]), int(row["seed"])): row
        for row in baseline_output["rows"] if row.get("arm") == "policy"
        and row.get("aspect") == cohort["aspect"] and int(row.get("vow", -1)) == cohort["vow"]
    }
    rows = {
        (int(row["policyIndex"]), int(row["seed"])): row
        for row in trace_output["rows"] if row.get("arm") == "current"
        and row.get("aspect") == cohort["aspect"] and int(row.get("vow", -1)) == cohort["vow"]
    }
    expected = cohort["policyCount"] * len(cohort["simulationSeeds"])
    require("baseline rectangle", len(baseline_rows) == expected)
    require("trace rectangle", len(rows) == expected)
    for key, row in rows.items():
        require("trace-current frozen identity",
                trace.canonical_without(row) == trace.canonical_without(baseline_rows[key]))
    policies: dict[int, dict[str, Any]] = {}
    for policy_index in range(cohort["policyCount"]):
        snapshots = {core.canonical(rows[(policy_index, seed)]["policy"])
                     for seed in cohort["simulationSeeds"]}
        require(f"policy {policy_index} identity", len(snapshots) == 1)
        policies[policy_index] = rows[(policy_index, cohort["simulationSeeds"][0])]["policy"]

    enabled_pools = {tier: list(ids) for tier, ids in content["cardPools"].items()}
    enabled_pools["rare"].append("novaflare")
    enabled_pools["uncommon"].append("emberdance")
    all_cards = [card_id for tier in ("common", "uncommon", "rare")
                 for card_id in enabled_pools[tier]]
    event_selector: set[int] = set()
    shop_selector: set[int] = set()
    for policy_index, policy in policies.items():
        score = card_score(policy, "novaflare", content["cards"]["novaflare"])
        require(f"candidate score {policy_index}", score == nova.candidate_score(policy))
        lower_or_equal = sum(
            card_id != "novaflare"
            and card_score(policy, card_id, content["cards"][card_id]) <= score
            for card_id in all_cards
        )
        if lower_or_equal >= protocol["eventBlock"]["otherCardsRequired"]:
            event_selector.add(policy_index)
        if score / float(protocol["shopBlock"]["minimumPossibleRarePrice"]) > \
                float(policy["shopMinRatio"]):
            shop_selector.add(policy_index)

    def event_opportunity(row: dict[str, Any]) -> bool:
        return any(node.get("type") == "event"
                   for node in row.get("trajectory", {}).get("nodes", []))

    def shop_opportunity(row: dict[str, Any]) -> bool:
        return any(node.get("type") == "shop"
                   for node in row.get("trajectory", {}).get("nodes", []))

    def afterimage_route(row: dict[str, Any]) -> bool:
        return int(row.get("packageEvents", {}).get("afterimageGuardDamage", 0)) > 0

    scoreline = trace.policy_set(rows, protocol, trace.scoreline_route)
    afterimage = trace.policy_set(rows, protocol, afterimage_route)
    require("Scoreline anchor", sorted(scoreline) ==
            protocol["sharedAnchors"]["scoreline"]["policies"])
    require("Afterimage anchor", sorted(afterimage) ==
            protocol["sharedAnchors"]["afterimage"]["policies"])
    baseline_faults = sum(
        row.get("outcome") in ("stall", "error") or bool(row.get("error"))
        for row in rows.values()
    )
    assessments = [
        assess("shop", shop_selector, shop_opportunity, rows, protocol,
               scoreline, afterimage, baseline_faults),
        assess("event", event_selector, event_opportunity, rows, protocol,
               scoreline, afterimage, baseline_faults),
    ]
    passing = [result["block"] for result in assessments if result["passes"]]
    selected = next((block for block in protocol["selectionOrder"] if block in passing), None)
    elapsed = time.monotonic() - started
    if elapsed > float(protocol["budget"]["maximumWallTimeSeconds"]):
        boundary, decision, selected = (
            3, "record-novaflare-nonreward-capacity-inconclusive-at-cap", None)
    elif selected is not None:
        boundary, decision = 1, f"authorise-novaflare-{selected}-identity-preflight"
    else:
        boundary, decision = 2, "close-deed-unlocked-ember-reserve-damage-family"
    ledger_after = identity.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": boundary,
        "decision": decision,
        "selectedBlock": selected,
        "passingBlocks": passing,
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "assessments": assessments,
        "sharedAnchors": {"scoreline": sorted(scoreline), "afterimage": sorted(afterimage)},
        "traceIdentity": {"rows": len(rows), "pathRngPolicyResultExact": True},
        "newSimulatorObservationRows": 0,
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "newLedgerRows": 0,
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "maximumModelContextTokens": 0,
        "wallTimeSeconds": elapsed,
        "authority": protocol["decisionRules"][
            "successAuthority" if boundary == 1 else (
                "futilityAuthority" if boundary == 2 else "inconclusiveAuthority")],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS",
        "decision": decision,
        "decisionBoundary": boundary,
        "selectedBlock": selected,
        "summarySha256": core.file_sha(SUMMARY),
        "newSimulatorObservationRows": 0,
    }))


if __name__ == "__main__":
    main()
