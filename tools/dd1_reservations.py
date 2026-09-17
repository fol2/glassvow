"""Before-child complete-unit reservations; immutable legacy observations.

The caller validates the EXISTING authority receipt. This module cannot issue
allowance or review. Every committed unit stays fully charged, even when spawn,
containment, observation, interruption or final receipt persistence fails.
"""
from __future__ import annotations
from contextlib import contextmanager
from copy import deepcopy
from datetime import datetime, timezone, timedelta
import fcntl
import hashlib
import json
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
        result = {}
        for key, value in items:
            need(key not in result, "duplicate JSON key")
            result[key] = value
        return result
    def bad(value):
        raise ReservationError("nonfinite JSON")
    try:
        value = json.loads(path.read_bytes(), object_pairs_hook=pairs, parse_constant=bad)
    except (ValueError, OSError) as exc:
        raise ReservationError("cannot read JSON: " + str(path)) from exc
    need(isinstance(value, dict), "JSON object required")
    return value


def atomic_write(path: Path, value: Mapping) -> None:
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
    fd = os.open(str(path) + ".lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as exc:
            raise ReservationError("one executor already holds account") from exc
        yield
    finally:
        os.close(fd)


def totals(account: Mapping, now: datetime | None = None) -> dict:
    now = now or datetime.now(timezone.utc)
    r, historical = account.get("recovery", {}), account.get("historical", {})
    for field, value in {"starts_cap": STARTS_CAP, "cpu_ns_cap": CPU_CAP,
                         "raw_bytes_cap": RAW_CAP, "per_invocation_cpu_seconds": 300,
                         "executors": 1}.items():
        need(type(r.get(field)) is int and r[field] == value, "mismatched cap: " + field)
    need(r.get("id") == OPERATION, "wrong account operation")
    need(r.get("first_engine_launch_utc") == FIRST and r.get("deadline_utc") == DEADLINE,
         "recovery clock cannot be reset")
    expiry = datetime.fromisoformat(DEADLINE.replace("Z", "+00:00"))
    need(now.tzinfo is not None and now < expiry, "recovery window expired")
    for field, expected in {"starts_used": 1277, "starts_cap": 8192,
                            "starts_remaining_arithmetic": 6915, "spendable": False,
                            "cpu_seconds": "UNKNOWN", "elapsed_seconds": "UNKNOWN",
                            "raw_bytes": "UNKNOWN"}.items():
        need(historical.get(field) == expected, "historical account is not new capacity")
    result = {"starts": natural(r.get("starts_used"), "starts_used"),
              "cpu_ns": natural(r.get("cpu_ns_used"), "cpu_ns_used"),
              "raw_bytes": natural(r.get("raw_bytes_used"), "raw_bytes_used")}
    units, seen = r.get("unit_reservations_v2", []), set()
    need(isinstance(units, list), "invalid reservation ledger")
    for row in units:
        need(isinstance(row, dict) and row.get("unit_id") not in seen, "duplicate reservation identity")
        seen.add(row["unit_id"])
        for field in result:
            result[field] += natural(row.get(field), "reserved " + field)
    for field, cap in (("starts", STARTS_CAP), ("cpu_ns", CPU_CAP), ("raw_bytes", RAW_CAP)):
        need(result[field] <= cap, "reported/committed capacity already exceeds " + field)
    return result


def available(account: Mapping, starts: int, cpu_ns: int, raw_bytes: int,
              now: datetime | None = None) -> dict:
    used = totals(account, now)
    for field, proposed, cap in (("starts", starts, STARTS_CAP), ("cpu_ns", cpu_ns, CPU_CAP),
                                 ("raw_bytes", raw_bytes, RAW_CAP)):
        need(used[field] + natural(proposed, field) <= cap, "exhausted complete-unit reservation: " + field)
    return used


def validate_unit(unit: Mapping, command: list[str], *, head: str, receipt_sha: str,
                  account_sha: str, source_reader: Callable[[str], bytes]) -> None:
    need(unit.get("schema") == "DD1-COMPLETE-UNIT-DEMAND-2", "complete unit demand required")
    need(unit.get("operation") == OPERATION and unit.get("scientific_m") == M, "wrong unit operation/M")
    need(unit.get("overlay_head") == head and bool(re.fullmatch(r"[0-9a-f]{40}", head)), "wrong exact source head")
    need(unit.get("receipt_sha256") == receipt_sha and unit.get("account_sha256") == account_sha,
         "stale receipt/account identity")
    need(isinstance(command, list) and command and unit.get("argv") == command, "command not bound to complete unit")
    need(bool(re.fullmatch(r"[A-Za-z0-9._-]{1,80}", str(unit.get("unit_id", "")))), "unsafe unit identity")
    need(unit.get("mode") in ("focused_fixture", "fixed_ordinary", "inert_control"), "unknown unit mode")
    contained = natural(unit.get("contained_starts"), "contained_starts")
    need(0 <= contained <= 2047, "unsafe contained-start bound")
    cpu = natural(unit.get("cpu_seconds"), "cpu_seconds")
    need(4 <= cpu <= 300, "unsafe complete-unit CPU bound")
    wall = unit.get("wall_seconds")
    need(type(wall) in (int, float) and 0 < wall <= 3600, "unsafe wall limit")
    raw = natural(unit.get("raw_bytes"), "raw_bytes")
    need(0 < raw <= RAW_CAP, "unsafe complete-unit raw bound")
    files = unit.get("source_files")
    need(isinstance(files, dict) and files, "missing exact source file bindings")
    for name, wanted in files.items():
        need(isinstance(name, str) and name.startswith("res://") and ".." not in Path(name[6:]).parts,
             "unsafe source path")
        need(isinstance(wanted, str) and re.fullmatch(r"[0-9a-f]{64}", wanted) is not None and
             digest(source_reader(name)) == wanted, "actual source bytes differ: " + name)


def reserve_and_run(account_path: Path, unit: Mapping, *, command: list[str], head: str,
                    receipt_sha: str, source_reader: Callable[[str], bytes],
                    authority_check: Callable[[Mapping], None], output: Path,
                    runner: Callable[[dict, Path], dict], now: datetime | None = None) -> dict:
    """runner is dependency-injected for inert ordering tests, not a CLI option.

    The production entry uses the bounded OS backend only. Atomic reservation
    persists before grant creation and before runner/probe/native child calls.
    Original events, reported counters, clock and historical data are untouched.
    """
    with account_lock(account_path):
        before_bytes = account_path.read_bytes()
        account = read(account_path)
        authority_check(account)
        validate_unit(unit, command, head=head, receipt_sha=receipt_sha,
                      account_sha=digest(before_bytes), source_reader=source_reader)
        units = account["recovery"].get("unit_reservations_v2", [])
        need(all(row["unit_id"] != unit["unit_id"] for row in units), "unit already reserved; no second spawn")
        need(not output.exists(), "output must be new; no historical overwrite")
        # Account/grant/receipt writes are conservatively included, not just the
        # native stdout/stderr. The child gets only the remaining raw envelope.
        metadata = 4 * len(before_bytes) + 4 * len(encode(unit)) + 131072
        need(metadata + 4096 < unit["raw_bytes"], "raw envelope cannot fit control bytes and probe")
        reserve = {"unit_id": unit["unit_id"], "starts": 1 + unit["contained_starts"],
                   "cpu_ns": unit["cpu_seconds"] * 10**9, "raw_bytes": unit["raw_bytes"],
                   "before_account_sha256": digest(before_bytes), "demand_sha256": digest(encode(unit)),
                   "state": "RESERVED", "observations": None}
        available(account, reserve["starts"], reserve["cpu_ns"], reserve["raw_bytes"], now)
        changed = deepcopy(account)
        changed["recovery"].setdefault("unit_reservations_v2", []).append(reserve)
        atomic_write(account_path, changed)  # BEFORE any runner/child invocation
        grant = dict(unit, schema="DD1-RESERVED-UNIT-2", engine_starts=1,
                     metadata_raw_reserved=metadata, child_raw_bytes=unit["raw_bytes"] - metadata - 4096,
                     deadline_unix=datetime.fromisoformat(DEADLINE.replace("Z", "+00:00")).timestamp())
        result: dict
        try:
            output.mkdir(parents=True, exist_ok=False)
            atomic_write(output / "UNIT-GRANT.json", grant)
            result = runner(grant, output)
            need(isinstance(result, dict), "invalid runner observation")
            result = json.loads(encode(result))
            need(len(encode(result)) <= 65536, "oversized control observation")
            reserve["state"] = "COMPLETE" if result.get("success") is True else "FAILED"
        except BaseException as exc:
            reserve["state"] = "INTERRUPTED" if isinstance(exc, (KeyboardInterrupt, SystemExit)) else "FAILED"
            result = {"success": False, "error": (type(exc).__name__ + ":" + str(exc))[:2048]}
        reserve["observations"] = result
        # No refunds or deferred contained-start debits. A failed write here
        # leaves the earlier full RESERVED charge durable and unspendable.
        atomic_write(account_path, changed)
        atomic_write(output / "UNIT-RESULT.json", {"unit": reserve, "result": result})
        return dict(result, charged=reserve, n0_accepted=False)
