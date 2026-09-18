"""Real harmless-process controls for B1. No OS mocks, engine or live account.

Run with python -I -S tools/dd1_linux/test_backend.py. DD1_B1_OUTPUT may name a
new evidence directory; complete bounded records, not test counts alone, persist.
"""
import base64
from copy import deepcopy
import ctypes
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(REPO / "tools"))
import inert_cases as fixture
import dd1_reservations as r

RECORDS = []
OUTPUT = Path(os.environ["DD1_B1_OUTPUT"]).resolve() if os.environ.get("DD1_B1_OUTPUT") else None


def bytes_record(raw):
    return dict(bytes=len(raw), sha256=r.digest(raw), base64=base64.b64encode(raw).decode())


def reap_extra():
    records = []
    end = time.monotonic() + 3
    while time.monotonic() < end:
        try:
            pid, status, usage = os.wait4(-1, os.WNOHANG)
        except ChildProcessError:
            return records
        if pid:
            records.append(dict(pid=pid, status=status, cpu_seconds=usage.ru_utime + usage.ru_stime))
        else:
            time.sleep(.01)
    raise AssertionError("a process survives cleanup")


class BackendTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Test driver adopts descendants when deliberately killing the controller.
        if ctypes.CDLL(None).prctl(36, 1, 0, 0, 0) != 0:
            raise RuntimeError("test driver subreaper unavailable")

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="dd1-b1-inert-")
        self.root = Path(self.tmp.name).resolve()
        self.children = []

    def tearDown(self):
        for child in self.children:
            if child.poll() is None:
                child.kill(); child.communicate(timeout=5)
        reap_extra()
        self.tmp.cleanup()

    def case(self, name, mode="positive", repo=REPO, **kw):
        root = self.root / name; root.mkdir()
        unit = fixture.case(root, repo, mode, **kw)
        return root, unit

    def launch(self, root, repo=REPO, pass_fds=()):
        cmd = [sys.executable, "-I", "-S", str(HERE / "inert_entry.py"), str(root), str(repo)]
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, pass_fds=pass_fds)
        proc.dd1_inputs = dict(demand=r.read(root / "demand.json"), receipt=r.read(root / "receipt.json"))
        self.children.append(proc)
        return proc, cmd

    def finish(self, root, proc, cmd, before, extra=None):
        out, err = proc.communicate(timeout=10)
        adopted = reap_extra()
        self.assertLessEqual(len(out) + len(err), 16384)
        account = r.read(root / "ACCOUNT.json")
        records = account["recovery"].get("unit_reservations_v2", [])
        processes = records[-1].get("processes", {}) if records else {}
        for item in processes.values():
            self.assertFalse((Path("/proc") / str(item["pid"])).exists(), "PID survived")
        files = {}
        capture = root / "result/capture"
        if capture.exists():
            for p in capture.rglob("*"):
                if p.is_symlink():
                    files[str(p.relative_to(capture))] = {"symlink": os.readlink(p)}
                elif p.is_file():
                    self.assertLessEqual(p.stat().st_size, 65536)
                    files[str(p.relative_to(capture))] = bytes_record(p.read_bytes())
        # No post-cleanup writes. This is a liveness check, not the raw meter.
        sizes = {str(p): p.stat().st_size for p in capture.rglob("*") if p.is_file() and not p.is_symlink()} if capture.exists() else {}
        time.sleep(.03)
        self.assertEqual(sizes, {str(p): p.stat().st_size for p in capture.rglob("*") if p.is_file() and not p.is_symlink()} if capture.exists() else {})
        record = dict(name=root.name, command=cmd, controller_exit=proc.returncode,
            controller_stdout=bytes_record(out), controller_stderr=bytes_record(err),
            demand=proc.dd1_inputs["demand"], receipt=proc.dd1_inputs["receipt"],
            account_before=before, account_after=account, files=files,
            adopted_by_test_driver=adopted, recorded_pids_absent=True, output_stable_after_cleanup=True, extra=extra)
        record["control_files"] = {name: bytes_record((root / "result" / name).read_bytes())
            for name in ("UNIT-GRANT.json", "UNIT-RESULT.json") if (root / "result" / name).exists()}
        if (root / "returned.json").exists():
            record["returned"] = r.read(root / "returned.json")
        RECORDS.append(record)
        return record

    def run_case(self, root, repo=REPO):
        before = r.read(root / "ACCOUNT.json")
        proc, cmd = self.launch(root, repo)
        return self.finish(root, proc, cmd, before)

    def rejected(self, root, fragment, repo=REPO):
        before = (root / "ACCOUNT.json").read_bytes()
        record = self.run_case(root, repo)
        self.assertEqual(record["controller_exit"], 2)
        output = base64.b64decode(record["controller_stdout"]["base64"]).decode()
        self.assertIn(fragment, output)
        self.assertEqual((root / "ACCOUNT.json").read_bytes(), before)
        self.assertFalse((root / "result").exists())
        return record

    def report(self, record):
        self.assertIn("returned", record)
        result = record["returned"]
        self.assertTrue(result["cleanup_confirmed"])
        self.assertFalse(result["native_qualified"])
        self.assertFalse(result["n0_accepted"])
        u = record["demand"]; charge = result["charged"]
        self.assertEqual(charge["starts"], u["contained_starts"] + 1)
        self.assertEqual(charge["cpu_ns"], u["cpu_seconds"] * 10**9)
        self.assertEqual(charge["raw_bytes"], u["raw_bytes"])
        self.assertEqual(record["account_before"]["historical"], record["account_after"]["historical"])
        for k, v in record["account_before"]["recovery"].items():
            self.assertEqual(v, record["account_after"]["recovery"][k])
        return result["supervisor_report"]

    def test_threaded_atomic_save_positive(self):
        root, _ = self.case("positive")
        rec = self.run_case(root); report = self.report(rec)
        self.assertEqual(rec["controller_exit"], 0)
        self.assertEqual(report["thread_births_including_main"], 3)
        self.assertEqual(report["execs"], 1)
        self.assertEqual(base64.b64decode(rec["files"]["save.json"]["base64"]), b'{"v":2}\n')
        self.assertEqual(base64.b64decode(rec["files"]["stderr.bin"]["base64"]), b'ERR\n')
        self.assertIn(b'OK SAVE THREADS', base64.b64decode(rec["files"]["stdout.bin"]["base64"]))

    def test_pinned_dynamic_runtime_and_missing_dependencies(self):
        root, unit = self.case("dynamic")
        def runtime(name):
            path = "tools/dd1_linux/build/" + name
            return dict(path=path, sha256=r.digest((REPO / path).read_bytes()), executable=True)
        unit["linux"]["runtime"] = {"/workload": runtime("inert-dynamic"),
            "/lib64/ld-linux-x86-64.so.2": runtime("ld-linux-x86-64.so.2"),
            "/lib/x86_64-linux-gnu/libc.so.6": runtime("libc.so.6")}
        fixture.sign(root, unit)
        rec = self.run_case(root); self.report(rec)
        self.assertEqual(rec["controller_exit"], 0)
        for missing in ("/lib64/ld-linux-x86-64.so.2", "/lib/x86_64-linux-gnu/libc.so.6"):
            other, demand = self.case("missing-" + Path(missing).name)
            demand["linux"]["runtime"] = deepcopy(unit["linux"]["runtime"])
            del demand["linux"]["runtime"][missing]
            fixture.sign(other, demand)
            self.rejected(other, "unbound interpreter" if "ld-linux" in missing else "unbound runtime dependency")

    def test_aggregate_cpu_and_wall_blocked_io(self):
        for mode in ("cpu", "blocked_io"):
            with self.subTest(mode=mode):
                root, _ = self.case(mode, mode, wall_seconds=2)
                rec = self.run_case(root); report = self.report(rec)
                self.assertEqual(rec["controller_exit"], 1)
                self.assertEqual(report["signal"], signal.SIGKILL)
                if mode == "cpu":
                    self.assertEqual(report["thread_births_including_main"], 3)
                    self.assertGreaterEqual(report["workload_cpu_seconds"], .9)
                    self.assertLess(report["workload_cpu_seconds"], 2)
                else:
                    self.assertEqual(report["stop_signal"], signal.SIGALRM)

    def test_repeated_and_competing_writes_reach_budget_guard(self):
        for mode in ("overwrites", "race"):
            with self.subTest(mode=mode):
                root, _ = self.case(mode, mode)
                rec = self.run_case(root); report = self.report(rec)
                self.assertEqual(rec["controller_exit"], 1)
                self.assertEqual(report["last_denied_syscall"], 18)  # x86-64 pwrite64
                self.assertEqual(report["reserved_before_writes"], report["raw_cap"])
                self.assertLess(sum(x.get("bytes", 0) for x in rec["files"].values()), report["raw_cap"])

    def test_forbidden_process_and_alternative_output_paths(self):
        modes = dict(fork=57, vfork=58, clone=56, exec=59, execveat=322, socket=41, namespace=272,
            writev=20, pwritev=296, pwritev2=328, shared_mmap=9, shared_then_mprotect=9,
            truncate=77, sendfile=40, splice=275, copy_file_range=326, io_uring=425, aio=206, mknod=133, mknodat=259, thread_limit=56)
        for mode, number in modes.items():
            with self.subTest(mode=mode):
                root, _ = self.case(mode, mode)
                rec = self.run_case(root); report = self.report(rec)
                self.assertEqual(rec["controller_exit"], 1)
                self.assertEqual(report["last_denied_syscall"], number)
                self.assertEqual(report["execs"], 1)
                self.assertEqual(report["thread_births_including_main"], 4 if mode == "thread_limit" else 1)
        for mode in ("abi", "ia32"):
            root, _ = self.case(mode, mode)
            rec = self.run_case(root); report = self.report(rec)
            # x32 hits the filter KILL branch. This host does not provide an
            # int-0x80 ABI: its instruction faults before that branch; record
            # this separately, never as a tested seccomp arch mismatch.
            self.assertEqual(report["signal"], signal.SIGSYS if mode == "abi" else signal.SIGSEGV)
            if mode == "ia32": rec["alternate_abi_limit"] = "host int-0x80 SIGSEGV; seccomp arch guard source-only"
        root, _ = self.case("clone3", "clone3")
        rec = self.run_case(root); report = self.report(rec)
        self.assertGreaterEqual(report["clone3_denied"], 1)
        self.assertEqual(report["thread_births_including_main"], 1)
        self.assertIn(b'errno=38', base64.b64decode(rec["files"]["stdout.bin"]["base64"]))

    def wait_live(self, root, proc):
        end = time.monotonic() + 4
        while time.monotonic() < end:
            rows = r.read(root / "ACCOUNT.json")["recovery"].get("unit_reservations_v2", [])
            stream = root / "result/capture/stdout.bin"
            if rows and "processes" in rows[-1] and stream.exists() and stream.stat().st_size:
                return rows[-1]
            self.assertIsNone(proc.poll(), "controller failed before live adverse control")
            time.sleep(.01)
        self.fail("did not reach actual running workload")

    def test_real_signals_cleanup_and_charges(self):
        for target, sig in (("supervisor", signal.SIGTERM), ("supervisor", signal.SIGKILL),
                ("supervisor", signal.SIGSTOP), ("controller", signal.SIGTERM), ("controller", signal.SIGKILL)):
            with self.subTest(target=target, signal=sig):
                root, unit = self.case(target + "-" + str(int(sig)), "linger", wall_seconds=2)
                before = r.read(root / "ACCOUNT.json")
                proc, cmd = self.launch(root)
                row = self.wait_live(root, proc)
                target_pid = row["processes"][target]["pid"]
                os.kill(target_pid, sig)
                rec = self.finish(root, proc, cmd, before, dict(signal=int(sig), target=target, pid=target_pid))
                self.assertNotEqual(rec["controller_exit"], 0)
                self.assertEqual(r.totals(rec["account_after"])["starts"], 2041)
                if target == "controller" and sig == signal.SIGKILL:
                    self.assertEqual(rec["account_after"]["recovery"]["unit_reservations_v2"][-1]["state"], "RESERVED")
                    unit.update(unit_id="new-after-crash", account_sha256=r.digest((root / "ACCOUNT.json").read_bytes()))
                    fixture.sign(root, unit)
                    # Remove no records/output: use an alternate requested output by moving old output for this test only.
                    (root / "result").rename(root / "retained-result")
                    self.rejected(root, "unresolved prior workload")
                    old_totals = r.totals(r.read(root / "ACCOUNT.json"))
                    reconciliation = r.reconcile_stale(root / "ACCOUNT.json")
                    self.assertEqual(reconciliation["totals"], old_totals)
                    self.assertFalse(reconciliation["launch_permitted"])
                    rec["stale_reconciliation"] = reconciliation
                else:
                    self.report(rec)

    def test_concurrent_and_duplicate_units_deny_at_intended_guard(self):
        root, unit = self.case("concurrent", "linger", wall_seconds=3)
        before = r.read(root / "ACCOUNT.json")
        proc, cmd = self.launch(root); row = self.wait_live(root, proc)
        # Test the same lock with real second process; stale hash is updated so it is not the tested guard.
        unit.update(unit_id="second", account_sha256=r.digest((root / "ACCOUNT.json").read_bytes()))
        fixture.sign(root, unit)
        second, _ = self.launch(root)
        out, err = second.communicate(timeout=5)
        self.assertEqual(second.returncode, 2)
        self.assertIn(b'one executor already holds account', out)
        os.kill(row["processes"]["supervisor"]["pid"], signal.SIGTERM)
        rec = self.finish(root, proc, cmd, before, dict(second_stdout=bytes_record(out), second_stderr=bytes_record(err)))
        self.assertEqual(len(rec["account_after"]["recovery"]["unit_reservations_v2"]), 1)
        # Independent positive then exact same identity, with fresh byte bindings.
        root, unit = self.case("duplicate")
        self.run_case(root)
        unit["account_sha256"] = r.digest((root / "ACCOUNT.json").read_bytes()); fixture.sign(root, unit)
        saved = (root / "result/capture/save.json").read_bytes()
        p, cmd = self.launch(root); out, err = p.communicate(timeout=5)
        self.assertEqual(p.returncode, 2); self.assertIn(b'unit already reserved', out)
        self.assertEqual(saved, (root / "result/capture/save.json").read_bytes())
        RECORDS.append(dict(name="duplicate-denial", stdout=bytes_record(out), stderr=bytes_record(err), demand=unit,
            account_after=r.read(root / "ACCOUNT.json"), protected_output_unchanged=True))

    def test_exhausted_reservations_and_changed_identity_before_effects(self):
        for field, value in (("starts_used", 2048), ("cpu_ns_used", r.CPU_CAP), ("raw_bytes_used", r.RAW_CAP)):
            root, unit = self.case(field)
            a = r.read(root / "ACCOUNT.json"); a["recovery"][field] = value
            r.atomic_write(root / "ACCOUNT.json", a)
            unit["account_sha256"] = r.digest((root / "ACCOUNT.json").read_bytes()); fixture.sign(root, unit)
            self.rejected(root, "exhausted complete-unit reservation")
        for name in ("argv", "receipt", "binary", "helper", "source", "architecture", "output-root"):
            root, unit = self.case(name)
            if name == "argv":
                unit["argv"].append("changed"); r.atomic_write(root / "demand.json", unit)
                fragment = "inert demand/receipt mismatch"
            elif name == "receipt":
                r.atomic_write(root / "receipt.json", dict(schema="DD1-INERT-ONLY", demand_sha256="0"*64))
                fragment = "inert demand/receipt mismatch"
            else:
                fragment = {"binary": "runtime identity mismatch", "helper": "helper must be pinned",
                    "source": "actual source bytes differ", "architecture": "missing supported Linux demand", "output-root": "unbound output root"}[name]
                if name == "binary": unit["linux"]["runtime"]["/workload"]["sha256"] = "0"*64
                elif name == "helper": unit["linux"]["helper"]["sha256"] = "0"*64
                elif name == "source": unit["source_files"][next(iter(unit["source_files"]))] = "0"*64
                elif name == "architecture": unit["linux"]["abi"] = "other"
                else: unit["linux"]["output_root"] = str(root / "wrong")
                fixture.sign(root, unit)
            self.rejected(root, fragment)

    def test_output_alias_and_non_synthetic_account_reject(self):
        root, unit = self.case("aliased-output")
        saved = root / "saved"; saved.mkdir(); (saved / "keep").write_text("KEEP")
        (root / "result").symlink_to(saved, target_is_directory=True)
        # Bind the resolved root, so the alias guard, not demand binding, rejects.
        unit["linux"]["output_root"] = str(saved); fixture.sign(root, unit)
        before = (root / "ACCOUNT.json").read_bytes()
        proc, _ = self.launch(root); out, err = proc.communicate(timeout=5)
        self.assertEqual(proc.returncode, 2); self.assertIn(b'output must be new and unaliased', out)
        self.assertEqual((saved / "keep").read_text(), "KEEP")
        self.assertEqual((root / "ACCOUNT.json").read_bytes(), before)
        RECORDS.append(dict(name="output-alias", stdout=bytes_record(out), stderr=bytes_record(err),
            demand=unit, receipt=r.read(root / "receipt.json"), account_before=json.loads(before),
            account_after=r.read(root / "ACCOUNT.json"), account_unchanged=True, protected_output_unchanged=True))
        root, unit = self.case("non-synthetic-account")
        a = r.read(root / "ACCOUNT.json"); a["synthetic"] = False
        r.atomic_write(root / "ACCOUNT.json", a)
        unit["account_sha256"] = r.digest((root / "ACCOUNT.json").read_bytes()); fixture.sign(root, unit)
        self.rejected(root, "inert entry requires synthetic account")

    def test_source_aliases_and_escape_with_changed_original(self):
        copy = self.root / "copied-repo"
        shutil.copytree(REPO / "tools", copy / "tools", ignore=shutil.ignore_patterns("__pycache__"))
        for name, binary in (("changed-executable", "inert"), ("changed-helper", "supervisor")):
            root, unit = self.case(name, repo=copy)
            target = copy / "tools/dd1_linux/build" / binary
            original = target.read_bytes()
            target.write_bytes(b"CHANGED AFTER DEMAND")
            self.rejected(root, "runtime identity mismatch" if binary == "inert" else "helper must be pinned", copy)
            target.write_bytes(original)
        root, unit = self.case("unsupported-ELF", repo=copy)
        target = copy / "tools/dd1_linux/build/inert"
        original = target.read_bytes(); wrong = bytearray(original); wrong[18:20] = b"\x03\x00"
        target.write_bytes(wrong)
        unit["linux"]["runtime"]["/workload"]["sha256"] = r.digest(wrong)
        fixture.sign(root, unit)
        self.rejected(root, "unsupported executable architecture/ABI", copy)
        target.write_bytes(original)
        source = copy / "input"; source.write_bytes(b"IMMUTABLE\n")
        for name in ("symbolic", "hardlinked", "traversal"):
            root, unit = self.case(name, repo=copy)
            if name == "symbolic": (copy / "alias").symlink_to(source)
            elif name == "hardlinked": os.link(source, copy / "alias")
            else: pass
            key = "res://../input" if name == "traversal" else "res://alias"
            unit["source_files"][key] = r.digest(source.read_bytes()); fixture.sign(root, unit)
            self.rejected(root, "unsafe input path" if name == "traversal" else "Too many levels" if name == "symbolic" else "nonregular/linked", copy)
            if name != "traversal": (copy / "alias").unlink()
        root, unit = self.case("escape", "escape", repo=copy)
        unit["source_files"]["res://input"] = r.digest(source.read_bytes()); unit["argv"].append(str(source))
        fixture.sign(root, unit)
        before = r.read(root / "ACCOUNT.json")
        fd = os.open(source, os.O_RDWR); os.dup2(fd, 64); os.close(fd)
        proc, cmd = self.launch(root, copy, pass_fds=(64,)); os.close(64)
        end = time.monotonic() + 4
        while time.monotonic() < end:
            rows = r.read(root / "ACCOUNT.json")["recovery"].get("unit_reservations_v2", [])
            if rows and "processes" in rows[-1]: break
            self.assertIsNone(proc.poll()); time.sleep(.005)
        source.rename(copy / "original-renamed"); source.write_bytes(b"HOST CHANGED\n")
        rec = self.finish(root, proc, cmd, before)
        self.assertEqual(rec["controller_exit"], 0)
        self.assertEqual(source.read_bytes(), b"HOST CHANGED\n")
        self.assertEqual((copy / "original-renamed").read_bytes(), b"IMMUTABLE\n")
        self.assertIn(b'ISOLATED', base64.b64decode(rec["files"]["stdout.bin"]["base64"]))


if __name__ == "__main__":
    if OUTPUT:
        OUTPUT.mkdir(parents=True, exist_ok=False)
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(BackendTests)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    if OUTPUT:
        # Self-contained JSON includes exact synthetic inputs, account states,
        # bounded outputs and every process observation. No real account is read.
        (OUTPUT / "REAL-INERT-CONTROLS.json").write_bytes(r.encode(dict(
            schema="DD1-B1-INERT-CONTROLS-1", synthetic=True,
            tests=result.testsRun, failures=len(result.failures), errors=len(result.errors),
            native_launches=0, records=RECORDS)))
    sys.exit(not result.wasSuccessful())
