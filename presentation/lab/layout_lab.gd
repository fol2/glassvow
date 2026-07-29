class_name LayoutLab
extends Control
## The layout bench: `assets/layout/combat-layout.json` drawn over the screen it
## composes, at any of the five stage shapes, with every number's ORIGIN shown.
##
##   godot --path . -- --layout                       # opens on pad-landscape
##   godot --path . -- --layout --shape=phone-portrait --scope=chrome
##   tools/shot.sh --layout --shape=pad-portrait --shot=/tmp/layout-pp.png
##
## Keys: 1-5 shape · , . act · S scope · L level · left/right field · up/down
## value (shift x10) · R revert · ctrl-S save · O overlay · H panel. Click a box
## to select it, drag it to author it. `--nopanel` captures the overlay alone.
##
## WHY THIS EXISTS, AND WHY IT IS ONE BENCH. The benchmark ships two editors for
## one screen — `?bfedit=1` (640+155 lines) for the battlefield, `?bfuiedit=1`
## (687+157) for the chrome — split only by the order they were built in. They
## are two copies of the same program because each one's serialiser re-declares
## its schema in code. `LayoutBook` declares the schema once, as data, so this
## bench walks `SCOPES` and gets both for free; reward, map and card join by
## adding a `SCOPES` entry, not by growing a third editor.
##
## THE THING BOTH BENCHMARK EDITORS DO WORST. `bf-editor.js:14-15` writes into a
## fixed bucket, so the number in front of you might be authored at this shape or
## inherited from base, and there is no way to tell — which means editing an
## inherited value silently promotes it to an override, and the override is
## invisible from then on. Every row here carries its origin (act / shape / base
## / default / absent) in its own colour, because "where does this come from" is
## the question an inheriting layout has to be able to answer before it is safe
## to author against.
##
## The picture under the overlay is a REAL fight — the same `GlassvowGame`, the
## same `CombatScreen`, constructed at the selected shape and act. Nothing here
## re-implements the composition, so the bench cannot drift from the screen it
## claims to describe. Only the boxes are drawn here, and they are computed from
## the same resolved layout the screen was handed.
##
## WHERE AN EDIT GOES is a choice, shown before it is made. `WRITE TO` starts on
## the level the value already lives at, so the first drag of an inherited number
## moves it where it is rather than promoting it — promoting is something you
## pick. Which fields a drag moves, and which way each one counts, is
## `LayoutBook.drag_step`'s answer out of the schema; this bench holds no table
## of its own, because a second table is what the benchmark's two serialisers
## were. Saving goes through `LayoutBook.save`, which validates before `DataFile`
## opens anything — a refused save leaves the file exactly as it was.

const PANEL_W: float = 366.0
const MARGIN: float = 12.0
## A fixed seed, so switching shape re-stands the same fight rather than a new
## one — an editor whose picture changes when you change tab is unusable.
const SEED: int = 20260727
## The book owns how many acts there are; the bench only draws that many tabs.
const ACTS: int = LayoutBook.ACTS

## The colour each origin is drawn in, in the overlay and in the inspector. They
## are deliberately far apart: this readout exists to be scanned, not read.
const ORIGIN_INK: Dictionary[StringName, Color] = {
	LayoutBook.FROM_ACT: Color(1.0, 0.60, 0.30),
	LayoutBook.FROM_SHAPE: Color(0.56, 0.82, 1.0),
	LayoutBook.FROM_BASE: Color(0.52, 0.78, 0.62),
	LayoutBook.FROM_DEFAULT: Color(0.58, 0.64, 0.80),
	# Muted, NOT alarming. A widget pinned to `left` having no `right` is the
	# correct state and the validator would complain if it had both; a readout
	# that painted every unauthored field red would cry wolf on most of the book.
	LayoutBook.FROM_ABSENT: Color(0.42, 0.40, 0.50),
}

var content: ContentDB

var _shape: StringName = StageShape.IDENTITY
var _act: int = 0
var _scope: StringName = &"battlefield"
var _foes: Array[String] = ["sporeling", "sporeling"]
var _selected: String = "hero"
## Which field of the selected box the arrow keys and R act on, as an index into
## the form's own order.
var _field: int = 0
## Which level an edit lands in. Not a constant and not the innermost one: see
## `_default_level`.
var _level: StringName = LayoutBook.FROM_SHAPE
var _dragging: bool = false
var _drag_from: Vector2 = Vector2.ZERO

var _game: GlassvowGame
var _screen: CombatScreen
var _host: Control
var _over: Control
var _panel: PanelContainer
var _rows: VBoxContainer
var _levels: VBoxContainer
var _save_button: Button
var _list: ItemList
var _status: Label
## Every box in the current scope: `path`, `form`, `label`, `rect`, `origin`.
## Rebuilt whenever the resolved layout changes, and the single source both the
## overlay and the inspector read — they cannot disagree about what is selected.
var _boxes: Array[Dictionary] = []


func _init(content_ref: ContentDB) -> void:
	content = content_ref
	# Unlike the mocks, a capture here KEEPS the panel: the readout is the thing
	# this bench produces, and a screenshot of the overlay without its origins is
	# a screenshot of the combat screen. `--nopanel` is for the overlay alone.
	var panelled: bool = true
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shape="):
			var want: StringName = StringName(arg.trim_prefix("--shape="))
			if StageShape.REFERENCES.has(want):
				_shape = want
		elif arg.begins_with("--act="):
			_act = clampi(int(arg.trim_prefix("--act=")), 0, ACTS - 1)
		elif arg.begins_with("--scope="):
			var scope: StringName = StringName(arg.trim_prefix("--scope="))
			if LayoutBook.SCOPES.has(scope):
				_scope = scope
		elif arg.begins_with("--target="):
			_selected = arg.trim_prefix("--target=")
		elif arg.begins_with("--foes="):
			_foes.assign(Array(arg.trim_prefix("--foes=").split(",", false)))
		elif arg == "--nopanel":
			panelled = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GlassStyle.theme()

	var back: ColorRect = ColorRect.new()
	back.color = Color(0.02, 0.025, 0.05)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)

	_host = Control.new()
	_host.mouse_filter = Control.MOUSE_FILTER_PASS
	_host.clip_contents = true
	add_child(_host)

	_over = Control.new()
	_over.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over.mouse_filter = Control.MOUSE_FILTER_STOP
	_over.draw.connect(_draw_overlay)
	_over.gui_input.connect(_on_overlay_input)
	_host.add_child(_over)

	_panel = _build_panel()
	add_child(_panel)
	_panel.visible = panelled

	_status = _caption("")
	_status.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.offset_top = -20.0
	_status.offset_bottom = -4.0
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_status)

	resized.connect(_relayout)
	_rebuild()


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var shapes: Array = StageShape.REFERENCES.keys()
	var index: int = key.keycode - KEY_1
	if key.ctrl_pressed or key.meta_pressed:
		if key.keycode != KEY_S:
			return
		_save()
	elif index >= 0 and index < shapes.size():
		_shape = shapes[index]
		_rebuild()
	elif key.keycode == KEY_COMMA or key.keycode == KEY_PERIOD:
		_act = wrapi(_act + (1 if key.keycode == KEY_PERIOD else -1), 0, ACTS)
		_rebuild()
	elif key.keycode == KEY_S:
		var scopes: Array = LayoutBook.SCOPES.keys()
		_scope = scopes[wrapi(scopes.find(_scope) + 1, 0, scopes.size())]
		_refresh()
	elif key.keycode == KEY_L:
		_level = LayoutBook.LEVELS[wrapi(LayoutBook.LEVELS.find(_level) + 1,
			0, LayoutBook.LEVELS.size())]
		_refresh_rows()
	elif key.keycode == KEY_LEFT or key.keycode == KEY_RIGHT:
		var names: PackedStringArray = LayoutBook.fields(_form())
		if names.is_empty():
			return
		_field = wrapi(_field + (1 if key.keycode == KEY_RIGHT else -1), 0, names.size())
		_refresh_rows()
	elif key.keycode == KEY_UP or key.keycode == KEY_DOWN:
		# Arrows move the ONE field in front of you, which is how `zoom`,
		# `opacity` and `s` are reachable at all — a drag can only move the
		# fields the schema binds to an edge.
		_nudge_field((1.0 if key.keycode == KEY_UP else -1.0)
			* (10.0 if key.shift_pressed else 1.0))
	elif key.keycode == KEY_R:
		_revert()
	elif key.keycode == KEY_O:
		_over.visible = not _over.visible
	elif key.keycode == KEY_H:
		_panel.visible = not _panel.visible
		_relayout()
	else:
		return
	accept_event()


# ---------------------------------------------------------------- the picture

## Stand the fight up again at the selected shape and act.
##
## Rebuilt rather than re-laid-out because `CombatScreen` resolves the book once
## in `_init` — shape is a construction-time fact for it, and pretending
## otherwise here would mean testing a screen no player will ever run.
func _rebuild() -> void:
	if _screen != null:
		_screen.queue_free()
		_screen = null
	var ref: Vector2 = Vector2(StageShape.REFERENCES[_shape])
	_host.size = ref
	_game = GlassvowGame.new(content, RunState.new_run(content, SEED))
	_screen = CombatScreen.new(_game, _shape, _act)
	_host.add_child(_screen)
	_host.move_child(_screen, 0)  # under the overlay, which draws last
	_screen.start_encounter(_foes, "normal", "layout bench")
	_relayout()
	_refresh()


## Fit the stage beside the panel. Never magnified past 1:1 — a phone shape
## blown up to fill a desktop window would be judged at a sharpness no phone has.
func _relayout() -> void:
	if _host == null:
		return
	var ref: Vector2 = Vector2(StageShape.REFERENCES[_shape])
	var gutter: float = (PANEL_W + MARGIN) if _panel != null and _panel.visible else 0.0
	var avail: Vector2 = Vector2(maxf(80.0, size.x - gutter - MARGIN * 2.0),
		maxf(80.0, size.y - MARGIN * 2.0 - 20.0))
	var fit: float = minf(1.0, minf(avail.x / ref.x, avail.y / ref.y))
	_host.scale = Vector2(fit, fit)
	_host.position = (Vector2(MARGIN, MARGIN) + (avail - ref * fit) * 0.5).floor()
	if _panel != null:
		_panel.position = Vector2(size.x - PANEL_W - MARGIN, MARGIN)
		_panel.size = Vector2(PANEL_W, maxf(120.0, size.y - MARGIN * 2.0 - 20.0))


# ---------------------------------------------------------------- the boxes

## Every authorable thing in the current scope, in the order the panel lists it.
##
## The order is `SCOPES`' own, which is `FORMS`' own, which is the order a human
## should meet these numbers in — declared once in the schema so the editor's
## row order cannot drift from the serialiser's key order the way the
## benchmark's two did.
func _collect(layout: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ref: Vector2 = Vector2(StageShape.REFERENCES[_shape])
	var ground: float = LayoutBook.num(layout.get("groundY"))
	if _scope == &"battlefield":
		# The stage form's target is the layout ROOT, which has no path of its
		# own — so the box asks the question its picture actually poses, which is
		# where this ground line came from.
		out.append(_entry("", &"stage", "stage · ground line",
			Rect2(0.0, ref.y - ground, ref.x, 0.0), "groundY"))
		var hero: Dictionary = layout.get("hero", {})
		out.append(_entry("hero", &"hero", "hero", _actor_box(hero, ref, ground)))
		var table: Dictionary = layout.get("slots", {})
		var counts: Array[int] = []
		for key: String in table:
			if key.is_valid_int():
				counts.append(int(key))
		counts.sort()
		for count: int in counts:
			var seats: Array = table[str(count)]
			for i: int in seats.size():
				var seat: Dictionary = seats[i]
				# Provenance is asked at the FORMATION, not at the number: arrays
				# replace wholesale (`battlefield.js:38-47`), so a shape that
				# touches one seat has authored all of them.
				out.append(_entry("slots/%d/%d" % [count, i], &"slot",
					"foe %d of %d" % [i + 1, count],
					_seat_box(seat, ref, ground), "slots/%d" % count))
		for art: String in LayoutBook.LAYERS:
			var layer: Dictionary = layout.get("layers", {}).get(art, {})
			out.append(_entry("layers/%s" % art, &"layer", "plate · %s" % art,
				_plate_box(layer, ref, ground, LayoutBook.num(layout.get("ledgeLip")),
					art == "ledge")))
		return out
	for widget: String in LayoutBook.SCOPES[_scope]:
		var form: StringName = LayoutBook.SCOPES[_scope][widget]
		var seat: Dictionary = layout.get(widget, {})
		if seat.is_empty():
			continue
		var box: Rect2 = (Rect2(0.0, 0.0, ref.x, LayoutBook.num(seat.get("height")))
			if form == &"hud" else _widget_box(seat, ref))
		out.append(_entry(widget, form, widget, box))
	return out


func _entry(path: String, form: StringName, label: String, rect: Rect2,
		prov: String = "") -> Dictionary:
	var at: String = prov if prov != "" else path
	return {
		"path": path, "form": form, "label": label, "rect": rect,
		"origin": LayoutBook.origin(_scope, _shape, _act, at),
	}


## The hero's box: `w` x `h`, centred on `x`, standing `y` above the ground.
func _actor_box(actor: Dictionary, ref: Vector2, ground: float) -> Rect2:
	var w: float = LayoutBook.num(actor.get("w"))
	var h: float = LayoutBook.num(actor.get("h"))
	var foot: float = ref.y - ground - LayoutBook.num(actor.get("y"))
	return Rect2(LayoutBook.num(actor.get("x")) - w * 0.5, foot - h, w, h)


## A foe seat is an anchor, not a box — the book authors where a foe STANDS and
## how big it is relative to its own art, never a rectangle. So the marker is
## square, sized by `s`, and centred on the point the actor's feet land on.
func _seat_box(seat: Dictionary, ref: Vector2, ground: float) -> Rect2:
	var r: float = 26.0 * LayoutBook.num(seat.get("s"), 1.0)
	var at: Vector2 = Vector2(LayoutBook.num(seat.get("x")),
		ref.y - ground - LayoutBook.num(seat.get("y")))
	return Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0)


## A scenery plate, by the same arithmetic `combat_screen.gd:1073` composes it
## with: `min-width: 100%` against the stage, `zoom` about the bottom edge, and
## the ledge hung off the ground line rather than off the stage bottom.
func _plate_box(layer: Dictionary, ref: Vector2, ground: float, lip: float,
		is_ledge: bool) -> Rect2:
	var h: float = LayoutBook.num(layer.get("h"))
	var y: float = LayoutBook.num(layer.get("y"))
	var zoom: float = LayoutBook.num(layer.get("zoom"), 1.0)
	var base: Vector2 = Vector2(maxf(ref.x, h * _aspect(is_ledge)), h)
	var box: Vector2 = base * zoom
	var bottom: float = maxf(0.0, ground + lip - h + y) if is_ledge else y
	return Rect2(ref.x * 0.5 - box.x * 0.5 + LayoutBook.num(layer.get("x")),
		ref.y - bottom - box.y, box.x, box.y)


## A chrome widget's box, by `hud_bar.gd:986`'s rule: a gap from one horizontal
## edge and one vertical one. A widget the book gives no `w`/`h` — `energy`,
## `omen`, `relics`, `hand` — is a bare anchor and comes back zero-sized, which
## the overlay draws as a crosshair rather than inventing a rectangle for it.
func _widget_box(seat: Dictionary, ref: Vector2) -> Rect2:
	var w: float = LayoutBook.num(seat.get("w"))
	var h: float = LayoutBook.num(seat.get("h"))
	var x: float = (ref.x - LayoutBook.num(seat.get("right")) - w
		if seat.has("right") else LayoutBook.num(seat.get("left")))
	var y: float = (LayoutBook.num(seat.get("top")) if seat.has("top")
		else ref.y - LayoutBook.num(seat.get("bottom")) - h)
	return Rect2(x, y, w, h)


## The plate art's aspect, for `min-width: 100%`. Loaded from the same act-1
## theme `combat_screen.gd:38` hangs the fight on; a missing file falls back to
## the stage's own aspect, which makes the plate exactly full-width and is the
## honest reading of "no art to measure".
func _aspect(is_ledge: bool) -> float:
	var path: String = "res://assets/art/stage/act1-%s.png" % ("ledge" if is_ledge else "backdrop")
	if not ResourceLoader.exists(path):
		return 0.0
	var tex: Texture2D = load(path)
	return float(tex.get_width()) / maxf(1.0, float(tex.get_height()))


# ---------------------------------------------------------------- the overlay

func _draw_overlay() -> void:
	var ref: Vector2 = Vector2(StageShape.REFERENCES[_shape])
	_over.draw_rect(Rect2(Vector2.ZERO, ref), Color(1.0, 1.0, 1.0, 0.16), false, 1.0)
	for box: Dictionary in _boxes:
		var chosen: bool = _path(box) == _selected
		var ink: Color = _ink(_origin_of(box))
		ink.a = 0.95 if chosen else 0.42
		var rect: Rect2 = box["rect"]
		if rect.size.x <= 0.0 and rect.size.y <= 0.0:
			_draw_cross(rect.position, ink, chosen)
		elif rect.size.y <= 0.0:
			# The ground line: a full-width rule, not a box with no height.
			_over.draw_line(rect.position, rect.position + Vector2(rect.size.x, 0.0),
				ink, 3.0 if chosen else 1.0)
		else:
			_over.draw_rect(rect, ink, false, 3.0 if chosen else 1.0)
		if chosen:
			var tag: String = "%s · %s" % [box["label"], box["origin"]]
			var font: Font = get_theme_default_font()
			var at: Vector2 = rect.position + Vector2(4.0, -6.0)
			_over.draw_string(font, at.max(Vector2(4.0, 14.0)), tag,
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, ink)


func _draw_cross(at: Vector2, ink: Color, chosen: bool) -> void:
	var arm: float = 14.0 if chosen else 9.0
	var wide: float = 3.0 if chosen else 1.0
	_over.draw_line(at - Vector2(arm, 0.0), at + Vector2(arm, 0.0), ink, wide)
	_over.draw_line(at - Vector2(0.0, arm), at + Vector2(0.0, arm), ink, wide)


## Click to select, drag to author.
##
## The SMALLEST box under the pointer wins the click, so a foe seat sitting on
## top of a full-width plate is still reachable. A drag then moves every field of
## that box the schema binds to an edge — which fields those are, and which way
## each one counts, is `LayoutBook.drag_step`'s answer, not this bench's.
func _on_overlay_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT:
		if not click.pressed:
			_dragging = false
			return
		var best: String = _under(click.position)
		if best == "":
			return
		if best != _selected:
			_selected = best
			_field = 0
			_level = _default_level()
			_refresh_rows()
			_sync_list()
		_dragging = true
		_drag_from = click.position
		_over.queue_redraw()
		accept_event()
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion == null or not _dragging:
		return
	# Whole pixels only. The book is authored in them, and a drag that wrote
	# 231.6043 would put a number in the file no one could have typed.
	var step: Vector2 = (motion.position - _drag_from).round()
	if step.is_zero_approx():
		return
	_drag_from += step
	_nudge(step)
	accept_event()


## The smallest box under a point, or "".
func _under(at: Vector2) -> String:
	var best: String = ""
	var smallest: float = INF
	for box: Dictionary in _boxes:
		var rect: Rect2 = box["rect"]
		var hit: Rect2 = rect.grow(6.0) if rect.size.x * rect.size.y > 0.0 else rect.grow(14.0)
		if not hit.has_point(at):
			continue
		var area: float = maxf(1.0, hit.size.x) * maxf(1.0, hit.size.y)
		if area < smallest:
			smallest = area
			best = _path(box)
	return best


# ---------------------------------------------------------------- authoring

## The level an edit to the selected box would land in if nobody chose one.
##
## Its own origin, so the first drag of an inherited number does NOT quietly
## promote it to a shape override — the bench moves the value where it already
## lives, and promoting is something you ask for. A default or absent value has
## nowhere of its own, so it starts at the shape, which is the level an editor
## opened on a particular shape is there to author.
func _default_level() -> StringName:
	var origin: StringName = _origin_of(_box())
	return origin if LayoutBook.LEVELS.has(origin) else LayoutBook.FROM_SHAPE


func _box() -> Dictionary:
	for box: Dictionary in _boxes:
		if _path(box) == _selected:
			return box
	return {}


func _form() -> StringName:
	var box: Dictionary = _box()
	if box.is_empty():
		return &""
	var form: StringName = box["form"]
	return form


## Move the selected box by a whole-pixel delta, in stage px.
func _nudge(step: Vector2) -> void:
	var box: Dictionary = _box()
	if box.is_empty():
		return
	var form: StringName = box["form"]
	var target: Dictionary = LayoutBook.at(LayoutBook.resolve(_scope, _shape, _act), _selected)
	var moved: bool = false
	for field: String in LayoutBook.fields(form):
		var per_px: Vector2 = LayoutBook.drag_step(form, field)
		if per_px.is_zero_approx() or not target.has(field):
			continue
		LayoutBook.author(_scope, _shape, _act, _level, _selected, field,
			LayoutBook.num(target[field]) + per_px.dot(step))
		moved = true
	if moved:
		_reapply()


## Change the one field the panel has highlighted, clamped to its declared
## range. Works on an ABSENT field too — it starts from the schema default, so
## setting a value the book never carried is the same gesture as changing one.
func _nudge_field(delta: float) -> void:
	var box: Dictionary = _box()
	if box.is_empty():
		return
	var form: StringName = box["form"]
	var names: PackedStringArray = LayoutBook.fields(form)
	if _field < 0 or _field >= names.size():
		return
	var field: String = names[_field]
	var spec: Dictionary = LayoutBook.FIELDS.get(StringName("%s/%s" % [form, field]), {})
	var target: Dictionary = LayoutBook.at(LayoutBook.resolve(_scope, _shape, _act), _selected)
	var now: float = LayoutBook.num(target.get(field), LayoutBook.num(spec.get("default")))
	LayoutBook.author(_scope, _shape, _act, _level, _selected, field, clampf(now + delta,
		LayoutBook.num(spec.get("min"), -INF), LayoutBook.num(spec.get("max"), INF)))
	_reapply()


## Put the selected field back to whatever it inherits at this level.
func _revert() -> void:
	var box: Dictionary = _box()
	if box.is_empty():
		return
	var form: StringName = box["form"]
	var names: PackedStringArray = LayoutBook.fields(form)
	if _field < 0 or _field >= names.size():
		return
	LayoutBook.unauthor(_scope, _shape, _act, _level, _selected, names[_field])
	_reapply()


## Re-stand the fight on the edited book. The screen resolves once in `_init`, so
## seeing an edit means rebuilding it — which is also the only honest preview,
## since it is the same code path a player's first frame takes.
func _reapply() -> void:
	_rebuild()


func _save() -> void:
	var why: String = LayoutBook.save()
	_status.text = ("saved %s" % LayoutBook.BOOK_PATH) if why.is_empty() else "NOT saved — %s" % why
	_status.add_theme_color_override("font_color",
		GlassStyle.TEXT_DIM if why.is_empty() else GlassStyle.HP_RED)


# ---------------------------------------------------------------- the panel

func _build_panel() -> PanelContainer:
	var frame: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.06, 0.94)
	sb.border_color = Color(GlassStyle.GLASS.r, GlassStyle.GLASS.g, GlassStyle.GLASS.b, 0.20)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	frame.add_theme_stylebox_override("panel", sb)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)

	var keys: Label = _caption("1-5 shape · , . act · S scope · L level · left/right field"
		+ " · up/down value (shift x10) · R revert · drag a box · ctrl-S save"
		+ " · O overlay · H panel")
	# Wrapped, or this one line sets the panel's minimum width and every tab strip
	# below it is laid out for a panel twice as wide as the one on screen.
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(keys)

	col.add_child(_heading("SHAPE"))
	var shapes: PackedStringArray = []
	for name: StringName in StageShape.REFERENCES:
		shapes.append(String(name))
	col.add_child(_tabs(shapes, shapes.find(String(_shape)), func(i: int) -> void:
		_shape = StringName(shapes[i])
		_rebuild()))

	col.add_child(_heading("ACT"))
	var acts: PackedStringArray = []
	for i: int in ACTS:
		acts.append("act %d" % i)
	col.add_child(_tabs(acts, _act, func(i: int) -> void:
		_act = i
		_rebuild()))

	col.add_child(_heading("SCOPE"))
	var scopes: PackedStringArray = []
	for name: StringName in LayoutBook.SCOPES:
		scopes.append(String(name))
	col.add_child(_tabs(scopes, scopes.find(String(_scope)), func(i: int) -> void:
		_scope = StringName(scopes[i])
		_refresh()))

	col.add_child(_heading("BOXES"))
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(0.0, 150.0)
	_list.add_theme_font_size_override("font_size", 11)
	_list.item_selected.connect(func(i: int) -> void:
		_selected = _path(_boxes[i])
		_field = 0
		_level = _default_level()
		_refresh_rows()
		_over.queue_redraw())
	col.add_child(_list)

	# The one control the benchmark's editors do not have, and the reason this
	# bench can be trusted with an inherited number: WHERE the next edit lands,
	# shown and chosen before it lands rather than discovered afterwards.
	col.add_child(_heading("WRITE TO"))
	_levels = _tabs_host()
	col.add_child(_levels)

	col.add_child(_heading("FIELDS"))
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	col.add_child(_rows)

	_save_button = _button("save the book", _save)
	col.add_child(_save_button)

	col.add_child(_heading("ORIGIN"))
	for origin: StringName in ORIGIN_INK:
		var l: Label = _caption(_legend(origin))
		l.add_theme_color_override("font_color", _ink(origin))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(l)
	return frame


static func _legend(origin: StringName) -> String:
	match origin:
		LayoutBook.FROM_ACT:
			return "act — authored in this shape's act bucket"
		LayoutBook.FROM_SHAPE:
			return "shape — authored on this shape, all acts"
		LayoutBook.FROM_BASE:
			return "base — inherited; editing it here would override"
		LayoutBook.FROM_DEFAULT:
			return "default — nobody authored it; the schema filled it in"
	return "absent — no value anywhere; for a one-edge widget that is correct"


func _tabs_host() -> VBoxContainer:
	var host: VBoxContainer = VBoxContainer.new()
	host.add_theme_constant_override("separation", 4)
	return host


func _button(text: String, on_press: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 11)
	GlassStyle.style_button(b, GlassStyle.EMBER)
	b.pressed.connect(on_press)
	return b


## Free a container's children NOW rather than at the end of the frame.
## `queue_free` alone would leave the old rows in the tree beside the new ones
## for one frame, which reads as a panel that doubles every time you click.
static func _clear(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()


## A row of buttons that behaves like a tab strip. `TabBar` would carry a theme
## this bench does not want and would still need the same index plumbing.
func _tabs(labels: PackedStringArray, chosen: int, on_pick: Callable) -> Control:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2 if labels.size() > 3 else 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	for i: int in labels.size():
		var b: Button = Button.new()
		b.text = labels[i]
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 11)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		GlassStyle.style_button(b, GlassStyle.EMBER if i == chosen else GlassStyle.GLASS)
		b.pressed.connect(on_pick.bind(i))
		grid.add_child(b)
	return grid


# ---------------------------------------------------------------- the readout

## Re-derive everything the panel and the overlay show from the resolved layout.
func _refresh() -> void:
	var layout: Dictionary = LayoutBook.resolve(_scope, _shape, _act)
	_boxes = _collect(layout)
	var paths: PackedStringArray = []
	for box: Dictionary in _boxes:
		paths.append(_path(box))
	if paths.find(_selected) < 0:
		_selected = _boxes[0]["path"] if not _boxes.is_empty() else ""
	if _list != null:
		_list.clear()
		for box: Dictionary in _boxes:
			_list.add_item("%s   %s" % [box["label"], box["origin"]])
			_list.set_item_custom_fg_color(_list.item_count - 1, _ink(_origin_of(box)))
		_sync_list()
	_refresh_rows()
	_over.queue_redraw()
	var faults: PackedStringArray = LayoutBook.validate()
	_status.text = "%s · %s · act %d · %s" % [_shape, _scope, _act,
		"book validates" if faults.is_empty() else "%d complaint(s)" % faults.size()]


func _sync_list() -> void:
	for i: int in _boxes.size():
		if _path(_boxes[i]) == _selected:
			_list.select(i)
			_list.ensure_current_is_visible()
			return
	_list.deselect_all()


## One row per field of the selected box: the value, and where it came from.
##
## Fields the book leaves absent are listed too, greyed — an editor that hides
## what is unset cannot be used to set it, which is the other half of why the
## benchmark's overrides were invisible.
func _refresh_rows() -> void:
	if _rows == null:
		return
	_clear(_rows)
	_refresh_levels()
	var chosen: Dictionary = _box()
	if chosen.is_empty():
		return
	var layout: Dictionary = LayoutBook.resolve(_scope, _shape, _act)
	var target: Dictionary = LayoutBook.at(layout, _path(chosen))
	var form: StringName = chosen["form"]
	_rows.add_child(_caption("%s — %s" % [chosen["label"], form]))
	var names: PackedStringArray = LayoutBook.fields(form)
	_field = clampi(_field, 0, maxi(0, names.size() - 1))
	for i: int in names.size():
		var field: String = names[i]
		var spec: Dictionary = LayoutBook.FIELDS.get(
			StringName("%s/%s" % [form, field]), {})
		var here: bool = target.has(field)
		# A slot's origin is the formation's, for the same array-replace reason
		# `_collect` gives; everything else is asked per field.
		var origin: StringName = (_origin_of(chosen) if form == &"slot"
			else LayoutBook.origin(_scope, _shape, _act, _path_of(chosen, field)))
		var value: String = ("%s %s" % [_number(LayoutBook.num(target.get(field))),
			spec.get("unit", "")] if here else "—")
		var moves: bool = not LayoutBook.drag_step(form, field).is_zero_approx()
		var row: Button = Button.new()
		row.flat = true
		row.clip_text = true
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_theme_font_size_override("font_size", 10)
		row.add_theme_color_override("font_color", _ink(origin))
		# `>` marks the field the arrow keys act on; `drag` marks the ones a drag
		# moves, which is the schema's answer rather than this bench's opinion.
		# Both plain ASCII: the bundled UI font is a CJK face and its coverage of
		# arrows and bullets is not something a readout should depend on.
		row.text = "%s %s %s   %s   %s%s" % [
			">" if i == _field else " ", field, spec.get("bind", "?"),
			value, origin, "   drag" if moves else ""]
		row.pressed.connect(func() -> void:
			_field = i
			_refresh_rows())
		_rows.add_child(row)


## The three levels, with the one the next edit lands in lit, and the save
## button carrying whether there is anything to save.
func _refresh_levels() -> void:
	if _levels == null:
		return
	_clear(_levels)
	var labels: PackedStringArray = []
	for level: StringName in LayoutBook.LEVELS:
		labels.append("act %d" % _act if level == LayoutBook.FROM_ACT else String(level))
	_levels.add_child(_tabs(labels, LayoutBook.LEVELS.find(_level), func(i: int) -> void:
		_level = LayoutBook.LEVELS[i]
		_refresh_rows()))
	if _save_button != null:
		_save_button.text = ("save the book (edited)" if LayoutBook.is_dirty()
			else "save the book")


## A box's path into the resolved layout. Written out rather than subscripted at
## every call site because the warnings-as-errors gate refuses a Variant where a
## String is declared, and a typed local is the whole of the fix.
static func _path(box: Dictionary) -> String:
	var path: String = box["path"]
	return path


static func _origin_of(box: Dictionary) -> StringName:
	var origin: StringName = box["origin"]
	return origin


static func _ink(origin: StringName) -> Color:
	var colour: Color = ORIGIN_INK.get(origin, GlassStyle.TEXT_DIM)
	return colour


static func _path_of(box: Dictionary, field: String) -> String:
	var path: String = _path(box)
	return field if path.is_empty() else "%s/%s" % [path, field]


## An authored number as a human wrote it. The book is almost all whole pixels
## and `232.0` reads as a value someone tuned to a decimal; the few that are not
## whole — `zoom 0.4` — keep their digits. GDScript's `%` has no `%g`.
static func _number(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else String.num(value, 3)


static func _heading(text: String) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", GlassStyle.EMBER)
	return l


static func _caption(text: String) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
	return l
