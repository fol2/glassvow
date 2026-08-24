from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one match, found {count}")
    return text.replace(old, new, 1)


path = ROOT / "presentation/map/map_scene.gd"
text = path.read_text()
text = replace_once(
    text,
    '''## Metres each unit-scale kit is grown to, indexed as the manifest orders them:
## road-slab-a, road-slab-b, standing-monument, ash-trunk-fork, root-wedge,
## charred-stump, fallen-bough-arch, ash-cairn-mass.
const KIT_SCALE: Array[float] = [3.0, 3.0, 3.4, 6.2, 2.8, 2.2, 4.6, 3.2]
const TERMINUS_SCALE: float = 3.6
''',
    '''## Mesh scale, yaw policy, semantic class, footprint and occlusion facts
## are owned by MapAssetProfiles and keyed by manifest asset ID.
''',
    "scene profile-owned scale constants",
)
text = replace_once(
    text,
    "const THRESHOLD_YAW: float = -46.0",
    "## The fixed −46° yaw is declared by the act1-vigil profile.",
    "scene threshold yaw authority",
)
text = replace_once(
    text,
    "const THRESHOLD_SCALE: float = 7.0",
    "## The 7.0 world scale is declared by the act1-vigil profile.",
    "scene threshold scale authority",
)
text = replace_once(
    text,
    "const ROAD_SCALE: float = 2.15",
    "## Road slab default scale is declared by each shared-road profile.",
    "scene road scale authority",
)
text = replace_once(
    text,
    '''## Metres of ground a piece of scenery hides per metre of its own height, at
## the camera's tilt: 1 / tan(40°).
const HIDE_PER_HEIGHT: float = 1.19
''',
    '''## The current camera-directional hide envelope is owned by MapAssetProfiles.
''',
    "scene hide-depth authority",
)
text = text.replace("`THRESHOLD_SCALE`", "the `act1-vigil` profile scale")
text = replace_once(
    text,
    '''var _asset_geometry: Node3D
var _road_meshes: Array[Mesh] = []''',
    '''var _asset_geometry: Node3D
var _asset_profiles: MapAssetProfiles
var _active_profile_digest: String = ""
var _road_meshes: Array[Mesh] = []
var _road_profiles: Array[Dictionary] = []''',
    "scene profile members",
)
text = replace_once(
    text,
    "\t_materials = MapMaterials.new(_key.basis.z, _rig.zoom_stop, manifest, resource_loader)",
    "\t_asset_profiles = MapAssetProfiles.new(manifest)\n"
    "\t_materials = MapMaterials.new(_key.basis.z, _rig.zoom_stop, manifest, resource_loader)",
    "scene profile registry construction",
)
text = replace_once(
    text,
    '''func active_asset_resources() -> Array[Resource]:
\treturn _materials.active_asset_resources()
''',
    '''func active_asset_resources() -> Array[Resource]:
\treturn _materials.active_asset_resources()


func asset_profile_digest() -> String:
\treturn _active_profile_digest
''',
    "scene profile digest getter",
)
text = replace_once(
    text,
    '''\t_road_meshes.clear()
\t# Nothing is standing yet''',
    '''\t_road_meshes.clear()
\t_road_profiles.clear()
\t_active_profile_digest = ""
\t# Nothing is standing yet''',
    "scene clear active profiles",
)
text = replace_once(
    text,
    '''\tvar raw_kits: Variant = assets.get("kits", [])
\tvar raw_terminus: Variant = assets.get("terminus", null)
\tif not (raw_kits is Array) or not (raw_terminus is Resource):''',
    '''\tvar raw_kits: Variant = assets.get("kits", [])
\tvar raw_kit_ids: Variant = assets.get("kit_ids", PackedStringArray())
\tvar raw_terminus: Variant = assets.get("terminus", null)
\tvar terminus_id: String = str(assets.get("terminus_id", ""))
\tif not (raw_kits is Array) or not (raw_kit_ids is PackedStringArray) \\
\t\t\tor not (raw_terminus is Resource):''',
    "scene bound asset IDs",
)
text = replace_once(
    text,
    '''\tvar meshes: Array[Mesh] = []
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
\t\treturn''',
    '''\tvar kit_ids: PackedStringArray = raw_kit_ids
\tif kit_ids.size() != 8:
\t\treturn
\tvar meshes: Array[Mesh] = []
\tvar profiles: Array[Dictionary] = []
\tfor i: int in range(kit_resources.size()):
\t\tvar raw: Variant = kit_resources[i]
\t\tif not (raw is Resource):
\t\t\treturn
\t\tvar resource: Resource = raw
\t\tvar mesh: Mesh = _mesh_from(resource)
\t\tif mesh == null:
\t\t\treturn
\t\tvar value: Dictionary = _asset_profiles.profile(kit_ids[i], mesh)
\t\tif value.is_empty():
\t\t\treturn
\t\tmeshes.append(mesh)
\t\tprofiles.append(value)
\tvar terminus_resource: Resource = raw_terminus
\tvar terminus_mesh: Mesh = _mesh_from(terminus_resource)
\tif terminus_mesh == null:
\t\treturn
\tvar terminus_profile: Dictionary = _asset_profiles.profile(
\t\t\tterminus_id, terminus_mesh)
\tif terminus_profile.is_empty():
\t\treturn
\tvar active_profiles: Array[Dictionary] = []
\tactive_profiles.assign(profiles)
\tactive_profiles.append(terminus_profile)
\tvar raw_threshold: Variant = assets.get("threshold", null)
\tvar threshold_mesh: Mesh = null
\tvar threshold_profile: Dictionary = {}
\tif raw_threshold is Resource:
\t\tvar threshold_resource: Resource = raw_threshold
\t\tthreshold_mesh = _mesh_from(threshold_resource)
\t\tif threshold_mesh == null:
\t\t\treturn
\t\tthreshold_profile = _asset_profiles.profile(
\t\t\t\tstr(assets.get("threshold_id", "")), threshold_mesh)
\t\tif threshold_profile.is_empty():
\t\t\treturn
\t\tactive_profiles.append(threshold_profile)
\t_active_profile_digest = _asset_profiles.digest(active_profiles)
\tif _active_profile_digest.is_empty():
\t\treturn''',
    "scene build active profiles",
)
text = replace_once(
    text,
    "\t_road_meshes = [meshes[0], meshes[1]]",
    "\t_road_meshes = [meshes[0], meshes[1]]\n"
    "\t_road_profiles = [profiles[0], profiles[1]]",
    "scene road profiles",
)
text = replace_once(
    text,
    '''\t\t_add_multimesh(_asset_geometry, "AssetKit%02d" % i, meshes[i], placements,
\t\t\t\ti * 7 + _dress_salt(), KIT_SCALE[i])''',
    '''\t\t_add_multimesh(_asset_geometry, "AssetKit%02d" % i, meshes[i], placements,
\t\t\t\ti * 7 + _dress_salt(), _asset_profiles.default_scale(profiles[i]))''',
    "scene scenery scale profiles",
)
text = replace_once(
    text,
    '''\t# Tell the projection what now stands where, so the nodes can step out
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
\t\t\t\tbox.size.y * unit * HIDE_PER_HEIGHT))''',
    '''\t# Publish the build-4-compatible directional envelope from the same
\t# profiles whose polygons the compiler will consume. No second formula lives here.
\tvar pieces: Array[Vector4] = []
\tfor j: int in range(positions.size()):
\t\tvar kit: int = seat_kit(j, kinds)
\t\tpieces.append(_asset_profiles.directional_envelope(
\t\t\t\tprofiles[kit], positions[j]))''',
    "scene shared occlusion envelope",
)
text = replace_once(
    text,
    "\tterminus.scale = Vector3.ONE * TERMINUS_SCALE",
    "\tterminus.scale = Vector3.ONE * _asset_profiles.default_scale(terminus_profile)",
    "scene terminus scale profile",
)
text = replace_once(
    text,
    '''\tvar raw_threshold: Variant = assets.get("threshold", null)
\tif raw_threshold is Resource:
\t\tvar gate_res: Resource = raw_threshold
\t\tvar gate_mesh: Mesh = _mesh_from(gate_res)
\t\tif gate_mesh != null:''',
    '''\tif threshold_mesh != null and not threshold_profile.is_empty():
\t\tvar gate_mesh: Mesh = threshold_mesh''',
    "scene reuse threshold profile",
)
text = replace_once(
    text,
    '''\t\t\tgate.rotation_degrees = Vector3(0.0, THRESHOLD_YAW, 0.0)
\t\t\tgate.scale = Vector3.ONE * THRESHOLD_SCALE''',
    '''\t\tgate.rotation_degrees = Vector3(
\t\t\t\t0.0, _asset_profiles.fixed_yaw(threshold_profile), 0.0)
\t\tgate.scale = Vector3.ONE * _asset_profiles.default_scale(threshold_profile)''',
    "scene threshold profile transform",
)
# The threshold block lost one indentation level when its nested mesh-null guard
# became the outer condition. Shift only that known body, ending before road setup.
threshold_start = text.index("\tif threshold_mesh != null and not threshold_profile.is_empty():")
threshold_end = text.index("\t# Seat the road pair now", threshold_start)
threshold_block = text[threshold_start:threshold_end]
threshold_block = threshold_block.replace("\n\t\t\t", "\n\t\t")
text = text[:threshold_start] + threshold_block + text[threshold_end:]
text = replace_once(
    text,
    '''func _build_road() -> void:
\tif _asset_geometry == null or _road_meshes.size() < 2:''',
    '''func _build_road() -> void:
\tif _asset_geometry == null or _road_meshes.size() < 2 \\
\t\t\tor _road_profiles.size() < 2:''',
    "scene road profile guard",
)
text = replace_once(
    text,
    '''\t\tvar node: MultiMeshInstance3D = _road_multimesh(
\t\t\t\t_road_meshes[m], laid[m], yaws[m], m)''',
    '''\t\tvar node: MultiMeshInstance3D = _road_multimesh(
\t\t\t\t_road_meshes[m], laid[m], yaws[m], m, _road_profiles[m])''',
    "scene road profile call",
)
text = replace_once(
    text,
    '''func _road_multimesh(mesh: Mesh, positions: PackedVector3Array,
\t\tyaws: PackedFloat32Array, seed_index: int) -> MultiMeshInstance3D:''',
    '''func _road_multimesh(mesh: Mesh, positions: PackedVector3Array,
\t\tyaws: PackedFloat32Array, seed_index: int,
\t\tprofile: Dictionary) -> MultiMeshInstance3D:''',
    "scene road profile signature",
)
text = replace_once(
    text,
    '''\t\tvar scale: Vector3 = Vector3(
\t\t\t\tROAD_SCALE * (1.0 + wobble),
\t\t\t\tROAD_SCALE * 0.6,
\t\t\t\tROAD_SCALE * (1.0 - wobble))''',
    '''\t\tvar unit: float = _asset_profiles.default_scale(profile)
\t\tvar scale: Vector3 = Vector3(
\t\t\t\tunit * (1.0 + wobble),
\t\t\t\tunit * 0.6,
\t\t\t\tunit * (1.0 - wobble))''',
    "scene road profile scale",
)
path.write_text(text)
