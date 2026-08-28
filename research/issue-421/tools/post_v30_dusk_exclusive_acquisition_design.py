#!/usr/bin/env python3
"""Zero-row design audit for the authorised Dusk acquisition/UI fallback."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v30-dusk-exclusive-acquisition-design-v1.json"
SUMMARY = core.ROOT / "summaries/post-v30-dusk-exclusive-acquisition-design-v1.json"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Dusk acquisition design mismatch: {label}")


def sha(path: Path) -> str:
    return core.file_sha(path)


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite a completed Dusk acquisition design audit")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    require("runner SHA", sha(Path(__file__)) == protocol["immutableInputs"]["runnerSha256"])
    require(
        "task capsule SHA",
        sha(core.ROOT / "task-capsule.json") == protocol["immutableInputs"]["taskCapsuleSha256"],
    )

    source = Path(protocol["immutableInputs"]["sourceRoot"])
    head = subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=source, text=True
    ).strip()
    require("source commit", head == protocol["immutableInputs"]["sourceCommit"])
    blobs: dict[str, str] = {}
    for relative, expected in protocol["immutableInputs"]["sourceSha256"].items():
        path = source / relative
        require(f"source exists {relative}", path.is_file())
        require(f"source SHA {relative}", sha(path) == expected)
        blobs[relative] = path.read_text()
    require("source file cap", len(blobs) <= protocol["budget"]["maximumSourceFilesRead"])

    evidence: dict[str, dict[str, Any]] = {}
    for name, packet in protocol["immutableEvidence"].items():
        path = core.ROOT / packet["path"]
        require(f"evidence SHA {name}", sha(path) == packet["sha256"])
        row = json.loads(path.read_text())
        require(f"evidence decision {name}", row["decision"] == packet["decision"])
        evidence[name] = row
    require("evidence file cap", len(evidence) <= protocol["budget"]["maximumEvidenceFilesRead"])

    content = json.loads(blobs["content/full-content.json"])
    dusk = next(row for row in content["aspects"] if row["id"] == "duskblade")
    deck = list(map(str, dusk["startDeck"]))
    packages = protocol["packageDefinitions"]
    for package, spec in packages.items():
        producer, consumer = spec["producer"], spec["consumer"]
        require(f"{package} producer starts owned", producer in deck)
        require(f"{package} consumer starts absent", consumer not in deck)
        require(f"{package} consumer exists", consumer in content["cards"])
        require(
            f"{package} consumer pool membership",
            any(consumer in ids for ids in content["cardPools"].values()),
        )
    consumers = [spec["consumer"] for spec in packages.values()]
    require("consumer identities separate", len(set(consumers)) == len(consumers))
    require(
        "shared product availability gate",
        content["poolGate"]["cards"].get("executioner")
        == protocol["productAvailabilityGate"],
    )
    require(
        "other consumer needs no later gate",
        "guardedStrike" not in content["poolGate"]["cards"],
    )

    seams = protocol["sourceSeamAssertions"]
    for relative, needles in seams.items():
        for needle in needles:
            require(f"source seam {relative}: {needle}", needle in blobs[relative])
    choice_source = blobs["presentation/run/choice_screen.gd"].lower()
    require(
        "ChoiceScreen adds no RNG",
        all(term not in choice_source for term in ["randi(", "randf(", "pick_random", ".rng"]),
    )

    eligible: list[dict[str, Any]] = []
    rejected: dict[str, list[str]] = {}
    for candidate in protocol["candidateMatrix"]:
        faults: list[str] = []
        for field in ["newSaveFields", "newInternalIds", "newRngCalls", "newPresentationTypes"]:
            if int(candidate[field]) != 0:
                faults.append(field)
        if candidate["aspect"] != "duskblade":
            faults.append("aspect")
        if candidate["representation"] != "one-existing-consumer-card":
            faults.append("representation")
        if candidate["policySelector"] != "choose_card-null-rng-then-cardDecline":
            faults.append("policySelector")
        if candidate["persistence"] != "existing-player-deck-save":
            faults.append("persistence")
        if candidate["productAvailabilityGate"] != protocol["productAvailabilityGate"]:
            faults.append("productAvailabilityGate")
        if candidate["changesPayoff"] or candidate["breakingContract"]:
            faults.append("contract")
        if faults:
            rejected[candidate["id"]] = faults
            continue
        rank = (
            int(candidate["productionRuntimeFilesChanged"]),
            int(candidate["researchFilesChanged"]),
            str(candidate["id"]),
        )
        eligible.append({"candidate": candidate, "rank": rank})

    eligible.sort(key=lambda row: row["rank"])
    require("at least one contract-safe candidate", bool(eligible))
    best_rank = eligible[0]["rank"][:2]
    winners = [row for row in eligible if row["rank"][:2] == best_rank]
    selected = winners[0]["candidate"] if len(winners) == 1 else None
    clear = selected is not None and selected["id"] == protocol["expectedMinimumCandidate"]

    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    ledger_after = identity.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    elapsed = time.monotonic() - started
    require("wall-time cap", elapsed <= protocol["budget"]["maximumWallTimeSeconds"])

    if clear:
        boundary, decision, authority_key = 1, "freeze-choice-screen-consumer-acquisition-contract", "successAuthority"
    else:
        boundary, decision, authority_key = 2, "close-dusk-exclusive-acquisition-design", "futilityAuthority"
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": boundary,
        "decision": decision,
        "protocolSha256": protocol_sha,
        "runnerSha256": sha(Path(__file__)),
        "sourceCommit": head,
        "sourceFilesRead": len(blobs),
        "evidenceFilesRead": len(evidence),
        "packageDefinitions": packages,
        "duskStartDeck": deck,
        "productAvailabilityGate": protocol["productAvailabilityGate"],
        "eligibleCandidates": [row["candidate"]["id"] for row in eligible],
        "rejectedCandidates": rejected,
        "selectedCandidate": selected,
        "minimumRank": list(best_rank),
        "claimBoundary": protocol["claimBoundary"],
        "newSimulatorObservationRows": 0,
        "newLedgerRows": 0,
        "supportRowsInspected": 0,
        "cacheFilesRead": 0,
        "godotProcesses": 0,
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "maximumModelContextTokens": 0,
        "wallTimeSeconds": elapsed,
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "authority": protocol["decisionRules"][authority_key],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS",
        "decisionBoundary": boundary,
        "decision": decision,
        "selectedCandidate": None if selected is None else selected["id"],
        "newSimulatorObservationRows": 0,
        "summarySha256": sha(SUMMARY),
    }))


if __name__ == "__main__":
    main()
