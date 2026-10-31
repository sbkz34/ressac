#!/usr/bin/env python3
"""Sons propres à Ressac (ceux de Dernière Vague viennent de tools/gen_assets.py).

Pas sur la terre, sur un sol dur et dans l'eau (plusieurs variantes, plus naturels que l'ancien
« step »), vent de chute libre et sous la voile, ouverture du parachute, sortie de l'avion, moteur
de l'avion, entrée dans l'eau et brasse, marqueurs de touche (corps, tête, armure, armure brisée),
battements de cœur quand on est à bout de forces, tyrolienne, ouverture de coffre, annonce, musique de fin de partie, pluie.

    python3 tools/gen_sons.py        → assets/sfx/*.wav
"""
import os
import wave

import numpy as np
from scipy.signal import butter, sosfilt

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sfx")
SR = 44100
rng = np.random.default_rng(20261028)


def t(d):
    return np.arange(int(SR * d)) / SR


def white(d):
    return rng.standard_normal(int(SR * d))


def band(x, lo, hi, order=2):
    sos = butter(order, [lo, hi], btype="bandpass", fs=SR, output="sos")
    return sosfilt(sos, x)


def low(x, hz, order=2):
    return sosfilt(butter(order, hz, btype="lowpass", fs=SR, output="sos"), x)


def high(x, hz, order=2):
    return sosfilt(butter(order, hz, btype="highpass", fs=SR, output="sos"), x)


def env(d, attack, decay):
    tt = t(d)
    return np.clip(tt / max(attack, 1e-5), 0, 1) * np.exp(-tt / decay)


def place(total, events):
    out = np.zeros(int(SR * total))
    for start, sig, gain in events:
        s = int(SR * start)
        n = max(0, min(len(sig), len(out) - s))
        out[s:s + n] += sig[:n] * gain
    return out


def write(name, x, peak=0.9, fade=True):
    m = np.max(np.abs(x))
    x = x * (peak / m) if m > 0 else x
    if fade:
        f = min(len(x), 300)
        x[-f:] *= np.linspace(1, 0, f)
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(os.path.join(ROOT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(name, f"{len(x) / SR:.2f} s")


def loopable(x, xfade=0.25):
    """Boucle sans clic : la fin se fond dans le début."""
    n = int(SR * xfade)
    head, body = x[:n], x[n:]
    ramp = np.linspace(0, 1, n)
    body[-n:] = body[-n:] * (1 - ramp) + head * ramp
    return body


def grains(d, count, lo, hi, gmin=0.6, gmax=3.0, spread=1.0):
    """Petits craquements (gravier, herbe sèche) répartis sur la durée."""
    out = np.zeros(int(SR * d))
    for _ in range(count):
        g = rng.uniform(gmin, gmax) / 1000.0
        n = int(SR * g * 4)
        s = int(rng.beta(1.3, 2.6) * spread * (len(out) - n))
        gr = band(rng.standard_normal(n), lo, hi) * np.exp(-np.arange(n) / (SR * g)) * rng.uniform(0.2, 1.0)
        out[s:s + n] += gr
    return out


# ------------------------------------------------------------------------------------------------
# Pas
# ------------------------------------------------------------------------------------------------
for k in range(4):
    # Terre, herbe : talon sourd, puis le craquement du sol sous la semelle et la pointe du pied.
    d = 0.22
    heel = low(white(d), 260) * env(d, 0.004, 0.022)
    thump = np.sin(2 * np.pi * rng.uniform(60, 80) * t(d)) * env(d, 0.003, 0.025) * 0.5
    crunch = low(grains(0.16, 38, 900, 4200), 5000)
    toe = low(white(0.1), 400) * env(0.1, 0.003, 0.015)
    x = place(d, [(0.0, heel, 1.0), (0.0, thump, 1.0), (0.012, crunch, 0.55), (rng.uniform(0.05, 0.07), toe, 0.5)])
    write(f"pas_terre_{k + 1}.wav", x, peak=0.55)
    # Sol dur (pierre, béton, planches) : talon plus net, semelle qui frotte un peu.
    heel = band(white(d), 180, 1400) * env(d, 0.002, 0.012)
    body = low(white(d), 220) * env(d, 0.003, 0.02)
    scuff = band(white(0.08), 1500, 5000) * env(0.08, 0.01, 0.018)
    toe = band(white(0.08), 200, 1600) * env(0.08, 0.002, 0.008)
    x = place(d, [(0.0, heel, 1.0), (0.0, body, 0.9), (0.01, scuff, 0.18), (rng.uniform(0.045, 0.065), toe, 0.55)])
    write(f"pas_dur_{k + 1}.wav", x, peak=0.5)
    # Eau peu profonde : remous et gouttes.
    d = 0.35
    slosh = band(white(d), 300, 2500) * env(d, 0.01, 0.07)
    drops = grains(0.3, 14, 1500, 6000, 2.0, 6.0)
    write(f"pas_eau_{k + 1}.wav", place(d, [(0.0, slosh, 1.0), (0.03, drops, 0.5)]), peak=0.5)

# ------------------------------------------------------------------------------------------------
# Air : chute libre, voile, sortie de l'avion, moteur
# ------------------------------------------------------------------------------------------------
d = 4.0
tt = t(d + 0.25)
gust = 1.0 + 0.35 * np.sin(2 * np.pi * 0.5 * tt) + 0.2 * np.sin(2 * np.pi * 1.25 * tt + 1.0)
rush = band(white(d + 0.25), 140, 1400, 2) * gust + band(white(d + 0.25), 1800, 4500) * 0.08 * gust
write("vent_chute.wav", loopable(rush), peak=0.7, fade=False)
# Sous la voile : vent plus doux et la toile qui claque par moments.
calm = band(white(d + 0.25), 120, 900, 1) * (1.0 + 0.3 * np.sin(2 * np.pi * 0.3 * tt))
flaps = np.zeros_like(calm)
for s in np.arange(0.2, d, 0.37):
    n = int(SR * 0.05)
    i = int(SR * (s + rng.uniform(-0.08, 0.08)))
    flaps[i:i + n] += band(white(0.05), 200, 1200) * np.exp(-np.arange(n) / (SR * 0.012)) * rng.uniform(0.2, 0.8)
write("vent_voile.wav", loopable(calm + flaps * 1.2), peak=0.6, fade=False)
# Ouverture du parachute : froissement qui monte, puis la toile qui se tend d'un coup.
d = 0.9
rustle = band(white(d), 400, 3500) * np.clip(t(d) / 0.45, 0, 1) ** 2 * np.exp(-np.clip(t(d) - 0.45, 0, None) / 0.08)
snap = low(white(0.4), 500) * env(0.4, 0.004, 0.06)
thwump = np.sin(2 * np.pi * 55 * t(0.4)) * env(0.4, 0.005, 0.08)
write("voile.wav", place(d, [(0.0, rustle, 0.7), (0.42, snap, 1.0), (0.42, thwump, 0.8)]))
# Sortie de l'avion : on passe dans le flux d'air (souffle qui enfle puis s'éloigne), sans choc.
d = 1.3
swell = np.sin(np.pi * np.clip(t(d) / d, 0, 1)) ** 1.2
whoosh = band(white(d), 220, 1800, 2) * swell * (0.6 + 0.4 * np.exp(-t(d) * 2))
write("sortie_avion.wav", whoosh, peak=0.6)
# Moteur de l'avion (cabine) : ronflement grave des hélices, en boucle.
d = 3.0
tt = t(d + 0.25)
f0 = 38.0
drone = sum(np.sin(2 * np.pi * f0 * h * tt + rng.uniform(0, 6)) / h for h in (1, 2, 3, 4, 6))
drone *= 1.0 + 0.15 * np.sin(2 * np.pi * f0 * 0.5 * tt)
hum = low(white(d + 0.25), 300) * 0.8
write("moteur_avion.wav", loopable(low(drone, 500) * 0.6 + hum), peak=0.6, fade=False)

# ------------------------------------------------------------------------------------------------
# Eau : plongeon et brasse
# ------------------------------------------------------------------------------------------------
d = 1.1
impact = band(white(d), 200, 3000) * env(d, 0.003, 0.09)
bubbles = np.zeros(int(SR * d))
for _ in range(26):
    n = int(SR * 0.04)
    s = int(rng.uniform(0.05, 0.8) * SR)
    f = rng.uniform(500, 1600)
    b = np.sin(2 * np.pi * np.cumsum(np.linspace(f, f * 1.5, n)) / SR) * np.exp(-np.arange(n) / (SR * 0.008))
    bubbles[s:s + n] += b * rng.uniform(0.1, 0.4)
splash_tail = band(white(d), 1500, 6000) * env(d, 0.01, 0.2) * 0.3
write("plouf.wav", impact + bubbles + splash_tail)
d = 0.6
stroke = band(white(d), 250, 1800) * np.sin(np.pi * np.clip(t(d) / d, 0, 1)) ** 2
write("brasse.wav", stroke + grains(d, 10, 1500, 5000, 2.0, 5.0) * 0.4, peak=0.5)

# ------------------------------------------------------------------------------------------------
# Marqueurs de touche
# ------------------------------------------------------------------------------------------------
# Corps : un « tac » sec et bref, bien audible sans être aigu.
d = 0.09
tac = band(white(d), 1800, 5200) * env(d, 0.0005, 0.006)
knock = np.sin(2 * np.pi * 1150 * t(d)) * env(d, 0.0005, 0.012) * 0.6
write("marque_corps.wav", tac + knock, peak=0.8)
# Tête : plus clair, avec une petite résonance.
d = 0.2
ping = (np.sin(2 * np.pi * 2650 * t(d)) + 0.5 * np.sin(2 * np.pi * 3980 * t(d))) * env(d, 0.0005, 0.035)
write("marque_tete.wav", ping * 0.7 + band(white(d), 2500, 7000) * env(d, 0.0005, 0.005), peak=0.75)
# Armure : impact sur une plaque, mat et un peu céramique.
d = 0.14
plate = band(white(d), 700, 2600) * env(d, 0.0005, 0.01)
ring = np.sin(2 * np.pi * 1720 * t(d)) * env(d, 0.0005, 0.025) * 0.35
write("marque_armure.wav", plate + ring, peak=0.75)
# Armure brisée : une plaque qui éclate (craquement + éclats).
d = 0.5
crack = band(white(d), 900, 5000) * env(d, 0.0005, 0.02)
shards = grains(0.4, 40, 2500, 9000, 0.8, 3.0)
crunch = band(white(d), 300, 1500) * env(d, 0.001, 0.04)
write("armure_brisee.wav", place(d, [(0.0, crack, 1.0), (0.0, crunch, 0.8), (0.02, shards, 0.7)]), peak=0.85)

# ------------------------------------------------------------------------------------------------
# Battements de cœur (à bout de forces), un battement double
# ------------------------------------------------------------------------------------------------
d = 0.9
beat = lambda: low(np.sin(2 * np.pi * 52 * t(0.18)) * env(0.18, 0.006, 0.05) + low(white(0.18), 120) * env(0.18, 0.004, 0.03) * 0.5, 180)
write("coeur.wav", place(d, [(0.0, beat(), 1.0), (0.24, beat(), 0.7)]), peak=0.8)

# Tyrolienne : la poulie qui file sur le câble (sifflement métallique qui monte, cliquetis),
# puis l'arrivée (choc sourd).
d = 2.8
tt = t(d)
f = 520 + 260 * np.clip(tt / 0.6, 0, 1)
whine = np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.35 + np.sin(2 * np.pi * np.cumsum(f * 2.01) / SR) * 0.15
whine *= 0.6 + 0.4 * np.sin(2 * np.pi * 7.0 * tt)
rattle = band(white(d), 1800, 5000) * (0.5 + 0.5 * (np.sin(2 * np.pi * 23.0 * tt) > 0.6))
hiss = band(white(d), 300, 1500) * 0.6
body = (whine + rattle * 0.35 + hiss) * np.clip(tt / 0.15, 0, 1) * np.clip((d - tt) / 0.5, 0, 1)
dd = 0.35
clunk = low(white(dd), 400) * env(dd, 0.002, 0.08) * 1.6 + np.sin(2 * np.pi * 140 * t(dd)) * env(dd, 0.001, 0.06)
write("tyrolienne.wav", place(d + 0.4, [(0.0, body, 0.8), (d - 0.15, clunk, 1.0)]), peak=0.6)

# Ouverture de coffre, courte : déclic du loquet, couvercle qui grince un instant, choc du bois.
d = 0.5
tt = t(d)
click = band(white(d), 2500, 7000) * env(d, 0.0005, 0.008)
f = 380 + 260 * np.clip(tt / 0.18, 0, 1)
creak = np.sin(2 * np.pi * np.cumsum(f) / SR) * (0.6 + 0.4 * (np.sin(2 * np.pi * 47 * tt) > 0))
creak = band(creak, 300, 2500) * np.clip(tt / 0.02, 0, 1) * np.exp(-tt * 9.0) * 0.5
thud = low(white(d), 300) * env(d, 0.002, 0.06) * 1.4 + np.sin(2 * np.pi * 110 * tt) * env(d, 0.001, 0.05)
write("coffre.wav", place(d, [(0.0, click, 0.9), (0.03, creak, 0.7), (0.22, thud, 1.0)]), peak=0.7)

# Annonce (Brume, survivants, ravitaillement) : impact grave et souffle qui monte.
d = 1.6
tt = t(d)
hit = (np.sin(2 * np.pi * 55 * tt) + 0.5 * np.sin(2 * np.pi * 82.5 * tt) + 0.3 * np.sin(2 * np.pi * 110 * tt)) * np.exp(-tt * 2.2)
brass = sum(np.sin(2 * np.pi * f * tt) / (h + 1) for h, f in enumerate([220, 330, 440, 660])) * np.exp(-tt * 3.0) * np.clip(tt / 0.03, 0, 1)
rise = band(white(d), 600, 4000) * np.clip((tt - 0.05) / 0.8, 0, 1) * np.exp(-np.maximum(tt - 0.85, 0) * 8.0) * 0.25
write("annonce.wav", low(hit, 400) * 0.9 + low(brass, 2500) * 0.35 + rise, peak=0.75)

# Musique de fin de partie (boucle de 16 s, 120 bpm) : basse obstinée en ré mineur, grosse caisse,
# charleston, nappe tendue. La fin de la boucle rejoint son début.
bpm = 120.0
beat = 60.0 / bpm
d = 32 * beat
n = int(d * SR)
tt = np.arange(n) / SR
mus = np.zeros(n)
def note(f, start, dur, amp, shape="saw"):
    i0 = int(start * SR)
    m = min(int(dur * SR), n - i0)
    if m <= 0:
        return
    x = np.arange(m) / SR
    if shape == "saw":
        w = sum(np.sin(2 * np.pi * f * k * x) / k for k in range(1, 7))
    else:
        w = np.sin(2 * np.pi * f * x) + 0.3 * np.sin(2 * np.pi * 2 * f * x)
    e = np.clip(x / 0.01, 0, 1) * np.exp(-x * 5.0)
    mus[i0:i0 + m] += w * e * amp
bass = [73.42, 73.42, 87.31, 73.42, 65.41, 65.41, 77.78, 69.30]   # ré, ré, fa, ré, do, do, mi♭, do♯
for bar in range(8):
    for k in range(8):
        f = bass[bar] * (2.0 if k in (3, 7) else 1.0)
        note(f, (bar * 4 + k * 0.5) * beat, 0.45 * beat, 0.28)
mus = low(mus, 900)
kick_len = int(0.25 * SR)
kx = np.arange(kick_len) / SR
kick = np.sin(2 * np.pi * (45 + 90 * np.exp(-kx * 30)) * kx) * np.exp(-kx * 14)
for b in range(32):
    i0 = int(b * beat * SR)
    m = min(kick_len, n - i0)
    mus[i0:i0 + m] += kick[:m] * 0.9
hat = band(white(0.05), 6000, 12000) * env(0.05, 0.001, 0.02)
for b in range(64):
    i0 = int((b * 0.5 + 0.25) * beat * SR)
    m = min(len(hat), n - i0)
    mus[i0:i0 + m] += hat[:m] * (0.25 if b % 2 else 0.15)
snare = band(white(0.2), 800, 6000) * env(0.2, 0.001, 0.07)
for b in range(32):
    if b % 4 in (1, 3):
        i0 = int(b * beat * SR)
        m = min(len(snare), n - i0)
        mus[i0:i0 + m] += snare[:m] * 0.35
pad = sum(np.sin(2 * np.pi * f * tt + k) for k, f in enumerate([293.66, 349.23, 440.0, 466.16]))
pad = low(pad, 1800) * (0.5 + 0.5 * np.sin(2 * np.pi * tt / (8 * beat))) * 0.07
mus += pad
write("musique_fin.wav", mus, peak=0.7, fade=False)

# Pluie (boucle de 6 s) : souffle large, crépitement de gouttes, quelques gouttes plus lourdes.
d = 6.0
wash = band(white(d + 0.25), 400, 7000) * 0.5 + low(white(d + 0.25), 500) * 0.4
patter = grains(d + 0.25, 2600, 2000, 9000, 0.3, 1.2) * 0.35
heavy = grains(d + 0.25, 140, 600, 2500, 1.5, 3.0) * 0.3
write("pluie.wav", loopable(wash + patter + heavy), peak=0.55, fade=False)
