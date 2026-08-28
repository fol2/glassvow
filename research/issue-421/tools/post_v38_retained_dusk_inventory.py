#!/usr/bin/env python3
"""Zero-row inventory of immutable #524 retained Duskblade edges."""

from __future__ import annotations

import json
import subprocess
import time
from collections import Counter
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import post_v38_ward_whole_run_discovery_audit as ward
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-retained-dusk-inventory-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-retained-dusk-inventory-v1.json"


def require_equal(label: str, left: Any, right: Any) -> None:
    if left != right:
        raise RuntimeError(f"retained Dusk inventory mismatch: {label}")


def git_blob(commit: str, path: str) -> bytes:
    return subprocess.run(
        ["git", "show", f"{commit}:{path}"], cwd=core.SOURCE, check=True,
        capture_output=True,
    ).stdout


def edge_support(rows: list[dict[str, Any]], producer: str,
                 policy_count: int, gates: dict[str, int]) -> dict[str, Any]:
    active = ward.active_indices(rows, lambda row: ward.ward_active(row, producer))
    reachable = ward.active_indices(
        rows, lambda row: ward.pair_reachable(row, producer, "fortify")
    )
    offered = ward.active_indices(
        rows,
        lambda row: int((row.get("packageEvents") or {}).get(
            f"{producer}Offered", 0
        )) > 0 and int((row.get("packageEvents") or {}).get(
            "fortifyOffered", 0
        )) > 0,
    )
    result = {
        "active": len(active),
        "inactive": policy_count - len(active),
        "reachable": len(reachable),
        "consumerReached": len(active),
        "bothOffered": len(offered),
    }
    result["clear"] = (
        result["active"] >= gates["minimumActivePolicies"]
        and result["inactive"] >= gates["minimumInactivePolicies"]
        and result["reachable"] >= gates["minimumReachablePolicies"]
        and result["consumerReached"] >= gates["minimumConsumerReachedPolicies"]
    )
    result["activePolicies"] = sorted(active)
    return result


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the retained Dusk inventory")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    runner_sha = core.file_sha(Path(__file__))
    require_equal("runner SHA", runner_sha, protocol["immutableInputs"]["runnerSha256"])

    evidence_payloads: dict[str, dict[str, Any]] = {}
    for name, spec in protocol["immutableScientificEvidence"].items():
        if "commit" in spec:
            blob = git_blob(spec["commit"], spec["path"])
            require_equal(f"{name} SHA", core.sha(blob), spec["sha256"])
            evidence_payloads[name] = json.loads(blob)
        else:
            path = core.ROOT / spec["path"]
            require_equal(f"{name} SHA", core.file_sha(path), spec["sha256"])
            evidence_payloads[name] = json.loads(path.read_text())

    gate = evidence_payloads["issue524PackageGate"]
    promoted = sorted(
        value for value in gate["microdecks"]["promotedEdgeAspects"]
        if value.endswith("|duskblade")
    )
    require_equal("immutable #524 Dusk edges", promoted,
                  sorted(protocol["retainedDuskEdges"]))
    graph = evidence_payloads["issue524MechanismGraph"]
    require_equal("immutable #524 content", graph["contentSha256"],
                  protocol["baseline"]["contentSha256"])
    terminal = evidence_payloads["issue525TerminalFinding"]
    exhausted = sorted(row["family"] for row in terminal["designFamilyExhaustion"])
    require_equal("immutable #525 exhausted families", exhausted,
                  sorted(protocol["closedDirections"]["issue525Families"]))
    prior_ward = evidence_payloads["wardWholeRunAudit"]
    require_equal("Ward decision", prior_ward["decision"],
                  "reject-exact-ward-candidate-close-tested-direction")
    require_equal("Ward hard failures", all(prior_ward["hardFailureWitnesses"].values()),
                  True)

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
    rows = [
        row for row in output["rows"]
        if row.get("arm") == "policy" and row.get("aspect") == "duskblade"
    ]
    cohort = protocol["cohort"]
    require_equal("policy row count", len(rows), cohort["policyRows"])
    require_equal("policy roots", {int(row["policyRoot"]) for row in rows},
                  {cohort["policyRoot"]})
    require_equal("policy indices", {int(row["policyIndex"]) for row in rows},
                  set(range(cohort["policyCount"])))
    require_equal("policy seeds", {int(row["seed"]) for row in rows},
                  set(cohort["simulationSeeds"]))
    require_equal("rows per policy", Counter(int(row["policyIndex"]) for row in rows),
                  Counter({index: len(cohort["simulationSeeds"])
                           for index in range(cohort["policyCount"])}))
    snapshots: dict[int, set[str]] = {}
    for row in rows:
        snapshots.setdefault(int(row["policyIndex"]), set()).add(
            core.sha(core.canonical(row["policy"]).encode())
        )
    require_equal("policy snapshot identity", all(len(value) == 1
                                                   for value in snapshots.values()), True)

    gates = protocol["gates"]
    edges = {
        producer: edge_support(rows, producer, cohort["policyCount"], gates)
        for producer in protocol["eligibleCurrentMainProducers"]
    }
    scoreline = ward.active_indices(rows, ward.scoreline_active)
    brace = set(edges["brace"]["activePolicies"])
    bulwark = set(edges["bulwark"]["activePolicies"])
    faults = ward.faults(rows)
    eligible = [
        producer for producer in protocol["selectionOrder"]
        if edges[producer]["clear"]
    ]
    selected = eligible[0] if eligible and faults == 0 else None
    if selected is None:
        decision_boundary = 2
        decision = "close-immutable-retained-dusk-inventory"
        authority = protocol["decisionRules"]["futilityAuthority"]
    else:
        decision_boundary = 1
        decision = f"freeze-current-main-{selected}-fortify-for-heldout"
        authority = protocol["decisionRules"]["successAuthority"]

    if time.monotonic() - started > float(protocol["budget"]["maximumWallTimeSeconds"]):
        raise TimeoutError("retained Dusk inventory exceeded its frozen ceiling")
    ledger_after = identity.ledger_identity()
    require_equal("append-only ledger", ledger_before, ledger_after)
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": decision_boundary,
        "decision": decision,
        "protocolSha256": protocol_sha,
        "runnerSha256": runner_sha,
        "retainedDuskEdges": promoted,
        "closedDirections": protocol["closedDirections"],
        "edgeSupport": edges,
        "selectionOrder": protocol["selectionOrder"],
        "selectedProducer": selected,
        "scorelineActivePolicies": len(scoreline),
        "edgeSeparation": {
            "braceOnly": len(brace - bulwark),
            "bulwarkOnly": len(bulwark - brace),
            "crossActive": len(brace & bulwark),
        },
        "scorelineSeparation": {
            producer: {
                "scorelineOnly": len(scoreline - set(result["activePolicies"])),
                "wardOnly": len(set(result["activePolicies"]) - scoreline),
                "crossActive": len(set(result["activePolicies"]) & scoreline),
            } for producer, result in edges.items()
        },
        "policyIdentities": len(snapshots),
        "faults": faults,
        "newSimulatorObservationRows": 0,
        "newLedgerRows": 0,
        "protectedSeedRows": 0,
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "authority": authority,
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS",
        "decision": decision,
        "decisionBoundary": decision_boundary,
        "selectedProducer": selected,
        "summarySha256": core.file_sha(SUMMARY),
        "newSimulatorObservationRows": 0,
    }))


if __name__ == "__main__":
    main()
