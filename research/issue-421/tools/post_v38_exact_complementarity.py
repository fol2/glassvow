#!/usr/bin/env python3
"""Exact-candidate four-package causal panel for Glassvow issue #421."""

from __future__ import annotations

import argparse
import json
import statistics
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_blocked_crn as blocked
import post_v38_knob_identity as identity_v1
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-exact-complementarity-v1.json"
MANIFEST = core.ROOT / "execution/post-v38-exact-complementarity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-exact-complementarity-v1.json"


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
        "auditRunnerSha256": core.file_sha(
            core.ROOT / "post_v38_exact_complementarity_audit.py"
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
    audit_path = core.ROOT / protocol["entryGate"]["auditSummary"]
    if core.file_sha(audit_path) != protocol["entryGate"]["auditSummarySha256"]:
        raise RuntimeError("zero-row complementarity audit drifted")
    audit = json.loads(audit_path.read_text())
    if audit.get("decision") != "heldout-four-package-causal-panel-required" \
            or audit.get("newSimulatorObservationRows") != 0:
        raise RuntimeError("zero-row audit did not authorise this panel")
    content_sha = protocol["candidate"]["contentSha256"]
    content_path = core.CACHE / f"{content_sha}.json"
    if not content_path.is_file() or core.file_sha(content_path) != content_sha:
        raise RuntimeError("exact candidate content is missing or corrupt")
    hand_size = protocol["admissionSet"]["immutableAdmittedAshHandSizePackage"]
    pair_hashes: set[str] = set()
    for sha in (content_sha, str(hand_size["liveContentSha256"])):
        content = json.loads((core.CACHE / f"{sha}.json").read_text())
        pair = {card: content["cards"][card]
                for card in hand_size["relevantCardIds"]}
        pair_hashes.add(core.sha((core.canonical(pair) + "\n").encode()))
    if pair_hashes != {str(hand_size["relevantCardPairSha256"])}:
        raise RuntimeError("immutable hand-size package leaves drifted")
    if not MANIFEST.is_file():
        raise RuntimeError("execution manifest is missing")
    manifest = json.loads(MANIFEST.read_text())
    required = {
        "protocolSha256": protocol_sha,
        "runnerSha256": actual["runnerSha256"],
        "probeSha256": actual["probeSha256"],
        "auditSummarySha256": core.file_sha(audit_path),
        "ledgerSha256BeforeFirstObservation": protocol["ledgerFreeze"]["sha256"],
        "ledgerRecordsBeforeFirstObservation": protocol["ledgerFreeze"]["records"],
        "maximumSimulatorObservationRows": protocol["budget"][
            "maximumNewSimulatorObservationRows"
        ],
        "maximumWallTimeSeconds": protocol["budget"]["maximumWallTimeSeconds"],
        "maximumModelContextTokensDuringExecutionAndDecision": 0,
    }
    for key, expected in required.items():
        if manifest.get(key) != expected:
            raise RuntimeError(f"execution manifest drifted at {key}")
    ledger = identity_v1.ledger_identity()
    if ledger != protocol["ledgerFreeze"]:
        with core.open_ledger() as db:
            if core.existing_record(db, protocol_sha) is None:
                raise RuntimeError("ledger changed before the first causal-panel row")
    return {**actual, "executionManifestSha256": core.file_sha(MANIFEST)}


def panel_rows(protocol: dict[str, Any], only_package: str | None = None) \
        -> list[dict[str, Any]]:
    policy = protocol["cohort"]["policyIdentity"]
    seeds = protocol["cohort"]["researchSeeds"]
    settings = protocol["candidate"]["research421"]
    rows: list[dict[str, Any]] = []
    for index, seed in enumerate(range(int(seeds["first"]), int(seeds["last"]) + 1)):
        for package in sorted(protocol["packages"]):
            if only_package is not None and package != only_package:
                continue
            spec = protocol["packages"][package]
            base = ["strike"] * 8 if package == "dusk-afterimage-guard" \
                else ["strike"] * 4 + ["brace"] * 4
            for aspect in ("duskblade", "ashwarden"):
                for arm in core.ARMS:
                    producer = str(spec["producer"]) if arm in ("A", "AB") else "brace"
                    consumer = str(spec["consumer"]) if arm in ("B", "AB") else "strike"
                    rows.append({
                        "id": f"exact-panel-{package}-{aspect}-{arm}-{seed}",
                        "stage": "post-v38-exact-complementarity",
                        "package": package,
                        "edge": package,
                        "arm": arm,
                        "split": "heldout",
                        "context": "exact-candidate-Q2-W0",
                        "aspect": aspect,
                        "seed": seed,
                        "vow": 0,
                        "response": "combatUtility",
                        "mode": "pilot",
                        "maxTurns": 20,
                        "policyRoot": int(policy["root"]),
                        "policyIndex": index,
                        "research421": settings,
                        "deck": [*base, producer, consumer],
                        "enemies": ["gravewarden"],
                        "unlocks": ["aspect2"],
                    })
    expected = int(protocol["budget"][
        "rowsPerPackage" if only_package is not None
        else "maximumNewSimulatorObservationRows"
    ])
    if len(rows) != expected or len({row["id"] for row in rows}) != expected:
        raise ValueError("exact causal-panel rectangle is incomplete or duplicated")
    if any(3000 <= int(row["seed"]) <= 5399 for row in rows):
        raise ValueError("protected seed entered the causal panel")
    return rows


def plan_for(protocol: dict[str, Any], protocol_sha: str,
             rows: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "content": str(core.CACHE / f"{protocol['candidate']['contentSha256']}.json"),
        "rows": rows,
    }


def validate_rectangle(protocol: dict[str, Any], rows: list[dict[str, Any]]) -> None:
    seeds = protocol["cohort"]["researchSeeds"]
    expected = {
        (package, aspect, arm, seed)
        for package in protocol["packages"] for aspect in ("duskblade", "ashwarden")
        for arm in core.ARMS
        for seed in range(int(seeds["first"]), int(seeds["last"]) + 1)
    }
    observed = {
        (str(row["package"]), str(row["aspect"]), str(row["arm"]), int(row["seed"]))
        for row in rows
    }
    if observed != expected or len(rows) != len(expected):
        raise ValueError("causal-panel output rectangle drifted")


def card_metric(row: dict[str, Any], spec: dict[str, Any]) -> float:
    raw = float((row.get("cards") or {}).get(str(spec["consumer"]), {}).get(
        str(spec["cardMetric"]), 0
    ))
    return float(spec.get("cardMetricDirection", 1.0)) * raw


def fitted_interval(values: list[float], scale: float,
                    protocol: dict[str, Any]) -> dict[str, float]:
    return blocked.signed_interval(
        values, scale, int(protocol["budget"]["bootstrapResamples"])
    )


def package_result(protocol: dict[str, Any], package: str,
                   rows: list[dict[str, Any]]) -> dict[str, Any]:
    spec = protocol["packages"][package]
    target = str(spec["aspect"])
    control = "ashwarden" if target == "duskblade" else "duskblade"
    grouped: dict[tuple[str, int], dict[str, dict[str, Any]]] = {}
    for row in rows:
        if row["package"] == package:
            grouped.setdefault((str(row["aspect"]), int(row["seed"])), {})[
                str(row["arm"])
            ] = row
    if not grouped or any(set(block) != set(core.ARMS) for block in grouped.values()):
        raise ValueError(f"incomplete four-arm block for {package}")
    effects: dict[str, dict[int, float]] = {target: {}, control: {}}
    interactions: dict[str, dict[int, float]] = {target: {}, control: {}}
    target_scale_values: list[float] = []
    witnesses = 0
    faults = 0
    added_faults = 0
    duration_values: list[float] = []
    duration_missing = 0
    for aspect in (target, control):
        for (found_aspect, seed), block in sorted(grouped.items()):
            if found_aspect != aspect:
                continue
            values = {arm: card_metric(block[arm], spec) for arm in core.ARMS}
            if aspect == target:
                target_scale_values.extend(values.values())
            effects[aspect][seed] = values["AB"] - values["B"]
            interactions[aspect][seed] = (
                values["AB"] - values["A"] - values["B"] + values["none"]
            )
            block_faults = {arm: blocked.is_fault(block[arm]) for arm in core.ARMS}
            faults += sum(block_faults.values())
            added_faults += int(block_faults["AB"] and not any(
                block_faults[arm] for arm in ("none", "A", "B")
            ))
            if aspect == target:
                if interactions[aspect][seed] > 0 \
                        and core._combined_mechanism_fired(package, block["AB"]):
                    witnesses += 1
                if all(block[arm]["outcome"] == "win" for arm in core.ARMS):
                    duration_values.append(float(block["AB"]["turns"]) - min(
                        float(block[arm]["turns"]) for arm in ("none", "A", "B")
                    ))
                else:
                    duration_missing += 1
    scale = statistics.pstdev(target_scale_values)
    conditional = fitted_interval(list(effects[target].values()), scale, protocol)
    interaction = fitted_interval(list(interactions[target].values()), scale, protocol)
    separation = fitted_interval([
        interactions[target][seed] - interactions[control][seed]
        for seed in sorted(interactions[target])
    ], 1.0, protocol)
    duration = None if duration_missing else fitted_interval(duration_values, 1.0, protocol)
    target_value = float(protocol["gates"]["minimumStandardisedComplementarity"])
    minimum_witnesses = int(protocol["gates"]["minimumMechanismWitnesses"])
    duration_limit = float(protocol["gates"]["durationUpperBound"])
    clear = conditional["p025"] >= target_value \
        and interaction["p025"] >= target_value \
        and separation["p025"] > 0 \
        and witnesses >= minimum_witnesses \
        and faults == 0 and added_faults == 0 \
        and duration is not None and duration["p975"] <= duration_limit
    decisive_failure = conditional["p975"] < target_value \
        or interaction["p975"] < target_value \
        or separation["p975"] <= 0 \
        or witnesses < minimum_witnesses \
        or faults > 0 or added_faults > 0 or duration is None \
        or duration["p025"] > duration_limit
    return {
        "conditionalProducerEffect": conditional,
        "producerConsumerInteraction": interaction,
        "targetMinusControlInteraction": separation,
        "mechanismWitnesses": witnesses,
        "faults": faults,
        "addedFaults": added_faults,
        "durationABMinusBestSingle": duration,
        "durationMissingPairs": duration_missing,
        "clear": clear,
        "decisiveFailure": decisive_failure,
    }


def analyse(protocol: dict[str, Any], rows: list[dict[str, Any]]) -> dict[str, Any]:
    validate_rectangle(protocol, rows)
    packages = {
        package: package_result(protocol, package, rows)
        for package in sorted(protocol["packages"])
    }
    required_dusk = list(protocol["admissionSet"]["requiredDuskPackages"])
    supplemental_ash = list(protocol["admissionSet"]["supplementalAshPackages"])
    minimum_ash = int(protocol["admissionSet"]["minimumSupplementalAshPackages"])
    admitted = sorted(name for name, result in packages.items() if result["clear"])
    if all(name in admitted for name in required_dusk) \
            and sum(name in admitted for name in supplemental_ash) >= minimum_ash:
        decision, boundary = "admit-exact-complementarity-set", 1
    elif any(packages[name]["decisiveFailure"] for name in required_dusk) \
            or sum(packages[name]["decisiveFailure"] for name in supplemental_ash) \
            > len(supplemental_ash) - minimum_ash:
        decision, boundary = "reject-candidate-close-scalar-family-continue-structurally", 2
    else:
        decision, boundary = "inconclusive-at-preregistered-cap", 3
    return {
        "schemaVersion": 1,
        "decisionBoundary": boundary,
        "decision": decision,
        "admittedNewPackages": admitted,
        "immutableAdmittedPackage": protocol["admissionSet"][
            "immutableAdmittedAshHandSizePackage"
        ],
        "packages": packages,
    }


def enforce_wall_cap(protocol: dict[str, Any], started: float) -> None:
    if time.monotonic() - started > float(protocol["budget"]["maximumWallTimeSeconds"]):
        raise TimeoutError("exact causal-panel wall-time cap reached")


def execute() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to rerun a completed exact causal panel")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    identity = verify_entry(protocol, protocol_sha)
    started = time.monotonic()
    db = core.open_ledger()
    core.record(db, "protocol", protocol_sha, protocol)
    core.record(db, "source-identity", core.sha(core.canonical(identity).encode()), identity)
    rows: list[dict[str, Any]] = []
    for package in sorted(protocol["packages"]):
        output = core.run_plan(
            db, protocol_sha,
            plan_for(protocol, protocol_sha, panel_rows(protocol, package)),
        )
        rows.extend(output["rows"])
        observed = protocol_observation_count(db, protocol_sha)
        if observed > int(protocol["budget"]["maximumNewSimulatorObservationRows"]):
            raise RuntimeError("causal-panel observation cap exceeded")
        enforce_wall_cap(protocol, started)
        print(core.canonical({"stage": "exact-causal-panel", "package": package,
                              "protocolObservationRows": observed}), flush=True)
    validate_rectangle(protocol, rows)
    observed = protocol_observation_count(db, protocol_sha)
    if observed != int(protocol["budget"]["maximumNewSimulatorObservationRows"]):
        raise RuntimeError("causal-panel observation count does not match its frozen cap")
    enforce_wall_cap(protocol, started)
    result = analyse(protocol, rows)
    analysis = {
        **result,
        "protocolSha256": protocol_sha,
        "runnerSha256": identity["runnerSha256"],
        "newSimulatorObservationRows": observed,
        "protectedSeedRows": 0,
    }
    analysis_sha, _ = core.cache_json(analysis)
    core.record(db, "analysis", f"post-v38-exact-complementarity:analysis:{protocol_sha}", {
        **analysis, "analysisSha256": analysis_sha,
    })
    summary = {
        "schemaVersion": 1,
        "decisionBoundary": result["decisionBoundary"],
        "decision": result["decision"],
        "protocolSha256": protocol_sha,
        "runnerSha256": identity["runnerSha256"],
        "executionManifestSha256": identity["executionManifestSha256"],
        "analysisSha256": analysis_sha,
        "candidate": protocol["candidate"],
        "newSimulatorObservationRows": observed,
        "protectedSeedRows": 0,
        "wallTimeSeconds": time.monotonic() - started,
        "authority": protocol["decisionRules"][
            "successAuthority" if result["decisionBoundary"] == 1
            else "futilityAuthority" if result["decisionBoundary"] == 2
            else "inconclusiveAuthority"
        ],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    summary_sha, _ = core.cache_json(summary)
    core.record(db, "analysis", f"post-v38-exact-complementarity:summary:{protocol_sha}", {
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
        raise RuntimeError("refusing to overwrite an existing causal-panel summary") from error
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical(summary))


def synthetic_cards(package: str, spec: dict[str, Any]) -> dict[str, Any]:
    cards: dict[str, Any] = {str(spec["consumer"]): {str(spec["cardMetric"]): (
        -1 if float(spec.get("cardMetricDirection", 1.0)) < 0 else 1
    )}}
    if package == "ash-bloodfire-leech":
        cards.update({"bloodRite": {"status:bloodfire": 1},
                      "leechBlade": {"status:bloodfire": -1, "damage": 1}})
    elif package == "ash-poison-catalyst":
        cards.update({"toxicMist": {"status:mistbound": 1},
                      "catalyst": {"status:mistbound": -1,
                                   str(spec["cardMetric"]): 1}})
    elif package == "dusk-scoreline":
        cards.update({"chisel": {"status:scoreline": 1},
                      "executioner": {"status:scoreline": -1, "shatter": 1}})
    elif package == "dusk-afterimage-guard":
        cards.update({"defend": {"status:afterimage": 1},
                      "guardedStrike": {"status:afterimage": -1, "damage": 1}})
    return cards


def validate_design() -> None:
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    identity = verify_entry(protocol, protocol_sha)
    planned = panel_rows(protocol)
    synthetic: list[dict[str, Any]] = []
    for row in planned:
        target = str(protocol["packages"][row["package"]]["aspect"])
        item = {**row, "outcome": "win", "turns": 1, "error": "", "cards": {}}
        if row["arm"] == "AB" and row["aspect"] == target:
            item["cards"] = synthetic_cards(
                str(row["package"]), protocol["packages"][row["package"]]
            )
        synthetic.append(item)
    result = analyse(protocol, synthetic)
    if result["decision"] != "admit-exact-complementarity-set":
        raise AssertionError("positive causal-panel decision self-check failed")
    print(core.canonical({
        "status": "PASS",
        "protocolSha256": protocol_sha,
        "runnerSha256": identity["runnerSha256"],
        "packages": len(protocol["packages"]),
        "rows": len(planned),
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
