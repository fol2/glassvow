shader_type canvas_item;

// THE CARD EDGE. A pane of glass is clear face-on; its EDGE is where the
// material shows itself — light trapped by internal reflection escapes at the
// cut. So the edge carries both identity channels at once, on different
// physical properties, and they never fight over the same pixel:
//
//   type   = the colour of the glass (the hue of the edge light)
//   rarity = the finish of the cut   (how the edge was worked)
//
//   0 raw       starter/special — unpolished cut: dim, desaturated, flat
//   1 cut       common — a clean line of the glass colour
//   2 polished  uncommon — the edge catches light: lit above, deep below,
//               a polish line inside, and a breath of edge-light bleeding
//               into the face
//   3 gilt      rare — polished, with gold worked into the outer lip,
//               pooling at the corners; on hover a slow sheen walks the rim
//   4 leaden    curse (type override) — darker than the face; this glass
//               drinks light, and only the cursor's glint shows its colour
//
// Geometry, outside in (d = signed distance to the silhouette, negative
// inward): a LIP_W dark lip (the arris — keeps the silhouette crisp against
// bright fields), the edge band to edge_w, a 1px polish line, then the bleed
// falling off into the face. The node fills past the silhouette and the mask
// node cuts d >= 0, so the mask's antialiasing is the only outer edge.
//
// Painted in local pixels via the v_pos varying, not UV — UVs depend on the
// node type that hosts the material; VERTEX does not.

uniform vec2 card_size = vec2(152.0, 216.0);
uniform float radius = 11.0;
uniform float edge_w = 2.0;
uniform int finish = 1;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 rule_col : source_color = vec4(0.020, 0.027, 0.055, 1.0);
uniform vec4 gold_lit : source_color = vec4(1.000, 0.914, 0.675, 1.0);
uniform vec4 gold : source_color = vec4(0.949, 0.757, 0.306, 1.0);
uniform vec4 gold_dim : source_color = vec4(0.702, 0.514, 0.122, 1.0);
uniform float hover = 0.0;
uniform vec2 mouse_px = vec2(-1000.0, -1000.0);

const float LIP_W = 0.6;
const float LINE_W = 1.0;
const float BLEED_D = 7.0;

varying vec2 v_pos;

void vertex() {
	v_pos = VERTEX;
}

// Standard rounded-rect SDF; also hands back q for corner proximity.
float sdf(vec2 p, vec2 half_s, float r, out vec2 q) {
	q = abs(p - half_s) - (half_s - vec2(r));
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

// Layer `src` with coverage `sa` over the running premultiplied-ish pair.
void lay(inout vec3 col, inout float a, vec3 src, float sa) {
	float out_a = sa + a * (1.0 - sa);
	col = out_a > 0.0001 ? (src * sa + col * a * (1.0 - sa)) / out_a : col;
	a = out_a;
}

void fragment() {
	vec2 q;
	float d = sdf(v_pos, card_size * 0.5, radius, q);
	float aa = max(fwidth(d), 0.001);

	// Light falls from above: 1 at the top edge, 0 at the bottom.
	float vlight = 1.0 - v_pos.y / card_size.y;
	// 1 inside a corner arc, feathering in 10px before it.
	float corner = smoothstep(-10.0, 3.0, min(q.x, q.y));
	// Cursor proximity on the rim — the glint. Dead while hover is 0.
	float prox = exp(-length(v_pos - mouse_px) / 55.0) * hover;

	vec3 t = tint.rgb;
	vec3 band_col;
	vec3 line_col;
	float line_a;
	float bleed_a;
	float glint_amp;
	if (finish == 0) {          // raw
		vec3 dull = mix(t, vec3(dot(t, vec3(0.333))), 0.40);
		band_col = mix(rule_col.rgb, dull, 0.38);
		line_col = t;
		line_a = 0.22;
		bleed_a = 0.0;
		glint_amp = 0.16;
	} else if (finish == 1) {   // cut
		band_col = mix(rule_col.rgb, t, 0.52) * mix(0.90, 1.10, vlight);
		line_col = t;
		line_a = 0.40;
		bleed_a = 0.0;
		glint_amp = 0.26;
	} else if (finish == 2) {   // polished
		vec3 lit_t = mix(t, vec3(1.0), 0.45);
		band_col = mix(mix(rule_col.rgb, t, 0.80) * 0.82,
			lit_t, pow(vlight, 1.6) * 0.85);
		line_col = lit_t;
		line_a = 0.28 + 0.26 * vlight;
		bleed_a = 0.07;
		glint_amp = 0.45;
	} else if (finish == 3) {   // gilt
		vec3 lit_t = mix(t, vec3(1.0), 0.40);
		band_col = mix(mix(rule_col.rgb, t, 0.80) * 0.82,
			lit_t, pow(vlight, 1.6) * 0.72);
		vec3 gold_v = mix(gold_dim.rgb, gold_lit.rgb, vlight);
		// Gold pools at the corners, heavier where the light lands.
		band_col = mix(band_col, gold_v, corner * mix(0.45, 0.95, vlight));
		// ...and rides the outer lip of the band all the way round.
		float glip = smoothstep(-1.4, -0.7, d);
		band_col = mix(band_col, gold_v, glip * 0.80);
		// On hover a single soft arc of sheen walks the rim, slowly.
		vec2 pc = v_pos - card_size * 0.5;
		float sheen = pow(0.5 + 0.5 * cos(atan(pc.y, pc.x) - TIME * 0.6), 3.0);
		band_col += gold_lit.rgb * sheen * 0.12 * hover;
		line_col = mix(gold.rgb, gold_lit.rgb, vlight);
		line_a = 0.34 + 0.30 * vlight;
		bleed_a = 0.09;
		glint_amp = 0.60;
	} else {                    // leaden
		band_col = rule_col.rgb * 0.55;
		line_col = t;
		line_a = 0.10;
		bleed_a = 0.0;
		glint_amp = 0.30;
	}

	vec3 glint_col = finish == 3 ? gold_lit.rgb : mix(vec3(1.0), t, 0.35);
	if (finish == 4) {
		glint_col = t;
	}
	band_col += glint_col * prox * glint_amp;

	// Compose, deepest first: bleed, polish line, band, lip.
	float bx = clamp((-d - (edge_w + LINE_W)) / BLEED_D, 0.0, 1.0);
	float fall = (1.0 - bx) * (1.0 - bx);
	vec3 bleed_col = finish == 3 ? mix(t, gold.rgb, corner * 0.6) : t;
	vec3 col = bleed_col;
	float a = bleed_a * (1.0 + prox * 6.0) * fall;

	float line_m = smoothstep(-edge_w - LINE_W - aa, -edge_w - LINE_W + aa, d)
		* (1.0 - smoothstep(-edge_w - aa, -edge_w + aa, d));
	lay(col, a, line_col + glint_col * prox * glint_amp * 0.5,
		line_a * line_m);

	float band_m = smoothstep(-edge_w - aa, -edge_w + aa, d);
	lay(col, a, band_col, band_m);

	float lip_m = smoothstep(-LIP_W - aa, -LIP_W + aa, d);
	lay(col, a, mix(rule_col.rgb, band_col, 0.35 + prox * 0.4), lip_m);

	COLOR = vec4(col, a);
}
