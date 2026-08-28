#!/usr/bin/env python3
"""Zero-row source/evidence coverage audit for existing Duskblade grammar."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-native-dusk-grammar-coverage-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-native-dusk-grammar-coverage-v1.json"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Native Dusk grammar coverage mismatch: {label}")


def main_blob(path: str) -> bytes:
    return subprocess.run(
        ["git", "show", f"HEAD:{path}"], cwd=core.SOURCE,
        check=True, capture_output=True,
    ).stdout


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the native grammar coverage summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    require("runner SHA", core.file_sha(Path(__file__)) ==
            protocol["immutableInputs"]["runnerSha256"])
    require("source commit", subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=core.SOURCE, check=True,
        text=True, capture_output=True,
    ).stdout.strip() == protocol["immutableInputs"]["sourceCommit"])
    for path, expected_sha in protocol["immutableInputs"]["sourceSha256"].items():
        require(f"{path} SHA", core.sha(main_blob(path)) == expected_sha)
    content_blob = main_blob("content/full-content.json")
    require("content SHA", core.sha(content_blob) ==
            protocol["immutableInputs"]["contentSha256"])
    content = json.loads(content_blob)
    require("Dusk start deck", content["aspects"][0]["startDeck"] ==
            protocol["coverageUniverse"]["duskStartDeck"])
    require("Dusk default art", content["aspects"][0]["art"] ==
            protocol["coverageUniverse"]["duskDefaultArt"])
    for card_id, definition in protocol["coverageUniverse"][
            "uncoveredCarrierDefinitions"].items():
        require(f"{card_id} definition", content["cards"][card_id] == definition)
    for deed_id, unlocks in protocol["coverageUniverse"]["unlockDefinitions"].items():
        require(f"{deed_id} unlocks", content["deeds"][deed_id]["unlocks"] == unlocks)

    source_text = {path: main_blob(path).decode()
                   for path in protocol["immutableInputs"]["sourceSha256"]}
    for assertion in protocol["sourceAssertions"]:
        require(assertion["id"], assertion["contains"] in source_text[assertion["path"]])

    evidence_results = {}
    for name, spec in protocol["priorEvidence"].items():
        path = core.ROOT / spec["path"]
        require(f"{name} SHA", core.file_sha(path) == spec["sha256"])
        decision = json.loads(path.read_text())["decision"]
        require(f"{name} decision", decision == spec["decision"])
        evidence_results[name] = {"sha256": spec["sha256"], "decision": decision}

    family_ids = [family["id"] for family in protocol["coverageFamilies"]]
    require("coverage family universe", family_ids ==
            protocol["coverageUniverse"]["candidateFamilies"])
    for family in protocol["coverageFamilies"]:
        require(f"{family['id']} disposition",
                family["disposition"] in ("closed", "uncovered"))
        if family["disposition"] == "closed":
            require(f"{family['id']} evidence", bool(family["evidence"])
                    and all(name in evidence_results for name in family["evidence"]))
        else:
            require(f"{family['id']} no prior decision", not family["evidence"])
    require("excluded scalar classification",
            all(item["classification"] == "non-selective-scalar-or-context"
                for item in protocol["nonCandidateSourceFamilies"]))

    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    uncovered = [family["id"] for family in protocol["coverageFamilies"]
                 if family["disposition"] != "closed" or not family["evidence"]]
    require("at most one uncovered family", len(uncovered) <=
            protocol["coverageUniverse"]["maximumUncoveredFamilies"])
    elapsed = time.monotonic() - started
    if elapsed > float(protocol["budget"]["maximumWallTimeSeconds"]):
        boundary, decision = 3, "record-native-dusk-grammar-coverage-inconclusive-at-cap"
    elif not uncovered:
        boundary, decision = 2, "close-existing-native-dusk-grammar"
    else:
        boundary, decision = 1, "freeze-one-uncovered-native-family-for-capacity"
    ledger_after = identity.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": boundary,
        "decision": decision,
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "coverageFamilies": protocol["coverageFamilies"],
        "nonCandidateSourceFamilies": protocol["nonCandidateSourceFamilies"],
        "uncoveredCandidateFamilies": uncovered,
        "evidenceResults": evidence_results,
        "sourceIdentity": {
            "commit": protocol["immutableInputs"]["sourceCommit"],
            "sha256": protocol["immutableInputs"]["sourceSha256"],
            "contentSha256": protocol["immutableInputs"]["contentSha256"],
        },
        "newSimulatorObservationRows": 0,
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "newLedgerRows": 0,
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "maximumModelContextTokens": 0,
        "wallTimeSeconds": elapsed,
        "authority": protocol["decisionRules"][
            "successAuthority" if boundary == 1 else (
                "futilityAuthority" if boundary == 2 else "inconclusiveAuthority")],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS",
        "decision": decision,
        "decisionBoundary": boundary,
        "uncoveredCandidateFamilies": uncovered,
        "summarySha256": core.file_sha(SUMMARY),
        "newSimulatorObservationRows": 0,
    }))


if __name__ == "__main__":
    main()
