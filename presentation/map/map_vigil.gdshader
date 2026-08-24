shader_type spatial;
render_mode unshaded, cull_back;

// THE ONE BUILDING ON THE MAP, and the one surface here that is unwrapped
// rather than projected.
//
// Read map_prop.gdshader first. Everything about the light is its: unshaded,
// the same quantised ramp between the act's `band_shade` and `band_key`, the
// same grade lookup by world XZ with alpha pushing N·L down the ramp for
// contact. If `ramp()` moves there it moves here, or the Vigil lights
// differently from the ground it stands on and the silhouette comes apart.
//
// WHAT DIFFERS, AND WHY IT IS ALLOWED TO. The prop shader projects because its
// geometry is BOUGHT untextured: with 23 separately generated kits, an unwrap
// per kit is 23 chances for texture style to drift, so the map surfaces
// everything itself and a bought GLB's UVs are deliberately ignored.
//
// The Vigil is not bought. It is authored in `tools/make_act1_vigil.py`, so its
// UVs are ours too, and they are not an auto-unwrap: V is world height over the
// building's height and U runs around it. A band painted at a fraction of the
// sheet therefore lands at that fraction of the BUILDING on every face, roof
// included — plinth, coursed wall, corbel, slate, smoke. Triplanar cannot do
// that. It has no idea which way is up on a given face, so it would put the
// same stone on the plinth and the ridge.
//
// This is the only asset with the exception, and `map_asset_checks.inspect_glb`
// names it rather than opening TEXCOORD_0 to the map at large.

uniform vec3 sun = vec3(-0.35, 0.78, 0.52);
uniform int bands = 3;
uniform vec3 band_shade : source_color = vec3(0.14, 0.16, 0.28);
uniform vec3 band_key : source_color = vec3(0.96, 0.88, 0.72);

uniform sampler2D grade : filter_linear, repeat_disable, source_color;
uniform vec4 grade_rect = vec4(-64.0, -64.0, 128.0, 128.0);
uniform float contact = 0.55;

// The sheet. U repeats around the building; V does not, and must not — it is
// the height axis, so wrapping it would fold the roof back onto the plinth.
uniform sampler2D trim : filter_linear_mipmap, repeat_enable;
// Where the building sits against the value ladder. Well above the scenery's
// 0.100: this is the one built thing in Act I and it should not read as another
// rock. Below the road's 0.880, so the road still leads the eye.
uniform float surface_value = 0.620;
uniform float tex_mean = 0.5;

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
	// V is clamped, not wrapped: the mesh already bakes height into 0..1, and a
	// fragment that lands a hair outside from interpolation must take the band
	// at the end rather than the one at the other end of the building.
	vec2 uv = vec2(UV.x, clamp(UV.y, 0.001, 0.999));
	vec3 albedo = texture(trim, uv).rgb * (surface_value / max(tex_mean, 1e-4));
	vec4 g = texture(grade, (world_pos.xz - grade_rect.xy) / grade_rect.zw);
	float nl = dot(normalize(world_n), normalize(sun)) * 0.5 + 0.5;
	nl -= (1.0 - g.a) * contact;
	ALBEDO = albedo * ramp_value(nl) * g.rgb;
}
