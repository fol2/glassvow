extends RefCounted
## Probe the added rail/pier geometry, not just the unchanged route surface.
const Probe = preload("res://tools/map_workshop/act2/mesh_probe.gd")
const M = preload("res://presentation/map/landscape/mesh_tools.gd")

static func measure(causeways: Node3D) -> Dictionary:
	var obstacles: Array[Probe] = []
	for mesh: ArrayMesh in causeways.decoration_meshes:
		var probe: Probe = Probe.new()
		probe.build(mesh)
		obstacles.append(probe)
	var floors: Array[Probe] = []
	for mesh: ArrayMesh in causeways.deck_meshes:
		var probe: Probe = Probe.new()
		probe.build(mesh)
		floors.append(probe)
	var tested: int = 0
	var hits: int = 0
	var examples: Array[Dictionary] = []
	var corridors: Dictionary = causeways.sampled_routes.duplicate()
	var links: Dictionary = causeways.ruin_links
	corridors.merge(links)
	for key: String in corridors:
		var points: PackedVector3Array = corridors[key]
		for i: int in range(points.size()):
			var point: Vector3 = points[i]
			var delta: Vector3 = points[mini(i+1,points.size()-1)]-points[maxi(0,i-1)]
			var side: Vector2 = Vector2(-delta.z,delta.x).normalized()
			for offset: float in [-.75,-.5,0.0,.5,.75]:
				var at: Vector2 = Vector2(point.x,point.z)+side*offset
				var floor_height: float = point.y+.022
				for probe: Probe in floors:
					for height: float in probe.heights(at):
						if absf(height-point.y)<.4:
							floor_height = maxf(floor_height,height)
				tested += 1
				var obstruction_found: bool = false
				for part: int in range(obstacles.size()):
					for height: float in obstacles[part].heights(at):
						if height>floor_height+.04 and height<floor_height+2.12:
							obstruction_found = true
							if examples.size()<12:
								var distances: Array = []
								for field: RefCounted in causeways.fields:
									distances.append(field.field(at)["distance"])
								examples.append({"edge":key,"at":[at.x,at.y],"floor":floor_height,"obstacle":height,"part":part,"offset":offset,"field_distances":distances,"triangles":_faces_at(obstacles[part],at,floor_height)})
							break
					if obstruction_found:
						break
				if obstruction_found:
					hits += 1

	return {"body_samples":tested,"decoration_hits":hits,"examples":examples,
		"scope":"Actual rail and pier triangles over rendered treads; five lateral samples across a 1.5 m corridor, 2.12 m body height."}

static func _faces_at(probe: Probe,at: Vector2,floor_height: float) -> Array:
	var result: Array = []
	for triangle: Array[Vector3] in probe.cells.get(Vector2i(floori(at.x),floori(at.y)),[]):
		var a: Vector3 = triangle[0]
		var b: Vector3 = triangle[1]
		var c: Vector3 = triangle[2]
		var ab: Vector2 = Vector2(b.x-a.x,b.z-a.z)
		var ac: Vector2 = Vector2(c.x-a.x,c.z-a.z)
		var delta: Vector2 = at-Vector2(a.x,a.z)
		var u: float = delta.cross(ac)/ab.cross(ac)
		var v: float = ab.cross(delta)/ab.cross(ac)
		var height: float = a.y*(1-u-v)+b.y*u+c.y*v
		if u>=-.00001 and v>=-.00001 and u+v<=1.00001 and height>floor_height+.04 and height<floor_height+2.12:
			result.append([[a.x,a.y,a.z],[b.x,b.y,b.z],[c.x,c.y,c.z]])
			if result.size()==3: break
	return result
