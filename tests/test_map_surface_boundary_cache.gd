extends RefCounted
## Repeated clipping queries must retain the exact uncached surface geometry.
const Smooth = preload("res://presentation/map/chapters/common/smooth_surfaces.gd")
class Uncached extends Smooth:
	func _position(item: Dictionary) -> Vector3:
		var at: Vector2 = item["at"]
		var height: float = item["height"]
		var distance: float = item["distance"]
		if absf(distance)<.00000001:
			height=field(at)["height"]
		return Vector3(at.x,height,at.y)

static func run(fails: Array[String]) -> void:
	var spans: Array[Dictionary] = []
	var points: PackedVector3Array = [Vector3(-2,3,0),Vector3(0,3.5,0),Vector3(1,3.7,1),Vector3(1,3.7,3)]
	for i: int in range(points.size()-1):
		spans.append({"a":points[i],"b":points[i+1],"wa":1.0,"wb":1.0,"half_a":.92,"half_b":1.1,"s":float(i),"edge":"bend"})
	var cached: Smooth = Smooth.new()
	var reference: Smooth = Uncached.new()
	var previous: PackedByteArray = []
	for pass_index: int in range(2):
		if pass_index==1:
			for span: Dictionary in spans:
				span["a"]+=Vector3.UP
				span["b"]+=Vector3.UP
		var results: Array = []
		for field: Smooth in [reference,cached]:
			field.setup(spans,func(_x: float,_z: float) -> float: return -2.0)
			var surfaces: Array = []
			var top: SurfaceTool = SurfaceTool.new()
			var sides: SurfaceTool = SurfaceTool.new()
			top.begin(Mesh.PRIMITIVE_TRIANGLES)
			sides.begin(Mesh.PRIMITIVE_TRIANGLES)
			field.append(top,sides)
			for builder: SurfaceTool in [top,sides]:
				builder.generate_normals()
				surfaces.append(builder.commit().surface_get_arrays(0))
			results.append(surfaces)
		if pass_index==1 and var_to_bytes(results[1])==previous:
			fails.append("Repeated setup retained the previous mesh heights")
		previous=var_to_bytes(results[1])
		if var_to_bytes(results[0])!=var_to_bytes(results[1]):
			fails.append("Boundary cache changed deck/body geometry or retained old heights after setup")
