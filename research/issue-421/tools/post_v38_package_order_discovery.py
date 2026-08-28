#!/usr/bin/env python3
"""Mechanism-blocked package-order discovery for Glassvow issue #421."""

from __future__ import annotations

import argparse
import json
import statistics
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_exact_complementarity as exact
import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-package-order-discovery-v1.json"
MANIFEST = core.ROOT / "execution/post-v38-package-order-discovery-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-package-order-discovery-v1.json"
AFTERIMAGE = "dusk-afterimage-guard"


def source_identity() -> dict[str, Any]:
    return {
        "sourceCommit": subprocess.run(
            ["git", "rev-parse", "HEAD"], cwd=core.SOURCE, check=True,
            text=True, capture_output=True,
        ).stdout.strip(),
        "godotVersion": subprocess.run(
            ["godot", "--version"], check=True, text=True, capture_output=True,
        ).stdout.strip(),
        "combatRulesSha256": core.file_sha(core.SOURCE / "domain/rules/combat.gd"),
        "pilotSha256": core.file_sha(core.SOURCE / "tools/balance_pilot.gd"),
        "probeSha256": core.file_sha(core.SOURCE / "tools/research_421_probe.gd"),
        "researchCoreSha256": core.file_sha(core.ROOT / "research.py"),
        "identityRunnerSha256": core.file_sha(
            core.ROOT / "post_v38_package_order_identity.py"
        ),
        "runnerSha256": core.file_sha(Path(__file__)),
    }


def protocol_observation_count(db: Any, protocol_sha: str) -> int:
    return int(db.execute(
        "SELECT COUNT(*) FROM records WHERE kind = 'observation' AND identity LIKE ?",
        (f"{protocol_sha}:%",),
    ).fetchone()[0])


def verify_entry(protocol: dict[str, Any], protocol_sha: str) -> dict[str, Any]:
    actual = source_identity()
    for key, expected in protocol["immutableInputs"].items():
        if actual.get(key) != expected:
            raise RuntimeError(
                f"immutable input drift: {key} expected {expected} got {actual.get(key)}"
            )
    for name, gate in protocol["entryGates"].items():
        path = core.ROOT / gate["path"]
        if not path.is_file() or core.file_sha(path) != gate["sha256"]:
            raise RuntimeError(f"entry gate drifted: {name}")
        loaded = json.loads(path.read_text())
        if loaded.get("decision") != gate["decision"]:
            raise RuntimeError(f"entry gate decision drifted: {name}")
    content_sha = protocol["structuralCandidate"]["contentSha256"]
    content_path = core.CACHE / f"{content_sha}.json"
    if not content_path.is_file() or core.file_sha(content_path) != content_sha:
        raise RuntimeError("fixed mechanism-substrate content is missing or corrupt")
    if not MANIFEST.is_file():
        raise RuntimeError("execution manifest is missing")
    manifest = json.loads(MANIFEST.read_text())
    required = {
        "protocolSha256": protocol_sha,
        "runnerSha256": actual["runnerSha256"],
        "probeSha256": actual["probeSha256"],
        "identitySummarySha256": protocol["entryGates"]["packageOrderIdentity"][
            "sha256"
        ],
        "ledgerSha256BeforeFirstObservation": protocol["ledgerFreeze"]["sha256"],
        "ledgerRecordsBeforeFirstObservation": protocol["ledgerFreeze"]["records"],
        "initialSimulatorObservationRows": protocol["budget"][
            "initialSimulatorObservationRows"
        ],
        "maximumSimulatorObservationRows": protocol["budget"][
            "maximumNewSimulatorObservationRows"
        ],
        "maximumWallTimeSeconds": protocol["budget"]["maximumWallTimeSeconds"],
        "maximumModelContextTokensDuringExecutionAndDecision": 0,
    }
    for key, expected in required.items():
        if manifest.get(key) != expected:
            raise RuntimeError(f"execution manifest drifted at {key}")
    ledger = identity.ledger_identity()
    if ledger != protocol["ledgerFreeze"]:
        with core.open_ledger() as db:
            if core.existing_record(db, protocol_sha) is None:
                raise RuntimeError("ledger changed before the first discovery row")
    return {**actual, "executionManifestSha256": core.file_sha(MANIFEST)}


def panel_rows(
    protocol: dict[str, Any], package: str, order: int, arms: tuple[str, ...]
) -> list[dict[str, Any]]:
    spec = protocol["packages"][package]
    cohort = protocol["cohort"]
    settings = dict(protocol["structuralCandidate"]["research421"])
    settings["packageOrder"] = order
    rows: list[dict[str, Any]] = []
    for index, seed in enumerate(range(
        int(cohort["researchSeeds"]["first"]),
        int(cohort["researchSeeds"]["last"]) + 1,
    )):
        base = ["strike"] * 8 if package == AFTERIMAGE else ["strike"] * 4 + ["brace"] * 4
        for aspect in ("duskblade", "ashwarden"):
            for arm in arms:
                producer = str(spec["producer"]) if arm in ("A", "AB") else "brace"
                consumer = str(spec["consumer"]) if arm in ("B", "AB") else "strike"
                rows.append({
                    "id": f"package-order-discovery-{package}-o{order}-{aspect}-{arm}-{seed}",
                    "stage": "post-v38-package-order-discovery",
                    "package": package,
                    "edge": package,
                    "arm": arm,
                    "split": "discovery",
                    "context": f"fixed-substrate-Q2-W0-package-order-{order}",
                    "aspect": aspect,
                    "seed": seed,
                    "vow": 0,
                    "response": "combatUtility",
                    "mode": "pilot",
                    "maxTurns": 20,
                    "policyRoot": int(cohort["policyIdentity"]["root"]),
                    "policyIndex": index,
                    "research421": settings,
                    "deck": [*base, producer, consumer],
                    "enemies": ["gravewarden"],
                    "unlocks": ["aspect2"],
                })
    expected = int(cohort["policyIdentity"]["count"]) * 2 * len(arms)
    if len(rows) != expected or len({row["id"] for row in rows}) != expected:
        raise ValueError("package-order block is incomplete or duplicated")
    if any(3000 <= int(row["seed"]) <= 5399 for row in rows):
        raise ValueError("protected seed entered package-order discovery")
    return rows


def initial_rows(protocol: dict[str, Any]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for package in sorted(protocol["packages"]):
        rows.extend(panel_rows(protocol, package, 1, core.ARMS))
        rows.extend(panel_rows(
            protocol, package, 0, core.ARMS if package == AFTERIMAGE else ("AB",)
        ))
    if len(rows) != int(protocol["budget"]["initialSimulatorObservationRows"]):
        raise ValueError("initial mechanism-blocked design drifted")
    return rows


def plan_for(protocol: dict[str, Any], protocol_sha: str,
             rows: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "content": str(core.CACHE / f"{protocol['structuralCandidate']['contentSha256']}.json"),
        "rows": rows,
    }


def cells(rows: list[dict[str, Any]], package: str, order: int) -> list[dict[str, Any]]:
    marker = f"package-order-{order}"
    return [row for row in rows if row["package"] == package and marker in row["context"]]


def interaction_separation(
    protocol: dict[str, Any], package: str, rows: list[dict[str, Any]]
) -> dict[int, float]:
    spec = protocol["packages"][package]
    target = str(spec["aspect"])
    control = "ashwarden" if target == "duskblade" else "duskblade"
    grouped = {
        (str(row["aspect"]), int(row["seed"])): {}
        for row in rows
    }
    for row in rows:
        grouped[(str(row["aspect"]), int(row["seed"]))][str(row["arm"])] = row
    result: dict[int, float] = {}
    for seed in range(
        int(protocol["cohort"]["researchSeeds"]["first"]),
        int(protocol["cohort"]["researchSeeds"]["last"]) + 1,
    ):
        values: dict[str, float] = {}
        for aspect in (target, control):
            block = grouped[(aspect, seed)]
            if set(block) != set(core.ARMS):
                raise ValueError(f"incomplete interaction block for {package}")
            metric = {arm: exact.card_metric(block[arm], spec) for arm in core.ARMS}
            values[aspect] = metric["AB"] - metric["A"] - metric["B"] + metric["none"]
        result[seed] = values[target] - values[control]
    return result


def structural_gain(
    protocol: dict[str, Any], package: str,
    off_rows: list[dict[str, Any]], on_rows: list[dict[str, Any]],
) -> dict[str, float]:
    off = interaction_separation(protocol, package, off_rows)
    on = interaction_separation(protocol, package, on_rows)
    return exact.fitted_interval(
        [on[seed] - off[seed] for seed in sorted(on)], 1.0, protocol
    )


def anchor_interference(
    protocol: dict[str, Any], package: str,
    off_rows: list[dict[str, Any]], on_rows: list[dict[str, Any]],
) -> dict[str, Any]:
    spec = protocol["packages"][package]
    target = str(spec["aspect"])
    control = "ashwarden" if target == "duskblade" else "duskblade"
    off = {(str(row["aspect"]), int(row["seed"])): row for row in off_rows}
    on = {(str(row["aspect"]), int(row["seed"])): row for row in on_rows}
    movement: list[float] = []
    target_values: list[float] = []
    outcome_changes = 0
    fault_changes = 0
    duration_changes: list[float] = []
    for seed in range(
        int(protocol["cohort"]["researchSeeds"]["first"]),
        int(protocol["cohort"]["researchSeeds"]["last"]) + 1,
    ):
        delta: dict[str, float] = {}
        for aspect in (target, control):
            old, new = off[(aspect, seed)], on[(aspect, seed)]
            old_value = exact.card_metric(old, spec)
            new_value = exact.card_metric(new, spec)
            delta[aspect] = new_value - old_value
            if aspect == target:
                target_values.extend((old_value, new_value))
            outcome_changes += int(old["outcome"] != new["outcome"])
            fault_changes += int(exact.blocked.is_fault(old) != exact.blocked.is_fault(new))
            duration_changes.append(float(new["turns"]) - float(old["turns"]))
        movement.append(delta[target] - delta[control])
    scale = statistics.pstdev(target_values)
    endpoint = exact.fitted_interval(movement, scale, protocol)
    duration = exact.fitted_interval(duration_changes, 1.0, protocol)
    threshold = float(protocol["interferenceGate"]["standardisedEndpointMagnitude"])
    duration_limit = float(protocol["interferenceGate"]["durationMagnitudeTurns"])
    expand = endpoint["p025"] >= threshold or endpoint["p975"] <= -threshold \
        or duration["p025"] >= duration_limit or duration["p975"] <= -duration_limit \
        or outcome_changes > 0 or fault_changes > 0
    return {
        "standardisedTargetMinusControlABMovement": endpoint,
        "durationMovement": duration,
        "outcomeChanges": outcome_changes,
        "faultChanges": fault_changes,
        "expand": expand,
    }


def analyse_initial(protocol: dict[str, Any], rows: list[dict[str, Any]]) \
        -> tuple[dict[str, Any], list[str]]:
    packages = {
        package: exact.package_result(protocol, package, cells(rows, package, 1))
        for package in sorted(protocol["packages"])
    }
    after_off = exact.package_result(
        protocol, AFTERIMAGE, cells(rows, AFTERIMAGE, 0)
    )
    gain = structural_gain(
        protocol, AFTERIMAGE, cells(rows, AFTERIMAGE, 0), cells(rows, AFTERIMAGE, 1)
    )
    anchors: dict[str, Any] = {}
    expansions: list[str] = []
    for package in sorted(protocol["packages"]):
        if package == AFTERIMAGE:
            continue
        anchor = anchor_interference(
            protocol, package, cells(rows, package, 0),
            [row for row in cells(rows, package, 1) if row["arm"] == "AB"],
        )
        anchors[package] = anchor
        if anchor["expand"]:
            expansions.append(package)
    return {
        "packagesAtOrderOn": packages,
        "afterimageAtOrderOff": after_off,
        "afterimageStructureGain": gain,
        "sharedABInterferenceAnchors": anchors,
    }, expansions


def decision(protocol: dict[str, Any], analysis: dict[str, Any]) -> tuple[int, str]:
    packages = analysis["packagesAtOrderOn"]
    admitted = {name for name, result in packages.items() if result["clear"]}
    required_dusk = set(protocol["admissionSet"]["requiredDuskPackages"])
    ash = set(protocol["admissionSet"]["supplementalAshPackages"])
    enough_packages = required_dusk <= admitted \
        and len(admitted & ash) >= int(protocol["admissionSet"]["minimumSupplementalAshPackages"])
    gain = analysis["afterimageStructureGain"]
    if enough_packages and gain["p025"] > 0:
        return 1, "freeze-one-structural-candidate-for-independent-heldout-confirmation"
    required_failure = any(packages[name]["decisiveFailure"] for name in required_dusk)
    ash_failures = sum(packages[name]["decisiveFailure"] for name in ash)
    too_many_ash_failures = ash_failures > len(ash) \
        - int(protocol["admissionSet"]["minimumSupplementalAshPackages"])
    if packages[AFTERIMAGE]["decisiveFailure"] or gain["p975"] <= 0 \
            or required_failure or too_many_ash_failures:
        return 2, "close-package-order-grammar-continue-next-structural-mechanism"
    return 3, "inconclusive-at-preregistered-cap"


def enforce_caps(protocol: dict[str, Any], protocol_sha: str, db: Any,
                 started: float) -> int:
    observed = protocol_observation_count(db, protocol_sha)
    if observed > int(protocol["budget"]["maximumNewSimulatorObservationRows"]):
        raise RuntimeError("package-order observation cap exceeded")
    if time.monotonic() - started > float(protocol["budget"]["maximumWallTimeSeconds"]):
        raise TimeoutError("package-order wall-time cap reached")
    return observed


def execute() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to rerun completed package-order discovery")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    source = verify_entry(protocol, protocol_sha)
    started = time.monotonic()
    db = core.open_ledger()
    core.record(db, "protocol", protocol_sha, protocol)
    core.record(db, "source-identity", core.sha(core.canonical(source).encode()), source)
    rows = core.run_plan(
        db, protocol_sha, plan_for(protocol, protocol_sha, initial_rows(protocol))
    )["rows"]
    observed = enforce_caps(protocol, protocol_sha, db, started)
    if observed != int(protocol["budget"]["initialSimulatorObservationRows"]):
        raise RuntimeError("initial observation count missed its frozen boundary")
    analysis, expansions = analyse_initial(protocol, rows)
    for package in expansions:
        extra = panel_rows(protocol, package, 0, ("none", "A", "B"))
        rows.extend(core.run_plan(
            db, protocol_sha, plan_for(protocol, protocol_sha, extra)
        )["rows"])
        analysis.setdefault("expandedOrderOffPackages", {})[package] = {
            "packageAtOrderOff": exact.package_result(
                protocol, package, cells(rows, package, 0)
            ),
            "structureGain": structural_gain(
                protocol, package, cells(rows, package, 0), cells(rows, package, 1)
            ),
        }
        observed = enforce_caps(protocol, protocol_sha, db, started)
    expected = int(protocol["budget"]["initialSimulatorObservationRows"]) \
        + len(expansions) * int(protocol["budget"]["rowsPerOptionalExpansion"])
    if observed != expected:
        raise RuntimeError("staged observation count drifted")
    boundary, result = decision(protocol, analysis)
    final = {
        "schemaVersion": 1,
        "decisionBoundary": boundary,
        "decision": result,
        "protocolSha256": protocol_sha,
        "runnerSha256": source["runnerSha256"],
        "newSimulatorObservationRows": observed,
        "protectedSeedRows": 0,
        "optionalExpansions": expansions,
        **analysis,
    }
    analysis_sha, _ = core.cache_json(final)
    core.record(db, "analysis", f"post-v38-package-order-discovery:analysis:{protocol_sha}", {
        **final, "analysisSha256": analysis_sha,
    })
    summary = {
        "schemaVersion": 1,
        "decisionBoundary": boundary,
        "decision": result,
        "protocolSha256": protocol_sha,
        "runnerSha256": source["runnerSha256"],
        "executionManifestSha256": source["executionManifestSha256"],
        "analysisSha256": analysis_sha,
        "structuralCandidate": protocol["structuralCandidate"],
        "newSimulatorObservationRows": observed,
        "protectedSeedRows": 0,
        "optionalExpansions": expansions,
        "wallTimeSeconds": time.monotonic() - started,
        "authority": protocol["decisionRules"][
            "successAuthority" if boundary == 1
            else "futilityAuthority" if boundary == 2
            else "inconclusiveAuthority"
        ],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    summary_sha, _ = core.cache_json(summary)
    core.record(db, "analysis", f"post-v38-package-order-discovery:summary:{protocol_sha}", {
        **summary, "summarySha256": summary_sha,
    })
    print(core.canonical({**summary, "summarySha256": summary_sha}))


def record_inconclusive(error: Exception) -> None:
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    with core.open_ledger() as db:
        observations = protocol_observation_count(db, protocol_sha)
    summary = {
        "schemaVersion": 1,
        "decisionBoundary": 3,
        "decision": "inconclusive-at-preregistered-cap",
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "newSimulatorObservationRows": observations,
        "protectedSeedRows": 0,
        "faultType": type(error).__name__,
        "fault": str(error),
        "authority": "Do not rerun or extend this protocol.",
    }
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite an existing discovery summary") from error
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical(summary))


def validate_design() -> None:
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    source = verify_entry(protocol, protocol_sha)
    planned = initial_rows(protocol)
    synthetic: list[dict[str, Any]] = []
    for row in planned:
        item = {**row, "outcome": "win", "turns": 1, "error": "", "cards": {}}
        target = str(protocol["packages"][row["package"]]["aspect"])
        enabled = "package-order-1" in row["context"]
        unchanged_anchor = row["package"] != AFTERIMAGE
        if (enabled or unchanged_anchor) and row["arm"] == "AB" \
                and row["aspect"] == target:
            item["cards"] = exact.synthetic_cards(
                str(row["package"]), protocol["packages"][row["package"]]
            )
        synthetic.append(item)
    analysis, expansions = analyse_initial(protocol, synthetic)
    boundary, result = decision(protocol, analysis)
    if boundary != 1 or expansions:
        raise AssertionError("positive package-order decision self-check failed")
    print(core.canonical({
        "status": "PASS",
        "decision": result,
        "protocolSha256": protocol_sha,
        "runnerSha256": source["runnerSha256"],
        "initialRows": len(planned),
    }))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "execute"))
    args = parser.parse_args()
    if args.command == "validate":
        validate_design()
    else:
        try:
            execute()
        except Exception as error:
            record_inconclusive(error)
            raise


if __name__ == "__main__":
    main()
