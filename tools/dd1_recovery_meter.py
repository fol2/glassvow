#!/usr/bin/env python3
"""DD1 receipt preflight and complete-unit reservation entry.

Native entry requires H host-authenticated exact execution demand and venue
authority. The bare CLI cannot supply it. Legacy receipts/accounts are unchanged.
Source-only self-test uses explicitly synthetic temporary accounts.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import resource
import signal
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Mapping, Sequence


REPO = Path(__file__).resolve().parents[1]
QUAL = REPO / "research/p9-six-route/dusk-design-1-20260916/native-qualification"
RECOVERY = QUAL / "recovery"
BINDINGS_PATH = RECOVERY / "RECEIPT-BINDINGS.json"
ACCOUNT_PATH = RECOVERY / "ACCOUNT.json"
LAUNCH_RECEIPT_PATH = RECOVERY / "LAUNCH-RECEIPT.json"
RECEIPTS_DIR = RECOVERY / "receipts"
STARTING_G = "84cd143f44923294e614def62de74e720598648a"
CPU_NS_CAP = 4 * 3600 * 10**9
RAW_CAP = 1073741824
STARTS_CAP = 2048
PER_INVOCATION_CPU_S = 300
WINDOW_DAYS = 7


class MeterError(RuntimeError):
    """Launch or accounting rejected."""


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def utc_now() -> datetime:
    return datetime.now(timezone.utc).replace(microsecond=0)


def utc_stamp(value: datetime | None) -> str | None:
    if value is None:
        return None
    return value.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def parse_utc(value: Any) -> datetime | None:
    if not value:
        return None
    text = str(value).replace("Z", "+00:00")
    return datetime.fromisoformat(text)


def read_json(path: Path) -> dict[str, Any]:
    from dd1_reservations import read
    return read(path)


def write_json(path: Path, value: Mapping[str, Any]) -> None:
    from dd1_reservations import atomic_write
    atomic_write(path, value)


def git_rev_parse(rev: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(REPO), "rev-parse", rev],
        check=False, capture_output=True, text=True,
    )
    if result.returncode != 0:
        raise MeterError(f"git rev-parse {rev} failed: {result.stderr.strip()}")
    return result.stdout.strip()


def git_is_ancestor(ancestor: str, head: str) -> bool:
    result = subprocess.run(
        ["git", "-C", str(REPO), "merge-base", "--is-ancestor", ancestor, head],
        check=False, capture_output=True, text=True,
    )
    return result.returncode == 0


def load_bindings() -> dict[str, Any]:
    if not BINDINGS_PATH.is_file():
        raise MeterError("RECEIPT-BINDINGS.json missing")
    return read_json(BINDINGS_PATH)


def verify_stored_bodies(bindings: Mapping[str, Any]) -> dict[str, str]:
    files = bindings.get("files")
    if not isinstance(files, dict) or not files:
        raise MeterError("bindings files map missing")
    out: dict[str, str] = {}
    for name, meta in files.items():
        path = RECEIPTS_DIR / str(name)
        if not path.is_file():
            raise MeterError(f"receipt body missing: {name}")
        actual = sha256_file(path)
        expected = str(meta.get("sha256", ""))
        if actual != expected:
            raise MeterError(f"stale or wrong receipt body {name}")
        if int(meta.get("bytes", -1)) != path.stat().st_size:
            raise MeterError(f"receipt size mismatch {name}")
        out[str(name)] = actual
    required = [
        "protocol-5717964158.md",
        "selection-5718178514.md",
        "review-5718202450.md",
        "binding-5718448223.md",
        "task-5718464731.md",
    ]
    for name in required:
        if name not in out:
            raise MeterError(f"required receipt absent: {name}")
    return out


def remaining_ok(account: Mapping[str, Any], reserve_starts: int, reserve_cpu_s: int,
                 reserve_raw_bytes: int = 0) -> None:
    from dd1_reservations import available, natural
    available(account, reserve_starts, natural(reserve_cpu_s, "CPU seconds") * 10**9, reserve_raw_bytes)


def validate_launch_receipt(
    receipt: Mapping[str, Any],
    *,
    bindings: Mapping[str, Any],
    account: Mapping[str, Any],
    overlay_head: str,
    require_descendant: bool = True,
) -> dict[str, Any]:
    if str(receipt.get("schema", "")) != "DD1-N0-RECOVERY-1-LAUNCH-RECEIPT-1":
        raise MeterError("wrong or missing launch-receipt schema")
    if str(receipt.get("operation", "")) != "DD1-N0-RECOVERY-1":
        raise MeterError("wrong operation identity")
    bodies = verify_stored_bodies(bindings)
    claimed = receipt.get("bodies")
    if not isinstance(claimed, dict):
        raise MeterError("launch receipt missing bodies")
    for name, digest in bodies.items():
        if str(claimed.get(name, "")) != digest:
            raise MeterError(f"launch receipt stale identity: {name}")
    source = receipt.get("source")
    if not isinstance(source, dict):
        raise MeterError("launch receipt missing source")
    if str(source.get("scientific_m", "")) != str(bindings.get("scientific_m", "")):
        raise MeterError("stale scientific M identity")
    if str(source.get("starting_overlay_commit", "")) != STARTING_G:
        raise MeterError("stale starting overlay identity")
    if str(source.get("driver", "")) != str(bindings.get("driver", "")):
        raise MeterError("stale driver identity")
    if str(source.get("pilot_version", "")) != str(bindings.get("pilot_version", "")):
        raise MeterError("stale pilot identity")
    inputs = receipt.get("inputs")
    if not isinstance(inputs, dict):
        raise MeterError("launch receipt missing inputs")
    if int(inputs.get("pending_seed", -1)) != 5420099:
        raise MeterError("wrong pending seed")
    roots = inputs.get("pv_roots")
    if roots != list(range(5421600, 5421616)):
        raise MeterError("wrong or reordered P_v roots")
    if require_descendant and overlay_head != STARTING_G:
        if not git_is_ancestor(STARTING_G, overlay_head):
            raise MeterError("overlay head is not G or a descendant of G")
    for key in ("d", "c", "h", "allocation"):
        if not bindings.get(key) or source.get(key) != bindings[key]:
            raise MeterError("accepted source mismatch: " + key)
    caps = receipt.get("reservations", {})
    for key in ("starts_cap", "cpu_ns_cap", "raw_bytes_cap", "per_invocation_cpu_seconds", "executors"):
        if type(caps.get(key)) is not int or caps[key] != account["recovery"].get(key):
            raise MeterError("receipt cap mismatch: " + key)
    if receipt.get("expiry", {}).get("deadline_utc") != account["recovery"].get("deadline_utc"):
        raise MeterError("receipt expiry mismatch")
    remaining_ok(account, 0, 0, 0)  # integrity preflight only; NEVER launch permission
    return {
        "ok": True,
        "overlay_head": overlay_head,
        "bodies": bodies,
        "launch_permitted": False,
    }


def build_launch_receipt(bindings: Mapping[str, Any], account: Mapping[str, Any]) -> dict[str, Any]:
    # Pure historical representation only. The CLI cannot publish/activate it.
    bodies = verify_stored_bodies(bindings)
    recovery = account["recovery"]
    return {
        "schema": "DD1-N0-RECOVERY-1-LAUNCH-RECEIPT-1",
        "operation": "DD1-N0-RECOVERY-1",
        "owner_comment_id": 5718178514,
        "method_comment_id": 5717964158,
        "review_comment_id": 5718202450,
        "binding_comment_id": 5718448223,
        "task_comment_id": 5718464731,
        "bodies": bodies,
        "source": {
            "starting_overlay_commit": STARTING_G,
            "starting_overlay_tree": "bc9850d151c20a4395ce8138fb381b1d4ad9604d",
            "scientific_m": bindings["scientific_m"],
            "driver": bindings["driver"],
            "pilot_version": bindings["pilot_version"],
            "d": bindings["d"],
            "c": bindings["c"],
            "h": bindings["h"],
            "allocation": bindings["allocation"],
        },
        "inputs": {
            "pending_seed": 5420099,
            "pv_roots": list(range(5421600, 5421616)),
        },
        "reservations": {
            "starts_cap": recovery["starts_cap"],
            "starts_used": recovery["starts_used"],
            "cpu_ns_cap": recovery["cpu_ns_cap"],
            "cpu_ns_used": recovery["cpu_ns_used"],
            "raw_bytes_cap": recovery["raw_bytes_cap"],
            "raw_bytes_used": recovery["raw_bytes_used"],
            "per_invocation_cpu_seconds": recovery["per_invocation_cpu_seconds"],
            "executors": 1,
        },
        "expiry": {
            "window_days": WINDOW_DAYS,
            "first_engine_launch_utc": recovery.get("first_engine_launch_utc"),
            "deadline_utc": recovery.get("deadline_utc"),
        },
        "note": "File existence is not permission. Env vars are not authority.",
    }


def load_account(path: Path = ACCOUNT_PATH) -> dict[str, Any]:
    if not path.is_file():
        raise MeterError(f"account missing: {path}")
    return read_json(path)


def charge_account(*args, **kwargs):
    raise MeterError("post-process charging is not before-start authority; legacy observations remain unchanged")


def run_metered(
    command: Sequence[str],
    *,
    receipt_path: Path,
    account_path: Path,
    out_dir: Path,
    cpu_seconds: int,
    output_limit: int,
    interrupt_after_s: float | None,
    counts_as_engine: bool,
    overlay_head: str | None = None,
    wait_seconds: int | None = None,
    unit_path: Path | None = None,
    trusted_context: Any = None,
    evidence_packet: Mapping[str, Any] | None = None,
) -> dict[str, Any]:
    if unit_path is None:
        raise MeterError("complete pre-reserved unit demand is required; legacy one-start path removed")
    if not counts_as_engine or interrupt_after_s is not None:
        raise MeterError("native CLI cannot borrow inert-test authority")
    if trusted_context is None or evidence_packet is None:
        raise MeterError("native execution requires H host-authenticated exact demand; bare CLI is inert")
    from dd1_meter_entry import run_complete_unit
    unit = read_json(unit_path)
    if cpu_seconds != unit.get("cpu_seconds") or output_limit != unit.get("raw_bytes"):
        raise MeterError("CLI CPU/raw limits differ from complete unit")
    if wait_seconds is not None and wait_seconds != unit.get("wall_seconds"):
        raise MeterError("CLI wall limit differs from complete unit")
    if overlay_head is None:
        raise MeterError("exact host-bound head required; no Git child inside the execution unit")
    head = overlay_head
    return run_complete_unit(list(command), unit=unit, account_path=account_path,
        receipt_path=receipt_path, output=out_dir, head=head, repo=REPO,
        trusted_context=trusted_context, evidence_packet=evidence_packet)


def cmd_write_receipt() -> int:
    raise MeterError("source-only disposition: no new or refreshed launch receipt")


def cmd_validate(receipt_path: Path) -> int:
    bindings = load_bindings()
    account = load_account()
    if not receipt_path.is_file():
        raise MeterError("receipt path does not exist")
    if receipt_path.stat().st_size == 0:
        raise MeterError("empty receipt")
    receipt = read_json(receipt_path)
    head = git_rev_parse("HEAD")
    report = validate_launch_receipt(
        receipt, bindings=bindings, account=account, overlay_head=head)
    print(json.dumps({"ok": True, **report}, sort_keys=True))
    return 0


def _write_temp_account(directory: Path, **recovery_over: Any) -> Path:
    # Retained for this source checkpoint; never called by the new self-test.
    account = {
        "schema": "DD1-N0-RECOVERY-1-ACCOUNT-1",
        "historical": {
            "starts_used": 1277,
            "starts_cap": 8192,
            "starts_remaining_arithmetic": 6915,
            "spendable": False,
            "cpu_seconds": "UNKNOWN",
        },
        "recovery": {
            "id": "DD1-N0-RECOVERY-1",
            "starts_used": 0,
            "starts_cap": STARTS_CAP,
            "cpu_ns_used": 0,
            "cpu_ns_cap": CPU_NS_CAP,
            "raw_bytes_used": 0,
            "raw_bytes_cap": RAW_CAP,
            "executors": 1,
            "per_invocation_cpu_seconds": PER_INVOCATION_CPU_S,
            "first_engine_launch_utc": None,
            "deadline_utc": None,
            "events": [],
            **recovery_over,
        },
    }
    path = directory / "ACCOUNT.json"
    write_json(path, account)
    return path


def cmd_self_test(log_path: Path) -> int:
    # Python-only unittest module. No live account, receipt mutation or engine.
    import unittest
    import test_dd1_source_repair
    suite = unittest.defaultTestLoader.loadTestsFromModule(test_dd1_source_repair)
    with log_path.open("w", encoding="utf-8") as log:
        result = unittest.TextTestRunner(stream=log, verbosity=2).run(suite)
    print(log_path.read_text())
    return 0 if result.wasSuccessful() else 1


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("write-receipt")
    p_val = sub.add_parser("validate")
    p_val.add_argument("--receipt", type=Path, default=LAUNCH_RECEIPT_PATH)
    p_run = sub.add_parser("run")
    p_run.add_argument("--receipt", type=Path, default=LAUNCH_RECEIPT_PATH)
    p_run.add_argument("--account", type=Path, default=ACCOUNT_PATH)
    p_run.add_argument("--out-dir", type=Path, required=True)
    p_run.add_argument("--cpu-seconds", type=int, default=PER_INVOCATION_CPU_S)
    p_run.add_argument("--output-limit", type=int, default=RAW_CAP)
    p_run.add_argument("--engine", action="store_true", help="counts as recovery engine launch")
    p_run.add_argument("--wait-seconds", type=int, default=0)
    p_run.add_argument("--unit", type=Path, required=True)
    p_run.add_argument("command", nargs=argparse.REMAINDER)
    p_chg = sub.add_parser("charge-contained")
    p_chg.add_argument("--starts", type=int, required=True)
    p_chg.add_argument("--note", default="contained native/forward-simulation starts")
    p_chg.add_argument("--account", type=Path, default=ACCOUNT_PATH)
    p_test = sub.add_parser("self-test")
    p_test.add_argument("--log", type=Path, required=True)
    args = parser.parse_args(argv)
    from dd1_reservations import ReservationError
    try:
        if args.cmd == "write-receipt":
            return cmd_write_receipt()
        if args.cmd == "validate":
            return cmd_validate(args.receipt)
        if args.cmd == "charge-contained":
            raise MeterError("deferred contained-start authority removed; no account changed")
        if args.cmd == "self-test":
            return cmd_self_test(args.log)
        if args.cmd == "run":
            command = list(args.command)
            if command and command[0] == "--":
                command = command[1:]
            if not command:
                raise MeterError("run requires a command")
            result = run_metered(
                command,
                receipt_path=args.receipt,
                account_path=args.account,
                out_dir=args.out_dir,
                cpu_seconds=args.cpu_seconds,
                output_limit=args.output_limit,
                interrupt_after_s=None,
                counts_as_engine=bool(args.engine),
                wait_seconds=(args.wait_seconds or None),
                unit_path=args.unit,
            )
            print(json.dumps(result, sort_keys=True, default=str))
            return 0 if result.get("success") else 1
    except (MeterError, ReservationError, OSError, ValueError) as error:
        print(json.dumps({"ok": False, "error": str(error)}), file=sys.stderr)
        return 2
    return 2


if __name__ == "__main__":
    sys.exit(main())
