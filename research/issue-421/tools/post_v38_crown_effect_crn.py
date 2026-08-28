#!/usr/bin/env python3
"""Preregistered natural-acquisition CRN ablation for Shatterer's Crown."""

from __future__ import annotations

import copy
import json
import os
import statistics
import subprocess
import tempfile
import time
from pathlib import Path
from typing import Any, Callable

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-crown-effect-crn-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-crown-effect-crn-v1.json"
GODOT = core.ROOT / "toolchains/godot-4.7.1/godot"
META = ("id", "stage", "arm")


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Crown CRN mismatch: {label}")


def canonical_without(row: dict[str, Any], keys: tuple[str, ...] = META) -> str:
    value = copy.deepcopy(row)
    for key in keys:
        value.pop(key, None)
    return core.canonical(value)


def source_identity() -> dict[str, Any]:
    return {
        "sourceCommit": subprocess.run(
            ["git", "rev-parse", "HEAD"], cwd=core.SOURCE, check=True,
            text=True, capture_output=True,
        ).stdout.strip(),
        "godotVersion": subprocess.run(
            [str(GODOT), "--version"], check=True, text=True, capture_output=True,
        ).stdout.strip(),
        "godotBinarySha256": core.file_sha(GODOT),
        "baselineContentSha256": core.file_sha(
            core.CACHE / "a0d608a5142d2e3aab799cdf33d3163922b402c2aaf2a895e46e096399b56cf1.json"
        ),
        "combatRulesSha256": core.file_sha(core.SOURCE / "domain/rules/combat.gd"),
        "pilotSha256": core.file_sha(core.SOURCE / "tools/balance_pilot.gd"),
        "policySha256": core.file_sha(core.SOURCE / "tools/balance_policy.gd"),
        "balanceSimSha256": core.file_sha(core.SOURCE / "tools/balance_sim.gd"),
        "probeSha256": core.file_sha(core.SOURCE / "tools/research_421_probe.gd"),
        "researchCoreSha256": core.file_sha(core.ROOT / "research.py"),
        "runnerSha256": core.file_sha(Path(__file__)),
    }


def remaining(deadline: float) -> int:
    seconds = int(deadline - time.monotonic())
    if seconds < 1:
        raise TimeoutError("Crown CRN exceeded its frozen wall-time ceiling")
    return seconds


def run_plan(db: Any, protocol_sha: str, plan: dict[str, Any],
             deadline: float) -> tuple[dict[str, Any], dict[str, Any]]:
    output = core.run_plan(db, protocol_sha, plan, timeout=remaining(deadline))
    plan_sha, _ = core.cache_json(plan)
    output_sha, _ = core.cache_json(output)
    return output, {"planSha256": plan_sha, "outputSha256": output_sha,
                    "rows": len(output["rows"])}


def baseline_rows(protocol: dict[str, Any]) -> dict[tuple[int, int], dict[str, Any]]:
    path = core.CACHE / f"{protocol['baseline']['outputSha256']}.json"
    require("baseline output SHA", core.file_sha(path) == protocol["baseline"]["outputSha256"])
    output = json.loads(path.read_text())
    require("baseline plan SHA", output["planSha256"] == protocol["baseline"]["planSha256"])
    require("baseline content SHA",
            output["contentIdentity"]["contentFileSha256"] ==
            protocol["immutableInputs"]["baselineContentSha256"])
    rows = [row for row in output["rows"]
            if row.get("arm") == "policy" and row.get("aspect") == "duskblade"
            and int(row.get("vow", -1)) == 5]
    require("baseline rectangle size", len(rows) == 256)
    found = {(int(row["policyIndex"]), int(row["seed"])): row for row in rows}
    require("baseline unique identities", len(found) == len(rows))
    active = sorted([{"policyIndex": key[0], "seed": key[1]} for key, row in found.items()
                     if "shatterersCrown" in set(map(str, row.get("relics", [])))],
                    key=lambda row: (row["policyIndex"], row["seed"]))
    require("active cohort freeze", active == protocol["cohorts"]["activeRows"])
    for row in protocol["cohorts"]["negativeControlRows"]:
        key = (int(row["policyIndex"]), int(row["seed"]))
        require("negative control exists", key in found)
        require("negative control excludes Crown",
                "shatterersCrown" not in set(map(str, found[key].get("relics", []))))
    return found


def settings(protocol: dict[str, Any], cell: str) -> dict[str, Any]:
    fixed = protocol["fixedResearchSettings"].copy()
    fixed.update(protocol["designMatrix"][cell])
    return fixed


def surface_plan(protocol: dict[str, Any], protocol_sha: str) -> dict[str, Any]:
    rows: list[dict[str, Any]] = []
    for subject, relics, seed in (
            ("crown", ["shatterersCrown"], 347000), ("no-crown", [], 347001)):
        rows.append({
            "id": f"crown-surface-{subject}-omitted", "runId": f"surface-{subject}",
            "mode": "crown-surface", "aspect": "duskblade", "seed": seed,
            "deck": ["strike", "strike", "defend", "defend"], "relics": relics,
            "enemies": ["rootheart"],
        })
        for cell in protocol["designMatrix"]:
            rows.append({
                "id": f"crown-surface-{subject}-{cell}", "runId": f"surface-{subject}",
                "mode": "crown-surface", "aspect": "duskblade", "seed": seed,
                "deck": ["strike", "strike", "defend", "defend"], "relics": relics,
                "enemies": ["rootheart"], "research421": settings(protocol, cell),
            })
    return {"schemaVersion": 1, "protocolSha256": protocol_sha,
            "content": str(core.CACHE / f"{protocol['immutableInputs']['baselineContentSha256']}.json"),
            "rows": rows}


def strip_surface(row: dict[str, Any], facet: bool = False,
                  fervor: bool = False) -> str:
    value = copy.deepcopy(row)
    value.pop("id", None)
    value.pop("research421", None)
    if facet:
        value.pop("enemyFacetMax", None)
    if fervor:
        statuses = value["enemyStatuses"].copy()
        statuses.pop("str", None)
        value["enemyStatuses"] = statuses
    return core.canonical(value)


def check_surface(rows: list[dict[str, Any]]) -> dict[str, Any]:
    by_id = {str(row["id"]): row for row in rows}
    require("surface row count", len(rows) == 10 and len(by_id) == len(rows))
    for subject in ("crown", "no-crown"):
        omitted = by_id[f"crown-surface-{subject}-omitted"]
        current = by_id[f"crown-surface-{subject}-current"]
        require(f"{subject} explicit null identity",
                strip_surface(omitted) == strip_surface(current))
    no_crown = [by_id[f"crown-surface-no-crown-{cell}"]
                for cell in ("current", "thresholdOff", "fervorOff", "bothOff")]
    require("no-Crown factor isolation",
            len({strip_surface(row) for row in no_crown}) == 1)
    current = by_id["crown-surface-crown-current"]
    threshold = by_id["crown-surface-crown-thresholdOff"]
    fervor = by_id["crown-surface-crown-fervorOff"]
    both = by_id["crown-surface-crown-bothOff"]
    require("threshold changes exactly one facet",
            int(threshold["enemyFacetMax"]) == int(current["enemyFacetMax"]) + 1)
    require("threshold isolation", strip_surface(current, facet=True) ==
            strip_surface(threshold, facet=True))
    require("Fervor changes exactly one Strength",
            int(current["enemyStatuses"].get("str", 0)) ==
            int(fervor["enemyStatuses"].get("str", 0)) + 1)
    require("Fervor isolation", strip_surface(current, fervor=True) ==
            strip_surface(fervor, fervor=True))
    require("both-off threshold isolation", strip_surface(fervor, facet=True) ==
            strip_surface(both, facet=True))
    require("both-off Fervor isolation", strip_surface(threshold, fervor=True) ==
            strip_surface(both, fervor=True))
    return {
        "status": "PASS", "rows": len(rows),
        "currentFacetMax": current["enemyFacetMax"],
        "offFacetMax": threshold["enemyFacetMax"],
        "currentFervor": current["enemyStatuses"].get("str", 0),
        "offFervor": fervor["enemyStatuses"].get("str", 0),
        "rngIdentity": len({row["rng"] for row in no_crown + [current, threshold, fervor, both]}) == 2,
    }


def invalid_level_checks(protocol: dict[str, Any], protocol_sha: str,
                         deadline: float) -> list[dict[str, Any]]:
    results = []
    for factor in ("shatterersCrownFacetThreshold", "shatterersCrownFervor"):
        bad = settings(protocol, "current")
        bad[factor] = 2
        plan = {
            "schemaVersion": 1, "protocolSha256": protocol_sha,
            "content": str(core.CACHE / f"{protocol['immutableInputs']['baselineContentSha256']}.json"),
            "rows": [{"id": f"invalid-{factor}", "mode": "crown-surface",
                      "aspect": "duskblade", "seed": 347002, "deck": ["strike"],
                      "relics": ["shatterersCrown"], "enemies": ["rootheart"],
                      "research421": bad}],
        }
        _, plan_path = core.cache_json(plan)
        with tempfile.TemporaryDirectory(dir=core.WORK) as tmp:
            out = Path(tmp) / "invalid.json"
            result = subprocess.run(
                [str(GODOT), "--headless", "-s", "res://tools/research_421_probe.gd", "--",
                 f"--plan={plan_path}", f"--out={out}"], cwd=core.SOURCE,
                text=True, capture_output=True, timeout=remaining(deadline),
            )
            diagnostic = result.stdout + result.stderr
            require(f"{factor} invalid level rejected", result.returncode == 2)
            require(f"{factor} invalid level produced no output", not out.exists())
            require(f"{factor} invalid diagnostic", "unregistered level" in diagnostic)
            results.append({"factor": factor, "exitCode": result.returncode,
                            "diagnostic": "unregistered level"})
    return results


def identity_plan(protocol: dict[str, Any], protocol_sha: str) -> dict[str, Any]:
    rows = []
    for case in protocol["identityCases"]:
        base = {
            "mode": "whole-run", "aspect": "duskblade", "vow": 5,
            "seed": case["seed"], "policyRoot": protocol["cohorts"]["policyRoot"],
            "policyIndex": case["policyIndex"], "captureTrace": False,
        }
        rows.append({**base, "id": f"identity-{case['id']}-omitted",
                     "stage": "crown-identity", "arm": "omitted"})
        rows.append({**base, "id": f"identity-{case['id']}-null",
                     "stage": "crown-identity", "arm": "null",
                     "research421": settings(protocol, "current")})
    return {"schemaVersion": 1, "protocolSha256": protocol_sha, "mode": "whole-run",
            "content": str(core.CACHE / f"{protocol['immutableInputs']['baselineContentSha256']}.json"),
            "rows": rows}


def check_identity(rows: list[dict[str, Any]], baseline: dict[tuple[int, int], dict[str, Any]],
                   protocol: dict[str, Any]) -> dict[str, Any]:
    by_id = {str(row["id"]): row for row in rows}
    require("identity row count", len(rows) == 2 * len(protocol["identityCases"]))
    for case in protocol["identityCases"]:
        omitted = by_id[f"identity-{case['id']}-omitted"]
        null = by_id[f"identity-{case['id']}-null"]
        frozen = baseline[(int(case["policyIndex"]), int(case["seed"]))]
        require(f"{case['id']} omitted-null identity",
                canonical_without(omitted) == canonical_without(null))
        require(f"{case['id']} frozen baseline identity",
                canonical_without(omitted) == canonical_without(frozen))
        has_crown = "shatterersCrown" in set(map(str, omitted.get("relics", [])))
        require(f"{case['id']} exposure class", has_crown == case["crownOwned"])
    return {"status": "PASS", "rows": len(rows),
            "cases": len(protocol["identityCases"]), "frozenBaselineExact": True}


def discovery_plan(protocol: dict[str, Any], protocol_sha: str) -> tuple[dict[str, Any], dict[str, Any]]:
    rows = []
    identities = {}
    for cohort, selected in (("active", protocol["cohorts"]["activeRows"]),
                             ("negative", protocol["cohorts"]["negativeControlRows"])):
        for pair in selected:
            for cell in protocol["designMatrix"]:
                row_id = f"crown-crn-{cohort}-{cell}-{pair['policyIndex']}-{pair['seed']}"
                rows.append({
                    "id": row_id, "stage": "crown-effect-crn", "arm": cell,
                    "mode": "whole-run", "aspect": "duskblade", "vow": 5,
                    "seed": pair["seed"], "policyRoot": protocol["cohorts"]["policyRoot"],
                    "policyIndex": pair["policyIndex"], "captureTrace": True,
                    "research421": settings(protocol, cell),
                })
                identities[row_id] = (cohort, int(pair["policyIndex"]),
                                      int(pair["seed"]), cell)
    require("discovery row ceiling",
            len(rows) == protocol["budget"]["discoveryObservationRows"])
    return ({"schemaVersion": 1, "protocolSha256": protocol_sha, "mode": "whole-run",
             "content": str(core.CACHE / f"{protocol['immutableInputs']['baselineContentSha256']}.json"),
             "rows": rows}, identities)


def metric(row: dict[str, Any], endpoint: str) -> float:
    if endpoint == "shatters":
        return float(sum(int(fight.get("shatters", 0)) for fight in row.get("fights", [])))
    if endpoint == "duration":
        fights = row.get("fights", [])
        require("duration has fights", bool(fights))
        return statistics.fmean(float(fight["turns"]) for fight in fights)
    if endpoint == "win":
        return float(row.get("outcome") == "win")
    if endpoint == "fault":
        return float(row.get("outcome") in ("stall", "error") or bool(row.get("error")))
    if endpoint == "hp":
        return float(row.get("hp", 0))
    raise KeyError(endpoint)


def acquisition_prefix(row: dict[str, Any]) -> list[dict[str, Any]]:
    choices = row["trajectory"]["bossRelics"]
    for index, choice in enumerate(choices):
        if choice.get("chosen") == "shatterersCrown":
            return choices[:index + 1]
    return []


def analyse(rows: list[dict[str, Any]], identities: dict[str, Any],
            baseline: dict[tuple[int, int], dict[str, Any]],
            protocol: dict[str, Any]) -> dict[str, Any]:
    indexed: dict[tuple[str, int, int, str], dict[str, Any]] = {}
    for row in rows:
        require("known discovery row", row["id"] in identities)
        indexed[identities[row["id"]]] = row
    require("complete discovery rectangle", len(indexed) == len(identities) == len(rows))
    cells = list(protocol["designMatrix"])
    negative_exact = True
    current_baseline_exact = True
    acquisition_exact = True
    policy_exact = True
    for cohort, selected in (("active", protocol["cohorts"]["activeRows"]),
                             ("negative", protocol["cohorts"]["negativeControlRows"])):
        for pair in selected:
            key = (int(pair["policyIndex"]), int(pair["seed"]))
            block = {cell: indexed[(cohort, key[0], key[1], cell)] for cell in cells}
            current = block["current"]
            without_trace = copy.deepcopy(current)
            without_trace.pop("trajectory", None)
            current_baseline_exact = current_baseline_exact and (
                canonical_without(without_trace) == canonical_without(baseline[key]))
            policy_exact = policy_exact and len({core.canonical(row["policy"])
                                                  for row in block.values()}) == 1
            if cohort == "negative":
                negative_exact = negative_exact and len(
                    {canonical_without(row) for row in block.values()}) == 1
            else:
                prefixes = [acquisition_prefix(row) for row in block.values()]
                acquisition_exact = acquisition_exact and bool(prefixes[0]) and len(
                    {core.canonical(prefix) for prefix in prefixes}) == 1
                acquisition_exact = acquisition_exact and all(
                    "shatterersCrown" in set(map(str, row.get("relics", [])))
                    for row in block.values())
    require("current frozen path and result", current_baseline_exact)
    require("policy identity", policy_exact)
    require("no-Crown exact negative controls", negative_exact)
    require("Crown acquisition prefix identity", acquisition_exact)

    coefficients = protocol["contrasts"]
    endpoints = ("shatters", "duration", "win", "fault", "hp")
    effects: dict[str, Any] = {}
    active = protocol["cohorts"]["activeRows"]
    for contrast_index, (name, weights) in enumerate(coefficients.items()):
        policy_values: dict[int, dict[str, list[float]]] = {}
        for pair in active:
            policy = int(pair["policyIndex"])
            seed = int(pair["seed"])
            for endpoint in endpoints:
                value = sum(float(weight) * metric(indexed[("active", policy, seed, cell)], endpoint)
                            for cell, weight in weights.items())
                policy_values.setdefault(policy, {}).setdefault(endpoint, []).append(value)
        result: dict[str, Any] = {}
        for endpoint_index, endpoint in enumerate(endpoints):
            clustered = [statistics.fmean(values[endpoint])
                         for _, values in sorted(policy_values.items())]
            result[endpoint] = core.interval(
                clustered, 1.0,
                int(protocol["estimators"]["bootstrapSeed"]) + 10 * contrast_index + endpoint_index,
            )
            result[endpoint]["policyValues"] = clustered
        effects[name] = result
    return {
        "identity": {"currentFrozenBaselineExact": current_baseline_exact,
                     "policyExact": policy_exact, "negativeControlExact": negative_exact,
                     "acquisitionPrefixExact": acquisition_exact},
        "effects": effects,
        "activeRows": len(active),
        "activePolicies": len({int(row["policyIndex"]) for row in active}),
        "negativeControlRows": len(protocol["cohorts"]["negativeControlRows"]),
    }


def candidate_result(name: str, cell: str, total_contrast: str, mechanism_contrast: str,
                     indexed_rows: list[dict[str, Any]], analysis: dict[str, Any],
                     protocol: dict[str, Any]) -> dict[str, Any]:
    gates = protocol["gates"]
    total = analysis["effects"][total_contrast]
    mechanism = analysis["effects"][mechanism_contrast]
    selected = [row for row in indexed_rows if row.get("arm") == cell
                and row["id"].startswith("crown-crn-active-")]

    def witness(effect: dict[str, Any], relation: Callable[[float], bool]) -> int:
        return sum(relation(float(value)) for value in effect["shatters"]["policyValues"])

    positive = witness(total, lambda value: value > 0)
    inactive = witness(total, lambda value: value == 0)
    mechanism_positive = witness(mechanism, lambda value: value > 0)
    mechanism_inactive = witness(mechanism, lambda value: value == 0)
    viable = len({int(row["policyIndex"]) for row in selected
                  if row.get("outcome") == "win" and metric(row, "shatters") > 0})
    faults = sum(metric(row, "fault") > 0 for row in selected)
    win_rate = statistics.fmean(metric(row, "win") for row in selected)
    checks = {
        "totalEffect": total["shatters"]["p025"] > 0,
        "mechanismEffect": mechanism["shatters"]["p025"] > 0,
        "positivePolicyWitnesses": positive >= gates["minimumPositivePolicyWitnesses"],
        "inactivePolicyWitnesses": inactive >= gates["minimumInactivePolicyWitnesses"],
        "mechanismPositiveWitnesses": mechanism_positive >=
            gates["minimumPositivePolicyWitnesses"],
        "mechanismInactiveWitnesses": mechanism_inactive >=
            gates["minimumInactivePolicyWitnesses"],
        "viablePolicies": viable >= gates["minimumViablePolicies"],
        "reliability": faults == 0,
        "vow5": win_rate <= gates["maximumVow5WinRate"],
        "duration": total["duration"]["p975"] <= gates["durationUpperBound"],
    }
    fixed_failure = (
        total["shatters"]["point"] <= 0 or total["shatters"]["p975"] <= 0
        or mechanism["shatters"]["point"] <= 0 or mechanism["shatters"]["p975"] <= 0
        or not checks["positivePolicyWitnesses"] or not checks["inactivePolicyWitnesses"]
        or not checks["mechanismPositiveWitnesses"] or not checks["mechanismInactiveWitnesses"]
        or not checks["viablePolicies"] or not checks["reliability"] or not checks["vow5"]
        or total["duration"]["p025"] > gates["durationUpperBound"]
    )
    status = "pass" if all(checks.values()) else ("fail" if fixed_failure else "inconclusive")
    return {
        "name": name, "cell": cell, "totalContrast": total_contrast,
        "mechanismContrast": mechanism_contrast, "status": status,
        "checks": checks, "positivePolicyWitnesses": positive,
        "inactivePolicyWitnesses": inactive,
        "mechanismPositiveWitnesses": mechanism_positive,
        "mechanismInactiveWitnesses": mechanism_inactive,
        "viablePolicies": viable, "faults": faults, "vow5WinRate": win_rate,
    }


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the Crown CRN summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    deadline = started + float(protocol["budget"]["maximumWallTimeSeconds"])
    old_path = os.environ.get("PATH", "")
    os.environ["PATH"] = f"{GODOT.parent}:{old_path}"
    actual_source = source_identity()
    for key, expected in protocol["immutableInputs"].items():
        require(f"immutable {key}", actual_source.get(key) == expected)
    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    baseline = baseline_rows(protocol)
    db = core.open_ledger()
    try:
        surface_output, surface_manifest = run_plan(
            db, protocol_sha, surface_plan(protocol, protocol_sha), deadline)
        surface = check_surface(surface_output["rows"])
        invalid = invalid_level_checks(protocol, protocol_sha, deadline)
        identity_output, identity_manifest = run_plan(
            db, protocol_sha, identity_plan(protocol, protocol_sha), deadline)
        whole_identity = check_identity(identity_output["rows"], baseline, protocol)
        discovery_spec, identities = discovery_plan(protocol, protocol_sha)
        discovery_output, discovery_manifest = run_plan(
            db, protocol_sha, discovery_spec, deadline)
        analysis = analyse(discovery_output["rows"], identities, baseline, protocol)
        current = candidate_result(
            "shipping-shatterers-crown", "current", "authoredTotal", "thresholdAtFervor",
            discovery_output["rows"], analysis, protocol)
        threshold_only = candidate_result(
            "threshold-only-shatterers-crown", "fervorOff", "thresholdOnlyTotal",
            "thresholdWithoutFervor", discovery_output["rows"], analysis, protocol)
        selected = current if current["status"] == "pass" else (
            threshold_only if threshold_only["status"] == "pass" else None)
        if selected is not None:
            boundary, decision = 1, f"freeze-{selected['name']}-for-heldout"
        elif current["status"] == threshold_only["status"] == "fail":
            boundary, decision = 2, "close-shatterers-crown-effect-family"
        else:
            boundary, decision = 3, "inconclusive-at-preregistered-cap"
        observation_rows = (surface_manifest["rows"] + identity_manifest["rows"]
                            + discovery_manifest["rows"])
        require("total observation row cap",
                observation_rows == protocol["budget"]["maximumNewSimulatorObservationRows"])
        elapsed = time.monotonic() - started
        require("wall-time ceiling", elapsed <= protocol["budget"]["maximumWallTimeSeconds"])
        ledger_after = identity.ledger_identity()
        require("protected seeds remain absent", ledger_after["protectedSeedRows"] == 0)
        summary = {
            "schemaVersion": 1, "issue": 421, "decisionBoundary": boundary,
            "decision": decision, "selectedCandidate": selected,
            "candidateAssessments": [current, threshold_only],
            "protocolSha256": protocol_sha, "sourceIdentity": actual_source,
            "preflight": {"surface": surface, "invalidLevels": invalid,
                          "wholeRunIdentity": whole_identity},
            "design": analysis,
            "execution": {"surface": surface_manifest, "identity": identity_manifest,
                          "discovery": discovery_manifest,
                          "newSimulatorObservationRows": observation_rows,
                          "maximumModelContextTokens": 0, "wallTimeSeconds": elapsed},
            "ledgerBefore": ledger_before, "ledgerAfter": ledger_after,
            "newLedgerRows": ledger_after["records"] - ledger_before["records"],
            "protectedSeedRows": ledger_after["protectedSeedRows"],
            "authority": protocol["decisionRules"][
                "successAuthority" if boundary == 1 else (
                    "futilityAuthority" if boundary == 2 else "inconclusiveAuthority")],
        }
        SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
        print(core.canonical({"status": "PASS", "decision": decision,
                              "decisionBoundary": boundary,
                              "summarySha256": core.file_sha(SUMMARY),
                              "newSimulatorObservationRows": observation_rows}))
    finally:
        db.close()
        os.environ["PATH"] = old_path


if __name__ == "__main__":
    main()
