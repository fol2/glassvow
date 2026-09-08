extends RefCounted
## Preserve the complete old diagnostic contract while avoiding valid-path strings.
const F = preload("res://domain/map_layout/map_layout_canonical.gd")
static func run(fails: Array[String]) -> void:
	var cases: Array = [null,true,42,"琉璃",-.0,INF,NAN,Vector3.ONE,PackedByteArray([1]),
		{"a":[1,2.5,"valid"],"b":{}},{1:INF,"good":[NAN,Vector2.ZERO]},[INF,NAN,{"x":INF}]]
	for i: int in range(5):
		cases.append({"nested":[cases.duplicate(true)]})
	for value: Variant in cases:
		var actual: Array[String] = ["existing"]
		var expected: Array[String] = ["existing"]
		F.validate(value,"root",actual)
		_reference(value,"root",expected)
		if actual!=expected: fails.append("canonical validation: detailed errors changed")
	var fixture: Dictionary = {"z":-.0,"a":[1,"琉璃",true]}
	if F.canonical_text(fixture)!=F.canonical_text({"a":[1,"琉璃",true],"z":0.0}):
		fails.append("canonical validation: ordering or negative-zero identity changed")

static func _reference(value: Variant, path: String, errors: Array[String]) -> void:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			pass
		TYPE_FLOAT:
			if not is_finite(F.float_value(value)): errors.append("%s must be finite"%path)
		TYPE_ARRAY:
			var rows: Array = value
			for i: int in range(rows.size()): _reference(rows[i],"%s[%d]"%[path,i],errors)
		TYPE_DICTIONARY:
			var row: Dictionary = value
			for key: Variant in row.keys():
				if typeof(key)!=TYPE_STRING:
					errors.append("%s has a non-string key"%path)
					continue
				_reference(row[key],"%s.%s"%[path,key],errors)
		_:
			errors.append("%s uses unsupported Variant type %d"%[path,typeof(value)])
