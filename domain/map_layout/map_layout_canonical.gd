class_name MapLayoutCanonical
extends RefCounted
## Canonical plain-data codec for Map Compiler v2 contracts.
## Dictionaries are key-sorted. Arrays retain semantic order. Finite floats use
## exact binary64 little-endian hex; only signed zero is normalised.

const CODEC_VERSION: String = "map-layout-canonical-v1"
const FLOAT_POLICY: String = "finite-binary64-little-endian-hex; signed-zero-normalised"


static func float_value(value: Variant) -> float:
	assert(typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT)
	@warning_ignore("unsafe_call_argument")
	return float(value)


static func int_value(value: Variant) -> int:
	assert(typeof(value) == TYPE_INT)
	@warning_ignore("unsafe_call_argument")
	return int(value)


static func bool_value(value: Variant) -> bool:
	assert(typeof(value) == TYPE_BOOL)
	@warning_ignore("unsafe_call_argument")
	return bool(value)


static func validate(value: Variant, path: String, errors: Array[String]) -> void:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			pass
		TYPE_FLOAT:
			if not is_finite(float_value(value)):
				errors.append("%s must be finite" % path)
		TYPE_ARRAY:
			var rows: Array = value
			for i: int in range(rows.size()):
				validate(rows[i], "%s[%d]" % [path, i], errors)
		TYPE_DICTIONARY:
			var row: Dictionary = value
			for key_v: Variant in row.keys():
				if typeof(key_v) != TYPE_STRING:
					errors.append("%s has a non-string key" % path)
					continue
				var key: String = key_v
				validate(row[key], "%s.%s" % [path, key], errors)
		_:
			errors.append("%s uses unsupported Variant type %d" % [path, typeof(value)])


static func fields(
	raw: Dictionary,
	required: PackedStringArray,
	optional: PackedStringArray,
	path: String,
	errors: Array[String]
) -> void:
	for key_v: Variant in raw.keys():
		if typeof(key_v) != TYPE_STRING:
			continue
		var key: String = key_v
		if not required.has(key) and not optional.has(key):
			errors.append("%s has unknown field %s" % [path, key])
	for key: String in required:
		if not raw.has(key):
			errors.append("%s is missing field %s" % [path, key])


static func nonempty(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and not str(value).is_empty()


static func sha256_text(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or str(value).length() != 64:
		return false
	var text: String = value
	for i: int in range(text.length()):
		var code: int = text.unicode_at(i)
		if not (code >= 48 and code <= 57) and not (code >= 97 and code <= 102):
			return false
	return true


static func vector(value: Variant, size: int, positive: bool = false) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	var parts: Array = value
	if parts.size() != size:
		return false
	for part: Variant in parts:
		if typeof(part) != TYPE_FLOAT and typeof(part) != TYPE_INT:
			return false
		var number: float = float_value(part)
		if not is_finite(number) or (positive and number <= 0.0):
			return false
	return true


static func same_vector(a_v: Variant, b_v: Variant, size: int) -> bool:
	if not vector(a_v, size) or not vector(b_v, size):
		return false
	var a: Array = a_v
	var b: Array = b_v
	for i: int in range(size):
		if float_value(a[i]) != float_value(b[i]):
			return false
	return true


static func number(value: Variant, positive: bool = false) -> bool:
	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		return false
	var parsed: float = float_value(value)
	return is_finite(parsed) and (not positive or parsed > 0.0)


static func sorted_keys(raw: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for key_v: Variant in raw.keys():
		out.append(str(key_v))
	out.sort()
	return out


static func ordered_dictionary(value: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: String in sorted_keys(value):
		out[key] = ordered(value[key])
	return out


static func ordered(value: Variant) -> Variant:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return value
		TYPE_FLOAT:
			var number_value: float = float_value(value)
			return 0.0 if number_value == 0.0 else number_value
		TYPE_ARRAY:
			var rows: Array = value
			var array_out: Array = []
			for row_v: Variant in rows:
				array_out.append(ordered(row_v))
			return array_out
		TYPE_DICTIONARY:
			var row: Dictionary = value
			return ordered_dictionary(row)
		_:
			return null


static func canonical_text(value: Variant) -> String:
	var errors: Array[String] = []
	validate(value, "value", errors)
	if not errors.is_empty():
		return ""
	return "%s|%s" % [CODEC_VERSION, _encode(value)]


static func canonical_bytes(value: Variant) -> PackedByteArray:
	return canonical_text(value).to_utf8_buffer()


static func digest(value: Variant) -> String:
	var bytes: PackedByteArray = canonical_bytes(value)
	if bytes.is_empty():
		return ""
	var context: HashingContext = HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(bytes) != OK:
		return ""
	return context.finish().hex_encode()


static func _encode(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return "n;"
		TYPE_BOOL:
			return "b1;" if bool_value(value) else "b0;"
		TYPE_INT:
			return "i%s;" % str(value)
		TYPE_FLOAT:
			var number_value: float = float_value(value)
			var bytes: PackedByteArray = PackedByteArray()
			bytes.resize(8)
			bytes.encode_double(0, 0.0 if number_value == 0.0 else number_value)
			return "f%s;" % bytes.hex_encode()
		TYPE_STRING:
			return _string(str(value))
		TYPE_ARRAY:
			var rows: Array = value
			var array_parts: Array[String] = []
			for row_v: Variant in rows:
				array_parts.append(_encode(row_v))
			return "a%d[%s]" % [rows.size(), "".join(array_parts)]
		TYPE_DICTIONARY:
			var row: Dictionary = value
			var dict_parts: Array[String] = []
			for key: String in sorted_keys(row):
				dict_parts.append(_string(key))
				dict_parts.append(_encode(row[key]))
			return "d%d{%s}" % [row.size(), "".join(dict_parts)]
		_:
			return ""


static func _string(value: String) -> String:
	return "s%d:%s;" % [value.to_utf8_buffer().size(), value]
