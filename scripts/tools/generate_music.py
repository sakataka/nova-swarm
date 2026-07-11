#!/usr/bin/env python3
"""Generate Nova Swarm's original, loop-safe arcade soundtrack."""

from __future__ import annotations

import math
import random
import wave
from array import array
from pathlib import Path


RATE = 44_100
TAU = math.tau
OUT = Path(__file__).resolve().parents[2] / "public/assets/audio/music"
THEME = (0, 3, 7, 10, 12, 7, 15, 12)


def midi(note: float) -> float:
    return 440.0 * 2.0 ** ((note - 69.0) / 12.0)


def saw(freq: float, t: float) -> float:
    return 2.0 * ((freq * t) % 1.0) - 1.0


def triangle(freq: float, t: float) -> float:
    return 1.0 - 4.0 * abs(((freq * t) % 1.0) - 0.5)


def decay(phase: float, speed: float) -> float:
    return math.exp(-phase * speed)


def drum_noise(index: int) -> float:
    value = (index * 1_103_515_245 + 12_345) & 0x7FFFFFFF
    return float((value >> 8) & 0xFFFF) / 32_767.5 - 1.0


def render_track(name: str, bpm: float, bars: int, root: int, energy: float, mood: str) -> None:
    beats = bars * 4
    duration = beats * 60.0 / bpm
    frames = round(duration * RATE)
    samples = array("h")
    chord_shapes = ((0, 3, 7), (-2, 3, 7), (-5, 0, 3), (-7, -2, 3))

    for i in range(frames):
        t = i / RATE
        beat = t * bpm / 60.0
        beat_phase = beat % 1.0
        eighth = int(beat * 2.0)
        sixteenth = int(beat * 4.0)
        bar = int(beat / 4.0)
        chord = chord_shapes[bar % len(chord_shapes)]
        root_note = root + chord[0]

        pad = 0.0
        for interval in chord:
            freq = midi(root + interval + 12)
            pad += math.sin(TAU * freq * t + math.sin(t * 0.31) * 0.12)
        pad *= 0.055 if mood != "game_over" else 0.075

        bass_phase = (beat * 2.0) % 1.0
        bass_note = root_note + (12 if eighth % 8 in (6, 7) else 0)
        bass = (saw(midi(bass_note), t) * 0.62 + math.sin(TAU * midi(bass_note) * t) * 0.38)
        bass *= decay(bass_phase, 3.6) * (0.18 + energy * 0.08)

        motif_note = root + 24 + THEME[eighth % len(THEME)]
        arp = triangle(midi(motif_note), t) * decay((beat * 2.0) % 1.0, 5.8)
        arp += math.sin(TAU * midi(motif_note + 12) * t) * decay((beat * 2.0) % 1.0, 8.5) * 0.3
        arp *= 0.11 + energy * 0.045

        lead = 0.0
        if mood in ("pressure", "boss", "victory"):
            lead_step = int(beat) % len(THEME)
            lead_note = root + 24 + THEME[lead_step]
            lead = (triangle(midi(lead_note), t) + math.sin(TAU * midi(lead_note) * t) * 0.45)
            lead *= decay(beat_phase, 2.3) * (0.07 + energy * 0.04)

        kick = 0.0
        snare = 0.0
        hat = 0.0
        if mood not in ("title", "game_over"):
            kick_phase = beat_phase
            kick_freq = 48.0 + 92.0 * decay(kick_phase, 16.0)
            kick = math.sin(TAU * kick_freq * t) * decay(kick_phase, 12.0) * (0.42 + energy * 0.08)
            if int(beat) % 4 in (1, 3):
                snare = drum_noise(i) * decay(beat_phase, 18.0) * 0.23
                snare += math.sin(TAU * 190.0 * t) * decay(beat_phase, 20.0) * 0.09
            hat_phase = (beat * (4.0 if mood == "boss" else 2.0)) % 1.0
            hat = drum_noise(i * 7) * decay(hat_phase, 30.0) * (0.055 + energy * 0.025)
        elif mood == "title":
            pulse_phase = (beat * 2.0) % 1.0
            kick = math.sin(TAU * 58.0 * t) * decay(beat_phase, 13.0) * 0.22
            hat = drum_noise(i * 5) * decay(pulse_phase, 36.0) * 0.028
        else:
            bass *= 0.72
            arp *= 0.52

        riser = 0.0
        if mood in ("pressure", "boss") and sixteenth % 32 >= 28:
            riser_phase = (sixteenth % 32 - 28 + (beat * 4.0) % 1.0) / 4.0
            riser = drum_noise(i * 11) * riser_phase * riser_phase * 0.035

        mono = pad + bass + arp + lead + kick + snare + hat + riser
        if mood == "victory":
            mono += math.sin(TAU * midi(root + 36 + THEME[eighth % 4]) * t) * 0.06
        mono = math.tanh(mono * 1.32) * 0.78

        shimmer = math.sin(TAU * midi(root + 31) * (t + 0.007)) * 0.012 * energy
        left = max(-1.0, min(1.0, mono + shimmer))
        right = max(-1.0, min(1.0, mono - shimmer))
        samples.append(round(left * 32_767.0))
        samples.append(round(right * 32_767.0))

    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / name), "wb") as wav:
        wav.setnchannels(2)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(samples.tobytes())


def main() -> None:
    random.seed(20260711)
    tracks = (
        ("title_neon_loop.wav", 108.0, 8, 45, 0.62, "title"),
        ("stage_drive_loop.wav", 150.0, 8, 45, 0.86, "drive"),
        ("stage_pressure_loop.wav", 162.0, 8, 48, 0.98, "pressure"),
        ("boss_core_loop.wav", 174.0, 8, 41, 1.08, "boss"),
        ("victory_clear_loop.wav", 132.0, 8, 48, 0.8, "victory"),
        ("game_over_loop.wav", 72.0, 4, 41, 0.42, "game_over"),
    )
    for track in tracks:
        render_track(*track)
        print(OUT / track[0])


if __name__ == "__main__":
    main()
