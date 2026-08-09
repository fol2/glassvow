class_name Preferences
extends RefCounted
## Player-facing settings persisted at user://settings.cfg — audio (Master/
## Music/SFX), display (fullscreen, vsync) and motion (screen shake, reduce
## motion). Supersedes the audio-only user://audio.cfg: its values are
## imported once, the first time this file is created, and never re-read.
##
## `active` is the main-owned handle (SKILL §2: no autoloads). Main replaces
## it with the disk-backed instance at boot; the default is an in-memory
## instance holding the same defaults, so labs and tests that never boot main
## read sane values and can never write the player's real settings file.

const PATH: String = "user://settings.cfg"
const LEGACY_AUDIO_PATH: String = "user://audio.cfg"

const MASTER: StringName = &"Master"
const MUSIC: StringName = &"Music"
const SFX: StringName = &"SFX"

const DEFAULT_MASTER: float = 1.0
const DEFAULT_MUSIC: float = 0.35
const DEFAULT_SFX: float = 0.55

static var active: Preferences = Preferences.new()

var master_volume: float = DEFAULT_MASTER
var music_volume: float = DEFAULT_MUSIC
var sfx_volume: float = DEFAULT_SFX
var master_muted: bool = false
var music_muted: bool = false
var sfx_muted: bool = false

var fullscreen: bool = false
var vsync: bool = true
var screen_shake: bool = true
var reduce_motion: bool = false
## Empty = derive from OS (`zh*` → zh-Hant, else en). Explicit `en` / `zh-Hant`
## overrides. Persisted under [locale] language.
var language: String = ""

## Only the instance read from disk writes back to disk; the default `active`
## stand-in stays in memory whatever a lab does to it.
var _persistent: bool = false
var _path: String = PATH


static func read_from_disk(path: String = PATH,
		legacy_audio_path: String = LEGACY_AUDIO_PATH) -> Preferences:
	var preferences: Preferences = Preferences.new()
	preferences._path = path
	preferences._persistent = true
	var config: ConfigFile = ConfigFile.new()
	if config.load(path) == OK:
		preferences._read(config)
	else:
		# First boot on the new file: carry the old audio.cfg choices over,
		# then store immediately so the import happens exactly once —
		# settings.cfg owns every key from here on.
		preferences._import_legacy(legacy_audio_path)
		preferences._store()
	preferences.apply_audio()
	return preferences


func volume(bus: StringName) -> float:
	match bus:
		MASTER: return master_volume
		MUSIC: return music_volume
		SFX: return sfx_volume
	return 1.0


func is_muted(bus: StringName) -> bool:
	match bus:
		MASTER: return master_muted
		MUSIC: return music_muted
		SFX: return sfx_muted
	return false


func set_volume(bus: StringName, value: float) -> void:
	var clamped: float = clampf(value, 0.0, 1.0)
	match bus:
		MASTER: master_volume = clamped
		MUSIC: music_volume = clamped
		SFX: sfx_volume = clamped
		_:
			push_warning("preferences: unknown bus '%s'" % bus)
			return
	_apply_bus(bus)
	_store()


func set_muted(bus: StringName, value: bool) -> void:
	match bus:
		MASTER: master_muted = value
		MUSIC: music_muted = value
		SFX: sfx_muted = value
		_:
			push_warning("preferences: unknown bus '%s'" % bus)
			return
	_apply_bus(bus)
	_store()


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	apply_display()
	_store()


func set_vsync(on: bool) -> void:
	vsync = on
	apply_display()
	_store()


func set_screen_shake(on: bool) -> void:
	screen_shake = on
	_store()


func set_reduce_motion(on: bool) -> void:
	reduce_motion = on
	_store()


func set_language(code: String) -> void:
	language = code
	_store()


## Resolves the catalogue code Preferences wants Locale to load.
func effective_language() -> StringName:
	return resolve_language(language, OS.get_locale_language())


## Pure resolver: an explicit player choice wins; otherwise the OS language
## selects Traditional Chinese for any zh locale and English for everything else.
static func resolve_language(saved: String, os_language: String) -> StringName:
	if saved == "en" or saved == "zh-Hant":
		return StringName(saved)
	if os_language.begins_with("zh"):
		return Locale.CODE_ZH_HANT
	return Locale.CODE_EN


func apply_audio() -> void:
	_apply_bus(MASTER)
	_apply_bus(MUSIC)
	_apply_bus(SFX)


## Window mode is applied only where main decides the window is the player's
## (a plain boot) — capture rigs and labs own their windows and never call
## this, so a saved fullscreen choice cannot hijack a screenshot run.
func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen
		else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)


func _read(config: ConfigFile) -> void:
	master_volume = _volume_value(
		config.get_value("audio", "master_volume", DEFAULT_MASTER), DEFAULT_MASTER)
	music_volume = _volume_value(
		config.get_value("audio", "music_volume", DEFAULT_MUSIC), DEFAULT_MUSIC)
	sfx_volume = _volume_value(
		config.get_value("audio", "sfx_volume", DEFAULT_SFX), DEFAULT_SFX)
	master_muted = _bool_value(config.get_value("audio", "master_muted", false), false)
	music_muted = _bool_value(config.get_value("audio", "music_muted", false), false)
	sfx_muted = _bool_value(config.get_value("audio", "sfx_muted", false), false)
	fullscreen = _bool_value(config.get_value("display", "fullscreen", false), false)
	vsync = _bool_value(config.get_value("display", "vsync", true), true)
	screen_shake = _bool_value(config.get_value("motion", "screen_shake", true), true)
	reduce_motion = _bool_value(
		config.get_value("motion", "reduce_motion", false), false)
	language = str(config.get_value("locale", "language", ""))


func _import_legacy(legacy_audio_path: String) -> void:
	var legacy: ConfigFile = ConfigFile.new()
	if legacy.load(legacy_audio_path) != OK:
		return
	music_volume = _volume_value(
		legacy.get_value("music", "volume", DEFAULT_MUSIC), DEFAULT_MUSIC)
	sfx_volume = _volume_value(
		legacy.get_value("sfx", "volume", DEFAULT_SFX), DEFAULT_SFX)
	music_muted = _bool_value(legacy.get_value("music", "muted", false), false)
	sfx_muted = _bool_value(legacy.get_value("sfx", "muted", false), false)


static func _volume_value(value: Variant, fallback: float) -> float:
	if value is float or value is int:
		return clampf(str(value).to_float(), 0.0, 1.0)
	return fallback


static func _bool_value(value: Variant, fallback: bool) -> bool:
	if value is bool:
		return value
	return fallback


func _apply_bus(bus: StringName) -> void:
	var index: int = AudioServer.get_bus_index(bus)
	if index < 0:
		push_warning("preferences: missing bus '%s'" % bus)
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume(bus), 0.0001)))
	AudioServer.set_bus_mute(index, is_muted(bus))


func _store() -> void:
	if not _persistent:
		return
	var config: ConfigFile = ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "master_muted", master_muted)
	config.set_value("audio", "music_muted", music_muted)
	config.set_value("audio", "sfx_muted", sfx_muted)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "vsync", vsync)
	config.set_value("motion", "screen_shake", screen_shake)
	config.set_value("motion", "reduce_motion", reduce_motion)
	config.set_value("locale", "language", language)
	var error: Error = config.save(_path)
	if error != OK:
		push_warning("preferences: could not save (%s)" % error_string(error))
