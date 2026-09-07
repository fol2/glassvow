extends RefCounted
const Masonry = preload("res://tools/map_workshop/common/passage_masonry.gd")
static func run(fails: Array[String]) -> void:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var upper: Array = [[-8,3.1,0],[-2,3.1,0],[2,3.1,0],[8,3.1,0]]
	var lower: Array = [[0,0,-10],[0,0,10]]
	Masonry._foundation(surface,upper,lower,2.5,2.5,.65)
	var mesh: ArrayMesh = surface.commit()
	var faces: PackedVector3Array = mesh.get_faces()
	for vertex: Vector3 in faces:
		if vertex.y > 2.4501:
			fails.append("foundation: overlaps the walking deck thickness")
			break
	for point: Vector2 in [Vector2(-5,0),Vector2(5,0)]:
		if not _has_top(faces,point):
			fails.append("foundation: adjacent level segment left unsupported")
	if _has_top(faces,Vector2.ZERO):
		fails.append("foundation: lower passage filled")
static func _has_top(faces: PackedVector3Array,point: Vector2) -> bool:
	for index: int in range(0,faces.size(),3):
		var a: Vector3 = faces[index]
		var b: Vector3 = faces[index+1]
		var c: Vector3 = faces[index+2]
		if absf(a.y-2.45) > .001 or absf(b.y-2.45) > .001 or absf(c.y-2.45) > .001:
			continue
		if Geometry2D.is_point_in_polygon(point,PackedVector2Array([Vector2(a.x,a.z),Vector2(b.x,b.z),Vector2(c.x,c.z)])):
			return true
	return false
