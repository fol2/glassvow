shader_type spatial;
render_mode unshaded, cull_back;

// EVERYTHING STANDING ON THE GROUND: rock, slab, bark, ash heap. Bought as
// UNTEXTURED geometry, so every square millimetre of surface here is ours,
// projected rather than unwrapped — which is what makes a bought GLB's UV
// layout irrelevant and removes texture style drift across separately
// generated modules.
//
// Read map_ground.gdshader first; this file is its twin and the header there
// carries the shared reasoning (why unshaded, why no outline or rim, why the
// per-act tint lives on the ramp, why the value gap is a uniform). Only what
// differs is argued here. The two must band identically — if `ramp()` moves
// in one file it moves in both, or ground and prop light differently and the
// silhouette failure this design repairs comes straight back.
//
// FOUR FETCHES AGAINST THE GROUND'S TWO. Three triplanar taps plus the grade.
// That is the whole arithmetic behind splitting the shaders: props are ~15%
// of the frame, so the expensive path runs on the small share and the cheap
// one on the large.
//
// SEVEN WITH `second_octave` ON — six triplanar taps plus the grade. That is
// the optional prop cost #233 item 2 exists to price, and it is optional in
// the only sense a bench can use: a uniform branch, so the off path pays one
// scalar compare and nothing else. Every fetch, every multiply and even the
// second sample position live inside the taken side; nothing was hoisted to a
// varying, because a varying is interpolated whether the branch runs or not.
// One compare is the FLOOR for a runtime toggle here, and that was checked
// rather than assumed: at 4.7.1 `Shader`, `ShaderMaterial`, `Material` and
// `RenderingServer` expose no define, variant or specialisation method between
// them, and the shader preprocessor's `#define` is per-file, so nothing can
// compile the branch away per material. The alternative that would — a third
// .gdshader carrying the variant — pays a second material and a duplicate of
// every line this file argues in order to save one compare. Declined.
//
// WORLD triplanar, not local. Local space would give every instance of the
// same module the identical texel pattern, and 25 modules reused across an
// act would read as 25 stamps. World space breaks that — and then creates its
// own problem, which is what `phase` below exists to fix.
//
// WHY THIS SHADER EXISTS AT ALL. A cel ramp quantises N·L into bands. Under a
// camera pitched 50–60° with one key, every up-facing surface returns the same
// N·L and therefore the same band; triplanar cannot separate them either,
// because its blend weight is a pure function of the normal, so two up-facing
// surfaces get identical weights and, projected through world space, identical
// texels. Rock top, neighbouring rock top and the ground beneath land in one
// band, one texel neighbourhood, one tint — and outlines are banned, cast
// shadows do not exist in this tree, SSAO is unavailable on Mobile, and
// LightmapGI cannot bake MultiMesh. `docs/map-concept-brief.md` §2 defines the
// `unlit` node state as "silhouette only, type hidden", so a world with no
// silhouette separation cannot carry the node language. Three things here are
// the repair: the grade's contact darkening (which is the only term that can
// see a neighbour), the per-instance phase, and the value gap.

// ── the key ───────────────────────────────────────────────────────────────
uniform vec3 sun = vec3(-0.35, 0.78, 0.52);
uniform int bands = 3;
uniform vec3 band_shade : source_color = vec3(0.14, 0.16, 0.28);
uniform vec3 band_key : source_color = vec3(0.96, 0.88, 0.72);

// ── the grade ─────────────────────────────────────────────────────────────
// Sampled by the fragment's own world XZ, which for a standing prop is its
// footprint at every height — so a prop is graded by where it stands, takes
// the aerial ramp its neighbours take, and picks up its own contact blob
// along its lower body.
uniform sampler2D grade : filter_linear, repeat_disable, source_color;
uniform vec4 grade_rect = vec4(-64.0, -64.0, 128.0, 128.0);
uniform float contact = 0.55;

// ── the surface ───────────────────────────────────────────────────────────
uniform sampler2D surface_tex : filter_linear_mipmap, repeat_enable;
const float TEX_STOPS[4] = {0.035, 0.070, 0.140, 0.280};
uniform int tex_stop = 1;

// A SECOND SAMPLING OCTAVE, AT A SCALE THAT CANNOT ALIGN (#233 item 2). The
// tile repeats at its own edge, so at stop 1 the surface pattern repeats every
// 1/0.070 = 14.3 world units — about two repeats across the 28.8-unit frame
// the proxy camera sees, which is exactly the range where the eye locks onto a
// layout and reads the world as wallpaper.
//
// BAKING OCTAVES INTO THE TILE CANNOT FIX THAT, and the tile already carries
// two: an octave baked at 4x cells is periodic on the SAME edge, so it adds
// detail inside the period without adding a period. A baked toggle therefore
// costs nothing and changes nothing about the repeat — which is precisely what
// the proxy measured before this uniform existed.
//
// Sampling the same tile a SECOND time at a different scale does add one, and
// then the ratio decides everything, because the two fields realign wherever
// m periods of one meet n of the other. Pick 1/2 and they realign every second
// tile: the repeat comes back at twice the distance, now decorated. 1/phi^2 is
// the far end of that scale — phi^2's continued fraction is all 1s after the
// lead, so no small rational approximates it, which is the property "most
// irrational" names. On the actual periods, 14.29 and 37.40 world units first
// fall within a quarter-period of each other 71 units out, two and a half
// frame widths past anything on screen.
//
// MEASURED, on a flat plane carrying this material under a flat white grade so
// the image is the surface pattern and nothing else, four tile periods tall.
// r is the row autocorrelation at the lag named; a perfect repeat is 1.0000.
//
//   ratio  mix    r(P)     r(2P)    strongest repeat  grain kept
//   —      off    1.0000   1.0000   1.0000 at P       1.000
//   1/phi2 0.32   0.8003   0.7983   0.8022 at P       0.737
//   1/phi2 0.40   0.6618   0.6577   0.6656 at P       0.705
//   1/phi2 0.50   0.4512   0.4445   0.4581 at P       0.690
//   1/2    0.32   0.8184   1.0000   1.0000 at 2P      0.767
//   1/2    0.50   0.5093   1.0000   1.0000 at 2P      0.727
//
// The last two rows are the argument above, on screen: a commensurate ratio
// still returns a PERFECT repeat, merely moved to 2P, and no weight touches it
// — 1/2 at an equal blend halves r(P) and leaves r(2P) at 1.0000 exactly. The
// ratio removes the period; the weight only decides how much of it is left at
// P. And since the weight is the only lever on r(P) — w1^2/(w1^2+w2^2), which
// predicts 0.819/0.692/0.500 against the 0.800/0.662/0.451 measured — the
// blend is equal. At 0.32 the grid is still legible by eye in the rig; at 0.50
// it is not.
//
// 0.45 IS THE FLOOR FOR AN EQUAL TWO-TAP BLEND, not zero: half the weight is
// still sitting on an exactly periodic field, and no weight can do better than
// half. Lower than 0.45 needs a third sample or per-tile stochastic offsets —
// a different price point, and #233 is pricing this one.
//
// COARSER, NOT FINER, deliberately. A finer octave at an irrational ratio
// would break the period too, but it lands its detail inside the base blob
// where the baked octave already put some; a coarser one drifts the whole
// neighbourhood's value across the frame, so each repeat of the base pattern
// sits on a different level and the eye loses the match it was making.
const float OCTAVE_SCALE = 0.381966;   // 1/phi^2 — see above
const float OCTAVE_MIX = 0.50;         // equal — see the table

// The mix is linear and both samples are the same tile, so both carry the same
// mean and the blend's mean is unchanged: repair 8's value lock survives the
// octave untouched, at any weight. Measured, mean linear luminance moves from
// 0.07628 to 0.07626. CONTRAST DOES NOT SURVIVE: an equal blend of two
// decorrelated samples carries 1/sqrt(2) of one sample's contrast — the same
// arithmetic that makes triplanar's crossover a contrast trough, appearing a
// second time in the same shader — and the rig measured 0.690 against that
// 0.707. Renormalising the deviation about surface_value would buy it back for
// one multiply, and is declined: 0.707 is only exact while the two samples
// stay decorrelated, so the correction would be a constant standing in for
// something that moves with OCTAVE_SCALE. A histogram-preserving blend
// (Heitz/Neyret) buys it back properly and needs a precomputed decorrelated
// tile plus an inverse-histogram lookup — a third fetch and an offline step,
// to repair 31% of the grain on 15% of the frame.
uniform bool second_octave = false;

// How hard the three projections cut over into one another. Low values blend
// wide and the band shows as a stripe of halved texture contrast — two
// decorrelated samples averaged carry 1/sqrt(2) of one sample's contrast, and
// on a flat cel band that loss of grain is the only signal left, so it reads
// as a smeared belt. High values narrow the band toward a seam. Measured, both
// ends and the trade between them: tools/probe_map_shaders.gd.
uniform float sharpness = 8.0;

// PER-INSTANCE TEXTURE PHASE (#207 repair 4). World triplanar means a prop
// standing on the ground samples the world field at almost the same place the
// ground does, in the same band, at the same tint — and welds into it. This
// offsets each instance's sample position by its own vector, so the weld is
// broken for free, without a second material, a second draw or a fetch.
//
// It arrives through MultiMesh instance custom data, which requires
// `use_custom_data = true` on the MultiMesh before any instance is written;
// the scene sets each instance's Color to three values in 0..1 and this scales
// them into world units. `phase` is deliberately not a round number: an offset
// that lands on a multiple of the tile period is no offset at all.
//
// The second octave rides the same offset — it scales `tri_pos`, which already
// carries it — so repair 4 decorrelates instances on both taps for one vec3
// multiply and no second custom-data channel. At stop 1 the full custom-data
// range spans 37 * 0.070 = 2.59 tile periods on the base tap and 0.99 on the
// octave. Both spread instances across a whole period, which is what the
// offset is for; 0.99 is a coincidence of these two constants and nothing
// downstream depends on it.
uniform float phase = 37.0;

// ── the value gap ─────────────────────────────────────────────────────────
// The dark half of the anchor's measured pair: V 0.35 sRGB, 0.100 linear,
// against the ground's 0.68 / 0.420. Props are the dark masses cut into the
// bright stage, not the other way round. See map_ground.gdshader for why the
// pin is on the tile's mean rather than on each fragment.
//
// THE GAP HAS NO AGREED MEASUREMENT SITE, and that is now understood rather
// than merely unresolved. Three sites are available and two of them answer a
// different question:
//
//   uniform space         0.420 vs 0.100 linear, by construction. Ignores
//                         lighting and the grade entirely, so it can only ever
//                         report the constants back.
//   whole-screen average  folds in every prop face turned away from the key.
//                         Those render near-black BY CONSTRUCTION — half-
//                         lambert bottoms out in band_shade — and are not what
//                         the anchor's 0.35 describes, which is a lit mass on
//                         a lit stage.
//   under the key, in     the only site where both surfaces are answering the
//   screen space          same question the anchor asked.
//
// Measured at the third: ground 0.614, prop 0.342, gap 0.272, against the
// anchor's 0.68/0.35 and its gap of 0.33. The numbers are recorded as they
// came out. Nothing here is tuned toward 0.33 — a uniform moved to make one
// screen-space patch land on a number would be fitting the constant to the
// measurement site, and the site is the thing in question. Whether 0.272
// should be widened, and by moving which of surface_value, band_shade or the
// grade, is #234's decision and not a tuning job in this file.
uniform float surface_value = 0.100;
uniform float tex_mean = 0.5;

varying vec3 world_pos;
varying vec3 world_n;
varying vec3 tri_pos;
varying vec3 tri_w;


// Duplicated from map_ground.gdshader on purpose — see the header there.
vec3 ramp(float nl) {
	float n = float(max(bands, 2));
	float q = min(floor(clamp(nl, 0.0, 1.0) * n), n - 1.0) / (n - 1.0);
	return mix(band_shade, band_key, q);
}


// The weights and the sample position are computed HERE, per vertex, and
// interpolated — which is what makes triplanar nearly free in the fragment
// stage: three texture() calls and three multiply-adds, no ALU worth counting.
// The engine's own BaseMaterial3D triplanar does the same, and #207 verified
// it at 4.7.1-stable. The cost is that a coarsely tessellated module gets a
// linearly interpolated blend band and can show faceting across the crossover;
// that is a content constraint on the bought geometry, not something to fix
// here by moving the pow() into the fragment stage.
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 n = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	world_n = n;
	// The largest component is scaled to 1 BEFORE the pow, so the largest
	// weight is exactly 1 and the sum can never fall below it. Raising the raw
	// components instead underflows at the crossover — where every component
	// is ~0.707, and 0.707^32 is 1.05e-5, so a `max(sum, 1e-4)` guard silently
	// becomes active and scales the albedo down by 4.8x. That prints a hard
	// dark line along every 45-degree crossover, which probe_map_shaders.gd
	// measured before this line was written and which reads exactly like the
	// contour #233 asks about. It is not one; it is arithmetic.
	vec3 a = abs(n);
	a /= max(max(a.x, a.y), max(a.z, 1e-6));
	vec3 w = pow(a, vec3(sharpness));
	tri_w = w / (w.x + w.y + w.z);
	// No sign flip on the X projection. The engine negates one axis there, so
	// a directional tile mirrors between the two opposite faces of the same
	// object; dropping the negation costs nothing and these tiles are
	// non-directional material patches, not paintings with a top.
	tri_pos = (world_pos + INSTANCE_CUSTOM.xyz * phase) * TEX_STOPS[clamp(tex_stop, 0, 3)];
}


void fragment() {
	vec3 albedo = (texture(surface_tex, tri_pos.zy).rgb * tri_w.x
		+ texture(surface_tex, tri_pos.xz).rgb * tri_w.y
		+ texture(surface_tex, tri_pos.xy).rgb * tri_w.z)
		* (surface_value / max(tex_mean, 1e-4));
	if (second_octave) {
		vec3 o = tri_pos * OCTAVE_SCALE;
		vec3 coarse = (texture(surface_tex, o.zy).rgb * tri_w.x
			+ texture(surface_tex, o.xz).rgb * tri_w.y
			+ texture(surface_tex, o.xy).rgb * tri_w.z)
			* (surface_value / max(tex_mean, 1e-4));
		albedo = mix(albedo, coarse, OCTAVE_MIX);
	}
	vec4 g = texture(grade, (world_pos.xz - grade_rect.xy) / grade_rect.zw);

	float nl = dot(normalize(world_n), normalize(sun)) * 0.5 + 0.5;
	nl -= (1.0 - g.a) * contact;
	ALBEDO = albedo * ramp(nl) * g.rgb;
}
