"""Exact host qualification for DD1-KERNEL-COMPAT-1. No I/O, clock, or host probe.

require/native_bindings raise ReservationError on any mismatch. The inert
reservation policy is code-pinned; callers cannot shape its deadline.
"""
from __future__ import annotations
import json
import re
import dd1_reservations as r

SCHEMA = "DD1-KERNEL-QUALIFICATION-1"
OPERATION = "DD1-KERNEL-COMPAT-1"
SELECTION = 5845725453
DISPOSITION_SCHEMA = "DD1-KERNEL-COMPAT-DISPOSITION-1"
PRIMITIVES = frozenset((
    "seccomp_user_notif", "user_namespace", "mount_namespace", "network_namespace",
    "readonly_bind_remount", "subreaper", "pdeathsig", "rlimit_cpu", "cgroup_v2"))
IDENTITY_FIELDS = ("system", "machine", "kernel_release", "kernel_version",
                   "pointer_bytes", "libc")
LEGACY_RELEASE = "6.18.44"
QUALIFIED_IDENTITY = dict(
    system="Linux", machine="x86_64", kernel_release="6.12.94+",
    kernel_version="#1 SMP PREEMPT_DYNAMIC Mon Sep 14 19:13:20 UTC 2026",
    pointer_bytes=8, libc=["glibc", "2.41"])
KEYS = frozenset(("schema", "operation", "selection", "source_head", "status", "mode",
                  "host_identity", "primitives"))
INERT_RESERVATION_POLICY = {
    "operation": "DD1-KERNEL-COMPAT-1",
    "selection": 5845725453,
    "start_utc": "2026-09-26T11:02:00Z",
    "deadline_utc": "2026-09-27T11:02:00Z",
    "synthetic_only": True,
    "starts_cap": 16,
    "cpu_ns_cap": 300_000_000_000,
    "raw_bytes_cap": 134_217_728,
    "per_invocation_cpu_seconds": 30,
    "executors": 1,
}


def profile_sha256(unit):
    return r.digest(r.encode(unit["kernel_qualification"]))


def require(unit, host_facts):
    q = unit.get("kernel_qualification")
    if q is None:
        r.need(host_facts["system"] == "Linux" and host_facts["machine"] == "x86_64"
               and host_facts["pointer_bytes"] == 8 and host_facts["kernel_release"] == LEGACY_RELEASE,
               "unsupported host/ABI; no fallback")
        return
    r.need(isinstance(q, dict), "kernel qualification profile required")
    r.need(set(q) == KEYS, "no extra fields")
    r.need(q["schema"] == SCHEMA, "wrong kernel qualification schema")
    r.need(q["operation"] == OPERATION, "wrong kernel qualification operation")
    r.need(q["selection"] == SELECTION, "wrong kernel qualification selection")
    head = q["source_head"]
    r.need(isinstance(head, str) and re.fullmatch(r"[0-9a-f]{40}", head) is not None
           and head == unit.get("overlay_head"), "wrong source head")
    r.need(q["status"] in ("REQUALIFYING", "QUALIFIED"), "wrong kernel qualification status")
    r.need(q["mode"] == unit.get("mode"), "kernel qualification mode mismatch")
    ident = q["host_identity"]
    r.need(isinstance(ident, dict) and set(ident) == set(IDENTITY_FIELDS), "wrong host identity fields")
    for field in IDENTITY_FIELDS:
        r.need(field in host_facts and ident[field] == host_facts[field], "host identity mismatch: " + field)
    prims = q["primitives"]
    r.need(isinstance(prims, list) and all(isinstance(name, str) for name in prims)
           and len(prims) == len(PRIMITIVES) and sorted(prims) == sorted(PRIMITIVES),
           "wrong primitive set")
    if q["status"] == "REQUALIFYING":
        r.need(q["mode"] == "inert_control" and unit.get("mode") == "inert_control",
               "REQUALIFYING is inert-control only")


def native_bindings(unit, expected, context):
    q = unit.get("kernel_qualification")
    if q is None:
        return
    r.need(isinstance(q, dict), "kernel qualification profile required")
    r.need(q.get("status") == "QUALIFIED",
           "REQUALIFYING/incomplete kernel qualification is not native authority")
    role = expected["roles"].get("kernel_qualification_disposition", {})
    raw = context.resolve(role.get("locator"))
    r.need(isinstance(raw, bytes) and r.digest(raw) == role.get("sha256"),
           "missing kernel qualification disposition")
    try:
        d = json.loads(raw)
    except ValueError as exc:
        raise r.ReservationError("malformed kernel qualification disposition") from exc
    r.need(isinstance(d, dict), "malformed kernel qualification disposition")
    r.need(d.get("schema") == DISPOSITION_SCHEMA, "wrong disposition schema")
    r.need(d.get("operation") == OPERATION, "wrong disposition operation")
    r.need(d.get("owner_selection") == SELECTION, "wrong disposition owner selection")
    r.need(d.get("profile_sha256") == profile_sha256(unit), "wrong disposition profile")
    r.need(d.get("source_head") == unit["overlay_head"], "wrong disposition source head")
    r.need(d.get("kernel_identity") == q["host_identity"], "wrong disposition kernel identity")
    r.need(d.get("independent_review") == "APPROVE", "disposition review is not approved")
    r.need(d.get("planner_acceptance") == "ACCEPTED", "disposition is not accepted")
    r.need(d.get("launch_admitted") is True, "disposition launch is not admitted")
    auth = expected.get("receipt_authorities", {}).get("kernel_qualification_disposition", {})
    r.need(isinstance(auth.get("authority"), str) and auth["authority"]
           and not auth["authority"].startswith("synthetic:")
           and auth.get("sha256") == r.digest(raw) and d.get("authority") == auth["authority"]
           and context.receipts.get("kernel_qualification_disposition") == raw,
           "unauthenticated kernel qualification issuer")
    r.need(context.kind == "empirical", "kernel qualification rejects synthetic native authority")


def inert_reservation_policy(unit):
    """Return the code-pinned K1 inert policy, or fail closed. No I/O and no clock."""
    q = unit.get("kernel_qualification")
    r.need(unit.get("mode") == "inert_control", "kernel reservation policy is inert-control only")
    r.need(unit.get("operation") == OPERATION, "wrong unit operation")
    r.need(isinstance(q, dict), "kernel qualification required")
    r.need(q.get("selection") == SELECTION and q.get("operation") == OPERATION,
           "wrong kernel qualification selection")
    r.need(unit.get("operation_start_utc") == INERT_RESERVATION_POLICY["start_utc"],
           "wrong operation_start_utc")
    r.need(unit.get("operation_deadline_utc") == INERT_RESERVATION_POLICY["deadline_utc"],
           "wrong operation_deadline_utc")
    r.need(q.get("status") == "REQUALIFYING", "REQUALIFYING required")
    r.need(q.get("host_identity") == QUALIFIED_IDENTITY, "wrong K0 host identity")
    return dict(INERT_RESERVATION_POLICY)
