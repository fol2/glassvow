extends RefCounted
class Lower extends RefCounted:
	var calls: int = 0
	func field(_at: Vector2) -> Dictionary:
		calls+=1
		return {"distance":-.2,"height":3.022}

static func run(fails: Array[String]) -> void:
	var lower: Lower = Lower.new()
	var upper: RefCounted = preload("res://presentation/map/chapters/common/landing_surfaces.gd").new()
	upper.lower=lower
	var spans: Array[Dictionary] = [{"a":Vector3(0,3,0),"b":Vector3(3,3,0),"wa":1.0,"wb":1.0,"s":0.0,"edge":"upper"}]
	upper.setup(spans,func(_x: float,_z: float) -> float: return -2.0)
	var absent: Dictionary = upper.field(Vector2(20,20))
	if absent["distance"]!=INF or absent.get("delegated",false) or lower.calls!=0:
		fails.append("An absent upper deck still queries or delegates to the lower layer")
	var joined: Dictionary = upper.field(Vector2(1,0))
	var joined_distance: float = joined["distance"]
	if lower.calls!=1 or not joined.get("delegated",false) or absf(joined_distance-.2)>.000001:
		fails.append("Real shared landings no longer delegate exact-height deck ownership")
