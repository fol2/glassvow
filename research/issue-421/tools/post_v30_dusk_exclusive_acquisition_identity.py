#!/usr/bin/env python3
"""Exact-runtime identity preflight for the Dusk acquisition/UI contract."""

from __future__ import annotations

import json
import subprocess
import tempfile
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v30-dusk-exclusive-acquisition-identity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v30-dusk-exclusive-acquisition-identity-v1.json"
BASELINE = core.ROOT / "dusk-acquisition-baseline-v1-source"
PROTOTYPE = core.ROOT / "dusk-acquisition-identity-v1-source"
PROBE = "res://tools/research_421_dusk_acquisition_probe.gd"
GODOT = Path("/Applications/Godot.app/Contents/MacOS/Godot")


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Dusk acquisition identity mismatch: {label}")


def remaining(deadline: float) -> int:
    seconds = int(deadline - time.monotonic())
    if seconds < 1:
        raise TimeoutError("Dusk acquisition identity exceeded its wall-time ceiling")
    return seconds


def run_probe(
    source: Path, plan: dict[str, Any], deadline: float,
) -> tuple[dict[str, Any], str, str]:
    plan_sha, plan_path = core.cache_json(plan)
    core.WORK.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=core.WORK, prefix="dusk-acquisition-identity-") as tmp:
        output_path = Path(tmp) / "output.json"
        result = subprocess.run(
            [str(GODOT), "--headless", "-s", PROBE, "--",
             f"--plan={plan_path}", f"--out={output_path}"],
            cwd=source, text=True, capture_output=True, timeout=remaining(deadline),
        )
        if result.returncode or not output_path.is_file():
            raise OSError(
                f"probe failed ({result.returncode})\n"
                f"{result.stdout[-2000:]}\n{result.stderr[-4000:]}"
            )
        output = json.loads(output_path.read_text())
    require("plan identity", output.get("planSha256") == plan_sha)
    output_sha, _ = core.cache_json(output)
    return output, plan_sha, output_sha


def invalid_configuration_fails(
    protocol_sha: str, content: str, spec: dict[str, Any], deadline: float,
) -> tuple[bool, bool, str, str]:
    invalid = dict(spec)
    invalid.update({"mode": "direct", "acquisition": "invalid"})
    plan = {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "content": content,
        "rows": [invalid],
    }
    plan_sha, plan_path = core.cache_json(plan)
    core.WORK.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=core.WORK, prefix="dusk-acquisition-invalid-") as tmp:
        output_path = Path(tmp) / "output.json"
        result = subprocess.run(
            [str(GODOT), "--headless", "-s", PROBE, "--",
             f"--plan={plan_path}", f"--out={output_path}"],
            cwd=PROTOTYPE, text=True, capture_output=True, timeout=remaining(deadline),
        )
        output_exists = output_path.exists()
    clear = (
        result.returncode != 0
        and not output_exists
        and "acquisition accepts only omitted, off or pilot" in result.stderr
    )
    unavailable = not clear and result.returncode != 0 and not output_exists
    return clear, unavailable, plan_sha, result.stderr[-4000:]


def source_identity(protocol: dict[str, Any]) -> dict[str, Any]:
    immutable = protocol["immutableInputs"]
    out: dict[str, Any] = {
        "runnerSha256": core.file_sha(Path(__file__)),
        "godotVersion": subprocess.run(
            [str(GODOT), "--version"], check=True, text=True, capture_output=True,
        ).stdout.strip(),
        "godotBinarySha256": core.file_sha(GODOT),
        "taskCapsuleSha256": core.file_sha(core.ROOT / "task-capsule.json"),
        "designProtocolSha256": core.file_sha(
            core.ROOT / "protocols/post-v30-dusk-exclusive-acquisition-design-v1.json"),
        "designSummarySha256": core.file_sha(
            core.ROOT / "summaries/post-v30-dusk-exclusive-acquisition-design-v1.json"),
    }
    for name, source in (("baseline", BASELINE), ("prototype", PROTOTYPE)):
        out[f"{name}SourceCommit"] = subprocess.run(
            ["git", "rev-parse", "HEAD"], cwd=source, check=True,
            text=True, capture_output=True,
        ).stdout.strip()
        out[f"{name}Status"] = subprocess.run(
            ["git", "status", "--porcelain"], cwd=source, check=True,
            text=True, capture_output=True,
        ).stdout.splitlines()
        for relative in immutable[f"{name}Sha256"]:
            out[f"{name}:{relative}"] = core.file_sha(source / relative)
    return out


def verify_inputs(protocol: dict[str, Any]) -> dict[str, Any]:
    observed = source_identity(protocol)
    immutable = protocol["immutableInputs"]
    for key in [
        "runnerSha256", "godotVersion", "godotBinarySha256", "taskCapsuleSha256",
        "designProtocolSha256", "designSummarySha256", "baselineSourceCommit",
        "prototypeSourceCommit", "baselineStatus", "prototypeStatus",
    ]:
        require(key, observed[key] == immutable[key])
    for name in ("baseline", "prototype"):
        for relative, expected in immutable[f"{name}Sha256"].items():
            require(f"{name} {relative}", observed[f"{name}:{relative}"] == expected)
    return observed


def whole_specs(protocol: dict[str, Any]) -> list[dict[str, Any]]:
    cohort = protocol["identityCohort"]
    return [
        {
            "mode": "whole",
            "aspect": cohort["aspect"],
            "vow": cohort["vow"],
            "seed": seed,
            "policyRoot": cohort["policyRoot"],
            "policyIndex": policy_index,
        }
        for policy_index in range(cohort["policyCount"])
        for seed in cohort["simulationSeeds"]
    ]


def analyse_whole(
    baseline_rows: list[dict[str, Any]], prototype_rows: list[dict[str, Any]],
    per_arm: int,
) -> dict[str, int]:
    require("baseline whole row count", len(baseline_rows) == per_arm)
    require("prototype whole row count", len(prototype_rows) == per_arm * 2)
    omitted = prototype_rows[:per_arm]
    explicit = prototype_rows[per_arm:]
    return {
        "baselineVersusOmittedMismatchRows": sum(
            left != right for left, right in zip(baseline_rows, omitted)
        ),
        "omittedVersusExplicitNullMismatchRows": sum(
            left != right for left, right in zip(omitted, explicit)
        ),
        "rngMismatchRows": sum(
            not (baseline_rows[i]["rng"] == omitted[i]["rng"] == explicit[i]["rng"])
            for i in range(per_arm)
        ),
        "policyMismatchRows": sum(
            not (
                baseline_rows[i]["policy"]
                == omitted[i]["policy"]
                == explicit[i]["policy"]
            )
            for i in range(per_arm)
        ),
        "outcomeMismatchRows": sum(
            not (
                baseline_rows[i]["outcome"]
                == omitted[i]["outcome"]
                == explicit[i]["outcome"]
            )
            for i in range(per_arm)
        ),
    }


def ids(cards: list[dict[str, Any]]) -> list[str]:
    return [str(card["id"]) for card in cards]


def analyse_direct(
    rows: list[dict[str, Any]], protocol: dict[str, Any], content: dict[str, Any],
) -> dict[str, Any]:
    cases = protocol["directCases"]
    require("direct row count", len(rows) == len(cases))
    by_id = {str(row["id"]): row for row in rows}
    require("direct row identities", set(by_id) == {case["id"] for case in cases})
    results: dict[str, Any] = {}
    for case in cases:
        row = by_id[case["id"]]
        expected = str(case["expectedChoice"])
        require(f"{case['id']} aspect", row["aspect"] == case["aspect"])
        require(f"{case['id']} acquisition", row["acquisition"] == case["acquisition"])
        require(f"{case['id']} random-build", row["randomBuild"] == case["randomBuild"])
        require(f"{case['id']} choice", row["choice"] == expected)
        require(
            f"{case['id']} choice RNG",
            row["choiceRngBefore"] == row["choiceRngAfter"],
        )
        require(
            f"{case['id']} RunState RNG",
            row["nullRunRng"] == row["enabledRunRng"] == row["reloadedRunRng"],
        )
        require(
            f"{case['id']} save round-trip",
            row["enabledDeck"] == row["reloadedDeck"]
            and row["enabledUid"] == row["reloadedUid"],
        )
        require(f"{case['id']} poolWave2", row["poolWave2Gate"] == "poolWave2")
        require(f"{case['id']} Guarded Strike gate", row["guardedStrikeGate"] == "")
        require(
            f"{case['id']} producer content identity",
            row["producerDefinitions"]
            == {name: content["cards"][name] for name in ("chisel", "defend")},
        )
        require(
            f"{case['id']} consumer content identity",
            row["consumerDefinitions"]
            == {name: content["cards"][name] for name in ("executioner", "guardedStrike")},
        )
        null_deck, enabled_deck = row["nullDeck"], row["enabledDeck"]
        if expected:
            require(
                f"{case['id']} exactly one consumer",
                enabled_deck[:-1] == null_deck
                and len(enabled_deck) == len(null_deck) + 1
                and enabled_deck[-1]["id"] == expected
                and enabled_deck[-1]["uid"] == row["nullUid"],
            )
            require(f"{case['id']} UID advance", row["enabledUid"] == row["nullUid"] + 1)
            chosen_score = (
                row["scorelineScore"] if expected == "executioner"
                else row["afterimageScore"]
            )
            require(f"{case['id']} cardDecline", chosen_score >= row["cardDecline"])
        else:
            require(f"{case['id']} no acquisition", enabled_deck == null_deck)
            require(f"{case['id']} no UID movement", row["enabledUid"] == row["nullUid"])
            if case["reason"] == "decline":
                require(
                    f"{case['id']} exact decline",
                    max(row["scorelineScore"], row["afterimageScore"])
                    < row["cardDecline"],
                )
        results[case["id"]] = {
            "choice": expected,
            "scorelineScore": row["scorelineScore"],
            "afterimageScore": row["afterimageScore"],
            "cardDecline": row["cardDecline"],
            "deckDelta": len(enabled_deck) - len(null_deck),
            "rngExact": True,
            "saveRoundTripExact": True,
        }
    return {
        "status": "PASS",
        "rows": len(rows),
        "cases": results,
        "duskOnlyExact": True,
        "oneExistingConsumerExact": True,
        "cardDeclineExact": True,
        "randomBuildNullRngExact": True,
        "contentAndPayoffIdentityExact": True,
        "saveRoundTripExact": True,
    }


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite a completed Dusk acquisition identity")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    source = verify_inputs(protocol)
    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    content_path = core.CACHE / f"{protocol['immutableInputs']['contentSha256']}.json"
    require("content cache identity", core.file_sha(content_path) == protocol["immutableInputs"]["contentSha256"])
    content = json.loads(content_path.read_text())
    started = time.monotonic()
    deadline = started + float(protocol["budget"]["maximumWallTimeSeconds"])
    outputs: dict[str, Any] = {}
    observed_rows = 0
    invalid_clear = False
    whole_identity: dict[str, int] = {}
    direct_results: dict[str, Any] = {}
    execution_error = ""
    execution_unavailable = False
    try:
        invalid_clear, invalid_unavailable, invalid_plan_sha, invalid_stderr = invalid_configuration_fails(
            protocol_sha, str(content_path), protocol["directCases"][0], deadline,
        )
        outputs["invalidPlanSha256"] = invalid_plan_sha
        if not invalid_clear:
            execution_error = invalid_stderr
            execution_unavailable = invalid_unavailable
        else:
            direct_plan = {
                "schemaVersion": 1,
                "protocolSha256": protocol_sha,
                "content": str(content_path),
                "rows": [dict(case, mode="direct") for case in protocol["directCases"]],
            }
            direct_output, direct_plan_sha, direct_output_sha = run_probe(
                PROTOTYPE, direct_plan, deadline,
            )
            outputs.update({
                "directPlanSha256": direct_plan_sha,
                "directOutputSha256": direct_output_sha,
            })
            direct_rows = direct_output.get("rows", [])
            observed_rows += len(direct_rows)
            direct_results = analyse_direct(direct_rows, protocol, content)

            base_specs = whole_specs(protocol)
            per_arm = len(base_specs)
            require("whole rectangle", per_arm == protocol["identityCohort"]["rowsPerArm"])
            baseline_plan = {
                "schemaVersion": 1,
                "protocolSha256": protocol_sha,
                "content": str(content_path),
                "rows": base_specs,
            }
            prototype_specs = [dict(spec) for spec in base_specs]
            prototype_specs.extend(dict(spec, acquisition="off") for spec in base_specs)
            require(
                "enabled whole-run excluded",
                all(spec.get("acquisition", "") in ("", "off") for spec in prototype_specs),
            )
            prototype_plan = {
                "schemaVersion": 1,
                "protocolSha256": protocol_sha,
                "content": str(content_path),
                "rows": prototype_specs,
            }
            baseline_output, baseline_plan_sha, baseline_output_sha = run_probe(
                BASELINE, baseline_plan, deadline,
            )
            outputs.update({
                "baselinePlanSha256": baseline_plan_sha,
                "baselineOutputSha256": baseline_output_sha,
            })
            baseline_rows = baseline_output.get("rows", [])
            observed_rows += len(baseline_rows)
            prototype_output, prototype_plan_sha, prototype_output_sha = run_probe(
                PROTOTYPE, prototype_plan, deadline,
            )
            outputs.update({
                "prototypePlanSha256": prototype_plan_sha,
                "prototypeOutputSha256": prototype_output_sha,
            })
            prototype_rows = prototype_output.get("rows", [])
            observed_rows += len(prototype_rows)
            require(
                "content identity across probes",
                baseline_output["contentIdentity"]
                == prototype_output["contentIdentity"]
                == direct_output["contentIdentity"],
            )
            whole_identity = analyse_whole(baseline_rows, prototype_rows, per_arm)
    except (OSError, subprocess.TimeoutExpired, KeyError, TypeError, ValueError) as error:
        execution_error = str(error)
        execution_unavailable = True
    except RuntimeError as error:
        execution_error = str(error)

    elapsed = time.monotonic() - started
    ledger_after = identity.ledger_identity()
    require("zero-ledger identity", ledger_after == ledger_before)
    expected_rows = protocol["budget"]["maximumIdentityObservationRows"]
    if execution_error and execution_unavailable:
        boundary, outcome = 3, "inconclusive"
        decision = "record-dusk-acquisition-identity-inconclusive"
    elif execution_error:
        boundary, outcome = 2, "futility"
        decision = "close-dusk-acquisition-contract-on-identity-failure"
    elif elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        boundary, outcome = 3, "inconclusive"
        decision = "record-dusk-acquisition-identity-inconclusive-at-cap"
    elif observed_rows != expected_rows:
        boundary, outcome = 3, "inconclusive"
        decision = "record-dusk-acquisition-identity-inconclusive-on-row-count"
    elif invalid_clear and all(value == 0 for value in whole_identity.values()):
        boundary, outcome = 1, "success"
        decision = "freeze-dusk-exclusive-acquisition-identity"
    else:
        boundary, outcome = 2, "futility"
        decision = "close-dusk-acquisition-contract-on-identity-failure"
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": boundary,
        "decision": decision,
        "outcomeClass": outcome,
        "protocolSha256": protocol_sha,
        "runnerSha256": source["runnerSha256"],
        "sourceCommit": source["prototypeSourceCommit"],
        "godotVersion": source["godotVersion"],
        "invalidConfigurationFailedClosed": invalid_clear,
        "directControls": direct_results,
        "wholeRunIdentity": whole_identity,
        "cacheObjects": outputs,
        "executionError": execution_error,
        "newIdentityObservationRows": observed_rows,
        "enabledWholeRunRows": 0,
        "newCausalRows": 0,
        "newLedgerRows": 0,
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "maximumModelContextTokens": 0,
        "wallTimeSeconds": elapsed,
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "authority": protocol["decisionRules"][f"{outcome}Authority"],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS",
        "decisionBoundary": boundary,
        "decision": decision,
        "newIdentityObservationRows": observed_rows,
        "enabledWholeRunRows": 0,
        "summarySha256": core.file_sha(SUMMARY),
    }))


if __name__ == "__main__":
    main()
