class_name RewardEmbers
extends Control
## CONCEPT 「燼」— THE EMBERS. The reward is not handed to you by a menu. It is
## what you broke, still in the colour of the thing you broke it out of.
##
## THE ARGUMENT. Every reward screen in the genre has the same hole in it: the
## fight ends, the fight vanishes, and an unrelated panel slides in carrying
## numbers. Nothing on it came from anywhere. Here the screen OPENS on the husk
## the enemy died as — GlassGem's own silhouette, its own dead colours — and
## the spoils are cut out of it. The gold was its light. The cards are its
## biggest pieces. Nothing arrives from off-screen, because nothing needs to.
##
## WHAT THIS BUYS THAT ART CANNOT. The palette is the ENEMY'S hue, straight off
## `art.hue` in content. Duskfang pays out at 22 degrees and a glass construct
## pays out cold, so two fights produce visibly different reward screens with
## no second asset drawn and no second code path. That is a whole axis of
## variety for one float, and it is variety the player can feel without ever
## being able to name it.
##
## WHY IT IS 2D AND THE WINDOW IS NOT. The window is CardView's sibling: a face
## on real geometry under a real lamp. This is GlassGem's sibling — pure _draw,
## no art, no viewport, a silhouette and a fill. The two concepts are arguing
## about what a reward IS, so it would be dishonest to let one of them win on
## rendering budget. This one costs a redraw.
##
## THE ONE COST, STATED PLAINLY: this screen needs the enemy's hue, and a
## reward Dictionary does not carry one. `hue` is a constructor argument, and
## whoever wires this into main must pass the hue of what just died — the same
## `art.hue` EnemyView already reads. Given nothing, it falls back to ember and
## the concept still works, it just stops being about the fight you had.

signal claimed(what: StringName, id: String)
signal finished()

const EMBER_HUE: float = 22.0        # the fallback: lantern-fire, Duskfang's own

## THE HUSK. GlassGem's cut, at the size a thing that just died should be. The
## silhouette is reproduced rather than imported because GlassGem is a live
## combat node with its own state contract; what is wanted here is its SHAPE.
const HUSK_R: Vector2 = Vector2(132.0, 152.0)
const HUSK_AT: Vector2 = Vector2(0.0, -84.0)

## The break. Six facets, each split once more, is fourteen pieces — enough to
## read as shattered, few enough that every piece is still a shape rather than
## a speck.
const RING: int = 6
const SPLIT: int = 2
## How far a piece is thrown, as a multiple of where it already sat. Past about
## 2 the wreckage leaves the frame and the break stops reading as a break.
const THROW: float = 1.92

const SEAT: Vector2 = Vector2(196.0, 132.0)   # a spoil's own piece of the husk
const SEAT_GAP: float = 34.0
const SEAT_Y: float = -132.0
const ART_H: float = 76.0

const CARD_W_OUT: float = 178.0
const CARD_SCALE: float = CARD_W_OUT / CardView.CARD_W
const CARD_GAP: float = 22.0
const CARD_Y: float = 116.0

const BURST: float = 0.62            # the husk coming apart
const HOLD: float = 0.18             # ...after a beat of it just sitting there
const CARD_IN: float = 0.30
const COOL: float = 0.34             # ember -> the item's own colour

const DEBRIS_A: float = 0.15
const TEXT: Color = Color(0.843, 0.863, 0.918)
const TEXT_DIM: Color = Color(0.545, 0.576, 0.678)
const GOLD: Color = Color(0.949, 0.757, 0.306)

var reward: Dictionary = {}
var content: ContentDB
var encounter_kind: String = "normal"
var hue: float = EMBER_HUE

## Every piece: a polygon in husk-local coordinates plus where it ends up.
## `seat` is -1 for debris, otherwise the spoil index it carries.
var _shards: Array[Dictionary] = []
var _burst: float = 0.0
var _cool: float = 0.0
var _field: Control = null           # the debris layer; draws, takes no input
var _plate: Control = null
var _spoils: Array[Dictionary] = []
var _card_ids: Array[String] = []
var _cards: Array[CardView] = []
var _faces: Array[Control] = []
var _picked: bool = false
var _take_line: Label = null
var _bar: HBoxContainer = null
var _centre: Vector2 = Vector2.ZERO


func _init(reward_ref: Dictionary, content_ref: ContentDB,
		kind: String = "normal", enemy_hue: float = -1.0) -> void:
	reward = reward_ref
	content = content_ref
	encounter_kind = kind
	hue = EMBER_HUE if enemy_hue < 0.0 else enemy_hue
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_spoils = RewardSpoils.list(reward, content)
	_card_ids = RewardSpoils.card_ids(reward)

	var ground: ColorRect = ColorRect.new()
	ground.color = Color(0.012, 0.016, 0.038, 0.93)
	ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)

	# The heat the husk is still giving off, in its own hue. It sits under
	# everything and is the only thing on screen that is not a shard.
	var glow: TextureRect = TextureRect.new()
	glow.texture = GlassStyle.grad_tex(
		PackedColorArray([Color(_hue_at(0.62, 0.55), 0.20),
			Color(_hue_at(0.62, 0.30), 0.0)]),
		PackedFloat32Array([0.0, 1.0]), true, Vector2(0.5, 0.5), Vector2(1.0, 0.5))
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)

	_field = Control.new()
	_field.set_anchors_preset(Control.PRESET_FULL_RECT)
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field.draw.connect(_draw_field)
	add_child(_field)

	_build_shards()
	_build_plate()


func _hue_at(sat: float, val: float) -> Color:
	return Color.from_hsv(fmod(hue, 360.0) / 360.0, sat, val)


# ---------------------------------------------------------------- the break

## Cut the husk into pieces the way it was built: six facets around a centre,
## each halved. Every shard is therefore a real slice of the silhouette rather
## than a random triangle scattered near it, which is why the assembled state
## reads as an intact gem instead of a pile that happens to overlap.
func _build_shards() -> void:
	var outline: PackedVector2Array = _husk_outline()
	var wedge: int = 0
	for i: int in range(RING):
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % RING]
		for s: int in range(SPLIT):
			var t0: float = float(s) / float(SPLIT)
			var t1: float = float(s + 1) / float(SPLIT)
			var poly: PackedVector2Array = PackedVector2Array([
				Vector2.ZERO, a.lerp(b, t0), a.lerp(b, t1),
			])
			# Debris keeps the direction it broke in — thrown out along its own
			# midline and settling a little low, because it is falling, not
			# radiating. THROW is deliberately modest: a piece that leaves the
			# frame stops being wreckage and becomes a transition wipe.
			var mid: Vector2 = (poly[1] + poly[2]) * 0.5
			# Every wedge thrown the SAME multiple lands the debris on a clock
			# face — twelve triangles at twelve even radii, which is the one
			# thing wreckage never looks like. The golden-ratio walk gives each
			# piece its own distance and stays reproducible, so a shot of this
			# screen is the same shot tomorrow.
			var far: float = THROW * (0.62 + 0.85
				* fmod(float(wedge) * 0.6180339887 + 0.17, 1.0))
			_shards.append({
				"poly": poly,
				"home": HUSK_AT + mid * far + Vector2(0.0, 34.0),
				"seat": -1,
				"spin": (fmod(float(wedge) * 0.6180339887, 1.0) - 0.5) * 0.7,
				"lit": 0.30 + 0.55 * float((i * SPLIT + s) % 3) / 2.0,
			})
			wedge += 1
	# The seats are their OWN pieces, not promoted wedges. A wedge is a thin
	# triangle running to a point at the husk's centre; scaling one up until it
	# could carry a 196px item makes a spike, not a plate. These are cut to the
	# size the job needs and jittered so the three are not one shape stamped
	# three times.
	var seats: Array[Vector2] = _seat_positions()
	for i: int in range(seats.size()):
		_shards.append({
			"poly": _slab(i),
			"home": seats[i],
			"seat": i,
			"spin": (fmod(float(i) * 0.6180339887 + 0.31, 1.0) - 0.5) * 0.5,
			"lit": 0.62 + 0.16 * float(i % 2),
		})


## A slab of the husk big enough to set something on. Five points rather than
## four so no edge is parallel to its opposite and it never reads as a card.
static func _slab(i: int) -> PackedVector2Array:
	var j: float = fmod(float(i) * 0.7548776662, 1.0) - 0.5    # -0.5 .. 0.5
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(-0.50, -0.46 + 0.10 * j), Vector2(0.42 - 0.08 * j, -0.50),
		Vector2(0.50, 0.34), Vector2(0.12 + 0.14 * j, 0.50),
		Vector2(-0.46, 0.40 + 0.08 * j),
	])
	var out: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in pts:
		out.append(p * SEAT)
	return out


func _husk_outline() -> PackedVector2Array:
	# GlassGem's cut: crown point, shoulders, lower corners, cutlet point.
	return PackedVector2Array([
		Vector2(0.0, -HUSK_R.y),
		Vector2(HUSK_R.x, -HUSK_R.y * 0.28),
		Vector2(HUSK_R.x * 0.52, HUSK_R.y * 0.58),
		Vector2(0.0, HUSK_R.y),
		Vector2(-HUSK_R.x * 0.52, HUSK_R.y * 0.58),
		Vector2(-HUSK_R.x, -HUSK_R.y * 0.28),
	])


func _seat_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var n: int = _spoils.size()
	var span: float = float(n) * SEAT.x + float(maxi(0, n - 1)) * SEAT_GAP
	for i: int in range(n):
		out.append(Vector2(-span * 0.5 + SEAT.x * 0.5
			+ float(i) * (SEAT.x + SEAT_GAP), SEAT_Y))
	return out


## The debris and the seats, in one pass. Drawn rather than instanced because
## every piece is a flat polygon with one colour and a rim — a Control each
## would be forty nodes to say what one _draw says.
func _draw_field() -> void:
	for shard: Dictionary in _shards:
		var seat: int = shard["seat"]
		var at: Vector2 = _centre + _shard_at(shard)
		var spin_at: float = shard["spin"]
		var spin: float = spin_at * (1.0 - _burst)
		# A seat GROWS into its plate — on the way out it is still part of the
		# husk. Debris does the opposite and shrinks: a piece that keeps its full
		# size all the way out reads as a shape someone placed, where the same
		# piece at half size reads as something that came off.
		var scale: float = lerpf(1.0, 0.52, _burst) if seat < 0 \
			else lerpf(0.24, 1.0, _burst)
		var lit: float = shard["lit"]

		var tone: Color = _hue_at(0.55, 0.30 + 0.34 * lit)
		var rim: Color = _hue_at(0.35, 0.62 + 0.30 * lit)
		if seat >= 0:
			# A seat cools out of the husk's hue and into the item's own, which
			# is the whole claim: this piece WAS the enemy and is now yours.
			var mine: Color = _spoils[seat]["tone"]
			tone = tone.lerp(Color(mine.r * 0.42, mine.g * 0.42, mine.b * 0.42), _cool)
			rim = rim.lerp(mine, _cool)
		var alpha: float = 1.0 if seat >= 0 else lerpf(1.0, DEBRIS_A, _burst)

		var pts: PackedVector2Array = PackedVector2Array()
		var src: PackedVector2Array = shard["poly"]
		for p: Vector2 in src:
			pts.append(at + p.rotated(spin) * scale)
		_field.draw_colored_polygon(pts, Color(tone, alpha))
		var loop: PackedVector2Array = pts.duplicate()
		loop.append(pts[0])
		_field.draw_polyline(loop, Color(rim, alpha * 0.85), 1.6)


## Where a piece is right now: still in the husk at 0, at its resting place at
## 1, and thrown a little past it in between so the break has some weight.
func _shard_at(shard: Dictionary) -> Vector2:
	var home: Vector2 = shard["home"]
	var over: float = sin(_burst * PI) * 0.16
	return HUSK_AT.lerp(home, _burst) \
		+ (home - HUSK_AT).normalized() * over * 60.0


# ---------------------------------------------------------------- the face

func _build_plate() -> void:
	_plate = Control.new()
	_plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plate)

	var seats: Array[Vector2] = _seat_positions()
	for i: int in range(_spoils.size()):
		var face: Control = _spoil_face(_spoils[i], seats[i])
		_plate.add_child(face)
		_faces.append(face)

	for i: int in range(_card_ids.size()):
		var card: CardView = RewardSpoils.card(content, _card_ids[i],
			9100 + i, CARD_SCALE, _take_card)
		var seat: Control = RewardSpoils.pedestal(card, CARD_SCALE)
		seat.set_meta("home", _card_home(i))
		seat.modulate.a = 0.0
		_plate.add_child(seat)
		_cards.append(card)

	if not _card_ids.is_empty():
		_take_line = _caption("One piece comes with you", 13, TEXT_DIM, 3)
		_take_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_plate.add_child(_take_line)

	_bar = HBoxContainer.new()
	_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_bar.add_theme_constant_override("separation", 30)
	_plate.add_child(_bar)
	if not _card_ids.is_empty():
		_bar.add_child(_word("Leave it", _skip))
	_bar.add_child(_word("Walk on", _leave))


func _card_home(i: int) -> Vector2:
	var n: int = _card_ids.size()
	var w: float = CardView.CARD_W * CARD_SCALE
	var h: float = CardView.CARD_H * CARD_SCALE
	var span: float = float(n) * w + float(maxi(0, n - 1)) * CARD_GAP
	return Vector2(-span * 0.5 + float(i) * (w + CARD_GAP), CARD_Y - h * 0.5)


func _spoil_face(sp: Dictionary, at: Vector2) -> Control:
	var box: Control = Control.new()
	box.size = SEAT
	box.set_meta("home", at - SEAT * 0.5)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.modulate.a = 0.0

	var art: String = sp["art"]
	if art != "":
		var tex: TextureRect = TextureRect.new()
		tex.texture = load(art) as Texture2D
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.size = Vector2(SEAT.x, ART_H)
		tex.position = Vector2(0.0, 2.0)
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(tex)
	else:
		var mark: Label = _caption(str(sp["glyph"]), 44, TEXT, 0)
		mark.size = Vector2(SEAT.x, ART_H)
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(mark)

	# Light text here, not the window's dark paint: nothing is backlit on this
	# screen, so ink would simply be a hole.
	var name_label: Label = _caption(str(sp["name"]).to_upper(), 13, TEXT, 3)
	name_label.position = Vector2(0.0, ART_H + 6.0)
	name_label.size = Vector2(SEAT.x, 22.0)
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


# ---------------------------------------------------------------- the burst

func _ready() -> void:
	_place()
	resized.connect(_place)
	var tw: Tween = create_tween()
	# A beat of the husk just sitting there before it goes. Without it the
	# break has nothing to be a break FROM and reads as a transition.
	tw.tween_interval(HOLD)
	tw.tween_method(_set_burst, 0.0, 1.0, BURST).set_trans(Tween.TRANS_QUINT) \
		.set_ease(Tween.EASE_OUT)
	var after: Tween = create_tween().set_parallel(true)
	after.tween_method(_set_cool, 0.0, 1.0, COOL).set_delay(HOLD + BURST * 0.55)
	for i: int in range(_faces.size()):
		after.tween_property(_faces[i], "modulate:a", 1.0, 0.24) \
			.set_delay(HOLD + BURST * 0.62 + 0.05 * float(i))
	for i: int in range(_cards.size()):
		var seat: Control = _cards[i].get_parent()
		var home: Vector2 = seat.get_meta("home")
		var wait: float = HOLD + BURST * 0.7 + 0.06 * float(i)
		seat.position = _centre + home + Vector2(0.0, 34.0)
		after.tween_property(seat, "modulate:a", 1.0, CARD_IN).set_delay(wait)
		after.tween_property(seat, "position", _centre + home, CARD_IN + 0.08) \
			.set_delay(wait).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for i: int in range(_spoils.size()):
		var what: StringName = _spoils[i]["what"]
		var id: String = _spoils[i]["id"]
		get_tree().create_timer(HOLD + BURST * 0.62 + 0.05 * float(i)) \
			.timeout.connect(func() -> void: claimed.emit(what, id))


func _set_burst(v: float) -> void:
	_burst = v
	_field.queue_redraw()
	_place_faces()


func _set_cool(v: float) -> void:
	_cool = v
	_field.queue_redraw()


func _place() -> void:
	_centre = size * 0.5
	_field.queue_redraw()
	_place_faces()
	if _take_line != null:
		_take_line.size = Vector2(size.x, 22.0)
		_take_line.position = Vector2(0.0, _centre.y + CARD_Y
			+ CardView.CARD_H * CARD_SCALE * 0.5 + 16.0)
	if _bar != null:
		_bar.size = Vector2(size.x, 30.0)
		_bar.position = Vector2(0.0, _centre.y + CARD_Y
			+ CardView.CARD_H * CARD_SCALE * 0.5 + 44.0)


## Faces ride their shard out rather than appearing where it lands, so the item
## and the piece carrying it are never two separate events.
func _place_faces() -> void:
	for i: int in range(_faces.size()):
		var home: Vector2 = _faces[i].get_meta("home")
		_faces[i].position = _centre + home \
			+ (HUSK_AT - home) * (1.0 - _burst) * 0.35


# ---------------------------------------------------------------- the choice

func _take_card(id: String) -> void:
	if _picked:
		return
	_picked = true
	var tw: Tween = create_tween().set_parallel(true)
	for i: int in range(_card_ids.size()):
		if _card_ids[i] != id:
			tw.tween_property(_cards[i].get_parent(), "modulate:a", 0.14, 0.30)
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
			card.get_parent().modulate.a = 0.14
			card.set_playable(false)
		return
	for i: int in range(_spoils.size()):
		var mine: StringName = _spoils[i]["what"]
		if mine == what:
			_faces[i].modulate.a = 0.28


func request_leave() -> void:
	_leave()
