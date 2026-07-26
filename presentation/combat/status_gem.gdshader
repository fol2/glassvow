shader_type canvas_item;

// THE CABOCHON. card_surface.gdshader asks "what does this surface give back?"
// and answers it for a flat slab. This asks the same question for a 32px dome.
//
// It is the card's philosophy at chip scale, and it keeps the card's one rule:
// ANGLE, NOT TIME. Every term here is a function of geometry — the dome's own
// normal and where the room's lamp is — so a chip at rest is not animating, it
// is simply lit. Nothing in a status row should be moving; a row that breathes
// is a row you cannot stop looking at.
//
// One draw call per chip. No SubViewport, no MeshInstance3D: a 32px gem does not
// need a 3D stage, it needs a normal it can compute. The dome normal falls out
// of the disc's own coordinates for free.

uniform sampler2D icon : filter_linear_mipmap, source_color;
uniform vec4 tone : source_color = vec4(0.56, 0.82, 1.0, 1.0);
// 0 = boon, 1 = affliction. Drives every difference between the two: an
// affliction is the SAME gem, soaked and fractured, never a different shape.
uniform float affliction : hint_range(0.0, 1.0) = 0.0;
// The room's lamp, in chip-local -1..1. Shared across the row so every gem in
// the status bar catches the light from the same place — the moment they
// disagree they stop reading as objects sitting on one surface.
uniform vec2 lamp = vec2(-0.45, -0.62);
uniform float spec_tight = 34.0;
uniform float crack : hint_range(0.0, 1.0) = 0.0;
uniform float rim_gain = 1.0;

// Cheap value hash — only used to jitter the fracture so it is not a clean star.
float h(vec2 p) { return fract(sin(dot(p, vec2(41.7, 289.1))) * 43758.5453); }

// Distance to a radial fracture: n spokes out of the impact point, jittered.
float fracture(vec2 p) {
	float a = atan(p.y, p.x);
	float r = length(p);
	float spokes = 7.0;
	float seg = floor((a + 3.14159) / 6.28318 * spokes);
	float jit = (h(vec2(seg, 3.0)) - 0.5) * 0.42;
	float centre = (seg + 0.5) / spokes * 6.28318 - 3.14159 + jit;
	float d = abs(a - centre) * max(r, 0.12);
	// the crack only exists past the impact point and fades at the rim
	return smoothstep(0.055, 0.0, d) * smoothstep(0.06, 0.35, r) * smoothstep(1.0, 0.72, r);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r2 = dot(p, p);
	if (r2 > 1.0) discard;                 // the gem is a disc, not a square

	float z = sqrt(max(1.0 - r2, 0.0));
	vec3 N = vec3(p, z);
	vec3 L = normalize(vec3(lamp, 0.85));
	vec3 V = vec3(0.0, 0.0, 1.0);

	float diff = max(dot(N, L), 0.0);
	float spec = pow(max(dot(reflect(-L, N), V), 0.0), spec_tight);

	// A dome of glass MAGNIFIES what is under it, most at the edges where the
	// surface is steepest. Without this the icon reads as a sticker on a bead
	// rather than something sealed inside one.
	vec2 refr = p * (1.0 - z) * 0.11;
	vec4 art = texture(icon, clamp(UV - refr, vec2(0.001), vec2(0.999)));

	// Body: the status's own colour, darkest where the light does not reach.
	vec3 body = tone.rgb * (0.16 + 0.72 * diff);

	// An affliction is light being TAKEN. soak pulls the body under its own
	// floor — the one thing in the card's material table that only lead does.
	body = mix(body, body * 0.34 - 0.02, affliction);

	// The art sits inside the glass, so it is lit by the same lamp.
	vec3 lit_art = art.rgb * (0.42 + 0.78 * diff);
	vec3 col = mix(body, lit_art, art.a * 0.92);

	// Rim light: the bright edge a real cabochon carries all the way round,
	// and the thing that separates it from a busy scene behind.
	float rim = pow(1.0 - z, 2.6) * rim_gain;
	col += tone.rgb * rim * mix(0.55, 0.22, affliction);

	col += vec3(spec) * mix(0.85, 0.30, affliction);

	float f = fracture(p) * crack;
	col = mix(col, vec3(0.86, 0.92, 1.0), f * 0.72);

	// One pixel of anti-aliasing on the disc edge; a hard cut at 32px reads as
	// a jagged sprite no matter how good the shading is.
	float aa = fwidth(r2) * 1.4;
	float edge = 1.0 - smoothstep(1.0 - aa, 1.0, r2);

	COLOR = vec4(col, edge);
}
