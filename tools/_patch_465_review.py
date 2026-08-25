from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one match, found {count}")
    return text.replace(old, new, 1)


profile = ROOT / "presentation/map/map_asset_profiles.gd"
text = profile.read_text()
text = replace_once(
    text,
    """\tfor surface: int in range(mesh.get_surface_count()):
\t\tcanonical.append(mesh.surface_get_primitive_type(surface))
\t\tcanonical.append(mesh.surface_get_arrays(surface))""",
    """\tfor surface: int in range(mesh.get_surface_count()):
\t\tcanonical.append(mesh.surface_get_primitive_type(surface))
\tcanonical.append(mesh.get_faces())""",
    "profile source identity",
)
text = replace_once(
    text,
    """\telse:
\t\treturn _polygon_error(\"footprint must be an array\")
\tif points.size() > 1 and points[0].is_equal_approx(points[points.size() - 1]):""",
    """\telse:
\t\treturn _polygon_error(\"footprint must be an array\")
\tfor point: Vector2 in points:
\t\tif not is_finite(point.x) or not is_finite(point.y):
\t\t\treturn _polygon_error(\"point must be finite\")
\tif points.size() > 1 and points[0].is_equal_approx(points[points.size() - 1]):""",
    "packed polygon finite check",
)
profile.write_text(text)


scene = ROOT / "presentation/map/map_scene.gd"
text = scene.read_text()
comments = {
    "## The fixed −46° yaw is declared by the act1-vigil profile.":
        "# Fixed yaw comes from the act1-vigil profile.",
    "## The 7.0 world scale is declared by the act1-vigil profile.":
        "# World scale comes from the act1-vigil profile.",
    "## Road slab default scale is declared by each shared-road profile.":
        "# Road slab scale comes from the shared-road profiles.",
    "## The current camera-directional hide envelope is owned by MapAssetProfiles.":
        "# The current camera-directional hide envelope is owned by MapAssetProfiles.",
}
for old_comment, new_comment in comments.items():
    text = replace_once(text, old_comment, new_comment, "scene comment")
scene.write_text(text)


tests = ROOT / "tests/test_map_asset_profiles.gd"
text = tests.read_text()
text = replace_once(
    text,
    """\t\t_check(fails,
\t\t\t\tby_id[\"shared-road-slab-a\"].get(\"semantic_class\")
\t\t\t\t\t\t== MapAssetProfiles.SEMANTIC_ROAD
\t\t\t\tand by_id[\"act1-charred-stump\"].get(\"semantic_class\")
\t\t\t\t\t\t== MapAssetProfiles.SEMANTIC_SCENERY,""",
    """\t\t_check(fails,
\t\t\t\tstr(by_id[\"shared-road-slab-a\"].get(\"semantic_class\", \"\"))
\t\t\t\t\t\t== MapAssetProfiles.SEMANTIC_ROAD
\t\t\t\tand str(by_id[\"act1-charred-stump\"].get(\"semantic_class\", \"\"))
\t\t\t\t\t\t== MapAssetProfiles.SEMANTIC_SCENERY,""",
    "road semantic test typing",
)
text = replace_once(
    text,
    """\t\t_check(fails,
\t\t\t\tby_id[\"act1-vigil\"].get(\"semantic_class\")
\t\t\t\t\t\t== MapAssetProfiles.SEMANTIC_HERO
\t\t\t\tand by_id[\"act1-terminus\"].get(\"semantic_class\")
\t\t\t\t\t\t== MapAssetProfiles.SEMANTIC_HERO,""",
    """\t\t_check(fails,
\t\t\t\tstr(by_id[\"act1-vigil\"].get(\"semantic_class\", \"\"))
\t\t\t\t\t\t== MapAssetProfiles.SEMANTIC_HERO
\t\t\t\tand str(by_id[\"act1-terminus\"].get(\"semantic_class\", \"\"))
\t\t\t\t\t\t== MapAssetProfiles.SEMANTIC_HERO,""",
    "hero semantic test typing",
)
text = replace_once(
    text,
    """\t_check(fails, canonical_clockwise.get(\"points\") == canonical_counter.get(\"points\"),
\t\t\t\"clockwise, counter-clockwise and closing/consecutive duplicates canonicalise\")""",
    """\t_check(fails, _packed_vector2_value(canonical_clockwise, \"points\")
\t\t\t== _packed_vector2_value(canonical_counter, \"points\"),
\t\t\t\"clockwise, counter-clockwise and closing/consecutive duplicates canonicalise\")""",
    "polygon equality test typing",
)
text = replace_once(
    text,
    "static func _bool_value(source: Dictionary, key: String, fallback: bool) -> bool:",
    """static func _packed_vector2_value(
\t\tsource: Dictionary, key: String) -> PackedVector2Array:
\tvar raw: Variant = source.get(key, PackedVector2Array())
\tif raw is PackedVector2Array:
\t\tvar value: PackedVector2Array = raw
\t\treturn value
\treturn PackedVector2Array()


static func _bool_value(source: Dictionary, key: String, fallback: bool) -> bool:""",
    "typed polygon test helper",
)
tests.write_text(text)
