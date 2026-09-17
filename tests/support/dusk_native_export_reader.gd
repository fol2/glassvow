class_name DuskNativeExportReader
extends RefCounted
## Narrow N0 native capture/reader toward H D547-NATIVE-EXPORT-2.
## Serialized `bytes` are the sole resolution/observation root. Companion
## dictionaries, if retained, must match the decoded payload or the capture
## is rejected. Does not edit H or claim 2048-run qualification.


static func _ji(v: Variant) -> int:
	return int(float(str(v)))


static func digest_bytes(bytes: String) -> String:
	return bytes.sha256_text()


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
	var role: String = str(ident.get("role", "native_export/N0/v0"))
	if not ident.has("role"):
		ident["role"] = role
	var serial_events: Array = []
	for ev: Dictionary in frozen:
		var row: Dictionary = ev.duplicate(true)
		if row.has("t"):
			row["t"] = str(row["t"])
		serial_events.append(row)
	var serial_pre: Dictionary = {}
	for k: Variant in pre.keys():
		serial_pre[str(_ji(k))] = _ji(pre[k])
	var payload: Dictionary = {
		"role": role,
		"identity": ident,
		"pre_hp": serial_pre,
		"events": serial_events,
	}
	var bytes: String = JSON.stringify(payload)
	return {
		"identity": ident.duplicate(true),
		"pre_hp": pre.duplicate(true),
		"events": frozen.duplicate(true),
		"role": role,
		"bytes": bytes,
		"digest": digest_bytes(bytes),
	}


static func decoded_payload(capture: Dictionary) -> Variant:
	if not capture.has("bytes") or typeof(capture["bytes"]) != TYPE_STRING:
		return null
	var bytes: String = str(capture["bytes"])
	if bytes.is_empty():
		return null
	if capture.has("digest") and str(capture["digest"]) != digest_bytes(bytes):
		return null
	var parsed: Variant = JSON.parse_string(bytes)
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	var payload: Dictionary = _normalize_payload(parsed)
	if not payload.has("events") or not payload.has("pre_hp") or not payload.has("identity"):
		return null
	if _companions_present(capture) and not _companions_match(capture, payload):
		return null
	return payload


static func resolve(pointer: Dictionary, capture: Dictionary) -> Variant:
	var root_v: Variant = decoded_payload(capture)
	if typeof(root_v) != TYPE_DICTIONARY:
		return null
	var payload: Dictionary = root_v
	var role: String = str(payload.get("role", ""))
	if str(pointer.get("role", "")) != role:
		return null
	var path: Array = pointer.get("path", [])
	var node: Variant = payload
	for step_v: Variant in path:
		var step: String = str(step_v)
		if typeof(node) == TYPE_DICTIONARY:
			var d: Dictionary = node
			if not d.has(step):
				# JSON object keys are strings; integer event idx stays numeric in path.
				if not step.is_valid_int() or not d.has(_ji(step)):
					return null
				node = d[_ji(step)]
			else:
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
	var root_v: Variant = decoded_payload(capture)
	if typeof(root_v) != TYPE_DICTIONARY:
		return null
	var payload: Dictionary = root_v
	if typeof(payload["pre_hp"]) != TYPE_DICTIONARY:
		return null
	if typeof(payload["events"]) != TYPE_ARRAY:
		return null
	var events: Array = payload["events"]
	var hp: Dictionary = payload["pre_hp"].duplicate()
	var out: Array = []
	var seq: int = 0
	var role: String = str(payload.get("role", ""))
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
			"role": role,
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
	var root_v: Variant = decoded_payload(capture)
	if typeof(root_v) != TYPE_DICTIONARY:
		return []
	var payload: Dictionary = root_v
	if typeof(payload["events"]) != TYPE_ARRAY:
		return []
	var events: Array = payload["events"]
	var role: String = str(payload.get("role", ""))
	var out: Array = []
	var seq: int = 0
	for i: int in range(events.size()):
		var ev: Dictionary = events[i]
		if str(ev.get("t", "")) != "play":
			continue
		var ptr: Dictionary = {
			"role": role,
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


static func _companions_present(capture: Dictionary) -> bool:
	return capture.has("events") or capture.has("pre_hp") or capture.has("identity") \
		or capture.has("role")


static func _companions_match(capture: Dictionary, payload: Dictionary) -> bool:
	var companion: Dictionary = {
		"role": str(capture.get("role", payload.get("role", ""))),
		"identity": capture.get("identity", payload.get("identity", {})),
		"pre_hp": capture.get("pre_hp", payload.get("pre_hp", {})),
		"events": capture.get("events", payload.get("events", [])),
	}
	return _same(_normalize_payload(companion), payload)


static func _normalize_payload(raw_v: Variant) -> Dictionary:
	if typeof(raw_v) != TYPE_DICTIONARY:
		return {}
	var raw: Dictionary = raw_v
	var ident_v: Variant = raw.get("identity", {})
	if typeof(ident_v) != TYPE_DICTIONARY:
		return {}
	var ident: Dictionary = ident_v
	var role: String = str(raw.get("role", ident.get("role", "")))
	if role.is_empty():
		return {}
	var pre_v: Variant = raw.get("pre_hp", {})
	var pre_out: Dictionary = {}
	if typeof(pre_v) == TYPE_DICTIONARY:
		var pre: Dictionary = pre_v
		for k: Variant in pre.keys():
			pre_out[_ji(k)] = _ji(pre[k])
	var events_v: Variant = raw.get("events", [])
	var events_out: Array = []
	if typeof(events_v) == TYPE_ARRAY:
		for ev_v: Variant in events_v:
			if typeof(ev_v) != TYPE_DICTIONARY:
				continue
			var ev: Dictionary = ev_v
			ev = ev.duplicate(true)
			if ev.has("t"):
				ev["t"] = str(ev["t"])
			events_out.append(ev)
	return {
		"role": role,
		"identity": ident.duplicate(true),
		"pre_hp": pre_out,
		"events": events_out,
	}


static func _same(a: Variant, b: Variant) -> bool:
	if typeof(a) == TYPE_INT or typeof(a) == TYPE_FLOAT:
		if typeof(b) != TYPE_INT and typeof(b) != TYPE_FLOAT:
			return false
		return _ji(a) == _ji(b)
	if typeof(a) == TYPE_STRING_NAME or typeof(b) == TYPE_STRING_NAME \
			or typeof(a) == TYPE_STRING or typeof(b) == TYPE_STRING:
		return str(a) == str(b)
	if typeof(a) != typeof(b):
		return false
	match typeof(a):
		TYPE_DICTIONARY:
			var da: Dictionary = a
			var db: Dictionary = b
			if da.size() != db.size():
				return false
			for k: Variant in da.keys():
				if not db.has(k):
					return false
				if not _same(da[k], db[k]):
					return false
			return true
		TYPE_ARRAY:
			var aa: Array = a
			var ab: Array = b
			if aa.size() != ab.size():
				return false
			for i: int in range(aa.size()):
				if not _same(aa[i], ab[i]):
					return false
			return true
		_:
			return a == b
