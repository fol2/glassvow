#!/usr/bin/env python3
"""Zero-row exact-lethal precision design audit for issue #421."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as ledger
import research as core


PROTOCOL = core.ROOT / "protocols/post-843e899-terminal-hit-precision-design-v1.json"
SUMMARY = core.ROOT / "summaries/post-843e899-terminal-hit-precision-design-v1.json"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Terminal-hit precision design mismatch: {label}")


def candidate_sha(candidate: dict[str, Any]) -> str:
    value = {key: item for key, item in candidate.items() if key != "canonicalSha256"}
    return core.sha(core.canonical(value).encode())


def eligible(candidate: dict[str, Any], required_gates: list[str]) -> bool:
    gates = candidate["gates"]
    return (
        not candidate["closureAliases"]
        and all(bool(gates[name]) for name in required_gates)
    )


def rank(candidate: dict[str, Any]) -> tuple[Any, ...]:
    return (*candidate["selectionVector"], candidate["canonicalSha256"])


def classify(
    candidates: list[dict[str, Any]], required_gates: list[str],
) -> tuple[str, int, str, list[dict[str, Any]]]:
    legal = [candidate for candidate in candidates if eligible(candidate, required_gates)]
    if legal:
        ordered = sorted(legal, key=rank)
        if len(ordered) == 1 or rank(ordered[0]) < rank(ordered[1]):
            return (
                "success", 1,
                "freeze-terminal-hit-facet-salvage-contract-for-preflight",
                ordered[:1],
            )
        return (
            "inconclusive", 3,
            "record-terminal-hit-precision-design-inconclusive-at-cap", [],
        )
    return (
        "futility", 2, "close-exact-lethal-precision-at-zero-row-boundary", [],
    )


def self_check(required_gates: list[str]) -> None:
    gates = {name: True for name in required_gates}
    one = {
        "id": "one", "canonicalSha256": "1", "closureAliases": [],
        "gates": gates, "selectionVector": [0, 0, 0, 0, 0, 1],
    }
    two = {
        **one, "id": "two", "canonicalSha256": "2",
        "selectionVector": [1, 0, 0, 0, 0, 1],
    }
    require("self-check success", classify([two, one], required_gates)[1] == 1)
    require(
        "self-check selection", classify([two, one], required_gates)[3][0]["id"] == "one",
    )
    alias = {**one, "closureAliases": ["closed"]}
    require("self-check futility", classify([alias], required_gates)[1] == 2)


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite terminal-hit precision design summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    immutable = protocol["immutableInputs"]
    require("runner SHA", core.file_sha(Path(__file__)) == immutable["runnerSha256"])
    require(
        "task capsule SHA",
        core.file_sha(core.ROOT / immutable["taskCapsulePath"])
        == immutable["taskCapsuleSha256"],
    )
    self_check(protocol["requiredGates"])

    repository = Path(immutable["repositoryPath"])
    for ref, expected in immutable["repositoryRefs"].items():
        actual = subprocess.run(
            ["git", "rev-parse", ref], cwd=repository, check=True,
            text=True, capture_output=True,
        ).stdout.strip()
        require(f"repository ref {ref}", actual == expected)

    source_text: dict[str, str] = {}
    require(
        "source-file cap",
        len(immutable["sourceSha256"]) <= protocol["budget"]["maximumSourceFilesRead"],
    )
    for path, expected in immutable["sourceSha256"].items():
        blob = subprocess.run(
            ["git", "show", f"{immutable['sourceHead']}:{path}"],
            cwd=repository, check=True, capture_output=True,
        ).stdout
        require(f"source SHA {path}", core.sha(blob) == expected)
        source_text[path] = blob.decode()
    for assertion in protocol["sourceAssertions"]:
        text = source_text[assertion["path"]]
        if "contains" in assertion:
            require(f"source assertion {assertion['id']}", assertion["contains"] in text)
        else:
            require(f"source absence {assertion['id']}", assertion["absent"] not in text)
    for path, expected in immutable.get("researchFileSha256", {}).items():
        require(f"research file SHA {path}", core.file_sha(core.ROOT / path) == expected)

    evidence_decisions: dict[str, str] = {}
    require(
        "evidence-file cap",
        len(protocol["priorEvidence"]) <= protocol["budget"]["maximumEvidenceFilesRead"],
    )
    for evidence_id, evidence in protocol["priorEvidence"].items():
        path = core.ROOT / evidence["path"]
        require(f"evidence SHA {evidence_id}", core.file_sha(path) == evidence["sha256"])
        decision = str(json.loads(path.read_text())["decision"])
        require(f"evidence decision {evidence_id}", decision == evidence["decision"])
        evidence_decisions[evidence_id] = decision

    candidates = protocol["candidateDesigns"]
    require(
        "candidate cap",
        len(candidates) <= protocol["budget"]["maximumCandidateDesigns"],
    )
    require(
        "candidate identity",
        [candidate["id"] for candidate in candidates] == protocol["expectedCandidateIds"],
    )
    require(
        "candidate SHA identities",
        all(candidate_sha(candidate) == candidate["canonicalSha256"] for candidate in candidates),
    )
    require(
        "all required gates declared",
        all(set(protocol["requiredGates"]) <= set(candidate["gates"]) for candidate in candidates),
    )
    outcome, boundary, decision, selected = classify(candidates, protocol["requiredGates"])
    selected_ids = [candidate["id"] for candidate in selected]
    require("frozen selected set", selected_ids == protocol["expectedSelectedCandidateIds"])
    if selected:
        require(
            "twelve-field contract",
            list(selected[0]["contract"].keys()) == protocol["twelveFieldOrder"],
        )
        require("exact twelve fields", len(selected[0]["contract"]) == 12)

    ledger_before = ledger.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    ledger_after = ledger.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    elapsed = time.monotonic() - started
    if elapsed > float(protocol["budget"]["maximumWallTimeSeconds"]):
        outcome, boundary, decision, selected, selected_ids = (
            "inconclusive", 3,
            "record-terminal-hit-precision-design-inconclusive-at-cap", [], [],
        )

    assessments = [
        {
            "id": candidate["id"],
            "canonicalSha256": candidate["canonicalSha256"],
            "eligible": eligible(candidate, protocol["requiredGates"]),
            "closureAliases": candidate["closureAliases"],
            "failedGates": [
                gate for gate in protocol["requiredGates"] if not candidate["gates"][gate]
            ],
            "selectionVector": candidate["selectionVector"],
        }
        for candidate in candidates
    ]
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "outcomeClass": outcome,
        "decisionBoundary": boundary,
        "decision": decision,
        "selectedCandidateIds": selected_ids,
        "selectedContract": selected[0]["contract"] if selected else None,
        "assessments": assessments,
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
        "authority": protocol["decisionRules"][f"{outcome}Authority"],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": outcome.upper(),
        "decision": decision,
        "selectedCandidateIds": selected_ids,
        "newSimulatorObservationRows": 0,
    }))


if __name__ == "__main__":
    main()
