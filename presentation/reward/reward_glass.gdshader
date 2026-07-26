shader_type spatial;
render_mode unshaded, blend_premul_alpha, cull_disabled, depth_draw_never,
	shadows_disabled, fog_disabled, specular_disabled;

// BACKLIT GLASS. The card's shader answers "what does this surface give back?"
// — light arrives from the room and bounces off a finish. This one answers the
// opposite question: "what gets THROUGH?" There is no lamp in front and no
// reflection term anywhere in it. A pane is dark until something behind it is
// bright, which is the entire behaviour of a window.
//
// Consequences of that, both deliberate:
//   · additive, via PREMULTIPLIED alpha. Unlit glass contributes nothing,
//     because unlit glass IS black — there is no "off" colour to blend toward.
//     Straight blend_add cannot express that here: it still writes ALPHA, so
//     every pixel a spill quad covers turns opaque in the viewport's alpha
//     channel and the transparent stage composites as a black slab. Premul
//     lets brightness BE the coverage — ALBEDO carries the light, ALPHA
//     carries how much of what is behind it the light drowns out. Which is
//     also, for free, the halation: glass hot enough eats its own lead.
//   · no normal, no view vector. Transmission does not care where you stand.
//     Angle belongs to the lead in front, which is a real lit solid; the glass
//     itself only cares how far it sits from the sun.

uniform vec3 tone : source_color = vec3(1.0, 1.0, 1.0);
// The sun, in the same window pixels the mesh is built in. Not a Light3D: a
// light behind a pane never reaches the camera, it only decides how much of the
// pane's own colour is carried through.
uniform vec2 sun = vec2(0.0, 0.0);
uniform float reach = 340.0;
uniform float lit : hint_range(0.0, 1.0) = 0.0;
uniform float gain = 1.0;
// 0 = the pane. 1 = the light it throws PAST itself, onto the lead and the
// wall. Same shader because it is the same light — only the falloff differs.
uniform float soft = 0.0;
uniform float seed = 0.0;

varying vec3 wpos;
varying vec2 quad_uv;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	quad_uv = UV;
}

void fragment() {
	float d = distance(wpos.xy, sun) / reach;
	float fall = 1.0 / (1.0 + d * d);
	// Cathedral glass is never an even sheet. But sin(x) * sin(y) is a GRID —
	// separable in the pane's own axes, so it lands as polka dots however the
	// period is tuned, which is the one thing it must not look like. Antique
	// glass is drawn while it cools, so its unevenness is STRIATED: long
	// streaks along one axis, at several scales, none of them square to the
	// came. Three sines projected onto two off-axis directions at
	// incommensurate frequencies never repeat inside a pane.
	vec2 along = vec2(0.966, 0.259);        // 15 degrees off the horizontal
	vec2 across = vec2(-0.259, 0.966);
	float u = dot(wpos.xy, along);
	float v = dot(wpos.xy, across);
	float wave = sin(u * 0.038 + seed * 6.283)
		+ 0.62 * sin(u * 0.101 - seed * 4.113)
		+ 0.44 * sin(v * 0.021 + u * 0.007 + seed * 2.717);
	float body = fall * mix(0.90, 1.10, clamp(wave * 0.24 + 0.5, 0.0, 1.0));
	if (soft > 0.5) {
		vec2 c = (quad_uv - 0.5) * 2.0;
		float r = max(0.0, 1.0 - dot(c, c));
		body *= r * r;
	}
	float t = body * gain * lit;
	// Pot-metal glass is DEEP — the colour is in the melt, not printed on a
	// surface, so a 3mm sheet eats most of what it does not pass. Squaring the
	// tone is that thickness: it drops the channels the pigment blocks much
	// faster than the one it does not, which is what makes a jewel out of what
	// the content file spells as a pastel.
	vec3 pot = mix(tone, tone * tone, 0.65);
	// Hot glass goes WHITE, not more saturated. Push enough light through a
	// coloured sheet and the eye runs out of headroom in the two channels the
	// pigment did not block long before the third — so the core desaturates
	// while the edges keep the hue. Without this the pane climbs to a flat
	// screaming version of its own colour and reads as plastic.
	vec3 col = mix(pot, vec3(1.0), clamp(t * t * 0.34, 0.0, 0.62)) * t;
	ALBEDO = col;
	ALPHA = clamp(max(col.r, max(col.g, col.b)), 0.0, 1.0);
}
