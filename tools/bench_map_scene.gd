extends SceneTree
## Headed pan-repaint bench for #233: one honest map scene, twelve configs.
##
## Clock protocol from tools/bench_reward_stage.gd (WARMUP_FRAMES /
## SAMPLE_FRAMES; measure-render-time enabled ONCE before anything is sampled).
## Primary figure from tools/bench_actor_stage.gd: unsynchronised whole-frame
## interval. Viewport GPU timestamps read 0 on Metal — iPad 8's path — so
## CPU+GPU cannot answer #233. The CPU timer stays as a labelled secondary.
##
## The scene under test is MapSceneProxy — this harness does not build the
## proxy, and it does not touch scaling_3d_scale (OVERSAMPLE and
## scaling_3d_scale multiply). Binding frame is a pan, not a hold.
##
## Not a test; needs a real renderer — never --headless:
##   godot --path . --position -4000,-4000 -s res://tools/bench_map_scene.gd
##
## Mac numbers are NON-EVIDENCE. #233 counts only a headed pan-repaint on
## iPad 8 (A12).
##
## Each config is repeated REPEATS times with randomized interleaving to
## measure spread and distinguish signal from cache/thermal noise.

const WARMUP_FRAMES: int = 90
const SAMPLE_FRAMES: int = 180
const REPEATS: int = 5  # Repeats per config; lower on slow hardware
const VP_MAX: int = 2048
const TILT_DEGREES: float = -55.0
const PAN_DELTA_X: float = 0.08
const OVERSAMPLES: Array[float] = [1.0, 1.25, 1.5]
const AUTHORED_CANVAS: Vector2i = Vector2i(1180, 820)
const IPAD8_WINDOW: Vector2i = Vector2i(2160, 1620)
const IPAD8_STAGE: Vector2i = Vector2i(1180, 885)
const COMPOSITE_MPX: float = 3.50
const PASS_1_0_MPX: float = 1.04
const PASS_1_5_MPX: float = 2.35
## #158 / docs/rc-bar.md frame-pacing gate (60 fps display deadline).
const GATE_P95_MS: float = 16.67
const GATE_P99_MS: float = 25.00
const GATE_MAX_MS: float = 50.00
const GATE_MISS_PCT: float = 1.0
const FLOOR_EPS_MS: float = 0.05
const FLOOR_HZ: Array[int] = [60, 90, 120, 144, 180]

var _host: Control = null
var _vp: SubViewport = null
var _display: TextureRect = null
var _vp_rid: RID
var _proxy: MapSceneProxy = null
var _config: int = 0
var _frame: int = 0
var _samples: Array[float] = []
var _cpu: Array[float] = []
var _gpu_available: bool = false
var _results: Dictionary = {}  # config_idx -> Array[float] medians across repeats
# config_idx -> every sampled frame across every repeat. The #158 gate is a
# statement about FRAMES — P95, P99, worst frame and missed-deadline rate are
# all per-frame quantities — so keeping only each repeat's median collapsed a
# REPEATS x SAMPLE_FRAMES distribution to REPEATS numbers, at which point p95
# and p99 can do nothing but echo the median. `_results` survives, but only to
# price the harness's own repeat-to-repeat spread.
var _pooled: Dictionary[int, Array] = {}
var _pooled_cpu: Dictionary[int, Array] = {}
var _config_order: Array[int] = []  # Shuffled config order
var _run_idx: int = 0  # Index into _config_order


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("bench_map_scene: needs a real renderer; do not pass --headless")
		quit(2)
		return
	if not _assert_geometry():
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	root.size = IPAD8_STAGE

	_host = Control.new()
	_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_host)

	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_host.add_child(_vp)
	# Clock ONCE, before any config is sampled. Enabling inside the sample
	# loop made the first reading zero by construction (bench_reward_stage.gd).
	_vp_rid = _vp.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp_rid, true)

	_display = TextureRect.new()
	_display.texture = _vp.get_texture()
	_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_display.stretch_mode = TextureRect.STRETCH_SCALE
	_display.set_anchors_preset(Control.PRESET_FULL_RECT)
	_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_host.add_child(_display)

	_banner()
	print("map-scene pan probe — warmup %d, sample %d, %d repeats/config  %s / %s"
		% [WARMUP_FRAMES, SAMPLE_FRAMES, REPEATS,
			RenderingServer.get_current_rendering_method(),
			RenderingServer.get_video_adapter_name()])
	_build_config_order()
	_build()


func _build_config_order() -> void:
	_config_order.clear()
	for i: int in range(OVERSAMPLES.size() * 4 * REPEATS):
		_config_order.append(i)
	_config_order.shuffle()


func _assert_geometry() -> bool:
	var authored: Vector2i = StageShape.REFERENCES[StageShape.IDENTITY]
	if not _require(authored == AUTHORED_CANVAS,
		"authored canvas is %dx%d, #233 wants 1180x820" % [authored.x, authored.y]):
		return false
	var stage: Vector2i = StageShape.stage_size(&"pad-landscape", IPAD8_WINDOW)
	if not _require(stage == IPAD8_STAGE,
		"iPad 8 2160x1620 flexed to %dx%d, #233 wants 1180x885" % [stage.x, stage.y]):
		return false
	var composite: int = IPAD8_WINDOW.x * IPAD8_WINDOW.y
	if not _require(_mpx(composite) == COMPOSITE_MPX,
		"iPad 8 composite is %.2f Mpx, #233 wants 3.50" % _mpx(composite)):
		return false
	var pass_1: Vector2i = _vp_size(1.0)
	if not _require(pass_1 == IPAD8_STAGE and _mpx(pass_1.x * pass_1.y) == PASS_1_0_MPX,
		"oversample 1.0 is %dx%d (%.2f Mpx), #233 wants 1180x885 / 1.04"
			% [pass_1.x, pass_1.y, _mpx(pass_1.x * pass_1.y)]):
		return false
	var pass_15: Vector2i = _vp_size(1.5)
	if not _require(_mpx(pass_15.x * pass_15.y) == PASS_1_5_MPX,
		"oversample 1.5 is %dx%d (%.2f Mpx), #233 wants 2.35"
			% [pass_15.x, pass_15.y, _mpx(pass_15.x * pass_15.y)]):
		return false
	print("geometry  canvas %dx%d  iPad 8 window %dx%d → stage %dx%d"
		% [AUTHORED_CANVAS.x, AUTHORED_CANVAS.y,
			IPAD8_WINDOW.x, IPAD8_WINDOW.y, IPAD8_STAGE.x, IPAD8_STAGE.y])
	print("          composite %.2f Mpx  3D @1.0 %dx%d = %.2f Mpx  @1.5 %dx%d = %.2f Mpx"
		% [COMPOSITE_MPX, pass_1.x, pass_1.y, PASS_1_0_MPX,
			pass_15.x, pass_15.y, PASS_1_5_MPX])
	return true


func _vp_size(oversample: float) -> Vector2i:
	return Vector2i(
		mini(int(float(IPAD8_STAGE.x) * oversample), VP_MAX),
		mini(int(float(IPAD8_STAGE.y) * oversample), VP_MAX))


func _mpx(pixels: int) -> float:
	return snappedf(float(pixels) / 1000000.0, 0.01)


func _require(ok: bool, message: String) -> bool:
	if ok:
		return true
	printerr("bench_map_scene GEOMETRY FAIL: " + message)
	quit(2)
	return false


func _banner() -> void:
	print("")
	print("################################################################")
	print("#  NON-EVIDENCE unless this is a headed iPad 8 (A12) run.      #")
	print("#  Mac / M1 / M4 / any other GPU does NOT answer #233.         #")
	print("#  Do not quote these milliseconds as a 60 fps verdict.        #")
	print("################################################################")
	var version: Dictionary = Engine.get_version_info()
	var version_string: String = str(version["string"])
	print("host %s  %s  godot %s" % [
		OS.get_name(), Engine.get_architecture_name(), version_string])
	print("")

func _config_oversample() -> float:
	return OVERSAMPLES[_config >> 2]


func _config_octave() -> bool:
	return (_config % 4) >= 2


func _config_triplanar() -> bool:
	return (_config % 2) == 1


func _octave_label(octave: bool, triplanar: bool) -> String:
	# map_ground.gdshader has no octave path; the flag is inert on xz props.
	if not triplanar:
		return "n/a"
	return "on" if octave else "off"


func _build() -> void:
	for child: Node in _vp.get_children():
		_vp.remove_child(child)
		child.queue_free()
	_proxy = null
	var oversample: float = _config_oversample()
	_vp.size = _vp_size(oversample)
	_proxy = MapSceneProxy.new(_config_octave(), _config_triplanar(), TILT_DEGREES)
	_vp.add_child(_proxy.get_root())
	_frame = 0
	_samples.clear()
	_cpu.clear()


func _process(_delta: float) -> bool:
	if _proxy != null:
		_proxy.pan(PAN_DELTA_X)
	_frame += 1
	if _frame <= WARMUP_FRAMES:
		return false
	# PRIMARY: unsynchronised whole-frame interval. Viewport GPU timestamps
	# read 0 on Metal, so CPU+GPU cannot answer #233. Floored by the
	# presentation interval — a row at exactly 1/120 or 1/180 means 'below
	# the floor', not 'this is the cost' (bench_actor_stage.gd).
	_samples.append(_delta * 1000.0)
	# SECONDARY: viewport CPU timer. Independent of presentation; does not
	# see GPU work.
	_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(_vp_rid))
	_gpu_available = _gpu_available or \
		RenderingServer.viewport_get_measured_render_time_gpu(_vp_rid) > 0.0
	if _samples.size() < SAMPLE_FRAMES:
		return false
	_record()
	_run_idx += 1
	if _run_idx >= _config_order.size():
		_report()
		quit(0)
		return false
	_advance_config()
	_build()
	return false


func _advance_config() -> void:
	var run_idx: int = _config_order[_run_idx]
	_config = run_idx % (OVERSAMPLES.size() * 4)


func _percentile(sorted_samples: Array[float], p: float) -> float:
	return sorted_samples[int(float(sorted_samples.size()) * p)]


func _sorted_pool(raw: Array) -> Array[float]:
	var out: Array[float] = []
	out.assign(raw)
	out.sort()
	return out


func _floor_hz(med: float, p95: float) -> int:
	# Pinned means the body AND the tail sit on the same interval. A median
	# that happens to land on 1000/144 while p95 is a hitch is not a floor.
	for hz: int in FLOOR_HZ:
		var floor_ms: float = 1000.0 / float(hz)
		if absf(med - floor_ms) < FLOOR_EPS_MS \
				and absf(p95 - floor_ms) < FLOOR_EPS_MS:
			return hz
	return 0


func _clears_gate(p95: float, p99: float, max_ms: float, miss_pct: float) -> bool:
	return p95 <= GATE_P95_MS and p99 <= GATE_P99_MS \
		and max_ms <= GATE_MAX_MS and miss_pct <= GATE_MISS_PCT


func _verdict(p95: float, p99: float, max_ms: float, miss_pct: float,
		floor_hz: int) -> String:
	if not _clears_gate(p95, p99, max_ms, miss_pct):
		return "MISS"
	if floor_hz > 0:
		return "floor"
	return "clear"


func _record() -> void:
	_samples.sort()
	var wall: float = _samples[_samples.size() / 2]
	if _config not in _results:
		_results[_config] = []
		_pooled[_config] = []
		_pooled_cpu[_config] = []
	_results[_config].append(wall)
	var pool: Array = _pooled[_config]
	for s: float in _samples:
		pool.append(s)
	var cpu_pool: Array = _pooled_cpu[_config]
	for c: float in _cpu:
		cpu_pool.append(c)


func _overlaps(min1: float, max1: float, min2: float, max2: float) -> bool:
	return not (max1 < min2 or max2 < min1)

func _report() -> void:
	print("")
	print(" osamp | octave | triplanar | wall ms (spread) | p95 ms | p99 ms |  max ms | miss% |  CPU ms | vs #158")
	print(" ------|--------|-----------|-----------------|--------|--------|---------|-------|---------|--------")
	var floor_n: int = 0
	var miss_n: int = 0
	var clear_n: int = 0
	var config_stats: Array[Dictionary] = []
	
	# Aggregate each config's repeats into stats
	for cfg: int in range(OVERSAMPLES.size() * 4):
		if cfg not in _results or _results[cfg].is_empty():
			continue
		var medians: Array = _results[cfg]  # Array of float from _record()
		medians.sort()
		var cfg_med: float = medians[medians.size() / 2] if medians.size() > 0 else 0.0
		var cfg_min: float = medians[0]
		var cfg_max: float = medians[medians.size() - 1]
		_config = cfg  # Set for _config_* accessors
		config_stats.append({
			"cfg": cfg,
			"oversample": _config_oversample(),
			"octave": _config_octave(),
			"triplanar": _config_triplanar(),
			"median": cfg_med,
			"min": cfg_min,
			"max": cfg_max,
			"medians": medians,
			"frames": _sorted_pool(_pooled[cfg] if cfg in _pooled else []),
			"cpus": _sorted_pool(_pooled_cpu[cfg] if cfg in _pooled_cpu else []),
		})
	
	# Report each config and check overlaps
	for i: int in range(config_stats.size()):
		var stat: Dictionary = config_stats[i]
		var cfg_med: float = stat["median"]
		var cfg_min: float = stat["min"]
		var cfg_max: float = stat["max"]
		var triplanar: bool = stat["triplanar"]
		var octave: bool = stat["octave"]
		var oversample: float = stat["oversample"]
		
		# Every one of these is a per-frame quantity, read off the pooled frame
		# distribution. They were previously assigned cfg_med / 0.0 outright,
		# which made p99 unable to exceed the median and made the missed-
		# deadline rate a constant zero — so the #158 verdict could not report
		# a miss on pacing however badly the scene ran.
		var frames: Array[float] = stat["frames"]
		var cpus: Array[float] = stat["cpus"]
		var p95: float = _percentile(frames, 0.95)
		var p99: float = _percentile(frames, 0.99)
		var max_ms: float = frames[frames.size() - 1]
		var missed: int = 0
		for f: float in frames:
			if f > GATE_P95_MS:
				missed += 1
		var miss_pct: float = 100.0 * float(missed) / float(frames.size())
		var cpu: float = cpus[cpus.size() / 2] if not cpus.is_empty() else 0.0
		var floor_hz: int = _floor_hz(cfg_med, p95)
		var verdict: String = _verdict(p95, p99, max_ms, miss_pct, floor_hz)
		
		var resolvable: String = ""
		if i > 0:
			var prior: Dictionary = config_stats[i - 1]
			var prior_oversample: float = prior["oversample"]
			if int(prior_oversample) == int(oversample):
				var prior_min: float = prior["min"]
				var prior_max: float = prior["max"]
				if _overlaps(cfg_min, cfg_max, prior_min, prior_max):
					resolvable = " *OVERLAP*"
		
		var control_label: String = ""
		if not triplanar and i > 0:
			var prior: Dictionary = config_stats[i - 1]
			if not prior["triplanar"] and prior["oversample"] == oversample:
				control_label = " [control]"
		
		if verdict == "floor":
			floor_n += 1
		elif verdict == "MISS":
			miss_n += 1
		else:
			clear_n += 1
		print(" %5.2f | %6s | %9s | %6.3f ± %.3f–%.3f | %6.3f | %6.3f | %7.3f | %5.2f | %7.3f | %s%s%s" % [
			oversample,
			_octave_label(octave, triplanar),
			"tri" if triplanar else "xz",
			cfg_med, cfg_min, cfg_max, p95, p99, max_ms, miss_pct, cpu,
			verdict,
			resolvable,
			control_label])
	
	print("")
	print("wall ms = median unsynchronised whole-frame interval (median over %d repeats × %d frames/repeat)."
		% [REPEATS, SAMPLE_FRAMES])
	print("spread  = range of medians across repeats; *OVERLAP* means configs not resolvable")
	print("          above the harness's run-to-run noise.")
	print("CPU ms  = viewport CPU timer (secondary). GPU timer is not a column:")
	if _gpu_available:
		print("          GPU timestamps were non-zero on this driver.")
	else:
		print("          GPU timer reads 0 on this driver (Metal is one). Zero is")
		print("          UNMEASURED GPU work, not free GPU work.")
	print("wall ms is floored by the refresh interval — a median at exactly 1/120")
	print("or 1/180 means 'below the floor', not 'this is the cost'.")
	print("")
	print("#158 frame pacing (docs/rc-bar.md): P95 ≤ %.2f ms, P99 ≤ %.2f ms,"
		% [GATE_P95_MS, GATE_P99_MS])
	print("          no frame > %.2f ms, missed deadlines ≤ %.1f%%."
		% [GATE_MAX_MS, GATE_MISS_PCT])
	print("          this run: %d clear  %d refresh-floor  %d MISS  (Mac ≠ #233 evidence)"
		% [clear_n, floor_n, miss_n])
	print("octave = n/a when triplanar=xz: props use map_ground.gdshader,")
	print("         which has no octave path; the flag does not change the shader.")
	print("[control] = xz pair (identical configs); spread is harness precision measurement.")
	print("")
	print("MEMORY INSTRUMENTS")
	print("  RENDER_VIDEO_MEM_USED — renderer allocation, NOT the jetsam budget.")
	print("  resident  process RSS / phys_footprint — THIS is the jetsam figure.")
	_banner()
