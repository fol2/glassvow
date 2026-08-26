#!/usr/bin/env python3
"""Public-seam tests for the #503 Tier-2 F0 disruption-profile screen.

Seams under test:
- 503 protocol evaluation rectangle (seeds, root 7454, arms 1-2, 128 policies)
- 81 x (256 + 4,096) = 352,512 completeness / fail-closed contract
- profile diagnostics, conditional outcomes and factorial effect coding
- guardrails, Pareto and racingSet decision against t2-c000
- normalised observation replay and the pre-registered M4 row packet
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
    drop_volatile,
    evaluation_from_registry,
    evaluation_spec,
    grid_proxies,
    landscape_errors_fault,
    screening_metric_fault,
)
from balance_f0_tier1 import (  # noqa: E402
    identity_load,
    occupied_valid_cells,
    rank_gaps,
)
from balance_f0_tier2 import (  # noqa: E402
    GRIDS,
    KNOBS,
    attach_tier2_fields,
    authored_amount,
    contrast_weight,
    decide,
    factorial_effects,
    occupancy_rate_bands,
    profile_attribution_fault,
    profile_diagnostics,
    racing_set,
    tidy_candidate,
    _term,
)
from balance_seed_contract import check_invocation, load_contract  # noqa: E402

CONTRACT = json.loads((REPO / "docs/balance/508-f0-response-contract-v1.json").read_text())
PROTOCOL = json.loads((REPO / "docs/balance/503-f0-protocol-v1.json").read_text())
AXES = load_contract()["frozenLandscape"]


def _land(aspect: str, vow: int, seed: int, policy: int, deck: int, outcome: str,
          shatters: float, smolder: float, fights: list[dict] | None = None) -> dict:
    return {
        "aspect": aspect, "vow": vow, "seed": seed, "policyIndex": policy,
        "deck": deck, "outcome": outcome, "error": "",
        "fights": fights if fights is not None else [{
            "shatters": shatters, "smolderKills": smolder, "turns": 4,
            "hpLost": 3, "enemies": ["sporeling"],
            "profileDiagnostics": {
                "encounters": {}, "moves": {}, "block": [], "heal": [],
                "disruption": [], "tempo": [],
            },
        }],
    }


def _pd(encounters: dict, moves: dict, disruption: list | None = None,
        block: list | None = None, tempo: list | None = None) -> dict:
    return {
        "encounters": encounters, "moves": moves, "block": block or [],
        "heal": [], "disruption": disruption or [], "tempo": tempo or [],
    }


def _profile_fight(enemy: str, move: str, **extra: object) -> list[dict]:
    disruption = extra.get("disruption") or []
    block = extra.get("block") or []
    tempo = extra.get("tempo") or [{"enemy": enemy, "move": move, "kind": "act",
                                    "amount": 0, "blocked": 0}]
    return [{
        "shatters": extra.get("shatters", 0), "smolderKills": extra.get("smolder", 0),
        "turns": extra.get("turns", 4), "hpLost": extra.get("hpLost", 3),
        "enemies": [enemy],
        "profileDiagnostics": _pd({enemy: 1}, {enemy: {move: 1}},
                                  list(disruption), list(block), list(tempo)),
    }]


class Tier2F0ProtocolTest(unittest.TestCase):
    def test_protocol_binds_the_frozen_503_rectangle(self) -> None:
        selected = evaluation_from_registry(PROTOCOL, "f0", AXES)
        spec = evaluation_spec(selected)
        self.assertEqual(503, selected["issue"])
        self.assertTrue(selected["completeRectangle"])
        self.assertEqual("tier2", selected["candidateSource"])
        self.assertEqual(81, selected["candidateCount"])
        self.assertEqual(508, selected["candidateSeed"])
        self.assertEqual(10000, selected["bootstrap"])
        self.assertEqual(508, selected["bootSeed"])
        self.assertTrue(selected["inheritHostQualification"])
        self.assertEqual(["4.7.1.stable", "4.7.2.stable"], selected["godotPrefixes"])
        self.assertEqual({
            "controlStage": "tier2-f0-controls", "controlRoot": 7454,
            "controlFirst": 12100, "controlLast": 12131, "controlArms": [1, 2],
            "landscapeStage": "tier2-f0-mini-landscape", "landscapeRoot": 7454,
            "landscapeFirst": 12200, "landscapeLast": 12207,
            "policyFirst": 0, "policyCount": 128,
        }, spec)
        expected_controls = 32 * 2 * 4
        expected_landscape = 128 * 4 * 8
        self.assertEqual(256, expected_controls)
        self.assertEqual(4096, expected_landscape)
        self.assertEqual(352_512, 81 * (expected_controls + expected_landscape))
        contract = load_contract()
        self.assertEqual("", check_invocation(
            contract, "tier2-f0-controls", 12100, 12131, 7454))
        self.assertEqual("", check_invocation(
            contract, "tier2-f0-mini-landscape", 12200, 12207, 7454))
        self.assertTrue(check_invocation(
            contract, "tier2-f0-controls", 5000, 5000, 7454))
        self.assertTrue(check_invocation(
            contract, "tier2-f0-controls", 9100, 9100, 7454))
        self.assertTrue(check_invocation(
            contract, "tier2-f0-controls", 12100, 12131, 3454))
        self.assertTrue(check_invocation(
            contract, "tier2-f0-controls", 13400, 13400, 7454))
        self.assertTrue(check_invocation(
            contract, "tier2-f0-mini-landscape", 12200, 12207, 215))
        self.assertTrue(check_invocation(
            contract, "tier2-f0-controls", 12300, 12300, 7454))
        self.assertTrue(check_invocation(
            contract, "tier2-f0-controls", 12064, 12064, 7454))
        self.assertEqual("tier2-f0-controls", spec["controlStage"])
        self.assertEqual("tier2-f0-mini-landscape", spec["landscapeStage"])

    def test_complete_rectangle_only_fail_closes_on_errors(self) -> None:
        split_ok = [
            {"arm": arm, "aspect": aspect, "vow": 0, "seed": 12100, "outcome": outcome,
             "error": "", "deck": 30, "fights": []}
            for arm in (1, 2) for aspect, outcome in (("duskblade", "win"), ("ashwarden", "loss"))
        ]
        stall = split_ok + [{"arm": 1, "aspect": "duskblade", "vow": 0, "seed": 12101,
                             "outcome": "stall", "error": "", "deck": 30, "fights": []}]
        self.assertEqual("stalls-beyond-baseline", control_fault(stall, 0))
        self.assertEqual("", control_fault(stall, 0, complete_rectangle=True))
        errors = split_ok + [{"arm": 1, "aspect": "duskblade", "vow": 0, "seed": 12101,
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

    def test_bind_row_keeps_tier2_identity_and_profile_fights(self) -> None:
        identity = {
            "id": "t2-c001", "values": {"blockMitigation": "low",
                                        "blockTempoTrade": "baseline",
                                        "disruptionIntensity": "baseline",
                                        "disruptionTempoTrade": "baseline"},
            "fileSha256": "a" * 64, "semanticSha256": "b" * 64,
            "candidateFileSha256": "c" * 64, "candidateSemanticSha256": "d" * 64,
            "contentFileSha256": "e" * 64, "contentSemanticSha256": "f" * 64,
            "mobOverrideFileSha256": "1" * 64, "mobOverrideSemanticSha256": "2" * 64,
            "registryFileSha256": "3" * 64, "registrySemanticSha256": "4" * 64,
            "effectiveCatalogueSemanticSha256": "5" * 64,
            "searchSpaceSha256": "6" * 64, "seedRegistrySha256": "7" * 64,
            "commit": "deadbeef", "driverSha256": "8" * 64,
            "godotVersion": "4.7.1.stable.official.a13da4feb",
            "hostFingerprint": "9" * 64,
        }
        row = {
            "aspect": "duskblade", "vow": 0, "seed": 12100, "arm": 1, "outcome": "win",
            "error": "", "deck": 30, "fights": _profile_fight(
                "waylayer", "trick",
                disruption=[{"enemy": "waylayer", "move": "trick", "status": "frail",
                             "target": "player", "amount": 2}]),
            "deckIds": ["strike"], "relics": ["hollowCrown"],
        }
        extra = bind_row(row, identity, extras=True)
        self.assertEqual("t2-c001", extra["candidateId"])
        self.assertEqual(identity["values"], extra["values"])
        self.assertEqual(identity["values"], extra["vector"])
        self.assertEqual("c" * 64, extra["candidateFileSha256"])
        self.assertEqual("e" * 64, extra["contentFileSha256"])
        self.assertEqual("1" * 64, extra["mobOverrideFileSha256"])
        self.assertEqual("3" * 64, extra["registryFileSha256"])
        self.assertEqual(["strike"], extra["deckIds"])
        self.assertEqual("frail", extra["fights"][0]["profileDiagnostics"]["disruption"][0]["status"])
        plain = bind_row(row, identity, extras=False)
        self.assertNotIn("vector", plain)
        self.assertNotIn("deckIds", plain)


class Tier2F0MetricsTest(unittest.TestCase):
    def test_valid_cells_still_use_frozen_floors_and_tie_order(self) -> None:
        cells = {}
        for aspect in ("duskblade", "ashwarden"):
            for vow in (0, 5):
                for lean in ("shatter", "smolder", "attrition"):
                    for thick in ("thin", "mid", "fat"):
                        cells[f"{aspect}:v{vow}:{lean}:{thick}"] = {
                            "wins": 0, "runs": 10, "policies": 2, "winRate": 0.9,
                        }
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
        self.assertEqual("shatter:mid", dusk["topCell"])
        self.assertEqual({"duskblade:v0": 4, "duskblade:v5": 0,
                          "ashwarden:v0": 0, "ashwarden:v5": 0},
                         occupied_valid_cells(cells, CONTRACT))

    def test_occupancy_rate_is_runs_share_of_the_grid(self) -> None:
        rows = [_land("duskblade", 0, 12200, i, 20, "win", 2, 0) for i in range(8)]
        rows += [_land("duskblade", 0, 12200, 8 + i, 30, "loss", 2, 0) for i in range(4)]
        rows += [_land("duskblade", 0, 12200, 12 + i, 40, "win", 2, 0) for i in range(4)]
        bands = occupancy_rate_bands(rows, AXES)
        dusk = bands["duskblade:v0"]
        self.assertEqual(8, dusk["thin"]["runs"])
        self.assertEqual(0.5, dusk["thin"]["occupancyRate"])
        self.assertEqual(0.25, dusk["mid"]["occupancyRate"])
        self.assertEqual(0.25, dusk["fat"]["occupancyRate"])

    def test_profile_diagnostics_use_recorded_encounters_and_moves(self) -> None:
        rows = [
            _land("duskblade", 0, 12200, 0, 22, "win", 2, 0,
                  _profile_fight("gravewarden", "bulwark",
                                 block=[{"enemy": "gravewarden", "move": "bulwark", "amount": 12}])),
            _land("duskblade", 0, 12201, 1, 22, "win", 2, 0,
                  _profile_fight("waylayer", "trick",
                                 disruption=[{"enemy": "waylayer", "move": "trick",
                                              "status": "frail", "target": "player", "amount": 2}])),
            _land("ashwarden", 0, 12200, 0, 22, "win", 0, 2),
        ]
        diag = profile_diagnostics(rows, CONTRACT)
        dusk = diag["duskblade:v0"]
        self.assertEqual(2, dusk["eligibleRuns"])
        self.assertEqual(2, dusk["exposedRuns"])
        self.assertEqual(2, dusk["firedRuns"])
        self.assertEqual(1, dusk["encounters"].get("gravewarden"))
        self.assertEqual(1, dusk["encounters"].get("waylayer"))
        self.assertEqual(1, dusk["blockEvents"])
        self.assertEqual(1, dusk["disruptionEvents"])
        self.assertEqual(1.0, dusk["firingRate"])
        self.assertEqual("reached", dusk["reachability"]["block"])
        self.assertEqual("reached", dusk["reachability"]["disruption"])
        ash = diag["ashwarden:v0"]
        self.assertEqual("unreachable", ash["reachability"]["block"])
        self.assertEqual("unreachable", ash["reachability"]["disruption"])
        self.assertIsNone(ash["firingRate"])

    def test_malformed_disruption_events_fail_closed(self) -> None:
        ok = _land("duskblade", 0, 12200, 0, 22, "win", 2, 0, _profile_fight(
            "waylayer", "trick",
            disruption=[{"enemy": "waylayer", "move": "trick", "status": "frail",
                         "target": "player", "amount": 2}]))
        self.assertEqual("", profile_attribution_fault([ok]))
        bad_target = _land("duskblade", 0, 12200, 0, 22, "win", 2, 0, _profile_fight(
            "waylayer", "trick",
            disruption=[{"enemy": "waylayer", "move": "trick", "status": "frail",
                         "target": "enemy", "amount": 2}]))
        self.assertEqual("profile-attribution-failed", profile_attribution_fault([bad_target]))
        bad_status = _land("duskblade", 0, 12200, 0, 22, "win", 2, 0, _profile_fight(
            "waylayer", "trick",
            disruption=[{"enemy": "waylayer", "move": "trick", "status": "strength",
                         "target": "player", "amount": 2}]))
        self.assertEqual("profile-attribution-failed", profile_attribution_fault([bad_status]))

    def test_authored_disruption_amount_follows_the_intensity_knob(self) -> None:
        vector = {key: "baseline" for key in KNOBS}
        self.assertEqual(2, authored_amount(vector, "waylayer", "trick", "frail"))
        self.assertEqual(2, authored_amount(vector, "gravewarden", "entomb", "frail"))
        vector["disruptionIntensity"] = "high"
        self.assertEqual(3, authored_amount(vector, "watcherEye", "gaze", "vulnerable"))
        vector["disruptionIntensity"] = "low"
        self.assertEqual(1, authored_amount(vector, "waylayer", "trick", "frail"))

    def test_orthogonal_coding_is_the_frozen_508_contrasts(self) -> None:
        self.assertEqual(-1, contrast_weight("linear", "low"))
        self.assertEqual(0, contrast_weight("linear", "baseline"))
        self.assertEqual(1, contrast_weight("linear", "high"))
        self.assertEqual(1, contrast_weight("quadratic", "low"))
        self.assertEqual(-2, contrast_weight("quadratic", "baseline"))
        self.assertEqual(1, contrast_weight("quadratic", "high"))

    def test_factorial_effect_interval_crossing_zero_is_not_a_finding(self) -> None:
        rows = []
        levels = ("baseline", "low", "high")
        index = 0
        for a in levels:
            for b in levels:
                for c in levels:
                    for d in levels:
                        rows.append({
                            "id": f"t2-c{index:03d}", "status": "complete",
                            "values": {
                                "blockMitigation": a, "blockTempoTrade": b,
                                "disruptionIntensity": c, "disruptionTempoTrade": d,
                            },
                            "responses": {"c1aProxy": 2.0 if a != "high" else 1.9},
                        })
                        index += 1
        effects = factorial_effects(rows, n_boot=40, rng_seed=508)
        term = effects["main"]["blockMitigation"]["linear"]["c1aProxy"]
        self.assertLessEqual(term["p025"], term["p975"])
        self.assertIn("crossesZero", term)
        self.assertEqual(4, len(effects["main"]))
        self.assertEqual(6, len(effects["pairwise"]))
        if term["crossesZero"]:
            self.assertFalse(term["finding"])

    def test_decision_requires_paired_breadth_on_both_aspects(self) -> None:
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
                        valid = (lean == ("shatter" if aspect == "duskblade" else "smolder")
                                 and thick == "fat")
                        key = f"{aspect}:v{vow}:{lean}:{thick}"
                        cells[key] = {
                            "wins": 400 if valid else 10,
                            "runs": 500 if valid else 10,
                            "policies": 25 if valid else 2,
                            "winRate": 0.80 if valid else 0.10,
                            "stalls": 0, "errors": 0,
                        }
        proxies = grid_proxies(controls, cells)
        landscape = [
            _land("duskblade", 0, 12200, 0, 22, "win", 2, 0,
                  _profile_fight("gravewarden", "bulwark",
                                 block=[{"enemy": "gravewarden", "move": "bulwark", "amount": 12}])),
            _land("duskblade", 0, 12200, 1, 22, "win", 2, 0,
                  _profile_fight("waylayer", "trick",
                                 disruption=[{"enemy": "waylayer", "move": "trick",
                                              "status": "frail", "target": "player",
                                              "amount": 2}])),
            _land("ashwarden", 0, 12200, 0, 22, "win", 0, 2,
                  _profile_fight("shellback", "shell",
                                 block=[{"enemy": "shellback", "move": "shell", "amount": 13}])),
            _land("ashwarden", 0, 12200, 1, 22, "win", 0, 2,
                  _profile_fight("watcherEye", "gaze",
                                 disruption=[{"enemy": "watcherEye", "move": "gaze",
                                              "status": "vulnerable", "target": "player",
                                              "amount": 2}])),
        ]
        result = {
            "id": "t2-c001",
            "values": {"blockMitigation": "high", "blockTempoTrade": "baseline",
                       "disruptionIntensity": "baseline", "disruptionTempoTrade": "baseline"},
            "controls": controls, "cells": cells, "proxies": proxies,
            "controlStalls": 0, "controlErrors": 0,
            "landscapeStalls": 0, "landscapeErrors": 0,
        }
        attach_tier2_fields(
            result, AXES, CONTRACT,
            identity_load(json.loads((REPO / "content/full-content.json").read_text())),
            landscape, [])
        baseline = json.loads(json.dumps({k: v for k, v in result.items() if k != "decision"}))
        baseline["id"] = "t2-c000"
        baseline["values"] = {key: "baseline" for key in KNOBS}
        result["bootstrap"] = {
            "vsBaseline": {
                "c1": {key: {"p025": -0.4, "p50": -0.2, "p975": -0.05} for key in ("c1a", "c1b")},
                "breadth": {grid: {"p025": -0.4, "p50": -0.2, "p975": -0.05} for grid in GRIDS},
            }
        }
        for grid in ("duskblade:v0", "ashwarden:v0"):
            result["validProxies"][grid]["within10"] = 2
            result["validProxies"][grid]["viable"] = 2
            baseline["validProxies"][grid]["within10"] = 1
            baseline["validProxies"][grid]["viable"] = 1
            # A non-dominant thin cell actually improves versus t2-c000.
            result["cells"][f"{grid}:shatter:thin" if grid.startswith("dusk") else f"{grid}:smolder:thin"] = {
                "wins": 80, "runs": 200, "policies": 10, "winRate": 0.40,
            }
            baseline["cells"][f"{grid}:shatter:thin" if grid.startswith("dusk") else f"{grid}:smolder:thin"] = {
                "wins": 10, "runs": 200, "policies": 10, "winRate": 0.05,
            }
        decision = decide(result, baseline, CONTRACT)
        self.assertTrue(result["guardrails"]["clear"])
        self.assertTrue(decision["simulatorClear"])
        self.assertTrue(decision["profileAttribution"])
        self.assertIn("eligible", decision)


class Tier2F0ProductTest(unittest.TestCase):
    def test_tidy_pins_the_published_harvest_claims(self) -> None:
        tidy = json.loads((REPO / "docs/balance/data/503/tidy.json").read_text())
        self.assertEqual(81, len(tidy["candidates"]))
        self.assertEqual(352_512, tidy["totalRows"])
        self.assertEqual(81, tidy["complete"])
        self.assertEqual(0, tidy["earlyStop"])
        self.assertEqual([], tidy["racingSet"])
        self.assertEqual([], tidy["shortlist"])
        self.assertEqual("4.7.1.stable.official.a13da4feb", tidy["godotVersion"])
        self.assertTrue(tidy["hostFingerprint"].startswith("3a887fec"))
        for row in tidy["candidates"]:
            self.assertEqual("complete", row["status"])
            self.assertEqual(0, int(row["controlErrors"]))
            self.assertEqual(0, int(row["landscapeErrors"]))
            self.assertIn(row["id"], {f"t2-c{i:03d}" for i in range(81)})
            self.assertEqual(set(KNOBS), set(row["vector"]))
            self.assertTrue(row["identityClear"])
            self.assertTrue(row["profileAttribution"])
        by_id = {row["id"]: row for row in tidy["candidates"]}
        self.assertEqual({key: "baseline" for key in KNOBS}, by_id["t2-c000"]["vector"])
        self.assertEqual(
            "91e58450e16bbf20b5f6d2e774265b6557a725a4f89748eac7a8ccbfbedebd51",
            by_id["t2-c000"]["observationsSha256"])
        self.assertEqual(
            "243c03276d4dc517c6979d65e498cacf4f29d252a113176cf73ebb2fa158f407",
            by_id["t2-c012"]["observationsSha256"])
        self.assertFalse(any((fx.get("c1aProxy") or {}).get("finding")
                             or (fx.get("c1bProxy") or {}).get("finding")
                             for knob in tidy["factorialEffects"]["main"].values()
                             for fx in knob.values()))

    def test_factorial_point_estimates_reproduce_from_tidy_vectors(self) -> None:
        tidy = json.loads((REPO / "docs/balance/data/503/tidy.json").read_text())
        rows = tidy["candidates"]
        ys = [float(row["validC1a"]) for row in rows]
        weights = [float(contrast_weight("linear", row["vector"]["blockTempoTrade"]))
                   for row in rows]
        estimate = _term(weights, ys)
        published = tidy["factorialEffects"]["main"]["blockTempoTrade"]["linear"]["c1aProxy"]
        self.assertAlmostEqual(estimate, published["estimate"])
        self.assertTrue(published["crossesZero"])
        self.assertFalse(published["finding"])

    def test_m4_packet_matches_the_pre_registered_slice(self) -> None:
        spec = PROTOCOL["m4Replay"]
        self.assertEqual("t2-c000", spec["candidate"])
        self.assertEqual("tier2-f0-controls", spec["stage"])
        self.assertEqual(7454, spec["root"])
        self.assertEqual(12100, spec["seeds"]["first"])
        self.assertEqual(12103, spec["seeds"]["last"])
        packet = json.loads(
            (REPO / "docs/balance/data/503/m4-replay-packet.json").read_text())
        self.assertEqual(spec["candidate"], packet["candidate"])
        self.assertEqual(["win", "win", "win", "win"], packet["expectedOutcomes"])
        self.assertEqual(4, len(packet["rows"]))
        self.assertEqual(["duskblade"] * 4, [row["aspect"] for row in packet["rows"]])
        self.assertEqual([0] * 4, [row["vow"] for row in packet["rows"]])
        self.assertEqual([1] * 4, [row["arm"] for row in packet["rows"]])
        self.assertEqual([12100, 12101, 12102, 12103],
                         [row["seed"] for row in packet["rows"]])
        dropped = drop_volatile(packet["rows"])
        self.assertEqual(dropped, drop_volatile(json.loads(json.dumps(packet["rows"]))))
        first = packet["rows"][0]
        self.assertIn("vector", first)
        self.assertIn("profileDiagnostics", first["fights"][0])

    def test_tidy_candidate_shape_is_the_public_product(self) -> None:
        slim = tidy_candidate({
            "id": "t2-c000", "status": "complete", "earlyStop": None,
            "values": {key: "baseline" for key in KNOBS},
            "controlErrors": 0, "controlStalls": 0, "landscapeErrors": 0,
            "landscapeStalls": 1, "observationsSha256": "a" * 64,
            "controlRowCount": 256, "landscapeRowCount": 4096,
            "validC1a": 2.0, "validC1b": 2.0, "thinDeficit": 0.1, "midDeficit": 0.2,
            "guardrails": {"clear": True, "reasons": [], "identity": {"clear": True}},
            "decision": {"eligible": False, "reasons": ["breadth-not-credible"],
                         "simulatorClear": True, "profileAttribution": True},
            "proxies": {grid: {"topCell": "shatter:fat", "arm2Rate": 0.25} for grid in GRIDS},
            "validProxies": {grid: {"within10": 1, "viable": 1} for grid in GRIDS},
            "deckBands": {grid: {"thin": {"runs": 10, "winRate": 0.1, "occupancyRate": 0.2},
                                 "mid": {"runs": 20, "winRate": 0.3, "occupancyRate": 0.4},
                                 "fat": {"runs": 20, "winRate": 0.8, "occupancyRate": 0.4}}
                          for grid in GRIDS},
            "rankGaps": {grid: {"topToThird": 0.4, "topToFourth": 0.5} for grid in GRIDS},
        })
        self.assertEqual("t2-c000", slim["id"])
        self.assertEqual("baseline", slim["vector"]["blockMitigation"])
        self.assertIn("thinWinRate", slim)
        self.assertIn("within10", slim)

    def test_racing_set_is_bounded_and_drops_near_duplicates(self) -> None:
        candidates = []
        for index, vector in enumerate((
            {key: "baseline" for key in KNOBS},
            {**{key: "baseline" for key in KNOBS}, "blockMitigation": "high"},
            {**{key: "baseline" for key in KNOBS}, "blockMitigation": "high",
             "disruptionIntensity": "low"},
            {**{key: "baseline" for key in KNOBS}, "disruptionIntensity": "high"},
        )):
            candidates.append({
                "id": f"t2-c{index:03d}", "status": "complete", "earlyStop": None,
                "values": vector,
                "validC1a": 1.0 - index * 0.05, "validC1b": 1.0,
                "thinDeficit": 0.4, "midDeficit": 0.4,
                "gapThird": 0.3, "gapFourth": 0.4,
                "decision": {"eligible": index > 0, "reasons": []},
                "guardrails": {"clear": True},
            })
        chosen = racing_set(candidates)
        self.assertLessEqual(len(chosen), 4)
        self.assertNotIn("t2-c000", chosen)
        self.assertTrue(all(cid.startswith("t2-c") for cid in chosen))


if __name__ == "__main__":
    unittest.main()
