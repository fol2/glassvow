#!/usr/bin/env python3
"""Gate map tile/module assets (#207 repairs 7–9, #234 slice 5).

mipmaps    sidecar `mipmaps/generate=true` (importer default false on non-3D;
           a headless-added tile ships un-mipmapped and crawls on pan).
de-light   8×8 downsample; fail if linear Rec.709 luma spread (max−min) >
           DELIGHT_SPREAD. Fine grain averages out; baked light stays. Mean
           of this pass is the shader `tex_mean`.
seam       wrap-edge |Δ| / interior neighbour |Δ| (tile period). Fail if wrap
           is a stronger discontinuity than SEAM_RATIO × interior.
value-gap  linearised ground vs prop under MapRegions BAND_KEY (key cel band,
           grade=1, tex at mean). Pair is MapMaterials GROUND_VALUE/PROP_VALUE
           (0.420/0.100 linear ← sRGB V 0.68/0.35). VALUE_GAP_MIN = 0.272 —
           #255 measured 0.272 under the key band in screen space against the
           0.33 sRGB-V anchor. #234's call: gate at the measured floor; do not
           fail the tree for missing 0.33.
silhouette content criterion (AFK: wedges, slabs, dabs; no fine silhouette
           detail). Checkable today: PNG alpha cutouts whose 3×3-opening residue
           > SILHOUETTE_NOISE of opaque area. Not checkable: mesh outline
           frequency (.glb/.gltf/.obj/.fbx/.mesh) — needs a GPU silhouette
           raster; named and skipped, never failed.

Empty `assets/art/map/` is the production state; exit 0 with a note.
`--self-test` writes pass/fail tiles into a fixture dir (not assets/art/).
"""
from __future__ import annotations

import argparse, re, sys, tempfile
from pathlib import Path
from typing import Any, NamedTuple

REPO = Path(__file__).resolve().parent.parent
ASSET_DIR = REPO / "assets" / "art" / "map"
MATERIALS = REPO / "presentation" / "map" / "map_materials.gd"
REGIONS = REPO / "presentation" / "map" / "map_regions.gd"
IMAGE_EXT, MESH_EXT = {".png"}, {".glb", ".gltf", ".obj", ".fbx", ".mesh"}
DELIGHT_SPREAD, SEAM_RATIO, SILHOUETTE_NOISE = 0.15, 3.0, 0.04
VALUE_GAP_MIN = 0.272  # #255 screen-space under the key band; anchor is 0.33
REC709 = (0.2126, 0.7152, 0.0722)


class Finding(NamedTuple):
    gate: str
    path: str
    detail: str
    def __str__(self) -> str:
        return f"{self.gate:12} {self.path}  {self.detail}"


def srgb_to_linear(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

def linear_to_srgb(c: float) -> float:
    return 12.92 * c if c <= 0.0031308 else 1.055 * (max(c, 0.0) ** (1.0 / 2.4)) - 0.055

def luma(r: float, g: float, b: float) -> float:
    return sum(w * srgb_to_linear(c) for w, c in zip(REC709, (r, g, b)))

def _pil() -> Any:
    try:
        from PIL import Image
    except ImportError as error:
        raise SystemExit("Pillow is required to inspect map tiles") from error
    return Image

def mipmaps_on(sidecar: Path) -> bool:
    match = re.search(r"^mipmaps/generate=(true|false)\s*$", sidecar.read_text() if sidecar.is_file() else "", re.M)
    return bool(match) and match.group(1) == "true"

def pixels_of(path: Path) -> tuple[int, int, list[tuple[int, ...]]]:
    image = _pil().open(path).convert("RGBA")
    raw = image.tobytes()
    return image.size[0], image.size[1], [tuple(raw[i:i + 4]) for i in range(0, len(raw), 4)]

def delight_spread(px: list[tuple[int, ...]], w: int, h: int) -> float:
    cells: list[float] = []
    for cy in range(8):
        for cx in range(8):
            x0, x1 = cx * w // 8, max((cx + 1) * w // 8, cx * w // 8 + 1)
            y0, y1 = cy * h // 8, max((cy + 1) * h // 8, cy * h // 8 + 1)
            acc = [luma(px[y * w + x][0] / 255.0, px[y * w + x][1] / 255.0, px[y * w + x][2] / 255.0)
                   for y in range(y0, y1) for x in range(x0, x1)]
            cells.append(sum(acc) / len(acc))
    return max(cells) - min(cells)

def seam_ratio(px: list[tuple[int, ...]], w: int, h: int) -> float:
    def mag(a: tuple[int, ...], b: tuple[int, ...]) -> float:
        return sum(abs(srgb_to_linear(a[i] / 255.0) - srgb_to_linear(b[i] / 255.0)) for i in range(3)) / 3.0
    wrap = (sum(mag(px[y * w], px[y * w + w - 1]) for y in range(h)) / h
            + sum(mag(px[x], px[(h - 1) * w + x]) for x in range(w)) / w) * 0.5
    pairs = ([mag(px[y * w + x], px[y * w + x + 1]) for y in range(h) for x in range(w - 1)]
             + [mag(px[y * w + x], px[(y + 1) * w + x]) for y in range(h - 1) for x in range(w)])
    return wrap / max(sum(pairs) / len(pairs), 1e-4)

def silhouette_noise(px: list[tuple[int, ...]], w: int, h: int) -> float | None:
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

def check_image(path: Path, rel: str) -> list[Finding]:
    found: list[Finding] = []
    if not mipmaps_on(path.with_name(path.name + ".import")):
        found.append(Finding("mipmaps", rel, "mipmaps/generate is not true (Godot default false)"))
    w, h, px = pixels_of(path)
    spread = delight_spread(px, w, h)
    if spread > DELIGHT_SPREAD:
        found.append(Finding("de-light", rel, f"8×8 luma spread {spread:.3f} > {DELIGHT_SPREAD}"))
    ratio = seam_ratio(px, w, h)
    if ratio > SEAM_RATIO:
        found.append(Finding("seam", rel, f"wrap/interior {ratio:.2f} > {SEAM_RATIO}"))
    noise = silhouette_noise(px, w, h)
    if noise is not None and noise > SILHOUETTE_NOISE:
        found.append(Finding("silhouette", rel, f"small-feature fraction {noise:.3f} > {SILHOUETTE_NOISE}"))
    return found

def _floats(text: str, name: str) -> float:
    match = re.search(rf"const {name}:\s*float\s*=\s*([0-9.]+)", text)
    if match is None:
        raise RuntimeError(f"{name} missing")
    return float(match.group(1))

def _band_keys(text: str) -> list[tuple[float, float, float]]:
    block = re.search(r"const BAND_KEY:.*?(?=\nconst |\n## |\nvar |\Z)", text, re.S)
    if block is None:
        raise RuntimeError("BAND_KEY missing")
    keys = [(float(r), float(g), float(b)) for r, g, b in re.findall(
        r"Color\(\s*([0-9.]+)\s*,\s*([0-9.]+)\s*,\s*([0-9.]+)", block.group(0))]
    if not keys:
        raise RuntimeError("BAND_KEY has no Color() rows")
    return keys

def under_key_gap(ground: float, prop: float, key: tuple[float, float, float]) -> float:
    """sRGB Rec.709 Y of surface_value × linearised(BAND_KEY) — key band, no GPU."""
    y_key = sum(w * srgb_to_linear(c) for w, c in zip(REC709, key))
    return linear_to_srgb(ground * y_key) - linear_to_srgb(prop * y_key)

def check_palette() -> list[Finding]:
    ground = _floats(MATERIALS.read_text(), "GROUND_VALUE")
    prop = _floats(MATERIALS.read_text(), "PROP_VALUE")
    found: list[Finding] = []
    if ground - prop < VALUE_GAP_MIN:
        found.append(Finding("value-gap", str(MATERIALS.relative_to(REPO)),
                             f"linear {ground:.3f}−{prop:.3f}={ground - prop:.3f} < {VALUE_GAP_MIN} (#255 floor)"))
    for i, key in enumerate(_band_keys(REGIONS.read_text())):
        predicted = under_key_gap(ground, prop, key)
        if predicted <= 0.0:
            found.append(Finding("value-gap", str(REGIONS.relative_to(REPO)),
                                 f"act {i} key-band gap {predicted:.3f} ≤ 0 (ground not brighter than prop)"))
    return found

def scan(folder: Path) -> list[Finding]:
    found: list[Finding] = []
    if not folder.is_dir():
        return found
    for path in sorted(p for p in folder.rglob("*") if p.is_file()):
        rel = str(path.relative_to(REPO) if path.is_relative_to(REPO) else path)
        if path.suffix.lower() in IMAGE_EXT:
            found.extend(check_image(path, rel))
        elif path.suffix.lower() in MESH_EXT:
            print(f"silhouette   {rel}  SKIP mesh outline (needs GPU raster; PNG alpha is the check today)")
    return found

def report(found: list[Finding], folder: Path, images: int) -> int:
    for item in found:
        print(item, file=sys.stderr)
    if not folder.is_dir() or images == 0:
        print(f"map assets: none in {folder} — tile gates idle until tiles exist")
    if found:
        print(f"{len(found)} map-asset gate failure(s)", file=sys.stderr)
        return 1
    ground = _floats(MATERIALS.read_text(), "GROUND_VALUE")
    prop = _floats(MATERIALS.read_text(), "PROP_VALUE")
    predicted = " ".join(f"act{i}={under_key_gap(ground, prop, k):.3f}"
                         for i, k in enumerate(_band_keys(REGIONS.read_text())))
    print(f"value-gap OK  linear {ground - prop:.3f} ≥ {VALUE_GAP_MIN}  "
          f"(#255 measured {VALUE_GAP_MIN} vs anchor 0.33)")
    print(f"value-gap key-band  {predicted}  (predicted sRGB Y under BAND_KEY)")
    print("map assets OK" if images else "map assets OK (empty)")
    return 0

def _write_png(path: Path, kind: str) -> None:
    n, px, cells = 64, [], 16
    for y in range(n):
        for x in range(n):
            fx, fy = x * cells / n, y * cells / n
            ix, iy = int(fx), int(fy)
            tx, ty = fx - ix, fy - iy
            tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
            def h(i: int, j: int) -> float:
                k = ((i % cells) * 374761393 + (j % cells) * 668265263) & 0xFFFFFFFF
                k = (k ^ (k >> 13)) * 1274126177 & 0xFFFFFFFF
                return ((k >> 9) & 0xFFFFFF) / 16777215.0
            v = (h(ix, iy) * (1 - tx) * (1 - ty) + h(ix + 1, iy) * tx * (1 - ty)
                 + h(ix, iy + 1) * (1 - tx) * ty + h(ix + 1, iy + 1) * tx * ty)
            g = int((0.25 if x < n // 2 else 0.75) * 255) if kind == "shadow" else int((0.48 + v * 0.04) * 255)
            px.append((g, g, g, 255))
    path.parent.mkdir(parents=True, exist_ok=True)
    img = _pil().new("RGBA", (n, n))
    img.putdata(px)
    img.save(path)

def self_test() -> int:
    errors: list[str] = []
    with tempfile.TemporaryDirectory(prefix="map_asset_fixtures-") as raw:
        root = Path(raw)
        print(f"self-test fixtures at {root}")
        for name, kind, want in (("pass", "pass", []), ("fail", "shadow", ["de-light"])):
            png = root / name / f"{kind}.png"
            _write_png(png, kind)
            png.with_name(png.name + ".import").write_text("[params]\nmipmaps/generate=true\n")
            got = [f.gate for f in scan(png.parent)]
            if want and not any(g in got for g in want):
                errors.append(f"{name} wanted {want}, got {got}")
            elif want:
                print(f"self-test {name}: correctly failed {want} (got {got})")
            elif got:
                errors.append(f"{name} should pass, got {got}")
        (root / "empty").mkdir()
        if scan(root / "empty"):
            errors.append("empty dir should be idle")
        if check_palette():
            errors.append(f"live palette should pass, got {check_palette()}")
        live = _floats(MATERIALS.read_text(), "GROUND_VALUE") - _floats(MATERIALS.read_text(), "PROP_VALUE")
        if live < VALUE_GAP_MIN:
            errors.append(f"live linear gap {live:.3f} < {VALUE_GAP_MIN}")
        specks = [(180, 180, 180, 255 if (x - 32) ** 2 + (y - 32) ** 2 <= 324 else
                   (255 if (x + y * 13) % 17 == 0 else 0)) for y in range(64) for x in range(64)]
        noise = silhouette_noise(specks, 64, 64)
        if noise is None or noise <= SILHOUETTE_NOISE:
            errors.append(f"silhouette criterion should trip specks, got {noise}")
    if errors:
        print("\n".join(errors), file=sys.stderr)
        print("self-test FAILED", file=sys.stderr)
        return 1
    print("self-test OK (failing fixture correctly failed)")
    return 0

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--dir", type=Path, default=ASSET_DIR)
    args = parser.parse_args()
    if args.self_test:
        return self_test()
    folder: Path = args.dir
    found = scan(folder) + check_palette()
    images = 0 if not folder.is_dir() else sum(
        1 for p in folder.rglob("*") if p.suffix.lower() in IMAGE_EXT | MESH_EXT)
    return report(found, folder, images)

if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError) as error:
        print(f"map assets FAILED: {error}", file=sys.stderr)
        raise SystemExit(2)
