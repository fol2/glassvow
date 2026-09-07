extends Node3D
## The court's sole fragmented structure: a restrained ceremonial apparition.
const M = preload("res://tools/map_workshop/mesh_tools.gd")
func _ready() -> void:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color("50334d")
	material.metallic = .65
	material.roughness = .35
	material.emission_enabled = true
	material.emission = Color("7b244f")
	material.emission_energy_multiplier = .65
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for arc: Vector2 in [Vector2(8,53),Vector2(66,115),Vector2(123,169),
		Vector2(183,222),Vector2(234,279),Vector2(294,347)]:
		for step: int in range(12):
			var a: float = deg_to_rad(lerpf(arc.x,arc.y,float(step)/12))
			var b: float = deg_to_rad(lerpf(arc.x,arc.y,float(step+1)/12))
			var ai: Vector3 = Vector3(cos(a)*3.8,0,sin(a)*3.8)
			var ao: Vector3 = Vector3(cos(a)*4.04,0,sin(a)*4.04)
			var bi: Vector3 = Vector3(cos(b)*3.8,0,sin(b)*3.8)
			var bo: Vector3 = Vector3(cos(b)*4.04,0,sin(b)*4.04)
			var lift: Vector3 = Vector3(0,.13,0)
			_quad(surface,ai,bi,bo,ao)
			_quad(surface,ao+lift,bo+lift,bi+lift,ai+lift)
			_quad(surface,ao,bo,bo+lift,ao+lift)
			_quad(surface,bi,ai,ai+lift,bi+lift)
			if step == 0:
				_quad(surface,ai,ao,ao+lift,ai+lift)
			if step == 11:
				_quad(surface,bo,bi,bi+lift,bo+lift)
	var apparition: MeshInstance3D = M.node(self,M.finish(surface),material,"FracturedSovereignHalo")
	apparition.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func _process(delta: float) -> void:
	rotate_y(delta*.035)
static func _quad(surface: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3) -> void:
	M.triangle(surface,a,b,c)
	M.triangle(surface,a,c,d)
