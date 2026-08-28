#!/usr/bin/env python3
"""Read-only audit of the issue #421 package-order discovery."""

from __future__ import annotations

import json
import sqlite3
from pathlib import Path
from typing import Any

import post_v38_exact_complementarity as exact
import post_v38_knob_identity as identity
import post_v38_package_order_discovery as discovery
import research as core


PROTOCOL_SHA = "134d908c9db8998413e3c9858f3b9a9a09deb125ca779a23218a7a923ca549dd"
ANALYSIS_SHA = "4e6f7e53f853ca44040a7851940717cc3fa8d612741ec8f53ed89c53ea31138f"
SUMMARY_SHA = "0a09fd5108d1e1313657966b72cad435e9081a0b4f389793979d7365acd31f09"
AUDIT = core.ROOT / "summaries/post-v38-package-order-discovery-v1-audit.json"


def require_equal(label: str, left: Any, right: Any) -> None:
    if left != right:
        raise RuntimeError(f"audit mismatch: {label}")


def main() -> None:
    if AUDIT.exists():
        raise RuntimeError("refusing to overwrite an existing discovery audit")
    protocol, protocol_sha = core.load_protocol(discovery.PROTOCOL)
    require_equal("protocol SHA", protocol_sha, PROTOCOL_SHA)
    require_equal("summary SHA", core.file_sha(discovery.SUMMARY), SUMMARY_SHA)
    summary = json.loads(discovery.SUMMARY.read_text())
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
    require_equal(
        "observation count", len(rows), summary["newSimulatorObservationRows"]
    )
    require_equal("protected observations", protected, 0)
    initial = [
        row for row in rows
        if "package-order-1" in row["context"]
        or row["package"] == discovery.AFTERIMAGE
        or row["arm"] == "AB"
    ]
    require_equal(
        "initial row count", len(initial),
        protocol["budget"]["initialSimulatorObservationRows"],
    )
    recomputed, expansions = discovery.analyse_initial(protocol, initial)
    require_equal("optional expansions", expansions, summary["optionalExpansions"])
    for key, value in recomputed.items():
        require_equal(key, value, analysis[key])
    expanded: dict[str, Any] = {}
    for package in expansions:
        expanded[package] = {
            "packageAtOrderOff": exact.package_result(
                protocol, package, discovery.cells(rows, package, 0)
            ),
            "structureGain": discovery.structural_gain(
                protocol, package,
                discovery.cells(rows, package, 0),
                discovery.cells(rows, package, 1),
            ),
        }
    require_equal(
        "expanded analyses", expanded, analysis.get("expandedOrderOffPackages", {})
    )
    expected_rows = discovery.initial_rows(protocol)
    for package in expansions:
        expected_rows.extend(discovery.panel_rows(
            protocol, package, 0, ("none", "A", "B")
        ))
    require_equal(
        "complete deterministic row identities",
        {row["id"] for row in rows}, {row["id"] for row in expected_rows},
    )
    boundary, decision = discovery.decision(protocol, recomputed)
    require_equal("decision boundary", boundary, summary["decisionBoundary"])
    require_equal("decision", decision, summary["decision"])
    ledger = identity.ledger_identity()
    result = {
        "schemaVersion": 1,
        "decision": "package-order-discovery-audit-pass",
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(
            core.ROOT / "post_v38_package_order_discovery.py"
        ),
        "auditRunnerSha256": core.file_sha(Path(__file__)),
        "summaryFileSha256": SUMMARY_SHA,
        "analysisSha256": ANALYSIS_SHA,
        "decisionBoundary": boundary,
        "discoveryDecision": decision,
        "rows": len(rows),
        "optionalExpansions": expansions,
        "protectedSeedRows": protected,
        "afterimage": {
            "offClear": recomputed["afterimageAtOrderOff"]["clear"],
            "offWitnesses": recomputed["afterimageAtOrderOff"]["mechanismWitnesses"],
            "onClear": recomputed["packagesAtOrderOn"][discovery.AFTERIMAGE]["clear"],
            "onWitnesses": recomputed["packagesAtOrderOn"][discovery.AFTERIMAGE][
                "mechanismWitnesses"
            ],
            "structuralGain": recomputed["afterimageStructureGain"],
        },
        "allOrderOnPackagesClear": all(
            row["clear"] for row in recomputed["packagesAtOrderOn"].values()
        ),
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
