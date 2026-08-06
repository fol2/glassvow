class_name Locale
extends RefCounted
## Player-facing string catalogue — UI chrome (`ui.*`) and content display
## fields (`content.*`). `active` is the main-owned handle (SKILL §2: no
## autoloads). Main replaces it with a disk-backed instance at boot; the
## default is an in-memory English catalogue so labs and tests that never
## boot main still resolve keys.
##
## Fallback chain (never crash, never blank): requested language → en → the
## key itself. Interpolation uses `{param}` markers; rules-text `@n@` / `#n#`
## markers are content payload and pass through untouched.
##
## See docs/p7-locale-design.md for the generator boundary and key scheme.

const EN_PATH: String = "res://locale/en.json"
const CODE_EN: StringName = &"en"
const CODE_ZH_HANT: StringName = &"zh-Hant"

static var active: Locale = Locale.new()

var code: StringName = CODE_EN
var _requested: Dictionary = {}
var _fallback_en: Dictionary = {}
## Undo log for `hydrate_content`: [container, key, previous] per overlaid slot.
var _overlaid: Array = []


func _init(language: StringName = CODE_EN, en_path: String = EN_PATH) -> void:
	_fallback_en = _read_bundle(en_path)
	if not set_language(language):
		code = CODE_EN
		_requested = _fallback_en


## Swap the active catalogue. Unknown codes (or a missing file) leave the
## previous catalogue in place and return false.
func set_language(language: StringName) -> bool:
	if language == CODE_EN:
		code = CODE_EN
		_requested = _fallback_en
		return true
	var path: String = "res://locale/%s.json" % String(language)
	if not FileAccess.file_exists(path):
		return false
	var bundle: Dictionary = _read_bundle(path)
	if bundle.is_empty() and language != CODE_EN:
		return false
	code = language
	_requested = bundle
	return true


## Resolve a dotted key. Optional `params` substitutes `{name}`-style markers.
func t(key: String, params: Dictionary = {}) -> String:
	var text: Variant = _lookup(key)
	if typeof(text) != TYPE_STRING:
		return key
	var out: String = str(text)
	if params.is_empty():
		return out
	for param_key: Variant in params:
		out = out.replace("{%s}" % str(param_key), str(params[param_key]))
	return out


## Content display field: `content.<domain>.<id>.<field>`.
func content(domain: String, id: String, field: String = "name") -> String:
	return t("content.%s.%s.%s" % [domain, id, field])


## Whisper line by stable index (whispers are a plain array — no IDs).
func whisper(index: int) -> String:
	return t("content.whispers.%d" % index)


## Overlay the active language's `content.*` display strings onto the live
## `ContentDB` rows the presentation already reads (docs/p7-locale-design.md §3,
## mirroring web `hydrateContent`). Call at boot and after every
## `set_language`; returns the number of strings written.
##
## English is the bake — `content/full-content.json` is the English catalogue
## *and* the balance source of record, so hydrating `en` restores rather than
## copies (`locale/en.json` is seeded from the pre-P6 web fixture and can drift
## from a rebalanced row's text). Every write is logged, so switching back
## restores the bake exactly, and a key the catalogue omits is simply never
## written — it keeps its English text instead of the key literal `t` returns.
func hydrate_content(db: ContentDB) -> int:
	restore_content()
	if code == CODE_EN:
		return 0
	var content_v: Variant = _requested.get("content", {})
	if typeof(content_v) != TYPE_DICTIONARY:
		return 0
	var tree: Dictionary = content_v
	return overlay_content(db, tree, _overlaid)


## Put every overlaid slot back to its baked value and forget the log.
func restore_content() -> void:
	for i: int in range(_overlaid.size() - 1, -1, -1):
		var entry: Array = _overlaid[i]
		var container: Variant = entry[0]
		if typeof(container) == TYPE_DICTIONARY:
			var table: Dictionary = container
			table[entry[1]] = entry[2]
		elif typeof(container) == TYPE_ARRAY:
			var list: Array = container
			list[str(entry[1]).to_int()] = entry[2]
	_overlaid.clear()


## Catalogue domain → the `ContentDB` registry that holds its rows. `whispers`
## has no registry (`ContentDB` never loads it) and is read through `whisper()`.
static func _content_targets(db: ContentDB) -> Dictionary:
	return {
		"acts": db.acts, "affixes": db.affixes, "arts": db.arts, "aspects": db.aspects,
		"boons": db.boons, "cards": db.cards, "deeds": db.deeds, "enemies": db.enemies,
		"events": db.events, "omens": db.omens, "potions": db.potions, "quests": db.quests,
		"relics": db.relics, "shadeKits": db.shade_kits, "status": db.statuses,
		"variants": db.variants, "vows": db.vows,
	}


## Copy `tree` (a `content.*` subtree) onto `db`'s display fields, appending
## [container, key, previous] to `undo` for each write. Rows and fields the
## catalogue does not author, or that the bake does not carry, are skipped —
## never invented. IDs are keys here, never values: nothing renames a row.
static func overlay_content(db: ContentDB, tree: Dictionary, undo: Array) -> int:
	var written: int = 0
	var targets: Dictionary = _content_targets(db)
	for domain_v: Variant in tree:
		var domain: String = str(domain_v)
		if not targets.has(domain):
			continue
		var rows_v: Variant = tree[domain_v]
		if typeof(rows_v) != TYPE_DICTIONARY:
			continue
		var rows: Dictionary = rows_v
		for id_v: Variant in rows:
			var src_v: Variant = rows[id_v]
			if typeof(src_v) != TYPE_DICTIONARY:
				continue
			var src: Dictionary = src_v
			var row: Variant = _child(targets[domain], str(id_v))
			if row == null:
				continue
			written += _overlay_row(domain, src, row, undo)
	return written


## Two catalogue shapes do not mirror the bake: a card's upgraded text is the
## flat key `textUp` (bake: `up.text`), and event roll outcomes are keyed by
## roll id (bake: nested in `choices[].ops[].roll[]`). Everything else lines up.
static func _overlay_row(domain: String, src: Dictionary, row: Variant, undo: Array) -> int:
	var written: int = 0
	var rest: Dictionary = src
	if domain == "cards" and src.has("textUp"):
		rest = src.duplicate()
		var up: Variant = _child(row, "up")
		if typeof(up) == TYPE_DICTIONARY:
			written += _write(up, "text", str(rest["textUp"]), undo)
		rest.erase("textUp")
	elif domain == "events" and src.has("rolls"):
		rest = src.duplicate()
		written += _overlay_rolls(rest["rolls"], row, undo)
		rest.erase("rolls")
	return written + _overlay_node(rest, row, undo)


static func _overlay_rolls(rolls_v: Variant, row: Variant, undo: Array) -> int:
	if typeof(rolls_v) != TYPE_DICTIONARY or typeof(row) != TYPE_DICTIONARY:
		return 0
	var rolls: Dictionary = rolls_v
	var event_row: Dictionary = row
	var written: int = 0
	for choice_v: Variant in _rows(event_row.get("choices")):
		for op_v: Variant in _rows(_child(choice_v, "ops")):
			for outcome_v: Variant in _rows(_child(op_v, "roll")):
				if typeof(outcome_v) != TYPE_DICTIONARY:
					continue
				var outcome: Dictionary = outcome_v
				var outcome_src: Variant = rolls.get(str(outcome.get("id", "")))
				if typeof(outcome_src) == TYPE_DICTIONARY:
					var fields: Dictionary = outcome_src
					written += _overlay_node(fields, outcome, undo)
	return written


## Walk a catalogue node against the matching bake node. Strings are written,
## dictionaries recurse, arrays of strings copy by index (quest echoes, variant
## dialogue).
static func _overlay_node(src: Dictionary, dst: Variant, undo: Array) -> int:
	var written: int = 0
	for key_v: Variant in src:
		var key: String = str(key_v)
		var value: Variant = src[key_v]
		var kind: int = typeof(value)
		if kind == TYPE_STRING:
			written += _write(dst, key, str(value), undo)
			continue
		var child: Variant = _child(dst, key)
		if kind == TYPE_DICTIONARY and child != null:
			var sub: Dictionary = value
			written += _overlay_node(sub, child, undo)
		elif kind == TYPE_ARRAY and typeof(child) == TYPE_ARRAY:
			var lines: Array = value
			for i: int in range(lines.size()):
				if typeof(lines[i]) == TYPE_STRING:
					written += _write(child, str(i), str(lines[i]), undo)
	return written


## Assign only over an existing string slot, logging the previous value.
static func _write(dst: Variant, key: String, value: String, undo: Array) -> int:
	if typeof(dst) == TYPE_DICTIONARY:
		var table: Dictionary = dst
		if typeof(table.get(key)) != TYPE_STRING:
			return 0
		undo.append([table, key, table[key]])
		table[key] = value
		return 1
	if typeof(dst) == TYPE_ARRAY and key.is_valid_int():
		var list: Array = dst
		var index: int = int(key)
		if index < 0 or index >= list.size() or typeof(list[index]) != TYPE_STRING:
			return 0
		undo.append([list, index, list[index]])
		list[index] = value
		return 1
	return 0


## Catalogue keys address bake rows three ways: dictionary key, array index
## (acts, vows, event choices), and row `id` (aspects, roll outcomes).
static func _child(node: Variant, key: String) -> Variant:
	if typeof(node) == TYPE_DICTIONARY:
		var table: Dictionary = node
		return table.get(key)
	if typeof(node) == TYPE_ARRAY:
		var list: Array = node
		if key.is_valid_int():
			var index: int = int(key)
			return list[index] if index >= 0 and index < list.size() else null
		for entry_v: Variant in list:
			if typeof(entry_v) == TYPE_DICTIONARY:
				var entry: Dictionary = entry_v
				if str(entry.get("id", "")) == key:
					return entry
	return null


static func _rows(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	var list: Array = value
	return list


func _lookup(key: String) -> Variant:
	var parts: PackedStringArray = key.split(".")
	var found: Variant = _dig(_requested, parts)
	if typeof(found) == TYPE_STRING:
		return found
	if code != CODE_EN:
		found = _dig(_fallback_en, parts)
		if typeof(found) == TYPE_STRING:
			return found
	return null


static func _dig(cur: Variant, parts: PackedStringArray) -> Variant:
	var node: Variant = cur
	for part: String in parts:
		if typeof(node) == TYPE_DICTIONARY:
			var table: Dictionary = node
			if not table.has(part):
				return null
			node = table[part]
		elif typeof(node) == TYPE_ARRAY:
			if not part.is_valid_int():
				return null
			var rows: Array = node
			var index: int = int(part)
			if index < 0 or index >= rows.size():
				return null
			node = rows[index]
		else:
			return null
	return node


static func _read_bundle(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var raw: String = FileAccess.get_file_as_string(path)
	if raw.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("locale: %s is not a JSON object" % path)
		return {}
	return parsed
