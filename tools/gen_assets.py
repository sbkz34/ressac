#!/usr/bin/env python3
"""Generates the game's textures (PNG) and sound effects (WAV) procedurally.

Run from the repository root:  python3 tools/gen_assets.py
Everything in assets/tex and assets/sfx comes from this script: no third-party assets.
"""
import os
import wave

import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")
TEX = os.path.join(ROOT, "tex")
SFX = os.path.join(ROOT, "sfx")
os.makedirs(TEX, exist_ok=True)
os.makedirs(SFX, exist_ok=True)
rng = np.random.default_rng(7)

# ----------------------------------------------------------------------------------------------
# Textures (tileable: every blur wraps around the edges)
# ----------------------------------------------------------------------------------------------
N = 256


def noise(sigma, size=N):
    a = gaussian_filter(rng.standard_normal((size, size)), sigma, mode="wrap")
    a -= a.min()
    return a / max(a.max(), 1e-9)


def fbm(octaves=(1, 2, 4, 8, 16), weights=None, size=N):
    weights = weights or [0.5 ** i for i in range(len(octaves))]
    out = sum(w * noise(o, size) for o, w in zip(octaves, weights))
    out -= out.min()
    return out / out.max()


def save(name, rgb):
    img = np.clip(rgb * 255, 0, 255).astype(np.uint8)
    Image.fromarray(img, "RGB").save(os.path.join(TEX, name))


def colorize(v, dark, light):
    dark, light = np.array(dark), np.array(light)
    return dark + v[..., None] * (light - dark)


# Concrete wall: grey, stains running down, a few cracks.
v = fbm()
stains = gaussian_filter(rng.standard_normal((N, N)), (18, 3), mode="wrap")
stains = (stains - stains.min()) / (stains.max() - stains.min())
v = 0.55 * v + 0.45 * (1 - stains ** 2)
crack = np.zeros((N, N))
for _ in range(5):
    x, y = rng.integers(0, N, 2)
    for _ in range(120):
        crack[y % N, x % N] = 1
        x += rng.integers(-1, 2)
        y += rng.integers(0, 2)
v -= 0.35 * gaussian_filter(crack, 0.7, mode="wrap") * 3
save("concrete.png", colorize(np.clip(v, 0, 1), (0.22, 0.22, 0.21), (0.55, 0.54, 0.5)))

# Floor tiles: 4x4 tiles, grout lines, grime.
v = fbm((1, 3, 8))
tile = np.ones((N, N))
step = N // 4
for i in range(0, N, step):
    tile[i:i + 3, :] = 0.25
    tile[:, i:i + 3] = 0.25
tint = np.zeros((N, N))
for ty in range(4):
    for tx in range(4):
        tint[ty * step:(ty + 1) * step, tx * step:(tx + 1) * step] = rng.uniform(-0.08, 0.08)
grime = noise(20)
base = colorize(np.clip(0.6 * v + 0.4 * tile + tint - 0.3 * grime, 0, 1), (0.08, 0.09, 0.08),
                (0.42, 0.44, 0.4))
save("tiles.png", base)

# Wood planks (horizontal planks with grain).
y = np.arange(N)[:, None]
x = np.arange(N)[None, :]
streak = gaussian_filter(rng.standard_normal((N, N)), (1.2, 40), mode="wrap")
streak = (streak - streak.min()) / (streak.max() - streak.min())
grain = np.sin((y / N) * 2 * np.pi * 24 + 10 * streak) * 0.5 + 0.5
grain = 0.45 * grain + 0.55 * streak
plank_h = N // 4
seams = ((y % plank_h) < 3).astype(float)
shade = np.zeros((N, N))
for p in range(4):
    shade[p * plank_h:(p + 1) * plank_h, :] = rng.uniform(-0.12, 0.12)
v = np.clip(0.75 * grain + shade - 0.6 * seams, 0, 1)
save("wood.png", colorize(v, (0.16, 0.09, 0.04), (0.55, 0.36, 0.18)))

# Rusty metal panels.
v = fbm((1, 2, 4, 8))
rust = np.clip(noise(5) * 1.6 - 0.6, 0, 1)
panel = np.ones((N, N))
panel[:, :3] = panel[:3, :] = 0.3
panel[N // 2:N // 2 + 2, :] = 0.4
rivets = np.zeros((N, N))
for cy in (12, N // 2 - 10, N // 2 + 12, N - 12):
    for cx in range(12, N, 40):
        rivets[cy - 2:cy + 3, cx - 2:cx + 3] = 1
metal = colorize(np.clip(0.5 + 0.3 * v, 0, 1) * panel[..., None].squeeze(), (0.12, 0.13, 0.14),
                 (0.5, 0.52, 0.55))
rust_col = colorize(v, (0.25, 0.1, 0.04), (0.55, 0.28, 0.1))
out = metal * (1 - rust[..., None]) + rust_col * rust[..., None] + 0.25 * rivets[..., None]
save("metal.png", np.clip(out, 0, 1))

# Dirt for the ground outside.
v = fbm((1, 2, 4, 10, 24))
save("dirt.png", colorize(v, (0.06, 0.05, 0.03), (0.3, 0.25, 0.16)))

# Bricks (lower walls outside / accents).
bh, bw = N // 8, N // 4
mortar = np.zeros((N, N))
for row in range(8):
    mortar[row * bh:row * bh + 3, :] = 1
    off = (bw // 2) * (row % 2)
    for c in range(-1, 5):
        xx = (c * bw + off) % N
        mortar[row * bh:(row + 1) * bh, xx:xx + 3] = 1
bt = np.zeros((N, N))
for row in range(8):
    for c in range(5):
        bt[row * bh:(row + 1) * bh, (c * bw) % N:(c * bw) % N + bw] += rng.uniform(-0.1, 0.1)
v = np.clip(0.55 + 0.35 * fbm((1, 3, 6)) + bt - 0.7 * mortar, 0, 1)
save("brick.png", colorize(v, (0.15, 0.06, 0.04), (0.55, 0.25, 0.17)))

# ----------------------------------------------------------------------------------------------
# Sounds (44.1 kHz mono 16-bit)
# ----------------------------------------------------------------------------------------------
SR = 44100


def t(dur):
    return np.arange(int(SR * dur)) / SR


def env(dur, attack=0.002, decay=0.2):
    tt = t(dur)
    a = np.clip(tt / max(attack, 1e-6), 0, 1)
    return a * np.exp(-tt / decay)


def white(dur):
    return rng.uniform(-1, 1, int(SR * dur))


def lowpass(x, cutoff):
    # One-pole low-pass, cutoff in Hz (scalar or per-sample array).
    cutoff = np.broadcast_to(cutoff, x.shape)
    out = np.zeros_like(x)
    acc = 0.0
    k = 1 - np.exp(-2 * np.pi * cutoff / SR)
    for i in range(len(x)):
        acc += k[i] * (x[i] - acc)
        out[i] = acc
    return out


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def norm(x, peak=0.9):
    m = np.max(np.abs(x))
    return x * (peak / m) if m > 0 else x


def write(name, x):
    x = np.clip(norm(x), -1, 1)
    fade = min(len(x), 200)
    x[-fade:] *= np.linspace(1, 0, fade)
    data = (x * 32767).astype("<i2")
    with wave.open(os.path.join(SFX, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def pad(x, dur):
    out = np.zeros(int(SR * dur))
    out[:min(len(x), len(out))] = x[:len(out)]
    return out


def gunshot(dur, body_hz, crack_decay, body_decay, tone=0.0, cutoff=5000):
    n = white(dur)
    crack = highpass(n, 1500) * env(dur, 0.0005, crack_decay)
    body = lowpass(n, cutoff) * env(dur, 0.001, body_decay)
    thump = np.sin(2 * np.pi * body_hz * t(dur) * np.exp(-t(dur) * 8)) * env(dur, 0.001, body_decay * 0.8)
    return crack * 0.8 + body + thump * (0.8 + tone)


write("pistol.wav", gunshot(0.35, 110, 0.02, 0.06))
write("smg.wav", gunshot(0.22, 140, 0.012, 0.04, cutoff=6000))
write("rifle.wav", gunshot(0.5, 80, 0.03, 0.1, tone=0.3))
write("carbine.wav", gunshot(0.45, 95, 0.025, 0.09))
write("shotgun.wav", gunshot(0.8, 60, 0.04, 0.22, tone=0.5, cutoff=3000))
write("sniper.wav", gunshot(1.0, 55, 0.05, 0.25, tone=0.6, cutoff=4000))
write("lmg.wav", gunshot(0.4, 75, 0.02, 0.08, tone=0.4))
write("revolver.wav", gunshot(0.6, 70, 0.035, 0.13, tone=0.4))

# Energy weapon: falling sine sweep with buzz.
d = 0.45
tt = t(d)
freq = 1400 * np.exp(-tt * 9) + 180
phase = 2 * np.pi * np.cumsum(freq) / SR
zap = np.sign(np.sin(phase)) * 0.4 + np.sin(phase * 1.5) * 0.6
write("energy.wav", lowpass(zap, 4000) * env(d, 0.002, 0.15))

write("dryfire.wav", pad(highpass(white(0.03), 2000) * env(0.03, 0.0005, 0.006), 0.1))


def click(dur=0.04, hz=2500, decay=0.008):
    return highpass(white(dur), hz) * env(dur, 0.0005, decay)


r = np.zeros(int(SR * 1.0))
c1 = click(0.05, 1500, 0.01)
c2 = click(0.06, 900, 0.02)
r[int(SR * 0.05):int(SR * 0.05) + len(c1)] += c1
r[int(SR * 0.55):int(SR * 0.55) + len(c2)] += c2 * 1.2
write("reload.wav", r)


def place(total, events):
    """Mixes (start_time, signal, gain) events into one buffer of `total` seconds."""
    out = np.zeros(int(SR * total))
    for start, sig, gain in events:
        s = int(SR * start)
        n = min(len(sig), len(out) - s)
        out[s:s + n] += sig[:n] * gain
    return out


def metal_tick(hz, decay, dur=0.12):
    tt = t(dur)
    ring = np.sin(2 * np.pi * hz * tt) * np.exp(-tt / decay)
    return ring * 0.5 + highpass(white(dur), 2500) * np.exp(-tt / (decay * 0.4))


def thud(dur=0.15, cutoff=600, decay=0.03):
    return lowpass(white(dur), cutoff) * env(dur, 0.001, decay)


# Magazine out: release click, then the mag sliding out.
slide = highpass(white(0.18), 1200) * np.sin(np.pi * t(0.18) / 0.18) * 0.4
write("mag_out.wav", place(0.4, [(0.0, metal_tick(2200, 0.012), 1.0), (0.05, slide, 1.0)]))
# Magazine in: sliding in, then a solid clack.
write("mag_in.wav", place(0.35, [(0.0, slide[::-1], 0.8), (0.14, thud(0.15, 900, 0.025), 1.6),
                                  (0.14, metal_tick(1500, 0.02), 0.9)]))
# Bolt / charging handle: pulled back, released forward.
write("bolt.wav", place(0.45, [(0.0, metal_tick(1800, 0.015), 1.0), (0.02, slide[:3000], 0.6),
                                (0.2, metal_tick(1100, 0.03), 1.2), (0.2, thud(0.12, 700, 0.02), 1.4)]))
# Pump action: shuck back, shuck forward.
shuck = lowpass(white(0.12), 2500) * env(0.12, 0.002, 0.03)
write("pump.wav", place(0.45, [(0.0, shuck, 1.2), (0.0, metal_tick(900, 0.02), 0.6),
                                (0.2, shuck, 1.3), (0.2, metal_tick(700, 0.03), 0.8)]))
# One shell pushed into a tube / chamber.
write("shell_in.wav", place(0.2, [(0.0, metal_tick(2600, 0.01), 0.8), (0.03, thud(0.1, 1200, 0.02), 1.0)]))
# Break-action open / close.
write("break_open.wav", place(0.4, [(0.0, metal_tick(800, 0.04), 1.2), (0.0, thud(0.2, 400, 0.05), 1.0)]))
write("break_close.wav", place(0.3, [(0.0, metal_tick(1300, 0.025), 1.2), (0.0, thud(0.12, 800, 0.02), 1.6)]))
# Revolver cylinder: swing out with ratchet clicks.
write("cylinder.wav", place(0.5, [(i * 0.05, metal_tick(3000 - i * 150, 0.006, 0.05), 0.6) for i in range(6)]
                            + [(0.32, thud(0.12, 900, 0.02), 1.3)]))
# Energy cell: eject hiss, then a rising charge whine.
d = 0.9
whine_f = 300 + 1500 * (t(d) / d) ** 2
whine = np.sin(2 * np.pi * np.cumsum(whine_f) / SR) * np.clip(t(d) / 0.1, 0, 1) * np.exp(-((t(d) - d) ** 2) / 0.02)
write("energy_reload.wav", place(1.1, [(0.0, highpass(white(0.25), 3000) * env(0.25, 0.005, 0.08), 0.8),
                                       (0.15, whine, 0.7)]))
# Hit marker: short bright tick; kill marker: lower, punchier.
write("hitmarker.wav", place(0.12, [(0.0, metal_tick(3200, 0.012, 0.1), 1.0)]))
write("killmarker.wav", place(0.25, [(0.0, metal_tick(1800, 0.03, 0.2), 1.0), (0.0, thud(0.15, 500, 0.04), 1.2)]))

d = 0.25
sw = lowpass(white(d), 600 + 4000 * np.sin(np.pi * t(d) / d)) * np.sin(np.pi * t(d) / d) ** 2
write("knife.wav", sw)

d = 0.18
write("hit.wav", lowpass(white(d), 900) * env(d, 0.001, 0.04) + np.sin(2 * np.pi * 90 * t(d)) * env(d, 0.001, 0.05))
d = 0.35
write("headshot.wav", lowpass(white(d), 2200) * env(d, 0.001, 0.08) + 0.6 * np.sin(2 * np.pi * 60 * t(d)) * env(d, 0.001, 0.1))
d = 0.12

d = 0.5
cr = highpass(white(d), 800) * env(d, 0.001, 0.05)
cr += lowpass(white(d), 300) * env(d, 0.005, 0.12)
write("plank_break.wav", cr)
d = 0.3
write("plank_place.wav", lowpass(white(d), 500) * env(d, 0.001, 0.05) + np.sin(2 * np.pi * 180 * t(d)) * env(d, 0.001, 0.06))

# Purchase: two bright coin pings.
d = 0.6
p = np.zeros(int(SR * d))
for start, hz in ((0.0, 1318.5), (0.09, 1975.5)):
    s = int(SR * start)
    tt = np.arange(len(p) - s) / SR
    p[s:] += np.sin(2 * np.pi * hz * tt) * np.clip(tt / 0.002, 0, 1) * np.exp(-tt / 0.15)
write("buy.wav", p)
d = 0.35
write("denied.wav", np.sign(np.sin(2 * np.pi * 110 * t(d))) * 0.5 * env(d, 0.005, 0.2))


def groan(d, f0, wobble, brightness, seed):
    g = np.random.default_rng(seed)
    tt = t(d)
    f = f0 * (1 + 0.15 * np.sin(2 * np.pi * wobble * tt + g.uniform(0, 6))) * (1 - 0.25 * tt / d)
    phase = 2 * np.pi * np.cumsum(f) / SR
    saw = 2 * ((phase / (2 * np.pi)) % 1) - 1
    rough = g.uniform(-1, 1, len(tt))
    src = saw * 0.7 + rough * 0.5
    # Two crude formants ("aah" / "ooh") via band-passing.
    f1 = lowpass(src, brightness) - lowpass(src, brightness * 0.35)
    f2 = lowpass(src, brightness * 2.4) - lowpass(src, brightness * 1.6)
    shape = np.sin(np.pi * tt / d) ** 0.6
    return (f1 + 0.5 * f2) * shape


write("groan1.wav", groan(1.4, 85, 3.0, 700, 1))
write("groan2.wav", groan(1.1, 110, 5.0, 900, 2))
write("groan3.wav", groan(1.7, 70, 2.0, 600, 3))
write("growl.wav", groan(0.7, 140, 11.0, 1300, 4) + 0.3 * lowpass(white(0.7), 2000) * np.sin(np.pi * t(0.7) / 0.7))
write("zombie_death.wav", groan(0.9, 95, 1.5, 500, 5) * np.exp(-t(0.9) * 2))

d = 0.4
write("hurt.wav", lowpass(white(d), 400) * env(d, 0.001, 0.08) + np.sin(2 * np.pi * 55 * t(d)) * env(d, 0.001, 0.15))


def tone_seq(notes, dur_note, wave_fn, decay, gap=0.0, tail=0.6):
    total = len(notes) * (dur_note + gap) + tail
    out = np.zeros(int(SR * total))
    for i, hz in enumerate(notes):
        s = int(SR * i * (dur_note + gap))
        n = len(out) - s
        dd = n / SR
        tt = np.arange(n) / SR
        out[s:] += wave_fn(hz, tt) * np.clip(tt / 0.005, 0, 1) * np.exp(-tt / decay)
    return out


def bell(hz, tt):
    return (np.sin(2 * np.pi * hz * tt) + 0.5 * np.sin(2 * np.pi * hz * 2.76 * tt) * np.exp(-tt * 3)
            + 0.25 * np.sin(2 * np.pi * hz * 5.4 * tt) * np.exp(-tt * 6))


def pad_wave(hz, tt):
    return np.sin(2 * np.pi * hz * tt) + 0.3 * np.sin(2 * np.pi * hz * 2.01 * tt) + 0.2 * np.sin(2 * np.pi * hz * 0.5 * tt)


# Round start: low ominous bell strokes. Round end: descending minor figure.
write("round_start.wav", tone_seq([73.4, 73.4, 77.8], 0.9, bell, 1.2, tail=2.5))
write("round_end.wav", tone_seq([293.7, 277.2, 220.0, 146.8], 0.45, bell, 0.9, tail=2.0))
write("game_over.wav", tone_seq([146.8, 138.6, 110.0, 73.4], 0.8, pad_wave, 1.5, tail=3.0))

d = 1.0
sh = sum(np.sin(2 * np.pi * hz * t(d)) * np.exp(-t(d) * 3) for hz in (1568, 2093, 2637, 3136))
write("powerup_spawn.wav", sh * np.clip(t(d) / 0.05, 0, 1))
write("powerup_pick.wav", tone_seq([523.3, 659.3, 784.0, 1046.5], 0.07, lambda hz, tt: np.sin(2 * np.pi * hz * tt), 0.25, tail=0.5))
write("bomb.wav", lowpass(white(2.0), 600 * np.exp(-t(2.0) * 1.5) + 80) * env(2.0, 0.002, 0.6)
      + np.sin(2 * np.pi * 40 * t(2.0)) * env(2.0, 0.002, 0.5))

# Perk machine jingle (cheerful, slightly detuned organ).
def organ(hz, tt):
    return np.sin(2 * np.pi * hz * tt) + 0.5 * np.sin(2 * np.pi * hz * 2 * tt) + 0.3 * np.sin(2 * np.pi * hz * 3.01 * tt)


write("perk.wav", tone_seq([392, 523.3, 659.3, 784, 659.3, 784, 1046.5], 0.14, organ, 0.25, tail=0.8))

# Mystery box: music box arpeggio, about 4 s.
notes = [659.3, 784, 987.8, 1318.5, 1174.7, 987.8, 784, 880, 1046.5, 1318.5, 1567.9, 1318.5,
         1046.5, 880, 987.8, 1174.7, 1479.9, 1174.7, 987.8, 784, 659.3]
write("box.wav", tone_seq(notes, 0.18, lambda hz, tt: np.sin(2 * np.pi * hz * tt) + 0.2 * np.sin(2 * np.pi * hz * 4 * tt), 0.35, tail=0.5))

# Upgrade machine: rising mechanical whirr with clanks.
d = 3.2
tt = t(d)
f = 60 + 220 * tt / d
whirr = np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * 0.3 + lowpass(white(d), 400) * 0.6
for c in (0.2, 1.1, 2.0, 2.9):
    s = int(SR * c)
    k = click(0.15, 300, 0.05) * 2
    whirr[s:s + len(k)] += k
write("forge.wav", whirr * np.clip(tt / 0.1, 0, 1))

d = 1.2
creak_f = 200 + 80 * np.sin(2 * np.pi * 3 * t(d))
creak = lowpass(np.sign(np.sin(2 * np.pi * np.cumsum(creak_f) / SR)), 1500) * 0.3 * np.sin(np.pi * t(d) / d)
thud = np.zeros(int(SR * d))
th = lowpass(white(0.4), 200) * env(0.4, 0.002, 0.1)
thud[int(SR * 0.8):int(SR * 0.8) + len(th)] = th * 2
write("door.wav", creak + thud)

d = 0.25
write("step.wav", lowpass(white(d), 350) * env(d, 0.002, 0.03))
d = 0.6
write("jump_land.wav", lowpass(white(d), 250) * env(d, 0.002, 0.06))

# Dark ambient loop (10 s, loops cleanly: whole periods only).
d = 10.0
tt = t(d)
amb = (np.sin(2 * np.pi * 55 * tt) * 0.5 + np.sin(2 * np.pi * 82.5 * tt) * 0.3
       + np.sin(2 * np.pi * 110.3 * tt + 2 * np.sin(2 * np.pi * 0.2 * tt)) * 0.15)
amb *= 0.7 + 0.3 * np.sin(2 * np.pi * 0.1 * tt)
wind = lowpass(white(d), 300 + 200 * (np.sin(2 * np.pi * 0.3 * tt) + 1))
wind_loop = wind.copy()
xf = int(SR * 1.0)
wind_loop[:xf] = wind[:xf] * np.linspace(0, 1, xf) + wind[-xf:] * np.linspace(1, 0, xf)
x = amb * 0.6 + wind_loop * 2.0
data = (np.clip(norm(x, 0.5), -1, 1) * 32767).astype("<i2")
with wave.open(os.path.join(SFX, "ambient.wav"), "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(data.tobytes())

print("textures:", sorted(os.listdir(TEX)))
print("sounds:", sorted(os.listdir(SFX)))


# ----------------------------------------------------------------------------------------------
# Special round: zombie dogs
# ----------------------------------------------------------------------------------------------
def write_sfx(name, x):
    write(name, x)


# Howl: a long wavering cry that rises then falls, two voices slightly apart.
d = 2.6
tt = t(d)
contour = 380 + 260 * np.sin(np.pi * np.clip(tt / d * 1.15, 0, 1)) ** 1.5
howl = np.zeros_like(tt)
for detune, gain in ((1.0, 1.0), (1.012, 0.6), (2.0, 0.25)):
    f = contour * detune * (1 + 0.012 * np.sin(2 * np.pi * 5.5 * tt))
    howl += np.sin(2 * np.pi * np.cumsum(f) / SR) * gain
howl *= np.clip(tt / 0.25, 0, 1) * np.clip((d - tt) / 0.6, 0, 1)
howl += lowpass(white(d), 1200) * 0.08 * np.clip(tt / 0.25, 0, 1)
write_sfx("howl.wav", howl)
# Bark / bite: a short rough snarl and a snap of the jaws.
bark = groan(0.28, 260, 18.0, 1800, 9) * np.exp(-t(0.28) * 6)
write_sfx("bark.wav", place(0.4, [(0.0, bark, 1.0), (0.22, metal_tick(900, 0.01, 0.08), 0.8)]))
# Dog death: whimper turning into a crackling burst of embers.
whimper_f = 700 * np.exp(-t(0.4) * 3)
whimper = np.sin(2 * np.pi * np.cumsum(whimper_f) / SR) * np.exp(-t(0.4) * 5)
crackle = np.zeros(int(SR * 0.9))
for i in range(40):
    s0 = rng.integers(0, len(crackle) - 400)
    crackle[s0:s0 + 300] += highpass(white(300 / SR), 2000) * rng.uniform(0.2, 1.0) * np.exp(-np.arange(300) / 60)
write_sfx("dog_death.wav", place(1.0, [(0.0, whimper, 0.8), (0.1, crackle, 0.9), (0.1, lowpass(white(0.5), 300) * env(0.5, 0.002, 0.12), 1.2)]))
# Thunder crack (dog appearing): sharp crack, then a long low rumble.
d = 2.2
rumble = lowpass(white(d), 140 + 300 * np.exp(-t(d) * 3)) * env(d, 0.01, 0.7) * 3
write_sfx("thunder.wav", place(d, [(0.0, highpass(white(0.12), 1500) * env(0.12, 0.0005, 0.03), 1.0), (0.02, rumble, 1.0)]))


# ----------------------------------------------------------------------------------------------
# Equipment and power
# ----------------------------------------------------------------------------------------------
def _thud(dur, cutoff, decay):
    return lowpass(white(dur), cutoff) * env(dur, 0.001, decay)


# Grenade: sharp crack, heavy boom, debris.
d = 1.6
boom = lowpass(white(d), 900 * np.exp(-t(d) * 4) + 90) * env(d, 0.001, 0.35) * 2.5
write("grenade_explode.wav", place(d, [(0.0, highpass(white(0.08), 1800) * env(0.08, 0.0005, 0.02), 1.0),
                                       (0.0, boom, 1.0),
                                       (0.0, np.sin(2 * np.pi * 45 * t(d)) * env(d, 0.002, 0.4), 1.2)]))
# Decoy: a cheerful little march on a toy organ, 8 s, with a drum.
melody = [523.3, 659.3, 784.0, 659.3, 698.5, 880.0, 784.0, 659.3, 587.3, 698.5, 880.0, 1046.5,
          987.8, 784.0, 659.3, 523.3]
def toy(hz, tt):
    return np.sign(np.sin(2 * np.pi * hz * tt)) * 0.3 + np.sin(2 * np.pi * hz * 2 * tt) * 0.3
tune = tone_seq(melody * 2, 0.24, toy, 0.18, gap=0.01, tail=0.3)
drum = np.zeros_like(tune)
for i in range(0, int(len(tune) / SR / 0.25)):
    s0 = int(SR * i * 0.25)
    hitn = lowpass(white(0.1), 300 if i % 2 == 0 else 2500) * env(0.1, 0.001, 0.03)
    drum[s0:s0 + len(hitn)] += hitn[:max(0, min(len(hitn), len(drum) - s0))] * (1.2 if i % 2 == 0 else 0.5)
write("decoy.wav", tune * 0.8 + drum)
# Power on: heavy switch clunk, then a rising electrical hum.
d = 2.5
hum_f = 50 + 70 * np.clip(t(d) / 1.5, 0, 1)
hum = (np.sin(2 * np.pi * np.cumsum(hum_f) / SR) + 0.5 * np.sin(2 * np.pi * np.cumsum(hum_f * 2) / SR)
       + 0.3 * np.sign(np.sin(2 * np.pi * np.cumsum(hum_f * 3) / SR))) * np.clip(t(d) / 0.4, 0, 1) * np.clip((d - t(d)) / 0.6, 0, 1)
write("power_on.wav", place(d, [(0.0, _thud(0.3, 300, 0.08), 2.0), (0.0, metal_tick(400, 0.06, 0.3), 1.2), (0.15, hum, 0.6)]))
# Electric zap (trap).
d = 0.5
zap = (np.sign(np.sin(2 * np.pi * 120 * t(d))) * 0.4 + highpass(white(d), 3000)) * (rng.uniform(0, 1, len(t(d))) > 0.3) * np.exp(-t(d) * 3)
write("zap.wav", zap)
# Colosse: a deep, slow roar (low voices, rough noise), and a heavy ground smash.
d = 2.2
tt = t(d)
contour = 85 + 45 * np.sin(np.pi * np.clip(tt / d * 1.1, 0, 1))
roar = np.zeros_like(tt)
for detune, gain in ((1.0, 1.0), (1.5, 0.5), (2.02, 0.35), (3.01, 0.2)):
    f = contour * detune * (1 + 0.03 * np.sin(2 * np.pi * 7.0 * tt))
    roar += np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * gain * 0.5 + np.sin(2 * np.pi * np.cumsum(f) / SR) * gain * 0.5
roar = lowpass(roar, 1400) + lowpass(white(d), 700) * 0.5
roar *= np.clip(tt / 0.15, 0, 1) * np.clip((d - tt) / 0.7, 0, 1)
write("brute_roar.wav", roar)
d = 0.9
write("brute_smash.wav", place(d, [(0.0, _thud(0.6, 220, 0.12), 2.5), (0.0, lowpass(white(0.5), 1500) * env(0.5, 0.001, 0.12), 0.8),
                                   (0.05, metal_tick(180, 0.1, 0.4), 0.6)]))
# Crawler: a wet scraping drag.
d = 0.7
write("crawl.wav", lowpass(white(d), 900) * (0.5 + 0.5 * np.sin(2 * np.pi * 3.0 * t(d))) * np.clip((d - t(d)) / 0.3, 0, 1) * 0.8)


# ----------------------------------------------------------------------------------------------
# Weapon camouflages (unlocked by kills) and the challenge jingle.
# ----------------------------------------------------------------------------------------------
def blobs(colors, sigma, seed_shift=0):
    """Layered camouflage blobs: each colour wins where its own smooth noise is highest."""
    fields = [noise(sigma) + 0.15 * noise(sigma / 3) for _ in colors]
    idx = np.argmax(np.stack(fields), axis=0)
    out = np.array(colors)[idx]
    return out


save("camo_treillis.png", blobs([(0.2, 0.24, 0.13), (0.34, 0.3, 0.18), (0.11, 0.1, 0.08), (0.42, 0.41, 0.27)], 9))
save("camo_desert.png", blobs([(0.78, 0.68, 0.5), (0.63, 0.51, 0.35), (0.52, 0.4, 0.26), (0.72, 0.6, 0.42)], 12))
# Digital: blocky pixels from a small grid.
small = blobs([(0.08, 0.16, 0.38), (0.16, 0.32, 0.62), (0.3, 0.5, 0.82), (0.06, 0.08, 0.14)], 2.5)
small = small[::8, ::8]
save("camo_cobalt.png", np.kron(small, np.ones((8, 8, 1))))
# Ember: black rock with glowing cracks (the bright parts glow in game).
ridge = 1 - np.abs(fbm((2, 4, 8)) - 0.5) * 2
cracks = np.clip((ridge - 0.86) / 0.14, 0, 1) ** 1.5
base = colorize(fbm() * 0.4, (0.03, 0.02, 0.02), (0.14, 0.1, 0.08))
save("camo_braise.png", np.clip(base + cracks[..., None] * np.array([1.0, 0.45, 0.08]), 0, 1))
# Obsidian: glassy black with violet veins.
ridge = 1 - np.abs(fbm((3, 6, 12)) - 0.5) * 2
veins = np.clip((ridge - 0.9) / 0.1, 0, 1)
base = colorize(fbm((1, 2, 4)) * 0.5, (0.02, 0.015, 0.03), (0.1, 0.07, 0.14))
save("camo_obsidienne.png", np.clip(base + veins[..., None] * np.array([0.65, 0.2, 1.0]), 0, 1))

# Challenge complete: a short bright rising arpeggio.
write("challenge.wav", tone_seq([659.3, 830.6, 987.8, 1318.5], 0.09, bell, 0.25, gap=0.0, tail=0.8) * 0.8)

# ----------------------------------------------------------------------------------------------
# Melee swings, blade hits and the rocket launcher.
# ----------------------------------------------------------------------------------------------
def whoosh(d, f_from, f_to, gain=1.0):
    """Air swish: band of noise whose centre sweeps from f_from to f_to, loudest mid-swing."""
    tt = t(d)
    x = white(d)
    out = np.zeros_like(x)
    steps = 12
    for i in range(steps):
        a, b = int(len(x) * i / steps), int(len(x) * (i + 1) / steps)
        fc = f_from + (f_to - f_from) * i / (steps - 1)
        seg = highpass(lowpass(x, fc * 1.6), fc * 0.6)
        out[a:b] = seg[a:b]
    return out * np.sin(np.pi * np.clip(tt / d, 0, 1)) ** 1.5 * gain


write("axe_swing.wav", whoosh(0.42, 500, 180, 1.4))
write("sabre_swing.wav", place(0.3, [(0.0, whoosh(0.22, 2400, 900, 1.2), 1.0), (0.0, metal_tick(3200, 0.05, 0.15), 0.25)]))
write("blade_hit.wav", place(0.35, [(0.0, _thud(0.25, 500, 0.05), 1.6), (0.0, lowpass(white(0.12), 2500) * env(0.12, 0.001, 0.03), 0.9)]))
# Rocket: a hard thump then the hiss of the motor.
d = 1.2
hiss = highpass(white(d), 1500) * np.clip(t(d) / 0.05, 0, 1) * np.exp(-t(d) * 2.2) * 0.6
write("rocket_fire.wav", place(d, [(0.0, _thud(0.3, 200, 0.08), 2.2), (0.02, hiss, 1.0), (0.0, lowpass(white(0.2), 800) * env(0.2, 0.001, 0.06), 1.2)]))


# ----------------------------------------------------------------------------------------------
# Village textures: stone walls, plaster, cobbles, roof tiles, grass.
# ----------------------------------------------------------------------------------------------
from scipy.spatial import cKDTree


def voronoi_cells(points_n, size=N, jitter_seed=None):
    """Tileable Voronoi: distance to nearest and second-nearest point, and the cell id."""
    pts = rng.uniform(0, size, (points_n, 2))
    tiled = np.concatenate([pts + np.array([dx, dy]) * size for dx in (-1, 0, 1) for dy in (-1, 0, 1)])
    ids = np.tile(np.arange(points_n), 9)
    tree = cKDTree(tiled)
    yy, xx = np.mgrid[0:size, 0:size]
    d, i = tree.query(np.stack([xx.ravel(), yy.ravel()], axis=1), k=2)
    d1 = d[:, 0].reshape(size, size)
    d2 = d[:, 1].reshape(size, size)
    cell = ids[i[:, 0]].reshape(size, size)
    return d1, d2, cell


# Rough stone wall: irregular stones in mortar.
d1, d2, cell = voronoi_cells(70)
edge = np.clip((d2 - d1) / 3.5, 0, 1)
tone = rng.uniform(-0.12, 0.12, 70)[cell]
v = np.clip(0.45 + 0.3 * fbm((1, 2, 4)) + tone, 0, 1) * edge + 0.12 * (1 - edge)
save("pierre.png", colorize(v, (0.12, 0.11, 0.1), (0.62, 0.58, 0.52)))
# Cobblestones: rounder, darker, smaller.
d1, d2, cell = voronoi_cells(110)
edge = np.clip((d2 - d1) / 4.0, 0, 1) ** 0.7
tone = rng.uniform(-0.1, 0.1, 110)[cell]
v = np.clip(0.4 + 0.25 * fbm((1, 3)) + tone + 0.2 * (1 - d1 / d1.max()), 0, 1) * edge + 0.05 * (1 - edge)
save("paves.png", colorize(v, (0.06, 0.06, 0.07), (0.48, 0.47, 0.46)))
# Plaster: pale, stained, a few cracks.
v = fbm((2, 4, 8, 16))
stains = gaussian_filter(rng.standard_normal((N, N)), (22, 4), mode="wrap")
stains = (stains - stains.min()) / (stains.max() - stains.min())
v = np.clip(0.7 * v + 0.3 * (1 - stains ** 2), 0, 1)
save("enduit.png", colorize(v, (0.36, 0.33, 0.28), (0.72, 0.67, 0.58)))
# Roof tiles: rows of curved terracotta tiles.
yy, xx = np.mgrid[0:N, 0:N]
row_h = N // 8
col_w = N // 8
off = ((yy // row_h) % 2) * (col_w // 2)
u = ((xx + off) % col_w) / col_w
vrow = (yy % row_h) / row_h
curve = np.sin(np.pi * u) ** 0.6
shadow = np.clip(1.0 - vrow ** 4 * 1.2, 0, 1)
tint = rng.uniform(-0.1, 0.1, (8, 9))[(yy // row_h) % 8, ((xx + off) // col_w) % 9]
v = np.clip(0.35 + 0.45 * curve * shadow + tint + 0.15 * fbm((2, 6)), 0, 1)
save("tuiles.png", colorize(v, (0.18, 0.06, 0.03), (0.62, 0.3, 0.18)))
# Grass: dark, patchy, with bits of earth.
v = fbm((1, 2, 4, 8, 16))
blades = gaussian_filter(rng.standard_normal((N, N)), (2.5, 0.6), mode="wrap")
blades = (blades - blades.min()) / (blades.max() - blades.min())
earth = np.clip(noise(10) * 1.8 - 1.0, 0, 1)
g = colorize(np.clip(0.5 * v + 0.5 * blades, 0, 1), (0.04, 0.07, 0.03), (0.2, 0.3, 0.12))
e = colorize(v, (0.08, 0.06, 0.04), (0.28, 0.22, 0.15))
save("herbe.png", g * (1 - earth[..., None]) + e * earth[..., None])
