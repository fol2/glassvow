#!/usr/bin/env python3
"""Zero-row design audit for the post-b7b5099 Ward-spend family."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-b7b5099-ward-spend-design-v1.json"
SUMMARY = core.ROOT / "summaries/post-b7b5099-ward-spend-design-v1.json"
ORDER = [
    "producer", "mediatorState", "consumer", "payoffOperation",
    "lifecycleExpiry", "naturalCost", "duskBoundary", "scorelineFactor",
    "afterimageFactor", "interferenceRule", "nullPath", "policyExposure",
]


def git(*args: str) -> bytes:
    return subprocess.run(
        ["git", *args], cwd=Path("/Users/jamesto/Coding/glassvow"),
        check=True, capture_output=True,
    ).stdout


def source_bytes(head: str, path: str) -> bytes:
    return git("show", f"{head}:{path}")


def run() -> dict[str, Any]:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite completed Ward-spend design audit")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    immutable = protocol["immutableInputs"]
    faults: list[str] = []

    actual_head = git("rev-parse", "origin/main").decode().strip()
    if actual_head != immutable["sourceHead"]:
        faults.append("origin/main identity drift")
    actual_archive = subprocess.run(
        ["git", "ls-remote", "origin",
         "refs/heads/research/issue-421-post-810264c-private-causal-coverage-evidence"],
        cwd=immutable["repositoryPath"], check=True, text=True,
        capture_output=True,
    ).stdout.split()[0]
    if actual_archive != immutable["archiveHead"]:
        faults.append("archive b7b5099 identity drift")

    source_map = {
        "contentSha256": "content/full-content.json",
        "combatRulesSha256": "domain/rules/combat.gd",
        "playerCombatantSha256": "domain/state/player_combatant.gd",
        "balanceSimSha256": "tools/balance_sim.gd",
        "balancePilotSha256": "tools/balance_pilot.gd",
        "balancePolicySha256": "tools/balance_policy.gd",
    }
    for key, path in source_map.items():
        if core.sha(source_bytes(actual_head, path)) != immutable[key]:
            faults.append(f"source identity drift: {path}")

    content = json.loads(source_bytes(actual_head, "content/full-content.json"))
    expected_cards = {
        "brace": (1, 8, 11),
        "bulwark": (2, 13, 18),
        "guardedStrike": (1, 5, 7),
    }
    for card_id, (cost, base, upgraded) in expected_cards.items():
        card = content["cards"][card_id]
        if (card["cost"], card["effects"][0]["n"],
                card["up"]["effects"][0]["n"]) != (cost, base, upgraded):
            faults.append(f"current-main card basis drift: {card_id}")
    if "mirrorEdge" in content["cards"] or "mirrorEdge" in content["cardPools"]["common"]:
        faults.append("current-main unexpectedly contains mirrorEdge")

    contract = protocol["selectedContract"]
    if protocol["twelveFieldOrder"] != ORDER or list(contract) != ORDER:
        faults.append("twelve-field contract order or cardinality drift")
    if any(not isinstance(contract.get(key), str) or not contract[key]
           for key in ORDER):
        faults.append("twelve-field contract is incomplete")

    factors = protocol["causalFactors"]
    cells = [
        (spend, numerator, spend * numerator // 2)
        for spend in factors["spend"]
        for numerator in factors["payoffNumeratorPerTwoWard"]
    ]
    if cells != [(4, 1, 2), (4, 2, 4), (8, 1, 4), (8, 2, 8)]:
        faults.append("finite spend/payoff grid drift")
    if factors["producerLevel"] != ["brace", "bulwark-conditional-fallback"]:
        faults.append("producer fallback order drift")
    if protocol["budgets"]["protectedSeeds"] != 0 \
            or protocol["budgets"]["optimiserRows"] != 0:
        faults.append("protected or optimiser budget is non-zero")
    seeds = protocol["cohorts"]["capacityAndCrnSeeds"]
    if any(3000 <= int(seed) <= 5399 for seed in seeds):
        faults.append("protected seed entered research cohort")

    ledger_before = immutable["ledgerFreeze"]
    ledger_after = identity.ledger_identity()
    if ledger_after != ledger_before:
        faults.append("append-only ledger drifted before design decision")
    elapsed = time.monotonic() - started
    if elapsed > protocol["budgets"]["design"]["maximumWallTimeSeconds"]:
        outcome = "inconclusive"
        decision = "record-ward-spend-design-inconclusive-at-zero-row-cap"
    elif faults:
        outcome = "futility"
        decision = "close-invalid-ward-spend-design-without-implementation"
    else:
        outcome = "success"
        decision = "freeze-ward-spend-contract-for-source-null-and-direct-proof"

    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "outcomeClass": outcome,
        "decision": decision,
        "claimBoundary": protocol["claimBoundary"],
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "faults": faults,
        "sourceHead": actual_head,
        "archiveHeadPreserved": actual_archive,
        "grid": [
            {"spend": spend, "payoffNumeratorPerTwoWard": numerator,
             "separateDamage": damage}
            for spend, numerator, damage in cells
        ],
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "newScientificSimulatorRows": 0,
        "newLedgerRows": 0,
        "GodotProcesses": 0,
        "maximumModelContextTokensDuringExecutionAndDecision": 0,
        "wallTimeSeconds": elapsed,
        "authority": protocol["automaticDisposition"][outcome],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    return summary


if __name__ == "__main__":
    result = run()
    print(json.dumps({
        "outcomeClass": result["outcomeClass"],
        "decision": result["decision"],
        "faults": result["faults"],
        "rows": result["newScientificSimulatorRows"],
        "wallTimeSeconds": round(result["wallTimeSeconds"], 3),
    }, sort_keys=True))
