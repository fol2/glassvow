#!/usr/bin/env python3
"""Zero-row whole-run admission audit for hand-size and Bloodfire."""

from __future__ import annotations

import json
import sqlite3
import time
from pathlib import Path
from typing import Any

import post_v38_hand_size_inventory as inventory
import post_v38_knob_identity as identity
import post_v38_package_order_heldout as heldout
import post_v38_policy_package_order_decision_value_v2 as previous
import post_v38_heldout_confirmation as whole
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-ash-package-pair-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-ash-package-pair-v1.json"


def require_equal(label: str, left: Any, right: Any) -> None:
    if left != right:
        raise RuntimeError(f"Ash package-pair mismatch: {label}")


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite a completed Ash package-pair audit")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    runner_sha = core.file_sha(Path(__file__))
    require_equal("runner SHA", runner_sha, protocol["immutableInputs"]["runnerSha256"])
    for name, packet in protocol["immutableEvidence"].items():
        require_equal(f"{name} SHA", core.file_sha(core.ROOT / packet["path"]), packet["sha256"])
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
    arm_rows = [
        row for row in rows
        if row["stage"].endswith("heldout-whole") and "-structuralNull-" in row["id"]
    ]
    require_equal(
        "structural-null row count", len(arm_rows),
        heldout_protocol["budget"]["wholeRunRowsPerArm"],
    )
    whole.validate_rectangle(heldout_protocol, arm_rows)
    _, policy_rows = whole.split_rows(arm_rows)
    count = int(heldout_protocol["cohorts"]["policyIdentity"]["count"])
    snapshots = previous.policy_snapshots(policy_rows, count)
    result = inventory.analyse_arm(protocol, heldout_protocol, policy_rows)
    clear = result["fullPackageInventoryClear"]
    if time.monotonic() - started > float(protocol["budget"]["maximumWallTimeSeconds"]):
        raise TimeoutError("Ash package-pair audit exceeded its frozen ceiling")
    ledger_after = identity.ledger_identity()
    require_equal("append-only ledger", ledger_before, ledger_after)
    summary = {
        "schemaVersion": 1,
        "decisionBoundary": 1 if clear else 2,
        "decision": "admit-ash-hand-size-bloodfire-pair" if clear
        else "close-ash-hand-size-bloodfire-pair",
        "protocolSha256": protocol_sha,
        "runnerSha256": runner_sha,
        "sourceEvidenceProtocol": heldout_sha,
        "policyIdentities": len(snapshots),
        "structuralNull": result,
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
