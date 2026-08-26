extends SceneTree
## What the map's procedural layout actually does, over many seeds, headless.
##
## Six screenshots tell you the scenery moved. They do not tell you how often
## two waystone medallions end up overlapping, or whether a change that made
## the map prettier quietly started burying nodes behind rocks. Those are rates,
## and a rate needs a sample. This is that sample.
##
##   godot --headless -s res://tools/probe_map_seeds.gd -- --seeds=200
##
## Costs no window and no focus, so it is safe to run beside anything.
##
## The probe still rebuilds placements headlessly, but MapAssetProfiles is
## now the one source for mesh identity, scale, footprint and hide-depth facts.
## It loads only Act I's active set, matching runtime residency.
const ACT: int = 0
const KINDS: int = 6


func _initialize() -> void:
	var seeds: int = 200
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			seeds = maxi(1, int(arg.trim_prefix("--seeds=")))
	var registry: MapAssetProfiles = MapAssetProfiles.new()
	var by_id: Dictionary[String, Dictionary] = {}
	var active_profiles: Array[Dictionary] = []
	for asset_id: String in registry.ids_for_act(ACT):
		var resource: Resource = load(registry.resource_path(asset_id))
		var value: Dictionary = registry.profile(asset_id, _mesh(resource))
		if value.is_empty():
			push_error("map profile failed: %s" % asset_id)
			quit(2)
			return
		by_id[asset_id] = value
		active_profiles.append(value)
	var kit_profiles: Array[Dictionary] = []
	for asset_id: String in registry.ids_for_act(ACT, "kit"):
		kit_profiles.append(by_id[asset_id])
	var scene: MapScene = MapScene.new()
	var profile_digest: String = registry.digest(active_profiles)
	if profile_digest.is_empty() or profile_digest != scene.asset_profile_digest():
		push_error("runtime/probe map profile digest mismatch")
		scene.free()
		quit(2)
		return
	var content: ContentDB = ContentDB.load_slice()

	var pair_hits: int = 0
	var worst: float = 1.0
	var vigil_hits: int = 0
	var behind: int = 0
	var total: int = 0
	var max_shove: float = 0.0
	var bad_pair_seeds: int = 0
	var bad_vigil_seeds: int = 0
	var counts: Array[int] = []
	var clumps: int = 0
	var worst_clump: float = 1.0
	var clump_seeds: int = 0
	var vigil: Dictionary = by_id["act1-vigil"]
	var vigil_position: Vector3 = Vector3(
			MapScene.THRESHOLD_XZ.x, 0.0, MapScene.THRESHOLD_XZ.y)
	var vigil_scale: float = registry.default_scale(vigil)
	var vigil_points: PackedVector2Array = registry.transformed_footprint(
			vigil, vigil_position, registry.fixed_yaw(vigil),
			Vector3.ONE * vigil_scale)
	var vigil_rect: Rect2 = _bounds(vigil_points)

	for s: int in range(1, seeds + 1):
		var run: RunState = RunState.new_run(content, s, "probe-%d" % s, {})
		var map: WorldMap = WorldMap.benchmark(run)
		scene.set_scatter_salt(s)
		var pieces: Array[Vector4] = _pieces(
				scene, scene.prop_positions(), kit_profiles, registry)
		MapPinProjection.set_scenery(pieces)
		MapPinProjection.resolve(map.nodes)
		counts.append(map.nodes.size())
		total += map.nodes.size()
		var pts: Array[Vector3] = []
		var vf: int = 0
		for n: MapNode in map.nodes:
			var w: Vector3 = MapPinProjection.world_anchor(n)
			pts.append(w)
			var raw: Vector3 = MapPinProjection.sample(
					float(n.row) + n.jy, float(n.col) + n.jx)
			max_shove = maxf(max_shove, Vector2(w.x - raw.x, w.z - raw.z).length())
			if vigil_rect.has_point(Vector2(w.x, w.z)):
				vigil_hits += 1
				vf += 1
			if _is_behind(w, pieces):
				behind += 1
		if vf > 0:
			bad_vigil_seeds += 1
		# Scenery against scenery. `_band_seats` stratifies each family on its own
		# stream and the families never see each other, so two pieces from
		# different families can land in the same metre -- the hand-authored set
		# could not do that, because a person placed all 25 at once.
		var cf: int = 0
		for a: int in range(pieces.size()):
			for b: int in range(a + 1, pieces.size()):
				var reach: float = pieces[a].z + pieces[b].z
				if reach <= 0.0:
					continue
				var gap: float = Vector2(pieces[a].x - pieces[b].x,
						pieces[a].y - pieces[b].y).length() / reach
				if gap < 1.0:
					cf += 1
					worst_clump = minf(worst_clump, gap)
		if cf > 0:
			clumps += cf
			clump_seeds += 1
		var pf: int = _overlaps(pts)
		if pf > 0:
			bad_pair_seeds += 1
			pair_hits += pf
			worst = minf(worst, _worst_separation(pts))
	counts.sort()
	print("=== %d seeds, Act I ===" % seeds)
	print("asset profile digest : %s" % profile_digest)
	print("nodes/map min|med|max : %d | %d | %d   total %d"
			% [counts[0], counts[counts.size() / 2], counts[-1], total])
	print("overlapping node pairs: %d in %d seed(s)" % [pair_hits, bad_pair_seeds])
	print("worst pair separation : %.4f   (1.0 = discs just touching)" % worst)
	print("nodes in Vigil box    : %d in %d seed(s)" % [vigil_hits, bad_vigil_seeds])
	print("nodes behind scenery  : %d  (%.1f%%)"
			% [behind, 100.0 * float(behind) / maxf(float(total), 1.0)])
	print("largest shove         : %.3f  (cap %.2f)"
			% [max_shove, MapPinProjection.STEP_ASIDE_MAX])
	print("scenery pieces fouling: %d in %d seed(s)" % [clumps, clump_seeds])
	print("worst scenery overlap : %.4f   (1.0 = footprints just touching)"
			% worst_clump)
	scene.free()
	quit(0)


## Build the compatibility envelopes through the shared authority. Which
## species occupies a seat remains MapScene's deterministic placement decision.
func _pieces(scene: MapScene, seats: PackedVector3Array,
		profiles: Array[Dictionary], registry: MapAssetProfiles) -> Array[Vector4]:
	var out: Array[Vector4] = []
	for j: int in range(seats.size()):
		var kit: int = scene.seat_kit(j, KINDS)
		out.append(registry.directional_envelope(profiles[kit], seats[j]))
	return out


## The same directional test MapPinProjection._off_scenery makes: the camera
## looks from +z toward -z, so a piece hides only what is FURTHER from the
## camera than itself, and only as far back as its own height reaches.
func _is_behind(seat: Vector3, pieces: Array[Vector4]) -> bool:
	for p: Vector4 in pieces:
		var ahead: float = p.y - seat.z
		if ahead > 0.0 and ahead <= p.w \
				and absf(seat.x - p.x) < p.z + MapPinProjection.NODE_HALF_X:
			return true
	return false


func _separation(a: Vector3, b: Vector3) -> float:
	return maxf(absf(a.x - b.x) / (MapPinProjection.NODE_PAIR_X * 2.0),
			absf(a.z - b.z) / (MapPinProjection.NODE_PAIR_Z * 2.0))


func _overlaps(pts: Array[Vector3]) -> int:
	var hits: int = 0
	for i: int in range(pts.size()):
		for j: int in range(i + 1, pts.size()):
			if _separation(pts[i], pts[j]) < 1.0:
				hits += 1
	return hits


func _worst_separation(pts: Array[Vector3]) -> float:
	var worst: float = 1.0
	for i: int in range(pts.size()):
		for j: int in range(i + 1, pts.size()):
			worst = minf(worst, _separation(pts[i], pts[j]))
	return worst


func _mesh(resource: Resource) -> Mesh:
	if resource is Mesh:
		return resource as Mesh
	if not (resource is PackedScene):
		return null
	var root: Node = (resource as PackedScene).instantiate()
	var mesh_node: MeshInstance3D = _first_mesh(root)
	var mesh: Mesh = null
	if mesh_node != null:
		mesh = mesh_node.mesh
	root.free()
	return mesh


func _first_mesh(root: Node) -> MeshInstance3D:
	if root is MeshInstance3D:
		return root as MeshInstance3D
	for child: Node in root.get_children():
		var found: MeshInstance3D = _first_mesh(child)
		if found != null:
			return found
	return null


func _bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var out: Rect2 = Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		out = out.expand(point)
	return out
