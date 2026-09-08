extends RefCounted
## Adjacent corridors must not acquire a cliff when stair ownership changes.
static func run(fails: Array[String]) -> void:
	var field: RefCounted = preload("res://presentation/map/chapters/common/smooth_surfaces.gd").new()
	var spans: Array[Dictionary] = [
		{"a":Vector3(0,3,0),"b":Vector3(2,3.8,0),"wa":1.0,"wb":1.0,"s":0.0,"edge":"stairs"},
		{"a":Vector3(0,4.8,1.8),"b":Vector3(2,4.8,1.8),"wa":1.0,"wb":1.0,"s":0.0,"edge":"neighbour"}]
	field.setup(spans,func(_x: float,_z: float) -> float: return -2.0)
	var grade: RefCounted = preload("res://presentation/map/chapters/stone_bridge/flight_grade.gd").new()
	var points: Array[Vector3] = [Vector3(0,3,0),Vector3(1,3.4,0),Vector3(2,3.8,0)]
	grade._store(points,"stairs")
	field.stair_profile=grade
	var previous: float = field.field(Vector2(1,0))["height"]
	var largest: float = 0.0
	for i: int in range(1,181):
		var height: float = field.field(Vector2(1,i*.01))["height"]
		largest=maxf(largest,absf(height-previous))
		previous=height
	if largest>.1: fails.append("Stair ownership introduces a height cliff: "+str(largest))
