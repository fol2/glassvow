extends "res://tools/map_workshop/common/fitted_routes.gd"
## Act II composition supplies the shared route kit with its approved inputs.
func _init() -> void:
	levels = preload("res://tools/map_workshop/common/terrace_levels.gd").new()
	ruin_plan = preload("res://tools/map_workshop/act2/ruin_plan.gd").new()
	bridge_style = preload("res://tools/map_workshop/stone_bridge/presets.gd").drowned_city()
