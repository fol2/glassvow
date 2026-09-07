extends RefCounted
## Native instance transforms, visibility and prototype bounds must match sources.
static func audit(batch: Node3D) -> Dictionary:
	var failures: Array[String] = []
	var count: int = 0
	for link: Dictionary in batch.links:
		var source: MeshInstance3D = link["source"]
		var draw: MultiMeshInstance3D = link["draw"]
		var index: int = link["index"]
		var actual: Transform3D = draw.global_transform*draw.multimesh.get_instance_transform(index)
		var original_box: AABB = source.mesh.get_aabb()
		var batched_box: AABB = draw.multimesh.mesh.get_aabb()
		var mismatch: bool = source.visible or not draw.visible or index>=draw.multimesh.instance_count
		for corner: int in range(8):
			var expected: Vector3 = source.global_transform*original_box.get_endpoint(corner)
			var found: Vector3 = actual*batched_box.get_endpoint(corner)
			mismatch=mismatch or expected.distance_to(found)>.0001
		if mismatch and failures.size()<8: failures.append(str(source.name))
		count+=1
	return {"parts":count,"draws":batch.groups.size(),"failures":failures,"ok":count>0 and failures.is_empty()}

static func negative_canary(batch: Node3D) -> bool:
	if batch.links.is_empty(): return false
	var link: Dictionary = batch.links[0]
	var draw: MultiMeshInstance3D = link["draw"]
	var index: int = link["index"]
	var original: Transform3D = draw.multimesh.get_instance_transform(index)
	var moved: Transform3D = original
	moved.origin+=Vector3.ONE
	draw.multimesh.set_instance_transform(index,moved)
	var detected: bool = not audit(batch)["ok"]
	draw.multimesh.set_instance_transform(index,original)
	return detected
