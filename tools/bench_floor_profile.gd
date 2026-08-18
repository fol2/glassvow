extends Node
## Device Evidence Harness for wayfinder #172 / RC bar P2.
##
## Hosted by main.gd `--floor-profile` because iOS ignores `-s` (measured
## 2026-08-14, iPad 8). Tees to user:// — SceneTree.quit() does not exit on
## iOS, so the report cannot depend on a clean process end.
##
## Route leg: live WorldMapScreen pan (worst visible map motion) then the
## act-1 Leviathan boss with 96 sustained VFX, soaked for `--soak-seconds`
## (default 1800). Save leg: `--resume` to interactive. Platform thermals,
## battery and phys_footprint stay Instruments — GDScript cannot see them.
##
## Release export only. Mac numbers are not floor evidence.

const Bench: GDScript = preload("res://tools/bench_combat.gd")

const FIGHT_ID: String = "leviathan"
const KIND: String = "boss"
const SEED: int = 717
const ACT: int = 1
const PEAK_VFX: int = 96
const GATE_P95_MS: float = 16.67
const GATE_P99_MS: float = 25.00
const GATE_MAX_MS: float = 50.00
const GATE_MISS_PCT: float = 1.0
const DEFAULT_SOAK_S: float = 1800.0
const DEFAULT_MAP_S: float = 45.0
const WARMUP_S: float = 6.0
const SUSTAIN_S: float = 300.0
const VFX_TAIL_S: float = 4.0
const PAN_DELTA: float = 0.065
const WAIT_S: float = 12.0
const SE2_WINDOW: Vector2i = Vector2i(1334, 750)
const IPAD8_WINDOW: Vector2i = Vector2i(2160, 1620)
const TXT_PATH: String = "user://floor_profile.txt"
const JSON_PATH: String = "user://floor_profile.json"

enum Phase { WAIT, MAP, WAIT_COMBAT, COMBAT, SAVE, DONE }

var _req: Dictionary = {}
var _phase: int = Phase.WAIT
var _report: FileAccess = null
var _started_us: int = 0
var _phase_us: int = 0
var _last_us: int = 0
var _pan_delta: Vector2 = Vector2(PAN_DELTA, 0.0)
var _map: MapScene = null
var _combat: CombatScreen = null
var _map_ms: Array[float] = []
var _combat_ms: Array[float] = []
var _combat_us: Array[int] = []
var _renderer_peak: float = 0.0
var _vfx: int = 0
var _interactive_ms: float = 0.0


func _ready() -> void:
	_req = request(OS.get_cmdline_user_args())
	if _req.has("error"):
		_fail(str(_req["error"]))
		return
	if DisplayServer.get_name() == "headless":
		_fail("needs a real renderer; do not pass --headless")
		return
	if OS.is_debug_build():
		_fail("release performance evidence requires a release export")
		return
	if Locale.active.code != StringName(str(_req["locale"])):
		_fail("active language %s does not match --locale=%s" % [
			Locale.active.code, _req["locale"]])
		return
	if Preferences.active.reduce_motion:
		_fail("reduce_motion is on; floor evidence must run at full motion")
		return
	_report = FileAccess.open(TXT_PATH, FileAccess.WRITE)
	_started_us = Time.get_ticks_usec()
	_phase_us = _started_us
	_phase = Phase.SAVE if str(_req["leg"]) == "save" else Phase.WAIT
	_p("FLOOR_START " + JSON.stringify({
		"leg": _req["leg"], "locale": _req["locale"],
		"soak_s": _req["soak"], "map_s": _req["map"],
		"seed": SEED, "act": ACT, "fight": FIGHT_ID,
		"debug": OS.is_debug_build(),
		"renderer": RenderingServer.get_video_adapter_name(),
	}))


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	match _phase:
		Phase.WAIT:
			_tick_wait_map(now)
		Phase.MAP:
			_tick_map(now)
		Phase.WAIT_COMBAT:
			_tick_wait_combat(now)
		Phase.COMBAT:
			_tick_combat(now)
		Phase.SAVE:
			_tick_save(now)
		Phase.DONE:
			set_process(false)


func _tick_wait_map(now: int) -> void:
	if _late(now):
		return
	var maps: Array[Node] = get_tree().root.find_children("", "MapScene", true, false)
	if maps.size() != 1:
		return
	if float(now - _started_us) < WARMUP_S * 1000000.0:
		return
	_map = maps[0] as MapScene
	if _map == null:
		_fail("MapScene did not bind")
		return
	_map.set_live(true)
	var host: Node = get_parent()
	var trans: Variant = host.get("_transitions")
	if trans is TransitionLayer:
		var plate: TransitionLayer = trans
		plate.act_plate("The Sunken City", "", Color.WHITE)
	_phase = Phase.MAP
	_phase_us = now
	_last_us = now
	_p("FLOOR_MAP")


func _tick_map(now: int) -> void:
	var rig: MapCameraRig = _map.get_rig()
	var before: Vector2 = rig.camera_xz()
	rig.pan_world(_pan_delta)
	if rig.camera_xz().is_equal_approx(before):
		_pan_delta = -_pan_delta
		rig.pan_world(_pan_delta)
	_sample(now, _map_ms)
	_last_us = now
	if float(now - _phase_us) < float(str(_req["map"])) * 1000000.0:
		return
	_map = null
	var host: Node = get_parent()
	if host == null or not host.has_method(&"start_floor_combat"):
		_fail("main has no start_floor_combat")
		return
	host.call(&"start_floor_combat")
	_phase = Phase.WAIT_COMBAT
	_phase_us = now
	_p("FLOOR_COMBAT_WAIT")


func _tick_wait_combat(now: int) -> void:
	if _late(now):
		return
	var screens: Array[Node] = get_tree().root.find_children(
		"", "CombatScreen", true, false)
	if screens.size() != 1:
		return
	var combat: CombatScreen = screens[0] as CombatScreen
	if combat == null or combat.game == null or combat.game.cb == null:
		return
	if combat.seq.is_busy():
		return
	var actual: PackedStringArray = PackedStringArray()
	for enemy: EnemyCombatant in combat.game.cb.enemies:
		actual.append(String(enemy.variant_id if enemy.variant_id != &"" else enemy.key))
	var expected: PackedStringArray = PackedStringArray([FIGHT_ID])
	if actual != expected:
		_fail("fight mismatch: expected %s got %s" % [expected, actual])
		return
	var life: float = float(str(_req["soak"])) - float(str(_req["map"])) + VFX_TAIL_S
	_vfx = combat.performance_peak_vfx(PEAK_VFX, life)
	if _vfx != PEAK_VFX:
		_fail("expected %d peak VFX, got %d" % [PEAK_VFX, _vfx])
		return
	_combat = combat
	_phase = Phase.COMBAT
	_phase_us = now
	_last_us = now
	_p("FLOOR_COMBAT")


func _tick_combat(now: int) -> void:
	_sample(now, _combat_ms)
	_combat_us.append(now)
	_last_us = now
	var combat_s: float = float(str(_req["soak"])) - float(str(_req["map"]))
	if float(now - _phase_us) < combat_s * 1000000.0:
		return
	if _combat.performance_vfx_particles() != PEAK_VFX:
		_fail("VFX count drifted from %d" % PEAK_VFX)
		return
	_finish(now)


func _tick_save(now: int) -> void:
	if _late(now):
		return
	var maps: Array[Node] = get_tree().root.find_children("", "WorldMapScreen", true, false)
	var fights: Array[Node] = get_tree().root.find_children("", "CombatScreen", true, false)
	if maps.is_empty() and fights.is_empty():
		return
	_interactive_ms = float(now - _started_us) / 1000.0
	_finish(now)


func _sample(now: int, dest: Array[float]) -> void:
	dest.append(float(now - _last_us) / 1000.0)
	_renderer_peak = maxf(_renderer_peak,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))


func _late(now: int) -> bool:
	if float(now - _phase_us) <= WAIT_S * 1000000.0:
		return false
	_fail("timed out waiting for the next surface")
	return true


func _finish(now: int) -> void:
	_phase = Phase.DONE
	var win: Vector2i = get_tree().root.size
	var se2: Vector2i = StageShape.stage_size(&"phone-landscape", SE2_WINDOW)
	var pad: Vector2i = StageShape.stage_size(&"pad-landscape", IPAD8_WINDOW)
	var first: Array[float] = _window(_combat_ms, _combat_us, _phase_us,
		_phase_us + int(SUSTAIN_S * 1000000.0))
	var last: Array[float] = _window(_combat_ms, _combat_us,
		now - int(SUSTAIN_S * 1000000.0), now)
	var combat_s: float = float(now - _phase_us) / 1000000.0
	var is_save: bool = str(_req["leg"]) == "save"
	var scored: bool = not is_save and combat_s >= SUSTAIN_S * 2.0
	var pacing: Variant = null
	var save_ok: Variant = null
	if not is_save:
		pacing = pacing_ok(_combat_ms)
	else:
		save_ok = _interactive_ms > 0.0 and _interactive_ms <= 2000.0
	var report: Dictionary = {
		"schema": 1,
		"ticket": 172,
		"leg": _req["leg"],
		"locale": _req["locale"],
		"commit": _req["commit"],
		"provenance": {
			"godot": Engine.get_version_info(),
			"os": OS.get_name(),
			"architecture": Engine.get_architecture_name(),
			"renderer": RenderingServer.get_video_adapter_name(),
			"method": RenderingServer.get_current_rendering_method(),
			"release": not OS.is_debug_build(),
		},
		"fill": {
			"window": [win.x, win.y],
			"se2_stage": [se2.x, se2.y],
			"ipad8_stage": [pad.x, pad.y],
			"note": "iPad 8 composite is ~3.75× iPhone SE 2; never substitute",
		},
		"map": _summary(_map_ms),
		"combat": _summary(_combat_ms),
		"vfx": _vfx,
		"renderer_peak_mib": _renderer_peak / 1048576.0,
		"save_interactive_ms": _interactive_ms,
		"sustained_scored": scored,
		"sustained": {
			"first5": _summary(first),
			"last5": _summary(last),
			"ok": scored and sustained_ok(first, last),
		},
		"pacing_ok": pacing,
		"save_ok": save_ok,
		"instruments": {
			"thermal": null, "battery_points": null, "phys_footprint": null,
		},
	}
	var json: FileAccess = FileAccess.open(JSON_PATH, FileAccess.WRITE)
	if json == null:
		_fail("cannot write " + JSON_PATH)
		return
	json.store_string(JSON.stringify(report) + "\n")
	json.flush()
	json.close()
	_p("FLOOR_RESULT " + JSON.stringify({
		"pacing_ok": report["pacing_ok"],
		"sustained_scored": scored,
		"save_interactive_ms": _interactive_ms,
		"combat": report["combat"],
	}))
	_p("FLOOR_DONE")
	get_tree().quit(0)


static func request(args: PackedStringArray) -> Dictionary:
	var soak: float = DEFAULT_SOAK_S
	var map_s: float = DEFAULT_MAP_S
	var leg: String = "route"
	var locale: String = ""
	var commit: String = ""
	var seen_profile: bool = false
	for arg: String in args:
		if arg == "--floor-profile":
			seen_profile = true
		elif arg.begins_with("--soak-seconds="):
			soak = float(arg.trim_prefix("--soak-seconds="))
		elif arg.begins_with("--map-seconds="):
			map_s = float(arg.trim_prefix("--map-seconds="))
		elif arg.begins_with("--leg="):
			leg = arg.trim_prefix("--leg=")
		elif arg.begins_with("--locale="):
			locale = arg.trim_prefix("--locale=")
		elif arg.begins_with("--perf-commit="):
			commit = arg.trim_prefix("--perf-commit=").to_lower()
	if not seen_profile:
		return {"error": "missing --floor-profile"}
	if locale != "en" and locale != "zh-Hant":
		return {"error": "missing --locale=en|zh-Hant"}
	if leg != "route" and leg != "save":
		return {"error": "--leg wants route|save"}
	if soak < 1.0 or map_s < 0.5:
		return {"error": "soak/map duration too short"}
	if leg == "route" and map_s >= soak:
		return {"error": "--map-seconds must be < --soak-seconds"}
	if not commit.is_empty() and (commit.length() != 40 \
			or not commit.is_valid_hex_number(false)):
		return {"error": "invalid --perf-commit"}
	return {"soak": soak, "map": map_s, "leg": leg, "locale": locale,
		"commit": commit}


static func miss_rate(frames: Array[float], deadline: float) -> float:
	if frames.is_empty():
		return 0.0
	var n: int = 0
	for frame: float in frames:
		if frame > deadline:
			n += 1
	return 100.0 * float(n) / float(frames.size())


static func pacing_ok(frames: Array[float]) -> bool:
	if frames.is_empty():
		return false
	return Bench.percentile(frames, 0.95) <= GATE_P95_MS \
		and Bench.percentile(frames, 0.99) <= GATE_P99_MS \
		and Bench.maximum(frames) <= GATE_MAX_MS \
		and miss_rate(frames, GATE_P95_MS) <= GATE_MISS_PCT


static func sustained_ok(first: Array[float], last: Array[float]) -> bool:
	if first.is_empty() or last.is_empty():
		return false
	var fp: float = Bench.percentile(first, 0.95)
	var lp: float = Bench.percentile(last, 0.95)
	var fm: float = miss_rate(first, GATE_P95_MS)
	var lm: float = miss_rate(last, GATE_P95_MS)
	if fp <= 0.0:
		return lp <= GATE_P95_MS
	return lp <= fp * 1.10 and lm <= maxf(fm * 1.10, fm)


static func _window(frames: Array[float], times: Array[int],
		start_us: int, end_us: int) -> Array[float]:
	var out: Array[float] = []
	for i: int in range(mini(frames.size(), times.size())):
		if times[i] >= start_us and times[i] < end_us:
			out.append(frames[i])
	return out


static func _summary(frames: Array[float]) -> Dictionary:
	return {
		"n": frames.size(),
		"p50": Bench.percentile(frames, 0.50),
		"p90": Bench.percentile(frames, 0.90),
		"p95": Bench.percentile(frames, 0.95),
		"p99": Bench.percentile(frames, 0.99),
		"max": Bench.maximum(frames),
		"miss_pct": miss_rate(frames, GATE_P95_MS),
		"pacing_ok": pacing_ok(frames),
	}


func _p(line: String) -> void:
	print(line)
	if _report != null:
		_report.store_line(line)
		_report.flush()


func _fail(message: String) -> void:
	_p("FLOOR_ERROR " + message)
	push_error("bench_floor_profile: " + message)
	_phase = Phase.DONE
	set_process(false)
	get_tree().quit(2)
