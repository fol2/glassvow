extends RefCounted
const VERSION: String = "obsidian-court-surface-v3"
static func finish(source: MapLayoutResult,landscape: Node3D) -> Dictionary:
	return preload("res://presentation/map/chapters/common/measured_realisation.gd").finish(source,landscape,VERSION,"obsidian-court-surround")
