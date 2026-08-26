#!/usr/bin/env python3
"""Host fingerprint, seed-1000 digest and worker-count benchmark for #501."""
from __future__ import annotations

import argparse
import hashlib
import json
import platform
import shutil
import subprocess
import sys
import tempfile
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Any

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

from balance_s009_reconstruct import reconstruct  # noqa: E402
from balance_seed_contract import (  # noqa: E402
    LIVE_REL,
    MOBS_REL,
    REPO,
    SPACE_REL,
    catalogue_identity,
    check_invocation,
    file_sha256,
    load_contract,
    semantic_sha256,
)

ASPECTS = ("duskblade", "ashwarden")
VOWS = (0, 5)
FINGERPRINT = (12000, 12063)
FINGERPRINT_STAGE = "tier2-fingerprint"
REQUIRED_GODOT_PREFIX = "4.7.2.stable"
H39_FILE_SHA = "a0d608a5142d2e3aab799cdf33d3163922b402c2aaf2a895e46e096399b56cf1"
CANONICAL_REL = "docs/balance/data/501/canonical-host.json"
ISSUE = 501


def run(cmd: list[str], cwd: Path = REPO) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, cwd=cwd, text=True, capture_output=True)


def godot_version(godot: str) -> str:
    proc = run([godot, "--version"])
    if proc.returncode != 0:
        raise ValueError(f"{godot} --version failed: {proc.stderr.strip() or proc.stdout.strip()}")
    return proc.stdout.strip()


def require_godot(godot: str) -> str:
    version = godot_version(godot)
    if not version.startswith(REQUIRED_GODOT_PREFIX):
        raise ValueError(f"godot --version must start with {REQUIRED_GODOT_PREFIX}, got {version}")
    return version


def host_identity(workers: int) -> dict[str, Any]:
    cpu = platform.processor() or platform.machine()
    if sys.platform == "darwin":
        brand = run(["sysctl", "-n", "machdep.cpu.brand_string"])
        if brand.returncode == 0 and brand.stdout.strip():
            cpu = brand.stdout.strip()
    return {
        "os": platform.system(),
        "arch": platform.machine(),
        "cpu": cpu,
        "hostname": platform.node(),
        "workers": workers,
    }


def fingerprint_shards(jobs: int) -> list[dict[str, Any]]:
    if jobs < 1:
        raise ValueError("jobs must be positive")
    first, last = FINGERPRINT
    seed_n = last - first + 1
    cells = [(aspect, vow) for aspect in ASPECTS for vow in VOWS]
    parts = [1] * len(cells)
    for index in range(max(0, jobs - len(cells))):
        parts[index % len(cells)] += 1
    shards: list[dict[str, Any]] = []
    for (aspect, vow), n_parts in zip(cells, parts, strict=True):
        base, rem = divmod(seed_n, n_parts)
        start = first
        for part in range(n_parts):
            take = base + (1 if part < rem else 0)
            shards.append({"aspect": aspect, "vow": vow, "seed0": start, "runs": take})
            start += take
    return shards


def godot_sim(godot: str, flags: list[str], out: Path, log: Path) -> None:
    cmd = [godot, "--headless", "-s", "res://tools/balance_sim.gd", "--", *flags, f"--out={out}"]
    log.parent.mkdir(parents=True, exist_ok=True)
    with log.open("w", encoding="utf-8") as handle:
        handle.write(" ".join(cmd) + "\n")
        proc = subprocess.run(cmd, cwd=REPO, stdout=handle, stderr=subprocess.STDOUT)
    if proc.returncode != 0:
        raise RuntimeError(f"balance_sim exited {proc.returncode}; see {log}")
    if not out.is_file():
        raise RuntimeError(f"balance_sim wrote no output: {out}")


def load_report(path: Path) -> dict[str, Any]:
    blob = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(blob, dict) or "runs" not in blob:
        raise ValueError(f"expected a Metrics.report JSON: {path}")
    return blob


def row_fingerprint(row: dict[str, Any]) -> str:
    payload = {
        "aspect": row["aspect"],
        "deck": row["deck"],
        "error": row.get("error", ""),
        "gold": row["gold"],
        "hp": row["hp"],
        "maxHp": row["maxHp"],
        "outcome": row["outcome"],
        "rng": row["rng"],
        "seed": row["seed"],
        "vow": row["vow"],
    }
    return hashlib.sha256(json.dumps(payload, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def fingerprint_hash(rows: list[dict[str, Any]]) -> str:
    ordered = sorted(rows, key=lambda row: (int(row["seed"]), str(row["aspect"]), int(row["vow"])))
    return hashlib.sha256("\n".join(row_fingerprint(row) for row in ordered).encode()).hexdigest()


def count_faults(rows: list[dict[str, Any]]) -> tuple[int, int]:
    stalls = sum(1 for row in rows if row.get("outcome") == "stall")
    errors = sum(1 for row in rows if row.get("outcome") == "error")
    return stalls, errors


def run_digest(godot: str, out_dir: Path, content: str) -> dict[str, Any]:
    out = out_dir / "digest.json"
    flags = ["--aspect=duskblade", "--runs=1", "--seed0=1000", "--vow=0"]
    if content:
        flags.append(f"--content={content}")
    godot_sim(godot, flags, out, out_dir / "digest.log")
    report = load_report(out)
    row = report["runs"][0]
    digest = str(report.get("outcomeDigest", ""))
    if not digest:
        raise ValueError("balance_sim did not emit outcomeDigest for the seed-1000 row")
    return {
        "outcomeDigest": digest,
        "row": {"outcome": row["outcome"], "rng": row["rng"], "hp": row["hp"]},
        "manifest": report.get("manifest", {}),
    }


def run_fingerprint(godot: str, out_dir: Path, jobs: int, content: str) -> dict[str, Any]:
    error = check_invocation(load_contract(), FINGERPRINT_STAGE, FINGERPRINT[0], FINGERPRINT[1])
    if error:
        raise ValueError(error)
    shards = fingerprint_shards(jobs)
    t0 = time.perf_counter()
    rows: list[dict[str, Any]] = []
    manifests: list[dict[str, Any]] = []

    def _one(index_shard: tuple[int, dict[str, Any]]) -> tuple[dict[str, Any], list[dict[str, Any]]]:
        index, shard = index_shard
        out = out_dir / f"shard-{index}.json"
        flags = [
            f"--aspect={shard['aspect']}", f"--vow={shard['vow']}",
            f"--seed0={shard['seed0']}", f"--runs={shard['runs']}",
            f"--stage={FINGERPRINT_STAGE}",
        ]
        if content:
            flags.append(f"--content={content}")
        godot_sim(godot, flags, out, out_dir / f"shard-{index}.log")
        report = load_report(out)
        return report.get("manifest", {}), report["runs"]

    workers = min(jobs, len(shards))
    with ThreadPoolExecutor(max_workers=workers) as pool:
        for manifest, shard_rows in pool.map(_one, enumerate(shards)):
            manifests.append(manifest)
            rows.extend(shard_rows)
    wall = time.perf_counter() - t0
    stalls, errors = count_faults(rows)
    if len(rows) != 256:
        raise ValueError(f"fingerprint must retain 256 rows, got {len(rows)}")
    if stalls or errors:
        raise ValueError(f"fingerprint introduced stalls={stalls} errors={errors}")
    shas = {str(m.get("contentFileSha256", "")) for m in manifests if m}
    if len(shas) != 1:
        raise ValueError(f"fingerprint content SHA drifted across shards: {shas}")
    return {
        "rows": len(rows),
        "fingerprintHash": fingerprint_hash(rows),
        "stalls": stalls,
        "errors": errors,
        "wallSeconds": round(wall, 3),
        "rowsPerSecond": round(len(rows) / wall, 3) if wall else 0.0,
        "workers": workers,
        "shards": shards,
        "manifest": manifests[0] if manifests else {},
    }


def write_packet(path: Path, packet: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(packet, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def compare_packets(canonical: dict[str, Any], other: dict[str, Any]) -> list[str]:
    faults: list[str] = []
    for key in ("godotVersion", "contentFileSha256", "contentSemanticSha256",
                "mobOverrideFileSha256", "mobOverrideSemanticSha256",
                "searchSpaceSha256", "seedContractSha256", "driverSha256",
                "s009FileSha256", "s009SemanticSha256"):
        if canonical.get(key) != other.get(key):
            faults.append(f"{key} {other.get(key)} != canonical {canonical.get(key)}")
    if canonical.get("digest", {}).get("outcomeDigest") != other.get("digest", {}).get("outcomeDigest"):
        faults.append("seed-1000 digest mismatch")
    if canonical.get("fingerprint", {}).get("fingerprintHash") != other.get("fingerprint", {}).get("fingerprintHash"):
        faults.append("256-row fingerprint mismatch")
    return faults


def build_packet(godot: str, out_dir: Path, jobs: int, content: str) -> dict[str, Any]:
    version = require_godot(godot)
    content_path = Path(content) if content else REPO / LIVE_REL
    identity = catalogue_identity(content_path, REPO / SPACE_REL)
    s009 = reconstruct()["identity"]
    digest = run_digest(godot, out_dir, content)
    fingerprint = run_fingerprint(godot, out_dir, jobs, content)
    commit = str(fingerprint.get("manifest", {}).get("commit")
                 or digest.get("manifest", {}).get("commit") or "unknown")
    pin = load_contract()["digestPin"]["outcomeDigest"]
    if identity["contentFileSha256"] == H39_FILE_SHA and digest["outcomeDigest"] == pin:
        digest_status = "PIN_MATCH"
        qualified = True
        reason = ""
    elif identity["contentFileSha256"] == H39_FILE_SHA:
        digest_status = "PIN_MISMATCH"
        qualified = False
        reason = "seed-1000 digest does not match the H39 pin"
    else:
        digest_status = "RECORDED"
        qualified = True
        reason = ""
    return {
        "issue": ISSUE,
        "godotVersion": version,
        "commit": commit,
        **identity,
        "s009FileSha256": s009["fileSha256"],
        "s009SemanticSha256": s009["semanticSha256"],
        "host": host_identity(jobs),
        "digest": {**digest, "pin": pin, "status": digest_status},
        "fingerprint": fingerprint,
        "qualified": qualified,
        "reason": reason,
    }


def prove_concurrent(godot: str, out_dir: Path) -> dict[str, Any]:
    live = REPO / LIVE_REL
    before = file_sha256(live)
    raw = json.loads(live.read_text(encoding="utf-8"))
    left_dir, right_dir = out_dir / "c-left", out_dir / "c-right"
    left_dir.mkdir(parents=True)
    right_dir.mkdir(parents=True)
    left, right = dict(raw), dict(raw)
    left["player"], right["player"] = dict(raw["player"]), dict(raw["player"])
    left["aspects"], right["aspects"] = list(raw["aspects"]), list(raw["aspects"])
    left["aspects"][0], right["aspects"][0] = dict(raw["aspects"][0]), dict(raw["aspects"][0])
    left["player"]["maxHp"] = int(raw["player"]["maxHp"]) + 2
    right["player"]["maxHp"] = int(raw["player"]["maxHp"]) + 4
    left["aspects"][0]["maxHp"] = int(raw["aspects"][0]["maxHp"]) + 2
    right["aspects"][0]["maxHp"] = int(raw["aspects"][0]["maxHp"]) + 4
    left_path, right_path = left_dir / "full-content.json", right_dir / "full-content.json"
    left_path.write_text(json.dumps(left, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    right_path.write_text(json.dumps(right, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")

    def _run(name: str, path: Path) -> dict[str, Any]:
        out = out_dir / f"{name}.json"
        godot_sim(godot, ["--aspect=duskblade", "--runs=1", "--seed0=12000", "--vow=0",
                          f"--content={path}", f"--stage={FINGERPRINT_STAGE}"], out, out_dir / f"{name}.log")
        return load_report(out)

    with ThreadPoolExecutor(max_workers=2) as pool:
        left_report, right_report = list(pool.map(
            lambda item: _run(item[0], item[1]), (("left", left_path), ("right", right_path)),
        ))
    if file_sha256(live) != before:
        raise RuntimeError("live content/full-content.json changed during concurrent candidate runs")
    left_sha = left_report["manifest"]["contentFileSha256"]
    right_sha = right_report["manifest"]["contentFileSha256"]
    if left_sha == right_sha or left_sha != file_sha256(left_path) or right_sha != file_sha256(right_path):
        raise RuntimeError("concurrent candidates did not bind distinct loaded file SHAs")
    if left_report["runs"][0]["maxHp"] == right_report["runs"][0]["maxHp"]:
        raise RuntimeError("concurrent candidates observed one catalogue")
    return {
        "liveUnchanged": True,
        "leftFileSha256": left_sha,
        "rightFileSha256": right_sha,
        "leftMaxHp": left_report["runs"][0]["maxHp"],
        "rightMaxHp": right_report["runs"][0]["maxHp"],
    }


def _enemy_overlay(enemy_id: str, hp: list[int]) -> dict[str, Any]:
    blob = json.loads((REPO / LIVE_REL).read_text(encoding="utf-8"))
    row = json.loads(json.dumps(blob["enemies"][enemy_id]))
    row["hp"] = hp
    return {enemy_id: row}


def _write_overlay(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def prove_mobs(godot: str, out_dir: Path) -> dict[str, Any]:
    live = REPO / MOBS_REL
    before = file_sha256(live)
    overlay_dir = out_dir / "overlays"
    left_path, right_path = overlay_dir / "left.json", overlay_dir / "right.json"
    _write_overlay(left_path, _enemy_overlay("sporeling", [1, 1]))
    _write_overlay(right_path, _enemy_overlay("sporeling", [200, 200]))

    def _run(name: str, flags: list[str]) -> dict[str, Any]:
        out = out_dir / f"{name}.json"
        godot_sim(godot, ["--aspect=duskblade", "--runs=1", "--seed0=12000", "--vow=0",
                          f"--stage={FINGERPRINT_STAGE}", *flags],
                  out, out_dir / f"{name}.log")
        return load_report(out)

    with ThreadPoolExecutor(max_workers=2) as pool:
        left_report, right_report = list(pool.map(
            lambda item: _run(item[0], [f"--mobs={item[1]}"]),
            (("left", left_path), ("right", right_path)),
        ))
    if file_sha256(live) != before:
        raise RuntimeError("live content/mob-overrides.json changed during concurrent --mobs runs")
    left_sha = str(left_report["manifest"]["mobOverrideFileSha256"])
    right_sha = str(right_report["manifest"]["mobOverrideFileSha256"])
    if left_sha == right_sha or left_sha != file_sha256(left_path) or right_sha != file_sha256(right_path):
        raise RuntimeError("concurrent --mobs candidates did not bind distinct loaded file SHAs")
    left_row, right_row = left_report["runs"][0], right_report["runs"][0]
    if left_row["rng"] == right_row["rng"] and left_row["hp"] == right_row["hp"] \
            and left_row["outcome"] == right_row["outcome"]:
        raise RuntimeError("concurrent --mobs candidates observed one mob catalogue")
    replay = _run("replay", [f"--mobs={left_path}"])
    if str(replay.get("outcomeDigest", "")) != str(left_report.get("outcomeDigest", "")) \
            or not replay.get("outcomeDigest"):
        raise RuntimeError("same --mobs candidate/seed did not replay byte-identically")
    defaulted = _run("default", [])
    explicit = _run("explicit-empty", [f"--mobs={live}"])
    if str(defaulted.get("outcomeDigest", "")) != str(explicit.get("outcomeDigest", "")):
        raise RuntimeError("default no --mobs must match the live empty overlay")
    if str(defaulted["manifest"]["mobOverrideFileSha256"]) != before \
            or str(defaulted["manifest"]["mobOverrideSemanticSha256"]) != semantic_sha256(live):
        raise RuntimeError("default no --mobs must bind the live empty overlay identity")
    return {
        "liveUnchanged": True,
        "leftFileSha256": left_sha,
        "rightFileSha256": right_sha,
        "replayDigest": replay.get("outcomeDigest", ""),
    }


def fail_closed_cli(godot: str, out_dir: Path) -> None:
    missing = out_dir / "missing-out.json"
    proc = run([godot, "--headless", "-s", "res://tools/balance_sim.gd", "--",
                "--content=/no/such/glassvow-candidate.json", "--aspect=duskblade",
                "--runs=1", "--seed0=12000", "--vow=0", f"--stage={FINGERPRINT_STAGE}",
                f"--out={missing}"])
    if proc.returncode == 0:
        raise RuntimeError("missing --content must fail closed")
    if missing.exists() and missing.stat().st_size:
        blob = json.loads(missing.read_text(encoding="utf-8"))
        if isinstance(blob, dict) and blob.get("runs"):
            raise RuntimeError("missing --content emitted simulation rows")
    overlap = run([godot, "--headless", "-s", "res://tools/balance_sim.gd", "--",
                   "--aspect=duskblade", "--runs=1", "--seed0=5000", "--vow=0",
                   "--stage=f0-controls", f"--out={out_dir / 'overlap.json'}"])
    if overlap.returncode == 0:
        raise RuntimeError("F0 overlapping acceptance seeds must fail closed")
    tier1_overlap = run([godot, "--headless", "-s", "res://tools/balance_sim.gd", "--",
                         "--aspect=duskblade", "--runs=1", "--seed0=5000", "--vow=0",
                         "--stage=tier1-f0-controls", f"--out={out_dir / 'tier1-overlap.json'}"])
    if tier1_overlap.returncode == 0:
        raise RuntimeError("Tier-1 F0 overlapping acceptance seeds must fail closed")
    prior = run([godot, "--headless", "-s", "res://tools/balance_sim.gd", "--",
                 "--aspect=duskblade", "--runs=1", "--seed0=6000", "--vow=0",
                 "--stage=tier1-f0-controls", f"--out={out_dir / 'tier1-prior.json'}"])
    if prior.returncode == 0:
        raise RuntimeError("Tier-1 F0 overlapping the #454 F0 band must fail closed")
    sealed = run([godot, "--headless", "-s", "res://tools/balance_sim.gd", "--",
                  "--aspect=duskblade", "--runs=1", "--seed0=8000", "--vow=0",
                  "--stage=audit", f"--out={out_dir / 'audit.json'}"])
    if sealed.returncode == 0:
        raise RuntimeError("audit stage must stay sealed until finalist")
    tier1_sealed = run([godot, "--headless", "-s", "res://tools/balance_sim.gd", "--",
                        "--aspect=duskblade", "--runs=1", "--seed0=11000", "--vow=0",
                        "--stage=tier1-audit", f"--out={out_dir / 'tier1-audit.json'}"])
    if tier1_sealed.returncode == 0:
        raise RuntimeError("Tier-1 audit stage must stay sealed until a Tier-1 finalist")
    tier2_overlap = run([godot, "--headless", "-s", "res://tools/balance_sim.gd", "--",
                         "--aspect=duskblade", "--runs=1", "--seed0=5000", "--vow=0",
                         "--stage=tier2-f0-controls", f"--out={out_dir / 'tier2-overlap.json'}"])
    if tier2_overlap.returncode == 0:
        raise RuntimeError("Tier-2 F0 overlapping acceptance seeds must fail closed")
    unused = run([godot, "--headless", "-s", "res://tools/balance_sim.gd", "--",
                  "--aspect=duskblade", "--runs=1", "--seed0=13400", "--vow=0",
                  "--stage=tier2-f0-controls", f"--out={out_dir / 'tier2-unused.json'}"])
    if unused.returncode == 0:
        raise RuntimeError("Tier-2 F0 overlapping unused 13400–13999 must fail closed")
    tier2_sealed = run([godot, "--headless", "-s", "res://tools/balance_sim.gd", "--",
                        "--aspect=duskblade", "--runs=1", "--seed0=14000", "--vow=0",
                        "--stage=tier2-audit", f"--out={out_dir / 'tier2-audit.json'}"])
    if tier2_sealed.returncode == 0:
        raise RuntimeError("Tier-2 audit stage must stay sealed until a Tier-2 finalist")
    missing_mobs = out_dir / "missing-mobs.json"
    missing_mobs_proc = run([godot, "--headless", "-s", "res://tools/balance_sim.gd", "--",
                             "--mobs=/no/such/glassvow-mobs.json", "--aspect=duskblade",
                             "--runs=1", "--seed0=12000", "--vow=0", f"--stage={FINGERPRINT_STAGE}",
                             f"--out={missing_mobs}"])
    if missing_mobs_proc.returncode == 0:
        raise RuntimeError("missing --mobs must fail closed")
    if missing_mobs.exists() and missing_mobs.stat().st_size:
        blob = json.loads(missing_mobs.read_text(encoding="utf-8"))
        if isinstance(blob, dict) and blob.get("runs"):
            raise RuntimeError("missing --mobs emitted simulation rows")
    malformed = out_dir / "malformed-mobs.json"
    malformed.write_text("not-json\n", encoding="utf-8")
    malformed_out = out_dir / "malformed-out.json"
    malformed_proc = run([godot, "--headless", "-s", "res://tools/balance_sim.gd", "--",
                          f"--mobs={malformed}", "--aspect=duskblade", "--runs=1",
                          "--seed0=12000", "--vow=0", f"--stage={FINGERPRINT_STAGE}",
                          f"--out={malformed_out}"])
    if malformed_proc.returncode == 0:
        raise RuntimeError("malformed --mobs must fail closed")
    incomplete = out_dir / "incomplete-mobs.json"
    _write_overlay(incomplete, {"sporeling": {"hp": [1, 1]}})
    incomplete_out = out_dir / "incomplete-out.json"
    incomplete_proc = run([godot, "--headless", "-s", "res://tools/balance_sim.gd", "--",
                           f"--mobs={incomplete}", "--aspect=duskblade", "--runs=1",
                           "--seed0=12000", "--vow=0", f"--stage={FINGERPRINT_STAGE}",
                           f"--out={incomplete_out}"])
    if incomplete_proc.returncode == 0:
        raise RuntimeError("incomplete --mobs must fail closed")
    unknown = out_dir / "unknown-mobs.json"
    _write_overlay(unknown, {"notAMob": _enemy_overlay("sporeling", [1, 1])["sporeling"]})
    unknown_out = out_dir / "unknown-out.json"
    unknown_proc = run([godot, "--headless", "-s", "res://tools/balance_sim.gd", "--",
                        f"--mobs={unknown}", "--aspect=duskblade", "--runs=1",
                        "--seed0=12000", "--vow=0", f"--stage={FINGERPRINT_STAGE}",
                        f"--out={unknown_out}"])
    if unknown_proc.returncode == 0:
        raise RuntimeError("unknown --mobs id must fail closed")


def self_test(godot: str) -> int:
    load_contract()
    assert len(fingerprint_shards(4)) == 4
    assert len(fingerprint_shards(8)) == 8
    assert sum(shard["runs"] for shard in fingerprint_shards(6)) == 256
    if shutil.which(godot) is None and not Path(godot).is_file():
        raise ValueError(f"{godot} is required for host-qualify self-test")
    require_godot(godot)
    contract = load_contract()
    assert contract["stages"][FINGERPRINT_STAGE]["seeds"]["first"] == FINGERPRINT[0]
    assert contract["stages"][FINGERPRINT_STAGE]["seeds"]["last"] == FINGERPRINT[1]
    with tempfile.TemporaryDirectory(prefix="glassvow-501-") as temp:
        root = Path(temp)
        fail_closed_cli(godot, root)
        prove_concurrent(godot, root / "concurrent")
        prove_mobs(godot, root / "mobs")
    print("balance host qualify self-test OK")
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--digest", action="store_true")
    parser.add_argument("--fingerprint", action="store_true")
    parser.add_argument("--bench", action="store_true")
    parser.add_argument("--jobs", default="4", help="worker count, or comma list for --bench")
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--content", default="")
    parser.add_argument("--out", default="/tmp/glassvow-501-host")
    parser.add_argument("--compare", type=Path, help="canonical host packet to grade against")
    parser.add_argument("--mint", action="store_true",
                        help="write a packet without grading against the in-repo canonical")
    return parser.parse_args()


def _canonical_packet() -> dict[str, Any] | None:
    path = REPO / CANONICAL_REL
    if not path.is_file():
        return None
    blob = json.loads(path.read_text(encoding="utf-8"))
    return blob if isinstance(blob, dict) else None


def grade_against_canonical(packet: dict[str, Any], canonical_path: Path) -> None:
    canonical = json.loads(canonical_path.read_text(encoding="utf-8"))
    faults = compare_packets(canonical, packet)
    packet["canonical"] = str(canonical_path)
    packet["qualified"] = bool(packet.get("qualified")) and not faults
    packet["parityFaults"] = faults
    if faults:
        packet["reason"] = "; ".join(faults)


def main() -> int:
    args = parse_args()
    if args.self_test:
        return self_test(args.godot)
    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    job_list = [int(part) for part in str(args.jobs).split(",") if part]
    compare_path = args.compare
    if compare_path is None and not args.mint:
        default_canonical = REPO / CANONICAL_REL
        if default_canonical.is_file():
            compare_path = default_canonical
    if args.bench:
        results = []
        hashes: set[str] = set()
        canonical = None if args.mint else _canonical_packet()
        packet: dict[str, Any] = {}
        identity_faults: list[str] = []
        for jobs in job_list:
            packet = build_packet(args.godot, out_dir / f"bench-{jobs}", jobs, args.content)
            if compare_path is not None:
                grade_against_canonical(packet, compare_path)
                identity_faults.extend(str(fault) for fault in packet.get("parityFaults") or [])
            write_packet(out_dir / f"bench-{jobs}.json", packet)
            results.append({
                "workers": jobs,
                "rowsPerSecond": packet["fingerprint"]["rowsPerSecond"],
                "wallSeconds": packet["fingerprint"]["wallSeconds"],
                "fingerprintHash": packet["fingerprint"]["fingerprintHash"],
                "qualified": packet["qualified"],
            })
            hashes.add(packet["fingerprint"]["fingerprintHash"])
        if canonical and packet.get("contentFileSha256") == canonical.get("contentFileSha256"):
            hashes.add(str(canonical.get("fingerprint", {}).get("fingerprintHash", "")))
        chosen = max(results, key=lambda row: (row["qualified"], row["rowsPerSecond"]))
        summary = {
            "issue": ISSUE,
            "drift": len(hashes) != 1,
            "identityFaults": identity_faults,
            "chosenWorkers": None if len(hashes) != 1 else chosen["workers"],
            "runs": results,
        }
        write_packet(out_dir / "bench-summary.json", summary)
        print(json.dumps(summary, indent=2, sort_keys=True))
        return 0 if not summary["drift"] and not identity_faults else 2
    packet = build_packet(args.godot, out_dir, job_list[0], args.content)
    if compare_path is not None:
        grade_against_canonical(packet, compare_path)
    elif not args.mint:
        packet["qualified"] = False
        packet["reason"] = f"run with --compare {CANONICAL_REL}"
    write_packet(out_dir / "host.json", packet)
    print(json.dumps({
        "qualified": packet["qualified"],
        "fingerprintHash": packet["fingerprint"]["fingerprintHash"],
        "rowsPerSecond": packet["fingerprint"]["rowsPerSecond"],
        "host": packet["host"],
        "reason": packet.get("reason", ""),
    }, indent=2, sort_keys=True))
    return 0 if packet["qualified"] else 2


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (KeyError, OSError, TypeError, ValueError, RuntimeError) as exc:
        print(f"balance_host_qualify: {exc}", file=sys.stderr)
        raise SystemExit(2) from exc
