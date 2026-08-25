#!/usr/bin/env python3
"""Public-seam regression tests for the #458 F1 evidence pipeline."""
from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from balance_f0 import observation_bytes, progressive_plans
from balance_f1_cem import cem_output_complete, cem_spec
from balance_f1_cem_evidence import select_cem_policies, vow5_ceiling
from balance_f1_evidence import decision_record, reanalyse_layer
from balance_f1_finalists import (
    audit_comparison,
    boundary_diagnostics,
    finalist_contract,
    hydrated_updates,
)
from balance_seed_contract import load_contract, sha256_bytes


class BalanceF1EvidenceTest(unittest.TestCase):
    def test_racing_reanalysis_fails_closed_when_a_complete_raw_shard_is_missing(self) -> None:
        axes = load_contract()["frozenLandscape"]
        controls = [{"arm": arm, "aspect": aspect, "vow": vow, "seed": 6200,
                     "outcome": "win" if arm == 1 else "loss", "error": "",
                     "deck": 30, "fights": []}
                    for arm in (1, 2, 3, 4) for aspect in ("duskblade", "ashwarden")
                    for vow in (0, 5)]
        landscape = [{"policyIndex": 0, "aspect": aspect, "vow": vow, "seed": 6200,
                      "outcome": "win", "error": "", "deck": 40,
                      "fights": [{"shatters": 2, "smolderKills": 2}]}
                     for aspect in ("duskblade", "ashwarden") for vow in (0, 5)]
        controls.sort(key=lambda row: (row["arm"], row["aspect"], row["vow"], row["seed"]))
        landscape.sort(key=lambda row: (row["policyIndex"], row["aspect"],
                                        row["vow"], row["seed"]))
        identity = {"id": "c000", "values": {"flareDamage": 9},
                    "fileSha256": "f" * 64, "semanticSha256": "e" * 64,
                    "searchSpaceSha256": "s" * 64, "seedRegistrySha256": "r" * 64,
                    "commit": "deadbeef", "driverSha256": "d" * 64,
                    "godotVersion": "4.7.2.stable", "hostFingerprint": "h" * 64}
        payload = observation_bytes(controls + landscape, identity)
        candidate = {"id": "c000", "values": identity["values"],
                     "fileSha256": identity["fileSha256"],
                     "semanticSha256": identity["semanticSha256"],
                     "commit": identity["commit"], "godotVersion": identity["godotVersion"],
                     "hostFingerprint": identity["hostFingerprint"], "status": "complete",
                     "earlyStop": None, "controlRowCount": 16, "landscapeRowCount": 4,
                     "observationsSha256": sha256_bytes(payload)}
        summary = {"protocol": {
            "controls": {"stage": "f1-racing", "root": 1454,
                         "first": 6200, "last": 6200},
            "landscape": {"stage": "f1-racing", "root": 1454, "first": 6200,
                          "last": 6200, "policyFirst": 0, "policyCount": 1}},
            "searchSpaceSha256": identity["searchSpaceSha256"],
            "seedRegistrySha256": identity["seedRegistrySha256"],
            "driverSha256": identity["driverSha256"], "candidates": [candidate]}
        with tempfile.TemporaryDirectory(prefix="glassvow-raw-reanalyse-") as temp:
            root = Path(temp) / "c000"
            (root / "controls").mkdir(parents=True)
            (root / "landscape").mkdir()
            (root / "controls/shard-0.json").write_text(
                json.dumps({"runs": controls}), encoding="utf-8")
            landscape_path = root / "landscape/shard-0.ndjson"
            landscape_path.write_text("{}\n" + "".join(
                json.dumps(row) + "\n" for row in landscape), encoding="utf-8")
            (root / "observations.jsonl").write_bytes(payload)
            self.assertEqual("c000", reanalyse_layer(summary, Path(temp), 10, axes)
                             ["candidates"][0]["id"])
            landscape_path.unlink()
            with self.assertRaisesRegex(ValueError, "raw row count drifted"):
                reanalyse_layer(summary, Path(temp), 10, axes)

    def test_mini_cem_resume_is_bound_to_the_candidate_seed_packet(self) -> None:
        spec = {"popSize": 16, "elite": 4, "maxGen": 6, "seedCount": 8,
                "trainSeed0": 6400, "holdoutSeed0": 6800, "holdoutCount": 2,
                "root": 2454, "policyRoot": 1454}
        manifest = {"t": "manifest", "contentFileSha256": "candidate",
                    "seedPacketSha256": "old", "stage": "f1-mini-cem", "island": 0,
                    "popSize": 16, "elite": 4, "maxGen": 6, "seedCount": 8,
                    "trainSeed0": 6400, "holdoutSeed0": 6800, "holdoutCount": 2,
                    "rootSeed": 2454, "samplerRoot": 1454}
        rows = [manifest,
                {"t": "holdout", "outcome": "win"},
                {"t": "holdout", "outcome": "loss"},
                {"t": "final", "island": 0, "holdoutRuns": 2}]
        with tempfile.TemporaryDirectory(prefix="glassvow-cem-resume-") as temp:
            output = Path(temp) / "island.ndjson"
            output.write_text("".join(json.dumps(row) + "\n" for row in rows))
            self.assertTrue(cem_output_complete(output, "candidate", "old", spec, 0))
            self.assertFalse(cem_output_complete(output, "candidate", "new", spec, 0))

    def test_progressive_layer_plans_cover_only_new_disjoint_rectangles(self) -> None:
        def layer(control_last: int, policy_count: int, landscape_last: int) -> dict:
            return {"controlStage": "f1-racing", "controlRoot": 1454,
                    "controlFirst": 6200, "controlLast": control_last,
                    "controlArms": [1, 2],
                    "landscapeStage": "f1-racing", "landscapeRoot": 1454,
                    "landscapeFirst": 6200, "landscapeLast": landscape_last,
                    "policyFirst": 0, "policyCount": policy_count}

        controls, landscape = progressive_plans(layer(6231, 128, 6207),
                                                layer(6263, 256, 6215), 8)
        self.assertEqual(32, sum(row["seeds"] for row in controls))
        new_rows = sum(row["policyCount"] * 4 * row["seeds"] for row in landscape)
        self.assertEqual(256 * 4 * 16 - 128 * 4 * 8, new_rows)
        covered = set()
        for row in landscape:
            cells = {(policy, seed)
                     for policy in range(row["policyFirst"],
                                         row["policyFirst"] + row["policyCount"])
                     for seed in range(row["seed0"], row["seed0"] + row["seeds"])}
            self.assertFalse(covered & cells)
            covered |= cells
        self.assertNotIn((0, 6200), covered)
        self.assertIn((0, 6208), covered)
        self.assertIn((128, 6200), covered)

    def test_finalist_hydration_and_boundary_diagnostics_are_complete(self) -> None:
        values = {"duskMaxHp": 60, "flareDamage": 11, "ashfallSmolder": 4,
                  "ashfallWard": 7, "regrowthHeal": 4, "ironSkinWard": 2,
                  "guardedStrikeWard": 3, "venomStrikeSmolder": 5}
        updates = hydrated_updates(values)
        self.assertEqual("Deal @7@ damage. Gain #5# Ward.",
                         updates["content/full-content.json"]["cards.guardedStrike.up.text"])
        self.assertEqual("造成 @6@ 點傷害。施加 6 層陰燃。",
                         updates["locale/zh-Hant.json"]["content.cards.venomStrike.textUp"])
        repo = Path(__file__).resolve().parents[1]
        space = json.loads((repo / "docs/balance/421-content-search-space-v1.json").read_text())
        diagnostics = boundary_diagnostics(values, space)
        self.assertEqual(8, len(diagnostics["features"]))
        self.assertEqual(7, diagnostics["boundaryCount"])

    def test_audit_contradiction_uses_paired_effect_change_not_absolute_rates(self) -> None:
        def row(candidate_id: str, effect: tuple[float, float, float], identity: bool) -> dict:
            grid_delta = {grid: {key: {"p025": effect[0], "p50": effect[1], "p975": effect[2]}
                                      for key in ("arm2Rate", "topRate", "thirdRate",
                                                  "fourthRate", "margin")}
                          for grid in ("duskblade:v0", "duskblade:v5",
                                       "ashwarden:v0", "ashwarden:v5")}
            proxies = {}
            for grid in grid_delta:
                aspect = grid.split(":")[0]
                proxies[grid] = {"topCell": ("shatter:fat" if aspect == "duskblade" and identity
                                               else "smolder:fat"),
                                 "arm2Rate": 0.2, "margin": 0.5}
            deficit_delta = {key: {"p025": effect[0], "p50": effect[1], "p975": effect[2]}
                             for key in ("c1a", "c1b")}
            return {"id": candidate_id, "proxies": proxies,
                    "bootstrap": {"vsC000": {"gridDelta": grid_delta,
                                              "deficitDelta": deficit_delta},
                                  "grids": {grid: {
                                      "arm2Rate": {"p025": 0.1, "p50": 0.2, "p975": 0.3},
                                      "margin": {"p025": 0.4, "p50": 0.5, "p975": 0.6},
                                  } for grid in grid_delta}}}

        development = {"candidates": [row("c001", (0.18, 0.20, 0.22), True)]}
        audit = {"candidates": [row("c001", (-0.04, -0.02, 0.0), True)]}
        report = audit_comparison(development, audit, ["c001"], 0.10)
        self.assertTrue(report["candidates"][0]["confidenceBlocked"])
        self.assertIn("duskblade:v0:arm2Rate",
                      report["candidates"][0]["materialContradictions"])
        self.assertIn("binding:c1a", report["candidates"][0]["materialContradictions"])

    def test_mini_cem_spec_is_bounded_to_development_roots_and_seeds(self) -> None:
        contract = load_contract()
        protocol = {
            "miniCem": {
                "policyRoot": 1454, "root": 2454, "islands": 24,
                "popSize": 16, "elite": 4, "maxGen": 6, "seedCount": 8,
                "trainSeed0": 6400, "holdoutSeed0": 6800, "holdoutCount": 40,
            }
        }
        selected = cem_spec(protocol, contract)
        self.assertEqual(6447, selected["trainSeed0"]
                         + selected["maxGen"] * selected["seedCount"] - 1)
        protocol["miniCem"]["holdoutSeed0"] = 5000
        with self.assertRaises(ValueError):
            cem_spec(protocol, contract)

    def test_decision_record_carries_the_evidence_available_at_that_layer(self) -> None:
        candidate = {
            "id": "c000", "status": "complete", "earlyStop": None,
            "deficits": {"sum": 1.0}, "proxies": {"duskblade:v0": {"topCell": "shatter:fat"}},
            "bootstrap": {"deficits": {"c1a": {"p025": 0, "p50": 1, "p975": 2}}},
        }
        record = decision_record({"candidates": [candidate]},
                                 [{"id": "c000", "decision": "baseline", "reason": "paired-incumbent"}],
                                 "layer1")
        self.assertEqual("shatter:fat",
                         record["decisions"][0]["evidence"]["proxies"]["duskblade:v0"]["topCell"])
        self.assertEqual([], record["promoted"])

    def test_mini_cem_policy_selection_preserves_cell_variety_then_strength(self) -> None:
        rows = []
        for policy, cell, wins in [(0, "shatter:fat", 4), (1, "attrition:fat", 3),
                                   (2, "smolder:mid", 2), (3, "shatter:fat", 3),
                                   (4, "attrition:fat", 2), (5, "smolder:mid", 1),
                                   (6, "shatter:fat", 2)]:
            rows.append({"policyIndex": policy, "cell": cell, "wins": wins, "runs": 4})
        selected = select_cem_policies(rows, 6)
        self.assertEqual([0, 1, 2], [row["policyIndex"] for row in selected[:3]])
        self.assertEqual(6, len(selected))

    def test_mini_cem_vow5_ceiling_checks_both_grids(self) -> None:
        report = vow5_ceiling({
            "duskblade:v5": {"bestCeiling": 0.90},
            "ashwarden:v5": {"bestCeiling": 0.91},
        })
        self.assertTrue(report["grids"]["duskblade:v5"]["clear"])
        self.assertFalse(report["grids"]["ashwarden:v5"]["clear"])
        self.assertFalse(report["clear"])

    def test_finalist_contract_rejects_a_development_vow5_ceiling_fault(self) -> None:
        grids = ("duskblade:v0", "duskblade:v5", "ashwarden:v0", "ashwarden:v5")
        values = {"duskMaxHp": 60, "flareDamage": 11, "ashfallSmolder": 4,
                  "ashfallWard": 7, "regrowthHeal": 4, "ironSkinWard": 2,
                  "guardedStrikeWard": 3, "venomStrikeSmolder": 5}
        interval = {"p025": 0.1, "p50": 0.2, "p975": 0.3}
        evidence = {
            "proxies": {grid: {"arm2Rate": 0.2, "margin": 0.5,
                                "topCell": "shatter:fat"}
                        for grid in grids},
            "bootstrap": {"grids": {grid: {
                "arm2Rate": interval, "margin": {"p025": 0.4, "p50": 0.5, "p975": 0.6},
            } for grid in grids}},
        }
        repo = Path(__file__).resolve().parents[1]
        space = json.loads((repo / "docs/balance/421-content-search-space-v1.json").read_text())
        with self.assertRaisesRegex(ValueError, "development hard-constraint fault"):
            finalist_contract(
                ["c001"], {"candidates": [{"id": "c001", "values": values, "patch": []}]},
                {"promoted": ["c001"], "decisions": [{"id": "c001", "evidence": evidence}]},
                {"candidates": [{"id": "c001", "vow5Ceiling": {"clear": False}}]},
                {"candidates": [{"id": "c001"}], "nonGating": True}, space,
            )



if __name__ == "__main__":
    unittest.main()
