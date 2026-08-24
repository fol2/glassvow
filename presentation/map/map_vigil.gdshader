shader_type spatial;
render_mode unshaded, cull_back;

// THE ONE BUILDING ON THE MAP, and the one surface here that is sampled by its
// own UVs rather than projected.
//
// Read map_prop.gdshader first. Everything about the light is its: unshaded,
// the same quantised ramp between the act's `band_shade` and `band_key`, the
// same grade lookup by world XZ with alpha pushing N·L down the ramp for
// contact. If `ramp()` moves there it moves here, or the Vigil lights
// differently from the ground it stands on and the silhouette comes apart.
//
// WHAT DIFFERS, AND WHY. The prop shader projects because its geometry is
// bought untextured: with 23 separately generated kits, an unwrap per kit is
// 23 chances for texture style to drift, so the map surfaces everything itself
// and a bought GLB's UVs are deliberately ignored. That is still how the kits
// work, and it is still the right call FOR ROCKS.
//
// The Vigil is not a rock. It is the one built thing on the map, and what makes
// a building read as a building is exactly what projection cannot place:
// coursed ashlar that lines up along the wall, a corbel band where the roof
// meets it, slate above and not below. Its geometry arrives from Tripo with a
// baked albedo and the unwrap that goes with it, so it samples that.
//
// Until 2026-08-24 this instead sampled a hand-authored trim sheet whose V axis
// was the building's height. That was a workaround for a gate that refused
// textures, not a better idea: it could only ever paint horizontal bands, so
// the arched door, the buttress faces and the gable had no way to differ from
// the wall behind them.

uniform vec3 sun = vec3(-0.35, 0.78, 0.52);
uniform int bands = 3;
uniform vec3 band_shade : source_color = vec3(0.14, 0.16, 0.28);
uniform vec3 band_key : source_color = vec3(0.96, 0.88, 0.72);

uniform sampler2D grade : filter_linear, repeat_disable, source_color;
uniform vec4 grade_rect = vec4(-64.0, -64.0, 128.0, 128.0);
uniform float contact = 0.55;

// The baked albedo, carried inside the GLB and handed over by MapMaterials.
// `repeat_disable`: these are atlas UVs, so a fragment that lands a hair
// outside its chart must clamp to the chart edge, never wrap to another one.
uniform sampler2D surface_tex : filter_linear_mipmap, repeat_disable;
// Where the building sits against the value ladder: well above the scenery's
// 0.100, below the road's 0.880 so the road still leads the eye.
//
// NOT the 0.620 the ladder would like, and the texture is why. `surface_value`
// is a target for the MEAN, and this atlas has a mean of 0.252 with a long
// bright tail, so 0.620 multiplies by 2.46 and drives 4.5% of texels past 1.0
// (p99 = 1.38): the sunlit walls blow flat and the courses vanish exactly where
// the light is best. 0.450 multiplies by 1.79 and clips 0.04% (p99 = 0.93),
// which keeps the whole tonal range inside the ramp. Re-measure if the atlas is
// ever re-baked — it is a property of that image, not a taste call.
//
// It lands near the ground's 0.420 and the building still separates from it,
// because a mean is not a value: the slate roof sits far below that mean and
// the lit ashlar far above, which is the roof-over-wall read.
uniform float surface_value = 0.450;
// Measured over the baked atlas, which Tripo pads to 99.3% coverage — so this
// is the real mean of the building's own surface, not one diluted by gutters.
uniform float tex_mean = 0.252;

varying vec3 world_pos;
varying vec3 world_n;

// Duplicated from map_prop.gdshader on purpose — see the header there.
vec3 ramp_value(float nl) {
	float n = float(max(bands, 2));
	float q = min(floor(clamp(nl, 0.0, 1.0) * n), n - 1.0) / (n - 1.0);
	return mix(band_shade, band_key, q);
}


void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 albedo = texture(surface_tex, UV).rgb * (surface_value / max(tex_mean, 1e-4));
	vec4 g = texture(grade, (world_pos.xz - grade_rect.xy) / grade_rect.zw);
	float nl = dot(normalize(world_n), normalize(sun)) * 0.5 + 0.5;
	nl -= (1.0 - g.a) * contact;
	ALBEDO = albedo * ramp_value(nl) * g.rgb;
}
