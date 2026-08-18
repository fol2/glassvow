extends RefCounted
## Contract for the #172 floor-device Evidence Harness. Runtime timing stays
## outside the headless suite.

const Floor: GDScript = preload("res://tools/bench_floor_profile.gd")


static func run(fails: Array[String]) -> void:
	_locks(fails)
	_request(fails)
	_gates(fails)
	_fill(fails)


static func _locks(fails: Array[String]) -> void:
	# Preload consts return Variant. Assign to a typed local first — same
	# pattern as tests/test_performance_probe.gd — so _check's bool param
	# is not an unsafe_call_argument under warnings-as-errors.
	var peak: int = Floor.PEAK_VFX
	var seed: int = Floor.SEED
	var act: int = Floor.ACT
	var kind: String = Floor.KIND
	var fight: String = Floor.FIGHT_ID
	var p95: float = Floor.GATE_P95_MS
	var p99: float = Floor.GATE_P99_MS
	var spike: float = Floor.GATE_MAX_MS
	var miss: float = Floor.GATE_MISS_PCT
	var soak: float = Floor.DEFAULT_SOAK_S
	_check(fails, peak == 96, "floor harness locks 96 VFX particles")
	_check(fails, seed == 717, "floor harness locks seed 717")
	_check(fails, act == 1, "floor harness locks act 1 (Leviathan)")
	_check(fails, kind == "boss", "floor harness locks boss kind")
	_check(fails, fight == "leviathan", "floor harness locks the Leviathan fight")
	_check(fails, p95 == 16.67, "P95 gate is the 60 fps deadline")
	_check(fails, p99 == 25.00, "P99 gate is 25 ms")
	_check(fails, spike == 50.00, "no-frame-over-50 gate")
	_check(fails, miss == 1.0, "missed-deadline allowance is 1%")
	_check(fails, soak == 1800.0, "default soak is 30 minutes")


static func _request(fails: Array[String]) -> void:
	var ok: Dictionary = Floor.request(PackedStringArray([
		"--floor-profile", "--locale=zh-Hant", "--soak-seconds=30",
		"--map-seconds=5", "--perf-commit=0123456789abcdef0123456789abcdef01234567",
	]))
	_check(fails, not ok.has("error"), "complete route request is accepted")
	_check(fails, str(ok.get("leg", "")) == "route", "default leg is route")
	_check(fails, str(ok.get("locale", "")) == "zh-Hant", "locale is captured")
	var save_ok: Dictionary = Floor.request(PackedStringArray([
		"--floor-profile", "--locale=en", "--leg=save",
	]))
	_check(fails, not save_ok.has("error") and str(save_ok.get("leg", "")) == "save",
		"save leg is accepted")
	var missing: Dictionary = Floor.request(PackedStringArray(["--floor-profile"]))
	_check(fails, missing.has("error"), "missing locale is rejected")
	var inverted: Dictionary = Floor.request(PackedStringArray([
		"--floor-profile", "--locale=en", "--soak-seconds=10", "--map-seconds=10",
	]))
	_check(fails, inverted.has("error"), "map-seconds >= soak-seconds is rejected")
	var bad_leg: Dictionary = Floor.request(PackedStringArray([
		"--floor-profile", "--locale=en", "--leg=combat",
	]))
	_check(fails, bad_leg.has("error"), "unknown --leg is rejected")


static func _gates(fails: Array[String]) -> void:
	var held: Array[float] = []
	for _i: int in range(100):
		held.append(16.67)
	var held_ok: bool = Floor.pacing_ok(held)
	_check(fails, held_ok, "a 16.67 ms stream passes pacing")
	var held_miss: float = Floor.miss_rate(held, 16.67)
	_check(fails, held_miss == 0.0, "on-deadline frames are not misses")
	var spiked: Array[float] = []
	for frame: float in held:
		spiked.append(frame)
	spiked[99] = 51.0
	var spike_ok: bool = Floor.pacing_ok(spiked)
	_check(fails, spike_ok == false, "a 51 ms frame fails the max gate")
	var empty: Array[float] = []
	var empty_ok: bool = Floor.pacing_ok(empty)
	_check(fails, empty_ok == false, "empty sample fails pacing")
	var first: Array[float] = [16.0, 16.0, 16.0]
	var last_ok: Array[float] = [17.0, 17.0, 17.0]
	var sustain_ok: bool = Floor.sustained_ok(first, last_ok)
	_check(fails, sustain_ok, "≤10% P95 rise still passes sustained")
	var last_bad: Array[float] = [18.0, 18.0, 18.0]
	var sustain_bad: bool = Floor.sustained_ok(first, last_bad)
	_check(fails, sustain_bad == false, ">10% P95 rise fails sustained")


static func _fill(fails: Array[String]) -> void:
	var se2_window: Vector2i = Floor.SE2_WINDOW
	var pad_window: Vector2i = Floor.IPAD8_WINDOW
	var se2: Vector2i = StageShape.stage_size(&"phone-landscape", se2_window)
	var pad: Vector2i = StageShape.stage_size(&"pad-landscape", pad_window)
	_check(fails, se2 == Vector2i(844, 443),
		"SE 2 live stage is 844×443 (flex clamped)")
	_check(fails, pad == Vector2i(1180, 885),
		"iPad 8 live stage is 1180×885 (no bars)")
	var se2_px: int = se2_window.x * se2_window.y
	var pad_px: int = pad_window.x * pad_window.y
	_check(fails, pad_px > se2_px * 3,
		"iPad 8 native fill is more than 3× the SE 2; do not substitute")


static func _check(fails: Array[String], ok: bool, message: String) -> void:
	if not ok:
		fails.append(message)
