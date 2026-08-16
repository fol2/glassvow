extends RefCounted
## Original-content overlay: capture-safe merge over the generated baseline.
## Ids introduced here are legitimate; mob-overrides stays strict; validate stays
## authoritative for missing AI arms.


static func run(fails: Array[String]) -> void:
	_manifest(fails)
	_capture_survives(fails)
	_merge_semantics(fails)
	_mob_override_strictness(fails)
	_validate_requires_ai(fails)


static func _manifest(fails: Array[String]) -> void:
	var text: String = FileAccess.get_file_as_string(ContentDB.ORIGINAL_PATH)
	var raw: Variant = JSON.parse_string(text)
	if typeof(raw) != TYPE_DICTIONARY:
		fails.append("original-content: manifest did not parse to a dictionary")
		return
	var root: Dictionary = raw
	if str(root.get("_note", "")).is_empty():
		fails.append("original-content: manifest is missing a _note")
	for key_v: Variant in root:
		var key: String = str(key_v)
		if key.begins_with("_"):
			continue
		if not ContentDB.ORIGINAL_CONTENT_KEYS.has(key):
			fails.append("original-content: unknown top-level key %s" % key)
	var from_file: ContentDB = ContentDB.load_full(false)
	var act_v: Variant = from_file.acts[2] if from_file.acts.size() > 2 else null
	if typeof(act_v) != TYPE_DICTIONARY:
		fails.append("original-content: acts[2] is not a dictionary after overlay")
	else:
		var act: Dictionary = act_v
		if str(act.get("name", "")) != "The Obsidian Court":
			fails.append("original-content: acts[2].name was not overlaid")
	var theme_v: Variant = from_file.themes.get("act3")
	if typeof(theme_v) != TYPE_DICTIONARY:
		fails.append("original-content: themes.act3 is not a dictionary after overlay")
	else:
		var theme: Dictionary = theme_v
		if str(theme.get("name", "")) != "The Obsidian Court":
			fails.append("original-content: themes.act3.name was not overlaid")
	var catalogue_v: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(ContentDB.FULL_PATH)
	)
	if typeof(catalogue_v) != TYPE_DICTIONARY:
		fails.append("original-content: full-content.json did not parse")
		return
	var catalogue: Dictionary = catalogue_v
	var baseline_acts_v: Variant = catalogue.get("acts", [])
	if typeof(baseline_acts_v) != TYPE_ARRAY:
		fails.append("original-content: full-content acts is not an array")
		return
	var baseline_acts: Array = baseline_acts_v
	if from_file.acts.size() != baseline_acts.size():
		fails.append("original-content: index-merge changed acts.size()")


static func _capture_survives(fails: Array[String]) -> void:
	var baseline_v: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(ContentDB.FULL_PATH)
	)
	var original_v: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(ContentDB.ORIGINAL_PATH)
	)
	if typeof(baseline_v) != TYPE_DICTIONARY or typeof(original_v) != TYPE_DICTIONARY:
		fails.append("original-content: capture fixture parse failed")
		return
	var baseline: Dictionary = baseline_v
	var original: Dictionary = original_v.duplicate(true)
	var authored_enemies: Dictionary = original.get("enemies", {})
	authored_enemies["captureGhost"] = _test_enemy("Capture Ghost")
	original["enemies"] = authored_enemies

	var polluted: Dictionary = baseline.duplicate(true)
	var polluted_enemies: Dictionary = polluted["enemies"]
	polluted_enemies["handTyped"] = _test_enemy("Hand Typed")
	polluted["enemies"] = polluted_enemies

	var pre: ContentDB = ContentDB.new()
	pre.apply_catalogue(polluted)
	pre.apply_original_content(original)
	if not pre.enemies.has("handTyped") or not pre.enemies.has("captureGhost"):
		fails.append("original-content: pre-capture catalogue missing expected ids")

	# Capture writes CORE_CONTENT wholesale over full-content.json
	# (tools/capture_full_content.mjs). Reload the generated baseline plus the
	# same original overlay: hand-typed baseline rows vanish, original ids stay.
	var post: ContentDB = ContentDB.new()
	post.apply_catalogue(baseline)
	post.apply_original_content(original)
	if post.enemies.has("handTyped"):
		fails.append("original-content: capture did not replace hand-typed baseline rows")
	if not post.enemies.has("captureGhost"):
		fails.append("original-content: capture destroyed original-content entries")
	if not post.enemies.has("duskfang"):
		fails.append("original-content: recaptured baseline lost duskfang")


static func _merge_semantics(fails: Array[String]) -> void:
	var db: ContentDB = ContentDB.load_full(false)
	var before_name: String = str(db.enemy(&"duskfang").get("name", ""))
	var act_n: int = db.acts.size()
	var encounter_n: int = db.encounters.size()
	var gold_n: int = db.reward_gold.size()
	db.apply_original_content({
		"enemies": {
			"glasswraith": _test_enemy("Glasswraith"),
			"duskfang": {"hp": [99, 100]},
		},
		"acts": [{"name": "The Last Stair", "boss": "glasswraith"}],
		"encounters": [{"boss": [["glasswraith"]]}],
		"rewardGold": [{"normal": [1, 2], "elite": [3, 4], "boss": [5, 6]}],
	})
	if db.enemy(&"glasswraith").is_empty():
		fails.append("original-content: new id did not appear in the DB")
	if db.enemy(&"duskfang").get("hp") != [99, 100]:
		fails.append("original-content: specified baseline field was not overlaid")
	if str(db.enemy(&"duskfang").get("name", "")) != before_name:
		fails.append("original-content: unspecified baseline field was dropped")
	var dusk_moves_v: Variant = db.enemy(&"duskfang").get("moves", {})
	if typeof(dusk_moves_v) != TYPE_DICTIONARY:
		fails.append("original-content: unspecified nested moves were dropped")
	else:
		var dusk_moves: Dictionary = dusk_moves_v
		if not dusk_moves.has("bite"):
			fails.append("original-content: unspecified nested moves were dropped")
	if db.acts.size() != act_n + 1 or db.encounters.size() != encounter_n + 1 \
			or db.reward_gold.size() != gold_n + 1:
		fails.append("original-content: act-level arrays did not append")
	var renamed: ContentDB = ContentDB.load_full(false)
	var renamed_n: int = renamed.acts.size()
	var first_act_v: Variant = renamed.acts[0] if renamed.acts.size() > 0 else null
	if typeof(first_act_v) != TYPE_DICTIONARY:
		fails.append("original-content: acts[0] is not a dictionary")
	else:
		var first_act: Dictionary = first_act_v
		var kept_boss: Variant = first_act.get("boss")
		renamed.apply_original_content({"acts": {"0": {"name": "Renamed Act"}}})
		if renamed.acts.size() != renamed_n:
			fails.append("original-content: dict-form acts merge changed size")
		var after_act_v: Variant = renamed.acts[0]
		if typeof(after_act_v) != TYPE_DICTIONARY:
			fails.append("original-content: dict-form acts[0] is not a dictionary")
		else:
			var after_act: Dictionary = after_act_v
			if str(after_act.get("name", "")) != "Renamed Act":
				fails.append("original-content: dict-form acts merge did not overlay name")
			if after_act.get("boss") != kept_boss:
				fails.append("original-content: dict-form acts merge dropped unspecified field")


static func _mob_override_strictness(fails: Array[String]) -> void:
	var db: ContentDB = ContentDB.load_full(false)
	db.apply_original_content({"enemies": {"glasswraith": _test_enemy("Glasswraith")}})
	var known: Dictionary = db.enemy(&"glasswraith").duplicate(true)
	known["hp"] = [11, 12]
	if not db.apply_enemy_overrides({"glasswraith": known}).is_empty() \
			or db.enemy(&"glasswraith").get("hp") != [11, 12]:
		fails.append("original-content: mob-overrides rejected an original-content id")
	var before: Dictionary = db.enemy(&"duskfang").duplicate(true)
	if db.apply_enemy_overrides({"notAMob": known}).is_empty():
		fails.append("original-content: mob-overrides accepted an id unknown to both layers")
	if db.enemy(&"duskfang") != before:
		fails.append("original-content: rejected mob-overrides mutated the catalogue")


static func _validate_requires_ai(fails: Array[String]) -> void:
	var db: ContentDB = ContentDB.load_full(false)
	db.apply_original_content({"enemies": {"noAiGhost": _test_enemy("No AI Ghost")}})
	var faults: Array[String] = []
	db.validate(faults)
	var found: bool = false
	for msg: String in faults:
		if msg.contains("noAiGhost") and msg.contains("no AI handler"):
			found = true
			break
	if not found:
		fails.append("original-content: override enemy without decide() arm passed validate")


static func _test_enemy(display_name: String) -> Dictionary:
	return {
		"hp": [8, 8],
		"name": display_name,
		"art": {"kind": "wisp", "hue": 0.0, "size": 1.0},
		"moves": {"wail": {"intent": "attack", "dmg": 1, "name": "Wail"}},
	}
