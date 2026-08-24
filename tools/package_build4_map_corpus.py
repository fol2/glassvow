#!/usr/bin/env python3
"""Validate, index, and contact-sheet the #462 build-4 map corpus.

The Godot driver owns the production capture. This script is deliberately a
post-processor: it never changes a frame, except to make labelled thumbnails.
The canonical manifest excludes PNG hashes so two renders can prove the matrix
and dimensions stable even when renderer/font rasterisation differs by pixels.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any, Iterable

from PIL import Image, ImageDraw, ImageFont, ImageOps

EXPECTED_FRAMES = 168
EXPECTED_CLASSES = (
    "ROAD_SCENERY_INTERSECTION",
    "NODE_SCENERY_OCCLUSION",
    "NODE_NODE_COLLISION",
    "EDGE_CROSSING_OR_MERGE_AMBIGUITY",
    "ROUTE_STATE_TOO_FAINT",
    "OVERLAY_DEPTH_VIOLATION",
    "HERO_LANDMARK_FRAMING",
    "DENSITY_OR_NEGATIVE_SPACE",
    "REPETITION_OR_STAMPING",
)
SHAPE_ORDER = ("pad-landscape", "desktop-landscape", "phone-landscape")
POSE_ORDER = ("opening", "focused")
ZOOM_ORDER = (0, 1, 2, 3)


def canonical_json(value: Any) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + "\n").encode("utf-8")


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()



def load_font(size: int) -> ImageFont.ImageFont:
    candidates = (
        Path("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"),
        Path("/usr/share/fonts/dejavu/DejaVuSans.ttf"),
        Path("/System/Library/Fonts/Supplemental/Arial.ttf"),
        Path("/Library/Fonts/Arial.ttf"),
    )
    for candidate in candidates:
        if candidate.is_file():
            return ImageFont.truetype(str(candidate), size=size)
    return ImageFont.load_default()


def _frame_key(frame: dict[str, Any]) -> tuple[int, int, str, int, str]:
    return (
        int(frame["act"]),
        int(frame["seed"]),
        str(frame["shape"]),
        int(frame["zoom_stop"]),
        str(frame["pose"]),
    )


def validate_manifest(manifest: dict[str, Any]) -> list[dict[str, Any]]:
    if manifest.get("issue") != 462:
        raise ValueError("manifest is not bound to issue #462")
    if manifest.get("frame_count") != EXPECTED_FRAMES:
        raise ValueError(f"expected {EXPECTED_FRAMES} frames, got {manifest.get('frame_count')}")
    frames = manifest.get("frames")
    if not isinstance(frames, list) or len(frames) != EXPECTED_FRAMES:
        raise ValueError("frames list does not match the fixed 168-frame matrix")

    seen: set[tuple[int, int, str, int, str]] = set()
    expected_cases = {(act, seed) for act in (1, 2, 3) for seed in (717, 17634)} | {(4, 717)}
    for frame in frames:
        key = _frame_key(frame)
        if key in seen:
            raise ValueError(f"duplicate matrix cell: {key}")
        seen.add(key)
        act, seed, shape, zoom, pose = key
        if (act, seed) not in expected_cases:
            raise ValueError(f"unexpected act/seed cell: {(act, seed)}")
        if shape not in SHAPE_ORDER or zoom not in ZOOM_ORDER or pose not in POSE_ORDER:
            raise ValueError(f"unexpected shape/zoom/pose cell: {key}")
        filename = Path(str(frame["file"])).name
        required_tokens = (
            f"act-{act:02d}",
            f"seed-{seed:08d}",
            f"shape-{shape}",
            f"zoom-{zoom:02d}-",
            f"pose-{pose}",
            f"locale-{frame['locale']}",
        )
        missing = [token for token in required_tokens if token not in filename]
        if missing:
            raise ValueError(f"{filename} is missing filename dimensions: {missing}")

    expected = {
        (act, seed, shape, zoom, pose)
        for act, seed in expected_cases
        for shape in SHAPE_ORDER
        for zoom in ZOOM_ORDER
        for pose in POSE_ORDER
    }
    if seen != expected:
        missing = sorted(expected - seen)
        extra = sorted(seen - expected)
        raise ValueError(f"matrix mismatch; missing={missing[:5]} extra={extra[:5]}")
    return frames


def package_run(run_dir: Path) -> None:
    manifest_path = run_dir / "manifest.json"
    manifest = read_json(manifest_path)
    frames = validate_manifest(manifest)

    dimensions: list[dict[str, Any]] = []
    pixel_hashes: list[dict[str, str]] = []
    for frame in frames:
        image_path = run_dir / str(frame["file"])
        if not image_path.is_file():
            raise FileNotFoundError(f"missing raw frame: {image_path}")
        with Image.open(image_path) as image:
            actual = image.size
        expected = (
            int(frame["viewport"]["width"]),
            int(frame["viewport"]["height"]),
        )
        if actual != expected:
            raise ValueError(f"dimension drift for {image_path.name}: expected {expected}, got {actual}")
        dimensions.append(
            {
                "frame_id": str(frame["frame_id"]),
                "file": str(frame["file"]),
                "width": actual[0],
                "height": actual[1],
            }
        )
        pixel_hashes.append(
            {
                "frame_id": str(frame["frame_id"]),
                "file": str(frame["file"]),
                "png_sha256": sha256(image_path),
            }
        )

    (run_dir / "dimensions.json").write_bytes(
        canonical_json(
            {
                "schema": 1,
                "issue": 462,
                "capture_head": manifest["capture_head"],
                "frame_count": len(dimensions),
                "frames": dimensions,
            }
        )
    )
    (run_dir / "pixel-hashes.json").write_bytes(
        canonical_json(
            {
                "schema": 1,
                "issue": 462,
                "capture_head": manifest["capture_head"],
                "diagnostic_only": True,
                "frames": pixel_hashes,
            }
        )
    )
    make_contact_sheets(run_dir, manifest, frames)


def make_contact_sheets(
    run_dir: Path, manifest: dict[str, Any], frames: list[dict[str, Any]]
) -> None:
    output = run_dir / "contact-sheets"
    if output.exists():
        shutil.rmtree(output)
    output.mkdir(parents=True)

    by_case: dict[tuple[int, int], list[dict[str, Any]]] = defaultdict(list)
    for frame in frames:
        by_case[(int(frame["act"]), int(frame["seed"]))].append(frame)

    font = load_font(11)
    header_font = load_font(13)
    left = 178
    cell_w = 282
    cell_h = 194
    top = 78
    image_box = (260, 152)
    sheet_index: list[dict[str, Any]] = []

    for act, seed in sorted(by_case):
        case_frames = by_case[(act, seed)]
        lookup = {
            (str(frame["shape"]), int(frame["zoom_stop"]), str(frame["pose"])): frame
            for frame in case_frames
        }
        rows = [(shape, pose) for shape in SHAPE_ORDER for pose in POSE_ORDER]
        canvas = Image.new("RGB", (left + cell_w * 4, top + cell_h * len(rows)), (18, 20, 27))
        draw = ImageDraw.Draw(canvas)
        draw.text(
            (14, 10),
            f"#462 | TestFlight 1.0.0 (4) | Act {act} | seed {seed:08d} | locale {manifest['locale']}",
            font=header_font,
            fill=(238, 239, 243),
        )
        draw.text(
            (14, 30),
            f"source {manifest['build4_source_commit'][:12]} | capture head {manifest['capture_head'][:12]} | Godot {manifest['godot']}",
            font=font,
            fill=(166, 173, 187),
        )
        draw.text(
            (14, 49),
            "Columns are production zoom stops; rows are shipping shape × canonical camera pose.",
            font=font,
            fill=(166, 173, 187),
        )

        for column, zoom in enumerate(ZOOM_ORDER):
            any_frame = lookup[(SHAPE_ORDER[0], zoom, POSE_ORDER[0])]
            label = f"zoom-{zoom:02d}  size {float(any_frame['zoom_size']):g}"
            x = left + column * cell_w + 8
            draw.text((x, 61), label, font=font, fill=(222, 225, 232))

        included: list[str] = []
        for row, (shape, pose) in enumerate(rows):
            y = top + row * cell_h
            draw.text((14, y + 8), shape, font=font, fill=(232, 233, 237))
            draw.text((14, y + 26), f"pose-{pose}", font=font, fill=(171, 178, 191))
            for column, zoom in enumerate(ZOOM_ORDER):
                frame = lookup[(shape, zoom, pose)]
                image_path = run_dir / str(frame["file"])
                with Image.open(image_path) as source:
                    thumb = ImageOps.contain(source.convert("RGB"), image_box, Image.Resampling.LANCZOS)
                cell_x = left + column * cell_w
                cell_y = y
                paste_x = cell_x + (cell_w - thumb.width) // 2
                paste_y = cell_y + 7
                canvas.paste(thumb, (paste_x, paste_y))
                draw.rectangle(
                    (paste_x - 1, paste_y - 1, paste_x + thumb.width, paste_y + thumb.height),
                    outline=(73, 78, 91),
                    width=1,
                )
                draw.text(
                    (cell_x + 8, cell_y + 164),
                    f"{frame['frame_id']} | {frame['viewport']['width']}x{frame['viewport']['height']} | cam {frame['camera_xz']['x']:.2f},{frame['camera_xz']['z']:.2f}",
                    font=font,
                    fill=(188, 194, 205),
                )
                included.append(str(frame["file"]))

        filename = (
            f"act-{act:02d}_seed-{seed:08d}_shape-all_zoom-all_"
            f"pose-all_locale-{manifest['locale']}_contact-sheet.png"
        )
        path = output / filename
        canvas.save(path, format="PNG", optimize=True)
        sheet_index.append(
            {
                "act": act,
                "seed": seed,
                "shape": "all",
                "zoom": "all",
                "pose": "all",
                "locale": manifest["locale"],
                "file": filename,
                "width": canvas.width,
                "height": canvas.height,
                "frames": included,
            }
        )

    (output / "index.json").write_bytes(
        canonical_json(
            {
                "schema": 1,
                "issue": 462,
                "capture_head": manifest["capture_head"],
                "sheets": sheet_index,
            }
        )
    )


def compare_runs(first: Path, second: Path, output: Path) -> None:
    first_manifest = first / "manifest.json"
    second_manifest = second / "manifest.json"
    first_dimensions = first / "dimensions.json"
    second_dimensions = second / "dimensions.json"

    manifest_same = first_manifest.read_bytes() == second_manifest.read_bytes()
    dimensions_same = first_dimensions.read_bytes() == second_dimensions.read_bytes()
    first_pixels = read_json(first / "pixel-hashes.json")
    second_pixels = read_json(second / "pixel-hashes.json")
    first_by_file = {row["file"]: row["png_sha256"] for row in first_pixels["frames"]}
    second_by_file = {row["file"]: row["png_sha256"] for row in second_pixels["frames"]}
    pixel_differences = sorted(
        name for name in first_by_file.keys() | second_by_file.keys()
        if first_by_file.get(name) != second_by_file.get(name)
    )

    first_meta = read_json(first_manifest)
    second_meta = read_json(second_manifest)
    report = {
        "schema": 1,
        "issue": 462,
        "capture_head": first_meta.get("capture_head"),
        "second_capture_head": second_meta.get("capture_head"),
        "manifest_byte_identical": manifest_same,
        "dimensions_byte_identical": dimensions_same,
        "pixel_hashes_identical": not pixel_differences,
        "pixel_hash_difference_count": len(pixel_differences),
        "pixel_hash_differences": pixel_differences,
        "pixel_hash_policy": (
            "Diagnostic only. Pixel hashes may vary with GPU/driver/font rasterisation; "
            "the acceptance contract is the byte-identical manifest and dimensions index."
        ),
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(canonical_json(report))
    if not manifest_same or not dimensions_same:
        raise SystemExit(
            f"repeatability failure: manifest_same={manifest_same} dimensions_same={dimensions_same}"
        )


def publish_canonical(first: Path, output: Path) -> None:
    for name in ("manifest.json", "dimensions.json", "pixel-hashes.json"):
        shutil.copy2(first / name, output / name)
    target = output / "contact-sheets"
    if target.exists():
        shutil.rmtree(target)
    shutil.copytree(first / "contact-sheets", target)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)

    package = sub.add_parser("package", help="validate one capture and build contact sheets")
    package.add_argument("--run", type=Path, required=True)

    compare = sub.add_parser("compare", help="compare two packaged captures")
    compare.add_argument("--first", type=Path, required=True)
    compare.add_argument("--second", type=Path, required=True)
    compare.add_argument("--output", type=Path, required=True)

    publish = sub.add_parser("publish", help="copy run A's canonical compact packet to the output root")
    publish.add_argument("--first", type=Path, required=True)
    publish.add_argument("--output", type=Path, required=True)
    return parser


def main(argv: Iterable[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        if args.command == "package":
            package_run(args.run.resolve())
        elif args.command == "compare":
            compare_runs(args.first.resolve(), args.second.resolve(), args.output.resolve())
        elif args.command == "publish":
            output = args.output.resolve()
            output.mkdir(parents=True, exist_ok=True)
            publish_canonical(args.first.resolve(), output)
        else:  # pragma: no cover
            raise AssertionError(args.command)
    except (OSError, ValueError, KeyError, TypeError) as exc:
        print(f"package_build4_map_corpus: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
