#!/usr/bin/env python3
"""Zero-row source/interface proof for private-debt identity v2."""

from __future__ import annotations

import json
import re
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v30-private-debt-identity-v2-preflight.json"
SUMMARY = core.ROOT / "summaries/post-v30-private-debt-identity-v2-preflight.json"
BASELINE = core.ROOT / "private-debt-baseline-source"
V1 = core.ROOT / "private-debt-identity-source"
V2 = core.ROOT / "private-debt-identity-v2-source"
PUBLICATION = Path("/Users/jamesto/Research/glassvow-p9-421-publication")
PROBE = Path("tools/research_421_private_debt_probe.gd")
PROBE_UID = Path("tools/research_421_private_debt_probe.gd.uid")
COMBAT = Path("domain/rules/combat.gd")
CARD_INST = Path("domain/state/card_inst.gd")
EXPECTED_RESEARCH_STATUS = {
    " M domain/rules/combat.gd",
    "?? tools/research_421_private_debt_probe.gd",
    "?? tools/research_421_private_debt_probe.gd.uid",
}


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Private-debt v2 preflight mismatch: {label}")


def git(path: Path, *args: str) -> str:
    return subprocess.run(
        ["git", *args], cwd=path, check=True, text=True, capture_output=True,
    ).stdout.strip()


def status(path: Path) -> set[str]:
    return set(subprocess.run(
        ["git", "status", "--porcelain"], cwd=path, check=True,
        text=True, capture_output=True,
    ).stdout.splitlines())


def source_identity() -> dict[str, Any]:
    v1_probe = (V1 / PROBE).read_bytes()
    v2_probe = (V2 / PROBE).read_bytes()
    card_inst = (BASELINE / CARD_INST).read_text()
    invalid_v1 = re.findall(rb"\b[A-Za-z_][A-Za-z0-9_]*\.upgraded\b", v1_probe)
    invalid_v2 = re.findall(rb"\b[A-Za-z_][A-Za-z0-9_]*\.upgraded\b", v2_probe)
    corrected_v2 = re.findall(rb"\bcard\.up\b", v2_probe)

    require("baseline worktree clean", not status(BASELINE))
    require("v1 owned source status", status(V1) == EXPECTED_RESEARCH_STATUS)
    require("v2 owned source status", status(V2) == EXPECTED_RESEARCH_STATUS)
    require("current-main CardInst up declaration", len(re.findall(
        r"(?m)^var up: bool = false$", card_inst,
    )) == 1)
    require("current-main CardInst has no upgraded field", not re.search(
        r"(?m)^var upgraded\b", card_inst,
    ))
    require("v1 invalid projection count", len(invalid_v1) == 3)
    require("v2 invalid projection removed", not invalid_v2)
    require("v2 corrected projection count", len(corrected_v2) == 3)
    require("probe semantic normalisation", v2_probe.replace(
        b"card.up", b"card.upgraded",
    ) == v1_probe)
    require("prototype behaviour unchanged", (V1 / COMBAT).read_bytes() ==
            (V2 / COMBAT).read_bytes())
    require("probe UID unchanged", (V1 / PROBE_UID).read_bytes() ==
            (V2 / PROBE_UID).read_bytes())
    require("CardInst identity across sources", len({
        (path / CARD_INST).read_bytes() for path in (BASELINE, V1, V2)
    }) == 1)

    return {
        "sourceCommit": git(BASELINE, "rev-parse", "HEAD"),
        "v1SourceCommit": git(V1, "rev-parse", "HEAD"),
        "v2SourceCommit": git(V2, "rev-parse", "HEAD"),
        "archiveCommit": git(PUBLICATION, "rev-parse", "HEAD"),
        "cardInstSha256": core.file_sha(BASELINE / CARD_INST),
        "v1CombatRulesSha256": core.file_sha(V1 / COMBAT),
        "v2CombatRulesSha256": core.file_sha(V2 / COMBAT),
        "v1ProbeSha256": core.file_sha(V1 / PROBE),
        "v2ProbeSha256": core.file_sha(V2 / PROBE),
        "probeUidSha256": core.file_sha(V2 / PROBE_UID),
        "v1InvalidProjectionCount": len(invalid_v1),
        "v2InvalidProjectionCount": len(invalid_v2),
        "v2CorrectedProjectionCount": len(corrected_v2),
        "semanticChanges": [
            "card.upgraded -> card.up at producer result projection",
            "card.upgraded -> card.up at consumer result projection",
            "card.upgraded -> card.up at card-zone result projection",
        ],
        "taskCapsuleSha256": core.file_sha(core.ROOT / "task-capsule.json"),
        "runnerSha256": core.file_sha(Path(__file__)),
    }


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite private-debt v2 preflight summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    observed = source_identity()
    require("immutable source/interface identity",
            observed == protocol["immutableInputs"])
    require("v1 protocol identity", core.file_sha(
        core.ROOT / protocol["v1Evidence"]["identityProtocolPath"],
    ) == protocol["v1Evidence"]["identityProtocolSha256"])
    require("v1 audit identity", core.file_sha(
        core.ROOT / protocol["v1Evidence"]["auditSummaryPath"],
    ) == protocol["v1Evidence"]["auditSummarySha256"])
    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    elapsed = time.monotonic() - started
    require("wall-time ceiling", elapsed <= protocol["budget"]["maximumWallTimeSeconds"])
    ledger_after = identity.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decision": "admit-private-debt-identity-v2-execution",
        "outcomeClass": "success",
        "protocolSha256": protocol_sha,
        "sourceInterfaceIdentity": observed,
        "wholeRunRows": 0,
        "capacityRows": 0,
        "supportRows": 0,
        "causalRows": 0,
        "newSimulatorObservationRows": 0,
        "newLedgerRows": 0,
        "GodotProcesses": 0,
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "maximumModelContextTokens": 0,
        "wallTimeSeconds": elapsed,
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "authority": protocol["decisionRules"]["successAuthority"],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS",
        "decision": summary["decision"],
        "newSimulatorObservationRows": 0,
        "summarySha256": core.file_sha(SUMMARY),
    }))


if __name__ == "__main__":
    main()
