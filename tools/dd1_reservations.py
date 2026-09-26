"""Before-child complete-unit reservations. Legacy observations are immutable.

The runner dependency is an internal seam for inert tests. Native entry supplies
the fixed Linux backend, never a caller-selected runner. A reservation stays
fully charged on failure, interruption, or incomplete final reporting; no refund.
"""
from __future__ import annotations
from contextlib import contextmanager
from copy import deepcopy
from datetime import datetime, timezone
import fcntl
from contextvars import ContextVar

_lease = ContextVar("dd1_executor_lease", default=-1)
_active_reservation = ContextVar("dd1_active_reservation", default=None)
import hashlib
import json
import math
import os
from pathlib import Path
import re
import tempfile
from typing import Callable, Mapping

STARTS_CAP, CPU_CAP, RAW_CAP = 2048, 14_400_000_000_000, 1_073_741_824
FIRST, DEADLINE = "2026-09-17T17:54:40Z", "2026-09-24T17:54:40Z"
OPERATION = "DD1-N0-RECOVERY-1"
M = "07b5aa9dec8436132a524511d5438c510e322070"


class ReservationError(RuntimeError):
    pass


def need(condition: bool, reason: str) -> None:
    if not condition:
        raise ReservationError(reason)


def natural(value, name: str) -> int:
    need(type(value) is int and value >= 0, "invalid nonnegative integer: " + name)
    return value


def digest(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def encode(value) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False) + "\n").encode()


def read(path: Path) -> dict:
    def pairs(items):
        out = {}
        for key, value in items:
            need(key not in out, "duplicate JSON key")
            out[key] = value
        return out
    def bad(_):
        raise ReservationError("nonfinite JSON")
    try:
        value = json.loads(path.read_bytes(), object_pairs_hook=pairs, parse_constant=bad)
    except (ValueError, OSError, UnicodeError) as exc:
        raise ReservationError("cannot read JSON: " + str(path)) from exc
    need(isinstance(value, dict), "JSON object required")
    return value


def atomic_write(path: Path, value: Mapping) -> None:
    need(not path.is_symlink(), "symbolic output forbidden")
    raw = encode(value)
    fd, name = tempfile.mkstemp(prefix="." + path.name + ".", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as file:
            file.write(raw)
            file.flush()
            os.fsync(file.fileno())
        os.replace(name, path)
        directory = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
        need(path.read_bytes() == raw, "atomic write readback mismatch")
    finally:
        if os.path.exists(name):
            os.unlink(name)


@contextmanager
def account_lock(path: Path):
    need(path.is_file() and not path.is_symlink(), "missing or symbolic account")
    need(path.absolute() == path.resolve(), "account path alias forbidden")
    fd = os.open(str(path) + ".lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as exc:
            raise ReservationError("one executor already holds account") from exc
        token = _lease.set(fd)
        try:
            yield fd
        finally:
            _lease.reset(token)
    finally:
        os.close(fd)


def _pinned_policy(policy):
    import dd1_kernel_qualification as kernel_qualification
    need(isinstance(policy, dict) and policy == kernel_qualification.INERT_RESERVATION_POLICY,
         "caller-shaped reservation policy rejected")
    return policy


def _totals_kernel(account: Mapping, now: datetime, policy: Mapping) -> dict:
    policy = _pinned_policy(policy)
    need(account.get("synthetic") is True, "kernel reservation account must be synthetic")
    need(account.get("schema") == "DD1-KERNEL-COMPAT-1-SYNTHETIC-ACCOUNT-1", "wrong account schema")
    need("historical" not in account, "historical credit forbidden")
    recovery = account.get("recovery", {})
    need(isinstance(recovery, dict), "invalid accounts")
    need(recovery.get("id") == "DD1-KERNEL-COMPAT-1", "wrong account operation")
    need(recovery.get("selection") == policy["selection"], "wrong account selection")
    need(recovery.get("first_engine_launch_utc") == policy["start_utc"]
         and recovery.get("deadline_utc") == policy["deadline_utc"], "wrong account window")
    for field in ("starts_cap", "cpu_ns_cap", "raw_bytes_cap", "per_invocation_cpu_seconds", "executors"):
        need(type(recovery.get(field)) is int and recovery[field] == policy[field], "mismatched cap: " + field)
    start = datetime.fromisoformat(policy["start_utc"].replace("Z", "+00:00"))
    expiry = datetime.fromisoformat(policy["deadline_utc"].replace("Z", "+00:00"))
    need(now.tzinfo is not None and start <= now < expiry, "outside selected window")
    result = {"starts": natural(recovery.get("starts_used"), "starts_used"),
              "cpu_ns": natural(recovery.get("cpu_ns_used"), "cpu_ns_used"),
              "raw_bytes": natural(recovery.get("raw_bytes_used"), "raw_bytes_used")}
    units, seen = recovery.get("unit_reservations_v2", []), set()
    need(isinstance(units, list), "invalid reservation ledger")
    for row in units:
        need(isinstance(row, dict) and isinstance(row.get("unit_id"), str) and
             row["unit_id"] and row["unit_id"] not in seen, "duplicate/invalid reservation identity")
        seen.add(row["unit_id"])
        need(row.get("state") in ("RESERVED", "COMPLETE", "FAILED", "INTERRUPTED"), "invalid reservation state")
        for field in result:
            result[field] += natural(row.get(field), "reserved " + field)
    for field, cap in (("starts", policy["starts_cap"]), ("cpu_ns", policy["cpu_ns_cap"]),
                       ("raw_bytes", policy["raw_bytes_cap"])):
        need(result[field] <= cap, "reported/committed capacity already exceeds " + field)
    return result


def totals(account: Mapping, now: datetime | None = None, policy=None) -> dict:
    now = now or datetime.now(timezone.utc)
    if policy is not None:
        return _totals_kernel(account, now, policy)
    need(account.get("schema") == "DD1-N0-RECOVERY-1-ACCOUNT-1", "wrong account schema")
    r, historical = account.get("recovery", {}), account.get("historical", {})
    need(isinstance(r, dict) and isinstance(historical, dict), "invalid accounts")
    for field, value in {"starts_cap": STARTS_CAP, "cpu_ns_cap": CPU_CAP,
                         "raw_bytes_cap": RAW_CAP, "per_invocation_cpu_seconds": 300,
                         "executors": 1}.items():
        need(type(r.get(field)) is int and r[field] == value, "mismatched cap: " + field)
    need(r.get("id") == OPERATION, "wrong account operation")
    need(r.get("first_engine_launch_utc") == FIRST and r.get("deadline_utc") == DEADLINE, "recovery clock cannot be reset")
    start, expiry = (datetime.fromisoformat(s.replace("Z", "+00:00")) for s in (FIRST, DEADLINE))
    need(now.tzinfo is not None and start <= now < expiry, "outside recovery window")
    for field, expected in {"starts_used": 1277, "starts_cap": 8192,
                            "starts_remaining_arithmetic": 6915, "spendable": False, "attempt": "1/1 consumed",
                            "cpu_seconds": "UNKNOWN", "elapsed_seconds": "UNKNOWN",
                            "raw_bytes": "UNKNOWN"}.items():
        need(type(historical.get(field)) is type(expected) and historical[field] == expected,
             "historical account is not new capacity")
    result = {"starts": natural(r.get("starts_used"), "starts_used"),
              "cpu_ns": natural(r.get("cpu_ns_used"), "cpu_ns_used"),
              "raw_bytes": natural(r.get("raw_bytes_used"), "raw_bytes_used")}
    need(result["starts"] >= 2040 and result["cpu_ns"] >= 398617197992 and result["raw_bytes"] >= 893139,
         "recorded recovery costs cannot be decreased or refunded")
    units, seen = r.get("unit_reservations_v2", []), set()
    need(isinstance(units, list), "invalid reservation ledger")
    for row in units:
        need(isinstance(row, dict) and isinstance(row.get("unit_id"), str) and
             row["unit_id"] and row["unit_id"] not in seen, "duplicate/invalid reservation identity")
        seen.add(row["unit_id"])
        need(row.get("state") in ("RESERVED", "COMPLETE", "FAILED", "INTERRUPTED"), "invalid reservation state")
        for field in result:
            result[field] += natural(row.get(field), "reserved " + field)
    for field, cap in (("starts", STARTS_CAP), ("cpu_ns", CPU_CAP), ("raw_bytes", RAW_CAP)):
        need(result[field] <= cap, "reported/committed capacity already exceeds " + field)
    return result


def available(account: Mapping, starts: int, cpu_ns: int, raw_bytes: int,
              now: datetime | None = None, policy=None) -> dict:
    used = totals(account, now, policy)
    if policy is None:
        caps = (("starts", starts, STARTS_CAP), ("cpu_ns", cpu_ns, CPU_CAP), ("raw_bytes", raw_bytes, RAW_CAP))
    else:
        policy = _pinned_policy(policy)
        need(natural(cpu_ns, "cpu_ns") <= policy["per_invocation_cpu_seconds"] * 1_000_000_000,
             "per-invocation CPU ceiling")
        caps = (("starts", starts, policy["starts_cap"]), ("cpu_ns", cpu_ns, policy["cpu_ns_cap"]),
                ("raw_bytes", raw_bytes, policy["raw_bytes_cap"]))
    for field, proposed, cap in caps:
        need(used[field] + natural(proposed, field) <= cap, "exhausted complete-unit reservation: " + field)
    return used


def validate_unit(unit: Mapping, command: list[str], *, head: str, receipt_sha: str,
                  account_sha: str, source_reader: Callable[[str], bytes], policy=None) -> None:
    need(unit.get("schema") == "DD1-COMPLETE-UNIT-DEMAND-2", "complete unit demand required")
    if policy is None:
        need(unit.get("operation") == OPERATION and unit.get("scientific_m") == M, "wrong unit operation/M")
    else:
        import dd1_kernel_qualification as kernel_qualification
        pinned = kernel_qualification.inert_reservation_policy(unit)
        need(policy == pinned, "caller-shaped reservation policy rejected")
        need(unit.get("operation_start_utc") == policy["start_utc"]
             and unit.get("operation_deadline_utc") == policy["deadline_utc"],
             "selected window is not bound on the unit")
    need(unit.get("overlay_head") == head and bool(re.fullmatch(r"[0-9a-f]{40}", head)), "wrong exact source head")
    need(unit.get("receipt_sha256") == receipt_sha and unit.get("account_sha256") == account_sha, "stale receipt/account identity")
    need(isinstance(command, list) and command and all(isinstance(v, str) and v and "\0" not in v for v in command)
         and unit.get("argv") == command, "command not bound to complete unit")
    need(bool(re.fullmatch(r"[A-Za-z0-9._-]{1,80}", str(unit.get("unit_id", "")))), "unsafe unit identity")
    need(unit.get("mode") in ("focused_fixture", "fixed_ordinary", "inert_control", "engineering"), "unknown unit mode")
    contained = natural(unit.get("contained_starts"), "contained_starts")
    need(contained <= 2047, "unsafe contained-start bound")
    if unit.get("mode") == "fixed_ordinary":
        need(1 <= natural(unit.get("max_roots", 16), "max_roots") <= 16, "unsafe root prefix bound")
    if unit.get("mode") == "engineering":
        from dd1_compatibility import PROFILE, STAGES, validate_task
        need(isinstance(unit.get("compatibility"), dict) and
             unit["compatibility"].get("id") == PROFILE and unit.get("stage") in STAGES,
             "engineering requires its bound capability profile and stage")
        need(contained == (2 if unit["stage"] == "fixture" else 0),
             "engineering stage contained-start bound")
        validate_task(unit)
    cpu = natural(unit.get("cpu_seconds"), "cpu_seconds")
    need(4 <= cpu <= 300, "unsafe complete-unit CPU bound")
    if policy is not None:
        need(cpu <= policy["per_invocation_cpu_seconds"], "unsafe complete-unit CPU bound")
    wall = unit.get("wall_seconds")
    need(type(wall) in (int, float) and math.isfinite(wall) and 0 < wall <= 3600, "unsafe wall limit")
    raw = natural(unit.get("raw_bytes"), "raw_bytes")
    need(0 < raw <= RAW_CAP, "unsafe complete-unit raw bound")
    if policy is not None:
        need(raw <= policy["raw_bytes_cap"], "unsafe complete-unit raw bound")
    files = unit.get("source_files")
    need(isinstance(files, dict) and files, "missing exact source file bindings")
    for name, wanted in files.items():
        need(isinstance(name, str) and name.startswith("res://") and name[6:] and
             not Path(name[6:]).is_absolute() and ".." not in Path(name[6:]).parts, "unsafe source path")
        need(isinstance(wanted, str) and re.fullmatch(r"[0-9a-f]{64}", wanted) is not None and
             digest(source_reader(name)) == wanted, "actual source bytes differ: " + name)


def reserve_and_run(account_path: Path, unit: Mapping, *, command: list[str], head: str,
                    receipt_sha: str, source_reader: Callable[[str], bytes],
                    authority_check: Callable[[Mapping], None], output: Path,
                    runner: Callable[[dict, Path], dict], now: datetime | None = None,
                    policy=None) -> dict:
    """Internal runner seam, not a CLI permission or an aggregate OS sandbox."""
    if policy is not None:
        import dd1_kernel_qualification as kernel_qualification
        need(policy == kernel_qualification.inert_reservation_policy(unit),
             "caller-shaped reservation policy rejected")
    with account_lock(account_path):
        before_bytes = account_path.read_bytes()
        account = read(account_path)
        authority_check(account)
        validate_unit(unit, command, head=head, receipt_sha=receipt_sha,
                      account_sha=digest(before_bytes), source_reader=source_reader, policy=policy)
        units = account["recovery"].get("unit_reservations_v2", [])
        need(all(row["unit_id"] != unit["unit_id"] for row in units), "unit already reserved; no second spawn")
        need(all(row.get("backend") != "linux-x86_64-lp64-v1" or
                 (row.get("observations") or {}).get("cleanup_confirmed") is True for row in units),
             "unresolved prior workload; stale reservation requires cleanup evidence, never credit")
        need(not output.exists() and not output.is_symlink() and output.absolute() == output.resolve(),
             "output must be new and unaliased; no historical overwrite")
        metadata = 4 * len(before_bytes) + 4 * len(encode(unit)) + 524288
        need(metadata + 4096 < unit["raw_bytes"], "raw envelope cannot fit control bytes and probe")
        reserve = {"unit_id": unit["unit_id"], "starts": 1 + unit["contained_starts"],
                   "cpu_ns": unit["cpu_seconds"] * 10**9, "raw_bytes": unit["raw_bytes"],
                   "before_account_sha256": digest(before_bytes), "demand_sha256": digest(encode(unit)),
                   "backend": unit.get("linux", {}).get("abi"), "release_protocol": "B1-ACK-1" if unit.get("linux") else None,
                   "state": "RESERVED", "observations": None}
        available(account, reserve["starts"], reserve["cpu_ns"], reserve["raw_bytes"], now, policy)
        changed = deepcopy(account)
        changed["recovery"].setdefault("unit_reservations_v2", []).append(reserve)
        atomic_write(account_path, changed)  # Durable full charge BEFORE any runner/child.
        deadline_unix = datetime.fromisoformat(DEADLINE.replace("Z", "+00:00")).timestamp()
        if policy is not None:
            deadline_unix = int(datetime.fromisoformat(policy["deadline_utc"].replace("Z", "+00:00")).timestamp())
        grant = dict(unit, schema="DD1-RESERVED-UNIT-2", engine_starts=1,
                     artifact_root=str((output / "capture").resolve()),
                     metadata_raw_reserved=metadata, child_raw_bytes=unit["raw_bytes"] - metadata - 4096,
                     deadline_unix=deadline_unix)
        try:
            output.mkdir(parents=True, exist_ok=False)
            atomic_write(output / "UNIT-GRANT.json", grant)
            active = _active_reservation.set((account_path, changed, reserve))
            try:
                result = runner(grant, output)
            finally:
                _active_reservation.reset(active)
            need(isinstance(result, dict), "invalid runner observation")
            result = json.loads(encode(result))
            need(len(encode(result)) <= 65536, "oversized control observation")
            reserve["state"] = "COMPLETE" if result.get("success") is True else "FAILED"
        except BaseException as exc:
            reserve["state"] = "INTERRUPTED" if isinstance(exc, (KeyboardInterrupt, SystemExit)) else "FAILED"
            result = {"success": False, "error": (type(exc).__name__ + ":" + str(exc))[:2048]}
        reserve["observations"] = result
        # A failed final write leaves the initial full RESERVED charge durable.
        atomic_write(account_path, changed)
        atomic_write(output / "UNIT-RESULT.json", {"unit": reserve, "result": result})
        return dict(result, charged=reserve, n0_accepted=False)


def attach_processes(identities):
    """Trusted fixed backend only: persist identities before sending exec ACK."""
    active = _active_reservation.get()
    need(active is not None and _lease.get() >= 3, "no active process reservation")
    path, account, row = active
    need(row["state"] == "RESERVED" and row["release_protocol"] == "B1-ACK-1", "wrong release state")
    need("processes" not in row, "process identity already bound")
    row["processes"] = identities
    atomic_write(path, account)


def process_identity(pid):
    raw = Path("/proc") / str(pid) / "stat"
    fields = raw.read_text().rsplit(")", 1)[1].split()
    return dict(pid=pid, start_ticks=int(fields[19]), ppid=int(fields[1]),
                boot_id=Path("/proc/sys/kernel/random/boot_id").read_text().strip())


def reconcile_stale(account_path):
    """No launch or credit: close only B1-ACK-1 records with kernel absence.

    This is NOT called by native entry. A subsequent demand must bind the new
    account bytes. Any surviving PID blocks, even if its identity appears reused.
    Unknown pre-B1 records cannot be reconciled with this protocol.
    """
    with account_lock(account_path):
        account = read(account_path)
        before = totals(account)
        boot = Path("/proc/sys/kernel/random/boot_id").read_text().strip()
        rows = account["recovery"].get("unit_reservations_v2", [])
        changed = []
        for row in rows:
            if row.get("backend") != "linux-x86_64-lp64-v1" or (row.get("observations") or {}).get("cleanup_confirmed") is True:
                continue
            need(row.get("release_protocol") == "B1-ACK-1", "missing stale release protocol")
            processes = row.get("processes", {})
            for item in processes.values():
                need(item.get("boot_id") != boot or not (Path("/proc") / str(item["pid"])).exists(),
                     "stale workload/controller PID still present; cannot reconcile")
            # No identities means no durable ACK was possible. The inherited
            # executor lock covers the bootstrap until its death/normal reap.
            row["state"] = "INTERRUPTED"
            row["observations"] = dict(success=False, cleanup_confirmed=True,
                reconciliation="B1-ACK-1 executor lock and recorded PID absence",
                no_release_record=not bool(processes))
            changed.append(row["unit_id"])
        need(totals(account) == before, "reconciliation changed costs")
        if changed:
            atomic_write(account_path, account)
        return dict(reconciled=changed, totals=before, launch_permitted=False)