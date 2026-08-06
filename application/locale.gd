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
