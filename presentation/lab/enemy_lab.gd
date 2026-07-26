class_name EnemyLab
extends Control
## The enemy designer surface: every enemy in the content set standing on a
## ground line at its TRUE relative size.
##
## Why this shape: the benchmark sizes a creature `tierSizes[tier] * scale`,
## which runs from 115px (sporeling) to 1120px (leviathan) — a ten-fold ladder.
## Size is most of what tells one enemy from another before you read its name,
## so a sheet that draws the roster at one uniform size throws away the thing it
## exists to check. This one puts them shoulder to shoulder on shared ground
## lines, feet anchored, so the ladder and the foot offsets are both visible.
##
##   godot --path . -- --enemies                             # scale chart
##   tools/shot.sh --enemies --shot=/tmp/enemies.png
##   godot --path . -- --enemies --only=sporeling,leviathan  # detail, 1:1
##   godot --path . -- --enemies --states[=duskfang]         # the real states
##   godot --path . -- --enemies --bench[=duskfang]          # INTERACTIVE bench
##   godot --path . -- --enemies --states=duskfang --msaa=2 --oversample=1.5
##                                                           # the memory knobs
##   tools/shot.sh --enemies --hit[=duskfang] [--incidental] --strip=/tmp/h.png
##                                    # the recoil, photographed across 320ms
##
## --shot= and --strip= both quit when they are done, so those two go through
## tools/shot.sh; the rest leave a window open to work in. Neither form may
## carry --headless — a headless run has no viewport texture, so the capture
## hangs instead of failing.
##
## The bench is the one that answers questions a PNG cannot: refraction only
## reads when the thing behind it moves, the idle warp is motion, and the death
## rite is 200ms long. Click the body to score a crack exactly where you clicked,
## drag the glass constants live, and re-run the rite as often as you like — the
## same job the benchmark needs a separate glass-compare.html page for.
##
## The states sheet shows what the benchmark actually has, which is NOT a set of
## HP steps: HP moves the vial and leaves the body alone (COMBAT_CRACKS is off,
## and `.lowhp` is scoped away from the raster body). The glass language is
## spent on cracks and the death rite instead.
##
## The ground line and the contact shadows are drawn HERE, not in EnemyView —
## on a real screen the battlefield owns the ground, and an actor that carried
## its own floor could never stand on someone else's.

const CATALOG_PATH: String = "res://port_fixtures/content/core-mechanics.json"
const LOCALE_PATH: String = "res://port_fixtures/content/locale-en.json"

const MARGIN: float = 40.0
const GAP_X: float = 34.0
const ROW_GAP: float = 96.0
const CAPTION_H: float = 34.0
const CHROME_H: float = 96.0        # room the foot plate needs under the feet
const ROW_MAX_W: float = 2900.0
const PANEL_W: float = 300.0

## The states an enemy actually has in the benchmark. `cracks` is how many crack
## sites are scored into the glass; `ignite` is the death ramp 0..1.
const STATES: Array[Array] = [
	# label, hp_frac, ward, cracks, ignite, targeted, shatter
	["idle", 1.0, 0, 0, 0.0, false, false],
	["targeted", 0.72, 0, 0, 0.0, true, false],
	["warded", 0.72, 8, 0, 0.0, false, false],
	["cracked", 0.40, 0, 6, 0.0, false, false],
	["ignite", 0.05, 0, 8, 0.9, false, false],
	["shattered", 0.0, 0, 8, 1.0, false, true],
]

var content: ContentDB

var _sheet: Control
var _ground: Control
var _caption: Label
var _rows: Array[Dictionary] = []    # {ground: float, actors: Array[EnemyView]}
var _count: int = 0
var _mode: String = "roster"
var _sheet_size: Vector2 = Vector2.ZERO

# --- bench only
var _roster: Dictionary = {}
var _names: Dictionary = {}
var _ids: Array[String] = []
var _bench_actor: EnemyView = null
var _bench_id: String = ""
var _knobs: Dictionary = {}          # shader param -> live value
var _hp_frac: float = 1.0
var _zoom: float = 1.0
var _pan: Vector2 = Vector2.ZERO
var _panning: bool = false
var _auto_zoom: bool = true
var _readout: Label = null
var _strip_path: String = "/tmp/enemy-rite.png"
## The subject of whichever strip mode is running — `--rite` or `--hit`.
var _strip_id: String = ""
## `--incidental` makes the struck beat a poison tick rather than a sword blow.
var _hit_direct: bool = true
var _picker: OptionButton = null
var _meta_rows: Dictionary = {}
var _light_yaw: float = -32.0
var _light_pitch: float = -38.0


## The two heroes stand on the same ground line as the foes and get the same
## actor, so the bench can tune them side by side. They are not in the enemy
## mechanics fixture (they are the player's aspects), so their bench-only
## stat line lives here rather than being faked into the roster file.
const HEROES: Dictionary = {
	"duskblade": {"name": "Duskblade", "hp": [70, 70], "art": {"hue": 214}},
	"ashwarden": {"name": "Ashwarden", "hp": [78, 78], "art": {"hue": 26}},
}


## `--msaa=off|2|4|8`. Anything else keeps the authored 4x rather than guessing,
## because silently falling back to "off" would make a typo look like a saving.
static func _msaa_of(text: String) -> Viewport.MSAA:
	match text.to_lower():
		"off", "0", "1":
			return Viewport.MSAA_DISABLED
		"2", "2x":
			return Viewport.MSAA_2X
		"4", "4x":
			return Viewport.MSAA_4X
		"8", "8x":
			return Viewport.MSAA_8X
	push_warning("enemy lab: --msaa=%s not understood — keeping 4x" % text)
	return Viewport.MSAA_4X


static func load_roster(fallback: ContentDB) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(CATALOG_PATH)
	if not text.is_empty():
		var raw: Variant = JSON.parse_string(text)
		if typeof(raw) == TYPE_DICTIONARY:
			var doc: Dictionary = raw
			var mech: Variant = doc.get("mechanics")
			if typeof(mech) == TYPE_DICTIONARY:
				var mechanics: Dictionary = mech
				var all: Variant = mechanics.get("ENEMIES")
				if typeof(all) == TYPE_DICTIONARY:
					var out: Dictionary = all
					return out
	push_warning("enemy lab: %s unreadable — falling back to the slice registry"
		% CATALOG_PATH)
	return fallback.enemies


## Display names live in locale, never in the mechanics fixture (SKILL §3).
static func load_names() -> Dictionary:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(LOCALE_PATH))
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var doc: Dictionary = raw
	var domains: Variant = doc.get("domains")
	if typeof(domains) != TYPE_DICTIONARY:
		return {}
	var d: Dictionary = domains
	var enemies: Variant = d.get("enemies")
	if typeof(enemies) != TYPE_DICTIONARY:
		return {}
	var out: Dictionary = enemies
	return out


func _init(content_ref: ContentDB) -> void:
	content = content_ref
	var only: PackedStringArray = PackedStringArray()
	var states_id: String = ""
	# Each lab owns its own args (main.gd §labs), so the four lab sessions never
	# collide in the shared parse loop.
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",", false)
		elif arg == "--states":
			_mode = "states"
		elif arg.begins_with("--states="):
			_mode = "states"
			states_id = arg.trim_prefix("--states=")
		elif arg == "--bench":
			_mode = "bench"
		elif arg.begins_with("--bench="):
			_mode = "bench"
			states_id = arg.trim_prefix("--bench=")
		elif arg == "--rite":
			_mode = "rite"
		elif arg.begins_with("--rite="):
			_mode = "rite"
			states_id = arg.trim_prefix("--rite=")
		elif arg == "--hit":
			_mode = "hit"
		elif arg.begins_with("--hit="):
			_mode = "hit"
			states_id = arg.trim_prefix("--hit=")
		elif arg == "--incidental":
			_hit_direct = false
		# The rite's fireworks are additive and cover the debris completely, so a
		# shatter frame cannot be read for whether the body broke along its own
		# cracks while they are on. This is the flag that makes the shatter
		# judgeable, and it is why it exists.
		elif arg == "--bare":
			EnemyView.rite_fx = false
		elif arg.begins_with("--flare="):
			var fr: String = arg.trim_prefix("--flare=")
			if fr.is_valid_float() and float(fr) >= 0.0:
				EnemyView.flare_gain = float(fr)
			else:
				push_warning("enemy lab: --flare=%s not a number — keeping %.2f"
					% [fr, EnemyView.flare_gain])
		elif arg.begins_with("--strip="):
			_strip_path = arg.trim_prefix("--strip=")
		# The two memory knobs, priced in docs/actor-stage-frame-budget.md and left
		# to this lane to judge. Read here rather than hard-coded so the same
		# creature can be shot at several settings and the shots diffed at 1:1 —
		# which is the only way to see what the saving costs. Set before any actor
		# exists, because both are read while the stage is being built.
		elif arg.begins_with("--oversample="):
			# Validated, not clamped. `float("")` is 0.0, so a clamp would quietly
			# turn a mistyped flag into the blurriest setting on the dial — and a
			# blurry shot labelled as a saving is worse than no shot.
			var raw: String = arg.trim_prefix("--oversample=")
			if raw.is_valid_float() and float(raw) > 0.0:
				EnemyView.oversample = float(raw)
			else:
				push_warning("enemy lab: --oversample=%s not a positive number — keeping %.2f"
					% [raw, EnemyView.oversample])
		elif arg.begins_with("--msaa="):
			EnemyView.msaa = _msaa_of(arg.trim_prefix("--msaa="))

	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GlassStyle.theme()

	var field: ColorRect = ColorRect.new()
	field.color = CardLab.BACKDROP
	field.set_anchors_preset(Control.PRESET_FULL_RECT)
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(field)

	var roster: Dictionary = load_roster(content_ref)
	for hero_id: String in HEROES:
		roster[hero_id] = HEROES[hero_id]
	var names: Dictionary = load_names()
	var ids: Array[String] = []
	for k: Variant in roster.keys():
		ids.append(str(k))
	ids.sort()
	if not only.is_empty():
		var wanted: Array[String] = []
		var missing: Array[String] = []
		for req: String in only:
			if ids.has(req):
				wanted.append(req)
			else:
				missing.append(req)
		if not missing.is_empty():
			push_warning("enemy lab: no such enemy id: %s" % ", ".join(missing))
			print("enemy lab: no such enemy id: %s" % ", ".join(missing))
		ids = wanted

	# Hand-placed: actors stand on ground lines, which no container models.
	_sheet = Control.new()
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sheet)
	# The ground is its own node, first inside the sheet: a parent's _draw runs
	# BEFORE its children, so lines drawn on the lab itself land under the
	# opaque backdrop and vanish. Here they land under the actors, which is
	# where a floor belongs.
	_ground = Control.new()
	_ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ground.draw.connect(_draw_ground)
	_sheet.add_child(_ground)

	_roster = roster
	_names = names
	_ids = ids
	if _mode == "rite" or _mode == "hit":
		var pick_r: String = states_id
		if pick_r == "" or not roster.has(pick_r):
			pick_r = "duskfang" if roster.has("duskfang") else (str(ids[0]) if not ids.is_empty() else "")
		_strip_id = pick_r
	elif _mode == "bench":
		var want: String = states_id
		if want == "" or not roster.has(want):
			want = "duskfang" if roster.has("duskfang") else (str(ids[0]) if not ids.is_empty() else "")
		_build_panel()
		_build_bench(want)
	elif _mode == "states":
		var pick: String = states_id
		if pick == "" and not ids.is_empty():
			pick = ids[0] if only.is_empty() else ids[0]
		if pick == "" or not roster.has(pick):
			pick = "duskfang" if roster.has("duskfang") else str(ids[0])
		var pick_def: Dictionary = roster.get(pick, {})
		var pick_locale: Dictionary = names.get(pick, {})
		_build_states(pick, pick_def, pick_locale)
	else:
		_build_roster(ids, roster, names)

	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", 12)
	_caption.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
	_caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.offset_top = -26
	_caption.offset_bottom = -8
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caption)


## One actor, dressed and placed with its feet on `ground`.
func _actor(id: String, def: Dictionary, locale: Dictionary, x: float,
		ground: float) -> EnemyView:
	var art: Dictionary = def.get("art", {})
	var hue: float = art.get("hue", 210)
	var display: String = str(locale.get("name", def.get("name", id)))
	var view: EnemyView = EnemyView.new(0, display, hue, StringName(id))
	# Feet are the box bottom; footY lifts (or sinks) the actor off the line,
	# footX slides it — the benchmark's bfEnemyFootX / bfEnemyFootY.
	view.position = Vector2(x + view.foot.x, ground - view.size.y - view.foot.y)
	_sheet.add_child(view)
	return view


static func _tier_of(def: Dictionary) -> String:
	var boss: bool = def.get("boss", false)
	var elite: bool = def.get("elite", false)
	return "boss" if boss else ("elite" if elite else "normal")


static func _facet_max(def: Dictionary) -> int:
	var boss: bool = def.get("boss", false)
	var elite: bool = def.get("elite", false)
	var facets: int = def.get("facets", 6 if boss else (5 if elite else 4))
	return maxi(2, facets)


static func _max_hp(def: Dictionary) -> int:
	var hp_range: Array = def.get("hp", [1, 1])
	var top: int = hp_range[hp_range.size() - 1] if not hp_range.is_empty() else 1
	return maxi(top, 1)


## The scale chart: smallest first, packed into rows that each share a ground
## line, so the ladder reads left to right and top to bottom.
func _build_roster(ids: Array[String], roster: Dictionary, names: Dictionary) -> void:
	var sized: Array[Array] = []
	for id: String in ids:
		sized.append([EnemyView.art_box(StringName(id)), id])
	sized.sort_custom(func(a: Array, b: Array) -> bool:
		var wa: float = a[0]
		var wb: float = b[0]
		return wa < wb)

	var y: float = MARGIN
	var widest: float = 0.0
	var i: int = 0
	while i < sized.size():
		# Greedy fill: take actors until the row would overrun.
		var row_ids: Array[String] = []
		var row_w: float = 0.0
		var row_h: float = 0.0
		while i < sized.size():
			var w: float = sized[i][0]
			var add: float = w if row_ids.is_empty() else w + GAP_X
			if not row_ids.is_empty() and row_w + add > ROW_MAX_W:
				break
			row_w += add
			row_h = maxf(row_h, w)
			row_ids.append(str(sized[i][1]))
			i += 1
		var ground: float = y + row_h
		var x: float = MARGIN
		var actors: Array[EnemyView] = []
		for id: String in row_ids:
			var def: Dictionary = roster.get(id, {})
			var locale: Dictionary = names.get(id, {})
			var view: EnemyView = _actor(id, def, locale, x, ground)
			view.set_hp(_max_hp(def), _max_hp(def))
			view.set_facets(0, _facet_max(def))
			view.set_ward(0)
			view.clear_intent()
			view.align_plate(ground - (view.position.y + view.size.y))
			actors.append(view)
			x += view.art_size + GAP_X
		_rows.append({"ground": ground, "actors": actors, "width": x - GAP_X - MARGIN})
		widest = maxf(widest, x - GAP_X + MARGIN)
		y = ground + CHROME_H + ROW_GAP
		_count += row_ids.size()
	_sheet_size = Vector2(widest, y - ROW_GAP + MARGIN)
	# Centre every row against the widest: sorted by size, the tail rows hold two
	# or three giants and would otherwise sit hard left against a page of nothing.
	for row: Dictionary in _rows:
		var row_w: float = row["width"]
		var shift: float = (widest - MARGIN * 2.0 - row_w) * 0.5
		if shift <= 0.0:
			continue
		for a: Variant in row["actors"]:
			var view: EnemyView = a
			view.position.x += shift


## One enemy across the states it really has.
func _build_states(id: String, def: Dictionary, locale: Dictionary) -> void:
	var box: float = EnemyView.art_box(StringName(id))
	if box <= 0.0:
		box = 185.0
	var max_hp: int = _max_hp(def)
	var facet_max: int = _facet_max(def)
	var ground: float = MARGIN + box
	var x: float = MARGIN
	var actors: Array[EnemyView] = []
	for s: Array in STATES:
		var frac: float = s[1]
		var ward: int = s[2]
		var cracks: int = s[3]
		var ignite: float = s[4]
		var targeted: bool = s[5]
		var breaks: bool = s[6]
		var view: EnemyView = _actor(id, def, locale, x, ground)
		view.set_hp(maxi(1, int(roundf(float(max_hp) * frac))), max_hp)
		view.set_facets(cracks / 2, facet_max)
		view.set_ward(ward)
		view.clear_intent()
		# EnemyView's cap, not a second copy of it. This file carried its own
		# `MAX_SITES = 32` and the two drifted apart the moment the real cap moved.
		for _c: int in range(mini(cracks, EnemyView.MAX_SITES)):
			view.crack()
		if ignite > 0.0:
			view.set_ignite(ignite)
		view.set_targetable(targeted)
		if breaks:
			# main.gd holds ~30 frames before it captures, so the shards are
			# caught mid-flight — which is the only way a still shows physics.
			view.shatter()
		view.align_plate(ground - (view.position.y + view.size.y))
		actors.append(view)
		var tag: Label = Label.new()
		tag.text = str(s[0])
		tag.position = Vector2(x, ground + CHROME_H - 8.0)
		tag.custom_minimum_size = Vector2(box, 0.0)
		tag.size = Vector2(box, 18.0)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.add_theme_font_size_override("font_size", 12)
		tag.add_theme_color_override("font_color", GlassStyle.EMBER)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sheet.add_child(tag)
		x += box + GAP_X
	_rows.append({"ground": ground, "actors": actors})
	_count = STATES.size()
	_sheet_size = Vector2(x - GAP_X + MARGIN, ground + CHROME_H + MARGIN)


# ---------------------------------------------------------------- the bench

## Every knob the glass has, with the benchmark's approved measures as the
## starting point (docs/glass-crack-rendering.md §4.2). `warp` is
## mesh.js INTENSITY; `seam_gain` is this port's own, because a seam that only
## lights during ignite is impossible to tune while it is dark.
const KNOBS: Array[Array] = [
	# label, param, low, high, default
	["key light", "key", 0.0, 6.0, 1.5],
	["rim light", "rim", 0.0, 10.0, 1.8],
	["ignite", "ignite", 0.0, 1.0, 0.0],
	["glass area", "glass_area", 0.05, 1.2, 0.45],
	["glass roughness", "roughness", 0.0, 0.5, 0.12],
	["refraction bend", "refraction", 0.0, 0.25, 0.055],
	["ior", "ior", 1.0, 2.4, 1.45],
	["glass alpha", "alpha", 0.0, 1.0, 0.55],
	["relief (bump)", "bump", 0.0, 20.0, 3.5],
	["idle motion", "breathe", 0.0, 4.0, 1.0],
	## Awaiting a decision — the struck flash's strength. Judged here rather than
	## from strips because a 300ms beat in a still is weak evidence for anything.
	["struck flash", "flare_gain", 0.0, 3.0, 1.0],
]

## Per-creature layout, the values that live in char-meta.json. Editing these is
## the point of the editor half: they are the numbers the benchmark's ?charedit=1
## and ?bfedit=1 exist to nudge, and nobody can pick them from a spreadsheet.
const META_KNOBS: Array[Array] = [
	# label, json key, low, high
	["scale", "scale", 0.2, 4.5],
	["footX", "footX", -220.0, 220.0],
	["footY", "footY", -260.0, 260.0],
]


func _build_panel() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", GlassStyle.pane(GlassStyle.GLASS))
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -PANEL_W
	panel.offset_top = 8.0
	panel.offset_right = -8.0
	panel.offset_bottom = -8.0
	add_child(panel)

	var scroll: ScrollContainer = ScrollContainer.new()
	panel.add_child(scroll)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)

	var title: Label = Label.new()
	title.text = "ENEMY BENCH"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", GlassStyle.EMBER)
	rows.add_child(title)

	_picker = OptionButton.new()
	for id: String in _ids:
		_picker.add_item(id)
	_picker.item_selected.connect(func(i: int) -> void:
		_build_bench(_ids[i])
		_relayout_bench())
	rows.add_child(_picker)

	# The struck beat is 300ms and its flash peaks at 90ms, so it is unjudgeable
	# from a still. Two buttons rather than one because the whole point of the port
	# is that a sword blow and a poison tick are different events: the first shoves
	# and squashes, the second only twitches.
	rows.add_child(_button("strike it   (H)", func() -> void:
		if _bench_actor != null:
			_bench_actor.take_hit(true)))
	rows.add_child(_button("poison it   (J)", func() -> void:
		if _bench_actor != null:
			_bench_actor.take_hit(false)))

	rows.add_child(_button("+ crack   (C)", func() -> void:
		if _bench_actor != null:
			_bench_actor.crack()))
	rows.add_child(_button("shatter now   (S)", func() -> void:
		if _bench_actor != null:
			_bench_actor.shatter()))
	rows.add_child(_button("run the death rite   (K)", func() -> void:
		if _bench_actor != null:
			_bench_actor.mark_dead()))
	rows.add_child(_button("fireworks on/off   (F)", func() -> void:
		EnemyView.rite_fx = not EnemyView.rite_fx))
	rows.add_child(_button("rebuild the vessel   (R)", func() -> void:
		_build_bench(_bench_id)
		_relayout_bench()))

	# Slow-mo is not a luxury here: the rite is under a second and the shards
	# settle in two. Engine.time_scale drives the physics too, so the break can
	# be watched frame by frame instead of guessed at.
	var ts_lbl: Label = _dim("time scale   1.00x")
	rows.add_child(ts_lbl)
	var ts: HSlider = HSlider.new()
	ts.min_value = 0.05
	ts.max_value = 1.0
	ts.step = 0.01
	ts.value = 1.0
	ts.value_changed.connect(func(v: float) -> void:
		Engine.time_scale = v
		ts_lbl.text = "time scale   %.2fx" % v)
	rows.add_child(ts)

	# Real lighting only proves it is real when it swings.
	var yaw_lbl: Label = _dim("key yaw   -32")
	rows.add_child(yaw_lbl)
	var yaw: HSlider = HSlider.new()
	yaw.min_value = -180.0
	yaw.max_value = 180.0
	yaw.step = 1.0
	yaw.value = -32.0
	yaw.value_changed.connect(func(v: float) -> void:
		_light_yaw = v
		yaw_lbl.text = "key yaw   %d" % int(v)
		if _bench_actor != null:
			_bench_actor.set_light_angle(_light_yaw, _light_pitch))
	rows.add_child(yaw)
	var pitch_lbl: Label = _dim("key pitch   -38")
	rows.add_child(pitch_lbl)
	var pitch: HSlider = HSlider.new()
	pitch.min_value = -89.0
	pitch.max_value = 20.0
	pitch.step = 1.0
	pitch.value = -38.0
	pitch.value_changed.connect(func(v: float) -> void:
		_light_pitch = v
		pitch_lbl.text = "key pitch   %d" % int(v)
		if _bench_actor != null:
			_bench_actor.set_light_angle(_light_yaw, _light_pitch))
	rows.add_child(pitch)

	for k: Array in KNOBS:
		var param: String = k[1]
		var lo: float = k[2]
		var hi: float = k[3]
		var start: float = k[4]
		_slider(rows, str(k[0]), StringName(param), lo, hi, start)

	var hp_lbl: Label = _dim("hp   100%")
	rows.add_child(hp_lbl)
	var hp: HSlider = HSlider.new()
	hp.min_value = 0.0
	hp.max_value = 1.0
	hp.step = 0.01
	hp.value = 1.0
	hp.value_changed.connect(func(v: float) -> void:
		_hp_frac = v
		hp_lbl.text = "hp   %d%%" % int(roundf(v * 100.0))
		_apply_hp())
	rows.add_child(hp)

	var ward: CheckButton = CheckButton.new()
	ward.text = "ward"
	ward.toggled.connect(func(on: bool) -> void:
		if _bench_actor != null:
			_bench_actor.set_ward(8 if on else 0))
	rows.add_child(ward)

	var aim: CheckButton = CheckButton.new()
	aim.text = "targeted"
	aim.toggled.connect(func(on: bool) -> void:
		if _bench_actor != null:
			_bench_actor.set_targetable(on))
	rows.add_child(aim)

	# ---- editor half: the numbers that belong to the creature, not the glass.
	var head: Label = Label.new()
	head.text = "CHAR-META"
	head.add_theme_font_size_override("font_size", 12)
	head.add_theme_color_override("font_color", GlassStyle.EMBER)
	rows.add_child(head)
	for k: Array in META_KNOBS:
		var key: String = k[1]
		var lo2: float = k[2]
		var hi2: float = k[3]
		_meta_slider(rows, str(k[0]), key, lo2, hi2)
	rows.add_child(_button("save char-meta.json", func() -> void:
		var ok: bool = EnemyView.save_meta()
		_readout.text = ("saved char-meta.json" if ok
			else "could not write char-meta.json")))

	_readout = _dim("")
	_readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(_readout)

	var hint: Label = _dim("H strike · J poison · F fireworks off (see the shards)\nclick the body to crack it there\ndrag to pan · wheel to zoom\n[ ] prev / next enemy\nthe rite is a foe's — H and J work on a hero, K and S do not")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(hint)


## A char-meta value. Rebuilds the actor on release rather than per-frame — the
## size change re-creates a SubViewport, which is not a per-pixel-of-drag cost.
func _meta_slider(rows: VBoxContainer, label: String, key: String,
		lo: float, hi: float) -> void:
	var l: Label = _dim(label)
	rows.add_child(l)
	var s: HSlider = HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.01 if key == "scale" else 1.0
	s.value_changed.connect(func(v: float) -> void:
		l.text = "%s   %.2f" % [label, v]
		EnemyView.set_meta_value(StringName(_bench_id), key, v)
		if key == "scale":
			_build_bench(_bench_id)
		elif _bench_actor != null:
			var f: Vector2 = _bench_actor.foot
			_bench_actor.foot = Vector2(v, f.y) if key == "footX" else Vector2(f.x, v)
		_relayout_bench())
	rows.add_child(s)
	_meta_rows[key] = s


static func _dim(text: String) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
	return l


func _button(text: String, on_press: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	GlassStyle.style_button(b, GlassStyle.GLASS)
	b.pressed.connect(on_press)
	return b


## One live glass constant. The label carries its own value so the panel reads
## like the benchmark's slider bank rather than a row of anonymous tracks.
func _slider(rows: VBoxContainer, label: String, param: StringName,
		lo: float, hi: float, value: float) -> void:
	_knobs[param] = value
	var l: Label = _dim("%s   %.2f" % [label, value])
	rows.add_child(l)
	var s: HSlider = HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.01
	s.value = value
	s.value_changed.connect(func(v: float) -> void:
		_knobs[param] = v
		l.text = "%s   %.2f" % [label, v]
		if _bench_actor != null:
			_bench_actor.set_glass_param(param, v))
	rows.add_child(s)


## Rebuild the actor from scratch. Cheaper than unwinding a death rite, and it
## guarantees the bench always starts from the same vessel.
func _build_bench(id: String) -> void:
	_bench_id = id
	if _bench_actor != null:
		_bench_actor.queue_free()
		_bench_actor = null
	if not _roster.has(id):
		return
	var def: Dictionary = _roster.get(id, {})
	var locale: Dictionary = _names.get(id, {})
	# Placed at the origin; _relayout_bench frames it once the stage is known.
	_bench_actor = _actor(id, def, locale, 0.0, 0.0)
	_bench_actor.set_facets(0, _facet_max(def))
	_bench_actor.clear_intent()
	_bench_actor.set_ward(0)
	for param: Variant in _knobs.keys():
		var v: float = _knobs[param]
		_bench_actor.set_glass_param(StringName(str(param)), v)
	_apply_hp()
	_bench_actor.set_light_angle(_light_yaw, _light_pitch)
	# Point the char-meta sliders at THIS creature without re-firing their
	# handlers, or selecting a new enemy would immediately overwrite its numbers
	# with the previous one's.
	var entry: Dictionary = EnemyView.meta(StringName(id))
	for key: Variant in _meta_rows.keys():
		var sl: HSlider = _meta_rows[key]
		var dv: float = 1.0 if key == "scale" else 0.0
		var cur: float = entry.get(str(key), dv)
		sl.set_block_signals(true)
		sl.value = cur
		sl.set_block_signals(false)
	if _picker != null:
		var at: int = _ids.find(id)
		if at >= 0:
			_picker.select(at)
	# Re-frame per creature: 115px and 1120px cannot share one zoom, and a bench
	# that opens with the subject a speck is a bench you have to fix before use.
	_auto_zoom = true
	if _readout != null:
		_readout.text = "%s · %s · %d px box · foot %d,%d" % [
			id, _tier_of(def), int(_bench_actor.art_size),
			int(_bench_actor.foot.x), int(_bench_actor.foot.y)]


func _apply_hp() -> void:
	if _bench_actor == null:
		return
	var def: Dictionary = _roster.get(_bench_id, {})
	var max_hp: int = _max_hp(def)
	_bench_actor.set_hp(maxi(1, int(roundf(float(max_hp) * _hp_frac))), max_hp)


## Frame the actor against whatever stage is left of the panel, then apply the
## user's pan and zoom.
func _relayout_bench() -> void:
	if _bench_actor == null:
		return
	var stage: Vector2 = size
	var view_w: float = stage.x - PANEL_W - 24.0
	var ground: float = stage.y * 0.74
	_sheet_size = Vector2(view_w, stage.y)
	_bench_actor.position = Vector2(
		(view_w - _bench_actor.size.x) * 0.5 + _bench_actor.foot.x,
		ground - _bench_actor.size.y - _bench_actor.foot.y)
	_bench_actor.align_plate(ground - (_bench_actor.position.y + _bench_actor.size.y))
	_rows = [{"ground": ground, "actors": [_bench_actor], "width": _bench_actor.size.x}]
	_ground.size = _sheet_size
	if _auto_zoom:
		_zoom = clampf(stage.y * 0.52 / maxf(_bench_actor.art_size, 1.0), 0.2, 5.0)
		_pan = Vector2.ZERO
		_auto_zoom = false
	# Scale about the actor's feet, not the sheet origin — a standing figure
	# should grow out of the ground line, not slide off it.
	_sheet.pivot_offset = Vector2(view_w * 0.5, ground)
	_apply_view()
	_ground.queue_redraw()


func _apply_view() -> void:
	_sheet.scale = Vector2(_zoom, _zoom)
	_sheet.position = _pan
	_caption.text = "enemy lab · bench · %s · %d%%" % [_bench_id, int(roundf(_zoom * 100.0))]


## Click the body to score a crack exactly where the pointer landed — the whole
## reason the bench exists. Hit-tested through the actor's own transform so pan
## and zoom cannot skew the UV.
func _gui_input(event: InputEvent) -> void:
	if _mode != "bench":
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and _bench_actor != null:
				var local: Vector2 = _bench_actor.get_global_transform().affine_inverse() \
					* mb.global_position
				var uv: Vector2 = local / _bench_actor.size
				if uv.x >= 0.0 and uv.x <= 1.0 and uv.y >= 0.0 and uv.y <= 1.0:
					_bench_actor.crack(uv)
					return
			_panning = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = clampf(_zoom * 1.1, 0.2, 5.0)
			_apply_view()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = clampf(_zoom / 1.1, 0.2, 5.0)
			_apply_view()
		return
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null and _panning:
		_pan += mm.relative
		_apply_view()


func _unhandled_key_input(event: InputEvent) -> void:
	if _mode != "bench":
		return
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_H:
			if _bench_actor != null:
				_bench_actor.take_hit(true)
		KEY_J:
			if _bench_actor != null:
				_bench_actor.take_hit(false)
		KEY_C:
			if _bench_actor != null:
				_bench_actor.crack()
		KEY_K:
			if _bench_actor != null:
				_bench_actor.mark_dead()
		KEY_S:
			if _bench_actor != null:
				_bench_actor.shatter()
		KEY_F:
			EnemyView.rite_fx = not EnemyView.rite_fx
		KEY_R:
			_build_bench(_bench_id)
			_relayout_bench()
		KEY_BRACKETLEFT, KEY_BRACKETRIGHT:
			var at: int = _ids.find(_bench_id)
			var step: int = -1 if k.keycode == KEY_BRACKETLEFT else 1
			if at >= 0 and not _ids.is_empty():
				_build_bench(_ids[posmod(at + step, _ids.size())])
				_relayout_bench()


## The ground the actors stand on, plus a contact shadow under each. Sheet-local
## coordinates, so no sheet offset enters the maths.
func _draw_ground() -> void:
	# Commands must be issued ON the node that is drawing: a bare draw_line()
	# here would target the lab, which is not in its draw notification, and
	# Godot would drop it.
	for row: Dictionary in _rows:
		var ground: float = row["ground"]
		var actors: Array = row["actors"]
		if actors.is_empty():
			continue
		# Overdrawn well past the sheet: under bench zoom the line lives in sheet
		# space, and one that stopped at the sheet edge would hang in mid-air.
		_ground.draw_line(Vector2(-6000.0, ground), Vector2(6000.0, ground),
			Color(GlassStyle.GLASS.r, GlassStyle.GLASS.g, GlassStyle.GLASS.b, 0.18), 1.0)
		# No blob here any more. Each actor casts its own shadow inside its own
		# stage, projected along the key light off its own silhouette — so it
		# leans when the light swings and fades when the creature floats, which
		# a circle drawn on the floor could never do.


func _ready() -> void:
	_grow_window()
	if _mode == "rite":
		await _shoot_strip(RITE_FRAMES, "rite",
			func(v: EnemyView) -> void: v.mark_dead())
		return
	if _mode == "hit":
		await _shoot_strip(HIT_FRAMES, "hit",
			func(v: EnemyView) -> void: v.take_hit(_hit_direct))
		return
	if _mode == "bench":
		# No auto-fit here: the bench is driven, not framed. Zoom is the user's.
		get_window().content_scale_factor = 1.0
		await get_tree().process_frame
		_relayout_bench()
		get_viewport().size_changed.connect(_relayout_bench)
		return
	# One frame, then measure: project.godot stretches canvas_items off a fixed
	# 1180x820 base, so the stage is NOT the window's pixel size. This Control is
	# full-rect, so its own size is the stage in the units the sheet is built in.
	await get_tree().process_frame
	var stage: Vector2 = size
	var need: Vector2 = _sheet_size + Vector2(0.0, CAPTION_H)
	var fit: float = 1.0
	if need.x > 0.0 and need.y > 0.0:
		fit = minf(stage.x / need.x, stage.y / need.y)
	# Capped at 1:1 — magnifying an already-rasterised sheet reads as blur.
	var scale_at: float = minf(1.0, fit)
	get_window().content_scale_factor = scale_at
	await get_tree().process_frame
	# Centre the sheet in whatever stage the scale bought.
	var stage2: Vector2 = size
	_sheet.position = Vector2(
		maxf(0.0, (stage2.x - _sheet_size.x) * 0.5),
		maxf(0.0, (stage2.y - CAPTION_H - _sheet_size.y) * 0.5))
	_ground.size = _sheet_size
	_ground.queue_redraw()
	_caption.text = "enemy lab · %s · %d %s · %s" % [
		_mode, _count, "enemies" if _mode == "roster" else "states",
		"1:1" if is_equal_approx(scale_at, 1.0) else "%d%%" % int(roundf(scale_at * 100.0))]


## A still cannot show a beat that is over in a fraction of a second. These run the
## REAL thing — the same combat calls, the same tweens, the same physics — and
## photograph it at intervals, then lay the frames out as one strip. Deliberately
## NOT `--shot`: main.gd's capture fires once after ~30 frames, which for the rite
## lands before the shards have moved and for a hit lands after it is over.
const RITE_FRAMES: Array[float] = [0.0, 0.12, 0.3, 0.55, 0.9, 1.5]
## The recoil is 300ms and its flash peaks at 90ms, so the frames cluster early.
## A strip evenly spaced across 300ms would miss the peak entirely.
const HIT_FRAMES: Array[float] = [0.0, 0.04, 0.09, 0.15, 0.22, 0.32]


## Stand one actor up, run `action` on it, photograph `frames`, save the strip.
## Shared by `--rite` and `--hit` because only those three things differ; the
## framing, the hi-dpi crop derivation and the tiling are the same job twice.
func _shoot_strip(frames: Array[float], label: String, action: Callable) -> void:
	get_window().content_scale_factor = 1.0
	await get_tree().process_frame
	var def: Dictionary = _roster.get(_strip_id, {})
	var locale: Dictionary = _names.get(_strip_id, {})
	var stage: Vector2 = size
	var ground: float = stage.y * 0.72
	var view: EnemyView = _actor(_strip_id, def, locale, 0.0, ground)
	view.position = Vector2((stage.x - view.size.x) * 0.5, ground - view.size.y - view.foot.y)
	view.set_hp(_max_hp(def), _max_hp(def))
	view.set_facets(0, _facet_max(def))
	view.clear_intent()
	_rows = [{"ground": ground, "actors": [view], "width": view.size.x}]
	_sheet_size = stage
	_ground.size = stage
	_ground.queue_redraw()
	await get_tree().process_frame

	action.call(view)
	# Photograph the whole frame first. The viewport texture's reported size and
	# the size of the image it actually hands back do not always agree on a
	# hi-dpi window, so the crop is derived from the FRAME, after the fact.
	var shots: Array[Image] = []
	# Wait against ELAPSED time, not against the gap to the previous frame. Chaining
	# deltas adds the `frame_post_draw` await to every step, so a six-frame strip
	# drifted ~100 ms late by its last cell and a 90 ms flash looked as though it
	# had already finished by the third.
	var t0: float = float(Time.get_ticks_msec()) * 0.001
	for t: float in frames:
		while float(Time.get_ticks_msec()) * 0.001 - t0 < t:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		shots.append(get_viewport().get_texture().get_image())

	var k: float = float(shots[0].get_width()) / maxf(stage.x, 1.0)
	var pad: float = maxf(view.size.x * 0.85, 130.0)
	var top: float = view.position.y - pad * 0.5
	var bot: float = ground + pad * 0.8
	var crop: Rect2i = Rect2i(
		int(maxf(0.0, (view.position.x - pad) * k)),
		int(maxf(0.0, top * k)),
		int((view.size.x + pad * 2.0) * k),
		int((bot - top) * k))
	crop.size.x = mini(crop.size.x, shots[0].get_width() - crop.position.x)
	crop.size.y = mini(crop.size.y, shots[0].get_height() - crop.position.y)
	print("%s stage=%s frame=%dx%d k=%.3f crop=%s" % [
		label.to_upper(), stage, shots[0].get_width(), shots[0].get_height(), k, crop])
	var cells: Array[Image] = []
	for img: Image in shots:
		var cell: Image = Image.create_empty(
			crop.size.x, crop.size.y, false, img.get_format())
		cell.blit_rect(img, crop, Vector2i.ZERO)
		cells.append(cell)
	shots = cells

	var strip: Image = Image.create_empty(
		crop.size.x * shots.size(), crop.size.y, false, shots[0].get_format())
	for i: int in range(shots.size()):
		strip.blit_rect(shots[i], Rect2i(Vector2i.ZERO, crop.size),
			Vector2i(crop.size.x * i, 0))
	strip.save_png(_strip_path)
	print("%s strip saved: %s  (%d frames at %s s)" % [
		label, _strip_path, shots.size(), ", ".join(frames.map(
			func(v: float) -> String: return "%.2f" % v))])
	get_tree().quit(0)


## Take the usable screen before measuring: every pixel the window gains is
## resolution the sheet does not have to scale away.
func _grow_window() -> void:
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(
		DisplayServer.window_get_current_screen())
	if usable.size.x <= 0 or usable.size.y <= 0:
		return  # headless / no display
	var win: Window = get_window()
	var got: Vector2i = Vector2i(usable.size.x - 40, usable.size.y - 60)
	win.size = got
	win.position = usable.position + (usable.size - got) / 2
