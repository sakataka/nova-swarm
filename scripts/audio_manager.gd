extends Node
class_name NovaAudioManager

const MUSIC_BANK_LABEL := "nova_swarm"
const MUSIC_VOLUME_DB := -14.0
const MUSIC_DUCK_DB := -24.0
const MUSIC_OVERDRIVE_DB := -10.0
const MUSIC_FADE_TIME := 1.25

const MUSIC_PATHS := {
	"title": "res://public/assets/audio/music/title_neon_loop.wav",
	"stage_drive": "res://public/assets/audio/music/stage_drive_loop.wav",
	"stage_pressure": "res://public/assets/audio/music/stage_pressure_loop.wav",
	"boss_core": "res://public/assets/audio/music/boss_core_loop.wav",
	"victory_clear": "res://public/assets/audio/music/victory_clear_loop.wav",
	"game_over": "res://public/assets/audio/music/game_over_loop.wav",
}

var muted := false
var current_music_key := ""
var audio_players: Array[AudioStreamPlayer] = []
var sfx_streams: Dictionary = {}
var music_streams: Dictionary = {}
var _music_players: Array[AudioStreamPlayer] = []
var _active_music_player := 0
var _fade_time := 0.0
var _fade_elapsed := 0.0
var _previous_volume_db := -80.0
var _music_ducked := false
var _music_overdriven := false
var _shutting_down := false
var _enabled := true
var _resonate_manager: Node
var _resonate_ready := false
var _pending_music_key := ""
var _music_bank: Node


func _ready() -> void:
	_enabled = DisplayServer.get_name() != "headless"
	_setup_sfx()
	_setup_music()


func _exit_tree() -> void:
	shutdown()


func shutdown() -> void:
	if _shutting_down:
		return
	_shutting_down = true
	for player in audio_players:
		_free_player(player)
	for player in _music_players:
		_free_player(player)
	audio_players.clear()
	_music_players.clear()
	sfx_streams.clear()
	if _music_bank and is_instance_valid(_music_bank) and _music_bank.get_parent() == self:
		remove_child(_music_bank)
		_music_bank.free()


func play_music(music_key: String, fade_time := MUSIC_FADE_TIME) -> void:
	if not MUSIC_PATHS.has(music_key):
		push_warning("Unknown music key: " + music_key)
		return
	if current_music_key == music_key and _pending_music_key == "":
		return

	current_music_key = music_key
	_pending_music_key = music_key
	if muted or not _enabled:
		return

	if _try_play_resonate(fade_time):
		return
	if _resonate_manager and _resonate_manager.has_method("play") and _resonate_manager.get("has_loaded") != true:
		return
	_play_fallback_music(music_key, fade_time)


func set_music_ducked(ducked: bool) -> void:
	if _music_ducked == ducked:
		return
	_music_ducked = ducked
	_apply_music_volume()


func set_music_overdriven(overdriven: bool) -> void:
	if _music_overdriven == overdriven:
		return
	_music_overdriven = overdriven
	_apply_music_volume()


func toggle_mute() -> void:
	muted = not muted
	if muted:
		for player in audio_players:
			player.stop()
		_stop_music_players()
		if _resonate_manager and _resonate_manager.has_method("stop"):
			_resonate_manager.call("stop", 0.15)
		return

	if current_music_key != "":
		_pending_music_key = current_music_key
		play_music(current_music_key, 0.35)


func update_music(dt: float) -> void:
	if not _enabled:
		return
	if _pending_music_key != "" and not muted:
		_try_play_resonate(MUSIC_FADE_TIME)
	_update_fallback_fade(dt)


func play_sfx(sfx_name: String) -> void:
	if muted or not _enabled or not sfx_streams.has(sfx_name):
		return
	_play_stream(sfx_streams[sfx_name], -8.0 if sfx_name in ["bomb", "boss"] else -12.0)


func _setup_sfx() -> void:
	if not _enabled:
		return
	for i in range(10):
		var player := AudioStreamPlayer.new()
		add_child(player)
		audio_players.append(player)
	sfx_streams = {
		"shot": _make_tone(720, 0.08, "square", 0.18, -0.58),
		"hit": _make_noise(0.13, 0.2),
		"boom": _make_noise(0.42, 0.38),
		"bomb": _make_noise(0.72, 0.44),
		"hurt": _make_tone(220, 0.24, "square", 0.3, -0.36),
		"boss": _make_tone(110, 0.72, "saw", 0.32, -0.15),
		"clear": _make_tone(440, 0.32, "square", 0.22, 0.18),
		"overdrive": _make_tone(880, 0.46, "triangle", 0.28, 0.55),
		"graze": _make_tone(1180, 0.055, "square", 0.12, 0.18),
	}


func _setup_music() -> void:
	if not _enabled:
		return
	for music_key in MUSIC_PATHS.keys():
		var stream: AudioStream = load(MUSIC_PATHS[music_key])
		if stream:
			_prepare_loop(stream)
			music_streams[music_key] = stream

	for i in range(2):
		var player := AudioStreamPlayer.new()
		player.volume_db = -80.0
		player.finished.connect(_on_fallback_music_finished.bind(player))
		add_child(player)
		_music_players.append(player)

	_resonate_manager = get_node_or_null("/root/MusicManager")
	if _resonate_manager:
		_create_resonate_bank()
		if _resonate_manager.has_signal("updated"):
			_resonate_manager.connect("updated", _on_resonate_updated)


func _create_resonate_bank() -> void:
	if _music_bank:
		return
	_music_bank = MusicBank.new()
	_music_bank.name = "NovaMusicBank"
	_music_bank.label = MUSIC_BANK_LABEL
	var tracks: Array[MusicTrackResource] = []
	for music_key in music_streams.keys():
		var stem := MusicStemResource.new()
		stem.name = "main"
		stem.enabled = true
		stem.volume = 0.0
		stem.stream = music_streams[music_key]

		var stems: Array[MusicStemResource] = [stem]
		var track := MusicTrackResource.new()
		track.name = music_key
		track.bus = ""
		track.stems = stems
		tracks.append(track)
	_music_bank.tracks = tracks
	add_child(_music_bank)
	if _resonate_manager.has_method("add_bank"):
		_resonate_manager.call("add_bank", _music_bank)


func _on_resonate_updated() -> void:
	_resonate_ready = true
	if _pending_music_key != "" and not muted:
		_try_play_resonate(MUSIC_FADE_TIME)


func _try_play_resonate(fade_time: float) -> bool:
	if not _resonate_manager or _pending_music_key == "":
		return false
	if not _resonate_manager.has_method("play"):
		return false
	if _resonate_manager.get("has_loaded") != true:
		return false

	_resonate_ready = true
	_stop_music_players()
	_apply_music_volume()
	var played: bool = _resonate_manager.call("play", MUSIC_BANK_LABEL, _pending_music_key, fade_time, true)
	if played:
		_pending_music_key = ""
	return played


func _play_fallback_music(music_key: String, fade_time: float) -> void:
	if _music_players.is_empty():
		return
	if not music_streams.has(music_key):
		return
	var next_index := 1 - _active_music_player
	var next_player := _music_players[next_index]
	next_player.stream = music_streams[music_key]
	_prepare_loop(next_player.stream)
	next_player.volume_db = -80.0
	next_player.play()

	var previous_player := _music_players[_active_music_player]
	_previous_volume_db = previous_player.volume_db if previous_player.playing else -80.0
	_active_music_player = next_index
	_fade_time = maxf(0.01, fade_time)
	_fade_elapsed = 0.0
	_pending_music_key = ""


func _update_fallback_fade(dt: float) -> void:
	if _music_players.is_empty() or _fade_elapsed >= _fade_time:
		return
	_fade_elapsed = minf(_fade_time, _fade_elapsed + dt)
	var t := _fade_elapsed / _fade_time
	var active := _music_players[_active_music_player]
	var previous := _music_players[1 - _active_music_player]
	active.volume_db = lerpf(-80.0, _target_music_volume(), t)
	if previous.playing:
		previous.volume_db = lerpf(_previous_volume_db, -80.0, t)
		if t >= 1.0:
			previous.stop()


func _apply_music_volume() -> void:
	var volume := _target_music_volume()
	if _resonate_manager and _resonate_manager.has_method("set_volume"):
		_resonate_manager.call("set_volume", volume)
	if not _music_players.is_empty():
		_music_players[_active_music_player].volume_db = volume


func _target_music_volume() -> float:
	if _music_ducked:
		return MUSIC_DUCK_DB
	return MUSIC_OVERDRIVE_DB if _music_overdriven else MUSIC_VOLUME_DB


func _prepare_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)


func _on_fallback_music_finished(player: AudioStreamPlayer) -> void:
	if player.stream and not muted:
		player.play()


func _stop_music_players() -> void:
	for player in _music_players:
		player.stop()
		player.volume_db = -80.0


func _play_stream(stream: AudioStream, volume_db: float) -> void:
	for player in audio_players:
		if not player.playing:
			player.stream = stream
			player.volume_db = volume_db
			player.play()
			return


func _free_player(player: AudioStreamPlayer) -> void:
	player.stop()
	player.stream = null
	if is_instance_valid(player) and player.get_parent() == self:
		remove_child(player)
		player.free()


func _make_tone(freq: float, duration: float, wave: String, volume: float, freq_ramp: float) -> AudioStreamWAV:
	var mix_rate := 22050
	var frames := int(duration * mix_rate)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t := float(i) / mix_rate
		var p := t / duration
		var f := maxf(30.0, freq * (1.0 + freq_ramp * p))
		var phase := f * t
		var sample := 0.0
		if wave == "square":
			sample = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		elif wave == "triangle":
			sample = 2.0 * absf(2.0 * fmod(phase, 1.0) - 1.0) - 1.0
		elif wave == "saw":
			sample = 2.0 * fmod(phase, 1.0) - 1.0
		else:
			sample = sin(TAU * phase)
		var env := pow(1.0 - p, 1.8)
		_write_sample(data, i, sample * env * volume)
	return _make_wav(data, mix_rate)


func _make_noise(duration: float, volume: float) -> AudioStreamWAV:
	var mix_rate := 22050
	var frames := int(duration * mix_rate)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var last := 0.0
	for i in range(frames):
		var p := float(i) / frames
		last = lerpf(last, randf_range(-1.0, 1.0), 0.38)
		_write_sample(data, i, last * pow(1.0 - p, 2.2) * volume)
	return _make_wav(data, mix_rate)


func _write_sample(data: PackedByteArray, index: int, value: float) -> void:
	var sample := int(clampf(value, -1.0, 1.0) * 32767.0)
	var unsigned := sample if sample >= 0 else sample + 65536
	data[index * 2] = unsigned & 0xff
	data[index * 2 + 1] = (unsigned >> 8) & 0xff


func _make_wav(data: PackedByteArray, mix_rate: int) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = data
	return stream
