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
// this camera distance. A band of holo therefore exists as a real gradient
// across the face, and tilting slides it, exactly as it does in your hand.
//
// The eye is only half the budget. The other half is the LAMP, and for the
// same reason it has to be a point in that room rather than a direction: see
// THE LAMP below. Between them the card gets a real half-vector field, which
// is all a material has ever needed.
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

// THE LAMP. A POINT in the stage's own world, at card-pixel scale — not a
// direction. That one word is the difference between a highlight that is
// weather over the card and a light you can aim.
//
// A directional key is this same lamp moved to infinity, and infinity is the
// pose it takes at rest: 2000px up and slightly left of the lens, ~17 degrees
// off the view axis. It has to sit CLOSE to that axis, because the card only
// turns 7 degrees and a highlight parked 30 away could never be reached.
//
// What being a point buys is that L is DIFFERENT at every fragment. At 2000 the
// direction to the lamp swings 8 degrees corner to corner — enough to matter,
// nowhere near enough to localise anything, so every fragment shares a
// half-vector and the specular can only ever be a broad band. Bring the lamp to
// 150, where the cursor puts it, and that swing is 83 degrees with the
// half-vector taking 41, and the same material resolves into a pool the size of
// your thumb. Nothing about the material changed; the light did.
//
// lamp_ref is |lamp - card centre|^2, so the inverse square is 1 at the centre
// and a gradient from there out, rather than an exposure change every time the
// lamp moves. The clamp only stops a lamp parked over one corner from
// over-driving it.
uniform vec3 lamp = vec3(-190.0, 572.0, 1906.0);
uniform float lamp_ref = 3996120.0;
// How much light the near lamp adds OVER the room's. Zero at rest on purpose:
// the room light is already painted into the face, so all the lamp contributes
// is what it adds by being carried close.
uniform float lamp_gain = 0.0;

// The near lamp's diffuse strength where it is aimed. Multiplicative, and that
// is the whole argument against what it replaced: the old cursor glare added
// WHITE at 0.17 alpha, which greyed the card stock wherever it landed. Real
// light scales what is already there — black ink stays ink, and the parchment,
// the gold rules and the art are what come up.
const float LAMP_WASH = 0.75;

// A mirror shows the SOURCE, not the light that arrived. Every specular channel
// below — the lobe, the diffraction band, the film, the flakes — is an image of
// whatever is lighting the card, so what it returns follows the lamp's RADIANCE
// and not its irradiance, and the two are not the same thing at all: a bare
// lamp carried to 150 is a far fiercer thing to reflect than a room. That is
// the whole reason foil is dull on a shelf and violent in your hand, and why a
// confetti sheet goes off like a mirror ball the moment the light comes close.
// Diffuse does none of this — LAMP_WASH is irradiance and stays where it is.
const float LAMP_MIRROR = 2.0;

// ...except for the FLAKES, which are the one channel that can afford the
// gem's number. card_gem.gdshader lights the same card off the same lamp at a
// 64x radiance swing between room and bare bulb, and it is right to: that ratio
// is what a mirror really does. LAMP_MIRROR cannot be 64 because sheen and the
// diffraction band cover the whole face and would go to white. A confetti field
// covers 3 percent of it. So the flakes get their rest state pulled DOWN
// instead, and the ratio they end up with is 3 / 0.15, twenty.
//
// Measured on nebula, this is the actual bug the ratio fixes: before it the
// field was 56 percent as active at rest as it was with the lamp on the card,
// so carrying the light to it changed almost nothing. The lamp was never too
// weak — the room was too strong. A broad source cannot make a confetti sheet
// flash, and it should not be able to.
const float FLAKE_ROOM = 0.15;

// THE FLAKES ARE NOT ON THE SURFACE. A cosmos sheet is an embossed hologram
// under a laminate: its bright points are a virtual image sitting BELOW the
// face, which is the entire reason the effect reads as a star field you can
// look into rather than as glitter stuck to a page.
//
// So each flake carries its own depth and appears SLID by it — the same
// parallax card_gem.gdshader gets from refract(), for the same reason and to
// the same end. Two things fall out of one hash. Statically the field shears
// across the face, because the eye's angle is different at the top of the card
// than at the bottom. In motion the deep flakes travel further than the shallow
// ones and slide THROUGH them, and differential motion is the strongest depth
// cue a single eye has.
//
// The unit is PITCHES, not pixels, so the depth of the layer scales with the
// coarseness of the flake in it — and so the sweep's bound below can be one
// number instead of a function of the pitch.
const float FLAKE_DEEP = 3.0;
// And that bound is not a taste knob, it is where the 5x5 sweep stops being
// true. A flake owned by cell ci appears somewhere in ci + [0,1] plus its
// slide, and lights out to its farthest reach around that — the halo, at 1.2
// cells — so the fragments it touches still floor() into ci +/- 2 only while
// slide + reach stays under 2. At 0.55 the headroom is 1.45, and the halo's
// 1.2 and the largest torn disc's 0.7 both fit under it. Past the bound,
// flakes drop out along the lattice, which is the same "grid, not a sky" the
// sweep was built to prevent, arriving by a new road.
//
// It is par that gets clamped rather than the depth, and that is the whole
// reason the depth above can be a big number: scaling par scales every flake by
// the SAME factor, so the deep ones still travel further than the shallow ones
// and the layering survives. All the clamp does is stop the field sliding
// further once the card is already leaning hard.
const float FLAKE_SLIDE = 0.55;
// Depth costs light — the far flakes come back through more of the film and
// through whatever is floating above them. It is the static half of the cue:
// without it a still card has layers that are only provable by moving it.
const float FLAKE_MURK = 0.55;
// The halo. On a dark card a lit pinprick with no spill is a fleck of pigment;
// with three pixels of soft glow it is a SOURCE. That is halation — the lens
// and the eye blooming around anything much brighter than its ground — and it
// is gated by the same angular lobe as the flash, so it exists only while the
// flake is actually firing. Peak strength relative to the disc's own core.
const float FLAKE_GLOW = 0.15;
// The herd. A cosmos emboss is stamped in PATCHES a few millimetres wide, each
// patch sharing one groove orientation — so a real sheet flashes a REGION at a
// time, a wave rolling across the card as the angle sweeps. Flakes whose aim
// and colour are both fully random can only ever read as noise, which is to
// say as dust. This is how much of every flake's aim belongs to its patch
// rather than to itself.
const float FLAKE_HERD = 0.55;

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
uniform float flake_big = 0.0;
uniform float flake_hue = 0.0;
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

// One layer of the confetti field — the pattern a cosmos holofoil sheet is.
// Each cell holds one flake at a random offset, with its own facet tilt and
// its own place on the spectrum, so neighbours come out different colours
// while a tilt walks EVERY one of them along the spectrum together.
//
// That pairing is the whole effect, and either half alone fails: colours that
// are only random read as glitter paint stuck to the card, and a single shared
// band reads as cheap foil. A real sheet is a field of independent gratings —
// same physics as the holo band above, chopped into pieces and rotated.
//
// `edge`/`soft` bound the disc (edge is its radius in cells, soft where the
// falloff finishes), `lobe` is how narrow the flash is in angle, `tip` how far
// the facet leans off the surface. Big flakes want a softer rim, a wider lobe
// and a shallow tip.
//
// The 5x5 sweep is where the field's geometry is allowed to happen. A flake
// sits at a random point in its cell, slides sideways by its depth, tears to
// near double size, and throws a halo well past its own disc — sample the
// owning cell alone and all of that comes back clipped square along the
// lattice: a grid, not a sky. The bound that keeps five columns sufficient is
// worked at FLAKE_SLIDE, and the halo is the reason three stopped being enough.
//
// `par` is the eye's tangent in the card's own axes — how far a feature one
// unit down appears to move. See FLAKE_DEEP.
vec3 confetti(vec2 p, float pitch, float edge, float soft, float lobe,
		float tip, vec3 N, vec3 T, vec3 Bv, vec3 H, float g, vec2 par) {
	vec2 cell = p / max(pitch, 0.5);
	vec2 base = floor(cell);
	vec3 sum = vec3(0.0);
	for (int j = -2; j <= 2; j++) {
		for (int i = -2; i <= 2; i++) {
			vec2 ci = base + vec2(float(i), float(j));
			// How far down this one sits, and so where it APPEARS: its own
			// place in the cell, plus the slide its depth buys it. One hash
			// gives the whole field a thickness.
			float dep = hash12(ci + 3.1);
			float d = length(cell - ci - hash22(ci)
				- par * (dep * FLAKE_DEEP));
			// Foil tears unevenly. Most flakes are pinpricks; roughly one in
			// sixteen came off near double size, and those are the ones that
			// FLARE — a field with one fixed calibre is a print run.
			float sz = mix(0.85, 1.7, pow(hash12(ci + 11.3), 4.0));
			float shape = smoothstep(edge * sz, soft * sz, d);
			float halo = max(1.0 - d / 1.2, 0.0);
			if (shape + halo <= 0.0) {
				continue;
			}
			// The herd: this flake's aim is mostly its patch's aim, and its
			// place on the spectrum is mostly its patch's place. Two smooth
			// fields at different scales, so the colour clouds and the flash
			// regions never share an edge and nothing reads as tiles.
			vec2 aim = vec2(vnoise(ci * 0.13 + 31.7),
				vnoise(ci * 0.13 + 57.1)) - 0.5;
			vec2 jt = mix(hash22(ci + 19.7) - 0.5, aim, FLAKE_HERD);
			vec3 fn = normalize(N + (T * jt.x + Bv * jt.y) * tip);
			float s = pow(max(dot(fn, H), 0.0), lobe);
			vec3 hue = 0.5 + 0.5 * cos(TAU * (g + vnoise(ci * 0.16)
				+ (hash12(ci + 7.3) - 0.5) * 0.35
				+ vec3(0.0, 0.33, 0.67)));
			// At exact alignment every diffraction order lands together, so
			// the CORE of a flash is white and the colour lives on its
			// shoulder — s is the lobe itself, so s^2 whitens only its peak.
			// Saturated dots that never clip are pigment; these are light.
			sum += mix(hue, vec3(1.0), s * s)
				* (shape + FLAKE_GLOW * halo * halo)
				* (1.0 - FLAKE_MURK * dep) * s;
		}
	}
	return sum;
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

	// The lamp, resolved per fragment — these four lines are the whole feature.
	// VERTEX is in view space here, so one matrix takes the shading point back
	// to the room the lamp is standing in.
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 lv = lamp - world;
	float r2 = max(dot(lv, lv), 1.0);
	vec3 L = lv * inversesqrt(r2);
	float fall = min(lamp_ref / r2, 1.0);
	vec3 H = normalize(L + V);

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
	//
	// The stretch used to be 1 + 7|a|, which is 4.5x at the metallic tier. That
	// was harmless while the light was a fixed direction, because the highlight
	// was already a band spanning the card and a wider band is still a band. A
	// point lamp makes a POOL, and a pool stretched 4.5x is a horizontal bar
	// lying across the card — which is what it looked like. 1 + 3|a| caps the
	// tier at 2.5x, an unmistakable streak that is still a highlight.
	float ndh = dot(N, H);
	if (abs(aniso) > 0.001) {
		float sq = 1.0 + 3.0 * abs(aniso);
		vec2 ho = vec2(dot(H, T), dot(H, Bv));
		ho = aniso >= 0.0 ? vec2(ho.x / sq, ho.y) : vec2(ho.x, ho.y / sq);
		ndh = dot(N, normalize(T * ho.x + Bv * ho.y + N * dot(H, N)));
	}
	float spec = pow(max(ndh, 0.0), tight);

	// Diffraction. A grating throws each wavelength off at its own angle, so
	// the spectrum sweeps past the eye as the geometry turns — banded ACROSS
	// the grooves, which is what separates holo from pearl by eye.
	//
	// The order that reaches you is set by sin(out) - sin(in), and the
	// TANGENTIAL HALF-VECTOR is exactly that quantity. Driving it off V alone —
	// all a fixed key light lets you get away with — nails the fan to the eye,
	// so the rainbow can only ever answer the card. Off H it fans out of the
	// lamp's own reflection, and moving the light moves the rainbow. That is
	// the tell of real diffraction against a printed one.
	float groove = radians(holo_dir);
	float g = dot(vec2(dot(H, T), dot(H, Bv)),
		vec2(cos(groove), sin(groove))) * holo_scale;
	vec3 spectrum = 0.5 + 0.5 * cos(TAU * (g + vec3(0.0, 0.33, 0.67)));

	// Thin-film interference. The path through the film grows as 1/cos(theta),
	// zero on the axis and rising outward — so pearl rings AROUND that axis
	// rather than banding across the card. The axis is the lamp's reflection,
	// not the eye: taken off the view vector the rings sit nailed to the screen
	// while the card turns underneath them, which is the one thing a real pearl
	// coat never does.
	vec3 film = mix(vec3(1.0),
		0.5 + 0.5 * cos(TAU * (pearl_scale * (1.0 / max(base, 0.2) - 1.0)
			+ vec3(0.0, 0.28, 0.56))), 0.6);

	// The confetti field — cosmos holofoil. Two layers of it: a dense layer of
	// sharp pinpricks and a sparser layer of larger, softer, paler discs, which
	// is the pairing a real cosmos sheet has and the reason it reads as depth
	// rather than as glitter paint sprayed on.
	vec3 flake = vec3(0.0);
	if (sparkle > 0.0) {
		// Where the eye is, as a tangent in the card's own axes: how far a
		// feature one unit below the face appears to slide. Off Nf and not N,
		// because depth is measured from the FACE — the relief's normal says
		// how the coating catches light, not how thick it is.
		vec2 par = vec2(dot(V, T), dot(V, Bv)) / max(dot(V, Nf), 0.3);
		par *= min(1.0, FLAKE_SLIDE / max(FLAKE_DEEP * length(par), 1e-4));
		flake = confetti(cp, flake_px, 0.40, 0.08, 120.0, 1.2,
			N, T, Bv, H, g, par);
		if (flake_big > 0.0) {
			// Bigger facets are flatter, so they hold light over a wider angle
			// and stay pale — they never reach the pinpricks' saturation.
			vec3 disc = confetti(cp + 137.0, flake_big, 0.34, 0.20, 70.0, 0.9,
				N, T, Bv, H, g, par);
			flake += mix(disc, vec3(dot(disc, vec3(0.333))), 0.25) * 0.30;
		}
	}

	// Where the coating actually is. Spot foil and reverse holo are masks, not
	// materials — the same finish, laid on part of the card.
	//
	// `mf` is the second extent, and a real holo card needs two. The clear
	// LAMINATE runs over the whole card — that is the gloss and the travelling
	// wash, and it is why the whole thing is shiny in your hand. The foil EMBOSS
	// is stamped under the art window alone, because that is where the stamp
	// went. One mask cannot say that: whole-face puts the stars over the rules
	// text, and masking the lot to the art takes the shine off half the card.
	float m = 1.0;
	float mf = 1.0;
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
		} else if (mask == 4) {
			mf = in_art;                         // laminate whole, foil in art
		} else {
			m = smoothstep(-12.0, -9.0, sdf(cp, card_size * 0.5, radius));
		}
	}

	vec3 ink_c = mix(ink.rgb, tint.rgb, ink_tint);
	vec3 col = src.rgb;
	col *= 1.0 + (ph * 0.6 + gh * 0.4) * 0.02;   // ink pools in the valleys
	// The near lamp's own diffuse. It reads N, so the relief and the grain get
	// SHADED by it rather than merely tinted — and Lambert is flat head-on and
	// steep at a slant, so the weave shows most where the light rakes past it,
	// beside the pool rather than under it. That is what raking a lamp across
	// a textured stock does, and it is the reason texture and light had to end
	// up on the same vector.
	col *= 1.0 + lamp_gain * LAMP_WASH * max(dot(N, L), 0.0) * fall;
	col *= 1.0 - soak * broad * fall;            // lead drinks what lands on it
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
	// flake_hue decides whether the confetti keeps its own spectrum or takes the
	// material's colour. Gold leaf throws gold sparks, not rainbows; a cosmos
	// sheet is nothing BUT rainbows. The spectrum averages 0.5, so the hue-free
	// branch is doubled to land at the same brightness either way.
	float fi = dot(flake, vec3(0.333));
	// ...and unlike every channel above it, this one does NOT settle for the
	// shared LAMP_MIRROR. See FLAKE_ROOM: a mirror the size of a flake is
	// entitled to the gem's ratio, and only the flakes are small enough to be
	// given it without the face going white.
	add += mix(ink_c * fi * 2.0, flake, flake_hue) * sparkle * mf
		* mix(FLAKE_ROOM, 1.0, lamp_gain);

	// Everything the surface gives back is light the lamp delivered, so it all
	// carries the same inverse square. Head-on at rest that is a 3.5% gradient
	// corner to corner; with the lamp on the card it is most of why the far
	// side stays quiet while the near side sings.
	ALBEDO = col + add * m * fall * (1.0 + LAMP_MIRROR * lamp_gain);
	ALPHA = src.a;
}
