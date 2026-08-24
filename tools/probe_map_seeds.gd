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
## WHY IT REBUILDS THE SCENERY LIST INSTEAD OF ASKING MapScene FOR IT.
## `MapScene._bind_asset_geometry` is what normally publishes footprints to
## `MapPinProjection`, and it needs the act's real GLBs bound through a live
## SubViewport. Driving that headless once cost six minutes of wall clock and
## six seconds of CPU -- it blocks rather than works. So the seats come from
## MapScene (they are its own dealt output) and the footprint maths is
## repeated here from `_bind_asset_geometry`. THAT DUPLICATION IS THE ONE
## THING TO WATCH: if the radius or hide-depth formula changes there and not
## here, this probe will keep reporting a rate for a map that no longer exists.

const KIT_PATHS: Array[String] = [
	"res://assets/art/map/geometry/shared/road-slab-a.glb",
	"res://assets/art/map/geometry/shared/road-slab-b.glb",
	"res://assets/art/map/geometry/shared/standing-monument.glb",
	"res://assets/art/map/geometry/act1/ash-trunk-fork.glb",
	"res://assets/art/map/geometry/act1/root-wedge.glb",
	"res://assets/art/map/geometry/act1/charred-stump.glb",
	"res://assets/art/map/geometry/act1/fallen-bough-arch.glb",
	"res://assets/art/map/geometry/act1/ash-cairn-mass.glb",
]
## Kits 0 and 1 are the road, not scenery -- the same split MapScene makes.
const KINDS: int = 6
## Half the Vigil's rotated footprint, from THRESHOLD_SCALE and THRESHOLD_YAW.
const VIGIL_HALF: Vector2 = Vector2(4.25, 4.27)


func _initialize() -> void:
	var seeds: int = 200
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			seeds = maxi(1, int(arg.trim_prefix("--seeds=")))
	var boxes: Array[AABB] = []
	for path: String in KIT_PATHS:
		boxes.append(_aabb(path))
	var scene: MapScene = MapScene.new()
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
	var vc: Vector2 = MapScene.THRESHOLD_XZ

	for s: int in range(1, seeds + 1):
		var run: RunState = RunState.new_run(content, s, "probe-%d" % s, {})
		var map: WorldMap = WorldMap.benchmark(run)
		scene.set_scatter_salt(s)
		var pieces: Array[Vector4] = _pieces(scene.prop_positions(), boxes, s)
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
			if absf(w.x - vc.x) < VIGIL_HALF.x and absf(w.z - vc.y) < VIGIL_HALF.y:
				vigil_hits += 1
				vf += 1
			if _is_behind(w, pieces):
				behind += 1
		if vf > 0:
			bad_vigil_seeds += 1
		var pf: int = _overlaps(pts)
		if pf > 0:
			bad_pair_seeds += 1
			pair_hits += pf
			worst = minf(worst, _worst_separation(pts))
	counts.sort()
	print("=== %d seeds, Act I ===" % seeds)
	print("nodes/map min|med|max : %d | %d | %d   total %d"
			% [counts[0], counts[counts.size() / 2], counts[-1], total])
	print("overlapping node pairs: %d in %d seed(s)" % [pair_hits, bad_pair_seeds])
	print("worst pair separation : %.4f   (1.0 = discs just touching)" % worst)
	print("nodes in Vigil box    : %d in %d seed(s)" % [vigil_hits, bad_vigil_seeds])
	print("nodes behind scenery  : %d  (%.1f%%)"
			% [behind, 100.0 * float(behind) / maxf(float(total), 1.0)])
	print("largest shove         : %.3f  (cap %.2f)"
			% [max_shove, MapPinProjection.STEP_ASIDE_MAX])
	scene.free()
	quit(0)


## Repeated from MapScene._bind_asset_geometry -- see the header.
func _pieces(seats: PackedVector3Array, boxes: Array[AABB],
		salt: int) -> Array[Vector4]:
	var out: Array[Vector4] = []
	for j: int in range(seats.size()):
		var kit: int = 2 + posmod(j + salt, KINDS)
		var box: AABB = boxes[kit]
		var unit: float = MapScene.KIT_SCALE[kit]
		out.append(Vector4(seats[j].x, seats[j].z,
				maxf(box.size.x, box.size.z) * 0.5 * unit,
				box.size.y * unit * MapScene.HIDE_PER_HEIGHT))
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


func _aabb(path: String) -> AABB:
	var res: Resource = load(path)
	if res is Mesh:
		return (res as Mesh).get_aabb()
	if not (res is PackedScene):
		return AABB()
	var inst: Node = (res as PackedScene).instantiate()
	var mesh_node: MeshInstance3D = _first_mesh(inst)
	var box: AABB = mesh_node.mesh.get_aabb() if mesh_node != null else AABB()
	inst.free()
	return box


func _first_mesh(root: Node) -> MeshInstance3D:
	if root is MeshInstance3D:
		return root as MeshInstance3D
	for child: Node in root.get_children():
		var found: MeshInstance3D = _first_mesh(child)
		if found != null:
			return found
	return null
