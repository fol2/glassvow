class_name DuskNativeExportReader
extends RefCounted
## Narrow native snapshot/event reader toward H D547-NATIVE-EXPORT-2.
## Observes real GlassvowGame.apply queues. Does not rewrite H or invent
## trajectories. Pointers keep the bound shape: role + path.


static func _ji(v: Variant) -> int:
	return int(float(str(v)))


static func pointer(path: Array) -> Dictionary:
	return {"role": "native_export/A/v0", "path": path}


## Ordered HIT_ENEMY observations with physical HP vs reported amount/overkill.
static func hit_observations(events: Array, pre_hp: Dictionary) -> Array:
	var out: Array = []
	var hp: Dictionary = pre_hp.duplicate()
	var seq: int = 0
	for ev_v: Variant in events:
		var ev: Dictionary = ev_v
		if str(ev.get("t", "")) != "hitEnemy":
			continue
		var idx: int = _ji(ev.get("idx", -1))
		var amount: int = _ji(ev.get("amount", 0))
		var blocked: int = _ji(ev.get("blocked", 0))
		var hp_after: int = _ji(ev.get("hpAfter", 0))
		var overkill: int = _ji(ev.get("overkill", 0))
		var before: int = _ji(hp.get(idx, hp_after + amount))
		var physical: int = maxi(0, before - hp_after)
		hp[idx] = hp_after
		out.append({
			"seq": seq,
			"idx": idx,
			"amount": amount,
			"blocked": blocked,
			"hpAfter": hp_after,
			"overkill": overkill,
			"dead": ev.get("dead", false) == true,
			"physicalHpLoss": physical,
			"pointer": pointer(["events", "hitEnemy", seq]),
		})
		seq += 1
	return out


static func play_observations(events: Array) -> Array:
	var out: Array = []
	var seq: int = 0
	for ev_v: Variant in events:
		var ev: Dictionary = ev_v
		if str(ev.get("t", "")) != "play":
			continue
		out.append({
			"seq": seq,
			"uid": _ji(ev.get("uid", -1)),
			"id": str(ev.get("id", "")),
			"targetIdx": ev.get("targetIdx"),
			"pointer": pointer(["events", "play", seq]),
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


static func first_hit_index_before_chips(events: Array) -> int:
	var hit_i: int = -1
	var chip_i: int = -1
	for i: int in range(events.size()):
		var ev: Dictionary = events[i]
		var t: String = str(ev.get("t", ""))
		if t == "hitEnemy" and hit_i < 0:
			hit_i = i
		if t == "chip" and chip_i < 0:
			chip_i = i
	if hit_i < 0 or chip_i < 0:
		return -1
	return 1 if hit_i < chip_i else 0


static func pre_hp_map(cb: CombatState) -> Dictionary:
	var out: Dictionary = {}
	for e: EnemyCombatant in cb.enemies:
		out[e.idx] = e.hp
	return out
