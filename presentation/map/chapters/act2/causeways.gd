extends "res://presentation/map/chapters/common/fitted_routes.gd"
## Act II composition supplies the shared route kit with its approved inputs.
func _init() -> void:
	levels = preload("res://presentation/map/chapters/common/terrace_levels.gd").new()
	ruin_plan = preload("res://presentation/map/chapters/act2/ruin_plan.gd").new()
	bridge_style = preload("res://presentation/map/chapters/stone_bridge/presets.gd").drowned_city()
	bridge_style["sample_spacing"] = .8
