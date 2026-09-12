extends SceneTree
## Plants beside rocks/under canopies must not depend on insertion order.
const Kit = preload("res://presentation/map/landscape/kit.gd")
const Terrain = preload("res://presentation/map/landscape/terrain.gd")
func _initialize() -> void:
	var kit: Kit = Kit.new()
	var terrain: Terrain = Terrain.new()
	kit.terrain = terrain
	kit.tree_envelopes["conifer"] = PackedVector2Array()
	var checks: int = 0
	for pair: Array in [["conifer","ash-copse",2.0],["slate-bank","ash-copse",2.0]]:
		var first: String = str(pair[0])
		var second: String = str(pair[1])
		for gap: float in [.2,float(str(pair[2]))]:
			var a: Vector2 = Kit.PROFILES[first]
			var b: Vector2 = Kit.PROFILES[second]
			kit.placed = [{"kind":first,"position":Vector3.ZERO,"radius":a.x}]
			var ab: bool = kit.clear(Vector3(gap,0,0),b.x,b.y,second)
			kit.placed = [{"kind":second,"position":Vector3.ZERO,"radius":b.x}]
			var ba: bool = kit.clear(Vector3(gap,0,0),a.x,a.y,first)
			checks += 1
			if ab != ba or ab != (gap > 1):
				push_error("Planting order mismatch: %s / %s at %f" % [first,second,gap])
				kit.free()
				terrain.free()
				quit(1)
				return
	kit.free()
	terrain.free()
	print("PLANTING_ORDER_OK ",checks," paired clearance checks")
	quit()
