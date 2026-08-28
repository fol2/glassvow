#!/usr/bin/env python3
"""Zero-ledger identity and mediator preflight for the Mirror Oath research knobs."""

from __future__ import annotations

import copy
import json
import sqlite3
import subprocess
import tempfile
import time
from pathlib import Path
from typing import Any

import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-mirror-oath-identity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-mirror-oath-identity-v1.json"
GODOT = core.ROOT / "toolchains/godot-4.7.1/godot"
META = ("id", "stage", "arm")


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Mirror Oath identity mismatch: {label}")


def ledger_identity() -> dict[str, Any]:
    with sqlite3.connect(f"file:{core.LEDGER}?mode=ro", uri=True) as db:
        records, first, last = db.execute(
            "SELECT COUNT(*), MIN(seq), MAX(seq) FROM records"
        ).fetchone()
        protected = db.execute(
            "SELECT COUNT(*) FROM records WHERE kind = 'observation' "
            "AND CAST(json_extract(payload_json, '$.seed') AS INTEGER) "
            "BETWEEN 3000 AND 5399"
        ).fetchone()[0]
        integrity = db.execute("PRAGMA integrity_check").fetchone()[0]
    return {
        "sha256": core.file_sha(core.LEDGER),
        "records": records,
        "firstSequence": first,
        "lastSequence": last,
        "protectedSeedRows": protected,
        "sqliteIntegrity": integrity,
    }


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
        "contentSha256": core.file_sha(core.SOURCE / "content/full-content.json"),
        "combatRulesSha256": core.file_sha(core.SOURCE / "domain/rules/combat.gd"),
        "rewardRulesSha256": core.file_sha(core.SOURCE / "domain/rules/rewards.gd"),
        "runStateSha256": core.file_sha(core.SOURCE / "domain/state/run_state.gd"),
        "pilotSha256": core.file_sha(core.SOURCE / "tools/balance_pilot.gd"),
        "policySha256": core.file_sha(core.SOURCE / "tools/balance_policy.gd"),
        "balanceSimSha256": core.file_sha(core.SOURCE / "tools/balance_sim.gd"),
        "probeSha256": core.file_sha(core.SOURCE / "tools/research_421_probe.gd"),
        "researchCoreSha256": core.file_sha(core.ROOT / "research.py"),
        "runnerSha256": core.file_sha(Path(__file__)),
    }


def verify_inputs(protocol: dict[str, Any]) -> tuple[dict[str, Any], dict[str, Any]]:
    source = source_identity()
    ledger = ledger_identity()
    for key, expected in protocol["immutableInputs"].items():
        require(f"immutable {key}", source.get(key) == expected)
    for key, expected in protocol["ledgerFreeze"].items():
        require(f"ledger {key}", ledger.get(key) == expected)
    content_path = core.CACHE / f"{source['contentSha256']}.json"
    require("candidate content cache", content_path.is_file()
            and core.file_sha(content_path) == source["contentSha256"])
    return source, ledger


def remaining(deadline: float) -> int:
    seconds = int(deadline - time.monotonic())
    if seconds < 1:
        raise TimeoutError("Mirror Oath preflight exceeded its wall-time ceiling")
    return seconds


def run_probe(plan: dict[str, Any], deadline: float) -> tuple[dict[str, Any], str, str]:
    plan_sha, plan_path = core.cache_json(plan)
    core.WORK.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=core.WORK, prefix="mirror-oath-identity-") as tmp:
        out = Path(tmp) / "output.json"
        result = subprocess.run(
            [str(GODOT), "--headless", "-s", "res://tools/research_421_probe.gd", "--",
             f"--plan={plan_path}", f"--out={out}"],
            cwd=core.SOURCE, text=True, capture_output=True, timeout=remaining(deadline),
        )
        if result.returncode or not out.is_file():
            raise RuntimeError(
                f"probe failed ({result.returncode})\n"
                f"{result.stdout[-2000:]}\n{result.stderr[-4000:]}"
            )
        output = json.loads(out.read_text())
    output_sha, _ = core.cache_json(output)
    return output, plan_sha, output_sha


def fixed_settings(protocol: dict[str, Any], arm: str) -> dict[str, Any]:
    values = copy.deepcopy(protocol["fixedResearchSettings"])
    values.update(protocol["designMatrix"][arm])
    return values


def frozen_rows(protocol: dict[str, Any]) -> dict[tuple[int, int], dict[str, Any]]:
    evidence = protocol["frozenPath"]
    path = core.CACHE / f"{evidence['outputSha256']}.json"
    require("frozen output object", path.is_file()
            and core.file_sha(path) == evidence["outputSha256"])
    output = json.loads(path.read_text())
    require("frozen plan identity", output["planSha256"] == evidence["planSha256"])
    cohort = protocol["cohort"]
    rows = [row for row in output["rows"]
            if row.get("arm") == "current"
            and row.get("aspect") == cohort["aspect"]
            and int(row.get("vow", -1)) == cohort["vow"]]
    expected = cohort["policyCount"] * len(cohort["simulationSeeds"])
    require("frozen rectangle size", len(rows) == expected)
    found = {(int(row["policyIndex"]), int(row["seed"])): row for row in rows}
    require("frozen rectangle identities", len(found) == expected)
    return found


def without(value: dict[str, Any], *keys: str) -> dict[str, Any]:
    result = copy.deepcopy(value)
    for key in keys:
        result.pop(key, None)
    return result


def normalised_whole(row: dict[str, Any]) -> str:
    return core.canonical(without(row, *META))


def whole_plan(protocol: dict[str, Any], protocol_sha: str) -> dict[str, Any]:
    cohort = protocol["cohort"]
    rows: list[dict[str, Any]] = []
    for policy_index in range(cohort["policyCount"]):
        for seed in cohort["simulationSeeds"]:
            for arm in protocol["designMatrix"]:
                rows.append({
                    "id": f"mirror-oath-null-{arm}-p{policy_index}-s{seed}",
                    "stage": "post-v38-mirror-oath-identity",
                    "arm": arm,
                    "mode": "whole-run",
                    "aspect": cohort["aspect"],
                    "vow": cohort["vow"],
                    "seed": seed,
                    "policyRoot": cohort["policyRoot"],
                    "policyIndex": policy_index,
                    "captureTrace": True,
                    "research421": fixed_settings(protocol, arm),
                })
    require("whole-run replay ceiling",
            len(rows) == protocol["budget"]["wholeRunReplayExecutions"])
    return {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "content": str(core.CACHE / f"{protocol['immutableInputs']['contentSha256']}.json"),
        "rows": rows,
    }


def analyse_whole(rows: list[dict[str, Any]], protocol: dict[str, Any],
                  frozen: dict[tuple[int, int], dict[str, Any]]) -> dict[str, Any]:
    indexed: dict[tuple[str, int, int], dict[str, Any]] = {}
    for row in rows:
        key = (str(row["arm"]), int(row["policyIndex"]), int(row["seed"]))
        require("unique whole-run replay", key not in indexed)
        indexed[key] = row
    require("complete whole-run replay", len(indexed) == len(rows))
    arm_digests: dict[str, str] = {}
    for arm in protocol["designMatrix"]:
        canonical_rows: list[str] = []
        for policy_index in range(protocol["cohort"]["policyCount"]):
            for seed in protocol["cohort"]["simulationSeeds"]:
                observed = indexed[(arm, policy_index, seed)]
                expected = frozen[(policy_index, seed)]
                require(f"{arm} frozen path p{policy_index} s{seed}",
                        normalised_whole(observed) == normalised_whole(expected))
                canonical_rows.append(normalised_whole(observed))
        arm_digests[arm] = core.sha("\n".join(canonical_rows).encode())
    require("all null-arm digests exact", len(set(arm_digests.values())) == 1)
    return {
        "status": "PASS",
        "rowsPerNullEncoding": len(frozen),
        "frozenRows": len(frozen),
        "canonicalDigestByNullEncoding": arm_digests,
        "completePathPolicyTrajectoryRngAndResultExact": True,
    }


def surface_plan(protocol: dict[str, Any], protocol_sha: str) -> dict[str, Any]:
    seed = protocol["surfaceDesign"]["seed"]
    policy = protocol["surfaceDesign"]["policy"]
    base = {"mode": "mirror-oath-surface", "seed": seed, "policy": policy}
    current = copy.deepcopy(protocol["fixedResearchSettings"])

    def row(identifier: str, *, aspect: str = "duskblade", route: str = "afterimage",
            play_oath: bool = False, settings: dict[str, Any] | None = None) -> dict[str, Any]:
        value: dict[str, Any] = {**base, "id": identifier, "aspect": aspect,
                                 "route": route, "playOath": play_oath}
        if settings is not None:
            value["research421"] = settings
        return value

    pool0 = {**current, "mirrorOathPool": 0}
    pool1 = {**current, "mirrorOathPool": 1}
    gate0 = {**current, "mirrorOathGate": 0}
    gate1 = {**current, "mirrorOathGate": 1}
    rows = [
        row("null-dusk-omitted"),
        row("pool-null-dusk", settings=pool0),
        row("pool-enabled-dusk", settings=pool1),
        row("pool-null-ash", aspect="ashwarden", settings=pool0),
        row("pool-enabled-ash", aspect="ashwarden", settings=pool1),
        row("gate-null-dusk", settings=gate0),
        row("gate-enabled-dusk", settings=gate1),
        row("gate-null-dusk-with-oath", play_oath=True, settings=gate0),
        row("gate-enabled-dusk-with-oath", play_oath=True, settings=gate1),
        row("gate-null-ash-with-oath", aspect="ashwarden", play_oath=True,
            settings=gate0),
        row("gate-enabled-ash-with-oath", aspect="ashwarden", play_oath=True,
            settings=gate1),
        row("scoreline-gate-null", route="scoreline", settings=gate0),
        row("scoreline-gate-enabled", route="scoreline", settings=gate1),
    ]
    require("surface replay ceiling",
            len(rows) == protocol["budget"]["controlledSurfaceExecutions"])
    return {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "content": str(core.CACHE / f"{protocol['immutableInputs']['contentSha256']}.json"),
        "rows": rows,
    }


def strip_surface(row: dict[str, Any], *extra: str) -> str:
    return core.canonical(without(row, "id", "research421", *extra))


def strip_gate_mediator(row: dict[str, Any]) -> str:
    value = without(row, "id", "research421")
    for state_key in ("stateBeforeHarvest", "stateAfterHarvest"):
        state = value[state_key]
        state["playerStatuses"].pop("afterimage", None)
        state["queue"] = [event for event in state["queue"]
                          if not (event.get("t") == "status"
                                  and event.get("id") == "afterimage")]
    value["telemetry"].pop("afterimageApplied", None)
    value["telemetry"].pop("afterimageGateSuppressed", None)
    return core.canonical(value)


def analyse_surface(rows: list[dict[str, Any]], protocol: dict[str, Any]) -> dict[str, Any]:
    by_id = {str(row["id"]): row for row in rows}
    require("surface row count", len(rows) == len(by_id)
            == protocol["budget"]["controlledSurfaceExecutions"])
    for identifier, row in by_id.items():
        require(f"telemetry state inert {identifier}",
                row["stateBeforeHarvest"] == row["stateAfterHarvest"])
        require(f"pool RNG inert {identifier}",
                row["poolRngBefore"] == row["poolRngAfter"])

    omitted = by_id["null-dusk-omitted"]
    pool_null = by_id["pool-null-dusk"]
    pool_enabled = by_id["pool-enabled-dusk"]
    require("pool omitted versus explicit null", strip_surface(omitted)
            == strip_surface(pool_null))
    require("pool appends exact unlock", pool_enabled["unlocks"]
            == pool_null["unlocks"] + ["card:mirrorOath"])
    require("pool appends exact uncommon carrier", pool_enabled["uncommonPool"]
            == pool_null["uncommonPool"] + ["mirrorOath"])
    require("pool direct isolation", strip_surface(pool_null, "unlocks", "uncommonPool")
            == strip_surface(pool_enabled, "unlocks", "uncommonPool"))
    require("pool Dusk-only aspect gate", strip_surface(by_id["pool-null-ash"])
            == strip_surface(by_id["pool-enabled-ash"]))

    gate_null = by_id["gate-null-dusk"]
    gate_enabled = by_id["gate-enabled-dusk"]
    require("gate omitted versus explicit null", strip_surface(omitted)
            == strip_surface(gate_null))
    require("gate removes only Afterimage mediator", strip_gate_mediator(gate_null)
            == strip_gate_mediator(gate_enabled))
    require("null Ward creates Afterimage",
            gate_null["stateBeforeHarvest"]["playerStatuses"].get("afterimage") == 1
            and gate_null["telemetry"].get("afterimageApplied") == 1)
    require("enabled gate suppresses Afterimage without oath",
            "afterimage" not in gate_enabled["stateBeforeHarvest"]["playerStatuses"]
            and gate_enabled["telemetry"].get("afterimageGateSuppressed") == 1)
    require("Ward value unchanged by gate",
            gate_null["stateBeforeHarvest"]["playerBlock"]
            == gate_enabled["stateBeforeHarvest"]["playerBlock"]
            == protocol["surfaceDesign"]["expectedWard"])

    oath_null = by_id["gate-null-dusk-with-oath"]
    oath_enabled = by_id["gate-enabled-dusk-with-oath"]
    require("oath satisfies gate", strip_surface(oath_null) == strip_surface(oath_enabled))
    require("oath and Afterimage present",
            oath_enabled["stateBeforeHarvest"]["playerStatuses"].get("mirrorOath") == 1
            and oath_enabled["stateBeforeHarvest"]["playerStatuses"].get("afterimage") == 1)
    require("oath telemetry complete",
            oath_enabled["telemetry"].get("mirrorOathPlayed") == 1
            and oath_enabled["telemetry"].get("mirrorOathApplied") == 1
            and oath_enabled["telemetry"].get("defendPlayed") == 1
            and oath_enabled["telemetry"].get("afterimageApplied") == 1
            and "afterimageGateSuppressed" not in oath_enabled["telemetry"])

    ash_null = by_id["gate-null-ash-with-oath"]
    ash_enabled = by_id["gate-enabled-ash-with-oath"]
    require("gate preserves Ash path", strip_surface(ash_null) == strip_surface(ash_enabled))
    require("carrier and Afterimage are Dusk-only",
            "mirrorOath" not in ash_enabled["stateBeforeHarvest"]["playerStatuses"]
            and "afterimage" not in ash_enabled["stateBeforeHarvest"]["playerStatuses"])

    scoreline_null = by_id["scoreline-gate-null"]
    scoreline_enabled = by_id["scoreline-gate-enabled"]
    require("Scoreline path exact", strip_surface(scoreline_null)
            == strip_surface(scoreline_enabled))
    require("Scoreline control exercised", any(
        event.get("t") == "status" and event.get("id") == "scoreline"
        for event in scoreline_null["stateBeforeHarvest"]["queue"]))
    return {
        "status": "PASS",
        "rows": len(rows),
        "mirrorOathPool": {
            "nullIdentity": True,
            "exactDuskUncommonAppend": "mirrorOath",
            "AshPoolExact": True,
            "policyRngAndCombatStateExact": True,
        },
        "mirrorOathGate": {
            "nullIdentity": True,
            "onlySuppressedMediator": "afterimage",
            "WardExact": True,
            "oathPositiveControl": True,
            "AshNegativeControl": True,
            "ScorelineNegativeControl": True,
        },
        "telemetryStateAndRngInert": True,
    }


def invalid_level(protocol: dict[str, Any], protocol_sha: str, factor: str,
                  deadline: float) -> dict[str, Any]:
    settings = copy.deepcopy(protocol["fixedResearchSettings"])
    settings[factor] = 2
    plan = {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "content": str(core.CACHE / f"{protocol['immutableInputs']['contentSha256']}.json"),
        "rows": [{
            "id": f"invalid-{factor}", "mode": "mirror-oath-surface",
            "aspect": "duskblade", "seed": protocol["surfaceDesign"]["seed"],
            "policy": protocol["surfaceDesign"]["policy"], "research421": settings,
        }],
    }
    plan_sha, plan_path = core.cache_json(plan)
    with tempfile.TemporaryDirectory(dir=core.WORK, prefix="mirror-oath-invalid-") as tmp:
        out = Path(tmp) / "output.json"
        result = subprocess.run(
            [str(GODOT), "--headless", "-s", "res://tools/research_421_probe.gd", "--",
             f"--plan={plan_path}", f"--out={out}"],
            cwd=core.SOURCE, text=True, capture_output=True, timeout=remaining(deadline),
        )
        diagnostic = result.stdout + result.stderr
        require(f"{factor} invalid level exit", result.returncode == 2)
        require(f"{factor} invalid level output", not out.exists())
        require(f"{factor} invalid level diagnostic", "unregistered level" in diagnostic)
    return {"factor": factor, "level": 2, "planSha256": plan_sha,
            "exitCode": result.returncode, "diagnostic": "unregistered level"}


def main() -> None:
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    source, ledger_before = verify_inputs(protocol)
    started = time.monotonic()
    deadline = started + protocol["budget"]["maximumWallTimeSeconds"]
    frozen = frozen_rows(protocol)
    surface_output, surface_plan_sha, surface_output_sha = run_probe(
        surface_plan(protocol, protocol_sha), deadline)
    surface = analyse_surface(surface_output["rows"], protocol)
    whole_output, whole_plan_sha, whole_output_sha = run_probe(
        whole_plan(protocol, protocol_sha), deadline)
    whole = analyse_whole(whole_output["rows"], protocol, frozen)
    invalid = [invalid_level(protocol, protocol_sha, factor, deadline)
               for factor in ("mirrorOathPool", "mirrorOathGate")]
    elapsed = time.monotonic() - started
    require("wall-time ceiling", elapsed <= protocol["budget"]["maximumWallTimeSeconds"])
    ledger_after = ledger_identity()
    require("zero-ledger identity", ledger_before == ledger_after)
    summary = {
        "schemaVersion": 1,
        "decision": "mirror-oath-knobs-identity-safe",
        "protocolSha256": protocol_sha,
        "runnerSha256": source["runnerSha256"],
        "surfacePlanSha256": surface_plan_sha,
        "surfaceOutputSha256": surface_output_sha,
        "wholePlanSha256": whole_plan_sha,
        "wholeOutputSha256": whole_output_sha,
        "wholeRunIdentity": whole,
        "mediatorIsolation": surface,
        "invalidLevels": invalid,
        "wallTimeSeconds": elapsed,
        "newLedgerObservationRows": 0,
        "protectedSeedRows": 0,
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "decisionBoundary": protocol["decisionBoundary"]["onSuccess"],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical(summary))


if __name__ == "__main__":
    main()
