#!/usr/bin/env python3
"""Seal the evidence-backed terminal disposition for Glassvow issue #525."""

from __future__ import annotations

import json
import sqlite3
import subprocess
from pathlib import Path

import synthesise as phase_c


ROOT = phase_c.ROOT
SOURCE = phase_c.SOURCE
LEDGER = phase_c.LEDGER
PATCH = ROOT / "artifacts/research-kindle-damage-primitive-v1.patch"
PATCH_SHA256 = "b74c46fa6d7b9c44ae42a6863a069ef0a732bd6ce35e35bbee28d1393beef9b8"


def load(relative: str) -> dict:
    return json.loads((ROOT / relative).read_text())


def write_text_once(path: Path, text: str) -> None:
    if path.exists():
        if path.read_text() != text:
            raise RuntimeError(f"immutable output drift: {path}")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


def upper_standardised(summary: dict) -> float:
    return summary["pairedBootstrapP95"] / summary["scale"]


def selected_result(rows: list[dict], candidate_id: str) -> dict:
    return next(row for row in rows if row.get("candidateId", row.get("id")) == candidate_id)


def package_inventory() -> tuple[list[dict], dict]:
    positive = load("artifacts/phase-c-positive-control-v1.json")
    level1 = load("artifacts/phase-c-level1-validation-v1.json")
    ash_selected = level1["selected"][0]
    ash = selected_result(level1["results"], ash_selected["candidateId"])
    level2 = load("artifacts/phase-c-level2-validation-v1.json")
    ward_selected = level2["selected"][0]
    ward = selected_result(level2["results"], ward_selected["id"])
    primitive = load("artifacts/phase-c-level3-validation-v1.json")
    edge_uppers = {key: upper_standardised(value) for key, value in primitive["edges"].items()}
    panel_uppers = {key: upper_standardised(value["activation"])
                    for key, value in primitive["panels"].items()}
    inventory = [
        {
            "aspect": "ashwarden", "package": "hand-size-payoff",
            "status": "ISSUE_524_COMPLETE_PACKAGE_REPRODUCED",
            "candidateId": positive["candidateId"], "newRows": positive["rows"],
            "discoveryPass": positive["panels"]["discovery"]["packagePass"],
            "validationPass": positive["panels"]["validation"]["packagePass"],
        },
        {
            "aspect": "ashwarden", "package": "ash-poison-catalyst",
            "status": "PROBE_PANEL_PROMOTABLE_NOT_FULL_RUN_ADMITTED",
            "candidateId": ash_selected["candidateId"], "contentSha256": ash_selected["contentSha256"],
            "parameters": ash_selected["parameters"],
            "discoveryPass": ash["panels"]["discovery"]["packagePass"],
            "validationPass": ash["panels"]["validation"]["packagePass"],
        },
        {
            "aspect": "duskblade", "package": "ward-mirror-edge",
            "status": "PROBE_PANEL_PROMOTABLE_NOT_FULL_RUN_ADMITTED",
            "candidateId": ward_selected["id"], "contentSha256": ward_selected["contentSha256"],
            "parameters": ward_selected["parameters"],
            "discoveryPass": ward["panels"]["discovery"]["packagePass"],
            "validationPass": ward["panels"]["validation"]["packagePass"],
        },
        {
            "aspect": "duskblade", "package": "dusk-branch-flare",
            "status": "REJECTED_WITH_SUFFICIENT_HELD_OUT_PRECISION",
            "candidateId": primitive["candidate"]["id"],
            "contentSha256": primitive["candidate"]["contentSha256"],
            "runtimePatchSha256": primitive["candidate"]["runtimePatchSha256"],
            "parameters": primitive["candidate"]["parameters"],
            "edgeStandardisedUpper95": edge_uppers,
            "panelActivationStandardisedUpper95": panel_uppers,
            "practicalTarget": 0.25,
            "discoveryPass": primitive["panels"]["discovery"]["packagePass"],
            "validationPass": primitive["panels"]["validation"]["packagePass"],
        },
    ]
    precision = {
        "maximumHeldOutEdgeStandardisedUpper95": max(
            value for key, value in edge_uppers.items() if key.endswith("|validation")),
        "heldOutPanelActivationStandardisedUpper95": panel_uppers["validation"],
        "target": 0.25,
        "targetRuledOut": max(
            value for key, value in edge_uppers.items() if key.endswith("|validation")) < 0.25
            and panel_uppers["validation"] < 0.25,
    }
    return inventory, precision


def verify_and_counts(connection: sqlite3.Connection) -> tuple[dict, dict]:
    phase_c.verify_authority()
    if phase_c.file_sha256(PATCH) != PATCH_SHA256:
        raise RuntimeError("primitive patch hash drift")
    diff = subprocess.run(["git", "diff", "--binary"], cwd=SOURCE, text=True,
                          capture_output=True, check=True).stdout
    if diff != PATCH.read_text():
        raise RuntimeError("detached runtime differs from the frozen primitive patch")
    parse = subprocess.run(
        [str(SOURCE / "tools/check_scripts.sh"), "domain/rules/combat.gd", str(phase_c.RUNNER)],
        cwd=SOURCE, text=True, capture_output=True,
    )
    if parse.returncode or "scripts OK (2 checked)" not in parse.stdout:
        raise RuntimeError(f"targeted parse gate failed: {parse.stdout}\n{parse.stderr}")
    diff_check = subprocess.run(["git", "diff", "--check"], cwd=SOURCE, text=True,
                                capture_output=True)
    if diff_check.returncode:
        raise RuntimeError(f"research patch whitespace error: {diff_check.stdout}{diff_check.stderr}")
    before = connection.execute("select count(*) from sim_row").fetchone()[0]
    rerun = subprocess.run(["python3", str(ROOT / "tools/primitive.py"), "validate"],
                           cwd=ROOT, text=True, capture_output=True)
    if rerun.returncode or "MINIMAL_PRIMITIVE_VALIDATION_FAILED" not in rerun.stdout:
        raise RuntimeError(f"deterministic cache rerun failed: {rerun.stdout}\n{rerun.stderr}")
    after = connection.execute("select count(*) from sim_row").fetchone()[0]
    if before != after:
        raise RuntimeError("deterministic rerun added simulator rows")
    integrity = connection.execute("pragma integrity_check").fetchone()[0]
    duplicate = connection.execute(
        "select count(*)-count(distinct identity_sha256) from sim_row"
    ).fetchone()[0]
    reused = connection.execute("select count(*) from sim_row where is_new=0").fetchone()[0]
    new = connection.execute("select count(*) from sim_row where is_new=1").fetchone()[0]
    exclusions = connection.execute("select count(*) from exclusion").fetchone()[0]
    quarantines = connection.execute("select count(*) from quarantined_readout").fetchone()[0]
    seed_min, seed_max = connection.execute(
        "select min(seed),max(seed) from sim_row where is_new=1"
    ).fetchone()
    protected = connection.execute(
        "select count(*) from sim_row where is_new=1 and seed between 3000 and 5399"
    ).fetchone()[0]
    counts = dict(connection.execute(
        "select fidelity,count(*) from sim_row group by fidelity order by fidelity"
    ))
    objects = list(connection.execute(
        "select sha256,relative_path,bytes from object order by identity_sha256"
    ))
    for sha, relative, size in objects:
        path = ROOT / relative
        if not path.is_file() or path.stat().st_size != size or phase_c.file_sha256(path) != sha:
            raise RuntimeError(f"cache drift: {relative}")
    if (integrity, duplicate, reused, new, exclusions, quarantines, protected) != (
            "ok", 0, 7040, 39968, 504, 3, 0):
        raise RuntimeError("ledger cohort or exclusion drift")
    budget = {
        "schemaVersion": 1, "issue": 525,
        "phaseA": {"controlledOrQueryRows": 0, "ceiling": 2048, "wholeRunRows": 0},
        "phaseC": {"controlledMicrodeckShortPanelRows": new, "ceiling": 40000,
                   "remaining": 40000 - new, "fullRunRows": 0, "fullRunCeiling": 12288},
        "phaseD": {"partialOrShortRows": 0, "fullRunRows": 0, "reached": False},
        "phaseE": {"rewardFullRunRows": 0, "jointFullRunRows": 0, "reached": False},
        "cumulativeWholeRunRows": 0, "initialWholeRunCeiling": 73728,
        "extensionUsed": False, "newSeedMinimum": seed_min, "newSeedMaximum": seed_max,
        "acceptanceOrReserveRows": protected, "rowsByFidelity": counts,
        "stop": "Phase-C package minimum failed after the final authorised primitive family; later phases were not legal to enter.",
    }
    verification = {
        "schemaVersion": 1, "issue": 525, "status": "PASS",
        "sourceCommit": phase_c.SOURCE_COMMIT, "godotVersion": phase_c.GODOT_VERSION,
        "contentSha256": phase_c.file_sha256(phase_c.CONTENT),
        "baseSimulatorSha256": load("protocols/preregistration-v1.json")["identities"]["baseSimulatorSha256"],
        "mechanismRunnerSha256": phase_c.file_sha256(phase_c.RUNNER),
        "runtimePatchSha256": phase_c.file_sha256(PATCH),
        "targetedParseGate": parse.stdout.strip(), "gitDiffCheck": "PASS",
        "ledgerIntegrity": integrity, "duplicateIdentityRows": duplicate,
        "reusedRows": reused, "newRows": new, "excludedIssue519Rows": exclusions,
        "quarantinedIssue521Readouts": quarantines, "cacheObjectsVerified": len(objects),
        "deterministicRerunAddedRows": after - before,
        "acceptanceOrReserveRows": protected, "productWideCiRun": False,
        "githubActionsRun": False, "fullProductTestsRun": False,
    }
    return budget, verification


def seal() -> dict:
    connection = phase_c.open_ledger()
    budget, verification = verify_and_counts(connection)
    inventory, precision = package_inventory()
    terminal = {
        "schemaVersion": 1, "issue": 525,
        "status": "TERMINAL_STOP_EXHAUSTED_PREREGISTERED_DESIGN_FAMILIES",
        "scope": "The missing second Duskblade package only; not a game-wide or programme-wide impossibility claim.",
        "sourceCommit": phase_c.SOURCE_COMMIT, "godotVersion": phase_c.GODOT_VERSION,
        "contentSha256": phase_c.file_sha256(phase_c.CONTENT),
        "runtimePatchSha256": phase_c.file_sha256(PATCH),
        "reusedRows": verification["reusedRows"], "newRows": verification["newRows"],
        "excludedRows": verification["excludedIssue519Rows"],
        "quarantinedReadouts": verification["quarantinedIssue521Readouts"],
        "designFamilyExhaustion": [
            {"level": 1, "family": "dusk-kindle-draw-l1", "candidatesScreened": 16,
             "recommendationsIndependentlyValidated": 2,
             "result": "local interaction did not reproduce on both splits; panel win regressed"},
            {"level": 2, "family": "dusk-cinder-cut-l2", "newDefinitions": 1,
             "candidatesScreened": 8, "recommendationsIndependentlyValidated": 1,
             "result": "held-out package activation upper bound 0.052 SD and win delta -0.047"},
            {"level": 3, "family": "dusk-branch-flare-l3", "newPrimitives": 1,
             "valuesExhaustivelyScreened": [2, 3, 4], "recommendationsIndependentlyValidated": 1,
             "result": "held-out edge and panel upper bounds rule out the 0.25-SD practical target"},
        ],
        "precision": precision, "packageInventory": inventory,
        "packageMinimum": {"requiredPerAspect": 2, "met": False,
                           "blockingAspect": "duskblade", "missingPackages": 1},
        "mutations": {"reached": False, "reason": "package minimum not met"},
        "detector": {"reached": False, "contract": None, "reason": "package minimum not met"},
        "slateAndJointSearch": {"reached": False, "reason": "detector not admitted"},
        "productCandidate": None, "issue421Handoff": None,
        "unresolvedProductDecision": (
            "Choose whether to authorise a different evidence-backed Duskblade mechanism degree of freedom "
            "beyond #525's exhausted one-card/one-primitive Kindle/Branch ladder, or leave the P9 package "
            "minimum unmet. #525 does not authorise that expansion."
        ),
        "claimsNotMade": ["autonomous balancing is impossible", "Glassvow cannot support multiple strategies",
                          "the three probe-panel candidates are shipping-authorised"],
        "issue421Disposition": "leave open and unassigned; do not run the final P9 exam",
        "successorDisposition": "do not create another issue or successor",
    }
    phase_c.write_json_once(ROOT / "artifacts/budget-and-stop-ledger-v1.json", budget)
    phase_c.write_json_once(ROOT / "artifacts/final-targeted-verification-v1.json", verification)
    phase_c.write_json_once(ROOT / "artifacts/terminal-stop-finding-v1.json", terminal)
    report = f"""# Issue #525 final research report

## Decision

Terminal stop under the issue's exhausted-design-family clause. This is bounded to the missing second Duskblade package and is not a claim that autonomous balancing or multi-strategy Glassvow is impossible.

## Evidence

- Reused rows: {verification['reusedRows']}; new rows: {verification['newRows']}; duplicate identities: 0.
- Excluded #519 identities: {verification['excludedIssue519Rows']}; quarantined #521 readouts: {verification['quarantinedIssue521Readouts']}.
- Ashwarden `hand-size-payoff` reproduced. Ashwarden `ash-poison-catalyst` and Duskblade `ward-mirror-edge` cleared discovery and held-out probe/panel gates, but were not promoted through full-run economy/policy admission because the package minimum failed first.
- The missing Duskblade Kindle/Branch family exhausted level-1 scalar, one-card level-2 and one-primitive level-3 designs. The final held-out edge upper bound was {precision['maximumHeldOutEdgeStandardisedUpper95']:.3f} SD and the panel activation upper bound was {precision['heldOutPanelActivationStandardisedUpper95']:.3f} SD, both below the 0.25-SD target.
- Phase C stopped at {budget['phaseC']['controlledMicrodeckShortPanelRows']}/{budget['phaseC']['ceiling']} rows. No whole runs, mutations, detector calibration, slates, joint search, acceptance/reserve seeds, product-wide CI or GitHub Actions were used.

## Disposition

No product candidate and no detector contract are returned. Leave #421 open and unassigned. The unresolved product decision is whether to authorise a different Duskblade mechanism degree of freedom beyond the exhausted #525 grammar; #525 itself does not authorise that expansion or a successor issue.
"""
    write_text_once(ROOT / "summaries/final-report-v1.md", report)
    close_payload = {
        "schemaVersion": 1, "issue": 525, "parent": 421,
        "status": terminal["status"], "productCandidate": None, "detectorContract": None,
        "sourceCommit": phase_c.SOURCE_COMMIT, "godotVersion": phase_c.GODOT_VERSION,
        "contentSha256": phase_c.file_sha256(phase_c.CONTENT),
        "runtimePatchSha256": phase_c.file_sha256(PATCH),
        "reusedRows": verification["reusedRows"], "newRows": verification["newRows"],
        "terminalFindingSha256": phase_c.file_sha256(ROOT / "artifacts/terminal-stop-finding-v1.json"),
        "budgetLedgerSha256": phase_c.file_sha256(ROOT / "artifacts/budget-and-stop-ledger-v1.json"),
        "verificationSha256": phase_c.file_sha256(ROOT / "artifacts/final-targeted-verification-v1.json"),
        "reportSha256": phase_c.file_sha256(ROOT / "summaries/final-report-v1.md"),
        "branchCreated": False, "commitCreated": False, "pullRequestCreated": False,
        "githubActionsRun": False, "productWideCiRun": False, "successorCreated": False,
        "issue421Claimed": False, "acceptanceOrReserveRows": 0,
    }
    phase_c.write_json_once(ROOT / "artifacts/campaign-close-v1.json", close_payload)
    phase_c.record(connection, "campaign-close", close_payload)
    connection.execute("pragma wal_checkpoint(truncate)").fetchall()
    integrity = {
        "schemaVersion": 1, "issue": 525, "databaseSha256": phase_c.file_sha256(LEDGER),
        "integrity": connection.execute("pragma integrity_check").fetchone()[0],
        "simRows": connection.execute("select count(*) from sim_row").fetchone()[0],
        "reusedRows": verification["reusedRows"], "newRows": verification["newRows"],
        "duplicateIdentityRows": connection.execute(
            "select count(*)-count(distinct identity_sha256) from sim_row").fetchone()[0],
        "cacheObjects": connection.execute("select count(*) from object").fetchone()[0],
        "excludedIssue519Rows": verification["excludedIssue519Rows"],
        "quarantinedIssue521Readouts": verification["quarantinedIssue521Readouts"],
    }
    phase_c.write_json_once(ROOT / "artifacts/ledger-integrity-v1.json", integrity)
    manifest_paths = [
        *sorted((ROOT / "protocols").glob("*")), *sorted((ROOT / "artifacts").glob("*")),
        *sorted((ROOT / "summaries").glob("*")), *sorted((ROOT / "tools").glob("*")),
        *sorted((ROOT / "candidates").glob("*")), *sorted((ROOT / "work/batches").glob("*.plan.json")),
        LEDGER, *sorted((ROOT / "cache/sha256").glob("*")),
    ]
    files = {}
    for path in manifest_paths:
        if not path.is_file() or path.name == "immutable-manifest-v1.json" \
                or "__pycache__" in path.parts:
            continue
        files[str(path.relative_to(ROOT))] = {
            "sha256": phase_c.file_sha256(path), "bytes": path.stat().st_size,
        }
    manifest = {
        "schemaVersion": 1, "issue": 525, "sourceCommit": phase_c.SOURCE_COMMIT,
        "godotVersion": phase_c.GODOT_VERSION, "verdict": terminal["status"],
        "fileCount": len(files), "files": files,
    }
    phase_c.write_json_once(ROOT / "immutable-manifest-v1.json", manifest)
    result = {**close_payload, "ledgerSha256": phase_c.file_sha256(LEDGER),
              "ledgerIntegritySha256": phase_c.file_sha256(ROOT / "artifacts/ledger-integrity-v1.json"),
              "manifestSha256": phase_c.file_sha256(ROOT / "immutable-manifest-v1.json"),
              "manifestFiles": len(files)}
    print(phase_c.canonical(result))
    return result


def self_check() -> None:
    sample = {"pairedBootstrapP95": 1.0, "scale": 4.0}
    assert upper_standardised(sample) == 0.25
    print(phase_c.canonical({"status": "PASS", "terminalClause": "exhausted-design-families"}))


if __name__ == "__main__":
    parser = __import__("argparse").ArgumentParser()
    parser.add_argument("command", choices=("self-check", "seal"))
    args = parser.parse_args()
    self_check() if args.command == "self-check" else seal()
