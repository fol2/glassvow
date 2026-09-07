extends RefCounted
static func run(fails: Array[String]) -> void:
	var flight: Dictionary = preload("res://presentation/map/chapters/common/resolved_flight.gd").between_landings(Vector3.ZERO,Vector3(8,1.7,0),2.5,-1)
	var contacts: RefCounted = preload("res://presentation/map/chapters/common/walking_contacts.gd").new()
	var tops: Array = flight["tops"]
	contacts.add(tops)
	var mesh: ArrayMesh = preload("res://presentation/map/chapters/common/flight_mesh.gd").build(flight)
	var independent: RefCounted = preload("res://tools/map_workshop/common/mesh_probe.gd").new()
	independent.build(mesh)
	for x: int in range(1,160):
		for z: float in [-1.1,0,1.1]:
			var at: Vector3 = Vector3(x*.05,x*.05/8*1.7,z)
			var actual: PackedFloat32Array = independent.heights(Vector2(at.x,at.z))
			var y: float = contacts.height(at)
			# ArrayMesh compresses these vertices to a 0.1 mm grid.
			var found: bool = false
			for height: float in actual: found=found or absf(height-y)<.0001
			if not found:
				fails.append("Runtime walking height leaves the actual tread triangle: "+str(at)+" query="+str(y)+" mesh="+str(actual))
				return
	var outside: float = contacts.height(Vector3(4,1,3))
	if is_finite(outside): fails.append("Runtime contact invents support outside the stairs")
	var layered: RefCounted = preload("res://presentation/map/chapters/common/walking_contacts.gd").new()
	var ground: Array = [PackedVector3Array([Vector3(0,0,0),Vector3(1,0,0),Vector3(1,0,1),Vector3(0,0,1)])]
	var step: Array = [PackedVector3Array([Vector3(0,.17,0),Vector3(1,.17,0),Vector3(1,.17,1),Vector3(0,.17,1)])]
	layered.add(ground)
	layered.add(step)
	var supporting: float = layered.height(Vector3(.5,.02,.5))
	if absf(supporting-.17)>.0001: fails.append("The first stair tread loses contact to a closer underlying court")
