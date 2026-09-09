#!/usr/bin/env python3
"""Zero-ledger identity and mediator-isolation preflight for issue #421."""

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


PROTOCOL = core.ROOT / "protocols/post-v38-knob-identity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-knob-identity-v1.json"


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
            ["godot", "--version"], check=True, text=True, capture_output=True,
        ).stdout.strip(),
        "contentSha256": core.file_sha(
            core.CACHE / "e475482c76a405814dba4638860bb799f610a220fcde5d931c78d1a447e18f48.json"
        ),
        "combatRulesSha256": core.file_sha(core.SOURCE / "domain/rules/combat.gd"),
        "pilotSha256": core.file_sha(core.SOURCE / "tools/balance_pilot.gd"),
        "balanceSimSha256": core.file_sha(core.SOURCE / "tools/balance_sim.gd"),
        "probeSha256": core.file_sha(core.SOURCE / "tools/research_421_probe.gd"),
        "runnerSha256": core.file_sha(Path(__file__)),
    }


def verify_inputs(protocol: dict[str, Any]) -> tuple[dict[str, Any], dict[str, Any]]:
    actual_source = source_identity()
    actual_ledger = ledger_identity()
    for key, expected in protocol["immutableInputs"].items():
        actual = actual_source.get(key)
        if actual != expected:
            raise RuntimeError(
                f"immutable input drift: {key} expected {expected} got {actual}"
            )
    for key, expected in protocol["ledgerFreeze"].items():
        if actual_ledger.get(key) != expected:
            raise RuntimeError(
                f"ledger drift: {key} expected {expected} got {actual_ledger.get(key)}"
            )
    return actual_source, actual_ledger


def run_probe(plan: dict[str, Any], timeout: int) -> tuple[dict[str, Any], str, str]:
    plan_sha, plan_path = core.cache_json(plan)
    with tempfile.TemporaryDirectory(prefix="issue-421-knob-") as tmp:
        out = Path(tmp) / "output.json"
        result = subprocess.run(
            ["godot", "--headless", "-s", "res://tools/research_421_probe.gd", "--",
             f"--plan={plan_path}", f"--out={out}"],
            cwd=core.SOURCE, text=True, capture_output=True, timeout=timeout,
        )
        if result.returncode or not out.is_file():
            raise RuntimeError(
                f"probe failed ({result.returncode})\n"
                f"{result.stdout[-2000:]}\n{result.stderr[-4000:]}"
            )
        output = json.loads(out.read_text())
    output_sha, _ = core.cache_json(output)
    return output, plan_sha, output_sha


def require_equal(label: str, left: Any, right: Any) -> None:
    if left != right:
        raise RuntimeError(f"{label} differs")


def main() -> None:
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    source, ledger_before = verify_inputs(protocol)
    started = time.monotonic()
    content = str(core.CACHE / f"{protocol['immutableInputs']['contentSha256']}.json")
    defaults = protocol["factorDefinitions"]["nullSettings"]
    whole_cases = protocol["identityCases"]
    rows: list[dict[str, Any]] = []
    for case in whole_cases:
        common = {
            "id": case["id"], "stage": "post-v38-knob-identity",
            "mode": "whole-run", "aspect": case["aspect"], "vow": case["vow"],
            "seed": case["seed"], "policyRoot": case["policyRoot"],
            "policyIndex": case["policyIndex"], "captureTrace": True,
        }
        rows.append(common)
        explicit = copy.deepcopy(common)
        explicit["research421"] = defaults
        rows.append(explicit)
    surface_common = {
        "id": "null-surface", "stage": "post-v38-knob-identity",
        "mode": "knob-surface", "seed": protocol["surfaceCase"]["seed"],
        "policy": protocol["surfaceCase"]["policy"],
    }
    rows.append(surface_common)
    explicit_surface = copy.deepcopy(surface_common)
    explicit_surface["research421"] = defaults
    rows.append(explicit_surface)
    for label, settings in protocol["surfaceCase"]["settings"].items():
        row = copy.deepcopy(surface_common)
        row["id"] = label
        row["research421"] = settings
        rows.append(row)
    if len(rows) != protocol["budget"]["probeRowsMaximum"]:
        raise RuntimeError("probe plan does not match the frozen row ceiling")
    plan = {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "content": content,
        "rows": rows,
    }
    output, plan_sha, output_sha = run_probe(
        plan, protocol["budget"]["maximumWallTimeSeconds"]
    )
    observed = output["rows"]
    cursor = 0
    identity: dict[str, Any] = {}
    for case in whole_cases:
        absent, explicit = observed[cursor], observed[cursor + 1]
        require_equal(f"{case['id']} absent versus explicit null", absent, explicit)
        identity[case["id"]] = {
            "rowSha256": core.sha(core.canonical(absent).encode()),
            "policySha256": core.sha(core.canonical(absent["policy"]).encode()),
            "trajectorySha256": core.sha(
                core.canonical(absent["trajectory"]).encode()
            ),
            "rng": absent["rng"],
            "outcome": absent["outcome"],
        }
        cursor += 2
    absent_surface, explicit_surface_result = observed[cursor], observed[cursor + 1]
    require_equal("controlled surface absent versus explicit null",
                  absent_surface, explicit_surface_result)
    cursor += 2
    surfaces = {
        label: observed[cursor + offset]
        for offset, label in enumerate(protocol["surfaceCase"]["settings"])
    }
    ward_low, ward_high = surfaces["ward-low"], surfaces["ward-high"]
    acquisition_low = surfaces["acquisition-low"]
    acquisition_high = surfaces["acquisition-high"]
    for key in ("policy", "scorelineCompletionBonus", "afterimageCompletionBonus",
                "rngBeforeChoice", "rngAfterChoice"):
        require_equal(f"Ward isolation {key}", ward_low[key], ward_high[key])
    if ward_low["firstChoice"] == ward_high["firstChoice"] \
            or ward_high["firstChoice"] != protocol["surfaceCase"]["wardHighChoice"]:
        raise RuntimeError("Ward knob did not alter only the intended setup choice")
    for key in ("policy", "firstChoice", "rngBeforeChoice", "rngAfterChoice"):
        require_equal(
            f"acquisition isolation {key}", acquisition_low[key], acquisition_high[key]
        )
    expected_bonus = protocol["surfaceCase"]["expectedCompletionBonus"]
    for route in ("scoreline", "afterimage"):
        field = f"{route}CompletionBonus"
        if acquisition_low[field] != expected_bonus["low"] \
                or acquisition_high[field] != expected_bonus["high"]:
            raise RuntimeError(f"acquisition knob missed the {route} reward mediator")
    if ward_low["rngBeforeChoice"] != ward_low["rngAfterChoice"] \
            or ward_high["rngBeforeChoice"] != ward_high["rngAfterChoice"]:
        raise RuntimeError("Ward setup choice consumed RNG")
    invalid_plan = {
        "schemaVersion": 1, "protocolSha256": protocol_sha, "content": content,
        "rows": [{"id": "invalid-key", "mode": "knob-surface", "seed": 345100,
                  "research421": {"notAResearchKnob": 1}}],
    }
    invalid_sha, invalid_path = core.cache_json(invalid_plan)
    with tempfile.TemporaryDirectory(prefix="issue-421-knob-invalid-") as tmp:
        invalid_out = Path(tmp) / "output.json"
        invalid = subprocess.run(
            ["godot", "--headless", "-s", "res://tools/research_421_probe.gd", "--",
             f"--plan={invalid_path}", f"--out={invalid_out}"],
            cwd=core.SOURCE, text=True, capture_output=True,
            timeout=protocol["budget"]["maximumWallTimeSeconds"],
        )
    if invalid.returncode == 0 or "unknown research421 key" not in invalid.stderr:
        raise RuntimeError("unknown research knob did not fail closed")
    elapsed = time.monotonic() - started
    if elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        raise RuntimeError("preflight exceeded the frozen wall-time ceiling")
    ledger_after = ledger_identity()
    require_equal("append-only ledger", ledger_before, ledger_after)
    summary = {
        "schemaVersion": 1,
        "decision": "knobs-identity-safe",
        "protocolSha256": protocol_sha,
        "runnerSha256": source["runnerSha256"],
        "planSha256": plan_sha,
        "outputSha256": output_sha,
        "invalidPlanSha256": invalid_sha,
        "identityCases": identity,
        "nullSurfaceSha256": core.sha(core.canonical(absent_surface).encode()),
        "mediatorIsolation": {
            "wardSetupPriority": {
                "lowChoice": ward_low["firstChoice"],
                "highChoice": ward_high["firstChoice"],
                "completionBonusesUnchanged": True,
                "policyAndRngUnchanged": True,
            },
            "acquisitionPriority": {
                "lowBonus": expected_bonus["low"],
                "highBonus": expected_bonus["high"],
                "choicePolicyAndRngUnchanged": True,
            },
        },
        "unknownKeyFailedClosed": True,
        "newLedgerObservationRows": 0,
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical(summary))


if __name__ == "__main__":
    main()
