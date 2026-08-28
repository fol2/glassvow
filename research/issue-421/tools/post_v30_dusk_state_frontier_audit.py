#!/usr/bin/env python3
"""Zero-row source audit for the next Dusk Facet-state representation."""

from __future__ import annotations

import json
import re
import subprocess
import time
from pathlib import Path

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v30-dusk-state-frontier-audit-v1.json"
SUMMARY = core.ROOT / "summaries/post-v30-dusk-state-frontier-audit-v1.json"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Dusk state frontier mismatch: {label}")


def main_blob(path: str) -> bytes:
    return subprocess.run(
        ["git", "show", f"HEAD:{path}"], cwd=core.SOURCE,
        check=True, capture_output=True,
    ).stdout


def state_vars(source: str) -> list[str]:
    return re.findall(r"^var ([A-Za-z0-9_]+)", source, re.MULTILINE)


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the Dusk state frontier summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    immutable = protocol["immutableInputs"]
    require("runner SHA", core.file_sha(Path(__file__)) == immutable["runnerSha256"])
    require("task capsule SHA", core.file_sha(core.ROOT / "task-capsule.json") ==
            immutable["taskCapsuleSha256"])
    require("source commit", subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=core.SOURCE, check=True,
        text=True, capture_output=True,
    ).stdout.strip() == immutable["sourceCommit"])

    source_text: dict[str, str] = {}
    for path, expected_sha in immutable["sourceSha256"].items():
        blob = main_blob(path)
        require(f"{path} SHA", core.sha(blob) == expected_sha)
        source_text[path] = blob.decode()
    require("CombatState field inventory", state_vars(
        source_text["domain/state/combat_state.gd"]) ==
        protocol["stateIdentity"]["combatStateFields"])
    require("EnemyCombatant field inventory", state_vars(
        source_text["domain/state/enemy_combatant.gd"]) ==
        protocol["stateIdentity"]["enemyCombatantFields"])
    for assertion in protocol["sourceAssertions"]:
        require(assertion["id"], assertion["contains"] in source_text[assertion["path"]])

    content = json.loads(source_text["content/full-content.json"])
    formations = [formation for act in content["encounters"]
                  for groups in act.values() for formation in groups]
    encounter_identity = {
        "formations": len(formations),
        "multiEnemyFormations": sum(len(row) > 1 for row in formations),
        "singleEnemyFormations": sum(len(row) == 1 for row in formations),
        "maximumEnemies": max(map(len, formations)),
        "multiEnemyByAct": [sum(len(row) > 1 for groups in act.values()
                                for row in groups) for act in content["encounters"]],
    }
    require("encounter identity", encounter_identity == protocol["naturalRouteIdentity"])

    evidence_results: dict[str, dict[str, str]] = {}
    for name, spec in protocol["priorEvidence"].items():
        path = core.ROOT / spec["path"]
        require(f"{name} SHA", core.file_sha(path) == spec["sha256"])
        decision = json.loads(path.read_text())["decision"]
        require(f"{name} decision", decision == spec["decision"])
        evidence_results[name] = {"sha256": spec["sha256"], "decision": decision}

    relations = protocol["facetOwnershipPartition"]
    require("binary ownership partition", [item["relation"] for item in relations] ==
            ["same-current-target", "other-living-target"])
    for item in relations:
        require(f"{item['id']} evidence names",
                all(name in evidence_results for name in item["closureEvidence"]))
        require(f"{item['id']} disposition", item["disposition"] ==
                ("closed" if item["closureEvidence"] else "uncovered"))
    for alias in protocol["closedAliases"]:
        require(f"{alias['id']} closure", alias["disposition"] == "closed-alias" and
                all(name in evidence_results for name in alias["closureEvidence"]))

    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    uncovered = [item["id"] for item in relations if item["disposition"] == "uncovered"]
    require("selected primitive identity", uncovered ==
            [protocol["selectedPrimitive"]["id"]])
    elapsed = time.monotonic() - started
    if elapsed > float(protocol["budget"]["maximumWallTimeSeconds"]):
        boundary, decision = 3, "record-dusk-state-frontier-inconclusive-at-cap"
    elif len(uncovered) == 1:
        boundary, decision = 1, "freeze-cross-enemy-partial-facet-for-identity-preflight"
    else:
        boundary, decision = 2, "close-facet-ownership-state-frontier"
    ledger_after = identity.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    authority_key = {1: "successAuthority", 2: "futilityAuthority",
                     3: "inconclusiveAuthority"}[boundary]
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": boundary,
        "decision": decision,
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "frontierScope": protocol["frontierScope"],
        "facetOwnershipPartition": relations,
        "closedAliases": protocol["closedAliases"],
        "selectedPrimitive": protocol["selectedPrimitive"] if boundary == 1 else None,
        "naturalRouteIdentity": encounter_identity,
        "evidenceResults": evidence_results,
        "sourceIdentity": {
            "commit": immutable["sourceCommit"],
            "sha256": immutable["sourceSha256"],
            "taskCapsuleSha256": immutable["taskCapsuleSha256"],
        },
        "traceFilesRead": 0,
        "cacheFilesRead": 0,
        "newSimulatorObservationRows": 0,
        "newLedgerRows": 0,
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "maximumModelContextTokens": 0,
        "wallTimeSeconds": elapsed,
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "authority": protocol["decisionRules"][authority_key],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS",
        "decisionBoundary": boundary,
        "decision": decision,
        "selectedPrimitive": uncovered[0] if boundary == 1 else None,
        "summarySha256": core.file_sha(SUMMARY),
        "newSimulatorObservationRows": 0,
    }))


if __name__ == "__main__":
    main()
