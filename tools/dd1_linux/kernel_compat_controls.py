#!/usr/bin/env python3
"""One-case K2 driver for DD1-KERNEL-COMPAT-1. No second sandbox and no caller clock.

Reuses inert/compat2/fit fixtures through dd1_meter_entry._run_inert_unit.
The disposable account is the K1 synthetic account only.
"""
from __future__ import annotations
import argparse
import fcntl
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import dd1_kernel_qualification as kq
import dd1_reservations as r

BUILD_RESERVE = 60
HEADROOM = 36
RELEASE_TOTAL = 204
RELEASE_LIMIT = 240
AGGREGATE = 300
RAW_EACH = 8 * 1024 * 1024
CONTROLLER = "DD1_KERNEL_COMPAT_CONTROLLER"


def _argv(source, mode, births):
    if source == "fit_inert.c":
        return ["/workload", "sequential", str(births), "identity"]
    return ["/workload", mode]


def _case(case_id, source, mode, cap, observation, **extra):
    row = dict(case_id=case_id, source_file=source, mode=mode, cpu_cap=cap,
               argv_tokens=_argv(source, mode, extra.get("births")),
               required_observation=observation)
    row.update(extra)
    return row


ROWS = (
    _case("KC01_STRICT_POSITIVE", "inert.c", "positive", 12,
          "strict success; USER_NOTIF path live; 3 lifetime threads incl main; atomic save/readback; cleanup confirmed"),
    _case("KC02_READONLY_ESCAPE", "inert.c", "escape", 12,
          "writes/rename/alias to immutable source fail; original bytes readable; unit exits success; no escape"),
    _case("KC03_CLONE3_FALLBACK", "inert.c", "clone3", 10,
          "clone3 refused with ENOSYS path; no process created; bounded record; cleanup"),
    _case("KC04_STRICT_THREAD_CEILING", "inert.c", "thread_limit", 12,
          "strict four-lifetime-thread ceiling reached; next birth refused; no fifth thread"),
    _case("KC05_CPU_EXHAUST", "inert.c", "cpu", 20,
          "RLIMIT_CPU actually terminates workload; failure retained; cleanup; no refund/credit"),
    _case("KC06_RAW_OVERWRITE", "inert.c", "overwrites", 12,
          "monotone raw/write accounting; cap refusal before excess effect; failed unit remains charged"),
    _case("KC07_SOCKET_DENY", "inert.c", "socket", 10,
          "unrelated socket syscall EOPNOTSUPP/denied; no socket effect; strict failure"),
    _case("KC08_X32_ABI_KILL", "inert.c", "abi", 10,
          "x32-tagged syscall is fail-closed, expected SIGSYS; no BAD write"),
    _case("KC09_CONTROLLER_KILL", "inert.c", "linger", 12,
          "reservation/operation charge retained; PDEATHSIG/subreaper cleanup leaves controller/supervisor/workload identities gone",
          kill="controller"),
    _case("KC10_SUPERVISOR_KILL", "inert.c", "linger", 12,
          "failed outcome, cleanup confirmed, no surviving workload, charge retained",
          kill="supervisor"),
    _case("KC11_COMPAT_COMBINED", "compat2_inert.c", "combined", 16,
          "compatibility success + strict failure; exactly 1 process-refusal + 1 naming-refusal; CAPABILITY_CLASS_ONLY; save/readback"),
    _case("KC12_CPU_ABOVE_3", "compat2_inert.c", "cpu-above-three", 16,
          "controller 3/3, supervisor 2/2 and installed workload partition correct; workload exceeds former inherited 3s limit without escaping reserved total"),
    _case("KC13_FIT_14_BOUNDARY", "fit_inert.c", "sequential", 16,
          "accepted FIT ceiling reaches 14 lifetime threads incl main; exact mode/immutable-handler checks; atomic save",
          threads=14, births=13),
    _case("KC14_FIT_NEXT_BIRTH_DENY", "fit_inert.c", "sequential", 16,
          "15th lifetime birth is refused; no topology overflow",
          threads=14, births=14),
    _case("KC15_IA32_REACHABILITY", "inert.c", "ia32", 8,
          "if seccomp arch guard is reached: fail-closed SIGSYS; if host faults first with SIGSEGV and zero forbidden effects: record `NOT_REACHABLE_ON_HOST` and make no seccomp-arch claim; exit 0/effect => INCOMPATIBLE",
          special="ia32_reachability"),
    _case("KC16_NESTED_NAMESPACE_DENY", "inert.c", "namespace", 10,
          "workload cannot create another user namespace; EOPNOTSUPP/denied; existing isolated namespace remains intact"),
)


def plan():
    copied = []
    for row in ROWS:
        item = dict(row)
        item["argv_tokens"] = list(row["argv_tokens"])
        copied.append(item)
    return copied


def row_for(case_id):
    for row in ROWS:
        if row["case_id"] == case_id:
            return row
    return None


def synthetic_account():
    policy = kq.INERT_RESERVATION_POLICY
    return dict(schema="DD1-KERNEL-COMPAT-1-SYNTHETIC-ACCOUNT-1", synthetic=True,
        recovery=dict(id="DD1-KERNEL-COMPAT-1", selection=policy["selection"],
            starts_used=0, starts_cap=policy["starts_cap"],
            cpu_ns_used=0, cpu_ns_cap=policy["cpu_ns_cap"],
            raw_bytes_used=0, raw_bytes_cap=policy["raw_bytes_cap"],
            executors=policy["executors"], per_invocation_cpu_seconds=policy["per_invocation_cpu_seconds"],
            first_engine_launch_utc=policy["start_utc"], deadline_utc=policy["deadline_utc"],
            unit_reservations_v2=[],
            events=[{"note": "SYNTHETIC K1 inert reservation account; no historical credit"}]))


def qualification(head):
    identity = {key: (list(value) if isinstance(value, list) else value)
                for key, value in kq.QUALIFIED_IDENTITY.items()}
    return dict(schema=kq.SCHEMA, operation=kq.OPERATION, selection=kq.SELECTION, source_head=head,
                status="REQUALIFYING", mode="inert_control", host_identity=identity,
                primitives=sorted(kq.PRIMITIVES))


def refuse(reason):
    sys.stdout.write(json.dumps(dict(schema="DD1-KERNEL-COMPAT-1-CASE", refused_before_g=True,
                                    workload_release=False, reason=str(reason)[:2048]), sort_keys=True) + "\n")
    raise SystemExit(2)


def window_open():
    policy = kq.INERT_RESERVATION_POLICY
    now = datetime.now(timezone.utc)
    start = datetime.fromisoformat(policy["start_utc"].replace("Z", "+00:00"))
    deadline = datetime.fromisoformat(policy["deadline_utc"].replace("Z", "+00:00"))
    if not (start <= now < deadline):
        refuse("outside selected window")


def load_k0(root):
    import dd1_linux_snapshot as snap
    path = Path(root) / "K0.json"
    if not path.is_file():
        refuse("valid K0 record missing")
    try:
        record = r.read(path)
    except r.ReservationError as exc:
        refuse("valid K0 record missing: " + str(exc))
    host = record.get("host") if isinstance(record.get("host"), dict) else {}
    helper = record.get("helper") if isinstance(record.get("helper"), dict) else {}
    clone = record.get("clone") if isinstance(record.get("clone"), dict) else {}
    identity = kq.QUALIFIED_IDENTITY
    policy = kq.INERT_RESERVATION_POLICY
    valid = (record.get("schema") == "DD1-KERNEL-COMPAT-1-K0" and record.get("operation") == kq.OPERATION
             and record.get("selection_comment") == kq.SELECTION
             and record.get("deadline_utc") == policy["deadline_utc"]
             and record.get("selection_timestamp_utc") == policy["start_utc"]
             and host.get("kernel_release") == identity["kernel_release"]
             and host.get("kernel_version") == identity["kernel_version"]
             and host.get("machine") == identity["machine"]
             and host.get("pointer_bytes") == identity["pointer_bytes"]
             and host.get("libc") == identity["libc"]
             and helper.get("baseline_sha256") == snap.PINNED_HELPER_SHA256
             and isinstance(clone.get("path"), str) and clone["path"]
             and isinstance(record.get("counters"), dict))
    if not valid:
        refuse("valid K0 record missing")
    return record


def acquire_lock(root):
    fd = os.open(str(Path(root) / "LOCK"), os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        os.close(fd)
        refuse("whole-operation lock not acquired")
    return fd


def lock_held(root):
    fd = os.open(str(Path(root) / "LOCK"), os.O_RDWR | os.O_NOFOLLOW)
    try:
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return True
        fcntl.flock(fd, fcntl.LOCK_UN)
        return False
    finally:
        os.close(fd)


def apply_k1(unit, head, account_path, row):
    unit["operation"] = kq.OPERATION
    unit.pop("scientific_m", None)
    unit["overlay_head"] = head
    unit["operation_start_utc"] = kq.INERT_RESERVATION_POLICY["start_utc"]
    unit["operation_deadline_utc"] = kq.INERT_RESERVATION_POLICY["deadline_utc"]
    unit["kernel_qualification"] = qualification(head)
    unit["cpu_seconds"] = row["cpu_cap"]
    unit["wall_seconds"] = 60
    unit["raw_bytes"] = RAW_EACH
    unit["argv"] = list(row["argv_tokens"])
    unit["account_sha256"] = r.digest(Path(account_path).read_bytes())
    unit["linux"]["output_root"] = str((Path(account_path).parent / "output").resolve())


def sign(where, unit):
    unit.pop("receipt_sha256", None)
    receipt = dict(schema="DD1-INERT-ONLY", demand_sha256=r.digest(r.encode(unit)))
    raw = r.encode(receipt)
    (where / "receipt.json").write_bytes(raw)
    unit["receipt_sha256"] = r.digest(raw)
    (where / "unit.json").write_bytes(r.encode(unit))


def build_inert(where, repo, row, head):
    import dd1_linux_snapshot as snap
    where.mkdir(parents=True, exist_ok=False)
    ap = where / "ACCOUNT.json"
    ap.write_bytes(r.encode(synthetic_account()))
    sources = snap.HELPER_SOURCES | {"res://tools/dd1_linux/inert.c"}
    files = {name: r.digest((repo / name[6:]).read_bytes()) for name in sources}
    helper = repo / "tools/dd1_linux/build/supervisor"
    inert = repo / "tools/dd1_linux/build/inert"
    unit = dict(schema="DD1-COMPLETE-UNIT-DEMAND-2", operation=kq.OPERATION, overlay_head=head,
                unit_id=row["case_id"], mode="inert_control", contained_starts=0,
                source_files=files, argv=list(row["argv_tokens"]),
                linux=dict(abi=snap.ABI, entry="/workload", threads=4, workload_raw_bytes=65536,
                           helper=dict(path="tools/dd1_linux/build/supervisor", sha256=r.digest(helper.read_bytes())),
                           runtime={"/workload": dict(path="tools/dd1_linux/build/inert",
                                                      sha256=r.digest(inert.read_bytes()), executable=True)}))
    apply_k1(unit, head, ap, row)
    return unit, ap


def build_compat(where, repo, row, head):
    import compat2_controls as compat
    where.mkdir(parents=True, exist_ok=False)
    compat.HEAD = head
    unit, _repo = compat.make_unit(where, mode=row["mode"], cpu=row["cpu_cap"], repo=repo,
                                   existing_account=synthetic_account())
    ap = where / "synthetic-account.json"
    apply_k1(unit, head, ap, row)
    unit["compatibility"] = compat.profile(unit)
    unit["compatibility"]["kernel_qualification_sha256"] = r.digest(r.encode(unit["kernel_qualification"]))
    unit["account_sha256"] = r.digest(ap.read_bytes())
    return unit, ap


def build_fit(where, repo, row, head):
    import fit_controls as fit
    fit.HEAD = head
    unit, _repo, ap = fit.make(where, mode="sequential", threads=row["threads"], births=row["births"], repo=repo)
    ap.write_bytes(r.encode(synthetic_account()))
    apply_k1(unit, head, ap, row)
    fit.bind(unit, repo)
    unit["compatibility"]["kernel_qualification_sha256"] = r.digest(r.encode(unit["kernel_qualification"]))
    unit["linux"]["output_root"] = str((where / "output").resolve())
    unit["account_sha256"] = r.digest(ap.read_bytes())
    return unit, ap


def stage(root, repo, row, head):
    where = Path(root) / "dd1-kernel-compat-1" / row["case_id"]
    where.parent.mkdir(parents=True, exist_ok=True)
    if where.exists():
        refuse("case directory already exists")
    source = row["source_file"]
    if source == "inert.c":
        unit, ap = build_inert(where, repo, row, head)
    elif source == "compat2_inert.c":
        unit, ap = build_compat(where, repo, row, head)
    elif source == "fit_inert.c":
        unit, ap = build_fit(where, repo, row, head)
    else:
        refuse("unknown fixture")
    if unit["overlay_head"] != head or unit["kernel_qualification"]["source_head"] != head:
        refuse("head is not bound to the unit")
    if unit["kernel_qualification"]["selection"] != kq.SELECTION:
        refuse("owner selection mismatch")
    sign(where, unit)
    r.atomic_write(where / "paths.json", dict(account=str(ap), receipt=str(where / "receipt.json"),
                                              output=unit["linux"]["output_root"], repo=str(repo),
                                              argv=unit["argv"]))
    return where, unit, ap


def source_identity(repo, source_file):
    path = repo / "tools/dd1_linux" / source_file
    raw = path.read_bytes()
    return dict(path="tools/dd1_linux/" + source_file, sha256=r.digest(raw), bytes=len(raw))


def spawn(head, root, case_id):
    env = os.environ.copy()
    env[CONTROLLER] = "1"
    return subprocess.Popen([sys.executable, "-I", "-B", "-S", str(Path(__file__).resolve()),
                             "--head", head, "--root", str(root), "--case", case_id],
                            env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)


def wait_live(proc, output, account_path):
    end = time.monotonic() + 20
    while time.monotonic() < end:
        if proc.poll() is not None:
            return None
        marker = Path(output) / "capture" / "stdout.bin"
        try:
            rows = r.read(account_path)["recovery"].get("unit_reservations_v2", [])
        except (OSError, r.ReservationError, KeyError):
            rows = []
        if rows and rows[-1].get("processes") and marker.is_file() and b"LIVE\n" in marker.read_bytes():
            return rows[-1]["processes"]
        time.sleep(0.02)
    return None


def emit(row, head, child_exit, stdout, stderr, before, after, account):
    result = None
    if stdout:
        try:
            result = json.loads(stdout)
        except ValueError:
            result = {"unparsed_stdout": stdout[:2048]}
    charge = None
    try:
        rows = account["recovery"].get("unit_reservations_v2", [])
        charge = rows[-1] if rows else None
    except (AttributeError, KeyError, TypeError):
        charge = None
    sys.stdout.write(json.dumps(dict(
        schema="DD1-KERNEL-COMPAT-1-CASE", case_id=row["case_id"], operation=kq.OPERATION,
        selection=kq.SELECTION, head=head, cpu_cap=row["cpu_cap"],
        required_observation=row["required_observation"], child_exit=child_exit,
        refused_before_g=bool(result and result.get("pre_release_error")),
        result=result, stderr=(stderr or "")[:2048], charge=charge,
        source_before=before, source_after=after), sort_keys=True) + "\n")


def preflight(args):
    if row_for(args.case) is None:
        refuse("unknown case")
    if re.fullmatch(r"[0-9a-f]{40}", args.head) is None:
        refuse("exact K1 head required")
    window_open()
    return load_k0(args.root)


def controller_main(args):
    preflight(args)
    if not lock_held(args.root):
        refuse("whole-operation lock not held")
    where = Path(args.root) / "dd1-kernel-compat-1" / args.case
    meta = r.read(where / "paths.json")
    unit = r.read(where / "unit.json")
    if unit.get("overlay_head") != args.head:
        refuse("head is not bound to the unit")
    import dd1_meter_entry as entry
    try:
        result = entry._run_inert_unit(list(meta["argv"]), unit=unit, account_path=Path(meta["account"]),
                                        receipt_path=Path(meta["receipt"]), output=Path(meta["output"]),
                                        head=args.head, repo=Path(meta["repo"]))
        sys.stdout.write(json.dumps(result) + "\n")
        return 0
    except Exception as exc:
        sys.stdout.write(json.dumps({"pre_release_error": type(exc).__name__ + ":" + str(exc)}) + "\n")
        return 2


def driver_main(args):
    row = row_for(args.case)
    k0 = preflight(args)
    fd = acquire_lock(args.root)
    try:
        repo = Path(k0["clone"]["path"])
        if not repo.is_dir():
            refuse("K0 clone missing")
        before = source_identity(repo, row["source_file"])
        where, unit, ap = stage(args.root, repo, row, args.head)
        proc = spawn(args.head, args.root, args.case)
        try:
            if row.get("kill"):
                identities = wait_live(proc, unit["linux"]["output_root"], ap)
                if identities and proc.poll() is None:
                    os.kill(identities[row["kill"]]["pid"], signal.SIGKILL)
            try:
                out, err = proc.communicate(timeout=90)
            except subprocess.TimeoutExpired:
                proc.kill()
                out, err = proc.communicate()
        except Exception:
            if proc.poll() is None:
                proc.kill()
                proc.communicate()
            raise
        after = source_identity(repo, row["source_file"])
        try:
            account = r.read(ap)
        except r.ReservationError:
            account = {}
        emit(row, args.head, proc.returncode, out, err, before, after, account)
        return proc.returncode or 0
    finally:
        os.close(fd)


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("--head", required=True)
    parser.add_argument("--root", required=True)
    parser.add_argument("--case", required=True)
    args = parser.parse_args(argv)
    try:
        if os.environ.get(CONTROLLER) == "1":
            return controller_main(args)
        return driver_main(args)
    except SystemExit:
        raise
    except Exception as exc:
        refuse(type(exc).__name__ + ": " + str(exc))
        return 2


if __name__ == "__main__":
    sys.exit(main())
