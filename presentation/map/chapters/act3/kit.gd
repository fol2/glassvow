extends RefCounted
## Approved model geometry with the shared combat/map obsidian finish.
const SOURCES: Dictionary = {
	"obsidian-great-hall":preload("res://assets/map/act3/obsidian-great-hall.glb"),
	"covered-cloister-bay":preload("res://assets/map/act3/covered-cloister-bay.glb"),
	"glazed-gallery-bay":preload("res://assets/map/act3/glazed-gallery-bay.glb"),
	"cloister-bay":preload("res://assets/map/act3/cloister-bay.glb")}
var materials: Dictionary = {}

func instance(asset_name: String) -> Node3D:
	var scene: PackedScene = SOURCES[asset_name]
	var item: Node3D = scene.instantiate()
	item.set_meta("asset_name",asset_name)
	for child: Node in item.find_children("*","MeshInstance3D",true,false):
		var mesh: MeshInstance3D = child
		for surface: int in range(mesh.mesh.get_surface_count()):
			var original: Material = mesh.mesh.surface_get_material(surface)
			if not original is StandardMaterial3D: continue
			var roof: bool = original.resource_name.begins_with("Intact slate")
			if not roof and not original.resource_name.begins_with("Obsidian broad"): continue
			var key: String = asset_name+"/"+str(original.get_instance_id())
			if not materials.has(key):
				var standard: StandardMaterial3D = original
				var dressed: ShaderMaterial = stone(standard.albedo_color,Vector2(6.4,5.6) if roof else Vector2(6,2.4),.20,.20)
				dressed.set_shader_parameter("architectural_mapping",true)
				if asset_name in ["obsidian-great-hall","glazed-gallery-bay"]:
					dressed.set_shader_parameter("structural_joint_height",.32)
					dressed.set_shader_parameter("roughness_range",Vector2(.22,.40))
				materials[key]=dressed
			var replacement: Material = materials[key]
			mesh.set_surface_override_material(surface,replacement)
	return item

static func stone(colour: Color,slab: Vector2,coverage: float,strength: float) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader=preload("res://presentation/map/chapters/common/precinct_stone.gdshader")
	material.set_shader_parameter("roughness_range",Vector2(.42,.58))
	material.set_shader_parameter("obsidian_facets",true)
	material.set_shader_parameter("stone_colour",colour)
	material.set_shader_parameter("slab_size",slab)
	material.set_shader_parameter("joint_coverage",coverage)
	material.set_shader_parameter("joint_strength",strength)
	return material

static func glazing_light(parent: Node3D,position: Vector3,reach: float,energy: float) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.name="RecessedGlazingSpill"
	light.position=position
	light.light_color=Color("b33b9e")
	light.light_energy=energy
	light.omni_range=reach
	light.omni_attenuation=1.5
	light.light_specular=.35
	parent.add_child(light)
