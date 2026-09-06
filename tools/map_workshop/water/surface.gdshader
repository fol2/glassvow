shader_type spatial;
render_mode cull_back, specular_schlick_ggx;

uniform vec3 shallow_colour : source_color = vec3(.12,.28,.29);
uniform vec3 deep_colour : source_color = vec3(.02,.07,.10);
uniform float absorption = .8;
uniform float foam_width = .24;
uniform float foam_strength = .3;
uniform float ripple_scale = .12;
uniform float ripple_speed = .025;
uniform float normal_strength = .22;
uniform float refraction_strength = .012;
uniform float surface_roughness = .3;
uniform float surface_specular = .25;
uniform float caustic_strength = .035;
uniform float toon_strength = .65;
uniform vec3 crest_colour : source_color = vec3(.30,.49,.51);
uniform float captured_time = -1.0;
uniform sampler2D normal_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D foam_noise : filter_linear_mipmap, repeat_enable;
uniform sampler2D scene_depth : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D scene_colour : hint_screen_texture, filter_linear_mipmap, repeat_disable;
varying vec3 world_at;

vec3 view_position(vec2 uv, mat4 inverse_projection) {
	float raw = textureLod(scene_depth, uv, 0.0).r;
	float ndc = OUTPUT_IS_SRGB ? raw * 2.0 - 1.0 : raw;
	vec4 at = inverse_projection * vec4(uv * 2.0 - 1.0, ndc, 1.0);
	return at.xyz / at.w;
}

void vertex() { world_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	float t = captured_time >= 0.0 ? captured_time : TIME;
	vec2 uv = world_at.xz * ripple_scale;
	vec3 a = texture(normal_a, uv + vec2(t * ripple_speed, t * ripple_speed * .35)).rgb * 2.0 - 1.0;
	vec3 b = texture(normal_b, uv * .73 + vec2(-t * ripple_speed * .8, t * ripple_speed * .2)).rgb * 2.0 - 1.0;
	// World XZ slopes, transformed into view space for lighting and refraction.
	// A tangent normal's Z points out of the surface, not along screen Y.
	vec2 slope = (a.xy + b.xy) * normal_strength;
	vec3 world_normal = normalize(vec3(slope.x, 1.0, slope.y));
	NORMAL = normalize(mat3(VIEW_MATRIX) * world_normal);
	vec3 bed_view = view_position(SCREEN_UV, INV_PROJECTION_MATRIX);
	vec3 bed_world = (INV_VIEW_MATRIX * vec4(bed_view, 1.0)).xyz;
	float thickness = max(0.0, -bed_view.z + VERTEX.z);
	float vertical_depth = max(0.0, world_at.y - bed_world.y);
	float depth_factor = 1.0 - exp(-thickness * absorption);
	vec2 offset = (mat3(VIEW_MATRIX) * vec3(slope.x, 0.0, slope.y)).xy;
	vec2 refracted_uv = clamp(SCREEN_UV + offset * refraction_strength * smoothstep(0.0, .35, vertical_depth), vec2(.001), vec2(.999));
	vec3 refracted_view = view_position(refracted_uv, INV_PROJECTION_MATRIX);
	vec3 refracted_world = (INV_VIEW_MATRIX * vec4(refracted_view, 1.0)).xyz;
	if (refracted_world.y > world_at.y || refracted_view.z > VERTEX.z) {
		refracted_uv = SCREEN_UV;
	}
	vec3 bed = textureLod(scene_colour, refracted_uv, 0.0).rgb;
	vec3 tint = mix(shallow_colour, deep_colour, depth_factor);
	vec3 colour = mix(bed, tint, .28 + .69 * depth_factor);
	vec2 drift = world_at.xz * vec2(.045, .095) + vec2(t * ripple_speed * .14, -t * ripple_speed * .08);
	drift += vec2(sin(drift.y * 13.0 + t * .37), cos(drift.x * 11.0 - t * .29)) * .035;
	float noise = texture(foam_noise, drift).r;
	float second = texture(foam_noise, drift * .79 + vec2(.31, .47) - vec2(t * .002, 0.0)).r;
	float aa = max(fwidth(noise) * 1.3, .012);
	float crest = smoothstep(.43-aa, .43+aa, noise) * (1.0-smoothstep(.48-aa, .48+aa, noise));
	crest *= smoothstep(.40, .63, second);
	float patches = smoothstep(.48-aa, .48+aa, second);
	// Overview needs a quiet sea behind the route graph. Fade graphic detail
	// with world-space pixel footprint, equally for orthographic/perspective.
	float footprint = max(length(dFdx(world_at.xz)), length(dFdy(world_at.xz)));
	float graphic_weight = toon_strength * mix(1.0,.14,smoothstep(.035,.11,footprint));
	colour = mix(colour, colour * 1.24, patches * graphic_weight * .55);
	colour = mix(colour, crest_colour, crest * graphic_weight * smoothstep(.02,.35,vertical_depth));
	float shore = 1.0 - smoothstep(.015, foam_width, vertical_depth);
	float foam = shore * smoothstep(.35, .75, noise) * foam_strength;
	colour += crest_colour * crest * (1.0-depth_factor) * caustic_strength;
	ALBEDO = mix(colour, vec3(.62,.72,.71), foam);
	ROUGHNESS = mix(surface_roughness, .75, foam);
	METALLIC = 0.0;
	SPECULAR = surface_specular;
	// The screen sample already provides transmission; blending it again would
	// double the bed contribution and weaken depth colour.
	ALPHA = 1.0;
}
