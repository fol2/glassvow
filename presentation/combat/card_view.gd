class_name CardView
extends Button
## One card in the hand. M5a skeleton: a tall button showing cost / name /
## rules text; drag-to-play arrives with the HandView input pass (M5b).

var uid: int = 0
var card_id: StringName = &""
## "enemy" needs a target click; everything else plays on press.
var target_kind: String = ""
var unplayable: bool = false


func _init(inst: CardInst, data: Dictionary, cost: int) -> void:
	uid = inst.uid
	card_id = inst.id
	target_kind = str(data.get("target", ""))
	var unplayable_flag: bool = data.get("unplayable", false)
	unplayable = unplayable_flag
	var display_name: String = str(data.get("name", String(inst.id)))
	if inst.up:
		display_name += "+"
	var rules_text: String = str(data.get("text", ""))
	# Web card text wraps numbers in @dmg@ / #block# markers; strip for now —
	# rich text lands with the craft pass.
	rules_text = rules_text.replace("@", "").replace("#", "")
	var cost_line: String = "-" if unplayable else str(cost)
	text = "[%s]  %s\n\n%s" % [cost_line, display_name, rules_text]
	custom_minimum_size = Vector2(150, 190)
	clip_text = false
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	alignment = HORIZONTAL_ALIGNMENT_CENTER


## Grey out cards the player cannot afford / play right now.
func set_playable(playable: bool) -> void:
	disabled = not playable
	modulate = Color(1, 1, 1, 1) if playable else Color(0.6, 0.6, 0.6, 0.8)


func set_armed(armed: bool) -> void:
	modulate = Color(1.2, 1.2, 0.7, 1) if armed else Color(1, 1, 1, 1)
