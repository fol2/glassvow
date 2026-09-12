extends Node3D
## Opt-in read-only route guidance. The snapshot owns reachability, never this view.
const Floor = preload("res://tools/map_workshop/common/threshold_mesh_audit.gd")
var snapshot: Dictionary = {}
var paths: Dictionary = {}
var selected_edge: String = ""
var meshes: Dictionary = {}
var overview: Control
var camera: Camera3D
var sampled_points: int = 0
class Network extends Control:
	var guide: Node3D
	func _draw() -> void:
		if guide.camera == null:
			return
		for id: String in guide.paths:
			var screen: PackedVector2Array = []
			for p: Vector3 in guide.paths[id]:
				var view: Camera3D = guide.camera
				screen.append(view.unproject_position(p))
			var state: String = guide.classify(guide.snapshot,id)
			var colour: Color = Color("777182")
			if state == "visited": colour = Color("b29a73")
			if state == "available": colour = Color("d1b2e4")
			draw_polyline(screen,colour,2.5 if state=="available" else 1.0,true)
static func classify(data: Dictionary,id: String) -> String:
	var edge: Dictionary = data["edges"][id]
	if edge["from"] == data["current"] and edge["to"] in data["reachable"]:
		return "available"
	if edge["from"] in data["history"] and edge["to"] in data["history"]:
		return "visited"
	return "future"
static func selection(data: Dictionary,destination: String) -> String:
	var edges: Dictionary = data["edges"]
	for id: String in MapLayoutCanonical.sorted_keys(edges):
		var edge: Dictionary = data["edges"][id]
		if classify(data,id)=="available" and edge["to"]==destination:
			return id
	return ""
func configure(data: Dictionary,walking: MeshInstance3D,view: Camera3D) -> bool:
	snapshot = data.duplicate(true)
	camera = view
	var floor_index: Dictionary = Floor.floor_index(walking)
	for id: String in data["edges"]:
		var line: Array = data["edges"][id]["centerline"]
		var points: PackedVector3Array = []
		for i: int in range(line.size()-1):
			var a: Vector3 = point(line[i])
			var b: Vector3 = point(line[i+1])
			var steps: int = maxi(1,ceili(a.distance_to(b)/.12))
			for step: int in range(steps+1):
				if i>0 and step==0: continue
				var at: Vector3 = a.lerp(b,float(step)/steps)
				var height: float = Floor.floor_height(floor_index,at)
				if not is_finite(height):
					push_error("Guidance support missing "+id+" at "+str(at))
					return false
				at.y = height+.20
				points.append(at)
				sampled_points += 1
		paths[id] = points
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	var network: Network = Network.new()
	network.guide = self
	network.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(network)
	overview = network
	overview.hide()
	return true
func show_state(destination: String,whole: bool,enabled: bool=true) -> void:
	if overview == null: return
	selected_edge = selection(snapshot,destination)
	for id: String in meshes: meshes[id].visible = false
	if not whole and enabled and not selected_edge.is_empty():
		if not meshes.has(selected_edge):
			var selected_path: PackedVector3Array = paths[selected_edge]
			meshes[selected_edge] = ribbon(selected_path)
		meshes[selected_edge].visible = true
	overview.visible = whole and enabled
	if overview.visible: overview.queue_redraw()
func ribbon(points: PackedVector3Array) -> MeshInstance3D:
	var vertices: PackedVector3Array = []
	for i: int in range(points.size()-1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i+1]
		var side: Vector3 = (b-a).cross(Vector3.UP).normalized()*.07
		vertices.append_array(PackedVector3Array([a-side,a+side,b+side,a-side,b+side,b-side]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color("d1b2e4")
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance
static func point(raw: Variant) -> Vector3:
	var v: Array = raw
	return Vector3(MapLayoutCanonical.float_value(v[0]),MapLayoutCanonical.float_value(v[1]),MapLayoutCanonical.float_value(v[2]))
