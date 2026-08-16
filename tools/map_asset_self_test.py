"""Generated pass/fail fixtures for the #291 map-asset contract."""
from __future__ import annotations

import colorsys
import hashlib
import json
import shutil
import tempfile
from pathlib import Path
from typing import Any

from map_asset_checks import (
    Finding, check_grade, check_tile, payload_findings,
    validate_manifest, validate_provenance,
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
        if findings or records:
            errors.append(f"empty provenance fixture failed: {findings}/{records}")
        findings, present = payload_findings(contract, rows, records)
        if findings or present != 0:
            errors.append(f"empty planned payload failed: {findings}/{present}")
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
        findings, _ = payload_findings(contract, rows, {})
        _expect(errors, "provenance-required", "provenance", findings)
        bad = _record(str(mesh_row["id"]), mesh, "f" * 64)
        findings, _ = payload_findings(contract, rows, {str(mesh_row["id"]): bad})
        _expect(errors, "checksum", "checksum", findings)
        good = _record(str(mesh_row["id"]), mesh)
        findings, _ = payload_findings(contract, rows, {str(mesh_row["id"]): good})
        if _gates(findings) & {"provenance", "checksum", "file-size"}:
            errors.append(f"accepted mesh fixture failed: {findings}")
        mesh.write_bytes(b"x" * (int(mesh_row["bytes_max"]) + 1))
        huge = _record(str(mesh_row["id"]), mesh)
        findings, _ = payload_findings(contract, rows, {str(mesh_row["id"]): huge})
        _expect(errors, "file-size", "file-size", findings)
    return errors
