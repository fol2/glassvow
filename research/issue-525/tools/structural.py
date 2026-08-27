#!/usr/bin/env python3
"""Level-2 one-card escalation for issue #525 Phase C."""

from __future__ import annotations

import argparse
import copy
import json
import sqlite3
from pathlib import Path

from scipy.stats import qmc

import synthesise as phase_c


ROOT = phase_c.ROOT
FREEZE = ROOT / "artifacts/phase-c-level1-candidate-freeze-v1.json"
VALIDATION = ROOT / "artifacts/phase-c-level1-validation-v1.json"
SCREEN_SEEDS = phase_c.SCREEN_SEEDS
DISCOVERY_SEEDS = phase_c.DISCOVERY_SEEDS
VALIDATION_SEEDS = phase_c.VALIDATION_SEEDS

FAMILIES = {
    "ward-mirror-edge-l2": {
        "sourceFamily": "ward-double-l1", "package": "ward-mirror-edge",
        "aspect": "duskblade", "nodes": ("brace", "mirrorEdge", "fortify"),
        "response": "blockGain", "card": "mirrorEdge",
        "choices": {"damage": (6, 8, 10, 12), "block": (5, 7, 9, 11),
                    "rarity": ("common", "uncommon")},
        "edges": (
            {"id": "brace->fortify", "producer": "brace",
             "consumer": "fortify", "probe": "block"},
            {"id": "mirrorEdge->fortify", "producer": "mirrorEdge",
             "consumer": "fortify", "probe": "block"},
        ),
        "expressibilityGap": "The two block-double edges passed, but the package added 1.27-1.56 turns; existing cards provide no offensive block producer inside the package.",
    },
    "dusk-cinder-cut-l2": {
        "sourceFamily": "dusk-kindle-draw-l1", "package": "dusk-cinder-cut",
        "aspect": "duskblade", "nodes": ("cinderCut", "offering", "verdantBranch"),
        "response": "draw", "card": "cinderCut",
        "choices": {"cost": (0, 1), "damage": (5, 7, 9, 11),
                    "rarity": ("common", "uncommon")},
        "edges": (
            {"id": "cinderCut->verdantBranch", "producer": "cinderCut",
             "consumer": "verdantBranch", "probe": "branch"},
            {"id": "offering->verdantBranch", "producer": "offering",
             "consumer": "verdantBranch", "probe": "branch"},
        ),
        "expressibilityGap": "First Spark's own draw saturated the Branch interaction; a smallest exhaust attack exposes the supported Kindle-to-draw edge without borrowing the Ash hand-size payoff.",
    },
}


def level1_bases() -> dict[str, dict]:
    freeze = json.loads(FREEZE.read_text())
    candidates = {row["id"]: row for row in freeze["candidates"]}
    results = json.loads(VALIDATION.read_text())["results"]
    bases = {}
    for family in FAMILIES.values():
        rows = [row for row in results if row["family"] == family["sourceFamily"]]
        chosen = min(rows, key=lambda row: (row["changedFields"], row["normalisedL1"],
                                           -row["score"], row["candidateId"]))
        bases[family["sourceFamily"]] = candidates[chosen["candidateId"]]
    return bases


def card_definition(family_id: str, values: dict) -> dict:
    if family_id == "ward-mirror-edge-l2":
        damage, block = values["damage"], values["block"]
        return {
            "type": "attack", "rarity": values["rarity"], "cost": 1,
            "target": "enemy", "vfx": "slash",
            "effects": [{"kind": "dmg", "n": damage}, {"kind": "block", "n": block}],
            "up": {"effects": [{"kind": "dmg", "n": damage + 3},
                                {"kind": "block", "n": block + 3}],
                   "text": f"Deal @{damage + 3}@ damage. Gain #{block + 3}# Ward."},
            "name": "Mirror Edge", "text": f"Deal @{damage}@ damage. Gain #{block}# Ward.",
        }
    damage = values["damage"]
    return {
        "type": "attack", "rarity": values["rarity"], "cost": values["cost"],
        "target": "enemy", "vfx": "fire", "exhaust": True,
        "effects": [{"kind": "dmg", "n": damage}],
        "up": {"effects": [{"kind": "dmg", "n": damage + 3}],
               "text": f"Deal @{damage + 3}@ damage. Kindle."},
        "name": "Cinder Cut", "text": f"Deal @{damage}@ damage. Kindle.",
    }


def candidates() -> list[dict]:
    bases = level1_bases()
    out = []
    for index, (family_id, family) in enumerate(sorted(FAMILIES.items())):
        choices = family["choices"]
        names = sorted(choices)
        points = qmc.Sobol(len(names), scramble=True, seed=52520 + index).random_base2(5)
        seen = set()
        for point in points:
            values = {name: choices[name][min(int(point[offset] * len(choices[name])),
                                              len(choices[name]) - 1)]
                      for offset, name in enumerate(names)}
            key = phase_c.canonical(values)
            if key in seen:
                continue
            seen.add(key)
            base = bases[family["sourceFamily"]]
            content = json.loads(Path(base["contentPath"]).read_text())
            content["cards"][family["card"]] = card_definition(family_id, values)
            phase_c.synchronise_rarity(content, "cards", family["card"], values["rarity"])
            candidate_id = phase_c.digest({
                "family": family_id, "baseCandidateId": base["id"], "card": content["cards"][family["card"]],
            })
            path = ROOT / "candidates" / f"{candidate_id}.json"
            phase_c.write_json_once(path, content)
            out.append({
                "id": candidate_id, "family": family_id, "method": "sobol-level2",
                "parameters": values, "contentPath": str(path),
                "contentSha256": phase_c.file_sha256(path),
                "baseCandidateId": base["id"], "changedFields": base["changedFields"] + 1,
                "normalisedL1": base["normalisedL1"] + sum(
                    choices[name].index(values[name]) / max(1, len(choices[name]) - 1)
                    for name in names),
            })
            if len([row for row in out if row["family"] == family_id]) == 8:
                break
    if len(out) != 16:
        raise RuntimeError("level-2 generation did not produce 16 candidates")
    return out


def prepare(connection: sqlite3.Connection) -> list[dict]:
    rows = candidates()
    for row in rows:
        path = Path(row["contentPath"])
        identity = phase_c.digest({"kind": "candidate-content", "sha256": row["contentSha256"]})
        connection.execute(
            "insert or ignore into object values(?,525,'candidate-content',?,?,?)",
            (identity, row["contentSha256"], str(path.relative_to(ROOT)), path.stat().st_size),
        )
    connection.commit()
    phase_c.PACKAGES.update({family_id: {
        "family": family_id, "package": family["package"], "aspect": family["aspect"],
        "nodes": family["nodes"], "response": family["response"], "edges": family["edges"],
    } for family_id, family in FAMILIES.items()})
    freeze = {
        "schemaVersion": 1, "issue": 525, "level": 2, "candidateCount": len(rows),
        "rule": "One new card per failed family; existing effect primitives only.",
        "families": {key: {"sourceFamily": value["sourceFamily"],
                            "expressibilityGap": value["expressibilityGap"],
                            "newCard": value["card"]} for key, value in FAMILIES.items()},
        "candidates": rows,
    }
    phase_c.write_json_once(ROOT / "artifacts/phase-c-level2-candidate-freeze-v1.json", freeze)
    return rows


def screen() -> dict:
    phase_c.verify_authority()
    connection = phase_c.open_ledger()
    rows = prepare(connection)
    results = []
    for candidate in rows:
        fidelity = "issue-525-phase-c-level2-screen-v1"
        output = phase_c.run_plan(connection, candidate,
                                  phase_c.plan(candidate, {"discovery": SCREEN_SEEDS}, fidelity),
                                  fidelity)
        analysed = phase_c.analyse(output, candidate["family"], strict=False)
        results.append({**candidate, "rows": len(output), "score": analysed["score"],
                        "edges": analysed["edges"], "panels": analysed["panels"]})
    recommendations = []
    for family_id in sorted(FAMILIES):
        group = [row for row in results if row["family"] == family_id]
        chosen = max(group, key=lambda row: (row["score"], -row["changedFields"],
                                             -row["normalisedL1"], row["id"]))
        recommendations.append({key: chosen[key] for key in (
            "id", "family", "parameters", "contentPath", "contentSha256", "baseCandidateId",
            "changedFields", "normalisedL1", "score")})
    result = {"schemaVersion": 1, "issue": 525,
              "decision": "VALIDATE_ONE_LEVEL2_RECOMMENDATION_PER_FAILED_FAMILY",
              "screenRows": sum(row["rows"] for row in results),
              "recommendations": recommendations, "candidates": results}
    phase_c.write_json_once(ROOT / "artifacts/phase-c-level2-screen-v1.json", result)
    phase_c.record(connection, "phase-c-level2-screen", {
        "rows": result["screenRows"], "recommendations": [row["id"] for row in recommendations],
    })
    print(phase_c.canonical({key: result[key] for key in ("decision", "screenRows", "recommendations")}))
    return result


def validate() -> dict:
    phase_c.verify_authority()
    connection = phase_c.open_ledger()
    available = {row["id"]: row for row in prepare(connection)}
    screened = json.loads((ROOT / "artifacts/phase-c-level2-screen-v1.json").read_text())
    results = []
    for recommendation in screened["recommendations"]:
        candidate = available[recommendation["id"]]
        fidelity = "issue-525-phase-c-level2-validation-v1"
        output = phase_c.run_plan(connection, candidate, phase_c.plan(candidate, {
            "discovery": DISCOVERY_SEEDS, "validation": VALIDATION_SEEDS,
        }, fidelity), fidelity)
        analysed = phase_c.analyse(output, candidate["family"], strict=True)
        results.append({**candidate, **analysed})
        print(phase_c.canonical({"family": candidate["family"],
                                 "pass": analysed["admittedAtProbePanelGate"]}), flush=True)
    selected = [{key: row[key] for key in (
        "id", "family", "parameters", "contentPath", "contentSha256", "baseCandidateId",
        "changedFields", "normalisedL1", "score")}
                for row in results if row["admittedAtProbePanelGate"]]
    failed = sorted(set(FAMILIES) - {row["family"] for row in selected})
    phase_c_rows = connection.execute(
        "select count(*) from sim_row where is_new=1 and fidelity like 'issue-525-phase-c%'"
    ).fetchone()[0]
    if phase_c_rows > 40000:
        raise RuntimeError("preregistered Phase-C probe/panel row ceiling exceeded")
    decision = "PROCEED_TO_FULL_RUN_PACKAGE_ADMISSION" if not failed \
        else "LEVEL2_EXPRESSIBILITY_FAILURE_ESCALATE_MINIMAL_PRIMITIVE"
    result = {"schemaVersion": 1, "issue": 525, "decision": decision,
              "phaseCProbePanelRows": phase_c_rows, "selected": selected,
              "failedFamilies": failed, "results": results}
    phase_c.write_json_once(ROOT / "artifacts/phase-c-level2-validation-v1.json", result)
    phase_c.record(connection, "phase-c-level2-validation", {
        "decision": decision, "phaseCProbePanelRows": phase_c_rows,
        "selected": [row["id"] for row in selected], "failedFamilies": failed,
    })
    print(phase_c.canonical({key: result[key] for key in (
        "decision", "phaseCProbePanelRows", "selected", "failedFamilies")}))
    return result


def self_check() -> None:
    ward = card_definition("ward-mirror-edge-l2", {"damage": 8, "block": 7,
                                                     "rarity": "uncommon"})
    cut = card_definition("dusk-cinder-cut-l2", {"cost": 0, "damage": 7,
                                                  "rarity": "common"})
    assert [effect["kind"] for effect in ward["effects"]] == ["dmg", "block"]
    assert cut["exhaust"] and cut["effects"][0]["kind"] == "dmg"
    print(phase_c.canonical({"status": "PASS", "newDefinitionsPerFamily": 1}))


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
