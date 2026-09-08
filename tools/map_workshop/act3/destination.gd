extends RefCounted
## One intact royal precinct terminates at the generated boss, without new game edges.
var sites: Array[Dictionary] = []
var failure: String = ""
func build(sample: Dictionary,anchors: Dictionary,_routes: Dictionary) -> void:
	var boss: String = ""
	for node: Dictionary in sample["nodes"]:
		if node["type"]=="boss":
			boss = node["id"]
	if boss.is_empty():
		failure = "The royal precinct requires a generated boss node"
		return
	var anchor: Vector3 = anchors[boss]
	var centre: Vector3 = anchor+Vector3(32,-2.02,0)
	sites = [{"kind":"royal_precinct","ordinal":0,"node":boss,"anchor":anchor,"centre":centre,"yaw":-PI*.5,"half":Vector2(19,20),"door":anchor+Vector3(12,0,0)}]
