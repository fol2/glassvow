#!/usr/bin/env python3
"""Zero-row causal-topology coverage audit for issue #421 private state."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as ledger
import research as core


PROTOCOL = core.ROOT / "protocols/post-810264c-private-causal-coverage-v1.json"
SUMMARY = core.ROOT / "summaries/post-810264c-private-causal-coverage-v1.json"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Private causal coverage mismatch: {label}")


def candidate_sha(candidate: dict[str, Any]) -> str:
    payload = {key: value for key, value in candidate.items() if key != "canonicalSha256"}
    return core.sha(core.canonical(payload).encode())


def legal(candidate: dict[str, Any], required: list[str]) -> bool:
    return (
        not candidate["unresolvedFields"]
        and not candidate["closureAliases"]
        and all(candidate["gates"].get(gate, False) for gate in required)
    )


def classify(
    candidates: list[dict[str, Any]], required: list[str]
) -> tuple[str, int, str, list[dict[str, Any]]]:
    eligible = sorted(
        (candidate for candidate in candidates if legal(candidate, required)),
        key=lambda candidate: (candidate["selectionVector"], candidate["canonicalSha256"]),
    )
    if not eligible:
        return (
            "futility", 2,
            "close-corrected-private-causal-class-and-raise-owner-authority-package",
            [],
        )
    if len(eligible) == 1 or eligible[0]["selectionVector"] < eligible[1]["selectionVector"]:
        return "success", 1, "freeze-private-causal-contract-for-identity-preflight", eligible[:1]
    return "inconclusive", 3, "record-private-causal-coverage-inconclusive-at-cap", []


def self_check(required: list[str]) -> None:
    gates = {gate: True for gate in required}
    one = {
        "id": "one", "unresolvedFields": [], "closureAliases": [],
        "gates": gates, "selectionVector": [0, 0, 0, 0, 1],
    }
    one["canonicalSha256"] = candidate_sha(one)
    closed = {**one, "id": "closed", "closureAliases": ["closed"]}
    closed["canonicalSha256"] = candidate_sha(closed)
    require("self-check success", classify([one], required)[0] == "success")
    require("self-check futility", classify([closed], required)[0] == "futility")


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite private causal coverage summary")
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
    self_check(protocol["requiredGates"])

    repository = Path(immutable["repositoryPath"])
    for ref, expected in immutable["repositoryRefs"].items():
        actual = subprocess.run(
            ["git", "rev-parse", ref], cwd=repository, check=True,
            text=True, capture_output=True,
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
            cwd=repository, check=True, capture_output=True,
        ).stdout
        require(f"source SHA {name}", core.sha(blob) == expected)
        source_text[name] = blob.decode()
    for assertion in protocol["sourceAssertions"]:
        source = source_text[assertion["path"]]
        require(
            assertion["id"],
            assertion["contains"] in source
            if "contains" in assertion else assertion["absent"] not in source,
        )

    require(
        "evidence-file cap",
        len(protocol["priorEvidence"]) <= protocol["budget"]["maximumEvidenceFilesRead"],
    )
    decisions: dict[str, str] = {}
    for evidence_id, evidence in protocol["priorEvidence"].items():
        path = core.ROOT / evidence["path"]
        require(f"evidence SHA {evidence_id}", core.file_sha(path) == evidence["sha256"])
        decision = str(json.loads(path.read_text())["decision"])
        require(f"evidence decision {evidence_id}", decision == evidence["decision"])
        decisions[evidence_id] = decision

    candidates = protocol["causalTopologies"]
    require("topology cap", len(candidates) <= protocol["budget"]["maximumTopologies"])
    require(
        "topology identities",
        [candidate["id"] for candidate in candidates] == protocol["expectedTopologyIds"],
    )
    require(
        "topology canonical identities",
        all(candidate_sha(candidate) == candidate["canonicalSha256"] for candidate in candidates),
    )
    require(
        "required gates declared",
        all(set(protocol["requiredGates"]) <= set(candidate["gates"])
            for candidate in candidates),
    )
    require(
        "closure evidence resolved",
        all(set(candidate["evidenceIds"]) <= set(decisions) for candidate in candidates),
    )
    outcome, boundary, decision, selected = classify(candidates, protocol["requiredGates"])
    selected_ids = [candidate["id"] for candidate in selected]
    require("expected outcome", outcome == protocol["expectedOutcome"])
    require("expected selected set", selected_ids == protocol["expectedSelectedTopologyIds"])

    ledger_before = ledger.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    ledger_after = ledger.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    elapsed = time.monotonic() - started
    if elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        outcome, boundary, decision, selected_ids = (
            "inconclusive", 3, "record-private-causal-coverage-inconclusive-at-cap", [],
        )

    summary = {
        "schemaVersion": 1, "issue": 421, "outcomeClass": outcome,
        "decisionBoundary": boundary, "decision": decision,
        "allFourSerialCausalClassesExhausted": outcome == "futility",
        "humanAuthorityRequired": outcome == "futility",
        "selectedTopologyIds": selected_ids,
        "assessments": [{
            "id": candidate["id"], "canonicalSha256": candidate["canonicalSha256"],
            "eligible": legal(candidate, protocol["requiredGates"]),
            "unresolvedFields": candidate["unresolvedFields"],
            "closureAliases": candidate["closureAliases"],
            "failedGates": [
                gate for gate in protocol["requiredGates"] if not candidate["gates"][gate]
            ],
            "selectionVector": candidate["selectionVector"],
        } for candidate in candidates],
        "priorEvidenceDecisions": decisions,
        "humanAuthorityPackage": protocol["humanAuthorityPackage"]
        if outcome == "futility" else None,
        "protocolSha256": protocol_sha, "runnerSha256": core.file_sha(Path(__file__)),
        "sourceHead": immutable["sourceHead"],
        "archiveHeadsPreserved": immutable["archiveHeads"],
        "taskCapsuleSha256": immutable["taskCapsuleSha256"],
        "cachedObservationRowsRead": 0, "supportMetricsInspected": 0,
        "GodotProcesses": 0, "newSimulatorObservationRows": 0,
        "newLedgerRows": 0, "protectedSeedRows": ledger_after["protectedSeedRows"],
        "maximumModelContextTokensDuringExecutionAndDecision": 0,
        "wallTimeSeconds": round(elapsed, 6),
        "ledgerBefore": ledger_before, "ledgerAfter": ledger_after,
        "claimBoundary": protocol["claimBoundary"],
        "authority": protocol["decisionRules"][outcome + "Authority"],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": outcome.upper(), "decision": decision,
        "selectedTopologyIds": selected_ids, "newSimulatorObservationRows": 0,
    }))


if __name__ == "__main__":
    main()
