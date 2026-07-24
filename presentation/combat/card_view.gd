class_name CardView
extends Control
## One card, replicated from the visual benchmark (roguecardv2@6e069118, the
## pre-Pixi build). Every number below was measured off that build's DOM rather
## than eyeballed — its stage is 1180x820, the same virtual resolution this
## project uses, so the CSS pixels transfer 1:1 with no conversion.
##
## Benchmark spec, in stage px:
##   card      152 x 216, radius 11, 2px #05070E border, 1px inset rim in the
##             type tint at 0.40 alpha, drop shadow rgba(0,0,0,.55) 0 8 22
##   cost      36 x 36 hexagon hung at (-8, -8), Cinzel 800, ink #241A05
##   art       148 x 91 window, 1px #05070E rule beneath it
##   name      Cinzel 700 @ 13.5, letter-spacing 0.27, #E8DFC8
##   type      Alegreya 400 @ 10, letter-spacing 2.8, uppercase, type tint
##   text      Alegreya 400 @ 12.8, line-height 16.9, #C6CCDF
##   rarity    24 x 5 pill, radius 3, #3C465E, bottom centre
##
## Art is `assets/art/cards/<id>.jpg`, keyed straight off the content id; a card
## with no art on disk falls back to a bare pane. Below the style sits the raw
## pointer surface for the hand's drag state machine — mouse and touch both
## arrive through _gui_input (no emulate_touch_from_mouse); hover exists only on
## the mouse path by nature.

signal pressed_at(uid: int, global_pos: Vector2)
signal moved_to(uid: int, global_pos: Vector2)
signal released_at(uid: int, global_pos: Vector2)
signal hover_changed(uid: int, hovering: bool)

const ART_DIR: String = "res://assets/art/cards/"

const CARD_W: float = 152.0
const CARD_H: float = 216.0
const EDGE: float = 2.0          # card border; the inner column is 148 wide
const ART_H: float = 91.0
const NAME_H: float = 23.0
const TYPE_H: float = 13.0
const GEM: float = 36.0

const PARCHMENT: Color = Color(0.910, 0.875, 0.784)   # #E8DFC8 — name
const INK: Color = Color(0.043, 0.055, 0.102)         # #0B0E1A — card stock
const RULE: Color = Color(0.020, 0.027, 0.055)        # #05070E — borders
const BODY_TEXT: Color = Color(0.776, 0.800, 0.875)   # #C6CCDF — rules
const GEM_INK: Color = Color(0.141, 0.102, 0.020)     # #241A05 — cost numeral
const RARITY: Color = Color(0.235, 0.275, 0.369)      # #3C465E — pill

var uid: int = 0
var card_id: StringName = &""
## "enemy" needs a drop on an enemy; everything else plays on release above the hand.
var target_kind: String = ""
var unplayable: bool = false
var playable: bool = true
## Layout home assigned by HandView._relayout; snap-back target.
var home_position: Vector2 = Vector2.ZERO
var home_rotation: float = 0.0

var _held: bool = false


func _init(inst: CardInst, data: Dictionary, cost: int) -> void:
	uid = inst.uid
	card_id = inst.id
	target_kind = str(data.get("target", ""))
	var unplayable_flag: bool = data.get("unplayable", false)
	unplayable = unplayable_flag
	var ctype: String = str(data.get("type", ""))
	var tint: Color = _type_tint(ctype)
	custom_minimum_size = Vector2(CARD_W, CARD_H)
	size = custom_minimum_size
	pivot_offset = custom_minimum_size * 0.5

	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = INK
	sb.border_color = RULE
	sb.set_border_width_all(int(EDGE))
	sb.set_corner_radius_all(11)
	sb.set_content_margin_all(0)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 4)

	# The face clips (art must not spill past the radius); the cost gem overhangs
	# the corner and must not. So the card itself is a plain Control — a Container
	# here would also re-fit the gem to the card rect and bury its numeral.
	var layer: Panel = Panel.new()
	layer.add_theme_stylebox_override("panel", sb)
	layer.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)

	var art_path: String = ART_DIR + String(inst.id) + ".jpg"
	var art: Texture2D = null
	if ResourceLoader.exists(art_path):
		art = load(art_path) as Texture2D
	if art != null:
		var art_rect: TextureRect = TextureRect.new()
		art_rect.texture = art
		art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		# Source art is 3:2 landscape, the window is 148x91 — cover, don't fit.
		art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art_rect.set_anchors_preset(Control.PRESET_TOP_WIDE)
		art_rect.offset_left = EDGE
		art_rect.offset_right = -EDGE
		art_rect.offset_top = EDGE
		art_rect.offset_bottom = EDGE + ART_H
		art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(art_rect)

	var rule: ColorRect = ColorRect.new()
	rule.color = RULE
	rule.set_anchors_preset(Control.PRESET_TOP_WIDE)
	rule.offset_left = EDGE
	rule.offset_right = -EDGE
	rule.offset_top = EDGE + ART_H
	rule.offset_bottom = EDGE + ART_H + 1.0
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rule)

	# 1px inset rim in the type tint — the benchmark's inner box-shadow.
	var rim: Panel = Panel.new()
	var rim_sb: StyleBoxFlat = StyleBoxFlat.new()
	rim_sb.bg_color = Color(0, 0, 0, 0)
	rim_sb.border_color = Color(tint.r, tint.g, tint.b, 0.40)
	rim_sb.set_border_width_all(1)
	rim_sb.set_corner_radius_all(9)
	rim.add_theme_stylebox_override("panel", rim_sb)
	rim.set_anchors_preset(Control.PRESET_FULL_RECT)
	rim.offset_left = EDGE
	rim.offset_top = EDGE
	rim.offset_right = -EDGE
	rim.offset_bottom = -EDGE
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rim)

	var display_name: String = str(data.get("name", String(inst.id)))
	if inst.up:
		display_name += "+"
	var name_label: Label = Label.new()
	name_label.text = display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font", _font(GlassStyle.CINZEL_700, 0))
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", PARCHMENT)
	name_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	name_label.offset_left = EDGE
	name_label.offset_right = -EDGE
	name_label.offset_top = EDGE + ART_H + 1.0
	name_label.offset_bottom = EDGE + ART_H + 1.0 + NAME_H
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(name_label)

	var type_label: Label = Label.new()
	type_label.text = ctype.to_upper()
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 2.8px of tracking is most of this row's identity — without it the label
	# reads as a caption instead of a rubric.
	type_label.add_theme_font_override("font", _font(GlassStyle.ALEGREYA_400, 3))
	type_label.add_theme_font_size_override("font_size", 10)
	type_label.add_theme_color_override("font_color", tint)
	type_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	type_label.offset_left = EDGE
	type_label.offset_right = -EDGE
	type_label.offset_top = EDGE + ART_H + 1.0 + NAME_H
	type_label.offset_bottom = EDGE + ART_H + 1.0 + NAME_H + TYPE_H
	type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(type_label)

	# Web card text wraps keywords in @…@ / #…# markers, which the benchmark
	# renders as inline tinted spans. Stripped here — inline colouring needs
	# RichTextLabel and is a separate pass.
	var rules_text: String = str(data.get("text", "")).replace("@", "").replace("#", "")
	var body: Label = Label.new()
	body.text = rules_text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_override("font", _font(GlassStyle.ALEGREYA_400, 0))
	body.add_theme_font_size_override("font_size", 13)
	body.add_theme_constant_override("line_spacing", 4)
	body.add_theme_color_override("font_color", BODY_TEXT)
	# Centred in the stock below the rubric, matching the benchmark — a top-anchored
	# block leaves one-liners floating with a hole under them.
	body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.offset_left = 10.0
	body.offset_right = -10.0
	body.offset_top = EDGE + ART_H + 1.0 + NAME_H + TYPE_H
	body.offset_bottom = -14.0
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(body)

	var pill: Panel = Panel.new()
	var pill_sb: StyleBoxFlat = StyleBoxFlat.new()
	pill_sb.bg_color = RARITY
	pill_sb.set_corner_radius_all(3)
	pill.add_theme_stylebox_override("panel", pill_sb)
	pill.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	pill.offset_left = (CARD_W - 24.0) * 0.5
	pill.offset_right = (CARD_W - 24.0) * 0.5 + 24.0
	pill.offset_top = -10.0
	pill.offset_bottom = -5.0
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(pill)

	# The gem overhangs the corner, so it sits outside the clipped subtree.
	_build_cost_gem(cost, tint)

	mouse_entered.connect(func() -> void: hover_changed.emit(uid, true))
	mouse_exited.connect(func() -> void: hover_changed.emit(uid, false))


## A pointy-top hexagon in gold leaf, hung off the top-left corner at (-8, -8).
func _build_cost_gem(cost: int, tint: Color) -> void:
	var holder: Control = Control.new()
	holder.position = Vector2(-8.0, -8.0)
	holder.size = Vector2(GEM, GEM)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.top_level = false
	add_child(holder)

	var hex: Polygon2D = Polygon2D.new()
	hex.polygon = PackedVector2Array([
		Vector2(GEM * 0.5, 0.0), Vector2(GEM, GEM * 0.25),
		Vector2(GEM, GEM * 0.75), Vector2(GEM * 0.5, GEM),
		Vector2(0.0, GEM * 0.75), Vector2(0.0, GEM * 0.25),
	])
	hex.color = Color(0.847, 0.702, 0.361)
	holder.add_child(hex)

	var edge_line: Line2D = Line2D.new()
	var pts: PackedVector2Array = hex.polygon.duplicate()
	pts.append(hex.polygon[0])
	edge_line.points = pts
	edge_line.width = 1.5
	edge_line.default_color = Color(tint.r, tint.g, tint.b, 0.55)
	holder.add_child(edge_line)

	var cost_label: Label = Label.new()
	cost_label.text = "-" if unplayable else str(cost)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_override("font", _font(GlassStyle.CINZEL_800, 0))
	cost_label.add_theme_font_size_override("font_size", 17)
	cost_label.add_theme_color_override("font_color", GEM_INK)
	cost_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(cost_label)


## Cached FontVariations — one per (face, tracking) pair, built once per run.
## Label wants a Font resource, and a fresh FontVariation per label would re-pay
## the shaping setup on every card the hand deals.
static var _font_cache: Dictionary = {}


static func _font(path: String, tracking: int) -> Font:
	var key: String = path + "#" + str(tracking)
	if _font_cache.has(key):
		var hit: Font = _font_cache[key]
		return hit
	var base: FontFile = load(path) as FontFile
	var fv: FontVariation = FontVariation.new()
	fv.base_font = base
	if tracking != 0:
		fv.spacing_glyph = tracking
	_font_cache[key] = fv
	return fv


## Benchmark type tints, sampled from the pre-Pixi build's computed styles.
static func _type_tint(ctype: String) -> Color:
	match ctype:
		"attack":
			return Color(1.000, 0.349, 0.392)   # #FF5964
		"skill":
			return Color(0.306, 0.659, 0.871)   # #4EA8DE
		"power":
			return Color(0.702, 0.533, 1.000)   # #B388FF
		"status":
			return Color(0.498, 0.682, 0.612)   # #7FAE9C
		"curse":
			return Color(0.780, 0.482, 0.831)   # #C77BD4
		_:
			return GlassStyle.GLASS


func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		_press_release(mb.pressed, mb.global_position)
		return
	var st: InputEventScreenTouch = event as InputEventScreenTouch
	if st != null:
		# Touch events carry only a control-local position — lift to global.
		_press_release(st.pressed, get_global_transform() * st.position)
		return
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null and _held:
		moved_to.emit(uid, mm.global_position)
		return
	var sd: InputEventScreenDrag = event as InputEventScreenDrag
	if sd != null and _held:
		moved_to.emit(uid, get_global_transform() * sd.position)


func _press_release(pressed: bool, global_pos: Vector2) -> void:
	if pressed:
		_held = true
		pressed_at.emit(uid, global_pos)
	elif _held:
		_held = false
		released_at.emit(uid, global_pos)


## Grey out cards the player cannot afford / play right now.
func set_playable(can: bool) -> void:
	playable = can
	modulate = Color(1, 1, 1, 1) if can else Color(0.6, 0.6, 0.6, 0.8)


func snap_home() -> void:
	position = home_position
	rotation = home_rotation
	scale = Vector2.ONE
