class_name SfxBus
extends Node
## The sound of the fight. A port of `src/audio.js`, minus the synth.
##
## The benchmark ships two things behind `sfx.<id>()`: a bank of 36 ElevenLabs
## samples (pack `ashglass-v1`), and a WebAudio oscillator fallback for when the
## sample has not finished loading. Only the samples are ported. The fallback
## exists because a browser fetches its audio over the network and the first
## click can beat the download; a Godot project has its bank on disk before the
## window opens, so the branch it guards cannot be reached.
##
## `audio.js` runs every one-shot through a shared gain node — bus 0.55, source
## 0.85 — and lets them overlap freely, a fresh BufferSource per call. The
## Godot `SFX` bus carries the first gain (and the persisted setting). A
## `AudioStreamPlayer` plays one stream at a time, so overlap comes from a pool
## instead.

const DIR: String = "res://assets/audio/sfx/%s.mp3"

## The per-source gain `playSample` applies. The bus owns `DEFAULT_VOL`.
const SOURCE_GAIN: float = 0.85

## A draw wave staggers five flights, each of which may land on a pile bump
## while a hit is still ringing. Twelve voices covers the worst honest overlap
## without pre-allocating for a case the fight cannot produce.
const VOICES: int = 12

## `attackKey` (audio.js:280): the tier is `amount + blocked`, so a blow that
## was entirely soaked still sounds like the blow it was.
const HEAVY_AT: int = 16
const LIGHT_AT: int = 5

var muted: bool = false

## Typed so a cache read is an `AudioStream` rather than a `Variant` that has
## to be cast back to one.
var _streams: Dictionary[StringName, AudioStream] = {}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0


func _init() -> void:
	name = "SfxBus"
	# Headless runs the Dummy driver, where every `play()` is a silent no-op
	# that still costs a stream load and a voice. Tests and `--shot` captures
	# take the whole subsystem out rather than idle it.
	if DisplayServer.get_name() == "headless":
		muted = true
		return
	for i: int in range(VOICES):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = &"SFX"
		_players.append(p)
		add_child(p)


## One shot. Unknown ids are named rather than swallowed — a typo in a drain
## branch is otherwise a sound that silently never plays.
func play(id: StringName, gain: float = SOURCE_GAIN) -> void:
	if muted or _players.is_empty():
		return
	var stream: AudioStream = _stream(id)
	if stream == null:
		return
	# Round-robin rather than first-free: a voice that is still ringing is the
	# oldest one, and cutting it is what a twelve-deep pool is for.
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.volume_db = linear_to_db(maxf(0.0001, gain))
	p.play()


## `sfx.attack` (audio.js:287). `who` is &"hero" or &"enemy".
func attack(who: StringName, amount: int, blocked: int = 0) -> void:
	var weight: int = maxi(0, amount + blocked)
	var tier: String = "Med"
	if weight >= HEAVY_AT:
		tier = "Heavy"
	elif weight <= LIGHT_AT:
		tier = "Light"
	var prefix: String = "atkEnemy" if who == &"enemy" else "atkHero"
	play(StringName(prefix + tier))


func _stream(id: StringName) -> AudioStream:
	if _streams.has(id):
		return _streams[id]
	var path: String = DIR % id
	if not ResourceLoader.exists(path):
		push_warning("sfx: no sample for '%s'" % id)
		_streams[id] = null
		return null
	var stream: AudioStream = load(path)
	_streams[id] = stream
	return stream
