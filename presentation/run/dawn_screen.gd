class_name DawnScreen
extends Control
## Durable Dawn ceremony. The application still owns cursor advancement and
## persistence — the screen asks (`advance_requested`), main writes the save,
## and only a confirmed write reveals the next memory (`advance_confirmed`).
## What changed at P3.3: the screen is built ONCE and the feed animates in
## place, where the old drive rebuilt the whole route every 0.72s — a victory
## ceremony that blinked. The benchmark appends panels to one living host
## (end.js:125-163) and so does this.

signal deck_requested
signal commit_requested
## The feed wants the next memory. Main persists `pending_dawn.cursor + 1`
## and answers with `advance_confirmed()`; on a failed save it answers with
## nothing and the feed holds — a memory is never shown before it is owed.
signal advance_requested

const ASCENDED: String = "res://assets/art/meta/ascended.png"

## The benchmark's beat: `.dawn-event` enters over 550ms ease (styles.css:2583)
## and `drainEndQueue` sleeps the same 550ms per event (end.js:148).
const REVEAL_TIME: float = 0.55
## Input-first pacing (the P4.12 fold): click or space advances at once; the
## clock only steps in for a hands-off player, relaxed from the old drive's
## 0.72s rebuild timer to a readable 1.6s.
const AUTO_ADVANCE: float = 1.6
## Hold anything for this long and the rest of the dawn arrives at once.
const SKIP_HOLD: float = 0.6
## victoryFlow's flash — V.flash('#ffe9ac', 0.25, 1) (end.js:198).
const FLASH_COLOR: Color = Color(1.0, 0.9137255, 0.6745098)
const FLASH_TIME: float = 0.25
## sunrise() (scene3d.js:306-313) floods warm light in from behind the Spire —
## "the only daylight in the game". The port's dawn is a static painting, so
## the flood is read as a ramped warm wash over it: particles #ffd9a0 up top,
## glow #ffc478 low, over ~2.5s.
const SUNRISE_TIME: float = 2.5
const SUNRISE_HIGH: Color = Color(1.0, 0.8509804, 0.627451, 0.20)
const SUNRISE_LOW: Color = Color(1.0, 0.76862746, 0.47058824, 0.10)

const BEAT_IDLE: int = 0
const BEAT_REVEAL: int = 1
const BEAT_WAIT: int = 2

var shape: StringName = StageShape.IDENTITY

var _events: Array
var _cursor: int
var _stats: Dictionary
var _sfx: SfxBus
var _margin: MarginContainer
var _panel: PanelContainer
var _title: Label
var _grid: GridContainer
var _stats_grid: GridContainer
var _progress: Label
var _caption: Label
var _skip_fill: ColorRect
var _deck_btn: Button
var _commit_btn: Button
var _wash: ColorRect
var _sun: TextureRect
var _flash: ColorRect
var _beat: int = BEAT_IDLE
var _beat_t: float = 0.0
var _hold_t: float = 0.0
var _holding: bool = false
var _skipping: bool = false
var _asked: bool = false
var _sun_t: float = -1.0
var _reveal_card: Control = null
var _reveal_inset: MarginContainer = null


func _init(events: Array, cursor: int,
		stage_shape: StringName = StageShape.IDENTITY,
		stats: Dictionary = {}) -> void:
	_events = events.duplicate(true)
	_cursor = clampi(cursor, 0, _events.size())
	_stats = stats.duplicate(true)
	shape = stage_shape if StageShape.REFERENCES.has(stage_shape) else StageShape.IDENTITY
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GlassStyle.theme()
	_sfx = SfxBus.new()
	add_child(_sfx)
	_build()


func _ready() -> void:
	# The ceremony dressing belongs to the moment of ascent, not to a resumed
	# cursor: a player killed mid-dawn comes back to a quiet feed.
	if _cursor == 0 and not _events.is_empty():
		_flash_in()
		_sun_t = 0.0
		add_child(Confetti.new())
	if _cursor < _events.size():
		_begin_beat()
	set_process(true)


func _build() -> void:
	var art: TextureRect = TextureRect.new()
	art.texture = load(ASCENDED) as Texture2D
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	_wash = ColorRect.new()
	_wash.color = Color(0.025, 0.020, 0.035, 0.62)
	_wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wash)
	_sun = TextureRect.new()
	_sun.texture = GlassStyle.grad_tex(
		PackedColorArray([SUNRISE_HIGH, Color(SUNRISE_LOW, 0.0), SUNRISE_LOW]),
		PackedFloat32Array([0.0, 0.55, 1.0]), false, Vector2.ZERO, Vector2.DOWN)
	_sun.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sun.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sun.stretch_mode = TextureRect.STRETCH_SCALE
	_sun.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sun.modulate.a = 0.0
	add_child(_sun)

	_margin = MarginContainer.new()
	_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)
	var centre: CenterContainer = CenterContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_margin.add_child(centre)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", RunStyle.panel(14, 22, 0.88))
	centre.add_child(_panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 9)
	_panel.add_child(column)

	_title = _label("ASCENDED", 42, RunStyle.GOLD)
	_title.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_700, 4))
	column.add_child(_title)
	var subtitle: Label = _label("At Dawn, the Vigil remembers.", 15, RunStyle.PARCHMENT)
	column.add_child(subtitle)
	column.add_child(_underline())

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 260
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	column.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)
	if _events.is_empty():
		_grid.add_child(_event_card({"title": "Dawn", "body": "The Vigil is quiet."}, false))
	else:
		# The memories already owed by the save arrive standing — a resumed
		# dawn does not replay what the player has been shown and been
		# persisted through.
		for i: int in range(_cursor):
			var owed: Dictionary = _events[i]
			_grid.add_child(_event_card(owed, false))

	_build_stats(column)
	_progress = _label(_progress_text(), 11, RunStyle.GOLD_DIM)
	_progress.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_500, 1))
	column.add_child(_progress)

	var caption_seat: VBoxContainer = VBoxContainer.new()
	caption_seat.alignment = BoxContainer.ALIGNMENT_CENTER
	caption_seat.add_theme_constant_override("separation", 3)
	column.add_child(caption_seat)
	_caption = _label("CLICK OR SPACE TO CONTINUE  ·  HOLD TO SKIP", 9, RunStyle.TEXT_DIM)
	_caption.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_500, 1))
	caption_seat.add_child(_caption)
	# The skip vow fills gold under the caption while anything is held.
	_skip_fill = ColorRect.new()
	_skip_fill.color = RunStyle.GOLD
	_skip_fill.custom_minimum_size = Vector2(0.0, 2.0)
	_skip_fill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	caption_seat.add_child(_skip_fill)
	_caption.visible = _cursor < _events.size()
	_skip_fill.visible = _caption.visible

	# The benchmark renders both buttons disabled and enables them when the
	# ceremony settles (end.js:181-184, :241-244). Rendering them at all tells
	# the player where the ceremony is going.
	var actions: HFlowContainer = HFlowContainer.new()
	actions.alignment = FlowContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("h_separation", 12)
	actions.add_theme_constant_override("v_separation", 8)
	column.add_child(actions)
	_deck_btn = _action_button("VIEW FINAL DECK")
	_deck_btn.pressed.connect(func() -> void:
		_sfx.play(&"click")
		deck_requested.emit()
	)
	actions.add_child(_deck_btn)
	_commit_btn = _action_button("RETURN TO THE VIGIL")
	_commit_btn.pressed.connect(func() -> void:
		_sfx.play(&"click")
		commit_requested.emit()
	)
	actions.add_child(_commit_btn)
	var complete: bool = _cursor >= _events.size()
	_deck_btn.disabled = not complete
	_commit_btn.disabled = not complete
	set_shape(shape)


# ---------------------------------------------------------------- the feed

func _begin_beat() -> void:
	_beat = BEAT_REVEAL
	_beat_t = 0.0
	_asked = false
	var due: Dictionary = _events[_cursor]
	var card: PanelContainer = _event_card(due, true)
	_grid.add_child(card)
	_reveal_card = card
	_reveal_inset = card.get_child(0) as MarginContainer
	if _skipping:
		card.modulate.a = 1.0
		_set_inset(0.0)
		_finish_beat()
		return
	card.modulate.a = 0.0
	_set_inset(12.0)


func _finish_beat() -> void:
	_beat = BEAT_WAIT
	_beat_t = 0.0
	if _skipping and not _asked:
		_asked = true
		advance_requested.emit()


## Main's answer to `advance_requested`: the cursor write held, the next
## memory is owed. Called never on a failed save — the feed simply holds.
func advance_confirmed() -> void:
	_cursor += 1
	_progress.text = _progress_text()
	if _cursor >= _events.size():
		_complete()
	else:
		_begin_beat()


func _complete() -> void:
	_beat = BEAT_IDLE
	_caption.visible = false
	_skip_fill.visible = false
	_deck_btn.disabled = false
	_commit_btn.disabled = false
	_progress.text = _progress_text()


func _process(delta: float) -> void:
	if _sun_t >= 0.0 and _sun_t < SUNRISE_TIME:
		_sun_t = minf(SUNRISE_TIME, _sun_t + delta)
		var u: float = Motion.ease(Motion.EASE_IN_OUT, _sun_t / SUNRISE_TIME)
		_sun.modulate.a = u
		# The storm is over: the night wash thins as the light arrives.
		_wash.color.a = lerpf(0.62, 0.40, u)
	if _holding and _beat != BEAT_IDLE:
		_hold_t += delta
		var fill: float = clampf(_hold_t / SKIP_HOLD, 0.0, 1.0)
		_skip_fill.custom_minimum_size.x = _caption.size.x * fill
		if _hold_t >= SKIP_HOLD and not _skipping:
			_skipping = true
			_sfx.play(&"click")
			if _beat == BEAT_WAIT and not _asked:
				_asked = true
				advance_requested.emit()
	match _beat:
		BEAT_REVEAL:
			_beat_t += delta
			var u: float = clampf(_beat_t / REVEAL_TIME, 0.0, 1.0)
			var e: float = Motion.ease(Motion.CSS_EASE, u)
			if is_instance_valid(_reveal_card):
				_reveal_card.modulate.a = e
				_set_inset(lerpf(12.0, 0.0, e))
			if u >= 1.0:
				_finish_beat()
		BEAT_WAIT:
			_beat_t += delta
			if _beat_t >= AUTO_ADVANCE and not _asked:
				_asked = true
				advance_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if _beat == BEAT_IDLE:
		return
	var pressed: bool = false
	var released: bool = false
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pressed = (event as InputEventMouseButton).pressed
		released = not pressed
	elif event is InputEventKey and not (event as InputEventKey).echo:
		var key: Key = (event as InputEventKey).keycode
		if key == KEY_SPACE or key == KEY_ENTER or key == KEY_KP_ENTER:
			pressed = (event as InputEventKey).pressed
			released = not pressed
	if pressed:
		_holding = true
		_hold_t = 0.0
	elif released and _holding:
		_holding = false
		var was_tap: bool = _hold_t < SKIP_HOLD
		_hold_t = 0.0
		_skip_fill.custom_minimum_size.x = 0.0
		if was_tap and _beat == BEAT_WAIT and not _asked and not _skipping:
			_asked = true
			_sfx.play(&"click")
			advance_requested.emit()


func _set_inset(px: float) -> void:
	if _reveal_inset == null:
		return
	_reveal_inset.add_theme_constant_override("margin_top", int(roundf(9.0 + px)))
	_reveal_inset.add_theme_constant_override("margin_bottom", int(roundf(maxf(0.0, 9.0 - px))))


# ---------------------------------------------------------------- dressing

func _flash_in() -> void:
	_flash = ColorRect.new()
	_flash.color = FLASH_COLOR
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	Motion.bez(self, func(u: float) -> void:
		if is_instance_valid(_flash):
			_flash.modulate.a = 1.0 - u,
		FLASH_TIME, Motion.CSS_EASE_OUT
	).finished.connect(func() -> void:
		if is_instance_valid(_flash):
			_flash.queue_free()
	)


## victoryFlow's confetti (end.js:199-200): a burst every 400ms for 4.2s from
## a fifth of the way down the sky — 16 motes a burst in the three festival
## tones, thrown at 300 and pulled down at 260 over a 1.2s life. Drawn, not
## noded: sixty-odd quads a frame is one canvas item.
class Confetti extends Control:
	const TONES: Array[Color] = [
		Color(1.0, 0.8509804, 0.47843137),   # #ffd97a
		Color(0.7882353, 0.6901961, 1.0),    # #c9b0ff
		Color(0.5607843, 0.9098039, 0.627451),  # #8fe8a0
	]
	const BURST_EVERY: float = 0.4
	const BURSTS_FOR: float = 4.2
	const LIFE: float = 1.2

	class Mote extends RefCounted:
		var pos: Vector2
		var vel: Vector2
		var tone: Color
		var born: float
		var r: float

	var _t: float = 0.0
	var _next_burst: float = 0.0
	var _seed: int = 0x0DA3
	var _motes: Array[Mote] = []

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		if _t >= _next_burst and _t <= BURSTS_FOR:
			_next_burst += BURST_EVERY
			_burst()
		var alive: Array[Mote] = []
		for m: Mote in _motes:
			if _t - m.born > LIFE:
				continue
			m.vel.y += 260.0 * delta
			m.pos += m.vel * delta
			alive.append(m)
		_motes = alive
		if _t > BURSTS_FOR and _motes.is_empty():
			queue_free()
			return
		queue_redraw()

	func _rand() -> float:
		_seed = (_seed * 1103515245 + 12345) & 0x7FFFFFFF
		return float(_seed) / float(0x7FFFFFFF)

	func _burst() -> void:
		var at: Vector2 = Vector2(_rand() * size.x, size.y * 0.2)
		var tone: Color = TONES[int(_rand() * 3.0) % 3]
		for i: int in range(16):
			var ang: float = _rand() * TAU
			var speed: float = 300.0 * (0.35 + 0.65 * _rand())
			var m: Mote = Mote.new()
			m.pos = at
			m.vel = Vector2(cos(ang), sin(ang)) * speed
			m.tone = tone
			m.born = _t
			m.r = 1.6 + _rand() * 2.2
			_motes.append(m)

	func _draw() -> void:
		for m: Mote in _motes:
			var age: float = (_t - m.born) / LIFE
			var tone: Color = m.tone
			tone.a = 1.0 - age * age
			draw_rect(Rect2(m.pos.x, m.pos.y, m.r, m.r * 1.6), tone)


# ---------------------------------------------------------------- chrome

func _event_card(event: Dictionary, current: bool) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(180, 92)
	var style: StyleBoxFlat = GlassStyle.pane(RunStyle.GOLD, 0.78 if current else 0.62)
	style.border_color = Color(RunStyle.GOLD, 0.68 if current else 0.22)
	card.add_theme_stylebox_override("panel", style)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# The inset is the reveal's travel: margin_top eases 12→0 the way
	# `.dawn-event` translates in (styles.css:2583-2585).
	var inset: MarginContainer = MarginContainer.new()
	inset.add_theme_constant_override("margin_top", 9)
	inset.add_theme_constant_override("margin_bottom", 9)
	inset.add_theme_constant_override("margin_left", 11)
	inset.add_theme_constant_override("margin_right", 11)
	card.add_child(inset)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 4)
	inset.add_child(stack)
	var kind: String = str(event.get("kind", "memory"))
	var kicker: Label = _label(_event_kicker(kind), 9, RunStyle.GOLD_DIM)
	kicker.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_700, 1))
	stack.add_child(kicker)
	var title: Label = _label(str(event.get("title", "Dawn")), 13, RunStyle.PARCHMENT)
	title.add_theme_font_override("font", load(GlassStyle.CINZEL_700) as Font)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(title)
	var body: Label = _label(str(event.get("body", "")), 11, RunStyle.TEXT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(body)
	return card


func _build_stats(column: VBoxContainer) -> void:
	_stats_grid = GridContainer.new()
	_stats_grid.columns = 4
	_stats_grid.add_theme_constant_override("h_separation", 4)
	_stats_grid.add_theme_constant_override("v_separation", 4)
	_stats_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_stats_grid)
	for row: Array in [
		["floors", "FLOORS"], ["slain", "SLAIN"],
		["elites_bosses", "ELITES + BOSSES"], ["deck_size", "DECK SIZE"],
		["damage_dealt", "DAMAGE DEALT"], ["damage_taken", "DAMAGE TAKEN"],
		["cards_played", "CARDS PLAYED"], ["run_time", "RUN TIME"],
	]:
		var cell: PanelContainer = PanelContainer.new()
		cell.add_theme_stylebox_override("panel", GlassStyle.pane(RunStyle.GOLD, 0.52))
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_stats_grid.add_child(cell)
		var stack: VBoxContainer = VBoxContainer.new()
		stack.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.add_child(stack)
		var value: Label = _label(str(_stats.get(row[0], "—")), 17, RunStyle.PARCHMENT)
		value.add_theme_font_override("font", load(GlassStyle.CINZEL_700) as Font)
		stack.add_child(value)
		var caption: Label = _label(str(row[1]), 8, RunStyle.TEXT_DIM)
		caption.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_500, 1))
		stack.add_child(caption)


func _event_kicker(kind: String) -> String:
	match kind:
		"whisper": return "A WHISPER AT DAWN"
		"quest": return "A JOURNEY REVEALED"
		"progress": return "THE JOURNEY CONTINUES"
		"shard": return "EMBERGLASS SHARD"
		"unlock": return "THE VIGIL OPENS"
		_: return "AT DAWN"


func _action_button(text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(190, 46)
	button.add_theme_font_override("font", load(GlassStyle.CINZEL_700) as Font)
	RunStyle.style_button(button, true)
	return button


func _progress_text() -> String:
	if _events.is_empty() or _cursor >= _events.size():
		return "DAWN COMPLETE"
	return "DAWN %d OF %d · THE CURRENT MEMORY IS LIT" % [_cursor + 1, _events.size()]


func set_shape(stage_shape: StringName) -> void:
	if not StageShape.REFERENCES.has(stage_shape):
		return
	shape = stage_shape
	match shape:
		&"phone-portrait":
			_apply_shape(14, 350, 42, 2, 380)
		&"pad-portrait":
			_apply_shape(42, 720, 64, 2, 460)
		&"pad-landscape":
			_apply_shape(48, 800, 72, 3, 260)
		&"desktop-landscape":
			_apply_shape(52, 900, 80, 4, 260)
		&"phone-landscape":
			_apply_shape(10, 760, 46, 2, 150)


func _apply_shape(inset: int, panel_width: float, title_size: int,
		columns: int, grid_height: float) -> void:
	for side: String in ["left", "right", "top", "bottom"]:
		_margin.add_theme_constant_override("margin_" + side, inset)
	_panel.custom_minimum_size.x = panel_width
	_title.add_theme_font_size_override("font_size", title_size)
	_grid.columns = columns
	_grid.get_parent().custom_minimum_size.y = grid_height


static func _label(text: String, font_size: int, colour: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", load(GlassStyle.ALEGREYA_400) as Font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	return label


static func _underline() -> TextureRect:
	var line: TextureRect = TextureRect.new()
	line.custom_minimum_size = Vector2(100, 2)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	line.texture = GlassStyle.grad_tex(
		PackedColorArray([Color.TRANSPARENT, RunStyle.GOLD, Color.TRANSPARENT]),
		PackedFloat32Array([0.0, 0.5, 1.0]), false, Vector2.ZERO, Vector2.RIGHT)
	line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	line.stretch_mode = TextureRect.STRETCH_SCALE
	return line
