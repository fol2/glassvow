#!/usr/bin/env python3
"""Preregistered exact-repeat capacity test for one identity-safe policy remap."""

from __future__ import annotations

import copy
import json
import os
import subprocess
import tempfile
import time
from collections import Counter
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-momentum-preference-capacity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-momentum-preference-capacity-v1.json"
GODOT = core.ROOT / "toolchains/godot-4.7.1/godot"
META = ("id", "stage", "arm")


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Momentum preference capacity mismatch: {label}")


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
        raise TimeoutError("Momentum preference capacity exceeded its wall-time ceiling")
    return seconds


def run_plan(db: Any, protocol_sha: str, plan: dict[str, Any],
             deadline: float) -> tuple[dict[str, Any], dict[str, Any]]:
    output = core.run_plan(db, protocol_sha, plan, timeout=remaining(deadline))
    plan_sha, _ = core.cache_json(plan)
    output_sha, _ = core.cache_json(output)
    return output, {
        "planSha256": plan_sha,
        "outputSha256": output_sha,
        "rows": len(output["rows"]),
    }


def settings(protocol: dict[str, Any], arm: str) -> dict[str, Any]:
    resolved = protocol["fixedResearchSettings"].copy()
    resolved.update(protocol["designMatrix"][arm])
    return resolved


def baseline_rows(protocol: dict[str, Any]) -> dict[tuple[int, int], dict[str, Any]]:
    baseline = protocol["baseline"]
    output_path = core.CACHE / f"{baseline['outputSha256']}.json"
    require("baseline output SHA", core.file_sha(output_path) == baseline["outputSha256"])
    output = json.loads(output_path.read_text())
    require("baseline plan SHA", output["planSha256"] == baseline["planSha256"])
    require("baseline content SHA",
            output["contentIdentity"]["contentFileSha256"] == baseline["contentSha256"])
    cohort = protocol["cohort"]
    rows = [row for row in output["rows"]
            if row.get("arm") == "policy" and row.get("aspect") == cohort["aspect"]
            and int(row.get("vow", -1)) == cohort["vow"]]
    expected = cohort["policyCount"] * len(cohort["simulationSeeds"])
    require("baseline rectangle size", len(rows) == expected)
    found = {(int(row["policyIndex"]), int(row["seed"])): row for row in rows}
    require("baseline unique identities", len(found) == len(rows))
    require("baseline policy indices",
            {key[0] for key in found} == set(range(cohort["policyCount"])))
    require("baseline simulation seeds",
            {key[1] for key in found} == set(cohort["simulationSeeds"]))
    return found


def surface_plan(protocol: dict[str, Any], protocol_sha: str) -> dict[str, Any]:
    case = protocol["surfaceCase"]
    base = {
        "mode": "momentum-preference-surface",
        "aspect": "duskblade",
        "seed": case["seed"],
        "policyRoot": protocol["cohort"]["policyRoot"],
        "policyIndex": case["policyIndex"],
    }
    return {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "content": str(core.CACHE / f"{protocol['baseline']['contentSha256']}.json"),
        "rows": [
            {**base, "id": "momentum-surface-omitted"},
            {**base, "id": "momentum-surface-current",
             "research421": settings(protocol, "current")},
            {**base, "id": "momentum-surface-remap",
             "research421": settings(protocol, "remap")},
        ],
    }


def strip_surface(row: dict[str, Any], intended: bool = False) -> str:
    value = copy.deepcopy(row)
    value.pop("id", None)
    if intended:
        value.pop("research421", None)
        value.pop("momentumPreference", None)
        value["duskCardScores"].pop("momentum", None)
    return core.canonical(value)


def check_surface(rows: list[dict[str, Any]], protocol: dict[str, Any]) -> dict[str, Any]:
    by_id = {str(row["id"]): row for row in rows}
    require("surface row count", len(rows) == 3 and len(by_id) == len(rows))
    omitted = by_id["momentum-surface-omitted"]
    current = by_id["momentum-surface-current"]
    remap = by_id["momentum-surface-remap"]
    require("omitted-null surface identity", strip_surface(omitted) == strip_surface(current))
    require("policy identity", len({core.canonical(row["policy"])
                                    for row in (omitted, current, remap)}) == 1)
    require("enabled factor isolation", strip_surface(current, True) ==
            strip_surface(remap, True))
    require("Ash score identity", current["ashCardScores"] == remap["ashCardScores"])
    require("execute preference identity",
            current["executePreference"] == remap["executePreference"])
    policy_special = current["policy"]["special"]
    require("current Momentum alias",
            current["momentumPreference"] == policy_special["execute"])
    require("remapped Momentum preference",
            remap["momentumPreference"] == policy_special["shatterEchoDusk"])
    require("surface preference is non-degenerate",
            current["momentumPreference"] != remap["momentumPreference"])
    score_delta = (float(remap["duskCardScores"]["momentum"])
                   - float(current["duskCardScores"]["momentum"]))
    preference_delta = (float(remap["momentumPreference"])
                        - float(current["momentumPreference"]))
    require("only intended Momentum score delta", abs(score_delta - preference_delta) < 1e-9)
    require("registered remap snapshot",
            remap["research421"] == settings(protocol, "remap"))
    return {
        "status": "PASS",
        "rows": len(rows),
        "policyIndex": protocol["surfaceCase"]["policyIndex"],
        "currentPreference": current["momentumPreference"],
        "remapPreference": remap["momentumPreference"],
        "changedDuskCardScores": ["momentum"],
        "ashCardScoresExact": True,
        "policyExact": True,
    }


def invalid_level_check(protocol: dict[str, Any], protocol_sha: str,
                        deadline: float) -> dict[str, Any]:
    bad = settings(protocol, "current")
    bad["momentumPolicyPreference"] = 2
    case = protocol["surfaceCase"]
    plan = {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "content": str(core.CACHE / f"{protocol['baseline']['contentSha256']}.json"),
        "rows": [{
            "id": "invalid-momentum-policy-preference",
            "mode": "momentum-preference-surface",
            "aspect": "duskblade",
            "seed": case["seed"],
            "policyRoot": protocol["cohort"]["policyRoot"],
            "policyIndex": case["policyIndex"],
            "research421": bad,
        }],
    }
    _, plan_path = core.cache_json(plan)
    with tempfile.TemporaryDirectory(dir=core.WORK) as tmp:
        out = Path(tmp) / "invalid.json"
        result = subprocess.run(
            [str(GODOT), "--headless", "-s", "res://tools/research_421_probe.gd", "--",
             f"--plan={plan_path}", f"--out={out}"],
            cwd=core.SOURCE, text=True, capture_output=True, timeout=remaining(deadline),
        )
        diagnostic = result.stdout + result.stderr
        require("invalid level rejected", result.returncode == 2)
        require("invalid level produced no output", not out.exists())
        require("invalid level diagnostic", "unregistered level" in diagnostic)
    return {"factor": "momentumPolicyPreference", "level": 2,
            "exitCode": result.returncode, "diagnostic": "unregistered level"}


def telemetry_plan(protocol: dict[str, Any], protocol_sha: str) \
        -> tuple[dict[str, Any], dict[str, tuple[str, int, int]]]:
    rows: list[dict[str, Any]] = []
    identities: dict[str, tuple[str, int, int]] = {}
    cohort = protocol["cohort"]
    for policy_index in range(cohort["policyCount"]):
        for seed in cohort["simulationSeeds"]:
            for arm in protocol["designMatrix"]:
                row_id = f"momentum-telemetry-{arm}-p{policy_index}-s{seed}"
                rows.append({
                    "id": row_id,
                    "stage": "momentum-preference-capacity",
                    "arm": arm,
                    "mode": "whole-run",
                    "aspect": cohort["aspect"],
                    "vow": cohort["vow"],
                    "seed": seed,
                    "policyRoot": cohort["policyRoot"],
                    "policyIndex": policy_index,
                    "captureTrace": True,
                    "research421": settings(protocol, arm),
                })
                identities[row_id] = (arm, policy_index, seed)
    return ({
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "mode": "whole-run",
        "content": str(core.CACHE / f"{protocol['baseline']['contentSha256']}.json"),
        "rows": rows,
    }, identities)


def exact_repeat(row: dict[str, Any]) -> bool:
    counts = Counter(
        (int(play["fight"]), int(play["uid"]))
        for play in row["trajectory"]["plays"] if play["id"] == "momentum"
    )
    return any(count >= 2 for count in counts.values())


def exact_scoreline_route(row: dict[str, Any]) -> bool:
    by_fight: dict[int, list[dict[str, Any]]] = {}
    for play in row["trajectory"]["plays"]:
        by_fight.setdefault(int(play["fight"]), []).append(play)
    for plays in by_fight.values():
        ordered = sorted(plays, key=lambda play: int(play["event"]))
        first_chisel = next((int(play["event"]) for play in ordered
                             if play["id"] == "chisel"), None)
        if first_chisel is not None and any(
                play["id"] == "executioner" and int(play["event"]) > first_chisel
                for play in ordered):
            return True
    return False


def policy_set(rows: dict[tuple[str, int, int], dict[str, Any]], arm: str,
               protocol: dict[str, Any], predicate: Any) -> set[int]:
    robust = protocol["cohort"]["minimumRowsPerRobustPolicy"]
    seeds = protocol["cohort"]["simulationSeeds"]
    return {
        policy_index for policy_index in range(protocol["cohort"]["policyCount"])
        if sum(predicate(rows[(arm, policy_index, seed)]) for seed in seeds) >= robust
    }


def analyse(output_rows: list[dict[str, Any]], identities: dict[str, tuple[str, int, int]],
            baseline: dict[tuple[int, int], dict[str, Any]],
            protocol: dict[str, Any]) -> dict[str, Any]:
    indexed: dict[tuple[str, int, int], dict[str, Any]] = {}
    for row in output_rows:
        require("known telemetry row", row["id"] in identities)
        indexed[identities[row["id"]]] = row
    require("complete telemetry rectangle",
            len(indexed) == len(identities) == len(output_rows))
    current_faults: set[tuple[int, int]] = set()
    remap_faults: set[tuple[int, int]] = set()
    for policy_index in range(protocol["cohort"]["policyCount"]):
        for seed in protocol["cohort"]["simulationSeeds"]:
            current = indexed[("current", policy_index, seed)]
            remap = indexed[("remap", policy_index, seed)]
            without_trace = copy.deepcopy(current)
            without_trace.pop("trajectory", None)
            require("current frozen path, RNG and result",
                    canonical_without(without_trace) ==
                    canonical_without(baseline[(policy_index, seed)]))
            require("CRN policy identity", current["policy"] == remap["policy"])
            for arm_row in (current, remap):
                for play in arm_row["trajectory"]["plays"]:
                    require("complete play telemetry",
                            set(play) == {"fight", "event", "id", "uid"}
                            and int(play["fight"]) >= 0 and int(play["event"]) >= 0
                            and int(play["uid"]) >= 0)
            if current.get("outcome") in ("stall", "error") or current.get("error"):
                current_faults.add((policy_index, seed))
            if remap.get("outcome") in ("stall", "error") or remap.get("error"):
                remap_faults.add((policy_index, seed))

    active = {arm: policy_set(indexed, arm, protocol, exact_repeat)
              for arm in protocol["designMatrix"]}
    scoreline = {arm: policy_set(indexed, arm, protocol, exact_scoreline_route)
                 for arm in protocol["designMatrix"]}
    inactive = {
        arm: {policy_index for policy_index in range(protocol["cohort"]["policyCount"])
              if not any(exact_repeat(indexed[(arm, policy_index, seed)])
                         for seed in protocol["cohort"]["simulationSeeds"])}
        for arm in protocol["designMatrix"]
    }
    offered = {
        arm: {policy_index for policy_index in range(protocol["cohort"]["policyCount"])
              if any(int(indexed[(arm, policy_index, seed)]
                         ["packageEvents"].get("momentumOffered", 0)) > 0
                     for seed in protocol["cohort"]["simulationSeeds"])}
        for arm in protocol["designMatrix"]
    }
    acquired = {
        arm: {policy_index for policy_index in range(protocol["cohort"]["policyCount"])
              if any("momentum" in set(map(str, indexed[(arm, policy_index, seed)]
                                           .get("deckIds", [])))
                     for seed in protocol["cohort"]["simulationSeeds"])}
        for arm in protocol["designMatrix"]
    }
    honing_only = {arm: active[arm] - scoreline[arm] for arm in protocol["designMatrix"]}
    novel_separated = ((active["remap"] - active["current"])
                       - scoreline["current"] - scoreline["remap"])
    prior = json.loads((core.ROOT / protocol["priorEvidence"]["honingCapacity"]["path"])
                       .read_text())
    require("current exact repeats respect prior upper capacity",
            active["current"] <= set(prior["potentialActivePolicies"]))

    def jaccard(left: set[int], right: set[int]) -> float:
        return len(left & right) / len(left | right) if left | right else 1.0

    return {
        "identity": {
            "currentFrozenBaselineExact": True,
            "policyIdentityExactWithinEveryCRNBlock": True,
            "playTelemetryComplete": True,
        },
        "sets": {
            arm: {
                "exactRepeatActive": sorted(active[arm]),
                "exactRepeatInactive": sorted(inactive[arm]),
                "scorelineRouteActive": sorted(scoreline[arm]),
                "honingOnly": sorted(honing_only[arm]),
                "offered": sorted(offered[arm]),
                "acquired": sorted(acquired[arm]),
            } for arm in protocol["designMatrix"]
        },
        "novelSeparatedPolicies": sorted(novel_separated),
        "counts": {
            arm: {
                "exactRepeatActive": len(active[arm]),
                "exactRepeatInactive": len(inactive[arm]),
                "scorelineRouteActive": len(scoreline[arm]),
                "honingOnly": len(honing_only[arm]),
                "offered": len(offered[arm]),
                "acquired": len(acquired[arm]),
                "scorelineJaccard": jaccard(active[arm], scoreline[arm]),
            } for arm in protocol["designMatrix"]
        },
        "decisionValue": {
            "novelSeparatedPolicies": len(novel_separated),
            "honingOnlyDifference": len(honing_only["remap"]) - len(honing_only["current"]),
            "lostScorelinePolicies": sorted(scoreline["current"] - scoreline["remap"]),
            "gainedScorelinePolicies": sorted(scoreline["remap"] - scoreline["current"]),
        },
        "faults": {
            "current": sorted([list(key) for key in current_faults]),
            "remap": sorted([list(key) for key in remap_faults]),
            "addedByRemap": sorted([list(key) for key in remap_faults - current_faults]),
            "remapAddsNoFaultIdentity": remap_faults <= current_faults,
        },
    }


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the Momentum preference capacity summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    deadline = started + float(protocol["budget"]["maximumWallTimeSeconds"])
    old_path = os.environ.get("PATH", "")
    os.environ["PATH"] = f"{GODOT.parent}:{old_path}"
    actual_source = source_identity()
    for key, expected in protocol["immutableInputs"].items():
        require(f"immutable {key}", actual_source.get(key) == expected)
    for name, spec in protocol["priorEvidence"].items():
        path = core.ROOT / spec["path"]
        require(f"{name} SHA", core.file_sha(path) == spec["sha256"])
        require(f"{name} decision", json.loads(path.read_text())["decision"] == spec["decision"])
    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    baseline = baseline_rows(protocol)
    db = core.open_ledger()
    try:
        surface_output, surface_manifest = run_plan(
            db, protocol_sha, surface_plan(protocol, protocol_sha), deadline)
        surface = check_surface(surface_output["rows"], protocol)
        invalid = invalid_level_check(protocol, protocol_sha, deadline)
        telemetry_spec, identities = telemetry_plan(protocol, protocol_sha)
        telemetry_output, telemetry_manifest = run_plan(
            db, protocol_sha, telemetry_spec, deadline)
        analysis = analyse(telemetry_output["rows"], identities, baseline, protocol)
        gates = protocol["gates"]
        remap = analysis["counts"]["remap"]
        gate_results = {
            "identity": all(analysis["identity"].values()),
            "exactRepeatActive": remap["exactRepeatActive"] >=
            gates["minimumExactRepeatActivePolicies"],
            "exactRepeatInactive": remap["exactRepeatInactive"] >=
            gates["minimumExactRepeatInactivePolicies"],
            "naturalReachability": remap["offered"] >= gates["minimumOfferedPolicies"]
            and remap["acquired"] >= gates["minimumAcquiredPolicies"],
            "scorelineSeparation": remap["honingOnly"] >= gates["minimumHoningOnlyPolicies"]
            and remap["scorelineJaccard"] <= gates["maximumScorelineJaccard"],
            "independentDecisionValue":
            analysis["decisionValue"]["novelSeparatedPolicies"] >=
            gates["minimumNovelSeparatedPolicies"],
            "scorelineAnchor": remap["scorelineRouteActive"] >=
            gates["minimumScorelineRoutePolicies"],
            "reliability": len(analysis["faults"]["addedByRemap"]) <=
            gates["maximumAddedFaultIdentities"],
        }
        elapsed = time.monotonic() - started
        observation_rows = surface_manifest["rows"] + telemetry_manifest["rows"]
        require("observation row cap",
                observation_rows == protocol["budget"]["maximumNewSimulatorObservationRows"])
        if elapsed > float(protocol["budget"]["maximumWallTimeSeconds"]):
            boundary, decision = 3, "record-momentum-preference-capacity-inconclusive-at-cap"
        elif all(gate_results.values()):
            boundary, decision = 1, "authorise-honing-repeat-payoff-identity-preflight"
        else:
            boundary, decision = 2, "close-momentum-remap-and-honing-repeat-family"
        ledger_after = identity.ledger_identity()
        new_ledger_rows = ledger_after["records"] - ledger_before["records"]
        require("ledger row cap",
                new_ledger_rows == protocol["budget"]["maximumNewLedgerRows"])
        require("protected seeds remain absent", ledger_after["protectedSeedRows"] == 0)
        summary = {
            "schemaVersion": 1,
            "issue": 421,
            "decisionBoundary": boundary,
            "decision": decision,
            "protocolSha256": protocol_sha,
            "sourceIdentity": actual_source,
            "preflight": {"surface": surface, "invalidLevel": invalid},
            "analysis": analysis,
            "gateResults": gate_results,
            "execution": {
                "surface": surface_manifest,
                "telemetry": telemetry_manifest,
                "newSimulatorObservationRows": observation_rows,
                "maximumModelContextTokens": 0,
                "wallTimeSeconds": elapsed,
            },
            "ledgerBefore": ledger_before,
            "ledgerAfter": ledger_after,
            "newLedgerRows": new_ledger_rows,
            "protectedSeedRows": ledger_after["protectedSeedRows"],
            "authority": protocol["decisionRules"][
                "successAuthority" if boundary == 1 else (
                    "futilityAuthority" if boundary == 2 else "inconclusiveAuthority")],
        }
        SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
        print(core.canonical({
            "status": "PASS",
            "decision": decision,
            "decisionBoundary": boundary,
            "summarySha256": core.file_sha(SUMMARY),
            "newSimulatorObservationRows": observation_rows,
        }))
    finally:
        db.close()
        os.environ["PATH"] = old_path


if __name__ == "__main__":
    main()
