class_name RewardDesigns
extends Control
## THREE CANDIDATE REWARD SCREENS, past the benchmark. Pick one; the other two
## get deleted. Nothing here is production — `presentation/reward/reward_screen.gd`
## is the shipping screen and this file does not touch it.
##
##   godot --path . -s <boot> -- --design=lancet|reliquary|rose [--case=elite]
##   1 2 3      switch design          ← →   switch case
##   T          take the next spoil (shows the claimed state)
##   S          hide the strip, for a clean shot
##
## ── WHY ANY OF THIS ───────────────────────────────────────────────────────
## The ported screen is a good port and the wrong object. Look at what this
## game actually draws: the chest is a leaded window in a stone arch, the
## lantern is leaded glass, the phial is leaded glass, the card back is a
## leaded pane, the stage arch is a cathedral arch, and the meta screen is a
## SIX-WEDGE ROSE WINDOW with a lantern at its hub. One material, everywhere,
## drawn by hand at 512px.
##
## The reward screen renders that material at 30px inside a rounded rectangle.
## It is the most-looked-at screen in the loop — the one the player earned —
## and it is the only screen in the game that does not look like the game.
##
## So all three candidates start from the same two moves: the reward art gets
## to be BIG, and the frame around it is made of the same stuff as the art.
## They differ in what the frame IS.
##
##   lancet     A window in the wall. The spoils are its lights, and the head
##              of the arch carries the thing you killed — a memorial pane, the
##              way a church window carries a saint. Closest to the ported
##              screen's shape, so it is the low-risk pick: same reading order,
##              same row rhythm, every surface replaced.
##
##   reliquary  No panel at all. The chest, open, on the ledge you fought on,
##              with the act's own parallax behind it and its light thrown up
##              the stone. The spoils rise out of it at the size they are drawn
##              at. The most cinematic and the most expensive, and it is the
##              only one that puts the reward in the WORLD rather than over it.
##
##   rose       The game's own signature image, spent on the moment it was made
##              for. A rose window: the lantern at the hub, one wedge per spoil,
##              radiating. Trefoil, quatrefoil, cinquefoil — the figure is the
##              count, so the window's shape tells you how well the fight paid
##              before you have read a word. The boldest, and it buys that with
##              the one real cost noted at ROSE below.
##
## All three run on one shader (leaded_glass.gdshader) and the art already in
## the tree. No new assets.

const GLASS: Shader = preload("res://presentation/lab/leaded_glass.gdshader")
const ART: String = "res://assets/art/"

# ── the measured palette, carried over from the ported screen ──────────────
const LEAD: Color = Color(0.020, 0.027, 0.055)        # #05070E
const GOLD: Color = Color(0.949, 0.757, 0.306)        # #F2C14E
const GOLD_DIM: Color = Color(0.612, 0.486, 0.204)    # #9C7C34
const PARCHMENT: Color = Color(0.910, 0.875, 0.784)   # #E8DFC8
const TEXT: Color = Color(0.843, 0.863, 0.918)        # #D7DCEA
const TEXT_DIM: Color = Color(0.545, 0.576, 0.678)    # #8B93AD
const BTN_INK: Color = Color(0.102, 0.071, 0.024)     # #1A1206
const CARD_BLUE: Color = Color(0.42, 0.63, 0.86)
const NIGHT: Color = Color(0.020, 0.027, 0.063)

## Where the lamp stands, for every bead of came in every design. One direction
## for the whole screen or the lead stops agreeing with itself — the single
## thing that separates leaded glass from a drawn border.
const LAMP: Vector2 = Vector2(-0.48, -0.88)

const DESIGNS: Array[String] = ["lancet", "reliquary", "rose"]

## Cases copied rather than imported: reward_lab.gd belongs to another session
## and this file must not break when it moves. `enemy` is the addition — the
## lancet memorialises what you killed, and the reward dict never carried it.
const CASES: Dictionary = {
	"gold": {"kind": "normal", "enemy": "duskfang",
		"reward": {"gold": 17, "cards": [], "potion": null, "relic": null}},
	"cards": {"kind": "normal", "enemy": "gloomslime",
		"reward": {"gold": 14, "cards": ["heavyBlow", "cleave", "deflect"],
			"potion": null, "relic": null}},
	"full": {"kind": "normal", "enemy": "duskfang",
		"reward": {"gold": 22, "cards": ["flurry", "surge", "fortify"],
			"potion": "healing", "relic": "emberHeart"}},
	"elite": {"kind": "elite", "enemy": "gravewarden",
		"reward": {"gold": 33, "cards": ["executioner", "momentum", "empower"],
			"potion": "fire", "relic": "emberHeart"}},
}
const ORDER: Array[String] = ["gold", "cards", "full", "elite"]


## One thing the player can take. `tone` is the glass it is cut from — read off
## the content's own `tone` where there is one, so a phial's pane is the colour
## of the phial.
class Spoil:
	var what: StringName
	var title: String
	var sub: String
	var art: String
	var tone: Color
	var taken: bool = false

	func _init(w: StringName, t: String, s: String, a: String, c: Color) -> void:
		what = w
		title = t
		sub = s
		art = a
		tone = c


var content: ContentDB

var _design: String = "lancet"
var _case: String = "elite"
var _shot: String = ""
var _strip: bool = true
var _taken: int = 0
var _spoils: Array[Spoil] = []
var _stage: Control
var _bar: Control
var _note_l: Label

static var _fonts: Dictionary = {}
static var _mips: Dictionary = {}


func _init(content_ref: ContentDB) -> void:
	content = content_ref
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--design="):
			_design = arg.trim_prefix("--design=")
		elif arg.begins_with("--case="):
			_case = arg.trim_prefix("--case=")
		elif arg.begins_with("--shot="):
			_shot = arg.trim_prefix("--shot=")
		elif arg.begins_with("--take="):
			_taken = int(arg.trim_prefix("--take="))
	if not DESIGNS.has(_design):
		_design = "lancet"
	if not CASES.has(_case):
		_case = "elite"
	if _shot != "":
		_strip = false
	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = NIGHT
	add_child(bg)
	_build()
	if _strip:
		_build_strip()


# ------------------------------------------------------------------ the data
func _gather() -> void:
	_spoils = []
	var sample: Dictionary = CASES[_case]
	var rw: Dictionary = sample["reward"]
	var gold: int = str(rw.get("gold", 0)).to_int()
	if gold > 0:
		_spoils.append(Spoil.new(&"gold", "%d gold" % gold, "into the purse",
			ART + "ui/coin.png", GOLD))
	var pid: String = str(rw.get("potion", ""))
	if pid != "" and pid != "<null>":
		var p: Dictionary = content.potions.get(pid, {})
		_spoils.append(Spoil.new(&"potion", str(p.get("name", pid)),
			str(p.get("text", "")), ART + "potions/%s.png" % pid, _tone(p)))
	var rid: String = str(rw.get("relic", ""))
	if rid != "" and rid != "<null>":
		var r: Dictionary = content.relics.get(rid, {})
		_spoils.append(Spoil.new(&"relic", str(r.get("name", rid)),
			str(r.get("text", "")), ART + "relics/%s.png" % rid, _tone(r)))
	var cards: Array = rw.get("cards", [])
	if not cards.is_empty():
		_spoils.append(Spoil.new(&"card", "Add a card to your deck",
			"%d offered · take one" % cards.size(), ART + "piles/draw.png",
			CARD_BLUE))
	for i: int in range(_spoils.size()):
		_spoils[i].taken = i < _taken


static func _tone(def: Dictionary) -> Color:
	return Color.from_string(str(def.get("tone", "")), GOLD)


func _title_text() -> String:
	var kind: String = str(CASES[_case].get("kind", "normal"))
	if kind == "elite":
		return "ELITE SLAIN"
	if kind == "boss":
		return "THE WARDEN FALLS"
	return "VICTORY"


# ---------------------------------------------------------------- the shells
func _build() -> void:
	if is_instance_valid(_stage):
		_stage.queue_free()
	_gather()
	_stage = Control.new()
	_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	move_child(_stage, 1)
	match _design:
		"reliquary":
			_build_reliquary()
		"rose":
			_build_rose()
		_:
			_build_lancet()
	if is_instance_valid(_note_l):
		_note_l.text = "%s · %s · %d taken" % [_design, _case, _taken]


# ══════════════════════════════════════════════════════════════════════════
# LANCET — a window in the wall, and the spoils are its lights.
# ══════════════════════════════════════════════════════════════════════════
# The set-out is a real one: a pointed head of 320px rise over a 520px span
# (k = 79px, so the two arcs are struck just outside the jambs — a lancet, not
# a semicircle), the lights stacked below the springing line, and the sill left
# clear so the button reads as the step you leave by rather than another row.
#
# The head is the whole argument for this one. A church window's head carries
# the figure the window is FOR, and the reward screen already knows what that
# is: the thing you just killed. Every fight leaves a face in the glass, lit
# from behind in the encounter's own colour — gold for an elite, cold blue for
# an ordinary kill. It costs one TextureRect and no new art: all 27 enemy
# portraits are already in the tree.
const WIN: Rect2 = Rect2(330.0, 20.0, 520.0, 700.0)
const WIN_ARCH: float = 320.0
const ROW_H: float = 58.0
const ROW_GAP: float = 8.0


func _build_lancet() -> void:
	var kind: String = str(CASES[_case].get("kind", "normal"))
	var crown: Color = GOLD if kind != "normal" else Color(0.48, 0.68, 0.95)

	# The window itself: one pane, its own glass, lit low so the lights in front
	# of it read as brighter cuts in the same sheet.
	var win: ColorRect = _glass(WIN.size, Color(0.16, 0.22, 0.40), 19.0)
	_shade(win, {"arch": WIN_ARCH, "lit": 0.5, "radius": 14.0,
		"glow_at": Vector2(0.5, 0.30), "reach": 0.70, "seed": 3.0})
	_put(win, WIN)

	# The memorial: the slain, in the head, behind the glass rather than on it.
	var head: ColorRect = _glass(Vector2(184.0, 214.0), crown, 11.0)
	_shade(head, {"arch": 116.0, "lit": 1.25, "radius": 8.0,
		"glow_at": Vector2(0.5, 0.60), "reach": 0.52, "seed": 11.0})
	_put(head, Rect2(WIN.position.x + 168.0, WIN.position.y + 84.0, 184.0, 214.0))
	var eid: String = str(CASES[_case].get("enemy", ""))
	var face: TextureRect = _art(ART + "enemies/%s.png" % eid, 132.0)
	if face != null:
		# A figure IN the glass, not a sticker on it: held back toward the
		# pane's own colour so the light reads as coming through both, but not
		# so far back that it stops being the thing you recognise killing.
		face.modulate = Color(0.72, 0.70, 0.74, 0.97)
		_put(face, Rect2(WIN.position.x + 194.0, WIN.position.y + 122.0,
			132.0, 132.0))

	var mid: float = WIN.position.x + WIN.size.x * 0.5
	var t: Label = _text(_title_text(), GlassStyle.CINZEL_700, 27, PARCHMENT, 3)
	_put(t, Rect2(WIN.position.x, WIN.position.y + 330.0, WIN.size.x, 36.0))
	var orn: Label = _text("✦   ✦   ✦", GlassStyle.CINZEL_700, 12, GOLD_DIM, 5)
	_put(orn, Rect2(WIN.position.x, WIN.position.y + 370.0, WIN.size.x, 18.0))

	var y: float = WIN.position.y + 394.0
	for s: Spoil in _spoils:
		_lancet_row(s, Rect2(mid - 226.0, y, 452.0, ROW_H))
		y += ROW_H + ROW_GAP

	# On the sill, not in the window: leaving is not one of the spoils.
	_put(_seal("CONTINUE", 190.0), Rect2(mid - 95.0, 742.0, 190.0, 46.0))


func _lancet_row(s: Spoil, r: Rect2) -> void:
	var pane: ColorRect = _glass(r.size, s.tone, 7.0)
	_shade(pane, {"radius": 7.0, "lit": 0.16 if s.taken else 1.0,
		"ink": 1.0 if s.taken else 0.0, "glow_at": Vector2(0.10, 0.5),
		"reach": 0.52, "seed": r.position.y * 0.13})
	_put(pane, r)

	var icon: TextureRect = _art(s.art, 42.0)
	if icon != null:
		icon.modulate = Color(1, 1, 1, 0.35 if s.taken else 1.0)
		_put(icon, Rect2(r.position.x + 16.0, r.position.y + 8.0, 42.0, 42.0))

	var fade: float = 0.38 if s.taken else 1.0
	var name_l: Label = _text(s.title, GlassStyle.ALEGREYA_700, 18,
		Color(PARCHMENT, fade), 0)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_put(name_l, Rect2(r.position.x + 72.0, r.position.y + 9.0, 356.0, 22.0))
	if s.sub != "":
		var sub_l: Label = _text(s.sub, GlassStyle.ALEGREYA_400, 13,
			Color(TEXT_DIM, fade), 0)
		sub_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_put(sub_l, Rect2(r.position.x + 72.0, r.position.y + 32.0, 356.0, 18.0))


# ══════════════════════════════════════════════════════════════════════════
# RELIQUARY — the chest, on the ledge, in the light it throws.
# ══════════════════════════════════════════════════════════════════════════
# The one candidate with no panel. The act's three parallax plates are already
# drawn and already used by combat, chest-open.png is already drawn, and the
# spoils are drawn at 512px — so the whole design is "stop hiding all of it".
#
# The light is the work. The chest's own art has a glow baked into it that goes
# nowhere; here an additive pool sits in its mouth and throws colour up the
# stone, embers climb out of it, and every spoil carries a small pool of its
# own tone so it is lit BY the scene instead of pasted onto it.
const LEDGE_Y: float = 396.0
const CHEST: Vector2 = Vector2(590.0, 470.0)


func _build_reliquary() -> void:
	_plate(ART + "stage/act1-backdrop.png", Rect2(-60.0, 40.0, 1300.0, 500.0),
		Color(0.30, 0.34, 0.52, 1.0))
	_plate(ART + "stage/act1-mid.png", Rect2(240.0, -30.0, 700.0, 520.0),
		Color(0.44, 0.47, 0.62, 1.0))
	_plate(ART + "stage/act1-ledge.png", Rect2(-70.0, LEDGE_Y, 1320.0, 654.0),
		Color(0.40, 0.40, 0.52, 1.0))

	# The pool in the chest's mouth, thrown up the stone behind it.
	_pool(CHEST + Vector2(0.0, -6.0), 620.0, Color(1.0, 0.66, 0.28), 0.60)
	_pool(CHEST + Vector2(0.0, 40.0), 300.0, Color(1.0, 0.80, 0.42), 0.55)

	var chest: TextureRect = _art(ART + "props/chest-open.png", 330.0)
	if chest != null:
		_put(chest, Rect2(CHEST.x - 165.0, CHEST.y - 42.0, 330.0, 264.0))
	_embers(Vector2(CHEST.x, CHEST.y + 30.0), 120.0)

	# The spoils, standing out of the chest. Columns, not an arc: each one has a
	# name and a rules line under it, and on a tight arc those lines run into
	# each other — the objects were legible and the words were not. So the
	# column pitch is set by the TEXT, and the arc survives only as a shallow
	# lift toward the middle, which is the chest's own light doing the shaping.
	var n: int = _spoils.size()
	var pitch: float = 244.0
	for i: int in range(n):
		var mid: float = float(n - 1) * 0.5
		var off: float = float(i) - mid
		var lift: float = (1.0 - absf(off) / maxf(mid, 1.0)) * 26.0
		_relic_stand(_spoils[i], Vector2(CHEST.x + off * pitch, 292.0 - lift))

	var t: Label = _text(_title_text(), GlassStyle.CINZEL_700, 28, PARCHMENT, 3)
	_put(t, Rect2(0.0, 44.0, 1180.0, 38.0))
	var orn: Label = _text("✦   ✦   ✦", GlassStyle.CINZEL_700, 12, GOLD_DIM, 5)
	_put(orn, Rect2(0.0, 86.0, 1180.0, 18.0))
	_put(_seal("CONTINUE", 190.0), Rect2(495.0, 726.0, 190.0, 46.0))


func _relic_stand(s: Spoil, at: Vector2) -> void:
	var fade: float = 0.30 if s.taken else 1.0
	if not s.taken:
		_pool(at, 230.0, s.tone, 0.40)
	var icon: TextureRect = _art(s.art, 104.0)
	if icon != null:
		icon.modulate = Color(1, 1, 1, fade)
		_put(icon, Rect2(at.x - 52.0, at.y - 52.0, 104.0, 104.0))
	var name_l: Label = _text(s.title, GlassStyle.ALEGREYA_700, 17,
		Color(PARCHMENT, fade), 0)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_put(name_l, Rect2(at.x - 112.0, at.y + 60.0, 224.0, 26.0))
	if s.sub != "":
		var sub_l: Label = _text(s.sub, GlassStyle.ALEGREYA_400, 13,
			Color(TEXT_DIM, fade), 0)
		sub_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_put(sub_l, Rect2(at.x - 106.0, at.y + 86.0, 212.0, 40.0))


# ══════════════════════════════════════════════════════════════════════════
# ROSE — the game's signature image, spent on the moment it was made for.
# ══════════════════════════════════════════════════════════════════════════
# assets/art/meta/emberglass-*.png is a six-wedge rose with a lantern at its
# hub: this game already says "what you have earned is a window filling in".
# The reward is that sentence at the scale of one fight.
#
# The figure IS the count — three spoils cut a trefoil, four a quatrefoil, five
# a cinquefoil — so how well the fight paid is legible from across the room,
# before a word is read. The hub is the lantern, and the light comes from it
# OUTWARD: the wedges are brightest where they meet it.
#
# THE COST, and it is real: a wedge holds an object and a name, not a rules
# line. So the rules text moves to a single caption under the rose and belongs
# to whichever wedge is focused — turn the window and it tells you. That reads
# well with a pointer and it is the weakest of the three on a still screenshot,
# which is exactly the thing to judge it on. The other two show every line at
# once.
const ROSE_AT: Vector2 = Vector2(590.0, 356.0)
const ROSE_R: float = 250.0
const ROSE_HUB: float = 84.0


func _build_rose() -> void:
	var n: int = maxi(_spoils.size(), 3)
	var spin: float = _spin(n)
	var strip: ImageTexture = _tone_strip(n)
	var rose: ColorRect = _glass(Vector2(ROSE_R * 2.0, ROSE_R * 2.0), GOLD, 13.0)
	_shade(rose, {"shape_mode": 1, "outer": ROSE_R, "hub": ROSE_HUB,
		"wedges": n, "spin": spin, "lit": 1.0, "reach": 0.30, "seed": 5.0})
	var m: ShaderMaterial = rose.material as ShaderMaterial
	m.set_shader_parameter("tones", strip)
	_put(rose, Rect2(ROSE_AT.x - ROSE_R, ROSE_AT.y - ROSE_R,
		ROSE_R * 2.0, ROSE_R * 2.0))

	# The hub: the lantern, and the light every wedge is lit by. Two pools —
	# the throw across the glass, and the hot core the lantern sits in.
	_pool(ROSE_AT, 420.0, Color(1.0, 0.72, 0.34), 0.40)
	_pool(ROSE_AT, 190.0, Color(1.0, 0.84, 0.52), 0.55)
	var lamp: TextureRect = _art(ART + "ui/lantern.png", 128.0)
	if lamp != null:
		_put(lamp, Rect2(ROSE_AT.x - 64.0, ROSE_AT.y - 64.0, 128.0, 128.0))

	# One wedge per spoil, set out from the same angles the shader cuts — the
	# same `spin` on both sides, or the glass and the objects in it disagree.
	for i: int in range(_spoils.size()):
		var s: Spoil = _spoils[i]
		var a: float = TAU * ((float(i) + 0.5) / float(n) - spin) - PI
		var at: Vector2 = ROSE_AT + Vector2(cos(a), sin(a)) * 170.0
		var icon: TextureRect = _art(s.art, 74.0)
		if icon != null:
			icon.modulate = Color(1, 1, 1, 0.28 if s.taken else 1.0)
			_put(icon, Rect2(at.x - 37.0, at.y - 48.0, 74.0, 74.0))
		var name_l: Label = _text(s.title, GlassStyle.ALEGREYA_700, 14,
			Color(PARCHMENT, 0.30 if s.taken else 1.0), 0)
		name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_put(name_l, Rect2(at.x - 76.0, at.y + 30.0, 152.0, 38.0))

	var t: Label = _text(_title_text(), GlassStyle.CINZEL_700, 28, PARCHMENT, 3)
	_put(t, Rect2(0.0, 44.0, 1180.0, 38.0))
	var focus: Spoil = _focus()
	if focus != null:
		var cap: Label = _text("%s — %s" % [focus.title, focus.sub],
			GlassStyle.ALEGREYA_400, 15, TEXT, 0)
		_put(cap, Rect2(190.0, 650.0, 800.0, 22.0))
	_put(_seal("CONTINUE", 190.0), Rect2(495.0, 692.0, 190.0, 46.0))


## The shader cuts wedge i from t in [i/n, (i+1)/n) where t is the angle plus
## `spin`. This is the spin that lands wedge 0 square at the top for any n, so
## a trefoil and a quatrefoil both stand up straight instead of leaning.
static func _spin(n: int) -> float:
	return 0.5 / float(n) - 0.25


## Standing in for the pointer this design is really driven by: the caption
## belongs to whichever light is under the cursor. On a still it should show
## the line actually worth reading, and "into the purse" is not it — a relic
## outranks a phial outranks the offering's count.
func _focus() -> Spoil:
	var order: Array[StringName] = [&"relic", &"potion", &"card", &"gold"]
	for want: StringName in order:
		for s: Spoil in _spoils:
			if s.what == want and not s.taken and s.sub != "":
				return s
	return null


## One texel per wedge: rgb the glass it is cut from, alpha its own lamp. A
## strip instead of an array uniform, so the wedge count stays data — and a
## claimed wedge is one texel going dark, not a rebuild.
func _tone_strip(n: int) -> ImageTexture:
	var img: Image = Image.create_empty(n, 1, false, Image.FORMAT_RGBA8)
	for i: int in range(n):
		if i < _spoils.size():
			var s: Spoil = _spoils[i]
			img.set_pixel(i, 0, Color(s.tone.r, s.tone.g, s.tone.b,
				0.10 if s.taken else 1.0))
		else:
			# An unfilled light: real glass, no lamp. The window is still whole.
			img.set_pixel(i, 0, Color(0.30, 0.36, 0.52, 0.09))
	return ImageTexture.create_from_image(img)


# ------------------------------------------------------------------ the kit
func _glass(size: Vector2, tint: Color, came: float) -> ColorRect:
	var r: ColorRect = ColorRect.new()
	r.custom_minimum_size = size
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = GLASS
	m.set_shader_parameter("size", size)
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("lead", LEAD)
	m.set_shader_parameter("came", came)
	m.set_shader_parameter("lamp", LAMP)
	r.material = m
	return r


## Everything else the shader takes, by name, so a design reads as its own
## spec rather than eleven set_shader_parameter lines.
func _shade(node: ColorRect, opts: Dictionary) -> void:
	var m: ShaderMaterial = node.material as ShaderMaterial
	for key: String in opts:
		m.set_shader_parameter(key, opts[key])


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
## it. This is the cheap half of a Light2D and all this design needs — the
## expensive half (the plates going properly dark away from it) would want a
## CanvasModulate, and that belongs to the real screen, not a candidate.
func _pool(at: Vector2, size: float, tone: Color, strength: float) -> void:
	var tr: TextureRect = TextureRect.new()
	tr.texture = _radial(tone)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.modulate = Color(1, 1, 1, strength)
	var cm: CanvasItemMaterial = CanvasItemMaterial.new()
	cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	tr.material = cm
	_put(tr, Rect2(at.x - size * 0.5, at.y - size * 0.5, size, size))


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


func _seal(label: String, w: float) -> Control:
	var holder: Control = Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pane: ColorRect = _glass(Vector2(w, 46.0), GOLD, 5.0)
	_shade(pane, {"radius": 9.0, "lit": 1.7, "ripple": 0.4,
		"glow_at": Vector2(0.5, 0.34), "reach": 0.66, "seed": 21.0})
	pane.position = Vector2.ZERO
	pane.size = Vector2(w, 46.0)
	holder.add_child(pane)
	var l: Label = _text(label, GlassStyle.CINZEL_700, 17, BTN_INK, 3)
	l.position = Vector2(0.0, 12.0)
	l.size = Vector2(w, 24.0)
	holder.add_child(l)
	return holder


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
	return tr


static func _text(s: String, path: String, sz: int, col: Color,
		track: int) -> Label:
	var l: Label = Label.new()
	l.text = s
	l.add_theme_font_override("font", _font(path, track))
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.add_theme_constant_override("shadow_outline_size", 4)
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


## Art is authored at 512 and drawn here at 42-120. Without a mip chain that is
## a shimmering mess; SKILL §4 forbids hand-editing .import sidecars, so the
## chain is built at load and the sampler asked for it.
static func _mip(path: String) -> Texture2D:
	if _mips.has(path):
		var hit: Texture2D = _mips[path]
		return hit
	if not ResourceLoader.exists(path):
		push_warning("reward designs: missing art %s" % path)
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
	g.set_color(0, Color(tone.r, tone.g, tone.b, 1.0))
	g.set_color(1, Color(tone.r, tone.g, tone.b, 0.0))
	g.add_point(0.35, Color(tone.r, tone.g, tone.b, 0.42))
	var t: GradientTexture2D = GradientTexture2D.new()
	t.gradient = g
	t.width = 128
	t.height = 128
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t


# ------------------------------------------------------------------ the bench
func _build_strip() -> void:
	_bar = Control.new()
	_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_bar.position = Vector2(0.0, 776.0)
	_bar.size = Vector2(1180.0, 44.0)
	add_child(_bar)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.06, 0.86)
	bg.size = Vector2(1180.0, 44.0)
	_bar.add_child(bg)
	_note_l = _text("", GlassStyle.ALEGREYA_400, 14, TEXT_DIM, 0)
	_note_l.position = Vector2(0.0, 12.0)
	_note_l.size = Vector2(1180.0, 20.0)
	_note_l.text = "%s · %s · %d taken" % [_design, _case, _taken]
	_bar.add_child(_note_l)
	var hint: Label = _text("1 2 3 design   ← → case   T take   S strip",
		GlassStyle.ALEGREYA_400, 12, Color(TEXT_DIM, 0.55), 0)
	hint.position = Vector2(0.0, 28.0)
	hint.size = Vector2(1180.0, 16.0)
	_bar.add_child(hint)


func _unhandled_key_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_1, KEY_2, KEY_3:
			_design = DESIGNS[k.keycode - KEY_1]
			_taken = 0
			_build()
		KEY_LEFT, KEY_RIGHT:
			var step: int = -1 if k.keycode == KEY_LEFT else 1
			_case = ORDER[posmod(ORDER.find(_case) + step, ORDER.size())]
			_taken = 0
			_build()
		KEY_T:
			_taken = (_taken + 1) % (_spoils.size() + 1)
			_build()
		KEY_S:
			if is_instance_valid(_bar):
				_bar.visible = not _bar.visible
		_:
			return
	get_viewport().set_input_as_handled()
