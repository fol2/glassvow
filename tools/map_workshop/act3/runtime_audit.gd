extends RefCounted
## Independent actual triangles: all generated court corridors and architectural solids.
const Probe = preload("res://tools/map_workshop/common/threshold_mesh_audit.gd")
static func negative_canary(landscape: Node3D) -> Dictionary:
	var routes: Dictionary = landscape.terrain.source_edges
	var edge: Dictionary = routes[MapLayoutCanonical.sorted_keys(routes)[0]]
	var at: Vector3 = MapLandscape.v3(edge["centerline"][0])
	at = landscape.terrain.present(at)
	var obstacle: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(1,.2,1)
	obstacle.mesh = box
	landscape.architecture_foundations.add_child(obstacle)
	obstacle.global_position = at+Vector3.UP
	var report: Dictionary = measure(landscape)
	obstacle.free()
	return {"ok":not report["ok"] and report["obstructions"]>0,
		"injected_obstructions_detected":report["obstructions"],"scope":"Actual temporary mesh one metre above a generated route endpoint"}

static func measure(landscape: Node3D) -> Dictionary:
	var courts: Node3D = landscape.terrain.courts
	var walking: MeshInstance3D = courts.walking
	var floor_index: Dictionary = Probe.floor_index(walking)
	var triangles: Array[Dictionary] = []
	Probe._collect(courts,triangles)
	var foundations: Node3D = landscape.architecture_foundations
	Probe._collect(foundations,triangles)
	for placement: Dictionary in landscape.measured_placements:
		var item: Node3D = placement["node"]
		Probe._collect(item,triangles)
	var solid_index: Dictionary = Probe._index(triangles)
	var samples: int = 0
	var missing: int = 0
	var obstructions: int = 0
	var contact_errors: int = 0
	var minimum: float = INF
	var examples: Array[Dictionary] = []
	var routes: Dictionary = landscape.terrain.source_edges
	for id: String in MapLayoutCanonical.sorted_keys(routes):
		var edge: Dictionary = routes[id]
		var line: Array = edge["centerline"]
		var radius: float = MapLayoutCanonical.float_value(edge["corridor_width"])*.5
		for i: int in range(line.size()-1):
			var a: Vector3 = MapLandscape.v3(line[i])
			var b: Vector3 = MapLandscape.v3(line[i+1])
			var flat: Vector3 = Vector3(b.x-a.x,0,b.z-a.z)
			var side: Vector3 = flat.normalized().cross(Vector3.UP)
			var steps: int = maxi(1,ceili(flat.length()/.25))
			for station: int in range(steps+1):
				var centre: Vector3 = a.lerp(b,float(station)/steps)
				for lane: int in range(7):
					var at: Vector3 = centre+side*lerpf(-radius,radius,lane/6.0)
					var floor_y: float = Probe.floor_height(floor_index,at,.00025)
					samples+=1
					if not is_finite(floor_y):
						missing+=1
						if examples.size()<40: examples.append({"edge":id,"reason":"missing walking triangle","at":[at.x,at.y,at.z]})
						continue
					var contact: Vector3 = landscape.terrain.present(at)
					if absf(contact.y-floor_y)>.18:
						contact_errors+=1
						if examples.size()<40: examples.append({"edge":id,"reason":"runtime contact disagrees with actual floor","at":[at.x,at.y,at.z],"contact":contact.y,"floor":floor_y})
					var overhead: float = INF
					var bucket: Vector2i = Vector2i(floori(at.x/4),floori(at.z/4))
					for triangle: Dictionary in solid_index.get(bucket,[]):
						var y: float = Probe._height(at,triangle)
						# Ignore the walking face and a single adjacent 17 cm riser.
						if is_finite(y) and y>floor_y+.18: overhead=minf(overhead,y)
					if is_finite(overhead): minimum=minf(minimum,overhead-floor_y)
					if overhead-floor_y<2.45:
						obstructions+=1
						if examples.size()<40: examples.append({"edge":id,"reason":"solid in walking headroom","at":[at.x,at.y,at.z],"clearance":overhead-floor_y})
	return {"ok":samples>0 and missing==0 and obstructions==0 and contact_errors==0,"samples":samples,
		"floor_edge_tolerance_m":.00025,"missing":missing,"obstructions":obstructions,"contact_errors":contact_errors,"minimum_headroom":minimum,
		"examples":examples,"scope":"Actual walking/solid triangles, 0.25 m stations, seven full-width lanes, 2.45 m headroom"}
