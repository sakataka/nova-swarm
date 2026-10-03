extends SceneTree

const AudioManager = preload("res://scripts/audio_manager.gd")
const BeatClockScript = preload("res://scripts/beat_clock.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_beat_clock_follows_jittery_audio()
	var manager := AudioManager.new()
	root.add_child(manager)
	# Exercise the real imported streams and players with the Dummy audio driver.
	manager._enabled = true
	manager._setup_music()
	_assert(manager.music_streams.size() == 6, "all six main tracks load")
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://public/assets/audio/music/manifest.json"))
	_assert(manifest is Dictionary and manifest.status == "done", "delivery manifest is complete")
	if not manifest is Dictionary:
		quit(1)
		return
	_assert(manifest.tracks.size() == 9, "manifest contains every replacement")
	for track in manifest.tracks:
		if not manager.MUSIC_PATHS.has(track.id):
			# The Overdrive layers stay in the delivery record but are not played.
			continue
		var variant: Dictionary = track.variants[0]
		var path: String = "res://public/assets/audio/music/" + str(variant.file)
		var stream: AudioStreamWAV = load(path)
		_assert(stream != null, "imported WAV exists: " + track.id)
		if stream == null:
			continue
		manager._prepare_loop(stream)
		_assert(absf(stream.get_length() - float(variant.checks.seconds)) < 0.02, "import preserves duration: " + track.id)
		_assert(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and stream.loop_end > 0, "whole stream loops: " + track.id)
		if BeatClockScript.BPM.has(track.id):
			_assert(float(variant.input.bpm) == float(BeatClockScript.BPM[track.id]), "requested BPM matches beat clock: " + track.id)
		var player := AudioStreamPlayer.new()
		player.stream = stream
		root.add_child(player)
		player.play(maxf(0.0, stream.get_length() - 0.05))
		await create_timer(0.2).timeout
		_assert(player.playing and player.get_playback_position() < 1.0, "playback wraps at loop end: " + track.id)
		player.stop()
		player.stream = null
		player.queue_free()
	manager.play_music("stage_drive", 0.01)
	await create_timer(0.1).timeout
	var main_player: AudioStreamPlayer = manager._music_players[manager._active_music_player]
	manager.toggle_mute()
	_assert(not main_player.playing, "mute stops the BGM")
	manager.toggle_mute()
	_assert(manager._music_players[manager._active_music_player].playing, "unmute restores the BGM")
	manager.set_app_active(false)
	_assert(not manager._music_players.any(func(player: AudioStreamPlayer) -> bool: return player.playing), "background stops the BGM")
	manager.set_app_active(true)
	_assert(manager._music_players[manager._active_music_player].playing, "foreground restores the BGM")
	manager.shutdown()
	root.remove_child(manager)
	manager.free()
	# Let the audio thread release playback commands before SceneTree exits.
	await create_timer(0.15).timeout
	print("AUDIO_TEST_RESULT failures=", failures)
	quit(1 if failures else 0)


# Web playback positions jitter and the loop length is not a whole number of
# beats. The clock must still only move forward and tick once per beat.
func _test_beat_clock_follows_jittery_audio() -> void:
	var clock = BeatClockScript.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var dt := 1.0 / 60.0
	var loop_length := 59.75
	var audio_time := 0.37
	var monotonic := true
	var ticks := 0
	var shortest_gap := 99.0
	var since_tick := 0.0
	for frame in range(60 * 90):
		audio_time += dt
		var reported := fposmod(audio_time + rng.randf_range(-0.04, 0.04), loop_length)
		var before: float = clock.beat
		clock.update(dt, "stage_drive", reported)
		monotonic = monotonic and clock.beat >= before
		since_tick += dt
		if clock.ticked:
			ticks += 1
			if frame > 120:
				shortest_gap = minf(shortest_gap, since_tick)
			since_tick = 0.0
	var seconds_per_beat: float = clock.seconds_per_beat()
	_assert(monotonic, "beat clock never runs backwards")
	_assert(shortest_gap > seconds_per_beat * 0.5, "beat clock never double-ticks")
	_assert(absi(ticks - int(90.0 / seconds_per_beat)) <= 3, "beat clock keeps the tempo")
	var phase_error := absf(wrapf(fposmod(audio_time, loop_length) / seconds_per_beat - clock.beat, -0.5, 0.5))
	_assert(phase_error < 0.12, "beat clock stays locked to the audio phase")


func _assert(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("Audio test failed: " + label)
