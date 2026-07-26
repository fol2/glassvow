class_name EnemyView
extends Control
## One enemy as an ACTOR, not a placard: the painted creature standing at its
## own size, chrome hanging free above and below it, and — when it breaks — real
## glass.
##
## The contract this view keeps (benchmark: roguecardv2 src/ui/combat.js:600,
## styles.css:757) is that **this Control's rect IS the art box, and its bottom
## edge IS the creature's feet**. Nothing is drawn inside a panel. Sizing is the
## benchmark's own `tierSizes[tier] * scale`, read from
## assets/art/enemies/char-meta.json — 115px (sporeling) to 1120px (leviathan).
##
## THE GLASS IS ACTUALLY 3D. The body is a lit quad inside a SubViewport with
## its own World3D — the same trick card_view.gd uses for card stock — and the
## cracks are real extruded Voronoi shards with a refracting, clearcoated glass
## material, lit by real lights against a real sky. On death the vessel is
## swapped, in ONE frame, for pieces of ITSELF — opaque shards each carrying the
## patch of painting it covered — which tumble under real gravity, cool, and
## crumble to embers. The web benchmark had to fake every one of those: it
## hand-rolled ballistics in JS, baked crack normals to a 192px canvas, and
## needed an opaque back-buffer pass to get transmission at all
## (docs/glass-crack-rendering.md). Here the engine does it.
##
## Renders from explicit sync calls / event fields — never reads combat state
## directly (the sequencer contract). Targeting is drop-based (the hand's drag
## machine hit-tests get_global_rect(), which is why the rect is the art box).

## Foes and heroes are the same animal — a painting standing at its own size on
## the ground line — so one actor serves both and the art id decides the folder.
const ART_DIRS: Array[String] = [
	"res://assets/art/enemies/%s.png", "res://assets/art/heroes/%s.png",
]
const META_PATH: String = "res://assets/art/enemies/char-meta.json"
const WARD_ICON: Texture2D = preload("res://assets/art/ui/ward.png")

## Chrome geometry (benchmark styles.css: .hpbar-wrap width 150, .cplate gap 6,
## .top-chrome bottom calc(100% + 8px)).
const PLATE_W: float = 150.0
const PLATE_GAP: float = 8.0
const CROWN_GAP: float = 8.0
const WARD_ICON_PX: float = 20.0

## 1 px of art box = 0.01 world units, so a 176px creature stands 1.76m tall and
## the physics engine's own gravity is already in the right ballpark.
const UNIT: float = 0.01
## Head-room around the box for shards to fly into before the viewport clips.
const PAD_FRAC: float = 0.38
const FOV_DEG: float = 28.0
## Glass plate thickness as a fraction of the box — thin, but NOT zero: thickness
## is what makes a shard catch a highlight on its edge and refract at all.
const GLASS_THICK: float = 0.035
const MAX_SITES: int = 32
const VP_MAX: int = 2048

## Being struck (benchmark `choreoHit` / `hurtFlash`). The displacement is the
## benchmark's own 9 px, in the actor's own pixels rather than as a fraction of the
## box — which means a sporeling is knocked 8% of its width sideways and a
## leviathan barely twitches. That began as a CSS convenience, but it reads as
## mass, so it is kept; scale it by the box if a giant ever needs to flinch harder.
const KICK_PX: float = 9.0
const SQUASH: float = 0.03            ## scale(.97, 1.03) at the peak
const HIT_TIME: float = 0.3           ## the whole recoil, cubic-bezier(.22,1,.36,1)
const FLARE_RISE: float = 0.09        ## hurtFlash peaks at 30% of its 0.3s
## An incidental hit — poison, burn, thorns, self-damage — never gets the shove or
## the squash, only `hurtFlash`'s own smaller two-phase wobble: +7 px then -5 px,
## expressed against the 9 px kick so one constant governs the scale of all of it.
const NUDGE_OUT: float = 7.0 / KICK_PX
const NUDGE_BACK: float = -5.0 / KICK_PX

## How hard the struck flash reads. Awaiting a decision, so it is a static the lab
## can sweep (`--flare=N`) rather than a number buried in the shader.
static var flare_gain: float = 1.0

## The stage renders at this multiple of the box. At 1.0 a 176px creature is a
## 176px render being upscaled by the window's own content scale (and again by
## the bench's zoom), which is exactly the softness the first 3D pass had.
##
## **2.0, down from 2.5** — the one memory concession this view makes, worth −20%
## of a 310 MB four-actor stage (docs/actor-stage-frame-budget.md). Stage pixels
## go as the square of this, so it is the cheapest place to buy memory back.
## Judged at 1:1 against MSAA in the lab: dropping it coarsens the lit lip along a
## shard's edge but the lip stays lit, and 1.5 was too soft on the paintings.
static var oversample: float = 2.0

## Anti-aliasing on the actor stage — the same memory saving as `oversample`
## (4x → 2x is −21% against that knob's −20%) for a much worse price, which is why
## it is NOT the one that moved.
##
## MSAA is what makes a shard's edge *lit*; `oversample` only makes it *fine*. The
## side band is a sub-pixel sliver, so its specular highlight lives or dies on
## sub-pixel coverage: at 2x the continuous bright lip breaks into a dim broken
## line and the piece stops reading as glass at all — see
## docs/solutions/design-patterns/procedural-glass-reads-off-its-edges.md. The
## aggregate difference is small (RMSE 0.005) because the affected area is a few
## hundred pixels; those are the load-bearing ones.
##
## A static, like `oversample`, so a lab can compare settings without editing the
## file it is judging.
static var msaa: Viewport.MSAA = Viewport.MSAA_4X

var idx: int = 0
## Placement offsets for whoever puts this actor on the battlefield. Feet are
## this box's bottom edge (benchmark bfEnemyFootX / bfEnemyFootY).
var foot: Vector2 = Vector2.ZERO
var art_size: float = 0.0
## Which side this actor fights for, and how big it is — one field, because
## char-meta already models a hero as a size class (`tierSizes.hero` = 285)
## alongside normal, elite and boss. Nothing has to be passed in: the art id
## resolves the tier the same way it already resolves the box and the folder.
## An actor with no painting falls back to the gem, which is a foe's avatar.
var tier: String = "normal"

var _hue: float = 210.0
var _max_hp: int = 1
var _intent: IntentChip
var _gem: GlassGem
var _name_label: Label
var _hp_bar: ProgressBar
var _hp_label: Label
var _facets: FacetPips
var _ward_chip: PanelContainer
var _ward: Label
var _ward_icon: TextureRect
var _statuses: StatusRow
var _plate: VBoxContainer
var _dead: bool = false
## The recoil, signed and in units of KICK_PX — tweened, then composed into the
## idle by _process. Positive is away from the hero, which is where a foe is
## knocked; a hero is knocked the other way (see _away).
var _hit: float = 0.0
var _hit_squash: float = 0.0
var _hit_tween: Tween = null
var _flare_tween: Tween = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# --- the 3D stage
var _stage: SubViewport = null
var _display: TextureRect = null
var _quad: MeshInstance3D = null
var _body_mat: ShaderMaterial = null
var _vessel: Node3D = null
var _glass_root: Node3D = null
var _breathe: float = 1.0
var _phase: float = 0.0
var _shards: Array[Node3D] = []
var _key: DirectionalLight3D = null
var _rim: OmniLight3D = null
var _fire: OmniLight3D = null
var _env: Environment = null
var _sites: PackedVector2Array = PackedVector2Array()
var _span: float = 0.0          # padded box, in px
var _box_u: float = 0.0         # box HEIGHT, in world units
## Box WIDTH. The art box is square (the benchmark's hit rect) but the painting
## inside it is `contain`-fitted, and 6 of 27 foes plus both heroes are not
## square — drawn on a square quad they stretch. Fit by height, narrow by aspect.
var _quad_w: float = 0.0
var _shadow: MeshInstance3D = null
var _shadow_mat: ShaderMaterial = null
## Where the painting actually touches the ground, read off its own alpha:
## u across the quad, and the lift of the lowest opaque pixel above the box
## bottom (a floating creature casts a smaller, fainter, softer shadow).
var _contact_u: float = 0.5
var _lift: float = 0.0
var _shadow_opacity: float = 0.55
var _ignite: float = 0.0
## Glass reach past each crack site, as a fraction of the box — the benchmark's
## GLASS_AREA. Under 1.0 the body is mostly bare, which is the point: glass
## exists ONLY where the creature is broken.
var _glass_area: float = 0.45
var _glass_mat: ShaderMaterial = null
var _shard_shader: Shader = null
var _debris: Node3D = null
var _cam: Camera3D = null
var _shake: float = 0.0
var _art_img: Image = null

static var _meta: Dictionary = {}
static var _fx_cache: Dictionary = {}


## The body: a flat plate that takes REAL light. The painting has no normal map,
## so one is derived from its own luminance gradient in the fragment stage —
## every leaded seam and lit pane becomes relief the lamps can rake across. The
## bright panes also emit, because in this world the creature IS a lantern.
const BODY_SHADER: String = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley,
	specular_schlick_ggx;

uniform sampler2D body_tex : source_color, filter_linear_mipmap;
uniform float bump = 3.5;
uniform float emission_gain = 0.85;
uniform float target_lit = 0.0;
// Struck: 0 at rest, 1 at the peak of the flash. See take_hit().
uniform float flare = 0.0;
// How hard that peak hits. A knob rather than a constant because the CSS number
// does not transfer (see the flare block) so it has to be judged by eye.
uniform float flare_gain = 1.0;
// The vessel leaving. A custom shader that writes ALPHA overrides
// GeometryInstance3D.transparency outright, so the fade has to be a uniform.
uniform float fade = 1.0;

float luma(vec2 uv) {
	vec4 c = texture(body_tex, uv);
	return dot(c.rgb, vec3(0.299, 0.587, 0.114)) * c.a;
}

void fragment() {
	// NO uv warp here. The idle motion is a transform on the vessel node that
	// carries the glass with it — warping the texture instead slid the creature
	// out from under its own cracks, which is what "the crack does not align"
	// looks like.
	vec2 uv = UV;
	vec4 c = texture(body_tex, uv);
	ALBEDO = c.rgb;
	ALPHA = smoothstep(0.12, 0.45, c.a) * fade;

	vec2 ts = 1.0 / vec2(textureSize(body_tex, 0));
	float l = luma(uv);
	float lx = luma(uv + vec2(ts.x, 0.0));
	float ly = luma(uv + vec2(0.0, ts.y));
	// UV y runs down, world y runs up — flip or every lamp lights from below.
	NORMAL_MAP = normalize(vec3((l - lx) * bump, (ly - l) * bump, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;

	EMISSION = c.rgb * pow(l, 3.2) * emission_gain;
	ROUGHNESS = 0.78;
	METALLIC = 0.0;
	// Low specular: a painted body is not varnished, and a broad highlight over
	// the whole silhouette is the other half of the fog.
	SPECULAR = 0.18;

	// ONE dilated-alpha ring, two consumers: the targeting rim and the struck
	// flare's glow. Same silhouette, different colour and gain — the six taps are
	// the expensive part and there is no reason to pay for them twice.
	float rim = 0.0;
	if (target_lit > 0.0 || flare > 0.0) {
		vec2 px = ts * 9.0;
		float ring = 0.0;
		ring = max(ring, texture(body_tex, uv + vec2(px.x, 0.0)).a);
		ring = max(ring, texture(body_tex, uv - vec2(px.x, 0.0)).a);
		ring = max(ring, texture(body_tex, uv + vec2(0.0, px.y)).a);
		ring = max(ring, texture(body_tex, uv - vec2(0.0, px.y)).a);
		ring = max(ring, texture(body_tex, uv + px * 0.72).a);
		ring = max(ring, texture(body_tex, uv - px * 0.72).a);
		rim = clamp(ring - c.a, 0.0, 1.0);
	}
	if (target_lit > 0.0) {
		EMISSION += rim * target_lit * vec3(0.89, 0.84, 0.98) * 3.0;
		ALPHA = max(ALPHA, rim * target_lit);
	}
	// Struck. The benchmark's `hurtFlash` peaks at brightness 2.6 with
	// saturate .4 and an 18px white halo, so the glass goes briefly white-hot and
	// the silhouette carries a rim of it. Desaturating FIRST is what stops a red
	// creature simply going redder — the flash has to read as light, not as paint.
	// Struck. Two rejected attempts are worth recording, because both were the
	// CSS instruction taken literally:
	//   * `brightness(2.6)` as an EMISSION term over the whole body washed the
	//     creature out completely — a lit shader that already emits is not a
	//     composited sprite, so the number does not transfer.
	//   * the 18px halo as `ALPHA = max(ALPHA, rim)` widened the SILHOUETTE, which
	//     reads as a sticker outline or a selection highlight, not as a blow. A
	//     glow must sit over the body, never extend it.
	// What is left flashes the glass the creature is already made of: the lit panes
	// go white-hot, the dark armour between them does not, and the halo is a hint.
	// A third rejected attempt: `saturate(.4)`, ported as a 0.35 mix toward grey,
	// DOMINATED. On a warm creature under low light the desaturation lands before
	// the added light does, so frames 0-2 read as the beast going briefly pale and
	// frames 3-5 as it recovering its colour — the opposite event. CSS gets away
	// with it because `brightness(2.6)` overwhelms the desaturation; here the
	// light has to lead and the grey is a whisper on top of it.
	if (flare > 0.0) {
		float f = flare * flare_gain;
		// pow(l, 1.4) rather than the body's own 3.2: the flash reaches further
		// down the tonal range than the resting lantern glow, so a mid-tone pane
		// lights up too — but it is still keyed to the painting, so the flash has
		// the creature's own shape rather than being a wash over its box.
		vec3 lit = ALBEDO * pow(l, 1.4) * f * 4.0;
		float g = dot(ALBEDO, vec3(0.299, 0.587, 0.114));
		ALBEDO = mix(ALBEDO, vec3(g), 0.10 * f) * (1.0 + 0.8 * f);
		EMISSION += lit + rim * f * 0.3;
	}
}
"""


## Real glass: the view ray is refracted through the shard's own normal and used
## to sample what has already been drawn in this viewport — which is the body.
## So the creature genuinely bends behind its own fractures, with a Fresnel edge
## that whitens at grazing angles and a warm bloom as the vessel ignites.
##
## StandardMaterial3D's `refraction_enabled` cannot do this job here: it forces
## ALPHA to 1 and reads a screen that, inside a transparent SubViewport, is
## empty — which is why the first pass came out as grey pebbles.
const GLASS_SHADER: String = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley,
	specular_schlick_ggx;

// The shard shows THE CREATURE, refracted through its own thickness. That is
// the whole point of the shatter: the benchmark snapshots body+fire+glass and
// breaks the capture, so every flying piece carries the part of the monster it
// covered. A blank glass chip flying off a still-intact mob reads as debris.
uniform sampler2D body_tex : source_color, filter_linear_mipmap;
uniform float ior = 1.45;
uniform float bend = 0.055;     // how far the shard displaces what it holds
uniform float tint_a = 0.55;
uniform float rough = 0.12;
uniform float ignite = 0.0;
uniform vec3 tint = vec3(0.86, 0.93, 1.0);
uniform vec3 warm = vec3(1.0, 0.62, 0.26);

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	vec3 r = refract(-v, n, 1.0 / ior);
	// UV arrives already in body space (see _prism), so the shard samples the
	// exact pixels it sits over — aligned by construction, flying or not.
	vec2 uv = UV + r.xy * bend;
	vec4 c = texture(body_tex, uv);
	float f = pow(1.0 - clamp(dot(n, v), 0.0, 1.0), 3.0);
	ALBEDO = mix(c.rgb * tint, vec3(1.0), f * 0.45);
	// Opaque where it holds the creature, glassy at its edges, and never so
	// transparent that a flying piece disappears.
	ALPHA = clamp(max(c.a, 0.10) * tint_a + f * 0.6 + ignite * 0.1, 0.0, 1.0);
	ROUGHNESS = rough;
	METALLIC = 0.0;
	SPECULAR = 0.5;
	// The fire wells up through the FRACTURES: Fresnel is high on the side band
	// and the rim, near zero across the face.
	EMISSION = warm * ignite * pow(f, 1.4) * 5.0 + c.rgb * ignite * 0.35;
}
"""


## Death debris is NOT the overlay glass. A flying shard must BE a piece of the
## creature — cap faces carry the painting at full strength (same alpha curve as
## the body, so the union of shards at the handoff frame IS the body), fracture
## faces run molten and cool, and the whole piece finally crumbles to nothing
## through a blocky hash so debris never ghost-fades or litters the stage.
const SHARD_SHADER: String = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley,
	specular_schlick_ggx;

uniform sampler2D body_tex : source_color, filter_linear_mipmap;
uniform float heat = 1.0;      // molten fracture edges + inner glow, cools to 0
uniform float dissolve = 0.0;  // 0 whole -> 1 burned away to nothing

const vec3 WARM = vec3(1.0, 0.60, 0.24);

void fragment() {
	vec4 c = texture(body_tex, UV);
	// _prism colors the side band red and the caps black: COLOR.r is literally
	// "this face is a fracture surface".
	float edge = COLOR.r;
	// Blocky hash over BODY uv: the piece crumbles away cell by cell instead of
	// ghost-fading, and neighbouring shards never vanish in sync.
	float h = fract(sin(dot(floor(UV * 90.0), vec2(12.9898, 78.233))) * 43758.5453);
	float gone = step(h, dissolve);
	float brink = (1.0 - smoothstep(0.0, 0.2, h - dissolve)) * step(0.001, dissolve);
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	float f = pow(1.0 - clamp(dot(n, v), 0.0, 1.0), 3.0);
	// A cap is THE PAINTING — these are pieces of the mob, not glass in front of
	// it. A fracture face is molten while hot, dark cooled glass after. Heat is
	// seasoning, never paint: push the glow past a whisper and every piece is
	// the same white-hot popcorn and the creature is gone AGAIN, just hotter.
	ALBEDO = mix(c.rgb, WARM * 0.5, edge * (0.2 + 0.3 * heat));
	float amask = smoothstep(0.05, 0.30, c.a);
	ALPHA = mix(smoothstep(0.12, 0.45, c.a), amask, edge) * (1.0 - gone);
	ROUGHNESS = mix(0.55, 0.9, edge);
	METALLIC = 0.0;
	SPECULAR = 0.3;
	// The caps keep the body's own lantern glow (same pow(luma) curve as
	// BODY_SHADER) — a falling piece stays lit the way it was lit standing,
	// which is most of what makes it recognisably the same creature.
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114)) * c.a;
	EMISSION = WARM * (edge * heat * 0.9 + brink * 1.1 + f * heat * 0.3)
		+ c.rgb * (pow(l, 3.2) * 0.85 * (1.0 - edge) + heat * 0.25);
}
"""


static func meta(art_id: StringName) -> Dictionary:
	if _meta.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(META_PATH))
		if typeof(raw) == TYPE_DICTIONARY:
			_meta = raw
		else:
			push_warning("enemy view: %s unreadable — actors fall back to the gem"
				% META_PATH)
			_meta = {"chars": {}, "tierSizes": {}}
	var chars: Dictionary = _meta.get("chars", {})
	var entry: Dictionary = chars.get(String(art_id), {})
	return entry


## The benchmark's own size formula: tierSizes[tier] * scale (bfEnemySize).
static func art_box(art_id: StringName) -> float:
	var entry: Dictionary = meta(art_id)
	if entry.is_empty():
		return 0.0
	var tiers: Dictionary = _meta.get("tierSizes", {})
	var base: float = tiers.get(str(entry.get("tier", "normal")), 185)
	var scale: float = entry.get("scale", 1.0)
	return base * scale


## Editor seam. char-meta.json is presentation tuning data, not content and not
## a fixture, so the bench edits it in place — the same job the benchmark's
## ?charedit=1 does by rewriting src/char-meta.js. res:// is writable in a debug
## run; an exported build would have to keep its overrides in user://.
static func set_meta_value(art_id: StringName, key: String, value: Variant) -> void:
	meta(art_id)  # force the load before anyone mutates it
	var chars: Dictionary = _meta.get("chars", {})
	var entry: Dictionary = chars.get(String(art_id), {})
	entry[key] = value
	chars[String(art_id)] = entry
	_meta["chars"] = chars


static func save_meta() -> bool:
	var f: FileAccess = FileAccess.open(META_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("enemy view: cannot write %s" % META_PATH)
		return false
	f.store_string(JSON.stringify(_meta, "  "))
	f.close()
	return true


## `art_id` stays optional: a caller that does not pass one gets exactly the
## avatar it got before the paintings landed, because GlassGem is the missing-art
## fallback here just as enemySvg() is in the benchmark (assets.js:7).
func _init(enemy_idx: int, display_name: String, hue: float = 210.0,
		art_id: StringName = &"") -> void:
	idx = enemy_idx
	_hue = hue
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex: Texture2D = null
	if art_id != &"":
		for pattern: String in ART_DIRS:
			var path: String = pattern % art_id
			if ResourceLoader.exists(path):
				tex = load(path)
				break
		if tex == null:
			push_warning("enemy view: no painting for %s" % art_id)

	if tex != null:
		var entry: Dictionary = meta(art_id)
		tier = str(entry.get("tier", "normal"))
		art_size = art_box(art_id)
		if art_size <= 0.0:
			art_size = 185.0
		var fx: float = entry.get("footX", 0.0)
		var fy: float = entry.get("footY", 0.0)
		foot = Vector2(fx, fy)
		custom_minimum_size = Vector2(art_size, art_size)
		size = custom_minimum_size
		_rng.seed = hash(String(art_id)) + enemy_idx
		_build_stage(tex, enemy_idx)
	else:
		# No painting: the procedural gem, at the box it has always used. This is
		# also the world map's emblem widget, so it is left exactly alone.
		custom_minimum_size = Vector2(150, 92)
		size = custom_minimum_size
		art_size = 92.0
		_gem = GlassGem.new()
		_gem.set_anchors_preset(Control.PRESET_FULL_RECT)
		_gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_gem.set_state(_hue, 1.0, false)
		add_child(_gem)

	_build_chrome(display_name)


# ---------------------------------------------------------------- the 3D stage

func _build_stage(tex: Texture2D, enemy_idx: int) -> void:
	_span = art_size * (1.0 + 2.0 * PAD_FRAC)
	_box_u = art_size * UNIT
	var aspect: float = 1.0
	if tex.get_height() > 0:
		aspect = float(tex.get_width()) / float(tex.get_height())
	_quad_w = _box_u * aspect
	_read_contact(tex)

	_stage = SubViewport.new()
	var vp_px: int = mini(int(_span * oversample), VP_MAX)
	_stage.size = Vector2i(vp_px, vp_px)
	_stage.own_world_3d = true
	_stage.transparent_bg = true
	_stage.msaa_3d = msaa
	_stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_stage)

	# A real sky, used ONLY as light. background_mode stays CLEAR_COLOR so the
	# viewport keeps its alpha, while ambient and reflections still come off the
	# sky's radiance map — that is what gives the shards something to mirror.
	_env = Environment.new()
	_env.background_mode = Environment.BG_CLEAR_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_env.ambient_light_energy = 0.22
	var sky: Sky = Sky.new()
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	# The night-lantern key the rest of the screen is lit by: deep indigo dome,
	# ember bounce off the ground.
	sky_mat.sky_top_color = Color(0.05, 0.07, 0.16)
	sky_mat.sky_horizon_color = Color(0.16, 0.18, 0.30)
	sky_mat.ground_bottom_color = Color(0.16, 0.09, 0.05)
	sky_mat.ground_horizon_color = Color(0.22, 0.14, 0.08)
	sky.sky_material = sky_mat
	_env.sky = sky
	# LINEAR, not ACES: the filmic curve lifts blacks and desaturates, which on a
	# painting that is already 80% near-black reads as fog over the whole mob.
	_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = _env
	_stage.add_child(world_env)

	# Key: the lantern above and to the left, warm.
	_key = DirectionalLight3D.new()
	_key.light_color = Color(1.0, 0.86, 0.68)
	_key.light_energy = 1.5
	_key.rotation_degrees = Vector3(-38.0, -32.0, 0.0)
	_stage.add_child(_key)
	# Rim: cold glass-blue from behind, so the silhouette separates from night.
	_rim = OmniLight3D.new()
	_rim.light_color = GlassStyle.GLASS
	_rim.light_energy = 1.8
	_rim.omni_range = _box_u * 4.0
	_rim.position = Vector3(_box_u * 0.7, _box_u * 0.5, -_box_u * 0.9)
	_stage.add_child(_rim)
	# Fire: dark until the vessel ignites, then it is the light inside the glass.
	_fire = OmniLight3D.new()
	_fire.light_color = GlassStyle.EMBER
	_fire.light_energy = 0.0
	_fire.omni_range = _box_u * 3.0
	_fire.position = Vector3(0.0, 0.0, -_box_u * 0.25)
	_stage.add_child(_fire)

	# Body and glass share ONE node. The idle motion is this node's transform, so
	# a crack can never drift off the creature it was scored into.
	_vessel = Node3D.new()
	_stage.add_child(_vessel)
	_phase = float(enemy_idx) * 1.7

	_quad = MeshInstance3D.new()
	var qm: QuadMesh = QuadMesh.new()
	qm.size = Vector2(_quad_w, _box_u)
	_quad.mesh = qm
	var sh: Shader = Shader.new()
	sh.code = BODY_SHADER
	_body_mat = ShaderMaterial.new()
	_body_mat.shader = sh
	_body_mat.set_shader_parameter("body_tex", tex)
	_body_mat.set_shader_parameter("flare_gain", flare_gain)
	_body_mat.render_priority = -1   # drawn before the glass
	_quad.set_surface_override_material(0, _body_mat)
	_vessel.add_child(_quad)

	_glass_root = Node3D.new()
	_vessel.add_child(_glass_root)

	# Outside the vessel: the ground does not breathe with the creature.
	_build_shadow(tex)

	# Ground for the shards to land on, at the creature's own feet.
	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(_box_u * 6.0, _box_u * 0.1, _box_u * 6.0)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(0.0, -_box_u * 0.5 - _box_u * 0.05, 0.0)
	floor_body.physics_material_override = _bounce()
	_stage.add_child(floor_body)

	_cam = Camera3D.new()
	_cam.fov = FOV_DEG
	var dist: float = (_span * UNIT) * 0.5 / tan(deg_to_rad(FOV_DEG * 0.5))
	_cam.position = Vector3(0.0, 0.0, dist)
	_cam.near = dist * 0.25
	_cam.far = dist * 3.0
	_stage.add_child(_cam)

	_display = TextureRect.new()
	_display.texture = _stage.get_texture()
	_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_display.stretch_mode = TextureRect.STRETCH_SCALE
	var pad: float = art_size * PAD_FRAC
	_display.position = Vector2(-pad, -pad)
	_display.size = Vector2(_span, _span)
	_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_display)


## The cast shadow, and the reason it is nine knobs lighter than the benchmark's.
##
## The web shadow is a black copy of the sprite squashed by hand: --sh-sx/sy,
## --sh-skew, --sh-x/y, --sh-blur, --foot-ox/oy, --sh-o, authored per creature
## (styles.css .cast-shadow). Every one of those numbers is a person estimating
## where a light they do not have would throw the silhouette, because CSS cannot
## project. Here there IS a light, so the shape is derived: the lean and length
## come from the key's direction, the contact point from the painting's own
## alpha, the softening from distance off the ground. What is left to author is
## opacity.
const SHADOW_SHADER: String = """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

uniform sampler2D body_tex : source_color, filter_linear_mipmap;
uniform float opacity = 0.55;
uniform float softness = 1.0;

void fragment() {
	// UV.y 1 is the feet; the far end of the cast is the head. A real contact
	// shadow is sharp where the body meets the ground and diffuses with
	// distance, which is the whole job the authored blur radius was doing.
	float far = 1.0 - UV.y;
	float r = (0.003 + 0.035 * far) * softness;
	float a = 0.0;
	for (int i = -1; i <= 1; i++) {
		for (int j = -1; j <= 1; j++) {
			a += texture(body_tex, UV + vec2(float(i), float(j)) * r).a;
		}
	}
	a /= 9.0;
	ALBEDO = vec3(0.0);
	ALPHA = smoothstep(0.04, 0.55, a) * opacity * (1.0 - far * 0.5);
}
"""

## How far the ground plane is tipped from the picture plane. cos(78°) = 0.208,
## near the benchmark's --sh-sy default of 0.24 — the same foreshortening,
## except here it is a plane the light projects onto rather than a scale factor.
const GROUND_TILT_DEG: float = 78.0
## How far the cast may run, in body heights. The projection alone would put the
## key's 38° pitch at 1.6 body heights, which is true and looks wrong: in a
## side-on view a long cast reads as the creature hovering over its own shadow.
## Clamped to a ground POOL that leans with the light instead of a dramatic
## throw — the benchmark lands in the same place with sx 1.0 / sy 0.24.
const CAST_MIN: float = 0.6
const CAST_MAX: float = 1.15


## Read the contact point off the painting instead of authoring --foot-ox/oy:
## the lowest opaque row is where the creature meets the ground, and the
## horizontal centroid of that band is where its weight sits. Downsampled first
## — a contact point does not need 1024 rows, and a per-pixel scan of the full
## image in GDScript would cost more than the whole stage build.
func _read_contact(tex: Texture2D) -> void:
	var img: Image = tex.get_image()
	if img == null:
		return
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.resize(64, 64, Image.INTERPOLATE_BILINEAR)
	var bottom: int = -1
	for y: int in range(63, -1, -1):
		for x: int in range(64):
			if img.get_pixel(x, y).a > 0.15:
				bottom = y
				break
		if bottom >= 0:
			break
	if bottom < 0:
		return
	var sum: float = 0.0
	var weight: float = 0.0
	for y: int in range(maxi(bottom - 4, 0), bottom + 1):
		for x: int in range(64):
			var a: float = img.get_pixel(x, y).a
			sum += float(x) * a
			weight += a
	if weight > 0.0:
		_contact_u = (sum / weight + 0.5) / 64.0
	_lift = (1.0 - (float(bottom) + 1.0) / 64.0) * _box_u


func _build_shadow(tex: Texture2D) -> void:
	_shadow = MeshInstance3D.new()
	var qm: QuadMesh = QuadMesh.new()
	qm.size = Vector2(_quad_w, _box_u)
	# Origin on the BOTTOM edge, so the quad tips away about the contact line
	# rather than sinking half of itself through the floor.
	qm.center_offset = Vector3(0.0, _box_u * 0.5, 0.0)
	_shadow.mesh = qm
	var sh: Shader = Shader.new()
	sh.code = SHADOW_SHADER
	_shadow_mat = ShaderMaterial.new()
	_shadow_mat.shader = sh
	_shadow_mat.render_priority = -2   # under the body (-1) and the glass (1)
	_shadow_mat.set_shader_parameter("body_tex", tex)
	_shadow.set_surface_override_material(0, _shadow_mat)
	_shadow.position = Vector3(
		(_contact_u - 0.5) * _quad_w, -_box_u * 0.5 + _lift * 0.15, 0.0)
	_stage.add_child(_shadow)
	_update_shadow()


## Project the silhouette along the key light. This is the entire shadow model:
## run per unit height gives the lean, its magnitude gives the length, and the
## ground tilt does the foreshortening. Swing the key and the shadow swings —
## which the authored version could never do at any number of knobs.
func _update_shadow() -> void:
	if _shadow == null or _key == null:
		return
	var l: Vector3 = -_key.transform.basis.z
	# A light at or below the horizon would throw the shadow to infinity.
	l.y = minf(l.y, -0.12)
	var run: float = clampf(1.0 / -l.y, CAST_MIN, CAST_MAX)
	# Lift is the gap between the lowest painted pixel and the ground line: a
	# creature that floats casts a smaller, fainter, softer shadow, and one
	# standing on the line casts a sharp one. Free, because the alpha knows.
	var f: float = clampf(_lift / maxf(_box_u, 0.0001), 0.0, 0.6)
	var s: float = 1.0 - f * 0.5
	# Shear and shrink in ONE basis. Node3D.scale is DERIVED from the basis, so
	# assigning it after a sheared basis re-orthonormalises and silently throws
	# the shear away — the shadow then stands straight up behind the creature.
	var shear: Basis = Basis.IDENTITY
	shear.x = Vector3(s, 0.0, 0.0)
	shear.y = Vector3(clampf(l.x * run, -1.2, 1.2) * s, run * s, 0.0)
	_shadow.transform.basis = \
		Basis(Vector3.RIGHT, deg_to_rad(-GROUND_TILT_DEG)) * shear
	_shadow_mat.set_shader_parameter("opacity", _shadow_opacity * (1.0 - f * 1.2))
	_shadow_mat.set_shader_parameter("softness", 1.0 + f * 4.0)


static func _bounce(bounce: float = 0.28, friction: float = 0.7) -> PhysicsMaterial:
	var pm: PhysicsMaterial = PhysicsMaterial.new()
	pm.bounce = bounce
	pm.friction = friction
	return pm


## One glass material shared by every shard, so a tuning slider is one write.
func _glass_material() -> ShaderMaterial:
	if _glass_mat != null:
		return _glass_mat
	var sh: Shader = Shader.new()
	sh.code = GLASS_SHADER
	_glass_mat = ShaderMaterial.new()
	_glass_mat.shader = sh
	_glass_mat.render_priority = 1   # after the body
	if _body_mat != null:
		_glass_mat.set_shader_parameter("body_tex",
			_body_mat.get_shader_parameter("body_tex"))
	return _glass_mat


## Idle. A standing creature that never moves reads as a sticker, so the vessel
## leans and swells — as a TRANSFORM, which the glass rides along with. When the
## rite begins the idle hands over to the STRAIN — a rising quiver and swell, the
## vessel failing to contain its own fire — and after the burst the camera
## carries a short shake while the shards own their own motion.
func _process(delta: float) -> void:
	if _cam != null and _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 4.5)
		var kick: float = _box_u * 0.02 * _shake * _shake
		_cam.h_offset = _rng.randf_range(-kick, kick)
		_cam.v_offset = _rng.randf_range(-kick, kick)
	if _vessel == null:
		return
	var t: float = Time.get_ticks_msec() * 0.001 + _phase
	if _dead:
		if _vessel.visible and _ignite > 0.0:
			var q: float = _ignite * _ignite
			var amp: float = _box_u * 0.009 * q
			_vessel.position = Vector3(
				sin(t * 61.0) * amp, sin(t * 47.0) * amp * 0.7, 0.0)
			var s: float = 1.0 + 0.03 * q
			_vessel.scale = Vector3(s, s, 1.0)
		return
	var sw: float = sin(t * 1.05)
	var k: float = 1.0 + _breathe * 0.016 * sw
	# The recoil rides ON the idle rather than being tweened onto the vessel: this
	# function rewrites scale and position every frame, so a Tween aimed at either
	# would be erased before it was ever seen. `_hit` and `_hit_squash` are the
	# tweened values; composing them here is what makes the two coexist.
	_vessel.scale = Vector3(
		k * (1.0 - SQUASH * _hit_squash), k * (1.0 + SQUASH * _hit_squash), 1.0)
	_vessel.rotation.z = _breathe * 0.017 * sin(t * 0.71)
	_vessel.position = Vector3(
		_hit * KICK_PX * UNIT,
		_breathe * _box_u * 0.010 * sin(t * 0.83), 0.0)


# ---------------------------------------------------------------- being struck

## The body is struck.
##
## Two beats, and the benchmark separates them by *source* rather than by amount.
## `hurtFlash` fires on every hit a foe takes — poison included — so the flash
## does not distinguish; the shove does. A direct attack gets `choreoHit`'s full
## shove and squash; poison, burn, thorns and self-damage get only hurtFlash's
## smaller two-phase wobble, because a body recoiling hard from nothing visible
## reads as being punched by an invisible hand.
##
## The two are not stacked. In the benchmark they are two animations on one
## element, both writing `transform` and `filter`, so only one of them was ever
## visible on a direct hit — porting the conflict rather than the result would be
## transcribing a workaround.
##
## `hurtFlash` is a foe's animation there, and a struck hero is shoved without
## flashing, so the flare is withheld from a hero rather than dimmed for one.
func take_hit(direct: bool = true) -> void:
	if _dead:
		return
	if _gem != null:
		_gem_flash()
		return
	if _vessel == null:
		return
	if tier != "hero":
		_flare()
	if direct:
		_shove()
	else:
		_nudge()


## Which way a blow throws this actor. Derived rather than passed, on the same
## reasoning as `tier`: the hero stands left of the foes, so a struck foe is
## thrown right and a struck hero is thrown left.
func _away() -> float:
	return -1.0 if tier == "hero" else 1.0


func _shove() -> void:
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	_hit = _away()
	_hit_squash = 1.0
	# TRANS_QUINT / EASE_OUT is the near-equivalent of the benchmark's
	# cubic-bezier(.22, 1, .36, 1): almost all of the travel spent in the first
	# third, so the blow lands hard and the settle is barely noticed.
	_hit_tween = create_tween().set_parallel(true)
	_hit_tween.tween_property(self, "_hit", 0.0, HIT_TIME) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_hit_tween.tween_property(self, "_hit_squash", 0.0, HIT_TIME) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)


## hurtFlash's own displacement: out, back past centre, settle. No squash — an
## unstruck-looking body that merely twitches is the whole read for a poison tick.
func _nudge() -> void:
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	_hit_squash = 0.0
	var away: float = _away()
	_hit_tween = create_tween()
	_hit_tween.tween_property(self, "_hit", away * NUDGE_OUT, FLARE_RISE) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hit_tween.tween_property(self, "_hit", away * NUDGE_BACK, FLARE_RISE) \
		.set_trans(Tween.TRANS_SINE)
	_hit_tween.tween_property(self, "_hit", 0.0, HIT_TIME - FLARE_RISE * 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Up in 90ms, down over the rest — hurtFlash peaks at 30% of its 0.3s and the
## asymmetry is the point: a flash that faded as slowly as it rose would read as
## the creature glowing rather than as it being hit.
func _flare() -> void:
	if _body_mat == null:
		return
	if _flare_tween != null and _flare_tween.is_valid():
		_flare_tween.kill()
	# SINE / EASE_IN_OUT both ways, which is what interpolating between CSS
	# keyframes actually does. An EASE_OUT rise was tried and it front-loads so
	# hard that the flash was already at 45% on the first frame — the ramp the
	# benchmark spends 90ms on has to be visible as a ramp, or there was no reason
	# to give it 30% of the animation.
	_flare_tween = create_tween()
	_flare_tween.tween_method(_set_flare, 0.0, 1.0, FLARE_RISE) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_flare_tween.tween_method(_set_flare, 1.0, 0.0, HIT_TIME - FLARE_RISE) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _set_flare(v: float) -> void:
	if _body_mat != null:
		_body_mat.set_shader_parameter("flare", v)


## The gem has no body to shove and no shader to flash, so the fallback avatar
## takes the hit as a brightness pulse — the same channel set_targetable uses.
func _gem_flash() -> void:
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate", Color(2.2, 2.0, 2.0, 1.0), FLARE_RISE) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate", Color(1, 1, 1, 1), HIT_TIME - FLARE_RISE) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)


# ---------------------------------------------------------------- the cracks

## Half-plane clip: keep the side of the a|b bisector that belongs to `a`.
## Geometry2D has no half-plane primitive, so the plane arrives as a rectangle
## far larger than the box — the intersection is identical and it is four lines
## of code instead of a clipper.
static func _clip(poly: PackedVector2Array, a: Vector2, b: Vector2,
		big: float) -> PackedVector2Array:
	var mid: Vector2 = (a + b) * 0.5
	var n: Vector2 = (a - b).normalized()
	var t: Vector2 = Vector2(-n.y, n.x)
	var half: PackedVector2Array = PackedVector2Array([
		mid + t * big, mid - t * big, mid - t * big + n * big, mid + t * big + n * big,
	])
	var hit: Array[PackedVector2Array] = Geometry2D.intersect_polygons(poly, half)
	return hit[0] if not hit.is_empty() else PackedVector2Array()


## A circle as a polygon — Geometry2D only intersects polygons, and 20 sides is
## indistinguishable from round at the size a shard is ever drawn.
static func _disc(centre: Vector2, r: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in range(20):
		var a: float = TAU * float(i) / 20.0
		out.append(centre + Vector2(cos(a), sin(a)) * r)
	return out


## Voronoi cells for `sites`, in world units, centred on the quad. With
## `reach` > 0 each cell is bounded to a disc around its own site — without that
## every cell tiles the whole quad and the overlay "glass" becomes an opaque
## pane over the art. reach <= 0 keeps the full tiling, which is exactly what
## the death rite wants: the WHOLE body cut into panes.
func _voronoi(sites: PackedVector2Array, reach: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var hw: float = _quad_w * 0.5
	var hh: float = _box_u * 0.5
	var big: float = _box_u * 8.0
	var box: PackedVector2Array = PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh),
	])
	for i: int in range(sites.size()):
		var cell: PackedVector2Array = box
		for j: int in range(sites.size()):
			if i == j:
				continue
			cell = _clip(cell, sites[i], sites[j], big)
			if cell.is_empty():
				break
		if cell.size() < 3:
			continue
		if reach <= 0.0:
			out.append(cell)
			continue
		var patch: Array[PackedVector2Array] = Geometry2D.intersect_polygons(
			cell, _disc(sites[i], reach))
		if not patch.is_empty() and patch[0].size() >= 3:
			out.append(patch[0])
	return out


## The overlay cells: the crack web the creature carries while it still stands.
func _cells() -> Array[PackedVector2Array]:
	return _voronoi(_sites, _glass_area * minf(_quad_w, _box_u) * 0.5)


## Extrude a cell into a real plate with thickness. Thickness is the point: a
## zero-depth polygon cannot catch a highlight on its edge or bend anything.
##
## `origin` re-centres the vertices while the UVs stay in body space. A debris
## piece MUST be built around its own centroid: the first shatter pass left
## vertices in body coordinates with the RigidBody at the origin, so every
## shard's spin axis was the middle of the CREATURE — they swept arcs instead of
## tumbling, landed on an edge, and stood there like headstones.
##
## Vertex color is the face tag: caps BLACK, side band RED — the shard shader
## reads COLOR.r as "fracture surface" and pours the molten glow only there.
static func _prism(cell: PackedVector2Array, thick: float, box: Vector2,
		origin: Vector2 = Vector2.ZERO) -> ArrayMesh:
	var tri: PackedInt32Array = Geometry2D.triangulate_polygon(cell)
	if tri.is_empty():
		return null
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z: float = thick * 0.5
	st.set_color(Color(0, 0, 0))
	for face: int in range(2):
		var zz: float = z if face == 0 else -z
		var i: int = 0
		while i < tri.size():
			for k: int in range(3):
				var p: Vector2 = cell[tri[i + k]]
				st.set_uv(Vector2(p.x / box.x + 0.5, 0.5 - p.y / box.y))
				st.add_vertex(Vector3(p.x - origin.x, p.y - origin.y, zz))
			i += 3
	# Side band, quad per edge — where the thickness actually shows.
	st.set_color(Color(1, 0, 0))
	for i: int in range(cell.size()):
		var a: Vector2 = cell[i]
		var b: Vector2 = cell[(i + 1) % cell.size()]
		var quad: Array[Vector3] = [
			Vector3(a.x, a.y, z), Vector3(b.x, b.y, z), Vector3(b.x, b.y, -z),
			Vector3(a.x, a.y, z), Vector3(b.x, b.y, -z), Vector3(a.x, a.y, -z),
		]
		for v: Vector3 in quad:
			st.set_uv(Vector2(v.x / box.x + 0.5, 0.5 - v.y / box.y))
			st.add_vertex(v - Vector3(origin.x, origin.y, 0.0))
	st.generate_normals()
	return st.commit()


## Rebuild the shard set from the current sites. Cheap enough to redo on every
## crack: a handful of convex cells and one SurfaceTool pass each.
func _rebuild_glass() -> void:
	if _glass_root == null:
		return
	for c: Node in _glass_root.get_children():
		c.queue_free()
	_shards.clear()
	if _sites.size() < 2:
		return
	var mat: ShaderMaterial = _glass_material()
	var thick: float = _box_u * GLASS_THICK
	for cell: PackedVector2Array in _cells():
		var mesh: ArrayMesh = _prism(cell, thick, Vector2(_quad_w, _box_u))
		if mesh == null:
			continue
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = mesh
		mi.set_surface_override_material(0, mat)
		mi.position = Vector3(0.0, 0.0, thick * 0.6)
		_glass_root.add_child(mi)
		_shards.append(mi)


## Score a crack. `at` is in body UV; the sites drive the Voronoi that becomes
## the shards, exactly as crack sites do in the benchmark — except here they
## become geometry rather than a baked normal map.
func crack(at: Vector2 = Vector2(-1, -1)) -> void:
	if _glass_root == null or _sites.size() >= MAX_SITES:
		return
	var p: Vector2 = at
	if p.x < 0.0:
		p = Vector2(_rng.randf_range(0.2, 0.8), _rng.randf_range(0.2, 0.8))
	# UV (y down, 0..1) into quad-local world units (y up, centred).
	_sites.append(Vector2((p.x - 0.5) * _quad_w, (0.5 - p.y) * _box_u))
	_rebuild_glass()


func reset_glass() -> void:
	_dead = false
	_ignite = 0.0
	_shake = 0.0
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	if _flare_tween != null and _flare_tween.is_valid():
		_flare_tween.kill()
	_hit = 0.0
	_hit_squash = 0.0
	_set_flare(0.0)
	_sites = PackedVector2Array()
	modulate = Color(1, 1, 1, 1)
	if _debris != null:
		if is_instance_valid(_debris):
			_debris.queue_free()
		_debris = null
	if _vessel != null:
		_vessel.visible = true
		_vessel.transform = Transform3D.IDENTITY
	if _cam != null:
		_cam.h_offset = 0.0
		_cam.v_offset = 0.0
	_update_shadow()
	if _glass_mat != null:
		_glass_mat.set_shader_parameter("ignite", 0.0)
	if _fire != null:
		_fire.light_energy = 0.0
		_fire.position = Vector3(0.0, 0.0, -_box_u * 0.25)
	if _body_mat != null:
		_body_mat.set_shader_parameter("fade", 1.0)
		_body_mat.set_shader_parameter("emission_gain", 0.85)
	if _quad != null:
		_quad.visible = true
		_quad.position = Vector3.ZERO
	_rebuild_glass()


# ---------------------------------------------------------------- the death rite

## The vessel gives. The fire inside wells up through every fracture, one last
## web races the glass — then the shards STOP being decoration and become
## rigid bodies. No hand-rolled ballistics: gravity, tumble and the floor bounce
## are the physics engine's, which is the whole reason to be in Godot.
func mark_dead() -> void:
	if _dead:
		return
	# A hero does not break. The benchmark spends no crack, no ignition and no
	# shatter on the player's own body — a defeat is the screen's overlay, not the
	# vessel coming apart — so the rite is a foe's ending and this returns before
	# scoring anything. Guarded here rather than left to the caller, because the
	# rite is irreversible without rebuilding the actor.
	if tier == "hero":
		return
	_dead = true
	clear_intent()
	if _gem != null:
		_gem.set_state(_hue, 0.0, true)
		modulate = Color(0.5, 0.5, 0.56, 0.5)
		return
	# A dying vessel cracks the rest of the way through first.
	while _sites.size() < 9:
		crack()
	var tw: Tween = create_tween()
	tw.tween_method(set_ignite, _ignite, 1.0, 0.45).set_trans(Tween.TRANS_CUBIC)
	tw.tween_callback(shatter)


## The radial fracture map. Sites ring the burst point — dense near it, sparse
## far — which is how tempered glass actually fails: small hot cells at the
## impact, long wedges toward the silhouette.
func _death_sites(burst: Vector2) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	out.append(burst)
	var reach: float = _box_u * 0.52
	# Fewer, larger cells: a piece must be big enough to carry a readable patch
	# of the painting, or the rite degrades into confetti.
	var rings: Array[Array] = [[0.16, 4], [0.36, 7], [0.62, 9], [0.85, 10]]
	for ring: Array in rings:
		var rf: float = ring[0]
		var n: int = ring[1]
		for i: int in range(n):
			var a: float = TAU * (float(i) + _rng.randf_range(-0.35, 0.35)) / float(n)
			var r: float = reach * rf * _rng.randf_range(0.82, 1.22)
			var p: Vector2 = burst + Vector2(cos(a), sin(a)) * r
			p.x = clampf(p.x, -_quad_w * 0.49, _quad_w * 0.49)
			p.y = clampf(p.y, -_box_u * 0.49, _box_u * 0.49)
			out.append(p)
	return out


## Full-body panes, minus the empty ones. A cell whose every probe lands on
## transparent art would fly as an invisible slab wearing a glowing fracture
## rim — which is exactly "shattering something that is not the mob".
func _death_cells(burst: Vector2) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for cell: PackedVector2Array in _voronoi(_death_sites(burst), 0.0):
		var centre: Vector2 = Vector2.ZERO
		for v: Vector2 in cell:
			centre += v
		centre /= float(cell.size())
		if _touches_art(cell, centre):
			out.append(cell)
	return out


func _touches_art(cell: PackedVector2Array, centre: Vector2) -> bool:
	if _art_img == null:
		return true
	if _alpha_at(centre) > 0.08:
		return true
	for v: Vector2 in cell:
		if _alpha_at((centre + v) * 0.5) > 0.08:
			return true
	return false


func _alpha_at(p: Vector2) -> float:
	var w: int = _art_img.get_width()
	var h: int = _art_img.get_height()
	var x: int = clampi(int((p.x / _quad_w + 0.5) * float(w)), 0, w - 1)
	var y: int = clampi(int((0.5 - p.y / _box_u) * float(h)), 0, h - 1)
	return _art_img.get_pixel(x, y).a


## The vessel gives — and the CREATURE is what breaks. One frame it stands
## whole; the next, the painting itself is cut into radial panes, every piece
## opaque with the patch of art it covered, molten along its fracture edges.
## The intact body is HIDDEN the same frame (the benchmark's meshHandoff):
## nothing may remain behind the debris, because a mob still visible behind its
## own shards reads as "a pane in front broke, and the monster left". Then real
## physics carries the pieces — tumble biased out of the picture plane so
## nothing lands balanced on an edge — and every piece cools and crumbles to
## embers inside two seconds. Debris that lingers is scenery; debris that
## disperses is an event.
func shatter() -> void:
	if _vessel == null or not _vessel.visible:
		return
	if tier == "hero":
		return  # see mark_dead(): a hero's vessel never breaks
	_dead = true
	clear_intent()
	if _art_img == null and _body_mat != null:
		var t: Texture2D = _body_mat.get_shader_parameter("body_tex")
		if t != null:
			_art_img = t.get_image()
			if _art_img != null and _art_img.is_compressed():
				_art_img.decompress()
	# The handoff: the standing vessel vanishes THIS frame; its pieces replace it.
	# Its shadow goes with it — nothing is standing there to cast one.
	_vessel.transform = Transform3D.IDENTITY
	_vessel.visible = false
	if _shadow != null:
		var sfade: Tween = create_tween()
		sfade.tween_method(_set_shadow_fade, 1.0, 0.0, 0.35)
	if _debris != null and is_instance_valid(_debris):
		_debris.queue_free()
	_debris = Node3D.new()
	_stage.add_child(_debris)
	var burst: Vector2 = Vector2(0.0, _box_u * 0.05)
	var body_tex: Variant = null
	if _body_mat != null:
		body_tex = _body_mat.get_shader_parameter("body_tex")
	if _shard_shader == null:
		_shard_shader = Shader.new()
		_shard_shader.code = SHARD_SHADER
	# Thinner than the overlay plate: a thick prism reads as a crouton, all
	# fracture-face and no painting.
	var thick: float = _box_u * GLASS_THICK * 0.9
	var spin: float = 10.0 / maxf(1.0, sqrt(_box_u))
	for cell: PackedVector2Array in _death_cells(burst):
		var centre: Vector2 = Vector2.ZERO
		for v: Vector2 in cell:
			centre += v
		centre /= float(cell.size())
		var mesh: ArrayMesh = _prism(cell, thick, Vector2(_quad_w, _box_u), centre)
		if mesh == null:
			continue
		var smat: ShaderMaterial = ShaderMaterial.new()
		smat.shader = _shard_shader
		smat.set_shader_parameter("body_tex", body_tex)
		# Explicit, not redundant: a ShaderMaterial returns nil for any uniform
		# never set on the MATERIAL (defaults live in the shader), and a Tween
		# with a nil start value refuses the property outright.
		smat.set_shader_parameter("heat", 1.0)
		smat.set_shader_parameter("dissolve", 0.0)
		var rb: RigidBody3D = RigidBody3D.new()
		rb.physics_material_override = _bounce(0.35, 0.4)
		rb.gravity_scale = 2.4
		rb.angular_damp = 0.6
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = mesh
		mi.set_surface_override_material(0, smat)
		rb.add_child(mi)
		var shape: CollisionShape3D = CollisionShape3D.new()
		var conv: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
		conv.points = mesh.get_faces()
		shape.shape = conv
		rb.add_child(shape)
		rb.position = Vector3(centre.x, centre.y, 0.0)
		_debris.add_child(rb)
		# Blown outward from the burst with a shove toward the lens; tumble is
		# biased around the in-plane axes so plates FLIP out of the picture
		# plane rather than pinwheeling flat and settling upright.
		var out2: Vector2 = centre - burst
		var dir: Vector3 = Vector3.UP
		if out2.length() > _box_u * 0.001:
			dir = Vector3(out2.x, out2.y, 0.0).normalized()
		rb.linear_velocity = dir * _box_u * _rng.randf_range(0.45, 1.05) \
			+ Vector3(0.0, _box_u * 0.35, _box_u * _rng.randf_range(0.6, 1.5))
		rb.angular_velocity = Vector3(
			_rng.randf_range(-spin, spin) * 1.3,
			_rng.randf_range(-spin, spin) * 1.3,
			_rng.randf_range(-spin, spin) * 0.5)
		var cool_t: Tween = rb.create_tween()
		cool_t.tween_property(smat, "shader_parameter/heat", 0.0,
			_rng.randf_range(0.9, 1.4)) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		# Short lives, staggered: most pieces crumble at or just after first
		# bounce. A plate that settles flat shows the lens only its side band —
		# debris left lying around is where the "standing glass" read came from.
		var fade_t: Tween = rb.create_tween()
		fade_t.tween_interval(_rng.randf_range(0.55, 1.05))
		fade_t.tween_property(smat, "shader_parameter/dissolve", 1.0, 0.35)
		fade_t.tween_callback(rb.queue_free)
	_spawn_burst_flash(burst)
	_spawn_embers(burst)
	# The flash: the vessel's fire escapes all at once, thrown FORWARD onto the
	# flying pieces, then dies away with the embers.
	if _fire != null:
		_fire.position = Vector3(burst.x, burst.y, _box_u * 0.5)
		_fire.light_energy = 4.5
		var flash_t: Tween = create_tween()
		flash_t.tween_property(_fire, "light_energy", 0.0, 0.7) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_shake = 1.0
	# The stage clears itself; nothing of the rite may stand around afterwards.
	var d_t: Tween = _debris.create_tween()
	d_t.tween_interval(2.4)
	d_t.tween_callback(_debris.queue_free)


## One-shot ember burst: sparks thrown with the shards, floating a beat longer.
func _spawn_embers(burst: Vector2) -> void:
	var emb: CPUParticles3D = CPUParticles3D.new()
	emb.one_shot = true
	emb.explosiveness = 1.0
	emb.amount = 48
	emb.lifetime = 0.9
	emb.lifetime_randomness = 0.5
	var qm: QuadMesh = QuadMesh.new()
	qm.size = Vector2.ONE * _box_u * 0.05
	emb.mesh = qm
	emb.material_override = _add_mat(_fx_tex("ember"))
	emb.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	emb.emission_sphere_radius = _box_u * 0.14
	emb.direction = Vector3(0.0, 0.5, 1.0)
	emb.spread = 180.0
	emb.gravity = Vector3(0.0, -_box_u * 1.6, 0.0)
	emb.initial_velocity_min = _box_u * 0.8
	emb.initial_velocity_max = _box_u * 2.4
	emb.damping_min = _box_u * 0.5
	emb.damping_max = _box_u * 1.2
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(1.0, 0.86, 0.5, 1.0))
	grad.add_point(0.55, Color(1.0, 0.55, 0.2, 0.85))
	grad.set_color(1, Color(0.9, 0.3, 0.08, 0.0))
	emb.color_ramp = grad
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	emb.scale_amount_curve = curve
	emb.position = Vector3(burst.x, burst.y, _box_u * 0.1)
	_debris.add_child(emb)
	emb.finished.connect(emb.queue_free)


## The impact frame: a radial flare that blooms and is gone in a quarter second.
func _spawn_burst_flash(burst: Vector2) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var qm: QuadMesh = QuadMesh.new()
	qm.size = Vector2.ONE * _box_u * 1.1
	mi.mesh = qm
	var m: StandardMaterial3D = _add_mat(_fx_tex("burst"))
	mi.material_override = m
	mi.position = Vector3(burst.x, burst.y, _box_u * 0.3)
	mi.scale = Vector3.ONE * 0.55
	_debris.add_child(mi)
	var tw: Tween = mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * 1.5, 0.28) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color", Color(0, 0, 0, 0), 0.28) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)


## FX sprites are additive (black reads as transparent), loaded straight off
## disk so no import pass is needed mid-session; a missing file falls back to a
## procedural radial gradient. ponytail: Image.load_from_file bypasses the
## import system, so an exported build must import these or keep the fallback.
static func _fx_tex(fx_name: String) -> Texture2D:
	if _fx_cache.has(fx_name):
		var hit: Texture2D = _fx_cache[fx_name]
		return hit
	var path: String = "res://assets/art/enemies/fx/%s.png" % fx_name
	var tex: Texture2D = null
	if FileAccess.file_exists(path):
		var img: Image = Image.load_from_file(path)
		if img != null:
			tex = ImageTexture.create_from_image(img)
	if tex == null:
		var g: Gradient = Gradient.new()
		g.set_color(0, Color(1.0, 0.92, 0.7, 1.0))
		g.add_point(0.35, Color(1.0, 0.55, 0.2, 1.0))
		g.set_color(1, Color(0.0, 0.0, 0.0, 1.0))
		var gt: GradientTexture2D = GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(0.5, 0.0)
		gt.width = 64
		gt.height = 64
		tex = gt
	_fx_cache[fx_name] = tex
	return tex


static func _add_mat(tex: Texture2D) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = tex
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.disable_receive_shadows = true
	return m


## The death ramp, 0..1. Public so the bench can hold it at a frame the eye can
## look at — the benchmark's own rite is 200ms and unwatchable in a still.
func set_ignite(v: float) -> void:
	_ignite = clampf(v, 0.0, 1.0)
	if _fire != null:
		_fire.light_energy = 4.0 * _ignite
	if _body_mat != null:
		_body_mat.set_shader_parameter("emission_gain", 0.85 + 1.0 * _ignite)
	if _glass_mat != null:
		_glass_mat.set_shader_parameter("ignite", _ignite)


# ---------------------------------------------------------------- bench seams

## Live knobs. The glass constants are material properties and light energies
## rather than baked numbers, so a tuning surface can move them while it runs.
func set_glass_param(param: StringName, value: float) -> void:
	match param:
		&"ignite":
			set_ignite(value)
		&"breathe":
			_breathe = value
		&"bump", &"emission_gain":
			if _body_mat != null:
				_body_mat.set_shader_parameter(param, value)
		&"flare_gain":
			# Both, deliberately: the material so the actor on screen changes now,
			# and the static so the next actor the bench builds keeps the setting.
			flare_gain = value
			if _body_mat != null:
				_body_mat.set_shader_parameter("flare_gain", value)
		&"glass_area":
			_glass_area = value
			_rebuild_glass()
		&"shadow":
			_shadow_opacity = value
			_update_shadow()
		&"roughness":
			_glass_material().set_shader_parameter("rough", value)
		&"refraction":
			_glass_material().set_shader_parameter("bend", value)
		&"alpha":
			_glass_material().set_shader_parameter("tint_a", value)
		&"ior":
			_glass_material().set_shader_parameter("ior", value)
		&"key", &"rim", &"fire":
			var lamp: Light3D = _key if param == &"key" \
				else (_rim if param == &"rim" else _fire)
			if lamp != null:
				lamp.light_energy = value


## Swing the key light. Real lighting only reads as real when it moves — and
## the shadow is a projection along this light, so it swings with it.
func set_light_angle(yaw_deg: float, pitch_deg: float) -> void:
	if _key != null:
		_key.rotation_degrees = Vector3(pitch_deg, yaw_deg, 0.0)
	_update_shadow()


func _set_shadow_fade(v: float) -> void:
	if _shadow_mat != null:
		_shadow_mat.set_shader_parameter("opacity", _shadow_opacity * v)


func set_targetable(on: bool) -> void:
	if _dead:
		return
	if _body_mat != null:
		_body_mat.set_shader_parameter("target_lit", 1.0 if on else 0.0)
		return
	modulate = Color(1.28, 1.14, 0.9, 1.0) if on else Color(1, 1, 1, 1)


# ---------------------------------------------------------------- chrome

## A hero wears less chrome than a foe, and the benchmark's own DOM is the reason:
## its `.top-chrome` holds the status row ALONE, and its `.cplate` holds the ward
## chip, the HP vial and the HP label alone. A foe's crown adds `.intent`, and its
## plate adds a name line and a `.facet-row`
## (roguecardv2 src/ui/combat.js:215-257). Those three are therefore never built
## for a hero rather than built and hidden — an invisible widget still holds a
## slot open in a VBox, which is exactly the gap a hero's plate must not have.
##
## Every setter that would drive a missing widget is a no-op, so a caller does not
## have to know which kind of actor it is holding.
func _build_chrome(display_name: String) -> void:
	var is_hero: bool = tier == "hero"

	# ---- crown chrome: intent, then statuses. Anchored ABOVE the art box.
	var crown: VBoxContainer = VBoxContainer.new()
	crown.add_theme_constant_override("separation", 4)
	crown.alignment = BoxContainer.ALIGNMENT_END
	crown.set_anchors_preset(Control.PRESET_TOP_WIDE)
	crown.grow_vertical = Control.GROW_DIRECTION_BEGIN
	crown.offset_bottom = -CROWN_GAP
	crown.offset_top = -200.0
	crown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crown)

	# The standalone widgets, swapped in for the inline ember chip and the text
	# line that stood here. Both start empty: an intent with no kind and no
	# figure draws nothing (`.intent:empty`), and an actor with no conditions
	# has no row, rather than an invisible one holding a slot open.
	if not is_hero:
		_intent = IntentChip.new(&"", "")
		crown.add_child(_center(_intent))

	_statuses = StatusRow.new()
	crown.add_child(_statuses)

	# ---- foot plate: name (foes only), ward + HP vial, facets (foes only).
	# Anchored BELOW the feet.
	_plate = VBoxContainer.new()
	_plate.add_theme_constant_override("separation", 6)
	_plate.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_plate.grow_vertical = Control.GROW_DIRECTION_END
	_plate.offset_top = PLATE_GAP
	_plate.offset_bottom = PLATE_GAP + 200.0
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plate)

	if not is_hero:
		_name_label = _label(display_name)
		_name_label.add_theme_font_size_override("font_size", 14)
		_plate.add_child(_name_label)

	var vial_row: HBoxContainer = HBoxContainer.new()
	vial_row.add_theme_constant_override("separation", 6)
	vial_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vial_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_child(vial_row)

	# Ward is the painted lock, not a text pill — the same asset the benchmark
	# hangs on the left of the vial.
	_ward_chip = PanelContainer.new()
	_ward_chip.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_ward_chip.visible = false
	_ward_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ward_box: HBoxContainer = HBoxContainer.new()
	ward_box.add_theme_constant_override("separation", 2)
	_ward_icon = TextureRect.new()
	_ward_icon.texture = WARD_ICON
	_ward_icon.custom_minimum_size = Vector2(WARD_ICON_PX, WARD_ICON_PX)
	_ward_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ward_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ward_box.add_child(_ward_icon)
	_ward = _label("")
	_ward.add_theme_color_override("font_color", GlassStyle.GLASS)
	_ward.add_theme_font_size_override("font_size", 13)
	_ward.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ward_box.add_child(_ward)
	_ward_chip.add_child(ward_box)
	vial_row.add_child(_ward_chip)

	var hp_wrap: Control = Control.new()
	hp_wrap.custom_minimum_size = Vector2(PLATE_W, 16)
	hp_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vial_row.add_child(hp_wrap)
	_hp_bar = ProgressBar.new()
	_hp_bar.show_percentage = false
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	GlassStyle.style_bar(_hp_bar, GlassStyle.HP_RED)
	hp_wrap.add_child(_hp_bar)
	_hp_label = _label("")
	_hp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_label.add_theme_font_size_override("font_size", 11)
	_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_wrap.add_child(_hp_label)

	if not is_hero:
		_facets = FacetPips.new()
		_facets.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_plate.add_child(_facets)


static func _label(initial: String) -> Label:
	var l: Label = Label.new()
	l.text = initial
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## Chips size to content; wrap in a centre container so they don't stretch.
static func _center(node: Control) -> CenterContainer:
	var cc: CenterContainer = CenterContainer.new()
	cc.add_child(node)
	return cc


## Hang the foot plate from the GROUND rather than from this actor's own box.
## An actor whose art carries empty space under the creature sinks its box below
## the line (footY), and a row where every HP vial sat at a different height
## would be unreadable — the benchmark aligns the same way through --chrome-dy.
func align_plate(dy: float) -> void:
	_plate.offset_top = dy + PLATE_GAP
	_plate.offset_bottom = dy + PLATE_GAP + 200.0


# ---------------------------------------------------------------- state in

## Full sync from an enemy snapshot (drain-idle truth). `dmg_text` is already
## formatted by the screen ("" when the move deals no damage), `intent` is the
## move's own kind, and `infos` is the content status table for the hover text.
func sync(e: EnemyCombatant, dmg_text: String, intent: StringName,
		move_name: String = "", infos: Dictionary = {}) -> void:
	set_hp(e.hp, e.max_hp)
	set_ward(e.block)
	set_facets(mini(e.chips, e.facet_max), e.facet_max)
	set_statuses(e.statuses, infos)
	set_intent(intent, dmg_text, move_name)
	if e.hp <= 0:
		mark_dead()


## HP moves the vial, not the body. The benchmark keeps combat cracks OFF
## (COMBAT_CRACKS = false, combat.js:2642) and its `.lowhp` tilt is explicitly
## scoped away from the raster body — the glass language is spent on the death
## rite, not on attrition. The gem fallback still dims, because that is what a
## gem with no painting has to say.
func set_hp(hp: int, max_hp: int) -> void:
	_max_hp = maxi(max_hp, 1)
	_hp_bar.max_value = _max_hp
	_hp_bar.value = maxi(0, hp)
	_hp_label.text = "%d / %d" % [maxi(0, hp), max_hp]
	if _gem != null and not _dead:
		_gem.set_state(_hue, float(maxi(0, hp)) / float(_max_hp), hp <= 0)


func set_ward(block: int) -> void:
	_ward_chip.visible = block > 0
	if block > 0:
		_ward.text = str(block)


## A hero has no facet gauge to move — structural integrity is a foe's concept.
func set_facets(chips: int, facet_max: int) -> void:
	if _facets == null:
		return
	_facets.set_pips(chips, facet_max)


## The telegraph. `intent` is the move's own `intent` field — `attack`,
## `attack_block`, `debuff` — NOT its display name: the chip resolves both its
## icons and the single colour everything on it tints to from that id.
##
## The name goes to the tooltip instead of onto the chip, which is what the
## benchmark's `cursor: help` is for. It is passed in rather than looked up
## because a widget in `presentation/` does not read content.
##
## A hero telegraphs nothing — it acts when the player plays a card, so there is
## no next move to announce and no chip to announce it on.
func set_intent(intent: StringName, amount_text: String, move_name: String = "") -> void:
	if _intent == null:
		return
	_intent.set_intent(intent, amount_text)
	_intent.tooltip_text = move_name


## The telegraph has been spent, or there is nothing to telegraph. An intent
## with no kind and no figure draws nothing, so this is one call rather than a
## visibility flag someone downstream has to remember to restore.
func clear_intent() -> void:
	set_intent(&"", "")


func set_statuses(statuses: Dictionary, infos: Dictionary = {}) -> void:
	_statuses.sync(statuses, infos)
