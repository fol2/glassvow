"""Pure DD1-KERNEL-COMPAT-1 K1 checks. No kernel, subprocess, engine, or fixture build."""
from __future__ import annotations
from copy import deepcopy
from datetime import datetime, timedelta, timezone
import inspect
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent / "dd1_linux"))
import dd1_kernel_qualification as kq
import dd1_linux_backend as backend
import dd1_linux_snapshot as snap
import dd1_meter_entry as entry
import dd1_reservations as r
import kernel_compat_controls as controls

HEAD = "a" * 40
INSIDE = datetime(2026, 9, 26, 18, 0, tzinfo=timezone.utc)
AT_DEADLINE = datetime(2026, 9, 27, 11, 2, tzinfo=timezone.utc)
LEGACY_NOW = datetime(2026, 9, 18, tzinfo=timezone.utc)
SOURCE = b"inert source"


class Ctx:
    def __init__(self, files, kind="empirical", receipts=None):
        self.files, self.kind = files, kind
        self.receipts = receipts or {}

    def resolve(self, locator):
        return self.files.get(locator)


def host_facts(**over):
    host = {key: (list(value) if isinstance(value, list) else value)
            for key, value in kq.QUALIFIED_IDENTITY.items()}
    host.update(over)
    return host


def profile(head=HEAD, **over):
    body = dict(schema=kq.SCHEMA, operation=kq.OPERATION, selection=kq.SELECTION, source_head=head,
                status="REQUALIFYING", mode="inert_control", host_identity=host_facts(),
                primitives=sorted(kq.PRIMITIVES))
    body.update(over)
    return body


def unit(**over):
    qual = over.pop("qualification", {})
    body = dict(schema="DD1-COMPLETE-UNIT-DEMAND-2", operation=kq.OPERATION, overlay_head=HEAD,
                mode="inert_control", operation_start_utc=kq.INERT_RESERVATION_POLICY["start_utc"],
                operation_deadline_utc=kq.INERT_RESERVATION_POLICY["deadline_utc"],
                kernel_qualification=profile(**qual))
    body.update(over)
    return body


def k_account(**recovery):
    policy = kq.INERT_RESERVATION_POLICY
    body = dict(id="DD1-KERNEL-COMPAT-1", selection=policy["selection"], starts_used=0,
                starts_cap=policy["starts_cap"], cpu_ns_used=0, cpu_ns_cap=policy["cpu_ns_cap"],
                raw_bytes_used=0, raw_bytes_cap=policy["raw_bytes_cap"], executors=1,
                per_invocation_cpu_seconds=30, first_engine_launch_utc=policy["start_utc"],
                deadline_utc=policy["deadline_utc"], unit_reservations_v2=[],
                events=[{"note": "SYNTHETIC K1 inert reservation account; no historical credit"}])
    body.update(recovery)
    return dict(schema="DD1-KERNEL-COMPAT-1-SYNTHETIC-ACCOUNT-1", synthetic=True, recovery=body)


def legacy_account():
    return dict(schema="DD1-N0-RECOVERY-1-ACCOUNT-1", synthetic=True,
        historical=dict(attempt="1/1 consumed", starts_used=1277, starts_cap=8192,
            starts_remaining_arithmetic=6915, spendable=False, cpu_seconds="UNKNOWN",
            elapsed_seconds="UNKNOWN", raw_bytes="UNKNOWN"),
        recovery=dict(id=r.OPERATION, starts_used=2040, starts_cap=r.STARTS_CAP,
            cpu_ns_used=398617197992, cpu_ns_cap=r.CPU_CAP, raw_bytes_used=893139,
            raw_bytes_cap=r.RAW_CAP, executors=1, per_invocation_cpu_seconds=300,
            first_engine_launch_utc=r.FIRST, deadline_utc=r.DEADLINE,
            events=[{"note": "SYNTHETIC copy of immutable historical observations"}]))


def disposition(u, authority="owner:ash"):
    body = dict(schema=kq.DISPOSITION_SCHEMA, operation=kq.OPERATION, owner_selection=kq.SELECTION,
                profile_sha256=kq.profile_sha256(u), source_head=u["overlay_head"],
                kernel_identity=u["kernel_qualification"]["host_identity"],
                independent_review="APPROVE", planner_acceptance="ACCEPTED",
                launch_admitted=True, authority=authority)
    raw = r.encode(body)
    expected = dict(roles={"kernel_qualification_disposition": {"locator": "role", "sha256": r.digest(raw)}},
                    receipt_authorities={"kernel_qualification_disposition":
                                         {"authority": authority, "sha256": r.digest(raw)}})
    ctx = Ctx({"role": raw}, receipts={"kernel_qualification_disposition": raw})
    return raw, expected, ctx


class KernelQualificationTests(unittest.TestCase):
    def test_legacy_no_profile_6_18_44_passes(self):
        kq.require({}, host_facts(kernel_release="6.18.44"))

    def test_legacy_no_profile_6_12_94_fails(self):
        with self.assertRaisesRegex(r.ReservationError, "unsupported host/ABI; no fallback"):
            kq.require({}, host_facts())

    def test_requalifying_inert_6_12_94_passes(self):
        kq.require(unit(), host_facts())

    def test_requalifying_rejected_for_engineering_native(self):
        u = unit(mode="engineering", qualification={"mode": "engineering"})
        with self.assertRaisesRegex(r.ReservationError, "REQUALIFYING is inert-control only"):
            kq.require(u, host_facts())
        with self.assertRaisesRegex(r.ReservationError, "not native authority"):
            kq.native_bindings(u, {"roles": {}}, Ctx({}))

    def test_host_release_change_rejects(self):
        u = unit()
        u["kernel_qualification"]["host_identity"]["kernel_release"] = "6.18.44"
        with self.assertRaises(r.ReservationError):
            kq.require(u, host_facts())

    def test_host_version_change_rejects(self):
        u = unit()
        u["kernel_qualification"]["host_identity"]["kernel_version"] = "#1 different"
        with self.assertRaises(r.ReservationError):
            kq.require(u, host_facts())

    def test_host_machine_change_rejects(self):
        u = unit()
        u["kernel_qualification"]["host_identity"]["machine"] = "aarch64"
        with self.assertRaises(r.ReservationError):
            kq.require(u, host_facts())

    def test_host_pointer_change_rejects(self):
        u = unit()
        u["kernel_qualification"]["host_identity"]["pointer_bytes"] = 4
        with self.assertRaises(r.ReservationError):
            kq.require(u, host_facts())

    def test_host_libc_change_rejects(self):
        u = unit()
        u["kernel_qualification"]["host_identity"]["libc"] = ["glibc", "2.39"]
        with self.assertRaises(r.ReservationError):
            kq.require(u, host_facts())

    def test_wrong_selection_rejects(self):
        u = unit()
        u["kernel_qualification"]["selection"] = 1
        with self.assertRaises(r.ReservationError):
            kq.require(u, host_facts())

    def test_wrong_operation_rejects(self):
        u = unit()
        u["kernel_qualification"]["operation"] = "DD1-N0-RECOVERY-1"
        with self.assertRaises(r.ReservationError):
            kq.require(u, host_facts())

    def test_wrong_source_head_rejects(self):
        u = unit()
        u["kernel_qualification"]["source_head"] = "b" * 40
        with self.assertRaises(r.ReservationError):
            kq.require(u, host_facts())

    def test_missing_primitive_rejects(self):
        u = unit()
        u["kernel_qualification"]["primitives"] = sorted(kq.PRIMITIVES - {"cgroup_v2"})
        with self.assertRaises(r.ReservationError):
            kq.require(u, host_facts())

    def test_extra_primitive_rejects(self):
        u = unit()
        u["kernel_qualification"]["primitives"] = sorted(kq.PRIMITIVES) + ["ptrace"]
        with self.assertRaises(r.ReservationError):
            kq.require(u, host_facts())

    def test_extra_field_rejects(self):
        u = unit()
        u["kernel_qualification"]["boot_id"] = "not-a-profile-field"
        with self.assertRaisesRegex(r.ReservationError, "no extra fields"):
            kq.require(u, host_facts())

    def test_missing_disposition_rejects_native(self):
        u = unit(mode="engineering", qualification={"status": "QUALIFIED", "mode": "engineering"})
        with self.assertRaisesRegex(r.ReservationError, "missing kernel qualification disposition"):
            kq.native_bindings(u, {"roles": {}}, Ctx({}))

    def test_synthetic_disposition_rejects_native(self):
        u = unit(mode="engineering", qualification={"status": "QUALIFIED", "mode": "engineering"})
        _raw, expected, ctx = disposition(u, authority="synthetic:k1")
        with self.assertRaisesRegex(r.ReservationError, "unauthenticated kernel qualification issuer"):
            kq.native_bindings(u, expected, ctx)
        _raw, expected, ctx = disposition(u)
        ctx.kind = "synthetic"
        with self.assertRaisesRegex(r.ReservationError, "synthetic native authority"):
            kq.native_bindings(u, expected, ctx)
        _raw, expected, ctx = disposition(u)
        ctx.receipts["kernel_qualification_disposition"] = b"mismatch"
        with self.assertRaisesRegex(r.ReservationError, "unauthenticated kernel qualification issuer"):
            kq.native_bindings(u, expected, ctx)

    def test_staged_controller_source_substitution_differs(self):
        loaded = Path(kq.__file__).read_bytes()
        staged = loaded.replace(b"DD1-KERNEL-QUALIFICATION-1", b"DD1-KERNEL-QUALIFICATION-0", 1)
        self.assertNotEqual(loaded, staged)
        self.assertNotEqual(r.digest(loaded), r.digest(staged))
        prepare = Path(snap.__file__).read_text()
        self.assertIn("loaded controller source differs", prepare)
        self.assertIn("res://tools/dd1_kernel_qualification.py", snap.HELPER_SOURCES)
        self.assertEqual(snap.PINNED_HELPER_SHA256,
                         "41a4529af3bb2fb3f065d164dee8ac9cd2af7d761311c5ee63538347a44e45a4")

    def test_k2_plan_is_exactly_16_cases(self):
        rows = controls.plan()
        self.assertEqual(len(rows), 16)
        caps = [row["cpu_cap"] for row in rows]
        self.assertTrue(all(cap <= 30 for cap in caps))
        self.assertEqual(sum(caps), 204)
        self.assertLessEqual(sum(caps), 240)
        self.assertEqual(sum(caps) + controls.BUILD_RESERVE, 264)
        self.assertLessEqual(sum(caps) + controls.BUILD_RESERVE, controls.AGGREGATE)
        ids = [row["case_id"] for row in rows]
        self.assertEqual(len(set(ids)), 16)
        self.assertEqual(rows[8]["kill"], "controller")
        self.assertEqual(rows[9]["kill"], "supervisor")
        self.assertEqual(rows[12]["threads"], 14)
        self.assertEqual(rows[12]["births"], 13)
        self.assertEqual(rows[13]["births"], 14)
        self.assertEqual(rows[14]["special"], "ia32_reachability")
        for row in rows:
            self.assertEqual(row["argv_tokens"][0], "/workload")
            self.assertNotIn("godot", " ".join(row["argv_tokens"]).lower())
            self.assertTrue(row["required_observation"])
            self.assertNotIn("threads", rows[0])


class ReservationPolicyTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name).resolve()

    def tearDown(self):
        self.tmp.cleanup()

    def demand(self, name="k1-unit"):
        path = self.root / (name + "-account.json")
        r.atomic_write(path, k_account())
        cmd = ["/workload", "positive"]
        body = unit()
        body.update(receipt_sha256="2" * 64, account_sha256=r.digest(path.read_bytes()), argv=cmd,
                    unit_id=name, contained_starts=0, cpu_seconds=11, wall_seconds=30, raw_bytes=1_000_000,
                    source_files={"res://tools/dd1_linux/inert.c": r.digest(SOURCE)})
        return path, body, cmd

    def test_legacy_deadline_constant_unchanged(self):
        self.assertEqual(r.FIRST, "2026-09-17T17:54:40Z")
        self.assertEqual(r.DEADLINE, "2026-09-24T17:54:40Z")
        self.assertEqual(r.OPERATION, "DD1-N0-RECOVERY-1")

    def test_legacy_after_expiry_rejects(self):
        with self.assertRaisesRegex(r.ReservationError, "outside recovery window"):
            r.totals(legacy_account(), datetime(2026, 9, 25, tzinfo=timezone.utc))

    def test_kernel_policy_before_selected_deadline_passes(self):
        path, body, cmd = self.demand()
        policy = kq.inert_reservation_policy(body)
        self.assertEqual(policy, kq.INERT_RESERVATION_POLICY)
        self.assertEqual(policy["selection"], 5845725453)
        self.assertEqual(policy["start_utc"], "2026-09-26T11:02:00Z")
        self.assertEqual(policy["deadline_utc"], "2026-09-27T11:02:00Z")
        r.validate_unit(body, cmd, head=HEAD, receipt_sha="2" * 64, account_sha=body["account_sha256"],
                        source_reader=lambda _name: SOURCE, policy=policy)
        account = r.read(path)
        self.assertEqual(r.totals(account, INSIDE, policy)["starts"], 0)
        r.available(account, 1, 11 * 10**9, 1_000_000, INSIDE, policy)

    def test_kernel_policy_at_or_after_deadline_rejects(self):
        path, body, _cmd = self.demand()
        policy = kq.inert_reservation_policy(body)
        account = r.read(path)
        for now in (AT_DEADLINE, AT_DEADLINE + timedelta(seconds=1)):
            with self.assertRaises(r.ReservationError):
                r.totals(account, now, policy)

    def test_kernel_policy_field_mismatch_rejects(self):
        path, body, cmd = self.demand()
        policy = kq.INERT_RESERVATION_POLICY
        account = r.read(path)
        mutations = []
        for key, value in (("operation_start_utc", "2026-09-26T12:00:00Z"),
                           ("operation_deadline_utc", "2026-09-27T12:00:00Z")):
            changed = deepcopy(body)
            changed[key] = value
            mutations.append((key, lambda u=changed: kq.inert_reservation_policy(u)))
        missing = deepcopy(body)
        missing.pop("operation_start_utc")
        mutations.append(("missing-start", lambda: kq.inert_reservation_policy(missing)))
        missing_deadline = deepcopy(body)
        missing_deadline.pop("operation_deadline_utc")
        mutations.append(("missing-deadline", lambda: kq.inert_reservation_policy(missing_deadline)))
        for field, value in (("first_engine_launch_utc", "2026-09-26T12:00:00Z"),
                             ("deadline_utc", "2026-09-27T12:00:00Z"), ("selection", 1),
                             ("starts_cap", 15), ("cpu_ns_cap", 1), ("raw_bytes_cap", 1),
                             ("per_invocation_cpu_seconds", 31), ("executors", 2)):
            changed = k_account(**{field: value})
            mutations.append((field, lambda a=changed: r.totals(a, INSIDE, policy)))
        wrong_schema = k_account()
        wrong_schema["schema"] = "DD1-N0-RECOVERY-1-ACCOUNT-1"
        mutations.append(("schema", lambda: r.totals(wrong_schema, INSIDE, policy)))
        not_synthetic = k_account()
        not_synthetic["synthetic"] = False
        mutations.append(("synthetic", lambda: r.totals(not_synthetic, INSIDE, policy)))
        wrong_operation = deepcopy(body)
        wrong_operation["operation"] = r.OPERATION
        mutations.append(("operation", lambda: kq.inert_reservation_policy(wrong_operation)))
        for name, call in mutations:
            with self.subTest(name=name):
                with self.assertRaises(r.ReservationError):
                    call()
        self.assertEqual(path.read_bytes(), r.encode(account))

    def test_kernel_policy_for_old_inert_unit_rejects(self):
        old = dict(schema="DD1-COMPLETE-UNIT-DEMAND-2", operation=r.OPERATION, scientific_m=r.M,
                   mode="inert_control", overlay_head=HEAD)
        with self.assertRaises(r.ReservationError):
            kq.inert_reservation_policy(old)
        calls = []
        with self.assertRaises(r.ReservationError):
            r.reserve_and_run(self.root / "missing.json", old, command=["/workload", "positive"], head=HEAD,
                              receipt_sha="2" * 64, source_reader=lambda _name: SOURCE,
                              authority_check=lambda _account: None, output=self.root / "old-out",
                              runner=lambda *_args: calls.append(1) or {"success": True}, now=INSIDE,
                              policy=kq.INERT_RESERVATION_POLICY)
        self.assertFalse(calls)
        self.assertFalse((self.root / "missing.json").exists())

    def test_kernel_policy_on_native_path_rejects_before_effect(self):
        eng = unit(mode="engineering", qualification={"mode": "engineering", "status": "QUALIFIED"})
        calls = []
        with self.assertRaises(r.ReservationError):
            kq.inert_reservation_policy(eng)
        with self.assertRaises(r.ReservationError):
            r.reserve_and_run(self.root / "native.json", eng, command=["/workload", "positive"], head=HEAD,
                              receipt_sha="2" * 64, source_reader=lambda _name: SOURCE,
                              authority_check=lambda _account: None, output=self.root / "native-out",
                              runner=lambda *_args: calls.append(1) or {"success": True}, now=INSIDE,
                              policy=kq.INERT_RESERVATION_POLICY)
        self.assertFalse(calls)
        native = inspect.getsource(entry.run_complete_unit)
        self.assertNotIn("inert_reservation_policy", native)
        self.assertNotIn("reservation_policy", native)
        self.assertIn("controller_limits(unit)", native)

    def test_grant_deadline_is_selected_deadline(self):
        path, body, cmd = self.demand("grant")
        policy = kq.inert_reservation_policy(body)
        seen = {}

        def runner(grant, _output):
            seen["deadline"] = grant["deadline_unix"]
            return {"success": True}

        r.reserve_and_run(path, body, command=cmd, head=HEAD, receipt_sha="2" * 64,
                          source_reader=lambda _name: SOURCE, authority_check=lambda _account: None,
                          output=self.root / "grant", runner=runner, now=INSIDE, policy=policy)
        grant = r.read(self.root / "grant" / "UNIT-GRANT.json")
        self.assertEqual(seen["deadline"], 1790506920)
        self.assertEqual(grant["deadline_unix"], 1790506920)
        self.assertIsInstance(grant["deadline_unix"], int)

    def test_backend_default_vs_k1_clock(self):
        _path, body, _cmd = self.demand("clock")
        policy = kq.inert_reservation_policy(body)
        body["cpu_seconds"] = 20
        body["wall_seconds"] = 30
        n0 = datetime.fromisoformat(r.DEADLINE.replace("Z", "+00:00")).timestamp()
        self.assertLess(n0, time.time())
        k1 = datetime.fromisoformat(policy["deadline_utc"].replace("Z", "+00:00")).timestamp()
        expected = min(30.0, k1 - time.time())
        self.assertGreaterEqual(expected, 3)
        recorded = {}

        class Proc:
            def iterdir(self):
                return [object()]

        class Usage:
            ru_utime = 0.0
            ru_stime = 0.0

        class Libc:
            def prctl(self, *_args):
                return 0

        def run(deadline=None):
            backend._once = False
            with patch.object(backend, "Path", lambda _path: Proc()), \
                 patch.object(backend.resource, "getrusage", lambda _who: Usage()), \
                 patch.object(backend.resource, "getrlimit", lambda _res: (backend.resource.RLIM_INFINITY,) * 2), \
                 patch.object(backend.resource, "setrlimit", lambda *_args: None), \
                 patch.object(backend.signal, "signal", lambda *_args: None), \
                 patch.object(backend.signal, "pthread_sigmask", lambda *_args: None), \
                 patch.object(backend.signal, "setitimer", lambda _which, seconds, _interval=0: recorded.__setitem__("wall", seconds)), \
                 patch.object(backend.ctypes, "CDLL", lambda *_args, **_kwargs: Libc()), \
                 patch.object(backend.time, "monotonic", lambda: 10.0):
                if deadline is None:
                    return backend.controller_limits(body)
                return backend.controller_limits(body, deadline)

        try:
            with self.assertRaisesRegex(r.ReservationError, "cleanup headroom"):
                run(None)
            _start, remain = run(policy["deadline_utc"])
            self.assertAlmostEqual(recorded["wall"], expected, delta=1.5)
            self.assertAlmostEqual(remain, recorded["wall"] - 2, delta=1.5)
            with self.assertRaisesRegex(r.ReservationError, "unpinned kernel deadline"):
                run("2026-09-28T00:00:00Z")
        finally:
            backend._once = False

    def test_no_caller_clock_reaches_k2_release(self):
        driver = Path(controls.__file__).read_text()
        self.assertNotIn("now=", driver)
        self.assertNotIn("--now", driver)
        self.assertNotIn("--deadline", driver)
        self.assertNotIn("reservation_policy", driver)
        self.assertNotIn("now", inspect.signature(entry._run_inert_unit).parameters)
        inert = inspect.getsource(entry._run_inert_unit)
        self.assertIn("inert_reservation_policy(unit)", inert)
        self.assertIn('policy["deadline_utc"]', inert)
        path, body, cmd = self.demand("clock-reject")
        before = path.read_bytes()
        bad = dict(kq.INERT_RESERVATION_POLICY)
        bad["deadline_utc"] = "2026-09-28T00:00:00Z"
        calls = []
        with self.assertRaisesRegex(r.ReservationError, "caller-shaped reservation policy rejected"):
            r.reserve_and_run(path, body, command=cmd, head=HEAD, receipt_sha="2" * 64,
                              source_reader=lambda _name: SOURCE, authority_check=lambda _account: None,
                              output=self.root / "clock-reject", runner=lambda *_args: calls.append(1) or {"success": True},
                              now=INSIDE, policy=bad)
        self.assertFalse(calls)
        self.assertEqual(path.read_bytes(), before)

    def test_operation_totals_16_300s_128mib_no_refund(self):
        policy = kq.INERT_RESERVATION_POLICY

        def charged(count, **fields):
            base = dict(state="RESERVED", starts=1, cpu_ns=1, raw_bytes=1)
            base.update(fields)
            rows = [dict(base, unit_id="u" + str(index)) for index in range(count)]
            return k_account(unit_reservations_v2=rows)

        full = charged(16)
        self.assertEqual(r.totals(full, INSIDE, policy)["starts"], 16)
        with self.assertRaisesRegex(r.ReservationError, "exhausted complete-unit reservation: starts"):
            r.available(full, 1, 1, 1, INSIDE, policy)
        cpu = charged(1, cpu_ns=300_000_000_000)
        with self.assertRaisesRegex(r.ReservationError, "exhausted complete-unit reservation: cpu_ns"):
            r.available(cpu, 1, 1, 1, INSIDE, policy)
        raw = charged(1, raw_bytes=134_217_728)
        with self.assertRaisesRegex(r.ReservationError, "exhausted complete-unit reservation: raw_bytes"):
            r.available(raw, 1, 1, 1, INSIDE, policy)
        failed = charged(16, state="FAILED")
        self.assertEqual(r.totals(failed, INSIDE, policy)["starts"], 16)
        with self.assertRaisesRegex(r.ReservationError, "exhausted complete-unit reservation: starts"):
            r.available(failed, 1, 1, 1, INSIDE, policy)
        with self.assertRaisesRegex(r.ReservationError, "per-invocation CPU ceiling"):
            r.available(k_account(), 1, 31 * 10**9, 1, INSIDE, policy)

    def test_legacy_reservation_tests_unchanged(self):
        path = self.root / "legacy.json"
        r.atomic_write(path, legacy_account())
        cmd = ["/workload", "positive"]
        body = dict(schema="DD1-COMPLETE-UNIT-DEMAND-2", operation=r.OPERATION, scientific_m=r.M,
                    overlay_head="1" * 40, receipt_sha256="2" * 64, account_sha256=r.digest(path.read_bytes()),
                    argv=cmd, unit_id="legacy-1", mode="inert_control", contained_starts=1, cpu_seconds=4,
                    wall_seconds=5, raw_bytes=1_000_000, source_files={"res://inert.py": r.digest(SOURCE)})
        result = r.reserve_and_run(path, body, command=cmd, head="1" * 40, receipt_sha="2" * 64,
                                   source_reader=lambda _name: SOURCE, authority_check=lambda _account: None,
                                   output=self.root / "legacy-1", runner=lambda *_args: {"success": True}, now=LEGACY_NOW)
        self.assertEqual(result["charged"]["starts"], 2)
        self.assertEqual(r.totals(r.read(path), LEGACY_NOW)["starts"], 2042)
        grant = r.read(self.root / "legacy-1" / "UNIT-GRANT.json")
        self.assertEqual(grant["deadline_unix"],
                         datetime.fromisoformat(r.DEADLINE.replace("Z", "+00:00")).timestamp())
        self.assertFalse(result["n0_accepted"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
