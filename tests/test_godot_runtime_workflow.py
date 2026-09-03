#!/usr/bin/env python3
"""Static regressions for the bounded Godot workflow ingress."""
from __future__ import annotations

import json
import hashlib
import importlib.util
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CAMPAIGN_PATH = ROOT / "tools/execution_provenance/godot_runtime_campaign.py"
SPEC = importlib.util.spec_from_file_location("godot_runtime_campaign_workflow", CAMPAIGN_PATH)
assert SPEC and SPEC.loader
campaign = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(campaign)
WORKFLOW = (ROOT / ".github/workflows/execution-provenance-evidence.yml").read_text(
    encoding="utf-8")
PROFILE = json.loads((ROOT / "tools/execution_provenance/godot_runtime_profile.json").read_text(
    encoding="utf-8"))


class GodotRuntimeWorkflowTests(unittest.TestCase):
    def test_remote_budget_listing_fails_closed_before_mapfile(self) -> None:
        self.assertNotIn("mapfile -t runs < <(gh api", WORKFLOW)
        self.assertNotIn("mapfile -t jobs < <(gh api", WORKFLOW)
        self.assertIn('> "$runs_file"\n          mapfile -t runs < "$runs_file"', WORKFLOW)
        self.assertIn('> "$jobs_file"\n            mapfile -t jobs < "$jobs_file"', WORKFLOW)
        self.assertIn('test "$attempts" -le "$max_attempts"', WORKFLOW)

    def test_qualification_and_a1_have_distinct_non_cancelling_slots(self) -> None:
        self.assertIn("inputs.mode == 'godot-runtime-a1' && 'godot-runtime-a1'", WORKFLOW)
        self.assertIn(
            "cancel-in-progress: ${{ inputs.mode != 'godot-runtime' && "
            "inputs.mode != 'godot-runtime-a1' }}", WORKFLOW)
        self.assertIn("Qualify actual Godot runtime profile", WORKFLOW)
        self.assertIn("Execute admitted A1 Godot packet", WORKFLOW)
        runtime_header = WORKFLOW.split("\n  godot-runtime:\n", 1)[1].split("\n    steps:\n", 1)[0]
        self.assertIn("timeout-minutes: 15", runtime_header)

    def test_execution_authorities_and_request_index_are_frozen(self) -> None:
        self.assertEqual(
            (535, 5524343289),
            (PROFILE["packetIngress"]["qualification"]["authorityIssue"],
             PROFILE["packetIngress"]["qualification"]["authorityComment"]),
        )
        self.assertEqual(
            (421, 5524340839),
            (PROFILE["packetIngress"]["research"]["authorityIssue"],
             PROFILE["packetIngress"]["research"]["authorityComment"]),
        )
        self.assertIn('request_index not in manifest["requestIndices"]', WORKFLOW)

    def test_a1_requires_exact_main_capability_artifact(self) -> None:
        for required in (
                'test "$GITHUB_REF_NAME" = main',
                'test "$(git rev-parse HEAD)" = "$PRODUCT_SHA"',
                'repos/$GITHUB_REPOSITORY/issues/535/comments',
                'run.get("head_branch") != "main"',
                'artifact_name="godot-runtime-${PRODUCT_SHA}-${run_attempt}"',
                '--name "$artifact_name"',
                "campaign.validate_capability_receipt",
                "--capability-prerequisite",
                "--admit-only"):
            self.assertIn(required, WORKFLOW)

    def test_copied_receipt_hash_cannot_authorise_changed_content(self) -> None:
        payload = {
            "schema": campaign.CAPABILITY_CAMPAIGN_SCHEMA,
            "verdict": "PASS", "receipts": [],
        }
        expected = hashlib.sha256(campaign.canonical_bytes(payload) + b"\n").hexdigest()
        with tempfile.TemporaryDirectory(prefix="godot-capability-") as temporary:
            path = Path(temporary) / "campaign-receipt.json"
            campaign.write_json(path, {**payload, "receiptSha256": expected})
            campaign.validate_capability_receipt(path, expected)
            campaign.write_json(path, {
                **payload, "receipts": [{"forged": True}], "receiptSha256": expected,
            })
            with self.assertRaisesRegex(campaign.CampaignError, "content hash differs"):
                campaign.validate_capability_receipt(path, expected)

    def test_focused_regressions_include_trace_binding(self) -> None:
        self.assertIn("python3 -B tests/test_godot_runtime_trace_binding.py", WORKFLOW)


if __name__ == "__main__":
    unittest.main()
