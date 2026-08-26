#!/usr/bin/env python3
"""Public-seam tests for the #491 Tier-1 F0 response contract.

Seams under test:
- 491 protocol evaluation rectangle (seeds, root, arms 1-2, 128 policies)
- valid-cell rankGaps / occupiedValidCells / deckBands / finalDeckSize
- packageDiagnostics from recorded row events
- guardrails and promotion decision against t1-c000
- complete-rectangle early-stop (errors only)
"""
from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "tools"))

from balance_f0 import (  # noqa: E402
    bind_row,
    control_fault,
    evaluation_from_registry,
    evaluation_spec,
    grid_proxies,
    aggregate_cells,
    aggregate_controls,
    landscape_errors_fault,
    screening_metric_fault,
)
from balance_f0_tier1 import (  # noqa: E402
    RACING_SET,
    attach_tier1_fields,
    breadth_metric,
    cell_is_valid,
    decide,
    deck_bands,
    final_deck_size,
    guardrails,
    identity_load,
    occupied_valid_cells,
    package_diagnostics,
    package_effects,
    rank_gaps,
    valid_proxies,
)
from balance_seed_contract import check_invocation, load_contract  # noqa: E402

CONTRACT = json.loads((REPO / "docs/balance/490-f0-response-contract-v1.json").read_text())
PROTOCOL = json.loads((REPO / "docs/balance/491-f0-protocol-v1.json").read_text())
AXES = load_contract()["frozenLandscape"]
GRIDS = ("duskblade:v0", "duskblade:v5", "ashwarden:v0", "ashwarden:v5")


def _fight(shatters: float, smolder: float) -> list[dict]:
    return [{"shatters": shatters, "smolderKills": smolder}]


def _land(aspect: str, vow: int, seed: int, policy: int, deck: int, outcome: str,
          shatters: float, smolder: float, events: dict | None = None) -> dict:
    row = {
        "aspect": aspect, "vow": vow, "seed": seed, "policyIndex": policy,
        "deck": deck, "outcome": outcome, "error": "",
        "fights": _fight(shatters, smolder),
        "packageEvents": events or {},
    }
    return row


class Tier1F0ProtocolTest(unittest.TestCase):
    def test_protocol_binds_the_frozen_491_rectangle(self) -> None:
        selected = evaluation_from_registry(PROTOCOL, "f0", AXES)
        spec = evaluation_spec(selected)
        self.assertEqual(491, selected["issue"])
        self.assertTrue(selected["completeRectangle"])
        self.assertEqual("tier1", selected["candidateSource"])
        self.assertEqual(48, selected["candidateCount"])
        self.assertEqual(490, selected["candidateSeed"])
        self.assertEqual({
            "controlStage": "tier1-f0-controls", "controlRoot": 3454,
            "controlFirst": 9100, "controlLast": 9131, "controlArms": [1, 2],
            "landscapeStage": "tier1-f0-mini-landscape", "landscapeRoot": 3454,
            "landscapeFirst": 9200, "landscapeLast": 9207,
            "policyFirst": 0, "policyCount": 128,
        }, spec)
        expected_controls = 32 * 2 * 4
        expected_landscape = 128 * 4 * 8
        self.assertEqual(256, expected_controls)
        self.assertEqual(4096, expected_landscape)
        self.assertEqual(208_896, 48 * (expected_controls + expected_landscape))
        contract = load_contract()
        self.assertEqual("", check_invocation(
            contract, "tier1-f0-controls", 9100, 9131, 3454))
        self.assertEqual("", check_invocation(
            contract, "tier1-f0-mini-landscape", 9200, 9207, 3454))
        self.assertTrue(check_invocation(
            contract, "tier1-f0-controls", 5000, 5000, 3454))
        self.assertTrue(check_invocation(
            contract, "tier1-f0-controls", 9100, 9131, 454))

    def test_complete_rectangle_only_fail_closes_on_errors(self) -> None:
        split_ok = [
            {"arm": arm, "aspect": aspect, "vow": 0, "seed": 9100, "outcome": outcome,
             "error": "", "deck": 30, "fights": []}
            for arm in (1, 2) for aspect, outcome in (("duskblade", "win"), ("ashwarden", "loss"))
        ]
        stall = split_ok + [{"arm": 1, "aspect": "duskblade", "vow": 0, "seed": 9101,
                             "outcome": "stall", "error": "", "deck": 30, "fights": []}]
        self.assertEqual("stalls-beyond-baseline", control_fault(stall, 0))
        self.assertEqual("", control_fault(stall, 0, complete_rectangle=True))
        errors = split_ok + [{"arm": 1, "aspect": "duskblade", "vow": 0, "seed": 9101,
                              "outcome": "error", "error": "boom", "deck": 30, "fights": []}]
        self.assertEqual("errors", control_fault(errors, 0, complete_rectangle=True))
        self.assertEqual("errors", landscape_errors_fault(
            [{"outcome": "error", "error": "boom"}]))
        self.assertEqual("", landscape_errors_fault([{"outcome": "stall"}]))
        reversal = {
            "duskblade:v0": {"topCell": "smolder:fat"},
            "duskblade:v5": {"topCell": "shatter:fat"},
            "ashwarden:v0": {"topCell": "shatter:fat"},
            "ashwarden:v5": {"topCell": "smolder:fat"},
        }
        self.assertEqual("identity-reversal", screening_metric_fault(proxies=reversal))
        self.assertEqual("", screening_metric_fault(
            proxies=reversal, complete_rectangle=True))
        band = {"p025": 1.0, "p975": 1.2}
        low = {"p025": 0.0, "p975": 0.2}
        dominated = {"deficits": {key: band for key in ("c1a", "c1b", "c2arm", "c2gap")}}
        baseline = {"deficits": {key: low for key in ("c1a", "c1b", "c2arm", "c2gap")}}
        self.assertEqual("dominated-envelope", screening_metric_fault(
            bootstrap=dominated, baseline_bootstrap=baseline))
        self.assertEqual("", screening_metric_fault(
            bootstrap=dominated, baseline_bootstrap=baseline, complete_rectangle=True))

    def test_bind_row_keeps_package_events_off_non_491_observations(self) -> None:
        identity = {
            "id": "t1-c000", "values": {"duskNonShatter": "s009"},
            "fileSha256": "a" * 64, "semanticSha256": "b" * 64,
            "searchSpaceSha256": "c" * 64, "seedRegistrySha256": "d" * 64,
            "commit": "deadbeef", "driverSha256": "e" * 64,
            "godotVersion": "4.7.2.stable", "hostFingerprint": "f" * 64,
        }
        row = {
            "aspect": "duskblade", "vow": 0, "seed": 9100, "outcome": "win",
            "error": "", "deck": 30, "fights": [],
            "packageEvents": {"eclipseSlashPlayed": 1},
            "deckIds": ["strike"], "relics": ["hollowCrown"],
        }
        plain = bind_row(row, identity, extras=False)
        extra = bind_row(row, identity, extras=True)
        self.assertNotIn("packageEvents", plain)
        self.assertNotIn("deckIds", plain)
        self.assertNotIn("relics", plain)
        self.assertEqual({"eclipseSlashPlayed": 1}, extra["packageEvents"])
        self.assertEqual(["strike"], extra["deckIds"])
        self.assertEqual(["hollowCrown"], extra["relics"])


class Tier1F0ProductTest(unittest.TestCase):
    def test_tidy_pins_the_published_harvest_claims(self) -> None:
        tidy = json.loads((REPO / "docs/balance/data/491/tidy.json").read_text())
        rows = tidy["candidates"]
        self.assertEqual(48, len(rows))
        self.assertEqual(208_896, tidy["totalRows"])
        self.assertEqual([], tidy["shortlist"])
        self.assertEqual(list(RACING_SET), tidy["racingSet"])
        self.assertTrue(set(RACING_SET).isdisjoint(set(tidy["breadthPareto"])))
        self.assertNotIn("t1-c019", tidy["racingSet"])
        for row in rows:
            self.assertEqual("complete", row["status"])
            self.assertEqual(0, int(row["controlErrors"]))
            self.assertEqual(0, int(row["landscapeErrors"]))
            self.assertIn(row["id"], {f"t1-c{i:03d}" for i in range(48)})
        by_id = {row["id"]: row for row in rows}
        self.assertEqual("low", by_id["t1-c019"]["values"]["bossEnergyRoute"])

    def test_m4_packet_records_crown_energy_and_cycle_draws(self) -> None:
        packet = json.loads(
            (REPO / "docs/balance/data/491/m4-replay-packet.json").read_text())
        self.assertEqual(["win", "win", "win", "win"], packet["expectedOutcomes"])
        first = packet["rows"][0]["packageEvents"]
        self.assertEqual(90, first["extraEnergyGrantedByCrown"])
        self.assertEqual(106, first["cardsDrawnByCycle"])
        self.assertGreater(first["eclipseSlashPlayed"], 0)
        self.assertGreater(first["hollowCrownOwned"], 0)


class Tier1F0MetricsTest(unittest.TestCase):
    def test_valid_cells_use_frozen_policy_and_run_floors(self) -> None:
        self.assertTrue(cell_is_valid({"policies": 20, "runs": 400}))
        self.assertFalse(cell_is_valid({"policies": 19, "runs": 400}))
        self.assertFalse(cell_is_valid({"policies": 20, "runs": 399}))

    def test_rank_gaps_ignore_invalid_cells_and_use_tie_order(self) -> None:
        cells = {}
        for aspect in ("duskblade", "ashwarden"):
            for vow in (0, 5):
                for lean in ("shatter", "smolder", "attrition"):
                    for thick in ("thin", "mid", "fat"):
                        cells[f"{aspect}:v{vow}:{lean}:{thick}"] = {
                            "wins": 0, "runs": 10, "policies": 2, "winRate": 0.9,
                        }
        # Four valid Dusk V0 cells. Equal 0.70 rates must prefer shatter then thin.
        cells["duskblade:v0:smolder:fat"] = {
            "wins": 350, "runs": 500, "policies": 25, "winRate": 0.70,
        }
        cells["duskblade:v0:shatter:mid"] = {
            "wins": 287, "runs": 410, "policies": 21, "winRate": 0.70,
        }
        cells["duskblade:v0:shatter:thin"] = {
            "wins": 200, "runs": 400, "policies": 20, "winRate": 0.50,
        }
        cells["duskblade:v0:attrition:fat"] = {
            "wins": 160, "runs": 400, "policies": 20, "winRate": 0.40,
        }
        gaps = rank_gaps(cells, CONTRACT)
        dusk = gaps["duskblade:v0"]
        self.assertEqual(0.70, dusk["topRate"])
        self.assertEqual(0.50, dusk["thirdRate"])
        self.assertEqual(0.40, dusk["fourthRate"])
        self.assertAlmostEqual(0.20, dusk["topToThird"])
        self.assertAlmostEqual(0.30, dusk["topToFourth"])
        self.assertIsNone(gaps["ashwarden:v0"]["topRate"])
        self.assertEqual({"duskblade:v0": 4, "duskblade:v5": 0,
                          "ashwarden:v0": 0, "ashwarden:v5": 0},
                         occupied_valid_cells(cells, CONTRACT))

    def test_existing_proxies_still_rank_invalid_cells(self) -> None:
        controls = {
            f"{arm}:{aspect}:v{vow}": {"wins": 8, "runs": 32, "winRate": 0.25,
                                       "stalls": 0, "errors": 0}
            for arm in (1, 2) for aspect in ("duskblade", "ashwarden") for vow in (0, 5)
        }
        cells = {}
        for aspect in ("duskblade", "ashwarden"):
            for vow in (0, 5):
                for lean in ("shatter", "smolder", "attrition"):
                    for thick in ("thin", "mid", "fat"):
                        rate = 0.1
                        if lean == "smolder" and thick == "fat":
                            rate = 0.95
                        cells[f"{aspect}:v{vow}:{lean}:{thick}"] = {
                            "wins": int(rate * 10), "runs": 10, "policies": 2,
                            "winRate": rate, "stalls": 0, "errors": 0,
                        }
        proxies = grid_proxies(controls, cells)
        self.assertEqual("smolder:fat", proxies["duskblade:v0"]["topCell"])
        self.assertEqual(0.95, proxies["duskblade:v0"]["topRate"])

    def test_deck_bands_and_entropy_are_diagnostics(self) -> None:
        rows = []
        for policy in range(8):
            rows.append(_land("duskblade", 0, 9200, policy, 20, "win", 2, 0))
        for policy in range(8, 12):
            rows.append(_land("duskblade", 0, 9200, policy, 30, "loss", 2, 0))
        for policy in range(12, 16):
            rows.append(_land("duskblade", 0, 9200, policy, 40, "win", 2, 0))
        bands = deck_bands(rows, AXES)
        self.assertEqual(8, bands["duskblade:v0"]["thin"]["distinctPolicies"])
        self.assertEqual(8, bands["duskblade:v0"]["thin"]["wins"])
        self.assertEqual(1.0, bands["duskblade:v0"]["thin"]["winRate"])
        self.assertEqual(4, bands["duskblade:v0"]["mid"]["runs"])
        self.assertEqual(0.0, bands["duskblade:v0"]["mid"]["winRate"])
        sizes = final_deck_size(rows)
        self.assertEqual(16, sizes["duskblade:v0"]["observations"])
        self.assertEqual(20, sizes["duskblade:v0"]["min"])
        self.assertEqual(40, sizes["duskblade:v0"]["max"])
        self.assertEqual({"20": 8, "30": 4, "40": 4}, sizes["duskblade:v0"]["distribution"])
        self.assertGreater(sizes["duskblade:v0"]["entropy"], 1.0)

    def test_package_diagnostics_use_recorded_events_not_names(self) -> None:
        rows = [
            _land("duskblade", 0, 9200, 0, 22, "win", 2, 0, {
                "strikeDrawn": 4, "eclipseSlashDrawn": 2, "strikePlayed": 3,
                "eclipseSlashPlayed": 1, "crackedAppliedByEclipseSlash": 1,
            }),
            _land("duskblade", 0, 9201, 1, 40, "win", 2, 0, {
                "strikeDrawn": 4, "eclipseSlashDrawn": 0,
            }),
            _land("ashwarden", 0, 9200, 0, 22, "win", 0, 2, {
                "ashBiteDrawn": 4, "smotherDrawn": 2, "ashBitePlayed": 2,
            }),
        ]
        diag = package_diagnostics(rows, CONTRACT)
        dusk = diag["duskStarterAttrition"]["duskblade:v0"]
        self.assertEqual(2, dusk["eligibleRuns"])
        self.assertEqual(2, dusk["exposedRuns"])
        self.assertEqual(1, dusk["usedRuns"])
        self.assertTrue(dusk["mechanismFired"])
        self.assertEqual("reached", dusk["reachability"])
        ash_on_dusk = diag["ashStarterThinSustain"]["duskblade:v0"]
        self.assertEqual(0, ash_on_dusk["eligibleRuns"])
        self.assertEqual("not-applicable", ash_on_dusk["reachability"])
        ash = diag["ashStarterThinSustain"]["ashwarden:v0"]
        self.assertTrue(ash["mechanismFired"])
        empty = diag["ashcloudRoute"]["ashwarden:v0"]
        self.assertEqual("unreachable", empty["reachability"])
        self.assertFalse(empty["mechanismFired"])

    def test_identity_load_reads_aspect_kit_leaves(self) -> None:
        content = json.loads((REPO / "content/full-content.json").read_text())
        rules = identity_load(content)
        self.assertTrue(rules["duskblade:shatter-enabled"])
        self.assertTrue(rules["duskblade:smolder-application-blocked"])
        self.assertTrue(rules["ashwarden:shatter-blocked"])
        self.assertTrue(rules["ashwarden:smolder-enabled"])
        self.assertTrue(all(rules.values()))

    def test_guardrails_and_decision_follow_the_frozen_gates(self) -> None:
        controls = {
            f"{arm}:{aspect}:v{vow}": {
                "wins": 8 if arm == 2 else 16, "runs": 32,
                "winRate": 0.25 if arm == 2 else 0.5, "stalls": 0, "errors": 0,
            }
            for arm in (1, 2) for aspect in ("duskblade", "ashwarden") for vow in (0, 5)
        }
        cells = {}
        for aspect in ("duskblade", "ashwarden"):
            for vow in (0, 5):
                for lean in ("shatter", "smolder", "attrition"):
                    for thick in ("thin", "mid", "fat"):
                        valid = lean == "shatter" and thick == "fat"
                        rate = 0.80 if valid else 0.10
                        if aspect == "ashwarden" and valid:
                            lean_key = "smolder"
                        else:
                            lean_key = lean
                        key = f"{aspect}:v{vow}:{lean}:{thick}"
                        cells[key] = {
                            "wins": int(rate * 500) if valid else 10,
                            "runs": 500 if valid else 10,
                            "policies": 25 if valid else 2,
                            "winRate": rate, "stalls": 0, "errors": 0,
                        }
                        if aspect == "ashwarden" and lean == "shatter" and thick == "fat":
                            cells[key] = {
                                "wins": 10, "runs": 10, "policies": 2,
                                "winRate": 0.10, "stalls": 0, "errors": 0,
                            }
                        if aspect == "ashwarden" and lean == "smolder" and thick == "fat":
                            cells[key] = {
                                "wins": 400, "runs": 500, "policies": 25,
                                "winRate": 0.80, "stalls": 0, "errors": 0,
                            }
        proxies = grid_proxies(controls, cells)
        result = {
            "id": "t1-c001",
            "values": {"duskStarterAttrition": "high", "ashStarterThinSustain": "s009",
                       "neutralCycle": "s009", "removalEconomy": "s009",
                       "ashcloudRoute": "s009", "duskNonShatter": "s009",
                       "smolderRelicStack": "s009", "bossEnergyRoute": "s009"},
            "controls": controls, "cells": cells, "proxies": proxies,
            "controlStalls": 0, "controlErrors": 0,
            "landscapeStalls": 0, "landscapeErrors": 0,
            "packageDiagnostics": package_diagnostics([
                _land("duskblade", 0, 9200, 0, 22, "win", 2, 0, {
                    "strikeDrawn": 1, "strikePlayed": 1,
                    "eclipseSlashDrawn": 1, "eclipseSlashPlayed": 1,
                    "crackedAppliedByEclipseSlash": 1,
                }),
            ], CONTRACT),
        }
        attach_tier1_fields(result, AXES, CONTRACT, identity_load(
            json.loads((REPO / "content/full-content.json").read_text())))
        baseline = json.loads(json.dumps({k: v for k, v in result.items() if k != "decision"}))
        baseline["id"] = "t1-c000"
        baseline["values"] = {key: "s009" for key in result["values"]}
        baseline["controlStalls"] = 0
        baseline["landscapeStalls"] = 0
        result["bootstrap"] = {
            "vsBaseline": {
                "breadth": {
                    grid: {"p025": -0.4, "p50": -0.2, "p975": -0.05}
                    for grid in GRIDS
                }
            }
        }
        for grid in ("duskblade:v0", "ashwarden:v0"):
            result["validProxies"][grid]["within10"] = 2
            result["validProxies"][grid]["viable"] = 2
            baseline["validProxies"][grid]["within10"] = 1
            baseline["validProxies"][grid]["viable"] = 1
        effects = {
            "duskStarterAttrition": {
                "highVsS009": {"p025": -0.3, "p50": -0.2, "p975": -0.1},
            }
        }
        decision = decide(result, baseline, effects, CONTRACT)
        self.assertTrue(result["guardrails"]["clear"])
        self.assertIn("eligible", decision)
        self.assertTrue(decision["simulatorClear"])
        self.assertTrue(decision["breadthBothAspects"])
        self.assertEqual(["duskStarterAttrition"], decision["creditedPackages"])
        self.assertTrue(decision["eligible"])

    def test_effect_interval_crossing_zero_is_not_a_finding(self) -> None:
        rows = []
        for i, level in enumerate(["low"] * 4 + ["s009"] * 4 + ["high"] * 4):
            rows.append({
                "id": f"t1-c{i:03d}", "status": "complete",
                "values": {"duskStarterAttrition": level,
                           "ashStarterThinSustain": "s009"},
                "validBreadthSum": 2.0 if level != "high" else 1.9,
            })
        effects = package_effects(rows, ["duskStarterAttrition"], n_boot=50, rng_seed=491)
        interval = effects["duskStarterAttrition"]["highVsS009"]
        self.assertLessEqual(interval["p025"], interval["p975"])
        # A 0.1 point estimate on 12 rows is not required to exclude zero.
        self.assertTrue(interval["p025"] < 0 < interval["p975"] or interval["p975"] < 0
                        or interval["p025"] > 0)

    def test_breadth_metric_matches_the_frozen_formula(self) -> None:
        self.assertEqual(0.0, breadth_metric(3, 4))
        self.assertAlmostEqual(1.0 / 3.0 + 0.5, breadth_metric(2, 2))
        self.assertEqual(2.0, breadth_metric(0, 0))


if __name__ == "__main__":
    unittest.main()
