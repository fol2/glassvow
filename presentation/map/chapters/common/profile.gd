extends RefCounted
## Optional, validated presentation-height candidate. No graph changes; one explicit uniform presentation scale.
const M = preload("res://presentation/map/landscape/mesh_tools.gd")
var routes: Dictionary = {}
var planar_scale: float = 1.0
var failure: String = ""

func load_candidate(sample: Dictionary) -> void:
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--profile="):
			continue
		var path: String = arg.trim_prefix("--profile=")
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary:
			failure = "Invalid presentation profile JSON"
			return
		var data: Dictionary = parsed
		if not data.get("success",false) or data.get("source_digest","")!=sample["layout_digest"]:
			failure = "Presentation profile does not match the immutable sample"
			return
		planar_scale = float(str(data.get("scale",0)))
		if not is_finite(planar_scale) or planar_scale<1.0 or planar_scale>2.0:
			failure = "Presentation scale is outside the bounded study range"
			return
		routes = data.get("routes",{})
		if routes.size()!=sample["edges"].size():
			failure = "Presentation profile route count differs"
			return
		for key: String in sample["edges"]:
			if not routes.has(key):
				failure = "Presentation profile is missing "+key
				return

func apply(key: String,original: PackedVector3Array) -> PackedVector3Array:
	if routes.is_empty():
		return original
	var points: Array = routes[key]
	if points.size()!=original.size():
		failure = "Presentation profile sample count differs for "+key
		return original
	var result: PackedVector3Array = []
	for i: int in range(points.size()):
		var raw: Array = points[i]
		var p: Vector3 = M.v3(raw)
		if not p.is_finite() or Vector2(p.x-original[i].x*planar_scale,p.z-original[i].z*planar_scale).length()>.00001:
			failure = "Presentation profile moved an X/Z sample on "+key
			return original
		result.append(p)
	return result
