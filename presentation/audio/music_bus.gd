class_name MusicBus
extends Node
## Two-player loop/crossfade layer matching the benchmark's Music Cue contract.

const DIR: String = "res://assets/audio/music/%s.mp3"
const CROSSFADE: float = 0.8
const SILENT_DB: float = -60.0
const FILES: Dictionary[StringName, String] = {
	&"title": "title",
	&"embark": "embark",
	&"vigil": "vigil",
	&"roseWindow": "rose-window",
	&"map": "map",
	&"safeNodes": "safe-nodes",
	&"act1Combat": "act1-combat",
	&"act1Boss": "act1-boss",
	&"act2Combat": "act2-combat",
	&"act2Boss": "act2-boss",
	&"act3Combat": "act3-combat",
	&"act3Boss": "act3-boss",
	&"elite": "elite",
	&"paleOnes": "pale-ones",
	&"shadeDuel": "shade-duel",
	&"usurper": "usurper",
	&"eighthOmen": "eighth-omen",
	&"unreadablePage": "unreadable-page",
	&"hollowLamplighter": "hollow-lamplighter",
	&"sealedDoor": "sealed-door",
	&"victory": "victory",
	&"defeat": "defeat",
}

var current_cue: StringName = &""

var _players: Array[AudioStreamPlayer] = []
var _active: int = 0
var _fade: Tween = null


func _init() -> void:
	name = "MusicBus"
	if DisplayServer.get_name() == "headless":
		return
	for index: int in range(2):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "Player%d" % (index + 1)
		player.bus = &"Music"
		player.volume_db = SILENT_DB
		_players.append(player)
		add_child(player)


func play(cue: StringName) -> void:
	if _players.is_empty():
		return
	if cue == current_cue and _players[_active].playing:
		return
	if not FILES.has(cue):
		push_warning("music: unknown cue '%s'" % cue)
		return
	var path: String = DIR % FILES[cue]
	if not ResourceLoader.exists(path):
		push_warning("music: no track for '%s'" % cue)
		return
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		return
	stream = stream.duplicate() as AudioStream
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true

	var outgoing: AudioStreamPlayer = _players[_active]
	var incoming_index: int = 1 - _active
	var incoming: AudioStreamPlayer = _players[incoming_index]
	if _fade != null and _fade.is_valid():
		_fade.kill()
	incoming.stop()
	incoming.stream = stream
	incoming.volume_db = SILENT_DB
	incoming.play()
	_fade = create_tween().set_parallel(true)
	_fade.tween_property(incoming, "volume_db", 0.0, CROSSFADE)
	if outgoing.playing:
		_fade.tween_property(outgoing, "volume_db", SILENT_DB, CROSSFADE)
		_fade.chain().tween_callback(func() -> void:
			outgoing.stop()
			outgoing.stream = null
		)
	_active = incoming_index
	current_cue = cue


func stop() -> void:
	current_cue = &""
	if _players.is_empty():
		return
	if _fade != null and _fade.is_valid():
		_fade.kill()
	var outgoing: AudioStreamPlayer = _players[_active]
	if not outgoing.playing:
		return
	_fade = create_tween()
	_fade.tween_property(outgoing, "volume_db", SILENT_DB, CROSSFADE)
	_fade.tween_callback(func() -> void:
		outgoing.stop()
		outgoing.stream = null
	)
