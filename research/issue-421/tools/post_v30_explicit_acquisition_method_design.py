#!/usr/bin/env python3
"""Zero-row method decision for the post-selector ChoiceScreen continuation."""

from __future__ import annotations

import json
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v30-explicit-acquisition-method-design-v1.json"
SUMMARY = core.ROOT / "summaries/post-v30-explicit-acquisition-method-design-v1.json"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Explicit acquisition design mismatch: {label}")


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite explicit acquisition method design")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    immutable = protocol["immutableInputs"]
    require("runner identity", core.file_sha(Path(__file__)) == immutable["runnerSha256"])
    require("task capsule identity", core.file_sha(core.ROOT / "task-capsule.json") ==
            immutable["taskCapsuleSha256"])
    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])

    evidence: dict[str, dict[str, Any]] = {}
    for name, spec in protocol["evidence"].items():
        path = core.ROOT / spec["path"]
        require(f"{name} identity", core.file_sha(path) == spec["sha256"])
        evidence[name] = json.loads(path.read_text())
        require(f"{name} decision", evidence[name]["decision"] == spec["decision"])

    capacity = evidence["selectorCapacity"]
    identity_v2 = evidence["identityV2"]
    identity_v1 = evidence["identityV1"]
    design = evidence["choiceScreenDesign"]
    selector_closed = (
        capacity["decisionBoundary"] == 2
        and capacity["capacity"]["counts"]["guardedStrikePolicies"] == 1
        and capacity["capacity"]["counts"]["guardedStrikeViablePolicies"] == 0
        and capacity["capacity"]["counts"]["tiedPolicies"] == 0
        and capacity["capacity"]["counts"]["baselineFaultRows"] == 0
    )
    null_identity = identity_v2["decisionBoundary"] == 1 and all(
        result["completeRowMismatchRows"] == 0
        for result in identity_v2["comparisons"].values()
    )
    direct_mediator = (
        identity_v1["directControls"]["status"] == "PASS"
        and identity_v1["directControls"]["oneExistingConsumerExact"]
        and identity_v1["directControls"]["randomBuildNullRngExact"]
        and identity_v1["directControls"]["saveRoundTripExact"]
    )
    representation_exact = (
        design["selectedCandidate"]["id"] == "choice-screen-existing-consumer"
        and design["selectedCandidate"]["newInternalIds"] == 0
        and design["selectedCandidate"]["newSaveFields"] == 0
        and not design["selectedCandidate"]["changesPayoff"]
    )
    measured_method_value = (
        capacity["newSupportRows"] > 0 or capacity["newCausalRows"] > 0
    )
    candidates = {
        "retune-closed-card-score-selector": {
            "eligible": False,
            "failure": "The exact score selector and threshold are closed by capacity."
        },
        "exogenous-explicit-existing-consumer-factor": {
            "eligible": selector_closed and null_identity and direct_mediator
                        and representation_exact,
            "failure": "" if selector_closed and null_identity and direct_mediator
                       and representation_exact else "A required identity or mediator gate failed."
        },
        "new-policy-method-ml-rl-or-optimiser": {
            "eligible": selector_closed and measured_method_value,
            "failure": "No enabled activation or causal observation measures method decision value."
        },
        "random-or-hash-assignment": {
            "eligible": False,
            "failure": "Assignment would not establish policy choice or exploitation."
        },
        "new-content-payoff-or-carrier": {
            "eligible": False,
            "failure": "Existing consumers, persistence and direct mediators are already exact."
        }
    }
    eligible = [name for name, value in candidates.items() if value["eligible"]]
    require("unique minimum", eligible == ["exogenous-explicit-existing-consumer-factor"])
    elapsed = time.monotonic() - started
    require("wall-time ceiling", elapsed <= protocol["budget"]["maximumWallTimeSeconds"])
    ledger_after = identity.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": 1,
        "decision": "freeze-exogenous-explicit-acquisition-factor-for-identity",
        "outcomeClass": "success",
        "protocolSha256": protocol_sha,
        "runnerSha256": immutable["runnerSha256"],
        "selectorClosed": selector_closed,
        "nullIdentityExact": null_identity,
        "directMediatorExact": direct_mediator,
        "representationExact": representation_exact,
        "measuredPolicyMethodDecisionValue": measured_method_value,
        "candidates": candidates,
        "eligibleCandidates": eligible,
        "selectedFactor": protocol["selectedFactor"],
        "newSimulatorObservationRows": 0,
        "supportRowsInspected": 0,
        "cacheFilesRead": 0,
        "newLedgerRows": 0,
        "GodotProcesses": 0,
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "maximumModelContextTokens": 0,
        "wallTimeSeconds": elapsed,
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "authority": protocol["decisionRules"]["successAuthority"],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS",
        "decision": summary["decision"],
        "newSimulatorObservationRows": 0,
        "summarySha256": core.file_sha(SUMMARY),
    }))


if __name__ == "__main__":
    main()
