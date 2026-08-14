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
uniform float phase = 37.0;

// ── the value gap ─────────────────────────────────────────────────────────
// The dark half of the anchor's measured pair: V 0.35 sRGB, 0.100 linear,
// against the ground's 0.68 / 0.420. Props are the dark masses cut into the
// bright stage, not the other way round. See map_ground.gdshader for why the
// pin is on the tile's mean rather than on each fragment.
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
	vec4 g = texture(grade, (world_pos.xz - grade_rect.xy) / grade_rect.zw);

	float nl = dot(normalize(world_n), normalize(sun)) * 0.5 + 0.5;
	nl -= (1.0 - g.a) * contact;
	ALBEDO = albedo * ramp(nl) * g.rgb;
}
