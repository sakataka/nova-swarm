extends RefCounted
class_name BeatClock

# Tracks the beat of the current BGM loop.
# Game time drives the clock so headless runs stay deterministic; when real
# audio is playing, the playback position gently corrects the phase.

const BPM := {
	"title": 116.0,
	"stage_drive": 132.0,
	"stage_pressure": 162.0,
	"boss_core": 140.0,
	"victory_clear": 132.0,
	"game_over": 72.0,
}
const BEATS_PER_BAR := 4
# Timing window (in beats) that counts as "on the beat" for sync bonuses.
const SYNC_WINDOW := 0.2

var music_key := ""
var bpm := 132.0
var beat := 0.0
var ticked := false
var downbeat := false


func reset(key: String) -> void:
	music_key = key
	bpm = float(BPM.get(key, 120.0))
	beat = 0.0
	ticked = false
	downbeat = false


func update(dt: float, key: String, audio_position := -1.0) -> void:
	if key != music_key:
		reset(key)
	var previous := beat
	beat += dt * bpm / 60.0
	if audio_position >= 0.0:
		var audio_beat := audio_position * bpm / 60.0
		var error := wrapf(audio_beat - beat, -0.5, 0.5)
		beat += error * clampf(dt * 6.0, 0.0, 1.0)
	ticked = floorf(beat) > floorf(previous)
	downbeat = ticked and int(floorf(beat)) % BEATS_PER_BAR == 0


func phase() -> float:
	return fposmod(beat, 1.0)


func bar_position() -> int:
	return int(floorf(beat)) % BEATS_PER_BAR


# 1.0 right on the beat, decaying quickly afterwards. Used for visual pulses.
func pulse(sharpness := 5.0) -> float:
	return exp(-phase() * sharpness)


func bar_pulse() -> float:
	var bar_phase := fposmod(beat, float(BEATS_PER_BAR))
	return exp(-bar_phase * 3.2)


func is_on_beat(window := SYNC_WINDOW) -> bool:
	var p := phase()
	return p < window or p > 1.0 - window * 0.5


func seconds_per_beat() -> float:
	return 60.0 / bpm
