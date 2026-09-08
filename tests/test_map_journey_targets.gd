extends RefCounted
## Actual Controls must match the compiler's hit envelope at every shipping shape.
static func run(fails: Array[String]) -> void:
	for shape: StringName in StageShape.SHIPPING:
		var stage: Vector2 = Vector2(StageShape.REFERENCES[shape])
		var target: float = MapJourneyCameraContract.touch_size(stage)
		for kind: String in GlassWaystone.GLYPH_KINDS:
			var stone: GlassWaystone = GlassWaystone.new(0,kind,210,"",true)
			stone.set_journey_presentation(false,true)
			stone.set_touch_min(target,1.0)
			if stone.size!=Vector2.ONE*target or target<60:
				fails.append("journey target: actual Control differs from declared hit envelope: "+str(shape)+"/"+kind)
			var glyph_centre: Vector2 = stone._glyph_art.position+stone._glyph_art.size*.5
			if not glyph_centre.is_equal_approx(stone.size*.5):
				fails.append("journey target: glyph is not centred on its actual hit area")
			stone.free()
