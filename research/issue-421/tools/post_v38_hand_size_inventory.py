#!/usr/bin/env python3
"""Zero-row current-inventory audit for hand-size, Poison and one state lock."""

from __future__ import annotations

import json
import sqlite3
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import post_v38_package_order_heldout as heldout
import post_v38_policy_package_order_decision_value_v2 as previous
import post_v38_heldout_confirmation as whole
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-hand-size-inventory-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-hand-size-inventory-v1.json"


def require_equal(label: str, left: Any, right: Any) -> None:
    if left != right:
        raise RuntimeError(f"hand-size inventory mismatch: {label}")


def git_blob_sha(commit: str, path: str) -> str:
    blob = subprocess.run(
        ["git", "show", f"{commit}:{path}"], cwd=core.SOURCE,
        check=True, capture_output=True,
    ).stdout
    return core.sha(blob)


def package_sets(
    protocol: dict[str, Any], heldout_protocol: dict[str, Any],
    policy_rows: dict[tuple[str, int, int], dict[str, Any]],
) -> dict[str, dict[str, set[int]]]:
    count = int(heldout_protocol["cohorts"]["policyIdentity"]["count"])
    result: dict[str, dict[str, set[int]]] = {}
    for package, spec in protocol["packages"].items():
        aspect = str(spec["aspect"])
        producers = set(map(str, spec["producers"]))
        consumer = str(spec["consumer"])
        relevant = {
            index: [
                row for (found_aspect, found_index, _), row in policy_rows.items()
                if (found_aspect, found_index) == (aspect, index)
            ] for index in range(count)
        }
        reachable = {
            index for index, rows in relevant.items()
            if any(consumer in set(map(str, row.get("deckIds", [])))
                   and bool(producers & set(map(str, row.get("deckIds", []))))
                   for row in rows)
        }
        if package == "ash-hand-size-payoff":
            active = {
                index for index in reachable
                if any(
                    int((row.get("packageEvents") or {}).get("phantomBladesPlayed", 0)) > 0
                    and int((row.get("packageEvents") or {}).get("phantomDamage", 0)) > 0
                    and any(int((row.get("packageEvents") or {}).get(f"{card}Played", 0)) > 0
                            for card in producers)
                    for row in relevant[index]
                )
            }
            consumed = set(active)
        else:
            old_spec = heldout_protocol["packages"][package]
            active = {
                index for index, rows in relevant.items()
                if any(core._package_activation(row, old_spec) > 0 for row in rows)
            }
            consumed = {
                index for index in reachable
                if any(int((row.get("packageEvents") or {}).get(spec["consumedMetric"], 0)) > 0
                       for row in relevant[index])
            }
        tokens = set(map(str, spec["lockTokens"]))
        token_acquired = {
            index for index, rows in relevant.items()
            if any(tokens & set(map(str, row.get("deckIds", []))) for row in rows)
        }
        result[package] = {
            "active": active,
            "reachable": reachable,
            "consumed": consumed,
            "tokenAcquired": token_acquired,
        }
    return result


def analyse_arm(
    protocol: dict[str, Any], heldout_protocol: dict[str, Any],
    policy_rows: dict[tuple[str, int, int], dict[str, Any]],
) -> dict[str, Any]:
    count = int(heldout_protocol["cohorts"]["policyIdentity"]["count"])
    minimum = int(protocol["gates"]["minimumActiveAndInactivePolicies"])
    reach_minimum = int(protocol["gates"]["minimumReachablePolicies"])
    separation_minimum = int(protocol["gates"]["minimumExclusivePolicies"])
    cross_minimum = int(protocol["gates"]["minimumCrossActivePolicies"])
    sets = package_sets(protocol, heldout_protocol, policy_rows)
    packages: dict[str, Any] = {}
    for name, found in sets.items():
        active = len(found["active"])
        packages[name] = {
            "active": active,
            "inactive": count - active,
            "finalPairReachable": len(found["reachable"]),
            "consumerReachedWithFinalPair": len(found["consumed"]),
            "sensitivityClear": active >= minimum and count - active >= minimum,
            "reachabilityClear": len(found["reachable"]) >= reach_minimum
            and len(found["consumed"]) >= reach_minimum,
        }
    aspects: dict[str, Any] = {}
    for aspect, names in protocol["aspectPackages"].items():
        left, right = names
        left_only = sets[left]["active"] - sets[right]["active"]
        right_only = sets[right]["active"] - sets[left]["active"]
        cross = sets[left]["active"] & sets[right]["active"]
        left_token_only = sets[left]["tokenAcquired"] - sets[right]["tokenAcquired"]
        right_token_only = sets[right]["tokenAcquired"] - sets[left]["tokenAcquired"]
        dual_tokens = sets[left]["tokenAcquired"] & sets[right]["tokenAcquired"]
        aspects[aspect] = {
            f"{left}Only": len(left_only),
            f"{right}Only": len(right_only),
            "crossActive": len(cross),
            f"{left}TokenOnly": len(left_token_only),
            f"{right}TokenOnly": len(right_token_only),
            "dualPackageTokens": len(dual_tokens),
            "functionalSeparationClear": len(left_only) >= separation_minimum
            and len(right_only) >= separation_minimum,
            "stateLockCapacityClear": len(cross) >= cross_minimum
            and len(left_token_only) >= separation_minimum
            and len(right_token_only) >= separation_minimum
            and len(dual_tokens) >= cross_minimum
            and all(packages[name]["active"] >= minimum
                    and packages[name]["reachabilityClear"] for name in names),
        }
    faults = sum(
        bool(row.get("error")) or str(row.get("outcome")) in ("stall", "error")
        for row in policy_rows.values()
    )
    full_clear = faults == 0 and all(
        result["sensitivityClear"] and result["reachabilityClear"]
        for result in packages.values()
    ) and all(result["functionalSeparationClear"] for result in aspects.values())
    lock_capacity = faults == 0 and all(
        result["stateLockCapacityClear"] for result in aspects.values()
    )
    return {
        "packages": packages,
        "aspects": aspects,
        "faults": faults,
        "fullPackageInventoryClear": full_clear,
        "stateLockCapacityClear": lock_capacity,
    }


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite a completed hand-size inventory audit")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    runner_sha = core.file_sha(Path(__file__))
    require_equal("runner SHA", runner_sha, protocol["immutableInputs"]["runnerSha256"])
    for name, packet in protocol["immutableEvidence"].items():
        require_equal(f"{name} SHA", core.file_sha(core.ROOT / packet["path"]), packet["sha256"])
    for name, packet in protocol["immutableGitEvidence"].items():
        require_equal(
            f"{name} Git blob SHA", git_blob_sha(packet["commit"], packet["path"]),
            packet["sha256"],
        )
    for path, expected in protocol["sourceReconciliation"]["files"].items():
        for commit in protocol["sourceReconciliation"]["commits"]:
            require_equal(f"{commit}:{path}", git_blob_sha(commit, path), expected)
    for name, packet in protocol["contentReconciliation"].items():
        path = core.CACHE / f"{packet['contentSha256']}.json"
        require_equal(f"{name} content SHA", core.file_sha(path), packet["contentSha256"])
        content = json.loads(path.read_text())
        card_packet = {card: content["cards"][card] for card in protocol["handSizeCards"]}
        require_equal(
            f"{name} hand-size card packet",
            core.sha(core.canonical(card_packet).encode()), packet["handSizeCardPacketSha256"],
        )

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
    arms: dict[str, dict[tuple[str, int, int], dict[str, Any]]] = {}
    snapshots: dict[str, dict[int, dict[str, Any]]] = {}
    for arm in protocol["arms"]:
        arm_rows = [
            row for row in rows
            if row["stage"].endswith("heldout-whole") and f"-{arm}-" in row["id"]
        ]
        require_equal(
            f"{arm} row count", len(arm_rows),
            heldout_protocol["budget"]["wholeRunRowsPerArm"],
        )
        whole.validate_rectangle(heldout_protocol, arm_rows)
        _, arms[arm] = whole.split_rows(arm_rows)
        snapshots[arm] = previous.policy_snapshots(
            arms[arm], int(heldout_protocol["cohorts"]["policyIdentity"]["count"])
        )
    anchor = snapshots[protocol["decisionArm"]]
    for arm, found in snapshots.items():
        require_equal(f"{arm} policy snapshots", found, anchor)
    results = {
        arm: analyse_arm(protocol, heldout_protocol, policy_rows)
        for arm, policy_rows in arms.items()
    }
    decision_result = results[protocol["decisionArm"]]
    if decision_result["fullPackageInventoryClear"]:
        boundary, decision = 1, "admit-current-four-package-inventory"
    elif decision_result["stateLockCapacityClear"]:
        boundary, decision = 2, "authorise-first-acquisition-state-lock-identity-preflight"
    else:
        boundary, decision = 2, "close-first-acquisition-state-lock-before-implementation"
    if time.monotonic() - started > float(protocol["budget"]["maximumWallTimeSeconds"]):
        raise TimeoutError("hand-size inventory audit exceeded its frozen ceiling")
    ledger_after = identity.ledger_identity()
    require_equal("append-only ledger", ledger_before, ledger_after)
    summary = {
        "schemaVersion": 1,
        "decisionBoundary": boundary,
        "decision": decision,
        "protocolSha256": protocol_sha,
        "runnerSha256": runner_sha,
        "sourceEvidenceProtocol": heldout_sha,
        "sourceReconciliationExact": True,
        "handSizeCardPacketSha256": protocol["contentReconciliation"]["live"][
            "handSizeCardPacketSha256"
        ],
        "policyIdentities": len(anchor),
        "armResults": results,
        "retrospectiveScope": protocol["retrospectiveScope"],
        "newSimulatorObservationRows": 0,
        "protectedSeedRows": 0,
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "authority": protocol["decisionRules"][
            "admissionAuthority" if decision_result["fullPackageInventoryClear"]
            else ("stateLockAuthority" if decision_result["stateLockCapacityClear"]
                  else "futilityAuthority")
        ],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical(summary))


if __name__ == "__main__":
    main()
