from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

PROBE_PIECES = '## Profiles, scales and the build-4 envelope all come from MapAssetProfiles.\nfunc _pieces(scene: MapScene, seats: PackedVector3Array,\n\t\tprofiles: Array[Dictionary], registry: MapAssetProfiles) -> Array[Vector4]:\n\tvar out: Array[Vector4] = []\n\tfor j: int in range(seats.size()):\n\t\tvar kit: int = scene.seat_kit(j, KINDS)\n\t\tout.append(registry.occlusion_piece(profiles[kit], seats[j]))\n\treturn out\n'


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
text = replace_span(text, '## WHY IT REBUILDS THE SCENERY LIST INSTEAD OF ASKING MapScene FOR IT.',
    'const VIGIL_HALF: Vector2 = Vector2(4.25, 4.27)',
    '''## MapAssetProfiles is the one geometry authority. This probe still rebuilds
## the placement list headlessly, but never radius, height or footprint arithmetic.
const ACT: int = 0
const KINDS: int = 6''', "probe header")
old_setup = '''\tvar boxes: Array[AABB] = []
\tfor path: String in KIT_PATHS:
\t\tboxes.append(_aabb(path))
\tvar scene: MapScene = MapScene.new()
\tvar content: ContentDB = ContentDB.load_slice()'''
new_setup = '''\tvar registry: MapAssetProfiles = MapAssetProfiles.new()
\tvar by_id: Dictionary[String, Dictionary] = {}
\tvar active_profiles: Array[Dictionary] = []
\tfor asset_id: String in registry.ids_for_act(ACT):
\t\tvar mesh: Mesh = _mesh(load(registry.resource_path(asset_id)))
\t\tvar value: Dictionary = registry.profile(asset_id, mesh)
\t\tif value.is_empty():
\t\t\tpush_error("profile failed: %s" % asset_id); quit(2); return
\t\tby_id[asset_id] = value; active_profiles.append(value)
\tvar kit_profiles: Array[Dictionary] = []
\tfor asset_id: String in registry.ids_for_act(ACT, "kit"): kit_profiles.append(by_id[asset_id])
\tvar scene: MapScene = MapScene.new()
\tvar profile_digest: String = registry.digest(active_profiles)
\tif profile_digest.is_empty() or profile_digest != scene.asset_profile_digest():
\t\tpush_error("runtime/probe profile digest mismatch"); scene.free(); quit(2); return
\tvar content: ContentDB = ContentDB.load_slice()'''
text = replace_once(text, old_setup, new_setup, "probe profile setup")
text = replace_once(text, '\tvar vc: Vector2 = MapScene.THRESHOLD_XZ',
    '''\tvar vigil: Dictionary = by_id["act1-vigil"]
\tvar vigil_basis: Basis = Basis(Vector3.UP, deg_to_rad(registry.fixed_yaw(vigil))).scaled(
\t\t\tVector3.ONE * registry.default_scale(vigil))
\tvar vigil_rect: Rect2 = _bounds(registry.world_footprint(vigil,
\t\t\tTransform3D(vigil_basis, Vector3(MapScene.THRESHOLD_XZ.x, 0.0, MapScene.THRESHOLD_XZ.y))))''', "probe vigil footprint")
text = replace_once(text, '\t\tvar pieces: Array[Vector4] = _pieces(scene, scene.prop_positions(), boxes)',
    '\t\tvar pieces: Array[Vector4] = _pieces(scene, scene.prop_positions(), kit_profiles, registry)', "probe pieces call")
text = replace_once(text, '\t\t\tif absf(w.x - vc.x) < VIGIL_HALF.x and absf(w.z - vc.y) < VIGIL_HALF.y:',
    '\t\t\tif vigil_rect.has_point(Vector2(w.x, w.z)):', "probe vigil check")
text = replace_once(text, '\tprint("=== %d seeds, Act I ===" % seeds)',
    '\tprint("=== %d seeds, Act I ===" % seeds)\n\tprint("asset profile digest : %s" % profile_digest)', "probe digest output")
text = replace_span(text, '## Radius and hide-depth are repeated from MapScene._bind_asset_geometry -- see',
    '\treturn out\n\n\n## The same directional test MapPinProjection._off_scenery makes:',
    PROBE_PIECES.rstrip() + '\n\n\n## The same directional test MapPinProjection._off_scenery makes:', "probe pieces function")
text = replace_span(text, 'func _aabb(path: String) -> AABB:', '\treturn null',
    '''func _mesh(resource: Resource) -> Mesh:
\tif resource is Mesh: return resource as Mesh
\tif not (resource is PackedScene): return null
\tvar root: Node = (resource as PackedScene).instantiate()
\tvar mesh_node: MeshInstance3D = _first_mesh(root)
\tvar mesh: Mesh = mesh_node.mesh if mesh_node != null else null
\troot.free(); return mesh


func _first_mesh(root: Node) -> MeshInstance3D:
\tif root is MeshInstance3D: return root as MeshInstance3D
\tfor child: Node in root.get_children():
\t\tvar found: MeshInstance3D = _first_mesh(child)
\t\tif found != null: return found
\treturn null


func _bounds(points: PackedVector2Array) -> Rect2:
\tvar out: Rect2 = Rect2(points[0], Vector2.ZERO)
\tfor point: Vector2 in points: out = out.expand(point)
\treturn out''', "probe mesh/bounds helper")
path.write_text(text)
