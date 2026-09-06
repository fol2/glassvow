extends "res://tools/map_workshop/common/fitted_routes.gd"
## Court paving reuses fitted routes and real stairs, without bridge furniture.
func _build_edges(_index: int,_trim: Material,_settings: Dictionary) -> void:
	pass

func _build_piers(_trim: Material,_settings: Dictionary) -> void:
	pass

func _soffit(height: float,s: float,total: float,raised: bool) -> float:
	# Only grade-separated crossings retain a ceiling; ordinary roads are solid.
	return super._soffit(height,s,total,raised) if raised else -1.8

func build(sample: Dictionary) -> void:
	super.build(sample)
	if not failure.is_empty():
		return
	for child: Node in get_children():
		if str(child.name).begins_with("ArchedCausewayStructure"):
			child.name = "CourtPavingFoundation"
	var foundations: RefCounted = preload("res://tools/map_workshop/act3/passage_foundations.gd").new()
	foundations.lower = fields[0]
	foundations.upper = fields[1]
	var broad_spans: Array[Dictionary] = []
	for span: Dictionary in fields[1].spans:
		var broad: Dictionary = span.duplicate()
		broad["half_a"] = 3.8
		broad["half_b"] = 3.8
		broad_spans.append(broad)
	foundations.setup(broad_spans,func(_x: float,_z: float) -> float: return -2.0)
	var top: SurfaceTool = SurfaceTool.new()
	var body: SurfaceTool = SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	body.begin(Mesh.PRIMITIVE_TRIANGLES)
	body.set_smooth_group(-1)
	foundations.append(top,body)
	for surface: SurfaceTool in [top,body]:
		var mesh: ArrayMesh = M.finish(surface)
		M.node(self,mesh,stone,"SolidCourtPassageTerrace")
		decoration_meshes.append(mesh)
