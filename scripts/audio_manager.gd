extends Node
class_name NovaAudioManager

var muted := false
var music_timer := 0.0
var music_step := 0
var audio_players: Array[AudioStreamPlayer] = []
var sfx_streams: Dictionary = {}
var _shutting_down := false
var _enabled := true


func _ready() -> void:
	_enabled = DisplayServer.get_name() != "headless"
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
	}


func _exit_tree() -> void:
	shutdown()


func shutdown() -> void:
	if _shutting_down:
		return
	_shutting_down = true
	for player in audio_players:
		player.stop()
		player.stream = null
		if is_instance_valid(player) and player.get_parent() == self:
			remove_child(player)
			player.free()
	audio_players.clear()
	sfx_streams.clear()


func toggle_mute() -> void:
	muted = not muted
	if muted:
		for player in audio_players:
			player.stop()


func update_music(dt: float) -> void:
	if muted or not _enabled:
		return
	music_timer -= dt
	if music_timer > 0.0:
		return
	music_timer = 0.19
	var notes := [110.0, 146.83, 164.81, 220.0, 196.0, 164.81, 146.83, 130.81]
	var note: float = notes[music_step % notes.size()]
	music_step += 1
	_play_stream(_make_tone(note, 0.18, "square", 0.055, 0.0), -24.0)
	if music_step % 4 == 0:
		_play_stream(_make_tone(note * 2.0, 0.12, "triangle", 0.04, 0.0), -27.0)


func play_sfx(sfx_name: String) -> void:
	if muted or not _enabled or not sfx_streams.has(sfx_name):
		return
	_play_stream(sfx_streams[sfx_name], -8.0 if sfx_name in ["bomb", "boss"] else -12.0)


func _play_stream(stream: AudioStream, volume_db: float) -> void:
	for player in audio_players:
		if not player.playing:
			player.stream = stream
			player.volume_db = volume_db
			player.play()
			return


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
