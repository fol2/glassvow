#!/usr/bin/env python3
"""Audit the failed upgrade identity evidence and the narrower v1 diagnostic."""

from __future__ import annotations

import copy
import json
from collections import Counter
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


IDENTITY_PROTOCOL = core.ROOT / "protocols/post-v38-upgrade-telemetry-identity-v1.json"
IDENTITY_SUMMARY = core.ROOT / "summaries/post-v38-upgrade-telemetry-identity-v1.json"
AUDIT_V1 = core.ROOT / "summaries/post-v38-upgrade-telemetry-identity-v1-audit.json"
WARD_PROTOCOL = core.ROOT / "protocols/post-v38-ward-whole-run-discovery-v1.json"
AUDIT_V2 = core.ROOT / "summaries/post-v38-upgrade-telemetry-identity-v2-audit.json"
BASELINE_SHA = "110a70a2df530ab1ef6d2f992bda7d6041a02ccf18a9d2a683aaded140da02bf"
BASELINE_PLAN_SHA = "bf8c76c05d363115c4f6f28f480f11c0504012e19bda7d26fe0cbcc54d1ad67f"
OUTPUT_SHA = "197c23feac491c3faf0261421e37b9535b72fe855bc29f2e53ea09685ef0388a"
EXPECTED = {
    IDENTITY_PROTOCOL: "eab3d8a629f48751665950c5fabdc968e1296ac026f3305b70ad3f952ef5966f",
    IDENTITY_SUMMARY: "2a1d2a9c251846ac07bed519ce76e31fd7761fbd7ff7f1905383f143d78206da",
    AUDIT_V1: "cb3cab9e9671f82964eb8b398531f25775ff28d0c91b985763085cdc839998fb",
    WARD_PROTOCOL: "bfc892c8c1c931294b38309319524cbeed455fd56eecf4a479b5642b565798aa",
}
META = ("id", "stage", "arm", "policyRoot", "policyIndex", "trajectory")


def clean(row: dict[str, Any]) -> dict[str, Any]:
    value = copy.deepcopy(row)
    for key in META:
        value.pop(key, None)
    return value


def main() -> None:
    if AUDIT_V2.exists():
        raise RuntimeError("refusing to overwrite the v2 upgrade identity audit")
    for path, expected_sha in EXPECTED.items():
        if core.file_sha(path) != expected_sha:
            raise RuntimeError(f"immutable evidence drift: {path.name}")
    identity_protocol = json.loads(IDENTITY_PROTOCOL.read_text())
    identity_summary = json.loads(IDENTITY_SUMMARY.read_text())
    audit_v1 = json.loads(AUDIT_V1.read_text())
    ward_protocol = json.loads(WARD_PROTOCOL.read_text())
    if identity_summary["decision"] != "reject-upgrade-telemetry-as-not-identity-safe":
        raise RuntimeError("unexpected identity decision")
    if audit_v1["observed"]["nonPackageObservationMismatchRows"] != 198:
        raise RuntimeError("v1 diagnostic count drift")
    baseline_plan_path = core.CACHE / f"{BASELINE_PLAN_SHA}.json"
    baseline_path = core.CACHE / f"{BASELINE_SHA}.json"
    output_path = core.CACHE / f"{OUTPUT_SHA}.json"
    for path, expected_sha in (
        (baseline_plan_path, BASELINE_PLAN_SHA),
        (baseline_path, BASELINE_SHA),
        (output_path, OUTPUT_SHA),
    ):
        if core.file_sha(path) != expected_sha:
            raise RuntimeError(f"cache drift: {expected_sha}")
    baseline_plan = json.loads(baseline_plan_path.read_text())
    baseline_output = json.loads(baseline_path.read_text())
    output = json.loads(output_path.read_text())
    if baseline_plan["protocolSha256"] != EXPECTED[WARD_PROTOCOL]:
        raise RuntimeError("baseline plan is not the frozen Ward research plan")
    if baseline_output["runnerSha256"] != \
            ward_protocol["immutableInputs"]["probeSha256"]:
        raise RuntimeError("baseline probe provenance drift")

    baseline = {
        (int(row["policyIndex"]), int(row["seed"])): row
        for row in baseline_output["rows"]
        if row.get("arm") == "policy" and row.get("aspect") == "duskblade"
        and int(row.get("vow", -1)) == 5
    }
    observed = {
        (str(row["arm"]), int(row["policyIndex"]), int(row["seed"])): row
        for row in output["rows"]
    }
    if len(baseline) != 256 or len(observed) != 512:
        raise RuntimeError("identity rectangle drift")

    top_level_differences: Counter[str] = Counter()
    outcome_transitions: Counter[str] = Counter()
    core_mismatch_rows = 0
    paired_mismatch_rows = 0
    policy_mismatch_rows = 0
    rng_mismatch_rows = 0
    for key, baseline_row in baseline.items():
        null_row = observed[("explicit-null", *key)]
        enabled_row = observed[("enabled", *key)]
        base_clean = clean(baseline_row)
        null_clean = clean(null_row)
        enabled_clean = clean(enabled_row)
        paired_mismatch_rows += null_clean != enabled_clean
        for field in set(base_clean) | set(null_clean):
            if base_clean.get(field) != null_clean.get(field):
                top_level_differences[str(field)] += 1
        base_core = copy.deepcopy(base_clean)
        null_core = copy.deepcopy(null_clean)
        base_core.pop("packageEvents", None)
        null_core.pop("packageEvents", None)
        core_mismatch_rows += base_core != null_core
        policy_mismatch_rows += base_clean.get("policy") != null_clean.get("policy")
        rng_mismatch_rows += base_clean.get("rng") != null_clean.get("rng")
        outcome_transitions[
            f"{base_clean.get('outcome')}->{null_clean.get('outcome')}"
        ] += 1

    old_inputs = ward_protocol["immutableInputs"]
    current_blobs = identity_protocol["immutableInputs"]["currentMainBlobSha256"]
    source_comparison = {
        "contentSha256Equal": (
            ward_protocol["baseline"]["contentSha256"] ==
            identity_protocol["baseline"]["contentSha256"]
        ),
        "policyBlobSha256Equal": (
            old_inputs["balancePolicySha256"] ==
            current_blobs["tools/balance_policy.gd"]
        ),
        "pilotBlobSha256Equal": (
            old_inputs["pilotSha256"] ==
            current_blobs["tools/balance_pilot.gd"]
        ),
        "simulatorBlobSha256Equal": (
            old_inputs["balanceSimSha256"] ==
            current_blobs["tools/balance_sim.gd"]
        ),
        "historicalResearchPilotSha256": old_inputs["pilotSha256"],
        "currentMainPilotSha256": current_blobs["tools/balance_pilot.gd"],
        "historicalResearchSimulatorSha256": old_inputs["balanceSimSha256"],
        "currentMainSimulatorSha256": current_blobs["tools/balance_sim.gd"],
    }
    ledger_before = identity.ledger_identity()
    result = {
        "schemaVersion": 2,
        "issue": 421,
        "kind": "post-execution-audit-of-audit",
        "decisionUnchanged": identity_summary["decision"],
        "decisionBoundaryUnchanged": identity_summary["decisionBoundary"],
        "v1DiagnosticDefect": {
            "claim": audit_v1["interpretation"],
            "contradictingOwnCount": audit_v1["observed"]
            ["nonPackageObservationMismatchRows"],
            "disposition": "Preserve v1 unchanged; this v2 audit supersedes only its root-cause interpretation and grants no decision authority.",
        },
        "identityRows": 256,
        "observed": {
            "pairedNullEnabledMismatchRows": paired_mismatch_rows,
            "nonPackageObservationMismatchRows": core_mismatch_rows,
            "policyVectorMismatchRows": policy_mismatch_rows,
            "rngMismatchRows": rng_mismatch_rows,
            "topLevelDifferenceRowCounts": dict(sorted(top_level_differences.items())),
            "outcomeTransitions": dict(sorted(outcome_transitions.items())),
        },
        "baselineProvenance": {
            "planSha256": BASELINE_PLAN_SHA,
            "protocol": str(WARD_PROTOCOL.relative_to(core.ROOT)),
            "protocolSha256": EXPECTED[WARD_PROTOCOL],
            "runnerSha256": baseline_output["runnerSha256"],
            "declaredBaseline": ward_protocol["baseline"],
            "sourceComparison": source_comparison,
        },
        "rootCause": (
            "The reused baseline is the current-main content arm of the frozen Ward "
            "research experiment, executed with research-modified Pilot and "
            "BalanceSim blobs. The new explicit-null and enabled arms use exact "
            "current-main Pilot and policy blobs plus the isolated telemetry patch. "
            "Their identical pair does not make either equal to the older research "
            "simulator. The strict preregistered baseline identity therefore fails "
            "on genuine path, RNG, deck, fight and outcome differences."
        ),
        "interpretation": (
            "The old cache is valid evidence for contrasts that froze its research "
            "simulator and policy implementation, but it is not a pristine "
            "current-main simulator identity anchor. The upgrade telemetry remains "
            "rejected under its protocol; no repair, rerun, capacity analysis, "
            "payoff or product claim is authorised."
        ),
        "newSimulatorObservationRows": 0,
        "ledgerBefore": ledger_before,
        "ledgerAfter": identity.ledger_identity(),
        "newLedgerRows": 0,
        "protectedSeedRows": ledger_before["protectedSeedRows"],
        "maximumModelContextTokens": 0,
        "runnerSha256": core.file_sha(Path(__file__)),
    }
    if result["ledgerAfter"] != ledger_before:
        raise RuntimeError("ledger changed during v2 audit")
    AUDIT_V2.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS",
        "decisionUnchanged": result["decisionUnchanged"],
        "pairedMismatchRows": paired_mismatch_rows,
        "nonPackageObservationMismatchRows": core_mismatch_rows,
        "rngMismatchRows": rng_mismatch_rows,
        "auditSha256": core.file_sha(AUDIT_V2),
        "newSimulatorObservationRows": 0,
    }))


if __name__ == "__main__":
    main()
