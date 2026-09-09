extends SceneTree
const Bridge: GDScript=preload("res://bridge.gd")
func _initialize() -> void:
 Bridge.enabled=true
 quit(0)
