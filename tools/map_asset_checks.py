"""Manifest and payload checks shared by tools/check_map_assets.py (#291/#292)."""
from __future__ import annotations

import colorsys
import hashlib
import io
import json
import math
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile
from collections.abc import Callable
from pathlib import Path
from typing import Any, NamedTuple

## `threshold` is the west bookend, and only Act I has one: the story puts the
## Vigil at the start of the road and nowhere else (docs/story/01-world.md).
## Every other kind is a fixed bill per act; this one is a fixed bill of one
## for the whole map, which is why the per-act shape below accepts 0 or 1.
KINDS = {"kit", "terminus", "threshold", "tile", "grade"}
CONTROL_FILES = {"map-assets.json", "provenance.json"}
IMAGE_EXT, MESH_EXT = {".png"}, {".glb"}
DELIGHT_SPREAD, SEAM_RATIO = 0.15, 3.0
GRADE_HF_MAX, HUE_MIN_SAT = 0.035, 0.08
SILHOUETTE_NOISE, TRIANGLE_MIN = 0.04, 600
YAW_DEGREES = tuple(range(0, 360, 45))
REC709 = (0.2126, 0.7152, 0.0722)
EXPECTED_COUNTS = {"kit": 23, "terminus": 4, "threshold": 1, "tile": 8, "grade": 4}
REPO = Path(__file__).resolve().parent.parent
RASTER_SCRIPT = "res://tools/raster_map_silhouette.gd"
PROVENANCE_REQUIRED = {
    "asset_id", "source", "created_at", "license", "source_sha256",
    "final_sha256", "edits", "reviewer", "verdict",
}


class Finding(NamedTuple):
    gate: str
    path: str
    detail: str

    def __str__(self) -> str:
        return f"{self.gate:16} {self.path}  {self.detail}"


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
        # `components_max` switches off the hidden-internals check for a row, so
        # it is gated here rather than merely read in `inspect_glb`. Unbounded
        # and unvalidated it would let any kit write `components_max: 99` and
        # turn the check off with the manifest still green -- an opt-out with no
        # gate on the opt-out is not a gate.
        if "components_max" in row and kind != "threshold":
            found.append(Finding("manifest", where,
                                 f"components_max is not available to kind {kind!r}"))
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
        elif kind == "threshold":
            if role != "hero" or clean.suffix != ".glb" or act != 0:
                found.append(Finding("manifest", where,
                                     "threshold requires hero role, GLB, act 0"))
            if row.get("triangle_max") != 8000 or row.get("bytes_max") != 786432:
                found.append(Finding("manifest", where,
                                     "threshold caps must be 8000 triangles / 768 KiB"))
            if row.get("components_max") != 2:
                found.append(Finding("manifest", where,
                                     "threshold declares exactly components_max 2: "
                                     "the hall and the smoke over its chimney"))
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
        threshold = shape.pop("threshold", 0)
        if shape != {"kit": 8, "terminus": 1, "tile": 2, "grade": 1} \
                or roles != {"ground", "prop"} or threshold not in (0, 1):
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


def silhouette_noise(px: list[tuple[int, ...]], w: int, h: int) -> float | None:
    """3×3 opening residue / opaque area. Same metric the PNG gate used (#234)."""
    mask = [1 if p[3] >= 128 else 0 for p in px]
    opaque = sum(mask)
    if opaque in (0, w * h):
        return None

    def morph(src: list[int], pick: Any) -> list[int]:
        out = [0] * (w * h)
        for y in range(h):
            for x in range(w):
                vals = [src[y * w + x]]
                for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h:
                        vals.append(src[ny * w + nx])
                out[y * w + x] = int(pick(vals))
        return out

    opened = morph(morph(mask, min), max)
    return sum(1 for i, bit in enumerate(mask) if bit and not opened[i]) / opaque


def inspect_glb(path: Path, rel: str, row: dict[str, Any]) -> list[Finding]:
    data = path.read_bytes()
    if len(data) < 20 or data[:4] != b"glTF":
        return [Finding("mesh", rel, "file is not a GLB")]
    found: list[Finding] = []
    try:
        gltf, blob = _glb_chunks(data)
    except (KeyError, OSError, struct.error, UnicodeDecodeError, ValueError, json.JSONDecodeError) as error:
        return [Finding("mesh", rel, f"GLB parse failed: {error}")]
    meshes = gltf.get("meshes") or []
    if len(meshes) != 1 or len((meshes[0] or {}).get("primitives") or []) != 1:
        found.append(Finding("mesh", rel, "ordinary/hero contract is one mesh, one surface"))
        return found
    primitive = meshes[0]["primitives"][0]
    attributes = primitive.get("attributes") or {}
    mode = primitive.get("mode", 4)
    # UVs and a baked texture used to be banned outright here, on the reasoning
    # that surfacing everything by projection is what keeps 23 separately
    # generated kits from drifting apart in style (map_prop.gdshader). That ban
    # was retired on 2026-08-24: it was holding the map's one BUILDING to the
    # same rule as its rocks, and a building that cannot carry coursed stone,
    # a slate roof and a corbel band reads as another boulder. The kits are
    # still untextured -- by how they are authored, which is the discipline
    # that was actually doing the work, not by a gate refusing the file.
    #
    # What is still banned is what the map genuinely cannot use: a second UV
    # set, tangents for a normal map the unshaded shader never reads, and skin
    # weights for a rig that does not exist.
    banned = {"TEXCOORD_1", "TANGENT", "JOINTS_0", "WEIGHTS_0"}
    if mode != 4 or "POSITION" not in attributes or "NORMAL" not in attributes:
        found.append(Finding("mesh", rel, "need triangulated POSITION+NORMAL"))
    if banned & set(attributes):
        found.append(Finding("mesh", rel, f"forbidden attributes {sorted(banned & set(attributes))}"))
    for extra, label in (
        (gltf.get("animations") or [], "animation"),
        (gltf.get("skins") or [], "skeleton"),
    ):
        if extra:
            found.append(Finding("mesh", rel, f"{label} is not allowed on shipping kit GLBs"))
    # An embedded texture is allowed but not free: it rides inside the GLB, so
    # the row's `bytes_max` is what bounds it. No separate knob -- one budget.
    found.extend(_embedded_mean_findings(gltf, blob, rel, row))
    accessors = gltf.get("accessors") or []
    index_id = primitive.get("indices")
    tris = 0
    if isinstance(index_id, int) and 0 <= index_id < len(accessors):
        tris = int(accessors[index_id].get("count", 0)) // 3
    elif "POSITION" in attributes:
        pos = accessors[int(attributes["POSITION"])]
        tris = int(pos.get("count", 0)) // 3
    cap = int(row["triangle_max"])
    lo = TRIANGLE_MIN if row["kind"] == "kit" else 1
    if not lo <= tris <= cap:
        found.append(Finding("mesh", rel, f"{tris} triangles outside {lo}–{cap}"))
    pos_id = attributes.get("POSITION")
    if isinstance(pos_id, int) and 0 <= pos_id < len(accessors):
        mins = accessors[pos_id].get("min") or []
        if len(mins) >= 2 and not (-1e-3 <= float(mins[1]) <= 0.05):
            found.append(Finding("mesh", rel, f"ground pivot Y min {mins[1]!r}, expected ~0"))
        components = _connected_components(blob, gltf, primitive)
        # Most assets are one body. A row says so explicitly when it is not:
        # the Vigil's smoke floats clear of its chimney and is a second body on
        # purpose. Defaulting to 1 keeps every other row as strict as before.
        allowed = int(row.get("components_max", 1))
        if components > allowed:
            found.append(Finding("mesh", rel, f"{components} connected islands; hidden internals fail"))
    return found


def raster_masks(path: Path, repo: Path = REPO) -> list[tuple[int, int, list[tuple[int, ...]]]]:
    out = Path(tempfile.mkdtemp(prefix="map-sil-"))
    rel = path.resolve()
    try:
        glb_arg = "res://" + rel.relative_to(repo).as_posix()
    except ValueError:
        glb_arg = str(rel)
    godot = os.environ.get("GODOT", "godot")
    cmd = [
        godot, "--path", str(repo),
        "--position", os.environ.get("GLASSVOW_SHOT_POSITION", "-4000,-4000"),
        "-s", RASTER_SCRIPT, "--", f"--glb={glb_arg}", f"--out={out}",
    ]
    if sys.platform.startswith("linux"):
        cmd[1:1] = ["--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3"]
        if not os.environ.get("DISPLAY") and shutil.which("xvfb-run"):
            cmd = ["xvfb-run", "-a", *cmd]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=120, check=False)
    except (OSError, subprocess.TimeoutExpired) as error:
        raise RuntimeError(f"godot raster failed: {error}") from error
    if proc.returncode != 0:
        raise RuntimeError(
            f"godot raster rc={proc.returncode}: {(proc.stderr or proc.stdout or '').strip()[-800:]}")
    masks: list[tuple[int, int, list[tuple[int, ...]]]] = []
    for deg in YAW_DEGREES:
        png = out / f"rot-{deg:03d}.png"
        if not png.is_file():
            raise RuntimeError(f"missing mask {png.name}: {(proc.stdout or '')[-400:]}")
        _mode, w, h, px = pixels_of(png)
        masks.append((w, h, px))
    return masks


def evaluate_masks(masks: list[tuple[int, int, list[tuple[int, ...]]]], rel: str) -> list[Finding]:
    if len(masks) != len(YAW_DEGREES):
        return [Finding("gpu-raster", rel, f"{len(masks)} masks, expected {len(YAW_DEGREES)}")]
    found: list[Finding] = []
    for deg, (w, h, px) in zip(YAW_DEGREES, masks):
        noise = silhouette_noise(px, w, h)
        if noise is None:
            opaque = sum(1 for pixel in px if pixel[3] >= 128)
            if opaque == 0:
                found.append(Finding("silhouette", rel, f"yaw {deg} produced an empty mask"))
            else:
                found.append(Finding("silhouette", rel, f"yaw {deg} filled the transparent target"))
        elif noise > SILHOUETTE_NOISE:
            found.append(Finding("silhouette", rel,
                                 f"yaw {deg} small-feature fraction {noise:.3f} > {SILHOUETTE_NOISE}"))
        else:
            print(f"gpu-silhouette {rel}  yaw {deg} noise {noise:.4f} ≤ {SILHOUETTE_NOISE}")
    return found


def check_mesh(path: Path, rel: str, row: dict[str, Any],
               rasterize: Callable[[Path], list[tuple[int, int, list[tuple[int, ...]]]]] | None = None
               ) -> list[Finding]:
    found: list[Finding] = []
    if path.stat().st_size > int(row["bytes_max"]):
        found.append(Finding("file-size", rel, f"{path.stat().st_size} > {row['bytes_max']}"))
    found.extend(inspect_glb(path, rel, row))
    if any(item.gate == "mesh" and "not a GLB" in item.detail for item in found):
        return found
    try:
        masks = (rasterize or raster_masks)(path)
    except (OSError, RuntimeError, ValueError) as error:
        found.append(Finding("gpu-raster", rel, str(error)))
        return found
    found.extend(evaluate_masks(masks, rel))
    return found


def payload_findings(folder: Path, rows: list[dict[str, Any]],
                     provenance: dict[str, dict[str, Any]],
                     rasterize: Callable[[Path], list[tuple[int, int, list[tuple[int, ...]]]]] | None = None
                     ) -> tuple[list[Finding], int]:
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
                found.extend(check_mesh(path, rel, row, rasterize=rasterize))
    return found, present


def _glb_chunks(data: bytes) -> tuple[dict[str, Any], bytes]:
    _magic, _version, length = struct.unpack_from("<4sII", data, 0)
    offset = 12
    gltf: dict[str, Any] | None = None
    blob = b""
    while offset + 8 <= min(length, len(data)):
        chunk_len, chunk_type = struct.unpack_from("<I4s", data, offset)
        payload = data[offset + 8:offset + 8 + chunk_len]
        offset += 8 + chunk_len
        if chunk_type == b"JSON":
            gltf = json.loads(payload.decode("utf-8"))
        elif chunk_type == b"BIN\x00":
            blob = payload
    if not isinstance(gltf, dict):
        raise ValueError("GLB JSON chunk missing")
    return gltf, blob


## `tex_mean` is what the shader divides by to put a surface on the value
## ladder, so it is a MEASUREMENT of the baked atlas, not a preference. Nothing
## checked it: a re-bake would leave the number, and the `surface_value` derived
## from it, quietly describing an image that no longer exists. This is the check
## that makes the shader comment true.
def _embedded_mean_findings(gltf: dict[str, Any], blob: bytes, rel: str,
                            row: dict[str, Any]) -> list[Finding]:
    declared = row.get("tex_mean")
    images = gltf.get("images") or []
    if declared is None or not images:
        return []
    view_id = (images[0] or {}).get("bufferView")
    views = gltf.get("bufferViews") or []
    if not isinstance(view_id, int) or not 0 <= view_id < len(views):
        return [Finding("mesh", rel, "declares tex_mean but its image is not embedded")]
    view = views[view_id]
    start = int(view.get("byteOffset", 0))
    raw = blob[start:start + int(view["byteLength"])]
    try:
        image = _pil().open(io.BytesIO(raw)).convert("L")
    except (OSError, ValueError) as error:
        return [Finding("mesh", rel, f"embedded image unreadable: {error}")]
    pixels = image.tobytes()
    measured = (sum(pixels) / len(pixels)) / 255.0 if pixels else 0.0
    if abs(measured - float(declared)) > 0.01:
        return [Finding("mesh", rel,
                        f"embedded atlas mean {measured:.3f} is not the declared "
                        f"tex_mean {float(declared):.3f}")]
    return []


def _connected_components(blob: bytes, gltf: dict[str, Any], primitive: dict[str, Any]) -> int:
    attributes = primitive.get("attributes") or {}
    accessors = gltf.get("accessors") or []
    views = gltf.get("bufferViews") or []
    pos_id = attributes.get("POSITION")
    index_id = primitive.get("indices")
    if not isinstance(pos_id, int) or not isinstance(index_id, int):
        return 1
    pos = _read_accessor(blob, accessors[pos_id], views)
    indices = _read_accessor(blob, accessors[index_id], views)
    # Weld by POSITION before counting, or a UV seam reads as a tear. An unwrap
    # splits a vertex everywhere the chart is cut, so the same corner arrives as
    # two indices that no triangle joins: the Vigil measured 118 "islands" raw
    # and 2 welded, and 3824 -> 2825 verts is exactly the Euler prediction for a
    # closed surface at 5615 triangles.
    #
    # THIS IS A WEAKER CHECK THAN IT WAS, and the honest statement of how much.
    # The invariant moved from "no vertex-disjoint bodies" to "no
    # POSITION-disjoint bodies". A hidden interior body that floats free still
    # fails, measured -- but one that touches the shell at a single coincident
    # vertex now welds into the same component and passes: an unmerged CSG
    # union, an inset partition that kept its shared edge, an interior box
    # standing on the same floor plane. That is the price of letting an
    # unwrapped asset through at all, and it is worth paying only because the
    # alternative was banning UVs outright, which is what put a hand-painted
    # trim sheet on the map's one building.
    #
    # `round(..., 5)` is a bucket, not a tolerance: two coincident vertices
    # either side of a bucket edge stay split, and two distinct surfaces 10 um
    # apart merge. At this map's unit scale neither is a way to hide anything,
    # so it stays a bucket rather than growing a spatial index.
    seats: dict[tuple[float, float, float], int] = {}
    weld: list[int] = []
    for i in range(0, len(pos) - 2, 3):
        key = (round(float(pos[i]), 5),
               round(float(pos[i + 1]), 5),
               round(float(pos[i + 2]), 5))
        weld.append(seats.setdefault(key, len(seats)))
    count = len(seats)
    parent = list(range(count))

    def find(i: int) -> int:
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    for a, b, c in zip(indices[0::3], indices[1::3], indices[2::3]):
        ia, ib, ic = int(a), int(b), int(c)
        if max(ia, ib, ic) >= len(weld):
            continue
        ra, rb, rc = find(weld[ia]), find(weld[ib]), find(weld[ic])
        parent[rb] = ra
        parent[rc] = ra
    return len({find(i) for i in range(count)})


def _read_accessor(blob: bytes, accessor: dict[str, Any], views: list[Any]) -> tuple[float, ...]:
    view = views[int(accessor["bufferView"])]
    start = int(view.get("byteOffset", 0)) + int(accessor.get("byteOffset", 0))
    component = int(accessor["componentType"])
    count = int(accessor["count"])
    comps = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[str(accessor["type"])]
    fmt = {5121: "B", 5123: "H", 5125: "I", 5126: "f"}[component]
    n = count * comps
    return struct.unpack_from("<" + fmt * n, blob, start)
