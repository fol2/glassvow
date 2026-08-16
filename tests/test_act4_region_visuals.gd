extends RefCounted
## #220 region-visual slice: every act owns one map/combat palette row, and the
## fourth combat weather rises as reversed hearth-light instead of inheriting
## Act III's astral storm.


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_act4_region_visuals: %s" % what)


static func run(fails: Array[String]) -> void:
	_map_rows(fails)
	_combat_rows(fails)
	_dawn_weather(fails)


static func _map_rows(fails: Array[String]) -> void:
	_check(fails, MapRegions.FALLBACK_SKIES.size() == LayoutBook.ACTS
		and MapRegions.FALLBACK_FOGS.size() == LayoutBook.ACTS
		and MapRegions.FALLBACK_PARTICLES.size() == LayoutBook.ACTS
		and MapRegions.FALLBACK_GLOWS.size() == LayoutBook.ACTS
		and MapRegions.FALLBACK_ACCENTS.size() == LayoutBook.ACTS,
		"all five map fallback arrays carry one row per act")
	_check(fails, MapRegions.WEATHER_BY_ACT.size() == LayoutBook.ACTS
		and MapRegions.BAND_SHADE.size() == LayoutBook.ACTS
		and MapRegions.BAND_KEY.size() == LayoutBook.ACTS,
		"map weather and light-arc arrays carry one row per act")
	_check(fails, MapRegions.GRADE_HUE_NEAR.size() == LayoutBook.ACTS
		and MapRegions.GRADE_HUE_FAR.size() == LayoutBook.ACTS
		and MapRegions.GRADE_HUE_CORRIDOR.size() == LayoutBook.ACTS,
		"all three map grade-hue arrays carry one row per act")
	_check(fails, MapRegions.WEATHER_BY_ACT[3] == &"dawn",
		"Act IV owns the dawn weather key")


static func _combat_rows(fails: Array[String]) -> void:
	_check(fails, SkyField.ACT_SKIES.size() == LayoutBook.ACTS
		and SkyField.ACT_FOGS.size() == LayoutBook.ACTS
		and SkyField.ACT_PARTICLES.size() == LayoutBook.ACTS
		and SkyField.ACT_GLOWS.size() == LayoutBook.ACTS
		and SkyField.WEATHER_ALPHA.size() == LayoutBook.ACTS,
		"combat sky and weather arrays carry one row per act")
	var map_dawn: MapRegions = MapRegions.for_act(3)
	var combat_dawn: SkyField = SkyField.new(3)
	_check(fails, combat_dawn._weather_mode == 3,
		"Act IV combat selects weather mode 3 instead of clamping to Act III")
	_check(fails, combat_dawn._sky.is_equal_approx(map_dawn.sky)
		and combat_dawn._fog.is_equal_approx(map_dawn.fog)
		and combat_dawn._particles.is_equal_approx(map_dawn.particles)
		and combat_dawn._glow.is_equal_approx(map_dawn.glow),
		"Act IV map and combat share the authored dawn palette")
	_check(fails, not combat_dawn._sky.is_equal_approx(SkyField.ACT_SKIES[2])
		and not combat_dawn._particles.is_equal_approx(SkyField.ACT_PARTICLES[2]),
		"Act IV combat is visibly distinct from the Act III storm")
	combat_dawn.free()

	var clamped: SkyField = SkyField.new(99)
	_check(fails, clamped._weather_mode == 3,
		"future out-of-range act values clamp to the final authored row")
	clamped.free()


static func _dawn_weather(fails: Array[String]) -> void:
	var dawn: SkyField = SkyField.new(3)
	dawn.size = Vector2(800.0, 600.0)
	dawn._seed_field()
	dawn._weather[0].at = Vector2(400.0, 300.0)
	dawn._weather[0].seed = 0.25
	var before_y: float = dawn._weather[0].at.y
	dawn._step_weather(0.1)
	_check(fails, dawn._weather[0].at.y < before_y,
		"Act IV cinders rise rather than fall or run sideways")

	dawn._weather[0].at = Vector2(
		400.0, -dawn._weather[0].radius * SkyField.DAWN_LEN - 1.0)
	dawn._step_weather(0.0)
	_check(fails, dawn._weather[0].at.y > dawn.size.y,
		"a dawn cinder leaving the top recycles below the stage")

	dawn._t = SkyField.LIGHTNING_SLOT * 2.0
	dawn._step_lightning(0.1)
	_check(fails, is_zero_approx(dawn._lightning) and dawn._lit_slot == -1,
		"Act III heat lightning does not leak into the Act IV dawn")
	dawn.free()
