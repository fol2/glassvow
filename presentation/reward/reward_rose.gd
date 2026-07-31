class_name RewardRose
extends Control
## CONCEPT 「玫瑰窗」— THE ROSE. The game's own signature image, spent on the
## moment it was made for. Ported out of a parallel session's candidate so all
## six answers sit in one viewer over one set of cases.
##
## assets/art/meta/emberglass-*.png is already a six-wedge rose with a lantern
## at its hub: this game has been saying "what you have earned is a window
## filling in" on its meta screen the whole time. The reward is that sentence at
## the scale of one fight.
##
## THE FIGURE IS THE COUNT. Three spoils cut a trefoil, four a quatrefoil, five
## a cinquefoil — so how well the fight paid is legible from across the room
## before a word is read. That is the same claim the window concept makes by
## sizing the building, reached independently from the other direction, which is
## reasonable evidence it is the right claim.
##
## The hub is the lantern and the light comes from it OUTWARD: every wedge is
## brightest where it meets the middle.
##
## TWO REAL COSTS, and they are why this is a hard sell:
##
##   A wedge holds an object and a name, not a rules line. So every rules line
##   on the screen collapses into ONE caption under the rose, belonging to
##   whichever light is focused. That reads with a pointer and dies on a still —
##   which is exactly the thing to judge it on, because the other candidates
##   show every line at once.
##
##   The offering is one wedge, equal in weight to gold. A reward is four items
##   and exactly one is a decision; a figure that insists all four are the same
##   shape cannot say that. It is the most beautiful of the six and the least
##   able to express what the screen is for.

signal claimed(what: StringName, id: String)
signal finished()

const ROSE_AT: Vector2 = Vector2(590.0, 356.0)
const ROSE_R: float = 250.0
const ROSE_HUB: float = 84.0

var reward: Dictionary = {}
var content: ContentDB
var encounter_kind: String = "normal"

var _kit: RewardKit = null
var _spoils: Array[Dictionary] = []
var _card_ids: Array[String] = []
var _lights: Array[Dictionary] = []    # {what, id, icon, name}
var _taken: Dictionary = {}
var _rose: ColorRect = null
var _caption: Label = null


func _init(reward_ref: Dictionary, content_ref: ContentDB,
		kind: String = "normal") -> void:
	reward = reward_ref
	content = content_ref
	encounter_kind = kind
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


## Every light on the figure, in order: the announcements, then the offering.
func _all() -> Array[Dictionary]:
	var out: Array[Dictionary] = _spoils.duplicate()
	if not _card_ids.is_empty():
		out.append({
			"what": &"card", "id": "", "name": "Add a card to your deck",
			"sub": "%d offered · take one" % _card_ids.size(),
			"tone": RewardKit.CARD_BLUE, "glyph": "◈",
			"art": RewardKit.ART + "piles/draw.png",
		})
	return out


func _build() -> void:
	var lights: Array[Dictionary] = _all()
	var n: int = maxi(lights.size(), 3)
	var spin: float = _spin(n)
	_rose = _kit.glass(Vector2(ROSE_R * 2.0, ROSE_R * 2.0), RewardKit.GOLD, 13.0)
	RewardKit.shade(_rose, {"shape_mode": 1, "outer": ROSE_R, "hub": ROSE_HUB,
		"wedges": n, "spin": spin, "lit": 1.0, "reach": 0.30, "seed": 5.0})
	var m: ShaderMaterial = _rose.material as ShaderMaterial
	m.set_shader_parameter("tones", _tone_strip(n, lights))
	_kit.put(_rose, Rect2(ROSE_AT.x - ROSE_R, ROSE_AT.y - ROSE_R,
		ROSE_R * 2.0, ROSE_R * 2.0))

	# The hub: the lantern, and the light every wedge is lit by. Two pools — the
	# throw across the glass, and the hot core the lantern sits in.
	_kit.pool(ROSE_AT, 420.0, Color(1.0, 0.72, 0.34), 0.40)
	_kit.pool(ROSE_AT, 190.0, Color(1.0, 0.84, 0.52), 0.55)
	var lamp: TextureRect = RewardKit.art(RewardKit.ART + "ui/lantern.png", 128.0)
	if lamp != null:
		_kit.put(lamp, Rect2(ROSE_AT.x - 64.0, ROSE_AT.y - 64.0, 128.0, 128.0))

	# One wedge per light, set out from the same angles the shader cuts — the
	# same `spin` on both sides, or the glass and the objects in it disagree.
	for i: int in range(lights.size()):
		var sp: Dictionary = lights[i]
		var a: float = TAU * ((float(i) + 0.5) / float(n) - spin) - PI
		var at: Vector2 = ROSE_AT + Vector2(cos(a), sin(a)) * 170.0
		var icon: TextureRect = RewardKit.art(str(sp["art"]), 74.0)
		if icon != null:
			_kit.put(icon, Rect2(at.x - 37.0, at.y - 48.0, 74.0, 74.0))
		var name_l: Label = RewardKit.text(str(sp["name"]),
			GlassStyle.ALEGREYA_700, 14, RewardKit.PARCHMENT, 0)
		name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_kit.put(name_l, Rect2(at.x - 76.0, at.y + 30.0, 152.0, 38.0))

		var hit: Button = Button.new()
		hit.flat = true
		hit.focus_mode = Control.FOCUS_NONE
		hit.position = at - Vector2(76.0, 52.0)
		hit.size = Vector2(152.0, 124.0)
		var what: StringName = sp["what"]
		hit.pressed.connect(_take.bind(what, str(sp["id"])))
		_kit.stage.add_child(hit)
		_lights.append({"what": what, "id": str(sp["id"]), "icon": icon,
			"name": name_l, "hit": hit, "index": i})

	var t: Label = RewardKit.text(_title_text(), GlassStyle.CINZEL_700, 28,
		RewardKit.PARCHMENT, 3)
	_kit.put(t, Rect2(0.0, 44.0, RewardKit.CANVAS.x, 38.0))
	_caption = RewardKit.text("", GlassStyle.ALEGREYA_400, 15, RewardKit.TEXT, 0)
	_kit.put(_caption, Rect2(190.0, 650.0, 800.0, 22.0))
	_refresh_caption()

	var go: Button = Button.new()
	go.flat = true
	go.focus_mode = Control.FOCUS_NONE
	go.position = Vector2(495.0, 692.0)
	go.size = Vector2(190.0, 46.0)
	go.add_child(_kit.seal("CONTINUE", 190.0))
	go.pressed.connect(_leave)
	_kit.stage.add_child(go)


## The shader cuts wedge i from t in [i/n, (i+1)/n) where t is the angle plus
## `spin`. This is the spin that lands wedge 0 square at the top for any n, so a
## trefoil and a quatrefoil both stand up straight instead of leaning.
static func _spin(n: int) -> float:
	return 0.5 / float(n) - 0.25


## One texel per wedge: rgb the glass it is cut from, alpha its own lamp. A
## strip instead of an array uniform, so the wedge count stays data — and a
## claimed wedge is one texel going dark, not a rebuild.
func _tone_strip(n: int, lights: Array[Dictionary]) -> ImageTexture:
	var img: Image = Image.create_empty(n, 1, false, Image.FORMAT_RGBA8)
	for i: int in range(n):
		if i < lights.size():
			var tone: Color = lights[i]["tone"]
			var what: StringName = lights[i]["what"]
			img.set_pixel(i, 0, Color(tone.r, tone.g, tone.b,
				0.10 if _taken.has(what) else 1.0))
		else:
			# An unfilled light: real glass, no lamp. The window is still whole.
			img.set_pixel(i, 0, Color(0.30, 0.36, 0.52, 0.09))
	return ImageTexture.create_from_image(img)


## Standing in for the pointer this design is really driven by: the caption
## belongs to whichever light is under the cursor. On a still it should show the
## line actually worth reading, and "into the purse" is not it — a relic
## outranks a phial outranks the offering's count.
func _refresh_caption() -> void:
	if _caption == null:
		return
	var order: Array[StringName] = [&"relic", &"potion", &"card", &"gold"]
	for want: StringName in order:
		for sp: Dictionary in _all():
			var what: StringName = sp["what"]
			var sub: String = sp["sub"]
			if what == want and not _taken.has(what) and sub != "":
				_caption.text = "%s — %s" % [str(sp["name"]), sub]
				return
	_caption.text = ""


func _take(what: StringName, id: String) -> void:
	if _taken.has(what):
		return
	_taken[what] = true
	var lights: Array[Dictionary] = _all()
	var m: ShaderMaterial = _rose.material as ShaderMaterial
	m.set_shader_parameter("tones",
		_tone_strip(maxi(lights.size(), 3), lights))
	for light: Dictionary in _lights:
		var mine: StringName = light["what"]
		if mine != what:
			continue
		var icon: TextureRect = light["icon"]
		if icon != null:
			icon.modulate = Color(1, 1, 1, 0.28)
		var name_l: Label = light["name"]
		name_l.modulate.a = 0.30
		var hit: Button = light["hit"]
		hit.disabled = true
	_refresh_caption()
	claimed.emit(what, id)


func _title_text() -> String:
	return "ELITE SLAIN" if encounter_kind == "elite" else "VICTORY"


func _leave() -> void:
	finished.emit()


func mark_taken(what: StringName) -> void:
	_take(what, "")


func request_leave() -> void:
	_leave()
