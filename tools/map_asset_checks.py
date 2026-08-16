"""Manifest and payload checks shared by tools/check_map_assets.py (#291)."""
from __future__ import annotations

import colorsys
import hashlib
import json
import math
import re
from pathlib import Path
from typing import Any, NamedTuple

KINDS = {"kit", "terminus", "tile", "grade"}
CONTROL_FILES = {"map-assets.json", "provenance.json"}
IMAGE_EXT, MESH_EXT = {".png"}, {".glb"}
DELIGHT_SPREAD, SEAM_RATIO = 0.15, 3.0
GRADE_HF_MAX, HUE_MIN_SAT = 0.035, 0.08
REC709 = (0.2126, 0.7152, 0.0722)
EXPECTED_COUNTS = {"kit": 23, "terminus": 4, "tile": 8, "grade": 4}
PROVENANCE_REQUIRED = {
    "asset_id", "source", "created_at", "license", "source_sha256",
    "final_sha256", "edits", "reviewer", "verdict",
}


class Finding(NamedTuple):
    gate: str
    path: str
    detail: str

    def __str__(self) -> str:
        return f"{self.gate:14} {self.path}  {self.detail}"


def srgb_to_linear(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def luma(pixel: tuple[int, ...]) -> float:
    return sum(w * srgb_to_linear(pixel[i] / 255.0) for i, w in enumerate(REC709))


def _pil() -> Any:
    try:
        from PIL import Image
    except ImportError as error:
        raise RuntimeError("Pillow is required to inspect map assets") from error
    return Image


def _json(path: Path) -> Any:
    try:
        return json.loads(path.read_text())
    except (OSError, json.JSONDecodeError) as error:
        raise RuntimeError(f"cannot read {path}: {error}") from error


def _float_array(text: str, name: str) -> list[float]:
    match = re.search(rf"const {name}:.*?=\s*\[(.*?)\]", text, re.S)
    if match is None:
        raise RuntimeError(f"{name} missing")
    return [float(value) for value in re.findall(r"-?[0-9]+(?:\.[0-9]+)?", match.group(1))]


def validate_manifest(folder: Path, regions_text: str) -> tuple[list[dict[str, Any]], list[Finding]]:
    path = folder / "map-assets.json"
    if not path.is_file():
        return [], [Finding("manifest", str(path), "authoritative manifest is missing")]
    data = _json(path)
    found: list[Finding] = []
    if not isinstance(data, dict) or data.get("schema_version") != 1:
        return [], [Finding("manifest", str(path), "schema_version must be 1")]
    if data.get("asset_root") != "res://assets/art/map/":
        found.append(Finding("manifest", str(path), "asset_root must be res://assets/art/map/"))
    rows = data.get("assets")
    if not isinstance(rows, list):
        return [], found + [Finding("manifest", str(path), "assets must be an array")]
    seen_ids: set[str] = set()
    seen_paths: set[str] = set()
    counts = {kind: 0 for kind in KINDS}
    hues = {
        "near": _float_array(regions_text, "GRADE_HUE_NEAR"),
        "far": _float_array(regions_text, "GRADE_HUE_FAR"),
        "corridor": _float_array(regions_text, "GRADE_HUE_CORRIDOR"),
    }
    for index, raw in enumerate(rows):
        where = f"{path} assets[{index}]"
        if not isinstance(raw, dict):
            found.append(Finding("manifest", where, "row must be an object"))
            continue
        row: dict[str, Any] = raw
        missing = {"id", "kind", "act", "role", "path"} - row.keys()
        if missing:
            found.append(Finding("manifest", where, f"missing {sorted(missing)}"))
            continue
        asset_id, kind, rel = str(row["id"]), str(row["kind"]), str(row["path"])
        act, role = row["act"], str(row["role"])
        if asset_id in seen_ids or not re.fullmatch(r"[a-z0-9-]+", asset_id):
            found.append(Finding("manifest", where, f"duplicate or unsafe id {asset_id!r}"))
        seen_ids.add(asset_id)
        clean = Path(rel)
        if rel in seen_paths or clean.is_absolute() or ".." in clean.parts or rel.startswith("res://"):
            found.append(Finding("manifest", where, f"duplicate or unsafe path {rel!r}"))
        seen_paths.add(rel)
        if kind not in KINDS:
            found.append(Finding("manifest", where, f"unknown kind {kind!r}"))
            continue
        counts[kind] += 1
        if not isinstance(act, int) or act not in (-1, 0, 1, 2, 3):
            found.append(Finding("manifest", where, f"invalid act {act!r}"))
        if kind == "kit":
            if role != "ordinary" or clean.suffix != ".glb" or act not in (-1, 0, 1, 2, 3):
                found.append(Finding("manifest", where, "kit requires ordinary role, GLB, act -1..3"))
            if row.get("triangle_max") != 2500 or row.get("bytes_max") != 196608:
                found.append(Finding("manifest", where, "kit caps must be 2500 triangles / 192 KiB"))
        elif kind == "terminus":
            if role != "hero" or clean.suffix != ".glb" or act not in range(4):
                found.append(Finding("manifest", where, "terminus requires hero role, GLB, act 0..3"))
            if row.get("triangle_max") != 8000 or row.get("bytes_max") != 786432:
                found.append(Finding("manifest", where, "terminus caps must be 8000 triangles / 768 KiB"))
        elif kind == "tile":
            if role not in {"ground", "prop"} or clean.suffix != ".png" or act not in range(4):
                found.append(Finding("manifest", where, "tile requires ground/prop role, PNG, act 0..3"))
            if row.get("width") != 1024 or row.get("height") != 1024:
                found.append(Finding("manifest", where, "tile contract is exactly 1024×1024"))
            mean = row.get("tex_mean")
            tolerance = row.get("mean_tolerance")
            if not isinstance(mean, (int, float)) or not 0.48 <= float(mean) <= 0.52 or tolerance != 0.02:
                found.append(Finding("manifest", where, "tile mean must be 0.48..0.52 with tolerance 0.02"))
        else:
            if role != "grade" or clean.suffix != ".png" or act not in range(4):
                found.append(Finding("manifest", where, "grade requires grade role, PNG, act 0..3"))
            if row.get("width") != 512 or row.get("height") != 256:
                found.append(Finding("manifest", where, "grade contract is exactly 512×256"))
            arc = row.get("palette_arc")
            if not isinstance(arc, dict) or act not in range(4):
                found.append(Finding("manifest", where, "grade palette_arc is missing"))
            else:
                for key in ("near", "far", "corridor"):
                    expected = hues[key][act]
                    if not math.isclose(float(arc.get(key, -9.0)), expected, abs_tol=1e-6):
                        found.append(Finding("palette-arc", where,
                                             f"{key} must follow MapRegions ({expected:.2f})"))
                if arc.get("tolerance") != 0.1:
                    found.append(Finding("manifest", where, "grade hue tolerance must be 0.1"))
    for kind, expected in EXPECTED_COUNTS.items():
        if counts[kind] != expected:
            found.append(Finding("manifest", str(path),
                                 f"{kind} count {counts[kind]} != fixed bill {expected}"))
    for act in range(4):
        active = [row for row in rows if isinstance(row, dict) and row.get("act") in (-1, act)]
        shape = {kind: sum(row.get("kind") == kind for row in active) for kind in KINDS}
        roles = {str(row.get("role")) for row in active if row.get("kind") == "tile"}
        if shape != {"kit": 8, "terminus": 1, "tile": 2, "grade": 1} or roles != {"ground", "prop"}:
            found.append(Finding("manifest", str(path), f"act {act} active payload shape is {shape}/{roles}"))
    return rows, found


def validate_provenance(folder: Path, asset_ids: set[str]) -> tuple[dict[str, dict[str, Any]], list[Finding]]:
    path = folder / "provenance.json"
    if not path.is_file():
        return {}, [Finding("provenance", str(path), "provenance ledger is missing")]
    data = _json(path)
    found: list[Finding] = []
    if not isinstance(data, dict) or data.get("schema_version") != 1:
        return {}, [Finding("provenance", str(path), "schema_version must be 1")]
    schema = data.get("record_schema")
    if not isinstance(schema, dict) or set(schema.get("required", [])) != PROVENANCE_REQUIRED:
        found.append(Finding("provenance", str(path), "record_schema required fields drifted"))
    if not isinstance(schema, dict) or schema.get("verdicts") != ["accepted", "rejected"]:
        found.append(Finding("provenance", str(path), "record_schema verdicts drifted"))
    records = data.get("records")
    if not isinstance(records, list):
        return {}, found + [Finding("provenance", str(path), "records must be an array")]
    by_id: dict[str, dict[str, Any]] = {}
    sha_pattern = re.compile(r"^[0-9a-f]{64}$")
    for index, raw in enumerate(records):
        where = f"{path} records[{index}]"
        if not isinstance(raw, dict) or not PROVENANCE_REQUIRED.issubset(raw):
            found.append(Finding("provenance", where, "record misses required fields"))
            continue
        asset_id = str(raw["asset_id"])
        if asset_id not in asset_ids or asset_id in by_id:
            found.append(Finding("provenance", where, f"unknown or duplicate asset_id {asset_id!r}"))
        by_id[asset_id] = raw
        if raw["verdict"] not in {"accepted", "rejected"}:
            found.append(Finding("provenance", where, "verdict is not accepted/rejected"))
        if not isinstance(raw["edits"], list) or not all(
                sha_pattern.fullmatch(str(raw[key])) for key in ("source_sha256", "final_sha256")):
            found.append(Finding("provenance", where, "edits/sha256 fields have invalid shape"))
    return by_id, found


def import_findings(path: Path, rel: str) -> list[Finding]:
    sidecar = path.with_name(path.name + ".import")
    text = sidecar.read_text() if sidecar.is_file() else ""
    required = {
        "compression": r"^compress/mode=2\s*$",
        "high-quality": r"^compress/high_quality=true\s*$",
        "mipmaps": r"^mipmaps/generate=true\s*$",
    }
    return [Finding(gate, rel, f"{pattern[1:-4]} missing from generated .import")
            for gate, pattern in required.items() if re.search(pattern, text, re.M) is None]


def pixels_of(path: Path) -> tuple[str, int, int, list[tuple[int, ...]]]:
    image = _pil().open(path)
    mode, size = image.mode, image.size
    rgba = image.convert("RGBA")
    raw = rgba.tobytes()
    return mode, size[0], size[1], [tuple(raw[i:i + 4]) for i in range(0, len(raw), 4)]


def stored_mean(px: list[tuple[int, ...]]) -> float:
    return sum(sum(pixel[:3]) / (3.0 * 255.0) for pixel in px) / len(px)


def delight_spread(px: list[tuple[int, ...]], w: int, h: int) -> float:
    cells: list[float] = []
    for cy in range(8):
        for cx in range(8):
            x0, x1 = cx * w // 8, max((cx + 1) * w // 8, cx * w // 8 + 1)
            y0, y1 = cy * h // 8, max((cy + 1) * h // 8, cy * h // 8 + 1)
            values = [luma(px[y * w + x]) for y in range(y0, y1) for x in range(x0, x1)]
            cells.append(sum(values) / len(values))
    return max(cells) - min(cells)


def seam_ratio(px: list[tuple[int, ...]], w: int, h: int) -> float:
    def magnitude(a: tuple[int, ...], b: tuple[int, ...]) -> float:
        return sum(abs(srgb_to_linear(a[i] / 255.0) - srgb_to_linear(b[i] / 255.0))
                   for i in range(3)) / 3.0
    wrap = (sum(magnitude(px[y * w], px[y * w + w - 1]) for y in range(h)) / h
            + sum(magnitude(px[x], px[(h - 1) * w + x]) for x in range(w)) / w) * 0.5
    pairs = ([magnitude(px[y * w + x], px[y * w + x + 1]) for y in range(h) for x in range(w - 1)]
             + [magnitude(px[y * w + x], px[(y + 1) * w + x]) for y in range(h - 1) for x in range(w)])
    return wrap / max(sum(pairs) / len(pairs), 1e-4)


def low_frequency_residual(path: Path) -> float:
    image = _pil().open(path).convert("RGB")
    small = image.resize((max(1, image.width // 8), max(1, image.height // 8)), _pil().Resampling.BILINEAR)
    smooth = small.resize(image.size, _pil().Resampling.BILINEAR)
    return sum(abs(luma(a) - luma(b)) for a, b in zip(image.getdata(), smooth.getdata())) / (image.width * image.height)


def _edge_hue(px: list[tuple[int, ...]], w: int, h: int, left: bool) -> float | None:
    start, end = (0, max(1, w // 5)) if left else (w - max(1, w // 5), w)
    sx = sy = weight = 0.0
    for y in range(h):
        for x in range(start, end):
            r, g, b = (px[y * w + x][i] / 255.0 for i in range(3))
            hue, sat, value = colorsys.rgb_to_hsv(r, g, b)
            if sat < HUE_MIN_SAT:
                continue
            current = sat * max(value, 0.1)
            sx += math.cos(hue * math.tau) * current
            sy += math.sin(hue * math.tau) * current
            weight += current
    return None if weight == 0.0 else math.atan2(sy, sx) % math.tau / math.tau


def hue_distance(a: float, b: float) -> float:
    distance = abs(a - b) % 1.0
    return min(distance, 1.0 - distance)


def check_tile(path: Path, rel: str, row: dict[str, Any]) -> list[Finding]:
    found = import_findings(path, rel)
    mode, w, h, px = pixels_of(path)
    if mode != "RGB":
        found.append(Finding("channels", rel, f"tile mode {mode}, expected opaque RGB"))
    if (w, h) != (int(row["width"]), int(row["height"])):
        found.append(Finding("dimensions", rel, f"{w}×{h} != {row['width']}×{row['height']}"))
    mean = stored_mean(px)
    target, tolerance = float(row["tex_mean"]), float(row["mean_tolerance"])
    if abs(mean - target) > tolerance:
        found.append(Finding("mean", rel, f"stored mean {mean:.3f} outside {target:.3f}±{tolerance:.3f}"))
    spread = delight_spread(px, w, h)
    if spread > DELIGHT_SPREAD:
        found.append(Finding("de-light", rel, f"8×8 luma spread {spread:.3f} > {DELIGHT_SPREAD}"))
    ratio = seam_ratio(px, w, h)
    if ratio > SEAM_RATIO:
        found.append(Finding("seam", rel, f"wrap/interior {ratio:.2f} > {SEAM_RATIO}"))
    return found


def check_grade(path: Path, rel: str, row: dict[str, Any]) -> list[Finding]:
    found = import_findings(path, rel)
    mode, w, h, px = pixels_of(path)
    if mode != "RGBA":
        found.append(Finding("channels", rel, f"grade mode {mode}, expected RGBA"))
    if (w, h) != (int(row["width"]), int(row["height"])) or w != h * 2:
        found.append(Finding("dimensions", rel, f"grade {w}×{h} is not declared 2:1 shape"))
    alpha = [pixel[3] for pixel in px]
    if min(alpha) >= 250 or max(alpha) < 250:
        found.append(Finding("contact-mask", rel, "alpha must contain contact darkening and open 1.0 area"))
    residual = low_frequency_residual(path)
    if residual > GRADE_HF_MAX:
        found.append(Finding("low-frequency", rel, f"RGB residual {residual:.3f} > {GRADE_HF_MAX}"))
    arc = row["palette_arc"]
    near, far = _edge_hue(px, w, h, True), _edge_hue(px, w, h, False)
    tolerance = float(arc["tolerance"])
    if near is None or far is None or hue_distance(near or 0.0, float(arc["near"])) > tolerance \
            or hue_distance(far or 0.0, float(arc["far"])) > tolerance:
        found.append(Finding("palette-arc", rel,
                             f"edge hues {near!r}/{far!r} miss {arc['near']}/{arc['far']}±{tolerance}"))
    return found


def payload_findings(folder: Path, rows: list[dict[str, Any]],
                     provenance: dict[str, dict[str, Any]]) -> tuple[list[Finding], int]:
    found: list[Finding] = []
    by_path = {str(row["path"]): row for row in rows}
    declared = set(by_path)
    present = 0
    if folder.is_dir():
        for path in sorted(item for item in folder.rglob("*") if item.is_file()):
            rel = path.relative_to(folder).as_posix()
            if rel in CONTROL_FILES:
                continue
            if rel.endswith(".import"):
                source = rel[:-7]
                if source not in declared or not (folder / source).is_file():
                    found.append(Finding("undeclared", rel, "orphan/stale import sidecar"))
                continue
            if rel not in declared:
                found.append(Finding("undeclared", rel, "file is not declared by map-assets.json"))
                continue
            present += 1
            row = by_path[rel]
            record = provenance.get(str(row["id"]))
            if record is None or record.get("verdict") != "accepted":
                found.append(Finding("provenance", rel, "present asset lacks an accepted provenance record"))
            else:
                actual = hashlib.sha256(path.read_bytes()).hexdigest()
                if actual != record.get("final_sha256"):
                    found.append(Finding("checksum", rel, f"{actual} != provenance final_sha256"))
            if row["kind"] == "tile":
                found.extend(check_tile(path, rel, row))
            elif row["kind"] == "grade":
                found.extend(check_grade(path, rel, row))
            else:
                if path.stat().st_size > int(row["bytes_max"]):
                    found.append(Finding("file-size", rel, f"{path.stat().st_size} > {row['bytes_max']}"))
                print(f"gpu-silhouette {rel}  SKIP until #292 production-camera raster gate")
    return found, present
