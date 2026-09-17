"""Complete-unit native entry; no enabled aggregate containment backend.

Missing backend is a source blocker, not launch permission or an invitation to
spend the arithmetic remainder. Inert tests exercise the reservation seam only.
"""
from pathlib import Path
from typing import Mapping
import dd1_reservations as reservations
from dd1_provenance import REQUIRED_SOURCES


class BackendBlocked(reservations.ReservationError):
    pass


def require_native_backend():
    raise BackendBlocked("SOURCE_BLOCKED: aggregate CPU/process-tree/all-raw containment "
                         "and interruption cleanup have no implemented, demonstrated native backend")


def run_complete_unit(command, *, unit: Mapping, account_path: Path, receipt_path: Path,
                      output: Path, head: str, repo: Path, authority_check):
    account = reservations.read(account_path)
    authority_check(account)
    def source(name):
        relative = Path(name[6:])
        reservations.need(not relative.is_absolute() and ".." not in relative.parts, "source escape")
        path = repo
        for part in relative.parts:
            path = path / part
            reservations.need(not path.is_symlink(), "symbolic source")
        reservations.need(path.resolve().is_relative_to(repo.resolve()), "source escape")
        return path.read_bytes()
    reservations.validate_unit(unit, list(command), head=head,
        receipt_sha=reservations.digest(receipt_path.read_bytes()),
        account_sha=reservations.digest(account_path.read_bytes()), source_reader=source)
    reservations.need(unit.get("mode") != "inert_control" and account.get("synthetic") is not True,
                      "native CLI cannot select inert test authority")
    reservations.need(REQUIRED_SOURCES <= unit["source_files"].keys(), "native source closure incomplete")
    reservations.available(account, 1 + unit["contained_starts"], unit["cpu_seconds"] * 10**9, unit["raw_bytes"])
    # No fallback to per-process RLIMIT_CPU, stdout-only budgets or delayed debit.
    # Do not even reserve live capacity while the enforcing backend is absent.
    runner = require_native_backend()
    return reservations.reserve_and_run(account_path, unit, command=list(command), head=head,
        receipt_sha=reservations.digest(receipt_path.read_bytes()), source_reader=source,
        authority_check=authority_check, output=output, runner=runner)
