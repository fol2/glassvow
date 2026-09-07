extends RefCounted
## Falsify stale compiler assets, unsupported feet and changed five-stop truth.
const Probe = preload("res://tools/map_workshop/common/threshold_mesh_audit.gd")
static func source_errors(sample: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if sample.get("compiler_hard_pass")!=true: errors.append("Compiler rejected sample")
	var types: Array[String] = ["monster","monster","elite","rest","boss"]
	var nodes: Array = sample.get("nodes",[])
	if nodes.size()!=5 or sample.get("edges",{}).size()!=4: errors.append("Five-stop contract changed")
	for i: int in range(nodes.size()):
		var node: Dictionary = nodes[i]
		if i>=5 or node["id"]!="n"+str(i) or node["type"]!=types[i]: errors.append("Node order/type changed")
	for source: Dictionary in sample.get("hero_sources",{}).values():
		if FileAccess.get_sha256(str(source["path"]))!=source["sha256"]: errors.append("Stale hero asset: "+str(source["path"]))
	if sample.get("hero_sources",{}).size()!=2: errors.append("Missing chapter heroes")
	return errors
static func feet(roots: Array[Node3D], walking: MeshInstance3D) -> Dictionary:
	var floors: Array[Dictionary] = []
	Probe._collect(walking,floors)
	var index: Dictionary = Probe._index(floors)
	var failures: Array[Dictionary] = []
	var count: int = 0
	for root: Node3D in roots:
		var triangles: Array[Dictionary] = []
		Probe._collect(root,triangles)
		var low: float = INF
		for tri: Dictionary in triangles:
			for key: String in ["a","b","c"]:
				var p: Vector3 = tri[key]
				low = minf(low,p.y)
		var points: Dictionary = {}
		for tri: Dictionary in triangles:
			for key: String in ["a","b","c"]:
				var p: Vector3 = tri[key]
				if p.y<=low+.02: points[p] = true
		for p: Vector3 in points:
			count += 1
			var found: bool = false
			var bucket: Array = index.get(Vector2i(floori(p.x/4),floori(p.z/4)),[])
			for floor_tri: Dictionary in bucket:
				var y: float = Probe._height(p,floor_tri,.001)
				if is_finite(y) and absf(y-p.y)<.03: found = true
			if not found: failures.append({"structure":root.name,"point":[p.x,p.y,p.z]})
	return {"ok":failures.is_empty(),"feet_vertices":count,"failures":failures,"scope":"lowest rendered vertices against path triangles; 3 cm contact tolerance"}
