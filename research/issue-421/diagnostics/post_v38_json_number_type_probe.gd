extends SceneTree
## Zero-simulator diagnostic for the frozen v1 interface failure.


func _initialize() -> void:
	var parsed_v: Variant = JSON.parse_string("{\"n\":1}")
	var parsed: Dictionary = parsed_v
	var value: Variant = parsed["n"]
	print(JSON.stringify({
		"godot": Engine.get_version_info().get("string", ""),
		"source": "JSON integer literal 1",
		"typeCode": typeof(value),
		"typeName": type_string(typeof(value)),
		"value": value,
	}))
	quit(0)
