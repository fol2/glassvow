#!/usr/bin/env python3
"""Zero-new-row capacity audit for the complete non-damaging Skill-chip line."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any, Callable

import post_v38_cohand_opportunity_decomposition as cohand
import post_v38_competing_structural_options as structural
import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v30-skill-chip-capacity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v30-skill-chip-capacity-v1.json"
DAMAGING_SPECIALS = {"leech", "execute", "momentum", "phantom", "devour",
                     "shatterEcho", "emberNova"}


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Skill-chip capacity mismatch: {label}")


def main_blob(path: str) -> bytes:
    return subprocess.run(
        ["git", "show", f"HEAD:{path}"], cwd=core.SOURCE,
        check=True, capture_output=True,
    ).stdout


def source_sets(content: dict[str, Any]) -> dict[str, list[str]]:
    producers: list[str] = []
    attacks: list[str] = []
    for card_id, card in content["cards"].items():
        effects = card.get("effects", [])
        if card.get("type") == "attack":
            attacks.append(card_id)
        non_damaging = not any(
            effect.get("kind") == "dmg"
            or (effect.get("kind") == "special"
                and effect.get("id") in DAMAGING_SPECIALS)
            for effect in effects
        )
        if (card.get("type") == "skill" and non_damaging
                and any(effect.get("kind") == "chip" for effect in effects)):
            producers.append(card_id)
    return {"skillChipProducers": sorted(producers), "attacks": sorted(attacks)}


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite skill-chip capacity summary")
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
    for path, expected in immutable["sourceSha256"].items():
        require(f"source {path}", core.sha(main_blob(path)) == expected)
    for path, expected in immutable["fileSha256"].items():
        require(path, core.file_sha(core.ROOT / path) == expected)
    for name, spec in protocol["priorEvidence"].items():
        decision = json.loads((core.ROOT / spec["path"]).read_text())["decision"]
        require(f"{name} decision", decision == spec["decision"])
    h19 = main_blob(protocol["h19Evidence"]["path"])
    require("H19 evidence SHA", core.sha(h19) == protocol["h19Evidence"]["sha256"])

    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    trace = protocol["trace"]
    plan_path = core.CACHE / f"{trace['planSha256']}.json"
    output_path = core.CACHE / f"{trace['outputSha256']}.json"
    content_path = core.CACHE / f"{trace['contentSha256']}.json"
    require("plan SHA", core.file_sha(plan_path) == trace["planSha256"])
    require("output SHA", core.file_sha(output_path) == trace["outputSha256"])
    require("content SHA", core.file_sha(content_path) == trace["contentSha256"])
    plan = json.loads(plan_path.read_text())
    output = json.loads(output_path.read_text())
    content = json.loads(content_path.read_text())
    require("output plan identity", output["planSha256"] == trace["planSha256"])
    require("current-main content identity",
            core.sha(main_blob("content/full-content.json")) == trace["contentSha256"])

    cohort = protocol["cohort"]
    require("plan row count", len(plan["rows"]) == cohort["rows"])
    require("output row count", len(output["rows"]) == cohort["rows"])
    require("cached-row ceiling", len(output["rows"]) <=
            protocol["budget"]["maximumCachedObservationRowsRead"])
    rows: dict[tuple[int, int], dict[str, Any]] = {}
    for spec, row in zip(plan["rows"], output["rows"]):
        require("trace arm", spec.get("arm") == "cohand-telemetry-explicit-null")
        require("trace capture", spec.get("captureTrace") is True)
        require("trace explicit null", spec.get("explicitNull") is True)
        key = (int(spec["policyIndex"]), int(spec["seed"]))
        require(f"unique row {key}", key not in rows)
        require(f"seed identity {key}", int(row["seed"]) == key[1])
        rows[key] = row
    require("complete rectangle", len(rows) == cohort["rows"])

    derived = source_sets(content)
    require("source-derived classes", derived == protocol["sourceCardSets"])
    producers = set(derived["skillChipProducers"])
    consumers = set(derived["attacks"])
    predicate: Callable[[dict[str, Any]], bool] = lambda row: bool(
        structural.ordered_pairs(row, producers, consumers))
    active = structural.robust_set(rows, protocol, predicate)
    inactive = structural.exact_inactive_set(rows, protocol, predicate)
    ambiguous = set(range(cohort["policyCount"])) - active - inactive
    viable = {
        policy_index for policy_index in active
        if any(predicate(rows[(policy_index, seed)])
               and rows[(policy_index, seed)].get("outcome") == "win"
               for seed in cohort["simulationSeeds"])
    }
    pairs: set[tuple[str, str]] = set()
    for row in rows.values():
        pairs.update(structural.ordered_pairs(row, producers, consumers))

    scoreline = structural.robust_set(
        rows, protocol,
        lambda row: bool(structural.ordered_pairs(row, {"chisel"}, {"executioner"})),
    )
    afterimage = structural.robust_set(
        rows, protocol,
        lambda row: cohand.simultaneous_cohand(row, "defend", "guardedStrike"),
    )
    require("Scoreline anchor", sorted(scoreline) ==
            protocol["anchors"]["scoreline"]["policies"])
    require("Afterimage anchor", sorted(afterimage) ==
            protocol["anchors"]["afterimage"]["policies"])
    separations = {
        "scoreline": structural.separation(active, scoreline),
        "afterimage": structural.separation(active, afterimage),
    }
    faults = sum(
        row.get("outcome") in ("stall", "error") or bool(row.get("error"))
        for row in rows.values()
    )
    gates = protocol["gates"]
    standard = {
        "sourceBreadth": len({pair[0] for pair in pairs}) >= gates["minimumProducerCards"],
        "active": len(active) >= gates["minimumPotentialActivePolicies"],
        "inactive": len(inactive) >= gates["minimumExactInactivePolicies"],
        "viable": len(viable) >= gates["minimumViablePolicies"],
        "consumerBreadth": len({pair[1] for pair in pairs}) >= gates["minimumConsumerCards"],
        "scorelineSeparation": all((
            separations["scoreline"]["candidateOnlyPolicies"] >= gates["minimumCandidateOnlyPolicies"],
            separations["scoreline"]["anchorOnlyPolicies"] >= gates["minimumAnchorOnlyPolicies"],
            separations["scoreline"]["jaccard"] <= gates["maximumAnchorJaccard"],
        )),
        "afterimageSeparation": all((
            separations["afterimage"]["candidateOnlyPolicies"] >= gates["minimumCandidateOnlyPolicies"],
            separations["afterimage"]["anchorOnlyPolicies"] >= gates["minimumAnchorOnlyPolicies"],
            separations["afterimage"]["jaccard"] <= gates["maximumAnchorJaccard"],
        )),
        "reliability": faults <= gates["maximumBaselineFaultRows"],
    }
    bottleneck = {
        "soleAuthoredProducer": len(derived["skillChipProducers"]) == 1,
        "nonzeroSelectiveSupport": gates["minimumBottleneckActivePolicies"] <= len(active)
        < gates["minimumPotentialActivePolicies"],
        "halfViability": len(viable) >= gates["minimumBottleneckViablePolicies"],
        "inactive": standard["inactive"],
        "consumerBreadth": standard["consumerBreadth"],
        "scorelineSeparation": standard["scorelineSeparation"],
        "afterimageSeparation": standard["afterimageSeparation"],
        "reliability": standard["reliability"],
    }

    elapsed = time.monotonic() - started
    if elapsed > float(protocol["budget"]["maximumWallTimeSeconds"]):
        boundary, decision = 3, "record-skill-chip-capacity-inconclusive-at-cap"
    elif all(bottleneck.values()):
        boundary, decision = 1, "identify-skill-chip-source-repertoire-bottleneck"
    else:
        boundary, decision = 2, "close-current-skill-chip-line-at-cap"
    ledger_after = identity.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    authority_key = {1: "successAuthority", 2: "futilityAuthority",
                     3: "inconclusiveAuthority"}[boundary]
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": boundary,
        "decision": decision,
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "sourceCardSets": derived,
        "counts": {
            "potentialActivePolicies": len(active),
            "exactInactivePolicies": len(inactive),
            "ambiguousPolicies": len(ambiguous),
            "viablePolicies": len(viable),
            "distinctProducerCards": len({pair[0] for pair in pairs}),
            "distinctConsumerCards": len({pair[1] for pair in pairs}),
            "distinctPairs": len(pairs),
            "baselineFaultRows": faults,
        },
        "policySets": {
            "potentialActive": sorted(active), "exactInactive": sorted(inactive),
            "ambiguous": sorted(ambiguous), "viable": sorted(viable),
        },
        "observedPairs": [list(pair) for pair in sorted(pairs)],
        "separation": separations,
        "standardGateResults": standard,
        "bottleneckGateResults": bottleneck,
        "sourceIdentity": {
            "commit": immutable["sourceCommit"],
            "sha256": immutable["sourceSha256"],
            "taskCapsuleSha256": immutable["taskCapsuleSha256"],
        },
        "traceIdentity": {
            "planSha256": trace["planSha256"],
            "outputSha256": trace["outputSha256"],
            "rows": len(rows), "newRuntimeExecution": False,
        },
        "cachedObservationRowsRead": len(rows),
        "newSimulatorObservationRows": 0,
        "newLedgerRows": 0,
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "maximumModelContextTokens": 0,
        "wallTimeSeconds": elapsed,
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "authority": protocol["decisionRules"][authority_key],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS", "decisionBoundary": boundary, "decision": decision,
        "counts": summary["counts"], "summarySha256": core.file_sha(SUMMARY),
        "newSimulatorObservationRows": 0,
    }))


if __name__ == "__main__":
    main()
