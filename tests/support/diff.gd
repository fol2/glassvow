extends RefCounted
## Deep structural equality for fixture / event Dictionary compares.
## Returns "" on match, else the first divergent JSON-pointer-style path.


static func deep_eq(a: Variant, b: Variant, path: String = "$") -> String:
	var ta: int = typeof(a)
	var tb: int = typeof(b)
	if ta != tb:
		return path
	match ta:
		TYPE_DICTIONARY:
			var da: Dictionary = a
			var db: Dictionary = b
			if da.size() != db.size():
				return path
			for key: Variant in da.keys():
				if not db.has(key):
					return path + "." + str(key)
				var child: String = deep_eq(da[key], db[key], path + "." + str(key))
				if child != "":
					return child
			for key: Variant in db.keys():
				if not da.has(key):
					return path + "." + str(key)
			return ""
		TYPE_ARRAY:
			var aa: Array = a
			var ab: Array = b
			if aa.size() != ab.size():
				return path
			for i: int in range(aa.size()):
				var child: String = deep_eq(aa[i], ab[i], path + "[%d]" % i)
				if child != "":
					return child
			return ""
		TYPE_FLOAT:
			if a != b:
				return path
			return ""
		_:
			if a != b:
				return path
			return ""
