"""Fixed Linux enforcement implementation, shared by native and inert entry.

Each call belongs to a dedicated single-threaded controller process. A callback,
flag or unit field cannot select a different runner. Native authority lives in
H's already-authenticated host context, NOT in this module or a self-hash.
"""
import ctypes
import fcntl
import json
import os
from pathlib import Path
import resource
import signal
import subprocess
import time
import dd1_reservations as r
import dd1_linux_snapshot as snapshot
import dd1_preparation as preparation
import dd1_compatibility as compatibility

_once = False


def controller_limits(unit):
    global _once
    r.need(not _once and len(list(Path("/proc/self/task").iterdir())) == 1, "dedicated single-thread controller required")
    _once = True
    r.need(11 <= r.natural(unit.get("cpu_seconds"), "CPU") <= 300, "CPU partition")
    # Retain a high HARD ceiling only until fork/exec so the workload can
    # LOWER its inherited limit to U-10. The controller SOFT limit remains 3,
    # unblocked/default-fatal; controller then irreversibly lowers hard to 3.
    # Bounds including one-second enforcement headroom per process:
    # controller <=4, supervisor bootstrap <=4, workload <=U-9: total <=U-1.
    used = resource.getrusage(resource.RUSAGE_SELF)
    r.need(used.ru_utime + used.ru_stime < 1, "fresh controller CPU baseline required")
    inherited = resource.getrlimit(resource.RLIMIT_CPU)
    r.need(inherited[1] == resource.RLIM_INFINITY or inherited[1] >= unit["cpu_seconds"],
           "inherited CPU ceiling cannot support demand")
    signal.signal(signal.SIGXCPU, signal.SIG_DFL)
    signal.pthread_sigmask(signal.SIG_UNBLOCK, {signal.SIGXCPU})
    resource.setrlimit(resource.RLIMIT_CPU, (3, unit["cpu_seconds"]))
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    libc = ctypes.CDLL(None, use_errno=True)
    r.need(libc.prctl(36, 1, 0, 0, 0) == 0, "controller subreaper unavailable")
    start = time.monotonic()
    deadline = __import__("datetime").datetime.fromisoformat(r.DEADLINE.replace("Z", "+00:00")).timestamp()
    wall = min(float(unit["wall_seconds"]), deadline - time.time())
    r.need(wall >= 3, "complete wall envelope needs two seconds of cleanup headroom")
    def interrupt(signum, _):
        raise InterruptedError("controller signal " + str(signum))
    for sig in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
        signal.signal(sig, interrupt)
    # Fatal hard deadline cannot be swallowed by reservation/error handling.
    # The workload/communicate soft deadline reserves two seconds for cleanup.
    signal.signal(signal.SIGALRM, lambda *_: os._exit(124))
    signal.setitimer(signal.ITIMER_REAL, wall)
    return start, wall - 2


def sealed_helper(raw):
    fd = os.memfd_create("dd1-verified-static-supervisor", os.MFD_CLOEXEC | os.MFD_ALLOW_SEALING)
    view = memoryview(raw)
    while view:
        n = os.write(fd, view); view = view[n:]
    fcntl.fcntl(fd, fcntl.F_ADD_SEALS, fcntl.F_SEAL_WRITE | fcntl.F_SEAL_GROW | fcntl.F_SEAL_SHRINK | fcntl.F_SEAL_SEAL)
    return fd


def reap_adopted():
    # Dedicated subreaper has no unrelated children. A killed supervisor's
    # workload is adopted here; PR_SET_PDEATHSIG kills it in the kernel.
    observed = []
    end = time.monotonic() + 2
    while time.monotonic() < end:
        try:
            pid, status, usage = os.wait4(-1, os.WNOHANG)
        except ChildProcessError:
            return True, observed
        if pid:
            observed.append(dict(pid=pid, status=status, cpu_seconds=usage.ru_utime + usage.ru_stime))
        else:
            time.sleep(.01)
    return False, observed


class Prepared:
    def __init__(self, unit, command, repo, lifetime, generated=None):
        self.unit, self.command, self.lifetime = unit, command, lifetime
        self.pinned = snapshot.prepare(unit, command, repo, generated)

    def __call__(self, grant, output):
        p = self.pinned
        allowance = p["config"]["workload_raw_bytes"]
        r.need(p["setup_raw"] + allowance <= grant["child_raw_bytes"], "raw remaining envelope cannot fit setup/child")
        root = output / "private-root"
        root.mkdir(mode=0o700)
        (root / "out").mkdir()
        capture = output / "capture"; capture.mkdir(mode=0o700)
        # Names/bytes fixed above. Every destination is new; no symlink copying.
        for name, (raw, executable) in p["files"].items():
            path = root / name[1:]; path.parent.mkdir(parents=True, exist_ok=True)
            with path.open("xb") as stream:
                stream.write(raw); stream.flush(); os.fsync(stream.fileno())
            path.chmod(0o500 if executable else 0o400)
            r.need(path.read_bytes() == raw, "private snapshot readback mismatch")
        # The legacy GDScript receipt reader needs a read-only account INPUT,
        # not the writable live account. Only the exact pre-reservation bytes
        # bound in the demand are copied here; no alias to account_path exists.
        account_view = root / "source/research/p9-six-route/dusk-design-1-20260916/native-qualification/recovery/ACCOUNT.json"
        account_view.parent.mkdir(parents=True, exist_ok=True)
        with account_view.open("xb") as stream:
            stream.write(self.account_bytes); stream.flush(); os.fsync(stream.fileno())
        account_view.chmod(0o400)
        inside = dict(grant, artifact_root="/out/capture")
        (capture / "capture").mkdir()
        r.atomic_write(root / "grant.json", inside)
        (root / "grant.json").chmod(0o400)
        # Entry validated these exact receipt bytes; never remount live receipt.
        (root / "launch-receipt.json").write_bytes(self.receipt_bytes)
        (root / "launch-receipt.json").chmod(0o400)
        preparation.create_slots(root, capture, p["preparation"])
        helper = sealed_helper(p["helper"])
        lease = r._lease.get()
        r.need(lease >= 3, "missing inherited account executor lease")
        elapsed = time.monotonic() - self.lifetime[0]
        wall_ms = int((self.lifetime[1] - elapsed - .1) * 1000)
        r.need(wall_ms >= 100, "setup exhausted unit wall bound")
        args = ["dd1-supervisor", str(root), str(capture), str(allowance),
                str(self.unit["cpu_seconds"] - 10), str(wall_ms), str(p["config"]["threads"]),
                str(os.getpid()), str(lease), str(int(p["profile"] is not None)),
                str(p["profile"]["naming_total"] if p["profile"] else 0),
                str(p["profile"]["clone3_maximum"] if p["profile"] else 0), *self.command]
        proc, raw, err, interruption, first = None, b"", b"", None, b""
        try:
            proc = subprocess.Popen(args, executable="/proc/self/fd/" + str(helper),
                pass_fds=(helper, lease), stdin=subprocess.PIPE,
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, env={})
            resource.setrlimit(resource.RLIMIT_CPU, (3, 3))
            first = proc.stdout.readline(512)
            started = json.loads(first)
            r.need(started.get("phase") == "started" and started.get("supervisor") == proc.pid, "bootstrap identity")
            identities = dict(controller=r.process_identity(os.getpid()),
                supervisor=r.process_identity(proc.pid), workload=r.process_identity(started["workload"]))
            r.need(identities["workload"]["ppid"] == proc.pid, "workload parent identity")
            r.attach_processes(identities)  # durable BEFORE the workload release
            rest, err = proc.communicate(input=b"G", timeout=max(.1, wall_ms / 1000 + .05))
            raw = first + rest
        except BaseException as exc:
            interruption = type(exc).__name__ + ":" + str(exc)
            if proc is not None:
                proc.kill()
                # The hard controller deadline remains armed during cleanup.
                rest, err = proc.communicate(timeout=2)
                raw = first + rest
        finally:
            os.close(helper)
        clean, adopted = reap_adopted()
        r.need(len(raw) <= 32768 and len(err) <= 4096, "trusted diagnostic size contract")
        events = [json.loads(line) for line in raw.splitlines()]
        report = next((x for x in events if x.get("phase") == "result"), {})
        success = report.get("success") is True and proc is not None and proc.returncode == 0 and clean and not interruption
        classification = next((x for x in events if x.get("phase") == "classification"), {})
        task = {"ok": False, "errors": ["missing successful enforcement/task exit"]}
        sealed = None
        if success:
            try:
                task = compatibility.task_outcome(self.unit, capture, classification)
                success = success and task["ok"]
                if success:
                    sealed = preparation.seal(self.unit, p, output, clean, success)
            except (OSError, ValueError, r.ReservationError) as exc:
                task = {"ok": False, "errors": [type(exc).__name__ + ":" + str(exc)]}
                success = False
        usage = resource.getrusage(resource.RUSAGE_SELF)
        return dict(success=success, cleanup_confirmed=clean,
            classification=classification, task_outcome=task, sealed_preparation=sealed,
            strict_verdict=bool(classification.get("strict_success") and success),
            compatibility_verdict=bool(p.get("profile") and success),
            classification_scope="kernel refusals, cleanup and exit; task validation is separate",
            controller_cpu_limits=list(resource.getrlimit(resource.RLIMIT_CPU)),
            refused_requests=[e for e in events if e.get("phase") == "refusal"],
            controller_cpu_seconds_at_report=usage.ru_utime + usage.ru_stime,
            elapsed_seconds_at_report=time.monotonic() - self.lifetime[0],
            backend=snapshot.ABI, source_snapshot_sha256=r.digest(r.encode({k: r.digest(v[0]) for k, v in p["files"].items()})),
            source_snapshot_files=len(p["files"]),
            helper_sha256=r.digest(p["helper"]), setup_raw_reserved=p["setup_raw"],
            workload_raw_reserved=allowance, supervisor_report=report,
            supervisor_stdout=raw.decode(), supervisor_stderr=err.decode(),
            supervisor_exit=proc.returncode if proc else None, adopted=adopted,
            interruption=interruption, native_qualified=False)
