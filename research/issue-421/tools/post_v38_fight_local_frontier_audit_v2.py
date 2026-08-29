#!/usr/bin/env python3
"""Zero-row fight-local mechanism and method frontier audit for issue #421."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as ledger
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-fight-local-frontier-audit-v2.json"
SUMMARY = core.ROOT / "summaries/post-v38-fight-local-frontier-audit-v2.json"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Fight-local frontier mismatch: {label}")


def selected(items: list[dict[str, Any]]) -> list[str]:
    return [
        str(item["id"])
        for item in items
        if all(bool(item["signals"][name]) for name in item["requiredSignals"])
    ]


def classify(
    mechanisms: list[dict[str, Any]], methods: list[dict[str, Any]],
) -> tuple[str, int, str, list[str], list[str], list[str]]:
    eligible_mechanisms = selected(mechanisms)
    eligible_methods = selected(methods)
    unresolved = [
        str(item["id"])
        for item in mechanisms
        if bool(item.get("requiresNewProductSemantics", False))
        and bool(item["signals"].get("mechanisticallyDistinct", False))
    ]
    if len(eligible_mechanisms) == 1 and not eligible_methods:
        return (
            "success", 1, "freeze-one-fight-local-frontier-class-for-design",
            eligible_mechanisms, eligible_methods, unresolved,
        )
    if not eligible_mechanisms and not eligible_methods and len(unresolved) >= 2:
        return (
            "futility", 2, "record-fight-local-mechanism-selection-gate-unavailable",
            eligible_mechanisms, eligible_methods, unresolved,
        )
    return (
        "inconclusive", 3, "record-fight-local-frontier-audit-inconclusive-at-cap",
        eligible_mechanisms, eligible_methods, unresolved,
    )


def self_check() -> None:
    complete = {
        "id": "complete", "requiredSignals": ["a", "b"],
        "signals": {"a": True, "b": True},
    }
    incomplete = {
        "id": "incomplete", "requiredSignals": ["a", "b"],
        "signals": {"a": True, "b": False, "mechanisticallyDistinct": True},
        "requiresNewProductSemantics": True,
    }
    outcome = classify([complete], [])
    require("self-check success", outcome[:4] == (
        "success", 1, "freeze-one-fight-local-frontier-class-for-design", ["complete"],
    ))
    second = {**incomplete, "id": "other"}
    outcome = classify([incomplete, second], [])
    require("self-check unavailable", outcome[:3] == (
        "futility", 2, "record-fight-local-mechanism-selection-gate-unavailable",
    ))
    outcome = classify([], [complete])
    require("self-check inconclusive", outcome[0] == "inconclusive")


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the fight-local frontier summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    immutable = protocol["immutableInputs"]
    require("runner SHA", core.file_sha(Path(__file__)) == immutable["runnerSha256"])
    self_check()
    require(
        "task capsule SHA",
        core.file_sha(core.ROOT / immutable["taskCapsulePath"])
        == immutable["taskCapsuleSha256"],
    )
    for path, expected in immutable["researchFileSha256"].items():
        require(f"research file {path}", core.file_sha(core.ROOT / path) == expected)
    supersedes = protocol["supersedesMechanicalFailure"]
    require(
        "v1 protocol identity",
        core.file_sha(core.ROOT / supersedes["protocolPath"])
        == supersedes["protocolSha256"],
    )
    require(
        "v1 runner identity",
        core.file_sha(core.ROOT / supersedes["runnerPath"])
        == supersedes["runnerSha256"],
    )
    require(
        "v1 failure identity",
        core.file_sha(core.ROOT / supersedes["failurePath"])
        == supersedes["failureSha256"],
    )

    repository = Path(immutable["repositoryPath"])
    for ref, expected in immutable["repositoryRefs"].items():
        actual = subprocess.run(
            ["git", "rev-parse", ref], cwd=repository, check=True,
            text=True, capture_output=True,
        ).stdout.strip()
        require(f"repository ref {ref}", actual == expected)
    source_text: dict[str, str] = {}
    for path, expected in immutable["sourceSha256"].items():
        blob = subprocess.run(
            ["git", "show", f"{immutable['sourceHead']}:{path}"],
            cwd=repository, check=True, capture_output=True,
        ).stdout
        require(f"source {path}", core.sha(blob) == expected)
        source_text[path] = blob.decode()
    for assertion in protocol["sourceAssertions"]:
        text = source_text[assertion["path"]]
        if "contains" in assertion:
            require(f"source assertion {assertion['id']}", assertion["contains"] in text)
        else:
            require(f"source absence {assertion['id']}", assertion["absent"] not in text)

    evidence_decisions: dict[str, str] = {}
    for evidence_id, evidence in protocol["priorEvidence"].items():
        path = core.ROOT / evidence["path"]
        require(f"evidence SHA {evidence_id}", core.file_sha(path) == evidence["sha256"])
        if path.suffix == ".json":
            decision = str(json.loads(path.read_text()).get("decision", ""))
            require(f"evidence decision {evidence_id}", decision == evidence["decision"])
            evidence_decisions[evidence_id] = decision

    mechanisms = protocol["frontierClasses"]
    methods = protocol["methodClasses"]
    require(
        "frontier class identity",
        [item["id"] for item in mechanisms] == protocol["expectedFrontierClassIds"],
    )
    require(
        "method class identity",
        [item["id"] for item in methods] == protocol["expectedMethodClassIds"],
    )
    require(
        "all required mechanism signals declared",
        all(set(item["requiredSignals"]) <= set(item["signals"]) for item in mechanisms),
    )
    require(
        "all required method signals declared",
        all(set(item["requiredSignals"]) <= set(item["signals"]) for item in methods),
    )
    outcome, boundary, decision, eligible, eligible_methods, unresolved = classify(
        mechanisms, methods,
    )
    require("frozen eligible mechanism set", eligible == protocol["expectedEligibleMechanisms"])
    require("frozen eligible method set", eligible_methods == protocol["expectedEligibleMethods"])
    require("unresolved semantic breadth", len(unresolved) >= protocol["gates"]["minimumUnresolvedSemanticClasses"])

    elapsed = time.monotonic() - started
    if elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        outcome = "inconclusive"
        boundary = 3
        decision = "record-fight-local-frontier-audit-inconclusive-at-cap"
        eligible = []
        eligible_methods = []
    ledger_before = ledger.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    ledger_after = ledger.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "outcomeClass": outcome,
        "decisionBoundary": boundary,
        "decision": decision,
        "selectedMechanisms": eligible if outcome == "success" else [],
        "selectedMethods": eligible_methods if outcome == "success" else [],
        "unresolvedSemanticClasses": unresolved,
        "frontierClassCount": len(mechanisms),
        "methodClassCount": len(methods),
        "priorEvidenceDecisions": evidence_decisions,
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "newSimulatorObservationRows": 0,
        "newLedgerRows": 0,
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "maximumModelContextTokensDuringExecutionAndDecision": 0,
        "wallTimeSeconds": round(elapsed, 6),
        "claimBoundary": protocol["claimBoundary"],
        "authority": protocol["decisionRules"][f"{outcome}Authority"],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": outcome.upper(),
        "decision": decision,
        "selectedMechanisms": summary["selectedMechanisms"],
        "selectedMethods": summary["selectedMethods"],
        "newSimulatorObservationRows": 0,
    }))


if __name__ == "__main__":
    main()
