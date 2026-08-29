#!/usr/bin/env python3
"""Staged implementation identity for the explicit Dusk acquisition factor."""

from __future__ import annotations

import json
import subprocess
import tempfile
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v30-explicit-acquisition-identity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v30-explicit-acquisition-identity-v1.json"
SOURCE = core.ROOT / "dusk-explicit-acquisition-identity-v1-source"
BASELINE_PLAN_SHA = "d33926aec9e22a14f1709120a261c52571e9a94b78c98d90d2a19b9d136c61d3"
BASELINE_OUTPUT_SHA = "1be7272596391fd1f7b296af480bc366ae8b6a2af50c71c3dc508fc6ae3b458f"
PROBE = "res://tools/research_421_explicit_dusk_acquisition_probe.gd"
GODOT = Path("/Applications/Godot.app/Contents/MacOS/Godot")
DRIVERS = (
    "tools/balance_sim.gd", "tools/balance_sweep.gd", "tools/balance_cem.gd",
    "tools/balance_pilot.gd", "tools/balance_policy.gd", "tools/balance_catalogue.gd",
)


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Explicit acquisition identity mismatch: {label}")


def remaining(deadline: float) -> int:
    seconds = int(deadline - time.monotonic())
    if seconds < 1:
        raise TimeoutError("explicit acquisition identity exceeded its wall-time ceiling")
    return seconds


def git(*args: str) -> str:
    return subprocess.run(
        ["git", *args], cwd=SOURCE, check=True, text=True, capture_output=True,
    ).stdout.strip()


def cache_object(digest: str) -> dict[str, Any]:
    path = core.CACHE / f"{digest}.json"
    require(f"cache {digest} exists", path.is_file())
    require(f"cache {digest} identity", core.file_sha(path) == digest)
    value = json.loads(path.read_text())
    require(f"cache {digest} JSON type", isinstance(value, dict))
    return value


def driver_sha() -> str:
    text = "".join(f"{relative}\n{(SOURCE / relative).read_text()}" for relative in DRIVERS)
    return core.sha(text.encode())


def whole_specs(protocol: dict[str, Any], first: int, count: int) -> list[dict[str, Any]]:
    cohort = protocol["cohort"]
    return [
        {
            "mode": "whole",
            "aspect": cohort["aspect"],
            "vow": cohort["vow"],
            "seed": seed,
            "policyRoot": cohort["policyRoot"],
            "policyIndex": policy_index,
        }
        for policy_index in range(first, first + count)
        for seed in cohort["simulationSeeds"]
    ]


def normalised_sources_exact(protocol: dict[str, Any]) -> bool:
    baseline = core.ROOT / "dusk-acquisition-baseline-v1-source"
    run_state = (SOURCE / "domain/state/run_state.gd").read_text()
    run_addition = (
        '\tvar dusk_package_consumer: StringName = StringName(str(profile.get('
        '"duskPackageConsumer", "")))\n'
        '\tif rs.aspect == 0 and dusk_package_consumer in [&"executioner", &"guardedStrike"]:\n'
        '\t\trs.player.deck.append(CardInst.new(rs.next_uid(), dusk_package_consumer, false))\n'
    )
    sim = (SOURCE / "tools/balance_sim.gd").read_text()
    old_signature = (
        '\t\tvigil: VigilState = null, strip_start_hex: bool = false) -> Dictionary:\n'
        '\t_probe = {}\n'
    )
    new_signature = (
        '\t\tvigil: VigilState = null, strip_start_hex: bool = false,\n'
        '\t\tdusk_acquisition_choice: String = "") -> Dictionary:\n'
        '\t_probe = {}\n'
        '\tassert(dusk_acquisition_choice in ["", "off", "executioner", "guardedStrike"])\n'
    )
    injection = (
        '\tif aspect == "duskblade" and dusk_acquisition_choice in '
        '["executioner", "guardedStrike"]:\n'
        '\t\tprofile["duskPackageConsumer"] = dusk_acquisition_choice\n'
    )
    require("RunState intended addition count", run_state.count(run_addition) == 1)
    require("BalanceSim intended signature count", sim.count(new_signature) == 1)
    require("BalanceSim intended injection count", sim.count(injection) == 1)
    normalised_run_state = run_state.replace(run_addition, "")
    normalised_sim = sim.replace(new_signature, old_signature).replace(injection, "")
    return (
        normalised_run_state == (baseline / "domain/state/run_state.gd").read_text()
        and normalised_sim == (baseline / "tools/balance_sim.gd").read_text()
        and driver_sha() == protocol["immutableInputs"]["prototypeDriverSha256"]
    )


def verify_preflight(
    protocol: dict[str, Any], protocol_sha: str,
) -> tuple[dict[str, Any], dict[str, Any], dict[str, list[dict[str, Any]]]]:
    immutable = protocol["immutableInputs"]
    require("runner identity", core.file_sha(Path(__file__)) == immutable["runnerSha256"])
    require("source commit", git("rev-parse", "HEAD") == immutable["sourceCommit"])
    status = subprocess.run(
        ["git", "status", "--porcelain"], cwd=SOURCE, check=True,
        text=True, capture_output=True,
    ).stdout.splitlines()
    require("source status", status == immutable["sourceStatus"])
    require("tracked diff identity", core.sha(subprocess.run(
        ["git", "diff", "--no-ext-diff"], cwd=SOURCE, check=True,
        capture_output=True,
    ).stdout) == immutable["trackedDiffSha256"])
    require("Godot version", subprocess.run(
        [str(GODOT), "--version"], check=True, text=True, capture_output=True,
    ).stdout.strip() == immutable["godotVersion"])
    require("Godot binary", core.file_sha(GODOT) == immutable["godotBinarySha256"])
    require("task capsule", core.file_sha(core.ROOT / "task-capsule.json") ==
            immutable["taskCapsuleSha256"])
    for relative, expected in immutable["sourceSha256"].items():
        require(f"source {relative}", core.file_sha(SOURCE / relative) == expected)
    for relative, expected in immutable["evidenceSha256"].items():
        require(f"evidence {relative}", core.file_sha(core.ROOT / relative) == expected)
    require("only intended source deltas", normalised_sources_exact(protocol))
    probe = (SOURCE / protocol["probeContract"]["path"]).read_text()
    for anchor in protocol["probeContract"]["cardinalityAnchors"]:
        require(f"probe cardinality anchor {anchor}", probe.count(anchor) == 1)
    for anchor in protocol["probeContract"]["equalityAnchors"]:
        require(f"probe equality anchor {anchor}", anchor in probe)

    baseline_plan = cache_object(BASELINE_PLAN_SHA)
    baseline_output = cache_object(BASELINE_OUTPUT_SHA)
    require("baseline output plan", baseline_output["planSha256"] == BASELINE_PLAN_SHA)
    cohort = protocol["cohort"]
    full_specs = whole_specs(protocol, 0, cohort["policyCount"])
    require("baseline plan rows", baseline_plan["rows"] == full_specs)
    require("baseline output cardinality", len(baseline_output["rows"]) == cohort["rows"])
    row_fields = set(protocol["comparisonContract"]["canonicalRowFields"])
    require("baseline row schema", all(set(row) == row_fields
                                        for row in baseline_output["rows"]))
    require("baseline provenance", baseline_output["contentIdentity"] ==
            protocol["outputProvenance"]["baselineContentIdentity"])
    require("baseline probe provenance", baseline_output["probeSha256"] ==
            protocol["outputProvenance"]["baselineProbeSha256"])

    sentinel_count = protocol["staging"]["sentinelPolicyCount"]
    sentinel = whole_specs(protocol, 0, sentinel_count)
    remainder = whole_specs(protocol, sentinel_count, cohort["policyCount"] - sentinel_count)
    plans = {
        "invalid": {
            "schemaVersion": 1, "protocolSha256": protocol_sha,
            "content": protocol["contentPath"],
            "rows": [dict(protocol["directCases"][0], mode="direct", acquisition="invalid")],
        },
        "direct": {
            "schemaVersion": 1, "protocolSha256": protocol_sha,
            "content": protocol["contentPath"],
            "rows": [dict(case, mode="direct") for case in protocol["directCases"]],
        },
        "sentinel": {
            "schemaVersion": 1, "protocolSha256": protocol_sha,
            "content": protocol["contentPath"],
            "rows": sentinel + [dict(spec, acquisition="off") for spec in sentinel],
        },
        "remainder": {
            "schemaVersion": 1, "protocolSha256": protocol_sha,
            "content": protocol["contentPath"],
            "rows": remainder + [dict(spec, acquisition="off") for spec in remainder],
        },
    }
    expected = protocol["staging"]["expectedOutputRows"]
    require("direct plan cardinality", len(plans["direct"]["rows"]) == expected["direct"])
    require("sentinel plan cardinality", len(plans["sentinel"]["rows"]) == expected["sentinel"])
    require("remainder plan cardinality", len(plans["remainder"]["rows"]) == expected["remainder"])
    require("complete null cardinality", expected["sentinel"] + expected["remainder"] ==
            cohort["rows"] * 2)
    return baseline_output, {
        "status": "PASS",
        "expectedCardinalityExact": True,
        "crossArmEqualityFieldsInvariant": True,
        "sourceDeltaExact": True,
        "canonicalRowFields": len(row_fields),
        "prototypeDriverSha256": driver_sha(),
    }, plans


def run_probe(
    plan: dict[str, Any], deadline: float,
) -> tuple[dict[str, Any], str, str]:
    plan_sha, plan_path = core.cache_json(plan)
    core.WORK.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=core.WORK, prefix="explicit-acquisition-") as tmp:
        output_path = Path(tmp) / "output.json"
        result = subprocess.run(
            [str(GODOT), "--headless", "-s", PROBE, "--",
             f"--plan={plan_path}", f"--out={output_path}"],
            cwd=SOURCE, text=True, capture_output=True, timeout=remaining(deadline),
        )
        if result.returncode or not output_path.is_file():
            raise OSError(
                f"probe failed ({result.returncode})\n"
                f"{result.stdout[-2000:]}\n{result.stderr[-4000:]}"
            )
        output = json.loads(output_path.read_text())
    require("output plan identity", output.get("planSha256") == plan_sha)
    output_sha, _ = core.cache_json(output)
    return output, plan_sha, output_sha


def invalid_fails(plan: dict[str, Any], deadline: float) -> tuple[bool, str, str]:
    plan_sha, plan_path = core.cache_json(plan)
    core.WORK.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=core.WORK, prefix="explicit-acquisition-invalid-") as tmp:
        output_path = Path(tmp) / "output.json"
        result = subprocess.run(
            [str(GODOT), "--headless", "-s", PROBE, "--",
             f"--plan={plan_path}", f"--out={output_path}"],
            cwd=SOURCE, text=True, capture_output=True, timeout=remaining(deadline),
        )
        clear = (
            result.returncode != 0 and not output_path.exists()
            and "acquisition accepts only omitted, off, executioner or guardedStrike"
            in result.stderr
        )
    return clear, plan_sha, result.stderr[-4000:]


def verify_output(
    label: str, output: dict[str, Any], expected_rows: int,
    protocol: dict[str, Any], whole: bool,
) -> None:
    require(f"{label} output keys", set(output) == {
        "schemaVersion", "planSha256", "probeSha256", "contentIdentity", "rows",
    })
    require(f"{label} schema", output["schemaVersion"] == 1)
    require(f"{label} cardinality", len(output["rows"]) == expected_rows)
    require(f"{label} probe provenance", output["probeSha256"] ==
            protocol["outputProvenance"]["prototypeProbeSha256"])
    require(f"{label} content provenance", output["contentIdentity"] ==
            protocol["outputProvenance"]["prototypeContentIdentity"])
    if whole:
        fields = set(protocol["comparisonContract"]["canonicalRowFields"])
        require(f"{label} row schema", all(set(row) == fields for row in output["rows"]))


def analyse_direct(
    rows: list[dict[str, Any]], protocol: dict[str, Any], content: dict[str, Any],
) -> dict[str, Any]:
    cases = protocol["directCases"]
    require("direct row count", len(rows) == len(cases))
    by_id = {str(row["id"]): row for row in rows}
    require("direct identities", set(by_id) == {case["id"] for case in cases})
    results: dict[str, Any] = {}
    for case in cases:
        row = by_id[case["id"]]
        expected = case["expectedChoice"]
        require(f"{case['id']} aspect", row["aspect"] == case["aspect"])
        require(f"{case['id']} acquisition", row["acquisition"] == case["acquisition"])
        require(f"{case['id']} random build", row["randomBuild"] == case["randomBuild"])
        require(f"{case['id']} choice", row["choice"] == expected)
        require(f"{case['id']} choice RNG", row["choiceRngBefore"] == row["choiceRngAfter"])
        require(f"{case['id']} run RNG", row["nullRunRng"] == row["enabledRunRng"] ==
                row["reloadedRunRng"])
        require(f"{case['id']} save", row["enabledDeck"] == row["reloadedDeck"] and
                row["enabledUid"] == row["reloadedUid"])
        require(f"{case['id']} pool gate", row["poolWave2Gate"] == "poolWave2")
        require(f"{case['id']} guard gate", row["guardedStrikeGate"] == "")
        require(f"{case['id']} producers", row["producerDefinitions"] == {
            name: content["cards"][name] for name in ("chisel", "defend")
        })
        require(f"{case['id']} consumers", row["consumerDefinitions"] == {
            name: content["cards"][name] for name in ("executioner", "guardedStrike")
        })
        if expected:
            require(f"{case['id']} one card", row["enabledDeck"][:-1] == row["nullDeck"]
                    and len(row["enabledDeck"]) == len(row["nullDeck"]) + 1
                    and row["enabledDeck"][-1]["id"] == expected
                    and row["enabledDeck"][-1]["uid"] == row["nullUid"])
            require(f"{case['id']} UID", row["enabledUid"] == row["nullUid"] + 1)
        else:
            require(f"{case['id']} null deck", row["enabledDeck"] == row["nullDeck"])
            require(f"{case['id']} null UID", row["enabledUid"] == row["nullUid"])
        results[case["id"]] = {
            "choice": expected,
            "deckDelta": len(row["enabledDeck"]) - len(row["nullDeck"]),
            "rngExact": True,
            "saveRoundTripExact": True,
        }
    return {"status": "PASS", "rows": len(rows), "cases": results}


def comparison(
    left: list[dict[str, Any]], right: list[dict[str, Any]],
    protocol: dict[str, Any],
) -> dict[str, Any]:
    groups = protocol["comparisonContract"]["rowFieldsByEstimand"]
    return {
        "rows": len(left),
        "completeRowMismatchRows": sum(a != b for a, b in zip(left, right)),
        "mismatchRowsByEstimand": {
            name: sum(any(a[field] != b[field] for field in fields)
                      for a, b in zip(left, right))
            for name, fields in groups.items()
        },
    }


def exact(result: dict[str, Any]) -> bool:
    return result["completeRowMismatchRows"] == 0 and all(
        value == 0 for value in result["mismatchRowsByEstimand"].values()
    )


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite completed explicit acquisition identity")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    deadline = started + float(protocol["budget"]["maximumWallTimeSeconds"])
    ledger_before: dict[str, Any] = {}
    ledger_after: dict[str, Any] = {}
    preflight: dict[str, Any] = {"status": "UNRESOLVED"}
    direct: dict[str, Any] = {}
    sentinel: dict[str, Any] = {}
    full: dict[str, Any] = {}
    cache_objects: dict[str, str] = {}
    execution_error = ""
    unavailable = False
    invalid_clear = False
    new_rows = 0
    godot_processes = 0
    baseline: dict[str, Any] = {}
    plans: dict[str, Any] = {}
    try:
        ledger_before = identity.ledger_identity()
        require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
        baseline, preflight, plans = verify_preflight(protocol, protocol_sha)
    except (FileNotFoundError, json.JSONDecodeError, KeyError, TypeError,
            ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        execution_error, unavailable = str(error), True

    if not execution_error:
        try:
            invalid_clear, plan_sha, stderr = invalid_fails(plans["invalid"], deadline)
            godot_processes += 1
            cache_objects["invalidPlanSha256"] = plan_sha
            if not invalid_clear:
                raise RuntimeError(stderr or "invalid acquisition did not fail closed")
            direct_output, plan_sha, output_sha = run_probe(plans["direct"], deadline)
            godot_processes += 1
            cache_objects.update({
                "directPlanSha256": plan_sha, "directOutputSha256": output_sha,
            })
            verify_output("direct", direct_output,
                          protocol["staging"]["expectedOutputRows"]["direct"],
                          protocol, False)
            content = cache_object(protocol["immutableInputs"]["contentSha256"])
            direct = analyse_direct(direct_output["rows"], protocol, content)
            new_rows += len(direct_output["rows"])

            sentinel_output, plan_sha, output_sha = run_probe(plans["sentinel"], deadline)
            godot_processes += 1
            cache_objects.update({
                "sentinelPlanSha256": plan_sha, "sentinelOutputSha256": output_sha,
            })
            sentinel_expected = protocol["staging"]["expectedOutputRows"]["sentinel"]
            verify_output("sentinel", sentinel_output, sentinel_expected, protocol, True)
            new_rows += len(sentinel_output["rows"])
            per_sentinel = sentinel_expected // 2
            base_sentinel = baseline["rows"][:per_sentinel]
            omitted_sentinel = sentinel_output["rows"][:per_sentinel]
            off_sentinel = sentinel_output["rows"][per_sentinel:]
            sentinel = {
                "pristineVersusOmitted": comparison(
                    base_sentinel, omitted_sentinel, protocol,
                ),
                "omittedVersusOff": comparison(omitted_sentinel, off_sentinel, protocol),
            }
            require("sentinel identity", all(exact(value) for value in sentinel.values()))

            remainder_output, plan_sha, output_sha = run_probe(plans["remainder"], deadline)
            godot_processes += 1
            cache_objects.update({
                "remainderPlanSha256": plan_sha, "remainderOutputSha256": output_sha,
            })
            remainder_expected = protocol["staging"]["expectedOutputRows"]["remainder"]
            verify_output("remainder", remainder_output, remainder_expected, protocol, True)
            new_rows += len(remainder_output["rows"])
            per_remainder = remainder_expected // 2
            omitted = omitted_sentinel + remainder_output["rows"][:per_remainder]
            off = off_sentinel + remainder_output["rows"][per_remainder:]
            require("full arm cardinality", len(omitted) == len(off) ==
                    protocol["cohort"]["rows"])
            full = {
                "pristineVersusOmitted": comparison(baseline["rows"], omitted, protocol),
                "omittedVersusOff": comparison(omitted, off, protocol),
            }
        except (OSError, subprocess.TimeoutExpired) as error:
            execution_error, unavailable = str(error), True
        except (FileNotFoundError, json.JSONDecodeError, KeyError, TypeError,
                ValueError, RuntimeError) as error:
            execution_error = str(error)

    try:
        ledger_after = identity.ledger_identity()
        require("zero-row ledger identity", ledger_after == ledger_before)
    except (RuntimeError, OSError) as error:
        execution_error, unavailable = str(error), True
    elapsed = time.monotonic() - started
    if elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        execution_error, unavailable = "explicit acquisition identity exceeded wall-time cap", True
    if new_rows > protocol["budget"]["maximumNewIdentityObservationRows"]:
        execution_error, unavailable = "explicit acquisition identity exceeded its row cap", True
    if godot_processes > protocol["budget"]["maximumGodotProcesses"]:
        execution_error, unavailable = "explicit acquisition identity exceeded its process cap", True
    full_exact = bool(full) and all(exact(value) for value in full.values())
    if execution_error and unavailable:
        boundary, outcome = 3, "inconclusive"
        decision = "record-explicit-acquisition-identity-inconclusive"
    elif execution_error or not invalid_clear or not full_exact:
        boundary, outcome = 2, "futility"
        decision = "close-explicit-acquisition-factor-on-identity-failure"
    else:
        boundary, outcome = 1, "success"
        decision = "freeze-explicit-acquisition-factor-for-support"
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": boundary,
        "decision": decision,
        "outcomeClass": outcome,
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "preflight": preflight,
        "invalidConfigurationFailedClosed": invalid_clear,
        "directControls": direct,
        "sentinelIdentity": sentinel,
        "fullNullIdentity": full,
        "cacheObjects": cache_objects,
        "executionError": execution_error,
        "newIdentityObservationRows": new_rows,
        "enabledWholeRunRows": 0,
        "newSupportRows": 0,
        "newCausalRows": 0,
        "newLedgerRows": 0,
        "GodotProcesses": godot_processes,
        "protectedSeedRows": ledger_after.get(
            "protectedSeedRows", ledger_before.get("protectedSeedRows", 0),
        ),
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
        "newIdentityObservationRows": new_rows,
        "enabledWholeRunRows": 0,
        "summarySha256": core.file_sha(SUMMARY),
    }))


if __name__ == "__main__":
    main()
