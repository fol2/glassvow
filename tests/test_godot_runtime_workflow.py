#!/usr/bin/env python3
"""Static regressions for the bounded Godot workflow ingress."""
from __future__ import annotations

import json
import hashlib
import importlib.util
import subprocess
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
    def test_packet_boundary_exposes_outside_to_inside_rename(self) -> None:
        self.assertEqual(3, WORKFLOW.count("git diff --no-renames --name-only"))
        self.assertNotIn("git diff --name-only", WORKFLOW)
        with tempfile.TemporaryDirectory(prefix="godot-packet-rename-") as temporary:
            repository = Path(temporary)
            subprocess.run(["git", "init", "-q"], cwd=repository, check=True)
            subprocess.run(
                ["git", "config", "diff.renames", "true"],
                cwd=repository, check=True)
            outside = repository / "outside.gd"
            outside.write_text("extends SceneTree\n", encoding="utf-8")
            subprocess.run(["git", "add", "."], cwd=repository, check=True)
            subprocess.run([
                "git", "-c", "user.name=Test", "-c",
                "user.email=test@example.invalid", "commit", "-qm", "base",
            ], cwd=repository, check=True)
            base = subprocess.run(
                ["git", "rev-parse", "HEAD"], cwd=repository, check=True,
                capture_output=True, text=True).stdout.strip()
            packet_root = "research_packets/issue-421-a1-v2-g0"
            destination = repository / packet_root / "oracle.gd"
            destination.parent.mkdir(parents=True)
            subprocess.run(
                ["git", "mv", str(outside), str(destination)],
                cwd=repository, check=True)
            subprocess.run([
                "git", "-c", "user.name=Test", "-c",
                "user.email=test@example.invalid", "commit", "-qm", "packet",
            ], cwd=repository, check=True)
            head = subprocess.run(
                ["git", "rev-parse", "HEAD"], cwd=repository, check=True,
                capture_output=True, text=True).stdout.strip()
            rename_detected = subprocess.run([
                "git", "diff", "--name-only", "-z", base, head, "--", ".",
            ], cwd=repository, check=True, capture_output=True).stdout.split(b"\0")
            self.assertEqual(
                {f"{packet_root}/oracle.gd"},
                {path.decode("utf-8") for path in rename_detected if path})
            changed = subprocess.run([
                "git", "diff", "--no-renames", "--name-only", "-z",
                base, head, "--", ".",
            ], cwd=repository, check=True, capture_output=True).stdout.split(b"\0")
            paths = {path.decode("utf-8") for path in changed if path}
            self.assertEqual({"outside.gd", f"{packet_root}/oracle.gd"}, paths)
            self.assertTrue(any(
                not path.startswith(f"{packet_root}/") for path in paths))

    def test_remote_budget_listing_fails_closed_before_mapfile(self) -> None:
        budget = WORKFLOW.split(
            "      - name: Reserve finite remote qualification budget\n", 1
        )[1].split("\n      - name:", 1)[0]
        self.assertNotIn("mapfile -t runs < <(gh api", WORKFLOW)
        self.assertNotIn("mapfile -t jobs < <(gh api", WORKFLOW)
        self.assertIn('> "$runs_file"\n          mapfile -t runs < "$runs_file"', WORKFLOW)
        self.assertIn('> "$jobs_file"\n            mapfile -t jobs < "$jobs_file"', WORKFLOW)
        self.assertIn('test "$attempts" -le "$max_attempts"', WORKFLOW)
        self.assertIn('caps["budgetEpochComment"]', budget)
        self.assertIn(
            'repos/$GITHUB_REPOSITORY/issues/comments/$budget_epoch_comment',
            budget,
        )
        self.assertIn(".created_at", budget)
        self.assertIn(".started_at", budget)
        self.assertIn('iso_second() {', budget)
        self.assertIn('([.][0-9]+)?Z$', budget)
        self.assertIn('"$job_started_at" < "$epoch_created_at"', budget)
        self.assertNotIn(
            '| "\\(.id):\\(.run_attempt)"',
            budget,
        )
        self.assertNotIn('attempts=$((attempts + ${#jobs[@]}))', budget)

    def test_budget_epoch_is_frozen_to_the_owner_authority(self) -> None:
        caps = PROFILE["caps"]
        self.assertEqual(5535398605, caps["budgetEpochComment"])
        self.assertEqual(PROFILE["authority"]["comment"], caps["budgetEpochComment"])
        self.assertEqual((8, 120, 15), (
            caps["maxQualificationAttempts"], caps["maxHostedMinutes"],
            caps["maxMinutesPerQualificationAttempt"],
        ))

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
            (535, 5535398605),
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

    def test_runtime_environment_records_cpu_auxv_and_glibc_hwcaps(self) -> None:
        runtime = WORKFLOW.split("\n  godot-runtime:\n", 1)[1].split(
            "\n  cleanup-a1-packet-ref:\n", 1)[0]
        environment = runtime.split(
            "      - name: Install and identify exact Godot 4.7.2\n", 1
        )[1].split("\n      - name:", 1)[0]
        for required in (
                "/proc/cpuinfo", "model name", "flags",
                "LD_SHOW_AUXV=1 /bin/true",
                "/usr/lib/x86_64-linux-gnu/glibc-hwcaps"):
            self.assertIn(required, environment)

    def test_g0_diagnostic_captures_every_path_operation_from_raw_trace(self) -> None:
        g0 = WORKFLOW.split("\n  godot-g0:\n", 1)[1].split(
            "\n  godot-runtime:\n", 1)[0]
        required = (
            "python3 -B tools/execution_provenance/godot_runtime_g0_trace.py",
            "--trace-directory artifacts/godot-g0/raw",
            '--working-directory "$GITHUB_WORKSPACE"',
            '--root "PRODUCT=$RUNNER_TEMP/g0-product"',
            '--root "PACKET=$RUNNER_TEMP/g0-packet/${{ inputs.packet_root }}"',
            '--root "GODOT=$RUNNER_TEMP/godot/godot"',
            '--root "HOME=$RUNNER_TEMP/g0-runtime-home"',
            '--root "OUTPUT=$GITHUB_WORKSPACE/artifacts/godot-g0/run"',
            "--output artifacts/godot-g0/path-operation-closure.json",
        )
        for value in required:
            self.assertIn(value, g0)
        self.assertLess(
            g0.index(required[0]),
            g0.index("Upload non-authoritative G0 diagnostics"),
        )

    def test_campaign_hashes_runtime_identities_before_godot_cases(self) -> None:
        source = CAMPAIGN_PATH.read_text(encoding="utf-8")
        self.assertLess(
            source.index("evaluate_venue_eligibility"),
            source.index("runner.run_case"),
        )
        self.assertIn("venue-eligibility.json", source)
        self.assertIn("RUNTIME_DEPENDENCY_MISMATCH: venue identity differs", source)

    def test_venue_eligibility_uses_bytes_not_image_label(self) -> None:
        with tempfile.TemporaryDirectory(prefix="godot-venue-") as temporary:
            root = Path(temporary)
            godot = root / "godot"
            product = root / "product"
            product.mkdir()
            payload = b"runtime-bytes"
            godot.write_bytes(payload)
            digest = hashlib.sha256(payload).hexdigest()
            identities = [{
                "path": "${GODOT}", "size": len(payload), "sha256": digest,
            }]
            eligible = campaign.evaluate_venue_eligibility(
                identities, godot, product, "ubuntu24", "other-image",
                "20260831.293.1")
            self.assertEqual("ELIGIBLE", eligible["verdict"])
            self.assertEqual(0, eligible["mismatchCount"])
            self.assertEqual("other-image", eligible["imageVersion"])
            identities[0]["sha256"] = "0" * 64
            ineligible = campaign.evaluate_venue_eligibility(
                identities, godot, product, "ubuntu24", "20260831.293.1",
                "20260831.293.1")
            self.assertEqual("INELIGIBLE", ineligible["verdict"])
            self.assertEqual(
                "RUNTIME_DEPENDENCY_MISMATCH",
                ineligible["mismatches"][0]["reason"])


if __name__ == "__main__":
    unittest.main()
