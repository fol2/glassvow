class_name RewardLancet
extends Control
## CONCEPT 「窗龕」— THE LANCET. A window in the wall, and the spoils are its
## lights. Ported out of a parallel session's candidate so all six answers sit
## in one viewer over one set of cases.
##
## THE HEAD IS THE ARGUMENT. A church window's head carries the figure the
## window is FOR, and this screen already knows what that is: the thing you just
## killed. Every fight leaves a face in the glass, lit from behind in the
## encounter's own colour — gold for an elite, cold blue for an ordinary kill.
## It costs one TextureRect and no new art; all 27 enemy portraits are in the
## tree already. Of everything either session drew, this is the best single
## idea, and it is the one the other candidates should be raiding.
##
## THE SET-OUT IS A REAL ONE. A pointed head of 320px rise over a 520px span —
## and the proportion is not taste, it is the only way a pointed arch is legal.
## Two-centred arches put each centre on the springing line at
## c = (rise^2 - h^2) / 2h, which goes NEGATIVE the moment the rise drops under
## the half-width; a negative c sweeps each arc through its own 90 degrees
## before the two meet, so both halves bulge above the apex and cross. Portrait
## is what buys the point. (The window concept, being 604 wide, could not have
## one at any height and takes a segmental head instead.)
##
## WHAT IT DOES NOT DO, kept deliberately rather than fixed: the offering is
## still a ROW reading "Add a card to your deck · 3 offered · take one", with
## the real cards behind a second door. That is the thing being judged here —
## repairing it would turn this into the reliquary and there would be nothing
## left to compare. See RewardReliquary for the same canvas with the offering
## on the screen.

signal claimed(what: StringName, id: String)
signal finished()

const WIN: Rect2 = Rect2(330.0, 20.0, 520.0, 700.0)
const WIN_ARCH: float = 320.0
const ROW_H: float = 58.0
const ROW_GAP: float = 8.0

var reward: Dictionary = {}
var content: ContentDB
var encounter_kind: String = "normal"
var enemy: String = ""

var _kit: RewardKit = null
var _spoils: Array[Dictionary] = []
var _card_ids: Array[String] = []
var _rows: Array[Dictionary] = []      # {what, id, pane, icon, labels}
var _taken: Dictionary = {}
var _picked: bool = false


func _init(reward_ref: Dictionary, content_ref: ContentDB,
		kind: String = "normal", enemy_id: String = "") -> void:
	reward = reward_ref
	content = content_ref
	encounter_kind = kind
	enemy = enemy_id
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_spoils = RewardSpoils.list(reward, content)
	_card_ids = RewardSpoils.card_ids(reward)

	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = RewardKit.NIGHT
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var stage: Control = Control.new()
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	_kit = RewardKit.new(stage)
	_build()


func _build() -> void:
	var crown: Color = RewardKit.GOLD if encounter_kind != "normal" \
		else Color(0.48, 0.68, 0.95)

	# The window itself: one pane, its own glass, lit low so the lights in front
	# of it read as brighter cuts in the same sheet.
	var win: ColorRect = _kit.glass(WIN.size, Color(0.16, 0.22, 0.40), 19.0)
	RewardKit.shade(win, {"arch": WIN_ARCH, "lit": 0.5, "radius": 14.0,
		"glow_at": Vector2(0.5, 0.30), "reach": 0.70, "seed": 3.0})
	_kit.put(win, WIN)

	# The memorial: the slain, in the head, behind the glass rather than on it.
	var head: ColorRect = _kit.glass(Vector2(184.0, 214.0), crown, 11.0)
	RewardKit.shade(head, {"arch": 116.0, "lit": 1.25, "radius": 8.0,
		"glow_at": Vector2(0.5, 0.60), "reach": 0.52, "seed": 11.0})
	_kit.put(head, Rect2(WIN.position.x + 168.0, WIN.position.y + 84.0,
		184.0, 214.0))
	if enemy != "":
		var face: TextureRect = RewardKit.art(
			RewardKit.ART + "enemies/%s.png" % enemy, 132.0)
		if face != null:
			# A figure IN the glass, not a sticker on it: held back toward the
			# pane's own colour so the light reads as coming through both, but
			# not so far back it stops being the thing you recognise killing.
			face.modulate = Color(0.72, 0.70, 0.74, 0.97)
			_kit.put(face, Rect2(WIN.position.x + 194.0, WIN.position.y + 122.0,
				132.0, 132.0))

	var mid: float = WIN.position.x + WIN.size.x * 0.5
	var t: Label = RewardKit.text(_title_text(), GlassStyle.CINZEL_700, 27,
		RewardKit.PARCHMENT, 3)
	_kit.put(t, Rect2(WIN.position.x, WIN.position.y + 330.0, WIN.size.x, 36.0))
	var orn: Label = RewardKit.text("✦   ✦   ✦", GlassStyle.CINZEL_700, 12,
		RewardKit.GOLD_DIM, 5)
	_kit.put(orn, Rect2(WIN.position.x, WIN.position.y + 370.0, WIN.size.x, 18.0))

	var y: float = WIN.position.y + 394.0
	for sp: Dictionary in _spoils:
		var what: StringName = sp["what"]
		var tone: Color = sp["tone"]
		_row(what, str(sp["id"]), str(sp["name"]), str(sp["sub"]), tone,
			str(sp["art"]), Rect2(mid - 226.0, y, 452.0, ROW_H))
		y += ROW_H + ROW_GAP
	if not _card_ids.is_empty():
		_row(&"card", "", "Add a card to your deck",
			"%d offered · take one" % _card_ids.size(), RewardKit.CARD_BLUE,
			RewardKit.ART + "piles/draw.png", Rect2(mid - 226.0, y, 452.0, ROW_H))

	# On the sill, not in the window: leaving is not one of the spoils.
	var go: Button = _button("CONTINUE", 190.0)
	go.position = Vector2(mid - 95.0, 742.0)
	go.size = Vector2(190.0, 46.0)
	_kit.stage.add_child(go)


func _row(what: StringName, id: String, title: String, sub: String,
		tone: Color, art: String, r: Rect2) -> void:
	var pane: ColorRect = _kit.glass(r.size, tone, 7.0)
	RewardKit.shade(pane, {"radius": 7.0, "lit": 1.0, "ink": 0.0,
		"glow_at": Vector2(0.10, 0.5), "reach": 0.52, "seed": r.position.y * 0.13})
	_kit.put(pane, r)

	var icon: TextureRect = RewardKit.art(art, 42.0)
	if icon != null:
		_kit.put(icon, Rect2(r.position.x + 16.0, r.position.y + 8.0, 42.0, 42.0))
	var name_l: Label = RewardKit.text(title, GlassStyle.ALEGREYA_700, 18,
		RewardKit.PARCHMENT, 0)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_kit.put(name_l, Rect2(r.position.x + 72.0, r.position.y + 9.0, 356.0, 22.0))
	var sub_l: Label = null
	if sub != "":
		sub_l = RewardKit.text(sub, GlassStyle.ALEGREYA_400, 13,
			RewardKit.TEXT_DIM, 0)
		sub_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_kit.put(sub_l, Rect2(r.position.x + 72.0, r.position.y + 32.0, 356.0, 18.0))

	# The pane is scenery; the click surface is a flat Button laid over it, so a
	# row has one pressed signal however many pieces it is made of.
	var hit: Button = Button.new()
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.position = r.position
	hit.size = r.size
	hit.pressed.connect(_take.bind(what, id))
	_kit.stage.add_child(hit)
	_rows.append({"what": what, "id": id, "pane": pane, "icon": icon,
		"name": name_l, "sub": sub_l, "hit": hit})


func _take(what: StringName, id: String) -> void:
	if _taken.has(what):
		return
	_taken[what] = true
	if what == &"card":
		_picked = true
	for row: Dictionary in _rows:
		var mine: StringName = row["what"]
		if mine != what:
			continue
		# `ink` is the shader's own claimed state: the glass keeps its colour
		# and loses its lamp, which is what a light with nothing behind it does.
		var pane: ColorRect = row["pane"]
		RewardKit.shade(pane, {"lit": 0.16, "ink": 1.0})
		var icon: TextureRect = row["icon"]
		if icon != null:
			icon.modulate = Color(1, 1, 1, 0.35)
		var name_l: Label = row["name"]
		name_l.modulate.a = 0.38
		var sub_v: Variant = row["sub"]
		if sub_v != null:
			var sub_l: Label = sub_v
			sub_l.modulate.a = 0.38
		var hit: Button = row["hit"]
		hit.disabled = true
	claimed.emit(what, id)


func _title_text() -> String:
	return "ELITE SLAIN" if encounter_kind == "elite" else "VICTORY"


func _button(label: String, w: float) -> Button:
	var b: Button = Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_child(_kit.seal(label, w))
	b.pressed.connect(_leave)
	return b


func _leave() -> void:
	finished.emit()


func mark_taken(what: StringName) -> void:
	_take(what, "")


func request_leave() -> void:
	_leave()
