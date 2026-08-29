#!/usr/bin/env python3
"""Identity preflight for the single issue #421 Afterimage order control."""

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


PROTOCOL = core.ROOT / "protocols/post-v38-afterimage-order-identity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-afterimage-order-identity-v1.json"
BASELINE = core.ROOT / "afterimage-order-v1-baseline"
CANDIDATE = core.ROOT / "afterimage-order-v1-source"
BASELINE_PROBE = "res://tools/research_421_afterimage_order_baseline_probe.gd"
CANDIDATE_PROBE = "res://tools/research_421_afterimage_order_probe.gd"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(label)


def settings(
    afterimage: str = "off",
    order: str = "current",
    scoreline: str = "off",
) -> dict[str, str]:
    return {
        "schemaVersion": "fight-local-order-v1",
        "scorelinePayoff": scoreline,
        "afterimagePayoff": afterimage,
        "afterimageOrder": order,
    }


def direct_rows(scripted_seed: int) -> list[dict[str, Any]]:
    specs = (
        ("eligible", ["defend", "guardedStrike"], [{"t": "pilotCards"}],
         "duskblade", 2, 99, "off"),
        ("insufficient-energy", ["defend", "guardedStrike"], [{"t": "pilotCards"}],
         "duskblade", 1, 99, "off"),
        ("no-defend", ["guardedStrike", "strike"], [{"t": "pilotCards"}],
         "duskblade", 2, 99, "off"),
        ("no-guarded-strike", ["defend", "strike"], [{"t": "pilotCards"}],
         "duskblade", 2, 99, "off"),
        ("ash", ["defend", "guardedStrike"], [{"t": "pilotCards"}],
         "ashwarden", 2, 99, "off"),
        ("mediator-occupied", ["defend", "guardedStrike"],
         [{"t": "setAfterimageWard", "value": 5}, {"t": "pilotCards"}],
         "duskblade", 2, 99, "off"),
        ("scoreline-anchor", ["defend", "guardedStrike"], [{"t": "pilotCards"}],
         "duskblade", 2, 99, "faultline-bonus-6"),
    )
    rows: list[dict[str, Any]] = []
    for name, cards, actions, aspect, energy, block, scoreline in specs:
        for order in ("current", "ward-before-edge"):
            row = v1.scripted(f"{name}-{order}", cards, actions, aspect=aspect)
            row.update({
                "seed": scripted_seed,
                "playerEnergy": energy,
                "playerBlock": block,
                "research421": settings("ward-base-5", order, scoreline),
            })
            rows.append(row)
    return rows


def invalid_configuration_fails(
    protocol_sha: str,
    content: str,
    encoded: Any,
    expected: str,
    godot: str,
    timeout: int,
    scripted_seed: int,
) -> tuple[bool, str]:
    row = v1.scripted("invalid-order-v1", ["defend"], [v1.play("defend")])
    row["seed"] = scripted_seed
    row["research421"] = encoded
    plan = {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "content": content,
        "rows": [row],
    }
    plan_sha, plan_path = core.cache_json(plan)
    with tempfile.TemporaryDirectory(prefix="issue-421-afterimage-order-invalid-") as tmp:
        out = Path(tmp) / "output.json"
        result = subprocess.run(
            [godot, "--headless", "-s", CANDIDATE_PROBE, "--",
             f"--plan={plan_path}", f"--out={out}"],
            cwd=CANDIDATE, text=True, capture_output=True, timeout=timeout,
        )
        output_created = out.exists()
    return result.returncode != 0 and not output_created and expected in result.stderr, plan_sha


def events(row: dict[str, Any], kind: str) -> list[dict[str, Any]]:
    return [event for event in row["queue"] if event.get("t") == kind]


def stages(row: dict[str, Any], kind: str) -> list[str]:
    return [str(event["stage"]) for event in events(row, kind)]


def plays(row: dict[str, Any]) -> list[str]:
    return [str(event["id"]) for event in row["queue"] if event.get("t") == "play"]


def without_id(row: dict[str, Any]) -> dict[str, Any]:
    result = copy.deepcopy(row)
    result.pop("id", None)
    return result


def direct_faults(rows: list[dict[str, Any]]) -> list[str]:
    by_id = {row["id"]: row for row in rows}
    faults: list[str] = []

    def check(label: str, condition: bool) -> None:
        if not condition:
            faults.append(label)

    pair_names = (
        "eligible", "insufficient-energy", "no-defend", "no-guarded-strike",
        "ash", "mediator-occupied", "scoreline-anchor",
    )
    for name in pair_names:
        current = by_id[f"{name}-current"]
        enabled = by_id[f"{name}-ward-before-edge"]
        check(f"{name}-rng", current["rng"] == enabled["rng"])

    current = by_id["eligible-current"]
    enabled = by_id["eligible-ward-before-edge"]
    current_choice = current["policyChoices"][0]
    enabled_choice = enabled["policyChoices"][0]
    check("eligible-current-choice",
          current_choice["chosen"] == "guardedStrike" and
          current_choice["research421AfterimageOrder"] is False)
    check("eligible-enabled-choice",
          enabled_choice["chosen"] == "defend" and
          enabled_choice["research421AfterimageOrder"] is True)
    check("eligible-score-invariance",
          current_choice["scores"] == enabled_choice["scores"])
    check("eligible-current-path", plays(current) == ["guardedStrike"])
    check("eligible-enabled-path", plays(enabled) == ["defend", "guardedStrike"])
    check("eligible-current-no-afterimage",
          not events(current, "research421Afterimage"))
    check("eligible-enabled-mediator",
          stages(enabled, "research421Afterimage") ==
          ["producer", "mediator-set", "consumer", "mediator-consume", "payoff"])
    payoff = events(enabled, "research421Afterimage")[-1]
    check("eligible-payoff-value",
          payoff.get("requested") == 5 and payoff.get("realised") == 5)
    check("eligible-intervention-telemetry",
          len(events(enabled, "research421AfterimageOrder")) == 1 and
          not events(current, "research421AfterimageOrder"))

    for name in (
        "insufficient-energy", "no-defend", "no-guarded-strike", "ash",
        "mediator-occupied",
    ):
        check(f"{name}-exact-null",
              without_id(by_id[f"{name}-current"]) ==
              without_id(by_id[f"{name}-ward-before-edge"]))
        check(f"{name}-no-intervention",
              not events(by_id[f"{name}-ward-before-edge"],
                         "research421AfterimageOrder"))

    occupied = by_id["mediator-occupied-ward-before-edge"]
    check("mediator-occupied-consumer",
          stages(occupied, "research421Afterimage") ==
          ["consumer", "mediator-consume", "payoff"])
    check("mediator-occupied-choice",
          occupied["policyChoices"][0]["chosen"] == "guardedStrike")

    ash = by_id["ash-ward-before-edge"]
    check("ash-mechanism-null",
          not events(ash, "research421Afterimage") and
          not events(ash, "research421AfterimageOrder"))

    joint_current = by_id["scoreline-anchor-current"]
    joint_enabled = by_id["scoreline-anchor-ward-before-edge"]
    check("scoreline-anchor-current-no-interference",
          without_id(joint_current) == without_id(current))
    check("scoreline-anchor-enabled-no-interference",
          without_id(joint_enabled) == without_id(enabled))
    check("scoreline-anchor-no-scoreline-events",
          not events(joint_current, "research421Scoreline") and
          not events(joint_enabled, "research421Scoreline"))
    return faults


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the Afterimage order identity summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    immutable = protocol["immutableInputs"]
    require("runner SHA drift", core.file_sha(Path(__file__)) == immutable["runnerSha256"])
    require("task capsule drift", core.file_sha(core.ROOT / immutable["taskCapsulePath"]) ==
            immutable["taskCapsuleSha256"])
    for path, expected in immutable["predecessorSha256"].items():
        require(f"predecessor drift: {path}",
                core.file_sha(core.ROOT / path) == expected)
    previous_identity = json.loads(
        (core.ROOT / "summaries/post-v38-fight-local-identity-v2.json").read_text()
    )
    previous_capacity = json.loads(
        (core.ROOT / "summaries/post-v38-fight-local-capacity-v1.json").read_text()
    )
    decomposition = json.loads(
        (core.ROOT / "summaries/post-v38-fight-local-capacity-decomposition-v1.json").read_text()
    )
    require("v2 identity not frozen success",
            previous_identity.get("outcomeClass") == "success")
    require("capacity closure drift",
            previous_capacity.get("decision") == "close-fight-local-v2-at-capacity")
    require("order-control selection drift",
            decomposition.get("decision") == "select-one-afterimage-ward-before-edge-control")

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

    pilot_source = (CANDIDATE / "tools/balance_pilot.gd").read_text()
    static_faults = []
    if pilot_source.count("_research421_afterimage_pick(") != 2:
        static_faults.append("order-pick call cardinality")
    if pilot_source.count('"t": &"research421AfterimageOrder"') != 1:
        static_faults.append("order-intervention telemetry cardinality")

    cohort_rows = v1.whole_run_rows(protocol)
    scripted_seed = protocol["cohort"]["scriptedSeed"]
    null_rows = copy.deepcopy(v1.null_controls())
    for row in null_rows:
        row["seed"] = scripted_seed
    per_arm = len(cohort_rows) + len(null_rows)
    require("frozen null arm size", per_arm == protocol["budget"]["rowsPerNullArm"])
    baseline_rows = cohort_rows + null_rows
    explicit_rows = [
        dict(row, research421=settings()) for row in copy.deepcopy(baseline_rows)
    ]
    enabled_direct = direct_rows(scripted_seed)
    require("frozen direct row count",
            len(enabled_direct) == protocol["budget"]["enabledDirectRows"])

    baseline_plan = {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "arm": "pristine-current-main-order-v1-cohort",
        "content": str(content_path),
        "rows": baseline_rows,
    }
    candidate_plan = {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "arm": "candidate-order-v1-null-and-direct-fixed-plan",
        "content": str(content_path),
        "rows": baseline_rows + explicit_rows + enabled_direct,
    }

    started = time.monotonic()
    cap = protocol["budget"]["maximumWallTimeSeconds"]
    invalid_results: dict[str, bool] = {}
    outputs: dict[str, str] = {}
    execution_error = ""
    try:
        invalid_cases = (
            ("schema-type", {"schemaVersion": 1},
             "requires schemaVersion=fight-local-order-v1"),
            ("schema-value", {"schemaVersion": "fight-local-v2"},
             "requires schemaVersion=fight-local-order-v1"),
            ("scoreline-token", {"schemaVersion": "fight-local-order-v1",
             "scorelinePayoff": "unknown"},
             "scorelinePayoff has unregistered level"),
            ("afterimage-token", {"schemaVersion": "fight-local-order-v1",
             "afterimagePayoff": "unknown"},
             "afterimagePayoff has unregistered level"),
            ("order-token", {"schemaVersion": "fight-local-order-v1",
             "afterimageOrder": "unknown"},
             "afterimageOrder has unregistered level"),
            ("order-without-payoff", {"schemaVersion": "fight-local-order-v1",
             "afterimagePayoff": "off", "afterimageOrder": "ward-before-edge"},
             "ward-before-edge requires Afterimage payoff"),
            ("unknown-key", {"schemaVersion": "fight-local-order-v1",
             "unknown": "off"}, "unknown key unknown"),
            ("settings-type", [], "research421 must be a dictionary"),
        )
        for name, encoded, expected in invalid_cases:
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
        decision = "record-afterimage-order-identity-inconclusive-at-cap"
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
        faults.extend(direct_faults(direct))
        if observed_rows != protocol["budget"]["maximumNewSimulatorObservationRows"]:
            faults.append("observation row count")
        if elapsed > cap:
            boundary = 3
            outcome_class = "inconclusive"
            decision = "record-afterimage-order-identity-inconclusive-at-cap"
        elif faults:
            boundary = 2
            outcome_class = "futility"
            decision = "close-afterimage-order-v1-without-capacity-use"
        else:
            boundary = 1
            outcome_class = "success"
            decision = "freeze-afterimage-order-v1-for-capacity-preregistration"

    ledger_after = identity.ledger_identity()
    if ledger_after != ledger_before and outcome_class != "inconclusive":
        faults.append("ledger changed")
        boundary = 2
        outcome_class = "futility"
        decision = "close-afterimage-order-v1-without-capacity-use"
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
            "success": "Authorises a separately preregistered Afterimage capacity screen only.",
            "futility": "Closes this order representation without rescue and continues inside #421.",
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
