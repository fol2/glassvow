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
## victoryFlow's flash — V.flash('#ffe9ac', 0.25, 1) (end.js:198), read against
## the SIGNATURE, not the call: flash(color, alpha, dur) (vfx.js:149), so this
## is a QUARTER-alpha veil over one full second, decayed linearly
## (vfx.js:131: globalAlpha = life/dur * alpha). The first cut transposed the
## arguments — a full-alpha quarter-second white-out, four times the peak for
## a quarter of the time, and a photosensitivity hazard on top of being wrong.
const FLASH_COLOR: Color = Color(1.0, 0.9137255, 0.6745098)
const FLASH_ALPHA: float = 0.25
const FLASH_TIME: float = 1.0
## sunrise() (scene3d.js:306-313) is a STATE the scene holds, not an event —
## the reference re-asserts it on every won render. Its two field colours
## (sky #5a3452, fog #8a4a55) lighten the whole world; its two accents
## (particles #ffd9a0, glow #ffc478) warm the highlights. The port's dawn is
## a static painting, so the field half is read as the night wash THINNING
## (0.62 → 0.40) and the accent half as a warm veil laid over everything —
## panel included, because a sunrise that spares the thing you are reading
## is not a sunrise. Deliberate port interpretation; the reference's
## bloomBase and weatherOp have no counterpart on this screen and are not
## claimed.
const SUNRISE_TIME: float = 2.5
const SUNRISE_HIGH: Color = Color(1.0, 0.8509804, 0.627451, 0.14)
const SUNRISE_LOW: Color = Color(1.0, 0.76862746, 0.47058824, 0.07)
const WASH_NIGHT: float = 0.62
const WASH_DAWN: float = 0.40

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
var _reveal_seat: MarginContainer = null
var _confetti: Confetti = null

## The reveal's travel, and every seat's constant extra height: top and
## bottom margins always sum to this, so a sliding card never changes its
## row's height.
const TRAVEL: float = 12.0


func _init(events: Array, cursor: int,
		stage_shape: StringName = StageShape.IDENTITY,
		stats: Dictionary = {}, sfx: SfxBus = null) -> void:
	_events = events.duplicate(true)
	_cursor = clampi(cursor, 0, _events.size())
	_stats = stats.duplicate(true)
	shape = stage_shape if StageShape.REFERENCES.has(stage_shape) else StageShape.IDENTITY
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GlassStyle.theme()
	_sfx = sfx if sfx != null else SfxBus.new()
	if sfx == null:
		add_child(_sfx)
	_build()


func _ready() -> void:
	# The one-shots — flash, confetti, the fanfare — belong to the moment of
	# ascent: a player killed mid-dawn comes back to a quiet feed. The LIGHT is
	# not one of them: sunrise is a state the scene holds, so a resumed dawn
	# arrives with it already settled rather than stranded in night.
	if _cursor == 0 and not _events.is_empty():
		_sun_t = 0.0
		# REDUCE MOTION: flash and confetti are celebration MOTION and stay
		# out (`.dawn-event { animation: none; transition: none; }`,
		# styles.css:2052); the sunrise is a state the scene holds and keeps
		# arriving either way.
		if not Preferences.active.reduce_motion:
			_flash_in()
			_confetti = Confetti.new()
			add_child(_confetti)
	else:
		_sun.modulate.a = 1.0
		_wash.color.a = WASH_DAWN
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

	_title = _label(Locale.active.t("ui.dawn.title"), 42, RunStyle.GOLD)
	_title.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_700, 4))
	column.add_child(_title)
	var subtitle: Label = _label(Locale.active.t("ui.dawn.subtitle"), 15, RunStyle.PARCHMENT)
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
		_grid.add_child(_seat(_event_card({"title": Locale.active.t("ui.dawn.quietTitle"), "body": Locale.active.t("ui.dawn.quietBody")})))
	else:
		# The memories already owed by the save arrive standing — a resumed
		# dawn does not replay what the player has been shown and been
		# persisted through.
		for i: int in range(_cursor):
			var owed: Dictionary = _events[i]
			_grid.add_child(_seat(_event_card(owed)))

	_build_stats(column)
	_progress = _label(_progress_text(), 11, RunStyle.GOLD_DIM)
	_progress.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_500, 1))
	column.add_child(_progress)

	# The benchmark renders both buttons disabled and enables them when the
	# ceremony settles (end.js:181-184, :241-244). Rendering them at all tells
	# the player where the ceremony is going.
	var actions: HFlowContainer = HFlowContainer.new()
	actions.alignment = FlowContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("h_separation", 12)
	actions.add_theme_constant_override("v_separation", 8)
	column.add_child(actions)
	_deck_btn = _action_button(Locale.active.t("ui.end.viewDeck").to_upper(), false)
	_deck_btn.pressed.connect(func() -> void:
		_sfx.play(&"click")
		deck_requested.emit()
	)
	actions.add_child(_deck_btn)
	_commit_btn = _action_button(Locale.active.t("ui.end.returnVigil").to_upper(), true)
	_commit_btn.pressed.connect(func() -> void:
		_sfx.play(&"click")
		commit_requested.emit()
	)
	actions.add_child(_commit_btn)
	var complete: bool = _cursor >= _events.size()
	_deck_btn.disabled = not complete
	_commit_btn.disabled = not complete
	# `.btn:disabled { opacity: 0.45 }` (styles.css:156) fades plate and label
	# TOGETHER — the port's disabled state re-dressed the label alone and left
	# two full-chroma gold plates as the loudest things on a screen the player
	# cannot use them on.
	_deck_btn.modulate.a = 1.0 if complete else 0.45
	_commit_btn.modulate.a = 1.0 if complete else 0.45

	# The input hint speaks in the UI register — plain reading face, below the
	# buttons — not in the vow's own tracked small caps, where a line about
	# mouse buttons read as scripture and two stacked fine-print lines read as
	# none.
	var caption_seat: VBoxContainer = VBoxContainer.new()
	caption_seat.alignment = BoxContainer.ALIGNMENT_CENTER
	caption_seat.add_theme_constant_override("separation", 3)
	column.add_child(caption_seat)
	_caption = _label("click or space to continue  ·  hold to skip", 10,
		Color(RunStyle.TEXT_DIM, 0.85))
	caption_seat.add_child(_caption)
	# The skip vow fills gold under the caption while anything is held.
	_skip_fill = ColorRect.new()
	_skip_fill.color = RunStyle.GOLD
	_skip_fill.custom_minimum_size = Vector2(0.0, 2.0)
	_skip_fill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	caption_seat.add_child(_skip_fill)
	_caption.visible = _cursor < _events.size()
	_skip_fill.visible = _caption.visible

	# The sunrise veil lies over EVERYTHING built above — panel included —
	# because warmth that spares the thing you are reading is not a sunrise.
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
	set_shape(shape)


# ---------------------------------------------------------------- the feed

func _begin_beat() -> void:
	_beat = BEAT_REVEAL
	_beat_t = 0.0
	_asked = false
	var due: Dictionary = _events[_cursor]
	var card: PanelContainer = _event_card(due)
	var seat: MarginContainer = _seat(card, 0.0 if _skipping else TRAVEL)
	_grid.add_child(seat)
	_reveal_card = card
	_reveal_seat = seat
	if _skipping:
		# The reference's own instant path still staggers (end.js:145-146:
		# shown, then sleep(40)) — a fast-forward the eye can follow, and one
		# save per beat instead of the whole remainder inside one frame.
		card.modulate.a = 1.0
		_finish_beat()
		return
	card.modulate.a = 0.0


func _finish_beat() -> void:
	_beat = BEAT_WAIT
	_beat_t = 0.0


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
	_deck_btn.modulate.a = 1.0
	_commit_btn.modulate.a = 1.0
	_progress.text = _progress_text()
	# The festival plays to the ceremony, not past it: bursts keep coming
	# while memories are still arriving, and stop when the feed settles —
	# the reference's 4.2s covered its 3.3s drain the same way.
	if is_instance_valid(_confetti):
		_confetti.finish()


func _process(delta: float) -> void:
	if _sun_t >= 0.0 and _sun_t < SUNRISE_TIME:
		_sun_t = minf(SUNRISE_TIME, _sun_t + delta)
		var u: float = Motion.ease(Motion.EASE_IN_OUT, _sun_t / SUNRISE_TIME)
		_sun.modulate.a = u
		# The storm is over: the night wash thins as the light arrives.
		_wash.color.a = lerpf(WASH_NIGHT, WASH_DAWN, u)
	if _holding and _beat != BEAT_IDLE:
		_hold_t += delta
		var fill: float = clampf(_hold_t / SKIP_HOLD, 0.0, 1.0)
		_skip_fill.custom_minimum_size.x = maxf(_caption.size.x, 220.0) * fill
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
			# `.dawn-event { animation: none }` (styles.css:2052): the card
			# stands at once, but the CLOCK is untouched — `u` still walks
			# REVEAL_TIME so every memory keeps its full dwell. Reduced
			# motion must never buy the player LESS reading time.
			var shown: float = 1.0 if Preferences.active.reduce_motion \
				else Motion.ease(Motion.CSS_EASE, u)
			if is_instance_valid(_reveal_card) and is_instance_valid(_reveal_seat):
				# The whole panel slides — `.dawn-event` animates transform,
				# not layout (styles.css:2583-2585). The travel lives in the
				# seat's margins, whose sum never changes, so the row's height
				# holds while the card moves.
				_reveal_card.modulate.a = shown
				_set_travel(_reveal_seat, lerpf(TRAVEL, 0.0, shown))
			if u >= 1.0:
				_finish_beat()
		BEAT_WAIT:
			_beat_t += delta
			var wait: float = 0.04 if _skipping else AUTO_ADVANCE
			if _beat_t >= wait and not _asked:
				_asked = true
				advance_requested.emit()


## Mouse arrives through _gui_input: this Control is full-rect with
## MOUSE_FILTER_STOP, so it consumes clicks as GUI input and an
## _unhandled_input handler would wait for a click that can never fall
## through — which is exactly what the first cut did. The buttons stop
## their own clicks before they reach here. Keys still arrive unhandled;
## nothing on this screen holds focus while the feed runs.
func _gui_input(event: InputEvent) -> void:
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse != null and mouse.button_index == MOUSE_BUTTON_LEFT:
		_press(mouse.pressed)


func _unhandled_key_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or key_event.echo:
		return
	if key_event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		_press(key_event.pressed)


func _press(down: bool) -> void:
	if _beat == BEAT_IDLE:
		return
	if down:
		_holding = true
		_hold_t = 0.0
		return
	if not _holding:
		return
	_holding = false
	var was_tap: bool = _hold_t < SKIP_HOLD
	_hold_t = 0.0
	_skip_fill.custom_minimum_size.x = 0.0
	if not was_tap or _skipping or _asked:
		return
	_sfx.play(&"click")
	if _beat == BEAT_WAIT:
		_asked = true
		advance_requested.emit()
	elif _beat == BEAT_REVEAL and is_instance_valid(_reveal_card):
		# A tap mid-entrance means "I have read it": the card lands standing
		# and the next memory is asked for at once.
		_reveal_card.modulate.a = 1.0
		if is_instance_valid(_reveal_seat):
			_set_travel(_reveal_seat, 0.0)
		_finish_beat()
		_asked = true
		advance_requested.emit()


# ---------------------------------------------------------------- dressing

func _flash_in() -> void:
	_flash = ColorRect.new()
	_flash.color = FLASH_COLOR
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.modulate.a = FLASH_ALPHA
	add_child(_flash)
	# Linear, because that is the decay: globalAlpha = life/dur * alpha
	# (vfx.js:131). A Tween's default transition is exactly that.
	var tw: Tween = create_tween()
	tw.tween_property(_flash, "modulate:a", 0.0, FLASH_TIME)
	tw.finished.connect(func() -> void:
		if is_instance_valid(_flash):
			_flash.queue_free()
	)


## victoryFlow's confetti (end.js:199-200): a burst every 400ms, 16 motes in
## one festival tone per burst, thrown at speed 300 and pulled down at 260.
## Each mote is V.burst's SPARK (vfx.js:88-98): a stroke laid along its own
## velocity, length |v|·0.045+2, width fading with alpha, composited
## ADDITIVELY — light, not litter. Life is 1.2s randomised ×(0.6..1.4), drag
## 1.6, opaque until the last quarter-second. The reference clears its
## interval at 4.2s against a 3.3s drain; the port's drain breathes with the
## player, so the festival runs until the feed settles (finish()) and never
## shorter than the reference's own 4.2s. First burst at t=0.4 — setInterval
## fires late, and nothing bursts under the flash. Seeded, not random, so a
## capture is reproducible shot to shot; the pattern varies burst to burst,
## which is all the eye ever compares.
class Confetti extends Control:
	const TONES: Array[Color] = [
		Color(1.0, 0.8509804, 0.47843137),   # #ffd97a
		Color(0.7882353, 0.6901961, 1.0),    # #c9b0ff
		Color(0.5607843, 0.9098039, 0.627451),  # #8fe8a0
	]
	const BURST_EVERY: float = 0.4
	const MIN_FESTIVAL: float = 4.2
	const LIFE: float = 1.2
	const DRAG: float = 1.6

	class Mote extends RefCounted:
		var pos: Vector2
		var vel: Vector2
		var tone: Color
		var born: float
		var life: float
		var width: float

	var _t: float = 0.0
	var _next_burst: float = BURST_EVERY
	var _seed: int = 0x0DA3
	var _motes: Array[Mote] = []
	var _finished: bool = false

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat: CanvasItemMaterial = CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat

	## The feed has settled; let the last motes gutter out.
	func finish() -> void:
		_finished = true

	func _process(delta: float) -> void:
		_t += delta
		var bursting: bool = _t <= MIN_FESTIVAL or not _finished
		if bursting and _t >= _next_burst:
			_next_burst += BURST_EVERY
			_burst()
		var alive: Array[Mote] = []
		for m: Mote in _motes:
			if _t - m.born > m.life:
				continue
			m.vel *= maxf(0.0, 1.0 - DRAG * delta)
			m.vel.y += 260.0 * delta
			m.pos += m.vel * delta
			alive.append(m)
		_motes = alive
		if _finished and _t > MIN_FESTIVAL and _motes.is_empty():
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
			# vfx.js:154 — speed * (0.35 + rand * 0.75).
			var speed: float = 300.0 * (0.35 + 0.75 * _rand())
			var m: Mote = Mote.new()
			m.pos = at
			m.vel = Vector2(cos(ang), sin(ang)) * speed
			m.tone = tone
			m.born = _t
			m.life = LIFE * (0.6 + 0.8 * _rand())
			# vfx.js: lineWidth = size * a with size 3 × (0.6 + rand × 0.8) —
			# the width spread is part of why a burst reads as depth.
			m.width = 3.0 * (0.6 + 0.8 * _rand())
			_motes.append(m)

	func _draw() -> void:
		for m: Mote in _motes:
			var left: float = m.life - (_t - m.born)
			# Opaque until the final quarter-second (vfx.js: min(1, life/0.25)).
			var a: float = clampf(left / 0.25, 0.0, 1.0)
			var speed: float = m.vel.length()
			var stroke: Vector2 = (m.vel / speed if speed > 0.01 else Vector2.DOWN) \
				* (speed * 0.045 + 2.0)
			# The streak trails BEHIND the mote (vfx.js:94-97 draws pos back
			# along its angle) — the trail is the motion cue. And under ADD
			# the festival tones must arrive scaled down, or every overlap
			# clips to white and two of the three tones stop existing:
			# measured 712 of 1402 mote pixels hueless at full value.
			var lit: Color = Color(m.tone.r * 0.55, m.tone.g * 0.55, m.tone.b * 0.55, a)
			draw_line(m.pos, m.pos - stroke, lit, maxf(0.5, m.width * a))


# ---------------------------------------------------------------- chrome

## The reveal slides the CARD inside a seat the grid owns. The seat is a
## REAL container — a MarginContainer whose top and bottom margins always
## sum to TRAVEL — so container sizing and minimum-size propagation stay
## intact and every card in a row stretches to the row's height. The first
## cut used a bare Control here, which sorts nothing: the fresh dawn's one
## card arrived force-sized to the whole reserve and unsorted — a blank
## 224px pane on the frame this screen exists for.
func _seat(card: PanelContainer, travel: float = 0.0) -> MarginContainer:
	var seat: MarginContainer = MarginContainer.new()
	seat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seat.add_child(card)
	_set_travel(seat, travel)
	return seat


static func _set_travel(seat: MarginContainer, px: float) -> void:
	seat.add_theme_constant_override("margin_top", int(roundf(px)))
	seat.add_theme_constant_override("margin_bottom", int(roundf(TRAVEL - px)))


## `.dawn-event` (styles.css:2579-2591), flat: min 145×82, 1px border
## rgba(242,193,78,.22) on rgba(8,9,16,.82), radius 9, padding 9/11 — and NO
## shadow and NO "current" state. The reference lights every memory the
## same; the arriving one announces itself by its entrance, not by a border
## three times brighter than its neighbours' (which is also what kept a
## resumed feed from matching a watched one).
func _event_card(event: Dictionary) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(145, 82)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.03137255, 0.03529412, 0.0627451, 0.82)
	style.set_border_width_all(1)
	style.border_color = Color(RunStyle.GOLD, 0.22)
	style.set_corner_radius_all(9)
	style.content_margin_left = 11
	style.content_margin_right = 11
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	card.add_theme_stylebox_override("panel", style)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 4)
	card.add_child(stack)
	# Glyph speaks the register — shardGrant / act4Reveal (end.js:117-122)
	# render icon + name/copy with no kicker.
	if event.has("icon"):
		var glyph_id: String = str(event["icon"])
		if glyph_id == "shard" or glyph_id == "door":
			stack.add_child(DawnGlyph.new(glyph_id))
	else:
		var kind: String = str(event.get("kind", "memory"))
		var kicker: Label = _label(_event_kicker(kind), 9, RunStyle.GOLD_DIM)
		kicker.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_700, 1))
		stack.add_child(kicker)
	# Kicker speaks the register; title carries the earned thing; a whisper
	# has no title and an unlock may have no body — empty lines take no room.
	var title_text: String = str(event.get("title", ""))
	if not title_text.is_empty():
		var title: Label = _label(title_text, 13, RunStyle.PARCHMENT)
		title.add_theme_font_override("font", load(GlassStyle.CINZEL_700) as Font)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stack.add_child(title)
	var body_text: String = str(event.get("body", ""))
	if not body_text.is_empty():
		var body: Label = _label(body_text, 11, RunStyle.TEXT)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stack.add_child(body)
	# `.dawn-count` (styles.css:2589-2590) — questProgress progress/target.
	if event.has("count"):
		var count_text: String = str(event["count"])
		if not count_text.is_empty():
			var count_seat: MarginContainer = MarginContainer.new()
			count_seat.add_theme_constant_override("margin_top", 5)
			count_seat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var count_label: Label = _label(count_text, 17, RunStyle.GOLD)
			count_label.add_theme_font_override("font",
				load(GlassStyle.CINZEL_700) as Font)
			count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			count_seat.add_child(count_label)
			stack.add_child(count_seat)
	return card


## Emberglass shard + sealed-door glyphs (art.js:502, :506), drawn in a
## 24-unit viewbox scaled to 42×42 / 48×48. Gold fill at low alpha, stroked
## outline — the reference's SVG paths, not textures.
class DawnGlyph extends Control:
	var _kind: String = ""

	func _init(kind: String) -> void:
		_kind = kind
		var side: float = 42.0 if kind == "shard" else 48.0
		custom_minimum_size = Vector2(side, side)
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s: float = size.x / 24.0
		match _kind:
			"shard":
				_draw_shard(s)
			"door":
				_draw_door(s)

	func _draw_shard(s: float) -> void:
		# Pentagon: M(12,2.6) L(19.2,8.2) L(16.6,20.4) L(8.1,18.8) L(4.8,8.8) Z
		var pts: PackedVector2Array = PackedVector2Array([
			Vector2(12.0, 2.6) * s,
			Vector2(19.2, 8.2) * s,
			Vector2(16.6, 20.4) * s,
			Vector2(8.1, 18.8) * s,
			Vector2(4.8, 8.8) * s,
		])
		draw_colored_polygon(pts, Color(RunStyle.GOLD, 0.2))
		var ring: PackedVector2Array = pts.duplicate()
		ring.append(pts[0])
		draw_polyline(ring, RunStyle.GOLD, 1.9, true)
		# Facets: (4.8,8.8)→(11.6,11.5)→(19.2,8.2);
		# (12,2.6)→(11.6,11.5)→(8.1,18.8); (11.6,11.5)→(16.6,20.4).
		var hub: Vector2 = Vector2(11.6, 11.5) * s
		draw_polyline(PackedVector2Array([
			Vector2(4.8, 8.8) * s, hub, Vector2(19.2, 8.2) * s,
		]), RunStyle.GOLD, 1.35, true)
		draw_polyline(PackedVector2Array([
			Vector2(12.0, 2.6) * s, hub, Vector2(8.1, 18.8) * s,
		]), RunStyle.GOLD, 1.35, true)
		draw_line(hub, Vector2(16.6, 20.4) * s, RunStyle.GOLD, 1.35, true)

	func _draw_door(s: float) -> void:
		# Outer arch: M(6.1,21) V(9.4) arc r=5.9 to (17.9,9.4) V(21) Z.
		var outer: PackedVector2Array = PackedVector2Array()
		outer.append(Vector2(6.1, 21.0) * s)
		var oc: Vector2 = Vector2(12.0, 9.4)
		var orad: float = 5.9
		for i: int in range(16):
			var a: float = PI + (float(i) / 15.0) * PI
			outer.append(Vector2(oc.x + cos(a) * orad, oc.y + sin(a) * orad) * s)
		outer.append(Vector2(17.9, 21.0) * s)
		draw_colored_polygon(outer, Color(RunStyle.GOLD, 0.16))
		var outer_ring: PackedVector2Array = outer.duplicate()
		outer_ring.append(outer[0])
		draw_polyline(outer_ring, RunStyle.GOLD, 1.9, true)
		# Inner arch: (9,21)→(9,9.7) arc r=3 to (15,9.7)→(15,21).
		var inner: PackedVector2Array = PackedVector2Array()
		inner.append(Vector2(9.0, 21.0) * s)
		var ic: Vector2 = Vector2(12.0, 9.7)
		var irad: float = 3.0
		for i: int in range(16):
			var a: float = PI + (float(i) / 15.0) * PI
			inner.append(Vector2(ic.x + cos(a) * irad, ic.y + sin(a) * irad) * s)
		inner.append(Vector2(15.0, 21.0) * s)
		draw_polyline(inner, RunStyle.GOLD, 1.55, true)
		# Centre bar, ground line, handle stub.
		draw_line(Vector2(12.0, 6.8) * s, Vector2(12.0, 21.0) * s,
			RunStyle.GOLD, 1.55, true)
		draw_line(Vector2(4.4, 21.0) * s, Vector2(19.6, 21.0) * s,
			RunStyle.GOLD, 1.9, true)
		draw_line(Vector2(10.7, 13.4) * s, Vector2(12.0, 13.4) * s,
			RunStyle.GOLD, 1.9, true)


func _build_stats(column: VBoxContainer) -> void:
	_stats_grid = GridContainer.new()
	_stats_grid.columns = 4
	_stats_grid.add_theme_constant_override("h_separation", 4)
	_stats_grid.add_theme_constant_override("v_separation", 4)
	_stats_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_stats_grid)
	for row: Array in [
		["floors", Locale.active.t("ui.end.floors").to_upper()],
		["slain", Locale.active.t("ui.end.slain").to_upper()],
		["elites_bosses", Locale.active.t("ui.end.elitesBossesPlus").to_upper()],
		["deck_size", Locale.active.t("ui.end.deckSize").to_upper()],
		["damage_dealt", Locale.active.t("ui.end.dmgDealt").to_upper()],
		["damage_taken", Locale.active.t("ui.end.dmgTaken").to_upper()],
		["cards_played", Locale.active.t("ui.end.cardsPlayed").to_upper()],
		["run_time", Locale.active.t("ui.end.runTime").to_upper()],
	]:
		var cell: PanelContainer = PanelContainer.new()
		cell.add_theme_stylebox_override("panel", GlassStyle.stat_cell())
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
		"whisper": return Locale.active.t("ui.dawn.kickerWhisper")
		"quest": return Locale.active.t("ui.dawn.kickerQuest")
		"progress": return Locale.active.t("ui.dawn.kickerProgress")
		"shard": return Locale.active.t("ui.dawn.kickerShard")
		"unlock": return Locale.active.t("ui.dawn.kickerUnlock")
		_: return Locale.active.t("ui.dawn.kickerDefault")


## `primary` marks the way ONWARD — the port's own hierarchy (the benchmark
## dresses both as plain .btn), applied the same way on both end screens:
## the terminal commit wears gold, the deck viewer steps back. Two gold
## plates side by side weighed a choice the screen never asks.
func _action_button(text: String, primary: bool = false) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(190, 46)
	button.add_theme_font_override("font", load(GlassStyle.CINZEL_700) as Font)
	RunStyle.style_button(button, primary)
	# `.btn:disabled { opacity: 0.45 }` (styles.css:156) fades the COMPOSED
	# button once. Here modulate does all of it, so the disabled dressing
	# must do none — full plate, its own label ink. Stacking style_button's
	# faded plate and 0.45 label under the modulate faded the text three
	# times over: measured gone (max luminance 89, same as its plate).
	button.add_theme_stylebox_override("disabled", button.get_theme_stylebox("normal"))
	button.add_theme_color_override("font_disabled_color",
		RunStyle.INK if primary else RunStyle.PARCHMENT)
	return button


func _progress_text() -> String:
	if _events.is_empty() or _cursor >= _events.size():
		return Locale.active.t("ui.dawn.complete")
	return Locale.active.t("ui.dawn.progress", {
		"n": _cursor + 1, "total": _events.size(),
	})


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
	# FINAL-content-sized under the shape's CAP. The reference is
	# content-sized live (max-height: 27cqh, styles.css:2576) because its
	# whole drain lasts 3.3s; the port's feed breathes with the player, and a
	# panel that grew mid-ceremony would shove every element on the screen
	# once a row. So the reserve is the height the feed ENDS at — at most one
	# unfilled row of quiet, gone by the ceremony's midpoint, instead of the
	# old 260px floor that opened on two missing rows of hole.
	var rows: int = maxi(1, int(ceilf(
		float(maxi(1, _events.size())) / float(maxi(1, columns)))))
	# A seat is 82 + TRAVEL tall — the reviewer's parting nit, banked.
	var need: float = float(rows) * 94.0 + float(rows - 1) * 8.0
	_grid.get_parent().custom_minimum_size.y = minf(grid_height, need)


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
