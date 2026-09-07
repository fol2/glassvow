extends RefCounted
const VERSION: String = "drowned-city-surface-v2"
static func finish(source: MapLayoutResult,landscape: Node3D) -> Dictionary:
	return preload("res://presentation/map/chapters/common/measured_realisation.gd").finish(source,landscape,VERSION,"drowned-city-surround")
