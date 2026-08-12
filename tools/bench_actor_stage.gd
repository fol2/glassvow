extends SceneTree
## Frame-budget probe for the per-actor 3D stage.
##
## `docs/commercial-game-delivery.md` §5 records the proposed combat frame
## threshold. This component diagnostic does not grant release clearance. Every
## actor builds its own `SubViewport` with
## `own_world_3d`, MSAA 4x, a `ProceduralSkyMaterial` feeding both ambient and
## reflections, three lights, and `render_target_update_mode = UPDATE_ALWAYS`
## — so N actors are N separate 3D worlds re-rendered every frame
## (`enemy_view.gd:384-450`). `docs/actor-animation-checklist.md` §5.4 flags this
## as a scaling concern. This probe isolates that component; the exported
## whole-product matrix remains the release evidence.
##
## Not a test: `tests/run_all.gd` only discovers `res://tests/test_*.gd`, so this
## never joins the suite. It needs a real renderer — do NOT run it `--headless`,
## which swaps in the dummy driver and reports a cost no player would ever pay.
##
##   godot --path . -s res://tools/bench_actor_stage.gd -- --actors=1,3,6,12,29
##
## Reports the MEDIAN and p95, not the mean: a mean folds the shader-compile
## hitches of the first seconds into a number meant to describe the steady state.
## The figure is the engine's own per-viewport GPU timer summed over the window
## and every actor stage — see `_process` for why the wall-clock delta cannot
## answer this question.

const DEFAULT_COUNTS: Array[int] = [1, 3, 6, 12, 29]
const WARMUP_FRAMES: int = 90
const SAMPLE_FRAMES: int = 180

## A fixed slice of the roster, taken in this order so a 3-actor run is always
## the same three. Random picks would make two runs incomparable.
const ROSTER: Array[StringName] = [
	&"sporeling", &"duskfang", &"gloomslime", &"shade", &"siren",
	&"mirelurker", &"rootheart", &"shellback", &"ashAcolyte", &"drownedOne",
	&"alphaFang", &"chaosHound", &"deepmaw", &"gravewarden", &"obsidianGolem",
	&"abyssalKnight", &"heraldOfEnd", &"leviathan", &"sovereign",
]

var _counts: Array[int] = []
var _stage_i: int = 0
var _frame: int = 0
var _samples: Array[float] = []
var _cpu: Array[float] = []
var _gpu: Array[float] = []
var _rows: Array[Dictionary] = []
var _host: Control = null
## Total stage pixels standing this round — the load the render actually carries,
## which actor COUNT only stands in for because the roster's art boxes differ.
var _px: int = 0
## -1 leaves whatever the view chose; 0/2/4 override it. Indexes MSAA_MODES.
var _msaa: int = -1

const MSAA_MODES: Dictionary = {
	0: Viewport.MSAA_DISABLED, 2: Viewport.MSAA_2X, 4: Viewport.MSAA_4X,
}
## Every viewport whose cost belongs to this frame: the window, plus one per
## actor. Held as RIDs because that is what the measurement API takes.
var _vps: Array[RID] = []


## `--actors=1,3,6` overrides the ladder. Anything unparseable falls back rather
## than running an empty ladder and printing a table with no rows.
func _parse_counts() -> Array[int]:
	var out: Array[int] = []
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--actors="):
			continue
		for part: String in arg.trim_prefix("--actors=").split(",", false):
			if part.strip_edges().is_valid_int():
				out.append(int(part))
	return out if not out.is_empty() else DEFAULT_COUNTS


## `--oversample=1.5` prices the one lever that needs no edit to another lane's
## file: `EnemyView.oversample` is a static var, and stage pixels — hence render
## target memory — go as its SQUARE.
func _apply_oversample() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--oversample="):
			EnemyView.oversample = float(arg.trim_prefix("--oversample="))
		elif arg.begins_with("--msaa="):
			var m: int = int(arg.trim_prefix("--msaa="))
			_msaa = m if MSAA_MODES.has(m) else -1


func _initialize() -> void:
	_counts = _parse_counts()
	_apply_oversample()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	root.size = Vector2i(1920, 1080)

	_host = Control.new()
	_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_host)

	print("actor-stage component probe — %s"
		% RenderingServer.get_video_adapter_name())
	if OS.get_cmdline_user_args().has("--textures"):
		_price_textures()
	print("oversample=%.2f  VP_MAX=%d  MSAA=%s  update=ALWAYS\n" % [
		EnemyView.oversample, EnemyView.VP_MAX,
		"as authored (4x)" if _msaa < 0 else "%dx (overridden)" % _msaa])
	_build(_counts[0])


## `--textures` prices the OTHER half of the memory question. Every texture in
## this project imports at `compress/mode=0` (lossless) — 245 of them, none GPU
## block-compressed — so each is resident as uncompressed RGBA8 at w×h×4.
## Whether that
## matters more than the stages is not a thing to reason about; it is a thing to
## load and read off the meter. Held in a static so the loads are not collected
## between the read and the print.
static var _held: Array[Texture2D] = []


func _price_textures() -> void:
	var before: float = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	# Parallel PackedStringArrays, not an array of arrays: element access on a
	# packed array is typed String, where `Array[i]` is a Variant that this
	# project's warnings-as-errors will not pass to `DirAccess.open`.
	var labels: PackedStringArray = PackedStringArray([
		"cards", "enemies", "stage", "ui", "statuses"])
	var dirs: PackedStringArray = PackedStringArray([
		"res://assets/art/cards", "res://assets/art/enemies",
		"res://assets/art/stage", "res://assets/art/ui",
		"res://assets/art/statuses"])
	for i: int in labels.size():
		var label: String = labels[i]
		var root_dir: String = dirs[i]
		var dir: DirAccess = DirAccess.open(root_dir)
		if dir == null:
			continue
		var n: int = 0
		var mark: float = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
		dir.list_dir_begin()
		var f: String = dir.get_next()
		while f != "":
			if not dir.current_is_dir() and (f.ends_with(".png") or f.ends_with(".jpg")):
				var tex: Texture2D = load("%s/%s" % [root_dir, f]) as Texture2D
				if tex != null:
					_held.append(tex)
					n += 1
			f = dir.get_next()
		# Textures upload lazily; force the frame that does it before reading.
		RenderingServer.force_draw()
		var now: float = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
		print("  %-8s %3d textures  +%7.1f renderer MiB" % [label, n, now - mark])
	RenderingServer.force_draw()
	var after: float = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	print("  ---------------------------------------")
	print("  every source texture resident: %.1f renderer MiB (was %.1f)\n"
		% [after, before])
	_held.clear()


## Actors are laid out on a grid so none is clipped out of the window — an actor
## outside the viewport is still rendered (its SubViewport does not know where it
## sits), but clipping would make the DRAW-CALL column a lie.
func _build(n: int) -> void:
	for child: Node in _host.get_children():
		_host.remove_child(child)
		child.queue_free()
	var cols: int = int(ceilf(sqrt(float(n))))
	var cell: Vector2 = _host.size / Vector2(float(cols), float(cols))
	var px: int = 0
	_vps = [root.get_viewport_rid()]
	for i: int in n:
		var art: StringName = ROSTER[i % ROSTER.size()]
		var view: EnemyView = EnemyView.new(i, String(art), 210.0, art)
		view.position = Vector2(float(i % cols), float(i / cols)) * cell
		_host.add_child(view)
		px += _collect_stage(view)
	for rid: RID in _vps:
		RenderingServer.viewport_set_measure_render_time(rid, true)
	_px = px
	_frame = 0
	_samples.clear()
	_cpu.clear()
	_gpu.clear()
	print("  building %2d actors … %d total stage pixels" % [n, px])


## The SubViewport is a child of the view; read its real size rather than
## recomputing the formula, so this stays honest if the sizing changes. Registers
## the stage for measurement on the way past — an actor's cost is its own
## viewport's, and the window's figure does not include it.
func _collect_stage(view: Control) -> int:
	for child: Node in view.get_children():
		if child is SubViewport:
			var vp: SubViewport = child as SubViewport
			# `--msaa=0|2|4` prices the other big lever. Set here, AFTER the view
			# has built itself, rather than by editing `enemy_view.gd` — that file
			# belongs to another lane and a benchmark must not need a change in
			# the thing it is benchmarking.
			if _msaa >= 0:
				vp.msaa_3d = MSAA_MODES[_msaa]
			_vps.append(vp.get_viewport_rid())
			return vp.size.x * vp.size.y
	return 0


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame <= WARMUP_FRAMES:
		return false
	# NOT the wall-clock delta. A first pass sampled `delta` and every row under
	# ~10 ms came back as exactly 5.56 or 8.33 ms — 1/180 and 1/120 — because the
	# figure was quantised by presentation, not by work. The engine's per-viewport
	# render timers are independent of when the frame is shown, which is the only
	# way to read a cost below the refresh interval.
	#
	# Summed across the window AND every actor stage: a SubViewport is a separate
	# viewport with its own pass, so the window's own figure excludes exactly the
	# thing being measured.
	var gpu: float = 0.0
	var cpu: float = 0.0
	for rid: RID in _vps:
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
	_gpu.append(gpu)
	# Kept alongside, not instead: the gap between the two says whether a miss is
	# CPU or GPU bound, which is the difference between optimising the script and
	# cutting the render.
	_cpu.append(cpu)
	# Wall-clock is kept as well because the GPU timer is not implemented on every
	# backend — Metal reports a flat 0. Wall-clock is quantised by presentation
	# and so only means anything once the work exceeds the refresh interval, but
	# above that line it is the only figure left that sees the GPU at all.
	_samples.append(_delta * 1000.0)
	if _samples.size() < SAMPLE_FRAMES:
		return false

	_record(_counts[_stage_i])
	_stage_i += 1
	if _stage_i >= _counts.size():
		_report()
		return true
	_build(_counts[_stage_i])
	return false


func _record(n: int) -> void:
	_samples.sort()
	_cpu.sort()
	_gpu.sort()
	_rows.append({
		"n": n,
		"med": _samples[_samples.size() / 2],
		"p95": _samples[int(float(_samples.size()) * 0.95)],
		"cpu": _cpu[_cpu.size() / 2],
		"gpu": _gpu[_gpu.size() / 2],
		"px": _px,
		"draw": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"renderer_mib": Performance.get_monitor(
			Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
	})


func _report() -> void:
	print("\n actors | wall ms | p95 ms | render CPU | GPU ms | stage Mpx | draw | renderer MiB")
	print(" -------|---------|--------|------------|--------|-----------|------|-------------")
	var gpu_dead: bool = true
	for r: Dictionary in _rows:
		# Typed locals first: a Dictionary read is a Variant, and this project
		# treats warnings as errors.
		var med: float = r["med"]
		var gpu: float = r["gpu"]
		var px: int = r["px"]
		if gpu > 0.0:
			gpu_dead = false
		print(" %6d | %7.2f | %6.2f | %10.2f | %6.2f | %9.1f | %4.0f | %12.1f" % [
			r["n"], med, r["p95"], r["cpu"], gpu, float(px) / 1048576.0,
			r["draw"], r["renderer_mib"]])
	if gpu_dead:
		print("\nGPU ms read 0 on every row: this backend does not implement GPU")
		print("timestamp queries (Metal is one). The GPU column is UNMEASURED, not")
		print("free. Wall-clock is the only figure here that sees the GPU, and it")
		print("is floored by the refresh interval — a row at exactly 1/120 or 1/180")
		print("means 'below the floor', not 'this is the cost'.")
	print("\nRenderer allocation and draw calls are adapter- and backend-specific")
	print("diagnostics from this run; neither proves another device or driver.")
	print("This component probe is not whole-product release clearance.")
