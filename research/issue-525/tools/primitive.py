#!/usr/bin/env python3
"""One minimal level-3 effect primitive for issue #525 Phase C."""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path

import synthesise as phase_c


ROOT = phase_c.ROOT
SOURCE = phase_c.SOURCE
FAMILY = "dusk-branch-flare-l3"
SOURCE_FAMILY = "dusk-cinder-cut-l2"
PATCH_ARTIFACT = ROOT / "artifacts/research-kindle-damage-primitive-v1.patch"
LEVEL2_FREEZE = ROOT / "artifacts/phase-c-level2-candidate-freeze-v1.json"
LEVEL2_RESULT = ROOT / "artifacts/phase-c-level2-validation-v1.json"

PACKAGE = {
    "family": FAMILY, "package": "dusk-branch-flare", "aspect": "duskblade",
    "nodes": ("cinderCut", "offering", "verdantBranch"), "response": "directDamage",
    "edges": (
        {"id": "cinderCut->verdantBranch", "producer": "cinderCut",
         "consumer": "verdantBranch", "probe": "branch"},
        {"id": "offering->verdantBranch", "producer": "offering",
         "consumer": "verdantBranch", "probe": "branch"},
    ),
}


def runtime_freeze() -> str:
    names = subprocess.run(["git", "diff", "--name-only"], cwd=SOURCE, text=True,
                           capture_output=True, check=True).stdout.splitlines()
    if names != ["domain/rules/combat.gd"]:
        raise RuntimeError(f"unexpected research runtime patch: {names}")
    patch = subprocess.run(["git", "diff", "--binary"], cwd=SOURCE, text=True,
                           capture_output=True, check=True).stdout
    if "kindleDamage" not in patch or patch.count("diff --git") != 1:
        raise RuntimeError("minimal primitive patch drift")
    if PATCH_ARTIFACT.exists():
        if PATCH_ARTIFACT.read_text() != patch:
            raise RuntimeError("immutable primitive patch drift")
    else:
        PATCH_ARTIFACT.write_text(patch)
    return phase_c.file_sha256(PATCH_ARTIFACT)


def level2_base() -> dict:
    failed = next(row for row in json.loads(LEVEL2_RESULT.read_text())["results"]
                  if row["family"] == SOURCE_FAMILY)
    rows = json.loads(LEVEL2_FREEZE.read_text())["candidates"]
    return next(row for row in rows if row["id"] == failed["id"])


def candidates(patch_sha: str) -> list[dict]:
    base = level2_base()
    out = []
    for damage in (2, 3, 4):
        content = json.loads(Path(base["contentPath"]).read_text())
        branch = content["relics"]["verdantBranch"]
        branch["kindleDamage"] = damage
        branch["text"] = (f"Whenever a card is Kindled or burned away, draw 1 card and "
                          f"deal {damage} damage to ALL enemies.")
        candidate_id = phase_c.digest({
            "family": FAMILY, "baseCandidateId": base["id"], "kindleDamage": damage,
            "runtimePatchSha256": patch_sha,
        })
        path = ROOT / "candidates" / f"{candidate_id}.json"
        phase_c.write_json_once(path, content)
        out.append({
            "id": candidate_id, "family": FAMILY, "method": "exhaustive-level3",
            "parameters": {"/relics/verdantBranch/kindleDamage": damage},
            "contentPath": str(path), "contentSha256": phase_c.file_sha256(path),
            "baseCandidateId": base["id"], "runtimePatchSha256": patch_sha,
            "changedFields": base["changedFields"] + 1, "normalisedL1": base["normalisedL1"] + damage / 4,
        })
    return out


def prepare(connection) -> tuple[str, list[dict]]:
    patch_sha = runtime_freeze()
    phase_c.PACKAGES[FAMILY] = PACKAGE
    rows = candidates(patch_sha)
    for row in rows:
        path = Path(row["contentPath"])
        identity = phase_c.digest({"kind": "candidate-content", "sha256": row["contentSha256"]})
        connection.execute(
            "insert or ignore into object values(?,525,'candidate-content',?,?,?)",
            (identity, row["contentSha256"], str(path.relative_to(ROOT)), path.stat().st_size),
        )
    connection.commit()
    freeze = {
        "schemaVersion": 1, "issue": 525, "level": 3,
        "expressibilityFailure": "Existing draw and exhaust primitives moved the local mediator but did not produce held-out complementarity, package activation or non-regressed wins.",
        "primitive": "Optional verdantBranch.kindleDamage; positive values deal fixed non-attack damage to every living enemy after a Kindle/burn. Missing or zero is the exact legacy path.",
        "runtimePatchSha256": patch_sha, "candidateCount": len(rows), "candidates": rows,
    }
    phase_c.write_json_once(ROOT / "artifacts/phase-c-level3-candidate-freeze-v1.json", freeze)
    return patch_sha, rows


def marked_plan(candidate: dict, seeds: dict[str, tuple[int, ...]], fidelity: str,
                patch_sha: str) -> dict:
    value = phase_c.plan(candidate, seeds, fidelity)
    value["runtimePatchSha256"] = patch_sha
    for row in value["rows"]:
        row["runtimePatchSha256"] = patch_sha
    return value


def prove_legacy_identity(connection, patch_sha: str) -> dict:
    base = level2_base()
    plan_path = next(path for path in sorted((ROOT / "work/batches").glob("*.plan.json"))
                     if (lambda value: value.get("candidateId") == base["id"]
                         and value.get("stage") == "issue-525-phase-c-level2-validation-v1")(
                             json.loads(path.read_text())))
    old_plan = json.loads(plan_path.read_text())
    specs = [dict(row, runtimePatchSha256=patch_sha) for row in old_plan["rows"][:16]]
    fidelity = "issue-525-phase-c-level3-legacy-identity-v1"
    value = {key: old_plan[key] for key in (
        "schemaVersion", "issue", "sourceCommit", "candidateId", "content")}
    value.update({"stage": fidelity, "runtimePatchSha256": patch_sha, "rows": specs})
    prior = {}
    for raw, in connection.execute(
            "select row_json from sim_row where candidate_id=? and fidelity=?",
            (base["id"], "issue-525-phase-c-level2-validation-v1")):
        row = json.loads(raw)
        row.pop("identitySha256", None)
        row.pop("contentSemanticSha256", None)
        prior[row["id"]] = row
    output = phase_c.run_plan(connection, base, value, fidelity)
    if any(row != prior.get(row["id"]) for row in output):
        raise RuntimeError("zero/absent primitive changed the legacy path")
    result = {"rows": len(output), "exactMatches": len(output),
              "runtimePatchSha256": patch_sha, "baseCandidateId": base["id"],
              "priorFidelity": "issue-525-phase-c-level2-validation-v1"}
    phase_c.write_json_once(ROOT / "artifacts/phase-c-level3-legacy-identity-v1.json", result)
    phase_c.record(connection, "phase-c-level3-legacy-identity", result)
    return result


def screen() -> dict:
    phase_c.verify_authority()
    connection = phase_c.open_ledger()
    patch_sha, rows = prepare(connection)
    legacy = prove_legacy_identity(connection, patch_sha)
    results = []
    for candidate in rows:
        fidelity = "issue-525-phase-c-level3-screen-v1"
        output = phase_c.run_plan(connection, candidate, marked_plan(
            candidate, {"discovery": phase_c.SCREEN_SEEDS}, fidelity, patch_sha), fidelity)
        analysed = phase_c.analyse(output, FAMILY, strict=False)
        results.append({**candidate, "rows": len(output), "score": analysed["score"],
                        "edges": analysed["edges"], "panels": analysed["panels"]})
    chosen = max(results, key=lambda row: (row["score"], -row["changedFields"],
                                           -row["normalisedL1"], row["id"]))
    recommendation = {key: chosen[key] for key in (
        "id", "family", "parameters", "contentPath", "contentSha256", "baseCandidateId",
        "runtimePatchSha256", "changedFields", "normalisedL1", "score")}
    result = {"schemaVersion": 1, "issue": 525,
              "decision": "VALIDATE_MINIMAL_PRIMITIVE_RECOMMENDATION",
              "legacyIdentity": legacy, "screenRows": sum(row["rows"] for row in results),
              "recommendation": recommendation, "candidates": results}
    phase_c.write_json_once(ROOT / "artifacts/phase-c-level3-screen-v1.json", result)
    phase_c.record(connection, "phase-c-level3-screen", {
        "rows": result["screenRows"], "recommendation": recommendation["id"],
        "runtimePatchSha256": patch_sha,
    })
    print(phase_c.canonical({key: result[key] for key in (
        "decision", "legacyIdentity", "screenRows", "recommendation")}))
    return result


def validate() -> dict:
    phase_c.verify_authority()
    connection = phase_c.open_ledger()
    patch_sha, rows = prepare(connection)
    available = {row["id"]: row for row in rows}
    recommendation = json.loads((ROOT / "artifacts/phase-c-level3-screen-v1.json").read_text())[
        "recommendation"]
    candidate = available[recommendation["id"]]
    fidelity = "issue-525-phase-c-level3-validation-v1"
    output = phase_c.run_plan(connection, candidate, marked_plan(candidate, {
        "discovery": phase_c.DISCOVERY_SEEDS, "validation": phase_c.VALIDATION_SEEDS,
    }, fidelity, patch_sha), fidelity)
    analysed = phase_c.analyse(output, FAMILY, strict=True)
    phase_c_rows = connection.execute(
        "select count(*) from sim_row where is_new=1 and fidelity like 'issue-525-phase-c%'"
    ).fetchone()[0]
    if phase_c_rows > 40000:
        raise RuntimeError("preregistered Phase-C probe/panel row ceiling exceeded")
    decision = "PROCEED_TO_FULL_RUN_PACKAGE_ADMISSION" if analysed[
        "admittedAtProbePanelGate"] else "MINIMAL_PRIMITIVE_VALIDATION_FAILED"
    result = {"schemaVersion": 1, "issue": 525, "decision": decision,
              "phaseCProbePanelRows": phase_c_rows, "candidate": candidate, **analysed}
    phase_c.write_json_once(ROOT / "artifacts/phase-c-level3-validation-v1.json", result)
    phase_c.record(connection, "phase-c-level3-validation", {
        "decision": decision, "phaseCProbePanelRows": phase_c_rows,
        "candidateId": candidate["id"], "runtimePatchSha256": patch_sha,
    })
    print(phase_c.canonical({"decision": decision, "phaseCProbePanelRows": phase_c_rows,
                             "candidateId": candidate["id"],
                             "parameters": candidate["parameters"]}))
    return result


def self_check() -> None:
    assert PACKAGE["response"] == "directDamage" and len(PACKAGE["edges"]) == 2
    assert [2, 3, 4] == list(range(2, 5))
    print(phase_c.canonical({"status": "PASS", "level3Families": 1,
                             "maximumPhaseCRows": 40000}))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("self-check", "screen", "validate"))
    args = parser.parse_args()
    if args.command == "self-check":
        self_check()
    elif args.command == "screen":
        screen()
    else:
        validate()


if __name__ == "__main__":
    main()
