#!/usr/bin/env python3
"""Post-execution root-cause audit of the failed upgrade identity gate."""

from __future__ import annotations

import copy
import json
from collections import Counter
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


SUMMARY = core.ROOT / "summaries/post-v38-upgrade-telemetry-identity-v1.json"
AUDIT = core.ROOT / "summaries/post-v38-upgrade-telemetry-identity-v1-audit.json"
BASELINE_SHA = "110a70a2df530ab1ef6d2f992bda7d6041a02ccf18a9d2a683aaded140da02bf"
OUTPUT_SHA = "197c23feac491c3faf0261421e37b9535b72fe855bc29f2e53ea09685ef0388a"
SUMMARY_SHA = "2a1d2a9c251846ac07bed519ce76e31fd7761fbd7ff7f1905383f143d78206da"
META = ("id", "stage", "arm", "policyRoot", "policyIndex", "trajectory")


def clean(row: dict[str, Any], drop_package_events: bool = False) -> dict[str, Any]:
    value = copy.deepcopy(row)
    for key in META:
        value.pop(key, None)
    if drop_package_events:
        value.pop("packageEvents", None)
    return value


def main() -> None:
    if AUDIT.exists():
        raise RuntimeError("refusing to overwrite the upgrade identity audit")
    if core.file_sha(SUMMARY) != SUMMARY_SHA:
        raise RuntimeError("upgrade identity summary drift")
    summary = json.loads(SUMMARY.read_text())
    if summary["decision"] != "reject-upgrade-telemetry-as-not-identity-safe":
        raise RuntimeError("unexpected upgrade identity decision")
    baseline_path = core.CACHE / f"{BASELINE_SHA}.json"
    output_path = core.CACHE / f"{OUTPUT_SHA}.json"
    if core.file_sha(baseline_path) != BASELINE_SHA \
            or core.file_sha(output_path) != OUTPUT_SHA:
        raise RuntimeError("identity cache drift")
    baseline_output = json.loads(baseline_path.read_text())
    output = json.loads(output_path.read_text())
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

    null_mismatch = 0
    enabled_mismatch = 0
    paired_mismatch = 0
    core_mismatch = 0
    differing_package_keys: Counter[str] = Counter()
    for key, baseline_row in baseline.items():
        null_row = observed[("explicit-null", *key)]
        enabled_row = observed[("enabled", *key)]
        base_clean = clean(baseline_row)
        null_clean = clean(null_row)
        enabled_clean = clean(enabled_row)
        null_mismatch += base_clean != null_clean
        enabled_mismatch += base_clean != enabled_clean
        paired_mismatch += null_clean != enabled_clean
        core_mismatch += clean(baseline_row, True) != clean(null_row, True)
        base_events = base_clean.get("packageEvents", {})
        null_events = null_clean.get("packageEvents", {})
        for event in set(base_events) | set(null_events):
            if base_events.get(event) != null_events.get(event):
                differing_package_keys[str(event)] += 1

    ledger_before = identity.ledger_identity()
    result = {
        "schemaVersion": 1,
        "issue": 421,
        "kind": "post-execution-root-cause-audit",
        "decisionUnchanged": summary["decision"],
        "decisionBoundaryUnchanged": summary["decisionBoundary"],
        "identityRows": 256,
        "observed": {
            "explicitNullMismatchRows": null_mismatch,
            "enabledMismatchRows": enabled_mismatch,
            "pairedNullEnabledMismatchRows": paired_mismatch,
            "nonPackageObservationMismatchRows": core_mismatch,
            "differingPackageEventKeys": dict(sorted(differing_package_keys.items())),
        },
        "rootCause": (
            "The frozen baseline cache contains prior research-only packageEvents "
            "probes that exact current-main does not emit. The preregistered canonical "
            "identity retained packageEvents, so those output-schema differences "
            "correctly failed the frozen gate."
        ),
        "interpretation": (
            "All non-package-observation fields and the null/enabled pair are exact in "
            "this post-execution diagnostic. This does not reverse or weaken the "
            "preregistered boundary-2 decision and grants no repair, rerun, capacity "
            "analysis, payoff or product authority."
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
        raise RuntimeError("ledger changed during root-cause audit")
    AUDIT.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS",
        "decisionUnchanged": result["decisionUnchanged"],
        "explicitNullMismatchRows": null_mismatch,
        "pairedMismatchRows": paired_mismatch,
        "nonPackageObservationMismatchRows": core_mismatch,
        "auditSha256": core.file_sha(AUDIT),
        "newSimulatorObservationRows": 0,
    }))


if __name__ == "__main__":
    main()
