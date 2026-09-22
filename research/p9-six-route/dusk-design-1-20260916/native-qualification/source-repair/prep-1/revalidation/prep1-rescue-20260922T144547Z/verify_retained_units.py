#!/usr/bin/env python3
"""PREP-1 rescue reader: verify three retained units; never execute their code."""
import argparse
import base64
from datetime import datetime, timezone
import hashlib
import json
import lzma
import os
from pathlib import Path
import platform
import resource
import time

I = "d4e91e4fc70d57c81922cc1883b339877d835a53"
E = "e469476598cff36493e377865ec3df5447e52651"
PINS = {
    "BUILD-COMMAND-BUNDLE.json": "b95d8685e7a717ce50e239ee13a613f9efa75a95",
    "METADATA-COMMAND-BUNDLE.json": "63c488cee9af1df72d8e48a1828cd0ae05437f97",
    "MATRIX-RESULT-194750.json": "05dcfbef0163aa8927fef7818ab5a5f201a688d8",
}

def sha(raw):
    return hashlib.sha256(raw).hexdigest()

def blob(raw):
    return hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()

def require(value, message):
    if not value:
        raise ValueError(message)

def stream(value):
    raw = value.get("utf8", value.get("text", "")).encode()
    require(len(raw) == value["bytes"] and sha(raw) == value["sha256"], "stream identity")
    return raw

def bundle(raw):
    wrapper = json.loads(raw)
    compressed = base64.b64decode("".join(wrapper["payload_base64_lines"]), validate=True)
    require(len(compressed) == wrapper["compressed_bytes"] and
            sha(compressed) == wrapper["compressed_sha256"], "compressed identity")
    decoder = lzma.LZMADecompressor()
    decoded = decoder.decompress(compressed, max_length=2**20)
    require(decoder.eof and not decoder.unused_data, "incomplete/extra XZ stream")
    require(len(decoded) == wrapper["decoded_bytes"] and
            sha(decoded) == wrapper["decoded_sha256"], "decoded identity")
    return wrapper, decoded, json.loads(decoded)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    require(not args.output.exists(), "refuse to replace an observation")
    started = datetime.now(timezone.utc).isoformat()
    t0 = time.monotonic()
    cpu0 = resource.getrusage(resource.RUSAGE_SELF)
    units = {}
    for name, wanted in PINS.items():
        raw = (args.input / name).read_bytes()
        require(blob(raw) == wanted, name + ": GitHub byte identity")
        row = {"git_blob": wanted, "bytes": len(raw), "sha256": sha(raw)}
        if name.endswith("BUNDLE.json"):
            wrapper, decoded, record = bundle(raw)
            row.update(decoded_bytes=len(decoded), decoded_sha256=sha(decoded),
                       compressed_bytes=wrapper["compressed_bytes"],
                       compressed_sha256=wrapper["compressed_sha256"])
            require(record["implementation"] == I and record["exit"] == 0, "source/exit")
            out = stream(record["stdout"])
            require(stream(record["stderr"]) == b"", "nonempty stderr")
            row.update(execution_run_id=record["run_id"], argv=record["argv"],
                       started_utc=record["started_utc"], ended_utc=record["ended_utc"],
                       exit=record["exit"], wall_seconds=record["wall_seconds"],
                       stdout_bytes=len(out), stdout_sha256=sha(out))
            if name.startswith("BUILD"):
                require(record["source_before"] == record["source_after"], "recorded source drift")
                require(sha(record["observer_source_utf8"].encode()) == record["observer_source_sha256"], "observer bytes")
                require(record["host"]["observer_task_count"] == 1, "recorded controller topology")
                pins = {"supervisor": "b22fdaba90df2a1a317f1d3a690522736a1301f9b442016764d5bf173f2fdf0f",
                        "prep-inert": "d13b4975c0c131e15780f435474d88f2950cb25629c69fe497cbb7824a446629"}
                require(all(record["build_after"][n]["sha256"] == h for n, h in pins.items()), "build pins")
                result = json.loads(out)
                require(all(x.get("exit", 0) == 0 for x in result["builds"]), "compiler failure")
                require(result["engine_runs"] == result["helper_runs"] == 0, "build scope")
                row.update(source_manifest_files=len(record["source_before"]),
                           source_manifest_bytes=sum(x["bytes"] for x in record["source_before"].values()),
                           recorded_sources_before_equal_after=True, build_after=record["build_after"],
                           recorded_resources=record["children_usage"],
                           prior_observer_correction=record["observer_preflight_correction"]["correction"])
            else:
                result = json.loads(out)
                require(result["source_before"] == result["source_after"], "metadata input/source drift")
                require(result["threads"] == 1 and result["result"] == "PASS", "metadata outcome")
                require(stream(record["checker"]), "missing exact checker")
                for path, item in record["inputs"].items():
                    data = stream(item)
                    source = result["source_before"][path]
                    require(blob(data) == source["git_blob"] and sha(data) == source["sha256"] and
                            len(data) == source["bytes"], "metadata input bytes")
                require(len(result["outcomes"]) == 3 and all(x["result"] == "PASS" for x in result["outcomes"]), "sample outcomes")
                row.update(sample_inputs={n: result["source_before"][n] for n in record["inputs"]},
                           sample_results=[{"path": x["path"], "result": x["result"]} for x in result["outcomes"]],
                           checker_sha256=record["checker"]["sha256"],
                           recorded_resources=record["child_resources"], limits=record["limits"])
        else:
            record = json.loads(raw)
            require(record["head"] == I and record["exit"] == 0 and record["observer_tasks"] == 1, "matrix identity/exit")
            for key in ("stdout", "stderr"):
                data = record[key].encode()
                spec = record["streams"]["MATRIX-" + key + ".txt"]
                require(len(data) == spec["bytes"] and sha(data) == spec["sha256"], "matrix stream")
            passed = record["passed"]
            require(len(passed) == len(set(passed)) == 45, "distinct group count")
            require(record["stdout"] == "".join("PASS " + n + "\n" for n in passed) and record["stderr"] == "", "matrix results")
            witness = record["mutate_use_restore"]
            require(witness["resource_utf8"] == "DD1-INERT-RESOURCE:quality=9:ASSET-INERT\n" and
                    witness["final_sidecar_utf8"].endswith("quality=7\n") and
                    witness["task_success"] is False and witness["sealed_preparation"] is None and
                    witness["audit"]["seed_history"]["ok"] is False, "mutation witness")
            row.update(execution_run_id=record["run_id"], argv=record["argv"],
                       started_utc=record["start_utc"], ended_utc=record["end_utc"], exit=0,
                       wall_seconds=record["wall_seconds"], recorded_resources=record["measured_child_resource"],
                       groups=passed, source_after_verified_equal_recorded=record["source_after_verified_equal"],
                       limits="Actual aggregate command record; not a substitute for all underlying raw cases or command metadata of another run.")
        units[name] = row
    usage = resource.getrusage(resource.RUSAGE_SELF)
    report = {"schema": "PREP1-RESCUE-READBACK-1", "run_id": args.input.name,
              "authority": "#542/5757861057; owner rescue continuation", "evidence_head": E,
              "implementation": I, "started_utc": started,
              "ended_utc": datetime.now(timezone.utc).isoformat(), "result": "PASS_READBACK_ONLY",
              "reader_sha256": sha(Path(__file__).read_bytes()),
              "host": {"system": platform.system(), "release": platform.release(), "machine": platform.machine(),
                       "boot_id": Path("/proc/sys/kernel/random/boot_id").read_text().strip(),
                       "task_count": len(list(Path("/proc/self/task").iterdir()))},
              "new_reader_resources": {"wall_seconds": time.monotonic() - t0,
                  "user_cpu_seconds": usage.ru_utime - cpu0.ru_utime,
                  "system_cpu_seconds": usage.ru_stime - cpu0.ru_stime,
                  "maxrss_kib_high_water": usage.ru_maxrss,
                  "scope": "Only this reader execution, excluding retrieval, materialization, earlier decodes and analysis; no ledger credit."},
              "units": units, "engine_runs_here": 0, "build_or_matrix_or_metadata_reruns_here": 0,
              "live_account_writes_here": 0, "source_changes_here": 0,
              "limits": "Verification of retained NEW evidence, not new execution of recorded commands, not recovery of unavailable original PREP-1 evidence, not independent approval; retain each execution run identity."}
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))

if __name__ == "__main__":
    main()
