extends CanvasLayer
## Diagnostic overlay for live performance metrics. Development-only, excluded from release.
## Not release evidence. Never mutates game state.
## Ring buffer sampling: bounded O(1) memory, fixed ~256 bytes + frame array.

const SAMPLE_INTERVAL: float = 0.016  # ~60Hz samples
const HISTORY_DURATION: float = 10.0  # 10-second rolling window
const MAX_SAMPLES: int = int(ceil(HISTORY_DURATION / SAMPLE_INTERVAL))  # ~625 frames

var _samples: Array[float] = []  # Ring buffer of frame times
var _sample_index: int = 0
var _last_sample_time: float = 0.0
var _hitch_count: int = 0  # Frames >33ms (30fps hitch threshold)
var _start_time: float = 0.0

var _panel: PanelContainer = null
var _stats_label: Label = null


func _ready() -> void:
	layer = 127  # Top layer
	_start_time = Time.get_ticks_msec() / 1000.0
	_samples.resize(MAX_SAMPLES)
	for i: int in range(MAX_SAMPLES):
		_samples[i] = 0.0
	_build_ui()
	set_process(true)


func _process(delta: float) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_sample_time >= SAMPLE_INTERVAL:
		_last_sample_time = now
		var frame_ms: float = delta * 1000.0
		_samples[_sample_index] = frame_ms
		if frame_ms > 33.0:  # Hitch threshold: 30 fps
			_hitch_count += 1
		_sample_index = (_sample_index + 1) % MAX_SAMPLES
		_update_stats_display(frame_ms)


func _build_ui() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.position = Vector2(viewport_size.x - 240.0, 16.0)
	_panel.custom_minimum_size = Vector2(220.0, 160.0)
	_panel.add_theme_stylebox_override("panel", _style())
	add_child(_panel)
	
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_panel.add_child(margin)
	
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)
	
	var title: Label = Label.new()
	title.text = "DIAGNOSTICS (dev-only)"
	title.add_theme_font_override("font", GlassStyle.face(GlassStyle.CINZEL_500))
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	vbox.add_child(title)
	
	_stats_label = Label.new()
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats_label.add_theme_font_override("font", GlassStyle.face(GlassStyle.CINZEL_500))
	_stats_label.add_theme_font_size_override("font_size", 9)
	_stats_label.add_theme_color_override("font_color", Color.LIGHT_GREEN)
	vbox.add_child(_stats_label)


func _update_stats_display(current_frame_ms: float) -> void:
	if _stats_label == null:
		return
	
	var fps: float = 1.0 / maxf(0.001, get_process_delta_time())
	var p95: float = _calculate_p95()
	var memory_mb: float = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	var draw_calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME) as float)
	
	_stats_label.text = "FPS: %.1f\nFrame: %.1fms\nP95: %.1fms\nHitches: %d\nMem: %.1f MB\nDraw: %d" % [
		fps, current_frame_ms, p95, _hitch_count, memory_mb, draw_calls
	]


func _calculate_p95() -> float:
	var valid: Array[float] = []
	for sample: float in _samples:
		if sample > 0.0:
			valid.append(sample)
	
	if valid.is_empty():
		return 0.0
	
	valid.sort()
	var index: int = int(float(valid.size()) * 0.95 - 1.0) as int
	return valid[clampi(index, 0, valid.size() - 1)]


func _style() -> StyleBox:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	style.set_border_enabled_all(true)
	style.set_border_width_all(1)
	style.border_color = Color.DARK_GRAY
	style.set_corner_radius_all(4)
	return style
