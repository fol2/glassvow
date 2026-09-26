"""Pure DD1-KERNEL-COMPAT-1 K1 checks. No kernel, subprocess, engine, or fixture build."""
from __future__ import annotations
from contextlib import redirect_stderr, redirect_stdout
from copy import deepcopy
from datetime import datetime, timedelta, timezone
import inspect
import io
import json
import os
import platform
import shutil
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent / "dd1_linux"))
import dd1_compatibility as compat
import dd1_kernel_qualification as kq
import dd1_linux_backend as backend
import dd1_linux_snapshot as snap
import dd1_meter_entry as entry
import dd1_reservations as r
import dd1_runtime_fit as fitmod
import kernel_compat_controls as controls

REAL_HELPER = snap.PINNED_HELPER_SHA256
REAL_INERT = entry.INERT_BINARIES
REAL_FIT = fitmod.INERT_BINARY
REAL_LIBC = compat.LIBC

HEAD = "a" * 40
INSIDE = datetime(2026, 9, 26, 18, 0, tzinfo=timezone.utc)
AT_DEADLINE = datetime(2026, 9, 27, 11, 2, tzinfo=timezone.utc)
LEGACY_NOW = datetime(2026, 9, 18, tzinfo=timezone.utc)
SOURCE = b"inert source"
CASE_RAW = 8_388_608
BASE_HEAD = "c17ae971a447c28e597b78d0ecb5eb29f36e644a"
REMOTE_MAIN = "07b5aa9dec8436132a524511d5438c510e322070"
HELPER_PIN = "41a4529af3bb2fb3f065d164dee8ac9cd2af7d761311c5ee63538347a44e45a4"


class FrozenClock(datetime):
    instant = INSIDE

    @classmethod
    def now(cls, tz=None):
        return cls.instant


class Proc:
    def __init__(self, out, code=0):
        self.out, self.code, self.returncode = out, code, None

    def poll(self):
        return self.returncode

    def communicate(self, timeout=None):
        self.returncode = self.code
        return self.out, ""

    def kill(self):
        self.returncode = -9


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
        moment = INSIDE.timestamp()
        n0 = datetime.fromisoformat(r.DEADLINE.replace("Z", "+00:00")).timestamp()
        self.assertLess(n0, moment)
        k1 = datetime.fromisoformat(policy["deadline_utc"].replace("Z", "+00:00")).timestamp()
        expected = min(30.0, k1 - moment)
        self.assertEqual(expected, 30.0)
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
                 patch.object(backend.time, "time", lambda: moment), \
                 patch.object(backend.time, "monotonic", lambda: 10.0):
                if deadline is None:
                    return backend.controller_limits(body)
                return backend.controller_limits(body, deadline)

        try:
            with self.assertRaisesRegex(r.ReservationError, "cleanup headroom"):
                run(None)
            _start, remain = run(policy["deadline_utc"])
            self.assertEqual(recorded["wall"], 30.0)
            self.assertEqual(remain, 28.0)
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


class LedgerTests(unittest.TestCase):
    POSITIVE = frozenset((
        "KC01_STRICT_POSITIVE", "KC02_READONLY_ESCAPE", "KC03_CLONE3_FALLBACK",
        "KC11_COMPAT_COMBINED", "KC12_CPU_ABOVE_3", "KC13_FIT_14_BOUNDARY",
        "KC15_IA32_REACHABILITY"))

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name).resolve()
        self.origin = controls.ROOT
        self._clock = controls.datetime
        self._boot = controls._live_boot_id_sha256
        self._absent = controls._identity_absent
        self._cpu = controls._observed_cpu_ns
        self._stage = controls.stage
        self._spawn = controls.spawn
        self._wait = controls.wait_live
        self._signal = controls._signal_pid
        self._write = r.atomic_write
        self.boot_hash = "c" * 64
        FrozenClock.instant = INSIDE
        controls.datetime = FrozenClock
        controls._live_boot_id_sha256 = lambda: self.boot_hash
        controls._identity_absent = lambda identity: True
        self.clone = self.root / "clone"
        for name in snap.HELPER_SOURCES:
            dest = self.clone / name[6:]
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(self.origin / name[6:], dest)
        for name in ("inert.c", "compat2_inert.c", "fit_inert.c"):
            shutil.copyfile(self.origin / "tools/dd1_linux" / name, self.clone / "tools/dd1_linux" / name)
        build = self.clone / "tools/dd1_linux/build"
        build.mkdir(parents=True)
        self.blobs = {
            "supervisor": b"supervisor-bytes", "inert": b"inert-bytes",
            "compat2-inert": b"compat2-bytes", "fit-inert": b"fit-bytes", "libc.so.6": b"libc-bytes"}
        for name, raw in self.blobs.items():
            (build / name).write_bytes(raw)
        controls.ROOT = self.clone
        self.patch_pins()
        self.write_k0()
        (self.root / "LOCK").write_bytes(b"")

    def tearDown(self):
        controls.ROOT = self.origin
        controls.datetime = self._clock
        controls._live_boot_id_sha256 = self._boot
        controls._identity_absent = self._absent
        controls._observed_cpu_ns = self._cpu
        controls.stage = self._stage
        controls.spawn = self._spawn
        controls.wait_live = self._wait
        controls._signal_pid = self._signal
        r.atomic_write = self._write
        snap.PINNED_HELPER_SHA256 = REAL_HELPER
        entry.INERT_BINARIES = REAL_INERT
        fitmod.INERT_BINARY = REAL_FIT
        compat.LIBC = REAL_LIBC
        FrozenClock.instant = INSIDE
        self.tmp.cleanup()

    def patch_pins(self):
        snap.PINNED_HELPER_SHA256 = r.digest(self.blobs["supervisor"])
        entry.INERT_BINARIES = frozenset((r.digest(self.blobs["inert"]), r.digest(self.blobs["compat2-inert"])))
        fitmod.INERT_BINARY = r.digest(self.blobs["fit-inert"])
        compat.LIBC = r.digest(self.blobs["libc.so.6"])

    def source_map(self, clone=None):
        clone = self.clone if clone is None else clone
        return {name: r.digest((clone / name[6:]).read_bytes()) for name in snap.HELPER_SOURCES}

    def k0_body(self, durable=None, clone=None, head=HEAD):
        durable = self.root if durable is None else durable
        clone = self.clone if clone is None else clone
        primitives = {name: True for name in (
            "seccomp_user_notif", "user_namespace", "mount_namespace", "network_namespace",
            "readonly_bind_remount", "subreaper", "pdeathsig", "cgroup_v2")}
        primitives.update(rlimit_cpu_soft=1, rlimit_cpu_hard=1)
        return dict(
            schema="DD1-KERNEL-COMPAT-1-K0", operation=kq.OPERATION, selection_comment=5845725453,
            selection_timestamp_utc="2026-09-26T11:02:00Z", deadline_utc="2026-09-27T11:02:00Z",
            custodian="Tushar", executor="grokbot-vm", durable_root=str(durable),
            lock=dict(path=str(Path(durable) / "LOCK"), acquired=True, locker_pid=1,
                      locker_start_ticks=2, acquired_at_utc="2026-09-26T11:02:00Z",
                      same_unix_user_advisory_only=True),
            clone=dict(path=str(clone), head=head, tree="b" * 40, clean=True,
                       shared_clone_modified=False, remote_main=REMOTE_MAIN),
            host=dict(hostname="test-host", os_id="debian", os_version="13",
                      kernel_release=kq.QUALIFIED_IDENTITY["kernel_release"],
                      kernel_version=kq.QUALIFIED_IDENTITY["kernel_version"],
                      machine="x86_64", pointer_bytes=8, libc=["glibc", "2.41"],
                      python=platform.python_version(), boot_id_sha256=self.boot_hash, cgroup_v2=True),
            resources=dict(vcpus=1, memory_total_bytes=1, memory_available_bytes=1, swap_total_bytes=0,
                           disk_free_bytes=1, load_1m=0.1),
            primitives=primitives,
            github=dict(ls_remote_main=REMOTE_MAIN, authenticated_gh_api_available=True),
            persistence=dict(home_root_expected_persistent=True, usr_may_reset_on_computer_update=True,
                             flock_path="flock", python_path="python3", cc_path="cc",
                             openssh_reinstall_after_update_risk=True),
            helper=dict(baseline_sha256=HELPER_PIN, compiled_in_k0=False),
            helper_sources_sha256=self.source_map(clone),
            counters=dict(workload_releases=0, compile_commands=0, engine_runs=0, source_mutations=0))

    def write_k0(self, body=None):
        r.atomic_write(self.root / "K0.json", self.k0_body() if body is None else body)

    def invoke(self, args):
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            try:
                code = controls.main(args)
            except SystemExit as exc:
                return exc.code, out.getvalue(), err.getvalue()
        return code, out.getvalue(), err.getvalue()

    def init_ledger(self, cpu_ns=10_000_000_000, root=None):
        root = self.root if root is None else root
        return self.invoke(["--head", HEAD, "--root", str(root), "--init-ledger", "--build-cpu-ns", str(cpu_ns)])

    def reset(self):
        ledger = self.root / "K2-LEDGER.json"
        if ledger.is_symlink() or ledger.exists():
            ledger.unlink()
        case_root = self.root / "dd1-kernel-compat-1"
        if case_root.exists() or case_root.is_symlink():
            shutil.rmtree(case_root)
        code, text, err = self.init_ledger()
        self.assertEqual(code, 0, text + err)
        return r.read(ledger)

    def evidence(self, case_id):
        planned = controls.row_for(case_id)
        success = case_id in self.POSITIVE or case_id == "KC09_CONTROLLER_KILL"
        report, capture = {}, {"save.json": None, "stdout.bin": None, "save.bin": None}
        src_input = frozen = None
        if case_id == "KC01_STRICT_POSITIVE":
            report.update(thread_births_including_main=3, execs=1)
            capture["save.json"] = b'{"v":2}\n'
            capture["stdout.bin"] = b"OK SAVE THREADS\n"
        elif case_id == "KC02_READONLY_ESCAPE":
            capture["stdout.bin"] = b"ISOLATED\n"
            src_input = b"IMMUTABLE\n"
        elif case_id == "KC03_CLONE3_FALLBACK":
            report.update(clone3_denied=1, thread_births_including_main=1)
            capture["stdout.bin"] = b"errno=38\n"
        elif case_id == "KC04_STRICT_THREAD_CEILING":
            report.update(last_denied_syscall=56, execs=1, thread_births_including_main=4)
        elif case_id == "KC05_CPU_EXHAUST":
            report.update(signal=9, thread_births_including_main=3, workload_cpu_seconds=10)
        elif case_id == "KC06_RAW_OVERWRITE":
            report.update(last_denied_syscall=18, reserved_before_writes=1_000_000_000, raw_cap=1_000_000_000)
        elif case_id == "KC07_SOCKET_DENY":
            report.update(last_denied_syscall=41, execs=1, thread_births_including_main=1)
        elif case_id == "KC08_X32_ABI_KILL":
            report.update(signal=31)
            capture["stdout.bin"] = b"clean\n"
        elif case_id == "KC11_COMPAT_COMBINED":
            capture["save.bin"] = b"COMPAT2\n"
            frozen = b"FROZEN-INERT\n"
        elif case_id == "KC12_CPU_ABOVE_3":
            report.update(workload_cpu_seconds=5)
            frozen = b"FROZEN-INERT\n"
        elif case_id == "KC13_FIT_14_BOUNDARY":
            report.update(thread_limit=14, profile_mode=2)
            capture["save.bin"] = b"FIT1\n"
            capture["stdout.bin"] = b"MODE:0555 owner=1 group=1 other=1\n"
        elif case_id == "KC15_IA32_REACHABILITY":
            report.update(signal=31)
        elif case_id == "KC16_NESTED_NAMESPACE_DENY":
            report.update(last_denied_syscall=272, execs=1, thread_births_including_main=1)
        z = dict(success=success, cleanup_confirmed=True, native_qualified=False, n0_accepted=False,
                 helper_sha256=snap.PINNED_HELPER_SHA256, supervisor_report=report)
        if case_id == "KC11_COMPAT_COMBINED":
            z.update(compatibility_verdict=True, strict_verdict=False,
                     classification=dict(process_refusals=1, naming_refusals=1),
                     refused_requests=[dict(attribution="CAPABILITY_CLASS_ONLY")])
        elif case_id == "KC12_CPU_ABOVE_3":
            z.update(classification=dict(workload_cpu_soft=6, workload_cpu_hard=6,
                                         supervisor_cpu_soft=2, supervisor_cpu_hard=2),
                     controller_cpu_limits=[3, 3])
        state = "RESERVED" if case_id == "KC09_CONTROLLER_KILL" else ("COMPLETE" if success else "FAILED")
        row = dict(unit_id=case_id, starts=1, cpu_ns=planned["cpu_cap"] * 1_000_000_000, raw_bytes=CASE_RAW,
                   state=state, processes={
                       "controller": {"pid": 11, "start_ticks": 1, "boot_id": "b"},
                       "supervisor": {"pid": 12, "start_ticks": 2, "boot_id": "b"},
                       "workload": {"pid": 13, "start_ticks": 3, "boot_id": "b"}})
        return dict(exit=-9 if case_id == "KC09_CONTROLLER_KILL" else 0, stdout_one=True, z=z,
                    account_readable=True, row=row, exception=False, timeout=False, live=True,
                    killed=("controller" if case_id == "KC09_CONTROLLER_KILL"
                            else "supervisor" if case_id == "KC10_SUPERVISOR_KILL" else None),
                    identities_absent=True, source_same=True, unit_raw_bytes=CASE_RAW, capture=capture,
                    capture_bytes=10, src_input=src_input, src_moved=False, src_hardlink=False,
                    src_original=False, src_frozen=frozen)

    def lay_down(self, root, row, evidence):
        where = Path(root) / "dd1-kernel-compat-1" / row["case_id"]
        where.mkdir(parents=True)
        source = where / "source"
        source.mkdir()
        capture = where / "output" / "capture"
        capture.mkdir(parents=True)
        for name, data in evidence["capture"].items():
            if data is not None:
                (capture / name).write_bytes(data)
        if evidence["src_input"] is not None:
            (source / "input").write_bytes(evidence["src_input"])
        if evidence["src_frozen"] is not None:
            (source / "inputs").mkdir()
            (source / "inputs" / "frozen.txt").write_bytes(evidence["src_frozen"])
        account = where / "ACCOUNT.json"
        r.atomic_write(account, dict(recovery=dict(unit_reservations_v2=[evidence["row"]])))
        r.atomic_write(where / "paths.json", dict(repo=str(source)))
        unit = dict(raw_bytes=evidence["unit_raw_bytes"], linux=dict(output_root=str(where / "output")))
        return where, unit, account

    def install_expected(self, evidence_for=None):
        def stage(root, repo, row, head):
            evidence = self.evidence(row["case_id"]) if evidence_for is None else evidence_for(row["case_id"])
            return self.lay_down(root, row, evidence)

        def spawn(head, root, case_id):
            evidence = self.evidence(case_id) if evidence_for is None else evidence_for(case_id)
            return Proc(json.dumps(evidence["z"]), evidence["exit"])

        controls.stage = stage
        controls.spawn = spawn
        controls.wait_live = lambda proc, output, account: {
            "controller": {"pid": 11}, "supervisor": {"pid": 12}, "workload": {"pid": 13}}
        controls._signal_pid = lambda pid, sig: None

    def run_case(self, case_id, evidence_for=None):
        self.install_expected(evidence_for)
        code, text, err = self.invoke(["--head", HEAD, "--root", str(self.root), "--case", case_id])
        return code, text, err, r.read(self.root / "K2-LEDGER.json")

    def test_ledger_init_exact_shape_and_build_reserve(self):
        snap.PINNED_HELPER_SHA256 = REAL_HELPER
        entry.INERT_BINARIES = REAL_INERT
        fitmod.INERT_BINARY = REAL_FIT
        compat.LIBC = REAL_LIBC
        good = {"supervisor": REAL_HELPER, "inert": next(iter(REAL_INERT)),
                "compat2-inert": next(iter(REAL_INERT)), "fit-inert": REAL_FIT, "libc.so.6": REAL_LIBC}
        self.assertEqual(controls.build_problems(10_000_000_000, good), [])
        self.assertEqual(controls.build_problems(61_000_000_000, good), ["build cpu above 60s reserve"])
        self.assertIn("supervisor pin mismatch", controls.build_problems(10_000_000_000, dict(good, supervisor="0" * 64)))
        self.patch_pins()
        code, text, err = self.init_ledger(10_000_000_000)
        self.assertEqual(code, 0, text + err)
        ledger = r.read(self.root / "K2-LEDGER.json")
        self.assertEqual(set(ledger), {
            "schema", "operation", "selection_comment", "window", "head", "k0_sha256", "caps",
            "build", "used", "rows", "latch"})
        self.assertEqual(ledger["schema"], "DD1-KERNEL-COMPAT-1-K2-LEDGER-1")
        self.assertEqual(ledger["operation"], "DD1-KERNEL-COMPAT-1")
        self.assertEqual(ledger["selection_comment"], 5845725453)
        self.assertEqual(ledger["window"], {
            "start_utc": "2026-09-26T11:02:00Z", "deadline_utc": "2026-09-27T11:02:00Z",
            "deadline_unix": 1790506920})
        self.assertEqual(ledger["head"], HEAD)
        self.assertEqual(ledger["k0_sha256"], r.digest((self.root / "K0.json").read_bytes()))
        self.assertEqual(ledger["caps"], {
            "release_slots": 16, "cpu_ns": 300_000_000_000, "raw_bytes": 134_217_728,
            "case_cpu_ns_max": 30_000_000_000, "case_raw_bytes": CASE_RAW,
            "build_reserve_cpu_ns": 60_000_000_000, "planned_release_cpu_ns": 204_000_000_000,
            "headroom_cpu_ns": 36_000_000_000})
        self.assertEqual(ledger["build"]["cpu_ns_reserved"], 60_000_000_000)
        self.assertEqual(ledger["build"]["cpu_ns_observed"], 10_000_000_000)
        self.assertEqual(ledger["build"]["cpu_ns_charged"], 60_000_000_000)
        self.assertEqual(ledger["build"]["status"], "OK")
        self.assertEqual(ledger["build"]["reasons"], [])
        self.assertEqual(set(ledger["build"]["artefacts_sha256"]), {
            "supervisor", "inert", "compat2-inert", "fit-inert", "libc.so.6"})
        self.assertEqual(ledger["used"]["cpu_ns_charged"], 60_000_000_000)
        self.assertEqual(ledger["used"]["release_slots"], 0)
        self.assertEqual(ledger["used"]["workload_releases"], 0)
        self.assertEqual(ledger["used"]["raw_bytes_charged"], 0)
        self.assertEqual(ledger["rows"], [])
        self.assertIsNone(ledger["latch"])
        before = (self.root / "K2-LEDGER.json").read_bytes()
        code, text, err = self.init_ledger()
        self.assertEqual(code, 2, text + err)
        self.assertFalse(json.loads(text)["ledger_mutated"])
        self.assertEqual((self.root / "K2-LEDGER.json").read_bytes(), before)
        (self.root / "K2-LEDGER.json").unlink()
        code, text, err = self.init_ledger(61_000_000_000)
        self.assertEqual(code, 0, text + err)
        latched = r.read(self.root / "K2-LEDGER.json")
        self.assertEqual(latched["build"]["cpu_ns_charged"], 61_000_000_000)
        self.assertEqual(latched["build"]["status"], "INCOMPATIBLE_BUILD")
        self.assertEqual(latched["build"]["reasons"], ["build cpu above 60s reserve"])
        self.assertEqual(latched["latch"]["outcome"], "INCOMPATIBLE_BUILD")
        self.assertIsNone(latched["latch"]["case_id"])
        self.assertEqual(latched["rows"], [])
        for name, reason in (("supervisor", "supervisor pin mismatch"), ("libc.so.6", "libc pin mismatch")):
            (self.root / "K2-LEDGER.json").unlink()
            target = self.clone / "tools/dd1_linux/build" / name
            saved = target.read_bytes()
            target.write_bytes(b"wrong")
            code, text, err = self.init_ledger()
            body = r.read(self.root / "K2-LEDGER.json")
            self.assertEqual(body["build"]["status"], "INCOMPATIBLE_BUILD", text + err)
            self.assertIn(reason, body["build"]["reasons"])
            self.assertEqual(body["rows"], [])
            target.write_bytes(saved)
        fit_path = self.clone / "tools/dd1_linux/build" / "fit-inert"
        saved = fit_path.read_bytes()
        fit_path.unlink()
        (self.root / "K2-LEDGER.json").unlink()
        code, text, err = self.init_ledger()
        body = r.read(self.root / "K2-LEDGER.json")
        self.assertEqual(body["build"]["status"], "INCOMPATIBLE_BUILD")
        self.assertIsNone(body["build"]["artefacts_sha256"]["fit-inert"])
        self.assertIn("fit-inert pin mismatch", body["build"]["reasons"])
        fit_path.write_bytes(saved)
        (self.root / "K2-LEDGER.json").unlink()
        link_target = self.root / "elsewhere.json"
        link_target.write_bytes(b"untouched\n")
        (self.root / "K2-LEDGER.json").symlink_to(link_target)
        code, text, err = self.init_ledger()
        self.assertEqual(code, 2, text + err)
        self.assertFalse(json.loads(text)["ledger_mutated"])
        self.assertEqual(link_target.read_bytes(), b"untouched\n")
        self.assertTrue((self.root / "K2-LEDGER.json").is_symlink())
        listed = set(os.listdir(self.root))
        (self.root / "K2-LEDGER.json").unlink()
        code, text, err = self.invoke(["--head", HEAD, "--root", str(self.root), "--init-ledger"])
        self.assertEqual(code, 2, text + err)
        self.assertNotIn("K2-LEDGER.json", os.listdir(self.root))
        code, text, err = self.invoke(["--head", HEAD, "--root", str(self.root), "--init-ledger",
                                       "--build-cpu-ns", "-1", "--case", "KC01_STRICT_POSITIVE"])
        self.assertEqual(code, 2, text + err)
        self.assertNotIn("K2-LEDGER.json", set(os.listdir(self.root)) - listed)

    def test_ledger_cumulative_caps_across_cases(self):
        self.reset()
        controls._observed_cpu_ns = lambda: 0
        for row in controls.plan():
            with self.subTest(case_id=row["case_id"]):
                code, text, err, ledger = self.run_case(row["case_id"])
                current = ledger["rows"][-1]
                self.assertEqual(code, 0, text + err)
                self.assertEqual(current["classification"], "EXPECTED", (current["reasons"], err, text[-400:]))
        ledger = r.read(self.root / "K2-LEDGER.json")
        overhead = sum(max(0, row["cpu_ns_observed"] - row["cpu_ns_reserved"]) for row in ledger["rows"])
        self.assertEqual(ledger["used"]["release_slots"], 16)
        self.assertEqual(ledger["used"]["workload_releases"], 16)
        self.assertEqual(ledger["used"]["cpu_ns_charged"], 60_000_000_000 + 204_000_000_000 + overhead)
        self.assertEqual(ledger["used"]["raw_bytes_charged"], 134_217_728)
        self.assertIsNone(ledger["latch"])
        before = (self.root / "K2-LEDGER.json").read_bytes()
        code, text, err = self.invoke(["--head", HEAD, "--root", str(self.root), "--case", "KC01_STRICT_POSITIVE"])
        self.assertEqual(code, 2, text + err)
        self.assertEqual((self.root / "K2-LEDGER.json").read_bytes(), before)
        self.assertTrue(controls.reservation_fits(
            dict(release_slots=15, cpu_ns_charged=0, raw_bytes_charged=0), 12_000_000_000))
        self.assertFalse(controls.reservation_fits(
            dict(release_slots=16, cpu_ns_charged=0, raw_bytes_charged=0), 1))
        self.assertTrue(controls.reservation_fits(
            dict(release_slots=0, cpu_ns_charged=300_000_000_000 - 12_000_000_000, raw_bytes_charged=0),
            12_000_000_000))
        self.assertFalse(controls.reservation_fits(
            dict(release_slots=0, cpu_ns_charged=300_000_000_000 - 12_000_000_000 + 1, raw_bytes_charged=0),
            12_000_000_000))
        edge = 134_217_728 - CASE_RAW
        self.assertTrue(controls.reservation_fits(
            dict(release_slots=0, cpu_ns_charged=0, raw_bytes_charged=edge), 1))
        self.assertFalse(controls.reservation_fits(
            dict(release_slots=0, cpu_ns_charged=0, raw_bytes_charged=edge + 1), 1))
        self.assertFalse(controls.reservation_fits(
            dict(release_slots=16, cpu_ns_charged=264_000_000_000, raw_bytes_charged=0), 1))

    def test_ledger_reserve_is_durable_before_spawn(self):
        self.reset()
        seen = {}

        def spawn(head, root, case_id):
            ledger = r.read(Path(root) / "K2-LEDGER.json")
            seen["row"] = ledger["rows"][-1]
            seen["used"] = dict(ledger["used"])
            evidence = self.evidence(case_id)
            return Proc(json.dumps(evidence["z"]), evidence["exit"])

        controls.spawn = spawn
        controls.stage = lambda root, repo, row, head: self.lay_down(root, row, self.evidence(row["case_id"]))
        code, text, err = self.invoke(["--head", HEAD, "--root", str(self.root), "--case", "KC01_STRICT_POSITIVE"])
        self.assertEqual(code, 0, text + err)
        self.assertEqual(seen["row"]["state"], "RESERVED")
        self.assertEqual(seen["row"]["case_id"], "KC01_STRICT_POSITIVE")
        self.assertEqual(seen["row"]["g"], "SENT_OR_UNCERTAIN")
        self.assertEqual(seen["used"]["release_slots"], 1)
        self.assertEqual(seen["used"]["cpu_ns_charged"], 60_000_000_000 + 12_000_000_000)
        self.assertEqual(seen["used"]["raw_bytes_charged"], CASE_RAW)
        self.reset()
        before = (self.root / "K2-LEDGER.json").read_bytes()
        calls = {}

        def boom(path, value):
            if Path(path).name == "K2-LEDGER.json" and value.get("rows") and value["rows"][-1]["state"] == "RESERVED":
                raise RuntimeError("disk full")
            return self._write(path, value)

        r.atomic_write = boom
        controls.stage = lambda *args: calls.__setitem__("stage", True)
        controls.spawn = lambda *args: calls.__setitem__("spawn", True)
        code, text, err = self.invoke(["--head", HEAD, "--root", str(self.root), "--case", "KC01_STRICT_POSITIVE"])
        self.assertEqual(code, 2, text + err)
        self.assertFalse(calls)
        self.assertEqual((self.root / "K2-LEDGER.json").read_bytes(), before)
        body = json.loads(text)
        self.assertTrue(body["refused_before_g"])
        self.assertFalse(body["ledger_mutated"])
        self.assertIsInstance(body["cpu_ns"], int)
        r.atomic_write = self._write
        self.reset()
        ledger = r.read(self.root / "K2-LEDGER.json")
        ledger["rows"].append(controls.make_reserved_row(1, "KC02_READONLY_ESCAPE", 12_000_000_000))
        ledger["used"] = controls.recompute_used(ledger)
        r.atomic_write(self.root / "K2-LEDGER.json", ledger)
        called = {}
        original_run = entry._run_inert_unit
        entry._run_inert_unit = lambda *args, **kwargs: called.__setitem__("ran", True)
        fd = controls.acquire_lock(str(self.root))
        os.environ[controls.CONTROLLER] = "1"
        try:
            code, text, err = self.invoke(["--head", HEAD, "--root", str(self.root), "--case", "KC01_STRICT_POSITIVE"])
        finally:
            os.environ.pop(controls.CONTROLLER, None)
            os.close(fd)
            entry._run_inert_unit = original_run
        self.assertEqual(code, 2, text + err)
        self.assertIn("no durable K2 ledger reservation", text)
        self.assertNotIn("ran", called)

    def test_ledger_dangling_reserved_row_abandons_and_latches(self):
        self.reset()
        path = self.root / "K2-LEDGER.json"
        ledger = r.read(path)
        ledger["rows"].append(controls.make_reserved_row(1, "KC01_STRICT_POSITIVE", 12_000_000_000))
        ledger["used"] = controls.recompute_used(ledger)
        r.atomic_write(path, ledger)
        calls = {}
        controls.stage = lambda *args: calls.__setitem__("stage", True)
        code, text, err = self.invoke(["--head", HEAD, "--root", str(self.root), "--case", "KC02_READONLY_ESCAPE"])
        self.assertEqual(code, 2, text + err)
        self.assertNotIn("stage", calls)
        body = json.loads(text)
        self.assertTrue(body["ledger_mutated"])
        ledger = r.read(path)
        self.assertEqual(ledger["rows"][0]["state"], "ABANDONED")
        self.assertEqual(ledger["rows"][0]["reasons"], ["DANGLING_RESERVED_ROW"])
        self.assertEqual(ledger["rows"][0]["cpu_ns_charged"], 12_000_000_000)
        self.assertEqual(ledger["latch"]["outcome"], "INCONCLUSIVE")
        self.assertEqual(ledger["latch"]["case_id"], "KC01_STRICT_POSITIVE")
        before = path.read_bytes()
        code, text, err = self.invoke(["--head", HEAD, "--root", str(self.root), "--case", "KC03_CLONE3_FALLBACK"])
        self.assertEqual(code, 2, text + err)
        self.assertFalse(json.loads(text)["ledger_mutated"])
        self.assertEqual(path.read_bytes(), before)

    def test_ledger_no_refund(self):
        self.reset()
        controls._observed_cpu_ns = lambda: 0
        code, text, err, ledger = self.run_case("KC01_STRICT_POSITIVE")
        self.assertEqual(code, 0, text + err)
        row = ledger["rows"][-1]
        self.assertLess(row["cpu_ns_observed"], row["cpu_ns_reserved"])
        self.assertEqual(row["cpu_ns_charged"], row["cpu_ns_reserved"])
        controls._observed_cpu_ns = lambda: 20_000_000_000
        code, text, err, ledger = self.run_case("KC02_READONLY_ESCAPE")
        self.assertEqual(code, 0, text + err)
        row = ledger["rows"][-1]
        self.assertGreater(row["cpu_ns_observed"], row["cpu_ns_reserved"])
        self.assertEqual(row["cpu_ns_charged"], 20_000_000_000)
        self.reset()
        path = self.root / "K2-LEDGER.json"
        ledger = r.read(path)
        ledger["rows"].append(controls.make_reserved_row(1, "KC03_CLONE3_FALLBACK", 10_000_000_000))
        ledger["used"] = controls.recompute_used(ledger)
        r.atomic_write(path, ledger)
        self.invoke(["--head", HEAD, "--root", str(self.root), "--case", "KC04_STRICT_THREAD_CEILING"])
        abandoned = r.read(path)["rows"][0]
        self.assertEqual(abandoned["state"], "ABANDONED")
        self.assertEqual(abandoned["cpu_ns_charged"], 10_000_000_000)
        self.assertEqual(abandoned["raw_bytes_charged"], CASE_RAW)
        self.reset()
        controls._observed_cpu_ns = lambda: 0

        def stage(root, repo, row, head):
            evidence = self.evidence(row["case_id"])
            where, unit, account = self.lay_down(root, row, evidence)
            r.atomic_write(account, dict(recovery=dict(unit_reservations_v2=[])))
            return where, unit, account

        controls.stage = stage
        controls.spawn = lambda head, root, case_id: Proc(json.dumps({"pre_release_error": "nope"}), 2)
        code, text, err = self.invoke(["--head", HEAD, "--root", str(self.root), "--case", "KC01_STRICT_POSITIVE"])
        self.assertEqual(code, 0, text + err)
        ledger = r.read(path)
        self.assertEqual(ledger["rows"][-1]["g"], "NOT_SENT")
        self.assertEqual(ledger["rows"][-1]["classification"], "INCONCLUSIVE")
        self.assertEqual(ledger["used"]["workload_releases"], 0)
        self.assertEqual(ledger["used"]["release_slots"], 1)
        self.assertEqual(ledger["rows"][-1]["cpu_ns_charged"], 12_000_000_000)
        self.assertEqual(ledger["rows"][-1]["raw_bytes_charged"], CASE_RAW)
        self.assertEqual(ledger["latch"]["outcome"], "INCONCLUSIVE")

    def test_ledger_stop_latch_after_unexpected(self):
        def bad_exit(case_id):
            evidence = self.evidence(case_id)
            evidence["exit"] = 1
            return evidence

        self.reset()
        code, text, err, ledger = self.run_case("KC01_STRICT_POSITIVE", bad_exit)
        self.assertEqual(ledger["rows"][-1]["classification"], "INCOMPATIBLE", text + err)
        self.assertEqual(ledger["latch"]["outcome"], "INCOMPATIBLE")
        self.assertEqual(ledger["latch"]["case_id"], "KC01_STRICT_POSITIVE")
        before = (self.root / "K2-LEDGER.json").read_bytes()
        calls = {}
        controls.stage = lambda *args: calls.__setitem__("stage", True)
        code, text, err = self.invoke(["--head", HEAD, "--root", str(self.root), "--case", "KC02_READONLY_ESCAPE"])
        self.assertEqual(code, 2, text + err)
        self.assertNotIn("stage", calls)
        self.assertEqual((self.root / "K2-LEDGER.json").read_bytes(), before)
        self.assertEqual(r.read(self.root / "K2-LEDGER.json")["latch"]["outcome"], "INCOMPATIBLE")

        self.reset()
        controls.stage = lambda root, repo, row, head: self.lay_down(root, row, self.evidence(row["case_id"]))
        controls.spawn = lambda head, root, case_id: Proc("not-json", 2)
        code, text, err = self.invoke(["--head", HEAD, "--root", str(self.root), "--case", "KC03_CLONE3_FALLBACK"])
        ledger = r.read(self.root / "K2-LEDGER.json")
        self.assertEqual(ledger["rows"][-1]["classification"], "INCONCLUSIVE", text + err)
        self.assertEqual(ledger["latch"]["outcome"], "INCONCLUSIVE")
        before = (self.root / "K2-LEDGER.json").read_bytes()
        code, text, err = self.invoke(["--head", HEAD, "--root", str(self.root), "--case", "KC04_STRICT_THREAD_CEILING"])
        self.assertEqual(code, 2)
        self.assertEqual((self.root / "K2-LEDGER.json").read_bytes(), before)

        self.reset()
        code, text, err, ledger = self.run_case("KC05_CPU_EXHAUST")
        self.assertEqual(ledger["rows"][-1]["classification"], "EXPECTED", text + err)
        self.assertIsNone(ledger["latch"])

        def segv(case_id):
            evidence = self.evidence(case_id)
            evidence["z"] = dict(evidence["z"])
            evidence["z"]["success"] = False
            evidence["z"]["supervisor_report"] = dict(evidence["z"]["supervisor_report"])
            evidence["z"]["supervisor_report"]["signal"] = 11
            evidence["row"] = dict(evidence["row"])
            evidence["row"]["state"] = "FAILED"
            return evidence

        self.reset()
        code, text, err, ledger = self.run_case("KC15_IA32_REACHABILITY", segv)
        self.assertEqual(ledger["rows"][-1]["classification"], "NOT_REACHABLE_ON_HOST", (text, err))
        self.assertIsNone(ledger["latch"])
        kind, reasons = controls.apply_audits("EXPECTED", [], CASE_RAW + 1, 1, 1)
        self.assertEqual(kind, "INCOMPATIBLE")
        self.assertIn("CASE_EVIDENCE_OVER_8MIB", reasons)
        kind, reasons = controls.apply_audits("EXPECTED", [], 1, 300_000_000_001, 1)
        self.assertEqual(kind, "INCONCLUSIVE")
        self.assertIn("OPERATION_CPU_OVER_CAP", reasons)
        kind, reasons = controls.apply_audits("EXPECTED", [], 1, 1, 134_217_729)
        self.assertEqual(kind, "INCONCLUSIVE")
        self.assertIn("OPERATION_RETAINED_OVER_128MIB", reasons)
        kind, reasons = controls.apply_audits("INCOMPATIBLE", ["predicate"], CASE_RAW + 1, 300_000_000_001, 1)
        self.assertEqual(kind, "INCOMPATIBLE")
        self.assertIn("predicate", reasons)
        self.assertIn("OPERATION_CPU_OVER_CAP", reasons)

    def test_ledger_missing_or_corrupt_refuses_without_mutation(self):
        def unchanged(prepare, case_id="KC01_STRICT_POSITIVE"):
            self.reset()
            path = self.root / "K2-LEDGER.json"
            prepare(path)
            snapshot = path.read_bytes() if path.is_file() and not path.is_symlink() else None
            link = os.readlink(path) if path.is_symlink() else None
            calls = {}
            controls.stage = lambda *args: calls.__setitem__("stage", True)
            controls.spawn = lambda *args: calls.__setitem__("spawn", True)
            code, text, err = self.invoke(["--head", HEAD, "--root", str(self.root), "--case", case_id])
            self.assertEqual(code, 2, text + err)
            self.assertFalse(calls, text + err)
            if link is not None:
                self.assertTrue(path.is_symlink())
                self.assertEqual(os.readlink(path), link)
            elif snapshot is None:
                self.assertFalse(path.exists())
            else:
                self.assertEqual(path.read_bytes(), snapshot)

        def rewrite(mutate, case_id="KC01_STRICT_POSITIVE"):
            def prepare(path):
                ledger = r.read(path)
                mutate(ledger)
                r.atomic_write(path, ledger)
            unchanged(prepare, case_id)

        unchanged(lambda path: path.unlink())
        unchanged(lambda path: (path.unlink(), path.symlink_to(self.root / "K0.json")))
        unchanged(lambda path: path.write_bytes(b"{"))
        unchanged(lambda path: path.write_bytes(b'{"schema":"a","schema":"b"}\n'))
        unchanged(lambda path: path.write_bytes(b'{"schema": NaN}\n'))
        rewrite(lambda ledger: ledger.__setitem__("schema", "OTHER"))
        rewrite(lambda ledger: ledger.__setitem__("operation", "OTHER"))
        rewrite(lambda ledger: ledger.__setitem__("selection_comment", 5827591001))
        rewrite(lambda ledger: ledger["window"].__setitem__("start_utc", "2026-09-25T05:57:00Z"))
        rewrite(lambda ledger: ledger["window"].__setitem__("deadline_unix", 1))
        rewrite(lambda ledger: ledger["caps"].__setitem__("release_slots", 15))
        rewrite(lambda ledger: ledger.__setitem__("head", "b" * 40))
        rewrite(lambda ledger: ledger.__setitem__("k0_sha256", "0" * 64))
        rewrite(lambda ledger: ledger.__setitem__("extra", 1))
        rewrite(lambda ledger: ledger["rows"].append(dict(
            controls.make_reserved_row(1, "KC01_STRICT_POSITIVE", 12_000_000_000), extra=1)) or ledger.__setitem__(
            "used", controls.recompute_used(ledger)))

        def used_off(key):
            def mutate(ledger):
                ledger["used"][key] += 1
            rewrite(mutate)
        for key in ("release_slots", "workload_releases", "cpu_ns_charged", "raw_bytes_charged", "raw_bytes_observed"):
            used_off(key)

        def reserved_not_last(ledger):
            ledger["rows"] = [
                controls.make_reserved_row(1, "KC01_STRICT_POSITIVE", 12_000_000_000),
                dict(seq=2, case_id="KC02_READONLY_ESCAPE", state="FINAL", g="SENT_OR_UNCERTAIN",
                     cpu_ns_reserved=12_000_000_000, cpu_ns_observed=0, cpu_ns_charged=12_000_000_000,
                     raw_bytes_reserved=CASE_RAW, raw_bytes_observed=0, raw_bytes_charged=CASE_RAW,
                     reserved_utc=controls.stamp(), finished_utc=controls.stamp(), classification="EXPECTED",
                     reasons=[], record_sha256="ab" * 32)]
            ledger["used"] = controls.recompute_used(ledger)
        rewrite(reserved_not_last, "KC16_NESTED_NAMESPACE_DENY")

        def two_stops(ledger):
            rows = []
            for index, case_id, cap in ((1, "KC01_STRICT_POSITIVE", 12_000_000_000), (2, "KC02_READONLY_ESCAPE", 12_000_000_000)):
                rows.append(dict(seq=index, case_id=case_id, state="FINAL", g="SENT_OR_UNCERTAIN",
                                 cpu_ns_reserved=cap, cpu_ns_observed=0, cpu_ns_charged=cap,
                                 raw_bytes_reserved=CASE_RAW, raw_bytes_observed=0, raw_bytes_charged=CASE_RAW,
                                 reserved_utc=controls.stamp(), finished_utc=controls.stamp(),
                                 classification="INCOMPATIBLE", reasons=["x"], record_sha256="cd" * 32))
            ledger["rows"] = rows
            ledger["latch"] = None
            ledger["used"] = controls.recompute_used(ledger)
        rewrite(two_stops, "KC16_NESTED_NAMESPACE_DENY")

        def null_latch(ledger):
            ledger["rows"] = [dict(seq=1, case_id="KC01_STRICT_POSITIVE", state="FINAL", g="SENT_OR_UNCERTAIN",
                                   cpu_ns_reserved=12_000_000_000, cpu_ns_observed=0, cpu_ns_charged=12_000_000_000,
                                   raw_bytes_reserved=CASE_RAW, raw_bytes_observed=0, raw_bytes_charged=CASE_RAW,
                                   reserved_utc=controls.stamp(), finished_utc=controls.stamp(),
                                   classification="INCOMPATIBLE", reasons=["x"], record_sha256="ef" * 32)]
            ledger["latch"] = None
            ledger["used"] = controls.recompute_used(ledger)
        rewrite(null_latch, "KC16_NESTED_NAMESPACE_DENY")

        durable = self.clone
        body = self.k0_body(durable, durable, HEAD)
        r.atomic_write(durable / "K0.json", body)
        (durable / "LOCK").write_bytes(b"")
        planted = durable / "K2-LEDGER.json"
        planted.write_bytes(b"keep\n")
        calls = {}
        controls.stage = lambda *args: calls.__setitem__("stage", True)
        code, text, err = self.invoke(["--head", HEAD, "--root", str(durable), "--case", "KC01_STRICT_POSITIVE"])
        self.assertEqual(code, 2, text + err)
        self.assertNotIn("stage", calls)
        self.assertEqual(planted.read_bytes(), b"keep\n")

    def test_ledger_no_case_rerun(self):
        path = self.root / "K2-LEDGER.json"
        self.reset()
        self.run_case("KC01_STRICT_POSITIVE")
        before = path.read_bytes()
        calls = {}
        controls.stage = lambda *args: calls.__setitem__("stage", True)
        code, text, err = self.invoke(["--head", HEAD, "--root", str(self.root), "--case", "KC01_STRICT_POSITIVE"])
        self.assertEqual(code, 2, text + err)
        self.assertNotIn("stage", calls)
        self.assertEqual(path.read_bytes(), before)
        self.reset()
        controls.spawn = lambda *args: Proc("not-json", 2)
        controls.stage = lambda root, repo, row, head: self.lay_down(root, row, self.evidence(row["case_id"]))
        self.invoke(["--head", HEAD, "--root", str(self.root), "--case", "KC02_READONLY_ESCAPE"])
        before = path.read_bytes()
        calls.clear()
        controls.stage = lambda *args: calls.__setitem__("stage", True)
        code, text, err = self.invoke(["--head", HEAD, "--root", str(self.root), "--case", "KC02_READONLY_ESCAPE"])
        self.assertEqual(code, 2, text + err)
        self.assertEqual(path.read_bytes(), before)
        self.reset()
        ledger = r.read(path)
        ledger["rows"].append(controls.make_reserved_row(1, "KC03_CLONE3_FALLBACK", 10_000_000_000))
        ledger["used"] = controls.recompute_used(ledger)
        r.atomic_write(path, ledger)
        self.invoke(["--head", HEAD, "--root", str(self.root), "--case", "KC04_STRICT_THREAD_CEILING"])
        before = path.read_bytes()
        calls.clear()
        controls.stage = lambda *args: calls.__setitem__("stage", True)
        code, text, err = self.invoke(["--head", HEAD, "--root", str(self.root), "--case", "KC03_CLONE3_FALLBACK"])
        self.assertEqual(code, 2, text + err)
        self.assertNotIn("stage", calls)
        self.assertEqual(path.read_bytes(), before)
        self.reset()
        (self.root / "dd1-kernel-compat-1" / "KC05_CPU_EXHAUST").mkdir(parents=True)
        before = path.read_bytes()
        calls.clear()
        controls.stage = lambda *args: calls.__setitem__("stage", True)
        code, text, err = self.invoke(["--head", HEAD, "--root", str(self.root), "--case", "KC05_CPU_EXHAUST"])
        self.assertEqual(code, 2, text + err)
        self.assertNotIn("stage", calls)
        self.assertEqual(path.read_bytes(), before)

    def test_g_evidence_rule(self):
        case_id = "KC01_STRICT_POSITIVE"
        self.assertEqual(controls.g_evidence(None, case_id), "SENT_OR_UNCERTAIN")
        self.assertEqual(controls.g_evidence({"recovery": {"unit_reservations_v2": []}}, case_id), "NOT_SENT")
        self.assertEqual(controls.g_evidence(
            {"recovery": {"unit_reservations_v2": [{"unit_id": case_id}]}}, case_id), "NOT_SENT")
        self.assertEqual(controls.g_evidence(
            {"recovery": {"unit_reservations_v2": [{"unit_id": case_id, "processes": {"controller": {}}}]}},
            case_id), "SENT_OR_UNCERTAIN")

    def test_classify_expected_vs_stop(self):
        ids = [row["case_id"] for row in controls.plan()]
        for case_id in ids:
            with self.subTest(case_id=case_id, kind="expected"):
                kind, reasons = controls.classify(case_id, self.evidence(case_id))
                self.assertEqual(kind, "EXPECTED", reasons)
            with self.subTest(case_id=case_id, kind="contradiction"):
                bad = self.evidence(case_id)
                if case_id == "KC09_CONTROLLER_KILL":
                    bad["exit"] = 0
                else:
                    bad["exit"] = 1
                self.assertEqual(controls.classify(case_id, bad)[0], "INCOMPATIBLE")
            with self.subTest(case_id=case_id, kind="missing"):
                missing = self.evidence(case_id)
                if case_id == "KC09_CONTROLLER_KILL":
                    missing["row"] = dict(missing["row"])
                    missing["row"].pop("state")
                else:
                    missing["z"] = dict(missing["z"])
                    missing["z"].pop("cleanup_confirmed")
                self.assertEqual(controls.classify(case_id, missing)[0], "INCONCLUSIVE")
            if case_id == "KC15_IA32_REACHABILITY":
                continue
            other = self.evidence(case_id)
            other["z"] = dict(other["z"])
            report = dict(other["z"].get("supervisor_report") or {})
            report["signal"] = 11
            other["z"]["supervisor_report"] = report
            other["z"]["success"] = False
            if isinstance(other["row"], dict) and case_id != "KC09_CONTROLLER_KILL":
                other["row"] = dict(other["row"])
                other["row"]["state"] = "FAILED"
            self.assertNotEqual(controls.classify(case_id, other)[0], "NOT_REACHABLE_ON_HOST")
        segv = self.evidence("KC15_IA32_REACHABILITY")
        segv["z"] = dict(segv["z"])
        segv["z"]["success"] = False
        segv["z"]["supervisor_report"] = dict(segv["z"]["supervisor_report"], signal=11)
        segv["row"] = dict(segv["row"], state="FAILED")
        self.assertEqual(controls.classify("KC15_IA32_REACHABILITY", segv)[0], "NOT_REACHABLE_ON_HOST")
        exited = self.evidence("KC15_IA32_REACHABILITY")
        exited["exit"] = 32
        self.assertEqual(controls.classify("KC15_IA32_REACHABILITY", exited)[0], "INCOMPATIBLE")
        self.assertEqual(controls.classify("KC15_IA32_REACHABILITY", self.evidence("KC15_IA32_REACHABILITY"))[0], "EXPECTED")

    def test_k0_reverified_record(self):
        loaded = controls.load_k0(str(self.root), HEAD)
        self.assertEqual(loaded["selection_comment"], 5845725453)
        self.assertEqual(loaded["clone"]["head"], HEAD)

        def rejects(mutate, head=HEAD):
            raw = (self.root / "K0.json").read_bytes()
            body = r.read(self.root / "K0.json")
            mutate(body)
            r.atomic_write(self.root / "K0.json", body)
            try:
                with redirect_stdout(io.StringIO()), self.assertRaises(SystemExit):
                    controls.load_k0(str(self.root), head)
            finally:
                (self.root / "K0.json").write_bytes(raw)

        rejects(lambda body: body.__setitem__("selection_comment", 5827591001))
        rejects(lambda body: body.update(selection_timestamp_utc="2026-09-25T05:57:00Z",
                                         deadline_utc="2026-09-26T05:57:00Z"))
        rejects(lambda body: body["lock"].__setitem__("acquired_at_utc", "2026-09-25T05:57:00Z"))
        rejects(lambda body: body["clone"].__setitem__("head", BASE_HEAD))
        rejects(lambda body: body["clone"].__setitem__("head", BASE_HEAD), head=BASE_HEAD)
        rejects(lambda body: body["helper"].__setitem__("baseline_sha256", "0" * 64))
        rejects(lambda body: body["helper_sources_sha256"].__setitem__("res://extra.py", "1" * 64))
        rejects(lambda body: body["helper_sources_sha256"].__setitem__(
            next(iter(body["helper_sources_sha256"])), "2" * 64))
        rejects(lambda body: body["counters"].__setitem__("workload_releases", 1))
        rejects(lambda body: body.__setitem__("extra", 1))
        rejects(lambda body: body["host"].__setitem__("boot_id_sha256", "d" * 64))

    def test_kc02_staging_binds_escape_input(self):
        fake = self.root / "escape-clone"
        names = snap.HELPER_SOURCES | {"res://tools/dd1_linux/inert.c"}
        for name in names:
            dest = fake / name[6:]
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(b"src:" + name.encode())
        build = fake / "tools/dd1_linux/build"
        build.mkdir(parents=True)
        (build / "supervisor").write_bytes(b"SUP")
        (build / "inert").write_bytes(b"INERT")

        def snapshot(tree):
            found = {}
            for dirpath, _dirs, files in os.walk(tree):
                for name in files:
                    path = Path(dirpath) / name
                    found[str(path.relative_to(tree))] = path.read_bytes()
            return found

        before = snapshot(fake)
        where, unit, _account = controls.stage(str(self.root), fake, controls.row_for("KC02_READONLY_ESCAPE"), HEAD)
        self.assertEqual(unit["argv"][0], "/workload")
        self.assertEqual(unit["argv"][1], "escape")
        self.assertEqual(len(unit["argv"]), 3)
        self.assertEqual(Path(unit["argv"][2]), where / "source" / "input")
        self.assertEqual(unit["source_files"]["res://input"], r.digest(b"IMMUTABLE\n"))
        self.assertEqual((where / "source" / "input").read_bytes(), b"IMMUTABLE\n")
        meta = r.read(where / "paths.json")
        self.assertEqual(Path(meta["repo"]), where / "source")
        self.assertEqual(snapshot(fake), before)
        self.assertIn("repo=None", inspect.getsource(controls.build_compat))
        self.assertIn("repo=None", inspect.getsource(controls.build_fit))

    def test_fixed_clock_window_refusal(self):
        self.reset()
        before = (self.root / "K2-LEDGER.json").read_bytes()
        FrozenClock.instant = AT_DEADLINE
        calls = {}
        controls.stage = lambda *args: calls.__setitem__("stage", True)
        code, text, err = self.invoke(["--head", HEAD, "--root", str(self.root), "--case", "KC01_STRICT_POSITIVE"])
        self.assertEqual(code, 2, text + err)
        self.assertIn("outside selected window", text)
        self.assertFalse(json.loads(text)["ledger_mutated"])
        self.assertNotIn("stage", calls)
        self.assertEqual((self.root / "K2-LEDGER.json").read_bytes(), before)
        FrozenClock.instant = INSIDE

    def test_malformed_disposition_rejects_as_reservation_error(self):
        qualified = unit(mode="engineering", qualification={"status": "QUALIFIED", "mode": "engineering"})
        for raw in (b"not json", b"[]", b"{}", b"\xff"):
            expected = dict(roles={"kernel_qualification_disposition": {"locator": "role", "sha256": r.digest(raw)}},
                            receipt_authorities={})
            with self.assertRaises(r.ReservationError):
                kq.native_bindings(qualified, expected, Ctx({"role": raw}))
        bare = unit(mode="engineering", qualification={"status": "QUALIFIED", "mode": "engineering"})
        bare["kernel_qualification"] = ["not-a-dict"]
        with self.assertRaises(r.ReservationError):
            kq.native_bindings(bare, {"roles": {}}, Ctx({}))


if __name__ == "__main__":
    unittest.main(verbosity=2)
