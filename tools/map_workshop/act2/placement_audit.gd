extends RefCounted
## Conservative architectural bounds versus sampled, body-sized route corridors.
var cells: Dictionary = {}
var mesh_count: int = 0

func measure(architecture: Array[Node3D],causeways: Node3D) -> Dictionary:
	for root: Node3D in architecture:
		_index(root)
	var failures: Array[Dictionary] = []
	var hits: int = 0
	var samples: int = 0
	var corridors: Dictionary = causeways.sampled_routes.duplicate()
	var links: Dictionary = causeways.ruin_links
	corridors.merge(links)
	for key: String in corridors:
		var points: PackedVector3Array = corridors[key]
		for i: int in range(points.size()):
			var p: Vector3 = points[i]+Vector3.UP*.022
			# Decorative submerged arrivals are not playable body corridors.
			if links.has(key) and p.y<1.18:
				continue
			var direction: Vector3 = points[mini(i+1,points.size()-1)]-points[maxi(i-1,0)]
			var side: Vector3 = Vector3(direction.z,0,-direction.x).normalized()
			for offset: float in [-.5,0,.5]:
				var at: Vector3 = p+side*offset
				var body: AABB = AABB(at+Vector3(-.25,.08,-.25),Vector3(.5,2.12,.5))
				var bucket: Array = cells.get(Vector2i(floori(at.x/4),floori(at.z/4)),[])
				samples += 1
				for item: Dictionary in bucket:
					var box: AABB = item["bounds"]
					if body.intersects(box):
						hits += 1
						if failures.size()<12:
							failures.append({"edge":key,"at":[at.x,at.y,at.z],"mesh":item["name"]})
	return {"architecture_meshes":mesh_count,"body_samples":samples,"bounds_hits":hits,"first_hits":failures,
		"scope":"Conservative mesh AABBs, 0.5 m body width / 2.12 m above boots, centre and +/-0.5 m route offsets. Positive hits need triangle-level diagnosis."}

func _index(node: Node) -> void:
	if node is MeshInstance3D:
		var item: MeshInstance3D = node
		var bounds: AABB = item.global_transform*item.mesh.get_aabb()
		var low: Vector3 = bounds.position-Vector3(.3,0,.3)
		var high: Vector3 = bounds.end+Vector3(.3,0,.3)
		for x: int in range(floori(low.x/4),floori(high.x/4)+1):
			for z: int in range(floori(low.z/4),floori(high.z/4)+1):
				var key: Vector2i = Vector2i(x,z)
				if not cells.has(key):
					cells[key] = []
				cells[key].append({"bounds":bounds,"name":str(item.get_path())})
		mesh_count += 1
	for child: Node in node.get_children():
		_index(child)
