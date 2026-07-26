class_name RewardWindow
extends Control
## CONCEPT 「窗」— THE WINDOW. The reward is not a list of things you own. It is
## a window the fight just lit, and what you won is in it as light.
##
## THE ARGUMENT. A reward is four items and exactly one of them is a decision
## (see RewardSpoils). The benchmark renders all four as identical rows with
## identical buttons, which spends three clicks having the player acknowledge
## news. So here the announcements ARRIVE — the sun comes up behind the glass
## and each spoil's pane fills with its own colour, claimed as it lights — and
## the entire body of the screen is the one thing that is actually a choice.
## Nothing is a row, and nothing has a button except the choice.
##
## THE WINDOW IS THE READOUT. Its size is the haul. One spoil and no offering
## builds a small votive light; an elite with everything builds a three-lancet
## window with a lit head above it. You know how well the fight paid before you
## have read a word, because the architecture itself is different. No number
## does that, and no number has to.
##
## WHY THIS IS THE CARD'S SIBLING AND NOT ITS DECORATION. Both are a 2D face
## rendered offscreen and mounted on real geometry under a real light. The card
## is lit from the FRONT — you tilt it and a finish answers. The window is lit
## from BEHIND, so its glass has no finish to give back at all, and the only lit
## solid in the scene is the lead holding it. Move the cursor and the sun moves
## behind the sheet: panes trade brightness, the highlight travels along the
## lead's round, and halation eats the came where the glass runs hottest. Same
## engine, opposite light. The pair states the game's material thesis twice.
##
## The offering is the three lancets, each card standing in glass of its own
## type colour. Take one and its light stays while the other two go to lead, so
## the window ends the encounter as a record of what was taken from it.
##
## CardView is imported read-only: scaled, seated, and never touched again. This
## screen sets no card pose and moves no card lamp.

signal claimed(what: StringName, id: String)
signal finished()

const GLASS_SHADER: Shader = preload("res://presentation/reward/reward_glass.gdshader")

## ── THE LEAD ─────────────────────────────────────────────────────────────
## Came is a round bar, not a flat strip, and that is the whole reason there is
## a light in front of this scene at all. A box takes one flat value across its
## face and the window reads as a diagram. A round takes a highlight that
## TRAVELS as the lamp moves, which is what says the lead is metal, and in
## front of the glass, rather than a line drawn on it.
const CAME: float = 4.4              # radius — an 8.8px bar
const CAME_Z: float = 7.0            # the lead stands proud of the sheet
## The spill draws in FRONT of the lead on purpose: a pane bright enough eats
## its own came at the edges. That is halation, it is what a real backlit
## window does, and it is the cheapest honest cue that the light is behind.
const HALO_Z: float = 9.5

## ── THE OPENING ──────────────────────────────────────────────────────────
const LANCET_W: float = 214.0        # holds a 178px card with 18px of glass each side
const LANCET_H: float = 272.0
const LANCET_GAP: float = 8.0
const HEAD_H: float = 132.0
const ARCH_RISE: float = 104.0
const SILL: float = 22.0
## No offering: the window contracts to a single votive light, rather than
## standing three empty openings up and calling that a layout.
const SOLO_W: float = 344.0
const SOLO_HEAD_H: float = 212.0
const SOLO_ARCH: float = 92.0
const PAD: float = 52.0              # stage margin — room for the halation

const CARD_W_OUT: float = 178.0      # the benchmark's own pick size (--cw)
const CARD_SCALE: float = CARD_W_OUT / CardView.CARD_W

## THE SUN sits low and behind, and the cursor carries it +/- SUN_SWING. It is
## why a pane is brighter on one side than the other, and why that changes when
## you move. It never moves on a timer: a light that drifts under three cards
## you are trying to read is a surface that will not hold still long enough to
## be decided on, and this project has already paid for that lesson once.
const SUN_REACH: float = 448.0
const SUN_SWING: Vector2 = Vector2(150.0, 74.0)
const GAIN_SPOIL: float = 1.30
const GAIN_FIELD: float = 0.62       # the sky under the arch: present, never loud
const GAIN_DEAD: float = 0.10        # a lancet whose card was not taken
const GAIN_CHOSEN: float = 1.75

const DAWN: float = 0.28             # one pane filling
const DAWN_STAGGER: float = 0.040
const CARD_RISE: float = 26.0
const CARD_IN: float = 0.26

const LEAD: Color = Color(0.115, 0.130, 0.175)
const PARCHMENT: Color = Color(0.910, 0.875, 0.784)
const TEXT_DIM: Color = Color(0.545, 0.576, 0.678)
const GOLD: Color = Color(0.949, 0.757, 0.306)
const SKY: Color = Color(0.36, 0.56, 0.86)
## Paint on glass STOPS light, it never adds any — so the lettering on a lit
## pane is dark. Parchment text here would read as a sticker in front of the
## window instead of something fired onto it.
const VITREOUS: Color = Color(0.055, 0.045, 0.030, 0.94)

var reward: Dictionary = {}
var content: ContentDB
var encounter_kind: String = "normal"

var _stage: SubViewport = null
var _stage_rect: TextureRect = null
var _plate: Control = null           # the 2D layer, registered to the glass
var _sun_home: Vector2 = Vector2.ZERO
var _sun_mat: Array[ShaderMaterial] = []    # every pane AND every spill
var _lancet_mat: Array[ShaderMaterial] = []
var _faces: Array[Control] = []             # the spoils painted on the head
var _cards: Array[CardView] = []
var _card_ids: Array[String] = []
var _spoils: Array[Dictionary] = []
var _picked: bool = false
var _win: Vector2 = Vector2.ZERO            # glass extent, window px
var _stage_size: Vector2 = Vector2.ZERO
var _take_line: Label = null
var _bar: HBoxContainer = null

# Vertical stations, resolved once in _layout and read by both builders.
var _has_cards: bool = false
var _head_h: float = 0.0
var _lancet_h: float = 0.0
var _arch_rise: float = 0.0
var _y_sill: float = 0.0
var _y_transom: float = 0.0
var _y_spring: float = 0.0
var _cell: float = 0.0


func _init(reward_ref: Dictionary, content_ref: ContentDB,
		kind: String = "normal") -> void:
	reward = reward_ref
	content = content_ref
	encounter_kind = kind
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_spoils = RewardSpoils.list(reward, content)
	_card_ids = RewardSpoils.card_ids(reward)

	var ground: ColorRect = ColorRect.new()
	ground.color = Color(0.012, 0.016, 0.038, 0.90)
	ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)

	_layout()
	_build_stage()
	_build_plate()


## Glass extent and every vertical station, all a function of what the fight
## paid. Called before either builder so the two agree by construction.
func _layout() -> void:
	_has_cards = not _card_ids.is_empty()
	_head_h = HEAD_H if _has_cards else SOLO_HEAD_H
	_arch_rise = ARCH_RISE if _has_cards else SOLO_ARCH
	# An elite gets a taller head. This screen never captions what kind of fight
	# it was and does not need to: the concept's whole claim is that the
	# ARCHITECTURE is the readout, so an elite has to be a grander building or
	# the claim is not being kept.
	if encounter_kind == "elite":
		_arch_rise *= 1.32
	_lancet_h = LANCET_H if _has_cards else 0.0
	var w: float = 3.0 * LANCET_W + 2.0 * LANCET_GAP if _has_cards else SOLO_W
	_win = Vector2(w, SILL + _lancet_h + _head_h + _arch_rise)
	_y_sill = -_win.y * 0.5 + SILL
	_y_transom = _y_sill + _lancet_h
	_y_spring = _y_transom + _head_h
	_cell = _win.x / float(maxi(1, _spoils.size()))
	_stage_size = _win + Vector2(PAD, PAD) * 2.0
	# The sun sits behind the SPOILS, not behind the middle of the frame: they
	# are what the screen is about, the falloff then runs outward from them,
	# and the tympanum above gets enough light to carry its inscription.
	_sun_home = Vector2(0.0, _y_transom + _head_h * 0.5)


# ---------------------------------------------------------------- the glass

func _build_stage() -> void:
	_stage = SubViewport.new()
	_stage.size = Vector2i(int(_stage_size.x), int(_stage_size.y))
	_stage.own_world_3d = true
	_stage.transparent_bg = true
	_stage.msaa_3d = Viewport.MSAA_4X
	_stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_stage)

	var half: Vector2 = _win * 0.5

	# THE TYMPANUM — the sky under the arch. Always there, always cool, and
	# deliberately the dimmest thing lit: it is what the spoils are bright
	# AGAINST. Let it compete and every colour in the head goes muddy. The arc
	# already runs springing-to-springing, so the polygon closes itself along
	# the springing line and must not be handed that edge twice.
	_pane(_arch(half.x, _arch_rise, _y_spring), SKY, GAIN_FIELD, 0.31)

	# THE HEAD — one pane per spoil, dividing the full width between them. A
	# richer fight subdivides the window into more colours. There is no empty
	# seat and no placeholder, because a pane that is not there is not drawn.
	for i: int in range(_spoils.size()):
		var x0: float = -half.x + _cell * float(i)
		var tone: Color = _spoils[i]["tone"]
		_pane(_rect(x0, _y_transom, _cell, _head_h), tone, GAIN_SPOIL,
			0.17 * float(i + 1))
		if i > 0:
			_came(Vector2(x0, _y_transom), Vector2(x0, _y_spring))

	# THE LANCETS — the offering. Each card stands in glass of its own type
	# colour, so the SHAPE of what is on offer reads before a word of it does.
	for i: int in range(_card_ids.size()):
		var lx: float = -half.x + float(i) * (LANCET_W + LANCET_GAP)
		var tint: Color = RewardSpoils.tint_of(content, _card_ids[i])
		_lancet_mat.append(_pane(_rect(lx, _y_sill, LANCET_W, _lancet_h),
			tint, GAIN_SPOIL, 0.53 + 0.11 * float(i)))
		if i > 0:
			_came(Vector2(lx - LANCET_GAP * 0.5, _y_sill),
				Vector2(lx - LANCET_GAP * 0.5, _y_transom))

	# THE LEAD: perimeter, springing, transom — then the arch as a chain of
	# short bars, which is how a real arch is leaded anyway.
	_came(Vector2(-half.x, -half.y), Vector2(half.x, -half.y))
	_came(Vector2(-half.x, _y_sill), Vector2(half.x, _y_sill))
	_came(Vector2(-half.x, -half.y), Vector2(-half.x, _y_spring))
	_came(Vector2(half.x, -half.y), Vector2(half.x, _y_spring))
	_came(Vector2(-half.x, _y_spring), Vector2(half.x, _y_spring))
	if _has_cards:
		_came(Vector2(-half.x, _y_transom), Vector2(half.x, _y_transom))
	var curve: PackedVector2Array = _arch(half.x, _arch_rise, _y_spring)
	for i: int in range(curve.size() - 1):
		_came(curve[i], curve[i + 1])
	# THE FAN. A tympanum this wide, left as one sheet, is a slab — and a slab
	# is the one thing a window must never look like. The classic answer is to
	# glaze it as radiating lights, and every rib's outer end is already a point
	# on the arc, so the ribs cost a loop and nothing else. They converge on the
	# springing bar, which is where a real fan light lands them.
	for i: int in range(3, curve.size() - 3, 3):
		_came(Vector2(0.0, _y_spring), curve[i])

	_push_sun(_sun_home)

	# Ambient, or the lead renders as a black cut-out: with one light and no
	# sky there is nothing for a metal to reflect, and unlit metal is not dark,
	# it is absent.
	var env: Environment = Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.34, 0.42, 0.62)
	env.ambient_light_energy = 0.55
	# An Environment brings a BACKGROUND with it, and its default clear colour
	# is opaque — which quietly overrides transparent_bg and paints the stage's
	# whole rect as a slab behind the window. Clearing to zero alpha keeps the
	# ambient without the box.
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.0, 0.0)
	# A SubViewport's own World3D is not created until it enters the tree, and
	# this screen is built entirely in _init — so the world is handed over
	# rather than reached into, which also puts its ownership in one place.
	var world: World3D = World3D.new()
	world.environment = env
	_stage.world_3d = world

	# Head-on long lens at the distance where the stage maps 1:1 onto logical
	# pixels at z = 0 — the same framing the card uses, so a card laid over this
	# render sits at the scale the glass behind it was drawn for.
	var cam: Camera3D = Camera3D.new()
	cam.fov = CardView.FOV_DEG
	var dist: float = _stage_size.y * 0.5 / tan(deg_to_rad(CardView.FOV_DEG * 0.5))
	cam.position = Vector3(0.0, 0.0, dist + CAME_Z)
	cam.near = dist * 0.4
	cam.far = dist * 1.8
	_stage.add_child(cam)

	# The room's lantern, in front, reaching only the lead — up and to the left,
	# the same quarter CardView's ROOM_LAMP comes from, so the window and the
	# cards in it are lit by one room. Fixed: the cursor moves the SUN.
	var lamp: DirectionalLight3D = DirectionalLight3D.new()
	lamp.light_energy = 1.65
	lamp.light_color = Color(0.86, 0.90, 1.0)
	lamp.rotation_degrees = Vector3(-38.0, -26.0, 0.0)
	_stage.add_child(lamp)

	_stage_rect = TextureRect.new()
	_stage_rect.texture = _stage.get_texture()
	_stage_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_stage_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_stage_rect.size = _stage_size
	_stage_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage_rect)


## One pane, plus the light it throws past itself. Both are the same shader on
## the same tone because they are the same light — only the falloff differs.
func _pane(poly: PackedVector2Array, tone: Color, gain: float,
		seed: float) -> ShaderMaterial:
	var mat: ShaderMaterial = _glass(tone, gain, seed, 0.0)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = _poly_mesh(poly)
	mi.material_override = mat
	_stage.add_child(mi)

	var lo: Vector2 = poly[0]
	var hi: Vector2 = poly[0]
	for p: Vector2 in poly:
		lo = lo.min(p)
		hi = hi.max(p)
	var halo: MeshInstance3D = MeshInstance3D.new()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = (hi - lo) * 1.34
	halo.mesh = quad
	halo.position = Vector3((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5, HALO_Z)
	halo.material_override = _glass(tone, gain * 0.50, seed, 1.0)
	_stage.add_child(halo)
	return mat


## Every material lands on _sun_mat so one loop moves the sun for all of them,
## and _ready can walk the same list in pairs to bring them up.
func _glass(tone: Color, gain: float, seed: float, soft: float) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = GLASS_SHADER
	m.set_shader_parameter("tone", tone)
	m.set_shader_parameter("gain", gain)
	m.set_shader_parameter("seed", seed)
	m.set_shader_parameter("soft", soft)
	m.set_shader_parameter("reach", SUN_REACH)
	m.set_shader_parameter("lit", 0.0)
	_sun_mat.append(m)
	return m


func _came(a: Vector2, b: Vector2) -> void:
	var d: Vector2 = b - a
	var length: float = d.length()
	if length < 0.01:
		return
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = CAME
	cyl.bottom_radius = CAME
	cyl.height = length
	cyl.radial_segments = 12
	cyl.rings = 0
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = LEAD
	mat.metallic = 0.34
	mat.roughness = 0.33
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = cyl
	mi.material_override = mat
	mi.position = Vector3((a.x + b.x) * 0.5, (a.y + b.y) * 0.5, CAME_Z)
	mi.rotation = Vector3(0.0, 0.0, d.angle() - PI * 0.5)
	_stage.add_child(mi)


## A SEGMENTAL arch of half-width `h` rising `rise` from `y`, returned left
## springing to right springing. One arc, struck from a centre dropped BELOW
## the springing line.
##
## It is segmental and not the pointed arch you would expect of a window
## because a pointed arch cannot exist at this proportion. A two-centred arch
## puts each centre on the springing line at c = (rise^2 - h^2) / 2h, which
## goes negative whenever the rise is under the half-width — and a negative c
## sweeps the arc through its own 90 degrees BEFORE it reaches the meeting
## point, so each half bulges above the apex and the two cross. The head is
## 604 wide; a pointed one would need a 302px rise to be legal. A wide low head
## takes a segmental arch in real glazing for exactly this reason.
##
##   k = (h^2 - rise^2) / 2 rise   how far below the springing the centre sits
##   r = k + rise                  radius, through both springings and the crown
static func _arch(h: float, rise: float, y: float) -> PackedVector2Array:
	var k: float = (h * h - rise * rise) / (2.0 * rise)
	var r: float = k + rise
	var a0: float = atan2(k, h)          # the springing, as an angle at the centre
	var steps: int = 18
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in range(steps + 1):
		var t: float = (PI - a0) + (2.0 * a0 - PI) * (float(i) / float(steps))
		out.append(Vector2(cos(t) * r, y - k + sin(t) * r))
	return out


static func _rect(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(x, y), Vector2(x + w, y),
		Vector2(x + w, y + h), Vector2(x, y + h),
	])


## Window-pixel polygon to a flat mesh at z = 0, UVs normalised to its own
## bounding box so the spill's radial falloff has something to run on.
static func _poly_mesh(poly: PackedVector2Array) -> ArrayMesh:
	var idx: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
	var lo: Vector2 = poly[0]
	var hi: Vector2 = poly[0]
	for p: Vector2 in poly:
		lo = lo.min(p)
		hi = hi.max(p)
	var span: Vector2 = Vector2(maxf(hi.x - lo.x, 0.001), maxf(hi.y - lo.y, 0.001))
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in idx:
		var p: Vector2 = poly[i]
		st.set_normal(Vector3(0.0, 0.0, 1.0))
		st.set_uv((p - lo) / span)
		st.add_vertex(Vector3(p.x, p.y, 0.0))
	var mesh: ArrayMesh = ArrayMesh.new()
	st.commit(mesh)
	return mesh


func _push_sun(at: Vector2) -> void:
	for m: ShaderMaterial in _sun_mat:
		m.set_shader_parameter("sun", at)


# ---------------------------------------------------------------- the face

## Everything drawn ON the glass. The plate is sized to the glass and placed as
## one piece, so every child can be laid out in window coordinates at build
## time — before this Control has ever been given a size.
func _build_plate() -> void:
	_plate = Control.new()
	_plate.size = _win
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plate)

	var half: Vector2 = _win * 0.5
	for i: int in range(_spoils.size()):
		var x0: float = -half.x + _cell * float(i)
		var face: Control = _spoil_face(_spoils[i],
			_local(Vector2(x0, _y_transom + _head_h)), Vector2(_cell, _head_h))
		_plate.add_child(face)
		_faces.append(face)

	for i: int in range(_card_ids.size()):
		var lx: float = -half.x + float(i) * (LANCET_W + LANCET_GAP)
		var card: CardView = RewardSpoils.card(content, _card_ids[i],
			9000 + i, CARD_SCALE, _take_card)
		var seat: Control = RewardSpoils.pedestal(card, CARD_SCALE)
		seat.position = _local(Vector2(lx, _y_transom)) + Vector2(
			(LANCET_W - CardView.CARD_W * CARD_SCALE) * 0.5,
			(_lancet_h - CardView.CARD_H * CARD_SCALE) * 0.5)
		seat.modulate.a = 0.0
		_plate.add_child(seat)
		_cards.append(card)

	if _has_cards:
		_take_line = _caption("Take one light with you", 13, TEXT_DIM, 3)
		_take_line.size = Vector2(_win.x, 22.0)
		_take_line.position = Vector2(0.0, _win.y + 16.0)
		_take_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_plate.add_child(_take_line)

	_bar_row()


func _bar_row() -> void:
	_bar = HBoxContainer.new()
	_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_bar.add_theme_constant_override("separation", 30)
	_bar.size = Vector2(_win.x, 30.0)
	_bar.position = Vector2(0.0, _win.y + (46.0 if _has_cards else 20.0))
	_plate.add_child(_bar)
	if _has_cards:
		_bar.add_child(_word("Leave it", _skip))
	_bar.add_child(_word("Walk on", _leave))


## A spoil, painted on its pane: the object itself, its name beneath it. The
## art is ALREADY leaded glass — a cut-out object with came around it — so it
## is shown lit rather than silhouetted. Anything else would be painting over
## the one asset that already speaks this language.
func _spoil_face(sp: Dictionary, at: Vector2, cell: Vector2) -> Control:
	var box: Control = Control.new()
	box.position = at
	box.size = cell
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.modulate.a = 0.0

	var art: String = sp["art"]
	var label_y: float = cell.y - 32.0
	if art != "":
		var tex: TextureRect = TextureRect.new()
		tex.texture = load(art) as Texture2D
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.size = Vector2(cell.x, label_y - 6.0)
		tex.position = Vector2(0.0, 5.0)
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(tex)
	else:
		var mark: Label = _caption(str(sp["glyph"]), 46, VITREOUS, 0)
		mark.size = Vector2(cell.x, label_y)
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(mark)

	var name_label: Label = _caption(str(sp["name"]).to_upper(), 14, VITREOUS, 3)
	name_label.position = Vector2(0.0, label_y)
	name_label.size = Vector2(cell.x, 24.0)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)
	return box


func _caption(text: String, px: int, col: Color, tracking: int) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_override("font",
		RewardSpoils.font(GlassStyle.CINZEL_700, tracking))
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Chrome, such as it is: a word. The window is the screen — a filled gold
## button beside it would be the loudest thing on it and would be saying the
## least of anything there.
func _word(text: String, on_press: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", RewardSpoils.font(GlassStyle.CINZEL_700, 3))
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", TEXT_DIM)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_color_override("font_pressed_color", GOLD)
	b.pressed.connect(on_press)
	return b


# ---------------------------------------------------------------- the dawn

func _ready() -> void:
	_place()
	resized.connect(_place)
	var tw: Tween = create_tween().set_parallel(true)
	# _sun_mat holds each pane's sheet and spill adjacently, so integer-halving
	# the index gives the pane number and the pair comes up together.
	for i: int in range(_sun_mat.size()):
		tw.tween_property(_sun_mat[i], "shader_parameter/lit", 1.0, DAWN) \
			.set_delay(float(i / 2) * DAWN_STAGGER).set_trans(Tween.TRANS_SINE)
	for i: int in range(_faces.size()):
		tw.tween_property(_faces[i], "modulate:a", 1.0, DAWN) \
			.set_delay(DAWN_STAGGER * float(i) + 0.06)
	for i: int in range(_cards.size()):
		var seat: Control = _cards[i].get_parent()
		var home: float = seat.position.y
		var wait: float = 0.13 + 0.055 * float(i)
		seat.position.y = home + CARD_RISE
		tw.tween_property(seat, "modulate:a", 1.0, CARD_IN).set_delay(wait)
		tw.tween_property(seat, "position:y", home, CARD_IN + 0.06) \
			.set_delay(wait).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# The news is claimed as it LIGHTS, not when a button is pressed. The signal
	# contract stays per-item and unchanged, so a save still records exactly
	# which pieces of this reward were banked — the player is spared the
	# clicking, not the record.
	for i: int in range(_spoils.size()):
		var what: StringName = _spoils[i]["what"]
		var id: String = _spoils[i]["id"]
		get_tree().create_timer(DAWN_STAGGER * float(i) + DAWN * 0.6) \
			.timeout.connect(func() -> void: claimed.emit(what, id))


## The window is centred, and the plate rides with it, so a card sits in its
## lancet at any screen size without either builder knowing the screen size.
func _place() -> void:
	var centre: Vector2 = size * 0.5
	_stage_rect.position = centre - _stage_size * 0.5
	_plate.position = centre - _win * 0.5


## Window px (origin centre, y up) to plate-local (origin top-left, y down).
func _local(p: Vector2) -> Vector2:
	return Vector2(p.x + _win.x * 0.5, _win.y * 0.5 - p.y)


func _input(event: InputEvent) -> void:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion == null or size.x < 1.0:
		return
	var n: Vector2 = (motion.position / size) * 2.0 - Vector2.ONE
	_push_sun(_sun_home + Vector2(n.x * SUN_SWING.x, -n.y * SUN_SWING.y))


# ---------------------------------------------------------------- the choice

## Answering the offering — with a card id, or "" for Skip. The chosen lancet
## keeps its light and the others go to lead, so what is left on screen is a
## record of what was taken from this window.
func _take_card(id: String) -> void:
	if _picked:
		return
	_picked = true
	var tw: Tween = create_tween().set_parallel(true)
	for i: int in range(_card_ids.size()):
		var chosen: bool = _card_ids[i] == id
		tw.tween_property(_lancet_mat[i], "shader_parameter/gain",
			GAIN_CHOSEN if chosen else GAIN_DEAD, 0.42)
		if not chosen:
			tw.tween_property(_cards[i].get_parent(), "modulate:a", 0.16, 0.32)
		_cards[i].set_playable(false)
	if _take_line != null:
		tw.tween_property(_take_line, "modulate:a", 0.0, 0.24)
	claimed.emit(&"card", id)


func _skip() -> void:
	_take_card("")


func _leave() -> void:
	if not _picked and _has_cards:
		_take_card("")
	finished.emit()


## Save-resume: a reward reopened after a quit shows what is LEFT, not what was
## generated. Mirrors the web's persisted `pendingReward.taken`.
func mark_taken(what: StringName) -> void:
	if what == &"card":
		_picked = true
		for card: CardView in _cards:
			card.get_parent().modulate.a = 0.16
			card.set_playable(false)
		return
	for i: int in range(_spoils.size()):
		var mine: StringName = _spoils[i]["what"]
		if mine == what:
			_faces[i].modulate.a = 0.30


func request_leave() -> void:
	_leave()
