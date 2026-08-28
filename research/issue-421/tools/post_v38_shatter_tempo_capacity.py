#!/usr/bin/env python3
"""Zero-row capacity screen for one Duskblade Shatter-to-heavy-Attack relay."""

from __future__ import annotations

import json
import subprocess
import time
from collections import Counter
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-shatter-tempo-capacity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-shatter-tempo-capacity-v1.json"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Shatter-tempo capacity mismatch: {label}")


def policy_hits(rows: list[dict[str, Any]], predicate: Any) -> dict[int, int]:
    hits: Counter[int] = Counter()
    for row in rows:
        if predicate(row):
            hits[int(row["policyIndex"])] += 1
    return dict(hits)


def shatters(row: dict[str, Any]) -> int:
    return sum(int(fight.get("shatters", 0)) for fight in row.get("fights", []))


def played(row: dict[str, Any], card_id: str) -> int:
    return int((row.get("packageEvents") or {}).get(f"{card_id}Played", 0))


def offered(row: dict[str, Any], card_id: str) -> int:
    return int((row.get("packageEvents") or {}).get(f"{card_id}Offered", 0))


def classify(hits: dict[int, int], count: int, robust: int) -> tuple[set[int], set[int], set[int]]:
    active = {index for index in range(count) if hits.get(index, 0) >= robust}
    inactive = {index for index in range(count) if hits.get(index, 0) == 0}
    return active, inactive, set(range(count)) - active - inactive


def self_check() -> None:
    active, inactive, ambiguous = classify({0: 2, 1: 1}, 4, 2)
    require("classification self-check", active == {0} and inactive == {2, 3}
            and ambiguous == {1})


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the Shatter-tempo capacity screen")
    self_check()
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    require("runner SHA", core.file_sha(Path(__file__)) ==
            protocol["immutableInputs"]["runnerSha256"])
    require("source commit", subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=core.SOURCE, check=True,
        text=True, capture_output=True,
    ).stdout.strip() == protocol["immutableInputs"]["sourceCommit"])

    for name, spec in protocol["priorEvidence"].items():
        path = core.ROOT / spec["path"]
        require(f"{name} SHA", core.file_sha(path) == spec["sha256"])
        payload = json.loads(path.read_text())
        for key, expected in spec.get("required", {}).items():
            value: Any = payload
            for part in key.split("."):
                value = value[part]
            require(f"{name} {key}", value == expected)

    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    baseline = protocol["baseline"]
    content_path = core.CACHE / f"{baseline['contentSha256']}.json"
    output_path = core.CACHE / f"{baseline['outputSha256']}.json"
    require("content SHA", core.file_sha(content_path) == baseline["contentSha256"])
    require("output SHA", core.file_sha(output_path) == baseline["outputSha256"])
    content = json.loads(content_path.read_text())
    output = json.loads(output_path.read_text())
    require("plan SHA", output["planSha256"] == baseline["planSha256"])
    require("output content identity", output["contentIdentity"]["contentFileSha256"] ==
            baseline["contentSha256"])

    reward_ids = [*content["cardPools"]["common"], *content["cardPools"]["uncommon"],
                  *content["cardPools"]["rare"]]
    eligible = sorted(card_id for card_id in reward_ids
                      if content["cards"][card_id].get("type") == "attack"
                      and int(content["cards"][card_id].get("cost", 0)) >=
                      int(protocol["sourceFilter"]["minimumPrintedCost"]))
    require("eligible source filter", eligible == sorted(protocol["sourceFilter"]["eligibleCards"]))
    require("eligible cards unlocked", all("locked" not in content["cards"][card_id]
                                            for card_id in eligible))

    cohort = protocol["cohort"]
    rows = [row for row in output["rows"] if row.get("arm") == "policy"
            and row.get("aspect") == cohort["aspect"] and int(row.get("vow", -1)) == cohort["vow"]]
    require("row count", len(rows) == cohort["policyRows"])
    require("policy root", {int(row["policyRoot"]) for row in rows} == {cohort["policyRoot"]})
    require("policy indices", {int(row["policyIndex"]) for row in rows} ==
            set(range(cohort["policyCount"])))
    require("simulation seeds", {int(row["seed"]) for row in rows} ==
            set(cohort["simulationSeeds"]))
    require("rows per policy", Counter(int(row["policyIndex"]) for row in rows) ==
            Counter({index: len(cohort["simulationSeeds"])
                     for index in range(cohort["policyCount"])}))

    heavy_hits = policy_hits(rows, lambda row: shatters(row) > 0 and
                             any(played(row, card_id) > 0 for card_id in eligible))
    source_hits = policy_hits(rows, lambda row: shatters(row) > 0)
    offered_hits = policy_hits(rows, lambda row:
                               any(offered(row, card_id) > 0 for card_id in eligible))
    acquired_hits = policy_hits(rows, lambda row:
                                any(card_id in set(map(str, row.get("deckIds", [])))
                                    for card_id in eligible))
    scoreline_hits = policy_hits(rows, lambda row: played(row, "chisel") > 0
                                 and played(row, "executioner") > 0)
    viable_hits = policy_hits(rows, lambda row: row.get("outcome") == "win")
    robust = int(cohort["minimumRowsPerRobustPolicy"])
    heavy_active, heavy_inactive, heavy_ambiguous = classify(
        heavy_hits, cohort["policyCount"], robust)
    score_active, _, _ = classify(scoreline_hits, cohort["policyCount"], robust)
    source_ready, _, _ = classify(source_hits, cohort["policyCount"], robust)
    offered_policies = {index for index, hits in offered_hits.items() if hits > 0}
    acquired_policies = {index for index, hits in acquired_hits.items() if hits > 0}
    viable_policies = {index for index, hits in viable_hits.items() if hits >= robust}
    used_cards = sorted(card_id for card_id in eligible if any(
        int(row["policyIndex"]) in heavy_active and shatters(row) > 0
        and played(row, card_id) > 0 for row in rows))

    separation = {
        "relayOnly": len(heavy_active - score_active),
        "scorelineOnly": len(score_active - heavy_active),
        "crossActive": len(heavy_active & score_active),
        "jaccard": (len(heavy_active & score_active) / len(heavy_active | score_active)
                    if heavy_active | score_active else 1.0),
    }
    counts = {
        "sourceReadyPolicies": len(source_ready),
        "robustActivePolicies": len(heavy_active),
        "robustInactivePolicies": len(heavy_inactive),
        "ambiguousPolicies": len(heavy_ambiguous),
        "offeredPolicies": len(offered_policies),
        "acquiredPolicies": len(acquired_policies),
        "viableActivePolicies": len(heavy_active & viable_policies),
        "distinctConsumedCards": len(used_cards),
        "baselineFaultRows": sum(row.get("outcome") in ("stall", "error")
                                 or bool(row.get("error")) for row in rows),
    }
    gates = protocol["gates"]
    gate_results = {
        "sourceReady": counts["sourceReadyPolicies"] >= gates["minimumSourceReadyPolicies"],
        "active": counts["robustActivePolicies"] >= gates["minimumActivePolicies"],
        "inactive": counts["robustInactivePolicies"] >= gates["minimumInactivePolicies"],
        "reachable": counts["offeredPolicies"] >= gates["minimumOfferedPolicies"]
        and counts["acquiredPolicies"] >= gates["minimumAcquiredPolicies"],
        "viable": counts["viableActivePolicies"] >= gates["minimumViableActivePolicies"],
        "sourceBreadth": counts["distinctConsumedCards"] >= gates["minimumDistinctConsumedCards"],
        "scorelineSeparation": separation["relayOnly"] >= gates["minimumRelayOnlyPolicies"]
        and separation["jaccard"] <= gates["maximumScorelineJaccard"],
    }
    elapsed = time.monotonic() - started
    if elapsed > float(protocol["budget"]["maximumWallTimeSeconds"]):
        boundary, decision = 3, "record-shatter-tempo-capacity-inconclusive-at-cap"
        authority = protocol["decisionRules"]["inconclusiveAuthority"]
    elif all(gate_results.values()):
        boundary, decision = 1, "authorise-shatter-tempo-relay-identity-preflight"
        authority = protocol["decisionRules"]["successAuthority"]
    else:
        boundary, decision = 2, "close-shatter-tempo-relay-without-implementation"
        authority = protocol["decisionRules"]["futilityAuthority"]

    ledger_after = identity.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    summary = {
        "schemaVersion": 1, "issue": 421, "decisionBoundary": boundary,
        "decision": decision, "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)), "candidate": protocol["candidate"],
        "eligibleCards": eligible, "counts": counts, "gateResults": gate_results,
        "functionalSeparation": separation, "activePolicies": sorted(heavy_active),
        "inactivePolicies": sorted(heavy_inactive), "ambiguousPolicies": sorted(heavy_ambiguous),
        "usedEligibleCards": used_cards, "policyIdentities": cohort["policyCount"],
        "newSimulatorObservationRows": 0, "newLedgerRows": 0, "protectedSeedRows": 0,
        "wallTimeSeconds": elapsed, "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after, "authority": authority,
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({"status": "PASS", "decision": decision,
                          "decisionBoundary": boundary,
                          "summarySha256": core.file_sha(SUMMARY),
                          "newSimulatorObservationRows": 0}))


if __name__ == "__main__":
    main()
