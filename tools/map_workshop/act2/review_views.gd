extends RefCounted
## Named native detail views; the bridge figure is an explicit scale reference.
static func apply(name_value: String,camera: Camera3D,library: Node3D,causeways: Node3D,world: Node3D) -> void:
	if name_value == "submerged":
		var site: Dictionary = causeways.ruin_plan.sites[4]
		var anchor: Vector3 = site["anchor"]
		var centre: Vector3 = site["centre"]
		var target: Vector3 = anchor.lerp(centre,.6)+Vector3.UP
		camera.position = target+Vector3(8,20,24)
		camera.look_at(target)
		camera.size = 22
	elif name_value == "boss":
		var anchor: Vector3 = causeways.ruin_plan.sites[0]["anchor"]
		var target: Vector3 = anchor.lerp(library.position+Vector3.UP*3,.55)
		camera.position = target+Vector3(-8,23,28)
		camera.look_at(target)
		camera.size = 27
	elif name_value == "library":
		var target: Vector3 = library.position+Vector3(0,3,0)
		camera.position = target+Vector3(10,18,20)
		camera.look_at(target)
		camera.size = 18
	elif name_value == "precinct":
		var centre: Vector3 = causeways.ruin_plan.sites[1]["centre"]
		var target: Vector3 = centre+Vector3.UP*2.7
		camera.position = target+Vector3(10,17,20)
		camera.look_at(target)
		camera.size = 23
	elif name_value == "stairs":
		for child: Node in causeways.get_children():
			if child is MeshInstance3D and str(child.name).begins_with("StoneBridgeStairTreads"):
				var item: MeshInstance3D = child
				var faces: PackedVector3Array = item.mesh.get_faces()
				var index: int = floori(faces.size()/36.0*.2)*36
				var target: Vector3 = faces[index]+Vector3.UP*.5
				camera.position = target+Vector3(8,15,10)
				camera.look_at(target)
				camera.size = 8
				break
	elif name_value == "bridge":
		var cut: Dictionary = causeways.levels.cuts[1]
		var at: Vector2 = cut["at"]
		var direction: Vector2 = cut["direction"]
		var field: RefCounted = causeways.fields[0]
		var floor_value: Dictionary = field.field(at)
		var height: float = floor_value["height"]
		var target: Vector3 = Vector3(at.x,height+1,at.y)
		var figure: Node3D = preload("res://tools/map_workshop/pilgrim.gd").new()
		world.add_child(figure)
		figure.position = Vector3(at.x,height,at.y)
		camera.position = target+Vector3(direction.x*36,16,direction.y*36)
		camera.look_at(target)
		camera.size = 11
