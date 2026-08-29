#!/usr/bin/env python3
"""Identity preflight for the issue #421 Scoreline component control."""

from __future__ import annotations

import copy
import json
import subprocess
import tempfile
import time
from pathlib import Path
from typing import Any

import post_v38_fight_local_identity as v1
import post_v38_knob_identity as ledger
import post_v38_scoreline_commitment_identity_v1 as commitment
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-scoreline-component-identity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-scoreline-component-identity-v1.json"
BASELINE = commitment.BASELINE
CANDIDATE = core.ROOT / "scoreline-component-v1-source"
BASELINE_PROBE = commitment.BASELINE_PROBE
CANDIDATE_PROBE = commitment.CANDIDATE_PROBE


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(label)


def settings(payoff: str = "off", oath: str = "none") -> dict[str, str]:
    return {
        "schemaVersion": "scoreline-component-v1",
        "scorelinePayoff": payoff,
        "scorelineCommitment": oath,
    }


def direct_rows(scripted_seed: int) -> list[dict[str, Any]]:
    rows = [
        v1.scripted("assignment-only-ab", ["chisel", "executioner"],
                    [v1.play("chisel", 0), v1.play("executioner", 0)]),
        v1.scripted("full-ab", ["chisel", "executioner"],
                    [v1.play("chisel", 0), v1.play("executioner", 0)]),
        v1.scripted(
            "assignment-only-ash",
            ["chisel", "defend", "executioner", "guardedStrike"],
            [v1.play("chisel", 0), v1.play("defend"), v1.play("executioner", 0),
             v1.play("guardedStrike", 0)], aspect="ashwarden",
        ),
        v1.scripted(
            "full-ash",
            ["chisel", "defend", "executioner", "guardedStrike"],
            [v1.play("chisel", 0), v1.play("defend"), v1.play("executioner", 0),
             v1.play("guardedStrike", 0)], aspect="ashwarden",
        ),
    ]
    for row in rows:
        row["seed"] = scripted_seed
    rows[0]["research421"] = settings("off", "scoreline-oath")
    rows[1]["research421"] = settings("faultline-bonus-6", "scoreline-oath")
    rows[2]["research421"] = settings("off", "scoreline-oath")
    rows[3]["research421"] = settings("faultline-bonus-6", "scoreline-oath")
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
    row = v1.scripted("invalid-component-v1", ["chisel"], [v1.play("chisel", 0)])
    row["seed"] = scripted_seed
    row["research421"] = encoded
    plan = {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "content": content,
        "rows": [row],
    }
    plan_sha, plan_path = core.cache_json(plan)
    with tempfile.TemporaryDirectory(prefix="issue-421-scoreline-component-invalid-") as tmp:
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


def normalise(row: dict[str, Any], *, drop_id: bool = False) -> dict[str, Any]:
    result = copy.deepcopy(row)
    result.pop("research421", None)
    if drop_id:
        result.pop("id", None)
    return result


def direct_faults(
    rows: list[dict[str, Any]], gate_nulls: dict[str, dict[str, Any]]
) -> list[str]:
    by_id = {row["id"]: row for row in rows}
    faults: list[str] = []

    def check(label: str, condition: bool) -> None:
        if not condition:
            faults.append(label)

    base = gate_nulls["null-scoreline-ab"]["commitment"]
    assignment = by_id["assignment-only-ab"]
    full = by_id["full-ab"]
    assigned = assignment["commitment"]
    check("identical-assignment", assigned == full["commitment"])
    check("assignment-relic", assigned["relics"] == base["relics"] + [commitment.OATH])
    check("assignment-deck", assigned["deckIds"] == base["deckIds"] + ["executioner"])
    check("assignment-deck-uids", assigned["deckUids"][:-1] == base["deckUids"] and
          assigned["deckUids"][-1] == base["reloadUid"])
    check("assignment-delta", assigned["deckDelta"] == 1 and assigned["uidDelta"] == 1)
    check("assignment-no-rng", assigned["rngBefore"] == assigned["rngAfter"] ==
          base["rngBefore"] == base["rngAfter"])
    check("assignment-save", assigned["reloadOk"] is True and
          assigned["reloadRelics"] == assigned["relics"] and
          assigned["reloadDeckIds"] == assigned["deckIds"] and
          assigned["reloadDeckUids"] == assigned["deckUids"] and
          assigned["reloadUid"] == base["reloadUid"] + 1)

    kind = "research421Scoreline"
    check("assignment-only-no-scoreline", not events(assignment, kind))
    check("full-scoreline-path", stages(full, kind) ==
          ["producer", "mediator-set", "consumer", "mediator-consume", "payoff"])
    payoff = events(full, kind)[-1]
    check("full-scoreline-payoff", payoff.get("requested") == 6 and
          payoff.get("realised") == 6)
    check("component-policy-identity", assignment["policyChoices"] == full["policyChoices"])
    check("component-rng-identity", assignment["rng"] == full["rng"])

    ash_assignment = by_id["assignment-only-ash"]
    ash_full = by_id["full-ash"]
    ash_null = gate_nulls["null-ash-joint"]
    check("ash-assignment-exact-null", normalise(ash_assignment, drop_id=True) ==
          normalise(ash_null, drop_id=True))
    check("ash-full-exact-null", normalise(ash_full, drop_id=True) ==
          normalise(ash_null, drop_id=True))
    check("ash-no-scoreline", not events(ash_assignment, kind) and not events(ash_full, kind))
    check("afterimage-absent", all(not events(row, "research421Afterimage")
                                    for row in rows))
    return faults


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the Scoreline component identity summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    immutable = protocol["immutableInputs"]
    require("runner SHA drift", core.file_sha(Path(__file__)) == immutable["runnerSha256"])
    require("task capsule drift", core.file_sha(core.ROOT / immutable["taskCapsulePath"]) ==
            immutable["taskCapsuleSha256"])
    for path, expected in immutable["predecessorSha256"].items():
        require(f"predecessor drift: {path}", core.file_sha(core.ROOT / path) == expected)
    capacity = json.loads(
        (core.ROOT / "summaries/post-v38-scoreline-commitment-capacity-v1.json").read_text()
    )
    decomposition = json.loads(
        (core.ROOT /
         "summaries/post-v38-scoreline-commitment-capacity-decomposition-v1.json").read_text()
    )
    require("capacity gate not passed", capacity.get("outcomeClass") == "success")
    require("component-control selection drift", decomposition.get("decision") ==
            "select-three-arm-scoreline-component-control")

    repository = Path(immutable["repositoryPath"])
    for ref, expected in immutable["repositoryRefs"].items():
        actual = subprocess.run(
            ["git", "rev-parse", ref], cwd=repository, check=True,
            text=True, capture_output=True,
        ).stdout.strip()
        require(f"repository ref drift: {ref}", actual == expected)
    for source, expected_head in (
        (BASELINE, immutable["baselineHead"]),
        (CANDIDATE, immutable["candidateHead"]),
    ):
        head = subprocess.run(
            ["git", "rev-parse", "HEAD"], cwd=source, check=True,
            text=True, capture_output=True,
        ).stdout.strip()
        require(f"{source.name} head drift", head == expected_head)
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
    ledger_before = ledger.ledger_identity()
    require("ledger freeze drift", ledger_before == protocol["ledgerFreeze"])

    combat_source = (CANDIDATE / "domain/rules/combat.gd").read_text()
    sim_source = (CANDIDATE / "tools/balance_sim.gd").read_text()
    apply_source = sim_source.split(
        "static func apply_research421_scoreline_commitment(", 1
    )[1].split("\n\nstatic func", 1)[0]
    static_faults = []
    for label, condition in (
        ("scoreline producer cardinality",
         combat_source.count("_research421_scoreline_producer(") == 2),
        ("scoreline consumer cardinality",
         combat_source.count("_research421_scoreline_after_card(") == 2),
        ("commitment relic append cardinality",
         sim_source.count("run.player.relics.append(RESEARCH421_SCORELINE_OATH)") == 1),
        ("commitment card append cardinality",
         sim_source.count('run.player.deck.append(CardInst.new(run.next_uid(), &"executioner"') == 1),
        ("commitment no RNG call", "rng" not in apply_source.lower()),
        ("component schema cardinality", sim_source.count("scoreline-component-v1") == 2),
        ("Afterimage implementation absent", "research421Afterimage" not in combat_source and
         "research421Afterimage" not in sim_source),
    ):
        if not condition:
            static_faults.append(label)

    cohort_rows = v1.whole_run_rows(protocol)
    scripted_seed = protocol["cohort"]["scriptedSeed"]
    null_rows = copy.deepcopy(v1.null_controls())
    for row in null_rows:
        row["seed"] = scripted_seed
    per_arm = len(cohort_rows) + len(null_rows)
    require("frozen null arm size", per_arm == protocol["budget"]["rowsPerNullArm"])
    baseline_rows = cohort_rows + null_rows
    explicit_rows = [dict(row, research421=settings()) for row in copy.deepcopy(baseline_rows)]
    gate_rows = [dict(row, research421=settings("faultline-bonus-6", "none"))
                 for row in copy.deepcopy(baseline_rows)]
    direct = direct_rows(scripted_seed)
    require("frozen direct row count", len(direct) == protocol["budget"]["directRows"])

    baseline_plan = {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "arm": "pristine-current-main-scoreline-component-v1",
        "content": str(content_path),
        "rows": baseline_rows,
    }
    candidate_plan = {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "arm": "candidate-scoreline-component-v1-fixed-plan",
        "content": str(content_path),
        "rows": baseline_rows + explicit_rows + gate_rows + direct,
    }

    started = time.monotonic()
    cap = protocol["budget"]["maximumWallTimeSeconds"]
    invalid_results: dict[str, bool] = {}
    outputs: dict[str, str] = {}
    execution_error = ""
    try:
        invalid_cases = (
            ("schema-type", {"schemaVersion": 1, "scorelinePayoff": "off",
             "scorelineCommitment": "none"},
             "requires schemaVersion=scoreline-component-v1"),
            ("schema-value", {"schemaVersion": "scoreline-commitment-v1",
             "scorelinePayoff": "off", "scorelineCommitment": "none"},
             "requires schemaVersion=scoreline-component-v1"),
            ("missing-payoff", {"schemaVersion": "scoreline-component-v1",
             "scorelineCommitment": "none"}, "requires both registered factors"),
            ("missing-commitment", {"schemaVersion": "scoreline-component-v1",
             "scorelinePayoff": "off"}, "requires both registered factors"),
            ("payoff-type", {"schemaVersion": "scoreline-component-v1",
             "scorelinePayoff": 6, "scorelineCommitment": "none"},
             "scorelinePayoff has unregistered level"),
            ("payoff-token", {"schemaVersion": "scoreline-component-v1",
             "scorelinePayoff": "unknown", "scorelineCommitment": "none"},
             "scorelinePayoff has unregistered level"),
            ("commitment-type", {"schemaVersion": "scoreline-component-v1",
             "scorelinePayoff": "off", "scorelineCommitment": 1},
             "scorelineCommitment has unregistered level"),
            ("commitment-token", {"schemaVersion": "scoreline-component-v1",
             "scorelinePayoff": "off", "scorelineCommitment": "unknown"},
             "scorelineCommitment has unregistered level"),
            ("unknown-key", {"schemaVersion": "scoreline-component-v1",
             "scorelinePayoff": "off", "scorelineCommitment": "none", "unknown": "off"},
             "unknown key unknown"),
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
        decision = "record-scoreline-component-identity-inconclusive-at-cap"
    else:
        baseline_observed = baseline_output["rows"]
        candidate_observed = candidate_output["rows"]
        omitted = candidate_observed[:per_arm]
        explicit = candidate_observed[per_arm:per_arm * 2]
        gate = candidate_observed[per_arm * 2:per_arm * 3]
        direct_observed = candidate_observed[per_arm * 3:]
        observed_rows = len(baseline_observed) + len(candidate_observed)
        identity_counts = {
            "baselineVersusOmittedMismatchRows": sum(
                left != normalise(right) for left, right in zip(baseline_observed, omitted)
            ),
            "omittedVersusExplicitMismatchRows": sum(
                normalise(left) != normalise(right) for left, right in zip(omitted, explicit)
            ),
            "explicitVersusNoOathGateMismatchRows": sum(
                normalise(left) != normalise(right) for left, right in zip(explicit, gate)
            ),
            "nullRngMismatchRows": sum(
                not (baseline_observed[i]["rng"] == omitted[i]["rng"] ==
                     explicit[i]["rng"] == gate[i]["rng"])
                for i in range(per_arm)
            ),
        }
        faults.extend(key for key, value in identity_counts.items() if value)
        faults.extend(name for name, ok in invalid_results.items() if not ok)
        gate_nulls = {row["id"]: row for row in gate[len(cohort_rows):]}
        faults.extend(direct_faults(direct_observed, gate_nulls))
        if observed_rows != protocol["budget"]["maximumSimulatorObservationRows"]:
            faults.append("observation row count")
        if elapsed > cap:
            boundary = 3
            outcome_class = "inconclusive"
            decision = "record-scoreline-component-identity-inconclusive-at-cap"
        elif faults:
            boundary = 2
            outcome_class = "futility"
            decision = "close-scoreline-component-control-without-endpoint-use"
        else:
            boundary = 1
            outcome_class = "success"
            decision = "freeze-scoreline-component-control-for-three-arm-crn-panel"

    ledger_after = ledger.ledger_identity()
    if ledger_after != ledger_before and outcome_class != "inconclusive":
        faults.append("ledger changed")
        boundary = 2
        outcome_class = "futility"
        decision = "close-scoreline-component-control-without-endpoint-use"
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
            "success": "Authorises one separately preregistered three-arm Scoreline CRN panel only.",
            "futility": "Closes this component control without rescue and continues inside #421.",
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
