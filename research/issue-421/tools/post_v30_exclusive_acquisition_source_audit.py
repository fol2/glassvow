#!/usr/bin/env python3
"""Exact-source feasibility audit for a deterministic exclusive acquisition path."""

from __future__ import annotations

import json
import re
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v30-exclusive-acquisition-source-audit-v1.json"
SUMMARY = core.ROOT / "summaries/post-v30-exclusive-acquisition-source-audit-v1.json"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Exclusive-acquisition source mismatch: {label}")


def main_blob(path: str) -> bytes:
    return subprocess.run(
        ["git", "show", f"HEAD:{path}"], cwd=core.SOURCE,
        check=True, capture_output=True,
    ).stdout


def function_blocks(path: str, text: str) -> list[dict[str, str]]:
    starts = list(re.finditer(r"(?m)^(?:static\s+)?func\s+([A-Za-z0-9_]+)\s*\(", text))
    blocks: list[dict[str, str]] = []
    for index, match in enumerate(starts):
        end = starts[index + 1].start() if index + 1 < len(starts) else len(text)
        blocks.append({"file": path, "function": match.group(1), "text": text[match.start():end]})
    return blocks


def alias_for(text: str) -> str:
    lower = text.lower()
    aliases = [
        ("lantern-art", ("lantern", "art")),
        ("boss-relic", ("boss", "relic")),
        ("shop", ("shop",)),
        ("event", ("event",)),
        ("deed-unlock", ("deed", "unlock")),
        ("removal", ("remove", "removal")),
        ("elite", ("elite",)),
        ("normal-reward", ("reward", "card")),
    ]
    for alias, terms in aliases:
        if any(term in lower for term in terms):
            return alias
    return "unclassified"


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite exclusive-acquisition source summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    immutable = protocol["immutableInputs"]
    require("runner SHA", core.file_sha(Path(__file__)) == immutable["runnerSha256"])
    require("task capsule SHA", core.file_sha(core.ROOT / "task-capsule.json") ==
            immutable["taskCapsuleSha256"])
    require("source commit", subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=core.SOURCE, check=True,
        text=True, capture_output=True,
    ).stdout.strip() == immutable["sourceCommit"])
    blobs = {path: main_blob(path) for path in immutable["sourceSha256"]}
    for path, expected_sha in immutable["sourceSha256"].items():
        require(f"{path} SHA", core.sha(blobs[path]) == expected_sha)

    evidence: dict[str, dict[str, Any]] = {}
    for name, spec in protocol["closedPathEvidence"].items():
        path = core.ROOT / spec["path"]
        require(f"{name} SHA", core.file_sha(path) == spec["sha256"])
        evidence[name] = json.loads(path.read_text())
        require(f"{name} decision", evidence[name]["decision"] == spec["decision"])

    texts = {path: blob.decode() for path, blob in blobs.items() if path.endswith(".gd")}
    blocks = [block for path, text in texts.items() for block in function_blocks(path, text)]
    terms = protocol["sourceClassification"]
    acquisition_blocks: list[dict[str, Any]] = []
    pilot_aliases: set[str] = set()
    for block in blocks:
        lower = block["text"].lower()
        acquisition = any(term in lower for term in terms["acquisitionTerms"])
        choice = any(term in lower for term in terms["choiceTerms"])
        aspect = any(term in lower for term in terms["aspectTerms"])
        rng = any(term in lower for term in terms["rngTerms"])
        persistent = any(term in lower for term in terms["persistenceTerms"])
        alias = alias_for(block["function"] + "\n" + block["text"])
        if block["file"] == "tools/balance_pilot.gd" and acquisition and choice:
            pilot_aliases.add(alias)
        if block["file"] != "tools/balance_pilot.gd" and acquisition:
            acquisition_blocks.append({
                "file": block["file"],
                "function": block["function"],
                "alias": alias,
                "choice": choice,
                "aspectQualified": aspect,
                "usesRng": rng,
                "persistent": persistent,
            })

    closed_aliases = set(protocol["closedAliases"])
    for block in acquisition_blocks:
        block["policyVisible"] = block["alias"] in pilot_aliases
        block["closedAlias"] = block["alias"] in closed_aliases
        block["eligible"] = (
            block["choice"] and block["aspectQualified"] and
            not block["usesRng"] and block["persistent"] and
            block["policyVisible"] and not block["closedAlias"]
        )
    eligible = [block for block in acquisition_blocks if block["eligible"]]

    run_text = texts["domain/state/run_state.gd"].lower()
    save_text = texts["application/save_service.gd"].lower()
    content_text = texts["content/content_db.gd"].lower()
    generic_contract = {
        "runOwnsGenericRelicCollection": "relic" in run_text,
        "saveUsesDictionaryPayload": "dictionary" in save_text or "dict" in save_text,
        "contentUsesStringDictionaryIds": "dictionary" in content_text and "string" in content_text,
    }
    source_contract_compatible = all(generic_contract.values())
    elapsed = time.monotonic() - started
    if elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        boundary, decision = 3, "record-exclusive-acquisition-source-inconclusive-at-cap"
    elif len(eligible) == 1 and source_contract_compatible:
        boundary, decision = 1, "freeze-one-native-exclusive-acquisition-shape"
    else:
        boundary, decision = 2, "record-native-exclusive-acquisition-path-unavailable"

    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    ledger_after = identity.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    authority_key = (
        "successAuthority" if boundary == 1 else
        "futilityAuthority" if boundary == 2 else "inconclusiveAuthority"
    )
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": boundary,
        "decision": decision,
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "sourceFilesRead": len(blobs),
        "sourceFunctionBlocks": len(blocks),
        "acquisitionBlocks": acquisition_blocks,
        "pilotAliases": sorted(pilot_aliases),
        "eligibleNativePaths": eligible,
        "genericContract": generic_contract,
        "sourceContractCompatible": source_contract_compatible,
        "closedPathDecisions": {name: item["decision"] for name, item in evidence.items()},
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
        "eligibleNativePaths": len(eligible),
        "newSimulatorObservationRows": 0,
        "summarySha256": core.file_sha(SUMMARY),
    }))


if __name__ == "__main__":
    main()
