#!/usr/bin/env python3
"""Zero-row mechanical preflight for #421 Ember-overflow capacity."""

from __future__ import annotations

import json
import sqlite3
import subprocess
from pathlib import Path

import post_d486_private_overflow_capacity_v1 as capacity
import post_v38_knob_identity as identity
import research as core


SUMMARY = core.ROOT / "summaries/post-d486-private-overflow-capacity-v1-preflight.json"


def numeric_values(value: object) -> list[int]:
    if isinstance(value, bool):
        return []
    if isinstance(value, int):
        return [value]
    if isinstance(value, list):
        return [number for item in value for number in numeric_values(item)]
    if isinstance(value, dict):
        return [number for item in value.values() for number in numeric_values(item)]
    return []


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite private-overflow capacity preflight")
    protocol, protocol_sha = core.load_protocol(capacity.PROTOCOL)
    immutable = protocol["immutableInputs"]
    actual_source = capacity.source_identity(protocol)
    faults: list[str] = []
    if actual_source != {key: immutable[key] for key in actual_source}:
        faults.append("immutable source identity drift")
    ledger = identity.ledger_identity()
    if ledger != protocol["ledgerFreeze"]:
        faults.append("ledger freeze drift")
    faults.extend(capacity.static_faults(protocol))

    baseline_probe = capacity.common.BASELINE / capacity.PROBE.removeprefix("res://")
    candidate_probe = capacity.common.CANDIDATE / capacity.PROBE.removeprefix("res://")
    if core.file_sha(baseline_probe) != core.file_sha(candidate_probe):
        faults.append("cross-arm probe byte identity")
    for source, paths in (
        (capacity.common.BASELINE, [capacity.PROBE.removeprefix("res://")]),
        (capacity.common.CANDIDATE, [
            "domain/state/player_combatant.gd", "domain/rules/combat.gd",
            "tools/balance_sim.gd", capacity.PROBE.removeprefix("res://"),
        ]),
    ):
        result = subprocess.run(
            ["tools/check_scripts.sh", *paths], cwd=source,
            text=True, capture_output=True,
        )
        if result.returncode != 0:
            faults.append(f"parse gate failed: {source.name}")

    rows = capacity.common.cohort_rows(protocol, False)
    rows += capacity.common.cohort_rows(protocol, True)
    if len(rows) != protocol["budget"]["newScientificSimulatorObservationRows"]:
        faults.append("row budget drift")
    cohort = protocol["cohort"]
    with sqlite3.connect(f"file:{core.LEDGER}?mode=ro", uri=True) as db:
        reused = db.execute(
            "SELECT COUNT(*) FROM records WHERE "
            "CAST(json_extract(payload_json, '$.policyRoot') AS INTEGER) = ? OR "
            "CAST(json_extract(payload_json, '$.seed') AS INTEGER) BETWEEN ? AND ?",
            (cohort["policyRoot"], min(cohort["simulationSeeds"]),
             max(cohort["simulationSeeds"])),
        ).fetchone()[0]
    if reused:
        faults.append("cohort reused in append-only ledger")
    needles = {cohort["policyRoot"], *cohort["simulationSeeds"]}
    for path in [*core.ROOT.glob("protocols/*.json"), *core.ROOT.glob("summaries/*.json")]:
        if path == capacity.PROTOCOL:
            continue
        try:
            values = set(numeric_values(json.loads(path.read_text())))
        except json.JSONDecodeError:
            faults.append(f"invalid prior JSON: {path.relative_to(core.ROOT)}")
            continue
        if needles & values:
            faults.append(f"cohort identity reused: {path.relative_to(core.ROOT)}")

    decision = "authorise-first-scientific-capacity-look" if not faults else "refuse-capacity-look"
    summary = {
        "schemaVersion": 1, "issue": 421, "decision": decision,
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "capacityRunnerSha256": core.file_sha(Path(capacity.__file__)),
        "sourceIdentity": actual_source, "ledgerIdentity": ledger,
        "plannedRows": len(rows), "plannedGodotProcesses": 2,
        "freshLedgerRows": reused, "faults": faults,
        "newSimulatorObservationRows": 0, "newLedgerRows": 0,
        "maximumModelContextTokensDuringExecutionAndDecision": 0,
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"decision": decision, "faults": faults}, sort_keys=True))
    if faults:
        raise SystemExit(2)


if __name__ == "__main__":
    main()
