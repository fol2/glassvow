extends RefCounted
## Real-catalogue coverage and the display-only boundary for Locale hydration.


static func run(fails: Array[String]) -> void:
	_real_catalogue_census(fails)
	_hostile_tree_cannot_write_mechanics(fails)


## Count the source, not a production allowlist: every string actually authored
## under a live domain must land exactly once. Whispers have no ContentDB row.
static func _real_catalogue_census(fails: Array[String]) -> void:
	var file: FileAccess = FileAccess.open("res://locale/zh-Hant.json", FileAccess.READ)
	if file == null:
		fails.append("hydration census: cannot open the zh-Hant catalogue")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		fails.append("hydration census: zh-Hant is not a JSON object")
		return
	var root: Dictionary = parsed
	var content_v: Variant = root.get("content")
	if typeof(content_v) != TYPE_DICTIONARY:
		fails.append("hydration census: zh-Hant has no content object")
		return
	var tree: Dictionary = content_v
	var db: ContentDB = ContentDB.load_full()
	var domain_count: int = 0
	var leaf_total: int = 0
	var write_total: int = 0
	for domain_v: Variant in tree:
		var domain: String = str(domain_v)
		if domain == "whispers":
			continue
		domain_count += 1
		var expected: int = _string_leaf_count(tree[domain_v])
		var undo: Array = []
		var one_domain: Dictionary = {domain: tree[domain_v]}
		var written: int = Locale.overlay_content(db, one_domain, undo)
		leaf_total += expected
		write_total += written
		if written != expected:
			fails.append("hydration census: %s wrote %d of %d source leaves"
				% [domain, written, expected])
		_assert_unique_destinations(domain, undo, fails)
		_unwind(undo)
	if domain_count != 17:
		fails.append("hydration census: expected 17 live domains, got %d" % domain_count)
	if leaf_total != 674:
		fails.append("hydration census: real catalogue has %d, expected 674 live leaves" % leaf_total)
	if write_total != leaf_total:
		fails.append("hydration census: wrote %d of %d live leaves" % [write_total, leaf_total])


## A locale bundle is data at a trust boundary. Existing string slots are not
## enough authority: mechanics strings must stay untouched even if injected.
static func _hostile_tree_cannot_write_mechanics(fails: Array[String]) -> void:
	var db: ContentDB = ContentDB.load_full()
	var before: String = _mechanics_fingerprint(db)
	var hostile: Dictionary = {
		"cards": {
			"strike": {"target": "allEnemies", "type": "curse", "rarity": "rare", "textUp": null},
			"eclipseSlash": {"effects": [
				{"kind": "heal"},
				{"kind": "dmg", "who": "self", "id": "str"},
			]},
		},
		"variants": {"paleDuskfang": {"id": "hostile-id", "base": "hostile-base"}},
		"enemies": {"sporeling": {"moves": {"spit": {"intent": "heal"}}}},
	}
	var undo: Array = []
	var written: int = Locale.overlay_content(db, hostile, undo)
	if written != 0:
		fails.append("hydration display shield: hostile tree made %d mechanics writes" % written)
	if _mechanics_fingerprint(db) != before:
		fails.append("hydration display shield: live id/base/target/kind/who mechanics changed")
	if str(db.cards["strike"]["up"]["text"]) != "Deal @9@ damage.":
		fails.append("hydration display shield: null textUp was stringified into the live row")
	_assert_unique_destinations("hostile", undo, fails)
	_unwind(undo)
	if _mechanics_fingerprint(db) != before:
		fails.append("hydration display shield: hostile-tree unwind did not restore mechanics")


static func _string_leaf_count(value: Variant) -> int:
	if typeof(value) == TYPE_STRING:
		return 1
	var count: int = 0
	if typeof(value) == TYPE_DICTIONARY:
		var table: Dictionary = value
		for child: Variant in table.values():
			count += _string_leaf_count(child)
	elif typeof(value) == TYPE_ARRAY:
		var rows: Array = value
		for child: Variant in rows:
			count += _string_leaf_count(child)
	return count


static func _assert_unique_destinations(domain: String, undo: Array,
		fails: Array[String]) -> void:
	for i: int in range(undo.size()):
		var left: Array = undo[i]
		for j: int in range(i):
			var right: Array = undo[j]
			if is_same(left[0], right[0]) and left[1] == right[1]:
				fails.append("hydration census: %s wrote one destination twice" % domain)
				return


static func _mechanics_fingerprint(db: ContentDB) -> String:
	return JSON.stringify([
		db.cards["strike"].get("target"), db.cards["strike"].get("type"),
		db.cards["strike"].get("rarity"), db.cards["eclipseSlash"].get("effects"),
		db.variants["paleDuskfang"].get("id"), db.variants["paleDuskfang"].get("base"),
		db.enemies["sporeling"]["moves"]["spit"].get("intent"),
	])


static func _unwind(undo: Array) -> void:
	var locale: Locale = Locale.new()
	locale._overlaid = undo
	locale.restore_content()
