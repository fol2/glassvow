extends Node
## Headed pan-repaint bench for #233: one honest map scene, twelve configs.
##
## A Node, not a SceneTree script, because the device it exists for cannot run
## one: measured 2026-08-14 on iPad 8 (iPadOS 26.1, release template), `-s` is
## silently ignored both as a devicectl launch argument and via the Info.plist
## `godot_cmdline` array — the app boots main.tscn either way, while
## `--log-file` from the same array is honoured. The literals `--script` and
## "Can't load script:" exist in the template binary; the path does not run.
## So main.gd hosts this bench behind `--map-bench`, the same route
## bench_combat.gd ships through.
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
##   godot --path . --position -4000,-4000 -- --map-bench
## On device: Info.plist `godot_cmdline` = ["--log-file","user://bench.log",
## "--","--map-bench"], then pull the log from the app container.
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
const PAN_DELTA_X: float = 0.065
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
## Fraction of frames that must sit on the median for the run to count as
## pinned to one interval rather than measuring a cost.
const QUANTISED_FRACTION: float = 0.60

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
var _renderer_mib: Dictionary[int, Array] = {}
var _screen_hz: float = 0.0  # Read once; separates a refresh floor from timer granularity
var _report_file: FileAccess = null
var _config_order: Array[int] = []  # Shuffled config order
var _run_idx: int = 0  # Index into _config_order


## Every report line goes through here: stdout for a tethered reader, plus an
## explicitly-flushed file for the device. Engine log buffering ate the final
## table row on the first iPad 8 run — SceneTree.quit() does not exit on iOS,
## so the logger never closes and its tail never flushes. This file does not
## depend on the process ending well.
func _p(line: String) -> void:
	print(line)
	if _report_file != null:
		_report_file.store_line(line)
		_report_file.flush()


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("bench_map_scene: needs a real renderer; do not pass --headless")
		get_tree().quit(2)
		return
	_report_file = FileAccess.open("user://bench_report.txt", FileAccess.WRITE)
	if not _assert_geometry():
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	get_tree().root.size = IPAD8_STAGE

	_host = Control.new()
	_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Child of the bench itself, not the tree root: root is mid-setup while
	# main.gd's _ready attaches this node, and a Control under a plain Node
	# anchors against the viewport anyway.
	add_child(_host)

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
	_p("map-scene pan probe — warmup %d, sample %d, %d repeats/config  %s / %s"
		% [WARMUP_FRAMES, SAMPLE_FRAMES, REPEATS,
			RenderingServer.get_current_rendering_method(),
			RenderingServer.get_video_adapter_name()])
	_build_config_order()
	_advance_config()
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
	var tilt_radians: float = deg_to_rad(absf(TILT_DEGREES))
	var ground_z_span: float = MapSceneProxy.CAM_SIZE / sin(tilt_radians)
	var ground_z_centre: float = MapSceneProxy.CAM_POS.z \
		- MapSceneProxy.CAM_POS.y / tan(tilt_radians)
	var z_min: float = ground_z_centre - ground_z_span / 2.0
	var z_max: float = ground_z_centre + ground_z_span / 2.0
	var aspect: float = float(IPAD8_STAGE.x) / float(IPAD8_STAGE.y)
	var half_width: float = MapSceneProxy.CAM_SIZE * aspect / 2.0
	var total_pan: float = float(WARMUP_FRAMES + SAMPLE_FRAMES) * PAN_DELTA_X
	var rest_x_min: float = MapSceneProxy.CAM_POS.x - half_width
	var rest_x_max: float = MapSceneProxy.CAM_POS.x + half_width
	var pan_x_min: float = rest_x_min + total_pan
	var pan_x_max: float = rest_x_max + total_pan
	var ground_min: Vector2 = -MapSceneProxy.GROUND_SIZE / 2.0
	var ground_max: Vector2 = MapSceneProxy.GROUND_SIZE / 2.0
	if not _require(z_min >= ground_min.y and z_max <= ground_max.y,
		"frame z %.2f..%.2f exceeds ground %.2f..%.2f"
			% [z_min, z_max, ground_min.y, ground_max.y]):
		return false
	if not _require(rest_x_min >= ground_min.x and rest_x_max <= ground_max.x \
			and pan_x_min >= ground_min.x and pan_x_max <= ground_max.x,
		"frame x %.2f..%.2f → %.2f..%.2f exceeds ground %.2f..%.2f"
			% [rest_x_min, rest_x_max, pan_x_min, pan_x_max,
				ground_min.x, ground_max.x]):
		return false
	var grade_x_max: float = MapSceneProxy.GRADE_MIN.x + MapSceneProxy.GRADE_SIZE.x
	if not _require(rest_x_min >= MapSceneProxy.GRADE_MIN.x and rest_x_max <= grade_x_max \
			and pan_x_min >= MapSceneProxy.GRADE_MIN.x and pan_x_max <= grade_x_max,
		"frame x %.2f..%.2f → %.2f..%.2f exceeds grade %.2f..%.2f"
			% [rest_x_min, rest_x_max, pan_x_min, pan_x_max,
				MapSceneProxy.GRADE_MIN.x, grade_x_max]):
		return false
	_p("geometry  canvas %dx%d  iPad 8 window %dx%d → stage %dx%d"
		% [AUTHORED_CANVAS.x, AUTHORED_CANVAS.y,
			IPAD8_WINDOW.x, IPAD8_WINDOW.y, IPAD8_STAGE.x, IPAD8_STAGE.y])
	_p("          composite %.2f Mpx  3D @1.0 %dx%d = %.2f Mpx  @1.5 %dx%d = %.2f Mpx"
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
	get_tree().quit(2)
	return false


func _banner() -> void:
	_p("")
	_p("################################################################")
	_p("#  NON-EVIDENCE unless this is a headed iPad 8 (A12) run.      #")
	_p("#  Mac / M1 / M4 / any other GPU does NOT answer #233.         #")
	_p("#  Do not quote these milliseconds as a 60 fps verdict.        #")
	_p("################################################################")
	var version: Dictionary = Engine.get_version_info()
	var version_string: String = str(version["string"])
	_p("host %s  %s  godot %s" % [
		OS.get_name(), Engine.get_architecture_name(), version_string])
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	var screen_hz: float = DisplayServer.screen_get_refresh_rate()
	_screen_hz = screen_hz
	var tree_root: Window = get_tree().root
	var window: Window = tree_root.get_window()
	var window_size: Vector2i = window.size if window != null else tree_root.size
	_p("device %s  screen %dx%d @ %.2f Hz" % [
		OS.get_model_name(), screen_size.x, screen_size.y, screen_hz])
	_p("window root %dx%d  get_window %dx%d" % [
		tree_root.size.x, tree_root.size.y, window_size.x, window_size.y])
	var tilt_radians: float = deg_to_rad(absf(TILT_DEGREES))
	var ground_z_span: float = MapSceneProxy.CAM_SIZE / sin(tilt_radians)
	var ground_z_centre: float = MapSceneProxy.CAM_POS.z \
		- MapSceneProxy.CAM_POS.y / tan(tilt_radians)
	var half_width: float = MapSceneProxy.CAM_SIZE \
		* float(IPAD8_STAGE.x) / float(IPAD8_STAGE.y) / 2.0
	var total_pan: float = float(WARMUP_FRAMES + SAMPLE_FRAMES) * PAN_DELTA_X
	_p("coverage z %.2f..%.2f (span %.2f)  x %.2f..%.2f → %.2f..%.2f (pan %.2f)" % [
		ground_z_centre - ground_z_span / 2.0, ground_z_centre + ground_z_span / 2.0,
		ground_z_span, MapSceneProxy.CAM_POS.x - half_width,
		MapSceneProxy.CAM_POS.x + half_width,
		MapSceneProxy.CAM_POS.x - half_width + total_pan,
		MapSceneProxy.CAM_POS.x + half_width + total_pan, total_pan])
	if window_size != IPAD8_STAGE:
		_p("WARNING: actual window is %dx%d; expected iPad 8 stage %dx%d" % [
			window_size.x, window_size.y, IPAD8_STAGE.x, IPAD8_STAGE.y])
	# bench_combat.gd:44-46 aborts here instead. This one warns, because the
	# debug slice is the honest way to rehearse the iOS launch path — but the
	# engine binary is not the shipped one, so the stamp has to survive into
	# anything pasted from this run.
	if OS.is_debug_build():
		_p("WARNING: DEBUG BUILD — engine differs from the shipped release")
		_p("         slice. Plumbing evidence only; #233 timings must come")
		_p("         from an --export-release build.")
	_p("")

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
	var completed_repeats: int = 0
	if _config in _results:
		var config_results: Array = _results[_config]
		completed_repeats = config_results.size()
	_p("INSTRUMENTS t=%dms config=%d osamp=%.2f octave=%s triplanar=%s repeat=%d/%d"
		% [Time.get_ticks_msec(), _config, _config_oversample(),
			_config_octave(), _config_triplanar(), completed_repeats + 1, REPEATS])
	for child: Node in _vp.get_children():
		_vp.remove_child(child)
		child.queue_free()
	_proxy = null
	var oversample: float = _config_oversample()
	_vp.size = _vp_size(oversample)
	if _config not in _results:
		_p("viewport config=%d actual=%dx%d %.2f Mpx" % [
			_config, _vp.size.x, _vp.size.y, _mpx(_vp.size.x * _vp.size.y)])
	_proxy = MapSceneProxy.new(_config_octave(), _config_triplanar(), TILT_DEGREES)
	_vp.add_child(_proxy.get_root())
	_frame = 0
	_samples.clear()
	_cpu.clear()


func _process(_delta: float) -> void:
	if _host == null:
		return  # _ready bailed (headless or geometry fail); tree is quitting
	if _proxy != null:
		_proxy.pan(PAN_DELTA_X)
	_frame += 1
	if _frame <= WARMUP_FRAMES:
		return
	# PRIMARY: unsynchronised whole-frame interval. Viewport GPU timestamps
	# read 0 on Metal, so CPU+GPU cannot answer #233. Floored by the
	# presentation interval — when most frames quantise to a known refresh
	# interval the row is below that floor, not an exact cost.
	_samples.append(_delta * 1000.0)
	# SECONDARY: viewport CPU timer. Independent of presentation; does not
	# see GPU work.
	_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(_vp_rid))
	_gpu_available = _gpu_available or \
		RenderingServer.viewport_get_measured_render_time_gpu(_vp_rid) > 0.0
	if _samples.size() < SAMPLE_FRAMES:
		return
	_record()
	_run_idx += 1
	if _run_idx >= _config_order.size():
		_report()
		get_tree().quit(0)
		set_process(false)
		return
	_advance_config()
	_build()


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


## Returns the implied Hz if the frame times are pinned to a single interval,
## else 0.0. There is no candidate list, deliberately. Two earlier versions had
## one and NEITHER could fire: the first required median and p95 both within
## 50 microseconds of the same 1000/N, which a single hitch defeats; the second
## kept FLOOR_HZ = [60, 90, 120, 144, 180] and was measured on 2026-08-14 with
## vsync forced on, where every median pinned to 13.333 ms — 75 Hz, absent from
## the list, so the count stayed at zero and the row still read 'clear'. A
## detector that cannot report the thing it exists to report is worse than no
## detector, because its silence reads as evidence. The anchor is now the run's
## own median, which is what a pinned distribution actually has.
func _quantised_hz(frames: Array[float]) -> float:
	if frames.is_empty():
		return 0.0
	var anchor: float = frames[frames.size() / 2]
	if anchor <= 0.0:
		return 0.0
	var on_anchor: int = 0
	for frame_ms: float in frames:
		if absf(frame_ms - anchor) <= FLOOR_EPS_MS:
			on_anchor += 1
	if float(on_anchor) / float(frames.size()) < QUANTISED_FRACTION:
		return 0.0
	return 1000.0 / anchor


func _clears_gate(p95: float, p99: float, max_ms: float, miss_pct: float) -> bool:
	return p95 <= GATE_P95_MS and p99 <= GATE_P99_MS \
		and max_ms <= GATE_MAX_MS and miss_pct <= GATE_MISS_PCT


## A quantised run is only a PRESENTATION floor when the interval it is pinned
## to is one the display could actually be imposing. Pinning far above the
## refresh rate is timer granularity instead — real information, but a
## different diagnosis, and calling it a refresh floor would send someone
## hunting for a vsync setting that is not the cause.
func _verdict(p95: float, p99: float, max_ms: float, miss_pct: float,
		quantised_hz: float) -> String:
	if not _clears_gate(p95, p99, max_ms, miss_pct):
		return "MISS"
	if quantised_hz > 0.0 and quantised_hz <= _screen_hz * 1.05:
		return "floor"
	return "clear"


func _record() -> void:
	_samples.sort()
	var wall: float = _samples[_samples.size() / 2]
	if _config not in _results:
		_results[_config] = []
		_pooled[_config] = []
		_pooled_cpu[_config] = []
		_renderer_mib[_config] = []
	_results[_config].append(wall)
	_renderer_mib[_config].append(
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / (1024.0 * 1024.0))
	var pool: Array = _pooled[_config]
	for s: float in _samples:
		pool.append(s)
	var cpu_pool: Array = _pooled_cpu[_config]
	for c: float in _cpu:
		cpu_pool.append(c)


func _overlaps(min1: float, max1: float, min2: float, max2: float) -> bool:
	return not (max1 < min2 or max2 < min1)

func _report() -> void:
	_p("")
	_p(" osamp | octave | triplanar | wall ms (spread) | p95 ms | p99 ms |  max ms | miss% |  CPU ms | render MiB | vs #158")
	_p(" ------|--------|-----------|------------------|--------|--------|---------|-------|---------|------------|--------")
	var floor_n: int = 0
	var miss_n: int = 0
	var clear_n: int = 0
	var config_stats: Array[Dictionary] = []
	var stats_by_config: Dictionary[int, Dictionary] = {}
	
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
		var stat: Dictionary = {
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
			"renderer_mib": _sorted_pool(
				_renderer_mib[cfg] if cfg in _renderer_mib else []),
		}
		config_stats.append(stat)
		stats_by_config[cfg] = stat
	
	# Report each config and check overlaps
	for stat: Dictionary in config_stats:
		var cfg: int = stat["cfg"]
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
		var renderer_mib_samples: Array[float] = stat["renderer_mib"]
		var p95: float = _percentile(frames, 0.95)
		var p99: float = _percentile(frames, 0.99)
		var max_ms: float = frames[frames.size() - 1]
		var missed: int = 0
		for f: float in frames:
			if f > GATE_P95_MS:
				missed += 1
		var miss_pct: float = 100.0 * float(missed) / float(frames.size())
		var cpu: float = cpus[cpus.size() / 2] if not cpus.is_empty() else 0.0
		var renderer_mib: float = renderer_mib_samples[renderer_mib_samples.size() / 2] \
			if not renderer_mib_samples.is_empty() else 0.0
		var quantised_hz: float = _quantised_hz(frames)
		var verdict: String = _verdict(p95, p99, max_ms, miss_pct, quantised_hz)
		
		# Partners are found by config IDENTITY, never by row order: within a stop
		# the rows run xz/tri/xz/tri, so the octave pair (cfg ^ 2) is never
		# adjacent and index-based comparison never tested it. Every lookup is
		# guarded — a run cut short still prints what it measured instead of
		# dying on a missing key at the moment of reporting, which on a long
		# device run is the difference between partial evidence and none.
		var overlap_labels: Array[String] = []
		var triplanar_partner: int = cfg ^ 1
		if triplanar_partner in stats_by_config:
			var tri_stat: Dictionary = stats_by_config[triplanar_partner]
			var tri_min: float = tri_stat["min"]
			var tri_max: float = tri_stat["max"]
			if _overlaps(cfg_min, cfg_max, tri_min, tri_max):
				overlap_labels.append("tri*")
		var octave_partner: int = cfg ^ 2
		if triplanar and octave_partner in stats_by_config:
			var oct_stat: Dictionary = stats_by_config[octave_partner]
			var oct_min: float = oct_stat["min"]
			var oct_max: float = oct_stat["max"]
			if _overlaps(cfg_min, cfg_max, oct_min, oct_max):
				overlap_labels.append("oct*")
		var oversample_partner: int = cfg + 4
		if oversample_partner in stats_by_config:
			var osamp_stat: Dictionary = stats_by_config[oversample_partner]
			var osamp_min: float = osamp_stat["min"]
			var osamp_max: float = osamp_stat["max"]
			if _overlaps(cfg_min, cfg_max, osamp_min, osamp_max):
				overlap_labels.append("osamp*")
		var comparison_label: String = ""
		if not overlap_labels.is_empty():
			comparison_label = " " + "/".join(overlap_labels)
		var control_label: String = " [control]" if not triplanar else ""
		
		if verdict == "floor":
			floor_n += 1
		elif verdict == "MISS":
			miss_n += 1
		else:
			clear_n += 1
		var verdict_label: String = verdict
		if quantised_hz > 0.0:
			# 'floor' = the display could be imposing this. 'quant' = pinned
			# above the refresh rate, so it is timer granularity, not pacing.
			var pin: String = "floor" if quantised_hz <= _screen_hz * 1.05 else "quant"
			verdict_label = "%s@%.0fHz" % [pin, quantised_hz] if verdict == "floor" \
				else "%s %s@%.0fHz" % [verdict, pin, quantised_hz]
		_p(" %5.2f | %6s | %9s | %6.3f ± %.3f–%.3f | %6.3f | %6.3f | %7.3f | %5.2f | %7.3f | %10.2f | %s%s%s" % [
			oversample,
			_octave_label(octave, triplanar),
			"tri" if triplanar else "xz",
			cfg_med, cfg_min, cfg_max, p95, p99, max_ms, miss_pct, cpu, renderer_mib,
			verdict_label,
			comparison_label,
			control_label])
	
	_p("")
	_p("wall ms = median unsynchronised whole-frame interval (median over %d repeats × %d frames/repeat)."
		% [REPEATS, SAMPLE_FRAMES])
	_p("spread  = range of medians across repeats; tri* / oct* / osamp* identify")
	_p("          comparisons that overlap within the harness's run-to-run noise.")
	_p("CPU ms  = viewport CPU timer (secondary). GPU timer is not a column:")
	if _gpu_available:
		_p("          GPU timestamps were non-zero on this driver.")
	else:
		_p("          GPU timer reads 0 on this driver (Metal is one). Zero is")
		_p("          UNMEASURED GPU work, not free GPU work.")
	_p("render MiB = RENDER_VIDEO_MEM_USED renderer allocation, NOT a jetsam figure.")
	_p("pinning: when >%.0f%% of a config's frames sit within %.2f ms of its own"
		% [QUANTISED_FRACTION * 100.0, FLOOR_EPS_MS])
	_p("         median, the row is pinned to one interval and the median is NOT")
	_p("         the scene's cost. floor@NHz = at or below this display's %.0f Hz,"
		% _screen_hz)
	_p("         so presentation is pacing it. quant@NHz = pinned ABOVE the")
	_p("         refresh rate, which is timer granularity, not vsync.")
	_p("")
	_p("#158 frame pacing (docs/rc-bar.md): P95 ≤ %.2f ms, P99 ≤ %.2f ms,"
		% [GATE_P95_MS, GATE_P99_MS])
	_p("          no frame > %.2f ms, missed deadlines ≤ %.1f%%."
		% [GATE_MAX_MS, GATE_MISS_PCT])
	_p("          this run: %d clear  %d refresh-floor  %d MISS  (Mac ≠ #233 evidence)"
		% [clear_n, floor_n, miss_n])
	_p("octave = n/a when triplanar=xz: props use map_ground.gdshader,")
	_p("         which has no octave path; the flag does not change the shader.")
	_p("[control] = xz pair (identical configs); spread is harness precision measurement.")
	_p("")
	_p("MEMORY INSTRUMENTS")
	_p("  RENDER_VIDEO_MEM_USED — renderer allocation, NOT the jetsam budget.")
	_p("  resident  process RSS / phys_footprint — THIS is the jetsam figure.")
	_banner()
