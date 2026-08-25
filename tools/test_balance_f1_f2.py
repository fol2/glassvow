#!/usr/bin/env python3
"""Public-seam regression tests for the #458 F1/F2 search driver."""
from __future__ import annotations

import unittest
import json
import tempfile
from pathlib import Path

from balance_f1_f2 import (
    adequacy_decision,
    balanced_supplemental,
    pareto_front,
    racing_decisions,
    response_deficit,
    write_search_bundle,
)
from balance_f0 import evaluation_from_registry, evaluation_spec, progressive_plans
from balance_seed_contract import check_invocation, load_contract
from balance_f1_evidence import (
    audit_comparison,
    boundary_diagnostics,
    decision_record,
    hydrated_updates,
    select_cem_policies,
)
from balance_f1_cem import cem_spec


class BalanceF1F2Test(unittest.TestCase):
    def test_progressive_layer_plans_cover_only_new_disjoint_rectangles(self) -> None:
        def layer(control_last: int, policy_count: int, landscape_last: int) -> dict:
            return {"controlStage": "f1-racing", "controlRoot": 1454,
                    "controlFirst": 6200, "controlLast": control_last,
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
            return {"id": candidate_id, "proxies": proxies,
                    "bootstrap": {"vsC000": {"gridDelta": grid_delta},
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

    def test_search_bundle_replays_f0_baseline_and_supplemental_catalogues(self) -> None:
        repo = Path(__file__).resolve().parents[1]
        space = json.loads((repo / "docs/balance/421-content-search-space-v1.json").read_text())
        f0 = json.loads((repo / "docs/balance/data/457/doe-manifest.json").read_text())
        supplemental, metrics = balanced_supplemental(
            space["features"], [row["values"] for row in f0["candidates"]], 4, 458, 256)
        with tempfile.TemporaryDirectory(prefix="glassvow-f1-bundle-") as temp:
            out = Path(temp) / "bundle"
            manifest = write_search_bundle(
                repo / "content/full-content.json",
                repo / "docs/balance/421-content-search-space-v1.json",
                f0, supplemental, metrics, out, ("c000", "c002"), 458)
            self.assertEqual(6, manifest["count"])
            self.assertEqual((repo / "content/full-content.json").read_bytes(),
                             (out / "c000/full-content.json").read_bytes())
            self.assertEqual(6, len({row["semanticSha256"] for row in manifest["candidates"]}))

    def test_response_deficit_uses_raw_components_not_a_pass_label(self) -> None:
        one_grid = [0.8, 0.75, 0.70, 3.0, 4.0, 0.40, 0.40]
        self.assertEqual(0.0, response_deficit(one_grid * 4))
        binding = [0.8, 0.5, 0.4, 1.0, 2.0, 0.40, 0.40]
        self.assertAlmostEqual(7.0 / 6.0, response_deficit(binding + one_grid * 3))

    def test_audit_band_needs_an_explicit_finalist_unseal(self) -> None:
        contract = load_contract()
        self.assertTrue(check_invocation(contract, "audit", 8000, 8199, 1454))
        self.assertEqual("", check_invocation(
            contract, "audit", 8000, 8199, 1454, sealed_token="finalist"))

    def test_generic_evaluator_uses_the_versioned_layer_ranges(self) -> None:
        protocol = {
            "controls": {"stage": "f1-racing", "root": 1454, "first": 6200, "last": 6263},
            "landscape": {"stage": "f1-racing", "root": 1454, "first": 6200,
                          "last": 6215, "policyFirst": 0, "policyCount": 256},
        }
        self.assertEqual({
            "controlStage": "f1-racing", "controlRoot": 1454,
            "controlFirst": 6200, "controlLast": 6263,
            "landscapeStage": "f1-racing", "landscapeRoot": 1454,
            "landscapeFirst": 6200, "landscapeLast": 6215,
            "policyFirst": 0, "policyCount": 256,
        }, evaluation_spec(protocol))

    def test_registry_layer_is_bound_to_issue_and_frozen_axes(self) -> None:
        registry = {"issue": 458, "evaluations": {"layer1": {
            "controls": {"first": 6200, "last": 6231},
            "landscape": {"first": 6200, "last": 6207, "policyCount": 128},
        }}}
        axes = {"deckCuts": {"thinMax": 25, "midMax": 35}}
        selected = evaluation_from_registry(registry, "layer1", axes)
        self.assertEqual(458, selected["issue"])
        self.assertEqual(axes, selected["frozenLandscape"])
        self.assertNotIn("maxPromotions", selected)

    def test_surrogate_must_beat_the_transparent_ranking_baseline(self) -> None:
        thresholds = {
            "maxNormalisedMaeRatio": 0.95,
            "minDeficitSpearman": 0.50,
            "minSpearmanLift": 0.05,
            "minTopQuartileRecall": 0.625,
            "minTopQuartileRecallLift": 0.125,
            "minIntervalCoverage": 0.80,
            "maxIntervalCoverage": 0.98,
        }
        weak = {
            "normalisedMae": 0.17,
            "baselineNormalisedMae": 0.19,
            "deficitSpearman": 0.51,
            "baselineDeficitSpearman": 0.56,
            "topQuartileRecall": 0.75,
            "baselineTopQuartileRecall": 0.50,
            "intervalCoverage": 0.90,
        }
        decision = adequacy_decision(weak, thresholds)
        self.assertFalse(decision["adequate"])
        self.assertIn("deficitSpearmanLift", decision["failed"])

        useful = dict(weak, deficitSpearman=0.68, baselineDeficitSpearman=0.56)
        self.assertTrue(adequacy_decision(useful, thresholds)["adequate"])

    def test_supplemental_batch_is_balanced_unique_and_excludes_f0(self) -> None:
        features = [
            {"id": f"f{index}", "values": list(range(5 if index < 4 else 4))}
            for index in range(8)
        ]
        excluded = [
            {f"f{column}": (row + column) % (5 if column < 4 else 4)
             for column in range(8)}
            for row in range(32)
        ]
        first, metrics = balanced_supplemental(features, excluded, 16, 458, 257)
        second, _ = balanced_supplemental(features, excluded, 16, 458, 257)

        self.assertEqual(first, second)
        self.assertEqual(16, len(first))
        self.assertEqual(16, len({tuple(row.values()) for row in first}))
        self.assertFalse({tuple(row.values()) for row in first}
                         & {tuple(row.values()) for row in excluded})
        self.assertGreaterEqual(metrics["minimumDistanceFromF0"], 2)
        self.assertEqual(257, metrics["restarts"])
        for counts in metrics["marginalCounts"].values():
            self.assertLessEqual(max(counts.values()) - min(counts.values()), 1)

    def test_acquisition_front_keeps_materially_different_trade_offs(self) -> None:
        rows = [
            {"id": "safe", "criteria": {"infeasibility": 0.1, "deficit": 0.4,
                                           "negUncertainty": -0.1, "negNovelty": -0.4}},
            {"id": "novel", "criteria": {"infeasibility": 0.2, "deficit": 0.3,
                                            "negUncertainty": -0.4, "negNovelty": -0.9}},
            {"id": "dominated", "criteria": {"infeasibility": 0.3, "deficit": 0.6,
                                                "negUncertainty": 0.0, "negNovelty": -0.2}},
        ]
        self.assertEqual(["safe", "novel"], pareto_front(rows, "criteria"))

    def test_racing_stops_a_confidence_envelope_dominated_candidate(self) -> None:
        def row(candidate_id: str, low: float, high: float) -> dict:
            intervals = {key: {"p025": low, "p50": (low + high) / 2, "p975": high}
                         for key in ("c1a", "c1b", "c2arm", "c2gap")}
            return {"id": candidate_id, "status": "complete", "earlyStop": None,
                    "bootstrap": {"deficits": intervals, "vsC000": {"deficitDelta": {
                        "c1a": {"p025": -0.1, "p50": 0.1, "p975": 0.3},
                        "c1b": {"p025": -0.1, "p50": 0.1, "p975": 0.3},
                    }}},
                    "deficits": {"c1a": low, "c1b": low, "c2arm": 0.0,
                                 "c2gap": 0.0, "sum": 2 * low}}

        decisions = racing_decisions([row("c000", 1.0, 1.2), row("lead", 0.2, 0.4),
                                      row("lag", 0.7, 0.9)], 3)
        by_id = {item["id"]: item for item in decisions}
        self.assertEqual("promote", by_id["lead"]["decision"])
        self.assertEqual("stop", by_id["lag"]["decision"])
        self.assertEqual("confidence-envelope-dominated", by_id["lag"]["reason"])

    def test_racing_requires_a_credible_binding_path_and_no_clear_c2_regression(self) -> None:
        def row(candidate_id: str, c1_low: float, c1_high: float) -> dict:
            intervals = {
                "c1a": {"p025": c1_low, "p50": c1_low, "p975": c1_high},
                "c1b": {"p025": c1_low, "p50": c1_low, "p975": c1_high},
                "c2arm": {"p025": 0.0, "p50": 0.0, "p975": 0.0},
                "c2gap": {"p025": 0.0, "p50": 0.0, "p975": 0.0},
            }
            return {"id": candidate_id, "status": "complete", "earlyStop": None,
                    "bootstrap": {"deficits": intervals, "grids": {},
                                  "vsC000": {"deficitDelta": {
                                      "c1a": {"p025": -0.2, "p50": 0.0, "p975": 0.2},
                                      "c1b": {"p025": -0.2, "p50": 0.0, "p975": 0.2},
                                  }}},
                    "deficits": {"c1a": c1_low, "c1b": c1_low, "c2arm": 0.0,
                                 "c2gap": 0.0, "sum": 2 * c1_low}}

        baseline = row("c000", 0.8, 1.0)
        baseline["bootstrap"]["deficits"]["c2arm"]["p975"] = 0.2
        baseline["bootstrap"]["deficits"]["c2gap"]["p975"] = 0.2
        no_path = row("no-path", 1.1, 1.3)
        no_path["bootstrap"]["vsC000"]["deficitDelta"] = {
            "c1a": {"p025": -0.4, "p50": -0.2, "p975": 0.0},
            "c1b": {"p025": -0.4, "p50": -0.2, "p975": 0.0},
        }
        hard = row("hard", 0.2, 0.5)
        hard["bootstrap"]["grids"] = {
            "duskblade:v0": {"arm2Rate": {"p025": 0.51, "p50": 0.55, "p975": 0.60},
                              "margin": {"p025": 0.10, "p50": 0.20, "p975": 0.40}}
        }
        by_id = {item["id"]: item for item in racing_decisions([baseline, no_path, hard], 3)}
        self.assertEqual("no-credible-binding-improvement", by_id["no-path"]["reason"])
        self.assertEqual("hard-constraint-regression", by_id["hard"]["reason"])


if __name__ == "__main__":
    unittest.main()
