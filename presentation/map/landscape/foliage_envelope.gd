extends RefCounted
static func load_conifer(kind: String = "conifer") -> PackedVector2Array:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/map-journey/%s-envelope.json" % kind))
	var result: PackedVector2Array = []
	if str(data.get("source_sha256", "")) != FileAccess.get_sha256("res://assets/art/map-journey/%s.glb" % kind):
		push_error("Conifer envelope must be regenerated for this mesh")
		return result
	for point: Array in data["points"]:
		result.append(Vector2(float(str(point[0])),float(str(point[1]))))
	return result
