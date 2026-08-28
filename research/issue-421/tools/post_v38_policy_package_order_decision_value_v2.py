#!/usr/bin/env python3
"""Corrected zero-row decision-value audit for policy-selective ordering."""

from __future__ import annotations

import json
import sqlite3
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import post_v38_package_order_heldout as heldout
import post_v38_heldout_confirmation as whole
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-policy-package-order-decision-value-v2.json"
SUMMARY = core.ROOT / "summaries/post-v38-policy-package-order-decision-value-v2.json"


def require_equal(label: str, left: Any, right: Any) -> None:
    if left != right:
        raise RuntimeError(f"decision-value audit mismatch: {label}")


def policy_snapshots(
    policy_rows: dict[tuple[str, int, int], dict[str, Any]], count: int,
) -> dict[int, dict[str, Any]]:
    found: dict[int, dict[str, dict[str, Any]]] = {}
    for (_, index, _), row in policy_rows.items():
        policy = row.get("policy")
        if not isinstance(policy, dict):
            raise RuntimeError("held-out policy snapshot is absent")
        digest = core.sha(core.canonical(policy).encode())
        found.setdefault(index, {})[digest] = policy
    if len(found) != count or any(len(values) != 1 for values in found.values()):
        raise RuntimeError("held-out policy identity is not exact")
    return {index: next(iter(values.values())) for index, values in found.items()}


def functional_separation(
    protocol: dict[str, Any], active: dict[str, set[int]],
) -> dict[str, Any]:
    result: dict[str, Any] = {}
    minimum = int(protocol["gates"]["minimumExclusivePolicies"])
    for aspect, packages in protocol["aspectPackages"].items():
        left, right = packages
        left_only = len(active[left] - active[right])
        right_only = len(active[right] - active[left])
        result[aspect] = {
            f"{left}Only": left_only,
            f"{right}Only": right_only,
            "clear": left_only >= minimum and right_only >= minimum,
        }
    return result


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite a completed decision-value audit")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    runner_sha = core.file_sha(Path(__file__))
    require_equal("runner SHA", runner_sha, protocol["immutableInputs"]["runnerSha256"])
    for name, packet in protocol["immutableEvidence"].items():
        path = core.ROOT / packet["path"]
        require_equal(f"{name} SHA", core.file_sha(path), packet["sha256"])
    heldout_protocol, heldout_sha = core.load_protocol(heldout.PROTOCOL)
    require_equal("held-out protocol identity", heldout_sha, protocol["sourceEvidenceProtocol"])
    ledger_before = identity.ledger_identity()
    require_equal("ledger freeze", ledger_before, protocol["ledgerFreeze"])

    with sqlite3.connect(f"file:{core.LEDGER}?mode=ro", uri=True) as db:
        rows = [json.loads(payload) for (payload,) in db.execute(
            "SELECT payload_json FROM records WHERE kind = 'observation' "
            "AND identity LIKE ? ORDER BY seq",
            (f"{heldout_sha}:%",),
        )]
    whole_rows = [row for row in rows if row["stage"].endswith("heldout-whole")]
    arms: dict[str, list[dict[str, Any]]] = {
        arm: [row for row in whole_rows if f"-{arm}-" in row["id"]]
        for arm in ("structuralCandidate", "structuralNull")
    }
    for arm, arm_rows in arms.items():
        require_equal(
            f"{arm} row count", len(arm_rows),
            heldout_protocol["budget"]["wholeRunRowsPerArm"],
        )
        whole.validate_rectangle(heldout_protocol, arm_rows)
    candidate_policy = whole.split_rows(arms["structuralCandidate"])[1]
    null_policy = whole.split_rows(arms["structuralNull"])[1]
    require_equal("candidate-null policy rectangle", set(candidate_policy), set(null_policy))
    count = int(heldout_protocol["cohorts"]["policyIdentity"]["count"])
    candidate_snapshots = policy_snapshots(candidate_policy, count)
    null_snapshots = policy_snapshots(null_policy, count)
    require_equal("candidate-null policy snapshots", candidate_snapshots, null_snapshots)

    candidate_active = heldout.activation_sets(heldout_protocol, candidate_policy)
    null_active = heldout.activation_sets(heldout_protocol, null_policy)
    splice_active: dict[str, set[int]] = {}
    package_results: dict[str, Any] = {}
    minimum = int(protocol["gates"]["minimumActiveAndInactivePolicies"])
    minimum_eligible = int(protocol["gates"]["minimumEligibleAndIneligiblePolicies"])
    for package, factor in protocol["packagePreferences"].items():
        group, key = factor["group"], factor["key"]
        threshold = float(factor["threshold"])
        eligible = {
            index for index, policy in candidate_snapshots.items()
            if float(policy[group][key]) >= threshold
        }
        ineligible = set(candidate_snapshots) - eligible
        splice = (candidate_active[package] & eligible) | (
            null_active[package] & ineligible
        )
        splice_active[package] = splice
        intersection = candidate_active[package] & null_active[package]
        candidate_gains = candidate_active[package] - null_active[package]
        candidate_losses = null_active[package] - candidate_active[package]
        package_results[package] = {
            "preference": f"{group}.{key}",
            "threshold": threshold,
            "eligible": len(eligible),
            "ineligible": len(ineligible),
            "eligibilityClear": (
                len(eligible) >= minimum_eligible and len(ineligible) >= minimum_eligible
            ),
            "candidateActive": len(candidate_active[package]),
            "nullActive": len(null_active[package]),
            "candidateGains": len(candidate_gains),
            "candidateLosses": len(candidate_losses),
            "eligibleGains": len(candidate_gains & eligible),
            "eligibleLosses": len(candidate_losses & eligible),
            "noInterferenceSpliceActive": len(splice),
            "noInterferenceSpliceInactive": count - len(splice),
            "noInterferenceSpliceSensitivityClear": (
                len(splice) >= minimum and count - len(splice) >= minimum
            ),
            "observedEndpointIntersectionActive": len(intersection),
            "maximumInactiveBySelectingObservedCandidateOrNullEndpoint": (
                count - len(intersection)
            ),
            "observedEndpointSelectionCanMeetInactiveMinimum": (
                count - len(intersection) >= minimum
            ),
        }

    separation = functional_separation(protocol, splice_active)
    eligibility_clear = all(row["eligibilityClear"] for row in package_results.values())
    sensitivity_clear = all(
        row["noInterferenceSpliceSensitivityClear"]
        and row["observedEndpointSelectionCanMeetInactiveMinimum"]
        for row in package_results.values()
    )
    separation_clear = all(row["clear"] for row in separation.values())
    decision_value = eligibility_clear and sensitivity_clear and separation_clear
    boundary = 1 if decision_value else 2
    decision = (
        "authorise-policy-package-order-crn"
        if decision_value
        else "close-positive-median-policy-package-order-without-new-simulator-rows"
    )
    if time.monotonic() - started > float(protocol["budget"]["maximumWallTimeSeconds"]):
        raise TimeoutError("decision-value audit exceeded its frozen wall-time ceiling")
    ledger_after = identity.ledger_identity()
    require_equal("append-only ledger", ledger_before, ledger_after)
    summary = {
        "schemaVersion": 1,
        "decisionBoundary": boundary,
        "decision": decision,
        "protocolSha256": protocol_sha,
        "runnerSha256": runner_sha,
        "sourceEvidenceProtocol": heldout_sha,
        "sourceWholeRunObservationRows": len(whole_rows),
        "policyIdentities": count,
        "packageResults": package_results,
        "noInterferenceSpliceFunctionalSeparation": separation,
        "eligibilityClear": eligibility_clear,
        "sensitivityClear": sensitivity_clear,
        "functionalSeparationClear": separation_clear,
        "measuredDecisionValue": decision_value,
        "retrospectiveScope": protocol["retrospectiveScope"],
        "newSimulatorObservationRows": 0,
        "protectedSeedRows": 0,
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "authority": protocol["decisionRules"][
            "successAuthority" if boundary == 1 else "futilityAuthority"
        ],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical(summary))


if __name__ == "__main__":
    main()
