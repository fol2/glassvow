class_name MapLandscapeAssets
extends RefCounted
## Fixed-camera painted meshes and sculpted stone share the compiler's real bounds.
## The 40-degree tilt is baked into each card's vertices, including its footprint.

const ROOT: String = "res://assets/art/map-atelier/"
const GATES: Array[String] = ["amber-tower", "drowned-gate", "obsidian-ring", "rose-gate"]
const SCENERY: Array[Array] = [
	["ash-tree", "slate-cluster"],
	["drowned-cloister", "slate-cluster"],
	["obsidian-blades", "slate-cluster"],
	["memorials", "ash-tree", "slate-cluster"],
]

var meshes: Dictionary[String, Mesh] = {}
var profiles: Dictionary = {}
var registry: MapAssetProfiles
var digest: String = ""
var paths: PackedStringArray = []
var resources: Array[Resource] = []
var failure: String = ""
var act: int = 0


func _init(act_index: int = 0) -> void:
	act = clampi(act_index, 0, 3)
	var rows: Array = []
	var defaults: Dictionary = {}
	var ids: Array = SCENERY[act].duplicate()
	ids.append(GATES[act])
	if act == 0:
		ids.append("vigil")
	for id: String in ids:
		var spec: Dictionary = _spec(id)
		var path: String = ROOT + str(spec["file"])
		var mesh: Mesh
		if id == "slate-cluster":
			var source: PackedScene = load(path) as PackedScene
			if source != null:
				var node: Node = source.instantiate()
				mesh = _first_mesh(node)
				node.free()
				resources.append(source)
		else:
			mesh = _card(path, spec)
		if mesh == null:
			failure = "Cannot load landscape asset: " + id
			return
		meshes[id] = mesh
		if not paths.has(path):
			paths.append(path)
		var hero: bool = id in GATES or id == "vigil"
		rows.append({"id": id, "kind": "terminus" if hero else "kit",
			"act": act, "path": str(spec["file"])})
		defaults[id] = {"scale": 1.0,
			"semantic_class": "hero" if hero else "scenery",
			"yaw_mode": "free" if id == "slate-cluster" else "fixed", "yaw_degrees": 0.0}
	registry = MapAssetProfiles.new({"assets": rows, "profile_defaults": defaults}, ROOT)
	var values: Array[Dictionary] = []
	for id: String in ids:
		var profile: Dictionary = registry.profile(id, meshes[id])
		if profile.is_empty():
			failure = "Invalid landscape geometry: " + id
			return
		profiles[id] = profile
		values.append(profile)
	digest = registry.digest(values)


func bundle() -> Dictionary:
	return {} if not failure.is_empty() or digest.is_empty() else {
		"profiles": profiles.duplicate(true), "digest": digest}


static func _spec(id: String) -> Dictionary:
	match id:
		"slate-cluster":
			return {"file": "slate-cluster.glb"}
		"ash-tree":
			return {"file": "ash-tree-painted.png", "height": 3.6}
		"vigil":
			return {"file": "vigil-painted.png", "height": 4.5}
		"rose-gate":
			return {"file": "sanctuary-painted.png", "height": 5.8}
		_:
			return {"file": id + ".png", "height": 5.6 if id in GATES else 2.3}


func _card(path: String, spec: Dictionary) -> Mesh:
	if not ResourceLoader.exists(path):
		return null
	var texture: Texture2D = load(path) as Texture2D
	if texture == null:
		return null
	resources.append(texture)
	var image: Image = texture.get_image()
	if image.detect_alpha() == Image.ALPHA_NONE:
		return null
	var used: Rect2i = image.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return null
	image = image.get_region(used)
	image.generate_mipmaps()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.3
	material.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var height: float = spec["height"]
	var card: QuadMesh = QuadMesh.new()
	card.size = Vector2(height * float(image.get_width()) / image.get_height(), height)
	card.center_offset = Vector3(0, height * 0.5, 0)
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.append_from(card, 0, Transform3D(Basis(Vector3.RIGHT,
		deg_to_rad(MapCameraRig.TILT_DEGREES)), Vector3.ZERO))
	var mesh: ArrayMesh = surface.commit()
	mesh.surface_set_material(0, material)
	return mesh


static func _first_mesh(node: Node) -> Mesh:
	if node is MeshInstance3D:
		return (node as MeshInstance3D).mesh
	for child: Node in node.get_children():
		var found: Mesh = _first_mesh(child)
		if found != null:
			return found
	return null
