#!/usr/bin/env python3
"""Focused fixtures for the scope-aware CI selection contract."""
from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("ci_scope", ROOT / "tools/ci_scope.py")
assert SPEC and SPEC.loader
CI = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = CI
SPEC.loader.exec_module(CI)
WORKFLOW = ROOT / ".github/workflows/ci.yml"


class ScopeFixtureTests(unittest.TestCase):
    def assert_scopes(self, selection: CI.Selection, *selected: str) -> None:
        expected = set(selected)
        actual = {name for name, value in selection.scopes.items() if value}
        self.assertEqual(expected, actual)

    def test_docs_only(self) -> None:
        selection = CI.classify_paths(["docs/ci-governance.md"])
        self.assert_scopes(selection, "docs")
        self.assertTrue(selection.checks["run_doc_anchors"])
        self.assertTrue(selection.checks["run_benchmark_freeze"])
        self.assertFalse(selection.checks["run_import_assets"])
        self.assertFalse(selection.checks["run_godot_tests"])
        self.assertFalse(selection.checks["run_map_assets"])

    def test_map_gdscript_and_map_test(self) -> None:
        paths = ["presentation/map/map_scene.gd", "tests/test_map_scene.gd"]
        selection = CI.classify_paths(paths)
        self.assert_scopes(selection, "godot_code", "map_code", "presentation")
        self.assertEqual(tuple(sorted(paths)), selection.changed_gdscripts)
        for check in ("run_gdscript_parse", "run_godot_tests", "run_map_quality",
                      "run_map_profiles", "run_performance_evidence"):
            self.assertTrue(selection.checks[check], check)
        for check in ("run_map_assets", "run_balance_doe", "run_locale_font"):
            self.assertFalse(selection.checks[check], check)

    def test_map_glb_and_manifest(self) -> None:
        selection = CI.classify_paths([
            "assets/art/map/geometry/act1/new-module.glb",
            "assets/art/map/map-assets.json",
        ])
        self.assert_scopes(selection, "map_assets")
        self.assertTrue(selection.checks["run_map_assets"])
        self.assertTrue(selection.checks["run_map_profiles"])
        self.assertTrue(selection.checks["run_import_assets"])
        self.assertFalse(selection.checks["run_map_quality"])
        self.assertFalse(selection.checks["run_balance_doe"])
        self.assertFalse(selection.checks["run_locale_font"])

    def test_balance_ml_only(self) -> None:
        selection = CI.classify_paths(["tools/balance_f1_f2.py"])
        self.assert_scopes(selection, "balance_ml")
        for check in ("run_balance_doe", "run_balance_seed", "run_balance_s009",
                      "run_balance_registry", "run_balance_host", "run_balance_f0",
                      "run_balance_tier1_f0", "run_balance_f1_f2"):
            self.assertTrue(selection.checks[check], check)
        self.assertFalse(selection.checks["run_import_assets"])

    def test_locale_and_font_only(self) -> None:
        selection = CI.classify_paths([
            "locale/zh-Hant.json", "assets/fonts/NotoSerifTC-Regular.woff2"])
        self.assert_scopes(selection, "locale_content")
        self.assertTrue(selection.checks["run_locale_font"])
        self.assertTrue(selection.checks["run_locale_coverage"])
        self.assertTrue(selection.checks["run_godot_tests"])
        self.assertFalse(selection.checks["run_balance_doe"])

    def test_release_platform_only(self) -> None:
        selection = CI.classify_paths([
            "export_presets.cfg", "scripts/store_signing_wizard.sh"])
        self.assert_scopes(selection, "release_platform")
        for check in ("run_store_exclusion", "run_store_gate_tests",
                      "run_performance_evidence", "run_choice_scroll",
                      "run_boss_relic", "run_dawn_containment", "run_hud_location"):
            self.assertTrue(selection.checks[check], check)
        self.assertFalse(selection.checks["run_balance_doe"])

    def test_mixed_change_unions_scopes_and_checks(self) -> None:
        selection = CI.classify_paths([
            "README.md", "domain/map_layout/map_layout_input.gd", "locale/en.json"])
        self.assert_scopes(selection, "docs", "godot_code", "map_code", "locale_content")
        for check in ("run_doc_anchors", "run_gdscript_parse", "run_godot_tests",
                      "run_map_quality", "run_map_profiles", "run_locale_font"):
            self.assertTrue(selection.checks[check], check)
        self.assertFalse(selection.checks["run_map_assets"])

    def test_unknown_production_path_selects_conservative_core(self) -> None:
        selection = CI.classify_paths(["application/runtime_contract.json"])
        self.assert_scopes(selection, "conservative_core")
        self.assertTrue(selection.checks["run_import_assets"])
        self.assertTrue(selection.checks["run_godot_tests"])
        self.assertFalse(selection.checks["run_map_assets"])

    def test_ci_authority_change_fails_closed_to_every_check(self) -> None:
        selection = CI.classify_paths([".github/workflows/ci.yml"])
        self.assert_scopes(selection, "ci_infra")
        self.assertFalse(selection.checks["run_gdscript_parse"])
        self.assertTrue(all(value for key, value in selection.checks.items()
                            if key != "run_gdscript_parse"))

    def test_deleted_gdscript_is_not_parsed_but_keeps_godot_scope(self) -> None:
        path = "domain/removed.gd"
        selection = CI.classify_paths([path], present_paths=[])
        self.assert_scopes(selection, "godot_code")
        self.assertEqual((), selection.changed_gdscripts)
        self.assertFalse(selection.checks["run_gdscript_parse"])
        self.assertTrue(selection.checks["run_godot_tests"])

    def test_empty_and_malformed_inputs_fail_closed(self) -> None:
        for paths in ([], [""], ["/absolute"], ["../escape"], ["a\n.md"],
                      ["same.md", "same.md"]):
            with self.subTest(paths=paths), self.assertRaises(CI.ScopeInputError):
                CI.classify_paths(paths)
        with self.assertRaises(CI.ScopeInputError):
            CI.classify_paths("README.md")

    def test_nul_input_requires_content_terminator_and_utf8(self) -> None:
        with tempfile.TemporaryDirectory(prefix="glassvow-ci-scope-") as directory:
            fixture = Path(directory) / "paths"
            for payload in (b"", b"README.md", b"README.md\0\xff\0"):
                fixture.write_bytes(payload)
                with self.subTest(payload=payload), self.assertRaises(CI.ScopeInputError):
                    CI.read_nul_paths(fixture)
            fixture.write_bytes(b"README.md\0docs/rc-bar.md\0")
            self.assertEqual(("README.md", "docs/rc-bar.md"), CI.read_nul_paths(fixture))

    def test_summary_audits_every_scope_and_check(self) -> None:
        summary = CI.render_summary(CI.classify_paths(["README.md"]))
        for scope in CI.SCOPE_NAMES:
            self.assertIn(f"`{scope}`", summary)
        for check in CI.CHECKS:
            self.assertIn(check.label, summary)
        self.assertIn("**SELECTED**", summary)
        self.assertIn("**SKIPPED**", summary)

    def test_full_main_manual_selection_runs_every_check(self) -> None:
        selection = CI.full_selection()
        self.assertTrue(selection.full_gate)
        self.assertTrue(all(selection.scopes.values()))
        self.assertTrue(all(selection.checks.values()))


class WorkflowContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.workflow = WORKFLOW.read_text(encoding="utf-8")

    def test_only_main_push_pull_request_and_manual_dispatch_trigger(self) -> None:
        self.assertIn("  pull_request:\n", self.workflow)
        self.assertIn("  push:\n    branches: [main]\n", self.workflow)
        self.assertIn("  workflow_dispatch:\n", self.workflow)
        self.assertNotIn("  push:\n  pull_request:", self.workflow)

    def test_superseded_pr_runs_cancel_in_one_stable_group(self) -> None:
        self.assertIn(
            "group: ci-${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}",
            self.workflow)
        self.assertIn("cancel-in-progress: true", self.workflow)

    def test_pr_diff_is_merge_base_scoped_and_classifier_is_fail_closed(self) -> None:
        self.assertIn('git diff --name-only --no-renames -z "$BASE_SHA...$HEAD_SHA"',
                      self.workflow)
        self.assertIn("--changed-paths-nul", self.workflow)
        self.assertIn("--full-gate", self.workflow)
        self.assertIn("tools/check_scripts.sh \"${scripts[@]}\"", self.workflow)

    def test_every_selection_output_controls_its_workflow_step(self) -> None:
        for check in CI.CHECKS:
            self.assertIn(f"- name: {check.label}\n", self.workflow)
            if not check.always:
                self.assertIn(
                    f"if: steps.scope.outputs.{check.key} == 'true'", self.workflow)

    def test_pre_change_full_gate_commands_remain_present(self) -> None:
        commands = (
            "tools/check_imports.sh",
            "tools/test_check_imports.sh",
            "tools/check_scripts.sh",
            "tools/test_check_scripts.sh",
            "tools/check_locale_font_coverage.py",
            "tools/check_locale_coverage.py --self-test",
            "tools/check_locale_coverage.py",
            "tools/check_store_dev_exclusion.py",
            "tools/test_check_store_dev_exclusion.sh",
            "tools/dev.py --check",
            "tools/balance_content_doe.py --self-test",
            "tools/balance_seed_contract.py --self-test",
            "tools/balance_s009_reconstruct.py --self-test",
            "tests/test_balance_tier1_design.py",
            "tools/balance_host_qualify.py --self-test",
            "tools/balance_f0.py --self-test",
            "tests/test_balance_tier1_f0.py",
            "tests/test_balance_f1_f2.py",
            "tests/test_balance_f1_evidence.py",
            "tools/check_anchors.py",
            "tools/check_benchmark_freeze.py",
            "tools/check_map_assets.py --self-test",
            "tools/land_map_glb.py --self-test",
            "tools/check_map_assets.py",
            "tools/check_map_quality_v2.py --self-test",
            "tools/check_map_quality_v2.py",
            "tests/test_performance_budget.py",
            "res://tests/run_all.gd",
            "res://tools/probe_map_seeds.gd -- --seeds=20",
            "res://tests/choice_scroll_reachability.gd",
            "res://tests/boss_relic_choice_containment.gd",
            "res://tests/dawn_phone_containment.gd",
            "res://tests/measure_hud_location.gd",
        )
        for command in commands:
            self.assertIn(command, self.workflow, command)


if __name__ == "__main__":
    unittest.main()
