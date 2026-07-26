extends RefCounted
## Gates the fracture-model invariants maintained by the focused checker.

const CHECK_FRACTURE: Script = preload("res://tools/check_fracture.gd")


static func run(fails: Array[String]) -> void:
	CHECK_FRACTURE.run(fails)
