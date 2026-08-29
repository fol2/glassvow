#!/usr/bin/env python3
"""Categorical fight-local representation identity preflight for issue #421."""

from __future__ import annotations

import copy
import json
import subprocess
import tempfile
import time
from pathlib import Path
from typing import Any

import post_v38_fight_local_identity as v1
import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-fight-local-identity-v2.json"
SUMMARY = core.ROOT / "summaries/post-v38-fight-local-identity-v2.json"
BASELINE = core.ROOT / "fight-local-sequencing-v2-baseline"
CANDIDATE = core.ROOT / "fight-local-sequencing-v2-source"
BASELINE_PROBE = "res://tools/research_421_fight_local_v2_baseline_probe.gd"
CANDIDATE_PROBE = "res://tools/research_421_fight_local_v2_probe.gd"
SCORELINE = {
    0: "off",
    4: "chisel-base-4",
    6: "faultline-bonus-6",
    8: "faultline-base-8",
}
AFTERIMAGE = {
    0: "off",
    4: "wardens-edge-4",
    5: "ward-base-5",
    8: "ward-upgraded-8",
}


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(label)


def settings(scoreline: int, afterimage: int) -> dict[str, str]:
    return {
        "schemaVersion": "fight-local-v2",
        "scorelinePayoff": SCORELINE[scoreline],
        "afterimagePayoff": AFTERIMAGE[afterimage],
    }


def reidentify(rows: list[dict[str, Any]], scripted_seed: int) -> list[dict[str, Any]]:
    result = copy.deepcopy(rows)
    for row in result:
        if row.get("mode") == "scripted":
            row["seed"] = scripted_seed
        old = row.get("research421")
        if isinstance(old, dict):
            row["research421"] = settings(
                int(old.get("scorelineDamage", 0)),
                int(old.get("afterimageWardCap", 0)),
            )
    return result


def invalid_configuration_fails(
    protocol_sha: str,
    content: str,
    encoded: Any,
    expected: str,
    godot: str,
    timeout: int,
    scripted_seed: int,
) -> tuple[bool, str]:
    row = v1.scripted("invalid-v2", ["defend"], [v1.play("defend")])
    row["seed"] = scripted_seed
    row["research421"] = encoded
    plan = {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "content": content,
        "rows": [row],
    }
    plan_sha, plan_path = core.cache_json(plan)
    with tempfile.TemporaryDirectory(prefix="issue-421-fight-local-v2-invalid-") as tmp:
        out = Path(tmp) / "output.json"
        result = subprocess.run(
            [godot, "--headless", "-s", CANDIDATE_PROBE, "--",
             f"--plan={plan_path}", f"--out={out}"],
            cwd=CANDIDATE, text=True, capture_output=True, timeout=timeout,
        )
        output_created = out.exists()
    return result.returncode != 0 and not output_created and expected in result.stderr, plan_sha


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the fight-local v2 identity summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    immutable = protocol["immutableInputs"]
    require("runner SHA drift", core.file_sha(Path(__file__)) == immutable["runnerSha256"])
    require("v1 constructor drift", core.file_sha(Path(v1.__file__)) ==
            immutable["v1ConstructorSha256"])
    require("task capsule drift", core.file_sha(core.ROOT / immutable["taskCapsulePath"]) ==
            immutable["taskCapsuleSha256"])
    require("v1 protocol drift", core.file_sha(v1.PROTOCOL) ==
            immutable["closedV1ProtocolSha256"])
    require("v1 summary drift", core.file_sha(v1.SUMMARY) == immutable["v1SummarySha256"])
    require("v1 diagnostic drift", core.file_sha(
        core.ROOT / "summaries/post-v38-fight-local-identity-v1-diagnostic.json") ==
        immutable["v1DiagnosticSha256"])

    repository = Path(immutable["repositoryPath"])
    for ref, expected in immutable["repositoryRefs"].items():
        actual = subprocess.run(
            ["git", "rev-parse", ref], cwd=repository, check=True,
            text=True, capture_output=True,
        ).stdout.strip()
        require(f"repository ref drift: {ref}", actual == expected)
    for source in (BASELINE, CANDIDATE):
        head = subprocess.run(
            ["git", "rev-parse", "HEAD"], cwd=source, check=True,
            text=True, capture_output=True,
        ).stdout.strip()
        require(f"{source.name} source drift", head == immutable["sourceCommit"])
    for source, key in ((BASELINE, "baselineSha256"), (CANDIDATE, "candidateSha256")):
        for name, expected in immutable[key].items():
            require(f"{key} {name} drift", core.file_sha(source / name) == expected)
    godot = immutable["godotBinaryPath"]
    require("Godot binary drift", core.file_sha(Path(godot)) == immutable["godotBinarySha256"])
    version = subprocess.run(
        [godot, "--version"], check=True, text=True, capture_output=True,
    ).stdout.strip()
    require("Godot version drift", version == immutable["godotVersion"])
    content_path = core.CACHE / f"{immutable['contentSha256']}.json"
    require("content drift", core.file_sha(content_path) == immutable["contentSha256"])
    ledger_before = identity.ledger_identity()
    require("ledger freeze drift", ledger_before == protocol["ledgerFreeze"])

    combat_source = (CANDIDATE / "domain/rules/combat.gd").read_text()
    static_faults = [
        label for label, count in (
            ("scoreline producer cardinality",
             combat_source.count("_research421_scoreline_producer(") - 2),
            ("afterimage producer cardinality",
             combat_source.count("_research421_afterimage_producer(") - 2),
            ("post-card consumer cardinality",
             combat_source.count("_research421_after_card(") - 2),
        ) if count != 0
    ]

    cohort_rows = v1.whole_run_rows(protocol)
    scripted_seed = protocol["cohort"]["scriptedSeed"]
    null_rows = reidentify(v1.null_controls(), scripted_seed)
    per_arm = len(cohort_rows) + len(null_rows)
    require("frozen arm size", per_arm == protocol["budget"]["rowsPerNullArm"])
    baseline_rows = cohort_rows + null_rows
    explicit_rows = [dict(row, research421=settings(0, 0)) for row in baseline_rows]
    enabled_rows = reidentify(v1.enabled_controls(), scripted_seed)
    require("enabled direct row count",
            len(enabled_rows) == protocol["budget"]["enabledDirectRows"])

    baseline_plan = {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "arm": "pristine-current-main-v2-cohort",
        "content": str(content_path),
        "rows": baseline_rows,
    }
    candidate_plan = {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "arm": "candidate-v2-null-and-direct-fixed-plan",
        "content": str(content_path),
        "rows": baseline_rows + explicit_rows + enabled_rows,
    }

    started = time.monotonic()
    cap = protocol["budget"]["maximumWallTimeSeconds"]
    invalid_results: dict[str, bool] = {}
    outputs: dict[str, Any] = {}
    execution_error = ""
    try:
        for name, encoded, expected in (
            ("schema-type", {"schemaVersion": 2},
             "requires schemaVersion=fight-local-v2"),
            ("schema-value", {"schemaVersion": "fight-local-v3"},
             "requires schemaVersion=fight-local-v2"),
            ("scoreline-token", {"schemaVersion": "fight-local-v2",
             "scorelinePayoff": "unknown"},
             "scorelinePayoff has unregistered level"),
            ("afterimage-token", {"schemaVersion": "fight-local-v2",
             "afterimagePayoff": "unknown"},
             "afterimagePayoff has unregistered level"),
            ("unknown-key", {"schemaVersion": "fight-local-v2", "unknown": "off"},
             "unknown key unknown"),
            ("settings-type", [], "research421 must be a dictionary"),
        ):
            ok, plan_sha = invalid_configuration_fails(
                protocol_sha, str(content_path), encoded, expected, godot,
                max(1, int(cap - (time.monotonic() - started))), scripted_seed,
            )
            invalid_results[name] = ok
            outputs[f"invalid{name.title().replace('-', '')}PlanSha256"] = plan_sha
        baseline_output, baseline_plan_sha, baseline_output_sha = v1.run_probe(
            BASELINE, BASELINE_PROBE, baseline_plan, godot,
            max(1, int(cap - (time.monotonic() - started))),
        )
        candidate_output, candidate_plan_sha, candidate_output_sha = v1.run_probe(
            CANDIDATE, CANDIDATE_PROBE, candidate_plan, godot,
            max(1, int(cap - (time.monotonic() - started))),
        )
        outputs.update({
            "baselinePlanSha256": baseline_plan_sha,
            "baselineOutputSha256": baseline_output_sha,
            "candidatePlanSha256": candidate_plan_sha,
            "candidateOutputSha256": candidate_output_sha,
        })
    except (RuntimeError, subprocess.TimeoutExpired, OSError) as error:
        execution_error = str(error)

    elapsed = time.monotonic() - started
    faults = list(static_faults)
    identity_counts: dict[str, int] = {}
    observed_rows = 0
    if execution_error:
        boundary = 3
        outcome_class = "inconclusive"
        decision = "record-fight-local-v2-identity-inconclusive-at-cap"
    else:
        baseline_observed = baseline_output["rows"]
        candidate_observed = candidate_output["rows"]
        omitted = candidate_observed[:per_arm]
        explicit = candidate_observed[per_arm:per_arm * 2]
        direct = candidate_observed[per_arm * 2:]
        observed_rows = len(baseline_observed) + len(candidate_observed)
        identity_counts = {
            "baselineVersusOmittedMismatchRows": sum(
                left != v1.without_research_state(right)
                for left, right in zip(baseline_observed, omitted)
            ),
            "omittedVersusExplicitMismatchRows": sum(
                v1.without_research_state(left) != v1.without_research_state(right)
                for left, right in zip(omitted, explicit)
            ),
            "rngMismatchRows": sum(
                not (baseline_observed[i]["rng"] == omitted[i]["rng"] == explicit[i]["rng"])
                for i in range(per_arm)
            ),
        }
        faults.extend(key for key, value in identity_counts.items() if value)
        faults.extend(name for name, ok in invalid_results.items() if not ok)
        explicit_null = {row["id"]: row for row in explicit[len(cohort_rows):]}
        faults.extend(v1.direct_faults(direct, explicit_null))
        if observed_rows != protocol["budget"]["maximumNewSimulatorObservationRows"]:
            faults.append("observation row count")
        if elapsed > cap:
            boundary = 3
            outcome_class = "inconclusive"
            decision = "record-fight-local-v2-identity-inconclusive-at-cap"
        elif faults:
            boundary = 2
            outcome_class = "futility"
            decision = "close-fight-local-v2-representation-without-causal-use"
        else:
            boundary = 1
            outcome_class = "success"
            decision = "freeze-fight-local-v2-representation-for-capacity-preregistration"

    ledger_after = identity.ledger_identity()
    if ledger_after != ledger_before and outcome_class != "inconclusive":
        faults.append("ledger changed")
        boundary = 2
        outcome_class = "futility"
        decision = "close-fight-local-v2-representation-without-causal-use"
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "protocolSha256": protocol_sha,
        "outcomeClass": outcome_class,
        "decisionBoundary": boundary,
        "decision": decision,
        "elapsedSeconds": round(elapsed, 6),
        "observedRows": observed_rows,
        "newLedgerRows": ledger_after["records"] - ledger_before["records"],
        "invalidConfigurationChecks": invalid_results,
        "identityCounts": identity_counts,
        "faults": sorted(set(faults)),
        "executionError": execution_error,
        "outputs": outputs,
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "authority": {
            "success": "Authorises a separately preregistered cheap capacity screen only.",
            "futility": "Closes this categorical representation without rescue or causal use.",
            "inconclusive": "Records the cap; no rerun, cohort change or causal use.",
        },
    }
    SUMMARY.write_text(core.canonical(summary) + "\n")
    print(json.dumps({
        "status": outcome_class.upper(),
        "decision": decision,
        "rows": observed_rows,
        "faults": summary["faults"],
    }, sort_keys=True))


if __name__ == "__main__":
    main()
