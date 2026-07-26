class_name RewardReliquary
extends Control
## CONCEPT 「龕」— THE RELIQUARY. No panel. The chest, open, on the ledge you
## fought on, and the offering standing in the light it throws.
##
## THIS IS A MERGE, and worth saying so plainly. The stage, the chest, the pools
## and the embers come from a parallel session's candidate; the information
## architecture comes from this one. Each was carrying the other's missing half.
##
## WHAT THE CANVAS GOT RIGHT. Look at what this game actually draws: the chest
## is a leaded window in a stone arch, the lantern is leaded glass, the phial is
## leaded glass, the stage arch is a cathedral arch. One material, everywhere,
## hand-drawn at 512px — and the ported reward screen rendered all of it at 30px
## inside a rounded rectangle. It was the only screen in the game that did not
## look like the game. Three parallax plates and the chest were already in the
## tree and already used by combat, so the whole backdrop is "stop hiding it".
##
## WHAT IT GOT WRONG, and what this file changes. A reward is four items and
## exactly ONE of them is a decision — nobody has ever declined gold. Every
## candidate so far, including the ported screen, rendered the offering as a
## fourth ROW reading "Add a card to your deck · 3 offered · take one". That is
## a label standing where the only real choice on the screen should be. So here:
##
##   the announcements ARRIVE. Gold, phial and relic rise out of the chest, are
##   claimed as they land, and are never a button. The player is spared the
##   clicking, not the record — `claimed` still fires per item, so a save still
##   knows exactly what was banked.
##
##   the offering IS the screen. Three real CardViews at 178px, the benchmark's
##   own pick size, standing in the chest's light where the label used to be.
##
## THE ONE THING THIS CANVAS COSTS, stated because it is the reason to reject
## it: a painted stage is loud, and the cards have to win against it. They are
## given the brightest band on the screen and the plates are pushed down, but a
## reward screen seen twenty times a run is a place where quiet may simply beat
## beautiful. The window concept is the quiet answer; this is the loud one.
##
## CardView is imported read-only: scaled, seated, never touched. No pose set,
## no lamp moved.

signal claimed(what: StringName, id: String)
signal finished()

const GLASS: Shader = preload("res://presentation/reward/leaded_glass.gdshader")
const ART: String = "res://assets/art/"

## One lamp direction for every bead of came on the screen, or the lead stops
## agreeing with itself — the single thing that separates leaded glass from a
## drawn border.
const LAMP: Vector2 = Vector2(-0.48, -0.88)

const LEAD: Color = Color(0.020, 0.027, 0.055)
const GOLD: Color = Color(0.949, 0.757, 0.306)
const GOLD_DIM: Color = Color(0.612, 0.486, 0.204)
const PARCHMENT: Color = Color(0.910, 0.875, 0.784)
const TEXT: Color = Color(0.843, 0.863, 0.918)
const TEXT_DIM: Color = Color(0.545, 0.576, 0.678)
const BTN_INK: Color = Color(0.102, 0.071, 0.024)
const NIGHT: Color = Color(0.020, 0.027, 0.063)

## The set-out, top to bottom. The offering sits in the middle third because it
## is the decision; the announcements are above it and smaller because they are
## news; the chest is under both because it is where they came from and the
## light has to travel UP through the things it lit.
const TITLE_Y: float = 22.0
const SPOIL_Y: float = 84.0
const SPOIL_ART: float = 66.0
const SPOIL_PITCH: float = 258.0
const CARD_W_OUT: float = 178.0
const CARD_SCALE: float = CARD_W_OUT / CardView.CARD_W
const CARD_GAP: float = 20.0
const CARD_Y: float = 232.0
const LEDGE_Y: float = 502.0
const CHEST_AT: Vector2 = Vector2(590.0, 572.0)
const CHEST_W: float = 268.0

const RISE: float = 0.36             # a spoil coming out of the chest
const RISE_STAGGER: float = 0.075
const RISE_FROM: float = 108.0
const DEAL: float = 0.28
const DEAL_STAGGER: float = 0.065
const DEAL_FROM: float = 34.0

var reward: Dictionary = {}
var content: ContentDB
var encounter_kind: String = "normal"

var _stage: Control = null
var _spoils: Array[Dictionary] = []
var _card_ids: Array[String] = []
var _cards: Array[CardView] = []
var _faces: Array[Control] = []
var _picked: bool = false
## No offering: the announcements drop into the space the cards would have had
## and are shown bigger. A fixed set-out leaves a gold-only win as one small
## coin at the top of a screen with a dead middle — the layout has to contract
## with the haul the same way the window's does, or the thin case looks broken
## rather than modest.
var _lean: bool = false
var _take_line: Label = null
var _bar: HBoxContainer = null

static var _fonts: Dictionary = {}
static var _mips: Dictionary = {}


func _init(reward_ref: Dictionary, content_ref: ContentDB,
		kind: String = "normal") -> void:
	reward = reward_ref
	content = content_ref
	encounter_kind = kind
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_spoils = RewardSpoils.list(reward, content)
	_card_ids = RewardSpoils.card_ids(reward)
	_lean = _card_ids.is_empty()

	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = NIGHT
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_stage = Control.new()
	_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_build()


func _build() -> void:
	# The act's own three plates, pushed well down. They are authored for a LIT
	# combat stage; left at their combat value they out-shout the cards, and the
	# cards are the only thing on this screen anybody has to decide about.
	_plate(ART + "stage/act1-backdrop.png", Rect2(-60.0, 40.0, 1300.0, 500.0),
		Color(0.20, 0.23, 0.36, 1.0))
	_plate(ART + "stage/act1-mid.png", Rect2(240.0, -30.0, 700.0, 520.0),
		Color(0.30, 0.32, 0.44, 1.0))
	_plate(ART + "stage/act1-ledge.png", Rect2(-70.0, LEDGE_Y, 1320.0, 654.0),
		Color(0.34, 0.34, 0.45, 1.0))

	# The chest's light, thrown up the stone — and then a broad cool pool behind
	# the offering, because three cards read against a painted forest only if
	# something puts them in front of it.
	# The big pool is centred ON the ledge's own top edge, not on the chest: the
	# plate lands as a dead-straight seam clean across the screen, and the only
	# thing that dissolves a horizon like that is light sitting on it.
	_pool(Vector2(CHEST_AT.x, LEDGE_Y + 24.0), 940.0, Color(1.0, 0.62, 0.26), 0.46)
	_pool(CHEST_AT + Vector2(0.0, 20.0), 300.0, Color(1.0, 0.80, 0.42), 0.52)
	_pool(Vector2(590.0, CARD_Y + 128.0), 900.0, Color(0.62, 0.74, 1.0), 0.16)

	# The ledge plate meets the backdrop as a dead straight line clean across the
	# screen. Light sitting on it was not enough — so the seam is given the one
	# thing that explains it: a band of shadow along the back edge of the floor,
	# which is where a real ledge is darkest anyway.
	_veil(LEDGE_Y + 26.0, 132.0)

	var chest: TextureRect = _art(ART + "props/chest-open.png", CHEST_W)
	if chest != null:
		_put(chest, Rect2(CHEST_AT.x - CHEST_W * 0.5, CHEST_AT.y - 38.0,
			CHEST_W, CHEST_W * 0.8))
	_embers(Vector2(CHEST_AT.x, CHEST_AT.y + 20.0), 100.0)

	var t: Label = _text(_title_text(), GlassStyle.CINZEL_700, 27, PARCHMENT, 3)
	_put(t, Rect2(0.0, TITLE_Y, 1180.0, 36.0))
	var orn: Label = _text("✦   ✦   ✦", GlassStyle.CINZEL_700, 12, GOLD_DIM, 5)
	_put(orn, Rect2(0.0, TITLE_Y + 40.0, 1180.0, 18.0))

	_build_spoils()
	_build_offering()
	_build_bar()


## The announcements. Objects at the size they were drawn at, with a pool of
## their own tone under each so they are lit BY the scene rather than pasted
## onto it. No frame, no row, no button — there is nothing here to decide.
func _build_spoils() -> void:
	var n: int = _spoils.size()
	for i: int in range(n):
		var sp: Dictionary = _spoils[i]
		var pitch: float = SPOIL_PITCH * (1.30 if _lean else 1.0)
		var art_h: float = SPOIL_ART * (1.75 if _lean else 1.0)
		var top: float = 286.0 if _lean else SPOIL_Y
		var x: float = 590.0 + (float(i) - float(n - 1) * 0.5) * pitch
		var box: Control = Control.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.modulate.a = 0.0
		_put(box, Rect2(x - pitch * 0.5, top, pitch, art_h + 62.0))

		var tone: Color = sp["tone"]
		var halo: TextureRect = _radial_rect(tone, 0.34)
		var glow: float = art_h * 3.0
		halo.position = Vector2(pitch * 0.5 - glow * 0.5, art_h * 0.5 - glow * 0.5)
		halo.size = Vector2(glow, glow)
		box.add_child(halo)

		var art: String = sp["art"]
		if art != "":
			var icon: TextureRect = _art(art, SPOIL_ART)
			if icon != null:
				# The box is WIDER than it is tall on purpose. The coin is square
				# and the relics are 512x341; fit both into a square and the
				# landscape ones come out two-thirds the height, so the relic
				# reads as the least of three announcements when it is the most.
				# Constraining the HEIGHT is what makes them one family.
				var w: float = art_h * 1.7
				icon.position = Vector2(pitch * 0.5 - w * 0.5, 0.0)
				icon.size = Vector2(w, art_h)
				box.add_child(icon)
		var name_l: Label = _text(str(sp["name"]), GlassStyle.ALEGREYA_700,
			20 if _lean else 17, PARCHMENT, 0)
		name_l.position = Vector2(0.0, art_h + 8.0)
		name_l.size = Vector2(pitch, 24.0)
		box.add_child(name_l)
		var sub: String = sp["sub"]
		if sub != "":
			var sub_l: Label = _text(sub, GlassStyle.ALEGREYA_400, 13, TEXT_DIM, 0)
			sub_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			sub_l.position = Vector2(14.0, art_h + 34.0)
			sub_l.size = Vector2(pitch - 28.0, 40.0)
			box.add_child(sub_l)
		_faces.append(box)


## The decision, at the benchmark's own pick size, standing where the label
## used to be.
func _build_offering() -> void:
	var n: int = _card_ids.size()
	if n == 0:
		return
	var w: float = CardView.CARD_W * CARD_SCALE
	var span: float = float(n) * w + float(n - 1) * CARD_GAP
	for i: int in range(n):
		var card: CardView = RewardSpoils.card(content, _card_ids[i],
			9200 + i, CARD_SCALE, _take_card)
		var seat: Control = RewardSpoils.pedestal(card, CARD_SCALE)
		var home: Vector2 = Vector2(590.0 - span * 0.5
			+ float(i) * (w + CARD_GAP), CARD_Y)
		seat.set_meta("home", home)
		seat.position = home + Vector2(0.0, DEAL_FROM)
		seat.modulate.a = 0.0
		# Cards take clicks; everything else on this screen is scenery, so the
		# offering is the one thing added outside _put's ignore-all filter.
		_stage.add_child(seat)
		seat.mouse_filter = Control.MOUSE_FILTER_PASS
		_cards.append(card)

	_take_line = _text("Take one from the light", GlassStyle.CINZEL_700, 13,
		TEXT_DIM, 3)
	_put(_take_line, Rect2(0.0, CARD_Y + CardView.CARD_H * CARD_SCALE + 12.0,
		1180.0, 20.0))


func _build_bar() -> void:
	_bar = HBoxContainer.new()
	_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_bar.add_theme_constant_override("separation", 32)
	_bar.position = Vector2(0.0, 778.0)
	_bar.size = Vector2(1180.0, 30.0)
	_stage.add_child(_bar)
	if not _card_ids.is_empty():
		_bar.add_child(_word("Leave it", _skip))
	_bar.add_child(_word("Walk on", _leave))


func _title_text() -> String:
	return "ELITE SLAIN" if encounter_kind == "elite" else "VICTORY"


func _word(text: String, on_press: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", _font(GlassStyle.CINZEL_700, 3))
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", PARCHMENT)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_color_override("font_pressed_color", GOLD)
	b.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	b.pressed.connect(on_press)
	return b


# ------------------------------------------------------------------ the rise

func _ready() -> void:
	var tw: Tween = create_tween().set_parallel(true)
	for i: int in range(_faces.size()):
		var face: Control = _faces[i]
		var home: float = face.position.y
		var wait: float = 0.10 + RISE_STAGGER * float(i)
		face.position.y = home + RISE_FROM
		tw.tween_property(face, "modulate:a", 1.0, RISE).set_delay(wait)
		tw.tween_property(face, "position:y", home, RISE + 0.10).set_delay(wait) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for i: int in range(_cards.size()):
		var seat: Control = _cards[i].get_parent()
		var at: Vector2 = seat.get_meta("home")
		var wait: float = 0.26 + DEAL_STAGGER * float(i)
		tw.tween_property(seat, "modulate:a", 1.0, DEAL).set_delay(wait)
		tw.tween_property(seat, "position", at, DEAL + 0.08).set_delay(wait) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Claimed as it LANDS, not when a button is pressed. The contract is
	# unchanged; only the clicking is gone.
	for i: int in range(_spoils.size()):
		var what: StringName = _spoils[i]["what"]
		var id: String = _spoils[i]["id"]
		get_tree().create_timer(0.10 + RISE_STAGGER * float(i) + RISE * 0.7) \
			.timeout.connect(func() -> void: claimed.emit(what, id))


func _take_card(id: String) -> void:
	if _picked:
		return
	_picked = true
	var tw: Tween = create_tween().set_parallel(true)
	for i: int in range(_card_ids.size()):
		if _card_ids[i] != id:
			tw.tween_property(_cards[i].get_parent(), "modulate:a", 0.15, 0.30)
		_cards[i].set_playable(false)
	if _take_line != null:
		tw.tween_property(_take_line, "modulate:a", 0.0, 0.22)
	claimed.emit(&"card", id)


func _skip() -> void:
	_take_card("")


func _leave() -> void:
	if not _picked and not _card_ids.is_empty():
		_take_card("")
	finished.emit()


func mark_taken(what: StringName) -> void:
	if what == &"card":
		_picked = true
		for card: CardView in _cards:
			card.get_parent().modulate.a = 0.15
			card.set_playable(false)
		return
	for i: int in range(_spoils.size()):
		var mine: StringName = _spoils[i]["what"]
		if mine == what:
			_faces[i].modulate.a = 0.26


func request_leave() -> void:
	_leave()


# ------------------------------------------------------------------- the kit

func _put(node: Control, r: Rect2) -> void:
	node.set_anchors_preset(Control.PRESET_TOP_LEFT)
	node.position = r.position
	node.size = r.size
	node.custom_minimum_size = r.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(node)


## A parallax plate, dimmed to sit behind a light source rather than in front
## of one — the plates are authored for a lit combat stage.
func _plate(path: String, r: Rect2, dim: Color) -> void:
	var t: Texture2D = _mip(path)
	if t == null:
		return
	var tr: TextureRect = TextureRect.new()
	tr.texture = t
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tr.modulate = dim
	_put(tr, r)


## A pool of light: additive, so it lifts what is under it instead of veiling
## it. The cheap half of a Light2D and all this needs — the expensive half (the
## plates going properly dark away from it) wants a CanvasModulate, and that
## belongs to the shipping screen rather than a candidate.
func _pool(at: Vector2, size: float, tone: Color, strength: float) -> void:
	var tr: TextureRect = _radial_rect(tone, strength)
	_put(tr, Rect2(at.x - size * 0.5, at.y - size * 0.5, size, size))


## A soft horizontal band of night, to lose a seam in.
func _veil(at_y: float, h: float) -> void:
	var tr: TextureRect = TextureRect.new()
	tr.texture = GlassStyle.grad_tex(
		PackedColorArray([Color(NIGHT, 0.0), Color(NIGHT, 0.92), Color(NIGHT, 0.0)]),
		PackedFloat32Array([0.0, 0.46, 1.0]), false,
		Vector2(0.5, 0.0), Vector2(0.5, 1.0))
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	_put(tr, Rect2(0.0, at_y - h * 0.5, 1180.0, h))


func _radial_rect(tone: Color, strength: float) -> TextureRect:
	var tr: TextureRect = TextureRect.new()
	tr.texture = _radial(tone)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.modulate = Color(1, 1, 1, strength)
	var cm: CanvasItemMaterial = CanvasItemMaterial.new()
	cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	tr.material = cm
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func _embers(at: Vector2, spread: float) -> void:
	var p: GPUParticles2D = GPUParticles2D.new()
	p.amount = 70
	p.lifetime = 3.4
	p.preprocess = 3.4          # already burning when the screen opens
	p.texture = _radial(Color(1.0, 0.78, 0.42))
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(spread, 6.0, 1.0)
	pm.direction = Vector3(0.0, -1.0, 0.0)
	pm.spread = 26.0
	pm.initial_velocity_min = 18.0
	pm.initial_velocity_max = 54.0
	pm.gravity = Vector3(0.0, -22.0, 0.0)
	pm.scale_min = 0.012
	pm.scale_max = 0.045
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color(1.0, 0.80, 0.45, 0.0))
	ramp.set_color(1, Color(1.0, 0.45, 0.16, 0.0))
	ramp.add_point(0.18, Color(1.0, 0.86, 0.55, 0.95))
	var ramp_t: GradientTexture1D = GradientTexture1D.new()
	ramp_t.gradient = ramp
	pm.color_ramp = ramp_t
	p.process_material = pm
	var cm: CanvasItemMaterial = CanvasItemMaterial.new()
	cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = cm
	p.position = at
	_stage.add_child(p)


func _art(path: String, w: float) -> TextureRect:
	var t: Texture2D = _mip(path)
	if t == null:
		return null
	var tr: TextureRect = TextureRect.new()
	tr.texture = t
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tr.custom_minimum_size = Vector2(w, w)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


static func _text(s: String, path: String, sz: int, col: Color,
		track: int) -> Label:
	var l: Label = Label.new()
	l.text = s
	l.add_theme_font_override("font", _font(path, track))
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	# Everything here stands on a painted stage, so every glyph carries its own
	# ground. Without the outline the sub lines die into the forest.
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.add_theme_constant_override("shadow_outline_size", 3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func _font(path: String, tracking: int) -> Font:
	var key: String = path + "#" + str(tracking)
	if _fonts.has(key):
		var hit: Font = _fonts[key]
		return hit
	var fv: FontVariation = FontVariation.new()
	fv.base_font = load(path) as FontFile
	if tracking != 0:
		fv.spacing_glyph = tracking
	_fonts[key] = fv
	return fv


## Art is authored at 512 and drawn here at 72-300. Without a mip chain that is
## a shimmering mess; SKILL §4 forbids hand-editing .import sidecars, so the
## chain is built at load and the sampler asked for it.
static func _mip(path: String) -> Texture2D:
	if _mips.has(path):
		var hit: Texture2D = _mips[path]
		return hit
	if not ResourceLoader.exists(path):
		push_warning("reward reliquary: missing art %s" % path)
		return null
	var src: Texture2D = load(path) as Texture2D
	if src == null:
		return null
	var img: Image = src.get_image()
	img.generate_mipmaps()
	var out: Texture2D = ImageTexture.create_from_image(img)
	_mips[path] = out
	return out


static func _radial(tone: Color) -> GradientTexture2D:
	var g: Gradient = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([tone, Color(tone.r, tone.g, tone.b, 0.0)])
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	return tex
