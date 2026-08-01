extends SceneTree
## Stage 5 of docs/reward-embers-3d-plan.md: the reward room, priced with the
## SAME instruments as the actor stage (tools/bench_actor_stage.gd) — the
## plan forbids calling the stage done before this number exists. One stage
## for the whole screen was the cost argument; this is the receipt.
##
## Not a test (needs a real renderer — never --headless):
##   godot --path . -s res://tools/bench_reward_stage.gd

const WARMUP_FRAMES: int = 90
const SAMPLE_FRAMES: int = 180

var _stage: RewardStage = null
var _frame: int = 0
var _vram_before: float = 0.0
var _samples: Array[float] = []
var _burst_done: bool = false


func _initialize() -> void:
	var host: Control = Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	_vram_before = Performance.get_monitor(
		Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	_stage = RewardStage.new("duskfang", 22.0)
	host.add_child(_stage)
	print("reward-stage probe — warmup %d, sample %d frames"
		% [WARMUP_FRAMES, SAMPLE_FRAMES])


var _vp_rid: RID


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 1:
		# The clock is enabled ONCE, before anything is sampled — enabling it
		# inside the loop guaranteed the first read was zero by construction.
		_vp_rid = _stage.get_viewport_rid_for_bench()
	if _frame == WARMUP_FRAMES:
		# The expensive frame is the HOLD: sixteen-odd prisms, not one quad.
		_stage.shatter()
		_burst_done = true
	if _burst_done and _frame > WARMUP_FRAMES + 90 \
			and _samples.size() < SAMPLE_FRAMES:
		var us: float = RenderingServer.viewport_get_measured_render_time_gpu(_vp_rid) \
			+ RenderingServer.viewport_get_measured_render_time_cpu(_vp_rid)
		_samples.append(us)
	if _samples.size() >= SAMPLE_FRAMES:
		var vram_now: float = Performance.get_monitor(
			Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
		_samples.sort()
		var median: float = _samples[_samples.size() / 2]
		var p95: float = _samples[int(float(_samples.size()) * 0.95)]
		print("reward stage VRAM: %.1f MB (before %.1f, after %.1f)"
			% [vram_now - _vram_before, _vram_before, vram_now])
		if p95 <= 0.0:
			# source-existing-is-not-rendering, applied to instruments: a
			# clock that reads zero has not measured — it must never print a
			# zero a reader would take for "free".
			print("hold frame, stage viewport: UNAVAILABLE on this driver path")
		else:
			print("hold frame, stage viewport: median %.3f ms  p95 %.3f ms"
				% [median / 1000.0, p95 / 1000.0])
		quit(0)
	return false
