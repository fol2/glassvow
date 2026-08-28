#!/usr/bin/env python3
"""Zero-row capacity audit for one deterministic package-commitment grammar."""

from __future__ import annotations

import json
import math
import sqlite3
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import post_v38_package_order_heldout as heldout
import post_v38_policy_package_order_decision_value_v2 as previous
import post_v38_heldout_confirmation as whole
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-package-commitment-capacity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-package-commitment-capacity-v1.json"


def require_equal(label: str, left: Any, right: Any) -> None:
    if left != right:
        raise RuntimeError(f"package-commitment capacity mismatch: {label}")


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite a completed capacity audit")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    runner_sha = core.file_sha(Path(__file__))
    require_equal("runner SHA", runner_sha, protocol["immutableInputs"]["runnerSha256"])
    for name, packet in protocol["immutableEvidence"].items():
        path = core.ROOT / packet["path"]
        require_equal(f"{name} SHA", core.file_sha(path), packet["sha256"])

    heldout_protocol, heldout_sha = core.load_protocol(heldout.PROTOCOL)
    require_equal("source protocol", heldout_sha, protocol["sourceEvidenceProtocol"])
    ledger_before = identity.ledger_identity()
    require_equal("ledger freeze", ledger_before, protocol["ledgerFreeze"])
    with sqlite3.connect(f"file:{core.LEDGER}?mode=ro", uri=True) as db:
        rows = [json.loads(payload) for (payload,) in db.execute(
            "SELECT payload_json FROM records WHERE kind = 'observation' "
            "AND identity LIKE ? ORDER BY seq",
            (f"{heldout_sha}:%",),
        )]
    null_rows = [
        row for row in rows
        if row["stage"].endswith("heldout-whole") and "-structuralNull-" in row["id"]
    ]
    require_equal(
        "structural-null row count", len(null_rows),
        heldout_protocol["budget"]["wholeRunRowsPerArm"],
    )
    whole.validate_rectangle(heldout_protocol, null_rows)
    _, policy_rows = whole.split_rows(null_rows)
    count = int(heldout_protocol["cohorts"]["policyIdentity"]["count"])
    snapshots = previous.policy_snapshots(policy_rows, count)
    active = heldout.activation_sets(heldout_protocol, policy_rows)

    relevant: dict[str, dict[int, list[dict[str, Any]]]] = {}
    reachable: dict[str, set[int]] = {}
    consumed: dict[str, set[int]] = {}
    offered: dict[str, set[int]] = {}
    acquired: dict[str, set[int]] = {}
    for package, spec in protocol["packages"].items():
        aspect = str(spec["aspect"])
        producer, consumer = str(spec["producer"]), str(spec["consumer"])
        relevant[package] = {
            index: [
                row for (found_aspect, found_index, _), row in policy_rows.items()
                if (found_aspect, found_index) == (aspect, index)
            ] for index in range(count)
        }
        reachable[package] = {
            index for index, found in relevant[package].items()
            if any({producer, consumer}.issubset(set(map(str, row.get("deckIds", []))))
                   for row in found)
        }
        consumed[package] = {
            index for index, found in relevant[package].items()
            if any(int((row.get("packageEvents") or {}).get(spec["consumedMetric"], 0)) > 0
                   and {producer, consumer}.issubset(set(map(str, row.get("deckIds", []))))
                   for row in found)
        }
        reward_ids = set(map(str, spec["gatedRewardIds"]))
        offered[package] = {
            index for index, found in relevant[package].items()
            if any(any(int((row.get("packageEvents") or {}).get(f"{card}Offered", 0)) > 0
                       for card in reward_ids) for row in found)
        }
        acquired[package] = {
            index for index, found in relevant[package].items()
            if any(reward_ids & set(map(str, row.get("deckIds", []))) for row in found)
        }

    preferred: dict[str, set[int]] = {package: set() for package in protocol["packages"]}
    ties_or_invalid: set[int] = set()
    for index, policy in snapshots.items():
        for aspect, packages in protocol["aspectPackages"].items():
            strengths: list[tuple[float, str]] = []
            for package in packages:
                factor = protocol["packages"][package]["preference"]
                value = float(policy[factor["group"]][factor["key"]])
                strength = value / float(factor["normaliser"])
                strengths.append((strength, package))
            if any(not math.isfinite(strength) for strength, _ in strengths) \
                    or strengths[0][0] == strengths[1][0]:
                ties_or_invalid.add(index)
            else:
                preferred[max(strengths)[1]].add(index)

    minimum_split = int(protocol["gates"]["minimumPreferredAndNonPreferredPolicies"])
    minimum_active = int(protocol["gates"]["minimumActiveAndInactivePolicies"])
    minimum_reachable = int(protocol["gates"]["minimumReachablePolicies"])
    minimum_interference = int(protocol["gates"]["minimumCrossActivePolicies"])
    package_results: dict[str, Any] = {}
    for aspect, packages in protocol["aspectPackages"].items():
        for package in packages:
            other = next(name for name in packages if name != package)
            selected = preferred[package]
            retained_active = active[package] & selected
            cross_active = retained_active & active[other]
            result = {
                "aspect": aspect,
                "preferredPolicies": len(selected),
                "nonPreferredPolicies": count - len(selected),
                "activeWhenPreferred": len(retained_active),
                "inactiveUnderStrictRetentionOracle": count - len(retained_active),
                "finalPairReachableWhenPreferred": len(reachable[package] & selected),
                "consumerReachedWithFinalPairWhenPreferred": len(consumed[package] & selected),
                "crossActiveWithNonPreferredPackage": len(cross_active),
                "nonPreferredRewardOfferedWhenPreferred": len(offered[other] & selected),
                "nonPreferredRewardAcquiredWhenPreferred": len(acquired[other] & selected),
                "preferenceSupportClear": len(selected) >= minimum_split
                and count - len(selected) >= minimum_split,
                "strictRetentionSensitivityClear": len(retained_active) >= minimum_active
                and count - len(retained_active) >= minimum_active,
                "reachabilityClear": len(reachable[package] & selected) >= minimum_reachable
                and len(consumed[package] & selected) >= minimum_reachable,
                "measuredInterferenceClear": len(cross_active) >= minimum_interference,
            }
            result["clear"] = all(
                result[key] for key in (
                    "preferenceSupportClear", "strictRetentionSensitivityClear",
                    "reachabilityClear", "measuredInterferenceClear",
                )
            )
            package_results[package] = result

    assignments = {package: sorted(indices) for package, indices in preferred.items()}
    clear = not ties_or_invalid and all(result["clear"] for result in package_results.values())
    decision = (
        "authorise-package-commitment-identity-preflight"
        if clear else "close-normalised-payoff-package-commitment-without-implementation"
    )
    if time.monotonic() - started > float(protocol["budget"]["maximumWallTimeSeconds"]):
        raise TimeoutError("package-commitment capacity audit exceeded its frozen ceiling")
    ledger_after = identity.ledger_identity()
    require_equal("append-only ledger", ledger_before, ledger_after)
    summary = {
        "schemaVersion": 1,
        "decisionBoundary": 1 if clear else 2,
        "decision": decision,
        "protocolSha256": protocol_sha,
        "runnerSha256": runner_sha,
        "sourceEvidenceProtocol": heldout_sha,
        "sourceStructuralNullRows": len(null_rows),
        "sourcePolicyRows": len(policy_rows),
        "policyIdentities": count,
        "preferenceAssignmentSha256": core.sha(core.canonical(assignments).encode()),
        "tiesOrInvalidPolicyIdentities": sorted(ties_or_invalid),
        "packageResults": package_results,
        "allCapacityGatesClear": clear,
        "retrospectiveScope": protocol["retrospectiveScope"],
        "newSimulatorObservationRows": 0,
        "protectedSeedRows": 0,
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "authority": protocol["decisionRules"][
            "successAuthority" if clear else "futilityAuthority"
        ],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical(summary))


if __name__ == "__main__":
    main()
