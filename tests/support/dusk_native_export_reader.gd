class_name DuskNativeExportReader
extends RefCounted
## Narrow N0 native capture/reader toward H D547-NATIVE-EXPORT-2.
## Resolves pointers against captured bytes. Does not edit H or claim
## 2048-run qualification.


static func _ji(v: Variant) -> int:
	return int(float(str(v)))


static func bind_capture(
	events: Array,
	pre_hp: Dictionary,
	identity: Dictionary
) -> Dictionary:
	var frozen: Array = []
	for ev_v: Variant in events:
		var ev: Dictionary = ev_v
		frozen.append(ev.duplicate(true))
	var pre: Dictionary = pre_hp.duplicate(true)
	var ident: Dictionary = identity.duplicate(true)
	var payload: Dictionary = {
		"identity": ident,
		"pre_hp": pre,
		"events": frozen,
	}
	return {
		"identity": ident,
		"pre_hp": pre,
		"events": frozen,
		"bytes": JSON.stringify(payload),
		"role": str(ident.get("role", "native_export/N0/v0")),
	}


static func resolve(pointer: Dictionary, capture: Dictionary) -> Variant:
	if str(pointer.get("role", "")) != str(capture.get("role", "")):
		return null
	var path: Array = pointer.get("path", [])
	var node: Variant = capture
	for step_v: Variant in path:
		var step: String = str(step_v)
		if typeof(node) == TYPE_DICTIONARY:
			var d: Dictionary = node
			if not d.has(step):
				return null
			node = d[step]
		elif typeof(node) == TYPE_ARRAY:
			var arr: Array = node
			if not step.is_valid_int():
				return null
			var idx: int = int(step)
			if idx < 0 or idx >= arr.size():
				return null
			node = arr[idx]
		else:
			return null
	return node


static func hit_observations(capture: Dictionary) -> Variant:
	if not capture.has("events") or not capture.has("pre_hp"):
		return null
	if typeof(capture["pre_hp"]) != TYPE_DICTIONARY:
		return null
	var events: Array = capture["events"]
	var hp: Dictionary = capture["pre_hp"]
	hp = hp.duplicate()
	var out: Array = []
	var seq: int = 0
	for i: int in range(events.size()):
		var ev: Dictionary = events[i]
		if str(ev.get("t", "")) != "hitEnemy":
			continue
		if not ev.has("idx") or not ev.has("amount") or not ev.has("hpAfter") or not ev.has("overkill"):
			return null
		var idx: int = _ji(ev["idx"])
		if not hp.has(idx):
			return null
		var hp_after: int = _ji(ev["hpAfter"])
		var before: int = _ji(hp[idx])
		var physical: int = maxi(0, before - hp_after)
		hp[idx] = hp_after
		var ptr: Dictionary = {
			"role": str(capture.get("role", "")),
			"path": ["events", i],
		}
		if resolve(ptr, capture) == null:
			return null
		out.append({
			"seq": seq,
			"idx": idx,
			"amount": _ji(ev["amount"]),
			"blocked": _ji(ev.get("blocked", 0)),
			"hpAfter": hp_after,
			"overkill": _ji(ev["overkill"]),
			"dead": ev.get("dead", false) == true,
			"physicalHpLoss": physical,
			"pointer": ptr,
		})
		seq += 1
	return out


static func play_observations(capture: Dictionary) -> Array:
	var out: Array = []
	var events: Array = capture.get("events", [])
	var seq: int = 0
	for i: int in range(events.size()):
		var ev: Dictionary = events[i]
		if str(ev.get("t", "")) != "play":
			continue
		var ptr: Dictionary = {
			"role": str(capture.get("role", "")),
			"path": ["events", i],
		}
		out.append({
			"seq": seq,
			"uid": _ji(ev.get("uid", -1)),
			"id": str(ev.get("id", "")),
			"targetIdx": ev.get("targetIdx"),
			"pointer": ptr,
			"resolved": resolve(ptr, capture) != null,
		})
		seq += 1
	return out


static func chip_order(events: Array) -> Array:
	var out: Array = []
	for ev_v: Variant in events:
		var ev: Dictionary = ev_v
		if str(ev.get("t", "")) == "chip":
			out.append({"idx": _ji(ev.get("idx", -1)), "n": _ji(ev.get("n", 0))})
	return out


## True iff the first `expected_hits` HIT_ENEMY events all precede the first CHIP.
## Extra HIT_ENEMY after settlement (Bell/collateral) is allowed.
## [hit, chip, hit, chip] with expected_hits=2 is false.
static func ordinary_hits_precede_first_chip(events: Array, expected_hits: int) -> bool:
	if expected_hits < 0:
		return false
	var hits_before: int = 0
	var saw_chip: bool = false
	for ev_v: Variant in events:
		var ev: Dictionary = ev_v
		var t: String = str(ev.get("t", ""))
		if t == "chip":
			saw_chip = true
			break
		if t == "hitEnemy":
			hits_before += 1
	if not saw_chip:
		return hits_before == expected_hits
	return hits_before == expected_hits


static func pre_hp_map(cb: CombatState) -> Dictionary:
	var out: Dictionary = {}
	for e: EnemyCombatant in cb.enemies:
		out[e.idx] = e.hp
	return out
