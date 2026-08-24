from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one match, found {count}")
    return text.replace(old, new, 1)


PROFILE_MANIFEST = '''  "schema_version": 2,
  "asset_root": "res://assets/art/map/",
  "profile_defaults": {
    "shared-road-slab-a": {"scale": 2.15, "semantic_class": "road", "yaw_mode": "road_aligned"},
    "shared-road-slab-b": {"scale": 2.15, "semantic_class": "road", "yaw_mode": "road_aligned"},
    "shared-standing-monument": {"scale": 3.4, "semantic_class": "scenery", "yaw_mode": "free"},
    "act1-ash-trunk-fork": {"scale": 6.2, "semantic_class": "scenery", "yaw_mode": "free"},
    "act1-root-wedge": {"scale": 2.8, "semantic_class": "scenery", "yaw_mode": "free"},
    "act1-charred-stump": {"scale": 2.2, "semantic_class": "scenery", "yaw_mode": "free"},
    "act1-fallen-bough-arch": {"scale": 4.6, "semantic_class": "arch_passable", "yaw_mode": "free"},
    "act1-ash-cairn-mass": {"scale": 3.2, "semantic_class": "scenery", "yaw_mode": "free"},
    "act2-drowned-wall-corner": {"scale": 6.2, "semantic_class": "scenery", "yaw_mode": "free"},
    "act2-silted-stair": {"scale": 2.8, "semantic_class": "scenery", "yaw_mode": "free"},
    "act2-library-arch": {"scale": 2.2, "semantic_class": "arch_passable", "yaw_mode": "free"},
    "act2-sunken-shelf-mass": {"scale": 4.6, "semantic_class": "scenery", "yaw_mode": "free"},
    "act2-lure-lantern-post": {"scale": 3.2, "semantic_class": "scenery", "yaw_mode": "free"},
    "act3-obsidian-blade": {"scale": 6.2, "semantic_class": "scenery", "yaw_mode": "free"},
    "act3-broken-halo": {"scale": 2.8, "semantic_class": "arch_passable", "yaw_mode": "free"},
    "act3-court-plinth": {"scale": 2.2, "semantic_class": "scenery", "yaw_mode": "free"},
    "act3-shattered-wall-mass": {"scale": 4.6, "semantic_class": "scenery", "yaw_mode": "free"},
    "act3-star-eye-mass": {"scale": 3.2, "semantic_class": "scenery", "yaw_mode": "free"},
    "act4-mirror-road-slab": {"scale": 6.2, "semantic_class": "scenery", "yaw_mode": "free"},
    "act4-standing-pair": {"scale": 2.8, "semantic_class": "scenery", "yaw_mode": "free"},
    "act4-reverse-hearth-arch": {"scale": 2.2, "semantic_class": "arch_passable", "yaw_mode": "free"},
    "act4-threshold-buttress": {"scale": 4.6, "semantic_class": "scenery", "yaw_mode": "free"},
    "act4-pale-fractured-mass": {"scale": 3.2, "semantic_class": "scenery", "yaw_mode": "free"},
    "act1-terminus": {"scale": 3.6, "semantic_class": "hero", "yaw_mode": "fixed", "yaw_degrees": 0.0},
    "act1-vigil": {"scale": 7.0, "semantic_class": "hero", "yaw_mode": "fixed", "yaw_degrees": -46.0},
    "act2-terminus": {"scale": 3.6, "semantic_class": "hero", "yaw_mode": "fixed", "yaw_degrees": 0.0},
    "act3-terminus": {"scale": 3.6, "semantic_class": "hero", "yaw_mode": "fixed", "yaw_degrees": 0.0},
    "act4-terminus": {"scale": 3.6, "semantic_class": "hero", "yaw_mode": "fixed", "yaw_degrees": 0.0}
  },
  "profile_overrides": {},
  "assets": ['''


PROFILE_CHECKER = r'''
PROFILE_SEMANTICS = {"road", "scenery", "hero", "arch_passable"}
PROFILE_YAW_MODES = {"free", "road_aligned", "fixed"}
PROFILE_DEFAULT_KEYS = {"scale", "semantic_class", "yaw_mode", "yaw_degrees"}
PROFILE_OVERRIDE_KEYS = {"footprint", "reason"}


def _finite_number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) \
        and math.isfinite(float(value))


def profile_findings(path: Path, defaults: Any, overrides: Any,
                     rows: list[dict[str, Any]]) -> list[Finding]:
    found: list[Finding] = []
    mesh_ids = {str(row.get("id")) for row in rows
                if row.get("kind") in {"kit", "terminus", "threshold"}}
    where = f"{path} profile_defaults"
    if not isinstance(defaults, dict):
        return [Finding("manifest", where, "profile_defaults must be an object")]
    default_ids = {str(asset_id) for asset_id in defaults}
    missing = sorted(mesh_ids - default_ids)
    unknown = sorted(default_ids - mesh_ids)
    if missing:
        found.append(Finding("manifest", where, f"missing mesh asset IDs {missing}"))
    if unknown:
        found.append(Finding("manifest", where, f"unknown mesh asset IDs {unknown}"))
    for raw_id, raw in defaults.items():
        asset_id = str(raw_id)
        item_where = f"{where}[{asset_id!r}]"
        if not isinstance(raw, dict):
            found.append(Finding("manifest", item_where, "default must be an object"))
            continue
        extra = sorted(set(raw) - PROFILE_DEFAULT_KEYS)
        if extra:
            found.append(Finding("manifest", item_where, f"unknown fields {extra}"))
        scale = raw.get("scale")
        semantic = raw.get("semantic_class")
        yaw_mode = raw.get("yaw_mode")
        if not _finite_number(scale) or float(scale) <= 0.0:
            found.append(Finding("manifest", item_where,
                                 "scale must be a positive finite number"))
        if semantic not in PROFILE_SEMANTICS:
            found.append(Finding("manifest", item_where,
                                 f"semantic_class must be one of {sorted(PROFILE_SEMANTICS)}"))
        if yaw_mode not in PROFILE_YAW_MODES:
            found.append(Finding("manifest", item_where,
                                 f"yaw_mode must be one of {sorted(PROFILE_YAW_MODES)}"))
        if yaw_mode == "fixed":
            if not _finite_number(raw.get("yaw_degrees")):
                found.append(Finding("manifest", item_where,
                                     "fixed yaw requires finite yaw_degrees"))
        elif "yaw_degrees" in raw:
            found.append(Finding("manifest", item_where,
                                 "yaw_degrees is only valid for fixed yaw"))
        expected_yaw = {
            "road": "road_aligned",
            "hero": "fixed",
            "scenery": "free",
            "arch_passable": "free",
        }.get(semantic)
        if expected_yaw is not None and yaw_mode != expected_yaw:
            found.append(Finding("manifest", item_where,
                                 f"{semantic} requires yaw_mode {expected_yaw}"))
    override_where = f"{path} profile_overrides"
    if not isinstance(overrides, dict):
        found.append(Finding("manifest", override_where,
                             "profile_overrides must be an object"))
        return found
    for raw_id, raw in overrides.items():
        asset_id = str(raw_id)
        item_where = f"{override_where}[{asset_id!r}]"
        if asset_id not in mesh_ids:
            found.append(Finding("manifest", item_where, "unknown mesh asset ID"))
        if not isinstance(raw, dict):
            found.append(Finding("manifest", item_where, "override must be an object"))
            continue
        extra = sorted(set(raw) - PROFILE_OVERRIDE_KEYS)
        if extra:
            found.append(Finding("manifest", item_where, f"unknown fields {extra}"))
        reason = raw.get("reason")
        if not isinstance(reason, str) or not reason.strip():
            found.append(Finding("manifest", item_where,
                                 "override reason must be non-empty"))
        polygon_error = _profile_polygon_error(raw.get("footprint"))
        if polygon_error:
            found.append(Finding("manifest", item_where, polygon_error))
    return found


def _profile_polygon_error(raw: Any) -> str:
    if not isinstance(raw, list):
        return "footprint must be an array"
    points: list[tuple[float, float]] = []
    for item in raw:
        if not isinstance(item, list) or len(item) != 2 \
                or not all(_finite_number(value) for value in item):
            return "footprint points must be finite [x,z] pairs"
        point = (float(item[0]), float(item[1]))
        if not points or point != points[-1]:
            points.append(point)
    if len(points) > 1 and points[0] == points[-1]:
        points.pop()
    if len(points) < 3 or len(set(points)) != len(points):
        return "footprint must contain at least three unique points"
    area = 0.0
    turn_sign = 0.0
    for index, point in enumerate(points):
        a = points[(index + 1) % len(points)]
        b = points[(index + 2) % len(points)]
        area += point[0] * a[1] - point[1] * a[0]
        turn = (a[0] - point[0]) * (b[1] - a[1]) \
            - (a[1] - point[1]) * (b[0] - a[0])
        if abs(turn) <= 1e-9:
            continue
        if turn_sign and math.copysign(1.0, turn) != math.copysign(1.0, turn_sign):
            return "footprint must be convex"
        turn_sign = turn
    if abs(area) <= 1e-9 or not turn_sign:
        return "footprint must have non-zero area"
    return ""
'''


PROFILE_SELF_TESTS = r'''
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
'''


def patch_manifest() -> None:
    path = ROOT / "assets/art/map/map-assets.json"
    text = path.read_text()
    text = replace_once(
        text,
        '''  "schema_version": 1,
  "asset_root": "res://assets/art/map/",
  "assets": [''',
        PROFILE_MANIFEST,
        "manifest profile schema",
    )
    path.write_text(text)


def patch_materials() -> None:
    path = ROOT / "presentation/map/map_materials.gd"
    text = path.read_text()
    text = replace_once(
        text,
        '''\tvar threshold: Resource = null
\tvar vigil_mean: float = 0.252''',
        '''\tvar threshold: Resource = null
\tvar threshold_id: String = ""
\tvar vigil_mean: float = 0.252''',
        "threshold ID variable",
    )
    text = replace_once(
        text,
        '''\t\t\t"threshold":
\t\t\t\tthreshold = resource
\t\t\t\tvigil_mean = _row_float(row, "tex_mean", 0.252)''',
        '''\t\t\t"threshold":
\t\t\t\tthreshold = resource
\t\t\t\tthreshold_id = _row_string(row, "id")
\t\t\t\tvigil_mean = _row_float(row, "tex_mean", 0.252)''',
        "threshold ID bind",
    )
    text = replace_once(
        text,
        '''\t\t"threshold": threshold,
\t\t"ground_tile": ground_tile''',
        '''\t\t"threshold": threshold, "threshold_id": threshold_id,
\t\t"ground_tile": ground_tile''',
        "threshold ID result",
    )
    path.write_text(text)


def patch_checker() -> None:
    path = ROOT / "tools/map_asset_checks.py"
    text = path.read_text()
    text = replace_once(
        text,
        '''class Finding(NamedTuple):
    gate: str
    path: str
    detail: str

    def __str__(self) -> str:
        return f"{self.gate:16} {self.path}  {self.detail}"
''',
        '''class Finding(NamedTuple):
    gate: str
    path: str
    detail: str

    def __str__(self) -> str:
        return f"{self.gate:16} {self.path}  {self.detail}"
''' + PROFILE_CHECKER + "\n",
        "profile checker helpers",
    )
    text = replace_once(
        text,
        '''    if not isinstance(data, dict) or data.get("schema_version") != 1:
        return [], [Finding("manifest", str(path), "schema_version must be 1")]
    if data.get("asset_root") != "res://assets/art/map/":''',
        '''    if not isinstance(data, dict) or data.get("schema_version") != 2:
        return [], [Finding("manifest", str(path), "schema_version must be 2")]
    allowed_top = {
        "schema_version", "asset_root", "profile_defaults",
        "profile_overrides", "assets",
    }
    unknown_top = sorted(set(data) - allowed_top)
    if unknown_top:
        found.append(Finding("manifest", str(path),
                             f"unknown fields {unknown_top}"))
    if data.get("asset_root") != "res://assets/art/map/":''',
        "manifest schema and top-level fields",
    )
    text = replace_once(
        text,
        '''    for kind, expected in EXPECTED_COUNTS.items():''',
        '''    found.extend(profile_findings(
        path, data.get("profile_defaults"), data.get("profile_overrides"), rows))
    for kind, expected in EXPECTED_COUNTS.items():''',
        "manifest profile validation call",
    )
    path.write_text(text)


def patch_self_test() -> None:
    path = ROOT / "tools/map_asset_self_test.py"
    text = path.read_text()
    text = replace_once(
        text,
        '''        if findings or present != 0:
            errors.append(f"empty planned payload failed: {findings}/{present}")
        (contract / "notes.txt").write_text("undeclared")''',
        '''        if findings or present != 0:
            errors.append(f"empty planned payload failed: {findings}/{present}")
''' + PROFILE_SELF_TESTS + '''
        (contract / "notes.txt").write_text("undeclared")''',
        "profile manifest self-tests",
    )
    path.write_text(text)


def patch_ci() -> None:
    path = ROOT / ".github/workflows/ci.yml"
    text = path.read_text()
    text = replace_once(
        text,
        '''      - name: Run tests
        run: godot --headless -s res://tests/run_all.gd
''',
        '''      - name: Run tests
        run: godot --headless -s res://tests/run_all.gd

      - name: Probe shared map asset profiles
        run: godot --headless -s res://tools/probe_map_seeds.gd -- --seeds=20
''',
        "profile probe CI",
    )
    path.write_text(text)


patch_manifest()
patch_materials()
patch_checker()
patch_self_test()
patch_ci()
