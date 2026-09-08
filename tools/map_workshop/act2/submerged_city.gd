extends Node3D
## Deterministic whole-act grouping in the actual generated route-free spaces.
const Quarter = preload("res://presentation/map/chapters/act2/sunken_quarter.gd")
var sites: Array[Vector3] = []

func build(causeways: Node3D, precincts: Node3D, library_at: Vector3) -> void:
	var routes: Array[PackedVector3Array] = []
	for points: PackedVector3Array in causeways.sampled_routes.values():
		routes.append(points)
	var low: Vector2 = Vector2.INF
	var high: Vector2 = -Vector2.INF
	for anchor: Vector3 in causeways.anchors.values():
		low = low.min(Vector2(anchor.x,anchor.z))
		high = high.max(Vector2(anchor.x,anchor.z))
	var occupied: Array[Vector3] = [library_at]
	var existing_sites: Array[Vector3] = precincts.sites
	occupied.append_array(existing_sites)
	var candidates: Array[Vector3] = []
	for x: int in range(ceili(low.x+9),floori(high.x-9),4):
		for z: int in range(ceili(low.y+6),floori(high.y-6),4):
			var at: Vector3 = Vector3(x,0,z)
			if precincts._clear(at,routes,Vector2(6.2,4.2)):
				candidates.append(at)
	for ordinal: int in range(8):
		var best: Vector3 = Vector3.INF
		var best_space: float = 17
		for at: Vector3 in candidates:
			var separation: float = INF
			for neighbour: Vector3 in occupied:
				separation = minf(separation,Vector2(at.x-neighbour.x,at.z-neighbour.z).length())
			if separation>best_space:
				best_space = separation
				best = at
		if not best.is_finite():
			break
		var quarter: Node3D = Quarter.new()
		add_child(quarter)
		quarter.position = best
		quarter.build(ordinal)
		sites.append(best)
		occupied.append(best)
	print("ACT_II_SUBMERGED_QUARTERS count=",sites.size()," sites=",sites)
