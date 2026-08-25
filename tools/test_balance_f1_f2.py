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
from balance_f0 import evaluation_from_registry, evaluation_spec
from balance_seed_contract import check_invocation, load_contract


class BalanceF1F2Test(unittest.TestCase):
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
                    "bootstrap": {"deficits": intervals},
                    "deficits": {"c1a": low, "c1b": low, "c2arm": 0.0,
                                 "c2gap": 0.0, "sum": 2 * low}}

        decisions = racing_decisions([row("c000", 1.0, 1.2), row("lead", 0.2, 0.4),
                                      row("lag", 0.7, 0.9)], 3)
        by_id = {item["id"]: item for item in decisions}
        self.assertEqual("promote", by_id["lead"]["decision"])
        self.assertEqual("stop", by_id["lag"]["decision"])
        self.assertEqual("confidence-envelope-dominated", by_id["lag"]["reason"])


if __name__ == "__main__":
    unittest.main()
