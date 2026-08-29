#!/usr/bin/env python3
"""Post-identity zero-row source-completeness audit for #421 cross-turn hold."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-843e899-cross-turn-hold-coverage-audit-v1.json"
SUMMARY = core.ROOT / "summaries/post-843e899-cross-turn-hold-coverage-audit-v1.json"
SOURCE = core.ROOT / "cross-turn-hold-v1-source"


def git(path: Path, *args: str) -> str:
    return subprocess.run(
        ["git", *args], cwd=path, check=True, text=True, capture_output=True,
    ).stdout.strip()


def section(text: str, start: str, end: str) -> str:
    return text.split(start, 1)[1].split(end, 1)[0]


def source_identity(protocol: dict[str, Any]) -> dict[str, Any]:
    immutable = protocol["immutableInputs"]
    repository = Path(immutable["repositoryPath"])
    return {
        "repositoryRefs": {
            ref: git(repository, "rev-parse", ref)
            for ref in immutable["repositoryRefs"]
        },
        "sourceHead": git(SOURCE, "rev-parse", "HEAD"),
        "sourceStatus": git(SOURCE, "status", "--porcelain=v1").splitlines(),
        "sourceSha256": {
            name: core.file_sha(SOURCE / name)
            for name in immutable["sourceSha256"]
        },
        "runnerSha256": core.file_sha(Path(__file__)),
        "taskCapsuleSha256": core.file_sha(core.ROOT / immutable["taskCapsulePath"]),
        "predecessorSha256": {
            name: core.file_sha(core.ROOT / name)
            for name in immutable["predecessorSha256"]
        },
    }


def audit_checks() -> dict[str, bool]:
    combat = (SOURCE / "domain/rules/combat.gd").read_text()
    content = json.loads((SOURCE / "content/full-content.json").read_text())
    policy = (SOURCE / "tools/balance_policy.gd").read_text()
    direct_protocol = json.loads(
        (core.ROOT / "protocols/post-843e899-cross-turn-hold-identity-v1.json").read_text()
    )
    special = section(combat, '"pyreTithe":', '"flawless":')
    exhaust = section(combat, "func exhaust_card(", "func _apply_effect(")
    kindle = section(combat, "func kindle_from_hand(", "func can_use_art(")
    offering = content["cards"]["offering"]
    direct_ids = {str(row["id"]) for row in direct_protocol["directScenarios"]}
    direct_text = json.dumps(direct_protocol["directScenarios"], sort_keys=True)
    return {
        "frozen contract requires removal expiry":
            "removal or absence" in direct_protocol["mechanismContract"]["lifecycle"],
        "authored Offering is a Skill": offering.get("type") == "skill",
        "authored Offering invokes Pyre Tithe": any(
            effect.get("kind") == "special" and effect.get("id") == "pyreTithe"
            for effect in offering.get("effects", [])
        ),
        "Pyre Tithe directly erases every other held card":
            "for held: CardInst in cb.hand.duplicate()" in special
            and "cb.hand.erase(held)" in special,
        "Pyre Tithe routes removed cards through shared exhaust":
            "exhaust_card(run, cb, held)" in special,
        "Pyre Tithe bypasses the public Kindle entry point":
            "kindle_from_hand" not in special,
        "Pyre Tithe branch lacks mediator expiry":
            "_research421_expire_hold" not in special,
        "shared exhaust lacks mediator expiry":
            "_research421_expire_hold" not in exhaust,
        "only direct Kindle path carries the Kindle expiry hook":
            '_research421_expire_hold(cb, "kindle")' in kindle,
        "Offering is reachable to the frozen policy repertoire":
            '"pyreTithe"' in policy,
        "direct matrix has no Offering removal scenario":
            "offering" not in direct_text.lower() and "pyretithe" not in direct_text.lower()
            and not any("removal" in row_id for row_id in direct_ids),
    }


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite cross-turn hold coverage audit")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    actual_source = source_identity(protocol)
    immutable = protocol["immutableInputs"]
    if actual_source != {key: immutable[key] for key in actual_source}:
        raise RuntimeError("immutable source identity drift")
    ledger_before = identity.ledger_identity()
    if ledger_before != protocol["ledgerFreeze"]:
        raise RuntimeError("ledger freeze drift")
    started = time.monotonic()
    checks = audit_checks()
    ledger_after = identity.ledger_identity()
    confirmed = all(checks.values()) and ledger_after == ledger_before
    outcome = "futility" if confirmed else "inconclusive"
    decision = (
        "close-cross-turn-hold-representation-and-advance-to-intent-history"
        if confirmed else "record-cross-turn-hold-coverage-audit-inconclusive"
    )
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "outcomeClass": outcome,
        "decision": decision,
        "claimBoundary": protocol["claimBoundary"],
        "authority": protocol["decisionRules"][outcome + "Authority"],
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "sourceIdentity": actual_source,
        "checks": checks,
        "failedChecks": [label for label, passed in checks.items() if not passed],
        "newSimulatorObservationRows": 0,
        "GodotProcesses": 0,
        "newLedgerRows": ledger_after["records"] - ledger_before["records"],
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "wallTimeSeconds": time.monotonic() - started,
        "maximumModelContextTokensDuringExecutionAndDecision": 0,
        "archiveHeadPreserved": actual_source["repositoryRefs"][
            "refs/remotes/origin/research/issue-421-post-reshuffle-frontier-evidence"
        ],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "outcomeClass": outcome,
        "decision": decision,
        "checks": sum(checks.values()),
        "failed": len(summary["failedChecks"]),
        "rows": 0,
    }, sort_keys=True))


if __name__ == "__main__":
    main()
