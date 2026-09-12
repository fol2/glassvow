#!/usr/bin/env python3
"""Public-seam tests for the issue #490 Tier-1 design registry."""
from __future__ import annotations
import json, sys, tempfile, unittest
from copy import deepcopy
from pathlib import Path
REPO = Path(__file__).resolve().parents[1]; sys.path.insert(0, str(REPO / "tools"))
from balance_s009_reconstruct import reconstruct  # noqa: E402
from balance_tier1_design import compile_design, generate_bundle, replay_patches  # noqa: E402
class BalanceTier1DesignTest(unittest.TestCase):
    def test_design_and_fail_closed_bundle(self) -> None:
        first, _ = compile_design(REPO); second, _ = compile_design(REPO); changed, _ = compile_design(REPO, seed=491)
        self.assertEqual(first, second); self.assertNotEqual(first["candidates"][17:], changed["candidates"][17:])
        self.assertEqual([f"t1-c{i:03d}" for i in range(48)], [row["id"] for row in first["candidates"]])
        self.assertTrue(first["candidates"][0]["baseline"]); self.assertEqual(first["candidates"][0]["fileSha256"], first["candidates"][0]["files"]["content/full-content.json"]["fileSha256"]); self.assertEqual(first["registryIdentity"]["fileSha256"], first["candidates"][0]["searchSpaceSha256"]); self.assertEqual(16, first["design"]["mainEffectAnchors"]); self.assertEqual(16, sum(sum(value != "s009" for value in row["values"].values()) == 1 for row in first["candidates"][1:17]))
        self.assertEqual(252, first["design"]["pairwiseLevelCoverage"]["observed"]); self.assertEqual(48, first["design"]["uniqueVectors"])
        self.assertTrue(all(max(counts.values()) - min(counts.values()) <= 1 for counts in first["design"]["marginalCounts"].values()))
        with tempfile.TemporaryDirectory(prefix="glassvow-tier1-") as temp:
            out = Path(temp) / "bundle"; other = Path(temp) / "bundle-copy"; generated = generate_bundle(REPO, out); generate_bundle(REPO, other)
            self.assertEqual({p.relative_to(out): p.read_bytes() for p in out.rglob("*") if p.is_file()}, {p.relative_to(other): p.read_bytes() for p in other.rglob("*") if p.is_file()})
            self.assertEqual(reconstruct(REPO)["blob"], (out / "t1-c000/full-content.json").read_bytes())
            packet = json.loads((out / "t1-c047/hydration-patches.json").read_text())
            for relative, target in packet["files"].items():
                replayed = replay_patches(json.loads((REPO / relative).read_text()), target["patch"])
                self.assertEqual(target["semanticSha256"], generated["candidates"][47]["files"][relative]["semanticSha256"])
                self.assertEqual(target["semanticSha256"], target["replaySemanticSha256"]); self.assertEqual(target["fileSha256"], target["replayFileSha256"]); self.assertIsInstance(replayed, dict)
        with tempfile.TemporaryDirectory(prefix="glassvow-tier1-unsafe-") as temp:
            unsafe = Path(temp) / "bundle"; unsafe.mkdir(); (unsafe / "keep").write_text("sentinel")
            with self.assertRaisesRegex(ValueError, "unmarked"): generate_bundle(REPO, unsafe, force=True)
            self.assertEqual("sentinel", (unsafe / "keep").read_text())
        registry = json.loads((REPO / "docs/balance/490-tier1-registry-v1.json").read_text()); cases = []
        for mutate in (lambda row: row["features"][0]["writes"][0]["values"].__setitem__(2, 7.5), lambda row: row["features"][4]["writes"][2]["values"].__setitem__(2, -1), lambda row: row["features"][0]["writes"][0]["values"].__setitem__(0, -1), lambda row: row["features"][6]["writes"][0].__setitem__("fallback", 3.5), lambda row: (row["features"][0]["hydration"][0]["en"][2].reverse(), row["features"][0]["hydration"][0]["zhHant"][2].reverse()), lambda row: (row["features"][0]["hydration"][1]["en"][2].__setitem__(0, "Deal @2@ damage. Apply 9 Cracked."), row["features"][0]["hydration"][1]["zhHant"][2].__setitem__(0, "造成 @2@ 點傷害。施加 9 層裂痕。")), lambda row: (row["features"][0]["hydration"][0]["en"][2].__setitem__(0, row["features"][0]["hydration"][0]["en"][2][0] + " 99"), row["features"][0]["hydration"][0]["zhHant"][2].__setitem__(0, row["features"][0]["hydration"][0]["zhHant"][2][0] + " 99")), lambda row: row.__setitem__("responseContractFileSha256", "0" * 64)):
            bad = deepcopy(registry); mutate(bad); cases.append(bad)
        with tempfile.TemporaryDirectory(prefix="glassvow-tier1-invalid-") as temp:
            for index, bad in enumerate(cases):
                path = Path(temp) / f"registry-{index}.json"; path.write_text(json.dumps(bad))
                with self.subTest(case=index), self.assertRaises(ValueError): compile_design(REPO, registry_path=path)
if __name__ == "__main__": unittest.main()
