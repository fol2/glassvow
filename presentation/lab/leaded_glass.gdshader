shader_type canvas_item;
// COLOURED GLASS HELD IN LEAD CAME, LIT FROM BEHIND.
//
// Every piece of art this game ships — the chest, the lantern, the phial, the
// card back, the arch on the stage, the emberglass rose in the meta screen —
// is the same object: coloured glass in a lead frame with a light behind it.
// The panels were not. This is a panel made of the same thing, and it is one
// ColorRect: no nine-slice, no border texture, no rim node stack.
//
// Three things happen here that a rounded rect cannot do:
//
//   the came is ROUND.   Lead came is a bead, not a line. Its normal turns
//                        through 180° across its own width, so it takes light
//                        on the lamp side and goes black on the other — which
//                        is the whole reason leaded glass reads as BUILT
//                        rather than drawn. `lamp` is a direction and the bead
//                        is shaded against it.
//   the glass has a BACK. `lit` is a lamp BEHIND the pane, not a fill colour.
//                        It falls off from `glow_at`, so a pane is brightest
//                        where the light stands and dies into its corners, and
//                        art laid on top of it is carried by that light.
//   the glass is UNEVEN. Antique glass is drawn, not floated: it keeps
//                        striations from the cylinder and seed bubbles from
//                        the melt. Both are here, in pane px, so they hold
//                        their size whatever the pane's size is.
//
// Angle, not time — the rule card_surface.gdshader works under. Nothing here
// reads TIME. A pane at rest is still a material.
//
// TWO FIGURES, ONE MATERIAL. `shape_mode` swaps only the question "where does
// the lead run"; every line below that is shared, because a rose window and a
// lancet light are the same craft in a different set-out.
//
//   0  LIGHT   a rounded rect, or — with `arch` — a pointed head.
//   1  ROSE    an annulus divided into `wedges`, lead on the rim, the hub ring
//              and every spoke. Its tints come from `tones`, a 1px-tall strip
//              carrying one texel per wedge: rgb the glass, alpha its lamp.
//              A strip, not an array uniform, so the wedge count is data.

uniform int shape_mode = 0;

// ── the set-out ───────────────────────────────────────────────────────────
uniform vec2 size = vec2(480.0, 84.0);    // the rect this draws into, px
uniform float radius = 10.0;              // LIGHT: corner radius, px
uniform float came = 7.0;                 // lead came width, px
// LIGHT: > 0 turns the head into a pointed arch of exactly this rise.
uniform float arch = 0.0;
uniform float outer = 250.0;              // ROSE: rim radius, px
uniform float hub = 78.0;                 // ROSE: hub radius, px
uniform int wedges = 6;                   // ROSE: how many lights
uniform float spin = 0.0;                 // ROSE: turns of the whole figure

// ── the light ─────────────────────────────────────────────────────────────
uniform vec4 tint : source_color = vec4(0.95, 0.76, 0.30, 1.0);
uniform vec4 lead : source_color = vec4(0.055, 0.062, 0.095, 1.0);
uniform float lit = 1.0;                  // the lamp behind, 0 = a dead light
uniform vec2 lamp = vec2(-0.55, -0.83);   // where the light comes FROM
uniform vec2 glow_at = vec2(0.5, 0.5);    // where it stands behind, in UV
uniform float reach = 0.62;               // its falloff, as a share of the fig
uniform float ripple = 1.0;               // glass unevenness, 0 = float glass
uniform float seed = 0.0;
uniform float ink = 0.0;                  // 1 = spent: keep the came, kill light
uniform sampler2D tones : filter_nearest, source_color;


float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}


// Value noise. Two octaves is enough for glass: one for the melt's swirl, one
// for the seed bubbles riding on it.
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}


float sd_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}


// The light's outline, signed px, negative inside.
float light_shape(vec2 p, vec2 b) {
	if (arch < 0.5) {
		return sd_box(p, b, radius);
	}
	float spring = -b.y + arch;           // where the head leaves the jambs
	if (p.y >= spring) {
		// The jambs. The box is carried 400px ABOVE the springing line on
		// purpose: give it a top edge at the springing and that edge becomes
		// the nearest surface for every pixel just under it, which puts a bead
		// of lead straight across the window where nothing is built. Run it
		// past the head and only the sides and sill can ever be nearest.
		float top = spring - 400.0;
		vec2 c = vec2(0.0, (top + b.y) * 0.5);
		return sd_box(p - c, vec2(b.x, (b.y - top) * 0.5), radius);
	}
	// The head: two arcs struck from the springing line, each centred under the
	// far jamb so it passes through the near one. A mason sets the centres out
	// from the rise: an arc of radius b.x + k rises sqrt(b.x^2 + 2*b.x*k), so a
	// head of `arch` px wants k = (arch^2 - b.x^2) / 2*b.x. k = 0 is a round
	// head, k = b.x the equilateral point, k < 0 a segmental drop — one line,
	// and the arch is authored in the px it actually occupies.
	float k = (arch * arch - b.x * b.x) / (2.0 * b.x);
	float r = b.x + k;
	return max(length(p - vec2(k, spring)) - r, length(p + vec2(k, -spring)) - r);
}


void fragment() {
	vec2 b = size * 0.5;
	vec2 p = (UV - 0.5) * size;           // px, origin at the figure's centre
	float d_shape;                        // < 0 inside the figure
	float d_lead;                         // < 0 on lead
	vec4 glass_tone = tint;
	float lamp_on = lit;

	if (shape_mode == 0) {
		d_shape = light_shape(p, b);
		d_lead = -(d_shape + came);
	} else {
		float rad = length(p);
		d_shape = max(rad - outer, hub - rad);
		// Distance to the nearest spoke, in px: the angular gap scaled by how
		// far out we are, which is why the lead keeps its width all the way.
		float t = fract((atan(p.y, p.x) + PI) / TAU + spin);
		float w = float(wedges);
		float f = fract(t * w);
		float spoke = min(f, 1.0 - f) * (TAU / w) * rad;
		// Lead on the rim, the hub ring and every spoke — each bead set fully
		// inside the figure rather than straddling its edge.
		d_lead = min(min(abs(rad - (outer - came * 0.5)),
				abs(rad - (hub + came * 0.5))), spoke) - came * 0.5;
		vec4 tex = texture(tones, vec2((floor(t * w) + 0.5) / w, 0.5));
		glass_tone = vec4(tex.rgb, 1.0);
		lamp_on = tex.a * lit;
	}

	float aa = fwidth(d_shape) + 0.0001;
	float solid = 1.0 - smoothstep(-aa, aa, d_shape);
	// No early-out: Godot forbids `return` in a processor function, and the
	// outside is a handful of ALU either way.
	float came_m = 1.0 - smoothstep(-aa, aa, d_lead);
	float glass_m = 1.0 - came_m;
	vec2 L = normalize(lamp);

	// ── the glass ─────────────────────────────────────────────────────────
	// Striations run the length of the cylinder the sheet was blown from —
	// long and shallow, tens of px, not a few. At a few they stop being glass
	// and become scanlines. Seed bubbles sit in the melt at a coarser period
	// than the striations they ride on.
	float striate = vnoise(vec2(p.x * 0.010 + seed, p.y * 0.045 + seed * 3.0));
	float bubbles = vnoise(p * 0.05 + seed * 7.0);
	float body = 1.0 + ripple * ((striate - 0.5) * 0.34 + (bubbles - 0.5) * 0.18);

	// The lamp behind. Measured in px, so a wide figure falls off across its
	// width the way a tall one falls off down its height.
	//
	// The ceiling matters as much as the falloff: this game is read at night
	// against #05070E, and glass lit past about half its tint stops being a
	// surface and becomes a lightbox — nothing can be laid on it and read.
	// A lit light peaks near 0.55 of its own colour and dies to 0.09.
	vec2 q = (UV - glow_at) * size;
	float rr = reach * max(size.x, size.y);
	float back = exp(-dot(q, q) / (rr * rr));
	float through = lamp_on * (0.09 + 0.46 * back) * body;

	vec3 glass = glass_tone.rgb * through;
	// Light that got in and did not get out: the glass keeps a floor of its own
	// colour, so an unlit light is dark GLASS rather than a hole.
	glass += glass_tone.rgb * 0.040;

	// The cut edge next to the lead takes the light twice — once coming
	// through, once off the cut itself. Thin, and most of the read.
	float cut = 1.0 - smoothstep(0.0, 3.0, d_lead);
	glass += glass_tone.rgb * cut * glass_m * (0.10 + 0.30 * lamp_on);

	// ── the came ──────────────────────────────────────────────────────────
	// A half-round bead, and `u` has to run -1..1 across the WHOLE width of it
	// — one shoulder, the crown, the other shoulder. Run it 0..1 from one edge
	// and half the bead clamps flat, which is a bead with no dark side, which
	// is a drawn border. d_lead is symmetric about the centreline, so its own
	// gradient points off the crown toward the glass and `g * u` is the normal.
	vec2 g = vec2(dFdx(d_lead), dFdy(d_lead));
	g = length(g) > 0.00001 ? normalize(g) : vec2(0.0, -1.0);
	float u = clamp((d_lead + came * 0.5) / max(came * 0.5, 0.001), -1.0, 1.0);
	float rise = sqrt(max(0.0, 1.0 - u * u));
	float lam = dot(g * u, L);
	vec3 metal = lead.rgb * (0.55 + 0.85 * rise);
	metal += vec3(0.62, 0.66, 0.78) * max(0.0, lam) * 0.50 * rise;
	metal *= 1.0 - 0.50 * max(0.0, -lam);
	// Lead in front of a lit light picks up the glass's colour along the
	// shoulder that faces it. Skipping this is what makes came read as drawn.
	metal += glass_tone.rgb * lamp_on * 0.22 * max(0.0, u) * rise;

	vec3 rgb = mix(glass, metal, came_m);
	rgb = mix(rgb, metal * 0.42 + glass_tone.rgb * 0.02, ink * glass_m);

	COLOR = vec4(rgb, solid);
}
