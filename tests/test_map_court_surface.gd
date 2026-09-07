extends RefCounted
const Court = preload("res://presentation/map/chapters/common/court_surface.gd")
static func run(fails: Array[String]) -> void:
	var patches: Array[Dictionary] = [{"height":2.0,"outline":PackedVector2Array([
		Vector2(0,0),Vector2(10,0),Vector2(10,10),Vector2(0,10)])}]
	var routes: Array[Dictionary] = [{"ok":true,"tops":[PackedVector3Array([
		Vector3(4,0,0),Vector3(6,0,0),Vector3(6,0,10),Vector3(4,0,10)])]}]
	var result: Dictionary = Court.resolve(patches,routes)
	var area: float = 0.0
	for face: PackedVector3Array in result["tops"]:
		area += (face[1]-face[0]).cross(face[2]-face[0]).length()*.5
		var centre: Vector3 = (face[0]+face[1]+face[2])/3.0
		if centre.x > 4.00001 and centre.x < 5.99999:
			fails.append("court: raised court covers lower passage")
	if absf(area-80.0) > .0001:
		fails.append("court: route cut-out changed remaining area")

	for wall: PackedVector3Array in result["walls"]:
		var centre: Vector3 = (wall[0]+wall[1]+wall[2]+wall[3])*.25
		if centre.x > 4.00001 and centre.x < 5.99999:
			fails.append("court: retaining wall blocks passage opening")

	var cut_wall_area: float = 0.0
	for wall: PackedVector3Array in result["walls"]:
		if absf(wall[0].x-wall[2].x)<.001 and (absf(wall[0].x-4)<.001 or absf(wall[0].x-6)<.001):
			cut_wall_area += (wall[1]-wall[0]).cross(wall[2]-wall[0]).length()
	if absf(cut_wall_area-40.0)>.001:
		fails.append("court: lower route cut-out has no complete retaining sides")

	var left: PackedVector2Array = [Vector2(4,0),Vector2(5,0),Vector2(5,10),Vector2(4,10)]
	var right: PackedVector2Array = [Vector2(5,0),Vector2(6,0),Vector2(6,10),Vector2(5,10)]
	var joined_masks: Array[PackedVector2Array] = [left,right,left]
	var levels: Array[float] = [0.0,0.0,0.0]
	var patch_outline: PackedVector2Array = patches[0]["outline"]
	var joined_walls: Array[PackedVector3Array] = Court._cut_walls(patch_outline,2.0,joined_masks,levels)
	var joined_area: float = 0.0
	for wall: PackedVector3Array in joined_walls:
		joined_area += (wall[1]-wall[0]).cross(wall[2]-wall[0]).length()
		if absf(wall[0].x-5)<.001 and absf(wall[2].x-5)<.001:
			fails.append("court: shared tread boundary became a blocking wall")
	if absf(joined_area-40.0)>.001:
		fails.append("court: duplicated masks doubled or removed an exterior wall")
