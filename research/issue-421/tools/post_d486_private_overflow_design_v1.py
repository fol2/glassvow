#!/usr/bin/env python3
"""Zero-row causal-topology design audit for issue #421 private state."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as ledger
import research as core


PROTOCOL = core.ROOT / "protocols/post-d486-private-overflow-design-v1.json"
SUMMARY = core.ROOT / "summaries/post-d486-private-overflow-design-v1.json"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Private-overflow design mismatch: {label}")


def canonical_sha(value: dict[str, Any]) -> str:
    return core.sha(core.canonical(value).encode())


def legal_residual(candidate: dict[str, Any]) -> bool:
    return (
        candidate["discarded"]
        and candidate["notRepresentedInState"]
        and candidate["duskSpecific"]
        and candidate["naturallyCostly"]
        and candidate["directlyObservable"]
        and not candidate["closureAliases"]
    )


def enumerate_consumers(content: dict[str, Any]) -> list[dict[str, Any]]:
    starters = {
        card_id
        for aspect in content["aspects"]
        for card_id in aspect["startDeck"]
    }
    reward_ids = [
        card_id
        for rarity in ("common", "uncommon", "rare")
        for card_id in content["cardPools"][rarity]
    ]
    candidates: list[dict[str, Any]] = []
    for card_id in reward_ids:
        card = content["cards"][card_id]
        effects = card.get("effects", [])
        if (
            card_id in starters
            or card.get("type") != "attack"
            or card.get("target") != "enemy"
            or len(effects) != 1
            or effects[0].get("kind") != "dmg"
            or int(card.get("chip", 0)) != 0
            or bool(card.get("exhaust", False))
        ):
            continue
        hits = int(effects[0].get("times", 1))
        candidate = {
            "id": card_id,
            "rarity": card["rarity"],
            "cost": int(card["cost"]),
            "baseDamage": int(effects[0]["n"]),
            "hitCount": hits,
            "directAttributionRank": 0 if hits == 1 else 1,
            "selectionVector": [0 if hits == 1 else 1, 1, 2, 1 + hits, 3],
        }
        candidate["canonicalSha256"] = canonical_sha(candidate)
        candidates.append(candidate)
    return sorted(
        candidates,
        key=lambda item: (*item["selectionVector"], item["canonicalSha256"]),
    )


def self_check() -> None:
    closed = {
        "discarded": True,
        "notRepresentedInState": True,
        "duskSpecific": True,
        "naturallyCostly": True,
        "directlyObservable": True,
        "closureAliases": ["closed"],
    }
    require("self-check closed residual", not legal_residual(closed))
    require(
        "self-check legal residual",
        legal_residual({**closed, "closureAliases": []}),
    )


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite private-overflow design summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    immutable = protocol["immutableInputs"]
    require("runner SHA", core.file_sha(Path(__file__)) == immutable["runnerSha256"])
    require(
        "task capsule SHA",
        core.file_sha(core.ROOT / immutable["taskCapsulePath"])
        == immutable["taskCapsuleSha256"],
    )
    require(
        "primary-source report SHA",
        core.file_sha(core.ROOT / immutable["primarySourceReportPath"])
        == immutable["primarySourceReportSha256"],
    )
    self_check()

    repository = Path(immutable["repositoryPath"])
    for ref, expected in immutable["repositoryRefs"].items():
        actual = subprocess.run(
            ["git", "rev-parse", ref],
            cwd=repository,
            check=True,
            text=True,
            capture_output=True,
        ).stdout.strip()
        require(f"repository ref {ref}", actual == expected)

    require(
        "source-file cap",
        len(immutable["sourceSha256"]) <= protocol["budget"]["maximumSourceFilesRead"],
    )
    source_text: dict[str, str] = {}
    for name, expected in immutable["sourceSha256"].items():
        blob = subprocess.run(
            ["git", "show", f"{immutable['sourceHead']}:{name}"],
            cwd=repository,
            check=True,
            capture_output=True,
        ).stdout
        require(f"source SHA {name}", core.sha(blob) == expected)
        source_text[name] = blob.decode()
    for assertion in protocol["sourceAssertions"]:
        source = source_text[assertion["path"]]
        require(
            assertion["id"],
            assertion["contains"] in source
            if "contains" in assertion
            else assertion["absent"] not in source,
        )

    require(
        "evidence-file cap",
        len(protocol["priorEvidence"]) <= protocol["budget"]["maximumEvidenceFilesRead"],
    )
    evidence_decisions: dict[str, str] = {}
    for evidence_id, evidence in protocol["priorEvidence"].items():
        evidence_path = core.ROOT / evidence["path"]
        require(f"evidence SHA {evidence_id}", core.file_sha(evidence_path) == evidence["sha256"])
        decision = str(json.loads(evidence_path.read_text())["decision"])
        require(f"evidence decision {evidence_id}", decision == evidence["decision"])
        evidence_decisions[evidence_id] = decision

    residuals = protocol["residualCandidates"]
    require(
        "residual cap",
        len(residuals) <= protocol["budget"]["maximumResidualCandidates"],
    )
    require(
        "residual identities",
        [item["id"] for item in residuals] == protocol["expectedResidualIds"],
    )
    legal_residuals = [item for item in residuals if legal_residual(item)]

    content = json.loads(source_text["content/full-content.json"])
    consumers = enumerate_consumers(content)
    require(
        "consumer identities",
        [item["id"] for item in consumers] == protocol["expectedConsumerIds"],
    )

    selected: dict[str, Any] | None = None
    if len(legal_residuals) == 1 and consumers:
        first_rank = tuple(consumers[0]["selectionVector"])
        rank_ties = [
            item for item in consumers if tuple(item["selectionVector"]) == first_rank
        ]
        if len(rank_ties) == 1:
            selected = {
                "id": f"{legal_residuals[0]['id']}->{consumers[0]['id']}",
                "producer": legal_residuals[0]["id"],
                "consumer": consumers[0]["id"],
                "consumerCanonicalSha256": consumers[0]["canonicalSha256"],
                "contract": protocol["selectedContract"],
            }

    if selected is not None:
        outcome = "success"
        boundary = 1
        decision = "freeze-ember-overflow-heavy-blow-contract-for-identity-preflight"
    elif not legal_residuals or not consumers:
        outcome = "futility"
        boundary = 2
        decision = "close-corrected-private-state-causal-grammar"
    else:
        outcome = "inconclusive"
        boundary = 3
        decision = "record-corrected-private-state-design-inconclusive-at-cap"

    require("expected outcome", outcome == protocol["expectedOutcome"])
    require(
        "selected identity",
        (None if selected is None else selected["id"])
        == protocol["expectedSelectedCandidateId"],
    )
    if selected is not None:
        require("twelve fields", len(selected["contract"]) == 12)
        require(
            "twelve-field order",
            list(selected["contract"]) == protocol["twelveFieldOrder"],
        )

    ledger_before = ledger.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    ledger_after = ledger.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    elapsed = time.monotonic() - started
    if elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        outcome = "inconclusive"
        boundary = 3
        decision = "record-corrected-private-state-design-inconclusive-at-cap"
        selected = None

    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "outcomeClass": outcome,
        "decisionBoundary": boundary,
        "decision": decision,
        "selectedCandidate": selected,
        "legalResidualIds": [item["id"] for item in legal_residuals],
        "consumerEnumeration": consumers,
        "priorEvidenceDecisions": evidence_decisions,
        "correctsInferenceFrom": immutable["correctedEvidencePath"],
        "correctedEvidencePreservedSha256": immutable["correctedEvidenceSha256"],
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "sourceHead": immutable["sourceHead"],
        "archiveHeadsPreserved": immutable["archiveHeads"],
        "taskCapsuleSha256": immutable["taskCapsuleSha256"],
        "cachedObservationRowsRead": 0,
        "supportMetricsInspected": 0,
        "GodotProcesses": 0,
        "newSimulatorObservationRows": 0,
        "newLedgerRows": 0,
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "maximumModelContextTokensDuringExecutionAndDecision": 0,
        "wallTimeSeconds": round(elapsed, 6),
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "claimBoundary": protocol["claimBoundary"],
        "authority": protocol["decisionRules"][outcome + "Authority"],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": outcome.upper(),
        "decision": decision,
        "selectedCandidateId": None if selected is None else selected["id"],
        "newSimulatorObservationRows": 0,
    }))


if __name__ == "__main__":
    main()
