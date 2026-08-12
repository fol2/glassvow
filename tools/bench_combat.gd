extends Node
## Release probe for the shipped Main -> real CombatScreen route.
## Main attaches this node only when `--perf-out=` is present, so the clean
## exported app is measured without a second composition or a debug build.

const WARMUP_SECONDS: float = 6.0
const WARMUP_FRAMES: int = 300
const SAMPLE_SECONDS: float = 10.0
const SAMPLE_FRAMES: int = 600
const ARG_KEYS: Array[String] = [
	"fight", "kind", "seed", "act", "shape", "vp", "perf-language",
	"perf-commit", "perf-out", "perf-mode",
]

var _main: Main
var _request: Dictionary = {}
var _frame: int = 0
var _started_us: int = 0
var _sampling_us: int = 0
var _last_frame_us: int = 0
var _vps: Array[RID] = []
var _viewport_pixels: int = 0
var _viewport_sizes: Array[Vector2i] = []
var _actor_stage_sizes: Array[Vector2i] = []
var _wall_ms: Array[float] = []
var _cpu_ms: Array[float] = []
var _setup_ms: Array[float] = []
var _gpu_ms: Array[float] = []
var _renderer_bytes: Array[float] = []


func _init(main_ref: Main) -> void:
	_main = main_ref


func _ready() -> void:
	_request = request(OS.get_cmdline_user_args())
	if _request.has("error"):
		_fail(str(_request["error"]))
		return
	if Locale.active.code != StringName(str(_request["language"])):
		_fail("active language %s does not match requested %s" % [
			Locale.active.code, _request["language"]])
		return
	if OS.is_debug_build():
		_fail("release performance evidence requires a release export")
		return
	_started_us = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	_frame += 1
	var now_us: int = Time.get_ticks_usec()
	if _sampling_us == 0:
		if _frame < WARMUP_FRAMES \
				or float(now_us - _started_us) < WARMUP_SECONDS * 1000000.0:
			return
		if not _bind_scene():
			return
		_sampling_us = now_us
		_last_frame_us = now_us
		return
	_wall_ms.append(float(now_us - _last_frame_us) / 1000.0)
	_last_frame_us = now_us
	var cpu: float = 0.0
	var gpu: float = 0.0
	for rid: RID in _vps:
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
	_cpu_ms.append(cpu)
	_setup_ms.append(RenderingServer.get_frame_setup_time_cpu())
	_gpu_ms.append(gpu)
	_renderer_bytes.append(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
	if _wall_ms.size() < SAMPLE_FRAMES \
			or float(now_us - _sampling_us) < SAMPLE_SECONDS * 1000000.0:
		return
	_write_report()


func _bind_scene() -> bool:
	var screens: Array[Node] = get_tree().root.find_children(
		"", "CombatScreen", true, false)
	if screens.size() != 1:
		_fail("expected one CombatScreen, got %d" % screens.size())
		return false
	var combat: CombatScreen = screens[0] as CombatScreen
	if combat.game == null or combat.game.cb == null:
		_fail("combat state did not start")
		return false
	if combat.seq.is_busy():
		_fail("combat did not settle before sampling")
		return false
	var expected_fight: PackedStringArray = _request["fight"]
	var actual_fight: PackedStringArray = PackedStringArray()
	for enemy: EnemyCombatant in combat.game.cb.enemies:
		actual_fight.append(String(enemy.variant_id if enemy.variant_id != &"" else enemy.key))
	if actual_fight != expected_fight:
		_fail("fight mismatch: expected %s got %s" % [expected_fight, actual_fight])
		return false
	var expected_size: Vector2i = Vector2i(
		int(float(str(_request["vp_x"]))), int(float(str(_request["vp_y"]))))
	if combat.shape != StringName(str(_request["shape"])) \
			or get_tree().root.size != expected_size:
		_fail("shape/window mismatch: %s %s" % [combat.shape, get_tree().root.size])
		return false
	var actors: Array[Node] = get_tree().root.find_children("", "EnemyView", true, false)
	if actors.size() != expected_fight.size() + 1:
		_fail("expected %d live actors, got %d" % [expected_fight.size() + 1, actors.size()])
		return false
	_vps = [get_tree().root.get_viewport_rid()]
	_viewport_pixels = get_tree().root.size.x * get_tree().root.size.y
	_viewport_sizes = [get_tree().root.size]
	for node: Node in get_tree().root.find_children("", "SubViewport", true, false):
		var viewport: SubViewport = node as SubViewport
		_vps.append(viewport.get_viewport_rid())
		_viewport_pixels += viewport.size.x * viewport.size.y
		_viewport_sizes.append(viewport.size)
	_actor_stage_sizes.clear()
	for actor: Node in actors:
		var stages: Array[Node] = actor.find_children("", "SubViewport", true, false)
		if stages.size() != 1:
			_fail("expected one stage per actor, got %d" % stages.size())
			return false
		var stage: SubViewport = stages[0] as SubViewport
		_actor_stage_sizes.append(stage.size)
	for rid: RID in _vps:
		RenderingServer.viewport_set_measure_render_time(rid, true)
	combat.performance_peak_vfx()
	print("BENCH_READY " + JSON.stringify({
		"pid": OS.get_process_id(), "shape": _request["shape"],
		"window": [expected_size.x, expected_size.y], "actors": actors.size(),
		"measured_viewports": _vps.size(), "language": _request["language"],
		"renderer": RenderingServer.get_video_adapter_name(),
	}))
	return true


func _write_report() -> void:
	var cpu_total: Array[float] = []
	for i: int in _cpu_ms.size():
		cpu_total.append(_cpu_ms[i] + _setup_ms[i])
	var report: Dictionary = {
		"schema": 1,
		"provenance": {
			"claimed_commit": _request["commit"],
			"godot": str(Engine.get_version_info()["string"]),
			"os": OS.get_name(), "architecture": Engine.get_architecture_name(),
			"renderer": RenderingServer.get_video_adapter_name(),
			"release": not OS.is_debug_build(),
			"rendering_method": RenderingServer.get_current_rendering_method(),
		},
		"request": {
			"fight": _request["fight"], "kind": _request["kind"],
			"seed": _request["seed"], "act": _request["act"],
			"shape": _request["shape"],
			"window": [_request["vp_x"], _request["vp_y"]],
			"language": _request["language"], "mode": _request["mode"],
		},
		"method": {
			"warmup_seconds": WARMUP_SECONDS,
			"warmup_frames_min": WARMUP_FRAMES,
			"sample_seconds": SAMPLE_SECONDS,
			"sample_frames_min": SAMPLE_FRAMES,
			"measured_viewports": _vps.size(), "viewport_pixels": _viewport_pixels,
			"viewport_sizes": _viewport_sizes,
			"actor_stage_sizes": _actor_stage_sizes,
		},
		"samples": {
			"observed_frame_ms": _wall_ms, "render_cpu_ms": _cpu_ms,
			"frame_setup_cpu_ms": _setup_ms, "render_cpu_plus_setup_ms": cpu_total,
			"render_gpu_ms": _gpu_ms, "renderer_allocated_bytes": _renderer_bytes,
		},
		"summary": {
			"sample_count": _wall_ms.size(),
			"observed_frame_median_ms": percentile(_wall_ms, 0.50),
			"observed_frame_p95_ms": percentile(_wall_ms, 0.95),
			"render_cpu_plus_setup_p95_ms": percentile(cpu_total, 0.95),
			"render_gpu_available": maximum(_gpu_ms) > 0.0,
			"render_gpu_p95_ms": percentile(_gpu_ms, 0.95),
			"renderer_allocated_peak_mib": maximum(_renderer_bytes) / 1048576.0,
		},
	}
	var file: FileAccess = FileAccess.open(str(_request["out"]), FileAccess.WRITE)
	if file == null:
		_fail("cannot write --perf-out")
		return
	file.store_string(JSON.stringify(report) + "\n")
	file.flush()
	file.close()
	print("BENCH_RESULT " + JSON.stringify(report["summary"]))
	if report["summary"]["render_gpu_available"] == false:
		print("BENCH_NOTE Metal GPU timer unavailable; zero is unmeasured, not free.")
	get_tree().quit(0)


static func request(args: PackedStringArray) -> Dictionary:
	var raw: Dictionary = {}
	for arg: String in args:
		if not arg.begins_with("--") or not arg.contains("="):
			continue
		var key: String = arg.get_slice("=", 0).trim_prefix("--")
		if not ARG_KEYS.has(key):
			continue
		if raw.has(key):
			return {"error": "duplicate --%s" % key}
		raw[key] = arg.substr(arg.find("=") + 1)
	for key: String in ARG_KEYS:
		if not raw.has(key) or str(raw[key]).is_empty():
			return {"error": "missing --%s" % key}
	var shape: StringName = StringName(str(raw["shape"]))
	if not StageShape.REFERENCES.has(shape):
		return {"error": "unknown shape"}
	var vp_parts: PackedStringArray = str(raw["vp"]).split("x", false)
	if vp_parts.size() != 2 or not vp_parts[0].is_valid_int() \
			or not vp_parts[1].is_valid_int():
		return {"error": "invalid --vp"}
	var vp: Vector2i = Vector2i(int(vp_parts[0]), int(vp_parts[1]))
	if vp != StageShape.REFERENCES[shape]:
		return {"error": "--vp does not match shape reference"}
	if str(raw["perf-language"]) not in ["en", "zh-Hant"]:
		return {"error": "invalid language"}
	if str(raw["kind"]) not in ["normal", "elite", "boss"]:
		return {"error": "invalid kind"}
	var seed: int = str(raw["seed"]).to_int()
	if not str(raw["seed"]).is_valid_int() or seed < 0:
		return {"error": "invalid seed"}
	var act: int = str(raw["act"]).to_int()
	if not str(raw["act"]).is_valid_int() or act not in range(3):
		return {"error": "invalid act"}
	if str(raw["perf-mode"]) != "full":
		return {"error": "invalid mode"}
	var commit: String = str(raw["perf-commit"]).to_lower()
	if commit.length() != 40 or not commit.is_valid_hex_number(false):
		return {"error": "invalid commit"}
	if not str(raw["perf-out"]).begins_with("/"):
		return {"error": "--perf-out must be absolute"}
	var fight: PackedStringArray = str(raw["fight"]).split(",", false)
	if fight.is_empty():
		return {"error": "empty fight"}
	return {
		"fight": fight, "kind": str(raw["kind"]), "seed": seed,
		"act": act, "shape": String(shape), "vp_x": vp.x, "vp_y": vp.y,
		"language": str(raw["perf-language"]), "commit": commit,
		"out": str(raw["perf-out"]), "mode": str(raw["perf-mode"]),
	}


static func percentile(values: Array[float], quantile: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	return sorted[mini(sorted.size() - 1,
		floori(float(sorted.size()) * clampf(quantile, 0.0, 1.0)))]


static func maximum(values: Array[float]) -> float:
	var out: float = 0.0
	for value: float in values:
		out = maxf(out, value)
	return out


func _fail(message: String) -> void:
	print("BENCH_ERROR " + message)
	push_error("bench_combat: " + message)
	set_process(false)
	get_tree().quit(2)
