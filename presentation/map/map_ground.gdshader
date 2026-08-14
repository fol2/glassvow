shader_type spatial;
render_mode unshaded, cull_back;

// THE GROUND THE JOURNEY RUNS ACROSS. ~85% of every map frame is this shader,
// so every fetch it does costs four times what the same fetch costs on a prop.
// It therefore does the fewest a graded, cel-shaded surface can: ONE surface
// lookup and ONE grade lookup. Two.
//
// It is a separate shader from map_prop.gdshader for exactly that reason
// (#207 repair 3). Props need world triplanar because they present faces on
// every axis; the ground presents one face, up, and a plain XZ lookup is
// already the correct projection for it. Unifying the two "for cleanliness"
// would buy one file and pay three texture fetches across the majority of the
// frame — the split IS the optimisation, not a tidiness failure.
//
// UNSHADED, AND WHY THE ENGINE'S LIGHTING PASS IS NOT USED. The map has one
// key light, no cast shadows (`shadow_enabled` appears nowhere in this tree),
// no SSAO on the Mobile renderer, and no baked GI (`LightmapGI` cannot bake
// `MultiMesh`). Under those four constraints the lighting pass has nothing
// left to contribute that this file does not compute itself, so running it
// would be a per-fragment light loop paid for a result thrown away. `sun` is
// the scene's DirectionalLight3D direction, pushed in as a uniform; the light
// node still exists and still lights the glass chrome, which IS shaded.
//
// NOTHING IS OUTLINED AND NOTHING IS RIMMED. Enlarged gameplay frames of the
// anchor carry no outline on the environment at all, and the rim visible in
// the store shots was found to be marketing compositing on a cut-out figure —
// #207 records it UNSOURCED and declines it. A rim here would also be the one
// cue that survives on EVERY up-facing surface equally, which is the failure
// this whole design is repairing, not a repair for it.
//
// The twin file carries the same ramp, the same value lock and the same grade
// read, deliberately duplicated rather than shared through a .gdshaderinc:
// the two pipelines are meant to diverge and a third file would suggest they
// should not. If you change `ramp()` here, change it there in the same edit —
// a ramp that drifts between ground and prop re-opens the silhouette failure.

// ── the key ───────────────────────────────────────────────────────────────
uniform vec3 sun = vec3(-0.35, 0.78, 0.52);  // direction TO the sun, world

// How many steps the ramp quantises N·L into. 3 or 4 in production; the probe
// drives it far higher to obtain a smooth control frame. No hint_range, so
// that control is not silently clamped away.
uniform int bands = 3;

// THE PER-ACT TINT LIVES HERE AND NOWHERE ELSE (#207 repair 5). It is applied
// to the two ramp endpoints, never multiplied into albedo: albedo tinting
// drags stone, bark and ash toward one hue and the map becomes a monochrome
// maquette, which is the exact inverse of the measured anchor rule that hue
// rotates 150° → 210° → 264° while value and saturation hold.
uniform vec3 band_shade : source_color = vec3(0.14, 0.16, 0.28);
uniform vec3 band_key : source_color = vec3(0.96, 0.88, 0.72);

// ── the grade ─────────────────────────────────────────────────────────────
// One top-down texture per act, sampled by world XZ, carrying three jobs at
// once (#207 repair 2):
//   .rgb  the corridor — bright and desaturated against a dark saturated
//         surround — and the aerial-perspective ramp along the journey axis.
//   .a    contact darkening under every prop. This is the ONLY mechanism in
//         the whole design that can see a neighbour, so it is standing in for
//         the cast shadow the renderer does not have.
// grade_rect is the act's world footprint: xy = min corner, zw = size.
uniform sampler2D grade : filter_linear, repeat_disable, source_color;
uniform vec4 grade_rect = vec4(-64.0, -64.0, 128.0, 128.0);
uniform float contact = 0.55;   // how far grade.a pushes N·L down the ramp

// ── the surface ───────────────────────────────────────────────────────────
uniform sampler2D surface_tex : filter_linear_mipmap, repeat_enable;

// ZOOM IS A STOP, NOT A DIAL (#207 repair 6). The index is an int on purpose:
// a float `tex_scale` driven from a continuous zoom makes the pattern crawl
// across every surface at a different rate and the world reads as a liquid.
// An int cannot be lerped. The stops are 2x apart so a change lands exactly
// on a mip level and swaps rather than resamples.
const float TEX_STOPS[4] = {0.035, 0.070, 0.140, 0.280};
uniform int tex_stop = 1;

// THE GROUND↔PROP VALUE GAP, MADE ENFORCEABLE (#207 repair 8). The anchor
// measures its bright stage at V 0.68 and its dark masses at V 0.35, in sRGB;
// those are 0.420 and 0.100 linear, which is the space this runs in, and the
// ground is the BRIGHT half — props are the dark masses cut into the stage.
//
// The gap is rescued from texture authoring by pinning the tile's MEAN, not
// each fragment: `tex_mean` is the tile's own measured mean luminance and the
// albedo is scaled so its mean lands exactly on `surface_value`. Every bit of
// the tile's contrast survives — which a per-fragment lock would have eaten,
// taking the cel bands with it — and the gate becomes a subtraction of two
// uniforms. `tex_mean` costs nothing to obtain: #207 repair 7's de-light gate
// already downsamples every tile to 8x8 to check its luminance spread, and
// the mean falls out of that same pass.
uniform float surface_value = 0.420;
uniform float tex_mean = 0.5;

// Neither shader uses heightmap/parallax relief, and neither may: triplanar
// silently disables it on the same material — `BaseMaterial3D` documents that
// `heightmap_enabled` is ignored — so relief that the prop shader cannot have
// must not become something the ground leans on either, or the two surfaces
// separate for the wrong reason.

varying vec3 world_pos;
varying vec3 world_n;


// Quantise N·L, then use it to MIX THE BAND COLOURS. The lowest band lands on
// band_shade exactly and the highest on band_key exactly whatever `bands` is,
// so changing the step count re-spaces the ramp without moving its ends.
vec3 ramp(float nl) {
	float n = float(max(bands, 2));
	float q = min(floor(clamp(nl, 0.0, 1.0) * n), n - 1.0) / (n - 1.0);
	return mix(band_shade, band_key, q);
}


void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_n = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}


void fragment() {
	float s = TEX_STOPS[clamp(tex_stop, 0, 3)];
	vec3 albedo = texture(surface_tex, world_pos.xz * s).rgb
		* (surface_value / max(tex_mean, 1e-4));
	vec4 g = texture(grade, (world_pos.xz - grade_rect.xy) / grade_rect.zw);

	// Half-lambert, not clamped lambert. Unshaded means there is no ambient
	// term anywhere, so max(dot, 0.0) would collapse the entire away-facing
	// hemisphere into one dead black — a slope turned away from the key would
	// lose its shape completely instead of sitting in the lowest band.
	float nl = dot(normalize(world_n), normalize(sun)) * 0.5 + 0.5;

	// Contact darkening enters BEFORE the quantiser, not as a multiply after
	// it. Multiplying the final colour lays grey dirt over the surface; pushing
	// N·L down the ramp drops the fragment into the act's own shadow band, so
	// the contact shadow arrives as light of a colour rather than as a stain,
	// and it arrives with the hard edge a cel shadow is supposed to have.
	nl -= (1.0 - g.a) * contact;

	// The grade multiplies last, so it does spatial work on top of a surface
	// whose value is already settled. Ground and prop at the same XZ take the
	// same multiplier, which is what carries the gap intact through the
	// corridor and out along the aerial ramp.
	ALBEDO = albedo * ramp(nl) * g.rgb;
}
