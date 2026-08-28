#!/usr/bin/env python3
"""Preregistered cross-enemy Facet identity preflight for issue #421."""

from __future__ import annotations

import copy
import json
import sqlite3
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Any

import research as core


PROTOCOL = core.ROOT / "protocols/post-v30-cross-enemy-facet-identity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v30-cross-enemy-facet-identity-v1.json"
SOURCE = core.ROOT / "cross-enemy-facet-identity-source"
GODOT = Path("/Applications/Godot.app/Contents/MacOS/Godot")
PROBE = "res://tools/research_421_cross_enemy_facet_identity_probe.gd"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Cross-enemy Facet identity mismatch: {label}")


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
            ["git", "rev-parse", "HEAD"], cwd=SOURCE, check=True,
            text=True, capture_output=True,
        ).stdout.strip(),
        "godotVersion": subprocess.run(
            [str(GODOT), "--version"], check=True, text=True,
            capture_output=True,
        ).stdout.strip(),
        "godotBinarySha256": core.file_sha(GODOT),
        "contentSha256": core.file_sha(SOURCE / "content/full-content.json"),
        "combatRulesSha256": core.file_sha(SOURCE / "domain/rules/combat.gd"),
        "balanceSimSha256": core.file_sha(SOURCE / "tools/balance_sim.gd"),
        "policySha256": core.file_sha(SOURCE / "tools/balance_policy.gd"),
        "probeSha256": core.file_sha(
            SOURCE / "tools/research_421_cross_enemy_facet_identity_probe.gd"),
        "probeUidSha256": core.file_sha(
            SOURCE / "tools/research_421_cross_enemy_facet_identity_probe.gd.uid"),
        "runnerSha256": core.file_sha(Path(__file__)),
        "frontierProtocolSha256": core.file_sha(
            core.ROOT / "protocols/post-v30-dusk-state-frontier-audit-v1.json"),
        "frontierSummarySha256": core.file_sha(
            core.ROOT / "summaries/post-v30-dusk-state-frontier-audit-v1.json"),
        "taskCapsuleSha256": core.file_sha(core.ROOT / "task-capsule.json"),
    }


def remaining(deadline: float) -> int:
    seconds = int(deadline - time.monotonic())
    if seconds < 1:
        raise TimeoutError("cross-enemy Facet identity exceeded its wall-time ceiling")
    return seconds


def run_probe(
    plan: dict[str, Any], deadline: float,
) -> tuple[dict[str, Any], str, str]:
    plan_sha, plan_path = core.cache_json(plan)
    core.WORK.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(
        dir=core.WORK, prefix="cross-enemy-facet-identity-"
    ) as tmp:
        output_path = Path(tmp) / "output.json"
        result = subprocess.run(
            [str(GODOT), "--headless", "-s", PROBE, "--",
             f"--plan={plan_path}", f"--out={output_path}"],
            cwd=SOURCE, text=True, capture_output=True,
            timeout=remaining(deadline),
        )
        if result.returncode or not output_path.is_file():
            raise RuntimeError(
                f"probe failed ({result.returncode})\n"
                f"{result.stdout[-2000:]}\n{result.stderr[-4000:]}"
            )
        output = json.loads(output_path.read_text())
    require("plan identity", output.get("planSha256") == plan_sha)
    output_sha, _ = core.cache_json(output)
    return output, plan_sha, output_sha


def direct_plan(protocol: dict[str, Any], protocol_sha: str) -> dict[str, Any]:
    return {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "mode": "direct",
        "content": str(SOURCE / "content/full-content.json"),
        "rows": [control["input"] for control in protocol["directControls"]],
    }


def whole_plan(
    protocol: dict[str, Any], protocol_sha: str, stage: str,
) -> dict[str, Any]:
    cohort = protocol[f"{stage}Cohort"]
    rows: list[dict[str, Any]] = []
    for policy_index in cohort["policyIndices"]:
        for seed in cohort["simulationSeeds"]:
            arms = (("explicit-false", False), ("explicit-false", True)) \
                if stage == "traceSentinel" else \
                (("omitted", True), ("explicit-false", True))
            for arm, capture in arms:
                rows.append({
                    "id": f"{stage}-p{policy_index}-s{seed}-{arm}-c{int(capture)}",
                    "arm": arm,
                    "capture": capture,
                    "policyRoot": cohort["policyRoot"],
                    "policyIndex": policy_index,
                    "seed": seed,
                    "aspect": cohort["aspect"],
                    "vow": cohort["vow"],
                })
    return {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "mode": "whole-runs",
        "content": str(SOURCE / "content/full-content.json"),
        "rows": rows,
    }


def check_direct(
    output: dict[str, Any], protocol: dict[str, Any],
) -> dict[str, Any]:
    rows = output.get("rows")
    require("direct row array", isinstance(rows, list))
    expected = {row["input"]["id"]: row["expected"]
                for row in protocol["directControls"]}
    require("direct row count", len(rows) == len(expected))
    seen: set[str] = set()
    rng_mismatches = 0
    mapping_mismatches = 0
    by_id: dict[str, dict[str, Any]] = {}
    for row in rows:
        row_id = str(row.get("id", ""))
        require(f"known direct row {row_id}", row_id in expected and row_id not in seen)
        seen.add(row_id)
        actual = copy.deepcopy(row)
        before = actual.pop("rngBefore")
        after = actual.pop("rngAfter")
        rng_mismatches += before != after
        mapping_mismatches += actual != expected[row_id]
        by_id[row_id] = actual
    require("all direct IDs", seen == set(expected))
    require("direct RNG identity", rng_mismatches == 0)
    require("direct exact mapping", mapping_mismatches == 0)
    off = copy.deepcopy(by_id["other-partial-factor-off"])
    on = copy.deepcopy(by_id["other-partial-factor-on"])
    on["factor"] = False
    on["enemyAfter"][1]["chips"] -= 1
    on["chipEvents"][0]["n"] -= 1
    on["chipEvents"][0]["chips"] -= 1
    require("focused mediator isolation", on == off)
    return {
        "rows": len(rows),
        "rngMismatchRows": rng_mismatches,
        "mappingMismatchRows": mapping_mismatches,
        "focusedMediatorMismatchRows": 0,
    }


def core_row(row: dict[str, Any]) -> dict[str, Any]:
    value = copy.deepcopy(row)
    for key in ("id", "arm", "capture", "trajectory"):
        value.pop(key)
    return value


def trace_schema_faults(trace: Any) -> int:
    if not isinstance(trace, dict) or set(trace) != {
        "capture", "nodes", "combatEvents", "cardRewards", "bossRelics"
    } or trace.get("capture") is not True:
        return 1
    if not all(isinstance(trace[key], list) for key in
               ("nodes", "combatEvents", "cardRewards", "bossRelics")):
        return 1
    allowed = {"turn", "play", "hitEnemy", "chip", "shatter", "die", "endTurn"}
    faults = 0
    for event in trace["combatEvents"]:
        faults += not isinstance(event, dict) or event.get("t") not in allowed \
            or not isinstance(event.get("fight"), int)
        if isinstance(event, dict) and event.get("t") == "play":
            faults += "targetIdx" not in event or "id" not in event or "uid" not in event
        if isinstance(event, dict) and event.get("t") == "chip":
            faults += any(key not in event for key in ("idx", "n", "chips", "facetMax"))
    return int(faults)


def check_sentinel(
    output: dict[str, Any], protocol: dict[str, Any],
) -> dict[str, Any]:
    rows = output.get("rows")
    require("sentinel row array", isinstance(rows, list))
    identities = int(protocol["traceSentinelCohort"]["identities"])
    require("sentinel row count", len(rows) == identities * 2)
    arms: dict[bool, dict[tuple[int, int], dict[str, Any]]] = {False: {}, True: {}}
    for row in rows:
        require("sentinel explicit false", row.get("arm") == "explicit-false")
        capture = row.get("capture")
        require("sentinel capture boolean", isinstance(capture, bool))
        key = int(row["policyIndex"]), int(row["seed"])
        require(f"unique sentinel {capture} {key}", key not in arms[capture])
        arms[capture][key] = row
    require("sentinel paired identities", set(arms[False]) == set(arms[True]))
    complete_mismatches = 0
    schema_faults = 0
    for key in sorted(arms[False]):
        off, on = arms[False][key], arms[True][key]
        complete_mismatches += core_row(off) != core_row(on)
        schema_faults += off["trajectory"] != {"capture": False}
        schema_faults += trace_schema_faults(on["trajectory"])
    require("sentinel core identity", complete_mismatches == 0)
    require("sentinel trace schema", schema_faults == 0)
    return {
        "identities": identities,
        "observationRows": len(rows),
        "coreMismatchRows": complete_mismatches,
        "schemaFaultRows": schema_faults,
    }


def comparable(row: dict[str, Any]) -> dict[str, Any]:
    value = copy.deepcopy(row)
    value.pop("id")
    value.pop("arm")
    return value


def check_identity(
    output: dict[str, Any], protocol: dict[str, Any],
) -> dict[str, Any]:
    rows = output.get("rows")
    require("identity row array", isinstance(rows, list))
    identities = int(protocol["identityCohort"]["identities"])
    require("identity row count", len(rows) == identities * 2)
    arms: dict[str, dict[tuple[int, int], dict[str, Any]]] = {
        "omitted": {}, "explicit-false": {},
    }
    for row in rows:
        arm = str(row.get("arm", ""))
        require(f"identity arm {arm}", arm in arms and row.get("capture") is True)
        key = int(row["policyIndex"]), int(row["seed"])
        require(f"unique identity {arm} {key}", key not in arms[arm])
        arms[arm][key] = row
    require("identity paired arms", set(arms["omitted"]) == set(arms["explicit-false"]))
    complete_mismatches = path_mismatches = rng_mismatches = 0
    policy_mismatches = result_mismatches = reliability_faults = 0
    schema_faults = 0
    outcomes: dict[str, int] = {}
    for key in sorted(arms["omitted"]):
        omitted, explicit = arms["omitted"][key], arms["explicit-false"][key]
        complete_mismatches += comparable(omitted) != comparable(explicit)
        path_mismatches += omitted["trajectory"] != explicit["trajectory"]
        rng_mismatches += omitted["rng"] != explicit["rng"]
        policy_mismatches += omitted["policy"] != explicit["policy"]
        result_mismatches += any(
            omitted[field] != explicit[field]
            for field in ("outcome", "error", "hp", "maxHp", "gold", "deck",
                          "fights", "relics", "deckIds", "economy")
        )
        reliability_faults += sum(
            bool(row.get("error")) or row.get("outcome") == "error"
            for row in (omitted, explicit)
        )
        schema_faults += trace_schema_faults(omitted["trajectory"])
        outcome = str(omitted["outcome"])
        outcomes[outcome] = outcomes.get(outcome, 0) + 1
    require("identity complete", complete_mismatches == 0)
    require("identity path", path_mismatches == 0)
    require("identity RNG", rng_mismatches == 0)
    require("identity policy", policy_mismatches == 0)
    require("identity result", result_mismatches == 0)
    require("identity reliability", reliability_faults == 0)
    require("identity trace schema", schema_faults == 0)
    return {
        "identities": identities,
        "observationRows": len(rows),
        "completeMismatchRows": complete_mismatches,
        "pathMismatchRows": path_mismatches,
        "rngMismatchRows": rng_mismatches,
        "policyMismatchRows": policy_mismatches,
        "resultMismatchRows": result_mismatches,
        "reliabilityFaultRows": reliability_faults,
        "schemaFaultRows": schema_faults,
        "outcomes": outcomes,
    }


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite cross-enemy Facet identity summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    source = source_identity()
    for key, expected in protocol["immutableInputs"].items():
        require(f"immutable {key}", source.get(key) == expected)
    ledger_before = ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    started = time.monotonic()
    deadline = started + float(protocol["budget"]["maximumWallTimeSeconds"])
    manifests: dict[str, Any] = {}
    direct: dict[str, Any] = {}
    sentinel: dict[str, Any] = {}
    identity_result: dict[str, Any] = {}
    process_count = observation_rows = 0
    failure = ""
    outcome_class = "success"
    try:
        output, plan_sha, output_sha = run_probe(direct_plan(protocol, protocol_sha), deadline)
        process_count += 1
        direct = check_direct(output, protocol)
        manifests["direct"] = {"planSha256": plan_sha, "outputSha256": output_sha}

        output, plan_sha, output_sha = run_probe(
            whole_plan(protocol, protocol_sha, "traceSentinel"), deadline)
        process_count += 1
        observation_rows += len(output["rows"])
        sentinel = check_sentinel(output, protocol)
        manifests["traceSentinel"] = {"planSha256": plan_sha, "outputSha256": output_sha}

        output, plan_sha, output_sha = run_probe(
            whole_plan(protocol, protocol_sha, "identity"), deadline)
        process_count += 1
        observation_rows += len(output["rows"])
        identity_result = check_identity(output, protocol)
        manifests["wholeRuns"] = {"planSha256": plan_sha, "outputSha256": output_sha}

        require("direct cap", direct["rows"] == protocol["budget"]["directExecutions"])
        require("observation cap", observation_rows ==
                protocol["budget"]["maximumWholeRunIdentityObservationRows"])
        require("process cap", process_count == protocol["budget"]["maximumGodotProcesses"])
    except (subprocess.TimeoutExpired, TimeoutError) as error:
        failure, outcome_class = str(error), "inconclusive"
    except (KeyError, RuntimeError, TypeError, ValueError) as error:
        failure, outcome_class = str(error), "futility"

    elapsed = time.monotonic() - started
    ledger_after = ledger_identity()
    if elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        failure, outcome_class = failure or "wall-time ceiling", "inconclusive"
    if ledger_after != ledger_before:
        failure, outcome_class = failure or "ledger identity drift", "inconclusive"
    success = not failure
    if success:
        outcome_class = "success"
    decision = {
        "success": "cross-enemy-facet-identity-green-authorise-capacity-trace-preregistration",
        "futility": "close-cross-enemy-facet-on-identity-failure",
        "inconclusive": "record-cross-enemy-facet-identity-inconclusive-at-cap",
    }[outcome_class]
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": {"success": 1, "futility": 2, "inconclusive": 3}[outcome_class],
        "decision": decision,
        "outcomeClass": outcome_class,
        "failure": failure,
        "protocolSha256": protocol_sha,
        "sourceIdentity": source,
        "directControls": direct,
        "traceSentinel": sentinel,
        "wholeRunIdentity": identity_result,
        "execution": {
            "manifests": manifests,
            "wholeRunIdentityObservationRows": observation_rows,
            "directExecutions": direct.get("rows", 0),
            "GodotProcesses": process_count,
            "enabledFactorWholeRunRows": 0,
            "supportMetricsInspected": 0,
            "causalRows": 0,
            "causalEndpointsInspected": 0,
            "newLedgerRows": ledger_after["records"] - ledger_before["records"],
            "protectedSeedRows": ledger_after["protectedSeedRows"],
            "maximumModelContextTokens": 0,
            "wallTimeSeconds": elapsed,
        },
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "authority": protocol["decisionRules"][f"{outcome_class}Authority"],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS" if success else "FAIL",
        "decision": decision,
        "summarySha256": core.file_sha(SUMMARY),
    }))
    if not success:
        sys.exit(2)


if __name__ == "__main__":
    main()
