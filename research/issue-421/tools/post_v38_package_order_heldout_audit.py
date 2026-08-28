#!/usr/bin/env python3
"""Read-only audit of the issue #421 package-order held-out result."""

from __future__ import annotations

import json
import sqlite3
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import post_v38_package_order_heldout as heldout
import research as core


PROTOCOL_SHA = "4b13f4c053b87ebcc21f78dc1623d8b3bd406c14dce41c07124dbef3e9b56d2e"
ANALYSIS_SHA = "1d855508351e2b9d16efadece99c6ed86a331127e00fc43dcd092f6b20769393"
SUMMARY_SHA = "853df2c3988270f3d1236b51177b85d014b92e200bad52fc05a66059a3985070"
AUDIT = core.ROOT / "summaries/post-v38-package-order-heldout-v1-audit.json"


def require_equal(label: str, left: Any, right: Any) -> None:
    if left != right:
        raise RuntimeError(f"audit mismatch: {label}")


def main() -> None:
    if AUDIT.exists():
        raise RuntimeError("refusing to overwrite an existing held-out audit")
    protocol, protocol_sha = core.load_protocol(heldout.PROTOCOL)
    require_equal("protocol SHA", protocol_sha, PROTOCOL_SHA)
    require_equal("summary SHA", core.file_sha(heldout.SUMMARY), SUMMARY_SHA)
    summary = json.loads(heldout.SUMMARY.read_text())
    require_equal("summary analysis SHA", summary["analysisSha256"], ANALYSIS_SHA)
    analysis_path = core.CACHE / f"{ANALYSIS_SHA}.json"
    require_equal("analysis object SHA", core.file_sha(analysis_path), ANALYSIS_SHA)
    analysis = json.loads(analysis_path.read_text())
    with sqlite3.connect(f"file:{core.LEDGER}?mode=ro", uri=True) as db:
        rows = [json.loads(row[0]) for row in db.execute(
            "SELECT payload_json FROM records WHERE kind = 'observation' "
            "AND identity LIKE ? ORDER BY seq",
            (f"{PROTOCOL_SHA}:%",),
        )]
        protected = int(db.execute(
            "SELECT COUNT(*) FROM records WHERE kind = 'observation' "
            "AND identity LIKE ? AND CAST(json_extract(payload_json, '$.seed') AS INTEGER) "
            "BETWEEN 3000 AND 5399",
            (f"{PROTOCOL_SHA}:%",),
        ).fetchone()[0])
    require_equal("observation count", len(rows), summary["newSimulatorObservationRows"])
    require_equal("protected observations", protected, 0)
    local_rows = [row for row in rows if row["stage"].endswith("heldout-local")]
    require_equal(
        "local rows", len(local_rows), protocol["budget"]["localSimulatorObservationRows"]
    )
    local = heldout.analyse_local(protocol, local_rows)
    require_equal("local analysis", local, analysis["localHeldout"])
    arms: dict[str, list[dict[str, Any]]] = {}
    for arm in protocol["wholeRunArms"]:
        arms[arm] = [
            row for row in rows
            if row["stage"].endswith("heldout-whole") and f"-{arm}-" in row["id"]
        ]
        require_equal(
            f"{arm} rows", len(arms[arm]), protocol["budget"]["wholeRunRowsPerArm"]
        )
    whole = heldout.analyse_whole(
        protocol, arms, heldout.excluded_policy_hashes(protocol)
    )
    require_equal("whole-run analysis", whole, analysis["wholeRunHeldout"])
    expected_ids = {row["id"] for row in heldout.local_rows(protocol)}
    for arm in protocol["wholeRunArms"]:
        expected_ids.update(row["id"] for row in heldout.whole_rows(protocol, arm))
    require_equal("complete deterministic row identities", {row["id"] for row in rows}, expected_ids)
    require_equal("decision", whole["decision"], summary["decision"])
    require_equal("decision boundary", whole["decisionBoundary"], summary["decisionBoundary"])
    packages = whole["strategyPackageActivation"]
    failed = {
        name: result for name, result in packages["packages"].items()
        if not result["sensitivityClear"] or not result["reachabilityClear"]
    }
    failed_separation = {
        aspect: result for aspect, result in packages["functionalSeparation"].items()
        if not result["clear"]
    }
    ledger = identity.ledger_identity()
    result = {
        "schemaVersion": 1,
        "decision": "package-order-heldout-audit-pass",
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(core.ROOT / "post_v38_package_order_heldout.py"),
        "auditRunnerSha256": core.file_sha(Path(__file__)),
        "summaryFileSha256": SUMMARY_SHA,
        "analysisSha256": ANALYSIS_SHA,
        "heldoutDecision": whole["decision"],
        "decisionBoundary": whole["decisionBoundary"],
        "rows": len(rows),
        "protectedSeedRows": protected,
        "localAllPackagesClear": all(
            row["clear"] for row in local["packagesAtOrderOn"].values()
        ),
        "localAfterimageStructuralGain": local["afterimageStructuralGain"],
        "policyIdentityClear": whole["policyIdentityAudit"]["clear"],
        "liveGuardrailsClear": all(
            whole["candidateVersusLiveGuardrails"][key]
            for key in ("randomBuildClear", "policyFixedClear", "durationClear")
        ),
        "structuralNullGuardrailsClear": all(
            whole["candidateVersusStructuralNullGuardrails"][key]
            for key in ("randomBuildClear", "policyFixedClear", "durationClear")
        ),
        "failedPackageSensitivityOrReachability": failed,
        "failedFunctionalSeparation": failed_separation,
        "allRowsAndDecisionRecomputed": True,
        "ledger": ledger,
        "authority": summary["authority"],
    }
    AUDIT.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS",
        "auditSha256": core.file_sha(AUDIT),
        "rows": len(rows),
        "protectedSeedRows": protected,
    }))


if __name__ == "__main__":
    main()
