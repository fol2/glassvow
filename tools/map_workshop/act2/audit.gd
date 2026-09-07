extends RefCounted
## Early discriminating geometry evidence; not complete chapter acceptance.
const Probe = preload("res://tools/map_workshop/act2/mesh_probe.gd")

static func measure(causeways: Node3D, sample: Dictionary) -> Dictionary:
	var missing: Array[String] = []
	var maximum_grade: float = 0
	var steepest: Dictionary = {}
	var minimum_dry: float = INF
	var endpoint_error: float = 0
	for key: String in sample["edges"]:
		if not causeways.sampled_routes.has(key):
			missing.append(key)
			continue
		var source: Dictionary = sample["edges"][key]
		var points: PackedVector3Array = causeways.sampled_routes[key]
		var raised: bool = false
		for raw: Array in source["centerline"]:
			raised = raised or float(str(raw[1]))>.3
		var field: RefCounted = causeways.fields[1 if raised else 0]
		var previous: Vector3 = Vector3.INF
		for point: Vector3 in points:
			var p: Vector3 = point
			var value: Dictionary = field.field(Vector2(p.x,p.z))
			var distance: float = value["distance"]
			if distance>0 and not value.get("delegated",false):
				missing.append(key+": uncovered sample")
			p.y = value["height"]
			minimum_dry = minf(minimum_dry,p.y-1.18)
			if previous.is_finite():
				var run: float = Vector2(p.x-previous.x,p.z-previous.z).length()
				var grade: float = absf(p.y-previous.y)/maxf(.00001,run)
				if grade>maximum_grade:
					maximum_grade = grade
					steepest = {"edge":key,"at":[p.x,p.y,p.z],"upper":raised}
			previous = p
		for i: int in [0,points.size()-1]:
			var p: Vector3 = points[i]
			var value: Dictionary = field.field(Vector2(p.x,p.z))
			var node_id: String = source["from"] if i==0 else source["to"]
			var anchor: Vector3 = causeways.anchors[node_id]
			var height: float = value["height"]
			endpoint_error = maxf(endpoint_error,absf(height-anchor.y))
	var minimum_clearance: float = INF
	var crossings: Array[Dictionary] = []
	for cut: Dictionary in causeways.levels.cuts:
		var at: Vector2 = cut["at"]
		var lower: Dictionary = causeways.fields[0].field(at)
		var upper: Dictionary = causeways.fields[1].field(at)
		var low: float = lower["height"]
		var high: float = upper["bottom"]
		minimum_clearance = minf(minimum_clearance,high-low)
		crossings.append({"at":[at.x,at.y],"floor":low,"soffit":high,"clearance":high-low})
	var width_checks: Dictionary = _width(causeways)
	return {"bridge_walkway":preload("res://tools/map_workshop/act2/bridge_walkway_audit.gd").measure(causeways),"rendered_deck":preload("res://tools/map_workshop/act2/deck_audit.gd").measure(causeways),"bridgehead_overlap":_joints(causeways),"rendered_width_checks":width_checks,"nodes":causeways.anchors.size(),"expected_nodes":sample["anchors"].size(),
		"edges":causeways.sampled_routes.size(),"expected_edges":sample["edges"].size(),
		"missing_route_samples":missing,"maximum_sampled_grade":maximum_grade,"steepest":steepest,
		"minimum_dry_margin":minimum_dry,"maximum_endpoint_height_error":endpoint_error,
		"crossings":crossings,"crossing_centres":causeways.levels.cuts.size(),"minimum_centre_headroom":minimum_clearance,
		"remaining_checks":["whole-width bridge clearance","library footprint and route obstruction","reference-shape readability","water motion and depth","owner review"]}

static func _width(causeways: Node3D) -> Dictionary:
	if causeways.fields.size()<2:
		return {"sample_count":0,"minimum_headroom":INF,"failures":[],"sampling":"No raised crossing in this generated graph"}
	var floor_probe: Probe = Probe.new()
	var soffit_probe: Probe = Probe.new()
	var floor_mesh: Mesh = causeways.deck_meshes[0]
	var soffit_mesh: Mesh = causeways.underside_meshes[1]
	floor_probe.build(floor_mesh)
	soffit_probe.build(soffit_mesh)
	var minimum: float = INF
	var count: int = 0
	var failures: Array[Dictionary] = []
	for cut: Dictionary in causeways.levels.cuts:
		var centre: Vector2 = cut["at"]
		var direction: Vector2 = cut["direction"]
		var side: Vector2 = Vector2(-direction.y,direction.x)
		for along: int in range(-24,25):
			for across: int in range(-6,7):
				var at: Vector2 = centre+direction*along*.125+side*across*.15
				var floors: PackedFloat32Array = floor_probe.heights(at)
				var soffits: PackedFloat32Array = soffit_probe.heights(at)
				if floors.is_empty() or soffits.is_empty():
					continue
				var floor_height: float = floors[0]
				var soffit_height: float = soffits[0]
				for h: float in floors:
					floor_height = maxf(floor_height,h)
				for h: float in soffits:
					soffit_height = minf(soffit_height,h)
				var clearance: float = soffit_height-floor_height
				minimum = minf(minimum,clearance)
				count += 1
				if clearance<2.2 and failures.size()<8:
					failures.append({"at":[at.x,at.y],"clearance":clearance})
	return {"sample_count":count,"minimum_headroom":minimum,"failures":failures,
		"sampling":"Rendered lower top and upper underside triangles, 0.125 m along / 0.15 m across, +/-0.9 m width at every generated crossing"}

static func _joints(causeways: Node3D) -> Dictionary:
	var count: int = 0
	var maximum: float = 0
	var worst: Vector2 = Vector2.ZERO
	for pad: Vector2 in causeways.levels.abutments:
		for x: int in range(-12,13):
			for z: int in range(-12,13):
				var at: Vector2 = pad+Vector2(x,z)*.125
				if at.distance_to(pad)>1.5:
					continue
				var lower: Dictionary = causeways.fields[0].field(at)
				var upper: Dictionary = causeways.fields[1].field(at)
				var low_distance: float = lower["distance"]
				var high_distance: float = upper["distance"]
				if low_distance>0 or (high_distance>0 and not upper.get("delegated",false)):
					continue
				var a: float = lower["height"]
				var b: float = upper["height"]
				count += 1
				if absf(a-b)>maximum:
					maximum = absf(a-b)
					worst = at
	return {"overlap_samples":count,"maximum_surface_separation":maximum,"worst":[worst.x,worst.y],"radius":1.5}
