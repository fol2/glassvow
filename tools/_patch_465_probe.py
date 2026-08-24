from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one match, found {count}")
    return text.replace(old, new, 1)


def replace_span(text: str, start: str, end: str, new: str, label: str) -> str:
    a = text.find(start)
    if a < 0:
        raise RuntimeError(f"{label}: start not found")
    b = text.find(end, a)
    if b < 0:
        raise RuntimeError(f"{label}: end not found")
    b += len(end)
    return text[:a] + new + text[b:]


path = ROOT / "tools/probe_map_seeds.gd"
text = path.read_text()
text = replace_span(
    text,
    "## WHY IT REBUILDS THE SCENERY LIST INSTEAD OF ASKING MapScene FOR IT.",
    "const VIGIL_HALF: Vector2 = Vector2(4.25, 4.27)",
    '''## The probe still rebuilds placements headlessly, but MapAssetProfiles is
## now the one source for mesh identity, scale, footprint and hide-depth facts.
## It loads only Act I's active set, matching runtime residency.
const ACT: int = 0
const KINDS: int = 6''',
    "probe profile authority header",
)
text = replace_once(
    text,
    '''\tvar boxes: Array[AABB] = []
\tfor path: String in KIT_PATHS:
\t\tboxes.append(_aabb(path))
\tvar scene: MapScene = MapScene.new()
\tvar content: ContentDB = ContentDB.load_slice()''',
    '''\tvar registry: MapAssetProfiles = MapAssetProfiles.new()
\tvar by_id: Dictionary[String, Dictionary] = {}
\tvar active_profiles: Array[Dictionary] = []
\tfor asset_id: String in registry.ids_for_act(ACT):
\t\tvar resource: Resource = load(registry.resource_path(asset_id))
\t\tvar value: Dictionary = registry.profile(asset_id, _mesh(resource))
\t\tif value.is_empty():
\t\t\tpush_error("map profile failed: %s" % asset_id)
\t\t\tquit(2)
\t\t\treturn
\t\tby_id[asset_id] = value
\t\tactive_profiles.append(value)
\tvar kit_profiles: Array[Dictionary] = []
\tfor asset_id: String in registry.ids_for_act(ACT, "kit"):
\t\tkit_profiles.append(by_id[asset_id])
\tvar scene: MapScene = MapScene.new()
\tvar profile_digest: String = registry.digest(active_profiles)
\tif profile_digest.is_empty() or profile_digest != scene.asset_profile_digest():
\t\tpush_error("runtime/probe map profile digest mismatch")
\t\tscene.free()
\t\tquit(2)
\t\treturn
\tvar content: ContentDB = ContentDB.load_slice()''',
    "probe profile setup",
)
text = replace_once(
    text,
    "\tvar vc: Vector2 = MapScene.THRESHOLD_XZ",
    '''\tvar vigil: Dictionary = by_id["act1-vigil"]
\tvar vigil_position: Vector3 = Vector3(
\t\t\tMapScene.THRESHOLD_XZ.x, 0.0, MapScene.THRESHOLD_XZ.y)
\tvar vigil_scale: float = registry.default_scale(vigil)
\tvar vigil_points: PackedVector2Array = registry.transformed_footprint(
\t\t\tvigil, vigil_position, registry.fixed_yaw(vigil),
\t\t\tVector3.ONE * vigil_scale)
\tvar vigil_rect: Rect2 = _bounds(vigil_points)''',
    "probe Vigil profile footprint",
)
text = replace_once(
    text,
    "\t\tvar pieces: Array[Vector4] = _pieces(scene, scene.prop_positions(), boxes)",
    '''\t\tvar pieces: Array[Vector4] = _pieces(
\t\t\t\tscene, scene.prop_positions(), kit_profiles, registry)''',
    "probe profile envelope call",
)
text = replace_once(
    text,
    "\t\t\tif absf(w.x - vc.x) < VIGIL_HALF.x and absf(w.z - vc.y) < VIGIL_HALF.y:",
    "\t\t\tif vigil_rect.has_point(Vector2(w.x, w.z)):",
    "probe Vigil protected footprint",
)
text = replace_once(
    text,
    "\tprint(\"=== %d seeds, Act I ===\" % seeds)",
    '''\tprint("=== %d seeds, Act I ===" % seeds)
\tprint("asset profile digest : %s" % profile_digest)''',
    "probe digest evidence",
)
text = replace_span(
    text,
    "## Radius and hide-depth are repeated from MapScene._bind_asset_geometry -- see",
    "\treturn out\n\n\n## The same directional test MapPinProjection._off_scenery makes:",
    '''## Build the compatibility envelopes through the shared authority. Which
## species occupies a seat remains MapScene's deterministic placement decision.
func _pieces(scene: MapScene, seats: PackedVector3Array,
\t\tprofiles: Array[Dictionary], registry: MapAssetProfiles) -> Array[Vector4]:
\tvar out: Array[Vector4] = []
\tfor j: int in range(seats.size()):
\t\tvar kit: int = scene.seat_kit(j, KINDS)
\t\tout.append(registry.directional_envelope(profiles[kit], seats[j]))
\treturn out


## The same directional test MapPinProjection._off_scenery makes:''',
    "probe removes duplicated formula",
)
text = replace_span(
    text,
    "func _aabb(path: String) -> AABB:",
    "\treturn null",
    '''func _mesh(resource: Resource) -> Mesh:
\tif resource is Mesh:
\t\treturn resource as Mesh
\tif not (resource is PackedScene):
\t\treturn null
\tvar root: Node = (resource as PackedScene).instantiate()
\tvar mesh_node: MeshInstance3D = _first_mesh(root)
\tvar mesh: Mesh = null
\tif mesh_node != null:
\t\tmesh = mesh_node.mesh
\troot.free()
\treturn mesh


func _first_mesh(root: Node) -> MeshInstance3D:
\tif root is MeshInstance3D:
\t\treturn root as MeshInstance3D
\tfor child: Node in root.get_children():
\t\tvar found: MeshInstance3D = _first_mesh(child)
\t\tif found != null:
\t\t\treturn found
\treturn null


func _bounds(points: PackedVector2Array) -> Rect2:
\tif points.is_empty():
\t\treturn Rect2()
\tvar out: Rect2 = Rect2(points[0], Vector2.ZERO)
\tfor point: Vector2 in points:
\t\tout = out.expand(point)
\treturn out''',
    "probe mesh and footprint helpers",
)
path.write_text(text)
