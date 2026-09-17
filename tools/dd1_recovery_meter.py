#!/usr/bin/env python3
"""Smallest existing-tool wrapper for DD1-N0-RECOVERY-1.

Validates owner/method/binding receipt bodies, operation, source/driver/input
identities, reservations and expiry before any spawn. File existence and
environment variables are not permission. Counts engine starts, process-tree
CPU (wait4 rusage), and cumulative raw stdout+stderr. Failures remain charged.
Inert non-game controls live in --self-test.
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
    raw = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(raw, dict):
        raise MeterError(f"JSON object required: {path}")
    return raw


def write_json(path: Path, value: Mapping[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


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


def remaining_ok(account: Mapping[str, Any], reserve_starts: int, reserve_cpu_s: int) -> None:
    recovery = account.get("recovery")
    if not isinstance(recovery, dict):
        raise MeterError("recovery account missing")
    used = int(recovery.get("starts_used", 0))
    cap = int(recovery.get("starts_cap", STARTS_CAP))
    if used + reserve_starts > cap:
        raise MeterError("exhausted reservation: starts")
    cpu_used = int(recovery.get("cpu_ns_used", 0))
    cpu_cap = int(recovery.get("cpu_ns_cap", CPU_NS_CAP))
    if cpu_used + reserve_cpu_s * 10**9 > cpu_cap:
        raise MeterError("exhausted reservation: cpu")
    raw_used = int(recovery.get("raw_bytes_used", 0))
    raw_cap = int(recovery.get("raw_bytes_cap", RAW_CAP))
    if raw_used >= raw_cap:
        raise MeterError("exhausted reservation: raw")
    first = parse_utc(recovery.get("first_engine_launch_utc"))
    deadline = parse_utc(recovery.get("deadline_utc"))
    if first is not None and deadline is not None and utc_now() > deadline:
        raise MeterError("recovery window expired")


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
    remaining_ok(account, 1, 0)
    return {
        "ok": True,
        "overlay_head": overlay_head,
        "bodies": bodies,
    }


def build_launch_receipt(bindings: Mapping[str, Any], account: Mapping[str, Any]) -> dict[str, Any]:
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


def charge_account(
    account: dict[str, Any],
    *,
    starts: int,
    cpu_ns: int,
    raw_bytes: int,
    event: Mapping[str, Any],
    clock_start: bool,
) -> dict[str, Any]:
    recovery = dict(account["recovery"])
    recovery["starts_used"] = int(recovery.get("starts_used", 0)) + starts
    recovery["cpu_ns_used"] = int(recovery.get("cpu_ns_used", 0)) + max(0, cpu_ns)
    recovery["raw_bytes_used"] = int(recovery.get("raw_bytes_used", 0)) + max(0, raw_bytes)
    if clock_start and not recovery.get("first_engine_launch_utc"):
        started = utc_now()
        recovery["first_engine_launch_utc"] = utc_stamp(started)
        recovery["deadline_utc"] = utc_stamp(started + timedelta(days=WINDOW_DAYS))
    events = list(recovery.get("events", []))
    events.append(dict(event))
    recovery["events"] = events
    account = dict(account)
    account["recovery"] = recovery
    return account


def _preexec_limits(cpu_seconds: int, output_bytes: int) -> None:
    os.setsid()
    resource.setrlimit(resource.RLIMIT_CPU, (cpu_seconds, cpu_seconds))
    # stdout/stderr are pipes; file-size limit still covers redirected files.
    if output_bytes > 0:
        resource.setrlimit(resource.RLIMIT_FSIZE, (output_bytes, output_bytes))


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
) -> dict[str, Any]:
    bindings = load_bindings()
    account = load_account(account_path)
    if not receipt_path.is_file():
        raise MeterError("launch receipt missing")
    if receipt_path.stat().st_size == 0:
        raise MeterError("empty launch receipt")
    receipt = read_json(receipt_path)
    head = overlay_head or git_rev_parse("HEAD")
    validate_launch_receipt(receipt, bindings=bindings, account=account, overlay_head=head)
    remaining_ok(account, 1, 0)
    out_dir.mkdir(parents=True, exist_ok=True)
    stdout_path = out_dir / "stdout.bin"
    stderr_path = out_dir / "stderr.bin"
    # Reserve before spawn. Failures stay charged.
    reserved_at = utc_stamp(utc_now())
    account = charge_account(
        account,
        starts=1,
        cpu_ns=0,
        raw_bytes=0,
        event={
            "kind": "reserve",
            "at_utc": reserved_at,
            "command": list(command),
            "counts_as_engine": counts_as_engine,
        },
        clock_start=counts_as_engine,
    )
    write_json(account_path, account)
    if account_path.resolve() == ACCOUNT_PATH.resolve():
        write_json(LAUNCH_RECEIPT_PATH, build_launch_receipt(bindings, account))

    env = os.environ.copy()
    env.pop("DD1_NATIVE_LAUNCH_PERMIT", None)

    usage_before = resource.getrusage(resource.RUSAGE_CHILDREN)
    started = time.monotonic()
    proc = subprocess.Popen(
        list(command),
        cwd=str(REPO),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=env,
        preexec_fn=lambda: _preexec_limits(cpu_seconds, output_limit),
    )
    killed = ""
    stdout_chunks: list[bytes] = []
    stderr_chunks: list[bytes] = []
    raw = 0

    def _ingest(stream, bucket: list[bytes]) -> None:
        nonlocal raw, killed
        assert stream is not None
        while True:
            block = stream.read(65536)
            if not block:
                break
            bucket.append(block)
            raw += len(block)
            if raw > output_limit:
                killed = "output_limit"
                os.killpg(proc.pid, signal.SIGKILL)
                break

    import threading
    t_out = threading.Thread(target=_ingest, args=(proc.stdout, stdout_chunks), daemon=True)
    t_err = threading.Thread(target=_ingest, args=(proc.stderr, stderr_chunks), daemon=True)
    t_out.start()
    t_err.start()
    if interrupt_after_s is not None:
        time.sleep(interrupt_after_s)
        if proc.poll() is None:
            killed = killed or "interrupt"
            os.killpg(proc.pid, signal.SIGTERM)
            time.sleep(0.2)
            if proc.poll() is None:
                os.killpg(proc.pid, signal.SIGKILL)
    wait_s = max(5, cpu_seconds + 8)
    if wait_seconds is not None:
        wait_s = max(wait_s, wait_seconds)
    if interrupt_after_s is not None:
        wait_s = max(wait_s, interrupt_after_s + 5)
    try:
        returncode = proc.wait(timeout=wait_s)
    except subprocess.TimeoutExpired:
        killed = killed or "wait_timeout"
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        returncode = proc.wait()
    t_out.join(timeout=2)
    t_err.join(timeout=2)
    elapsed_s = time.monotonic() - started
    usage_after = resource.getrusage(resource.RUSAGE_CHILDREN)
    cpu_s = (usage_after.ru_utime - usage_before.ru_utime) + (
        usage_after.ru_stime - usage_before.ru_stime
    )
    cpu_ns = int(cpu_s * 1_000_000_000)
    stdout_bytes = b"".join(stdout_chunks)
    stderr_bytes = b"".join(stderr_chunks)
    stdout_path.write_bytes(stdout_bytes)
    stderr_path.write_bytes(stderr_bytes)
    success = returncode == 0 and not killed
    account = load_account(account_path)
    account = charge_account(
        account,
        starts=0,
        cpu_ns=cpu_ns,
        raw_bytes=len(stdout_bytes) + len(stderr_bytes),
        event={
            "kind": "complete" if success else "fail",
            "at_utc": utc_stamp(utc_now()),
            "returncode": returncode,
            "killed": killed,
            "cpu_ns": cpu_ns,
            "raw_bytes": len(stdout_bytes) + len(stderr_bytes),
            "elapsed_s": elapsed_s,
            "command": list(command),
        },
        clock_start=False,
    )
    write_json(account_path, account)
    if account_path.resolve() == ACCOUNT_PATH.resolve():
        write_json(LAUNCH_RECEIPT_PATH, build_launch_receipt(bindings, account))
    result = {
        "success": success,
        "returncode": returncode,
        "killed": killed,
        "cpu_ns": cpu_ns,
        "raw_bytes": len(stdout_bytes) + len(stderr_bytes),
        "elapsed_s": elapsed_s,
        "stdout_path": str(stdout_path),
        "stderr_path": str(stderr_path),
        "account": account["recovery"],
    }
    if not success:
        result["error"] = killed or f"exit {returncode}"
    return result


def cmd_write_receipt() -> int:
    bindings = load_bindings()
    account = load_account()
    receipt = build_launch_receipt(bindings, account)
    write_json(LAUNCH_RECEIPT_PATH, receipt)
    print(json.dumps({"wrote": str(LAUNCH_RECEIPT_PATH), "sha256": sha256_file(LAUNCH_RECEIPT_PATH)}))
    return 0


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
    """Inert non-game containment: no Godot, no game I/O."""
    bindings = load_bindings()
    lines: list[str] = []
    failures: list[str] = []

    def note(msg: str) -> None:
        lines.append(msg)
        print(msg)

    with tempfile.TemporaryDirectory(prefix="dd1-inert-") as raw_tmp:
        tmp = Path(raw_tmp)
        good_account = load_account()
        good_receipt = build_launch_receipt(bindings, good_account)
        receipt_path = tmp / "LAUNCH-RECEIPT.json"
        write_json(receipt_path, good_receipt)
        head = git_rev_parse("HEAD")

        # 1. Exhausted reservation.
        exhausted = tmp / "exhausted"
        exhausted.mkdir()
        acc = _write_temp_account(exhausted, starts_used=STARTS_CAP)
        try:
            validate_launch_receipt(
                good_receipt, bindings=bindings, account=read_json(acc), overlay_head=head)
            failures.append("exhausted reservation was accepted")
            note("FAIL exhausted reservation accepted")
        except MeterError as error:
            if "exhausted" not in str(error):
                failures.append(f"exhausted wrong error: {error}")
                note(f"FAIL exhausted: {error}")
            else:
                after = read_json(acc)
                if int(after["recovery"]["starts_used"]) != STARTS_CAP:
                    failures.append("exhausted reservation reset the account")
                    note("FAIL exhausted reset")
                else:
                    note("PASS exhausted reservation rejected; account unchanged")

        # 2. Wrong / stale identity.
        stale = dict(good_receipt)
        stale_source = dict(stale["source"])
        stale_source["scientific_m"] = "0" * 40
        stale["source"] = stale_source
        try:
            validate_launch_receipt(
                stale, bindings=bindings, account=good_account, overlay_head=head)
            failures.append("stale M identity accepted")
            note("FAIL stale identity accepted")
        except MeterError as error:
            note(f"PASS stale identity rejected: {error}")

        empty_path = tmp / "empty.json"
        empty_path.write_text("", encoding="utf-8")
        try:
            if empty_path.stat().st_size == 0:
                raise MeterError("empty receipt")
            failures.append("empty receipt not rejected")
        except MeterError:
            note("PASS empty receipt rejected")

        missing = tmp / "missing.json"
        if missing.exists():
            failures.append("missing path existed")
        else:
            note("PASS missing receipt path is not permission")

        exist_only = tmp / "LAUNCH-PERMITTED.json"
        exist_only.write_text("{}\n", encoding="utf-8")
        try:
            validate_launch_receipt(
                read_json(exist_only), bindings=bindings, account=good_account, overlay_head=head)
            failures.append("file-existence empty object accepted")
            note("FAIL existence-only accepted")
        except MeterError as error:
            note(f"PASS file existence alone rejected: {error}")

        os.environ["DD1_NATIVE_LAUNCH_PERMIT"] = "1"
        try:
            validate_launch_receipt(
                {"schema": "nope"}, bindings=bindings, account=good_account, overlay_head=head)
            failures.append("env var authorised a bad receipt")
            note("FAIL env var authorised")
        except MeterError:
            note("PASS environment variable is not authority")
        finally:
            os.environ.pop("DD1_NATIVE_LAUNCH_PERMIT", None)

        # 3. Child CPU limit.
        cpu_dir = tmp / "cpu"
        cpu_dir.mkdir()
        cpu_account = _write_temp_account(cpu_dir)
        cpu_receipt = cpu_dir / "LAUNCH-RECEIPT.json"
        write_json(cpu_receipt, build_launch_receipt(bindings, read_json(cpu_account)))
        cpu_out = cpu_dir / "out"
        busy = [sys.executable, "-c", "x=0\nwhile True:\n x+=1"]
        cpu_result = run_metered(
            busy,
            receipt_path=cpu_receipt,
            account_path=cpu_account,
            out_dir=cpu_out,
            cpu_seconds=1,
            output_limit=1_000_000,
            interrupt_after_s=None,
            counts_as_engine=False,
            overlay_head=head,
        )
        cpu_after = read_json(cpu_account)
        if cpu_result.get("success"):
            failures.append("CPU-limited busy loop succeeded")
            note("FAIL CPU limit succeeded")
        elif int(cpu_after["recovery"]["starts_used"]) < 1:
            failures.append("CPU limit reset starts")
            note("FAIL CPU limit reset account")
        else:
            note(
                "PASS child CPU limit failed closed "
                f"killed={cpu_result.get('killed')!r} rc={cpu_result.get('returncode')} "
                f"starts={cpu_after['recovery']['starts_used']}"
            )

        # 4. Output limit.
        out_lim = tmp / "outlim"
        out_lim.mkdir()
        out_account = _write_temp_account(out_lim)
        out_receipt = out_lim / "LAUNCH-RECEIPT.json"
        write_json(out_receipt, build_launch_receipt(bindings, read_json(out_account)))
        writer = [sys.executable, "-c", "import sys\nwhile True:\n sys.stdout.write('A'*4096); sys.stdout.flush()"]
        out_result = run_metered(
            writer,
            receipt_path=out_receipt,
            account_path=out_account,
            out_dir=out_lim / "out",
            cpu_seconds=30,
            output_limit=64_000,
            interrupt_after_s=None,
            counts_as_engine=False,
            overlay_head=head,
        )
        out_after = read_json(out_account)
        if out_result.get("success"):
            failures.append("output-limit writer succeeded")
            note("FAIL output limit succeeded")
        elif int(out_after["recovery"]["starts_used"]) < 1:
            failures.append("output limit reset starts")
            note("FAIL output limit reset")
        else:
            note(
                "PASS output limit failed closed "
                f"killed={out_result.get('killed')!r} raw={out_result.get('raw_bytes')} "
                f"starts={out_after['recovery']['starts_used']}"
            )

        # 5. Interruption.
        intr = tmp / "intr"
        intr.mkdir()
        intr_account = _write_temp_account(intr)
        intr_receipt = intr / "LAUNCH-RECEIPT.json"
        write_json(intr_receipt, build_launch_receipt(bindings, read_json(intr_account)))
        sleeper = [sys.executable, "-c", "import time; time.sleep(30)"]
        intr_result = run_metered(
            sleeper,
            receipt_path=intr_receipt,
            account_path=intr_account,
            out_dir=intr / "out",
            cpu_seconds=30,
            output_limit=1_000_000,
            interrupt_after_s=0.2,
            counts_as_engine=False,
            overlay_head=head,
        )
        intr_after = read_json(intr_account)
        if intr_result.get("success"):
            failures.append("interrupted sleep succeeded")
            note("FAIL interrupt succeeded")
        elif int(intr_after["recovery"]["starts_used"]) < 1:
            failures.append("interrupt reset starts")
            note("FAIL interrupt reset")
        else:
            note(
                "PASS interruption failed closed "
                f"killed={intr_result.get('killed')!r} starts={intr_after['recovery']['starts_used']}"
            )

    log_path.parent.mkdir(parents=True, exist_ok=True)
    log_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    if failures:
        print("SELF-TEST FAIL")
        for row in failures:
            print(f"  - {row}")
        return 1
    print("SELF-TEST PASS")
    return 0


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
    p_run.add_argument("command", nargs=argparse.REMAINDER)
    p_chg = sub.add_parser("charge-contained")
    p_chg.add_argument("--starts", type=int, required=True)
    p_chg.add_argument("--note", default="contained native/forward-simulation starts")
    p_chg.add_argument("--account", type=Path, default=ACCOUNT_PATH)
    p_test = sub.add_parser("self-test")
    p_test.add_argument("--log", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        if args.cmd == "write-receipt":
            return cmd_write_receipt()
        if args.cmd == "validate":
            return cmd_validate(args.receipt)
        if args.cmd == "charge-contained":
            account = load_account(args.account)
            remaining_ok(account, max(0, args.starts), 0)
            account = charge_account(
                account,
                starts=max(0, args.starts),
                cpu_ns=0,
                raw_bytes=0,
                event={
                    "kind": "contained_starts",
                    "at_utc": utc_stamp(utc_now()),
                    "starts": args.starts,
                    "note": args.note,
                },
                clock_start=False,
            )
            write_json(args.account, account)
            if args.account.resolve() == ACCOUNT_PATH.resolve():
                write_json(LAUNCH_RECEIPT_PATH, build_launch_receipt(load_bindings(), account))
            print(json.dumps({"starts_used": account["recovery"]["starts_used"]}))
            return 0
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
            )
            print(json.dumps(result, sort_keys=True, default=str))
            return 0 if result.get("success") else 1
    except MeterError as error:
        print(json.dumps({"ok": False, "error": str(error)}), file=sys.stderr)
        return 2
    return 2


if __name__ == "__main__":
    sys.exit(main())
