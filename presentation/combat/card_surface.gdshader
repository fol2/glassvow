shader_type spatial;
render_mode blend_mix, depth_draw_opaque, unshaded;

// THE CARD'S SURFACE. The 2D face has already painted everything the card
// SAYS. This shader paints what it IS: the light its material gives back.
//
// It can only exist because the card became a real object. A flat Control has
// no view vector — the best it can do is fake one off the cursor, which is why
// every CSS "holo card" on the web reads as a decal sliding under glass. Here
// the face is a plate in a 3D stage with a long lens, so every fragment has a
// true eye direction, and it is DIFFERENT at each corner even at rest: the
// card subtends ~11.6 degrees across its width and ~16.4 down its height at
// this camera distance. That angular spread is the whole material budget. A
// band of holo therefore exists as a real gradient across the face, and
// tilting slides it, exactly as it does on a card in your hand.
//
// Nothing here reads TIME. The card freezes both offscreen viewports the
// moment it stops moving, so a time-driven finish would silently die; every
// channel is a function of geometry instead. That constraint and the physics
// happen to agree — a material is not an animation.
//
// Layer order follows card_surface.gd: material (what it is), texture (how the
// surface breaks), finish (the coating). Stock never reaches this shader.

uniform sampler2D face_tex : filter_linear, source_color;
uniform vec2 face_size = vec2(168.0, 232.0);   // the inner texture, in card px
uniform vec2 face_pad = vec2(8.0, 8.0);        // its margin, so cp starts at 0
uniform vec2 card_size = vec2(152.0, 216.0);
uniform float radius = 11.0;
uniform vec4 art_rect = vec4(2.0, 2.0, 148.0, 91.0);   // x, y, w, h in card px

// The room's lamp, a touch above the lens and a touch to the left — the same
// light the face's own gradients already imply. It has to sit CLOSE to the
// view axis: the card only turns 7 degrees, so a highlight parked 30 degrees
// away could never be reached, and the finish would be a static print. At 17
// degrees the specular band sits just off the top edge at rest and walks down
// onto the face as the card leans, which is the behaviour worth having.
uniform vec3 key_dir = vec3(-0.095, 0.286, 0.953);

// material
uniform vec4 ink : source_color = vec4(1.0);
uniform vec4 tint : source_color = vec4(1.0);
uniform float ink_tint = 0.0;
uniform float soak = 0.0;
uniform float bleed = 0.0;
// texture
uniform float relief = 0.0;
uniform int relief_kind = 0;
uniform float relief_scale = 8.0;
uniform float grain = 0.0;
uniform float grain_scale = 1.0;
// finish
uniform float sheen = 0.0;
uniform float tight = 24.0;
uniform float aniso = 0.0;
uniform float holo = 0.0;
uniform float holo_scale = 6.0;
uniform float holo_dir = 0.0;
uniform float pearl = 0.0;
uniform float pearl_scale = 60.0;
uniform float sparkle = 0.0;
uniform float flake_px = 4.0;
uniform int mask = 0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

// The surface's shape, as a unit field in -1..1, on card pixels — so a 3.4px
// weave stays 3.4px whatever the render scale. Amplitude is applied by the
// caller, because depth and pitch have to stay independent knobs.
float pattern_h(vec2 p) {
	float k = TAU / max(relief_scale, 0.5);
	if (relief_kind == 1) {              // linen: two crossed sine warps
		return (sin(p.x * k) + sin(p.y * k)) * 0.5;
	} else if (relief_kind == 2) {       // engine-turning: concentric rings
		return sin(length(p - card_size * 0.5) * k);
	} else if (relief_kind == 3) {       // crosshatch etch, deliberately off-beat
		return sin((p.x + p.y) * k) * 0.6 + sin((p.x - p.y) * k * 1.37) * 0.4;
	} else if (relief_kind == 4) {       // pebble / paper tooth
		return vnoise(p * (k / TAU)) * 2.0 - 1.0;
	}
	return 0.0;
}

float grain_h(vec2 p) {
	return vnoise(p / max(grain_scale, 0.25)) * 2.0 - 1.0;
}

// A unit field of period P must have amplitude tan(A)*P/TAU to tip the normal
// by A degrees at its steepest. Depth is therefore stated in DEGREES, and that
// is the only unit that makes sense here: the card presents 4 to 14 degrees of
// half-angle in total, so a 3-degree weave modulates the highlight while a
// 22-degree one — which is what a raw 0.55 amplitude at a 3.4px pitch works
// out to — scrambles it into drawn lines that no longer read as a surface.
float depth_amp(float degrees, float period) {
	return tan(radians(degrees)) * period / TAU;
}

// Standard rounded-rect SDF, negative inside — the silhouette, for the
// frame-band mask. Same shape card_edge.gdshader cuts against.
float sdf(vec2 p, vec2 half_s, float r) {
	vec2 q = abs(p - half_s) - (half_s - vec2(r));
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec4 src = texture(face_tex, UV);
	vec2 cp = UV * face_size - face_pad;    // card-space px, (0,0) at the corner

	// The card's own axes, straight off the model matrix. The face is a rigid
	// plate, so its columns ARE the tangent frame — exact under any tilt, and
	// no per-vertex tangents to generate. Bv follows +v, which runs downward.
	vec3 T = normalize((MODEL_MATRIX * vec4(1.0, 0.0, 0.0, 0.0)).xyz);
	vec3 Bv = normalize((MODEL_MATRIX * vec4(0.0, -1.0, 0.0, 0.0)).xyz);
	vec3 Nf = normalize((MODEL_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz);
	vec3 V = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);

	// Texture bends the normal and nothing else — it adds no light of its own,
	// it only decides where the light that arrives is allowed to land. Sampled
	// one card pixel apart, so the slope is in card space and survives any
	// render scale; the two fields are scaled here so h0 costs no extra taps.
	float ra = depth_amp(relief, relief_scale);
	float ga = depth_amp(grain, grain_scale);
	float ph = pattern_h(cp);
	float gh = grain_h(cp);
	vec3 N = Nf;
	if (relief > 0.0 || grain > 0.0) {
		float h0 = ph * ra + gh * ga;
		float hx = pattern_h(cp + vec2(1.0, 0.0)) * ra
			+ grain_h(cp + vec2(1.0, 0.0)) * ga;
		float hy = pattern_h(cp + vec2(0.0, 1.0)) * ra
			+ grain_h(cp + vec2(0.0, 1.0)) * ga;
		N = normalize(Nf - T * (hx - h0) - Bv * (hy - h0));
	}

	vec3 L = normalize(key_dir);
	vec3 H = normalize(L + V);
	float ndv = max(dot(N, V), 1e-3);

	// Two envelopes off the same half-angle, because the channels are lit by
	// different physics. Both exponents are large on purpose: the card only
	// ever presents a sliver of half-angle — measured 4.25 to 13.65 degrees
	// across the face at rest, and 0.17 to 7.82 when it leans into the lamp —
	// so anything under about 100 cannot form a band at all. It comes out as a
	// flat wash over the whole face, which is the tell of every fake foil.
	float base = max(dot(N, H), 0.0);
	float broad = pow(base, 5.0);      // absorption: over nearly the whole face
	float band = pow(base, 110.0);     // diffraction and film: a travelling band

	// The specular lobe. Anisotropy squashes the half-vector's offset along one
	// card axis before the power, which widens the lobe there — so the
	// highlight comes out STRETCHED along the other axis. That is brushed
	// metal and satin weave in three lines; varnish leaves it alone.
	float ndh = dot(N, H);
	if (abs(aniso) > 0.001) {
		float sq = 1.0 + 7.0 * abs(aniso);
		vec2 ho = vec2(dot(H, T), dot(H, Bv));
		ho = aniso >= 0.0 ? vec2(ho.x / sq, ho.y) : vec2(ho.x, ho.y / sq);
		ndh = dot(N, normalize(T * ho.x + Bv * ho.y + N * dot(H, N)));
	}
	float spec = pow(max(ndh, 0.0), tight);

	// Diffraction. A grating throws each wavelength off at its own angle, so
	// the spectrum sweeps past the eye as the view direction turns — banded
	// ACROSS the grooves, which is what separates holo from pearl by eye.
	float groove = radians(holo_dir);
	float g = dot(vec2(dot(V, T), dot(V, Bv)),
		vec2(cos(groove), sin(groove))) * holo_scale;
	vec3 spectrum = 0.5 + 0.5 * cos(TAU * (g + vec3(0.0, 0.33, 0.67)));

	// Thin-film interference. The path through the film grows as 1/cos(theta),
	// which is zero at the point facing the lens and rises outward — so pearl
	// rings AROUND the view axis rather than banding across the card.
	vec3 film = mix(vec3(1.0),
		0.5 + 0.5 * cos(TAU * (pearl_scale * (1.0 / ndv - 1.0)
			+ vec3(0.0, 0.28, 0.56))), 0.6);

	// Flakes: one microfacet per cell, each with its own tilt, each returning
	// light over a couple of degrees only. That narrow lobe is the whole point
	// — a flake that is always lit is glitter paint, not glitter.
	float flake = 0.0;
	if (sparkle > 0.0) {
		vec2 cell = cp / max(flake_px, 0.5);
		vec2 ci = floor(cell);
		vec2 jt = hash22(ci + 19.7) - 0.5;
		vec3 fn = normalize(N + (T * jt.x + Bv * jt.y) * 1.5);
		flake = smoothstep(0.38, 0.05, length(fract(cell) - hash22(ci)))
			* pow(max(dot(fn, H), 0.0), 220.0);
	}

	// Where the coating actually is. Spot foil and reverse holo are masks, not
	// materials — the same finish, laid on part of the card.
	float m = 1.0;
	if (mask != 0) {
		vec2 a0 = art_rect.xy;
		vec2 a1 = art_rect.xy + art_rect.zw;
		float in_art = smoothstep(a0.x - 0.8, a0.x + 0.8, cp.x)
			* (1.0 - smoothstep(a1.x - 0.8, a1.x + 0.8, cp.x))
			* smoothstep(a0.y - 0.8, a0.y + 0.8, cp.y)
			* (1.0 - smoothstep(a1.y - 0.8, a1.y + 0.8, cp.y));
		if (mask == 1) {
			m = 1.0 - in_art;                    // reverse holo
		} else if (mask == 2) {
			m = in_art;                          // the art window alone
		} else {
			m = smoothstep(-12.0, -9.0, sdf(cp, card_size * 0.5, radius));
		}
	}

	vec3 ink_c = mix(ink.rgb, tint.rgb, ink_tint);
	vec3 col = src.rgb;
	col *= 1.0 + (ph * 0.6 + gh * 0.4) * 0.02;   // ink pools in the valleys
	col *= 1.0 - soak * broad;                   // lead drinks what lands on it
	// Subsurface: light that gets into the body comes back diffuse, so the
	// blacks lift a little and they lift toward the material's own colour.
	// It is why ink on paper is never as black as a screen's black.
	col += ink_c * bleed * 0.0025 * max(0.0, 1.0 - dot(col, vec3(0.333)));

	// Everything added is in LINEAR light, where the card's own stock sits at
	// about 0.006 and its text band at 0.020. That is the scale these numbers
	// are set against — an sRGB-looking 0.3 here would be thirty times the
	// card, which is exactly how a finish stops being a finish.
	vec3 add = ink_c * sheen * spec;
	add += spectrum * holo * band;
	add += film * pearl * band;
	add += mix(vec3(1.0), ink_c, 0.5) * sparkle * flake;

	ALBEDO = col + add * m;
	ALPHA = src.a;
}
