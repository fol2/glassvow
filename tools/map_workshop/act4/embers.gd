extends Node3D
## Sparse deterministic instanced embers in the void. No particle simulation/readback.
const COUNT: int = 42
var material: ShaderMaterial
func _ready() -> void:
	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = Vector2(.16,.25)
	material = ShaderMaterial.new()
	material.shader = preload("res://tools/map_workshop/act4/embers.gdshader")
	var multi: MultiMesh = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	multi.mesh = mesh
	multi.instance_count = COUNT
	for i: int in range(COUNT):
		var x: float = -58+fmod(i*37.71,116)
		var z: float = -42+fmod(i*23.13,82)
		var y: float = -12+fmod(i*5.17,34)
		multi.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(x,y,z)))
		multi.set_instance_custom_data(i,Color(fmod(i*.618,1),fmod(i*.317,1),fmod(i*.713,1),1))
	var item: MultiMeshInstance3D = MultiMeshInstance3D.new()
	item.multimesh = multi
	item.material_override = material
	item.custom_aabb = AABB(Vector3(-64,-20,-50),Vector3(128,70,110))
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(item)
