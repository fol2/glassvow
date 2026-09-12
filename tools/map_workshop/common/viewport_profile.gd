extends RefCounted
## Native timing only. Movie capture and physical-device claims are excluded.
static func measure(viewport: Viewport, frames: int = 120) -> Dictionary:
	var rid: RID = viewport.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid,true)
	for warmup: int in range(30):
		await RenderingServer.frame_post_draw
	var wall: Array[float] = []
	var cpu: Array[float] = []
	var gpu: Array[float] = []
	var previous: int = Time.get_ticks_usec()
	for frame: int in range(frames):
		await RenderingServer.frame_post_draw
		var now: int = Time.get_ticks_usec()
		wall.append((now-previous)/1000.0)
		previous = now
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
	RenderingServer.viewport_set_measure_render_time(rid,false)
	return {"frames":frames,"frame_interval_ms":_summary(wall),
		"render_cpu_ms":_summary(cpu),"render_gpu_ms":_summary(gpu),
		"gpu_timestamps_available":gpu.max()>0.0,
		"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"renderer_mib":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0,
		"scope":"desktop native stationary viewport; frame interval includes synchronisation; not device qualification"}

static func _summary(values: Array[float]) -> Dictionary:
	values.sort()
	return {"median":values[values.size()/2],"p95":values[mini(values.size()-1,ceili(values.size()*.95)-1)],"maximum":values[-1]}
