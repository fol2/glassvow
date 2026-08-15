#!/usr/bin/env python3
"""Fail-closed map manifest, provenance, ASTC, tile, grade, and mesh gates (#291).

`assets/art/map/map-assets.json` is the classifier shared with runtime binding.
Declared-but-absent payload is legal; undeclared files are not. Mesh silhouette
remains an explicit SKIP until #292 adds the production-camera GPU raster.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

from map_asset_checks import (
    Finding, payload_findings, srgb_to_linear,
    validate_manifest, validate_provenance,
)
from map_asset_self_test import run as run_fixture_tests

REPO = Path(__file__).resolve().parent.parent
ASSET_DIR = REPO / "assets" / "art" / "map"
MATERIALS = REPO / "presentation" / "map" / "map_materials.gd"
REGIONS = REPO / "presentation" / "map" / "map_regions.gd"
VALUE_GAP_MIN = 0.272
REC709 = (0.2126, 0.7152, 0.0722)


def _float(text: str, name: str) -> float:
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


def _linear_to_srgb(c: float) -> float:
    return 12.92 * c if c <= 0.0031308 else 1.055 * max(c, 0.0) ** (1.0 / 2.4) - 0.055


def _under_key_gap(ground: float, prop: float, key: tuple[float, float, float]) -> float:
    y_key = sum(weight * srgb_to_linear(channel) for weight, channel in zip(REC709, key))
    return _linear_to_srgb(ground * y_key) - _linear_to_srgb(prop * y_key)


def palette_findings(materials: str, regions: str) -> list[Finding]:
    ground, prop = _float(materials, "GROUND_VALUE"), _float(materials, "PROP_VALUE")
    found: list[Finding] = []
    if ground - prop < VALUE_GAP_MIN:
        found.append(Finding("value-gap", str(MATERIALS.relative_to(REPO)),
                             f"linear {ground:.3f}−{prop:.3f} < {VALUE_GAP_MIN}"))
    for act, key in enumerate(_band_keys(regions)):
        predicted = _under_key_gap(ground, prop, key)
        if predicted <= 0.0:
            found.append(Finding("value-gap", str(REGIONS.relative_to(REPO)),
                                 f"act {act} key-band gap {predicted:.3f} ≤ 0"))
    return found


def scan(folder: Path) -> tuple[list[Finding], int]:
    regions = REGIONS.read_text()
    rows, found = validate_manifest(folder, regions)
    records, provenance = validate_provenance(folder, {str(row["id"]) for row in rows})
    payload, present = payload_findings(folder, rows, records)
    return found + provenance + payload + palette_findings(MATERIALS.read_text(), regions), present


def report(found: list[Finding], folder: Path, present: int) -> int:
    for item in found:
        print(item, file=sys.stderr)
    if found:
        print(f"{len(found)} map-asset gate failure(s)", file=sys.stderr)
        return 1
    ground, prop = _float(MATERIALS.read_text(), "GROUND_VALUE"), _float(MATERIALS.read_text(), "PROP_VALUE")
    predicted = " ".join(f"act{i}={_under_key_gap(ground, prop, key):.3f}"
                         for i, key in enumerate(_band_keys(REGIONS.read_text())))
    print(f"value-gap OK  linear {ground - prop:.3f} ≥ {VALUE_GAP_MIN}; {predicted}")
    print(f"map assets OK ({present} payload files; declared absence uses fallbacks)")
    return 0


def self_test() -> int:
    errors = run_fixture_tests(ASSET_DIR / "map-assets.json", ASSET_DIR / "provenance.json", REGIONS)
    if palette_findings(MATERIALS.read_text(), REGIONS.read_text()):
        errors.append("live MapRegions/MapMaterials palette must pass")
    poisoned = MATERIALS.read_text().replace("GROUND_VALUE: float = 0.420", "GROUND_VALUE: float = 0.100")
    if "value-gap" not in {item.gate for item in palette_findings(poisoned, REGIONS.read_text())}:
        errors.append("value-gap fixture did not fail")
    else:
        print("self-test value-gap: correctly failed value-gap")
    if errors:
        print("\n".join(errors), file=sys.stderr)
        print("self-test FAILED", file=sys.stderr)
        return 1
    print("self-test OK (all injected gates failed; mesh silhouette remains named SKIP)")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--dir", type=Path, default=ASSET_DIR)
    args = parser.parse_args()
    if args.self_test:
        return self_test()
    found, present = scan(args.dir)
    return report(found, args.dir, present)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, TypeError, ValueError) as error:
        print(f"map assets FAILED: {error}", file=sys.stderr)
        raise SystemExit(2)
