#!/usr/bin/env python3
"""Identity/citation check for #542 source-only entry. No Godot, no kernel panels."""
from __future__ import annotations

import json
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
ART = "research/p9-six-route/duskblade-first-proof-20260912"
ENTRY = Path(__file__).resolve().parent / "SOURCE-ENTRY.md"
HANDOFF = ROOT / "research/p9-six-route/SESSION-HANDOFF.md"
BOUND_HEAD = "5b6b3a718b8c6200d12d5c06c85702ea9a0f35c6"
RECEIPT = {
    "CONTRACT.md": "265f2e7b696896659b0352e2bc69b31d5d938991",
    "SPECIFICATION.md": "45ca750e193fe114bb528f517088e21bbbcde908",
    "WORKER_TASK.md": "4482566565fd988bf01e601194fd6865f616e7b3",
    "reference_kernel.py": "ee091fb503849117358b3691264fca71803f8bbc",
    "METRIC_REGISTRY.json": "b98b3ef4a73890fe60f55c148c1df235fbb3b617",
    "ALLOCATION.json": "824ff18acbca2f776533beed83a43b21d9a50f2c",
    "ADAPTER_RECORDS.md": "ba53bce69de7667ac62038026eb29474c5567460",
}
STATE_BLOB = "8be35c9286b4a31ffc90ea9cac411e4653707311"
POINTERS = ("5683984558", "5682513452", "5684770969")
SECTIONS = (
    "## 1. Proposed product / dependency identities and eligibility",
    "## 2. Source-backed K1/K2/K3 package tuples (not three labels)",
    "## 3. Legal per-vow acquisition / profile prerequisites and native predecessor witnesses",
    "## 4. Native source → `ADAPTER_RECORDS` field / receipt mapping",
    "## 5. Staged-readiness manifest",
)
LOCATORS = (
    "CONTRACT.md",
    "SPECIFICATION.md",
    "ADAPTER_RECORDS.md",
    "R1",
    "R2",
    "R3",
    "R4",
    "R5",
    "R6",
    "R7",
    "R8",
    "R9",
    "R10",
    "R11",
    "R12",
    "R13",
    "R14",
    "3c7b2f9dba362d19128ef82ad559d3f26e54925371d823a665767032255eadaa",
    "91fd5de56727df42fdcb539b61e7cc7a32e77f3f85dbbe13baef3513e7003cfb",
    "a0d608a5142d2e3aab799cdf33d3163922b402c2aaf2a895e46e096399b56cf1",
    "3adb0e063a536bf249d3b5d9524427facf1398304206da59d97594d3fff246e8",
    "mature-three-act-no-side-state-v1",
    "D547-NATIVE-EXPORT-2",
    "duskblade/facet",
    "duskblade/fervor",
    "duskblade/cycle",
)


def git(*args: str) -> str:
    return subprocess.check_output(["git", "-C", str(ROOT), *args], text=True).strip()


def blob(path: str, rev: str = "HEAD") -> str:
    return git("rev-parse", f"{rev}:{path}")


class SourceEntryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.entry = ENTRY.read_text()
        cls.handoff = HANDOFF.read_text()
        cls.allocation = json.loads(
            git("show", f"{BOUND_HEAD}:{ART}/ALLOCATION.json")
        )

    def test_bound_head_and_receipt_blobs(self) -> None:
        self.assertEqual(git("rev-parse", BOUND_HEAD), BOUND_HEAD)
        for name, expected in RECEIPT.items():
            self.assertEqual(blob(f"{ART}/{name}", BOUND_HEAD), expected, name)
        self.assertEqual(
            blob("research/p9-six-route/SESSION-STATE.json", BOUND_HEAD),
            STATE_BLOB,
        )

    def test_approved_prefix_unchanged_vs_bound_head(self) -> None:
        diff = git("diff", "--stat", f"{BOUND_HEAD}", "--", ART)
        self.assertEqual(diff, "")

    def test_allocation_template_zero_spend(self) -> None:
        d = self.allocation
        self.assertEqual(d["status"], "OWNER_AUTHORISED_DESIGN_NOT_BOUND")
        self.assertIsNone(d["binding_receipt"])
        self.assertEqual(d["candidate_attempts"]["used"], 0)
        for stage in ("preflight", "development", "confirmation", "counterfactual"):
            self.assertEqual(d["native_starts"][stage]["used"], 0, stage)
        self.assertEqual(d["usage"]["cpu_seconds"], 0)
        self.assertEqual(d["new_game_outcomes_in_this_planner_pass"], 0)

    def test_handoff_names_binding_review_and_delivery(self) -> None:
        for pointer in POINTERS:
            self.assertIn(pointer, self.handoff)
        self.assertIn(BOUND_HEAD, self.handoff)
        self.assertIn("ADAPTER_RECORDS.md", self.handoff)
        self.assertNotIn("PROPOSED, NOT BOUND", self.handoff)

    def test_five_products_and_exact_locators(self) -> None:
        for heading in SECTIONS:
            self.assertIn(heading, self.entry, heading)
        for locator in LOCATORS:
            self.assertIn(locator, self.entry, locator)
        for pointer in POINTERS:
            self.assertIn(pointer, self.entry)

    def test_k3_gap_not_invented_package(self) -> None:
        text = self.entry
        self.assertIn("K3 — DISPOSITION `duskblade/cycle` is **not** substantiated on shipping", text)
        self.assertIn("K3 is not invented", text)
        self.assertIn("there is no eligible same-product three-package set in permitted source", text)
        self.assertNotIn("K3 = Afterimage", text)
        self.assertNotIn("K3 = Bloodfire", text)
        self.assertNotIn("K3 = Hand", text)

    def test_balance_sim_is_not_live_profile(self) -> None:
        text = self.entry
        self.assertIn("`tools/balance_sim.gd` is not live `P_v`", text)
        self.assertIn("mature-three-act-no-side-state-v1", text)
        self.assertIn("The signed control is unchanged in this batch", text)
        self.assertIn("Do not change the signed control", text)
        sim = git("show", "HEAD:tools/balance_sim.gd") if _head_has_sim() else (
            ROOT / "tools/balance_sim.gd"
        ).read_text()
        self.assertIn('PROFILE: String = "mature-three-act-no-side-state-v1"', sim)
        self.assertIn("reveals", sim)
        self.assertIn('unlocks": ["aspect2"]', sim)

    def test_certificate_count_and_no_spend_claims(self) -> None:
        self.assertIn("0/3 Duskblade", self.entry)
        self.assertIn("No closed R1–R14 panel is rerun", self.entry)
        self.assertIn("R11", self.entry)
        self.assertIn("SUMMARY_ONLY", self.entry)
        self.assertIn("R12", self.entry)
        self.assertIn("INCOMPLETE", self.entry)


def _head_has_sim() -> bool:
    try:
        git("rev-parse", "HEAD:tools/balance_sim.gd")
        return True
    except subprocess.CalledProcessError:
        return False


if __name__ == "__main__":
    unittest.main(verbosity=2)
