// Stage 3 of docs/reward-embers-3d-plan.md: the reward's own fracture
// material. Descended from the enemy lane's SHARD_SHADER (the borrowed
// spliced const carried stage 2) and now owned here, because the two
// materials answer different clocks: a combat shard is molten while HOT and
// cools to nothing, a reward piece cools INTO the item's colour — the cut
// is where the prize lives, which is the whole thesis of the embers.
//
// The corrode/tint splices are deliberately absent: a reward body was WHOLE
// when it broke (nothing has eaten its alpha), and the husk's variant cast
// is a stage-4 concern once D1 carries the id. The cut POLISHES as it
// cools — roughness falls toward glass and the schlick-ggx highlight
// tightens, which is this room's route to the card lane's lesson that a
// tight high-exponent highlight is what sells small glass. The plan's
// "unshaded, own lighting maths" was written for a screen with no lights;
// this room HAS the game's real lamp, rim and fire, so the material takes
// them rather than faking its own. Deviation on the record.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley,
	specular_schlick_ggx;

uniform sampler2D body_tex : source_color, filter_linear_mipmap;
// 0 = the moment of failure (white-hot cut), 1 = the hold (glass, the
// item's colour resting in the fracture).
uniform float cool = 0.0;
uniform vec3 cool_tint : source_color = vec3(1.0, 0.6, 0.24);

const vec3 WHITE_HOT = vec3(1.0, 0.93, 0.82);

void fragment() {
	vec4 c = texture(body_tex, UV);
	// _prism's face tag: caps black, side band red — COLOR.r is literally
	// "this face is a fracture surface".
	float edge = COLOR.r;
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	float f = pow(1.0 - clamp(dot(n, v), 0.0, 1.0), 3.0);
	float hot = 1.0 - cool;
	vec3 molten = mix(WHITE_HOT, cool_tint, cool);
	// A cap is THE PAINTING; the cut takes the molten face, dimming toward
	// half the tint as it cools so the colour reads as inside the glass.
	ALBEDO = mix(c.rgb, molten * 0.5, edge * (0.2 + 0.3 * hot));
	float amask = smoothstep(0.05, 0.30, c.a);
	ALPHA = mix(smoothstep(0.02, 0.18, c.a), amask, edge);
	// The cut polishes as it cools: molten glass is matte, cold glass is the
	// mirror. The caps stay a painting's 0.55.
	ROUGHNESS = mix(0.55, mix(0.9, 0.12, cool), edge);
	METALLIC = 0.0;
	SPECULAR = mix(0.3, 0.9, edge * cool);
	// The caps keep the body's own lantern glow — a flying piece stays lit
	// the way it was lit standing. The cut burns while hot and settles to a
	// whisper of the item's colour: past a whisper every piece is the same
	// white-hot popcorn and the creature is gone again, just hotter.
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114)) * c.a;
	EMISSION = molten * (edge * (hot * 0.9 + 0.12) + f * hot * 0.3)
		+ c.rgb * (pow(l, 3.2) * 0.85 * (1.0 - edge) + hot * 0.25);
}
