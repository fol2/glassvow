extends RefCounted
## Local illumination belongs to the placed model and follows its rotation.
static func attach_trial(model: Node3D) -> bool:
	var source: PackedScene = load("res://assets/art/map-journey/lamp-pair.glb") as PackedScene
	if source == null:
		return false
	model.add_child(source.instantiate())
	attach(model, "amber-arch")
	return true

static func attach(model: Node3D, kind: String) -> void:
	if kind != "amber-arch":
		return
	for side: int in [-1, 1]:
		var lamp: OmniLight3D = OmniLight3D.new()
		lamp.name = "Amber lamp " + str(side)
		# Outside the opaque glass proxy so its shell cannot shadow the source.
		lamp.position = Vector3(side * 2.30, 2.21, 0.72)
		lamp.light_color = Color("ffb85b")
		lamp.light_energy = 2.8
		lamp.omni_range = 3.2
		lamp.omni_attenuation = 1.5
		lamp.shadow_enabled = true
		model.add_child(lamp)
