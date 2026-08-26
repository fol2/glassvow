#!/usr/bin/env python3
"""Contract tests for the #492 Tier-1 progressive race."""
from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "tools"))

from balance_f0 import (  # noqa: E402
    create_audit_receipt,
    evaluation_from_registry,
    evaluation_spec,
    is_tier1_profile,
    observation_bytes,
    validate_audit_finalist_set,
    validate_candidate_manifest,
)
from balance_f0_tier1 import guardrails  # noqa: E402
from balance_seed_contract import check_invocation, load_contract  # noqa: E402
from balance_seed_contract import file_sha256, sha256_bytes  # noqa: E402
from balance_f1_evidence import reanalyse_layer  # noqa: E402
from balance_tier1_racing import decide_layer, pairwise_c1, strong_breadth  # noqa: E402

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
        self.assertEqual("strongest-per-cell-then-win-rate-v1",
                         cem["islandSelection"]["method"])
        self.assertEqual(4000, cem["pairedBootstrap"]["resamples"])
        self.assertEqual("holdout seed block across six islands",
                         cem["pairedBootstrap"]["unit"])
        audit = evaluation_from_registry(protocol, "audit", contract["frozenLandscape"])
        self.assertTrue(audit["finalistAudit"])
        self.assertEqual("tier1-audit", evaluation_spec(audit)["controlStage"])
        self.assertEqual("baseline plus frozen layer3 promoted ids",
                         protocol["audit"]["exactCandidates"])
        self.assertTrue(protocol["audit"]["receipt"]["exclusiveCreate"])

    def test_generated_bundle_must_match_the_committed_491_candidate_identities(self) -> None:
        expected = json.loads(
            (REPO / "docs/balance/data/491/candidate-manifest.json").read_text())
        actual = json.loads(json.dumps(expected))
        validate_candidate_manifest(actual, expected)
        actual["candidates"][0]["values"]["neutralCycle"] = "high"
        with self.assertRaisesRegex(ValueError, "candidate manifest drift"):
            validate_candidate_manifest(actual, expected)


class Tier1F1DecisionTest(unittest.TestCase):
    @staticmethod
    def _layer(candidate: dict, baseline: dict) -> dict:
        by_id = {baseline["id"]: baseline, candidate["id"]: candidate}
        for candidate_id in ("t1-c036", "t1-c040", "t1-c005"):
            row = _candidate(candidate_id, 1.1)
            row["earlyStop"] = "fixture-stop"
            row["status"] = "early-stop"
            by_id[candidate_id] = row
        return {"candidates": list(by_id.values())}

    def test_final_layer_promotes_only_reproducible_strong_breadth(self) -> None:
        protocol = json.loads(PROTOCOL_PATH.read_text())
        baseline = _candidate("t1-c000", 1.5, within=2, viable=3)
        candidate = _candidate("t1-c012", 1.0)
        _add_strengthened_cells(candidate, baseline)
        previous = {"evaluation": "layer2", "promoted": list(protocol["racingSet"])}
        report = decide_layer(self._layer(candidate, baseline), protocol, "layer3", previous)
        row = next(item for item in report["decisions"] if item["id"] == "t1-c012")
        self.assertEqual("promote", row["decision"])
        self.assertTrue(row["strongBreadth"]["clear"])
        self.assertEqual(["t1-c012"], report["promoted"])

    def test_excess_stall_fails_closed_before_budget_ranking(self) -> None:
        protocol = json.loads(PROTOCOL_PATH.read_text())
        baseline = _candidate("t1-c000", 1.5, within=2, viable=3)
        candidate = _candidate("t1-c012", 1.0)
        candidate["landscapeStalls"] = 1
        report = decide_layer(self._layer(candidate, baseline), protocol, "layer1")
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

    def test_layer1_missing_candidate_fails_closed(self) -> None:
        protocol = json.loads(PROTOCOL_PATH.read_text())
        with self.assertRaisesRegex(ValueError, "exact candidate set"):
            decide_layer({"candidates": [_candidate("t1-c000", 1.5),
                                          _candidate("t1-c012", 1.0)]},
                         protocol, "layer1")

    def test_pairwise_crn_interval_controls_dominance_not_marginal_intervals(self) -> None:
        protocol = json.loads(PROTOCOL_PATH.read_text())
        baseline = _candidate("t1-c000", 1.5, within=2, viable=3)
        candidate = _candidate("t1-c012", 1.0)
        other = _candidate("t1-c036", 1.0)
        rows = self._layer(candidate, baseline)
        rows["candidates"] = [row for row in rows["candidates"] if row["id"] != "t1-c036"]
        rows["candidates"].append(other)
        pairwise = {"t1-c012:t1-c036": {
            key: {"p025": -0.3, "p50": -0.2, "p975": -0.01} for key in ("c1a", "c1b")
        }, "t1-c036:t1-c012": {
            key: {"p025": 0.01, "p50": 0.2, "p975": 0.3} for key in ("c1a", "c1b")
        }}
        report = decide_layer(rows, protocol, "layer1", pairwise=pairwise)
        stopped = {row["id"]: row["reason"] for row in report["decisions"]
                   if row["decision"] == "stop"}
        self.assertEqual("paired-confidence-dominated", stopped["t1-c036"])

    def test_strict_identity_uses_aspect_top_and_vow5_ceiling_is_exclusive(self) -> None:
        proxies = {grid: {"arm2Rate": 0.1, "margin": 0.5,
                          "topCell": "shatter:fat" if grid.startswith("duskblade")
                          else "smolder:fat"} for grid in GRIDS}
        valid = {grid: {"topRate": 0.8,
                        "topCell": "shatter:fat" if grid.startswith("duskblade")
                        else "smolder:fat"} for grid in GRIDS}
        valid["duskblade:v0"]["topCell"] = "smolder:fat"
        valid["duskblade:v5"]["topRate"] = 0.90
        result = {"proxies": proxies, "validProxies": valid, "_controlRows": []}
        load_rules = {"duskblade:shatter-enabled": True,
                      "duskblade:smolder-application-blocked": True,
                      "ashwarden:shatter-blocked": True,
                      "ashwarden:smolder-enabled": True}
        strict = guardrails(result, json.loads(
            (REPO / "docs/balance/490-f0-response-contract-v1.json").read_text()),
            load_rules, strict=True)
        self.assertTrue(strict["identity"]["clear"])
        self.assertFalse(strict["byGrid"]["vow5Proxy"]["duskblade:v5"])
        proxies["duskblade:v0"]["topCell"] = "smolder:fat"
        self.assertFalse(guardrails(result, json.loads(
            (REPO / "docs/balance/490-f0-response-contract-v1.json").read_text()),
            load_rules, strict=True)["identity"]["clear"])

    def test_sealed_audit_binds_known_finalists_and_is_single_use(self) -> None:
        manifest_path = REPO / "docs/balance/data/491/candidate-manifest.json"
        manifest = json.loads(manifest_path.read_text())
        with tempfile.TemporaryDirectory(prefix="glassvow-492-audit-contract-") as temp:
            root = Path(temp)
            out = root / "audit"
            out.mkdir()
            protocol_path = root / "protocol.json"
            protocol_path.write_text("{}\n")
            decisions_path = root / "layer3-decisions.json"
            finalist_path = root / "finalist-set.json"
            audit_schema = json.loads(PROTOCOL_PATH.read_text())["audit"]["finalistSetSchema"]
            registry = {
                "issue": 492,
                "baseline": "t1-c000",
                "candidateManifest": str(manifest_path),
                "finalistBar": {"maximumFinalists": 2},
                "audit": {"finalistSetPath": str(finalist_path),
                          "auditOutput": str(out), "finalistSetSchema": audit_schema},
            }

            def write_packet(finalist: str) -> None:
                decisions = {"evaluation": "layer3", "promoted": [finalist],
                             "decisions": [{"id": finalist,
                                            "strongBreadth": {"clear": True}}]}
                decisions_path.write_text(json.dumps(decisions))
                packet = {"schemaVersion": 1, "issue": 492,
                          "protocolSha256": file_sha256(protocol_path),
                          "candidateManifestSha256": file_sha256(manifest_path),
                          "layer3Decisions": str(decisions_path),
                          "layer3DecisionsSha256": file_sha256(decisions_path),
                          "baseline": "t1-c000", "finalists": [finalist]}
                finalist_path.write_text(json.dumps(packet))

            write_packet("t1-missing")
            with self.assertRaisesRegex(ValueError, "frozen candidate manifest"):
                validate_audit_finalist_set(
                    finalist_path, protocol_path, registry, manifest,
                    ["t1-c000", "t1-missing"], out)
            write_packet("t1-c012")
            packet = validate_audit_finalist_set(
                finalist_path, protocol_path, registry, manifest,
                ["t1-c000", "t1-c012"], out)
            create_audit_receipt(out, finalist_path, packet, protocol_path)
            with self.assertRaisesRegex(ValueError, "already exists"):
                create_audit_receipt(out, finalist_path, packet, protocol_path)

    def test_tier1_decision_metrics_are_rebuilt_from_raw_not_trusted_from_summary(self) -> None:
        controls = [{"arm": arm, "aspect": aspect, "vow": vow, "seed": 9300,
                     "outcome": "win" if arm == 1 else "loss", "error": "", "deck": 30,
                     "fights": [], "packageEvents": {}}
                    for arm in (1, 2) for aspect in ("duskblade", "ashwarden")
                    for vow in (0, 5)]
        landscape = [{"policyIndex": 0, "aspect": aspect, "vow": vow, "seed": 9300,
                      "outcome": "win", "error": "", "deck": 30,
                      "fights": [{"shatters": 2, "smolderKills": 2}], "packageEvents": {}}
                     for aspect in ("duskblade", "ashwarden") for vow in (0, 5)]
        controls.sort(key=lambda row: (row["arm"], row["aspect"], row["vow"], row["seed"]))
        landscape.sort(key=lambda row: (row["policyIndex"], row["aspect"], row["vow"], row["seed"]))
        protocol = {"issue": 492, "candidateSource": "tier1", "baseline": "t1-c000",
                    "responseContract": "docs/balance/490-f0-response-contract-v1.json",
                    "controls": {"stage": "tier1-f1-racing", "root": 4454,
                                 "first": 9300, "last": 9300, "arms": [1, 2]},
                    "landscape": {"stage": "tier1-f1-racing", "root": 4454,
                                  "first": 9300, "last": 9300,
                                  "policyFirst": 0, "policyCount": 1}}
        with tempfile.TemporaryDirectory(prefix="glassvow-492-reanalyse-") as temp:
            root, bundle = Path(temp) / "raw", Path(temp) / "bundle"
            content = (REPO / "content/full-content.json").read_bytes()
            rows = []
            for candidate_id in ("t1-c000", "t1-c012"):
                values = {"duskNonShatter": "s009" if candidate_id == "t1-c000" else "high"}
                candidate_dir = root / candidate_id
                (candidate_dir / "controls").mkdir(parents=True)
                (candidate_dir / "landscape").mkdir()
                (candidate_dir / "controls/shard-000.json").write_text(
                    json.dumps({"runs": controls}))
                (candidate_dir / "landscape/shard-000.ndjson").write_text(
                    "{}\n" + "".join(json.dumps(row) + "\n" for row in landscape))
                content_path = bundle / candidate_id / "full-content.json"
                content_path.parent.mkdir(parents=True)
                content_path.write_bytes(content)
                identity = {"id": candidate_id, "values": values,
                            "fileSha256": file_sha256(content_path), "semanticSha256": "e" * 64,
                            "searchSpaceSha256": "s" * 64, "seedRegistrySha256": "r" * 64,
                            "commit": "deadbeef", "driverSha256": "d" * 64,
                            "godotVersion": "4.7.2.stable", "hostFingerprint": "h" * 64}
                payload = observation_bytes(controls + landscape, identity, extras=True)
                (candidate_dir / "observations.jsonl").write_bytes(payload)
                rows.append({"id": candidate_id, "values": values,
                             "fileSha256": identity["fileSha256"],
                             "semanticSha256": identity["semanticSha256"],
                             "commit": identity["commit"], "godotVersion": identity["godotVersion"],
                             "hostFingerprint": identity["hostFingerprint"], "status": "complete",
                             "earlyStop": None, "controlArms": [1, 2], "controlRowCount": 8,
                             "landscapeRowCount": 4, "observationsSha256": sha256_bytes(payload),
                             "validC1a": -999,
                             "packageDiagnostics": {"duskNonShatter": {
                                 "duskblade:v0": {"mechanismFired": True}}}})
            (bundle / "manifest.json").write_text(json.dumps({"candidates": rows}))
            summary = {"protocol": protocol, "searchSpaceSha256": "s" * 64,
                       "seedRegistrySha256": "r" * 64, "driverSha256": "d" * 64,
                       "candidates": rows}
            rebuilt = reanalyse_layer(summary, root, 10, load_contract()["frozenLandscape"],
                                      bundle)
            self.assertGreaterEqual(rebuilt["candidates"][1]["validC1a"], 0.0)
            self.assertFalse(rebuilt["candidates"][1]["packageDiagnostics"]
                             ["duskNonShatter"]["duskblade:v0"]["mechanismFired"])
            pairwise = pairwise_c1(
                root, rebuilt["candidates"], 10, 49201,
                json.loads((REPO / protocol["responseContract"]).read_text()))
            self.assertEqual({"t1-c000:t1-c012", "t1-c012:t1-c000"}, set(pairwise))


if __name__ == "__main__":
    unittest.main()
