#!/usr/bin/env python3
"""Copy a Studio GLB onto a map-kit path, write provenance, run existing gates.

Does not generate. Does not call the Tripo API. Does not implement a new
silhouette harness — it calls tools/check_map_assets.py and
tools/raster_map_silhouette.gd.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
from datetime import datetime, timezone, timedelta
from pathlib import Path
from typing import Any

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / "tools"))
from map_asset_checks import inspect_glb  # noqa: E402

HKT = timezone(timedelta(hours=8))


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    digest.update(path.read_bytes())
    return digest.hexdigest()


def load_json(path: Path) -> Any:
    return json.loads(path.read_text())


def dump_json(path: Path, data: Any) -> None:
    path.write_text(json.dumps(data, indent=2) + "\n")


def manifest_row(asset_id: str) -> dict[str, Any]:
    data = load_json(REPO / "assets/art/map/map-assets.json")
    for row in data["assets"]:
        if row["id"] == asset_id:
            return row
    raise SystemExit(f"asset_id {asset_id} not in map-assets.json")


def run(cmd: list[str], timeout: int = 300) -> str:
    proc = subprocess.run(
        cmd, cwd=str(REPO), capture_output=True, text=True, timeout=timeout, check=False,
    )
    if proc.returncode != 0:
        tail = (proc.stderr or proc.stdout or "").strip()[-1200:]
        raise RuntimeError(f"{' '.join(cmd[:4])} rc={proc.returncode}: {tail}")
    return (proc.stdout or "") + (proc.stderr or "")


def append_provenance(
    asset_id: str,
    dest: Path,
    src: Path,
    concept: Path,
    task_id: str,
    extras: dict[str, Any],
) -> None:
    path = REPO / "assets/art/map/provenance.json"
    data = load_json(path)
    paid = data.get("paid_product") or {}
    if paid.get("product") != "Studio" or paid.get("api_forbidden") is not True:
        raise RuntimeError("paid_product is not Studio with api_forbidden true")
    source_sha = sha256(src)
    final_sha = sha256(dest)
    concept_sha = sha256(concept) if concept.is_file() else ""
    record = {
        "asset_id": asset_id,
        "source": "Studio",
        "created_at": datetime.now(HKT).isoformat(timespec="seconds"),
        "license": "Tripo Studio Pro commercial grant (paid product Studio, not API)",
        "source_sha256": source_sha,
        "final_sha256": final_sha,
        "edits": extras.get("edits") or [
            "land_map_glb.py copy; Studio Export GLB kept if it already meets the ordinary contract",
        ],
        "reviewer": "fol2",
        "verdict": "accepted",
        "task_id": task_id,
        "face_limit": 1500,
        "texture": False,
        "pbr": False,
        "concept_path": str(concept.relative_to(REPO)) if concept.is_file() and concept.is_relative_to(REPO)
        else str(concept),
        "concept_sha256": concept_sha,
        "land_method": extras.get("land_method") or "studio_download",
        "polycount_target": 1500,
    }
    if extras.get("faces_reported") is not None:
        record["faces_reported"] = extras["faces_reported"]
    records = [row for row in data.get("records") or [] if row.get("asset_id") != asset_id]
    records.append(record)
    data["records"] = records
    dump_json(path, data)


def review_png(dest: Path, asset_id: str) -> Path:
    png = REPO / "docs/reviews/292" / f"{asset_id}-20.png"
    png.parent.mkdir(parents=True, exist_ok=True)
    rel = dest.resolve().relative_to(REPO)
    cmd = [
        os.environ.get("GODOT", "godot"),
        "--path", str(REPO),
        "--position", os.environ.get("GLASSVOW_SHOT_POSITION", "-4000,-4000"),
        "-s", "res://tools/raster_map_silhouette.gd", "--",
        f"--glb=res://{rel.as_posix()}",
        "--out=/tmp/map-sil-review",
        f"--review=res://docs/reviews/292/{asset_id}-20.png",
    ]
    run(cmd, timeout=120)
    if not png.is_file():
        raise RuntimeError(f"20-placement PNG missing: {png}")
    return png


def gates() -> str:
    chunks: list[str] = []
    chunks.append(run(["bash", "tools/check_imports.sh"], timeout=180))
    chunks.append(run(["bash", "tools/check_scripts.sh"], timeout=180))
    suite = run(
        [os.environ.get("GODOT", "godot"), "--headless", "-s", "res://tests/run_all.gd"],
        timeout=180,
    )
    if "PASS" not in suite:
        raise RuntimeError("test suite did not print PASS")
    chunks.append(suite)
    chunks.append(run([sys.executable, "tools/check_map_assets.py"], timeout=180))
    chunks.append(run([sys.executable, "tools/check_anchors.py"], timeout=60))
    chunks.append(run([sys.executable, "tools/check_benchmark_freeze.py"], timeout=60))
    return "\n".join(chunks)


def main() -> int:
    parser = argparse.ArgumentParser(description="Land a Studio GLB onto a map kit path")
    parser.add_argument("--asset", required=True)
    parser.add_argument("--src", required=True, type=Path)
    parser.add_argument("--concept", type=Path)
    parser.add_argument("--task-id", default="")
    parser.add_argument("--land-method", default="studio_download")
    parser.add_argument(
        "--edit",
        action="append",
        default=[],
        help="provenance edits[] row; repeatable. Default is an unmodified Studio Export copy.",
    )
    parser.add_argument("--gates", action="store_true")
    parser.add_argument("--no-review", action="store_true")
    args = parser.parse_args()
    os.chdir(REPO)
    row = manifest_row(args.asset)
    src = args.src if args.src.is_absolute() else Path(args.src)
    if not src.is_file():
        print(json.dumps({"ok": False, "summary": f"source GLB missing: {src}"}))
        return 2
    dest = REPO / "assets/art/map" / row["path"]
    concept = args.concept
    if concept is None:
        concept = REPO / "assets/art/map-concepts" / f"{args.asset}.jpg"
    elif not concept.is_absolute():
        concept = REPO / concept
    findings = inspect_glb(src, str(src), row)
    if findings:
        print(json.dumps({
            "ok": False,
            "summary": "; ".join(str(item) for item in findings),
        }))
        return 2
    dest.parent.mkdir(parents=True, exist_ok=True)
    if src.resolve() != dest.resolve():
        shutil.copy2(src, dest)
    append_provenance(
        args.asset, dest, src, concept, args.task_id,
        {"land_method": args.land_method, "edits": args.edit or [
            "land_map_glb.py copy of Studio Export GLB; no blender pass",
        ]},
    )
    review = None if args.no_review else str(review_png(dest, args.asset).relative_to(REPO))
    gate_out = ""
    if args.gates:
        gate_out = gates()
    print(json.dumps({
        "ok": True,
        "summary": f"landed {dest.relative_to(REPO)}" + ("; gates ran" if args.gates else ""),
        "glb_path": str(dest.relative_to(REPO)),
        "dest_path": str(dest.relative_to(REPO)),
        "land_method": args.land_method,
        "task_id": args.task_id,
        "review_path": review,
        "gate_tail": gate_out[-400:] if gate_out else "",
    }))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
