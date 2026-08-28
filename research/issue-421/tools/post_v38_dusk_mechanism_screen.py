#!/usr/bin/env python3
"""Zero-row source-and-policy screen for the next Duskblade mechanism."""

from __future__ import annotations

import itertools
import json
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import post_v38_ward_whole_run_discovery_audit as ward
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-dusk-mechanism-screen-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-dusk-mechanism-screen-v1.json"


def require_equal(label: str, left: Any, right: Any) -> None:
    if left != right:
        raise RuntimeError(f"Dusk mechanism screen mismatch: {label}")


def git_blob(commit: str, path: str) -> bytes:
    return subprocess.run(
        ["git", "show", f"{commit}:{path}"], cwd=core.SOURCE, check=True,
        capture_output=True,
    ).stdout


def relic_score(policy: dict[str, Any], relic_id: str, rarity: str,
                dusk_bonus_ids: set[str]) -> int:
    score = float(policy["relics"].get(
        relic_id, policy["relicRarity"].get(rarity, policy["relicFallback"])
    ))
    if relic_id in dusk_bonus_ids:
        score += float(policy["relicDuskBonus"])
    return int(score)


def policy_rows(output: dict[str, Any], protocol: dict[str, Any]) \
        -> tuple[list[dict[str, Any]], dict[int, dict[str, Any]]]:
    cohort = protocol["cohort"]
    rows = [
        row for row in output["rows"]
        if row.get("arm") == "policy" and row.get("aspect") == "duskblade"
    ]
    require_equal("policy row count", len(rows), cohort["policyRows"])
    require_equal("policy roots", {int(row["policyRoot"]) for row in rows},
                  {cohort["policyRoot"]})
    require_equal("policy indices", {int(row["policyIndex"]) for row in rows},
                  set(range(cohort["policyCount"])))
    require_equal("policy seeds", {int(row["seed"]) for row in rows},
                  set(cohort["simulationSeeds"]))
    snapshots: dict[int, dict[str, Any]] = {}
    identities: dict[int, set[str]] = {}
    for row in rows:
        index = int(row["policyIndex"])
        identities.setdefault(index, set()).add(
            core.sha(core.canonical(row["policy"]).encode())
        )
        snapshots[index] = row["policy"]
    require_equal("policy snapshot identity", all(len(value) == 1
                                                   for value in identities.values()), True)
    return rows, snapshots


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the Dusk mechanism screen")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    runner_sha = core.file_sha(Path(__file__))
    require_equal("runner SHA", runner_sha, protocol["immutableInputs"]["runnerSha256"])

    evidence: dict[str, dict[str, Any]] = {}
    for name, spec in protocol["immutableScientificEvidence"].items():
        if "commit" in spec:
            blob = git_blob(spec["commit"], spec["path"])
            require_equal(f"{name} SHA", core.sha(blob), spec["sha256"])
            evidence[name] = json.loads(blob)
        else:
            path = core.ROOT / spec["path"]
            require_equal(f"{name} SHA", core.file_sha(path), spec["sha256"])
            evidence[name] = json.loads(path.read_text())

    graph = evidence["issue524MechanismGraph"]
    dusk_edges = [
        edge for edge in graph["candidateEdges"]
        if edge["aspectScope"] == "duskblade"
    ]
    require_equal("Dusk graph edge count", len(dusk_edges),
                  protocol["sourceFilter"]["duskEdgeCount"])
    require_equal("Dusk graph mediators", {edge["mediator"] for edge in dusk_edges},
                  {protocol["sourceFilter"]["requiredMediator"]})
    excluded = set(protocol["sourceFilter"]["excludedTestedTargets"])
    eligible = [edge for edge in dusk_edges if edge["target"] not in excluded]
    require_equal("eligible targets", {edge["target"] for edge in eligible},
                  {protocol["candidate"]["graphTarget"]})
    require_equal("eligible source aliases", len(eligible),
                  protocol["sourceFilter"]["eligibleSourceAliases"])
    gate = evidence["issue524PackageGate"]
    tested_nodes = set(gate["packages"]["dusk-shatter-relics"]["nodes"])
    require_equal("tested target exclusion", tested_nodes,
                  set(protocol["sourceFilter"]["testedPackageNodes"]))
    require_equal("retained inventory decision",
                  evidence["retainedDuskInventory"]["decision"],
                  "close-immutable-retained-dusk-inventory")

    source = protocol["sourceIdentity"]
    for name, spec in source["files"].items():
        require_equal(f"source {name} SHA", core.file_sha(core.SOURCE / spec["path"]),
                      spec["sha256"])
    content = json.loads((core.SOURCE / source["files"]["content"]["path"]).read_text())
    candidate = protocol["candidate"]
    crown_id = candidate["relicId"]
    require_equal("candidate relic definition", content["relics"][crown_id],
                  candidate["definition"])
    boss_pool = list(map(str, content["relicPools"]["boss"]))
    require_equal("boss relic pool", boss_pool, candidate["bossPool"])

    ledger_before = identity.ledger_identity()
    require_equal("ledger freeze", ledger_before, protocol["ledgerFreeze"])
    output_spec = protocol["baseline"]["output"]
    output_path = core.CACHE / f"{output_spec['sha256']}.json"
    require_equal("baseline output SHA", core.file_sha(output_path),
                  output_spec["sha256"])
    output = json.loads(output_path.read_text())
    require_equal("baseline content identity",
                  output["contentIdentity"]["contentFileSha256"],
                  protocol["baseline"]["contentSha256"])
    rows, snapshots = policy_rows(output, protocol)

    dusk_bonus_ids = set(candidate["duskBonusRelics"])
    other_boss = [relic_id for relic_id in boss_pool if relic_id != crown_id]
    require_equal("other boss relic count", len(other_boss), 4)
    preference: dict[int, dict[str, Any]] = {}
    for index, policy in snapshots.items():
        crown_score = relic_score(policy, crown_id, "boss", dusk_bonus_ids)
        other_scores = {
            relic_id: relic_score(policy, relic_id, "boss", dusk_bonus_ids)
            for relic_id in other_boss
        }
        pair_wins = sum(
            crown_score > max(other_scores[left], other_scores[right])
            for left, right in itertools.combinations(other_boss, 2)
        )
        preference[index] = {
            "crownScore": crown_score,
            "otherScores": other_scores,
            "strictPairWins": pair_wins,
            "strictPairCount": 6,
            "robustSelector": pair_wins == 6,
            "robustDecliner": pair_wins == 0,
        }

    by_policy: dict[int, list[dict[str, Any]]] = {}
    for row in rows:
        by_policy.setdefault(int(row["policyIndex"]), []).append(row)
    crown_acquired = {
        index for index, group in by_policy.items()
        if any(crown_id in set(map(str, row.get("relics", []))) for row in group)
    }
    shatter_capable = {
        index for index, group in by_policy.items()
        if any(sum(int(fight.get("shatters", 0)) for fight in row.get("fights", [])) > 0
               for row in group)
    }
    crown_active = crown_acquired & shatter_capable
    boss_reachable = {
        index for index, group in by_policy.items()
        if any(len(row.get("economy", [])) > 0 for row in group)
    }
    robust_selectors = {
        index for index, result in preference.items() if result["robustSelector"]
    }
    robust_decliners = {
        index for index, result in preference.items() if result["robustDecliner"]
    }
    projected_active = robust_selectors & boss_reachable & shatter_capable
    gates = protocol["gates"]
    gate_results = {
        "robustSelectors": len(robust_selectors) >= gates["minimumRobustSelectors"],
        "robustDecliners": len(robust_decliners) >= gates["minimumRobustDecliners"],
        "projectedActive": len(projected_active) >= gates["minimumProjectedActivePolicies"],
        "bossReachable": len(boss_reachable) >= gates["minimumBossReachablePolicies"],
        "shatterCapable": len(shatter_capable) >= gates["minimumShatterCapablePolicies"],
    }
    clear = all(gate_results.values())
    decision_boundary = 1 if clear else 2
    decision = "freeze-dusk-shatter-threshold-crown-preflight" if clear \
        else "close-dusk-shatter-threshold-crown-screen"

    if time.monotonic() - started > float(protocol["budget"]["maximumWallTimeSeconds"]):
        raise TimeoutError("Dusk mechanism screen exceeded its frozen ceiling")
    ledger_after = identity.ledger_identity()
    require_equal("append-only ledger", ledger_before, ledger_after)
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": decision_boundary,
        "decision": decision,
        "protocolSha256": protocol_sha,
        "runnerSha256": runner_sha,
        "sourceFilter": {
            "duskEdges": len(dusk_edges),
            "mediator": protocol["sourceFilter"]["requiredMediator"],
            "excludedTestedTargets": sorted(excluded),
            "eligibleTarget": candidate["graphTarget"],
            "sourceAliasesCollapsed": len(eligible),
        },
        "candidate": candidate,
        "currentMainSupport": {
            "crownAcquiredPolicies": len(crown_acquired),
            "crownActivePolicies": len(crown_active),
            "crownInactivePolicies": protocol["cohort"]["policyCount"] - len(crown_active),
            "bossReachablePolicies": len(boss_reachable),
            "shatterCapablePolicies": len(shatter_capable),
        },
        "offerInclusionDecisionValue": {
            "robustSelectors": len(robust_selectors),
            "robustDecliners": len(robust_decliners),
            "contextDependentPolicies": protocol["cohort"]["policyCount"]
                - len(robust_selectors) - len(robust_decliners),
            "projectedActivePolicies": len(projected_active),
            "pairWinsHistogram": {
                str(wins): sum(result["strictPairWins"] == wins
                               for result in preference.values())
                for wins in range(7)
            },
            "definition": protocol["counterfactualDefinition"],
        },
        "gateResults": gate_results,
        "newSimulatorObservationRows": 0,
        "newLedgerRows": 0,
        "protectedSeedRows": 0,
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "authority": protocol["decisionRules"][
            "successAuthority" if clear else "futilityAuthority"
        ],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS",
        "decision": decision,
        "decisionBoundary": decision_boundary,
        "summarySha256": core.file_sha(SUMMARY),
        "newSimulatorObservationRows": 0,
    }))


if __name__ == "__main__":
    main()
