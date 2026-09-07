extends RefCounted
## Sample actual foundation triangles against all roads, and conservatively
## compare each solid piece with model bounds rather than the whole tunnel box.
const Probe = preload("res://tools/map_workshop/common/threshold_mesh_audit.gd")
const Occupancy = preload("res://tools/map_workshop/common/architectural_occupancy.gd")
static func run(foundations: Array[Node3D], walking: MeshInstance3D, routes: Dictionary, buildings: Array[Node3D]) -> Dictionary:
	var report: Dictionary = Probe.run(foundations,walking,routes)
	var failures: Array = report["failures"]
	var overlaps: Array[Dictionary] = []
	var piece_count: int = 0
	for foundation: Node3D in foundations:
		var pieces: Array = foundation.get_meta("foundation_bounds",[])
		piece_count += pieces.size()
		for piece: AABB in pieces:
			for building: Node3D in buildings:
				if Occupancy.boxes_overlap(piece,Occupancy.bounds(building)):
					overlaps.append({"foundation":str(foundation.name),"building":str(building.name)})
	# No overhead hits is a valid obstruction result; paired roof-clearance
	# qualification is separate and still requires actual ceiling hits.
	return {"ok":piece_count>0 and failures.is_empty() and overlaps.is_empty(),
		"road_count":routes.size(),"solid_pieces":piece_count,
		"overhead_hits":report["probe_count"],"road_failures":failures,
		"building_bounds_overlaps":overlaps,
		"scope":"sampled foundation obstruction over all route widths; conservative solid-piece/model bounds"}
