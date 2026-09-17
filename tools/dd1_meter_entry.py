"""Complete-unit entry seam. Native backend is deliberately NOT enabled.

A self-hashed unit is not authority. The legacy receipt reader is reused by the
existing CLI. The accepted protocol is not expanded or refreshed by this file.
"""
from pathlib import Path
from typing import Mapping
import dd1_reservations as reservations
from dd1_provenance import REQUIRED_SOURCES


class BackendBlocked(reservations.ReservationError):
    pass


def require_native_backend():
    # No environment flag or submitted receipt can override a source blocker.
    # The experimental libseccomp child failed notification receive with -95.
    # Aggregate CPU/thread headroom and every raw channel remain unproved.
    raise BackendBlocked("SOURCE_BLOCKED: no demonstrated aggregate CPU/process-tree/all-raw backend; "
                         "experimental notification receive returned -95; native entry disabled")


def run_complete_unit(command, *, unit: Mapping, account_path: Path, receipt_path: Path,
                      output: Path, head: str, repo: Path, authority_check):
    """Validate demand without mutating the account while backend is blocked.

    The enabling change must obtain a bounded runner from require_native_backend
    and pass that runner to reserve_and_run. That function commits the entire
    bound before the runner is invoked. There is no fallback to deferred charge,
    subprocess pipes, RUSAGE_CHILDREN, or per-file FSIZE as an aggregate bound.
    """
    account = reservations.read(account_path)
    authority_check(account)
    def source(name):
        path = (repo / name[6:]).resolve()
        reservations.need(path.is_relative_to(repo.resolve()) and not path.is_symlink(), "source escape")
        return path.read_bytes()
    reservations.validate_unit(unit, list(command), head=head,
        receipt_sha=reservations.digest(receipt_path.read_bytes()),
        account_sha=reservations.digest(account_path.read_bytes()), source_reader=source)
    reservations.need(unit.get("mode") != "inert_control", "native CLI cannot select inert test authority")
    reservations.need(REQUIRED_SOURCES <= unit["source_files"].keys(), "native source closure incomplete")
    reservations.available(account, 1 + unit["contained_starts"], unit["cpu_seconds"] * 10**9, unit["raw_bytes"])
    runner = require_native_backend()  # always raises BEFORE account/grant/child writes
    return reservations.reserve_and_run(account_path, unit, command=list(command), head=head,
        receipt_sha=reservations.digest(receipt_path.read_bytes()), source_reader=source,
        authority_check=authority_check, output=output, runner=runner)
