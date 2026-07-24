class_name EnemyView
extends PanelContainer
## One enemy pane: a floating night-glass placard holding an ember intent chip,
## a living glass-gem avatar, name, HP bar, a segmented facet gauge, ward, and
## statuses. Renders from explicit sync calls / event fields — never reads
## combat state directly (the sequencer contract). Targeting is drop-based (the
## hand's drag machine hit-tests this view's rect), so the pane takes no
## pointer input of its own.

var idx: int = 0

var _hue: float = 210.0
var _max_hp: int = 1
var _intent_chip: PanelContainer
var _intent: Label
var _gem: GlassGem
var _name_label: Label
var _hp_bar: ProgressBar
var _hp_label: Label
var _facets: FacetPips
var _ward_chip: PanelContainer
var _ward: Label
var _statuses: Label
var _dead: bool = false


func _init(enemy_idx: int, display_name: String, hue: float = 210.0) -> void:
	idx = enemy_idx
	_hue = hue
	custom_minimum_size = Vector2(196, 264)
	add_theme_stylebox_override("panel", GlassStyle.pane(GlassStyle.GLASS))

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(box)

	_intent_chip = _chip(GlassStyle.EMBER)
	_intent = _chip_label(_intent_chip, GlassStyle.EMBER)
	box.add_child(_center(_intent_chip))

	_gem = GlassGem.new()
	_gem.custom_minimum_size = Vector2(150, 92)
	_gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gem.set_state(_hue, 1.0, false)
	box.add_child(_gem)

	_name_label = _label(display_name)
	_name_label.add_theme_font_size_override("font_size", 16)
	box.add_child(_name_label)

	var hp_wrap: Control = Control.new()
	hp_wrap.custom_minimum_size = Vector2(0, 18)
	hp_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(hp_wrap)
	_hp_bar = ProgressBar.new()
	_hp_bar.show_percentage = false
	_hp_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	GlassStyle.style_bar(_hp_bar, GlassStyle.HP_RED)
	hp_wrap.add_child(_hp_bar)
	_hp_label = _label("")
	_hp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_label.add_theme_font_size_override("font_size", 12)
	_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_wrap.add_child(_hp_label)

	_facets = FacetPips.new()
	_facets.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_facets)

	_ward_chip = _chip(GlassStyle.GLASS)
	_ward = _chip_label(_ward_chip, GlassStyle.GLASS)
	_ward_chip.visible = false
	box.add_child(_center(_ward_chip))

	_statuses = _label("")
	_statuses.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
	_statuses.add_theme_font_size_override("font_size", 12)
	_statuses.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_statuses)


static func _label(initial: String) -> Label:
	var l: Label = Label.new()
	l.text = initial
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func _chip(accent: Color) -> PanelContainer:
	var c: PanelContainer = PanelContainer.new()
	c.add_theme_stylebox_override("panel", GlassStyle.chip(accent))
	return c


static func _chip_label(chip: PanelContainer, accent: Color) -> Label:
	var l: Label = _label("")
	l.add_theme_color_override("font_color", Color(accent.r, accent.g, accent.b, 0.95))
	l.add_theme_font_size_override("font_size", 13)
	chip.add_child(l)
	return l


## Chips size to content; wrap in a centre container so they don't stretch.
static func _center(node: Control) -> CenterContainer:
	var cc: CenterContainer = CenterContainer.new()
	cc.add_child(node)
	return cc


## Full sync from an enemy snapshot (drain-idle truth). dmg_text is already
## formatted by the screen ("" when the move deals no damage).
func sync(e: EnemyCombatant, dmg_text: String, intent_text: String) -> void:
	set_hp(e.hp, e.max_hp)
	set_ward(e.block)
	set_facets(mini(e.chips, e.facet_max), e.facet_max)
	set_statuses(e.statuses)
	var line: String = intent_text
	if dmg_text != "":
		line += "   %s" % dmg_text
	set_intent(line)
	if e.hp <= 0:
		mark_dead()


func set_hp(hp: int, max_hp: int) -> void:
	_max_hp = maxi(max_hp, 1)
	_hp_bar.max_value = _max_hp
	_hp_bar.value = maxi(0, hp)
	_hp_label.text = "%d / %d" % [maxi(0, hp), max_hp]
	if not _dead:
		_gem.set_state(_hue, float(maxi(0, hp)) / float(_max_hp), hp <= 0)


func set_ward(block: int) -> void:
	_ward_chip.visible = block > 0
	if block > 0:
		_ward.text = "Ward %d" % block


func set_facets(chips: int, facet_max: int) -> void:
	_facets.set_pips(chips, facet_max)


func set_intent(intent_text: String) -> void:
	_intent.text = intent_text
	_intent_chip.visible = intent_text.strip_edges() != ""


func set_statuses(statuses: Dictionary) -> void:
	var parts: Array[String] = []
	for k: Variant in statuses.keys():
		var n: int = statuses[k]
		if n != 0:
			parts.append("%s %d" % [str(k), n])
	_statuses.text = " · ".join(parts)


## Death leaves a dark husk; the gem goes cold and the pane fades back.
func mark_dead() -> void:
	_dead = true
	modulate = Color(0.5, 0.5, 0.56, 0.5)
	_gem.set_state(_hue, 0.0, true)
	_intent_chip.visible = false


func set_targetable(on: bool) -> void:
	if _dead:
		return
	modulate = Color(1.28, 1.14, 0.9, 1.0) if on else Color(1, 1, 1, 1)
