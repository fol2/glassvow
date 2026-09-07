extends Node
## Excluded release-template probe of the actual scenario-routed campaign map.
## Explicitly requested only; writes raw samples and native captures, then exits.
var host: Main
var reference: ScenarioReference
var output: String
var _frames: Array[float] = []
var _cpu: Array[float] = []
var _gpu: Array[float] = []
var _memory: Array[float] = []

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	if OS.is_debug_build() or DisplayServer.get_name()=="headless":
		_fail("Journey performance requires a native release template")
		return
	var started: int = Time.get_ticks_usec()
	var deadline: int = Time.get_ticks_msec()+180000
	while host._map_screen==null or host._map_loading:
		if Time.get_ticks_msec()>deadline:
			_fail("Scenario map did not become ready")
			return
		await get_tree().process_frame
	var screen: WorldMapScreen = host._map_screen
	if screen.layout_result()==null or screen._layout_compile.is_valid():
		_fail("Scenario did not bind a production map")
		return
	var source: String = screen.layout_input_digest()
	var realised: String = screen.layout_digest()
	var ready_ms: float = (Time.get_ticks_usec()-started)/1000.0
	var stage: SubViewport = screen._map_scene.get_stage()
	RenderingServer.viewport_set_measure_render_time(stage.get_viewport_rid(),true)
	for i: int in range(300): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.get_basename()+"-journey.png")
	var last: int = Time.get_ticks_usec()
	var sampling: int = last
	while _frames.size()<600 or Time.get_ticks_usec()-sampling<10000000:
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		_frames.append((now-last)/1000.0)
		last=now
		_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(stage.get_viewport_rid()))
		_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(stage.get_viewport_rid()))
		_memory.append(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
	# Readability capture uses the same navigation command as the visible button.
	screen._journey_zoom(true)
	for i: int in range(90): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.get_basename()+"-overview.png")
	var report: Dictionary = {
		"schema":1,"claim":"Release native campaign map steady-state; no combat or touch claim",
		"reference":reference.encode(),"engine":Engine.get_version_info(),
		"os":OS.get_name(),"os_version":OS.get_version(),"model":OS.get_model_name(),
		"renderer":RenderingServer.get_video_adapter_name(),"method":RenderingServer.get_current_rendering_method(),
		"debug":OS.is_debug_build(),"shape":host._shape,"viewport":str(get_viewport().get_visible_rect().size),
		"act":host.game.run.act,"input_digest":source,"layout_digest":realised,
		"ready_wait_ms":ready_ms,"derived_cache":screen._map_scene.layout_diagnostics().get("derived_cache_hit",false),
		"binding":screen.layout_diagnostics().get("binding_stages_ms",{}),
		"assembly":screen._map_scene.layout_diagnostics().get("assembly_ms",{}),
		"frames_ms":_frames,"render_cpu_ms":_cpu,"render_gpu_ms":_gpu,"renderer_bytes":_memory,
		"summary":{"samples":_frames.size(),"frame_p95_ms":_p95(_frames),"render_cpu_p95_ms":_p95(_cpu),
			"render_gpu_p95_ms":_p95(_gpu),"renderer_peak_mib":_memory.max()/1048576.0},
		"identity_stable":source==screen.layout_input_digest() and realised==screen.layout_digest(),
	}
	var file: FileAccess = FileAccess.open(output,FileAccess.WRITE)
	if file==null:
		_fail("Cannot write journey measurement")
		return
	file.store_string(JSON.stringify(report))
	file.close()
	print("JOURNEY_MEASURE ",JSON.stringify(report["summary"]))
	get_tree().quit(0 if report["identity_stable"] else 1)

func _p95(values: Array[float]) -> float:
	var ordered: Array[float] = values.duplicate()
	ordered.sort()
	return ordered[mini(ordered.size()-1,int(ordered.size()*.95))]

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(2)
