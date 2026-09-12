extends RefCounted
const Sightlines = preload("res://tools/map_workshop/common/precinct_sightlines.gd")
static func run(fails: Array[String]) -> void:
	var query: Sightlines = Sightlines.new()
	var faces: PackedVector3Array = []
	for interval: Vector2 in [Vector2(-2,-1),Vector2(1,2)]:
		faces.append_array(PackedVector3Array([Vector3(interval.x,-2,0),Vector3(interval.y,-2,0),Vector3(interval.y,2,0),
			Vector3(interval.x,-2,0),Vector3(interval.y,2,0),Vector3(interval.x,2,0)]))
	query.meshes.append({"bounds":AABB(Vector3(-2,-2,-.001),Vector3(4,4,.002)),"faces":faces})
	if query.segment_blocked(Vector3(0,0,5),Vector3(0,0,-5)):
		fails.append("sightline: open doorway treated as solid bounding box")
	if not query.segment_blocked(Vector3(1.5,0,5),Vector3(1.5,0,-5)):
		fails.append("sightline: opaque jamb did not block")
	if query.segment_blocked(Vector3(1.5,0,5),Vector3(1.5,0,1)):
		fails.append("sightline: wall behind target counted as occlusion")
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in range(260):
		var x: float = index*3.0
		for point: Vector3 in [Vector3(x,0,0),Vector3(x+1,0,0),Vector3(x,1,0)]:
			surface.add_vertex(point)
	var item: MeshInstance3D = MeshInstance3D.new()
	item.mesh = surface.commit()
	var batched: Sightlines = Sightlines.new()
	batched.cache_faces(item.mesh.get_faces())
	var direct: Sightlines = Sightlines.new()
	direct.meshes.append({"bounds":item.mesh.get_aabb().grow(.0001),"faces":item.mesh.get_faces()})
	for index: int in range(260):
		for offset: float in [.2,1.5]:
			var origin: Vector3 = Vector3(index*3.0+offset,.2,2)
			var target: Vector3 = origin-Vector3(0,0,4)
			if batched.segment_blocked(origin,target)!=direct.segment_blocked(origin,target):
				fails.append("sightline: triangle batching changed a hit or clear result")
	if batched.meshes.size()!=3:
		fails.append("sightline: large mesh not divided into bounded triangle batches")
	item.free()
	var culled: Sightlines = Sightlines.new()
	var triangle: PackedVector3Array = PackedVector3Array([Vector3(0,0,0),Vector3(1,0,0),Vector3(0,1,0)])
	culled.cache_faces(triangle,Transform3D.IDENTITY,BaseMaterial3D.CULL_BACK)
	if culled.segment_blocked(Vector3(.2,.2,2),Vector3(.2,.2,-2)):
		fails.append("sightline: culled rear face blocks a visible target")
	if not culled.segment_blocked(Vector3(.2,.2,-2),Vector3(.2,.2,2)):
		fails.append("sightline: rendered front face does not block")
	for mode: int in [BaseMaterial3D.CULL_FRONT,BaseMaterial3D.CULL_DISABLED]:
		var other: Sightlines = Sightlines.new()
		other.cache_faces(triangle,Transform3D.IDENTITY,mode)
		if not other.segment_blocked(Vector3(.2,.2,2),Vector3(.2,.2,-2)):
			fails.append("sightline: visible rear face did not block")
		if other.segment_blocked(Vector3(.2,.2,-2),Vector3(.2,.2,2)) != (mode==BaseMaterial3D.CULL_DISABLED):
			fails.append("sightline: front-cull and double-sided materials disagree")
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.cull_mode = BaseMaterial3D.CULL_FRONT
	if query._cull_mode(material)!=BaseMaterial3D.CULL_FRONT or query._cull_mode(null)!=BaseMaterial3D.CULL_DISABLED:
		fails.append("sightline: explicit material culling or unknown fallback lost")
	for option: String in ["", "render_mode cull_disabled;", "render_mode cull_front;"]:
		var shader_material: ShaderMaterial = ShaderMaterial.new()
		shader_material.shader = Shader.new()
		shader_material.shader.code = "shader_type spatial; "+option
		var expected: int = BaseMaterial3D.CULL_BACK if option.is_empty() else (BaseMaterial3D.CULL_FRONT if "cull_front" in option else BaseMaterial3D.CULL_DISABLED)
		if query._cull_mode(shader_material)!=expected:
			fails.append("sightline: shader culling differs from rendering")
