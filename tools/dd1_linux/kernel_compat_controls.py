#!/usr/bin/env python3
"""One-case K2 driver for DD1-KERNEL-COMPAT-1. No second sandbox and no caller clock.

Reuses inert/compat2/fit fixtures through dd1_meter_entry._run_inert_unit.
The disposable account is the K1 synthetic account only. K2-LEDGER.json under
--root is the operation-wide release, CPU and raw authority.
"""
from __future__ import annotations
import argparse
import fcntl
import json
import os
from pathlib import Path
import re
import resource
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
HELPER_PIN = "41a4529af3bb2fb3f065d164dee8ac9cd2af7d761311c5ee63538347a44e45a4"
BASE_HEAD = "c17ae971a447c28e597b78d0ecb5eb29f36e644a"
REMOTE_MAIN = "07b5aa9dec8436132a524511d5438c510e322070"
LEDGER_SCHEMA = "DD1-KERNEL-COMPAT-1-K2-LEDGER-1"
CASE_SCHEMA = "DD1-KERNEL-COMPAT-1-CASE"
K0_SCHEMA = "DD1-KERNEL-COMPAT-1-K0"
BUILD_RESERVE_NS = 60_000_000_000
CPU_CAP_NS = 300_000_000_000
RAW_CAP = 134_217_728
CASE_CPU_MAX_NS = 30_000_000_000
PLANNED_RELEASE_NS = 204_000_000_000
HEADROOM_NS = 36_000_000_000
RELEASE_SLOTS = 16
DEADLINE_UNIX = 1790506920
CASE_RAW = RAW_EACH
STOPS = frozenset(("INCOMPATIBLE", "INCONCLUSIVE"))
FINAL_KINDS = frozenset(("EXPECTED", "NOT_REACHABLE_ON_HOST", "INCOMPATIBLE", "INCONCLUSIVE"))
ART_KEYS = ("supervisor", "inert", "compat2-inert", "fit-inert", "libc.so.6")
TOP_KEYS = frozenset((
    "schema", "operation", "selection_comment", "window", "head", "k0_sha256", "caps",
    "build", "used", "rows", "latch"))
ROW_KEYS = frozenset((
    "seq", "case_id", "state", "g", "cpu_ns_reserved", "cpu_ns_observed", "cpu_ns_charged",
    "raw_bytes_reserved", "raw_bytes_observed", "raw_bytes_charged", "reserved_utc",
    "finished_utc", "classification", "reasons", "record_sha256"))
BUILD_KEYS = frozenset((
    "cpu_ns_reserved", "cpu_ns_observed", "cpu_ns_charged", "artefacts_sha256", "status",
    "reasons", "recorded_utc"))
USED_KEYS = frozenset((
    "release_slots", "workload_releases", "cpu_ns_charged", "raw_bytes_charged", "raw_bytes_observed"))
LATCH_KEYS = frozenset(("outcome", "case_id", "reasons", "latched_utc"))
WINDOW = {
    "start_utc": "2026-09-26T11:02:00Z",
    "deadline_utc": "2026-09-27T11:02:00Z",
    "deadline_unix": DEADLINE_UNIX,
}
CAPS = {
    "release_slots": RELEASE_SLOTS,
    "cpu_ns": CPU_CAP_NS,
    "raw_bytes": RAW_CAP,
    "case_cpu_ns_max": CASE_CPU_MAX_NS,
    "case_raw_bytes": CASE_RAW,
    "build_reserve_cpu_ns": BUILD_RESERVE_NS,
    "planned_release_cpu_ns": PLANNED_RELEASE_NS,
    "headroom_cpu_ns": HEADROOM_NS,
}
K0_KEYS = frozenset((
    "schema", "operation", "selection_comment", "selection_timestamp_utc", "deadline_utc",
    "custodian", "executor", "durable_root", "lock", "clone", "host", "resources",
    "primitives", "github", "persistence", "helper", "helper_sources_sha256", "counters"))
LOCK_KEYS = frozenset((
    "path", "acquired", "locker_pid", "locker_start_ticks", "acquired_at_utc",
    "same_unix_user_advisory_only"))
CLONE_KEYS = frozenset(("path", "head", "tree", "clean", "shared_clone_modified", "remote_main"))
HOST_KEYS = frozenset((
    "hostname", "os_id", "os_version", "kernel_release", "kernel_version", "machine",
    "pointer_bytes", "libc", "python", "boot_id_sha256", "cgroup_v2"))
RESOURCE_KEYS = frozenset((
    "vcpus", "memory_total_bytes", "memory_available_bytes", "swap_total_bytes",
    "disk_free_bytes", "load_1m"))
PRIMITIVE_BOOLS = (
    "seccomp_user_notif", "user_namespace", "mount_namespace", "network_namespace",
    "readonly_bind_remount", "subreaper", "pdeathsig", "cgroup_v2")
PRIMITIVE_KEYS = frozenset(PRIMITIVE_BOOLS + ("rlimit_cpu_soft", "rlimit_cpu_hard"))
PERSIST_KEYS = frozenset((
    "home_root_expected_persistent", "usr_may_reset_on_computer_update", "flock_path",
    "python_path", "cc_path", "openssh_reinstall_after_update_risk"))
COUNTER_KEYS = frozenset(("workload_releases", "compile_commands", "engine_runs", "source_mutations"))


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


def _observed_cpu_ns():
    total = 0.0
    for who in (resource.RUSAGE_SELF, resource.RUSAGE_CHILDREN):
        usage = resource.getrusage(who)
        total += usage.ru_utime + usage.ru_stime
    return int(total * 1_000_000_000)


def refuse(reason, mutated=False):
    sys.stdout.write(json.dumps(dict(
        schema=CASE_SCHEMA, refused_before_g=True, workload_release=False,
        ledger_mutated=bool(mutated), cpu_ns=_observed_cpu_ns(), reason=str(reason)[:2048]),
        sort_keys=True) + "\n")
    raise SystemExit(2)


def stamp():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ")


def parse_utc(value):
    if not isinstance(value, str) or not value.endswith("Z"):
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def valid_stamp(value):
    if not isinstance(value, str) or re.fullmatch(
            r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6}Z", value) is None:
        return False
    return parse_utc(value) is not None


def _hex(value, size):
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{%d}" % size, value) is not None


def _inside(child, parent):
    try:
        Path(child).resolve().relative_to(Path(parent).resolve())
    except (OSError, ValueError):
        return False
    return True


def ledger_file(root):
    return Path(root) / "K2-LEDGER.json"


def operation_dir(root):
    return Path(root) / "dd1-kernel-compat-1"


def case_directory(root, case_id):
    return operation_dir(root) / case_id


def location_problem(root, clone_path):
    path = ledger_file(root)
    if path.is_symlink():
        return "ledger path is a symlink"
    resolved = path.parent.resolve() / path.name
    if _inside(resolved, ROOT) or (clone_path and _inside(resolved, clone_path)):
        return "ledger path is inside a clone or checkout"
    if path.exists() and not path.is_file():
        return "ledger path is not a regular file"
    return None


def window_open():
    policy = kq.INERT_RESERVATION_POLICY
    moment = datetime.now(timezone.utc)
    start = datetime.fromisoformat(policy["start_utc"].replace("Z", "+00:00"))
    deadline = datetime.fromisoformat(policy["deadline_utc"].replace("Z", "+00:00"))
    if not (start <= moment < deadline):
        refuse("outside selected window")


def _live_boot_id_sha256():
    return r.digest(Path("/proc/sys/kernel/random/boot_id").read_bytes())


def _signal_pid(pid, sig):
    os.kill(pid, sig)


def _identity_absent(identity):
    """True once /proc identity is gone, reused, or from another boot. Polls ≤ 2s."""
    deadline = time.monotonic() + 2.0
    while True:
        try:
            current = r.process_identity(identity["pid"])
        except OSError:
            return True
        if current["start_ticks"] != identity.get("start_ticks") or current["boot_id"] != identity.get("boot_id"):
            return True
        if time.monotonic() >= deadline:
            return False
        time.sleep(0.02)


def k0_problem(record, root, head):
    if not isinstance(record, dict) or set(record) != K0_KEYS:
        return "K0 keys"
    if record["schema"] != K0_SCHEMA or record["operation"] != kq.OPERATION:
        return "K0 schema"
    if type(record["selection_comment"]) is not int or record["selection_comment"] != kq.SELECTION:
        return "K0 selection"
    if record["selection_timestamp_utc"] != WINDOW["start_utc"] or record["deadline_utc"] != WINDOW["deadline_utc"]:
        return "K0 window"
    if record["custodian"] != "Tushar" or record["executor"] != "grokbot-vm":
        return "K0 custody"
    durable = str(Path(root).resolve())
    if record["durable_root"] != durable:
        return "K0 durable root"
    lock = record["lock"]
    if not isinstance(lock, dict) or set(lock) != LOCK_KEYS:
        return "K0 lock keys"
    if lock["path"] != durable + "/LOCK" or lock["acquired"] is not True or lock["same_unix_user_advisory_only"] is not True:
        return "K0 lock"
    if type(lock["locker_pid"]) is not int or lock["locker_pid"] < 0 or type(lock["locker_start_ticks"]) is not int or lock["locker_start_ticks"] < 0:
        return "K0 lock identity"
    acquired = parse_utc(lock["acquired_at_utc"])
    start = parse_utc(WINDOW["start_utc"])
    deadline = parse_utc(WINDOW["deadline_utc"])
    if acquired is None or not (start <= acquired < deadline):
        return "K0 lock time"
    clone = record["clone"]
    if not isinstance(clone, dict) or set(clone) != CLONE_KEYS:
        return "K0 clone keys"
    if not isinstance(clone["path"], str) or not Path(clone["path"]).is_absolute():
        return "K0 clone path"
    resolved = Path(clone["path"]).resolve()
    if resolved != Path(ROOT).resolve():
        return "K0 clone is not the driver checkout"
    try:
        resolved.relative_to(Path(durable).resolve())
    except ValueError:
        return "K0 clone outside durable root"
    if clone["head"] == BASE_HEAD or clone["head"] != head or not _hex(clone["head"], 40) or not _hex(clone["tree"], 40):
        return "K0 clone head"
    if clone["clean"] is not True or clone["shared_clone_modified"] is not False or clone["remote_main"] != REMOTE_MAIN:
        return "K0 clone state"
    host = record["host"]
    if not isinstance(host, dict) or set(host) != HOST_KEYS:
        return "K0 host keys"
    if not isinstance(host["hostname"], str):
        return "K0 hostname"
    if host["os_id"] != "debian" or host["os_version"] != "13" or host["cgroup_v2"] is not True:
        return "K0 os"
    identity = kq.QUALIFIED_IDENTITY
    for field in ("kernel_release", "kernel_version", "machine", "pointer_bytes", "libc"):
        if host.get(field) != identity[field]:
            return "K0 host " + field
    import platform
    if host["python"] != platform.python_version() or not _hex(host["boot_id_sha256"], 64):
        return "K0 python or boot id"
    try:
        live_boot = _live_boot_id_sha256()
    except OSError:
        return "boot_id unreadable"
    if host["boot_id_sha256"] != live_boot:
        return "boot_id mismatch"
    resources = record["resources"]
    if not isinstance(resources, dict) or set(resources) != RESOURCE_KEYS:
        return "K0 resources"
    primitives = record["primitives"]
    if not isinstance(primitives, dict) or set(primitives) != PRIMITIVE_KEYS:
        return "K0 primitives"
    for name in PRIMITIVE_BOOLS:
        if primitives[name] is not True:
            return "K0 primitive " + name
    github = record["github"]
    if not isinstance(github, dict) or set(github) != {"ls_remote_main", "authenticated_gh_api_available"}:
        return "K0 github"
    if github["ls_remote_main"] != REMOTE_MAIN or github["authenticated_gh_api_available"] is not True:
        return "K0 github"
    persistence = record["persistence"]
    if not isinstance(persistence, dict) or set(persistence) != PERSIST_KEYS:
        return "K0 persistence"
    helper = record["helper"]
    if not isinstance(helper, dict) or set(helper) != {"baseline_sha256", "compiled_in_k0"}:
        return "K0 helper keys"
    if helper["baseline_sha256"] != HELPER_PIN or helper["compiled_in_k0"] is not False:
        return "K0 helper"
    import dd1_linux_snapshot as snap
    sources = record["helper_sources_sha256"]
    if not isinstance(sources, dict) or set(sources) != set(snap.HELPER_SOURCES):
        return "K0 helper source map"
    for name, digest in sources.items():
        if not _hex(digest, 64):
            return "K0 helper source digest"
        file = resolved / name[6:]
        try:
            raw = file.read_bytes()
        except OSError:
            return "K0 helper source unreadable"
        if r.digest(raw) != digest:
            return "K0 helper source drift"
    counters = record["counters"]
    if not isinstance(counters, dict) or set(counters) != COUNTER_KEYS:
        return "K0 counters"
    for key in COUNTER_KEYS:
        if type(counters[key]) is not int or counters[key] != 0:
            return "K0 counters"
    return None


def load_k0(root, head):
    path = Path(root) / "K0.json"
    if path.is_symlink() or not path.is_file():
        refuse("valid K0 record missing")
    try:
        record = r.read(path)
    except r.ReservationError as exc:
        refuse("valid K0 record missing: " + str(exc))
    problem = k0_problem(record, root, head)
    if problem:
        refuse("valid K0 record missing: " + problem)
    return record


def acquire_lock(root):
    try:
        fd = os.open(str(Path(root) / "LOCK"), os.O_RDWR | os.O_NOFOLLOW | os.O_CLOEXEC)
    except OSError:
        refuse("whole-operation lock not acquired")
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        os.close(fd)
        refuse("whole-operation lock not acquired")
    return fd


def lock_held(root):
    """True when another open file description already holds LOCK. Does not keep it."""
    try:
        fd = os.open(str(Path(root) / "LOCK"), os.O_RDWR | os.O_NOFOLLOW | os.O_CLOEXEC)
    except OSError:
        return False
    try:
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return True
        fcntl.flock(fd, fcntl.LOCK_UN)
        return False
    finally:
        os.close(fd)


def artefact_digests(clone):
    build = Path(clone) / "tools/dd1_linux/build"
    found = {}
    for name in ART_KEYS:
        path = build / name
        if path.is_symlink() or not path.is_file():
            found[name] = None
            continue
        try:
            found[name] = r.digest(path.read_bytes())
        except OSError:
            found[name] = None
    return found


def build_problems(observed, artefacts):
    import dd1_compatibility as compat
    import dd1_linux_snapshot as snap
    import dd1_meter_entry as entry
    import dd1_runtime_fit as fit
    reasons = []
    if not isinstance(artefacts, dict):
        return ["artefacts missing"]
    checks = (
        (artefacts.get("supervisor") == snap.PINNED_HELPER_SHA256, "supervisor pin mismatch"),
        (artefacts.get("inert") in entry.INERT_BINARIES, "inert pin mismatch"),
        (artefacts.get("compat2-inert") in entry.INERT_BINARIES, "compat2-inert pin mismatch"),
        (artefacts.get("fit-inert") == fit.INERT_BINARY, "fit-inert pin mismatch"),
        (artefacts.get("libc.so.6") == compat.LIBC, "libc pin mismatch"),
    )
    for ok, reason in checks:
        if not ok:
            reasons.append(reason)
    if type(observed) is int and observed > BUILD_RESERVE_NS:
        reasons.append("build cpu above 60s reserve")
    return reasons


def recompute_used(ledger):
    cpu = ledger["build"]["cpu_ns_charged"]
    raw_charged = 0
    raw_observed = 0
    releases = 0
    for row in ledger["rows"]:
        cpu += row["cpu_ns_charged"]
        raw_charged += row["raw_bytes_charged"]
        if row["raw_bytes_observed"] is not None:
            raw_observed += row["raw_bytes_observed"]
        if row["g"] == "SENT_OR_UNCERTAIN":
            releases += 1
    return dict(release_slots=len(ledger["rows"]), workload_releases=releases, cpu_ns_charged=cpu,
                raw_bytes_charged=raw_charged, raw_bytes_observed=raw_observed)


def reservation_fits(used, cpu_ns):
    return (type(used.get("release_slots")) is int and type(used.get("cpu_ns_charged")) is int
            and type(used.get("raw_bytes_charged")) is int and type(cpu_ns) is int
            and used["release_slots"] + 1 <= RELEASE_SLOTS
            and used["cpu_ns_charged"] + cpu_ns <= CPU_CAP_NS
            and used["raw_bytes_charged"] + CASE_RAW <= RAW_CAP)


def make_reserved_row(seq, case_id, cpu_ns):
    return dict(seq=seq, case_id=case_id, state="RESERVED", g="SENT_OR_UNCERTAIN",
                cpu_ns_reserved=cpu_ns, cpu_ns_observed=None, cpu_ns_charged=cpu_ns,
                raw_bytes_reserved=CASE_RAW, raw_bytes_observed=None, raw_bytes_charged=CASE_RAW,
                reserved_utc=stamp(), finished_utc=None, classification=None, reasons=[],
                record_sha256=None)


def _reasons_ok(value, empty):
    if not isinstance(value, list) or any(not isinstance(item, str) or not item for item in value):
        return False
    return (not value) if empty else bool(value)


def _row_shape(row, index, seen):
    if not isinstance(row, dict) or set(row) != ROW_KEYS:
        return "row keys"
    if type(row["seq"]) is not int or row["seq"] != index + 1:
        return "row seq"
    planned = row_for(row["case_id"]) if isinstance(row["case_id"], str) else None
    if planned is None:
        return "row case"
    if row["case_id"] in seen:
        return "duplicate case"
    seen.add(row["case_id"])
    cap = planned["cpu_cap"] * 1_000_000_000
    if type(row["cpu_ns_reserved"]) is not int or row["cpu_ns_reserved"] != cap:
        return "row cpu reserve"
    if type(row["raw_bytes_reserved"]) is not int or row["raw_bytes_reserved"] != CASE_RAW:
        return "row raw reserve"
    if not valid_stamp(row["reserved_utc"]):
        return "row reserved time"
    state = row["state"]
    if state == "RESERVED":
        ok = (row["g"] == "SENT_OR_UNCERTAIN" and row["cpu_ns_observed"] is None
              and row["raw_bytes_observed"] is None and row["cpu_ns_charged"] == row["cpu_ns_reserved"]
              and row["raw_bytes_charged"] == row["raw_bytes_reserved"] and row["finished_utc"] is None
              and row["classification"] is None and row["reasons"] == [] and row["record_sha256"] is None)
        return None if ok else "RESERVED row invariant"
    if state == "ABANDONED":
        ok = (row["g"] == "SENT_OR_UNCERTAIN" and row["cpu_ns_observed"] is None
              and row["raw_bytes_observed"] is None and row["cpu_ns_charged"] == row["cpu_ns_reserved"]
              and row["raw_bytes_charged"] == row["raw_bytes_reserved"] and valid_stamp(row["finished_utc"])
              and row["classification"] == "INCONCLUSIVE" and row["reasons"] == ["DANGLING_RESERVED_ROW"]
              and row["record_sha256"] is None)
        return None if ok else "ABANDONED row invariant"
    if state != "FINAL":
        return "row state"
    if row["g"] not in ("SENT_OR_UNCERTAIN", "NOT_SENT"):
        return "row g"
    if type(row["cpu_ns_observed"]) is not int or row["cpu_ns_observed"] < 0:
        return "row cpu observed"
    if type(row["raw_bytes_observed"]) is not int or row["raw_bytes_observed"] < 0:
        return "row raw observed"
    if row["cpu_ns_charged"] != max(row["cpu_ns_reserved"], row["cpu_ns_observed"]):
        return "row cpu charged"
    if row["raw_bytes_charged"] != max(row["raw_bytes_reserved"], row["raw_bytes_observed"]):
        return "row raw charged"
    if not valid_stamp(row["finished_utc"]) or row["classification"] not in FINAL_KINDS:
        return "row final fields"
    if row["classification"] == "NOT_REACHABLE_ON_HOST" and row["case_id"] != "KC15_IA32_REACHABILITY":
        return "NOT_REACHABLE_ON_HOST off KC15"
    stop = row["classification"] in STOPS
    if not _reasons_ok(row["reasons"], empty=not stop) or not _hex(row["record_sha256"], 64):
        return "row reasons or record"
    return None


def _stop(row):
    return row["state"] == "ABANDONED" or row.get("classification") in STOPS


def validate_ledger(ledger, head, k0_sha):
    if not isinstance(ledger, dict) or set(ledger) != TOP_KEYS:
        return "ledger keys"
    if ledger["schema"] != LEDGER_SCHEMA or ledger["operation"] != kq.OPERATION:
        return "ledger schema"
    if type(ledger["selection_comment"]) is not int or ledger["selection_comment"] != kq.SELECTION:
        return "ledger selection"
    if ledger["window"] != WINDOW or ledger["caps"] != CAPS:
        return "ledger window or caps"
    if ledger["head"] != head or not _hex(ledger["head"], 40) or ledger["k0_sha256"] != k0_sha or not _hex(k0_sha, 64):
        return "ledger head or k0"
    build = ledger["build"]
    if not isinstance(build, dict) or set(build) != BUILD_KEYS:
        return "build keys"
    if type(build["cpu_ns_reserved"]) is not int or build["cpu_ns_reserved"] != BUILD_RESERVE_NS:
        return "build reserve"
    if type(build["cpu_ns_observed"]) is not int or build["cpu_ns_observed"] < 0:
        return "build observed"
    if type(build["cpu_ns_charged"]) is not int or build["cpu_ns_charged"] != max(BUILD_RESERVE_NS, build["cpu_ns_observed"]):
        return "build charged"
    artefacts = build["artefacts_sha256"]
    if not isinstance(artefacts, dict) or set(artefacts) != set(ART_KEYS):
        return "build artefacts"
    for name in ART_KEYS:
        if artefacts[name] is not None and not _hex(artefacts[name], 64):
            return "build artefact hash"
    expected = build_problems(build["cpu_ns_observed"], artefacts)
    if build["status"] not in ("OK", "INCOMPATIBLE_BUILD") or build["reasons"] != expected:
        return "build status"
    if (build["status"] == "OK") != (not expected) or not valid_stamp(build["recorded_utc"]):
        return "build status"
    rows = ledger["rows"]
    if not isinstance(rows, list):
        return "rows"
    if build["status"] != "OK" and rows:
        return "build failure has releases"
    seen = set()
    for index, row in enumerate(rows):
        problem = _row_shape(row, index, seen)
        if problem:
            return problem
    if any(row["state"] == "RESERVED" and index != len(rows) - 1 for index, row in enumerate(rows)):
        return "RESERVED row is not last"
    stops = [index for index, row in enumerate(rows) if _stop(row)]
    if len(stops) > 1:
        return "more than one stop row"
    if len(stops) == 1 and stops[0] != len(rows) - 1:
        return "stop row is not last"
    used = ledger["used"]
    if not isinstance(used, dict) or set(used) != USED_KEYS:
        return "used keys"
    for key in USED_KEYS:
        if type(used[key]) is not int:
            return "used type"
    if used != recompute_used(ledger):
        return "used cache"
    should_latch = build["status"] != "OK" or bool(stops)
    latch = ledger["latch"]
    if (latch is not None) != should_latch:
        return "latch presence"
    if latch is not None:
        if not isinstance(latch, dict) or set(latch) != LATCH_KEYS or not valid_stamp(latch["latched_utc"]):
            return "latch keys"
        if not _reasons_ok(latch["reasons"], empty=False):
            return "latch reasons"
        if build["status"] != "OK":
            if latch["outcome"] != "INCOMPATIBLE_BUILD" or latch["case_id"] is not None:
                return "latch build"
        else:
            stop = rows[-1]
            if latch["outcome"] != stop["classification"] or latch["case_id"] != stop["case_id"] or not _stop(stop):
                return "latch row"
    if latch is None:
        if (used["release_slots"] > RELEASE_SLOTS or used["cpu_ns_charged"] > CPU_CAP_NS
                or used["raw_bytes_charged"] > RAW_CAP or used["workload_releases"] > used["release_slots"]):
            return "used over cap while open"
    return None


def g_evidence(account, case_id):
    if not isinstance(account, dict):
        return "SENT_OR_UNCERTAIN"
    recovery = account.get("recovery")
    rows = recovery.get("unit_reservations_v2") if isinstance(recovery, dict) else None
    if not isinstance(rows, list):
        return "NOT_SENT"
    match = None
    for item in rows:
        if isinstance(item, dict) and item.get("unit_id") == case_id:
            match = item
            break
    if not isinstance(match, dict) or "processes" not in match:
        return "NOT_SENT"
    return "SENT_OR_UNCERTAIN"


def _account_row(account, case_id):
    if not isinstance(account, dict):
        return None
    recovery = account.get("recovery")
    rows = recovery.get("unit_reservations_v2") if isinstance(recovery, dict) else None
    if not isinstance(rows, list):
        return None
    for item in rows:
        if isinstance(item, dict) and item.get("unit_id") == case_id:
            return item
    return None


def _want(container, key, expected, bad, inc, label, identical=False):
    if not isinstance(container, dict) or key not in container:
        inc.append(label + " absent")
        return
    value = container[key]
    if (value is not expected) if identical else (value != expected):
        bad.append(label)


def _want_int(container, key, expected, bad, inc, label):
    if not isinstance(container, dict) or key not in container:
        inc.append(label + " absent")
        return
    if type(container[key]) is not int or container[key] != expected:
        bad.append(label)


def _rep(z, key, expected, bad, inc):
    report = z.get("supervisor_report") if isinstance(z, dict) else None
    _want(report, key, expected, bad, inc, key)


def _capture(evidence, name):
    capture = evidence.get("capture")
    if not isinstance(capture, dict) or name not in capture or capture[name] is None:
        return None
    value = capture[name]
    if isinstance(value, str):
        return None
    if isinstance(value, (bytes, bytearray)):
        return bytes(value)
    return None


def _processes(row, evidence, bad, inc):
    if not isinstance(row, dict) or "processes" not in row:
        inc.append("processes absent")
        return
    procs = row["processes"]
    if not isinstance(procs, dict) or set(procs) != {"controller", "supervisor", "workload"}:
        bad.append("processes")
        return
    if "identities_absent" not in evidence:
        inc.append("identity absence absent")
    elif evidence["identities_absent"] is not True:
        bad.append("surviving process")


def _source_same(evidence, bad, inc):
    if "source_same" not in evidence:
        inc.append("source identity absent")
    elif evidence["source_same"] is not True:
        bad.append("source identity drift")


def _success_is(z, expected, bad):
    if isinstance(z, dict) and "success" in z and z["success"] is not expected:
        bad.append("success value")


def _common_b(case_id, evidence, z, row, bad, inc):
    import dd1_linux_snapshot as snap
    planned = row_for(case_id)
    if "exit" not in evidence:
        inc.append("exit absent")
    elif evidence["exit"] != 0:
        bad.append("controller exit")
    if "success" not in z:
        inc.append("z.success absent")
        success = None
    elif type(z["success"]) is not bool:
        bad.append("z.success")
        success = None
    else:
        success = z["success"]
    _want(z, "cleanup_confirmed", True, bad, inc, "cleanup_confirmed", identical=True)
    _want(z, "native_qualified", False, bad, inc, "native_qualified", identical=True)
    _want(z, "n0_accepted", False, bad, inc, "n0_accepted", identical=True)
    _want(z, "helper_sha256", snap.PINNED_HELPER_SHA256, bad, inc, "helper_sha256")
    _want_int(row, "starts", 1, bad, inc, "starts")
    _want_int(row, "cpu_ns", planned["cpu_cap"] * 1_000_000_000, bad, inc, "cpu_ns")
    if "unit_raw_bytes" not in evidence:
        inc.append("unit raw absent")
    else:
        _want_int(row, "raw_bytes", evidence["unit_raw_bytes"], bad, inc, "raw_bytes")
    if success is True:
        _want(row, "state", "COMPLETE", bad, inc, "state")
    elif success is False:
        _want(row, "state", "FAILED", bad, inc, "state")
    elif "state" not in row:
        inc.append("state absent")
    _processes(row, evidence, bad, inc)
    _source_same(evidence, bad, inc)


def _kc09(evidence, row, bad, inc):
    if "killed" not in evidence:
        inc.append("kill absent")
    elif evidence["killed"] != "controller":
        bad.append("controller not signalled")
    if "exit" not in evidence:
        inc.append("exit absent")
    elif evidence["exit"] != -9:
        bad.append("controller exit")
    _want(row, "state", "RESERVED", bad, inc, "state")
    _processes(row, evidence, bad, inc)
    _want_int(row, "cpu_ns", 12 * 1_000_000_000, bad, inc, "cpu_ns")
    if "unit_raw_bytes" not in evidence:
        inc.append("unit raw absent")
    else:
        _want_int(row, "raw_bytes", evidence["unit_raw_bytes"], bad, inc, "raw_bytes")


def _contains(evidence, name, needle, bad, inc, label):
    data = _capture(evidence, name)
    if data is None:
        inc.append(label + " absent")
    elif needle not in data:
        bad.append(label)


def _exact(evidence, name, expected, bad, inc, label):
    data = _capture(evidence, name)
    if data is None:
        inc.append(label + " absent")
    elif data != expected:
        bad.append(label)


def _number(report, key, bad, inc):
    if not isinstance(report, dict) or key not in report:
        inc.append(key + " absent")
        return None
    value = report[key]
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        bad.append(key)
        return None
    return value


def _ia32(z, bad, inc):
    report = z.get("supervisor_report") if isinstance(z, dict) else None
    if not isinstance(report, dict) or "signal" not in report:
        inc.append("rep.signal absent")
        return "EXPECTED"
    number = report["signal"]
    if number == 31:
        return "EXPECTED"
    if number == 11 and z.get("success") is False:
        return "NOT_REACHABLE_ON_HOST"
    bad.append("ia32 outcome")
    return "INCOMPATIBLE"


def _predicates(case_id, evidence, z, row, bad, inc):
    if case_id == "KC09_CONTROLLER_KILL":
        _kc09(evidence, row, bad, inc)
        return
    _common_b(case_id, evidence, z, row, bad, inc)
    if case_id == "KC01_STRICT_POSITIVE":
        _success_is(z, True, bad)
        _rep(z, "thread_births_including_main", 3, bad, inc)
        _rep(z, "execs", 1, bad, inc)
        _exact(evidence, "save.json", b'{"v":2}\n', bad, inc, "save.json")
        _contains(evidence, "stdout.bin", b"OK SAVE THREADS", bad, inc, "stdout.bin")
    elif case_id == "KC02_READONLY_ESCAPE":
        _success_is(z, True, bad)
        _contains(evidence, "stdout.bin", b"ISOLATED", bad, inc, "stdout.bin")
        if "src_input" not in evidence or evidence["src_input"] is None:
            inc.append("input absent")
        elif evidence["src_input"] != b"IMMUTABLE\n":
            bad.append("input bytes")
        for name in ("src_moved", "src_hardlink", "src_original"):
            if name not in evidence:
                inc.append(name + " absent")
            elif evidence[name] is not False:
                bad.append(name)
    elif case_id == "KC03_CLONE3_FALLBACK":
        report = z.get("supervisor_report") if isinstance(z.get("supervisor_report"), dict) else None
        if report is None or "clone3_denied" not in report:
            inc.append("clone3_denied absent")
        elif type(report["clone3_denied"]) is not int or report["clone3_denied"] < 1:
            bad.append("clone3_denied")
        _rep(z, "thread_births_including_main", 1, bad, inc)
        _contains(evidence, "stdout.bin", b"errno=38", bad, inc, "stdout.bin")
    elif case_id == "KC04_STRICT_THREAD_CEILING":
        _success_is(z, False, bad)
        _rep(z, "last_denied_syscall", 56, bad, inc)
        _rep(z, "execs", 1, bad, inc)
        _rep(z, "thread_births_including_main", 4, bad, inc)
    elif case_id == "KC05_CPU_EXHAUST":
        import dd1_linux_backend as backend
        _success_is(z, False, bad)
        _rep(z, "signal", 9, bad, inc)
        _rep(z, "thread_births_including_main", 3, bad, inc)
        limit = backend.cpu_partition(20)["workload"]
        seconds = _number(z.get("supervisor_report"), "workload_cpu_seconds", bad, inc)
        if seconds is not None and not (limit - 0.1 <= seconds < limit + 1):
            bad.append("workload_cpu_seconds")
    elif case_id == "KC06_RAW_OVERWRITE":
        _success_is(z, False, bad)
        _rep(z, "last_denied_syscall", 18, bad, inc)
        report = z.get("supervisor_report") if isinstance(z.get("supervisor_report"), dict) else None
        if report is None or "reserved_before_writes" not in report or "raw_cap" not in report:
            inc.append("raw_cap absent")
        elif report["reserved_before_writes"] != report["raw_cap"]:
            bad.append("reserved_before_writes")
        if "capture_bytes" not in evidence:
            inc.append("capture bytes absent")
        elif report is not None and "raw_cap" in report and not (
                type(evidence["capture_bytes"]) is int and type(report["raw_cap"]) is int
                and evidence["capture_bytes"] < report["raw_cap"]):
            bad.append("capture bytes")
    elif case_id == "KC07_SOCKET_DENY":
        _success_is(z, False, bad)
        _rep(z, "last_denied_syscall", 41, bad, inc)
        _rep(z, "execs", 1, bad, inc)
        _rep(z, "thread_births_including_main", 1, bad, inc)
    elif case_id == "KC08_X32_ABI_KILL":
        _success_is(z, False, bad)
        _rep(z, "signal", 31, bad, inc)
        data = _capture(evidence, "stdout.bin")
        if data is None:
            inc.append("stdout.bin absent")
        elif b"BAD" in data:
            bad.append("BAD write")
    elif case_id == "KC10_SUPERVISOR_KILL":
        _success_is(z, False, bad)
        if "killed" not in evidence:
            inc.append("kill absent")
        elif evidence["killed"] != "supervisor":
            bad.append("supervisor not signalled")
    elif case_id == "KC11_COMPAT_COMBINED":
        _success_is(z, True, bad)
        _want(z, "compatibility_verdict", True, bad, inc, "compatibility_verdict", identical=True)
        _want(z, "strict_verdict", False, bad, inc, "strict_verdict", identical=True)
        classes = z.get("classification") if isinstance(z.get("classification"), dict) else None
        _want_int(classes, "process_refusals", 1, bad, inc, "process_refusals")
        _want_int(classes, "naming_refusals", 1, bad, inc, "naming_refusals")
        requests = z.get("refused_requests")
        if not isinstance(requests, list):
            inc.append("refused_requests absent")
        elif any(not isinstance(item, dict) or item.get("attribution") != "CAPABILITY_CLASS_ONLY" for item in requests):
            bad.append("attribution")
        _exact(evidence, "save.bin", b"COMPAT2\n", bad, inc, "save.bin")
        if "src_frozen" not in evidence or evidence["src_frozen"] is None:
            inc.append("frozen absent")
        elif evidence["src_frozen"] != b"FROZEN-INERT\n":
            bad.append("frozen bytes")
    elif case_id == "KC12_CPU_ABOVE_3":
        _success_is(z, True, bad)
        classes = z.get("classification") if isinstance(z.get("classification"), dict) else None
        _want_int(classes, "workload_cpu_soft", 6, bad, inc, "workload_cpu_soft")
        _want_int(classes, "workload_cpu_hard", 6, bad, inc, "workload_cpu_hard")
        _want(z, "controller_cpu_limits", [3, 3], bad, inc, "controller_cpu_limits")
        _want_int(classes, "supervisor_cpu_soft", 2, bad, inc, "supervisor_cpu_soft")
        _want_int(classes, "supervisor_cpu_hard", 2, bad, inc, "supervisor_cpu_hard")
        seconds = _number(z.get("supervisor_report"), "workload_cpu_seconds", bad, inc)
        if seconds is not None and not seconds > 4:
            bad.append("workload_cpu_seconds")
        if "src_frozen" not in evidence or evidence["src_frozen"] is None:
            inc.append("frozen absent")
        elif evidence["src_frozen"] != b"FROZEN-INERT\n":
            bad.append("frozen bytes")
    elif case_id == "KC13_FIT_14_BOUNDARY":
        _success_is(z, True, bad)
        _rep(z, "thread_limit", 14, bad, inc)
        _rep(z, "profile_mode", 2, bad, inc)
        _exact(evidence, "save.bin", b"FIT1\n", bad, inc, "save.bin")
        _contains(evidence, "stdout.bin", b"MODE:0555 owner=1 group=1 other=1", bad, inc, "stdout.bin")
    elif case_id == "KC14_FIT_NEXT_BIRTH_DENY":
        _success_is(z, False, bad)
    elif case_id == "KC16_NESTED_NAMESPACE_DENY":
        _success_is(z, False, bad)
        _rep(z, "last_denied_syscall", 272, bad, inc)
        _rep(z, "execs", 1, bad, inc)
        _rep(z, "thread_births_including_main", 1, bad, inc)


def classify(case_id, evidence):
    """Return (classification, reasons) from a plain evidence dict. No kernel and no I/O."""
    bad, inc = [], []
    if not isinstance(evidence, dict) or row_for(case_id) is None:
        return "INCONCLUSIVE", ["evidence absent"]
    if evidence.get("exception") is True:
        inc.append("exception after reservation")
    if evidence.get("timeout") is True:
        inc.append("controller timeout")
    if evidence.get("stdout_one") is not True:
        inc.append("controller stdout is not one JSON object")
    z = evidence.get("z") if evidence.get("stdout_one") is True else None
    if not isinstance(z, dict):
        z = None
    if isinstance(z, dict) and "pre_release_error" in z:
        inc.append("pre_release_error")
    if evidence.get("account_readable") is not True:
        inc.append("per-case account unreadable")
    row = evidence.get("row") if evidence.get("account_readable") is True else None
    if evidence.get("account_readable") is True and not isinstance(row, dict):
        inc.append("per-case row unreadable")
        row = None
    if case_id in ("KC09_CONTROLLER_KILL", "KC10_SUPERVISOR_KILL") and evidence.get("live") is not True:
        inc.append("kill case never reached LIVE")
    if isinstance(z, dict) and isinstance(row, dict):
        _predicates(case_id, evidence, z, row, bad, inc)
    kind = "EXPECTED"
    if case_id == "KC15_IA32_REACHABILITY" and isinstance(z, dict) and isinstance(row, dict) and not bad and not inc:
        kind = _ia32(z, bad, inc)
    if bad:
        return "INCOMPATIBLE", bad + inc
    if inc:
        return "INCONCLUSIVE", inc
    return kind, []


def apply_audits(classification, reasons, case_raw, cpu_charged, retained):
    found = list(reasons)
    if type(case_raw) is int and case_raw > CASE_RAW:
        found.append("CASE_EVIDENCE_OVER_8MIB")
        classification = "INCOMPATIBLE"
    over = False
    if type(cpu_charged) is int and cpu_charged > CPU_CAP_NS:
        found.append("OPERATION_CPU_OVER_CAP")
        over = True
    if type(retained) is int and retained > RAW_CAP:
        found.append("OPERATION_RETAINED_OVER_128MIB")
        over = True
    if classification != "INCOMPATIBLE" and over:
        classification = "INCONCLUSIVE"
    return classification, found


def tree_bytes(root, skip=None):
    root = Path(root)
    try:
        if not root.exists() and not root.is_symlink():
            return 0
        if root.is_symlink():
            return root.lstat().st_size
    except OSError:
        return 0
    skip_resolved = None
    if skip is not None:
        try:
            skip_resolved = Path(skip).resolve()
            if root.resolve() == skip_resolved:
                return 0
        except OSError:
            skip_resolved = None
    total = 0
    for dirpath, dirnames, filenames in os.walk(root, followlinks=False):
        current = Path(dirpath)
        kept = []
        for name in dirnames:
            child = current / name
            try:
                if child.is_symlink():
                    total += child.lstat().st_size
                    continue
                if skip_resolved is not None and child.resolve() == skip_resolved:
                    continue
            except OSError:
                continue
            kept.append(name)
        dirnames[:] = kept
        for name in filenames:
            try:
                total += (current / name).lstat().st_size
            except OSError:
                pass
    return total


def case_observed_raw(case_dir):
    case_dir = Path(case_dir)
    return tree_bytes(case_dir, skip=case_dir / "source")


def retained_bytes(root, ledger_len):
    total = tree_bytes(operation_dir(root))
    k0 = Path(root) / "K0.json"
    try:
        if k0.is_symlink() or k0.is_file():
            total += k0.lstat().st_size
    except OSError:
        pass
    return total + ledger_len


def one_object(text):
    if not isinstance(text, str) or not text.strip():
        return None
    try:
        value = json.loads(text.strip())
    except ValueError:
        return None
    if not isinstance(value, dict):
        return None
    return value


def _read_bytes(path):
    try:
        if path.is_symlink() or not path.is_file():
            return None
        return path.read_bytes()
    except OSError:
        return None


def _exists(path):
    try:
        return path.exists()
    except OSError:
        return False


def assemble_evidence(row, where, unit, account, outcome):
    parsed = one_object(outcome.get("stdout"))
    readable = isinstance(account, dict)
    case_row = _account_row(account, row["case_id"]) if readable else None
    output = None
    if isinstance(unit, dict):
        output = unit.get("linux", {}).get("output_root") if isinstance(unit.get("linux"), dict) else None
    capture_dir = Path(output) / "capture" if isinstance(output, str) else None
    capture = {}
    for name in ("save.json", "stdout.bin", "save.bin"):
        capture[name] = _read_bytes(capture_dir / name) if capture_dir is not None else None
    src = Path(where) / "source" if where is not None else Path("source")
    if where is not None:
        try:
            meta = r.read(Path(where) / "paths.json")
            if isinstance(meta.get("repo"), str):
                src = Path(meta["repo"])
        except (OSError, r.ReservationError, AttributeError, TypeError):
            pass
    idents = []
    if isinstance(case_row, dict) and isinstance(case_row.get("processes"), dict):
        idents = [item for item in case_row["processes"].values() if isinstance(item, dict)]
    try:
        absent = all(_identity_absent(item) for item in idents) if idents else False
    except Exception:
        absent = False
    before, after = outcome.get("before"), outcome.get("after")
    killed = outcome.get("killed")
    measured = before is not None and after is not None
    return dict(
        exit=outcome.get("exit_code"), stdout_one=parsed is not None, z=parsed,
        account_readable=readable, row=case_row, exception=outcome.get("exc") is not None,
        timeout=outcome.get("timed_out") is True,
        live=(killed in ("controller", "supervisor")) if row.get("kill") else True,
        killed=killed if killed in ("controller", "supervisor") else None,
        identities_absent=absent, source_same=(before == after) if measured else True,
        unit_raw_bytes=unit.get("raw_bytes") if isinstance(unit, dict) else CASE_RAW,
        capture=capture, capture_bytes=tree_bytes(capture_dir) if capture_dir is not None else 0,
        src_input=_read_bytes(src / "input"), src_moved=_exists(src / "moved"),
        src_hardlink=_exists(src / "hardlink"), src_original=_exists(src / "original"),
        src_frozen=_read_bytes(src / "inputs" / "frozen.txt"))


def _set_latch(ledger, row):
    if row["classification"] not in STOPS or ledger.get("latch") is not None:
        return
    ledger["latch"] = dict(outcome=row["classification"], case_id=row["case_id"],
                           reasons=list(row["reasons"]), latched_utc=stamp())


def finalise(args, row, ledger, path, outcome):
    where = outcome.get("where") or case_directory(args.root, row["case_id"])
    account = None
    if outcome.get("account_path") is not None:
        try:
            account = r.read(outcome["account_path"])
        except (OSError, r.ReservationError):
            account = None
    evidence = assemble_evidence(row, where, outcome.get("unit"), account, outcome)
    kind, base = classify(row["case_id"], evidence)
    try:
        Path(where).mkdir(parents=True, exist_ok=True)
    except OSError:
        return False
    record = dict(
        schema=CASE_SCHEMA, case_id=row["case_id"], operation=kq.OPERATION, selection=kq.SELECTION,
        head=args.head, cpu_cap=row["cpu_cap"], required_observation=row["required_observation"],
        classification=kind, reasons=list(base), child_exit=outcome.get("exit_code"),
        result=evidence.get("z"), stderr=str(outcome.get("stderr") or "")[:2048],
        charge=evidence.get("row"), source_before=outcome.get("before"), source_after=outcome.get("after"),
        identities_absent=evidence.get("identities_absent"), g=g_evidence(account, row["case_id"]))
    record_path = Path(where) / "CASE-RECORD.json"
    try:
        r.atomic_write(record_path, record)
        record_sha = r.digest(record_path.read_bytes())
    except (OSError, r.ReservationError):
        return False
    observed_cpu = _observed_cpu_ns()
    observed_raw = case_observed_raw(where)
    current = ledger["rows"][-1]
    if current["case_id"] != row["case_id"] or current["state"] != "RESERVED":
        return False
    current["g"] = g_evidence(account, row["case_id"])
    current["cpu_ns_observed"] = observed_cpu
    current["raw_bytes_observed"] = observed_raw
    current["cpu_ns_charged"] = max(current["cpu_ns_reserved"], observed_cpu)
    current["raw_bytes_charged"] = max(current["raw_bytes_reserved"], observed_raw)
    current["finished_utc"] = stamp()
    current["record_sha256"] = record_sha
    current["state"] = "FINAL"
    classification, reasons = kind, list(base)
    saved_latch = ledger["latch"]
    for _pass in range(2):
        current["classification"] = classification
        current["reasons"] = reasons
        ledger["latch"] = saved_latch
        if classification in STOPS and ledger["latch"] is None:
            ledger["latch"] = dict(outcome=classification, case_id=row["case_id"],
                                   reasons=list(reasons), latched_utc=stamp())
        ledger["used"] = recompute_used(ledger)
        retained = retained_bytes(args.root, len(r.encode(ledger)))
        classification, reasons = apply_audits(
            kind, base, observed_raw, ledger["used"]["cpu_ns_charged"], retained)
    current["classification"] = classification
    current["reasons"] = reasons
    ledger["latch"] = saved_latch
    _set_latch(ledger, current)
    ledger["used"] = recompute_used(ledger)
    k0_sha = r.digest((Path(args.root) / "K0.json").read_bytes())
    problem = validate_ledger(ledger, args.head, k0_sha)
    if problem:
        sys.stderr.write("ledger self-check: " + problem + "\n")
        return False
    try:
        r.atomic_write(path, ledger)
    except (OSError, r.ReservationError):
        return False
    sys.stdout.write(json.dumps(dict(record=record, ledger_row=current), sort_keys=True) + "\n")
    return True


def collect(args, row, k0):
    outcome = dict(exc=None, timed_out=False, killed=None, exit_code=None, stdout=None, stderr="",
                   before=None, after=None, where=None, unit=None, account_path=None)
    repo = Path(k0["clone"]["path"])
    proc = None
    try:
        outcome["before"] = source_identity(repo, row["source_file"])
        where, unit, account_path = stage(args.root, repo, row, args.head)
        outcome["where"], outcome["unit"], outcome["account_path"] = where, unit, account_path
        proc = spawn(args.head, args.root, args.case)
        if row.get("kill"):
            identities = wait_live(proc, unit["linux"]["output_root"], account_path)
            if identities and proc.poll() is None:
                try:
                    _signal_pid(identities[row["kill"]]["pid"], signal.SIGKILL)
                    outcome["killed"] = row["kill"]
                except OSError:
                    outcome["killed"] = None
        try:
            out, err = proc.communicate(timeout=90)
        except subprocess.TimeoutExpired:
            outcome["timed_out"] = True
            proc.kill()
            out, err = proc.communicate()
        outcome["stdout"] = out
        outcome["stderr"] = err or ""
        outcome["exit_code"] = proc.returncode
        outcome["after"] = source_identity(repo, row["source_file"])
    except BaseException as exc:
        outcome["exc"] = exc
        if proc is not None and proc.poll() is None:
            try:
                proc.kill()
                proc.communicate()
            except Exception:
                pass
        if outcome["after"] is None:
            try:
                outcome["after"] = source_identity(repo, row["source_file"])
            except Exception:
                pass
    return outcome


def abandon(path, ledger):
    row = ledger["rows"][-1]
    row["state"] = "ABANDONED"
    row["g"] = "SENT_OR_UNCERTAIN"
    row["cpu_ns_observed"] = None
    row["raw_bytes_observed"] = None
    row["cpu_ns_charged"] = row["cpu_ns_reserved"]
    row["raw_bytes_charged"] = row["raw_bytes_reserved"]
    row["finished_utc"] = stamp()
    row["classification"] = "INCONCLUSIVE"
    row["reasons"] = ["DANGLING_RESERVED_ROW"]
    row["record_sha256"] = None
    ledger["latch"] = dict(outcome="INCONCLUSIVE", case_id=row["case_id"],
                           reasons=["DANGLING_RESERVED_ROW"], latched_utc=stamp())
    ledger["used"] = recompute_used(ledger)
    k0_sha = r.digest((path.parent / "K0.json").read_bytes())
    if validate_ledger(ledger, ledger["head"], k0_sha):
        return False
    try:
        r.atomic_write(path, ledger)
    except (OSError, r.ReservationError):
        return False
    return True


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
    account_path = where / "ACCOUNT.json"
    account_path.write_bytes(r.encode(synthetic_account()))
    names = snap.HELPER_SOURCES | {"res://tools/dd1_linux/inert.c"}
    staged = repo
    extra = []
    if row["case_id"] == "KC02_READONLY_ESCAPE":
        src = where / "source"
        for name in names:
            dest = src / name[6:]
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes((repo / name[6:]).read_bytes())
        for binary in ("supervisor", "inert"):
            dest = src / "tools/dd1_linux/build" / binary
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes((repo / "tools/dd1_linux/build" / binary).read_bytes())
        (src / "input").write_bytes(b"IMMUTABLE\n")
        files = {name: r.digest((src / name[6:]).read_bytes()) for name in names}
        files["res://input"] = r.digest(b"IMMUTABLE\n")
        helper = src / "tools/dd1_linux/build/supervisor"
        inert = src / "tools/dd1_linux/build/inert"
        staged = src
        extra = [str(src / "input")]
    else:
        files = {name: r.digest((repo / name[6:]).read_bytes()) for name in names}
        helper = repo / "tools/dd1_linux/build/supervisor"
        inert = repo / "tools/dd1_linux/build/inert"
    unit = dict(schema="DD1-COMPLETE-UNIT-DEMAND-2", operation=kq.OPERATION, overlay_head=head,
                unit_id=row["case_id"], mode="inert_control", contained_starts=0,
                source_files=files, argv=list(row["argv_tokens"]),
                linux=dict(abi=snap.ABI, entry="/workload", threads=4, workload_raw_bytes=65536,
                           helper=dict(path="tools/dd1_linux/build/supervisor", sha256=r.digest(helper.read_bytes())),
                           runtime={"/workload": dict(path="tools/dd1_linux/build/inert",
                                                      sha256=r.digest(inert.read_bytes()), executable=True)}))
    apply_k1(unit, head, account_path, row)
    if extra:
        unit["argv"] = list(row["argv_tokens"]) + extra
    return unit, account_path, staged


def build_compat(where, repo, row, head):
    import compat2_controls as compat
    where.mkdir(parents=True, exist_ok=False)
    compat.HEAD = head
    unit, staged = compat.make_unit(where, mode=row["mode"], cpu=row["cpu_cap"], repo=None,
                                    existing_account=synthetic_account())
    account_path = where / "synthetic-account.json"
    apply_k1(unit, head, account_path, row)
    unit["compatibility"] = compat.profile(unit)
    unit["compatibility"]["kernel_qualification_sha256"] = r.digest(r.encode(unit["kernel_qualification"]))
    unit["account_sha256"] = r.digest(account_path.read_bytes())
    return unit, account_path, staged


def build_fit(where, repo, row, head):
    import fit_controls as fitctl
    fitctl.HEAD = head
    unit, staged, account_path = fitctl.make(where, mode="sequential", threads=row["threads"],
                                             births=row["births"], repo=None)
    account_path.write_bytes(r.encode(synthetic_account()))
    apply_k1(unit, head, account_path, row)
    fitctl.bind(unit, staged)
    unit["compatibility"]["kernel_qualification_sha256"] = r.digest(r.encode(unit["kernel_qualification"]))
    unit["linux"]["output_root"] = str((where / "output").resolve())
    unit["account_sha256"] = r.digest(account_path.read_bytes())
    return unit, account_path, staged


def stage(root, repo, row, head):
    where = case_directory(root, row["case_id"])
    where.parent.mkdir(parents=True, exist_ok=True)
    if where.exists() or where.is_symlink():
        raise RuntimeError("case directory already exists")
    source = row["source_file"]
    if source == "inert.c":
        unit, account_path, staged = build_inert(where, repo, row, head)
    elif source == "compat2_inert.c":
        unit, account_path, staged = build_compat(where, repo, row, head)
    elif source == "fit_inert.c":
        unit, account_path, staged = build_fit(where, repo, row, head)
    else:
        raise RuntimeError("unknown fixture")
    if unit["overlay_head"] != head or unit["kernel_qualification"]["source_head"] != head:
        raise RuntimeError("head is not bound to the unit")
    if unit["kernel_qualification"]["selection"] != kq.SELECTION:
        raise RuntimeError("owner selection mismatch")
    sign(where, unit)
    r.atomic_write(where / "paths.json", dict(account=str(account_path), receipt=str(where / "receipt.json"),
                                              output=unit["linux"]["output_root"], repo=str(staged),
                                              argv=unit["argv"]))
    return where, unit, account_path


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


def preflight(args):
    if row_for(args.case) is None:
        refuse("unknown case")
    if re.fullmatch(r"[0-9a-f]{40}", args.head) is None:
        refuse("exact K1 head required")
    window_open()
    return load_k0(args.root, args.head)


def controller_reserved(args, k0):
    """Read-only guard. The parent already holds LOCK; this process must not take it."""
    if location_problem(args.root, k0["clone"]["path"]):
        return False
    path = ledger_file(args.root)
    if path.is_symlink() or not path.is_file():
        return False
    try:
        ledger = r.read(path)
        k0_sha = r.digest((Path(args.root) / "K0.json").read_bytes())
    except (OSError, r.ReservationError):
        return False
    if validate_ledger(ledger, args.head, k0_sha):
        return False
    rows = ledger["rows"]
    return bool(rows) and rows[-1].get("case_id") == args.case and rows[-1].get("state") == "RESERVED"


def controller_main(args):
    k0 = preflight(args)
    if not lock_held(args.root):
        refuse("whole-operation lock not held")
    if not controller_reserved(args, k0):
        sys.stdout.write(json.dumps({"pre_release_error": "no durable K2 ledger reservation"}) + "\n")
        return 2
    where = case_directory(args.root, args.case)
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
    if row is None:
        refuse("unknown case")
    if re.fullmatch(r"[0-9a-f]{40}", args.head) is None:
        refuse("exact K1 head required")
    window_open()
    fd = acquire_lock(args.root)
    try:
        k0 = load_k0(args.root, args.head)
        clone = k0["clone"]["path"]
        located = location_problem(args.root, clone)
        if located:
            refuse(located)
        path = ledger_file(args.root)
        if path.is_symlink() or not path.is_file():
            refuse("ledger missing")
        try:
            ledger = r.read(path)
        except r.ReservationError as exc:
            refuse("ledger unreadable: " + str(exc))
        k0_sha = r.digest((Path(args.root) / "K0.json").read_bytes())
        problem = validate_ledger(ledger, args.head, k0_sha)
        if problem:
            refuse(problem)
        if ledger["rows"] and ledger["rows"][-1]["state"] == "RESERVED":
            if abandon(path, ledger):
                refuse("dangling reserved row", mutated=True)
            refuse("dangling reserved row")
        if ledger["latch"] is not None:
            refuse("ledger latched")
        if any(item["case_id"] == args.case for item in ledger["rows"]):
            refuse("case already recorded")
        where = case_directory(args.root, args.case)
        if where.exists() or where.is_symlink():
            refuse("case directory already exists")
        cap_ns = row["cpu_cap"] * 1_000_000_000
        if not reservation_fits(ledger["used"], cap_ns):
            refuse("reservation exceeds operation cap")
        ledger["rows"].append(make_reserved_row(len(ledger["rows"]) + 1, args.case, cap_ns))
        ledger["used"] = recompute_used(ledger)
        problem = validate_ledger(ledger, args.head, k0_sha)
        if problem:
            refuse("reservation failed self-check: " + problem)
        try:
            r.atomic_write(path, ledger)
        except (OSError, r.ReservationError):
            refuse("reservation write failed")
        outcome = collect(args, row, k0)
        wrote = finalise(args, row, ledger, path, outcome)
        if isinstance(outcome.get("exc"), KeyboardInterrupt):
            raise outcome["exc"]
        if isinstance(outcome.get("exc"), SystemExit):
            raise outcome["exc"]
        return 0 if wrote and outcome.get("exc") is None else 2
    finally:
        os.close(fd)


def init_main(args):
    if re.fullmatch(r"[0-9a-f]{40}", args.head) is None:
        refuse("exact K1 head required")
    if args.build_cpu_ns is None or re.fullmatch(r"[0-9]+", args.build_cpu_ns) is None:
        refuse("build cpu nanoseconds required")
    observed = int(args.build_cpu_ns, 10)
    window_open()
    fd = acquire_lock(args.root)
    try:
        k0 = load_k0(args.root, args.head)
        clone = k0["clone"]["path"]
        located = location_problem(args.root, clone)
        if located:
            refuse(located)
        path = ledger_file(args.root)
        if path.exists() or path.is_symlink():
            refuse("ledger already exists")
        case_root = operation_dir(args.root)
        if case_root.is_symlink() or (case_root.exists() and (not case_root.is_dir() or any(case_root.iterdir()))):
            refuse("case root is not an empty directory")
        artefacts = artefact_digests(clone)
        reasons = build_problems(observed, artefacts)
        status = "INCOMPATIBLE_BUILD" if reasons else "OK"
        charged = max(BUILD_RESERVE_NS, observed)
        k0_sha = r.digest((Path(args.root) / "K0.json").read_bytes())
        recorded = stamp()
        build = dict(cpu_ns_reserved=BUILD_RESERVE_NS, cpu_ns_observed=observed, cpu_ns_charged=charged,
                     artefacts_sha256=artefacts, status=status, reasons=reasons, recorded_utc=recorded)
        latch = None
        if status != "OK":
            latch = dict(outcome="INCOMPATIBLE_BUILD", case_id=None, reasons=list(reasons), latched_utc=recorded)
        ledger = dict(
            schema=LEDGER_SCHEMA, operation=kq.OPERATION, selection_comment=kq.SELECTION,
            window=dict(WINDOW), head=args.head, k0_sha256=k0_sha, caps=dict(CAPS), build=build,
            used=dict(release_slots=0, workload_releases=0, cpu_ns_charged=charged,
                      raw_bytes_charged=0, raw_bytes_observed=0),
            rows=[], latch=latch)
        problem = validate_ledger(ledger, args.head, k0_sha)
        if problem:
            refuse("ledger failed self-check: " + problem)
        r.atomic_write(path, ledger)
        sys.stdout.write(json.dumps(dict(initialised=True, status=status), sort_keys=True) + "\n")
        return 0
    finally:
        os.close(fd)


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("--head", required=True)
    parser.add_argument("--root", required=True)
    parser.add_argument("--case", default=None)
    parser.add_argument("--init-ledger", action="store_true")
    parser.add_argument("--build-cpu-ns", default=None)
    args = parser.parse_args(argv)
    try:
        if args.init_ledger and args.case:
            refuse("--case and --init-ledger cannot be combined")
        if args.init_ledger:
            return init_main(args)
        if not args.case:
            refuse("--case is required")
        if os.environ.get(CONTROLLER) == "1":
            return controller_main(args)
        return driver_main(args)
    except SystemExit:
        raise
    except Exception as exc:
        refuse(type(exc).__name__ + ": " + str(exc))


if __name__ == "__main__":
    sys.exit(main())
