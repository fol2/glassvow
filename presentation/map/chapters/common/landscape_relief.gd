extends RefCounted
const F = preload("res://domain/map_layout/map_layout_canonical.gd")
## Broad authored landforms with level architectural reserves; no shader displacement.
static func resolve_profile(profile: Dictionary, reserves: Array[Rect2]) -> Dictionary:
	var resolved: Dictionary = profile.duplicate(true)
	for form: Dictionary in resolved.get("landforms",[]):
		if not form.has("reserve_index"):
			continue
		var reserve: Rect2 = reserves[int(F.float_value(form["reserve_index"]))]
		var fraction: float = F.float_value(form.get("along",.5))
		var offset: float = F.float_value(form.get("offset",12.0))
		form["x"] = lerpf(reserve.position.x,reserve.end.x,fraction)
		form["z"] = reserve.position.y-offset if form.get("side","near") == "near" else reserve.end.y+offset
	return resolved

static func height_at(point: Vector2, profile: Dictionary, reserves: Array[Rect2]) -> float:
	var height: float = F.float_value(profile.get("base_height",-2.0))
	for form: Dictionary in profile.get("landforms",[]):
		var centre: Vector2 = Vector2(F.float_value(form["x"]),F.float_value(form["z"]))
		var radius: Vector2 = Vector2(F.float_value(form["radius_x"]),F.float_value(form["radius_z"]))
		var distance: float = ((point-centre)/radius).length_squared()
		height += F.float_value(form["height"])*exp(-distance*2.0)
	var distance_to_reserve: float = INF
	for reserve: Rect2 in reserves:
		var nearest: Vector2 = Vector2(clampf(point.x,reserve.position.x,reserve.end.x),clampf(point.y,reserve.position.y,reserve.end.y))
		distance_to_reserve = minf(distance_to_reserve,point.distance_to(nearest))
	var blend: float = smoothstep(0.0,F.float_value(profile.get("shoulder_width",10.0)),distance_to_reserve)
	return lerpf(F.float_value(profile.get("contact_height",-.1)),height,blend)

static func build(bounds: Rect2, profile: Dictionary, reserves: Array[Rect2], material: Material) -> MeshInstance3D:
	var pitch: float = F.float_value(profile.get("mesh_pitch",2.0))
	var columns: int = ceili(bounds.size.x/pitch)
	var rows: int = ceili(bounds.size.y/pitch)
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faceted: bool = profile.get("faceted",false)
	for row: int in range(rows):
		for column: int in range(columns):
			var corners: Array[Vector3] = []
			for offset: Vector2i in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.ONE,Vector2i.DOWN]:
				var point: Vector2 = bounds.position+bounds.size*Vector2(float(column+offset.x)/columns,float(row+offset.y)/rows)
				corners.append(Vector3(point.x,height_at(point,profile,reserves),point.y))
			var indices: Array[int] = [0,1,2,0,2,3]
			for face_vertex: int in range(6):
				var index: int = indices[face_vertex]
				var vertex: Vector3 = corners[index]
				var point: Vector2 = Vector2(vertex.x,vertex.z)
				var dx: float = height_at(point+Vector2(.05,0),profile,reserves)-height_at(point-Vector2(.05,0),profile,reserves)
				var dz: float = height_at(point+Vector2(0,.05),profile,reserves)-height_at(point-Vector2(0,.05),profile,reserves)
				var normal: Vector3 = Vector3(-dx,.1,-dz).normalized()
				if faceted:
					var start: int = (face_vertex/3)*3
					normal = (corners[indices[start+2]]-corners[indices[start]]).cross(corners[indices[start+1]]-corners[indices[start]]).normalized()
				surface.set_normal(normal)
				surface.add_vertex(vertex)
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = "LandscapeRelief"
	instance.mesh = surface.commit()
	instance.material_override = material
	return instance
