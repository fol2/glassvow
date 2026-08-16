class_name CounterfactualSelf
extends RefCounted
## Act IV tracer: pick the kit this player did not walk.
## Axis is the live deck (attack = ember, skill/power = ash). The unwalked
## kit is `axisToKit[axis]` on the enemy row — never a default, never RNG.

const AXIS_EMBER: StringName = &"ember"
const AXIS_ASH: StringName = &"ash"
const KIT_FLAG: String = "counterKit"


static func classify_axis(run: RunState, content: ContentDB) -> Dictionary:
	var ember: int = 0
	var ash: int = 0
	for card: CardInst in run.player.deck:
		var def_v: Variant = content.cards.get(String(card.id), {})
		if typeof(def_v) != TYPE_DICTIONARY:
			continue
		var def: Dictionary = def_v
		var card_type: String = str(def.get("type", ""))
		if card_type == "attack":
			ember += 1
		elif card_type == "skill" or card_type == "power":
			ash += 1
	if ember == 0 and ash == 0:
		return {"ok": false, "axis": &"", "error": "deck has no classifiable cards",
			"ember": 0, "ash": 0}
	var axis: StringName = AXIS_EMBER if ember > ash else AXIS_ASH
	return {"ok": true, "axis": axis, "error": "", "ember": ember, "ash": ash}


static func resolve(run: RunState, enemy_def: Dictionary, content: ContentDB) -> Dictionary:
	if not enemy_def.has("counterfactual"):
		return {"ok": true, "id": "", "error": ""}
	var spec_v: Variant = enemy_def["counterfactual"]
	if typeof(spec_v) != TYPE_DICTIONARY:
		return {"ok": false, "id": "", "error": "counterfactual spec is not a dictionary"}
	var spec: Dictionary = spec_v
	var kits_v: Variant = spec.get("kits", {})
	var map_v: Variant = spec.get("axisToKit", {})
	if typeof(kits_v) != TYPE_DICTIONARY or typeof(map_v) != TYPE_DICTIONARY:
		return {"ok": false, "id": "", "error": "counterfactual kits/axisToKit missing"}
	var classified: Dictionary = classify_axis(run, content)
	if classified.get("ok", false) != true:
		return {"ok": false, "id": "", "error": str(classified.get("error", "unclassified"))}
	var axis: String = str(classified["axis"])
	var axis_map: Dictionary = map_v
	if not axis_map.has(axis):
		return {"ok": false, "id": "", "error": "axisToKit has no %s" % axis}
	var kit_id: String = str(axis_map[axis])
	var kits: Dictionary = kits_v
	var moves_v: Variant = kits.get(kit_id, null)
	if typeof(moves_v) != TYPE_ARRAY:
		return {"ok": false, "id": "", "error": "unsupported kit %s" % kit_id}
	var rows: Array = moves_v
	if rows.is_empty():
		return {"ok": false, "id": "", "error": "unsupported kit %s" % kit_id}
	var authored: Dictionary = enemy_def.get("moves", {})
	for move_v: Variant in rows:
		if not authored.has(str(move_v)):
			return {"ok": false, "id": "", "error": "kit %s names unknown move %s" % [kit_id, str(move_v)]}
	return {"ok": true, "id": kit_id, "error": ""}
