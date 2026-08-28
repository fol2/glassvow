#!/usr/bin/env python3
"""Zero-row current-main Dusk-core surface exhaustion audit for issue #421."""

from __future__ import annotations

import json
import re
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-source-complete-exhaustion-audit-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-source-complete-exhaustion-audit-v1.json"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Source-complete exhaustion mismatch: {label}")


def main_blob(path: str) -> bytes:
    return subprocess.run(
        ["git", "show", f"HEAD:{path}"], cwd=core.SOURCE,
        check=True, capture_output=True,
    ).stdout


def ember_line_inventory(source: str) -> dict[str, list[str]]:
    matches = list(re.finditer(
        r"(?m)^(?:static )?func ([A-Za-z0-9_]+)\(", source,
    ))
    inventory: dict[str, list[str]] = {}
    for index, match in enumerate(matches):
        end = matches[index + 1].start() if index + 1 < len(matches) else len(source)
        lines = []
        for raw in source[match.start():end].splitlines():
            code = raw.split("#", 1)[0].strip()
            if code and ("cb.embers" in code or "ember_cap" in code
                         or "gain_embers(" in code):
                lines.append(code)
        if lines:
            inventory[match.group(1)] = lines
    return dict(sorted(inventory.items()))


def string_paths(value: Any, needle: str, prefix: str = "") -> list[str]:
    found: list[str] = []
    if isinstance(value, dict):
        for key, child in value.items():
            path = f"{prefix}/{key}" if prefix else str(key)
            found.extend(string_paths(child, needle, path))
    elif isinstance(value, list):
        for index, child in enumerate(value):
            found.extend(string_paths(child, needle, f"{prefix}/{index}"))
    elif value == needle:
        found.append(prefix)
    return found


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the source-complete audit summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    immutable = protocol["immutableInputs"]
    require("runner SHA", core.file_sha(Path(__file__)) == immutable["runnerSha256"])
    source_commit = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=core.SOURCE,
        check=True, capture_output=True, text=True,
    ).stdout.strip()
    require("source commit", source_commit == immutable["sourceCommit"])
    for path, expected in immutable["sourceSha256"].items():
        require(f"source {path}", core.sha(main_blob(path)) == expected)
    for path, expected in immutable["fileSha256"].items():
        require(path, core.file_sha(core.ROOT / path) == expected)

    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    combat = main_blob("domain/rules/combat.gd").decode()
    content = json.loads(main_blob("content/full-content.json"))
    inventory = ember_line_inventory(combat)
    require("complete Ember line inventory",
            inventory == protocol["expectedEmberLineInventory"])

    coverage = protocol["runtimeSurfaceCoverage"]
    require("one coverage row per Ember function",
            sorted(row["function"] for row in coverage) == sorted(inventory))
    require("unique coverage functions",
            len({row["function"] for row in coverage}) == len(coverage))
    for row in coverage:
        function = row["function"]
        require(f"coverage lines {function}", row["lines"] == inventory[function])
        for path, expected in row.get("evidence", {}).items():
            evidence = json.loads((core.ROOT / path).read_text())
            require(f"evidence decision {path}",
                    evidence.get("decision") == expected)

    dusk = content["aspects"][0]
    require("Duskblade source identity", dusk["id"] == "duskblade"
            and dusk["startRelic"] == "emberHeart" and dusk["art"] == "flare")
    require("Crown carrier definition",
            content["relics"]["crownOfTheHearth"]
            == protocol["unclosedCarrierDefinition"])
    require("Crown boss reachability",
            "crownOfTheHearth" in content["relicPools"]["boss"])

    mention_inventory: dict[str, list[str]] = {}
    for path in sorted((core.ROOT / "summaries").glob("*.json")):
        paths = string_paths(json.loads(path.read_text()), "crownOfTheHearth")
        if paths:
            mention_inventory[str(path.relative_to(core.ROOT))] = paths
    require("prior Crown mention inventory",
            mention_inventory == protocol["priorCrownMentionInventory"])

    unclosed = [row["id"] for row in coverage if row["disposition"] == "unclosed"]
    elapsed = time.monotonic() - started
    if elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        boundary, outcome = 3, "inconclusive"
        decision = "record-source-complete-exhaustion-audit-inconclusive-at-cap"
        selected = None
    elif len(unclosed) == 1:
        boundary, outcome = 1, "success"
        selected = unclosed[0]
        decision = f"freeze-{selected}-for-zero-row-capacity-preregistration"
    elif not unclosed:
        boundary, outcome = 2, "futility"
        decision = "record-current-source-structural-exhaustion-at-cap"
        selected = None
    else:
        boundary, outcome = 3, "inconclusive"
        decision = "record-multiple-unclosed-current-source-surfaces-at-cap"
        selected = None

    ledger_after = identity.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": boundary,
        "decision": decision,
        "outcomeClass": outcome,
        "selectedFamily": selected,
        "unclosedFamilies": unclosed,
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "sourceIdentity": {"commit": source_commit,
                           "sha256": immutable["sourceSha256"]},
        "emberLineInventory": inventory,
        "runtimeSurfaceCoverage": coverage,
        "priorCrownMentionInventory": mention_inventory,
        "newSimulatorObservationRows": 0,
        "cachedObservationRowsRead": 0,
        "newLedgerRows": 0,
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "maximumModelContextTokens": 0,
        "wallTimeSeconds": elapsed,
        "factorDisposition": protocol["factorDisposition"],
        "authority": protocol["decisionRules"][f"{outcome}Authority"],
    }
    SUMMARY.parent.mkdir(parents=True, exist_ok=True)
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS",
        "decision": decision,
        "decisionBoundary": boundary,
        "selectedFamily": selected,
        "newSimulatorObservationRows": 0,
        "summarySha256": core.file_sha(SUMMARY),
    }))


if __name__ == "__main__":
    main()
