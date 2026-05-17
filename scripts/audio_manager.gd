extends Node
class_name NovaAudioManager

const MUSIC_BANK_LABEL := "nova_swarm"
const MUSIC_VOLUME_DB := -18.0
const MUSIC_DUCK_DB := -28.0
const MUSIC_OVERDRIVE_DB := -15.0
const MUSIC_FADE_TIME := 1.25
const OVERDRIVE_STEM_NAME := "overdrive"
const OVERDRIVE_STEM_FADE_TIME := 0.38
const OVERDRIVE_FALLBACK_VOLUME_DB := -22.0

const MUSIC_PATHS := {
	"title": "res://public/assets/audio/music/title_neon_loop.wav",
	"stage_drive": "res://public/assets/audio/music/stage_drive_loop.wav",
	"stage_pressure": "res://public/assets/audio/music/stage_pressure_loop.wav",
	"boss_core": "res://public/assets/audio/music/boss_core_loop.wav",
	"victory_clear": "res://public/assets/audio/music/victory_clear_loop.wav",
	"game_over": "res://public/assets/audio/music/game_over_loop.wav",
}

const OVERDRIVE_LAYER_SETTINGS := {
	"stage_drive": {"root": 220.0, "energy": 0.75, "volume": -15.0},
	"stage_pressure": {"root": 277.18, "energy": 0.92, "volume": -14.0},
	"boss_core": {"root": 164.81, "energy": 1.0, "volume": -13.0},
}

var muted := false
var current_music_key := ""
var audio_players: Array[AudioStreamPlayer] = []
var sfx_streams: Dictionary = {}
var music_streams: Dictionary = {}
var overdrive_music_streams: Dictionary = {}
var _music_players: Array[AudioStreamPlayer] = []
var _overdrive_music_player: AudioStreamPlayer
var _overdrive_fade_tween: Tween
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
	if _overdrive_music_player:
		_free_player(_overdrive_music_player)
	audio_players.clear()
	_music_players.clear()
	sfx_streams.clear()
	overdrive_music_streams.clear()
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
	_sync_overdrive_layer(OVERDRIVE_STEM_FADE_TIME)


func toggle_mute() -> void:
	muted = not muted
	if muted:
		for player in audio_players:
			player.stop()
		_stop_music_players()
		_stop_overdrive_fallback()
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


func has_overdrive_music_layer(music_key: String) -> bool:
	return OVERDRIVE_LAYER_SETTINGS.has(music_key)


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
	for music_key in OVERDRIVE_LAYER_SETTINGS.keys():
		overdrive_music_streams[music_key] = _make_overdrive_music_layer(music_key)

	for i in range(2):
		var player := AudioStreamPlayer.new()
		player.volume_db = -80.0
		player.finished.connect(_on_fallback_music_finished.bind(player))
		add_child(player)
		_music_players.append(player)

	_overdrive_music_player = AudioStreamPlayer.new()
	_overdrive_music_player.volume_db = -80.0
	_overdrive_music_player.finished.connect(_on_overdrive_fallback_finished)
	add_child(_overdrive_music_player)

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
		var stems: Array[MusicStemResource] = [_make_music_stem("main", music_streams[music_key], true, 0.0)]
		if overdrive_music_streams.has(music_key):
			var setting: Dictionary = OVERDRIVE_LAYER_SETTINGS[music_key]
			stems.append(_make_music_stem(OVERDRIVE_STEM_NAME, overdrive_music_streams[music_key], false, float(setting.volume)))

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
	var played: bool = _resonate_manager.call("play", MUSIC_BANK_LABEL, _pending_music_key, fade_time, false)
	if played:
		_pending_music_key = ""
		_sync_overdrive_layer(0.08)
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
	_sync_overdrive_layer(minf(OVERDRIVE_STEM_FADE_TIME, fade_time))


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
	if _overdrive_music_player and _overdrive_music_player.playing:
		_overdrive_music_player.volume_db = MUSIC_DUCK_DB if _music_ducked else OVERDRIVE_FALLBACK_VOLUME_DB


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


func _on_overdrive_fallback_finished() -> void:
	if _overdrive_music_player and _overdrive_music_player.stream and not muted and _music_overdriven:
		_overdrive_music_player.play()


func _stop_music_players() -> void:
	for player in _music_players:
		player.stop()
		player.volume_db = -80.0


func _stop_overdrive_fallback() -> void:
	if _overdrive_fade_tween and _overdrive_fade_tween.is_running():
		_overdrive_fade_tween.kill()
	if _overdrive_music_player:
		_overdrive_music_player.stop()
		_overdrive_music_player.volume_db = -80.0


func _make_music_stem(stem_name: String, stream: AudioStream, enabled: bool, volume_db: float) -> MusicStemResource:
	var stem := MusicStemResource.new()
	stem.name = stem_name
	stem.enabled = enabled
	stem.volume = volume_db
	stem.stream = stream
	return stem


func _sync_overdrive_layer(fade_time: float) -> void:
	var should_play := _music_overdriven and current_music_key in OVERDRIVE_LAYER_SETTINGS and not muted and _enabled
	var current_track_has_layer := current_music_key in OVERDRIVE_LAYER_SETTINGS
	if _resonate_ready and current_track_has_layer and _resonate_manager and _resonate_manager.has_method("enable_stem"):
		if should_play:
			_resonate_manager.call("enable_stem", OVERDRIVE_STEM_NAME, fade_time)
		elif _resonate_manager.has_method("disable_stem"):
			_resonate_manager.call("disable_stem", OVERDRIVE_STEM_NAME, fade_time)
	if not _resonate_ready:
		_sync_overdrive_fallback(should_play, fade_time)
	else:
		_stop_overdrive_fallback()


func _sync_overdrive_fallback(should_play: bool, fade_time: float) -> void:
	if not _overdrive_music_player:
		return
	if _overdrive_fade_tween and _overdrive_fade_tween.is_running():
		_overdrive_fade_tween.kill()
	if not should_play:
		if _overdrive_music_player.playing:
			_overdrive_fade_tween = create_tween()
			_overdrive_fade_tween.tween_property(_overdrive_music_player, "volume_db", -80.0, maxf(0.01, fade_time))
			_overdrive_fade_tween.finished.connect(func() -> void: _overdrive_music_player.stop())
		return
	if not overdrive_music_streams.has(current_music_key):
		return
	if _overdrive_music_player.stream != overdrive_music_streams[current_music_key]:
		_overdrive_music_player.stream = overdrive_music_streams[current_music_key]
		_prepare_loop(_overdrive_music_player.stream)
		_overdrive_music_player.play()
	elif not _overdrive_music_player.playing:
		_overdrive_music_player.play()
	var target_volume := MUSIC_DUCK_DB if _music_ducked else OVERDRIVE_FALLBACK_VOLUME_DB
	_overdrive_fade_tween = create_tween()
	_overdrive_fade_tween.tween_property(_overdrive_music_player, "volume_db", target_volume, maxf(0.01, fade_time))


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


func _make_overdrive_music_layer(music_key: String) -> AudioStreamWAV:
	var setting: Dictionary = OVERDRIVE_LAYER_SETTINGS[music_key]
	var root := float(setting.root)
	var energy := float(setting.energy)
	var mix_rate := 22050
	var duration := 4.0
	var frames := int(duration * mix_rate)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t := float(i) / mix_rate
		var beat := fmod(t * 2.0, 1.0)
		var sixteenth := fmod(t * 8.0, 1.0)
		var pulse := pow(maxf(0.0, 1.0 - beat * 3.8), 3.0)
		var hat := (1.0 if sixteenth < 0.42 else -1.0) * pow(1.0 - sixteenth, 1.7)
		var bass := sin(TAU * root * 0.5 * t) * (0.28 + pulse * 0.42)
		var octave := sin(TAU * root * 2.0 * t + sin(TAU * t * 0.5) * 0.35) * 0.12
		var alarm := sin(TAU * root * 3.0 * t) * (0.05 + pulse * 0.06)
		var sample := (bass + octave + alarm + hat * 0.08) * 0.26 * energy
		_write_sample(data, i, sample)
	var stream := _make_wav(data, mix_rate)
	_prepare_loop(stream)
	return stream


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
