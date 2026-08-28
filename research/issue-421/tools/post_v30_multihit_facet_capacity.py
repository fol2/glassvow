#!/usr/bin/env python3
"""Zero-row multi-hit Facet alias-fracture capacity audit for issue #421."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_competing_structural_options as structural
import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v30-multihit-facet-capacity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v30-multihit-facet-capacity-v1.json"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Multi-hit Facet capacity mismatch: {label}")


def main_blob(path: str) -> bytes:
    return subprocess.run(
        ["git", "show", f"HEAD:{path}"], cwd=core.SOURCE,
        check=True, capture_output=True,
    ).stdout


def multi_hit_cards(content: dict[str, Any]) -> list[str]:
    return sorted(
        card_id for card_id, card in content["cards"].items()
        if card.get("type") == "attack"
        and any(effect.get("kind") == "dmg" and int(effect.get("times", 1)) > 1
                for effect in card.get("effects", []))
        and any(effect.get("kind") == "dmg" and int(effect.get("times", 1)) > 1
                for effect in card.get("up", {}).get("effects", []))
    )


def played(row: dict[str, Any], cards: set[str]) -> bool:
    events = row["packageEvents"]
    return any(int(events.get(f"{card_id}Played", 0)) > 0 for card_id in cards)


def co_played(row: dict[str, Any], first: str, second: str) -> bool:
    events = row["packageEvents"]
    return int(events.get(f"{first}Played", 0)) > 0 \
        and int(events.get(f"{second}Played", 0)) > 0


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the multi-hit Facet summary")
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
    content = json.loads(main_blob("content/full-content.json"))
    combat = main_blob("domain/rules/combat.gd").decode()
    cards = multi_hit_cards(content)
    require("complete source card class", cards == protocol["sourceClass"]["cardIds"])
    for sentinel in protocol["sourceClass"]["facetAliasSentinels"]:
        require(f"Facet alias sentinel {sentinel['text']}",
                combat.count(sentinel["text"]) == sentinel["count"])

    trace = protocol["trace"]
    plan_path = core.CACHE / f"{trace['planSha256']}.json"
    output_path = core.CACHE / f"{trace['outputSha256']}.json"
    content_path = core.CACHE / f"{trace['contentSha256']}.json"
    for label, path, expected in (
        ("plan", plan_path, trace["planSha256"]),
        ("output", output_path, trace["outputSha256"]),
        ("content", content_path, trace["contentSha256"]),
    ):
        require(f"{label} SHA", core.file_sha(path) == expected)
    plan = json.loads(plan_path.read_text())
    output = json.loads(output_path.read_text())
    require("output plan identity", output["planSha256"] == trace["planSha256"])
    require("output source commit",
            output["contentIdentity"]["commit"] == immutable["sourceCommit"])
    require("output engine disclosure",
            output["contentIdentity"]["godot"] == trace["legacyEngineIdentity"])
    require("live content identity",
            core.sha(main_blob("content/full-content.json")) == trace["contentSha256"])

    cohort = protocol["cohort"]
    require("plan rows", len(plan["rows"]) == cohort["rows"])
    require("output rows", len(output["rows"]) == cohort["rows"])
    require("cached-row ceiling", len(output["rows"])
            <= protocol["budget"]["maximumCachedObservationRowsRead"])
    rows: dict[tuple[int, int], dict[str, Any]] = {}
    for spec, row in zip(plan["rows"], output["rows"]):
        require("policy root", int(spec["policyRoot"]) == cohort["policyRoot"])
        require("aspect", spec["aspect"] == cohort["aspect"])
        require("vow", int(spec["vow"]) == cohort["vow"])
        key = (int(spec["policyIndex"]), int(spec["seed"]))
        require(f"unique identity {key}", key not in rows)
        require(f"row seed {key}", int(row["seed"]) == key[1])
        rows[key] = row
    require("complete rectangle", len(rows) == cohort["rows"])

    card_set = set(cards)
    active = structural.robust_set(rows, protocol, lambda row: played(row, card_set))
    inactive = structural.exact_inactive_set(
        rows, protocol, lambda row: played(row, card_set),
    )
    ambiguous = set(range(cohort["policyCount"])) - active - inactive
    viable = {
        policy for policy in active
        if any(played(rows[(policy, seed)], card_set)
               and rows[(policy, seed)]["outcome"] == "win"
               for seed in cohort["simulationSeeds"])
    }
    anchors = {
        "scoreline": structural.robust_set(
            rows, protocol, lambda row: co_played(row, "chisel", "executioner"),
        ),
        "afterimage": structural.robust_set(
            rows, protocol, lambda row: co_played(row, "defend", "guardedStrike"),
        ),
    }
    for name, values in anchors.items():
        require(f"{name} anchor identity", len(values)
                == protocol["anchors"][name]["activePolicies"])
    separations = {name: structural.separation(active, values)
                   for name, values in anchors.items()}
    per_card = {}
    for card_id in cards:
        one = {card_id}
        per_card[card_id] = {
            "robustActivePolicies": len(structural.robust_set(
                rows, protocol, lambda row, selected=one: played(row, selected),
            )),
            "exactInactivePolicies": len(structural.exact_inactive_set(
                rows, protocol, lambda row, selected=one: played(row, selected),
            )),
            "playedRows": sum(played(row, one) for row in rows.values()),
        }

    gates = protocol["gates"]
    fault_rows = sum(row.get("outcome") in ("stall", "error")
                     or bool(row.get("error")) for row in rows.values())

    def separated(result: dict[str, Any]) -> bool:
        return (result["candidateOnlyPolicies"] >= gates["minimumCandidateOnlyPolicies"]
                and result["anchorOnlyPolicies"] >= gates["minimumAnchorOnlyPolicies"]
                and result["jaccard"] <= gates["maximumAnchorJaccard"])

    gate_results = {
        "active": len(active) >= gates["minimumPotentialActivePolicies"],
        "inactive": len(inactive) >= gates["minimumExactInactivePolicies"],
        "viable": len(viable) >= gates["minimumViablePolicies"],
        "sourceBreadth": sum(value["robustActivePolicies"] > 0
                             for value in per_card.values())
        >= gates["minimumRobustlyActiveSourceCards"],
        "scorelineSeparation": separated(separations["scoreline"]),
        "afterimageSeparation": separated(separations["afterimage"]),
        "reliability": fault_rows <= gates["maximumBaselineFaultRows"],
    }
    elapsed = time.monotonic() - started
    if elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        boundary, outcome = 3, "inconclusive"
        decision = "record-multihit-facet-capacity-inconclusive-at-cap"
    elif all(gate_results.values()):
        boundary, outcome = 1, "success"
        decision = "freeze-multihit-extra-facet-for-identity-preflight"
    else:
        boundary, outcome = 2, "futility"
        decision = "close-complete-multihit-extra-facet-family-at-cap"

    ledger_after = identity.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": boundary,
        "decision": decision,
        "outcomeClass": outcome,
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "registrationDisclosure": protocol["registrationDisclosure"],
        "sourceIdentity": {"commit": source_commit,
                           "sha256": immutable["sourceSha256"]},
        "sourceClass": {"cardIds": cards, "perCardSupport": per_card},
        "counts": {
            "potentialActivePolicies": len(active),
            "exactInactivePolicies": len(inactive),
            "ambiguousPolicies": len(ambiguous),
            "viablePolicies": len(viable),
            "baselineFaultRows": fault_rows,
        },
        "policySets": {
            "potentialActive": sorted(active),
            "exactInactive": sorted(inactive),
            "ambiguous": sorted(ambiguous),
            "viable": sorted(viable),
        },
        "anchors": {name: sorted(values) for name, values in anchors.items()},
        "separation": separations,
        "gateResults": gate_results,
        "eligible": all(gate_results.values()),
        "traceIdentity": {
            "rows": len(rows),
            "planSha256": trace["planSha256"],
            "outputSha256": trace["outputSha256"],
            "legacyEngineIdentity": trace["legacyEngineIdentity"],
            "newRuntimeExecution": False,
        },
        "newSimulatorObservationRows": 0,
        "cachedObservationRowsRead": len(rows),
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
        "newSimulatorObservationRows": 0,
        "summarySha256": core.file_sha(SUMMARY),
    }))


if __name__ == "__main__":
    main()
