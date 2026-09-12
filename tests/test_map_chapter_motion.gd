extends RefCounted
## Reduced motion reaches chapter effects, including CPU-driven halo rotation.
static func run(fails: Array[String]) -> void:
	var court: Node3D = preload("res://presentation/map/chapters/act3/landscape.gd").new()
	court.halo=Node3D.new()
	var halo: Node3D = court.halo
	court.add_child(halo)
	court.set_ambient_motion(false)
	if court.halo.is_processing(): fails.append("court motion: disabled halo still processes")
	court.set_ambient_motion(true)
	if not court.halo.is_processing(): fails.append("court motion: halo did not resume")
	court.free()
	var procession: Node3D = preload("res://presentation/map/chapters/act4/landscape.gd").new()
	procession.void_material=ShaderMaterial.new()
	procession.void_material.shader=preload("res://presentation/map/chapters/act4/void_background.gdshader")
	procession.embers=preload("res://presentation/map/chapters/act4/embers.gd").new()
	var embers: Node3D = procession.embers
	procession.add_child(embers)
	procession.embers.material=ShaderMaterial.new()
	procession.embers.material.shader=preload("res://presentation/map/chapters/act4/embers.gdshader")
	for enabled: bool in [false,true]:
		procession.set_ambient_motion(enabled)
		var expected: float = 1.0 if enabled else 0.0
		if procession.void_material.get_shader_parameter("motion")!=expected or procession.embers.material.get_shader_parameter("motion")!=expected:
			fails.append("void motion: background and embers did not follow the motion preference")
	procession.free()
