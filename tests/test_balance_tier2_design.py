#!/usr/bin/env python3
"""Public-seam tests for issue #508's Tier-2 disruption factorial."""
from __future__ import annotations
import hashlib, json, sys, tempfile, unittest
from copy import deepcopy
from pathlib import Path
REPO = Path(__file__).resolve().parents[1]; sys.path.insert(0, str(REPO / "tools"))
from balance_s009_reconstruct import reconstruct  # noqa: E402
from balance_tier2_design import compile_design, generate_bundle, validate_bundle  # noqa: E402
class BalanceTier2DesignTest(unittest.TestCase):
    def test_complete_factorial_is_deterministic_and_non_destructive(self) -> None:
        live = {path: (REPO / path).read_bytes() for path in (
            "content/full-content.json", "content/mob-overrides.json", "locale/en.json", "locale/zh-Hant.json")}
        first, _ = compile_design(REPO); second, _ = compile_design(REPO)
        self.assertEqual(first, second); self.assertNotIn(str(REPO), json.dumps(first))
        self.assertEqual([f"t2-c{i:03d}" for i in range(81)], [row["id"] for row in first["candidates"]]); self.assertEqual(81, len({tuple(row["vector"].values()) for row in first["candidates"]}))
        self.assertEqual(81, len({row["effectiveCatalogueSemanticSha256"] for row in first["candidates"]})); baseline = first["candidates"][0]
        self.assertTrue(baseline["baseline"]); self.assertEqual({}, baseline["mobOverrides"])
        self.assertEqual({key: "baseline" for key in first["design"]["knobOrder"]}, baseline["vector"]); self.assertTrue(all(row["vector"] == row["backMappedVector"] for row in first["candidates"]))
        with tempfile.TemporaryDirectory(prefix="glassvow-tier2-") as temp:
            left, right = Path(temp) / "left", Path(temp) / "right"
            generated = generate_bundle(REPO, left); generate_bundle(REPO, right)
            files = lambda root: {p.relative_to(root): p.read_bytes() for p in root.rglob("*") if p.is_file()}
            self.assertEqual(files(left), files(right))
            record = generated["candidates"][1]; directory = left / record["id"]
            expected = [record["contentIdentity"]["fileSha256"], record["mobOverrideIdentity"]["fileSha256"], record["candidateFileSha256"], generated["registryIdentity"]["fileSha256"]]
            actual = [hashlib.sha256((directory / name).read_bytes()).hexdigest() for name in ("full-content.json", "mob-overrides.json", "candidate.json")]
            self.assertEqual(expected, actual + [hashlib.sha256((REPO / "docs/balance/421-mob-disruption-space-v1.json").read_bytes()).hexdigest()])
            canonical = lambda path: hashlib.sha256(json.dumps(json.loads(path.read_text()), ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
            self.assertEqual([record["contentIdentity"]["semanticSha256"], record["mobOverrideIdentity"]["semanticSha256"], record["candidateSemanticSha256"], generated["registryIdentity"]["semanticSha256"]], [canonical(directory / name) for name in ("full-content.json", "mob-overrides.json", "candidate.json")] + [canonical(REPO / "docs/balance/421-mob-disruption-space-v1.json")])
            self.assertEqual(reconstruct(REPO)["blob"], (left / "t2-c000/full-content.json").read_bytes())
            self.assertEqual((REPO / "content/mob-overrides.json").read_bytes(), (left / "t2-c000/mob-overrides.json").read_bytes())
        self.assertEqual(live, {path: (REPO / path).read_bytes() for path in live})
    def test_registry_and_complete_overrides_fail_closed(self) -> None:
        registry = json.loads((REPO / "docs/balance/421-mob-disruption-space-v1.json").read_text())
        mutations = [
            lambda row: row.__setitem__("fixed", {}),
            lambda row: row["knobs"][0]["writes"][0]["values"].__setitem__("high", 1.5),
            lambda row: row["knobs"][0]["writes"][0].__setitem__("path", "/enemies/gravewarden/name"),
            lambda row: row["knobs"][1]["writes"].append(deepcopy(row["knobs"][0]["writes"][0])),
            lambda row: row.__setitem__("responseContractFileSha256", "0" * 64),
            lambda row: row["selection"]["disruptionPair"][0]["disruptionMoves"][0].__setitem__("id", "missing"),
        ]
        with tempfile.TemporaryDirectory(prefix="glassvow-tier2-invalid-") as temp:
            for index, mutate in enumerate(mutations):
                bad = deepcopy(registry); mutate(bad); path = Path(temp) / f"registry-{index}.json"
                path.write_text(json.dumps(bad))
                with self.subTest(registry=index), self.assertRaises(ValueError):
                    compile_design(REPO, registry_path=path)
            out = Path(temp) / "bundle"; generate_bundle(REPO, out)
            path = out / "t2-c001/mob-overrides.json"; original = json.loads(path.read_text())
            cases = []
            bad = deepcopy(original); bad["waylayer"]["name"] = "Changed"; cases.append(bad); bad = deepcopy(original); bad["waylayer"]["moves"]["renamed"] = bad["waylayer"]["moves"].pop("stab"); cases.append(bad)
            bad = deepcopy(original); bad["waylayer"] = {"hp": [1, 1]}; cases.append(bad)
            bad = deepcopy(original); bad["waylayer"]["hp"] = [40, 20]; cases.append(bad)
            for index, bad in enumerate(cases):
                path.write_text(json.dumps(bad) + "\n")
                with self.subTest(override=index), self.assertRaises(RuntimeError): validate_bundle(REPO, out)
            path.write_text(json.dumps(original, ensure_ascii=False, indent=2) + "\n")
            validate_bundle(REPO, out)
if __name__ == "__main__": unittest.main()
