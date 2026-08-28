#!/usr/bin/env python3
"""Zero-row Hearth observability and payoff-control audit for issue #421."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-hearth-observability-payoff-audit-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-hearth-observability-payoff-audit-v1.json"
SOURCE = core.ROOT / "hearth-priority-identity-source"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Hearth observability/payoff audit mismatch: {label}")


def head_blob(relative: str) -> bytes:
    return subprocess.run(
        ["git", "show", f"HEAD:{relative}"], cwd=SOURCE,
        check=True, capture_output=True,
    ).stdout


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the Hearth observability/payoff summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    immutable = protocol["immutableInputs"]
    require("runner SHA", core.file_sha(Path(__file__)) == immutable["runnerSha256"])
    source_commit = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=SOURCE,
        check=True, capture_output=True, text=True,
    ).stdout.strip()
    require("source commit", source_commit == immutable["sourceCommit"])
    for relative, expected in immutable["currentMainSourceSha256"].items():
        require(f"current-main source {relative}", core.sha(head_blob(relative)) == expected)
    for relative, expected in immutable["prototypeSourceSha256"].items():
        require(f"prototype source {relative}", core.file_sha(SOURCE / relative) == expected)
    for relative, expected in immutable["fileSha256"].items():
        require(relative, core.file_sha(core.ROOT / relative) == expected)

    current_text = {
        relative: head_blob(relative).decode()
        for relative in immutable["currentMainSourceSha256"]
    }
    prototype_text = {
        relative: (SOURCE / relative).read_text()
        for relative in immutable["prototypeSourceSha256"]
    }
    for relative, fragments in protocol["sourceAssertions"]["currentMain"].items():
        for fragment in fragments:
            require(f"current-main {relative} contains {fragment}",
                    fragment in current_text[relative])
    for relative, fragments in protocol["sourceAssertions"]["prototype"].items():
        for fragment in fragments:
            require(f"prototype {relative} contains {fragment}",
                    fragment in prototype_text[relative])

    combat = current_text["domain/rules/combat.gd"]
    order_fragments = protocol["postCombatOrder"]
    order_offsets = [combat.index(fragment) for fragment in order_fragments]
    require("post-combat order", order_offsets == sorted(order_offsets))

    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])

    observation_criteria = protocol["observationEligibility"]
    observation_assessments = []
    for surface in protocol["observationSurfaces"]:
        gates = {
            "crownOpportunity": surface["crownOpportunity"] is True,
            "terminalEmber": surface["terminalEmber"] is True,
            "activation": surface["activation"] is True,
            "singleHarvestHook": surface["hookCount"]
            <= observation_criteria["maximumHookCount"],
            "minimalFields": len(surface["fields"])
            <= observation_criteria["maximumFieldCount"],
            "captureGated": surface["captureGated"] is True,
            "identityAnchor": surface["identityAnchorAvailable"] is True,
            "unclosed": surface["priorClosureAliases"] == [],
        }
        observation_assessments.append({
            "id": surface["id"], "gateResults": gates,
            "eligible": all(gates.values()), "surface": surface,
        })
    selected_observations = [
        row for row in observation_assessments if row["eligible"]
    ]
    require("at most one observation surface", len(selected_observations) <= 1)

    payoff_criteria = protocol["payoffControlEligibility"]
    payoff_assessments = []
    for control in protocol["payoffControls"]:
        gates = {
            "singleRuntimeHook": control["runtimeHookCount"]
            <= payoff_criteria["maximumRuntimeHookCount"],
            "preservesAcquisition": control["preservesAcquisition"] is True,
            "preservesActivation": control["preservesActivation"] is True,
            "changesOnlyCrownHealInput": control["changesOnlyCrownHealInput"] is True,
            "noContentMutation": control["contentFilesChanged"] == 0,
            "exactCurrentNull": control["exactCurrentNull"] is True,
            "directControlCapable": control["directControlCapable"] is True,
        }
        payoff_assessments.append({
            "id": control["id"], "gateResults": gates,
            "eligible": all(gates.values()), "control": control,
        })
    selected_payoffs = [row for row in payoff_assessments if row["eligible"]]
    require("at most one payoff control", len(selected_payoffs) <= 1)

    elapsed = time.monotonic() - started
    if elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        boundary, outcome = 3, "inconclusive"
        decision = "record-hearth-observability-payoff-audit-inconclusive-at-cap"
    elif len(selected_observations) == 1 and len(selected_payoffs) == 1:
        boundary, outcome = 1, "success"
        decision = "freeze-hearth-harvest-telemetry-and-payoff-disable-for-identity-preflight"
    else:
        boundary, outcome = 2, "futility"
        decision = "close-hearth-observability-or-payoff-control-route"

    ledger_after = identity.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": boundary,
        "decision": decision,
        "outcomeClass": outcome,
        "selectedObservationSurface": (
            selected_observations[0]["id"] if len(selected_observations) == 1 else None
        ),
        "selectedPayoffControl": (
            selected_payoffs[0]["id"] if len(selected_payoffs) == 1 else None
        ),
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "sourceIdentity": {
            "commit": source_commit,
            "currentMainSha256": immutable["currentMainSourceSha256"],
            "prototypeSha256": immutable["prototypeSourceSha256"],
        },
        "postCombatOrder": order_fragments,
        "observationAssessments": observation_assessments,
        "payoffControlAssessments": payoff_assessments,
        "identityPreflightDesign": protocol["identityPreflightDesign"],
        "factorContract": protocol["factorDefinitions"],
        "mechanisticInteractions": protocol["mechanisticInteractions"],
        "newSimulatorObservationRows": 0,
        "cachedObservationRowsRead": 0,
        "newLedgerRows": 0,
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "maximumModelContextTokens": 0,
        "wallTimeSeconds": elapsed,
        "authority": protocol["decisionRules"][f"{outcome}Authority"],
    }
    SUMMARY.parent.mkdir(parents=True, exist_ok=True)
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS",
        "decision": decision,
        "decisionBoundary": boundary,
        "selectedObservationSurface": summary["selectedObservationSurface"],
        "selectedPayoffControl": summary["selectedPayoffControl"],
        "newSimulatorObservationRows": 0,
        "summarySha256": core.file_sha(SUMMARY),
    }))


if __name__ == "__main__":
    main()
