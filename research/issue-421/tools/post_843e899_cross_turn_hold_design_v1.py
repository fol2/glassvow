#!/usr/bin/env python3
"""Zero-row cross-turn hold lifecycle design audit for issue #421."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any

import post_843e899_positive_overkill_design_v1 as common
import post_v38_knob_identity as ledger
import research as core


PROTOCOL = core.ROOT / "protocols/post-843e899-cross-turn-hold-design-v1.json"
SUMMARY = core.ROOT / "summaries/post-843e899-cross-turn-hold-design-v1.json"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Cross-turn hold design mismatch: {label}")


def classify(
    candidates: list[dict[str, Any]], required: list[str],
) -> tuple[str, int, str, list[dict[str, Any]]]:
    legal = sorted(
        (candidate for candidate in candidates if common.eligible(candidate, required)),
        key=common.rank,
    )
    if not legal:
        return "futility", 2, "close-cross-turn-hold-at-zero-row-boundary", []
    if len(legal) == 1 or common.rank(legal[0]) < common.rank(legal[1]):
        return "success", 1, "freeze-one-turn-held-attack-contract-for-preflight", legal[:1]
    return "inconclusive", 3, "record-cross-turn-hold-design-inconclusive-at-cap", []


def self_check(required: list[str]) -> None:
    gates = {name: True for name in required}
    one = {
        "id": "one", "canonicalSha256": "1", "closureAliases": [],
        "gates": gates, "selectionVector": [0, 0, 0, 0, 1],
    }
    two = {**one, "id": "two", "canonicalSha256": "2",
           "selectionVector": [1, 0, 0, 0, 1]}
    require("self-check success", classify([two, one], required)[1] == 1)
    require("self-check selection", classify([two, one], required)[3][0]["id"] == "one")
    require("self-check futility",
            classify([{**one, "closureAliases": ["closed"]}], required)[1] == 2)


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite cross-turn hold design summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    immutable = protocol["immutableInputs"]
    require("runner SHA", core.file_sha(Path(__file__)) == immutable["runnerSha256"])
    require("task capsule SHA", core.file_sha(core.ROOT / immutable["taskCapsulePath"])
            == immutable["taskCapsuleSha256"])
    require("primary-source report SHA",
            core.file_sha(core.ROOT / immutable["primarySourceReportPath"])
            == immutable["primarySourceReportSha256"])
    self_check(protocol["requiredGates"])

    repository = Path(immutable["repositoryPath"])
    for ref, expected in immutable["repositoryRefs"].items():
        actual = subprocess.run(
            ["git", "rev-parse", ref], cwd=repository, check=True,
            text=True, capture_output=True,
        ).stdout.strip()
        require(f"repository ref {ref}", actual == expected)

    require("source-file cap",
            len(immutable["sourceSha256"]) <= protocol["budget"]["maximumSourceFilesRead"])
    source_text: dict[str, str] = {}
    for name, expected in immutable["sourceSha256"].items():
        blob = subprocess.run(
            ["git", "show", f"{immutable['sourceHead']}:{name}"],
            cwd=repository, check=True, capture_output=True,
        ).stdout
        require(f"source SHA {name}", core.sha(blob) == expected)
        source_text[name] = blob.decode()
    for assertion in protocol["sourceAssertions"]:
        source = source_text[assertion["path"]]
        require(assertion["id"], assertion.get("contains", "") in source
                if "contains" in assertion else assertion["absent"] not in source)

    require("evidence-file cap",
            len(protocol["priorEvidence"]) <= protocol["budget"]["maximumEvidenceFilesRead"])
    evidence_decisions: dict[str, str] = {}
    for evidence_id, evidence in protocol["priorEvidence"].items():
        path = core.ROOT / evidence["path"]
        require(f"evidence SHA {evidence_id}", core.file_sha(path) == evidence["sha256"])
        decision = str(json.loads(path.read_text())["decision"])
        require(f"evidence decision {evidence_id}", decision == evidence["decision"])
        evidence_decisions[evidence_id] = decision

    candidates = protocol["candidateDesigns"]
    require("candidate cap",
            len(candidates) <= protocol["budget"]["maximumCandidateDesigns"])
    require("candidate identities",
            [candidate["id"] for candidate in candidates] == protocol["expectedCandidateIds"])
    require("candidate SHA identities", all(
        common.candidate_sha(candidate) == candidate["canonicalSha256"]
        for candidate in candidates
    ))
    require("required gates declared", all(
        set(protocol["requiredGates"]) <= set(candidate["gates"])
        for candidate in candidates
    ))
    outcome, boundary, decision, selected = classify(candidates, protocol["requiredGates"])
    selected_ids = [candidate["id"] for candidate in selected]
    require("selected set", selected_ids == protocol["expectedSelectedCandidateIds"])
    if selected:
        require("twelve-field order",
                list(selected[0]["contract"]) == protocol["twelveFieldOrder"])
        require("exact twelve fields", len(selected[0]["contract"]) == 12)

    ledger_before = ledger.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    ledger_after = ledger.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    elapsed = time.monotonic() - started
    if elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        outcome, boundary, decision, selected, selected_ids = (
            "inconclusive", 3, "record-cross-turn-hold-design-inconclusive-at-cap", [], [],
        )

    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "outcomeClass": outcome,
        "decisionBoundary": boundary,
        "decision": decision,
        "selectedCandidateIds": selected_ids,
        "selectedContract": selected[0]["contract"] if selected else None,
        "assessments": [{
            "id": candidate["id"],
            "canonicalSha256": candidate["canonicalSha256"],
            "eligible": common.eligible(candidate, protocol["requiredGates"]),
            "closureAliases": candidate["closureAliases"],
            "failedGates": [
                gate for gate in protocol["requiredGates"] if not candidate["gates"][gate]
            ],
            "selectionVector": candidate["selectionVector"],
        } for candidate in candidates],
        "priorEvidenceDecisions": evidence_decisions,
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "sourceHead": immutable["sourceHead"],
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
        "status": outcome.upper(), "decision": decision,
        "selectedCandidateIds": selected_ids, "newSimulatorObservationRows": 0,
    }))


if __name__ == "__main__":
    main()
