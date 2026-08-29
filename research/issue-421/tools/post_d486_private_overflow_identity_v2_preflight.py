#!/usr/bin/env python3
"""Zero-observation mechanical preflight for private-overflow identity v2."""

from __future__ import annotations

import json
import time
from pathlib import Path
from typing import Any

import post_d486_private_overflow_identity_v1 as v1
import post_d486_private_overflow_identity_v2 as v2
import post_843e899_terminal_hit_precision_identity_v1 as direct
import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-d486-private-overflow-identity-v2.json"
PARENT = core.ROOT / "protocols/post-d486-private-overflow-identity-v1.json"
V1_SUMMARY = core.ROOT / "summaries/post-d486-private-overflow-identity-v1.json"
SUMMARY = core.ROOT / "summaries/post-d486-private-overflow-identity-v2-preflight.json"


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite private-overflow v2 preflight")
    started = time.monotonic()
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    parent, parent_sha = core.load_protocol(PARENT)
    faults: list[str] = []

    def check(label: str, condition: bool) -> None:
        if not condition:
            faults.append(label)

    check("parent protocol identity", parent_sha == protocol["parentProtocolSha256"])
    check("v1 summary identity",
          core.file_sha(V1_SUMMARY) == protocol["v1Stop"]["summarySha256"])
    v1_summary: dict[str, Any] = json.loads(V1_SUMMARY.read_text())
    check("v1 stopped inconclusive before observations",
          v1_summary.get("outcomeClass") == "inconclusive"
          and v1_summary.get("GodotProcesses") == 0
          and v1_summary.get("directControlledObservations") == 0
          and v1_summary.get("newSimulatorObservationRows") == 0)
    check("v1 replay remains forbidden", v1_summary.get("replayForbidden") is True)

    raw_baseline = v2.git_status(v1.BASELINE)
    raw_candidate = v2.git_status(v1.CANDIDATE)
    check("raw baseline status identity",
          raw_baseline == parent["immutableInputs"]["baselineStatus"])
    check("raw candidate status identity",
          raw_candidate == parent["immutableInputs"]["candidateStatus"])

    v1_actual = v1.source_identity(parent)
    v1_expected = {key: parent["immutableInputs"][key] for key in v1_actual}
    mismatches = [key for key in v1_actual if v1_actual[key] != v1_expected[key]]
    check("v1 mismatch isolated to candidate status", mismatches == ["candidateStatus"])
    check("v1 first-line whitespace loss reproduced",
          v1_actual["candidateStatus"]
          == ["M domain/rules/combat.gd", " M domain/state/player_combatant.gd",
              "?? tools/research_421_ember_overflow_probe.gd",
              "?? tools/research_421_ember_overflow_probe.gd.uid"])

    scenarios = parent["directScenarios"]
    baseline_rows = direct.arm_rows(scenarios, "baseline")
    candidate_rows = (
        direct.arm_rows(scenarios, "omitted")
        + direct.arm_rows(scenarios, "off")
        + direct.arm_rows(scenarios, "ab")
    )
    component = next(
        row for row in scenarios if row["id"] == parent["componentControlScenario"]
    )
    candidate_rows += direct.arm_rows([component], "a")
    candidate_rows += direct.arm_rows([component], "b")
    check("expected output cardinality",
          len(baseline_rows) == 15 and len(candidate_rows) == 47
          and len(baseline_rows) + len(candidate_rows)
          == protocol["budget"]["directControlledObservations"])
    check("scientific matrix inherited by hash",
          core.sha(json.dumps(scenarios, sort_keys=True, separators=(",", ":")).encode())
          == protocol["scientificContract"]["directScenariosCanonicalSha256"])
    check("probe byte identity", core.file_sha(
        v1.BASELINE / "tools/research_421_ember_overflow_probe.gd") == core.file_sha(
        v1.CANDIDATE / "tools/research_421_ember_overflow_probe.gd"))
    check("source and comparator static gates", not v1.static_faults())

    runner_source = Path(v2.__file__).read_text()
    check("v2 uses raw status function",
          ').stdout.splitlines()' in runner_source
          and '"status", "--porcelain=v1"' in runner_source)
    check("v2 inherits exact scenario matrix",
          'scenarios = parent["directScenarios"]' in runner_source)
    check("v2 inherits exact scientific analyser",
          "faults.extend(v1.direct_faults(parent, baseline, candidate))" in runner_source)
    check("v2 scientific summary absent", not v2.SUMMARY.exists())
    check("v2 runner identity",
          core.file_sha(Path(v2.__file__)) == protocol["immutableInputs"]["runnerSha256"])
    check("v2 preflight runner identity",
          core.file_sha(Path(__file__))
          == protocol["immutableInputs"]["preflightRunnerSha256"])
    check("ledger identity", identity.ledger_identity() == parent["ledgerFreeze"])

    elapsed = time.monotonic() - started
    check("wall-time cap", elapsed <= protocol["mechanicalPreflight"]["maximumWallTimeSeconds"])
    decision = (
        "authorise-first-scientific-v2-look" if not faults
        else "close-v2-before-scientific-look"
    )
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decision": decision,
        "protocolSha256": protocol_sha,
        "parentProtocolSha256": parent_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "faults": faults,
        "expectedBaselineRows": len(baseline_rows),
        "expectedCandidateRows": len(candidate_rows),
        "newDirectControlledObservations": 0,
        "newSimulatorObservationRows": 0,
        "newLedgerRows": 0,
        "GodotProbeProcesses": 0,
        "wallTimeSeconds": elapsed,
        "v1DispositionPreserved": "record-private-overflow-identity-inconclusive-at-cap",
        "correction": "Use raw git status --porcelain lines for provenance; no scientific field, source, probe, row, factor, estimator or stop rule changes.",
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"decision": decision, "faults": len(faults)}, sort_keys=True))


if __name__ == "__main__":
    main()
