class_name BalanceCatalogue
extends RefCounted
## Shared candidate-catalogue loader and #454 seed-contract guard for balance CLIs.

const SEEDS_PATH: String = "res://docs/balance/421-content-search-seeds-v1.json"
const DEFAULT_SPACE: String = "res://docs/balance/421-content-search-space-v1.json"
const DRIVER: PackedStringArray = [
	"tools/balance_sim.gd", "tools/balance_sweep.gd", "tools/balance_cem.gd",
	"tools/balance_pilot.gd", "tools/balance_policy.gd", "tools/balance_catalogue.gd",
]


static func resolve_path(path: String) -> String:
	var trimmed: String = path.strip_edges()
	if trimmed.is_empty():
		return ContentDB.FULL_PATH
	if trimmed.begins_with("res://") or trimmed.begins_with("user://"):
		return trimmed
	if trimmed.is_absolute_path():
		return trimmed
	return ProjectSettings.globalize_path("res://").path_join(trimmed)


static func open(opts: Dictionary) -> Dictionary:
	var stage_fault: String = stage_error(opts)
	if not stage_fault.is_empty():
		return {"error": stage_fault}
	var content_path: String = resolve_path(str(opts.get("content", "")))
	var space_path: String = resolve_path(str(opts.get("space", DEFAULT_SPACE)))
	if not FileAccess.file_exists(content_path):
		return {"error": "missing content: %s" % content_path}
	var text: String = FileAccess.get_file_as_string(content_path)
	if text.strip_edges().is_empty():
		return {"error": "empty content: %s" % content_path}
	var raw: Variant = JSON.parse_string(text)
	if typeof(raw) != TYPE_DICTIONARY:
		return {"error": "invalid content JSON: %s" % content_path}
	var root: Dictionary = raw
	if typeof(root.get("cards", null)) != TYPE_DICTIONARY \
			or typeof(root.get("player", null)) != TYPE_DICTIONARY:
		return {"error": "content did not load a catalogue: %s" % content_path}
	if not FileAccess.file_exists(space_path):
		return {"error": "missing search space: %s" % space_path}
	var semantic: String = _semantic_sha(content_path)
	if semantic.length() != 64:
		return {"error": "cannot compute semantic content SHA for %s" % content_path}
	var git_out: Array = []
	OS.execute("git", ["rev-parse", "HEAD"], git_out)
	return {
		"path": content_path,
		"identity": {
			"contentPath": content_path,
			"contentFileSha256": FileAccess.get_sha256(content_path),
			"contentSemanticSha256": semantic,
			"searchSpacePath": space_path,
			"searchSpaceSha256": FileAccess.get_sha256(space_path),
			"driverSha256": _driver_sha(),
			"commit": str(git_out[0]).strip_edges() if not git_out.is_empty() else "unknown",
			"godot": Engine.get_version_info().get("string", "unknown"),
			"stage": str(opts.get("stage", "")),
		},
	}


static func load_prepared(prepared: Dictionary) -> ContentDB:
	return ContentDB.load_from(str(prepared.get("path", "")), false)


static func _semantic_sha(path: String) -> String:
	var fs_path: String = path
	if path.begins_with("res://") or path.begins_with("user://"):
		fs_path = ProjectSettings.globalize_path(path)
	var out: Array = []
	var code: String = "import json,hashlib,sys;p=sys.argv[1];print(hashlib.sha256(json.dumps(json.load(open(p,encoding='utf-8')),ensure_ascii=False,sort_keys=True,separators=(',',':')).encode()).hexdigest())"
	OS.execute("python3", ["-c", code, fs_path], out)
	return str(out[0]).strip_edges() if not out.is_empty() else ""


static func stage_error(opts: Dictionary) -> String:
	var stage: String = str(opts.get("stage", "")).strip_edges()
	if stage.is_empty():
		return ""
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SEEDS_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return "missing or invalid seed contract %s" % SEEDS_PATH
	var contract: Dictionary = parsed
	var stages_v: Variant = contract.get("stages", {})
	if typeof(stages_v) != TYPE_DICTIONARY:
		return "invalid seed contract stages"
	var stages: Dictionary = stages_v
	var spec_v: Variant = stages.get(stage, null)
	if typeof(spec_v) != TYPE_DICTIONARY:
		return "unknown --stage %s" % stage
	var spec: Dictionary = spec_v
	var sealed_until: String = str(spec.get("sealedUntil", "")).strip_edges()
	if not sealed_until.is_empty() and str(opts.get("sealedToken", "")) != sealed_until:
		return "--stage %s is sealed until %s" % [stage, sealed_until]
	var first: int = _seed_first(opts)
	var last: int = first + _seed_count(opts) - 1
	var exam_v: Variant = contract.get("exam", {})
	if typeof(exam_v) != TYPE_DICTIONARY:
		return "invalid seed contract exam"
	var exam: Dictionary = exam_v
	var exam_roots: Dictionary = {}
	var roots_v: Variant = exam.get("roots", [])
	if typeof(roots_v) == TYPE_ARRAY:
		for root_v: Variant in roots_v:
			exam_roots[int(float(str(root_v)))] = true
	if stage == "exam":
		if not _inside_exam(spec, first, last):
			return "exam seeds %d..%d are outside the frozen exam bands" % [first, last]
		if _has_root(opts) and not exam_roots.has(_root(opts)):
			return "exam --rootSeed %d is not 215 or 216" % _root(opts)
		if opts.has("holdoutSeed0") and not _inside_exam(spec, int(float(str(opts["holdoutSeed0"]))),
				int(float(str(opts["holdoutSeed0"]))) + _holdout_count(opts) - 1):
			return "exam holdout is outside the frozen exam bands"
		return ""
	var allowed_v: Variant = spec.get("seeds", {})
	if typeof(allowed_v) != TYPE_DICTIONARY:
		return "--stage %s is missing a seed band" % stage
	var allowed: Dictionary = allowed_v
	if first < int(float(str(allowed["first"]))) or last > int(float(str(allowed["last"]))):
		return "--stage %s seeds %d..%d must sit inside %s..%s" % [stage, first, last,
			allowed["first"], allowed["last"]]
	if _overlaps_protected(contract, first, last):
		return "--stage %s overlaps the frozen exam or reserve" % stage
	if _has_root(opts):
		var root: int = _root(opts)
		if exam_roots.has(root):
			return "--stage %s cannot use frozen exam root %d" % [stage, root]
		var roots_allowed_v: Variant = spec.get("roots", [])
		if typeof(roots_allowed_v) != TYPE_ARRAY:
			return "--stage %s has invalid roots" % stage
		var allowed_roots: Array = roots_allowed_v
		if not allowed_roots.is_empty():
			var root_ok: bool = false
			for root_v: Variant in allowed_roots:
				if int(float(str(root_v))) == root:
					root_ok = true
					break
			if not root_ok:
				return "--stage %s --rootSeed must be %s, got %d" % [stage, str(allowed_roots), root]
	if spec.has("holdout"):
		if not opts.has("holdoutSeed0"):
			return "--stage %s requires a development holdout" % stage
		var hold_first: int = int(float(str(opts["holdoutSeed0"])))
		var hold_last: int = hold_first + _holdout_count(opts) - 1
		var hold_v: Variant = spec["holdout"]
		if typeof(hold_v) != TYPE_DICTIONARY:
			return "--stage %s has an invalid holdout band" % stage
		var hold: Dictionary = hold_v
		if hold_first < int(float(str(hold["first"]))) or hold_last > int(float(str(hold["last"]))):
			return "--stage %s holdout %d..%d must sit inside %s..%s" % [stage, hold_first, hold_last,
				hold["first"], hold["last"]]
		if _overlaps_protected(contract, hold_first, hold_last):
			return "--stage %s holdout overlaps the frozen exam or reserve" % stage
	elif opts.has("holdoutSeed0"):
		var hold_first: int = int(float(str(opts["holdoutSeed0"])))
		var hold_last: int = hold_first + _holdout_count(opts) - 1
		if _overlaps_protected(contract, hold_first, hold_last):
			return "--stage %s holdout overlaps the frozen exam or reserve" % stage
	return ""


static func _driver_sha() -> String:
	var acc: String = ""
	for rel: String in DRIVER:
		acc += rel + "\n" + FileAccess.get_file_as_string("res://%s" % rel)
	return acc.sha256_text()


static func _seed_first(opts: Dictionary) -> int:
	if opts.has("seed0"):
		return int(float(str(opts["seed0"])))
	if opts.has("trainSeed0"):
		return int(float(str(opts["trainSeed0"])))
	return 0


static func _seed_count(opts: Dictionary) -> int:
	if opts.has("runs"):
		return maxi(int(float(str(opts["runs"]))), 1)
	if opts.has("maxGen") and opts.has("seedCount"):
		return maxi(int(float(str(opts["maxGen"]))) * int(float(str(opts["seedCount"]))), 1)
	if opts.has("seeds"):
		return maxi(int(float(str(opts["seeds"]))), 1)
	return 1


static func _holdout_count(opts: Dictionary) -> int:
	if opts.has("holdoutCount"):
		return maxi(int(float(str(opts["holdoutCount"]))), 1)
	return 1


static func _has_root(opts: Dictionary) -> bool:
	return opts.has("rootSeed")


static func _root(opts: Dictionary) -> int:
	return int(float(str(opts["rootSeed"])))


static func _inside_exam(spec: Dictionary, first: int, last: int) -> bool:
	for band_v: Variant in spec.get("seedBands", []):
		var band: Dictionary = band_v
		if first >= int(float(str(band["first"]))) and last <= int(float(str(band["last"]))):
			return true
	return false


static func _overlaps_protected(contract: Dictionary, first: int, last: int) -> bool:
	var exam: Dictionary = contract.get("exam", {})
	for band_v: Variant in exam.get("seedBands", []):
		var band: Dictionary = band_v
		if first <= int(float(str(band["last"]))) and int(float(str(band["first"]))) <= last:
			return true
	var reserve: Dictionary = exam.get("reserve", {})
	return first <= int(float(str(reserve.get("last", -1)))) \
		and int(float(str(reserve.get("first", 0)))) <= last
