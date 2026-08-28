#!/usr/bin/env python3
"""Versioned deeds-schema correction for the zero-row Shatter aftermath audit."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v30-shatter-aftermath-audit-v2.json"
SUMMARY = core.ROOT / "summaries/post-v30-shatter-aftermath-audit-v2.json"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Shatter aftermath v2 mismatch: {label}")


def main_blob(path: str) -> bytes:
    return subprocess.run(
        ["git", "show", f"HEAD:{path}"], cwd=core.SOURCE,
        check=True, capture_output=True,
    ).stdout


def route_inventory(content: dict[str, Any]) -> dict[str, Any]:
    poison_ids = {
        card_id for card_id, card in content["cards"].items()
        if any(effect.get("kind") == "status" and effect.get("id") == "poison"
               for effect in card.get("effects", []))
    }
    reward_ids = [
        card_id for rarity in ("common", "uncommon", "rare")
        for card_id in content["cardPools"][rarity] if card_id in poison_ids
    ]
    starter_ids = sorted({
        card_id for aspect in content["aspects"] for card_id in aspect["startDeck"]
        if card_id in poison_ids
    })
    unlock_ids = sorted({
        unlock.removeprefix("card:")
        for deed in content["deeds"].values() for unlock in deed.get("unlocks", [])
        if unlock.startswith("card:") and unlock.removeprefix("card:") in poison_ids
    })
    formations = [
        formation
        for act in content["encounters"]
        for tier_formations in act.values()
        for formation in tier_formations
    ]
    return {
        "rewardPoolPoisonCards": reward_ids,
        "starterOnlyPoisonCards": starter_ids,
        "deedUnlockPoisonCards": unlock_ids,
        "allPoisonCards": sorted(poison_ids),
        "multiEnemyFormations": sum(len(row) > 1 for row in formations),
        "formations": len(formations),
        "maximumEnemies": max(map(len, formations)),
    }


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite Shatter aftermath v2 summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    base_path = core.ROOT / protocol["baseProtocol"]["path"]
    base, base_sha = core.load_protocol(base_path)
    immutable = protocol["immutableInputs"]
    started = time.monotonic()
    require("base protocol SHA", base_sha == protocol["baseProtocol"]["sha256"])
    require("runner SHA", core.file_sha(Path(__file__)) == immutable["runnerSha256"])
    require("task capsule SHA", core.file_sha(core.ROOT / "task-capsule.json") ==
            immutable["taskCapsuleSha256"])
    require("source commit", subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=core.SOURCE, check=True,
        text=True, capture_output=True,
    ).stdout.strip() == base["immutableInputs"]["sourceCommit"])
    failure_summary = core.ROOT / protocol["baseFailure"]["path"]
    require("base failure SHA", core.file_sha(failure_summary) ==
            protocol["baseFailure"]["sha256"])
    failure = json.loads(failure_summary.read_text())
    require("base failure boundary", failure["decisionBoundary"] == 3 and
            failure["execution"]["supportMetricsInspected"] == 0 and
            failure["execution"]["newSimulatorObservationRows"] == 0)

    sources: dict[str, str] = {}
    for path, expected_sha in base["immutableInputs"]["sourceSha256"].items():
        blob = main_blob(path)
        require(f"{path} SHA", core.sha(blob) == expected_sha)
        sources[path] = blob.decode()
    for assertion in base["sourceAssertions"]:
        require(assertion["id"], assertion["contains"] in sources[assertion["path"]])
    inventory = route_inventory(json.loads(sources["content/full-content.json"]))
    require("corrected route inventory", inventory == base["naturalRouteIdentity"])

    evidence: dict[str, dict[str, Any]] = {}
    for name, spec in base["priorEvidence"].items():
        path = core.ROOT / spec["path"]
        require(f"{name} SHA", core.file_sha(path) == spec["sha256"])
        evidence[name] = json.loads(path.read_text())
        require(f"{name} decision", evidence[name]["decision"] == spec["decision"])
    require("tested relic branch identity", evidence["duskScreen"]
            ["sourceFilter"]["excludedTestedTargets"] ==
            ["relic:prismCharm", "relic:bellOfEndings"])
    partition = base["aftermathBranchPartition"]
    selected = [row["id"] for row in partition if row["disposition"] == "uncovered"]
    require("unchanged branch order", [row["id"] for row in partition] == [
        "adamant-suppression", "unconditional-shatter-output", "prism-first-proc",
        "smolder-transfer", "bell-collateral-damage",
    ])
    require("unchanged hypothesis", selected == [base["selectedRelation"]["id"]])

    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == base["ledgerFreeze"])
    elapsed = time.monotonic() - started
    if elapsed > float(base["budget"]["maximumWallTimeSeconds"]):
        boundary, decision = 3, "record-shatter-aftermath-v2-inconclusive-at-cap"
        authority = base["decisionRules"]["inconclusiveAuthority"]
    else:
        boundary, decision = 1, "freeze-shatter-smolder-transfer-for-capacity-preregistration"
        authority = base["decisionRules"]["successAuthority"]
    ledger_after = identity.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    summary = {
        "schemaVersion": 2,
        "issue": 421,
        "decisionBoundary": boundary,
        "decision": decision,
        "protocolSha256": protocol_sha,
        "baseProtocolSha256": base_sha,
        "baseFailureSha256": protocol["baseFailure"]["sha256"],
        "runnerSha256": core.file_sha(Path(__file__)),
        "correction": protocol["correction"],
        "aftermathBranchPartition": partition,
        "selectedRelation": base["selectedRelation"] if boundary == 1 else None,
        "naturalRouteIdentity": inventory,
        "sourceIdentity": {
            "commit": base["immutableInputs"]["sourceCommit"],
            "sha256": base["immutableInputs"]["sourceSha256"],
            "taskCapsuleSha256": immutable["taskCapsuleSha256"],
        },
        "traceFilesRead": 0,
        "cacheFilesRead": 0,
        "supportMetricsInspected": 0,
        "newSimulatorObservationRows": 0,
        "newLedgerRows": 0,
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "maximumModelContextTokens": 0,
        "wallTimeSeconds": elapsed,
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "authority": authority,
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS",
        "decisionBoundary": boundary,
        "decision": decision,
        "selectedRelation": selected[0] if boundary == 1 else None,
        "newSimulatorObservationRows": 0,
        "summarySha256": core.file_sha(SUMMARY),
    }))


if __name__ == "__main__":
    main()
