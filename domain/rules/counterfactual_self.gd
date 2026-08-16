class_name CounterfactualSelf
extends RefCounted
## Act IV counterfactual selves: pick the kit this player did not walk.
## Each enemy names its axis (`deckType` or `statusLean`). The unwalked kit is
## `axisToKit[axis]` on the enemy row — never a default, never RNG.

const AXIS_DECK_TYPE: String = "deckType"
const AXIS_STATUS_LEAN: String = "statusLean"
const AXIS_EMBER: StringName = &"ember"
const AXIS_ASH: StringName = &"ash"
const AXIS_TOXIN: StringName = &"toxin"
const AXIS_WARD: StringName = &"ward"
const KIT_FLAG: String = "counterKit"


static func axis_keys(kind: String) -> PackedStringArray:
	match kind:
		AXIS_DECK_TYPE:
			return PackedStringArray(["ember", "ash"])
		AXIS_STATUS_LEAN:
			return PackedStringArray(["toxin", "ward"])
		_:
			return PackedStringArray()


static func classify_axis(run: RunState, content: ContentDB,
		axis_kind: String = AXIS_DECK_TYPE) -> Dictionary:
	match axis_kind:
		AXIS_DECK_TYPE:
			return _classify_deck_type(run, content)
		AXIS_STATUS_LEAN:
			return _classify_status_lean(run, content)
		_:
			return {"ok": false, "axis": &"", "error": "unknown axis %s" % axis_kind}


static func resolve(run: RunState, enemy_def: Dictionary, content: ContentDB) -> Dictionary:
	if not enemy_def.has("counterfactual"):
		return {"ok": true, "id": "", "error": ""}
	var spec_v: Variant = enemy_def["counterfactual"]
	if typeof(spec_v) != TYPE_DICTIONARY:
		return {"ok": false, "id": "", "error": "counterfactual spec is not a dictionary"}
	var spec: Dictionary = spec_v
	var axis_kind: String = str(spec.get("axis", AXIS_DECK_TYPE))
	if axis_keys(axis_kind).is_empty():
		return {"ok": false, "id": "", "error": "unknown axis %s" % axis_kind}
	var kits_v: Variant = spec.get("kits", {})
	var map_v: Variant = spec.get("axisToKit", {})
	if typeof(kits_v) != TYPE_DICTIONARY or typeof(map_v) != TYPE_DICTIONARY:
		return {"ok": false, "id": "", "error": "counterfactual kits/axisToKit missing"}
	var classified: Dictionary = classify_axis(run, content, axis_kind)
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


static func _classify_deck_type(run: RunState, content: ContentDB) -> Dictionary:
	var ember: int = 0
	var ash: int = 0
	for card: CardInst in run.player.deck:
		var def: Dictionary = _card_def(content, card)
		if def.is_empty():
			continue
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


static func _classify_status_lean(run: RunState, content: ContentDB) -> Dictionary:
	var toxin: int = 0
	var ward: int = 0
	for card: CardInst in run.player.deck:
		var lean: Dictionary = _status_lean(_card_def(content, card))
		if lean.get("toxin", false) == true:
			toxin += 1
		if lean.get("ward", false) == true:
			ward += 1
	if toxin == 0 and ward == 0:
		return {"ok": false, "axis": &"", "error": "deck has no toxin or ward cards",
			"toxin": 0, "ward": 0}
	var axis: StringName = AXIS_TOXIN if toxin > ward else AXIS_WARD
	return {"ok": true, "axis": axis, "error": "", "toxin": toxin, "ward": ward}


static func _card_def(content: ContentDB, card: CardInst) -> Dictionary:
	var def_v: Variant = content.cards.get(String(card.id), {})
	if typeof(def_v) != TYPE_DICTIONARY:
		return {}
	return def_v


static func _status_lean(def: Dictionary) -> Dictionary:
	var toxin: bool = false
	var ward: bool = false
	var effects_v: Variant = def.get("effects", [])
	if typeof(effects_v) != TYPE_ARRAY:
		return {"toxin": false, "ward": false}
	for fx_v: Variant in effects_v:
		if typeof(fx_v) != TYPE_DICTIONARY:
			continue
		var fx: Dictionary = fx_v
		if str(fx.get("kind", "")) == "block":
			ward = true
		if str(fx.get("id", "")) == "poison":
			toxin = true
	return {"toxin": toxin, "ward": ward}
