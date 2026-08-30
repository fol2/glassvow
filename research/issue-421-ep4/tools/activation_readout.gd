class_name EP4ActivationReadout
extends RefCounted
## Observation-only package activation readout for #421 EP4.


static func observe(events: Array, content: ContentDB) -> Dictionary:
	var counts: Dictionary = {}
	var last_card: String = ""
	var hand_sources: Dictionary = {}
	var ward_sources: Dictionary = {}
	var poison_sources: Dictionary = {}
	for event_v: Variant in events:
		if typeof(event_v) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_v
		var kind: String = str(event.get("t", ""))
		if kind == "turn" or kind == "endTurn" or kind == "enemyAct":
			last_card = ""
			hand_sources.clear()
			ward_sources.clear()
			continue
		if kind == "art" or kind == "potion":
			last_card = ""
			continue
		if kind == "play":
			last_card = str(event.get("id", ""))
			if last_card == "phantomBlades" and not hand_sources.is_empty():
				_bump(counts, "handSizePayoffActivations")
				for source_v: Variant in hand_sources:
					_bump(counts, "handSizePayoffFrom%s" % _title(str(source_v)))
			continue
		if kind == "draw" and last_card in ["preparation", "surge"]:
			hand_sources[last_card] = true
			continue
		if kind == "blockGain" and str(event.get("who", "")) == "player" \
				and int(float(str(event.get("n", 0)))) > 0:
			if last_card in ["brace", "mirrorEdge"]:
				ward_sources[last_card] = true
			elif last_card == "fortify" and not ward_sources.is_empty():
				_bump(counts, "wardMirrorEdgeActivations")
				for source_v: Variant in ward_sources:
					_bump(counts, "wardMirrorEdgeFrom%s" % _title(str(source_v)))
			continue
		if kind == "status" and str(event.get("id", "")) == "poison" \
				and int(float(str(event.get("n", 0)))) > 0 \
				and str(event.get("who", "")) != "player":
			_bump(counts, "enemySmolderApplications")
			var target: String = str(event.get("who", ""))
			if last_card in ["venomStrike", "toxicMist"]:
				if not poison_sources.has(target):
					poison_sources[target] = {}
				var target_sources: Dictionary = poison_sources[target]
				target_sources[last_card] = true
			elif last_card == "catalyst" and poison_sources.has(target):
				var catalyst_sources: Dictionary = poison_sources[target]
				_bump(counts, "ashPoisonCatalystActivations")
				for source_v: Variant in catalyst_sources:
					_bump(counts, "ashPoisonCatalystFrom%s" % _title(str(source_v)))
			continue
		if kind == "shatter":
			_bump(counts, "allShatters")
			if _is_attack(content, last_card):
				_bump(counts, "directShatterActivations")
	return counts


static func _is_attack(content: ContentDB, card_id: String) -> bool:
	if card_id.is_empty():
		return false
	var card_v: Variant = content.cards.get(card_id)
	if typeof(card_v) != TYPE_DICTIONARY:
		return false
	var card: Dictionary = card_v
	return str(card.get("type", "")) == "attack"


static func _bump(counts: Dictionary, key: String) -> void:
	counts[key] = int(float(str(counts.get(key, 0)))) + 1


static func _title(value: String) -> String:
	return value.left(1).to_upper() + value.substr(1)
