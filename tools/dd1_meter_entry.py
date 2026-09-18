"""Connected Linux complete-unit entry. Source work never authorises a game run.

Native execution requires H's externally authenticated host context binding the
EXACT execution_demand role, plus the existing recovery receipt. The command
line cannot construct that context, accept synthetic authority, inject a clock,
or supply a runner. Native venue qualification remains a separate disposition.
"""
from pathlib import Path
from typing import Mapping
import signal
import json
import dd1_reservations as reservations
import dd1_linux_backend as backend


class BackendBlocked(reservations.ReservationError):
    """Unsupported or unbound execution, not an unconditional backend stub."""


def require_native_backend(unit, command, repo, lifetime):
    return backend.Prepared(unit, command, repo, lifetime)


def _complete(command, unit, account_path, receipt_path, output, head, repo, check, lifetime):
    # A canonical immutable copy prevents caller mutation after validation.
    unit = json.loads(reservations.encode(unit))
    account = reservations.read(account_path)
    check(account)
    reservations.need(unit.get("linux", {}).get("output_root") == str(output.resolve()), "unbound output root")
    reservations.available(account, 1 + unit["contained_starts"], unit["cpu_seconds"] * 10**9, unit["raw_bytes"])
    try:
        prepared = require_native_backend(unit, list(command), repo, lifetime)
        receipt = receipt_path.read_bytes()
        prepared.receipt_bytes = receipt
        prepared.account_bytes = account_path.read_bytes()
        reservations.need(len(receipt) <= 65536 and reservations.digest(prepared.account_bytes) == unit["account_sha256"],
                          "receipt size or copied account identity")
        prepared.pinned["setup_raw"] += len(receipt) + len(prepared.account_bytes) + 32768
        metadata = 4 * len(prepared.account_bytes) + 4 * len(reservations.encode(unit)) + 524288
        reservations.need(prepared.pinned["setup_raw"] + unit["linux"]["workload_raw_bytes"] + metadata + 4096 <= unit["raw_bytes"],
                          "complete raw envelope cannot fit input/control/workload copies")
        return reservations.reserve_and_run(account_path, unit, command=list(command), head=head,
            receipt_sha=reservations.digest(receipt), source_reader=lambda name: prepared.pinned["source"][name],
            authority_check=check, output=output, runner=prepared)
    finally:
        signal.setitimer(signal.ITIMER_REAL, 0)


def run_complete_unit(command, *, unit: Mapping, account_path: Path, receipt_path: Path,
                      output: Path, head: str, repo: Path, trusted_context=None,
                      evidence_packet=None, authority_check=None):
    # Retain the old argument only to explicitly REJECT permissive callback use;
    # there is no callback-derived native permission or public test-clock seam.
    if authority_check is not None or trusted_context is None or evidence_packet is None:
        raise BackendBlocked("missing H host-authenticated exact execution demand; callbacks are not native authority")
    lifetime = backend.controller_limits(unit)
    reservations.need(trusted_context.kind == "empirical", "native entry rejects synthetic authority")
    from dd1_provenance import REQUIRED_SOURCES, _load_boundary
    expected = _load_boundary().verify_bindings(evidence_packet, trusted_context)
    binding = expected["roles"].get("execution_demand", {})
    raw = reservations.encode(unit)
    reservations.need(expected.get("artifact_head") == head and binding.get("sha256") == reservations.digest(raw)
        and trusted_context.resolve(binding.get("locator")) == raw, "unbound native execution demand/source")
    reservations.need(unit.get("mode") != "inert_control" and REQUIRED_SOURCES <= unit["source_files"].keys(),
                      "native mode/source closure invalid")
    from dd1_recovery_meter import load_bindings, validate_launch_receipt
    bindings = load_bindings()
    receipt = reservations.read(receipt_path)
    def check(account):
        reservations.need(account.get("synthetic") is not True, "native entry rejects synthetic account")
        validate_launch_receipt(receipt, bindings=bindings, account=account, overlay_head=head)
    return _complete(command, unit, account_path, receipt_path, output, head, repo, check, lifetime)


def _run_inert_unit(command, *, unit, account_path, receipt_path, output, head, repo):
    """Test-only entry: never reachable through the native meter CLI.

    Uses the SAME prepare/reserve/kernel-enforcement path. No OS mocks, supplied
    runner or test clock. A synthetic account and exact test-only receipt are
    mandatory; the repository's live account path cannot be selected.
    """
    lifetime = backend.controller_limits(unit)
    reservations.need(not account_path.resolve().is_relative_to(repo.resolve()), "inert account cannot be a repository account")
    receipt = reservations.read(receipt_path)
    # Receipt binds a demand with its receipt field omitted, avoiding a hash cycle.
    unsigned = dict(unit); unsigned.pop("receipt_sha256", None)
    reservations.need(receipt.get("schema") == "DD1-INERT-ONLY" and receipt.get("demand_sha256") ==
        reservations.digest(reservations.encode(unsigned)), "inert demand/receipt mismatch")
    reservations.need(unit.get("mode") == "inert_control" and command[0] == "/workload" and
                      "res://tools/dd1_linux/inert.c" in unit["source_files"], "inert fixture binding required")
    def check(account):
        reservations.need(account.get("synthetic") is True, "inert entry requires synthetic account")
    return _complete(command, unit, account_path, receipt_path, output, head, repo, check, lifetime)
