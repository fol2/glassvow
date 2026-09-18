"""Temporary SYNTHETIC inputs. No native-account resolver or native binary path."""
import hashlib
import os
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import dd1_reservations as r
import dd1_linux_snapshot as s


def account():
    return dict(schema="DD1-N0-RECOVERY-1-ACCOUNT-1", synthetic=True,
        historical=dict(attempt="1/1 consumed", starts_used=1277, starts_cap=8192,
            starts_remaining_arithmetic=6915, spendable=False, cpu_seconds="UNKNOWN",
            elapsed_seconds="UNKNOWN", raw_bytes="UNKNOWN"),
        recovery=dict(id=r.OPERATION, starts_used=2040, starts_cap=r.STARTS_CAP,
            cpu_ns_used=398617197992, cpu_ns_cap=r.CPU_CAP, raw_bytes_used=893139,
            raw_bytes_cap=r.RAW_CAP, executors=1, per_invocation_cpu_seconds=300,
            first_engine_launch_utc=r.FIRST, deadline_utc=r.DEADLINE,
            events=[{"note": "SYNTHETIC only; real observations are not loaded"}]))


def case(root, repo, mode="positive", **overrides):
    r.atomic_write(root / "ACCOUNT.json", account())
    sources = s.HELPER_SOURCES | {"res://tools/dd1_linux/inert.c"}
    unit = dict(schema="DD1-COMPLETE-UNIT-DEMAND-2", operation=r.OPERATION, scientific_m=r.M,
        overlay_head="5d10f2182f55cc2ee44b90474c823b0c312eaee7", account_sha256=r.digest((root / "ACCOUNT.json").read_bytes()),
        argv=["/workload", mode], unit_id="inert-" + mode, mode="inert_control", contained_starts=0,
        cpu_seconds=11, wall_seconds=5, raw_bytes=8 * 1024 * 1024,
        source_files={name: r.digest((repo / name[6:]).read_bytes()) for name in sources},
        linux=dict(abi=s.ABI, entry="/workload", output_root=str((root / "result").resolve()), threads=4, workload_raw_bytes=65536,
            helper=dict(path="tools/dd1_linux/build/supervisor", sha256=r.digest((repo / "tools/dd1_linux/build/supervisor").read_bytes())),
            runtime={"/workload": dict(path="tools/dd1_linux/build/inert", sha256=r.digest((repo / "tools/dd1_linux/build/inert").read_bytes()), executable=True)}))
    unit["overlay_head"] = os.environ.get("DD1_INERT_CODE_HEAD", unit["overlay_head"])
    unit.update(overrides)
    sign(root, unit)
    return unit


def sign(root, unit):
    unsigned = dict(unit); unsigned.pop("receipt_sha256", None)
    receipt = dict(schema="DD1-INERT-ONLY", demand_sha256=r.digest(r.encode(unsigned)))
    r.atomic_write(root / "receipt.json", receipt)
    unit["receipt_sha256"] = r.digest((root / "receipt.json").read_bytes())
    r.atomic_write(root / "demand.json", unit)
