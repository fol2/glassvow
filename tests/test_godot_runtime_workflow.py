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

    def test_a1_packet_ref_is_exactly_bound_before_archive_ingress(self) -> None:
        runtime = WORKFLOW.split("\n  godot-runtime:\n", 1)[1].split(
            "\n  cleanup-a1-packet-ref:\n", 1)[0]
        self.assertIn("packet_ref:", WORKFLOW.split("\n  pull_request:\n", 1)[0])
        self.assertIn(
            "Ephemeral A1-v2 packet branch bound to packet_sha",
            WORKFLOW.split("\n  pull_request:\n", 1)[0],
        )
        for required in (
                'test -z "$PACKET_REF"',
                'git ls-remote --refs origin "$PACKET_REF"',
                'test "$packet_ref_sha" = "$PACKET_SHA"',
                'test "$packet_ref_name" = "$PACKET_REF"',
                'git fetch --no-tags origin "$PACKET_REF"',
                'test "$(git rev-parse FETCH_HEAD)" = "$PACKET_SHA"'):
            self.assertIn(required, runtime)
        self.assertLess(
            runtime.index('git ls-remote --refs origin "$PACKET_REF"'),
            runtime.index('git archive --format=tar "$PACKET_SHA" "$PACKET_ROOT"'),
        )

    def test_packet_tree_is_capped_before_archive_and_json_parse(self) -> None:
        tree = 'git ls-tree -r -z -l "$PACKET_SHA" -- "$PACKET_ROOT"'
        archive = 'git archive --format=tar "$PACKET_SHA" "$PACKET_ROOT"'
        parse = "manifest = runner.read_packet_manifest(packet, profile)"
        self.assertIn(tree, WORKFLOW)
        self.assertIn('caps["maxPacketManifestBytes"]', WORKFLOW)
        self.assertLess(WORKFLOW.index(tree), WORKFLOW.index(archive))
        self.assertLess(WORKFLOW.index(archive), WORKFLOW.index(parse))

    def test_packet_ref_cleanup_is_separate_least_privilege_job(self) -> None:
        cleanup = WORKFLOW.split("\n  cleanup-a1-packet-ref:\n", 1)[1]
        header = cleanup.split("\n    steps:\n", 1)[0]
        self.assertIn("needs: godot-runtime", header)
        self.assertIn("actions: read", header)
        self.assertIn("contents: write", header)
        self.assertNotIn("issues: write", header)
        self.assertNotIn("pull-requests: write", header)
        self.assertIn("godot-runtime-a1-cleanup-${{ github.sha }}", cleanup)

    def test_packet_ref_deletion_requires_published_terminal_receipt(self) -> None:
        cleanup = WORKFLOW.split("\n  cleanup-a1-packet-ref:\n", 1)[1]
        receipt_download = cleanup.index('gh run download "$GITHUB_RUN_ID"')
        case_receipt = cleanup.index(
            'case_receipt="$published/admission/cases/G00/receipt.json"')
        receipt_validation = cleanup.index(
            'record.get("verdict") not in {"PASS", "REJECT", "INCONCLUSIVE"}')
        case_binding = cleanup.index(
            'record.get("caseReceiptSha256") != case_claimed')
        self.assertIn('separators=(",", ":")).encode() + b"\\n"', cleanup)
        remote_binding = cleanup.index('git ls-remote --refs origin "$PACKET_REF"')
        deletion = cleanup.index(
            'git push --force-with-lease="$PACKET_REF:$PACKET_SHA"')
        absence = cleanup.index('test ! -s "$packet_ref_rows"')
        self.assertLess(receipt_download, case_receipt)
        self.assertLess(case_receipt, receipt_validation)
        self.assertLess(receipt_validation, case_binding)
        self.assertLess(case_binding, remote_binding)
        self.assertLess(receipt_validation, remote_binding)
        self.assertLess(remote_binding, deletion)
        self.assertLess(deletion, absence)
        self.assertIn(
            '"schema": "glassvow.godot-runtime-provenance.packet-cleanup/v1"',
            cleanup,
        )

    def test_profile_freezes_research_ref_and_cleanup_policy(self) -> None:
        research = PROFILE["packetIngress"]["research"]
        self.assertEqual(
            "refs/heads/p9-packet-421-a1-v2-<lowercase safe token>",
            research["packetRefPattern"],
        )
        rule = research["packetRefRule"]
        self.assertIn("same-repository branch", rule)
        self.assertIn("immediately before fetch", rule)
        self.assertIn("immediately before deletion", rule)

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
