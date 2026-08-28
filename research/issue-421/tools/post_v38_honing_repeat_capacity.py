#!/usr/bin/env python3
"""Zero-row upper-capacity screen for a repeated Honing Edge package."""

from __future__ import annotations

import json
import subprocess
import time
from collections import Counter
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import post_v38_shatter_tempo_capacity as previous
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-honing-repeat-capacity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-honing-repeat-capacity-v1.json"


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the Honing Edge capacity screen")
    active, inactive, ambiguous = previous.classify({0: 2, 1: 1}, 4, 2)
    previous.require("classification self-check", active == {0} and inactive == {2, 3}
                     and ambiguous == {1})
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    previous.require("runner SHA", core.file_sha(Path(__file__)) ==
                     protocol["immutableInputs"]["runnerSha256"])
    previous.require("source commit", subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=core.SOURCE, check=True,
        text=True, capture_output=True,
    ).stdout.strip() == protocol["immutableInputs"]["sourceCommit"])
    combat_blob = subprocess.run(
        ["git", "show", "HEAD:domain/rules/combat.gd"], cwd=core.SOURCE,
        check=True, capture_output=True,
    ).stdout
    previous.require("combat source SHA", core.sha(combat_blob) ==
                     protocol["immutableInputs"]["combatRulesSha256"])

    for name, spec in protocol["priorEvidence"].items():
        path = core.ROOT / spec["path"]
        previous.require(f"{name} SHA", core.file_sha(path) == spec["sha256"])
        previous.require(f"{name} decision", json.loads(path.read_text())["decision"] ==
                         spec["decision"])

    ledger_before = identity.ledger_identity()
    previous.require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    baseline = protocol["baseline"]
    content_path = core.CACHE / f"{baseline['contentSha256']}.json"
    output_path = core.CACHE / f"{baseline['outputSha256']}.json"
    previous.require("content SHA", core.file_sha(content_path) == baseline["contentSha256"])
    previous.require("output SHA", core.file_sha(output_path) == baseline["outputSha256"])
    content = json.loads(content_path.read_text())
    output = json.loads(output_path.read_text())
    previous.require("plan SHA", output["planSha256"] == baseline["planSha256"])
    previous.require("content identity", output["contentIdentity"]["contentFileSha256"] ==
                     baseline["contentSha256"])
    previous.require("Honing Edge source identity", content["cards"]["momentum"] ==
                     protocol["sourceCard"])
    previous.require("Honing Edge reward reachability", "momentum" in
                     content["cardPools"]["uncommon"])

    cohort = protocol["cohort"]
    rows = [row for row in output["rows"] if row.get("arm") == "policy"
            and row.get("aspect") == cohort["aspect"] and int(row.get("vow", -1)) == cohort["vow"]]
    previous.require("row count", len(rows) == cohort["policyRows"])
    previous.require("policy root", {int(row["policyRoot"]) for row in rows} ==
                     {cohort["policyRoot"]})
    previous.require("policy indices", {int(row["policyIndex"]) for row in rows} ==
                     set(range(cohort["policyCount"])))
    previous.require("simulation seeds", {int(row["seed"]) for row in rows} ==
                     set(cohort["simulationSeeds"]))
    previous.require("rows per policy", Counter(int(row["policyIndex"]) for row in rows) ==
                     Counter({index: len(cohort["simulationSeeds"])
                              for index in range(cohort["policyCount"])}))

    potential_hits = previous.policy_hits(
        rows, lambda row: previous.played(row, "momentum") >= 2)
    any_play_hits = previous.policy_hits(
        rows, lambda row: previous.played(row, "momentum") > 0)
    offered_hits = previous.policy_hits(
        rows, lambda row: previous.offered(row, "momentum") > 0)
    acquired_hits = previous.policy_hits(
        rows, lambda row: "momentum" in set(map(str, row.get("deckIds", []))))
    scoreline_hits = previous.policy_hits(
        rows, lambda row: previous.played(row, "chisel") > 0
        and previous.played(row, "executioner") > 0)
    robust = int(cohort["minimumRowsPerRobustPolicy"])
    potential_active = {index for index in range(cohort["policyCount"])
                        if potential_hits.get(index, 0) >= robust}
    exact_inactive = {index for index in range(cohort["policyCount"])
                      if any_play_hits.get(index, 0) == 0}
    ambiguous = set(range(cohort["policyCount"])) - potential_active - exact_inactive
    offered_policies = set(offered_hits)
    acquired_policies = set(acquired_hits)
    scoreline, _, _ = previous.classify(scoreline_hits, cohort["policyCount"], robust)
    separation = {
        "honingOnly": len(potential_active - scoreline),
        "scorelineOnly": len(scoreline - potential_active),
        "crossActive": len(potential_active & scoreline),
        "jaccard": (len(potential_active & scoreline) /
                    len(potential_active | scoreline)
                    if potential_active | scoreline else 1.0),
    }
    counts = {
        "potentialActivePolicies": len(potential_active),
        "exactInactivePolicies": len(exact_inactive),
        "ambiguousPolicies": len(ambiguous),
        "offeredPolicies": len(offered_policies),
        "acquiredPolicies": len(acquired_policies),
        "baselineFaultRows": sum(row.get("outcome") in ("stall", "error")
                                 or bool(row.get("error")) for row in rows),
    }
    gates = protocol["gates"]
    gate_results = {
        "potentialActive": counts["potentialActivePolicies"] >=
        gates["minimumPotentialActivePolicies"],
        "inactive": counts["exactInactivePolicies"] >= gates["minimumInactivePolicies"],
        "reachable": counts["offeredPolicies"] >= gates["minimumOfferedPolicies"]
        and counts["acquiredPolicies"] >= gates["minimumAcquiredPolicies"],
        "scorelineSeparation": separation["honingOnly"] >= gates["minimumHoningOnlyPolicies"]
        and separation["jaccard"] <= gates["maximumScorelineJaccard"],
    }
    elapsed = time.monotonic() - started
    if elapsed > float(protocol["budget"]["maximumWallTimeSeconds"]):
        boundary, decision = 3, "record-honing-repeat-capacity-inconclusive-at-cap"
        authority = protocol["decisionRules"]["inconclusiveAuthority"]
    elif all(gate_results.values()):
        boundary, decision = 1, "authorise-honing-repeat-telemetry-preflight"
        authority = protocol["decisionRules"]["successAuthority"]
    else:
        boundary, decision = 2, "close-honing-repeat-without-implementation"
        authority = protocol["decisionRules"]["futilityAuthority"]

    ledger_after = identity.ledger_identity()
    previous.require("zero-row ledger identity", ledger_after == ledger_before)
    summary = {
        "schemaVersion": 1, "issue": 421, "decisionBoundary": boundary,
        "decision": decision, "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)), "candidate": protocol["candidate"],
        "counts": counts, "gateResults": gate_results, "functionalSeparation": separation,
        "potentialActivePolicies": sorted(potential_active),
        "inactivePolicies": sorted(exact_inactive), "ambiguousPolicies": sorted(ambiguous),
        "policyIdentities": cohort["policyCount"], "newSimulatorObservationRows": 0,
        "newLedgerRows": 0, "protectedSeedRows": 0, "wallTimeSeconds": elapsed,
        "ledgerBefore": ledger_before, "ledgerAfter": ledger_after, "authority": authority,
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({"status": "PASS", "decision": decision,
                          "decisionBoundary": boundary,
                          "summarySha256": core.file_sha(SUMMARY),
                          "newSimulatorObservationRows": 0}))


if __name__ == "__main__":
    main()
