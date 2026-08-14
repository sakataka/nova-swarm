extends Node
class_name NovaAudioManager

const MUSIC_BANK_LABEL := "nova_swarm"
const USE_RESONATE_MUSIC := false
const MUSIC_VOLUME_DB := -14.0
const MUSIC_DUCK_DB := -20.0
const MUSIC_OVERDRIVE_DB := -10.0
const MUSIC_FADE_TIME := 1.25
const OVERDRIVE_STEM_NAME := "overdrive"
const OVERDRIVE_STEM_FADE_TIME := 0.38
const OVERDRIVE_FALLBACK_VOLUME_DB := -22.0
const MUSIC_VOLUME_TWEEN_TIME := 0.25
const SFX_MIN_INTERVAL_MS := 70
const SFX_INTERVALS := {
	"shot": 55,
	"hit": 45,
	"chip": 45,
	"graze": 55,
	"wave": 180,
	"level_up": 240,
	"midboss_break": 280,
	"stage_clear": 350,
}

const MUSIC_PATHS := {
	"title": "res://public/assets/audio/music/title_neon_loop.wav",
	"stage_drive": "res://public/assets/audio/music/stage_drive_loop.wav",
	"stage_pressure": "res://public/assets/audio/music/stage_pressure_loop.wav",
	"boss_core": "res://public/assets/audio/music/boss_core_loop.wav",
	"victory_clear": "res://public/assets/audio/music/victory_clear_loop.wav",
	"game_over": "res://public/assets/audio/music/game_over_loop.wav",
}

const OVERDRIVE_LAYER_SETTINGS := {
	"stage_drive": {"root": 220.0, "energy": 0.75, "volume": -21.0},
	"stage_pressure": {"root": 277.18, "energy": 0.92, "volume": -20.0},
	"boss_core": {"root": 164.81, "energy": 1.0, "volume": -19.0},
}

var muted := false
var current_music_key := ""
var audio_players: Array[AudioStreamPlayer] = []
var sfx_streams: Dictionary = {}
var music_streams: Dictionary = {}
var overdrive_music_streams: Dictionary = {}
var _music_players: Array[AudioStreamPlayer] = []
var _overdrive_music_player: AudioStreamPlayer
var _volume_tween: Tween
var _overdrive_fade_tween: Tween
var _active_music_player := 0
var _fade_time := 0.0
var _fade_elapsed := 0.0
var _previous_volume_db := -80.0
var _music_ducked := false
var _music_overdriven := false
var _shutting_down := false
var _enabled := true
var _app_active := true
var _resonate_manager: Node
var _resonate_ready := false
var _pending_music_key := ""
var _music_bank: Node
var _sfx_last_played_ms: Dictionary = {}


func _ready() -> void:
	_enabled = DisplayServer.get_name() != "headless"
	_setup_buses()
	_setup_master_limiter()
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
	if muted or not _enabled or not _app_active:
		return

	if USE_RESONATE_MUSIC and _try_play_resonate(fade_time):
		return
	if USE_RESONATE_MUSIC and _resonate_manager and _resonate_manager.has_method("play") and _resonate_manager.get("has_loaded") != true:
		return
	_play_fallback_music(music_key, fade_time)


func replay_current_music(fade_time := 0.08) -> void:
	if current_music_key == "":
		return
	_pending_music_key = current_music_key
	if muted or not _enabled or not _app_active:
		return

	# Web browsers can suspend audio started before the first user gesture.
	# Reissuing play from that gesture makes the title cue audible without
	# changing the selected track or the normal crossfade path.
	if USE_RESONATE_MUSIC and _try_play_resonate(fade_time):
		return
	if USE_RESONATE_MUSIC and _resonate_manager and _resonate_manager.has_method("play") and _resonate_manager.get("has_loaded") != true:
		return
	_play_fallback_music(current_music_key, fade_time)


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


func set_app_active(active: bool) -> void:
	if _app_active == active:
		return
	_app_active = active
	if not active:
		for player in audio_players:
			player.stop()
		_stop_music_players()
		_stop_overdrive_fallback()
		if _resonate_manager and _resonate_manager.has_method("stop"):
			_resonate_manager.call("stop", 0.0)
		return

	if muted or not _enabled or current_music_key == "":
		return
	_pending_music_key = current_music_key
	if USE_RESONATE_MUSIC and _try_play_resonate(0.15):
		return
	_play_fallback_music(current_music_key, 0.15)


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

	if _app_active and current_music_key != "":
		_pending_music_key = current_music_key
		play_music(current_music_key, 0.35)


func update_music(dt: float) -> void:
	if not _enabled or not _app_active:
		return
	if USE_RESONATE_MUSIC and _pending_music_key != "" and not muted:
		_try_play_resonate(MUSIC_FADE_TIME)
	_update_fallback_fade(dt)


func play_sfx(sfx_name: String) -> void:
	if muted or not _enabled or not _app_active or not sfx_streams.has(sfx_name):
		return
	var now := Time.get_ticks_msec()
	var min_interval := int(SFX_INTERVALS.get(sfx_name, SFX_MIN_INTERVAL_MS))
	if now - int(_sfx_last_played_ms.get(sfx_name, -min_interval)) < min_interval:
		return
	_sfx_last_played_ms[sfx_name] = now
	var volume := -7.0 if sfx_name in ["bomb", "midboss_break", "stage_clear"] else -10.0 if sfx_name in ["boom", "hurt", "level_up"] else -13.0
	var pitch_variance := 0.025 if sfx_name in ["stage_clear", "level_up"] else 0.065
	_play_stream(sfx_streams[sfx_name], volume, pitch_variance)


func has_overdrive_music_layer(music_key: String) -> bool:
	return OVERDRIVE_LAYER_SETTINGS.has(music_key)


func _setup_sfx() -> void:
	if not _enabled:
		return
	for i in range(10):
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		audio_players.append(player)
	sfx_streams = {
		"shot": _make_layered_impact(0.075, 910.0, 0.76, 0.2),
		"hit": _make_layered_impact(0.105, 180.0, 0.9, 0.24),
		"boom": _make_layered_impact(0.38, 76.0, 0.62, 0.42),
		"bomb": _make_layered_impact(0.7, 46.0, 0.48, 0.5),
		"hurt": _make_tone(220, 0.24, "square", 0.3, -0.36),
		"boss": _make_tone(110, 0.72, "saw", 0.32, -0.15),
		"clear": _make_tone(440, 0.32, "square", 0.22, 0.18),
		"overdrive": _make_tone(880, 0.46, "triangle", 0.28, 0.55),
		"graze": _make_tone(1180, 0.055, "square", 0.12, 0.18),
		"chip": _make_pickup_tone(620.0, 0.13, 0.15),
		"level_up": _make_pickup_tone(420.0, 0.42, 0.28),
		"wave": _make_pickup_tone(300.0, 0.24, 0.2),
		"midboss_break": _make_layered_impact(0.82, 42.0, 0.72, 0.54),
		"stage_clear": _make_pickup_tone(330.0, 0.7, 0.3),
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
		player.bus = "Music"
		player.volume_db = -80.0
		player.finished.connect(_on_fallback_music_finished.bind(player))
		add_child(player)
		_music_players.append(player)

	_overdrive_music_player = AudioStreamPlayer.new()
	_overdrive_music_player.bus = "Music"
	_overdrive_music_player.volume_db = -80.0
	_overdrive_music_player.finished.connect(_on_overdrive_fallback_finished)
	add_child(_overdrive_music_player)

	if not USE_RESONATE_MUSIC:
		return
	_resonate_manager = get_node_or_null("/root/MusicManager")
	if _resonate_manager:
		_create_resonate_bank()
		if _resonate_manager.has_signal("updated"):
			_resonate_manager.connect("updated", _on_resonate_updated)


func _setup_master_limiter() -> void:
	if not _enabled:
		return
	var master_bus := AudioServer.get_bus_index("Master")
	for i in range(AudioServer.get_bus_effect_count(master_bus)):
		if AudioServer.get_bus_effect(master_bus, i) is AudioEffectHardLimiter:
			return
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -1.0
	AudioServer.add_bus_effect(master_bus, limiter)


func _setup_buses() -> void:
	if not _enabled:
		return
	_ensure_bus("Music")
	_ensure_bus("SFX")


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)


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
	if _pending_music_key != "" and not muted and _app_active:
		_try_play_resonate(MUSIC_FADE_TIME)


func _try_play_resonate(fade_time: float) -> bool:
	if not _app_active or not _resonate_manager or _pending_music_key == "":
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
	if not _app_active or _music_players.is_empty():
		return
	if not music_streams.has(music_key):
		return
	_kill_volume_tween()
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
	var target_linear := db_to_linear(_target_music_volume())
	active.volume_db = linear_to_db(maxf(0.00001, target_linear * t))
	if previous.playing:
		var previous_linear := db_to_linear(_previous_volume_db)
		previous.volume_db = linear_to_db(maxf(0.00001, previous_linear * (1.0 - t)))
		if t >= 1.0:
			previous.stop()


func _apply_music_volume() -> void:
	var volume := _target_music_volume()
	if _resonate_manager and _resonate_manager.has_method("set_volume"):
		_resonate_manager.call("set_volume", volume)
	if not _music_players.is_empty() and _fade_elapsed >= _fade_time:
		_kill_volume_tween()
		_volume_tween = create_tween()
		_volume_tween.tween_property(_music_players[_active_music_player], "volume_db", volume, MUSIC_VOLUME_TWEEN_TIME)
	if _overdrive_music_player and _overdrive_music_player.playing:
		if _overdrive_fade_tween and _overdrive_fade_tween.is_running():
			_overdrive_fade_tween.kill()
		_overdrive_fade_tween = create_tween()
		_overdrive_fade_tween.tween_property(_overdrive_music_player, "volume_db", MUSIC_DUCK_DB if _music_ducked else OVERDRIVE_FALLBACK_VOLUME_DB, MUSIC_VOLUME_TWEEN_TIME)


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
	if player.stream and not muted and _app_active:
		player.play()


func _on_overdrive_fallback_finished() -> void:
	if _overdrive_music_player and _overdrive_music_player.stream and not muted and _music_overdriven and _app_active:
		_overdrive_music_player.play()


func _stop_music_players() -> void:
	_kill_volume_tween()
	for player in _music_players:
		player.stop()
		player.volume_db = -80.0


func _kill_volume_tween() -> void:
	if _volume_tween and _volume_tween.is_running():
		_volume_tween.kill()


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
	var should_play := _music_overdriven and current_music_key in OVERDRIVE_LAYER_SETTINGS and not muted and _enabled and _app_active
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


func _play_stream(stream: AudioStream, volume_db: float, pitch_variance := 0.0) -> void:
	for player in audio_players:
		if not player.playing:
			player.stream = stream
			player.volume_db = volume_db
			player.pitch_scale = 1.0 + randf_range(-pitch_variance, pitch_variance)
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


func _make_layered_impact(duration: float, low_freq: float, brightness: float, volume: float) -> AudioStreamWAV:
	var mix_rate := 44100
	var frames := int(duration * mix_rate)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var filtered_noise := 0.0
	for i in range(frames):
		var t := float(i) / mix_rate
		var p := float(i) / maxf(1.0, float(frames))
		filtered_noise = lerpf(filtered_noise, randf_range(-1.0, 1.0), brightness)
		var low := sin(TAU * low_freq * (1.0 - p * 0.34) * t) * pow(1.0 - p, 2.0)
		var crack := filtered_noise * pow(1.0 - p, 3.4)
		var click := sin(TAU * (1900.0 - p * 1100.0) * t) * pow(1.0 - p, 8.0)
		_write_sample(data, i, (low * 0.52 + crack * 0.34 + click * 0.14) * volume)
	return _make_wav(data, mix_rate)


func _make_pickup_tone(root: float, duration: float, volume: float) -> AudioStreamWAV:
	var mix_rate := 44100
	var frames := int(duration * mix_rate)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t := float(i) / mix_rate
		var p := float(i) / maxf(1.0, float(frames))
		var step: float = floor(p * 4.0)
		var freq: float = root * pow(2.0, step * 4.0 / 12.0)
		var sample: float = sin(TAU * freq * t) * 0.7 + sin(TAU * freq * 2.0 * t) * 0.2
		_write_sample(data, i, sample * pow(1.0 - p, 1.4) * volume)
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
