class_name VowIncentives
extends RefCounted
## Candidate vow-incentive mixes for the #211 bake-off.
## James signed `A_modest_linear` as drafted (2026-08-18). `apply()` always
## resets knobs first; `none` is identity. Live runs call `shipping()`.

const NONE_ID: String = "none"
const SHIPPING_ID: String = "A_modest_linear"


static func catalog() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append(_mix("none", "No incentives (penalty-only control)",
		0.0, false, 0.0, false, 0.0, [0.0, 0.0, 0.0, 0.0, 0.0, 0.0], 0.0, "stack"))
	out.append(_mix("A_modest_linear", "#206 modest: 5pp both-cuts, 5% linear gold, 15% 2nd relic",
		0.05, false, 0.05, false, 0.15, [0.0, 0.0, 0.0, 0.02, 0.03, 0.05], 0.01, "stack"))
	out.append(_mix("B_steep_rarity", "Steeper rarity (8pp), same gold, 20% 2nd relic",
		0.08, false, 0.05, false, 0.20, [0.0, 0.0, 0.0, 0.03, 0.05, 0.08], 0.01, "stack"))
	out.append(_mix("C_compound_gold", "5pp rarity, 5% compounding gold, 15% 2nd relic",
		0.05, false, 0.05, true, 0.15, [0.0, 0.0, 0.0, 0.02, 0.03, 0.05], 0.01, "stack"))
	out.append(_mix("D_gold_heavy", "Light rarity (3pp), 8% linear gold, 10% 2nd relic",
		0.03, false, 0.08, false, 0.10, [0.0, 0.0, 0.0, 0.02, 0.03, 0.05], 0.01, "stack"))
	out.append(_mix("E_relic_heavy", "5pp rarity, 5% linear, 30% 2nd relic at Mark",
		0.05, false, 0.05, false, 0.30, [0.0, 0.0, 0.0, 0.02, 0.04, 0.07], 0.015, "stack"))
	out.append(_mix("F_uncommon_only", "Outside #206: uncommon-only 8pp, 3% gold, 15% 2nd",
		0.08, true, 0.03, false, 0.15, [0.0, 0.0, 0.0, 0.01, 0.02, 0.04], 0.01, "stack"))
	return out


static func _mix(id: String, label: String, rarity_pp: float, uncommon_only: bool,
		gold_pp: float, compound: bool, elite_second: float, mythic: Array,
		post_delta: float, post_mode: String) -> Dictionary:
	return {
		"id": id, "label": label,
		"rarity_pp": rarity_pp, "rarity_uncommon_only": uncommon_only,
		"gold_pp": gold_pp, "gold_compound": compound,
		"elite_second": elite_second,
		"mythic": mythic.duplicate(),
		"mythic_post_delta": post_delta, "mythic_post_mode": post_mode,
	}


static func has_id(id: String) -> bool:
	return not by_id(id).is_empty() or id == NONE_ID


static func by_id(id: String) -> Dictionary:
	if id.is_empty() or id == NONE_ID:
		return {"id": NONE_ID}
	for row: Dictionary in catalog():
		if str(row["id"]) == id:
			return row.duplicate(true)
	return {}


static func shipping() -> Dictionary:
	return by_id(SHIPPING_ID)


static func reset(rewards: RewardRules) -> void:
	rewards.rarity_shift = 0.0
	rewards.rarity_uncommon_only = false
	rewards.gold_vow_mult = 1.0
	rewards.elite_relic_second = 0.0


static func apply(rewards: RewardRules, mix: Dictionary, vow: int) -> void:
	reset(rewards)
	if mix.is_empty() or str(mix.get("id", "")) == NONE_ID:
		return
	var steps: int = 0
	if vow >= 2:
		steps = 2
	elif vow >= 1:
		steps = 1
	rewards.rarity_shift = float(str(mix.get("rarity_pp", 0))) * float(steps)
	rewards.rarity_uncommon_only = mix.get("rarity_uncommon_only", false) == true
	var gold_pp: float = float(str(mix.get("gold_pp", 0)))
	if mix.get("gold_compound", false) == true:
		rewards.gold_vow_mult = pow(1.0 + gold_pp, float(vow))
	else:
		rewards.gold_vow_mult = 1.0 + gold_pp * float(vow)
	rewards.elite_relic_second = float(str(mix.get("elite_second", 0))) if vow >= 4 else 0.0


static func mythic_rate(mix: Dictionary, vow: int, post_act4: bool) -> float:
	if mix.is_empty():
		return 0.0
	var rates_v: Variant = mix.get("mythic", [])
	if typeof(rates_v) != TYPE_ARRAY:
		return 0.0
	var rates: Array = rates_v
	var idx: int = clampi(vow, 0, maxi(0, rates.size() - 1))
	var rate: float = float(str(rates[idx])) if idx < rates.size() else 0.0
	if not post_act4:
		return rate
	var delta: float = float(str(mix.get("mythic_post_delta", 0)))
	if str(mix.get("mythic_post_mode", "stack")) == "replace":
		return delta
	return rate + delta


static func p_mythic(mix: Dictionary, vow: int, elites: float, post_act4: bool) -> float:
	var rate: float = mythic_rate(mix, vow, post_act4)
	if rate <= 0.0 or elites <= 0.0:
		return 0.0
	return 1.0 - pow(1.0 - rate, elites)


static func isolate(content: ContentDB, name: String) -> Dictionary:
	var spec: Dictionary = {
		"iron": {"vow": 1, "index": 0, "mods": {"hpMult": 1.12}, "strip_hex": false},
		"malice": {"vow": 2, "index": 1, "mods": {"enemyDmgBonus": 1}, "strip_hex": false},
		"deep": {"vow": 3, "index": 2, "mods": {"bossFacetDelta": 1}, "strip_hex": false},
		"mark": {"vow": 4, "index": 3, "mods": {"startHex": true}, "strip_hex": false},
		"waning": {"vow": 5, "index": 4, "mods": {"restHealFrac": 0.2}, "strip_hex": true},
		"deadhex": {"vow": 1, "index": 0, "mods": {"startHex": true}, "strip_hex": false},
		"empty1": {"vow": 1, "index": -1, "mods": {}, "strip_hex": false},
	}
	if not spec.has(name):
		return {"error": "unknown isolate %s" % name}
	var vows: Array = []
	for row_v: Variant in content.vows:
		var row: Dictionary = row_v
		var copy: Dictionary = row.duplicate(true)
		copy["mods"] = {}
		vows.append(copy)
	content.vows = vows
	var chosen: Dictionary = spec[name]
	var index: int = int(float(str(chosen["index"])))
	if index >= 0:
		var vow_row: Dictionary = content.vows[index]
		var mods_v: Variant = chosen["mods"]
		var mods: Dictionary = mods_v
		vow_row["mods"] = mods.duplicate(true)
	return chosen
