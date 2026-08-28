#!/usr/bin/env python3
"""Zero-row Dimmed-to-Facet structural capacity audit for issue #421."""

from __future__ import annotations

import json
import re
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_competing_structural_options as structural
import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v30-dimmed-facet-capacity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v30-dimmed-facet-capacity-v1.json"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Dimmed-Facet capacity mismatch: {label}")


def main_blob(path: str) -> bytes:
    return subprocess.run(
        ["git", "show", f"HEAD:{path}"], cwd=core.SOURCE,
        check=True, capture_output=True,
    ).stdout


def function_source(source: str, name: str) -> str:
    match = re.search(rf"(?m)^func {re.escape(name)}\(", source)
    require(f"function {name}", match is not None)
    assert match is not None
    following = re.search(r"(?m)^func [A-Za-z0-9_]+\(", source[match.end():])
    end = len(source) if following is None else match.end() + following.start()
    return source[match.start():end]


def source_sets(content: dict[str, Any]) -> dict[str, list[str]]:
    producers = []
    attacks = []
    for card_id, card in content["cards"].items():
        if card.get("type") == "attack":
            attacks.append(card_id)
        if any(effect.get("kind") == "status"
               and effect.get("who") in {"target", "allEnemies"}
               and effect.get("id") == "weak"
               for effect in card.get("effects", [])):
            producers.append(card_id)
    return {"dimmedProducers": sorted(producers), "attacks": sorted(attacks)}


def co_played(row: dict[str, Any], first: str, second: str) -> bool:
    events = row["packageEvents"]
    return int(events.get(f"{first}Played", 0)) > 0 \
        and int(events.get(f"{second}Played", 0)) > 0


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the Dimmed-Facet summary")
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
    policy = main_blob("tools/balance_policy.gd").decode()
    derived = source_sets(content)
    require("complete source sets", derived == protocol["sourceClasses"])
    require("sampled Weak preference", protocol["sourceAssertions"]["policyWeakField"]
            in policy)
    hit_enemy = function_source(combat, "hit_enemy")
    preview = function_source(combat, "preview_play") + function_source(combat, "_preview_hit")
    for text in protocol["sourceAssertions"]["currentHitSentinels"]:
        require(f"combat sentinel {text}", text in combat)
    require("target Weak absent from hit", '_sget(e.statuses, "weak")' not in hit_enemy)
    require("target Weak absent from preview",
            '_sget(target.statuses, "weak")' not in preview)

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
        require("trace arm", spec.get("arm") == "cohand-telemetry-explicit-null")
        require("trace capture", spec.get("captureTrace") is True)
        require("trace explicit null", spec.get("explicitNull") is True)
        key = (int(spec["policyIndex"]), int(spec["seed"]))
        require(f"unique identity {key}", key not in rows)
        require(f"row seed {key}", int(row["seed"]) == key[1])
        rows[key] = row
    require("complete rectangle", len(rows) == cohort["rows"])

    producer_set = set(derived["dimmedProducers"])
    attack_set = set(derived["attacks"])

    def opportunities(row: dict[str, Any]) -> set[tuple[str, str]]:
        return structural.ordered_pairs(row, producer_set, attack_set)

    active = structural.robust_set(rows, protocol, lambda row: bool(opportunities(row)))
    inactive = structural.exact_inactive_set(
        rows, protocol, lambda row: bool(opportunities(row)),
    )
    ambiguous = set(range(cohort["policyCount"])) - active - inactive
    viable = {
        policy_index for policy_index in active
        if any(opportunities(rows[(policy_index, seed)])
               and rows[(policy_index, seed)]["outcome"] == "win"
               for seed in cohort["simulationSeeds"])
    }
    pairs = set().union(*(opportunities(row) for row in rows.values()))
    producer_cards = sorted({pair[0] for pair in pairs})
    consumer_cards = sorted({pair[1] for pair in pairs})
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
    fault_rows = sum(row.get("outcome") in ("stall", "error")
                     or bool(row.get("error")) for row in rows.values())
    gates = protocol["gates"]

    def separated(result: dict[str, Any]) -> bool:
        return (result["candidateOnlyPolicies"] >= gates["minimumCandidateOnlyPolicies"]
                and result["anchorOnlyPolicies"] >= gates["minimumAnchorOnlyPolicies"]
                and result["jaccard"] <= gates["maximumAnchorJaccard"])

    gate_results = {
        "active": len(active) >= gates["minimumPotentialActivePolicies"],
        "inactive": len(inactive) >= gates["minimumExactInactivePolicies"],
        "viable": len(viable) >= gates["minimumViablePolicies"],
        "sourceBreadth": (
            len(producer_cards) >= gates["minimumDistinctProducerCards"]
            and len(consumer_cards) >= gates["minimumDistinctConsumerCards"]
            and len(pairs) >= gates["minimumDistinctPairs"]
        ),
        "scorelineSeparation": separated(separations["scoreline"]),
        "afterimageSeparation": separated(separations["afterimage"]),
        "reliability": fault_rows <= gates["maximumBaselineFaultRows"],
    }
    elapsed = time.monotonic() - started
    if elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        boundary, outcome = 3, "inconclusive"
        decision = "record-dimmed-facet-capacity-inconclusive-at-cap"
    elif all(gate_results.values()):
        boundary, outcome = 1, "success"
        decision = "freeze-dimmed-facet-primitive-for-identity-preflight"
    else:
        boundary, outcome = 2, "futility"
        decision = "close-dimmed-facet-primitive-family-at-cap"

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
        "sourceIdentity": {"commit": source_commit,
                           "sha256": immutable["sourceSha256"]},
        "sourceClasses": derived,
        "counts": {
            "potentialActivePolicies": len(active),
            "exactInactivePolicies": len(inactive),
            "ambiguousPolicies": len(ambiguous),
            "viablePolicies": len(viable),
            "distinctProducerCards": len(producer_cards),
            "distinctConsumerCards": len(consumer_cards),
            "distinctPairs": len(pairs),
            "baselineFaultRows": fault_rows,
        },
        "sourceBreadth": {
            "producerCards": producer_cards,
            "consumerCards": consumer_cards,
            "pairs": [list(pair) for pair in sorted(pairs)],
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
