#!/usr/bin/env python3
"""Zero-row independent audit of the Shatterer's Crown CRN decision."""

from __future__ import annotations

import copy
import json
import random
import statistics
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-crown-effect-crn-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-crown-effect-crn-v1.json"
AUDIT = core.ROOT / "summaries/post-v38-crown-effect-crn-v1-audit.json"


def need(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Crown CRN audit mismatch: {label}")


def canonical_without(row: dict[str, Any], extra: tuple[str, ...] = ()) -> str:
    value = copy.deepcopy(row)
    for key in ("id", "stage", "arm", *extra):
        value.pop(key, None)
    return core.canonical(value)


def percentile(values: list[float], probability: float) -> float:
    ordered = sorted(values)
    position = (len(ordered) - 1) * probability
    low = int(position)
    high = min(low + 1, len(ordered) - 1)
    return ordered[low] + (ordered[high] - ordered[low]) * (position - low)


def interval(values: list[float], seed: int) -> dict[str, float]:
    rng = random.Random(seed)
    boot = [statistics.fmean(rng.choice(values) for _ in values) for _ in range(5000)]
    return {"point": statistics.fmean(values), "p025": percentile(boot, 0.025),
            "p975": percentile(boot, 0.975)}


def shatters(row: dict[str, Any]) -> float:
    return float(sum(int(fight.get("shatters", 0)) for fight in row.get("fights", [])))


def duration(row: dict[str, Any]) -> float:
    fights = row.get("fights", [])
    need("duration has fights", bool(fights))
    return statistics.fmean(float(fight["turns"]) for fight in fights)


def acquisition_prefix(row: dict[str, Any]) -> list[dict[str, Any]]:
    choices = row["trajectory"]["bossRelics"]
    for index, choice in enumerate(choices):
        if choice.get("chosen") == "shatterersCrown":
            return choices[:index + 1]
    return []


def main() -> None:
    if AUDIT.exists():
        raise RuntimeError("refusing to overwrite the Crown CRN audit")
    before = identity.ledger_identity()
    protocol = json.loads(PROTOCOL.read_text())
    summary = json.loads(SUMMARY.read_text())
    need("protocol SHA", core.file_sha(PROTOCOL) == summary["protocolSha256"])
    need("summary SHA",
         core.file_sha(SUMMARY) == "7b7a11a1f78f42dcdf7f8a1ccd2515c9ddb10b066ade66a04f66f486b4aafa14")
    need("ledger freeze", before == summary["ledgerAfter"])
    execution = summary["execution"]
    raw_path = core.CACHE / f"{execution['discovery']['outputSha256']}.json"
    baseline_path = core.CACHE / f"{protocol['baseline']['outputSha256']}.json"
    need("raw output SHA", core.file_sha(raw_path) == execution["discovery"]["outputSha256"])
    need("baseline output SHA", core.file_sha(baseline_path) == protocol["baseline"]["outputSha256"])
    raw = json.loads(raw_path.read_text())
    baseline = json.loads(baseline_path.read_text())
    need("raw row count", len(raw["rows"]) == 160)
    baseline_rows = {(int(row["policyIndex"]), int(row["seed"])): row
                     for row in baseline["rows"]
                     if row.get("arm") == "policy" and row.get("aspect") == "duskblade"}
    indexed: dict[tuple[str, int, int, str], dict[str, Any]] = {}
    for row in raw["rows"]:
        parts = str(row["id"]).split("-")
        cohort = parts[2]
        cell = parts[3]
        indexed[(cohort, int(row["policyIndex"]), int(row["seed"]), cell)] = row
    need("raw identities unique", len(indexed) == 160)
    cells = list(protocol["designMatrix"])
    for cohort, pairs in (("active", protocol["cohorts"]["activeRows"]),
                          ("negative", protocol["cohorts"]["negativeControlRows"])):
        for pair in pairs:
            policy, seed = int(pair["policyIndex"]), int(pair["seed"])
            block = {cell: indexed[(cohort, policy, seed, cell)] for cell in cells}
            current = copy.deepcopy(block["current"])
            current.pop("trajectory", None)
            need("current baseline exact",
                 canonical_without(current) == canonical_without(baseline_rows[(policy, seed)]))
            need("policy exact", len({core.canonical(row["policy"])
                                      for row in block.values()}) == 1)
            if cohort == "negative":
                need("negative control exact",
                     len({canonical_without(row) for row in block.values()}) == 1)
            else:
                prefixes = [acquisition_prefix(row) for row in block.values()]
                need("acquisition prefix exact", bool(prefixes[0]) and
                     len({core.canonical(prefix) for prefix in prefixes}) == 1)

    coefficients = {
        "authoredTotal": {"current": 1, "bothOff": -1},
        "thresholdAtFervor": {"current": 1, "thresholdOff": -1},
        "thresholdOnlyTotal": {"fervorOff": 1, "bothOff": -1},
    }
    effects: dict[str, Any] = {}
    active = protocol["cohorts"]["activeRows"]
    for contrast_index, (name, weights) in enumerate(coefficients.items()):
        clustered: dict[int, dict[str, list[float]]] = {}
        for pair in active:
            policy, seed = int(pair["policyIndex"]), int(pair["seed"])
            for endpoint, function in (("shatters", shatters), ("duration", duration)):
                value = sum(weight * function(indexed[("active", policy, seed, cell)])
                            for cell, weight in weights.items())
                clustered.setdefault(policy, {}).setdefault(endpoint, []).append(value)
        effects[name] = {}
        for endpoint_index, endpoint in enumerate(("shatters", "duration")):
            values = [statistics.fmean(group[endpoint])
                      for _, group in sorted(clustered.items())]
            effects[name][endpoint] = {
                **interval(values, int(protocol["estimators"]["bootstrapSeed"])
                           + 10 * list(protocol["contrasts"]).index(name) + endpoint_index),
                "positivePolicies": sum(value > 0 for value in values),
                "inactivePolicies": sum(value == 0 for value in values),
                "negativePolicies": sum(value < 0 for value in values),
            }
            reported = summary["design"]["effects"][name][endpoint]
            for field in ("point", "p025", "p975"):
                need(f"{name} {endpoint} {field}",
                     effects[name][endpoint][field] == reported[field])

    assessments = {row["name"]: row for row in summary["candidateAssessments"]}
    current = assessments["shipping-shatterers-crown"]
    threshold = assessments["threshold-only-shatterers-crown"]
    need("current fixed failure", current["status"] == "fail" and
         current["inactivePolicyWitnesses"] == 1 and
         current["mechanismInactiveWitnesses"] == 1)
    need("threshold-only fixed failure", threshold["status"] == "fail" and
         threshold["inactivePolicyWitnesses"] == 0 and
         threshold["mechanismInactiveWitnesses"] == 0)
    need("decision boundary", summary["decisionBoundary"] == 2 and
         summary["decision"] == "close-shatterers-crown-effect-family" and
         summary["selectedCandidate"] is None)
    after = identity.ledger_identity()
    need("zero-row audit", after == before)
    audit = {
        "schemaVersion": 1, "issue": 421, "status": "PASS",
        "decisionBoundary": 2, "decision": summary["decision"],
        "protocolSha256": core.file_sha(PROTOCOL), "summarySha256": core.file_sha(SUMMARY),
        "rawOutputSha256": core.file_sha(raw_path), "rawRows": len(raw["rows"]),
        "identity": summary["design"]["identity"], "effects": effects,
        "fixedFailures": {
            "shippingInactivePolicies": current["inactivePolicyWitnesses"],
            "thresholdOnlyInactivePolicies": threshold["inactivePolicyWitnesses"],
            "requiredInactivePolicies": protocol["gates"]["minimumInactivePolicyWitnesses"],
        },
        "newSimulatorObservationRows": 0, "newLedgerRows": 0,
        "ledgerBefore": before, "ledgerAfter": after,
        "auditRunnerSha256": core.file_sha(Path(__file__)),
    }
    AUDIT.write_text(json.dumps(audit, indent=2, sort_keys=True) + "\n")
    print(core.canonical({"status": "PASS", "decisionBoundary": 2,
                          "auditSha256": core.file_sha(AUDIT),
                          "newSimulatorObservationRows": 0}))


if __name__ == "__main__":
    main()
