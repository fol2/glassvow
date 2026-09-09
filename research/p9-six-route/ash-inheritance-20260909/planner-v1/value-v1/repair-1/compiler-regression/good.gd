extends SceneTree
const Bridge: GDScript=preload("res://bridge.gd")
func _initialize() -> void:
 Bridge.configure(true)
 assert(Bridge.enabled == true)
 Bridge.configure(false)
 assert(Bridge.enabled == false)
 print("STATIC_CONFIGURATION_PASS")
 quit(0)
