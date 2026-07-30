class_name AudioPreferences
extends RefCounted
## Persisted Music/SFX controls. The benchmark keeps these independently too.

const PATH: String = "user://audio.cfg"
const MUSIC: StringName = &"Music"
const SFX: StringName = &"SFX"
const DEFAULT_MUSIC: float = 0.35
const DEFAULT_SFX: float = 0.55

var music_volume: float = DEFAULT_MUSIC
var sfx_volume: float = DEFAULT_SFX
var music_muted: bool = false
var sfx_muted: bool = false


static func read_from_disk() -> AudioPreferences:
	var preferences: AudioPreferences = AudioPreferences.new()
	var config: ConfigFile = ConfigFile.new()
	if config.load(PATH) == OK:
		var music_volume_value: Variant = config.get_value(
			"music", "volume", DEFAULT_MUSIC)
		var sfx_volume_value: Variant = config.get_value("sfx", "volume", DEFAULT_SFX)
		var music_muted_value: Variant = config.get_value("music", "muted", false)
		var sfx_muted_value: Variant = config.get_value("sfx", "muted", false)
		preferences.music_volume = _volume_value(music_volume_value, DEFAULT_MUSIC)
		preferences.sfx_volume = _volume_value(sfx_volume_value, DEFAULT_SFX)
		if music_muted_value is bool:
			preferences.music_muted = music_muted_value
		if sfx_muted_value is bool:
			preferences.sfx_muted = sfx_muted_value
	preferences.apply()
	return preferences


static func _volume_value(value: Variant, fallback: float) -> float:
	if value is float or value is int:
		return clampf(str(value).to_float(), 0.0, 1.0)
	return fallback


func volume(bus: StringName) -> float:
	return music_volume if bus == MUSIC else sfx_volume


func is_muted(bus: StringName) -> bool:
	return music_muted if bus == MUSIC else sfx_muted


func set_volume(bus: StringName, value: float) -> void:
	if bus == MUSIC:
		music_volume = clampf(value, 0.0, 1.0)
	elif bus == SFX:
		sfx_volume = clampf(value, 0.0, 1.0)
	else:
		push_warning("audio preferences: unknown bus '%s'" % bus)
		return
	_apply_bus(bus)
	_store()


func set_muted(bus: StringName, value: bool) -> void:
	if bus == MUSIC:
		music_muted = value
	elif bus == SFX:
		sfx_muted = value
	else:
		push_warning("audio preferences: unknown bus '%s'" % bus)
		return
	_apply_bus(bus)
	_store()


func apply() -> void:
	_apply_bus(MUSIC)
	_apply_bus(SFX)


func _apply_bus(bus: StringName) -> void:
	var index: int = AudioServer.get_bus_index(bus)
	if index < 0:
		push_warning("audio preferences: missing bus '%s'" % bus)
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume(bus), 0.0001)))
	AudioServer.set_bus_mute(index, is_muted(bus))


func _store() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("music", "volume", music_volume)
	config.set_value("music", "muted", music_muted)
	config.set_value("sfx", "volume", sfx_volume)
	config.set_value("sfx", "muted", sfx_muted)
	var error: Error = config.save(PATH)
	if error != OK:
		push_warning("audio preferences: could not save (%s)" % error_string(error))
