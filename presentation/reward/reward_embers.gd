class_name RewardEmbers
extends Control
## CONCEPT 「燼」— THE EMBERS. The reward is not handed to you by a menu. It is
## what you broke, still in the colour of the thing you broke it out of.
##
## THE ARGUMENT. Every reward screen in the genre has the same hole in it: the
## fight ends, the fight vanishes, and an unrelated panel slides in carrying
## numbers. Nothing on it came from anywhere. Here the screen OPENS on the husk
## the enemy died as — GlassGem's own cut, its own dead colours — the cracks
## take light, and it comes apart. The spoils are the three biggest pieces. The
## gold was its light. Nothing arrives from off-screen because nothing needs to.
##
## WHAT THIS BUYS THAT ART CANNOT. The palette is the ENEMY'S hue, straight off
## `art.hue` in content. Duskfang pays out at 22 degrees, a glass construct pays
## out cold, and the two produce visibly different reward screens with no second
## asset drawn and no second code path. A whole axis of variety for one float —
## and variety the player feels without ever being able to name it.
##
## ── WHAT MAKES IT GLASS, which is the whole of the second pass ────────────
##
## THE FRACTURE EDGE IS THE BRIGHTEST PART. This is the one optical fact that
## decides whether a shape reads as broken glass or as a polygon someone filled
## in. A cut edge gathers light along its whole length and throws it at you; the
## body is comparatively dark. The first version drew a uniform 1.6px outline
## and that is exactly what a vector shape looks like.
##
## AND IT IS BRIGHT UNEVENLY. A uniform bright outline is only a second kind of
## sticker. Each edge is lit by where it FACES: the rim is drawn per-edge, its
## width and heat set by that edge's outward normal against the real light in
## the scene. Edges turned toward the bed blaze and thicken, edges turned away
## go to a dark line. That single term is what makes a flat polygon read as a
## solid with a near side and a far side.
##
## THE LIGHT IS IN THE SCENE, NOT IN A CONSTANT. Every rim, every body glow and
## every ember is lit from the bed where the husk fell — one position, and every
## piece computes its own direction to it. Which is also why the pieces near the
## bed are the hot ones and the pieces thrown clear are nearly cold, for free.
##
## THINGS MUST REST ON SOMETHING. Wreckage floating in black is not wreckage.
## There is a floor: a horizon of ember light where the husk came down, debris
## lying along it, and the offering standing IN FRONT of it — so the cards are
## backlit by the thing they were cut out of.
##
## Angle and position, never TIME — the rule card_surface.gdshader works under.
## Once the break has settled nothing here animates; every value is geometry
## against a light, so the screen at rest is still a material.
##
## THE ONE COST, STATED PLAINLY: this screen needs the enemy's hue, and a reward
## Dictionary does not carry one. `hue` is a constructor argument and whoever
## wires this into main must pass the hue of what just died — the same
## `art.hue` EnemyView already reads. Given nothing it falls back to ember, and
## the concept still works, it just stops being about the fight you had.

signal claimed(what: StringName, id: String)
signal finished()

const EMBER_HUE: float = 22.0        # the fallback: lantern-fire, Duskfang's own

## THE HUSK. GlassGem's cut, at the size a thing that just died should be. The
## silhouette is reproduced rather than imported because GlassGem is a live
## combat node with its own state contract; what is wanted here is its SHAPE.
const HUSK_R: Vector2 = Vector2(126.0, 146.0)
const HUSK_AT: Vector2 = Vector2(0.0, -46.0)

## The break: six facets, each split, is twelve pieces — enough to read as
## shattered, few enough that every piece is still a shape and not a speck.
const RING: int = 6
const SPLIT: int = 2
const THROW: float = 2.15

## Where everything comes to rest, as offsets from the screen's centre.
const SEAT: Vector2 = Vector2(198.0, 128.0)
const SEAT_GAP: float = 40.0
const SEAT_Y: float = -272.0
## No offering: the one announcement drops toward the fire and the chrome comes
## up under it. Held at the full set-out, a gold-only win is a slab at the top,
## a fire in the middle and three hundred empty pixels of nothing — the layout
## has to contract with the haul or the thin case reads as broken.
const SEAT_Y_LEAN: float = -188.0
const LEAN_FOOT: float = 188.0
## What hangs below the rack: the take line, then the word row under it.
const FOOT_REACH: float = 72.0
## How far a seat slab reaches above its own centre, as a fraction of SEAT —
## `_slab`'s highest vertex, with a little over for the spin.
const SEAT_RISE: float = 0.58
const ART_H: float = 74.0
## The bed: where the husk came down, and the only light in the scene. It gets
## its own band. Parked behind the rack its hot core sat squarely under three
## opaque cards — the brightest thing on the screen, invisible, with only the
## dim outer throw showing past the edges. A light source has to be somewhere
## you can see it lighting things.
const BED_Y: float = -46.0
const BED_W: float = 1080.0
const BED_H: float = 216.0

const CARD_W_OUT: float = 178.0
const CARD_SCALE: float = CARD_W_OUT / CardView.CARD_W
const CARD_GAP: float = 22.0
const CARD_Y: float = 26.0           # top of the rack — it stands IN the bed

const SIT: float = 0.18              # the husk, whole, before anything
const BLAZE: float = 0.10            # the cracks taking light
const BURST: float = 0.46            # it coming apart
const COOL: float = 0.40             # white-hot fracture -> the item's colour
const CARD_IN: float = 0.28
const DEBRIS_A: float = 0.90

const TEXT: Color = Color(0.902, 0.914, 0.949)
const TEXT_DIM: Color = Color(0.600, 0.628, 0.706)
const GOLD: Color = Color(0.949, 0.757, 0.306)
const NIGHT: Color = Color(0.012, 0.015, 0.032)

var reward: Dictionary = {}
var content: ContentDB
var encounter_kind: String = "normal"
var hue: float = EMBER_HUE
## WHAT THE SCREEN MAY NOT DRAW INTO. This screen does not get the whole canvas.
## In the viewer the lab's control strip lies across the top; in the game the
## combat HUD will. The set-out is a column of fixed heights, so told what is
## eating an edge it can move OFF that edge — which is the whole difference
## between a layout that is wrong and a layout you simply cannot see. Both
## default to zero, so the shipping screen and every `--shot` are unaffected.
var safe_top: float = 0.0
var safe_bottom: float = 0.0

## Every piece: a polygon in husk-local coordinates plus where it ends up.
## `seat` is -1 for debris, otherwise the spoil index it carries.
var _shards: Array[Dictionary] = []
var _burst: float = 0.0
var _cool: float = 0.0
var _blaze: float = 0.0
## The bed is LIGHT and the wreckage is MATTER, so they cannot share a layer.
## Light has to be additive — drawn with normal alpha it can only ever pull the
## black toward its own colour, which is why the first bed read as a stain. The
## shards stay on a normal-blend layer above it, because a shard has to be able
## to occlude the glow it is lying in or it stops being a thing.
var _bed: Control = null
var _bed_tex: Array[GradientTexture2D] = []
var _motes: RewardKit = null
var _field: Control = null           # the wreckage; draws, takes no input
var _plate: Control = null
var _spoils: Array[Dictionary] = []
var _card_ids: Array[String] = []
var _cards: Array[CardView] = []
var _faces: Array[Control] = []
var _picked: bool = false
var _lean: bool = false
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
	_lean = _card_ids.is_empty()

	var ground: ColorRect = ColorRect.new()
	ground.color = NIGHT
	ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)

	_bed = Control.new()
	_bed.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add: CanvasItemMaterial = CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_bed.material = add
	_bed_tex = [
		RewardKit.radial(_hue_at(0.80, 0.42)),   # the long throw across the floor
		RewardKit.radial(_hue_at(0.62, 0.78)),   # the body of the fire
		RewardKit.radial(_hue_at(0.34, 1.00)),   # the core it fell into
	]
	_bed.draw.connect(_draw_bed)
	add_child(_bed)

	_field = Control.new()
	_field.set_anchors_preset(Control.PRESET_FULL_RECT)
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field.draw.connect(_draw_field)
	add_child(_field)

	_build_shards()
	_build_plate()
	# 「燼」means embers, and until now there were none — the bed was a glow with
	# nothing coming off it. These rise through the wreckage, so the fire reads
	# as still burning rather than as a light source parked behind the scene.
	var motes: Control = Control.new()
	motes.set_anchors_preset(Control.PRESET_FULL_RECT)
	motes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(motes)
	_motes = RewardKit.new(motes)


func _hue_at(sat: float, val: float) -> Color:
	return Color.from_hsv(fmod(hue, 360.0) / 360.0, sat, val)


## The bed, in screen coordinates — the light everything on this screen is lit
## by. One position, so no piece can disagree with another about where it is.
func _light() -> Vector2:
	return _centre + Vector2(0.0, BED_Y)


# ---------------------------------------------------------------- the break

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
			# Every wedge thrown the SAME multiple lands the debris on a clock
			# face. The golden-ratio walk gives each piece its own distance and
			# stays reproducible, so a shot of this screen is the same tomorrow.
			var mid: Vector2 = (poly[1] + poly[2]) * 0.5
			var jitter: float = fmod(float(wedge) * 0.6180339887 + 0.17, 1.0)
			var far: float = THROW * (0.70 + 1.30 * jitter)
			# ...and everything FALLS. Pieces settle onto the bed rather than
			# holding whatever height they were thrown to, which is the other
			# half of why the first pass read as shapes floating in a void.
			var land: Vector2 = HUSK_AT + mid * far
			# Pulled hard onto the bed line. Wreckage scattered evenly through the
			# air between two other bands is not wreckage, it is confetti — it has
			# to lie in the fire it came out of, and be SILHOUETTED by it.
			land.y = lerpf(land.y, BED_Y + (jitter - 0.40) * 46.0, 0.88)
			# Wide, but not off the edge: a piece clipped by the frame stops being
			# wreckage and becomes a rendering artefact.
			land.x *= 1.06
			_shards.append({
				"poly": poly,
				"home": land,
				"seat": -1,
				"spin": (jitter - 0.5) * 1.3,
				"lit": 0.32 + 0.5 * float((i * SPLIT + s) % 3) / 2.0,
			})
			wedge += 1
	# The seats are their OWN pieces, not promoted wedges. A wedge is a thin
	# triangle running to a point at the husk's centre; scaling one up until it
	# could carry a 198px item makes a spike, not a plate.
	var seats: Array[Vector2] = _seat_positions()
	for i: int in range(seats.size()):
		_shards.append({
			"poly": _slab(i),
			"home": seats[i],
			"seat": i,
			"spin": (fmod(float(i) * 0.6180339887 + 0.31, 1.0) - 0.5) * 0.34,
			"lit": 0.70 + 0.14 * float(i % 2),
		})


## A slab of the husk big enough to set something on. Five points rather than
## four so no edge is parallel to its opposite and it never reads as a card.
static func _slab(i: int) -> PackedVector2Array:
	var j: float = fmod(float(i) * 0.7548776662, 1.0) - 0.5    # -0.5 .. 0.5
	# Six points with two of them driven hard off the box: a shard has corners
	# that overshoot and corners that cave in, and a pentagon whose vertices all
	# sit near the bounding box is a rounded rectangle wearing a hat.
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(-0.54 - 0.10 * j, -0.30 + 0.16 * j),
		Vector2(-0.22 + 0.14 * j, -0.54),
		Vector2(0.50, -0.42 - 0.12 * j),
		Vector2(0.58 + 0.08 * j, 0.24 - 0.10 * j),
		Vector2(0.06 - 0.18 * j, 0.56),
		Vector2(-0.44 + 0.10 * j, 0.34 + 0.14 * j),
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
			+ float(i) * (SEAT.x + SEAT_GAP),
			SEAT_Y_LEAN if _lean else SEAT_Y))
	return out


# ---------------------------------------------------------------- the draw

func _draw_field() -> void:
	for shard: Dictionary in _shards:
		_draw_shard(shard)


## The bed: where the husk came down, and the only light in the scene. Drawn as
## stacked ellipses rather than one gradient so it has a hot core and a long
## cool throw — a bank of embers, not a lamp.
func _draw_bed() -> void:
	var at: Vector2 = _light()
	var heat: float = 0.24 + 0.76 * _burst
	# THREE SMOOTH LAYERS, not a stack of hard ellipses. Concentric draw_circles
	# band — nine of them is nine visible rings, which is a target, not a fire.
	# A radial gradient is one smooth falloff per layer and three of them nest
	# into a hot core with a long cool throw. They are also built ONCE: rebuilt
	# per frame this allocates three textures every redraw of the burst.
	_bed.draw_texture_rect(_bed_tex[0],
		_bed_rect(at, BED_W, BED_H), false, Color(1, 1, 1, 0.78 * heat))
	_bed.draw_texture_rect(_bed_tex[1],
		_bed_rect(at, BED_W * 0.46, BED_H * 0.52), false,
		Color(1, 1, 1, 0.70 * heat))
	_bed.draw_texture_rect(_bed_tex[2],
		_bed_rect(at, BED_W * 0.17, BED_H * 0.20), false,
		Color(1, 1, 1, 0.88 * heat))


static func _bed_rect(at: Vector2, w: float, h: float) -> Rect2:
	return Rect2(at - Vector2(w, h) * 0.5, Vector2(w, h))


## One piece of the enemy. Body, the light caught in its middle, then the rim —
## and the rim is the whole trick: drawn EDGE BY EDGE, each one's width and heat
## set by whether it faces the bed. A uniform outline is a vector shape however
## bright it is; this is what gives a flat polygon a near side and a far side.
func _draw_shard(shard: Dictionary) -> void:
	var seat: int = shard["seat"]
	var at: Vector2 = _centre + _shard_at(shard)
	var spin_at: float = shard["spin"]
	var spin: float = spin_at * (1.0 - _burst)
	var lit: float = shard["lit"]
	var scale: float = lerpf(1.0, 0.60, _burst) if seat < 0 \
		else lerpf(0.22, 1.0, _burst)

	# How near this piece is to the bed decides how hot it still is. Nothing
	# says "cooling" like the far pieces being the dead ones.
	var to_light: Vector2 = _light() - at
	var near: float = clampf(1.0 - to_light.length() / 620.0, 0.0, 1.0)
	var dir: Vector2 = to_light.normalized()

	# Glass this dark is read entirely off its edges. Giving the body a mid
	# value tries to describe the piece twice and succeeds at neither: it is too
	# dark to be a colour and too light to be a silhouette, which is precisely
	# the brown-paper look. It goes near-black, and the fracture carries it.
	var tone: Color = _hue_at(0.70, 0.06 + 0.13 * lit + 0.22 * near)
	var hot: Color = _hue_at(0.30, 1.0)
	if seat >= 0:
		# A seat cools out of the husk's hue into the item's own — the whole
		# claim of the concept in one lerp: this piece WAS the enemy, and is
		# now yours.
		var mine: Color = _spoils[seat]["tone"]
		tone = tone.lerp(Color(mine.r * 0.50, mine.g * 0.50, mine.b * 0.50), _cool)
		hot = hot.lerp(mine, _cool * 0.85)
	# Freshly broken glass is white at the cut and settles into its colour.
	var fresh: float = (1.0 - _cool) * _burst
	hot = hot.lerp(Color(1.0, 0.97, 0.92), fresh * 0.75)
	# THE BLAZE, before anything has moved. At _burst 0 every piece is still
	# stacked in the husk, so the shard edges ARE the crack lines — driving the
	# rim with it lights the fractures from inside a still-whole stone, which is
	# the one beat that makes the break read as a thing failing rather than a
	# transition playing. It dies as the pieces separate, because by then the
	# cracks have become edges and there is nothing left to crack.
	var flare: float = _blaze * (1.0 - _burst)
	hot = hot.lerp(Color(1.0, 0.98, 0.94), flare * 0.8)

	var alpha: float = 1.0 if seat >= 0 else lerpf(1.0, DEBRIS_A, _burst)
	var pts: PackedVector2Array = PackedVector2Array()
	var src: PackedVector2Array = shard["poly"]
	for p: Vector2 in src:
		pts.append(at + p.rotated(spin) * scale)

	# Body, then the light gathered in its middle: glass is not evenly lit
	# through, it pools where the piece is thickest.
	_field.draw_colored_polygon(pts, Color(tone, alpha * 0.88))
	# The inner glow is inset AND pushed toward the light. Centred, it reads as
	# a shape with a hole in it; shifted, the bright region crowds the lit edge
	# and the piece reads as something light is entering from one side.
	var core: PackedVector2Array = PackedVector2Array()
	var shift: Vector2 = dir * 13.0 * scale
	for p: Vector2 in pts:
		core.append(at.lerp(p, 0.60) + shift)
	_field.draw_colored_polygon(core,
		Color(hot, alpha * (0.14 + 0.42 * near) * (0.30 + 0.70 * _cool)))

	# THE FRACTURE. Per edge, lit by its own facing against the bed.
	var n: int = pts.size()
	for i: int in range(n):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % n]
		var edge: Vector2 = b - a
		if edge.length() < 0.5:
			continue
		# Outward normal: the shard is wound consistently, so one orthogonal is
		# always the one pointing away from the centroid.
		var outward: Vector2 = edge.orthogonal().normalized()
		if outward.dot(((a + b) * 0.5) - at) < 0.0:
			outward = -outward
		var facing: float = maxf(0.0, outward.dot(dir))
		var w: float = (1.0 + 5.6 * facing * (0.45 + 0.55 * near)) \
			* (1.0 + flare * 1.7)
		var glow: float = facing * (0.30 + 0.70 * near)
		# A fracture's brightness is a SURFACE reflection, not transmission —
		# so the hotter an edge is lit, the whiter it goes, whatever colour the
		# glass is. Keeping the rim in the body's own hue was the other reason
		# these read as cut paper: coloured glass with a coloured outline is a
		# sticker, and one white edge is what turns it into a solid.
		var edge_col: Color = hot.lerp(Color(1.0, 0.98, 0.95),
			facing * 0.70 + flare * 0.25)
		_field.draw_line(a, b, Color(edge_col,
			clampf(alpha * (0.20 + 0.80 * glow) + flare * 0.85, 0.0, 1.0)), w)


## Where a piece is right now: still in the husk at 0, at its resting place at
## 1, and thrown a little past it in between so the break has some weight.
func _shard_at(shard: Dictionary) -> Vector2:
	var home: Vector2 = shard["home"]
	var over: float = sin(_burst * PI) * 0.16
	return HUSK_AT.lerp(home, _burst) \
		+ (home - HUSK_AT).normalized() * over * 64.0


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
	var span: float = float(n) * w + float(maxi(0, n - 1)) * CARD_GAP
	return Vector2(-span * 0.5 + float(i) * (w + CARD_GAP), CARD_Y)


func _spoil_face(sp: Dictionary, at: Vector2) -> Control:
	var box: Control = Control.new()
	box.size = SEAT
	box.set_meta("home", at - SEAT * 0.5)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.modulate.a = 0.0

	var art: String = sp["art"]
	if art != "":
		var tex: TextureRect = TextureRect.new()
		tex.texture = RewardKit.mip(art)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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

	# Light text, not the window's dark paint: nothing here is backlit through
	# a sheet, so ink on a shard would just be a hole in it.
	var name_label: Label = _caption(str(sp["name"]).to_upper(), 13, TEXT, 3)
	name_label.position = Vector2(0.0, ART_H + 6.0)
	name_label.size = Vector2(SEAT.x, 22.0)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)
	return box


func _caption(text: String, px: int, col: Color, tracking: int) -> Label:
	var l: Label = RewardKit.text(text, GlassStyle.CINZEL_700, px, col, tracking)
	return l


func _word(text: String, on_press: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", RewardKit.font(GlassStyle.CINZEL_700, 3))
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", TEXT_DIM)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_color_override("font_pressed_color", GOLD)
	b.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	b.pressed.connect(on_press)
	return b


# ---------------------------------------------------------------- the burst

func _ready() -> void:
	_place()
	resized.connect(_place)
	# A beat of the husk sitting there, then the cracks take light, THEN it
	# goes. Without the first two the break has nothing to be a break from and
	# reads as a transition; with them it reads as a thing failing.
	var tw: Tween = create_tween()
	tw.tween_interval(SIT)
	tw.tween_method(_set_blaze, 0.0, 1.0, BLAZE)
	tw.tween_method(_set_burst, 0.0, 1.0, BURST).set_trans(Tween.TRANS_QUINT) \
		.set_ease(Tween.EASE_OUT)
	var after: Tween = create_tween().set_parallel(true)
	after.tween_method(_set_cool, 0.0, 1.0, COOL).set_delay(SIT + BLAZE + BURST * 0.5)
	for i: int in range(_faces.size()):
		after.tween_property(_faces[i], "modulate:a", 1.0, 0.24) \
			.set_delay(SIT + BLAZE + BURST * 0.66 + 0.05 * float(i))
	for i: int in range(_cards.size()):
		var seat: Control = _cards[i].get_parent()
		var home: Vector2 = seat.get_meta("home")
		var wait: float = SIT + BLAZE + BURST * 0.72 + 0.06 * float(i)
		seat.position = _centre + home + Vector2(0.0, 30.0)
		after.tween_property(seat, "modulate:a", 1.0, CARD_IN).set_delay(wait)
		after.tween_property(seat, "position", _centre + home, CARD_IN + 0.08) \
			.set_delay(wait).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for i: int in range(_spoils.size()):
		var what: StringName = _spoils[i]["what"]
		var id: String = _spoils[i]["id"]
		get_tree().create_timer(SIT + BLAZE + BURST * 0.66 + 0.05 * float(i)) \
			.timeout.connect(func() -> void: claimed.emit(what, id))


func _set_blaze(v: float) -> void:
	_blaze = v
	_field.queue_redraw()
	_bed.queue_redraw()


func _set_burst(v: float) -> void:
	_burst = v
	_field.queue_redraw()
	_bed.queue_redraw()
	_place_faces()


func _set_cool(v: float) -> void:
	_cool = v
	_field.queue_redraw()
	_bed.queue_redraw()


## Where the column stands. Centred in whatever band is left once the insets
## come off, and pinned to the TOP of that band when the band is shorter than
## the column — the buttons running off the bottom is a thing you can still see
## and scroll your eye to, the spoils hidden under the top edge is not, and the
## spoils are what the screen is for. With no insets this lands within four
## pixels of the raw centre, so nothing moves on a screen that owns its canvas.
func _anchor() -> Vector2:
	var rise: float = -(SEAT_Y_LEAN if _lean else SEAT_Y) + SEAT.y * SEAT_RISE
	var drop: float = (LEAN_FOOT if _lean
		else CARD_Y + CardView.CARD_H * CARD_SCALE) + FOOT_REACH
	var band: float = size.y - safe_top - safe_bottom
	return Vector2(size.x * 0.5,
		safe_top + rise + maxf(0.0, (band - rise - drop) * 0.5))


func _place() -> void:
	_centre = _anchor()
	if _motes != null and _motes.stage.get_child_count() == 0:
		_motes.embers(_light() + Vector2(0.0, 8.0), 340.0, hue)
	_field.queue_redraw()
	_bed.queue_redraw()
	_place_faces()
	var rack: float = _centre.y + (LEAN_FOOT if _lean
		else CARD_Y + CardView.CARD_H * CARD_SCALE)
	if _take_line != null:
		_take_line.size = Vector2(size.x, 22.0)
		_take_line.position = Vector2(0.0, rack + 14.0)
	if _bar != null:
		_bar.size = Vector2(size.x, 30.0)
		_bar.position = Vector2(0.0, rack + 42.0)


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
