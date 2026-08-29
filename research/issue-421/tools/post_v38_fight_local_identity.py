#!/usr/bin/env python3
"""Fight-local representation and null-identity preflight for issue #421."""

from __future__ import annotations

import json
import subprocess
import tempfile
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-fight-local-identity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-fight-local-identity-v1.json"
BASELINE = core.ROOT / "fight-local-sequencing-v1-baseline"
CANDIDATE = core.ROOT / "fight-local-sequencing-v1-source"
BASELINE_PROBE = "res://tools/research_421_fight_local_baseline_probe.gd"
CANDIDATE_PROBE = "res://tools/research_421_fight_local_probe.gd"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(label)


def scripted(
    row_id: str,
    cards: list[str | dict[str, Any]],
    actions: list[dict[str, Any]],
    *,
    aspect: str = "duskblade",
    enemies: list[str] | None = None,
) -> dict[str, Any]:
    return {
        "id": row_id,
        "mode": "scripted",
        "aspect": aspect,
        "seed": 347600,
        "enemyHp": 200,
        "enemies": enemies or ["gravewarden"],
        "cards": cards,
        "actions": actions,
        "policy": {},
    }


def play(card: str, target: int | None = None) -> dict[str, Any]:
    action: dict[str, Any] = {"t": "playCard", "card": card}
    if target is not None:
        action["target"] = target
    return action


def null_controls() -> list[dict[str, Any]]:
    return [
        scripted("null-scoreline-ab", ["chisel", "executioner"],
                 [play("chisel", 0), play("executioner", 0)]),
        scripted("null-afterimage-ab", ["defend", "guardedStrike"],
                 [play("defend"), play("guardedStrike", 0)]),
        scripted("null-joint-anchor",
                 ["chisel", "defend", "executioner", "guardedStrike"],
                 [play("chisel", 0), play("defend"), play("executioner", 0),
                  play("guardedStrike", 0)]),
        scripted("null-scoreline-wrong-target", ["chisel", "executioner"],
                 [play("chisel", 0), play("executioner", 1)],
                 enemies=["gravewarden", "gravewarden"]),
        scripted("null-scoreline-target-expiry", ["chisel", "strike"],
                 [play("chisel", 0), {"t": "setEnemyHp", "idx": 0, "hp": 1},
                  play("strike", 0)], enemies=["gravewarden", "gravewarden"]),
        scripted("null-scoreline-combat-expiry", ["chisel"],
                 [play("chisel", 0), {"t": "loseCombat"}]),
        scripted("null-afterimage-turn-expiry", ["defend"],
                 [play("defend"), {"t": "endTurn"}]),
        scripted("null-afterimage-combat-expiry", ["defend"],
                 [play("defend"), {"t": "loseCombat"}]),
        scripted("null-ash-joint", ["chisel", "defend", "executioner", "guardedStrike"],
                 [play("chisel", 0), play("defend"), play("executioner", 0),
                  play("guardedStrike", 0)], aspect="ashwarden"),
    ]


def with_settings(row: dict[str, Any], scoreline: int, afterimage: int) -> dict[str, Any]:
    result = dict(row)
    result["research421"] = {
        "schemaVersion": 1,
        "scorelineDamage": scoreline,
        "afterimageWardCap": afterimage,
    }
    return result


def enabled_controls() -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []

    def add(row: dict[str, Any], scoreline: int = 0, afterimage: int = 0) -> None:
        rows.append(with_settings(row, scoreline, afterimage))

    add(scripted("scoreline-a-6", ["chisel"], [play("chisel", 0)]), 6)
    add(scripted("scoreline-b-6", ["executioner"], [play("executioner", 0)]), 6)
    for value in (4, 6, 8):
        add(scripted(f"scoreline-ab-{value}", ["chisel", "executioner"],
                     [play("chisel", 0), play("executioner", 0)]), value)
    add(scripted("scoreline-ba-6", ["executioner", "chisel"],
                 [play("executioner", 0), play("chisel", 0)]), 6)
    add(scripted("scoreline-wrong-target-6", ["chisel", "executioner"],
                 [play("chisel", 0), play("executioner", 1)],
                 enemies=["gravewarden", "gravewarden"]), 6)
    add(scripted("scoreline-replace-6", ["chisel", "chisel"],
                 [play("chisel", 0), play("chisel", 0)]), 6)
    add(scripted("scoreline-target-expiry-6", ["chisel", "strike"],
                 [play("chisel", 0), {"t": "setEnemyHp", "idx": 0, "hp": 1},
                  play("strike", 0)], enemies=["gravewarden", "gravewarden"]), 6)
    add(scripted("scoreline-combat-expiry-6", ["chisel"],
                 [play("chisel", 0), {"t": "loseCombat"}]), 6)
    add(scripted("scoreline-ash-ab-6", ["chisel", "executioner"],
                 [play("chisel", 0), play("executioner", 0)], aspect="ashwarden"), 6)

    add(scripted("afterimage-a-5", ["defend"], [play("defend")]), afterimage=5)
    add(scripted("afterimage-b-5", ["guardedStrike"],
                 [play("guardedStrike", 0)]), afterimage=5)
    add(scripted("afterimage-ab-4", ["defend", "guardedStrike"],
                 [play("defend"), play("guardedStrike", 0)]), afterimage=4)
    add(scripted("afterimage-ab-5", ["defend", "guardedStrike"],
                 [play("defend"), play("guardedStrike", 0)]), afterimage=5)
    add(scripted("afterimage-ab-8-up", [{"id": "defend", "up": True}, "guardedStrike"],
                 [play("defend"), play("guardedStrike", 0)]), afterimage=8)
    add(scripted("afterimage-ba-5", ["guardedStrike", "defend"],
                 [play("guardedStrike", 0), play("defend")]), afterimage=5)
    add(scripted("afterimage-replace-8",
                 ["defend", {"id": "defend", "up": True}],
                 [play("defend"), play("defend")]), afterimage=8)
    add(scripted("afterimage-turn-expiry-5", ["defend"],
                 [play("defend"), {"t": "endTurn"}]), afterimage=5)
    add(scripted("afterimage-combat-expiry-5", ["defend"],
                 [play("defend"), {"t": "loseCombat"}]), afterimage=5)
    add(scripted("afterimage-ash-ab-5", ["defend", "guardedStrike"],
                 [play("defend"), play("guardedStrike", 0)], aspect="ashwarden"),
        afterimage=5)

    add(scripted("independence-scoreline-only-after-path", ["defend", "guardedStrike"],
                 [play("defend"), play("guardedStrike", 0)]), scoreline=6)
    add(scripted("independence-afterimage-only-scoreline-path", ["chisel", "executioner"],
                 [play("chisel", 0), play("executioner", 0)]), afterimage=5)
    add(scripted("joint-anchor-6-5",
                 ["chisel", "defend", "executioner", "guardedStrike"],
                 [play("chisel", 0), play("defend"), play("executioner", 0),
                  play("guardedStrike", 0)]), scoreline=6, afterimage=5)
    return rows


def whole_run_rows(protocol: dict[str, Any]) -> list[dict[str, Any]]:
    cohort = protocol["cohort"]
    return [
        {
            "id": f"whole-{policy_index}-{seed}",
            "mode": "whole-run",
            "aspect": cohort["aspect"],
            "vow": cohort["vow"],
            "seed": seed,
            "policyRoot": cohort["policyRoot"],
            "policyIndex": policy_index,
        }
        for policy_index in range(cohort["policyCount"])
        for seed in cohort["simulationSeeds"]
    ]


def run_probe(
    source: Path,
    probe: str,
    plan: dict[str, Any],
    godot: str,
    timeout: int,
) -> tuple[dict[str, Any], str, str]:
    plan_sha, plan_path = core.cache_json(plan)
    with tempfile.TemporaryDirectory(prefix="issue-421-fight-local-") as tmp:
        out = Path(tmp) / "output.json"
        result = subprocess.run(
            [godot, "--headless", "-s", probe, "--",
             f"--plan={plan_path}", f"--out={out}"],
            cwd=source, text=True, capture_output=True, timeout=timeout,
        )
        if result.returncode or not out.is_file():
            raise RuntimeError(
                f"probe failed ({result.returncode})\n"
                f"{result.stdout[-2000:]}\n{result.stderr[-4000:]}"
            )
        output = json.loads(out.read_text())
    output_sha, _ = core.cache_json(output)
    return output, plan_sha, output_sha


def invalid_configuration_fails(
    protocol_sha: str,
    content: str,
    settings: Any,
    expected: str,
    godot: str,
    timeout: int,
) -> tuple[bool, str]:
    row = scripted("invalid", ["defend"], [play("defend")])
    row["research421"] = settings
    plan = {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "content": content,
        "rows": [row],
    }
    plan_sha, plan_path = core.cache_json(plan)
    with tempfile.TemporaryDirectory(prefix="issue-421-fight-local-invalid-") as tmp:
        out = Path(tmp) / "output.json"
        result = subprocess.run(
            [godot, "--headless", "-s", CANDIDATE_PROBE, "--",
             f"--plan={plan_path}", f"--out={out}"],
            cwd=CANDIDATE, text=True, capture_output=True, timeout=timeout,
        )
        output_created = out.exists()
    return result.returncode != 0 and not output_created and expected in result.stderr, plan_sha


def without_research_state(row: dict[str, Any]) -> dict[str, Any]:
    result = dict(row)
    result.pop("research421", None)
    return result


def events(row: dict[str, Any], kind: str) -> list[dict[str, Any]]:
    return [event for event in row["queue"] if event.get("t") == kind]


def stages(row: dict[str, Any], kind: str) -> list[str]:
    return [str(event["stage"]) for event in events(row, kind)]


def direct_faults(rows: list[dict[str, Any]], explicit_null: dict[str, dict[str, Any]]) -> list[str]:
    by_id = {row["id"]: row for row in rows}
    faults: list[str] = []

    def check(label: str, condition: bool) -> None:
        if not condition:
            faults.append(label)

    score = "research421Scoreline"
    after = "research421Afterimage"
    check("scoreline-A", stages(by_id["scoreline-a-6"], score) ==
          ["producer", "mediator-set"])
    check("scoreline-B", not events(by_id["scoreline-b-6"], score))
    for value in (4, 6, 8):
        row = by_id[f"scoreline-ab-{value}"]
        check(f"scoreline-AB-{value}", stages(row, score) ==
              ["producer", "mediator-set", "consumer", "mediator-consume", "payoff"])
        payoff = events(row, score)[-1]
        check(f"scoreline-value-{value}",
              payoff.get("requested") == value and payoff.get("realised") == value)
    check("scoreline-BA", stages(by_id["scoreline-ba-6"], score) ==
          ["producer", "mediator-set"])
    check("scoreline-wrong-target", stages(by_id["scoreline-wrong-target-6"], score) ==
          ["producer", "mediator-set"])
    replace = events(by_id["scoreline-replace-6"], score)
    check("scoreline-replacement", stages(by_id["scoreline-replace-6"], score) ==
          ["producer", "mediator-set", "producer", "mediator-set"] and
          replace[-1].get("replaced") is True)
    target_expiry = events(by_id["scoreline-target-expiry-6"], score)
    check("scoreline-target-expiry", [event["stage"] for event in target_expiry] ==
          ["producer", "mediator-set", "expiry"] and
          target_expiry[-1].get("reason") == "target-death")
    combat_expiry = events(by_id["scoreline-combat-expiry-6"], score)
    check("scoreline-combat-expiry", [event["stage"] for event in combat_expiry] ==
          ["producer", "mediator-set", "expiry"] and
          combat_expiry[-1].get("reason") == "combat-end")
    check("scoreline-Ash-null", not events(by_id["scoreline-ash-ab-6"], score))

    check("afterimage-A", stages(by_id["afterimage-a-5"], after) ==
          ["producer", "mediator-set"])
    check("afterimage-B", not events(by_id["afterimage-b-5"], after))
    for row_id, value in (("afterimage-ab-4", 4), ("afterimage-ab-5", 5),
                          ("afterimage-ab-8-up", 8)):
        row = by_id[row_id]
        check(row_id, stages(row, after) ==
              ["producer", "mediator-set", "consumer", "mediator-consume", "payoff"])
        payoff = events(row, after)[-1]
        check(f"{row_id}-value", payoff.get("requested") == value and
              payoff.get("realised") == value)
    check("afterimage-BA", stages(by_id["afterimage-ba-5"], after) ==
          ["producer", "mediator-set"])
    replace = events(by_id["afterimage-replace-8"], after)
    check("afterimage-replacement", stages(by_id["afterimage-replace-8"], after) ==
          ["producer", "mediator-set", "producer", "mediator-set"] and
          replace[-1].get("replaced") is True and replace[-1].get("value") == 8)
    turn_expiry = events(by_id["afterimage-turn-expiry-5"], after)
    check("afterimage-turn-expiry", [event["stage"] for event in turn_expiry] ==
          ["producer", "mediator-set", "expiry"] and
          turn_expiry[-1].get("reason") == "player-turn-end")
    combat_expiry = events(by_id["afterimage-combat-expiry-5"], after)
    check("afterimage-combat-expiry", [event["stage"] for event in combat_expiry] ==
          ["producer", "mediator-set", "expiry"] and
          combat_expiry[-1].get("reason") == "combat-end")
    check("afterimage-Ash-null", not events(by_id["afterimage-ash-ab-5"], after))
    check("scoreline-factor-isolation", not events(
        by_id["independence-scoreline-only-after-path"], after))
    check("afterimage-factor-isolation", not events(
        by_id["independence-afterimage-only-scoreline-path"], score))

    joint = by_id["joint-anchor-6-5"]
    check("joint-scoreline", stages(joint, score) ==
          ["producer", "mediator-set", "consumer", "mediator-consume", "payoff"])
    check("joint-afterimage", stages(joint, after) ==
          ["producer", "mediator-set", "consumer", "mediator-consume", "payoff"])
    check("joint-values", events(joint, score)[-1].get("realised") == 6 and
          events(joint, after)[-1].get("realised") == 5)
    check("joint-scoreline-no-direct-interference",
          events(joint, score) == events(by_id["scoreline-ab-6"], score))
    check("joint-afterimage-no-direct-interference",
          events(joint, after) == events(by_id["afterimage-ab-5"], after))

    comparisons = (
        ("scoreline-ab-6", "null-scoreline-ab", 2),
        ("afterimage-ab-5", "null-afterimage-ab", 2),
        ("joint-anchor-6-5", "null-joint-anchor", 3),
    )
    for enabled_id, null_id, comparable_choices in comparisons:
        enabled = by_id[enabled_id]
        null = explicit_null[null_id]
        check(f"{enabled_id}-rng", enabled["rng"] == null["rng"])
        check(f"{enabled_id}-policy-before-payoff",
              enabled["policyChoices"][:comparable_choices] ==
              null["policyChoices"][:comparable_choices])
    return faults


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the fight-local identity summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    immutable = protocol["immutableInputs"]
    require("runner SHA drift", core.file_sha(Path(__file__)) == immutable["runnerSha256"])
    require("task capsule drift", core.file_sha(core.ROOT / immutable["taskCapsulePath"]) ==
            immutable["taskCapsuleSha256"])
    repository = Path(immutable["repositoryPath"])
    for ref, expected in (
        ("refs/remotes/origin/main", immutable["resolvedMain"]),
        ("refs/heads/research/issue-421-p9-recovery-evidence", immutable["archiveHead"]),
        ("refs/remotes/origin/research/issue-421-p9-recovery-evidence",
         immutable["archiveHead"]),
    ):
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
    for path, expected in immutable["baselineSha256"].items():
        require(f"baseline {path} drift", core.file_sha(BASELINE / path) == expected)
    for path, expected in immutable["candidateSha256"].items():
        require(f"candidate {path} drift", core.file_sha(CANDIDATE / path) == expected)
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
            ("scoreline producer cardinality", combat_source.count(
                "_research421_scoreline_producer(") - 2),
            ("afterimage producer cardinality", combat_source.count(
                "_research421_afterimage_producer(") - 2),
            ("post-card consumer cardinality", combat_source.count(
                "_research421_after_card(") - 2),
        ) if count != 0
    ]

    cohort_rows = whole_run_rows(protocol)
    null_rows = null_controls()
    per_arm = len(cohort_rows) + len(null_rows)
    require("frozen arm size", per_arm == protocol["budget"]["rowsPerNullArm"])
    baseline_rows = cohort_rows + null_rows
    explicit_settings = {"schemaVersion": 1, "scorelineDamage": 0, "afterimageWardCap": 0}
    explicit_rows = [dict(row, research421=explicit_settings) for row in baseline_rows]
    enabled_rows = enabled_controls()
    require("enabled direct row count",
            len(enabled_rows) == protocol["budget"]["enabledDirectRows"])

    baseline_plan = {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "arm": "pristine-current-main",
        "content": str(content_path),
        "rows": baseline_rows,
    }
    candidate_plan = {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "arm": "candidate-null-and-direct-fixed-plan",
        "content": str(content_path),
        "rows": baseline_rows + explicit_rows + enabled_rows,
    }

    started = time.monotonic()
    cap = protocol["budget"]["maximumWallTimeSeconds"]
    invalid_results: dict[str, bool] = {}
    outputs: dict[str, Any] = {}
    execution_error = ""
    try:
        for name, settings, expected in (
            ("schema", {"schemaVersion": 2}, "requires schemaVersion=1"),
            ("scoreline-level", {"schemaVersion": 1, "scorelineDamage": 7},
             "scorelineDamage has unregistered level"),
            ("afterimage-level", {"schemaVersion": 1, "afterimageWardCap": 6},
             "afterimageWardCap has unregistered level"),
            ("unknown-key", {"schemaVersion": 1, "unknown": 1}, "unknown key unknown"),
            ("wrong-type", [], "research421 must be a dictionary"),
        ):
            ok, plan_sha = invalid_configuration_fails(
                protocol_sha, str(content_path), settings, expected, godot,
                max(1, int(cap - (time.monotonic() - started))),
            )
            invalid_results[name] = ok
            outputs[f"invalid{name.title().replace('-', '')}PlanSha256"] = plan_sha
        baseline_output, baseline_plan_sha, baseline_output_sha = run_probe(
            BASELINE, BASELINE_PROBE, baseline_plan, godot,
            max(1, int(cap - (time.monotonic() - started))),
        )
        candidate_output, candidate_plan_sha, candidate_output_sha = run_probe(
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
        decision = "record-fight-local-identity-inconclusive-at-cap"
    else:
        baseline_observed = baseline_output["rows"]
        candidate_observed = candidate_output["rows"]
        omitted = candidate_observed[:per_arm]
        explicit = candidate_observed[per_arm:per_arm * 2]
        direct = candidate_observed[per_arm * 2:]
        observed_rows = len(baseline_observed) + len(candidate_observed)
        identity_counts = {
            "baselineVersusOmittedMismatchRows": sum(
                left != without_research_state(right)
                for left, right in zip(baseline_observed, omitted)
            ),
            "omittedVersusExplicitMismatchRows": sum(
                without_research_state(left) != without_research_state(right)
                for left, right in zip(omitted, explicit)
            ),
            "rngMismatchRows": sum(
                not (baseline_observed[i]["rng"] == omitted[i]["rng"] == explicit[i]["rng"])
                for i in range(per_arm)
            ),
        }
        faults.extend(key for key, value in identity_counts.items() if value)
        faults.extend(name for name, ok in invalid_results.items() if not ok)
        explicit_null = {
            row["id"]: row for row in explicit[len(cohort_rows):]
        }
        faults.extend(direct_faults(direct, explicit_null))
        if observed_rows != protocol["budget"]["maximumNewSimulatorObservationRows"]:
            faults.append("observation row count")
        if elapsed > cap:
            boundary = 3
            outcome_class = "inconclusive"
            decision = "record-fight-local-identity-inconclusive-at-cap"
        elif faults:
            boundary = 2
            outcome_class = "futility"
            decision = "close-fight-local-representation-without-causal-use"
        else:
            boundary = 1
            outcome_class = "success"
            decision = "freeze-fight-local-representation-for-capacity-preregistration"

    ledger_after = identity.ledger_identity()
    if ledger_after != ledger_before and outcome_class != "inconclusive":
        faults.append("ledger changed")
        boundary = 2
        outcome_class = "futility"
        decision = "close-fight-local-representation-without-causal-use"
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
            "futility": "Closes this exact representation without repair or causal use.",
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
