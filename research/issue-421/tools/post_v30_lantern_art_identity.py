#!/usr/bin/env python3
"""Preregistered exact-runtime Lantern-Art identity preflight for issue #421."""

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


PROTOCOL = core.ROOT / "protocols/post-v30-lantern-art-identity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v30-lantern-art-identity-v1.json"
SOURCE = core.ROOT / "lantern-art-identity-source"
GODOT = Path("/Applications/Godot.app/Contents/MacOS/Godot")
PROBE = "res://tools/research_421_lantern_art_identity_probe.gd"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Lantern-Art identity mismatch: {label}")


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
            SOURCE / "tools/research_421_lantern_art_identity_probe.gd"),
        "probeUidSha256": core.file_sha(
            SOURCE / "tools/research_421_lantern_art_identity_probe.gd.uid"),
        "runnerSha256": core.file_sha(Path(__file__)),
        "repertoireAuditProtocolSha256": core.file_sha(
            core.ROOT / "protocols/post-v30-lantern-art-repertoire-audit-v1.json"),
        "repertoireAuditSummarySha256": core.file_sha(
            core.ROOT / "summaries/post-v30-lantern-art-repertoire-audit-v1.json"),
        "taskCapsuleSha256": core.file_sha(core.ROOT / "task-capsule.json"),
    }


def remaining(deadline: float) -> int:
    seconds = int(deadline - time.monotonic())
    if seconds < 1:
        raise TimeoutError("Lantern-Art identity exceeded its wall-time ceiling")
    return seconds


def run_probe(
    plan: dict[str, Any], deadline: float,
) -> tuple[dict[str, Any], str, str]:
    plan_sha, plan_path = core.cache_json(plan)
    core.WORK.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(
        dir=core.WORK, prefix="lantern-art-identity-"
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


def whole_plan(protocol: dict[str, Any], protocol_sha: str) -> dict[str, Any]:
    cohort = protocol["identityCohort"]
    rows: list[dict[str, Any]] = []
    for policy_index in cohort["policyIndices"]:
        for seed in cohort["simulationSeeds"]:
            for arm in ("omitted", "explicit-flare"):
                rows.append({
                    "id": f"p{policy_index}-s{seed}-{arm}",
                    "arm": arm,
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
    for row in rows:
        row_id = str(row.get("id", ""))
        require(f"known direct row {row_id}", row_id in expected and row_id not in seen)
        seen.add(row_id)
        actual = copy.deepcopy(row)
        before = actual.pop("rngBefore")
        after = actual.pop("rngAfter")
        rng_mismatches += before != after
        mapping_mismatches += actual != expected[row_id]
    require("all direct IDs", seen == set(expected))
    require("direct RNG identity", rng_mismatches == 0)
    require("direct exact mapping", mapping_mismatches == 0)
    return {
        "rows": len(rows),
        "rngMismatchRows": rng_mismatches,
        "mappingMismatchRows": mapping_mismatches,
    }


def whole_key(row: dict[str, Any]) -> tuple[int, int]:
    return int(row["policyIndex"]), int(row["seed"])


def comparable(row: dict[str, Any]) -> dict[str, Any]:
    value = copy.deepcopy(row)
    value.pop("id")
    value.pop("arm")
    return value


def check_whole(
    output: dict[str, Any], protocol: dict[str, Any],
) -> dict[str, Any]:
    rows = output.get("rows")
    require("whole-run row array", isinstance(rows, list))
    expected_identities = int(protocol["identityCohort"]["identities"])
    require("whole-run row count", len(rows) == expected_identities * 2)
    arms: dict[str, dict[tuple[int, int], dict[str, Any]]] = {
        "omitted": {}, "explicit-flare": {},
    }
    for row in rows:
        arm = str(row.get("arm", ""))
        require(f"whole arm {arm}", arm in arms)
        key = whole_key(row)
        require(f"unique whole identity {arm} {key}", key not in arms[arm])
        arms[arm][key] = row
    require("whole paired identities", set(arms["omitted"]) == set(arms["explicit-flare"]))
    complete_mismatches = 0
    path_mismatches = 0
    rng_mismatches = 0
    policy_mismatches = 0
    result_mismatches = 0
    reliability_faults = 0
    outcomes: dict[str, int] = {}
    for key in sorted(arms["omitted"]):
        omitted = arms["omitted"][key]
        explicit = arms["explicit-flare"][key]
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
        outcome = str(omitted["outcome"])
        outcomes[outcome] = outcomes.get(outcome, 0) + 1
    require("whole complete identity", complete_mismatches == 0)
    require("whole path identity", path_mismatches == 0)
    require("whole RNG identity", rng_mismatches == 0)
    require("whole policy identity", policy_mismatches == 0)
    require("whole result identity", result_mismatches == 0)
    require("whole reliability", reliability_faults == 0)
    return {
        "identities": expected_identities,
        "completeMismatchRows": complete_mismatches,
        "pathMismatchRows": path_mismatches,
        "rngMismatchRows": rng_mismatches,
        "policyMismatchRows": policy_mismatches,
        "resultMismatchRows": result_mismatches,
        "reliabilityFaultRows": reliability_faults,
        "outcomes": outcomes,
    }


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite Lantern-Art identity summary")
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
    identity: dict[str, Any] = {}
    process_count = 0
    observation_rows = 0
    failure = ""
    outcome_class = "success"
    try:
        output, plan_sha, output_sha = run_probe(
            direct_plan(protocol, protocol_sha), deadline)
        process_count += 1
        direct = check_direct(output, protocol)
        manifests["direct"] = {"planSha256": plan_sha, "outputSha256": output_sha}

        output, plan_sha, output_sha = run_probe(
            whole_plan(protocol, protocol_sha), deadline)
        process_count += 1
        observation_rows = len(output["rows"])
        identity = check_whole(output, protocol)
        manifests["wholeRuns"] = {"planSha256": plan_sha, "outputSha256": output_sha}

        require("direct cap", direct["rows"] == protocol["budget"]["directExecutions"])
        require("observation cap", observation_rows
                == protocol["budget"]["maximumWholeRunIdentityObservationRows"])
        require("process cap", process_count == protocol["budget"]["maximumGodotProcesses"])
    except (subprocess.TimeoutExpired, TimeoutError) as error:
        failure = str(error)
        outcome_class = "inconclusive"
    except (KeyError, RuntimeError, TypeError, ValueError) as error:
        failure = str(error)
        outcome_class = "futility"

    elapsed = time.monotonic() - started
    ledger_after = ledger_identity()
    if elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        failure = failure or "wall-time ceiling"
        outcome_class = "inconclusive"
    if ledger_after != ledger_before:
        failure = failure or "ledger identity drift"
        outcome_class = "inconclusive"
    success = not failure
    if success:
        outcome_class = "success"
    decision = {
        "success": "lantern-art-identity-green-authorise-capacity-preregistration",
        "futility": "close-lantern-art-factor-on-identity-failure",
        "inconclusive": "record-lantern-art-identity-inconclusive-at-cap",
    }[outcome_class]
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": {"success": 1, "futility": 2, "inconclusive": 3}[
            outcome_class],
        "decision": decision,
        "outcomeClass": outcome_class,
        "failure": failure,
        "protocolSha256": protocol_sha,
        "sourceIdentity": source,
        "directControls": direct,
        "wholeRunIdentity": identity,
        "execution": {
            "manifests": manifests,
            "wholeRunIdentityObservationRows": observation_rows,
            "directExecutions": direct.get("rows", 0),
            "GodotProcesses": process_count,
            "enabledBeaconWholeRunRows": 0,
            "causalRows": 0,
            "causalEndpointsInspected": 0,
            "causalFits": 0,
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
        "decision": summary["decision"],
        "summarySha256": core.file_sha(SUMMARY),
    }))
    if not success:
        sys.exit(2)


if __name__ == "__main__":
    main()
