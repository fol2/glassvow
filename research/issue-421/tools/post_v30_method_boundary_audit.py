#!/usr/bin/env python3
"""Resolve policy-method authority after the two-hook Dusk grammar closes."""

from __future__ import annotations

import json
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v30-method-boundary-audit-v1.json"
SUMMARY = core.ROOT / "summaries/post-v30-method-boundary-audit-v1.json"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Method-boundary mismatch: {label}")


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite method-boundary summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    immutable = protocol["immutableInputs"]
    require("runner SHA", core.file_sha(Path(__file__)) == immutable["runnerSha256"])
    require("task capsule SHA", core.file_sha(core.ROOT / "task-capsule.json") ==
            immutable["taskCapsuleSha256"])
    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])

    evidence: dict[str, dict[str, Any]] = {}
    for name, spec in protocol["evidence"].items():
        path = core.ROOT / spec["path"]
        require(f"{name} SHA", core.file_sha(path) == spec["sha256"])
        evidence[name] = json.loads(path.read_text())
        require(f"{name} decision", evidence[name]["decision"] == spec["decision"])

    topology = evidence["current-main-order-topology"]
    cohand = evidence["cohand-opportunity"]
    energy = evidence["energy-telemetry-identity"]
    signal = evidence["policy-signal"]
    order_value = evidence["policy-package-order-decision-value"]
    commitment = evidence["package-commitment-capacity"]
    census = evidence["post-quarantine-structural-census"]
    debt = evidence["private-debt-identity-audit"]
    status = evidence["status-liability-capacity"]

    policy_bottleneck_signals = {
        "naturalOrderExplicitPolicyBottleneck":
            topology.get("failureClass") == "policy-repertoire-bottleneck",
        "cohandExplicitPolicyBottleneck":
            cohand.get("failureClass") == "policy-repertoire-bottleneck",
        "energyIdentityAdmitsPolicyInference":
            energy.get("decision") == "admit-energy-event-telemetry-for-policy-bottleneck",
        "heldoutPolicySignalClear": all(
            bool(route.get("clear")) for route in signal["routes"].values()),
        "packageOrderMeasuredDecisionValue":
            bool(order_value["measuredDecisionValue"]),
        "packageCommitmentAllCapacityGatesClear":
            bool(commitment["allCapacityGatesClear"]),
        "statusCapacityPolicyMethodAuthority":
            status.get("policyMethodAuthority") is True,
    }
    method_authorised = any(policy_bottleneck_signals.values())
    require("no hidden method authority", not method_authorised)

    require("two-hook census singleton",
            census["selectedDesigns"] == ["private-player-status-liability"])
    require("private debt quarantined", debt["decisionBoundary"] == 3)
    require("status liability closed", status["decisionBoundary"] == 2)
    require("status failure isolated to Afterimage separation",
            not status["gateResults"]["afterimageSeparation"] and
            all(value for name, value in status["gateResults"].items()
                if name != "afterimageSeparation"))
    two_hook_grammar_exhausted = True

    elapsed = time.monotonic() - started
    if elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        boundary, decision = 3, "record-method-boundary-inconclusive-at-cap"
    elif not method_authorised and two_hook_grammar_exhausted:
        boundary = 1
        decision = "freeze-deterministic-exclusive-acquisition-class-for-source-audit"
    else:
        boundary = 2
        decision = "authorise-no-new-method-or-structural-class"
    ledger_after = identity.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    authority_key = (
        "successAuthority" if boundary == 1 else
        "futilityAuthority" if boundary == 2 else "inconclusiveAuthority"
    )
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": boundary,
        "decision": decision,
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "policyBottleneckSignals": policy_bottleneck_signals,
        "policyMethodAuthorised": method_authorised,
        "twoHookCombatLocalGrammarExhausted": two_hook_grammar_exhausted,
        "selectedNextClass": protocol["nextStructuralClass"] if boundary == 1 else None,
        "newSimulatorObservationRows": 0,
        "newLedgerRows": 0,
        "supportRowsInspected": 0,
        "cacheFilesRead": 0,
        "godotProcesses": 0,
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
        "policyMethodAuthorised": method_authorised,
        "newSimulatorObservationRows": 0,
        "summarySha256": core.file_sha(SUMMARY),
    }))


if __name__ == "__main__":
    main()
