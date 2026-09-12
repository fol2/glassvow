extends RefCounted
## Peripheral atmosphere only; no change to geometry, routes or target positions.
const Source: Shader = preload("res://presentation/map/map_horizon.gdshader")
var material: ShaderMaterial = ShaderMaterial.new()
var _pose: Transform3D
var _zoom: float = -1.0
var _view: Vector2 = Vector2.ZERO
func _init(bounds: Rect2) -> void:
	material.shader = Source
	material.set_shader_parameter("world_bounds",Vector4(bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y))
func update(camera: Camera3D, view: Vector2) -> void:
	if view.y<=0 or (camera.transform==_pose and camera.size==_zoom and view==_view): return
	_pose = camera.transform
	_zoom = camera.size
	_view = view
	var pitch: float = absf(camera.rotation.x)
	var centre: Vector2 = Vector2(camera.position.x,camera.position.z-camera.position.y/tan(pitch))
	material.set_shader_parameter("ground_centre",centre)
	material.set_shader_parameter("ground_span",Vector2(camera.size*view.x/view.y,camera.size/sin(pitch)))
