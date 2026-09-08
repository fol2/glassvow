extends RefCounted
## Query-only coarse indices retain the full interpolation support of live decks.
static func run(fails: Array[String]) -> void:
	var fine: RefCounted = preload("res://presentation/map/chapters/common/smooth_surfaces.gd").new()
	var coarse: RefCounted = preload("res://presentation/map/chapters/common/smooth_surfaces.gd").new()
	coarse.query_cell_size=.5
	var spans: Array[Dictionary] = []
	for i: int in range(30):
		var a: Vector3 = Vector3(i*.2,3+sin(i*.1)*.3,sin(i*.2))
		var b: Vector3 = Vector3((i+1)*.2,3+sin((i+1)*.1)*.3,sin((i+1)*.2))
		spans.append({"a":a,"b":b,"wa":1.0,"wb":1.0,"half_a":1.1,"half_b":1.1,"s":i*.2,"edge":"bend"})
	for field: RefCounted in [fine,coarse]:
		field.setup(spans,func(_x: float,_z: float) -> float: return -2.0)
	for span: Dictionary in spans:
		var p: Vector3 = span["a"]
		for lateral: int in range(-8,9):
			var at: Vector2 = Vector2(p.x,p.z+lateral*.1)
			var a: Dictionary = fine.field(at)
			var b: Dictionary = coarse.field(at)
			for key: String in ["height","bottom","distance"]:
				var old_value: float = a[key]
				var new_value: float = b[key]
				if absf(old_value-new_value)>.000001:
					fails.append("A cached route query changed "+key+" at "+str(at))
					return
