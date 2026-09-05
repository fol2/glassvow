extends SceneTree
## Check every generated earth-road centreline against the uploaded mask source.
const Terrain = preload("res://tools/map_workshop/terrain.gd")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var terrain: Terrain = Terrain.new()
	root.add_child(terrain)
	var sample: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/map/studies/camera-composition/act1-seed717.json"))
	terrain.build(sample, false)
	var land: MeshInstance3D = terrain.get_node("Quiet sculpted ground") as MeshInstance3D
	var raw: Variant = land.material_override.get_meta("distance_image")
	if not raw is Image:
		quit(1)
		return
	var image: Image = raw
	var maximum: float = 0
	var count: int = 0
	for line: PackedVector3Array in terrain.lines:
		for index: int in range(line.size() - 1):
			var a: Vector3 = line[index]
			var b: Vector3 = line[index + 1]
			var steps: int = maxi(1, ceili(a.distance_to(b) / 0.15))
			for step: int in range(steps + 1):
				var p: Vector3 = a.lerp(b, float(step) / steps)
				if terrain.is_elevated(p):
					continue
				var x: int = clampi(floori((p.x+48)/96*image.get_width()),0,image.get_width()-1)
				var y: int = clampi(floori((p.z+30)/60*image.get_height()),0,image.get_height()-1)
				maximum = maxf(maximum,image.get_pixel(x,y).r)
				count += 1
	print("ROUTE_PAINT_AUDIT ", JSON.stringify({"samples":count,"max_centreline_distance":maximum,"limit":0.25}))
	quit(0 if count > 0 and maximum < 0.25 else 1)
