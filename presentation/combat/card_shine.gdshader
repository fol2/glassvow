shader_type canvas_item;
// `.card.r-rare .card-inner::after` (styles.css:592-597) — the gilt shine: a
// 115-degree band on a 260%-wide tile, swept by `shine 4.5s ease-in-out
// infinite` — parked off-right until the 62% mark, across the face by 92%,
// parked off-left for the rest of the loop.
//
// It lives HERE, on the main canvas over the slab, and not inside the card's
// own viewports: those freeze the moment the card settles (`_set_live`,
// card_view.gd), and a gloss is not worth keeping two offscreen targets awake
// per rare in hand. TIME drives the whole loop, so it costs no script at all.
// smoothstep stands in for cubic-bezier(.42,0,.58,1) — on a 16%-alpha gloss
// the difference is not readable.

uniform vec2 card_px = vec2(152.0, 216.0);
uniform float radius_px = 11.0;

// Signed distance to the card's rounded rectangle, so the band honours the
// same corners the face is cut to.
float rounded_mask(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + vec2(r);
	float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
	return 1.0 - smoothstep(-1.0, 1.0, d);
}

void fragment() {
	float u = fract(TIME / 4.5);
	float s = smoothstep(0.62, 0.92, u);
	// background-position 120% -> -60%, in card-width units of the 115-degree
	// axis. The margins are wide enough that the band is fully off the face at
	// both ends of the sweep.
	float sweep = mix(1.7, -1.1, s);
	vec2 px = UV * card_px;
	float along = dot(px, normalize(vec2(0.9063, 0.4226))) / card_px.x;
	float c = along - sweep;
	// The tile's two ramps: gold rgba(255,240,190,.16) with the broad shoulder,
	// a narrower white .05 riding just behind it (stops 32/46/52/66 of 260%).
	float gold = 1.0 - smoothstep(0.0, 0.36, abs(c));
	float white = 1.0 - smoothstep(0.0, 0.16, abs(c - 0.16));
	float ag = 0.16 * gold;
	float aw = 0.05 * white;
	float a = max(ag, aw);
	vec3 col = (vec3(1.0, 0.941, 0.745) * ag + vec3(1.0) * aw) / max(a, 0.001);
	COLOR = vec4(col, a * rounded_mask(px - card_px * 0.5, card_px * 0.5, radius_px));
}
