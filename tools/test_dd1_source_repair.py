"""Zero-game controls. Native GDScript tests are separate and UNEXECUTED here."""
from copy import deepcopy
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import dd1_provenance as p
import dd1_synthetic_capture as fixture
import dd1_reservations as r
import dd1_meter_entry as entry

NOW = datetime(2026, 9, 18, tzinfo=timezone.utc)
HERE = Path(__file__).resolve().parents[1]


def account():
    return dict(schema="DD1-N0-RECOVERY-1-ACCOUNT-1", synthetic=True,
        historical=dict(attempt="1/1 consumed", starts_used=1277, starts_cap=8192,
            starts_remaining_arithmetic=6915, spendable=False, cpu_seconds="UNKNOWN",
            elapsed_seconds="UNKNOWN", raw_bytes="UNKNOWN"),
        recovery=dict(id=r.OPERATION, starts_used=2040, starts_cap=r.STARTS_CAP,
            cpu_ns_used=398617197992, cpu_ns_cap=r.CPU_CAP, raw_bytes_used=893139,
            raw_bytes_cap=r.RAW_CAP, executors=1, per_invocation_cpu_seconds=300,
            first_engine_launch_utc=r.FIRST, deadline_utc=r.DEADLINE,
            events=[{"note": "SYNTHETIC copy of immutable historical observations"}]))


class ReservationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name).resolve()
        self.path = self.root / "ACCOUNT.json"
        r.atomic_write(self.path, account())
        self.cmd = [sys.executable, "-c", "print('INERT_ONLY')"]
        self.head, self.receipt = "1" * 40, "2" * 64
        self.calls = []

    def tearDown(self):
        self.tmp.cleanup()

    def unit(self, name="unit-1"):
        return dict(schema="DD1-COMPLETE-UNIT-DEMAND-2", operation=r.OPERATION, scientific_m=r.M,
            overlay_head=self.head, receipt_sha256=self.receipt, account_sha256=r.digest(self.path.read_bytes()),
            argv=self.cmd, unit_id=name, mode="inert_control", contained_starts=1,
            cpu_seconds=4, wall_seconds=5, raw_bytes=1_000_000,
            source_files={"res://inert.py": r.digest(b"inert source")})

    def run_unit(self, unit=None, runner=None):
        unit = unit or self.unit()
        def observe(grant, output):
            self.calls.append(grant)
            persisted = r.read(self.path)
            self.assertEqual(persisted["recovery"]["unit_reservations_v2"][-1]["state"], "RESERVED")
            self.assertEqual(r.totals(persisted, NOW)["starts"], 2042)
            proc = subprocess.run(self.cmd, capture_output=True, timeout=5, check=True)
            (output / "stdout.txt").write_bytes(proc.stdout)
            (output / "stderr.txt").write_bytes(proc.stderr)
            return dict(success=True, environment="INERT_ONLY", stdout=proc.stdout.decode(),
                        raw_observed=len(proc.stdout) + len(proc.stderr))
        return r.reserve_and_run(self.path, unit, command=self.cmd, head=self.head,
            receipt_sha=self.receipt, source_reader=lambda _: b"inert source", authority_check=lambda _: None,
            output=self.root / unit["unit_id"], runner=runner or observe, now=NOW)

    def test_child_sees_full_durable_reservation_and_history_unchanged(self):
        before = r.read(self.path)
        result = self.run_unit()
        after = r.read(self.path)
        self.assertEqual(result["stdout"], "INERT_ONLY\n")
        self.assertFalse(result["n0_accepted"])
        self.assertEqual(after["historical"], before["historical"])
        for key, value in before["recovery"].items():
            self.assertEqual(after["recovery"][key], value)
        self.assertEqual(result["charged"]["starts"], 2)
        self.assertEqual(result["charged"]["cpu_ns"], 4_000_000_000)
        self.assertEqual(result["charged"]["raw_bytes"], 1_000_000)

    def test_starts_cpu_and_cumulative_raw_deny_before_runner(self):
        for field, cap, proposed in (("starts_used", r.STARTS_CAP, 2),
                                    ("cpu_ns_used", r.CPU_CAP, 4_000_000_000),
                                    ("raw_bytes_used", r.RAW_CAP, 1_000_000)):
            with self.subTest(field=field):
                a = account(); a["recovery"][field] = cap - proposed + 1
                r.atomic_write(self.path, a)
                before = self.path.read_bytes()
                with self.assertRaisesRegex(r.ReservationError, "exhausted"):
                    self.run_unit()
                self.assertEqual(self.path.read_bytes(), before)
                self.assertFalse(self.calls)

    def test_failure_and_interrupt_never_refund(self):
        for exc, name in ((RuntimeError("failed"), "failure"), (KeyboardInterrupt(), "interrupt")):
            r.atomic_write(self.path, account())
            def fail(grant, output):
                self.assertEqual(r.totals(r.read(self.path), NOW)["starts"], 2042)
                raise exc
            out = self.run_unit(self.unit(name), fail)
            self.assertFalse(out["success"])
            self.assertEqual(r.totals(r.read(self.path), NOW)["starts"], 2042)
            self.assertEqual(out["charged"]["raw_bytes"], 1_000_000)

    def test_final_write_failure_preserves_initial_reservation(self):
        original, count = r.atomic_write, [0]
        def write(path, value):
            if path == self.path:
                count[0] += 1
                if count[0] == 2:
                    raise OSError("synthetic final fsync failure")
            return original(path, value)
        with patch.object(r, "atomic_write", write):
            with self.assertRaises(OSError):
                self.run_unit(runner=lambda *_: {"success": True})
        self.assertEqual(r.read(self.path)["recovery"]["unit_reservations_v2"][0]["state"], "RESERVED")

    def test_mismatched_caps_identity_source_command_unsafe_limits(self):
        for key, value in (("cpu_seconds", 0), ("cpu_seconds", 301), ("cpu_seconds", True),
            ("contained_starts", -1), ("contained_starts", 2048), ("raw_bytes", 1),
            ("wall_seconds", float("nan")), ("wall_seconds", -1), ("wall_seconds", True),
            ("account_sha256", "0" * 64), ("receipt_sha256", "0" * 64),
            ("overlay_head", "0" * 40), ("argv", ["not-the-command"]),
            ("source_files", {"res://inert.py": "0" * 64}),
            ("source_files", {"res://../escape": r.digest(b"inert source")})):
            with self.subTest(key=key, value=value):
                u = self.unit(); u[key] = value
                with self.assertRaises(r.ReservationError):
                    self.run_unit(u)
        self.assertFalse(self.calls)

    def test_account_reset_historical_credit_and_clock_denied(self):
        for section, field, value in (("historical", "spendable", True),
            ("historical", "starts_used", 0), ("historical", "cpu_seconds", 0),
            ("recovery", "starts_cap", 4096), ("recovery", "starts_used", 0),
            ("recovery", "cpu_ns_used", 0), ("recovery", "raw_bytes_used", 0), ("recovery", "executors", True),
            ("recovery", "deadline_utc", "2026-10-24T17:54:40Z")):
            a = account(); a[section][field] = value
            with self.assertRaises(r.ReservationError):
                r.totals(a, NOW)
        with self.assertRaises(r.ReservationError):
            r.totals(account(), datetime(2026, 9, 25, tzinfo=timezone.utc))

    def test_one_executor_duplicate_unit_and_output_alias(self):
        with r.account_lock(self.path):
            with self.assertRaisesRegex(r.ReservationError, "one executor"):
                self.run_unit()
        self.run_unit(runner=lambda *_: {"success": True})
        with self.assertRaisesRegex(r.ReservationError, "already reserved"):
            self.run_unit()
        self.assertFalse(self.calls)

    def test_existing_output_never_overwritten(self):
        target = self.root / "unit-1"; target.mkdir()
        (target / "protected").write_text("keep")
        before = self.path.read_bytes()
        with self.assertRaisesRegex(r.ReservationError, "output must be new"):
            self.run_unit()
        self.assertEqual(before, self.path.read_bytes())
        self.assertEqual((target / "protected").read_text(), "keep")

    def test_duplicate_json_and_symlink_accounts_reject(self):
        self.path.write_text('{"a":1,"a":2}')
        with self.assertRaises(r.ReservationError):
            r.read(self.path)
        alias = self.root / "alias.json"; alias.symlink_to(self.path)
        with self.assertRaises(r.ReservationError), r.account_lock(alias):
            pass

    def test_native_entry_cannot_spawn_or_spend_with_valid_demands(self):
        # All fake source bytes are explicitly synthetic; test only reaches the
        # entry's external-authority guard, not a claimed native source identity.
        a = account(); a.pop("synthetic")
        r.atomic_write(self.path, a)
        receipt = self.root / "receipt.json"; receipt.write_text("synthetic receipt")
        u = self.unit(); u.update(mode="fixed_ordinary", receipt_sha256=r.digest(receipt.read_bytes()))
        for name in p.REQUIRED_SOURCES:
            f = self.root / name[6:]; f.parent.mkdir(parents=True, exist_ok=True); f.write_bytes(b"inert source")
        u["source_files"] = {name: r.digest(b"inert source") for name in p.REQUIRED_SOURCES}
        before = self.path.read_bytes()
        original_available = r.available
        with patch.object(entry.reservations, "reserve_and_run") as spawn, \
                patch.object(r, "available", side_effect=lambda a, s, c, b: original_available(a, s, c, b, NOW)):
            with self.assertRaisesRegex(entry.BackendBlocked, "missing H host-authenticated exact execution demand"):
                entry.run_complete_unit(self.cmd, unit=u, account_path=self.path, receipt_path=receipt,
                    output=self.root / "never", head=self.head, repo=self.root, authority_check=lambda _: None)
            spawn.assert_not_called()
        self.assertEqual(before, self.path.read_bytes())
        self.assertFalse((self.root / "never").exists())


class ProvenanceTests(unittest.TestCase):
    def setUp(self):
        self.bundle, self.source = fixture.bundle()

    def reject(self):
        with self.assertRaises((p.CaptureError, TypeError, KeyError)):
            p.inspect_sequence(self.bundle, self.source)

    def test_constructed_complete_fixture_is_structural_only(self):
        report = p.inspect_sequence(self.bundle, self.source)
        self.assertTrue(report["both_profiles"])
        self.assertFalse(report["n0_accepted"])
        self.assertEqual(p.evaluate_witness({"approved": True, "sha256": p.sha(fixture.text(self.bundle))})["result"], "BLOCKED")

    def test_unearned_unrelated_and_wrong_first_profiles_reject(self):
        self.bundle["profiles"]["p0"] = deepcopy(self.bundle["profiles"]["p5"])
        self.reject()
        self.bundle, self.source = fixture.bundle()
        self.bundle["traces"][0]["initial_vigil"] = self.bundle["traces"][4]["commit_vigil"]
        self.reject()

    def test_wrong_root_vow_source_or_policy_reject(self):
        for target in ("seed", "vow", "source", "pilot"):
            self.bundle, self.source = fixture.bundle()
            row = self.bundle["traces"][0]
            if target in ("seed", "vow"):
                row[target] += 1
            elif target == "source":
                self.source["files"][next(iter(p.REQUIRED_SOURCES))] = "0" * 64
            else:
                self.source["pilot"]["random_play"] = True
            self.reject()

    def test_missing_preterminal_clear_receipt_or_dawn_reject(self):
        for target in ("pre_terminal_run", "run_cleared", "receipt", "cursor"):
            self.bundle, self.source = fixture.bundle(); row = self.bundle["traces"][0]
            if target == "pre_terminal_run":
                row[target] = ""
            elif target == "cursor":
                end = next(e for e in row["capture"]["rows"] if e.get("observed", {}).get("before_bytes"))
                raw = p.obj(end["observed"]["before_bytes"]); raw["pendingDawn"]["cursor"] = 0
                end["observed"]["before_bytes"] = fixture.text(raw)
                fixture.repack(row)
            else:
                row["terminal"][target] = False if target == "run_cleared" else {}
            self.reject()

    def test_rehashed_opaque_commands_dropped_events_and_failed_saves_reject(self):
        for target in ("opaque", "events", "save", "uid", "source"):
            self.bundle, self.source = fixture.bundle(); row = self.bundle["traces"][0]
            rows = row["capture"]["rows"]
            if target == "opaque":
                next(e for e in rows if e.get("action") == "apply")["action"] = "play_turn"
            elif target == "events":
                next(e for e in rows if "events" in e.get("observed", {}))["observed"]["events"] = []
            elif target == "save":
                next(e for e in rows if "ok" in e.get("observed", {}))["observed"]["ok"] = False
            elif target == "uid":
                next(e for e in rows if e.get("inputs", {}).get("t") == "playCard")["inputs"]["uid"] = 999
            else:
                rows[0]["sources"] = {}
            fixture.repack(row)
            self.reject()

    def test_rehashed_stale_combat_object_or_wrong_encounter_reject(self):
        for target in ("object", "encounter"):
            self.bundle, self.source = fixture.bundle(); row = self.bundle["traces"][0]
            begin = next(e for e in row["capture"]["rows"] if e.get("action") == "combat_result")
            if target == "object":
                begin["state"]["combat"]["object_id"] = "old-safe-node-object"
            else:
                begin["inputs"]["encounter"] = fixture.text([row["run_id"], 0, "safe-node"])
            fixture.repack(row)
            self.reject()

    def test_interruption_raw_damage_parent_and_summary_reject(self):
        for target in ("raw", "parent", "summary", "footer"):
            self.bundle, self.source = fixture.bundle(); row = self.bundle["traces"][0]
            if target == "raw": row["capture"]["journal_bytes"] += "bad"
            elif target == "parent":
                row["capture"]["rows"][1]["parent"] = 999; fixture.repack(row)
            elif target == "summary": row["starts"] = 2
            else:
                row["capture"]["rows"][-1]["complete"] = False; fixture.repack(row)
            self.reject()

    def test_after_reward_safe_node_old_combat_rejects_at_identity_guard(self):
        row, _ = fixture.route(p.ROOTS[0], p.blank_vigil(), self.source, combats=2)
        rows = row["capture"]["rows"]
        safe_begin = next(e for e in rows if e.get("action") == "safe_node")
        at = next(i for i, e in enumerate(rows) if e.get("phase") == "end" and e.get("token") == safe_begin["token"])
        state = deepcopy(rows[at]["state"])
        extra = [dict(phase="begin", token=10000, parent=-1, action="combat_result",
                      inputs=dict(encounter=fixture.text([row["run_id"], 0, "safe-node"]), result="win"), state=state),
                 dict(phase="end", token=10000, observed={}, state=state)]
        rows[at + 1:at + 1] = extra
        tokens = {e["token"]: i for i, e in enumerate(rows) if e.get("phase") == "begin"}
        for e in rows:
            if "token" in e: e["token"] = tokens[e["token"]]
            if e.get("parent", -1) != -1: e["parent"] = tokens[e["parent"]]
        fixture.repack(row)
        with self.assertRaisesRegex(p.CaptureError, "stale/duplicate/misbound combat dispatch"):
            p.inspect_route(row, self.source["files"], self.source["pilot"])

    def test_after_reward_safe_node_next_created_combat_is_structurally_valid(self):
        row, _ = fixture.route(p.ROOTS[0], p.blank_vigil(), self.source, combats=2)
        observed = p.inspect_route(row, self.source["files"], self.source["pilot"])
        self.assertEqual(observed["runsPlayed"], 1)
        self.assertEqual(row["starts"], 2)
        self.assertFalse(p.evaluate_witness({})["n0_accepted"])

    def test_H_role_adapter_keeps_producer_bytes_and_manifest_separate(self):
        # Explicit mocked H authority. Exercises adapter wiring, not H integration.
        bundle, manifest = fixture.bundle()
        manifest["extractor_sha256"] = "a" * 64
        blobs = {"trace": fixture.text(bundle).encode(), "manifest": fixture.text(manifest).encode()}
        expected = {"roles": {"preflight_trace": {"locator": "trace"},
            "development_manifest": {"locator": "manifest"},
            "extractor_source": {"locator": "producer", "sha256": "a" * 64}}}
        class Context:
            kind = "synthetic"
            def resolve(self, locator):
                return blobs[locator]
        class Boundary:
            def verify(self, packet, context):
                return expected, {}
        with patch.object(p, "_load_boundary", return_value=Boundary()):
            result = p.evaluate_witness({}, Context())
            self.assertEqual(result["result"], "SYNTHETIC_ONLY")
            self.assertFalse(result["n0_accepted"])
            manifest["extractor_sha256"] = "b" * 64
            blobs["manifest"] = fixture.text(manifest).encode()
            self.assertEqual(p.evaluate_witness({}, Context())["result"], "REJECT")

    def test_existing_H_boundary_is_called_before_record_inspection(self):
        class Boundary:
            def verify(self, packet, context):
                raise ValueError("SYNTHETIC H boundary rejection")
        with patch.object(p, "_load_boundary", return_value=Boundary()), patch.object(p, "inspect_sequence") as inspect:
            out = p.evaluate_witness({}, object())
            inspect.assert_not_called()
            self.assertEqual(out["result"], "REJECT")
            self.assertFalse(out["n0_accepted"])


class SourceShapeTests(unittest.TestCase):
    # These are source-shape regressions, NOT GDScript parse or native execution.
    def test_debit_before_native_apply_and_once_only_observer(self):
        main = (HERE / "tests/support/dd1_native_driver_main.gd").read_text()
        journal = (HERE / "tests/support/dd1_route_journal.gd").read_text()
        self.assertLess(main.index("Unit.consume()"), main.index("contained_starts += 1"))
        self.assertEqual(journal.count("super.apply(cmd)"), 1)
        self.assertLess(journal.index("before_combat_start()"), journal.index("super.apply(cmd)"))
        self.assertIn("return -1", journal)
        self.assertIn("game.cb != current_combat", main)
        self.assertLess(main.index("dispatched = true"), main.index("super._on_combat_over"))

    def test_terminal_and_initial_bytes_are_not_shortcuts(self):
        main = (HERE / "tests/support/dd1_native_driver_main.gd").read_text()
        capture = (HERE / "tests/support/dd1_ordinary_capture.gd").read_text()
        self.assertIn("super._on_dawn_advance(null)", main)
        self.assertIn("super._finish_dawn()", main)
        self.assertIn("main.complete_terminal()", capture)
        self.assertNotIn("SaveService.clear", capture)
        self.assertIn("unmapped_pending_public_choice", capture)


if __name__ == "__main__":
    unittest.main(verbosity=2)
