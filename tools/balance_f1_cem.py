#!/usr/bin/env python3
"""Run the bounded #458 development mini-CEM with replayable manifests."""
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Any

from balance_f0 import REPO, git_head, host_identity, qualified_packet, require_godot
from balance_seed_contract import (
    CONTRACT_REL,
    MOBS_REL,
    check_invocation,
    driver_sha256,
    file_sha256,
    load_contract,
    resolve_mobs_path,
)

TOOL_ID = "glassvow-balance-f1-cem-v1"
MARKER = ".glassvow-balance-f1-cem"
GRIDS = ("duskblade:v0", "duskblade:v5", "ashwarden:v0", "ashwarden:v5")


def _read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"expected JSON object: {path}")
    return value


def _prepare_out(path: Path, fresh: bool) -> None:
    marker = path / MARKER
    if path.is_symlink():
        raise ValueError(f"refusing output symlink: {path}")
    if path.exists():
        if not path.is_dir() or marker.is_symlink() or not marker.is_file() \
                or marker.read_text(encoding="utf-8") != f"{TOOL_ID}\n":
            raise ValueError(f"refusing unmarked output directory: {path}")
        if fresh:
            shutil.rmtree(path)
        else:
            return
    path.mkdir(parents=True)
    (path / MARKER).write_text(f"{TOOL_ID}\n", encoding="utf-8")


def cem_spec(protocol: dict[str, Any], contract: dict[str, Any]) -> dict[str, int]:
    raw = protocol["miniCem"]
    spec = {key: int(raw[key]) for key in (
        "policyRoot", "root", "islands", "popSize", "elite", "maxGen", "seedCount",
        "trainSeed0", "holdoutSeed0", "holdoutCount",
    )}
    if spec["islands"] != 24:
        raise ValueError("mini-CEM must keep exactly 24 islands (six per grid)")
    if spec["policyRoot"] != int(contract["development"]["f1PolicyRoot"]):
        raise ValueError("mini-CEM policy root drifted from the development contract")
    if spec["root"] != int(contract["development"]["miniCemRoot"]):
        raise ValueError("mini-CEM sampler root drifted from the development contract")
    train_last = spec["trainSeed0"] + spec["maxGen"] * spec["seedCount"] - 1
    holdout_last = spec["holdoutSeed0"] + spec["holdoutCount"] - 1
    error = check_invocation(
        contract, "f1-mini-cem", spec["trainSeed0"], train_last, spec["root"],
        spec["holdoutSeed0"], holdout_last,
    )
    if error:
        raise ValueError(error)
    return spec


def _seed_packet(path: Path) -> dict[str, Any]:
    packet = _read_json(path)
    for grid in GRIDS:
        rows = packet.get(grid)
        if not isinstance(rows, list) or len(rows) != 6:
            raise ValueError(f"{path} must contain six starts for {grid}")
        for row in rows:
            if not isinstance(row, dict) or "cell" not in row or "policyIndex" not in row:
                raise ValueError(f"malformed mini-CEM start in {path} / {grid}")
    return packet


def cem_output_complete(path: Path, candidate_sha: str, seed_packet_sha: str,
                        spec: dict[str, int], island: int, mobs_sha: str = "") -> bool:
    if not path.is_file():
        return False
    manifest: dict[str, Any] | None = None
    final: dict[str, Any] | None = None
    holdout = 0
    try:
        with path.open(encoding="utf-8") as handle:
            for line in handle:
                row = json.loads(line)
                if row.get("t") == "manifest":
                    manifest = row
                elif row.get("t") == "holdout":
                    holdout += 1
                elif row.get("t") == "final":
                    final = row
    except (OSError, json.JSONDecodeError):
        return False
    if manifest is None or final is None or holdout != spec["holdoutCount"]:
        return False
    expected = {
        "island": island, "popSize": spec["popSize"], "elite": spec["elite"],
        "maxGen": spec["maxGen"], "seedCount": spec["seedCount"],
        "trainSeed0": spec["trainSeed0"], "holdoutSeed0": spec["holdoutSeed0"],
        "holdoutCount": spec["holdoutCount"], "rootSeed": spec["root"],
        "samplerRoot": spec["policyRoot"],
    }
    return str(manifest.get("contentFileSha256")) == candidate_sha \
        and (not mobs_sha or str(manifest.get("mobOverrideFileSha256", "")) == mobs_sha) \
        and str(manifest.get("seedPacketSha256")) == seed_packet_sha \
        and str(manifest.get("stage")) == "f1-mini-cem" \
        and all(int(manifest.get(key, -1)) == value for key, value in expected.items()) \
        and int(final.get("island", -1)) == island \
        and int(final.get("holdoutRuns", -1)) == spec["holdoutCount"]


def _command(godot: str, content: Path, seeds: Path, out: Path,
             seed_packet_sha: str, spec: dict[str, int], island: int,
             mobs: Path) -> list[str]:
    return [
        godot, "--headless", "-s", "res://tools/balance_cem.gd", "--",
        f"--island={island}", f"--seedsJson={seeds}", f"--out={out}",
        f"--popSize={spec['popSize']}", f"--elite={spec['elite']}",
        f"--maxGen={spec['maxGen']}", f"--seedCount={spec['seedCount']}",
        f"--trainSeed0={spec['trainSeed0']}", f"--holdoutSeed0={spec['holdoutSeed0']}",
        f"--holdoutCount={spec['holdoutCount']}", f"--rootSeed={spec['root']}",
        f"--samplerRoot={spec['policyRoot']}", "--stage=f1-mini-cem",
        f"--seedPacketSha256={seed_packet_sha}",
        f"--content={content}", f"--mobs={mobs}",
    ]


def run(godot: str, jobs: int, bundle_dir: Path, seeds_dir: Path, out: Path,
        candidate_ids: list[str], protocol_path: Path, fresh: bool) -> dict[str, Any]:
    protocol = _read_json(protocol_path)
    contract = load_contract()
    spec = cem_spec(protocol, contract)
    bundle = _read_json(bundle_dir / "manifest.json")
    by_id = {str(row["id"]): row for row in bundle["candidates"]}
    if not candidate_ids or candidate_ids[0] != "c000" or len(candidate_ids) != len(set(candidate_ids)):
        raise ValueError("--candidates must be unique and begin with c000")
    for candidate_id in candidate_ids:
        if candidate_id not in by_id:
            raise ValueError(f"candidate {candidate_id} is absent from the bundle")
        _seed_packet(seeds_dir / f"{candidate_id}-seeds.json")
    _prepare_out(out, fresh)
    godot_version = require_godot(godot)
    host = host_identity(jobs)
    packet = qualified_packet(host, godot_version)
    live_mobs = REPO / MOBS_REL
    live_mobs_sha = file_sha256(live_mobs)

    tasks: list[tuple[str, int]] = [
        (candidate_id, island) for candidate_id in candidate_ids for island in range(spec["islands"])
    ]

    def worker(task: tuple[str, int]) -> tuple[str, int, str]:
        candidate_id, island = task
        candidate = by_id[candidate_id]
        content = bundle_dir / candidate_id / "full-content.json"
        mobs = resolve_mobs_path(candidate, bundle_dir)
        mobs_sha = file_sha256(mobs)
        seed_packet = seeds_dir / f"{candidate_id}-seeds.json"
        seed_packet_sha = file_sha256(seed_packet)
        if file_sha256(content) != str(candidate["fileSha256"]):
            raise ValueError(f"candidate {candidate_id} content SHA drifted")
        destination = out / candidate_id / f"island-{island:02d}.ndjson"
        destination.parent.mkdir(parents=True, exist_ok=True)
        if cem_output_complete(destination, str(candidate["fileSha256"]),
                               seed_packet_sha, spec, island, mobs_sha):
            return candidate_id, island, file_sha256(destination)
        temporary = Path(str(destination) + ".tmp")
        temporary.unlink(missing_ok=True)
        command = _command(godot, content, seed_packet, temporary,
                           seed_packet_sha, spec, island, mobs)
        log = destination.with_suffix(".log")
        with log.open("w", encoding="utf-8") as handle:
            handle.write(" ".join(command) + "\n")
            process = subprocess.run(command, cwd=REPO, stdout=handle,
                                     stderr=subprocess.STDOUT, check=False)
        if process.returncode != 0 or not cem_output_complete(
                temporary, str(candidate["fileSha256"]), seed_packet_sha, spec, island, mobs_sha):
            raise RuntimeError(f"mini-CEM failed for {candidate_id} island {island}; see {log}")
        temporary.replace(destination)
        return candidate_id, island, file_sha256(destination)

    raw: dict[str, dict[str, str]] = {candidate_id: {} for candidate_id in candidate_ids}
    with ThreadPoolExecutor(max_workers=max(1, min(jobs, len(tasks)))) as pool:
        for candidate_id, island, digest in pool.map(worker, tasks):
            raw[candidate_id][f"island-{island:02d}.ndjson"] = digest
            print(f"{candidate_id} island {island:02d} complete", flush=True)
    if file_sha256(live_mobs) != live_mobs_sha:
        raise RuntimeError("live content/mob-overrides.json changed during mini-CEM")
    manifest = {
        "tool": TOOL_ID, "issue": 458, "commit": git_head(),
        "godotVersion": godot_version, "host": host,
        "hostFingerprint": packet["fingerprint"]["fingerprintHash"],
        "candidateIds": candidate_ids, "spec": spec,
        "inputs": {
            "protocolSha256": file_sha256(protocol_path),
            "seedRegistrySha256": file_sha256(REPO / CONTRACT_REL),
            "bundleManifestSha256": file_sha256(bundle_dir / "manifest.json"),
            "driverSha256": driver_sha256(),
            "runnerSha256": file_sha256(Path(__file__)),
            "seedPacketSha256ByCandidate": {
                candidate_id: file_sha256(seeds_dir / f"{candidate_id}-seeds.json")
                for candidate_id in candidate_ids
            },
        },
        "rawSha256ByCandidate": raw,
    }
    (out / "manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return manifest


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--jobs", type=int, default=8)
    parser.add_argument("--protocol", default="docs/balance/458-f1-f2-protocol-v1.json")
    parser.add_argument("--bundle", required=True)
    parser.add_argument("--seeds-dir", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--candidates", required=True)
    parser.add_argument("--fresh", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    manifest = run(
        args.godot, args.jobs, Path(args.bundle), Path(args.seeds_dir), Path(args.out),
        args.candidates.split(","), Path(args.protocol), args.fresh,
    )
    print(json.dumps({"candidates": manifest["candidateIds"],
                      "islands": sum(len(rows) for rows in manifest["rawSha256ByCandidate"].values()),
                      "out": args.out}, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (KeyError, OSError, TypeError, ValueError, RuntimeError) as exc:
        print(f"balance_f1_cem: {exc}", file=sys.stderr)
        raise SystemExit(2) from exc
