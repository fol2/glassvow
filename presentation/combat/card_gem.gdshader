shader_type spatial;
render_mode depth_draw_opaque, unshaded;

// OPAQUE, and deliberately — this is the one render_mode line worth reading.
// A stone with leaf behind it passes no light, so it never writes ALPHA, so
// Godot puts it in the opaque pass where it WRITES DEPTH. The face plate beside
// it is blend_mix and does not, and two transparent surfaces on one mesh are
// ordered by nothing more reliable than the sort key — which is exactly how the
// card's own face came to paint over the gem the moment the gem stopped sharing
// its shader. Depth settles it instead of luck, and the silhouette gets the
// opaque pass's MSAA into the bargain.

// THE COST GEM. Every other surface on this card is a SHEET — stock, leaf,
// coating, all of it a few microns of something laid on a plane, and
// card_surface.gdshader shades exactly that. A gem is not a sheet. It is a
// SOLID, and every optical thing that makes a stone read as a stone happens
// because the light goes inside it and has to find its way back out.
//
// So the badge stopped being a drawing of a gem and became one: twelve real
// facets rising to a table, cut in card_view.gd's _prism_mesh, set over a leaf
// floor with the numeral struck into it. What this file does is follow one ray
// through that solid — in at a facet, down to the leaf, back out — and the four
// things a jeweller would name fall out of that single path.
//
//   the flash   A facet is a MIRROR. It is aimed at the lamp or it is not, and
//               that switch throwing one facet at a time as the light moves is
//               what a cut is FOR. It is also why the exponent here is the
//               largest number in the project: a coating spreads its highlight,
//               a cut refuses to.
//   the depth   What you see through the table is not what is under it. The ray
//               bends coming in, so the engraving SLIDES — by a different amount
//               under every facet, breaking at each edge. Nothing else reads as
//               "solid" for so little.
//   the colour  Glass absorbs along the path, so a long way through is not a
//               darker gold, it is a deeper one. The thin rim stays pale. That
//               gradient is the stone's own body and it needs no light at all,
//               which is what carries the gem in a still frame.
//   the return  The leaf at the bottom is a second mirror, so the lamp has a
//               SECOND image down there — and it answers a different question
//               than the surface flash does. That one asks where a facet
//               POINTS; this asks where it BENDS. They fire at different
//               moments in the same sweep, and two highlights moving at
//               different rates is what the eye reads as thickness.
//
// What is NOT here is FIRE, and that is a measurement rather than a shortcut.
// Dispersion was built — three indices for three channels, the way a stone's
// index really is a curve — and it moved the render by 0.15 percent. At SIX
// times the physical split it moved it 0.72, still with no colour an eye could
// find. The reason is not the 36 px. It is the LEAF: fire belongs to colourless
// stones, and every dispersed path in here crosses an amber body twice and
// comes back amber whatever angle it left at. A gold-backed stone cannot throw
// a rainbow. The loop came out.
//
// Nothing here reads TIME, for the same reason nothing else on this card does:
// the viewports freeze the moment the card stops moving, so a time-driven
// sparkle would silently die. Every channel is a function of geometry.

uniform sampler2D face_tex : filter_linear, repeat_disable, source_color;
uniform vec2 face_size = vec2(168.0, 232.0);   // the inner texture, in card px

// The stone, as the only two colours an eye can actually name: `foil` is the
// leaf with no glass over it, `deep` is that same leaf seen a full crown-height
// down. Everything between them is Beer-Lambert.
uniform vec4 foil : source_color = vec4(1.0);
uniform vec4 deep : source_color = vec4(1.0);
uniform float crown = 3.6;      // the cut's height in card px — see card_view.gd
// Lead crystal, which is what 琉璃 is. It buys two things over window glass:
// a stronger front-surface reflection (F0 below) and a shorter path through the
// body for the same crown, because the ray bends harder on the way in.
uniform float ior = 1.75;

// THE LAMP. The same three uniforms card_surface.gdshader takes, in the same
// units, meaning the same thing — so card_view.gd's _push_lamp() feeds a cut
// stone and a sheet of foil through one loop and they cannot drift apart. A
// stone and a coating disagree about everything except where the light is.
uniform vec3 lamp = vec3(-190.0, 572.0, 1906.0);
uniform float lamp_ref = 3996120.0;
uniform float lamp_gain = 0.0;

// A mirror returns the SOURCE's radiance, not the light that arrived — and the
// two sources this card ever has are not remotely the same object. A room is
// broad and mild. A bare lamp carried to 150 px is small and violent. That is
// the same argument card_surface.gdshader makes with LAMP_MIRROR, except a
// COATING can afford to fold it into a flat multiplier and a FACET cannot: a
// coating's highlight is wide under either source, a facet has nowhere to hide
// a broad one. So lamp_gain rides on the radiance here, which is where it
// physically lives.
//
// Get this wrong and the failure is unmistakable — the table is the facet most
// often square to the half-vector, so at rest it flashes at 60 percent of full
// and a bare-lamp radiance clips it to white with the numeral inside it.
// The ratio is enormous and it is supposed to be. It is also the number that
// decides whether the numeral survives: every one of these channels is ADDITIVE
// over a floor that includes near-black ink, so a reflection strong enough to
// see at rest is a reflection strong enough to VEIL the engraving — the same
// failure the painted cursor glare had, arriving by a completely different
// road. A gem does veil its own engraving; it does it where the light lands,
// for as long as the light is there, and not the rest of the time.
const float ROOM_LIGHT = 0.5;
const float LAMP_LIGHT = 32.0;

// n = 1.75 gives F0 = 0.074 by Schlick. The angular term is deliberately NOT
// computed: the steepest facet in this cut presents 40 degrees to the eye, and
// (1 - cos 40)^5 is 0.0007 — Schlick has not moved by then. A constant dressed
// up as physics is worse than a constant, so it stays a constant.
const float F0 = 0.074;
// The room as a mirror image (added) and as illumination through the facet
// (multiplied). SHADE is the one that carries the still frame — at 0.32 the
// body runs 0.68x to 1.32x across the cut, which is about the swing the
// benchmark's three-stop ramp had, and it costs the ink nothing.
const float ROOM = 0.035;
const float SHADE = 0.32;
// The leaf is a mirror, but a burnished one: it spreads what it returns instead
// of throwing it back in a point, which is why its lobe is the loose one and
// its gain the small one. Most of what the leaf sends back is already in `col`.
const float LEAF = 0.05;

const float TIGHT = 200.0;      // the facet flash: 4.8 degrees of half-width
const float GLINT = 60.0;       // the leaf's image: 8.8, it is a rough mirror

void fragment() {
	// Two frames, and keeping both is the entire point of this file. The SLAB's
	// axes (T, Bv, Nf) are the stone's floor — where the leaf and the numeral
	// lie. The FACET's normal N is not remotely the same thing, and everywhere
	// they disagree is where a gem stops looking like a badge.
	vec3 T = normalize((MODEL_MATRIX * vec4(1.0, 0.0, 0.0, 0.0)).xyz);
	vec3 Bv = normalize((MODEL_MATRIX * vec4(0.0, -1.0, 0.0, 0.0)).xyz);
	vec3 Nf = normalize((MODEL_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz);
	vec3 N = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 V = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);

	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 lv = lamp - world;
	float r2 = max(dot(lv, lv), 1.0);
	vec3 L = lv * inversesqrt(r2);
	float fall = min(lamp_ref / r2, 1.0);
	vec3 H = normalize(L + V);

	// IN. The eye's ray bends at the facet and runs down to the leaf. UV2.x is
	// how high above that leaf this fragment stands — carried per vertex,
	// because the cut is the only thing that knows — so one divide gives the
	// PATH: straight down under the table, a long slant under the crown. It is
	// both how far the engraving slides and how much colour the light picks up,
	// which is not a coincidence. It is the same journey.
	vec3 rr = refract(-V, N, 1.0 / ior);
	float path = UV2.x / max(-dot(rr, Nf), 0.15);
	vec2 slide = vec2(dot(rr, T), dot(rr, Bv)) * path;
	vec4 src = texture(face_tex, UV + slide / face_size);
	// Off the badge's own footprint the slide finds nothing, and what is under a
	// stone where the print runs out is the leaf itself.
	vec3 leaf = mix(foil.rgb, src.rgb, src.a);

	// Beer-Lambert, written as the ratio between the two named colours so that
	// one crown of path turns `foil` into `deep` exactly. Saturation is what
	// grows with depth, not darkness — the reason a stone's rim is pale and its
	// heart is not, and the reason the numeral sits in the deepest part of it.
	vec3 col = leaf * pow(max(deep.rgb, vec3(1e-4)) / max(foil.rgb, vec3(1e-4)),
		vec3(clamp(path / crown, 0.0, 3.0)));

	// The room, at its crudest: bright overhead, dark below. A facet shows
	// whatever it is aimed at, so with eighteen of them this one gradient is
	// what makes the CUT read in a still frame — the lamp only ever lights two
	// or three of them and the room has to carry the rest.
	//
	// It arrives TWICE, and the two are not interchangeable. A facet is a
	// mirror: F0 of what it faces, laid on top of the body, and small because F0
	// is small. A facet is also a WINDOW — the room's light goes through it, off
	// the leaf and back out, and how much makes that trip depends on the facet's
	// aim just as much. That one MULTIPLIES, and multiplying is the entire
	// reason the numeral is still black at rest: scale ink and it stays ink, add
	// to it and it goes grey. Which is precisely the failure the painted cursor
	// glare had, reached from the opposite direction.
	//
	// Between them they are what the badge's conic ramp was drawing. The
	// difference is that these turn when the card turns.
	float sky = smoothstep(-0.4, 0.7, reflect(-V, N).y);
	col *= 1.0 - SHADE + 2.0 * SHADE * sky;

	// The flash, off the facet's own face.
	float flash = pow(max(dot(N, H), 0.0), TIGHT);

	// OUT, the long way: down through the glass, off the leaf, back at the eye.
	// This highlight lives at the BOTTOM of the stone, so it asks a different
	// question than the flash above — that one asks where the facet POINTS, this
	// asks where it BENDS — and the two answer at different moments of the same
	// sweep.
	//
	// It is MULTIPLIED by the body rather than added to it, and that is not
	// bookkeeping. A surface reflection sits on top of whatever is underneath,
	// so the flash veils the engraving; this is light that had to get past the
	// ink to exist at all, so it cannot. It is the reason the numeral survives
	// the brightest moment the stone has.
	float glint = pow(max(dot(reflect(rr, Nf), L), 0.0), GLINT);

	// Both additions are IMAGES of whatever is lighting the card — one off the
	// facet's face, one off the leaf under it — so both take the source's
	// radiance and both fall off with it. The room's own reflection does not:
	// it is not an image of the lamp and it does not move when the lamp does.
	float source = mix(ROOM_LIGHT, LAMP_LIGHT, lamp_gain);
	vec3 add = vec3(flash * F0) + col * (glint * LEAF);
	ALBEDO = col + sky * ROOM + add * source * fall;
}
