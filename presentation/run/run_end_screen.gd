class_name RunEndScreen
extends Control
## Benchmark terminal presentation. The application owns bequests and Vigil commits.

signal bequest_requested(id: String)
signal commit_requested
signal deck_requested

const FALLEN: String = "res://assets/art/meta/fallen.png"
## `monumentRise` cubic-bezier(0.2, 0.7, 0.3, 1) — no Motion constant matches
## exactly (SCREEN_IN is 0.2/0.7/0.25/1; ENTER is 0.2/0.75/0.3/1).
const MONUMENT_RISE: Array[float] = [0.2, 0.7, 0.3, 1.0]

var shape: StringName = StageShape.IDENTITY

var _outcome: String
var _stats: Dictionary
var _bequest_choices: Array
var _bequest_answered: bool
var _fall_floor: int
var _sfx: SfxBus
var _margin: MarginContainer
var _panel: PanelContainer
var _column: VBoxContainer
var _title: Label
var _stats_grid: GridContainer
var _bequest_grid: GridContainer
var _grave_plate: ColorRect
var _rise_tween: Tween = null
var _rise_snapped: bool = false


func _init(outcome: String, stats: Dictionary, bequest_choices: Array,
		bequest_answered: bool, fall_floor: int,
		stage_shape: StringName = StageShape.IDENTITY, sfx: SfxBus = null) -> void:
	_outcome = outcome
	_stats = stats.duplicate(true)
	_bequest_choices = bequest_choices.duplicate(true)
	_bequest_answered = bequest_answered
	_fall_floor = maxi(0, fall_floor)
	shape = stage_shape if StageShape.REFERENCES.has(stage_shape) else StageShape.IDENTITY
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GlassStyle.theme()
	_sfx = sfx if sfx != null else SfxBus.new()
	if sfx == null:
		add_child(_sfx)
	_build()


func _ready() -> void:
	# Death owns the grave entrance (styles.css:1781-1791); abandon keeps the
	# generic screen_in from main. Reduce-motion skips both — final state now.
	if _outcome != "death" or Preferences.active.reduce_motion:
		return
	# graveReveal: ground starts BLACK and eases to the warm grave over 2.2s.
	if _grave_plate != null:
		var plate: ColorRect = _grave_plate
		Motion.bez(self, func(t: float) -> void:
			if is_instance_valid(plate):
				plate.modulate.a = 1.0 - t
		, 2.2, Motion.CSS_EASE).finished.connect(func() -> void:
			if is_instance_valid(plate):
				plate.queue_free()
			if _grave_plate == plate:
				_grave_plate = null
		)
	# monumentRise `both`: from-state (α0, +46px) holds through the 0.4s delay.
	_panel.modulate.a = 0.0
	await get_tree().process_frame
	if not is_instance_valid(_panel):
		return
	var base_y: float = _panel.position.y
	_panel.position.y = base_y + 46.0
	resized.connect(_on_rise_resized)
	await get_tree().create_timer(0.4).timeout
	if not is_instance_valid(_panel) or _rise_snapped:
		return
	_rise_tween = Motion.bez(self, func(t: float) -> void:
		if not is_instance_valid(_panel):
			return
		_panel.modulate.a = t
		_panel.position.y = base_y + 46.0 * (1.0 - t)
	, 1.6, MONUMENT_RISE)


func _on_rise_resized() -> void:
	# A resize re-seats the CenterContainer; writing against the captured base_y
	# would strand the monument. Snap to the container's fresh seat instead —
	# during the 0.4s hold too, where base_y is already stale before the tween
	# even starts.
	if _rise_snapped:
		return
	_rise_snapped = true
	if _rise_tween != null and is_instance_valid(_rise_tween) and _rise_tween.is_running():
		_rise_tween.kill()
	_rise_tween = null
	if is_instance_valid(_panel):
		_panel.modulate.a = 1.0


func _build() -> void:
	# "win" never reaches this screen: main short-circuits it to the Dawn
	# ceremony before construction (_show_run_end), exactly as the benchmark's
	# won end-screen is its own render branch (end.js:186).
	if _outcome == "death":
		_add_meta_backdrop(FALLEN)
		# Between backdrop and vignette — the black plate that graveReveal
		# dissolves. Reduce-motion never builds it (final state immediately).
		# Opaque by design — a deliberate deviation. The reference's graveReveal
		# swings only ≈(1.7, 2.1, 3.9) at the ellipse centre because its black sits
		# behind a 75-96% radial and .meta-bg at 0.4 — this port's opaque plate
		# swings ≈(9.5, 10.9, 12.3) by design, because the literal reading is the
		# invisible nothing issue #18 complained about.
		if not Preferences.active.reduce_motion:
			_grave_plate = ColorRect.new()
			_grave_plate.color = Color.BLACK
			_grave_plate.set_anchors_preset(Control.PRESET_FULL_RECT)
			_grave_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(_grave_plate)
	else:
		RunStyle.add_backdrop(self)
	_add_vignette()

	_margin = MarginContainer.new()
	_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_margin.add_child(scroll)
	var centre: CenterContainer = CenterContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(centre)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", RunStyle.panel(14, 24, 0.90))
	centre.add_child(_panel)
	_column = VBoxContainer.new()
	_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_column.add_theme_constant_override("separation", 9)
	_panel.add_child(_column)

	if _outcome == "death":
		# `.mon-flame` stands ON the monument, above the carved word.
		_column.add_child(MonumentFlame.new())
	_title = _label(_title_text(), 42, _title_colour())
	_title.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_700, 4))
	_column.add_child(_title)
	var subtitle: Label = _label(_subtitle_text(), 16, RunStyle.TEXT_DIM)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(subtitle)
	_column.add_child(_underline())
	_build_stats()
	# Benchmark renders stats + bequest + buttons TOGETHER (end.js:216-221).
	# Declining the bequest must still leave the exit.
	if _outcome == "death" and not _bequest_answered and not _bequest_choices.is_empty():
		_build_bequest()
	_build_commit()
	if _outcome == "death":
		# LAST child, like the reference: `.embers` is the final child of
		# `.end-screen` in the same stacking context as the monument
		# (end.js:222, styles.css:1774) — the ash rises across the FACE of
		# the stone. Built under the panel, 78% of the field's span was
		# hidden behind 90%-opaque glass; the field ignores the mouse, so
		# nothing under it loses a click.
		_add_embers()
	set_shape(shape)


func _build_stats() -> void:
	_stats_grid = GridContainer.new()
	_stats_grid.columns = 4
	_stats_grid.add_theme_constant_override("h_separation", 6)
	_stats_grid.add_theme_constant_override("v_separation", 6)
	_stats_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column.add_child(_stats_grid)
	_add_stat("floors", "FLOORS")
	_add_stat("slain", "SLAIN")
	_add_stat("elites_bosses", "ELITES + BOSSES")
	_add_stat("deck_size", "DECK SIZE")
	_add_stat("damage_dealt", "DAMAGE DEALT")
	_add_stat("damage_taken", "DAMAGE TAKEN")
	_add_stat("cards_played", "CARDS PLAYED")
	_add_stat("run_time", "RUN TIME")


func _add_stat(key: String, caption: String) -> void:
	var cell: PanelContainer = PanelContainer.new()
	cell.add_theme_stylebox_override("panel", GlassStyle.stat_cell())
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_grid.add_child(cell)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	cell.add_child(stack)
	var value: Label = _label(str(_stats.get(key, "—")), 22, RunStyle.PARCHMENT)
	value.add_theme_font_override("font", load(GlassStyle.CINZEL_700) as Font)
	stack.add_child(value)
	var name_label: Label = _label(caption, 9, RunStyle.TEXT_DIM)
	name_label.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_500, 1))
	stack.add_child(name_label)


func _build_bequest() -> void:
	var copy: Label = _label(
		"Carve one thing into the stone — the next climb may recover it in %s."
		% str(_stats.get("act_name", "this act")), 13, RunStyle.TEXT_DIM)
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(copy)
	_bequest_grid = GridContainer.new()
	_bequest_grid.columns = mini(4, _bequest_choices.size())
	_bequest_grid.add_theme_constant_override("h_separation", 10)
	_bequest_grid.add_theme_constant_override("v_separation", 8)
	_bequest_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_column.add_child(_bequest_grid)
	for row_v: Variant in _bequest_choices:
		var row: Dictionary = row_v
		var button: Button = _bequest_button(row)
		button.pressed.connect(_request_bequest.bind(str(row.get("id", ""))))
		_bequest_grid.add_child(button)


func _bequest_button(row: Dictionary) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(148, 102)
	RunStyle.style_card(button, false)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.offset_left = 8
	stack.offset_top = 7
	stack.offset_right = -8
	stack.offset_bottom = -7
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 2)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(stack)
	var icons: HBoxContainer = HBoxContainer.new()
	icons.alignment = BoxContainer.ALIGNMENT_CENTER
	icons.add_theme_constant_override("separation", 3)
	icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(icons)
	for path_v: Variant in [row.get("icon", ""), row.get("art", "")]:
		var path: String = str(path_v)
		if path.is_empty() or not ResourceLoader.exists(path):
			continue
		var art: TextureRect = TextureRect.new()
		art.texture = load(path) as Texture2D
		art.custom_minimum_size = Vector2(27, 27)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icons.add_child(art)
	var name_label: Label = _label(str(row.get("name", row.get("label", ""))),
		14, RunStyle.PARCHMENT)
	name_label.add_theme_font_override("font", load(GlassStyle.CINZEL_500) as Font)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(name_label)
	var note: Label = _label(str(row.get("note", "")), 11, RunStyle.TEXT_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(note)
	return button


func _build_commit() -> void:
	var actions: HBoxContainer = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	_column.add_child(actions)
	var deck: Button = _action_button("VIEW FINAL DECK")
	deck.pressed.connect(func() -> void:
		_sfx.play(&"click")
		deck_requested.emit()
	)
	actions.add_child(deck)
	# The way onward is the CTA; the deck viewer is a side glance. Two
	# identically-dressed buttons made the player weigh a choice this screen
	# is not asking them to make.
	var commit: Button = _action_button("RETURN TO THE VIGIL", true)
	commit.pressed.connect(_request_commit)
	actions.add_child(commit)


func _action_button(text: String, primary: bool = false) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(190, 46)
	button.add_theme_font_override("font", load(GlassStyle.CINZEL_700) as Font)
	RunStyle.style_button(button, primary)
	return button


func _request_bequest(id: String) -> void:
	_sfx.play(&"relic")
	bequest_requested.emit(id)


func _request_commit() -> void:
	_sfx.play(&"click")
	commit_requested.emit()


func set_shape(stage_shape: StringName) -> void:
	if not StageShape.REFERENCES.has(stage_shape):
		return
	shape = stage_shape
	match shape:
		&"phone-portrait":
			_apply_shape(14, 350, 42, 2, 1)
		&"pad-portrait":
			_apply_shape(42, 700, 64, 4, 2)
		&"pad-landscape":
			_apply_shape(54, 780, 72, 4, 4)
		&"desktop-landscape":
			_apply_shape(58, 820, 80, 4, 4)
		&"phone-landscape":
			_apply_shape(10, 720, 46, 4, 2)


func _apply_shape(inset: int, panel_width: float, title_size: int,
		stat_columns: int, bequest_columns: int) -> void:
	for side: String in ["left", "right", "top", "bottom"]:
		_margin.add_theme_constant_override("margin_" + side, inset)
	_panel.custom_minimum_size.x = panel_width
	_title.add_theme_font_size_override("font_size", title_size)
	_stats_grid.columns = stat_columns
	if _bequest_grid != null:
		_bequest_grid.columns = mini(bequest_columns, _bequest_choices.size())


func _title_text() -> String:
	match _outcome:
		"death": return "FALLEN"
		_: return "THE VOW IS SET ASIDE"


func _subtitle_text() -> String:
	match _outcome:
		"death": return "Your lantern went dark on floor %d." % _fall_floor
		_: return "The pilgrimage ends here. The Vigil will keep the record."


func _title_colour() -> Color:
	return Color("#6a7288") if _outcome == "death" else RunStyle.PARCHMENT


func _add_meta_backdrop(path: String) -> void:
	var art: TextureRect = TextureRect.new()
	art.texture = load(path) as Texture2D
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)


func _add_vignette() -> void:
	var shade: TextureRect = TextureRect.new()
	shade.texture = GlassStyle.grad_tex(
		PackedColorArray([Color(0, 0, 0, 0.16), Color(0, 0, 0, 0.78)]),
		PackedFloat32Array([0.0, 1.0]), true, Vector2(0.5, 0.48), Vector2(1.0, 0.48))
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)


## rgba(255,150,70) — the one warm the fire sheds, whether it is an ember's
## halo or the flame's throw. Declared once; two names for one colour was
## its own review finding.
const FIRE_WARM: Color = Color(1.0, 0.5882353, 0.27450982)


func _add_embers() -> void:
	# Seeded per DEATH, not per build: off the global streams (a field must
	# not perturb a run's rolls) but keyed to the fall, so two graves are not
	# the same photograph.
	add_child(EmberField.new(0x0EA5 ^ (_fall_floor * 2654435761)))


## The fallen screen's living ash (end.js:212-213, styles.css:1801-1811):
## fourteen embers rising from below the monument on their own clocks,
## forever. What stood here before was fourteen STATIC rectangles — the
## field is the point, a grave that still breathes heat. Drawn, not noded:
## fourteen soft dots a frame is one canvas item.
class EmberField extends Control:
	class Ember extends RefCounted:
		var x_frac: float   # left: 8% + rand * 84%
		var ex: float       # --ex: horizontal drift over the whole rise, ±45px
		var delay: float    # animation-delay: 0-4s
		var dur: float      # animation-duration: 3-6s

	## `emberRise` climbs -46cqh from `bottom: 18%` on a LINEAR clock.
	const RISE_FRAC: float = 0.46
	const FLOOR_FRAC: float = 0.82
	const BODY: Color = Color(1.0, 0.6901961, 0.4)          # #ffb066
	const HALO: Color = RunEndScreen.FIRE_WARM

	var _t: float = 0.0
	var _seed: int = 0x0EA5
	var _embers: Array[Ember] = []

	func _init(seed_in: int = 0x0EA5) -> void:
		_seed = seed_in & 0x7FFFFFFF
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for i: int in range(14):
			var e: Ember = Ember.new()
			e.x_frac = 0.08 + _rand() * 0.84
			e.ex = (_rand() - 0.5) * 90.0
			e.delay = _rand() * 4.0
			e.dur = 3.0 + _rand() * 3.0
			_embers.append(e)

	func _rand() -> float:
		_seed = (_seed * 1103515245 + 12345) & 0x7FFFFFFF
		return float(_seed) / float(0x7FFFFFFF)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		for e: Ember in _embers:
			var alive: float = _t - e.delay
			if alive < 0.0:
				continue
			var u: float = fmod(alive, e.dur) / e.dur
			# 0% α0 → 12% α0.95 → 100% α0, all on the linear clock.
			var a: float = (u / 0.12) * 0.95 if u < 0.12 \
				else 0.95 * (1.0 - (u - 0.12) / 0.88)
			var s: float = lerpf(1.0, 0.4, u)
			var at: Vector2 = Vector2(
				e.x_frac * size.x + e.ex * u,
				size.y * FLOOR_FRAC - size.y * RISE_FRAC * u)
			# The 8px box-shadow at 0.9 (styles.css:1804), read as soft rings
			# under the 4px body — the glow IS the ember at a glance; the dot
			# alone read as noise against the night ground.
			draw_circle(at, 7.0 * s, Color(HALO, a * 0.22))
			draw_circle(at, 4.4 * s, Color(HALO, a * 0.48))
			draw_circle(at, 2.0 * s, Color(BODY, a))


## The monument's flame (styles.css:1794-1800): a thumb of fire above the
## carved name, guttering on `monFlame`'s 2.6s ease-in-out — 0.9 tall, 0.5
## crouched at 38%, straightening through 62% with a 3° lean. The grave is
## not cold, which is the whole argument of the screen.
class MonumentFlame extends Control:
	const TIME: float = 2.6
	const AT: Array[float] = [0.0, 0.38, 0.62, 1.0]
	const ALPHA: Array[float] = [0.9, 0.5, 0.8, 0.9]
	const SCALE_Y: Array[float] = [1.0, 0.7, 0.9, 1.0]
	const ROT: Array[float] = [0.0, 0.0, -3.0, 0.0]
	const CORE: Color = Color(1.0, 0.9529412, 0.8117647)    # #fff3cf
	const MID: Color = Color(1.0, 0.6039216, 0.3019608)     # #ff9a4d
	const ROOT: Color = Color(0.47843137, 0.22745098, 0.0627451)  # #7a3a10

	var _t: float = 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(12, 18)
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t = fmod(_t + delta, TIME)
		queue_redraw()

	func _draw() -> void:
		var u: float = _t / TIME
		var a: float = Motion.css_keyframe(u, AT, ALPHA)
		var sy: float = Motion.css_keyframe(u, AT, SCALE_Y)
		var rot: float = deg_to_rad(Motion.css_keyframe(u, AT, ROT))
		# Pivot at the BASE — a deliberate deviation. The stylesheet leaves
		# transform-origin at its 50% 50% default, so the reference squeezes
		# toward the flame's middle; a flame guttering from a fixed root is
		# the truer physical read, and this port takes it, on the record.
		var base: Vector2 = Vector2(size.x * 0.5, size.y)
		draw_set_transform(base, rot, Vector2(1.0, sy))
		# The radial gradient as three stacked drops — dark root at the base,
		# amber body, hot core — all held above the baseline so the flame
		# never dips into whatever the layout puts beneath it.
		draw_circle(Vector2(0, -6), 5.5, Color(ROOT, a * 0.85))
		draw_circle(Vector2(0, -8.5), 4.4, Color(MID, a * 0.95))
		draw_circle(Vector2(0, -11), 2.4, Color(CORE, a))
		# The 22px shed, AFTER the body so nothing covers its heart, with a
		# real falloff: box-shadow's blur is a gaussian, and a hard 9px disc
		# at 0.16 read as a bead of solder — 18px of warm field standing in
		# for a ~56px throw. Four widening rings approximate the curve and
		# actually reach the stone.
		for ring: int in range(4):
			var r: float = 10.0 + 6.5 * float(ring)
			var fade: float = 0.11 * pow(0.62, float(ring))
			draw_circle(Vector2(0, -8), r, Color(RunEndScreen.FIRE_WARM, a * fade))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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
