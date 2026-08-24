from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one match, found {count}")
    return text.replace(old, new, 1)


def patch_manifest() -> None:
    path = ROOT / "assets/art/map/map-assets.json"
    text = path.read_text()
    text = replace_once(text,
        '  "schema_version": 1,\n  "asset_root": "res://assets/art/map/",',
        '''  "schema_version": 2,
  "asset_root": "res://assets/art/map/",
  "profile_policy": {
    "schema_version": 1,
    "kit_scales": [2.15, 2.15, 3.4, 6.2, 2.8, 2.2, 4.6, 3.2],
    "road_ids": ["shared-road-slab-a", "shared-road-slab-b"],
    "arch_passable_ids": ["act1-fallen-bough-arch", "act2-library-arch", "act3-broken-halo", "act4-reverse-hearth-arch"],
    "terminus_scale": 3.6,
    "threshold_scale": 7.0,
    "threshold_yaw_degrees": -46.0,
    "overrides": {}
  },''', "manifest profile policy")
    path.write_text(text)


def patch_materials() -> None:
    path = ROOT / "presentation/map/map_materials.gd"
    text = path.read_text()
    text = replace_once(text, '\tvar threshold: Resource = null\n\tvar vigil_mean: float = 0.252',
        '\tvar threshold: Resource = null\n\tvar threshold_id: String = ""\n\tvar vigil_mean: float = 0.252', "threshold id var")
    text = replace_once(text, '\t\t\t"threshold":\n\t\t\t\tthreshold = resource\n\t\t\t\tvigil_mean = _row_float(row, "tex_mean", 0.252)',
        '\t\t\t"threshold":\n\t\t\t\tthreshold = resource\n\t\t\t\tthreshold_id = _row_string(row, "id")\n\t\t\t\tvigil_mean = _row_float(row, "tex_mean", 0.252)', "threshold id bind")
    text = replace_once(text, '\t\t"threshold": threshold,\n\t\t"ground_tile": ground_tile',
        '\t\t"threshold": threshold, "threshold_id": threshold_id,\n\t\t"ground_tile": ground_tile', "threshold id return")
    path.write_text(text)


PROFILE_VALIDATOR = r'''
PROFILE_KEYS = {
    "schema_version", "kit_scales", "road_ids", "arch_passable_ids",
    "terminus_scale", "threshold_scale", "threshold_yaw_degrees", "overrides",
}


def _profile_policy_findings(path: Path, policy: Any,
                             rows: list[dict[str, Any]]) -> list[Finding]:
    where = f"{path} profile_policy"
    if not isinstance(policy, dict):
        return [Finding("manifest", where, "profile_policy must be an object")]
    found: list[Finding] = []
    unknown = set(policy) - PROFILE_KEYS
    if unknown:
        found.append(Finding("manifest", where, f"unknown fields {sorted(unknown)}"))
    if policy.get("schema_version") != 1:
        found.append(Finding("manifest", where, "schema_version must be 1"))
    scales = policy.get("kit_scales")
    if not isinstance(scales, list) or len(scales) != 8 or not all(
            isinstance(value, (int, float)) and math.isfinite(float(value))
            and float(value) > 0.0 for value in scales):
        found.append(Finding("manifest", where, "kit_scales must be eight positive finite numbers"))
    for key in ("terminus_scale", "threshold_scale"):
        value = policy.get(key)
        if not isinstance(value, (int, float)) or not math.isfinite(float(value)) or float(value) <= 0.0:
            found.append(Finding("manifest", where, f"{key} must be positive and finite"))
    yaw = policy.get("threshold_yaw_degrees")
    if not isinstance(yaw, (int, float)) or not math.isfinite(float(yaw)):
        found.append(Finding("manifest", where, "threshold_yaw_degrees must be finite"))
    by_id = {str(row.get("id")): row for row in rows}
    for key in ("road_ids", "arch_passable_ids"):
        raw = policy.get(key)
        if not isinstance(raw, list) or not all(isinstance(value, str) for value in raw) \
                or len(raw) != len(set(raw)):
            found.append(Finding("manifest", where, f"{key} must be a unique string array"))
            continue
        for asset_id in raw:
            if asset_id not in by_id or by_id[asset_id].get("kind") != "kit":
                found.append(Finding("manifest", where, f"{key} names missing/non-kit asset {asset_id!r}"))
    overrides = policy.get("overrides")
    if not isinstance(overrides, dict):
        found.append(Finding("manifest", where, "overrides must be an object"))
        return found
    for asset_id, raw in overrides.items():
        override_where = f"{where} overrides[{asset_id!r}]"
        if asset_id not in by_id or by_id[asset_id].get("kind") not in {"kit", "terminus", "threshold"}:
            found.append(Finding("manifest", override_where, "missing/non-mesh asset ID"))
        if not isinstance(raw, dict):
            found.append(Finding("manifest", override_where, "override must be an object"))
            continue
        unknown_override = set(raw) - {"footprint", "reason"}
        if unknown_override:
            found.append(Finding("manifest", override_where,
                                 f"unknown fields {sorted(unknown_override)}"))
        reason, polygon = raw.get("reason"), raw.get("footprint")
        if not isinstance(reason, str) or not reason.strip():
            found.append(Finding("manifest", override_where, "override reason is required"))
        error = _profile_polygon_error(polygon)
        if error:
            found.append(Finding("manifest", override_where, error))
    return found


def _profile_polygon_error(raw: Any) -> str:
    if not isinstance(raw, list):
        return "footprint must be an array"
    points: list[tuple[float, float]] = []
    for item in raw:
        if not isinstance(item, list) or len(item) != 2 or not all(
                isinstance(value, (int, float)) and math.isfinite(float(value)) for value in item):
            return "footprint points must be finite [x,z] pairs"
        point = (float(item[0]), float(item[1]))
        if not points or point != points[-1]:
            points.append(point)
    if len(points) > 1 and points[0] == points[-1]:
        points.pop()
    if len(points) < 3 or len(set(points)) != len(points):
        return "footprint must have at least three unique points"
    turn = 0.0
    for index, point in enumerate(points):
        a = points[(index + 1) % len(points)]
        b = points[(index + 2) % len(points)]
        cross = (a[0] - point[0]) * (b[1] - a[1]) - (a[1] - point[1]) * (b[0] - a[0])
        if abs(cross) <= 1e-9:
            continue
        if turn and math.copysign(1.0, cross) != math.copysign(1.0, turn):
            return "footprint must be convex"
        turn = cross
    return "footprint must have non-zero area" if not turn else ""
'''


def patch_checker() -> None:
    path = ROOT / "tools/map_asset_checks.py"
    text = path.read_text()
    text = replace_once(text, 'KINDS = {"kit", "terminus", "threshold", "tile", "grade"}\n',
        'KINDS = {"kit", "terminus", "threshold", "tile", "grade"}\n' + PROFILE_VALIDATOR + '\n',
        "profile validator")
    text = replace_once(text,
        '    if not isinstance(data, dict) or data.get("schema_version") != 1:\n        return [], [Finding("manifest", str(path), "schema_version must be 1")]',
        '    if not isinstance(data, dict) or data.get("schema_version") != 2:\n'
        '        return [], [Finding("manifest", str(path), "schema_version must be 2")]\n'
        '    unknown_top = set(data) - {"schema_version", "asset_root", "profile_policy", "assets"}\n'
        '    if unknown_top:\n'
        '        found.append(Finding("manifest", str(path), f"unknown fields {sorted(unknown_top)}"))',
        "manifest schema and fields")
    text = replace_once(text, '    for kind, expected in EXPECTED_COUNTS.items():',
        '    found.extend(_profile_policy_findings(path, data.get("profile_policy"), rows))\n'
        '    for kind, expected in EXPECTED_COUNTS.items():', "profile policy call")
    path.write_text(text)


def patch_ci() -> None:
    path = ROOT / ".github/workflows/ci.yml"
    text = path.read_text()
    text = replace_once(text,
        '      - name: Run tests\n        run: godot --headless -s res://tests/run_all.gd\n',
        '      - name: Run tests\n        run: godot --headless -s res://tests/run_all.gd\n\n'
        '      - name: Probe shared map asset profiles\n'
        '        run: godot --headless -s res://tools/probe_map_seeds.gd -- --seeds=20\n',
        "profile probe CI")
    path.write_text(text)


patch_manifest()
patch_materials()
patch_checker()
patch_ci()
