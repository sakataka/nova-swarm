extends SceneTree

const AudioManager = preload("res://scripts/audio_manager.gd")
const BeatClockScript = preload("res://scripts/beat_clock.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager := AudioManager.new()
	root.add_child(manager)
	# Exercise the real imported streams and players with the Dummy audio driver.
	manager._enabled = true
	manager._setup_music()
	_assert(manager.music_streams.size() == 6, "all six main tracks load")
	_assert(manager.overdrive_music_streams.size() == 3, "all three Overdrive layers load")
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://public/assets/audio/music/manifest.json"))
	_assert(manifest is Dictionary and manifest.status == "done", "delivery manifest is complete")
	if not manifest is Dictionary:
		quit(1)
		return
	_assert(manifest.tracks.size() == 9, "manifest contains every replacement")
	for track in manifest.tracks:
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
	for key in manager.OVERDRIVE_LAYER_SETTINGS:
		manager.set_music_overdriven(false)
		manager.play_music(key, 0.01)
		manager._music_players[manager._active_music_player].seek(7.0)
		await create_timer(0.1).timeout
		var expected: float = manager.get_music_position()
		manager.set_music_overdriven(true)
		await create_timer(0.1).timeout
		_assert(manager._overdrive_music_player.playing, "Overdrive layer starts: " + key)
		_assert(absf(manager._overdrive_music_player.get_playback_position() - expected) < 0.5, "Overdrive follows main position: " + key)
	manager.toggle_mute()
	_assert(not manager._overdrive_music_player.playing, "mute stops Overdrive")
	manager.toggle_mute()
	_assert(manager._overdrive_music_player.playing, "unmute restores Overdrive")
	manager.set_app_active(false)
	_assert(not manager._overdrive_music_player.playing, "background stops Overdrive")
	manager.set_app_active(true)
	_assert(manager._overdrive_music_player.playing, "foreground restores Overdrive")
	manager.shutdown()
	root.remove_child(manager)
	manager.free()
	# Let the audio thread release playback commands before SceneTree exits.
	await create_timer(0.15).timeout
	print("AUDIO_TEST_RESULT failures=", failures)
	quit(1 if failures else 0)


func _assert(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("Audio test failed: " + label)
