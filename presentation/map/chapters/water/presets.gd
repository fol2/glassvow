extends RefCounted
## Mood controls, separate from rendering. Later chapters can supply their own.
static func drowned_city() -> Dictionary:
	return {
		"shallow_colour": Color("386368"), "deep_colour": Color("15333f"),
		"absorption": .8, "foam_width": .08, "foam_strength": .14,
		"ripple_scale": .12, "ripple_speed": .055, "normal_strength": .07,
		"refraction_strength": .012, "surface_roughness": .48, "surface_specular": .22,
		"caustic_strength": .035,
		"toon_strength": .42, "crest_colour": Color("527b82"),
	}

static func quiet_river() -> Dictionary:
	return {
		"shallow_colour": Color("344b45"), "deep_colour": Color("101f27"),
		"absorption": 1.2, "foam_width": .18, "foam_strength": .25,
		"ripple_scale": .18, "ripple_speed": .045, "normal_strength": .18,
		"refraction_strength": .01, "surface_roughness": .35,
		"caustic_strength": .02,
	}
