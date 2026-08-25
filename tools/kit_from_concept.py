#!/usr/bin/env python3
"""One-shot map kit: concept image → Studio HD GLB → land at the manifest path.

No Tripo API. No per-mesh LLM. Generate spends Studio credits; --dry-run does not.

    python3 tools/kit_from_concept.py --asset act3-broken-halo
    python3 tools/kit_from_concept.py --asset act3-broken-halo --dry-run
    python3 tools/kit_from_concept.py --remaining
"""
from __future__ import annotations

import argparse
import json
import os
import struct
import subprocess
import sys
from pathlib import Path
from typing import Any

FILE_REPO = Path(__file__).resolve().parent.parent
REPO = FILE_REPO

CONCEPT_ALIASES = {
    "act1-vigil": "act1-vigil-hall.png",
    "act2-terminus": "act2-terminus-flooded-threshold.png",
    "act4-terminus": "act4-terminus-rose-threshold.png",
}


def load_row(asset_id: str) -> dict[str, Any]:
    data = json.loads((REPO / "assets/art/map/map-assets.json").read_text())
    for row in data["assets"]:
        if row["id"] == asset_id:
            return row
    raise SystemExit(f"asset_id {asset_id} not in map-assets.json")


def dest_path(row: dict[str, Any]) -> Path:
    return REPO / "assets/art/map" / row["path"]


def glb_has_embedded_image(path: Path) -> bool:
    if not path.is_file():
        return False
    data = path.read_bytes()
    if len(data) < 20 or data[:4] != b"glTF":
        return False
    json_len = struct.unpack_from("<I", data, 12)[0]
    gltf = json.loads(data[20:20 + json_len])
    return bool(gltf.get("images"))


def remaining_untextured() -> list[str]:
    data = json.loads((REPO / "assets/art/map/map-assets.json").read_text())
    ids: list[str] = []
    for row in data["assets"]:
        if row["kind"] not in {"kit", "terminus", "threshold"}:
            continue
        if not glb_has_embedded_image(dest_path(row)):
            ids.append(row["id"])
    return ids


def find_concept(asset_id: str, explicit: Path | None) -> Path:
    if explicit is not None:
        path = explicit if explicit.is_absolute() else REPO / explicit
        if not path.is_file():
            raise SystemExit(f"concept missing: {path}")
        return path
    alias = CONCEPT_ALIASES.get(asset_id)
    if alias:
        path = REPO / "assets/art/map-concepts" / alias
        if path.is_file():
            return path
    for ext in (".jpg", ".png"):
        path = REPO / "assets/art/map-concepts" / f"{asset_id}{ext}"
        if path.is_file():
            return path
    raise SystemExit(f"no concept for {asset_id} under assets/art/map-concepts/")


def studio_argv(row: dict[str, Any]) -> list[str]:
    hero = row.get("kind") in {"terminus", "threshold"} or row.get("role") == "hero"
    argv = [
        "--textured", "--privacy", "private", "--topology", "triangle", "--pbr", "off",
    ]
    if hero:
        # Vigil-class: Ultra on, 2K generate. Ordinary kits skip Ultra —
        # measured 2026-08-25 HD+Ultra generate_ms 97–146s vs historic Smart
        # Mesh ~15s. Texture still requires HD; Ultra is the extra wait.
        argv += ["--faces", "6000", "--texture-quality", "2k", "--ultra-mesh", "on"]
    else:
        argv += ["--faces", "1500", "--texture-quality", "1k", "--ultra-mesh", "off"]
    return argv


def run(cmd: list[str], timeout: int) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd, cwd=str(REPO), capture_output=True, text=True, timeout=timeout, check=False,
    )


def last_json_line(text: str) -> dict[str, Any]:
    for line in reversed((text or "").splitlines()):
        line = line.strip()
        if line.startswith("{") and line.endswith("}"):
            return json.loads(line)
    raise ValueError("no JSON object in command output")


def self_test() -> int:
    kit = studio_argv({"kind": "kit", "role": "ordinary"})
    hero = studio_argv({"kind": "terminus", "role": "hero"})
    gate = studio_argv({"kind": "threshold", "role": "hero"})
    assert "--texture-quality" in kit and kit[kit.index("--texture-quality") + 1] == "1k"
    assert kit[kit.index("--faces") + 1] == "1500"
    assert kit[kit.index("--ultra-mesh") + 1] == "off"
    assert hero[hero.index("--texture-quality") + 1] == "2k"
    assert hero[hero.index("--faces") + 1] == "6000"
    assert hero[hero.index("--ultra-mesh") + 1] == "on"
    assert gate[gate.index("--texture-quality") + 1] == "2k"
    vigil = dest_path(load_row("act1-vigil"))
    assert glb_has_embedded_image(vigil)
    assert "act1-vigil" not in remaining_untextured()
    print("self-test kit_from_concept: ordinary 1k/1500/ultra-off, hero 2k/6000/ultra-on")
    return 0


def main(argv: list[str] | None = None) -> int:
    if argv is None and "--self-test" in sys.argv:
        return self_test()
    parser = argparse.ArgumentParser(description="Concept → Studio HD → land one map kit GLB")
    parser.add_argument("--asset")
    parser.add_argument("--remaining", action="store_true",
                        help="land every kit/terminus/threshold whose dest GLB has no embedded image")
    parser.add_argument("--image", type=Path)
    parser.add_argument("--out", type=Path)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--no-review", action="store_true")
    parser.add_argument("--timeout", type=int, default=900)
    args = parser.parse_args(argv)
    os.chdir(REPO)
    if bool(args.asset) == bool(args.remaining):
        raise SystemExit("pass --asset ID or --remaining")
    if args.remaining:
        ids = remaining_untextured()
        landed: list[str] = []
        for asset_id in ids:
            one = ["--asset", asset_id, "--timeout", str(args.timeout)]
            if args.dry_run:
                one.append("--dry-run")
            if args.no_review:
                one.append("--no-review")
            rc = main(one)
            if rc != 0:
                print(json.dumps({
                    "ok": False,
                    "summary": f"--remaining stopped at {asset_id} rc={rc}",
                    "landed": landed,
                    "remaining": remaining_untextured(),
                }))
                return rc
            landed.append(asset_id)
        print(json.dumps({
            "ok": True,
            "summary": f"remaining: landed {len(landed)}",
            "landed": landed,
            "remaining": remaining_untextured(),
        }))
        return 0
    row = load_row(args.asset)
    concept = find_concept(args.asset, args.image)
    tmp = args.out if args.out else Path(f"/tmp/glassvow-studio-{args.asset}.glb")
    flags = studio_argv(row)
    studio_cmd = [
        "bun", "tools/studio_image_to_glb.ts",
        "--image", str(concept), "--out", str(tmp), *flags,
    ]
    if args.dry_run:
        studio_cmd.append("--dry-run")
    print(json.dumps({"phase": "studio", "cmd": studio_cmd}), file=sys.stderr)
    studio = run(studio_cmd, timeout=args.timeout)
    try:
        studio_json = last_json_line(studio.stdout or studio.stderr)
    except ValueError:
        print(json.dumps({
            "ok": False,
            "summary": f"studio produced no JSON rc={studio.returncode}: {(studio.stderr or studio.stdout or '')[-800:]}",
        }))
        return 2
    if studio.returncode != 0 or studio_json.get("ok") is not True:
        print(json.dumps({
            "ok": False,
            "summary": studio_json.get("summary") or f"studio rc={studio.returncode}",
            "studio": studio_json,
        }))
        return 2
    if args.dry_run:
        print(json.dumps({
            "ok": True,
            "summary": "dry-run: Generate not clicked",
            "asset_id": args.asset,
            "concept": str(concept.relative_to(REPO)),
            "studio": studio_json,
            "would_spend_credits": False,
        }))
        return 0
    if not tmp.is_file():
        print(json.dumps({"ok": False, "summary": f"studio ok but missing {tmp}"}))
        return 2
    land_cmd = [
        sys.executable, "tools/land_map_glb.py",
        "--asset", args.asset, "--src", str(tmp), "--concept", str(concept),
    ]
    if studio_json.get("task_id"):
        land_cmd += ["--task-id", str(studio_json["task_id"])]
    if args.no_review:
        land_cmd.append("--no-review")
    print(json.dumps({"phase": "land", "cmd": land_cmd}), file=sys.stderr)
    land = run(land_cmd, timeout=180)
    try:
        land_json = last_json_line(land.stdout or land.stderr)
    except ValueError:
        print(json.dumps({
            "ok": False,
            "summary": f"land produced no JSON rc={land.returncode}: {(land.stderr or land.stdout or '')[-800:]}",
            "studio": studio_json,
        }))
        return 2
    if land.returncode != 0 or land_json.get("ok") is not True:
        print(json.dumps({
            "ok": False,
            "summary": land_json.get("summary") or f"land rc={land.returncode}",
            "studio": studio_json,
            "land": land_json,
        }))
        return 2
    print(json.dumps({
        "ok": True,
        "summary": land_json.get("summary"),
        "asset_id": args.asset,
        "concept": str(concept.relative_to(REPO)),
        "glb_path": land_json.get("glb_path"),
        "task_id": studio_json.get("task_id") or land_json.get("task_id"),
        "studio": studio_json,
        "land": land_json,
    }))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
