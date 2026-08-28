#!/usr/bin/env python3
"""Zero-row legal-opportunity observability audit for issue #421."""

from __future__ import annotations

import json
import re
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-legal-opportunity-observability-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-legal-opportunity-observability-v1.json"
SOURCE = core.ROOT / "cohand-telemetry-source"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Legal-opportunity observability mismatch: {label}")


def assess(surface: dict[str, Any], protocol: dict[str, Any]) -> dict[str, Any]:
    gates = protocol["gates"]
    results = {
        "unclosed": not surface["priorClosureAliases"],
        "existingDeterministicEvents": surface["existingDeterministicEvents"],
        "singleExistingHook": surface["hookCount"] <= gates["maximumHookCount"],
        "containerLimit": surface["containerCount"] <= gates["maximumContainerCount"],
        "scalarFieldLimit": max(surface["fieldCounts"], default=0)
        <= gates["maximumScalarFieldsPerContainer"],
        "fixedScalarSchema": surface["fixedScalarSchema"],
        "completeEnergyMutationCensus": surface["completeEnergyMutationCensus"],
        "directDecisionInterval": surface["directDecisionInterval"],
        "identityAnchorAvailable": surface["identityAnchorAvailable"],
        "preservesFrozenTrace": surface["preservesFrozenTrace"],
    }
    return {"id": surface["id"], "eligible": all(results.values()),
            "gateResults": results, "surface": surface}


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the legal-opportunity audit")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    immutable = protocol["immutableInputs"]
    require("runner SHA", core.file_sha(Path(__file__)) == immutable["runnerSha256"])
    head = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=SOURCE, check=True,
        text=True, capture_output=True,
    ).stdout.strip()
    require("source commit", head == immutable["sourceCommit"])
    for path, expected in immutable["sourceSha256"].items():
        require(f"source {path}", core.file_sha(SOURCE / path) == expected)
    for path, expected in immutable["fileSha256"].items():
        require(path, core.file_sha(core.ROOT / path) == expected)
    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])

    content = json.loads((SOURCE / "content/full-content.json").read_text())
    defend = content["cards"]["defend"]
    edge = content["cards"]["guardedStrike"]
    require("Ward fixed cost", defend.get("cost") == 1)
    require("Edge fixed cost", edge.get("cost") == 1)
    require("Ward playable self target", defend.get("target") == "self"
            and defend.get("unplayable", False) is not True)
    require("Edge playable enemy target", edge.get("target") == "enemy"
            and edge.get("unplayable", False) is not True)

    combat = (SOURCE / "domain/rules/combat.gd").read_text()
    mutation_pattern = re.compile(r"^\s*(?:p|cb\.player)\.energy\s*(?:=|\+=|-=)", re.MULTILINE)
    current_energy_mutations = mutation_pattern.findall(combat)
    energy_events = re.findall(
        r'queue\.append\(\{"t": EventTypes\.ENERGY, "n": (?:p|cb\.player)\.energy\}\)',
        combat,
    )
    require("current-energy mutation census", len(current_energy_mutations)
            == protocol["sourceCensus"]["combatCurrentEnergyMutationSites"])
    require("energy-event append census", len(energy_events)
            == protocol["sourceCensus"]["combatEnergyEventAppendSites"])
    for snippet in protocol["sourceCensus"]["requiredSnippets"]:
        require(f"source snippet {snippet}", snippet in combat)

    surfaces = [
        {
            "id": "energy-event-decision-interval",
            "hook": "BalanceSim._harvest_fight existing event loop",
            "hookCount": 1,
            "containerCount": 1,
            "containers": {"energies": ["fight", "event", "n"]},
            "fieldCounts": [3],
            "fixedScalarSchema": True,
            "existingDeterministicEvents": True,
            "completeEnergyMutationCensus": True,
            "directDecisionInterval": True,
            "identityAnchorAvailable": True,
            "preservesFrozenTrace": True,
            "priorClosureAliases": [],
            "interpretation": (
                "Reconstruct exact current Energy beside the frozen hand and first-play state. "
                "Energy at least two proves both one-cost cards jointly affordable regardless "
                "of any first-card discount; Energy zero, or Energy one after a prior play, "
                "proves not jointly affordable. Energy one before the first play remains "
                "discount-aliased and contributes only to the upper bound."
            ),
        },
        {
            "id": "static-cost-from-existing-trace",
            "hook": "No new hook",
            "hookCount": 0,
            "containerCount": 0,
            "containers": {},
            "fieldCounts": [],
            "fixedScalarSchema": True,
            "existingDeterministicEvents": False,
            "completeEnergyMutationCensus": False,
            "directDecisionInterval": False,
            "identityAnchorAvailable": True,
            "preservesFrozenTrace": True,
            "priorClosureAliases": [],
            "interpretation": "Base costs alone omit live Energy, carry-over, gains and first-card discounts."
        },
        {
            "id": "pilot-legal-action-snapshots",
            "hook": "Would require a new BalancePilot decision-loop hook",
            "hookCount": 2,
            "containerCount": 1,
            "containers": {"decisions": ["fight", "turn", "legalUids", "energy"]},
            "fieldCounts": [4],
            "fixedScalarSchema": False,
            "existingDeterministicEvents": False,
            "completeEnergyMutationCensus": True,
            "directDecisionInterval": True,
            "identityAnchorAvailable": True,
            "preservesFrozenTrace": True,
            "priorClosureAliases": [],
            "interpretation": "Measures the policy decision surface when an existing scalar event is sufficient."
        },
    ]
    assessments = [assess(surface, protocol) for surface in surfaces]
    eligible = [row for row in assessments if row["eligible"]]
    elapsed = time.monotonic() - started
    if elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        boundary = 3
        outcome_class = "inconclusive"
        decision = "record-legal-opportunity-observability-inconclusive-at-cap"
        selected = None
    elif len(eligible) == 1 and eligible[0]["id"] == protocol["selectionRule"]["requiredId"]:
        boundary = 1
        outcome_class = "success"
        decision = "freeze-energy-events-for-legal-opportunity-identity-preflight"
        selected = eligible[0]["id"]
    else:
        boundary = 2
        outcome_class = "futility"
        decision = "close-existing-event-legal-opportunity-observability"
        selected = None
    ledger_after = identity.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    summary = {
        "schemaVersion": 1, "issue": 421, "decisionBoundary": boundary,
        "decision": decision, "outcomeClass": outcome_class,
        "protocolSha256": protocol_sha, "runnerSha256": core.file_sha(Path(__file__)),
        "sourceCommit": head,
        "sourceCensus": {
            "combatCurrentEnergyMutationSites": len(current_energy_mutations),
            "combatEnergyEventAppendSites": len(energy_events),
            "targetCards": {
                "defend": {"cost": defend["cost"], "target": defend["target"]},
                "guardedStrike": {"cost": edge["cost"], "target": edge["target"]},
            },
        },
        "assessments": assessments, "selectedSurface": selected,
        "newSimulatorObservationRows": 0, "newLedgerRows": 0,
        "ledgerBefore": ledger_before, "ledgerAfter": ledger_after,
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "maximumModelContextTokens": 0, "wallTimeSeconds": elapsed,
        "factorDisposition": protocol["factorDisposition"],
        "authority": protocol["decisionRules"][f"{outcome_class}Authority"],
    }
    SUMMARY.parent.mkdir(parents=True, exist_ok=True)
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS", "decision": decision, "decisionBoundary": boundary,
        "selectedSurface": selected, "newSimulatorObservationRows": 0,
        "summarySha256": core.file_sha(SUMMARY),
    }))


if __name__ == "__main__":
    main()
