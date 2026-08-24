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


path = ROOT / "presentation/map/map_scene.gd"
text = path.read_text()
text = replace_span(text,
    "## Metres each unit-scale kit is grown to, indexed as the manifest orders them:",
    "const HIDE_PER_HEIGHT: float = 1.19",
    '''## Hero anchors and road spacing remain placement facts; mesh scale, yaw policy,
## footprint and occlusion facts live only in MapAssetProfiles.
const THRESHOLD_XZ: Vector2 = Vector2(-41.3, 6.5)
const ROAD_STEP: float = 0.95''', "scene profile-owned constants")
text = replace_once(text, 'var _asset_geometry: Node3D\nvar _road_meshes: Array[Mesh] = []',
    'var _asset_geometry: Node3D\nvar _asset_profiles: MapAssetProfiles\nvar _active_profile_digest: String = ""\nvar _road_meshes: Array[Mesh] = []\nvar _road_profiles: Array[Dictionary] = []', "scene profile vars")
text = replace_once(text, '\t_materials = MapMaterials.new(_key.basis.z, _rig.zoom_stop, manifest, resource_loader)',
    '\t_asset_profiles = MapAssetProfiles.new(manifest)\n\t_materials = MapMaterials.new(_key.basis.z, _rig.zoom_stop, manifest, resource_loader)', "scene profile init")
text = replace_once(text, 'func active_asset_resources() -> Array[Resource]:\n\treturn _materials.active_asset_resources()\n',
    'func active_asset_resources() -> Array[Resource]:\n\treturn _materials.active_asset_resources()\n\n\nfunc asset_profile_digest() -> String:\n\treturn _active_profile_digest\n', "scene digest getter")
text = replace_once(text, '\t_road_meshes.clear()\n\t# Nothing is standing yet',
    '\t_road_meshes.clear()\n\t_road_profiles.clear()\n\t_active_profile_digest = ""\n\t# Nothing is standing yet', "scene clear profiles")
text = replace_once(text,
    '\tvar raw_kits: Variant = assets.get("kits", [])\n\tvar raw_terminus: Variant = assets.get("terminus", null)\n\tif not (raw_kits is Array) or not (raw_terminus is Resource):',
    '\tvar raw_kits: Variant = assets.get("kits", [])\n\tvar raw_kit_ids: Variant = assets.get("kit_ids", PackedStringArray())\n\tvar raw_terminus: Variant = assets.get("terminus", null)\n\tvar terminus_id: String = str(assets.get("terminus_id", ""))\n\tif not (raw_kits is Array) or not (raw_kit_ids is PackedStringArray) \\\n\t\t\tor not (raw_terminus is Resource):', "scene raw ids")
old_meshes = '''\tvar meshes: Array[Mesh] = []
\tfor raw: Variant in kit_resources:
\t\tif not (raw is Resource):
\t\t\treturn
\t\tvar resource: Resource = raw
\t\tvar mesh: Mesh = _mesh_from(resource)
\t\tif mesh == null:
\t\t\treturn
\t\tmeshes.append(mesh)
\tvar terminus_resource: Resource = raw_terminus
\tvar terminus_mesh: Mesh = _mesh_from(terminus_resource)
\tif terminus_mesh == null:
\t\treturn'''
new_meshes = '''\tvar kit_ids: PackedStringArray = raw_kit_ids
\tif kit_ids.size() != 8: return
\tvar meshes: Array[Mesh] = []
\tvar profiles: Array[Dictionary] = []
\tfor i: int in range(kit_resources.size()):
\t\tvar raw: Variant = kit_resources[i]
\t\tif not (raw is Resource): return
\t\tvar resource: Resource = raw
\t\tvar mesh: Mesh = _mesh_from(resource)
\t\tvar value: Dictionary = _asset_profiles.profile(kit_ids[i], mesh)
\t\tif mesh == null or value.is_empty(): return
\t\tmeshes.append(mesh); profiles.append(value)
\tvar terminus_resource: Resource = raw_terminus
\tvar terminus_mesh: Mesh = _mesh_from(terminus_resource)
\tvar terminus_profile: Dictionary = _asset_profiles.profile(terminus_id, terminus_mesh)
\tif terminus_mesh == null or terminus_profile.is_empty(): return
\tvar active_profiles: Array[Dictionary] = []
\tactive_profiles.assign(profiles)
\tactive_profiles.append(terminus_profile)
\tvar raw_threshold: Variant = assets.get("threshold", null)
\tvar threshold_mesh: Mesh = null
\tvar threshold_profile: Dictionary = {}
\tif raw_threshold is Resource:
\t\tvar threshold_resource: Resource = raw_threshold
\t\tthreshold_mesh = _mesh_from(threshold_resource)
\t\tthreshold_profile = _asset_profiles.profile(str(assets.get("threshold_id", "")), threshold_mesh)
\t\tif threshold_mesh == null or threshold_profile.is_empty(): return
\t\tactive_profiles.append(threshold_profile)
\t_active_profile_digest = _asset_profiles.digest(active_profiles)
\tif _active_profile_digest.is_empty(): return'''
text = replace_once(text, old_meshes, new_meshes, "scene build profiles")
text = replace_once(text, '\t_road_meshes = [meshes[0], meshes[1]]',
    '\t_road_meshes = [meshes[0], meshes[1]]\n\t_road_profiles = [profiles[0], profiles[1]]', "scene road profiles")
text = replace_once(text,
    '\t\t_add_multimesh(_asset_geometry, "AssetKit%02d" % i, meshes[i], placements,\n\t\t\t\ti * 7 + _dress_salt(), KIT_SCALE[i])',
    '\t\t_add_multimesh(_asset_geometry, "AssetKit%02d" % i, meshes[i], placements,\n\t\t\t\ti * 7 + _dress_salt(), _asset_profiles.default_scale(profiles[i]))', "scene kit scale")
old_pieces = '''\t# Tell the projection what now stands where, so the nodes can step out
\t# from behind it. Radius takes the wider of x and z because yaw can swing
\t# one into the other; depth is how much ground the piece's own height
\t# hides at the camera's tilt.
\t#
\t# BOTH of those are per-SPECIES, which is why this reads `_seat_kit` rather
\t# than repeating the arithmetic. It used to repeat it, and when the salt
\t# arrived only the placement loop above was updated: five run seeds in six
\t# then published a 6.2 m ash trunk as whatever the unsalted rotation
\t# happened to name, so the solver stepped nodes around footprints belonging
\t# to trees that were not there.
\tvar pieces: Array[Vector4] = []
\tfor j: int in range(positions.size()):
\t\tvar kit: int = seat_kit(j, kinds)
\t\tvar box: AABB = meshes[kit].get_aabb()
\t\tvar unit: float = KIT_SCALE[kit]
\t\tpieces.append(Vector4(positions[j].x, positions[j].z,
\t\t\t\tmaxf(box.size.x, box.size.z) * 0.5 * unit,
\t\t\t\tbox.size.y * unit * HIDE_PER_HEIGHT))'''
new_pieces = '''\t# MapAssetProfiles owns both the future polygon and this build-4-compatible
\t# directional envelope; runtime and probes cannot drift formulas again.
\tvar pieces: Array[Vector4] = []
\tfor j: int in range(positions.size()):
\t\tvar kit: int = seat_kit(j, kinds)
\t\tpieces.append(_asset_profiles.occlusion_piece(profiles[kit], positions[j]))'''
text = replace_once(text, old_pieces, new_pieces, "scene occlusion authority")
text = replace_once(text, '\tterminus.scale = Vector3.ONE * TERMINUS_SCALE',
    '\tterminus.scale = Vector3.ONE * _asset_profiles.default_scale(terminus_profile)', "scene terminus scale")
text = replace_once(text,
    '''\tvar raw_threshold: Variant = assets.get("threshold", null)
\tif raw_threshold is Resource:
\t\tvar gate_res: Resource = raw_threshold
\t\tvar gate_mesh: Mesh = _mesh_from(gate_res)
\t\tif gate_mesh != null:''',
    '''\tif threshold_mesh != null:
\t\tvar gate_mesh: Mesh = threshold_mesh
\t\tif not threshold_profile.is_empty():''', "scene threshold preprofile")
text = replace_once(text,
    '\t\t\tgate.rotation_degrees = Vector3(0.0, THRESHOLD_YAW, 0.0)\n\t\t\tgate.scale = Vector3.ONE * THRESHOLD_SCALE',
    '\t\t\tgate.rotation_degrees = Vector3(0.0, _asset_profiles.fixed_yaw(threshold_profile), 0.0)\n\t\t\tgate.scale = Vector3.ONE * _asset_profiles.default_scale(threshold_profile)', "scene threshold transform")
text = replace_once(text, 'func _build_road() -> void:\n\tif _asset_geometry == null or _road_meshes.size() < 2:',
    'func _build_road() -> void:\n\tif _asset_geometry == null or _road_meshes.size() < 2 or _road_profiles.size() < 2:', "scene road profile guard")
text = replace_once(text,
    '\t\tvar node: MultiMeshInstance3D = _road_multimesh(\n\t\t\t\t_road_meshes[m], laid[m], yaws[m], m)',
    '\t\tvar node: MultiMeshInstance3D = _road_multimesh(\n\t\t\t\t_road_meshes[m], laid[m], yaws[m], m, _road_profiles[m])', "scene road profile call")
text = replace_once(text,
    'func _road_multimesh(mesh: Mesh, positions: PackedVector3Array,\n\t\tyaws: PackedFloat32Array, seed_index: int) -> MultiMeshInstance3D:',
    'func _road_multimesh(mesh: Mesh, positions: PackedVector3Array,\n\t\tyaws: PackedFloat32Array, seed_index: int, profile: Dictionary) -> MultiMeshInstance3D:', "scene road profile signature")
text = replace_once(text,
    '''\t\tvar scale: Vector3 = Vector3(
\t\t\t\tROAD_SCALE * (1.0 + wobble),
\t\t\t\tROAD_SCALE * 0.6,
\t\t\t\tROAD_SCALE * (1.0 - wobble))''',
    '''\t\tvar unit: float = _asset_profiles.default_scale(profile)
\t\tvar scale: Vector3 = Vector3(
\t\t\t\tunit * (1.0 + wobble), unit * 0.6, unit * (1.0 - wobble))''', "scene road scale")
path.write_text(text)
