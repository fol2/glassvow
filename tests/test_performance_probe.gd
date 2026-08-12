extends RefCounted
## Deterministic laws for the headed performance probe. Runtime timing remains
## outside the headless suite; argument/route failures are exercised headed.

const Bench: GDScript = preload("res://tools/bench_combat.gd")


static func run(fails: Array[String]) -> void:
	var values: Array[float] = [1.0, 2.0, 3.0, 4.0, 5.0]
	var empty_values: Array[float] = []
	var median: float = Bench.percentile(values, 0.50)
	var p95: float = Bench.percentile(values, 0.95)
	var empty: float = Bench.percentile(empty_values, 0.95)
	_check(fails, median == 3.0,
		"combat bench median uses the sorted middle sample")
	_check(fails, p95 == 5.0,
		"combat bench p95 uses the fail-closed upper sample")
	_check(fails, empty == 0.0,
		"combat bench empty percentile is explicit")
	if not Bench.has_method("request"):
		fails.append("combat bench has no fail-closed release request contract")
		return
	var args: PackedStringArray = PackedStringArray([
		"--fight=sporeling,sporeling,sporeling", "--kind=normal",
		"--seed=717", "--act=0", "--shape=phone-landscape",
		"--vp=844x390", "--perf-language=zh-Hant",
		"--perf-commit=0123456789abcdef0123456789abcdef01234567",
		"--perf-out=/tmp/report.json",
	])
	var valid: Dictionary = Bench.request(args)
	_check(fails, not valid.has("error"),
		"combat bench accepts the complete release request")
	var missing: PackedStringArray = args.duplicate()
	missing.remove_at(missing.find("--shape=phone-landscape"))
	var missing_result: Dictionary = Bench.request(missing)
	_check(fails, missing_result.has("error"),
		"combat bench rejects a request without a shape")
	var wrong_size: PackedStringArray = args.duplicate()
	wrong_size[wrong_size.find("--vp=844x390")] = "--vp=845x390"
	var wrong_size_result: Dictionary = Bench.request(wrong_size)
	_check(fails, wrong_size_result.has("error"),
		"combat bench rejects a window outside its shape reference")
	var duplicate: PackedStringArray = args.duplicate()
	duplicate.append("--seed=718")
	var duplicate_result: Dictionary = Bench.request(duplicate)
	_check(fails, duplicate_result.has("error"),
		"combat bench rejects duplicate release arguments")


static func _check(fails: Array[String], ok: bool, message: String) -> void:
	if not ok:
		fails.append(message)
