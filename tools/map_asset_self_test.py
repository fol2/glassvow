"""Generated pass/fail fixtures for the #291 map-asset contract."""
from __future__ import annotations

import colorsys
import hashlib
import json
import shutil
import struct
import tempfile
from pathlib import Path
from typing import Any

from map_asset_checks import (
    Finding, SILHOUETTE_NOISE, check_grade, check_tile, payload_findings,
    silhouette_noise, validate_manifest, validate_provenance,
)

GOOD_IMPORT = """[params]
compress/mode=2
compress/high_quality=true
mipmaps/generate=true
"""


def _pil() -> Any:
    from PIL import Image
    return Image


def _sidecar(path: Path, text: str = GOOD_IMPORT) -> None:
    path.with_name(path.name + ".import").write_text(text)


def _tile(path: Path, kind: str = "pass", mode: str = "RGB", size: tuple[int, int] = (64, 64)) -> None:
    pixels: list[tuple[int, ...]] = []
    w, h = size
    for y in range(h):
        for x in range(w):
            if kind == "shadow":
                value = 64 if x < w // 2 else 192
            elif kind == "seam":
                value = 115 + int(25 * x / max(w - 1, 1))
            elif kind == "mean":
                value = 200
            else:
                value = 128
            pixels.append((value, value, value, 255) if mode == "RGBA" else (value, value, value))
    image = _pil().new(mode, size)
    image.putdata(pixels)
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)
    _sidecar(path)


def _grade(path: Path, kind: str = "pass", size: tuple[int, int] = (64, 32), mode: str = "RGBA") -> None:
    w, h = size
    pixels: list[tuple[int, ...]] = []
    for y in range(h):
        for x in range(w):
            t = x / max(w - 1, 1)
            hue = 0.35 if kind == "palette" else 0.95 + (0.88 - 0.95) * t
            value = 0.85
            if kind == "noise":
                value = 0.30 if (x + y) % 2 == 0 else 0.95
            rgb = tuple(round(channel * 255) for channel in colorsys.hsv_to_rgb(hue, 0.55, value))
            contact = (x - w // 2) ** 2 + (y - h // 2) ** 2 < (min(w, h) // 5) ** 2
            alpha = 255 if kind == "alpha" or not contact else 100
            pixels.append((*rgb, alpha) if mode == "RGBA" else rgb)
    image = _pil().new(mode, size)
    image.putdata(pixels)
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)
    _sidecar(path)


def _gates(found: list[Finding]) -> set[str]:
    return {item.gate for item in found}


def _expect(errors: list[str], name: str, gate: str, found: list[Finding]) -> None:
    got = _gates(found)
    if gate not in got:
        errors.append(f"{name}: expected {gate}, got {sorted(got)}")
    else:
        print(f"self-test {name}: correctly failed {gate}")


def _mask(kind: str, n: int = 64) -> tuple[int, int, list[tuple[int, ...]]]:
    pixels: list[tuple[int, ...]] = []
    for y in range(n):
        for x in range(n):
            disk = (x - n // 2) ** 2 + (y - n // 2) ** 2 <= 324
            speck = (x + y * 13) % 7 == 0
            if kind == "specks":
                alpha = 255 if disk or speck else 0
            else:
                alpha = 255 if disk else 0
            pixels.append((180, 180, 180, alpha))
    return n, n, pixels


def _disk_raster(_path: Path) -> list[tuple[int, int, list[tuple[int, ...]]]]:
    return [_mask("disk")] * 8


def _speck_raster(_path: Path) -> list[tuple[int, int, list[tuple[int, ...]]]]:
    return [_mask("specks")] * 8


def _write_grid_glb(path: Path, cols: int = 20, rows: int = 15) -> None:
    positions: list[float] = []
    normals: list[float] = []
    indices: list[int] = []
    for j in range(rows + 1):
        for i in range(cols + 1):
            positions.extend([i / cols - 0.5, 0.0, j / rows - 0.5])
            normals.extend([0.0, 1.0, 0.0])
    for j in range(rows):
        for i in range(cols):
            a = j * (cols + 1) + i
            b = a + 1
            c = a + cols + 1
            d = c + 1
            indices.extend([a, c, b, b, c, d])
    pos_b = struct.pack("<%df" % len(positions), *positions)
    nrm_b = struct.pack("<%df" % len(normals), *normals)
    idx_b = struct.pack("<%dI" % len(indices), *indices)
    blob = pos_b + nrm_b + idx_b
    xs, ys, zs = positions[0::3], positions[1::3], positions[2::3]
    gltf = {
        "asset": {"version": "2.0"},
        "buffers": [{"byteLength": len(blob)}],
        "bufferViews": [
            {"buffer": 0, "byteOffset": 0, "byteLength": len(pos_b)},
            {"buffer": 0, "byteOffset": len(pos_b), "byteLength": len(nrm_b)},
            {"buffer": 0, "byteOffset": len(pos_b) + len(nrm_b), "byteLength": len(idx_b)},
        ],
        "accessors": [
            {"bufferView": 0, "componentType": 5126, "count": len(xs), "type": "VEC3",
             "min": [min(xs), min(ys), min(zs)], "max": [max(xs), max(ys), max(zs)]},
            {"bufferView": 1, "componentType": 5126, "count": len(xs), "type": "VEC3"},
            {"bufferView": 2, "componentType": 5125, "count": len(indices), "type": "SCALAR"},
        ],
        "meshes": [{"primitives": [{"mode": 4, "indices": 2,
                                    "attributes": {"POSITION": 0, "NORMAL": 1}}]}],
        "nodes": [{"mesh": 0}],
        "scenes": [{"nodes": [0]}],
        "scene": 0,
    }
    json_bytes = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    json_bytes += b" " * ((4 - len(json_bytes) % 4) % 4)
    blob += b"\x00" * ((4 - len(blob) % 4) % 4)
    glb = bytearray()
    glb += struct.pack("<4sII", b"glTF", 2, 0)
    glb += struct.pack("<I4s", len(json_bytes), b"JSON") + json_bytes
    glb += struct.pack("<I4s", len(blob), b"BIN\x00") + blob
    struct.pack_into("<I", glb, 8, len(glb))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(glb)


def _record(asset_id: str, path: Path, final_sha: str | None = None) -> dict[str, Any]:
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    return {
        "asset_id": asset_id,
        "source": "generated fixture",
        "created_at": "2026-08-15T00:00:00Z",
        "license": "test-only",
        "source_sha256": "0" * 64,
        "final_sha256": final_sha or digest,
        "edits": [],
        "reviewer": "self-test",
        "verdict": "accepted",
    }


def run(manifest_path: Path, provenance_path: Path, regions_path: Path) -> list[str]:
    errors: list[str] = []
    regions = regions_path.read_text()
    tile_row = {"width": 64, "height": 64, "tex_mean": 0.5, "mean_tolerance": 0.02}
    grade_row = {
        "width": 64, "height": 32,
        "palette_arc": {"near": 0.95, "far": 0.88, "corridor": 0.98, "tolerance": 0.1},
    }
    with tempfile.TemporaryDirectory(prefix="map_asset_fixtures-") as raw:
        root = Path(raw)
        good_tile = root / "tile-pass.png"
        _tile(good_tile)
        if check_tile(good_tile, good_tile.name, tile_row):
            errors.append(f"passing tile failed: {check_tile(good_tile, good_tile.name, tile_row)}")
        import_cases = {
            "compression": GOOD_IMPORT.replace("compress/mode=2\n", ""),
            "high-quality": GOOD_IMPORT.replace("compress/high_quality=true\n", ""),
            "mipmaps": GOOD_IMPORT.replace("mipmaps/generate=true\n", ""),
        }
        for gate, text in import_cases.items():
            _sidecar(good_tile, text)
            _expect(errors, gate, gate, check_tile(good_tile, good_tile.name, tile_row))
        _sidecar(good_tile)
        for name, kind, mode, size, gate in (
            ("tile-channels", "pass", "RGBA", (64, 64), "channels"),
            ("tile-dimensions", "pass", "RGB", (32, 64), "dimensions"),
            ("tile-mean", "mean", "RGB", (64, 64), "mean"),
            ("tile-de-light", "shadow", "RGB", (64, 64), "de-light"),
            ("tile-seam", "seam", "RGB", (64, 64), "seam"),
        ):
            path = root / f"{name}.png"
            _tile(path, kind, mode, size)
            _expect(errors, name, gate, check_tile(path, path.name, tile_row))
        good_grade = root / "grade-pass.png"
        _grade(good_grade)
        if check_grade(good_grade, good_grade.name, grade_row):
            errors.append(f"passing grade failed: {check_grade(good_grade, good_grade.name, grade_row)}")
        for name, kind, mode, size, gate in (
            ("grade-channels", "pass", "RGB", (64, 32), "channels"),
            ("grade-dimensions", "pass", "RGBA", (64, 64), "dimensions"),
            ("grade-contact", "alpha", "RGBA", (64, 32), "contact-mask"),
            ("grade-frequency", "noise", "RGBA", (64, 32), "low-frequency"),
            ("grade-palette", "palette", "RGBA", (64, 32), "palette-arc"),
        ):
            path = root / f"{name}.png"
            _grade(path, kind, size, mode)
            _expect(errors, name, gate, check_grade(path, path.name, grade_row))

        contract = root / "contract"
        contract.mkdir()
        shutil.copy2(manifest_path, contract / "map-assets.json")
        shutil.copy2(provenance_path, contract / "provenance.json")
        rows, findings = validate_manifest(contract, regions)
        if findings:
            errors.append(f"live manifest fixture failed: {findings}")
        records, findings = validate_provenance(contract, {str(row["id"]) for row in rows})
        if findings:
            errors.append(f"live provenance fixture failed: {findings}")
        findings, present = payload_findings(contract, rows, records, rasterize=_disk_raster)
        if findings or present != 0:
            errors.append(f"empty planned payload failed: {findings}/{present}")

        live_manifest = json.loads((contract / "map-assets.json").read_text())
        profile_id = str(next(row["id"] for row in rows if row["kind"] == "kit"))

        poisoned = json.loads(json.dumps(live_manifest))
        poisoned["unexpected_profile_field"] = True
        (contract / "map-assets.json").write_text(json.dumps(poisoned))
        _expect(errors, "profile-unknown-top", "manifest",
                validate_manifest(contract, regions)[1])

        poisoned = json.loads(json.dumps(live_manifest))
        poisoned["profile_defaults"][profile_id]["unexpected"] = True
        (contract / "map-assets.json").write_text(json.dumps(poisoned))
        _expect(errors, "profile-unknown-default", "manifest",
                validate_manifest(contract, regions)[1])

        poisoned = json.loads(json.dumps(live_manifest))
        poisoned["profile_defaults"][profile_id]["scale"] = -1.0
        (contract / "map-assets.json").write_text(json.dumps(poisoned))
        _expect(errors, "profile-negative-scale", "manifest",
                validate_manifest(contract, regions)[1])

        poisoned = json.loads(json.dumps(live_manifest))
        poisoned["profile_defaults"].pop(profile_id)
        (contract / "map-assets.json").write_text(json.dumps(poisoned))
        _expect(errors, "profile-missing-id", "manifest",
                validate_manifest(contract, regions)[1])

        poisoned = json.loads(json.dumps(live_manifest))
        poisoned["profile_overrides"]["missing-asset"] = {
            "footprint": [[0, 0], [0, 1], [1, 1], [1, 0]],
            "reason": "fixture",
        }
        (contract / "map-assets.json").write_text(json.dumps(poisoned))
        _expect(errors, "profile-override-id", "manifest",
                validate_manifest(contract, regions)[1])

        poisoned = json.loads(json.dumps(live_manifest))
        poisoned["profile_overrides"][profile_id] = {
            "footprint": [[0, 0], [2, 0], [1, 0.5], [2, 1], [0, 1]],
            "reason": "fixture",
        }
        (contract / "map-assets.json").write_text(json.dumps(poisoned))
        _expect(errors, "profile-invalid-polygon", "manifest",
                validate_manifest(contract, regions)[1])
        (contract / "map-assets.json").write_text(json.dumps(live_manifest))

        (contract / "notes.txt").write_text("undeclared")
        findings, _present = payload_findings(contract, rows, records)
        _expect(errors, "undeclared", "undeclared", findings)
        (contract / "notes.txt").unlink()

        manifest = json.loads((contract / "map-assets.json").read_text())
        manifest["assets"] = manifest["assets"][:-1]
        (contract / "map-assets.json").write_text(json.dumps(manifest))
        _expect(errors, "manifest-count", "manifest", validate_manifest(contract, regions)[1])
        shutil.copy2(manifest_path, contract / "map-assets.json")
        manifest = json.loads((contract / "map-assets.json").read_text())
        manifest["assets"][-1]["palette_arc"]["near"] = 0.33
        (contract / "map-assets.json").write_text(json.dumps(manifest))
        _expect(errors, "manifest-palette", "palette-arc", validate_manifest(contract, regions)[1])
        shutil.copy2(manifest_path, contract / "map-assets.json")

        ledger = json.loads((contract / "provenance.json").read_text())
        ledger["record_schema"]["required"] = []
        (contract / "provenance.json").write_text(json.dumps(ledger))
        _expect(errors, "provenance-schema", "provenance",
                validate_provenance(contract, {str(row["id"]) for row in rows})[1])
        shutil.copy2(provenance_path, contract / "provenance.json")

        mesh_row = next(row for row in rows if row["kind"] == "kit")
        mesh = contract / str(mesh_row["path"])
        mesh.parent.mkdir(parents=True, exist_ok=True)
        mesh.write_bytes(b"fixture glb")
        findings, _ = payload_findings(contract, rows, {}, rasterize=_disk_raster)
        _expect(errors, "provenance-required", "provenance", findings)
        _expect(errors, "mesh-magic", "mesh", findings)
        bad = _record(str(mesh_row["id"]), mesh, "f" * 64)
        findings, _ = payload_findings(contract, rows, {str(mesh_row["id"]): bad},
                                      rasterize=_disk_raster)
        _expect(errors, "checksum", "checksum", findings)
        _write_grid_glb(mesh)
        good = _record(str(mesh_row["id"]), mesh)
        findings, _ = payload_findings(contract, rows, {str(mesh_row["id"]): good},
                                      rasterize=_disk_raster)
        if _gates(findings) & {"provenance", "checksum", "file-size", "mesh",
                               "silhouette", "gpu-raster"}:
            errors.append(f"accepted mesh fixture failed: {findings}")
        findings, _ = payload_findings(contract, rows, {str(mesh_row["id"]): good},
                                      rasterize=_speck_raster)
        _expect(errors, "silhouette", "silhouette", findings)
        specks = _mask("specks")
        noise = silhouette_noise(specks[2], specks[0], specks[1])
        if noise is None or noise <= SILHOUETTE_NOISE:
            errors.append(f"silhouette criterion should trip specks, got {noise}")
        else:
            print(f"self-test silhouette-metric: correctly failed {noise:.3f}")
        mesh.write_bytes(b"x" * (int(mesh_row["bytes_max"]) + 1))
        huge = _record(str(mesh_row["id"]), mesh)
        findings, _ = payload_findings(contract, rows, {str(mesh_row["id"]): huge},
                                      rasterize=_disk_raster)
        _expect(errors, "file-size", "file-size", findings)
    return errors
