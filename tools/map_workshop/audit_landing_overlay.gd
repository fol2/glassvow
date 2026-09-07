extends SceneTree
## Probe actual approach triangles against the rendered land, including edges.
const Terrain = preload("res://presentation/map/landscape/terrain.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var terrain: Terrain = Terrain.new()
	root.add_child(terrain)
	var sample: Dictionary = preload("res://tools/map_workshop/sample.gd").read()
	if sample.is_empty():
		quit(2)
		return
	terrain.build(sample,false)
	var deck: MeshInstance3D = terrain.get_node("Continuous bridge decks") as MeshInstance3D
	var arrays: Array = deck.mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var count: int = 0
	var failures: int = 0
	var minimum: float = INF
	var worst: Vector3 = Vector3.ZERO
	for i: int in range(0,points.size(),3):
		if minf(colours[i].r,minf(colours[i+1].r,colours[i+2].r))>.95:
			continue
		for a: int in range(5):
			for b: int in range(5-a):
				var u: float = a/4.0
				var v: float = b/4.0
				var p: Vector3 = points[i]*u+points[i+1]*v+points[i+2]*(1-u-v)
				var separation: float = p.y-terrain.surface_height(p.x,p.z)
				count += 1
				if separation<minimum:
					minimum = separation
					worst = p
				if separation<-.0001:
					failures += 1
	print("LANDING_OVERLAY_AUDIT ",JSON.stringify({"probes":count,"intersections":failures,"minimum_separation":minimum,"worst":str(worst)}))
	quit(0 if count>0 and failures==0 else 1)
