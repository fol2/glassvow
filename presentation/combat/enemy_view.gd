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
## material, lit by real lights against a real sky. On death they become
## RigidBody3D and fall. The web benchmark had to fake every one of those: it
## hand-rolled ballistics in JS, baked crack normals to a 192px canvas, and
## needed an opaque back-buffer pass to get transmission at all
## (docs/glass-crack-rendering.md). Here the engine does it.
##
## Renders from explicit sync calls / event fields — never reads combat state
## directly (the sequencer contract). Targeting is drop-based (the hand's drag
## machine hit-tests get_global_rect(), which is why the rect is the art box).

const ART_PATH: String = "res://assets/art/enemies/%s.png"
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

## The stage renders at this multiple of the box. At 1.0 a 176px creature is a
## 176px render being upscaled by the window's own content scale (and again by
## the bench's zoom), which is exactly the softness the first 3D pass had.
static var oversample: float = 2.5

var idx: int = 0
## Placement offsets for whoever puts this actor on the battlefield. Feet are
## this box's bottom edge (benchmark bfEnemyFootX / bfEnemyFootY).
var foot: Vector2 = Vector2.ZERO
var art_size: float = 0.0

var _hue: float = 210.0
var _max_hp: int = 1
var _intent_chip: PanelContainer
var _intent: Label
var _gem: GlassGem
var _name_label: Label
var _hp_bar: ProgressBar
var _hp_label: Label
var _facets: FacetPips
var _ward_chip: PanelContainer
var _ward: Label
var _ward_icon: TextureRect
var _statuses: Label
var _plate: VBoxContainer
var _dead: bool = false
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
var _box_u: float = 0.0         # box, in world units
var _ignite: float = 0.0
## Glass reach past each crack site, as a fraction of the box — the benchmark's
## GLASS_AREA. Under 1.0 the body is mostly bare, which is the point: glass
## exists ONLY where the creature is broken.
var _glass_area: float = 0.45
var _glass_mat: ShaderMaterial = null

static var _meta: Dictionary = {}


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

	if (target_lit > 0.0) {
		vec2 px = ts * 9.0;
		float ring = 0.0;
		ring = max(ring, texture(body_tex, uv + vec2(px.x, 0.0)).a);
		ring = max(ring, texture(body_tex, uv - vec2(px.x, 0.0)).a);
		ring = max(ring, texture(body_tex, uv + vec2(0.0, px.y)).a);
		ring = max(ring, texture(body_tex, uv - vec2(0.0, px.y)).a);
		ring = max(ring, texture(body_tex, uv + px * 0.72).a);
		ring = max(ring, texture(body_tex, uv - px * 0.72).a);
		float rim = clamp(ring - c.a, 0.0, 1.0) * target_lit;
		EMISSION += rim * vec3(0.89, 0.84, 0.98) * 3.0;
		ALPHA = max(ALPHA, rim);
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
		var path: String = ART_PATH % art_id
		if ResourceLoader.exists(path):
			tex = load(path) as Texture2D
		else:
			push_warning("enemy view: no painting at %s" % path)

	if tex != null:
		var entry: Dictionary = meta(art_id)
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

	_stage = SubViewport.new()
	var vp_px: int = mini(int(_span * oversample), VP_MAX)
	_stage.size = Vector2i(vp_px, vp_px)
	_stage.own_world_3d = true
	_stage.transparent_bg = true
	_stage.msaa_3d = Viewport.MSAA_4X
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
	qm.size = Vector2(_box_u, _box_u)
	_quad.mesh = qm
	var sh: Shader = Shader.new()
	sh.code = BODY_SHADER
	_body_mat = ShaderMaterial.new()
	_body_mat.shader = sh
	_body_mat.set_shader_parameter("body_tex", tex)
	_body_mat.render_priority = -1   # drawn before the glass
	_quad.set_surface_override_material(0, _body_mat)
	_vessel.add_child(_quad)

	_glass_root = Node3D.new()
	_vessel.add_child(_glass_root)

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

	var cam: Camera3D = Camera3D.new()
	cam.fov = FOV_DEG
	var dist: float = (_span * UNIT) * 0.5 / tan(deg_to_rad(FOV_DEG * 0.5))
	cam.position = Vector3(0.0, 0.0, dist)
	cam.near = dist * 0.25
	cam.far = dist * 3.0
	_stage.add_child(cam)

	_display = TextureRect.new()
	_display.texture = _stage.get_texture()
	_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_display.stretch_mode = TextureRect.STRETCH_SCALE
	var pad: float = art_size * PAD_FRAC
	_display.position = Vector2(-pad, -pad)
	_display.size = Vector2(_span, _span)
	_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_display)


static func _bounce() -> PhysicsMaterial:
	var pm: PhysicsMaterial = PhysicsMaterial.new()
	pm.bounce = 0.28
	pm.friction = 0.7
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
## leans and swells — as a TRANSFORM, which the glass rides along with. Stops the
## moment the vessel breaks, because by then the shards own their own motion.
func _process(_delta: float) -> void:
	if _vessel == null or _dead:
		return
	var t: float = Time.get_ticks_msec() * 0.001 + _phase
	var sw: float = sin(t * 1.05)
	var k: float = 1.0 + _breathe * 0.016 * sw
	_vessel.scale = Vector3(k, k, 1.0)
	_vessel.rotation.z = _breathe * 0.017 * sin(t * 0.71)
	_vessel.position.y = _breathe * _box_u * 0.010 * sin(t * 0.83)


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


## Voronoi cells for the current sites, in world units, centred on the quad.
func _cells() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var h: float = _box_u * 0.5
	var big: float = _box_u * 8.0
	var box: PackedVector2Array = PackedVector2Array([
		Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h),
	])
	for i: int in range(_sites.size()):
		var cell: PackedVector2Array = box
		for j: int in range(_sites.size()):
			if i == j:
				continue
			cell = _clip(cell, _sites[i], _sites[j], big)
			if cell.is_empty():
				break
		if cell.size() < 3:
			continue
		# Then bound it to the site's own reach. Without this every cell tiles
		# the whole quad and the "glass" becomes an opaque pane over the art.
		var patch: Array[PackedVector2Array] = Geometry2D.intersect_polygons(
			cell, _disc(_sites[i], _glass_area * _box_u * 0.5))
		if not patch.is_empty() and patch[0].size() >= 3:
			out.append(patch[0])
	return out


## Extrude a cell into a real plate with thickness. Thickness is the point: a
## zero-depth polygon cannot catch a highlight on its edge or bend anything.
static func _prism(cell: PackedVector2Array, thick: float, box: float) -> ArrayMesh:
	var tri: PackedInt32Array = Geometry2D.triangulate_polygon(cell)
	if tri.is_empty():
		return null
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z: float = thick * 0.5
	for face: int in range(2):
		var zz: float = z if face == 0 else -z
		var i: int = 0
		while i < tri.size():
			for k: int in range(3):
				var p: Vector2 = cell[tri[i + k]]
				st.set_uv(Vector2(p.x / box + 0.5, 0.5 - p.y / box))
				st.add_vertex(Vector3(p.x, p.y, zz))
			i += 3
	# Side band, quad per edge — where the thickness actually shows.
	for i: int in range(cell.size()):
		var a: Vector2 = cell[i]
		var b: Vector2 = cell[(i + 1) % cell.size()]
		var quad: Array[Vector3] = [
			Vector3(a.x, a.y, z), Vector3(b.x, b.y, z), Vector3(b.x, b.y, -z),
			Vector3(a.x, a.y, z), Vector3(b.x, b.y, -z), Vector3(a.x, a.y, -z),
		]
		for v: Vector3 in quad:
			st.set_uv(Vector2(v.x / box + 0.5, 0.5 - v.y / box))
			st.add_vertex(v)
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
		var mesh: ArrayMesh = _prism(cell, thick, _box_u)
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
	_sites.append(Vector2((p.x - 0.5) * _box_u, (0.5 - p.y) * _box_u))
	_rebuild_glass()


func reset_glass() -> void:
	_dead = false
	_ignite = 0.0
	_sites = PackedVector2Array()
	modulate = Color(1, 1, 1, 1)
	if _glass_mat != null:
		_glass_mat.set_shader_parameter("ignite", 0.0)
	if _fire != null:
		_fire.light_energy = 0.0
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
	_dead = true
	_intent_chip.visible = false
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


## Hand every shard to the physics engine and blow them off the body.
func shatter() -> void:
	if _glass_root == null:
		return
	if _sites.size() < 2:
		crack()
		crack()
		crack()
	var thick: float = _box_u * GLASS_THICK
	var mat: ShaderMaterial = _glass_material()
	mat.set_shader_parameter("ignite", 1.0)
	for c: Node in _glass_root.get_children():
		c.queue_free()
	_shards.clear()
	for cell: PackedVector2Array in _cells():
		var mesh: ArrayMesh = _prism(cell, thick, _box_u)
		if mesh == null:
			continue
		var centre: Vector2 = Vector2.ZERO
		for v: Vector2 in cell:
			centre += v
		centre /= float(cell.size())
		var rb: RigidBody3D = RigidBody3D.new()
		rb.physics_material_override = _bounce()
		rb.gravity_scale = 2.4
		rb.angular_damp = 0.35
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = mesh
		mi.set_surface_override_material(0, mat)
		rb.add_child(mi)
		var shape: CollisionShape3D = CollisionShape3D.new()
		var conv: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
		conv.points = mesh.get_faces()
		shape.shape = conv
		rb.add_child(shape)
		rb.position = Vector3(0.0, 0.0, thick * 0.6)
		_glass_root.add_child(rb)
		# Blown outward from the middle, with a shove toward the lens so the
		# break reads as depth rather than a flat card falling over.
		var away: Vector3 = Vector3(centre.x, centre.y, 0.0).normalized()
		if away == Vector3.ZERO:
			away = Vector3(0.0, 1.0, 0.0)
		rb.apply_impulse(away * _box_u * _rng.randf_range(0.7, 1.6)
			+ Vector3(0.0, _box_u * 0.5, _box_u * _rng.randf_range(0.5, 1.4)))
		rb.angular_velocity = Vector3(
			_rng.randf_range(-8.0, 8.0), _rng.randf_range(-8.0, 8.0),
			_rng.randf_range(-8.0, 8.0))
		_shards.append(rb)
	# The body goes with the glass; what is left is the light it was holding.
	if _quad != null:
		var tw: Tween = create_tween()
		tw.tween_method(_fade_body, 1.0, 0.0, 0.5).set_delay(0.12)
	# ...and the fire ESCAPES. Held at full blaze the shards read as anonymous
	# white chips; cooling them hands the creature back, so what lands on the
	# floor is recognisably the thing that was standing there.
	var cool: Tween = create_tween()
	cool.tween_method(_cool_glass, 1.0, 0.15, 0.7).set_delay(0.15)


func _cool_glass(v: float) -> void:
	if _glass_mat != null:
		_glass_mat.set_shader_parameter("ignite", v)
	if _fire != null:
		_fire.light_energy = 4.0 * v


func _fade_body(v: float) -> void:
	if _body_mat != null:
		_body_mat.set_shader_parameter("fade", v)
		_body_mat.set_shader_parameter("emission_gain", 0.85 * v)
	if _fire != null:
		_fire.light_energy = 4.0 * v * _ignite


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
		&"glass_area":
			_glass_area = value
			_rebuild_glass()
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


## Swing the key light. Real lighting only reads as real when it moves.
func set_light_angle(yaw_deg: float, pitch_deg: float) -> void:
	if _key != null:
		_key.rotation_degrees = Vector3(pitch_deg, yaw_deg, 0.0)


func set_targetable(on: bool) -> void:
	if _dead:
		return
	if _body_mat != null:
		_body_mat.set_shader_parameter("target_lit", 1.0 if on else 0.0)
		return
	modulate = Color(1.28, 1.14, 0.9, 1.0) if on else Color(1, 1, 1, 1)


# ---------------------------------------------------------------- chrome

func _build_chrome(display_name: String) -> void:
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

	# Session 3 owns the intent chip as a standalone widget and will swap it in
	# here — these three lines are the current inline one, unchanged.
	_intent_chip = _chip(GlassStyle.EMBER)
	_intent = _chip_label(_intent_chip, GlassStyle.EMBER)
	crown.add_child(_center(_intent_chip))

	_statuses = _label("")
	_statuses.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
	_statuses.add_theme_font_size_override("font_size", 12)
	_statuses.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	crown.add_child(_statuses)

	# ---- foot plate: name, ward + HP vial, facets. Anchored BELOW the feet.
	_plate = VBoxContainer.new()
	_plate.add_theme_constant_override("separation", 6)
	_plate.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_plate.grow_vertical = Control.GROW_DIRECTION_END
	_plate.offset_top = PLATE_GAP
	_plate.offset_bottom = PLATE_GAP + 200.0
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plate)

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

	_facets = FacetPips.new()
	_facets.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_child(_facets)


static func _label(initial: String) -> Label:
	var l: Label = Label.new()
	l.text = initial
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func _chip(accent: Color) -> PanelContainer:
	var c: PanelContainer = PanelContainer.new()
	c.add_theme_stylebox_override("panel", GlassStyle.chip(accent))
	return c


static func _chip_label(chip: PanelContainer, accent: Color) -> Label:
	var l: Label = _label("")
	l.add_theme_color_override("font_color", Color(accent.r, accent.g, accent.b, 0.95))
	l.add_theme_font_size_override("font_size", 13)
	chip.add_child(l)
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

## Full sync from an enemy snapshot (drain-idle truth). dmg_text is already
## formatted by the screen ("" when the move deals no damage).
func sync(e: EnemyCombatant, dmg_text: String, intent_text: String) -> void:
	set_hp(e.hp, e.max_hp)
	set_ward(e.block)
	set_facets(mini(e.chips, e.facet_max), e.facet_max)
	set_statuses(e.statuses)
	var line: String = intent_text
	if dmg_text != "":
		line += "   %s" % dmg_text
	set_intent(line)
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


func set_facets(chips: int, facet_max: int) -> void:
	_facets.set_pips(chips, facet_max)


func set_intent(intent_text: String) -> void:
	_intent.text = intent_text
	_intent_chip.visible = intent_text.strip_edges() != ""


func set_statuses(statuses: Dictionary) -> void:
	var parts: Array[String] = []
	for k: Variant in statuses.keys():
		var n: int = statuses[k]
		if n != 0:
			parts.append("%s %d" % [str(k), n])
	_statuses.text = " · ".join(parts)
