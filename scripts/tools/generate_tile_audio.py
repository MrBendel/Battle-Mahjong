"""Generate original, deterministic presentation SFX using Python's standard library."""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
OUTPUT = Path(__file__).resolve().parents[2] / "game-assets" / "audio"
OUTPUT.mkdir(parents=True, exist_ok=True)

def save(name, samples):
    peak = max(abs(x) for x in samples) or 1
    pcm = b"".join(struct.pack("<h", round(x / peak * 0.72 * 32767)) for x in samples)
    with wave.open(str(OUTPUT / name), "wb") as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(RATE)
        audio.writeframes(pcm)

rng = random.Random(714)
filtered = 0.0
samples = []
for i in range(int(RATE * 0.22)):
    t = i / RATE
    u = t / 0.22
    noise = rng.uniform(-1, 1)
    filtered += (noise - filtered) * (0.04 + 0.28 * math.sin(math.pi * u))
    envelope = math.sin(math.pi * u) ** 2.4
    samples.append(filtered * envelope)
save("tile_swoosh.wav", samples)

samples = []
for i in range(int(RATE * 0.18)):
    t = i / RATE
    attack = min(1, t / 0.0015)
    modes = sum(gain * math.sin(2 * math.pi * freq * t) * math.exp(-t / decay)
                for freq, gain, decay in [(940, 0.55, 0.020), (2130, 0.30, 0.032),
                                          (3670, 0.15, 0.014), (280, 0.25, 0.012)])
    click = rng.uniform(-1, 1) * 0.55 * math.exp(-t / 0.003)
    samples.append((modes + click) * attack * min(1, (0.18 - t) / 0.015))
save("tile_collision.wav", samples)

# Soft brush with a tiny ceramic tick, deliberately shorter than the travel swoosh.
samples = []
filtered = 0.0
for i in range(int(RATE * 0.10)):
    t = i / RATE
    u = t / 0.10
    filtered += (rng.uniform(-1, 1) - filtered) * 0.16
    brush = filtered * math.sin(math.pi * u) ** 2
    tick = 0.09 * math.sin(2 * math.pi * 1500 * t) * math.exp(-t / 0.015) * min(1, t / 0.003)
    samples.append(brush + tick)
save("tile_flip.wav", samples)
