#!/usr/bin/env python3
"""Zero-row capacity screen for a second-Shatter-on-one-enemy Dusk relay."""

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


PROTOCOL = core.ROOT / "protocols/post-v38-reseam-break-capacity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-reseam-break-capacity-v1.json"


def exact_witnesses(row: dict[str, Any]) -> list[dict[str, Any]]:
    return [fight for fight in row.get("fights", [])
            if len(fight.get("enemies", [])) == 1 and int(fight.get("shatters", 0)) >= 2]


def possible_witness(row: dict[str, Any]) -> bool:
    return any(int(fight.get("shatters", 0)) >= 2 for fight in row.get("fights", []))


def self_check() -> None:
    exact = {"fights": [{"enemies": ["one"], "shatters": 2}]}
    ambiguous = {"fights": [{"enemies": ["a", "b"], "shatters": 2}]}
    inactive = {"fights": [{"enemies": ["one"], "shatters": 1}]}
    previous.require("reseam exact self-check", len(exact_witnesses(exact)) == 1)
    previous.require("reseam ambiguity self-check", not exact_witnesses(ambiguous)
                     and possible_witness(ambiguous))
    previous.require("reseam inactive self-check", not possible_witness(inactive))


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the reseam-break capacity screen")
    self_check()
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
        payload = json.loads(path.read_text())
        previous.require(f"{name} decision", payload["decision"] == spec["decision"])

    ledger_before = identity.ledger_identity()
    previous.require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    baseline = protocol["baseline"]
    output_path = core.CACHE / f"{baseline['outputSha256']}.json"
    previous.require("output SHA", core.file_sha(output_path) == baseline["outputSha256"])
    output = json.loads(output_path.read_text())
    previous.require("plan SHA", output["planSha256"] == baseline["planSha256"])
    previous.require("content identity", output["contentIdentity"]["contentFileSha256"] ==
                     baseline["contentSha256"])

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

    exact_hits = previous.policy_hits(rows, lambda row: bool(exact_witnesses(row)))
    possible_hits = previous.policy_hits(rows, possible_witness)
    source_hits = previous.policy_hits(rows, lambda row: previous.shatters(row) > 0)
    successful_hits = previous.policy_hits(
        rows, lambda row: any(fight.get("result") == "win" for fight in exact_witnesses(row)))
    scoreline_hits = previous.policy_hits(
        rows, lambda row: previous.played(row, "chisel") > 0
        and previous.played(row, "executioner") > 0)
    robust = int(cohort["minimumRowsPerRobustPolicy"])
    active = {index for index in range(cohort["policyCount"])
              if exact_hits.get(index, 0) >= robust}
    inactive = {index for index in range(cohort["policyCount"])
                if possible_hits.get(index, 0) == 0}
    ambiguous = set(range(cohort["policyCount"])) - active - inactive
    source_ready, _, _ = previous.classify(source_hits, cohort["policyCount"], robust)
    successful = {index for index in range(cohort["policyCount"])
                  if successful_hits.get(index, 0) >= robust}
    scoreline, _, _ = previous.classify(scoreline_hits, cohort["policyCount"], robust)
    witness_acts = sorted({int(fight["act"]) for row in rows
                           for fight in exact_witnesses(row)})
    separation = {
        "reseamOnly": len(active - scoreline),
        "scorelineOnly": len(scoreline - active),
        "crossActive": len(active & scoreline),
        "jaccard": (len(active & scoreline) / len(active | scoreline)
                    if active | scoreline else 1.0),
    }
    counts = {
        "sourceReadyPolicies": len(source_ready),
        "robustExactActivePolicies": len(active),
        "exactInactivePolicies": len(inactive),
        "ambiguousPolicies": len(ambiguous),
        "successfulFightActivePolicies": len(active & successful),
        "witnessActs": witness_acts,
        "baselineFaultRows": sum(row.get("outcome") in ("stall", "error")
                                 or bool(row.get("error")) for row in rows),
    }
    gates = protocol["gates"]
    gate_results = {
        "sourceReady": counts["sourceReadyPolicies"] >= gates["minimumSourceReadyPolicies"],
        "active": counts["robustExactActivePolicies"] >= gates["minimumActivePolicies"],
        "inactive": counts["exactInactivePolicies"] >= gates["minimumInactivePolicies"],
        "successfulFight": counts["successfulFightActivePolicies"] >=
        gates["minimumSuccessfulFightActivePolicies"],
        "actBreadth": len(witness_acts) >= gates["minimumWitnessActs"],
        "scorelineSeparation": separation["reseamOnly"] >= gates["minimumReseamOnlyPolicies"]
        and separation["jaccard"] <= gates["maximumScorelineJaccard"],
    }
    elapsed = time.monotonic() - started
    if elapsed > float(protocol["budget"]["maximumWallTimeSeconds"]):
        boundary, decision = 3, "record-reseam-break-capacity-inconclusive-at-cap"
        authority = protocol["decisionRules"]["inconclusiveAuthority"]
    elif all(gate_results.values()):
        boundary, decision = 1, "authorise-reseam-break-identity-preflight"
        authority = protocol["decisionRules"]["successAuthority"]
    else:
        boundary, decision = 2, "close-reseam-break-without-implementation"
        authority = protocol["decisionRules"]["futilityAuthority"]

    ledger_after = identity.ledger_identity()
    previous.require("zero-row ledger identity", ledger_after == ledger_before)
    summary = {
        "schemaVersion": 1, "issue": 421, "decisionBoundary": boundary,
        "decision": decision, "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)), "candidate": protocol["candidate"],
        "counts": counts, "gateResults": gate_results,
        "functionalSeparation": separation, "activePolicies": sorted(active),
        "inactivePolicies": sorted(inactive), "ambiguousPolicies": sorted(ambiguous),
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
