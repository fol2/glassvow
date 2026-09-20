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
import dd1_preparation as preparation
import dd1_compatibility as compatibility


# Test authority is restricted to code-pinned harmless fixture builds, not any
# caller-named executable with a self-hash. Native entry cannot select this path.
INERT_BINARIES = frozenset(("d13b4975c0c131e15780f435474d88f2950cb25629c69fe497cbb7824a446629",
                            "00c91a9e612699082649e44536a8f40c436572378841ee4eaf70e8c45d1f7fa7",
                            "ead0fc4d0660d8a691469296c59827c66bad717b98d54671ecdb6eed8dcc9129",
                            "5144e1676b1ace6f29432e80b9e9f6eac49300a0b4173edb2b61e03dac9da1a1"))


H_PREFIX = "research/p9-six-route/duskblade-first-proof-20260912/"
H_BLOBS = {"evidence_boundary.py": "a88db0791572f430ea3e5cde85683c8527cead39",
           "reference_kernel.py": "ee091fb503849117358b3691264fca71803f8bbc"}


def check_h_closure(root):
    """Pin accepted H bytes before import; this does not authenticate a caller."""
    import hashlib
    files = {}
    for name, wanted in H_BLOBS.items():
        raw = preparation._regular(root / name, 65536)
        actual = hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()
        reservations.need(actual == wanted, "not accepted H module bytes:" + name)
        files["res://" + H_PREFIX + name] = reservations.digest(raw)
    return files


class BackendBlocked(reservations.ReservationError):
    """Unsupported or unbound execution, not an unconditional backend stub."""


def require_native_backend(unit, command, repo, lifetime, generated=None):
    return backend.Prepared(unit, command, repo, lifetime, generated)


def _complete(command, unit, account_path, receipt_path, output, head, repo, check, lifetime, inert=False):
    # A canonical immutable copy prevents caller mutation after validation.
    unit = json.loads(reservations.encode(unit))
    account = reservations.read(account_path)
    check(account)
    reservations.need(unit.get("linux", {}).get("output_root") == str(output.resolve()), "unbound output root")
    reservations.available(account, 1 + unit["contained_starts"], unit["cpu_seconds"] * 10**9, unit["raw_bytes"])
    try:
        generated = preparation.load_sealed(unit, account)
        prepared = require_native_backend(unit, list(command), repo, lifetime, generated)
        if inert:
            reservations.need(reservations.digest(prepared.pinned["files"][command[0]][0]) in INERT_BINARIES,
                              "inert entry permits only pinned harmless fixture")
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
    reservations.need(trusted_context.kind == "empirical", "native entry rejects synthetic authority")
    unit = json.loads(reservations.encode(unit))
    lifetime = backend.controller_limits(unit)
    h_files = check_h_closure(Path(__file__).resolve().parents[1] / H_PREFIX)
    reservations.need(all(unit.get("source_files", {}).get(k) == v for k, v in h_files.items()),
                      "accepted H closure missing from execution demand")
    from dd1_provenance import REQUIRED_SOURCES, _load_boundary
    expected = _load_boundary().verify_bindings(evidence_packet, trusted_context)
    binding = expected["roles"].get("execution_demand", {})
    raw = reservations.encode(unit)
    reservations.need(expected.get("artifact_head") == head and binding.get("sha256") == reservations.digest(raw)
        and trusted_context.resolve(binding.get("locator")) == raw, "unbound native execution demand/source")
    reservations.need(unit.get("mode") != "inert_control" and REQUIRED_SOURCES <= unit["source_files"].keys(),
                      "native mode/source closure invalid")
    compatibility.native_bindings(unit, expected, trusted_context)
    from dd1_recovery_meter import STARTING_G, load_bindings, validate_launch_receipt
    backend.snapshot.verify_ancestry(unit.get("linux", {}).get("ancestry"), head, STARTING_G)
    bindings = load_bindings()
    receipt = reservations.read(receipt_path)
    def check(account):
        reservations.need(account.get("synthetic") is not True, "native entry rejects synthetic account")
        validate_launch_receipt(receipt, bindings=bindings, account=account, overlay_head=head, require_descendant=False)
    return _complete(command, unit, account_path, receipt_path, output, head, repo, check, lifetime)


def _run_inert_unit(command, *, unit, account_path, receipt_path, output, head, repo):
    """Test-only entry: never reachable through the native meter CLI.

    Uses the SAME prepare/reserve/kernel-enforcement path. No OS mocks, supplied
    runner or test clock. A synthetic account and exact test-only receipt are
    mandatory; the repository's live account path cannot be selected.
    """
    unit = json.loads(reservations.encode(unit))
    lifetime = backend.controller_limits(unit)
    reservations.need(not account_path.resolve().is_relative_to(repo.resolve()), "inert account cannot be a repository account")
    receipt = reservations.read(receipt_path)
    # Receipt binds a demand with its receipt field omitted, avoiding a hash cycle.
    unsigned = dict(unit); unsigned.pop("receipt_sha256", None)
    reservations.need(receipt.get("schema") == "DD1-INERT-ONLY" and receipt.get("demand_sha256") ==
        reservations.digest(reservations.encode(unsigned)), "inert demand/receipt mismatch")
    reservations.need(unit.get("mode") == "inert_control" and command[0] == "/workload" and
                      ("res://tools/dd1_linux/inert.c" in unit["source_files"] or
                       "res://tools/dd1_linux/compat2_inert.c" in unit["source_files"] or
                       "res://tools/dd1_linux/prep_inert.c" in unit["source_files"]), "inert fixture binding required")
    def check(account):
        reservations.need(account.get("synthetic") is True, "inert entry requires synthetic account")
    return _complete(command, unit, account_path, receipt_path, output, head, repo, check, lifetime, inert=True)
