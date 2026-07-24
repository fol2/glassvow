class_name EnemyView
extends PanelContainer
## One enemy pane: intent, name, HP bar, ward, facet gauge, statuses.
## Renders from explicit sync calls / event fields — never reads combat
## state directly (the sequencer contract). Targeting is drop-based (the
## hand's drag machine hit-tests this view's rect), so the pane takes no
## pointer input of its own.

var idx: int = 0

var _intent: Label
var _name_label: Label
var _hp_bar: ProgressBar
var _hp_label: Label
var _ward: Label
var _facets: Label
var _statuses: Label
var _dead: bool = false


func _init(enemy_idx: int, display_name: String) -> void:
	idx = enemy_idx
	custom_minimum_size = Vector2(200, 250)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	_intent = _label("")
	_intent.add_theme_color_override("font_color", Color(1.0, 0.75, 0.45))
	box.add_child(_intent)
	_name_label = _label(display_name)
	box.add_child(_name_label)
	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(0, 14)
	_hp_bar.show_percentage = false
	box.add_child(_hp_bar)
	_hp_label = _label("")
	box.add_child(_hp_label)
	_ward = _label("")
	box.add_child(_ward)
	_facets = _label("")
	_facets.add_theme_color_override("font_color", Color(0.56, 0.82, 1.0))
	box.add_child(_facets)
	_statuses = _label("")
	_statuses.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_statuses)


static func _label(initial: String) -> Label:
	var l: Label = Label.new()
	l.text = initial
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## Full sync from an enemy snapshot (drain-idle truth). dmg_text is already
## formatted by the screen ("" when the move deals no damage).
func sync(e: EnemyCombatant, dmg_text: String, intent_text: String) -> void:
	set_hp(e.hp, e.max_hp)
	set_ward(e.block)
	set_facets(mini(e.chips, e.facet_max), e.facet_max)
	set_statuses(e.statuses)
	var line: String = intent_text
	if dmg_text != "":
		line += "  %s" % dmg_text
	set_intent(line)
	if e.hp <= 0:
		mark_dead()


func set_hp(hp: int, max_hp: int) -> void:
	_hp_bar.max_value = max_hp
	_hp_bar.value = maxi(0, hp)
	_hp_label.text = "%d / %d" % [maxi(0, hp), max_hp]


func set_ward(block: int) -> void:
	_ward.text = "Ward %d" % block if block > 0 else ""


func set_facets(chips: int, facet_max: int) -> void:
	_facets.text = "Facets %d / %d" % [chips, facet_max]


func set_intent(intent_text: String) -> void:
	_intent.text = intent_text


func set_statuses(statuses: Dictionary) -> void:
	var parts: Array[String] = []
	for k: Variant in statuses.keys():
		var n: int = statuses[k]
		if n != 0:
			parts.append("%s %d" % [str(k), n])
	_statuses.text = " · ".join(parts)


## Death leaves a faded husk this milestone; the dissolve lands with craft.
func mark_dead() -> void:
	_dead = true
	modulate = Color(0.35, 0.35, 0.4, 0.45)
	_intent.text = ""


func set_targetable(on: bool) -> void:
	if _dead:
		return
	modulate = Color(1.25, 1.1, 0.85, 1) if on else Color(1, 1, 1, 1)
