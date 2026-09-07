extends RefCounted
## Read-only design experiment. Routes and choices come from the compiled graph.
const M = preload("res://tools/map_workshop/mesh_tools.gd")
static func run(tree: SceneTree, world: Node3D, camera: Camera3D, data: Dictionary) -> void:
	var before: String = JSON.stringify(data)
	var anchors: Dictionary = data["anchors"]
	var current: String = data["current"]
	var choices: Array = data["reachable"]
	assert(choices.size() == 2)
	var overlay: Node3D = Node3D.new()
	world.add_child(overlay)
	var ui: CanvasLayer = CanvasLayer.new()
	world.add_child(ui)
	var centre: Vector3 = point(anchors[current])
	for id: String in choices:
		centre += point(anchors[id])
	centre /= 3.0
	for mode: String in ["arrival","choice-a","choice-b","overview"]:
		for child: Node in overlay.get_children():
			child.free()
		for child: Node in ui.get_children():
			child.free()
		var overview: bool = mode == "overview"
		var target: Vector3 = centre if not overview else Vector3(7,2,0)
		camera.size = 42.0 if not overview else 180.0
		camera.position = target+Vector3(-40,90,-90)
		camera.look_at(target)
		var selected: String = str(choices[1] if mode == "choice-b" else choices[0])
		var visible_nodes: Array = [current]+choices
		if overview:
			visible_nodes = anchors.keys()
		for edge: Dictionary in data["edges"].values():
			var available: bool = edge["from"] == current and edge["to"] in choices
			if not overview and (mode == "arrival" or not available or edge["to"] != selected):
				continue
			var colour: Color = Color("d0b0e5") if available else Color("696679")
			if edge["from"] in data["history"] and edge["to"] in data["history"]:
				colour = Color("a89370")
			var line: Array = edge["centerline"]
			for i: int in range(line.size()-1):
				var a: Vector3 = point(line[i])+Vector3.UP*.24
				var b: Vector3 = point(line[i+1])+Vector3.UP*.24
				if overview:
					var drawn: Line2D = Line2D.new()
					drawn.points = PackedVector2Array([camera.unproject_position(a),camera.unproject_position(b)])
					drawn.width = 2.5 if available else 1.0
					drawn.default_color = colour
					ui.add_child(drawn)
				else:
					var material: StandardMaterial3D = M.material(colour)
					material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					var strip: MeshInstance3D = M.box(overlay,(a+b)*.5,Vector3(.12,.045,a.distance_to(b)),material,"SelectedRoute")
					if a.distance_to(b)>.001:
						strip.look_at(b,Vector3.UP)
		for id: String in visible_nodes:
			var at: Vector2 = camera.unproject_position(point(anchors[id])+Vector3.UP*.5)
			var hot: bool = id == current or id in choices
			var label: Label = Label.new()
			label.position = at-Vector2(19,19)
			label.size = Vector2(38,38) if hot else Vector2(14,14)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.text = "●" if id == current else ("A" if id == str(choices[0]) else ("B" if id == str(choices[1]) else "·"))
			label.add_theme_font_size_override("font_size",22 if hot else 16)
			label.add_theme_color_override("font_color",Color("ecc995") if id == current else (Color("eadbf4") if hot else Color("a8a0b8")))
			label.add_theme_color_override("font_shadow_color",Color.BLACK)
			label.add_theme_constant_override("shadow_offset_x",2)
			label.add_theme_constant_override("shadow_offset_y",2)
			ui.add_child(label)
		var title: Label = Label.new()
		title.position = Vector2(24,18)
		title.text = "III  /  THE OBSIDIAN COURT"
		title.add_theme_font_size_override("font_size",19)
		ui.add_child(title)
		var legend: Label = Label.new()
		legend.position = Vector2(24,tree.root.size.y-48)
		legend.text = {"arrival":"You are here  ●     A / B  ·  Two available waystones", "choice-a":"Preview A  ·  Follow the light through the court stairs", "choice-b":"Preview B  ·  The other available approach", "overview":"Planning  ·  Gold: travelled   /   Lilac: next   /   Grey: later"}[mode]
		legend.add_theme_font_size_override("font_size",16)
		ui.add_child(legend)
		for frame: int in range(5):
			await tree.process_frame
		await RenderingServer.frame_post_draw
		var path: String = "/tmp/act3-wayfinding-"+str(tree.root.size.x)+"-"+mode+".png"
		assert(tree.root.get_texture().get_image().save_png(path)==OK)
	assert(JSON.stringify(data)==before)
	print("WAYFINDING_STUDY ",JSON.stringify({"current":current,"choices":choices,"source_unchanged":true,"edge_count":data["edges"].size(),"scope":"read-only native state previews; no gameplay interaction claim"}))
static func point(raw: Variant) -> Vector3:
	var value: Array = raw
	return Vector3(MapLayoutCanonical.float_value(value[0]),MapLayoutCanonical.float_value(value[1]),MapLayoutCanonical.float_value(value[2]))
