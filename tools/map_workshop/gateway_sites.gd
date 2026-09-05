extends RefCounted
## Select a straight, dry route passage; piers and projected body stay clear.
static func choose(terrain: Node3D, anchors: PackedVector3Array) -> Dictionary:
	var best: Dictionary = {}
	var score: float = INF
	for line: PackedVector3Array in terrain.lines:
		for index: int in range(line.size() - 1):
			var a: Vector3 = line[index]
			var b: Vector3 = line[index + 1]
			if a.distance_to(b) < 3 or absf(a.y - b.y) > 0.03 or a.y > 0.12:
				continue
			var forward: Vector3 = (b - a).normalized()
			var side: Vector3 = Vector3.UP.cross(forward)
			var yaw: float = atan2(forward.x, forward.z)
			if yaw > PI / 2:
				yaw -= PI
			elif yaw < -PI / 2:
				yaw += PI
			var half_x: float = absf(side.x) * 2.65 + absf(forward.x) * 0.70
			var half_z: float = absf(side.z) * 2.65 + absf(forward.z) * 0.70
			for fraction: float in [0.25, 0.4, 0.5, 0.6, 0.75]:
				var p: Vector3 = a.lerp(b, fraction)
				if terrain.stream_distance(p.x, p.z) < 5:
					continue
				var available: bool = true
				for anchor: Vector3 in anchors:
					var delta: Vector3 = p - anchor
					if absf(delta.x) < half_x + 1.2 and delta.z > -half_z - 1.3 and delta.z < half_z + 5.5 / tan(deg_to_rad(55)) + 1.3:
						available = false
				for sign_value: float in [-1, 1]:
					var pier: Vector3 = p + side * sign_value * 1.70
					if terrain.distance_to_roads(pier) < 1.62:
						available = false
				if not available:
					continue
				# The sample's early lower journey is the authored focal region.
				var candidate: float = p.distance_to(Vector3(-20, 0, 14)) + absf(yaw) * 2
				if candidate < score:
					score = candidate
					p.y = terrain.surface_height(p.x, p.z)
					best = {"position": p, "yaw": yaw}
	return best
