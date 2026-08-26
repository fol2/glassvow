#!/usr/bin/env python3
"""Contract tests for the #492 Tier-1 progressive race."""
from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "tools"))

from balance_f0 import evaluation_from_registry, evaluation_spec, is_tier1_profile  # noqa: E402
from balance_seed_contract import check_invocation, load_contract  # noqa: E402
from balance_tier1_racing import decide_layer, strong_breadth  # noqa: E402

PROTOCOL_PATH = REPO / "docs/balance/492-tier1-racing-protocol-v1.json"
GRIDS = ("duskblade:v0", "duskblade:v5", "ashwarden:v0", "ashwarden:v5")


def _candidate(candidate_id: str, breadth: float, within: int = 3,
               viable: int = 4) -> dict:
    values = {"duskNonShatter": "s009", "neutralCycle": "s009"}
    if candidate_id != "t1-c000":
        values["duskNonShatter"] = "high"
    return {
        "id": candidate_id,
        "status": "complete",
        "earlyStop": None,
        "values": values,
        "validC1a": breadth,
        "validC1b": breadth,
        "validBreadthSum": breadth * 2,
        "validProxies": {grid: {"within10": within, "viable": viable}
                         for grid in GRIDS},
        "bootstrap": {
            "c1": {
                "c1a": {"p025": breadth - 0.1, "p50": breadth, "p975": breadth + 0.1},
                "c1b": {"p025": breadth - 0.1, "p50": breadth, "p975": breadth + 0.1},
            },
            "vsBaseline": {
                "c1": {
                    "c1a": {"p025": -0.4, "p50": -0.2, "p975": -0.01},
                    "c1b": {"p025": -0.4, "p50": -0.2, "p975": -0.01},
                },
                "breadth": {grid: {"p025": -0.2, "p50": -0.1, "p975": 0.0}
                            for grid in GRIDS},
            },
        },
        "guardrails": {"clear": True, "reasons": []},
        "controlStalls": 0,
        "controlErrors": 0,
        "landscapeStalls": 0,
        "landscapeErrors": 0,
        "packageDiagnostics": {
            "duskNonShatter": {
                "duskblade:v0": {"mechanismFired": candidate_id != "t1-c000"},
                "duskblade:v5": {"mechanismFired": candidate_id != "t1-c000"},
                "ashwarden:v0": {"mechanismFired": False},
                "ashwarden:v5": {"mechanismFired": False},
            }
        },
        "cells": {},
        "fileSha256": "a" * 64,
        "semanticSha256": "b" * 64,
        "observationsSha256": "c" * 64,
        "controlRowCount": 1,
        "landscapeRowCount": 1,
    }


def _add_strengthened_cells(candidate: dict, baseline: dict) -> None:
    for aspect, lean in (("duskblade", "smolder"), ("ashwarden", "shatter")):
        key = f"{aspect}:v0:{lean}:mid"
        baseline["cells"][key] = {"policies": 30, "runs": 500, "winRate": 0.30}
        candidate["cells"][key] = {"policies": 30, "runs": 500, "winRate": 0.36}


class Tier1F1ProtocolTest(unittest.TestCase):
    def test_protocol_freezes_all_rectangles_and_caps(self) -> None:
        protocol = json.loads(PROTOCOL_PATH.read_text())
        self.assertTrue(is_tier1_profile(evaluation_from_registry(
            protocol, "layer1", load_contract()["frozenLandscape"])))
        self.assertEqual(
            ["t1-c012", "t1-c036", "t1-c040", "t1-c005"], protocol["racingSet"])
        expected = {
            "layer1": (9331, 128, 9307, 4),
            "layer2": (9363, 256, 9315, 3),
            "layer3": (9427, 512, 9331, 2),
        }
        contract = load_contract()
        for name, (control_last, policies, landscape_last, cap) in expected.items():
            selected = evaluation_from_registry(protocol, name, contract["frozenLandscape"])
            spec = evaluation_spec(selected)
            self.assertEqual((9300, control_last),
                             (spec["controlFirst"], spec["controlLast"]))
            self.assertEqual((policies, 9300, landscape_last),
                             (spec["policyCount"], spec["landscapeFirst"],
                              spec["landscapeLast"]))
            self.assertEqual(cap, protocol["evaluations"][name]["maxPromotions"])
            self.assertEqual("", check_invocation(
                contract, "tier1-f1-racing", 9300, control_last, 4454))
        cem = protocol["miniCem"]
        self.assertEqual((6454, 4454, 24, 16, 4, 6),
                         tuple(cem[key] for key in
                               ("root", "policyRoot", "islands", "popSize", "elite", "maxGen")))
        self.assertEqual("", check_invocation(
            contract, cem["stage"], 9600, 9647, 6454, 10000, 10039))
        audit = evaluation_from_registry(protocol, "audit", contract["frozenLandscape"])
        self.assertTrue(audit["finalistAudit"])
        self.assertEqual("tier1-audit", evaluation_spec(audit)["controlStage"])


class Tier1F1DecisionTest(unittest.TestCase):
    def test_final_layer_promotes_only_reproducible_strong_breadth(self) -> None:
        protocol = json.loads(PROTOCOL_PATH.read_text())
        baseline = _candidate("t1-c000", 1.5, within=2, viable=3)
        candidate = _candidate("t1-c012", 1.0)
        _add_strengthened_cells(candidate, baseline)
        report = decide_layer({"candidates": [baseline, candidate]}, protocol, "layer3")
        row = next(item for item in report["decisions"] if item["id"] == "t1-c012")
        self.assertEqual("promote", row["decision"])
        self.assertTrue(row["strongBreadth"]["clear"])
        self.assertEqual(["t1-c012"], report["promoted"])

    def test_excess_stall_fails_closed_before_budget_ranking(self) -> None:
        protocol = json.loads(PROTOCOL_PATH.read_text())
        baseline = _candidate("t1-c000", 1.5, within=2, viable=3)
        candidate = _candidate("t1-c012", 1.0)
        candidate["landscapeStalls"] = 1
        report = decide_layer({"candidates": [baseline, candidate]}, protocol, "layer1")
        row = next(item for item in report["decisions"] if item["id"] == "t1-c012")
        self.assertEqual(("stop", "stalls-beyond-baseline"),
                         (row["decision"], row["reason"]))

    def test_strong_breadth_requires_both_aspects_to_gain_a_non_dominant_cell(self) -> None:
        protocol = json.loads(PROTOCOL_PATH.read_text())
        baseline = _candidate("t1-c000", 1.5, within=2, viable=3)
        candidate = _candidate("t1-c012", 1.0)
        _add_strengthened_cells(candidate, baseline)
        self.assertTrue(strong_breadth(candidate, baseline,
                                       protocol["finalistBar"]["layer1"])["clear"])
        candidate["cells"].pop("ashwarden:v0:shatter:mid")
        self.assertFalse(strong_breadth(candidate, baseline,
                                        protocol["finalistBar"]["layer1"])["clear"])


if __name__ == "__main__":
    unittest.main()
