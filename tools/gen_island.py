#!/usr/bin/env python3
"""Génère l'Île du Lazaret à partir de data/ile.json.

Lancer depuis la racine du dépôt :  python3 tools/gen_island.py

Produit :
  assets/map/hauteurs.png    relief (hauteur codée sur 16 bits dans R et G), lu par le jeu
  assets/map/sols.png        mélange des sols (R sable, G roche, B chemin, A pavés)
  assets/map/sols2.png       R béton
  assets/map/carte.png       carte tactique (vue de dessus, quadrillage), utilisée en jeu
  assets/tex/sable.png       texture de sable (même style que les textures de Dernière Vague)
  data/vegetation.json       pins parasols, buissons et rochers
  docs/carte.png             la carte annotée (noms des lieux, stations d'achat, légende)

Tout est déterministe : même fichier de données, même île.
"""
import json
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from scipy.ndimage import distance_transform_edt, gaussian_filter, map_coordinates

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
DATA = json.load(open(os.path.join(ROOT, "data", "ile.json"), encoding="utf-8"))
MAP = os.path.join(ROOT, "assets", "map")
os.makedirs(MAP, exist_ok=True)
os.makedirs(os.path.join(ROOT, "docs"), exist_ok=True)

WORLD = DATA["monde"]           # 640 m de côté, centré sur 0
CELL = DATA["cellule"]          # 2 m entre deux points du relief
N = int(WORLD / CELL) + 1       # 321 points
HALF = WORLD / 2
H_MIN, H_RANGE = -10.0, 64.0    # plage codée dans hauteurs.png
rng = np.random.default_rng(DATA["graine"])

xs = np.linspace(-HALF, HALF, N)
X, Z = np.meshgrid(xs, xs)       # X[row, col] = x, Z[row, col] = z (ligne = z)


def smoothstep(e0, e1, v):
    t = np.clip((v - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def noise(sigma_m, shape=(N, N), cell=CELL):
    a = gaussian_filter(rng.standard_normal(shape), sigma_m / cell)
    a -= a.mean()
    return a / max(np.abs(a).max(), 1e-9)


def rot(x, z, deg):
    """Même convention que Godot (rotation autour de Y, angle positif = sens anti-horaire vu du dessus)."""
    a = math.radians(deg)
    return x * math.cos(a) + z * math.sin(a), -x * math.sin(a) + z * math.cos(a)


# ----------------------------------------------------------------------------------------------
# Forme de l'île
# ----------------------------------------------------------------------------------------------
def ellipse_field(m):
    return 1.0 - np.sqrt(((X - m["x"]) / m["rx"]) ** 2 + ((Z - m["z"]) / m["rz"]) ** 2)


land = np.max([ellipse_field(m) for m in DATA["masses"]], axis=0)
land += 0.10 * noise(30) + 0.06 * noise(12)
for c in DATA["creux"]:
    land = np.minimum(land, -ellipse_field(c))

# ----------------------------------------------------------------------------------------------
# Relief
# ----------------------------------------------------------------------------------------------
inland = smoothstep(0.0, 0.22, land)
h = np.where(land > 0, 0.8 + 10.0 * np.power(np.clip(land, 0, None), 0.8), 0.8 + land * 55.0)
hills = np.zeros_like(h)
for c in DATA["collines"]:
    d2 = (X - c["x"]) ** 2 + (Z - c["z"]) ** 2
    hills += c["h"] * np.exp(-d2 / (2 * c["s"] ** 2))
h += hills * inland
h += (2.2 * noise(20) + 0.8 * noise(6)) * inland

# Plateaux sous les lieux : le sol y est plat pour poser les bâtiments.
on_land = smoothstep(-0.03, 0.03, land)
for p in DATA["lieux"]:
    d = np.sqrt((X - p["x"]) ** 2 + (Z - p["z"]) ** 2)
    w = smoothstep(p["rayon"] + 26, p["rayon"], d) * on_land
    h = h * (1 - w) + p["h"] * w

# Zones dégagées avec une hauteur (le champ de tir) : un plateau rectangulaire bien plat.
for c in DATA.get("zones_degagees", []):
    if "h" not in c:
        continue
    ox = np.maximum(np.abs(X - c["x"]) - c["rx"], 0.0)
    oz = np.maximum(np.abs(Z - c["z"]) - c["rz"], 0.0)
    w = smoothstep(16.0, 0.0, np.sqrt(ox ** 2 + oz ** 2)) * on_land
    h = h * (1 - w) + c["h"] * w

# Chemins : on adoucit le relief le long des routes.
road_mask = Image.new("L", (N, N), 0)
dr = ImageDraw.Draw(road_mask)
to_px = lambda x, z: ((x + HALF) / CELL, (z + HALF) / CELL)
for r in DATA["routes"]:
    dr.line([to_px(*pt) for pt in r], fill=255, width=3, joint="curve")
road_d = distance_transform_edt(np.array(road_mask) < 128) * CELL
road_w = smoothstep(9.0, 2.0, road_d) * on_land
h = h * (1 - 0.6 * road_w) + gaussian_filter(h, 2.0) * 0.6 * road_w

h = np.clip(h, H_MIN, H_MIN + H_RANGE - 0.01)

# Contrôles : chaque lieu est sur la terre ferme, à la bonne hauteur.
for p in DATA["lieux"]:
    i, j = int(round((p["z"] + HALF) / CELL)), int(round((p["x"] + HALF) / CELL))
    assert land[i, j] > 0.02, f"{p['nom']} est dans l'eau"
    assert abs(h[i, j] - p["h"]) < 0.5, f"{p['nom']} : hauteur {h[i, j]:.1f} au lieu de {p['h']}"

v = np.round((h - H_MIN) / H_RANGE * 65535).astype(np.uint32)
img = np.zeros((N, N, 3), np.uint8)
img[..., 0] = v >> 8
img[..., 1] = v & 255
Image.fromarray(img, "RGB").save(os.path.join(MAP, "hauteurs.png"))

# ----------------------------------------------------------------------------------------------
# Sols, à 1 m par pixel
# ----------------------------------------------------------------------------------------------
S = 641
fine = np.linspace(0, N - 1, S)
FI, FJ = np.meshgrid(fine, fine, indexing="ij")
hf = map_coordinates(h, [FI, FJ], order=1)
lf = map_coordinates(land, [FI, FJ], order=1)
gz, gx = np.gradient(hf, 1.0)
slope = np.sqrt(gx ** 2 + gz ** 2)
fx = np.linspace(-HALF, HALF, S)
FX, FZ = np.meshgrid(fx, fx)

sand = smoothstep(2.4, 1.2, hf) * (1 - smoothstep(0.55, 0.8, slope))
rock = smoothstep(0.55, 0.95, slope) + smoothstep(-2.0, -5.0, hf) * 0.6
rock = np.clip(rock + 0.25 * noise(4, (S, S), 1.0) * smoothstep(0.3, 0.6, slope), 0, 1)

road_fine = Image.new("L", (S, S), 0)
dr = ImageDraw.Draw(road_fine)
for r in DATA["routes"]:
    dr.line([(x + HALF, z + HALF) for x, z in r], fill=255, width=4, joint="curve")
path = np.array(road_fine.filter(ImageFilter.GaussianBlur(1.6)), np.float32) / 255.0
paved = np.zeros((S, S), np.float32)
concrete = np.zeros((S, S), np.float32)
for p in DATA["lieux"]:
    d = np.sqrt((FX - p["x"]) ** 2 + (FZ - p["z"]) ** 2)
    edge = p["rayon"] * (0.62 if p["sol"] == "paves" else 0.85) + 6 * noise(8, (S, S), 1.0)
    w = smoothstep(edge + 1.5, edge - 1.5, d)
    if p["sol"] == "paves":
        paved = np.maximum(paved, w)
    elif p["sol"] == "concrete":
        concrete = np.maximum(concrete, w)
    else:
        path = np.maximum(path, w * 0.85)
dry = smoothstep(0.1, 0.9, noise(25, (S, S), 1.0) * 0.5 + 0.5) * 0.35  # plaques de terre sèche
path = np.maximum(path, dry * (1 - sand))

# Les sols les plus "construits" passent devant.
paved *= (1 - sand * 0.5)
concrete *= (1 - paved)
path *= (1 - np.maximum(paved, concrete))
rock *= (1 - np.maximum(paved, concrete)) * (1 - path * 0.7)
sand *= (1 - rock)


def u8(a):
    return (np.clip(a, 0, 1) * 255).astype(np.uint8)


Image.fromarray(np.dstack([u8(sand), u8(rock), u8(path), u8(paved)]), "RGBA").save(os.path.join(MAP, "sols.png"))
Image.fromarray(np.dstack([u8(concrete)] * 3), "RGB").save(os.path.join(MAP, "sols2.png"))

# ----------------------------------------------------------------------------------------------
# Texture de sable (même méthode que tools/gen_assets.py, pavable)
# ----------------------------------------------------------------------------------------------
T = 256
trng = np.random.default_rng(11)


def tnoise(sigma):
    a = gaussian_filter(trng.standard_normal((T, T)), sigma, mode="wrap")
    a -= a.min()
    return a / max(a.max(), 1e-9)


sv = 0.45 * tnoise(1) + 0.3 * tnoise(3) + 0.25 * tnoise(12)
ripples = 0.5 + 0.5 * np.sin((np.arange(T)[None, :] / T * 2 * np.pi * 9) + tnoise(10) * 6)
sv = np.clip(0.75 * sv + 0.25 * ripples, 0, 1)
dark, light = np.array([0.52, 0.45, 0.32]), np.array([0.86, 0.79, 0.62])
sand_tex = dark + (light - dark) * sv[..., None]
Image.fromarray((sand_tex * 255).astype(np.uint8), "RGB").save(os.path.join(ROOT, "assets", "tex", "sable.png"))


# ----------------------------------------------------------------------------------------------
# Bâtiments : emprises au sol (pour la carte et pour éloigner la végétation)
# ----------------------------------------------------------------------------------------------
def footprints():
    """Liste de (type, polygone monde [(x, z)...], cercle (x, z, r) ou None)."""
    out = []
    for p in DATA["lieux"]:
        for b in p["batiments"]:
            t = b["t"]
            r = b.get("r", 0)

            def world(lx, lz):
                rx, rz = rot(lx, lz, r)
                return p["x"] + b["x"] + rx, p["z"] + b["z"] + rz

            if t in ("bat", "hangar", "bunker", "quai", "bassins", "tombes"):
                w, d = b["w"], b["d"]
                out.append((t, [world(sx * w / 2, sz * d / 2) for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))], None, b))
            elif t == "conteneur":
                out.append((t, [world(sx * 3.0, sz * 1.2) for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))], None, b))
            elif t == "mur":
                w, e = b["w"], 0.5
                out.append((t, [world(sx * w / 2, sz * e / 2) for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))], None, b))
            elif t == "grue":
                out.append((t, [world(sx * 1.5, sz * 1.5) for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))], None, b))
            else:
                radius = {"phare": 3.6, "citerne": 5.0, "cheminee": 1.8, "mat": 2.0, "tas": 3.0,
                          "fontaine": 2.0, "emplacement": 4.0}[t]
                cx, cz = world(0, 0)
                out.append((t, None, (cx, cz, radius), b))
    return out


FOOT = footprints()

# ----------------------------------------------------------------------------------------------
# Végétation : pins parasols, buissons, rochers
# ----------------------------------------------------------------------------------------------
blocked = Image.new("L", (S, S), 0)
db = ImageDraw.Draw(blocked)
for t, poly, circ, _ in FOOT:
    if poly:
        db.polygon([(x + HALF, z + HALF) for x, z in poly], fill=255)
    else:
        x, z, rr = circ
        db.ellipse([x + HALF - rr, z + HALF - rr, x + HALF + rr, z + HALF + rr], fill=255)
for s in DATA["boutiques"]:
    db.ellipse([s["x"] + HALF - 4, s["z"] + HALF - 4, s["x"] + HALF + 4, s["z"] + HALF + 4], fill=255)
free_d = distance_transform_edt(np.array(blocked) < 128)


def sample(a, x, z):
    return a[int(round(z + HALF)), int(round(x + HALF))]


grass = np.clip(1 - sand - rock - path - paved - concrete, 0, 1)
vrng = np.random.default_rng(DATA["graine"] + 1)
veg = {"pins": [], "buissons": [], "rochers": []}
forest = noise(40, (S, S), 1.0)  # bosquets : les pins se regroupent


def pick(count, ok, tries=40000):
    found = []
    for _ in range(tries):
        if len(found) >= count:
            break
        x, z = vrng.uniform(-HALF + 4, HALF - 4, 2)
        if ok(x, z):
            found.append((x, z))
    return found


def cleared(x, z):
    return any(abs(x - c["x"]) < c["rx"] and abs(z - c["z"]) < c["rz"] for c in DATA.get("zones_degagees", []))


def near_poi(x, z, margin):
    return any(math.hypot(x - p["x"], z - p["z"]) < p["rayon"] * 0.7 + margin for p in DATA["lieux"])


def ok_pine(x, z):
    return (sample(grass, x, z) > 0.6 and 2.5 < sample(hf, x, z) < 34 and sample(slope, x, z) < 0.45
            and sample(free_d, x, z) > 7 and sample(path, x, z) < 0.2 and not near_poi(x, z, -6) and not cleared(x, z)
            and vrng.random() < 0.25 + 0.75 * max(0.0, sample(forest, x, z)))


def ok_bush(x, z):
    return (sample(grass, x, z) > 0.4 and sample(hf, x, z) > 1.5 and sample(slope, x, z) < 0.7
            and sample(free_d, x, z) > 3 and sample(path, x, z) < 0.3 and not cleared(x, z))


def ok_rock(x, z):
    return (sample(lf, x, z) > -0.01 and (sample(rock, x, z) > 0.35 or (sample(sand, x, z) > 0.5 and vrng.random() < 0.08))
            and sample(free_d, x, z) > 5 and sample(path, x, z) < 0.2 and not cleared(x, z))


for x, z in pick(240, ok_pine):
    veg["pins"].append([round(x, 1), round(z, 1), round(float(vrng.uniform(6.5, 11.0)), 1), round(float(vrng.uniform(0, 360)))])
for x, z in pick(420, ok_bush):
    veg["buissons"].append([round(x, 1), round(z, 1), round(float(vrng.uniform(0.6, 1.4)), 2)])
for x, z in pick(170, ok_rock):
    veg["rochers"].append([round(x, 1), round(z, 1), round(float(vrng.uniform(0.8, 2.6)), 2), round(float(vrng.uniform(0, 360)))])
json.dump(veg, open(os.path.join(ROOT, "data", "vegetation.json"), "w"), separators=(",", ":"))

# ----------------------------------------------------------------------------------------------
# Carte tactique (2 px par mètre, monde entier)
# ----------------------------------------------------------------------------------------------
PX = 2
M = WORLD * PX
big = lambda a: np.array(Image.fromarray(a.astype(np.float32), "F").resize((M, M), Image.BILINEAR))
H2 = big(hf)
L2 = big(lf)

# Ombrage du relief (lumière du nord-ouest).
gz2, gx2 = np.gradient(H2, 1.0 / PX)
nx, ny, nz = -gx2, np.ones_like(H2), -gz2
nl = np.sqrt(nx ** 2 + ny ** 2 + nz ** 2)
lx, ly, lz = -0.6, 0.7, -0.6
ll = math.sqrt(lx * lx + ly * ly + lz * lz)
shade = np.clip((nx * lx + ny * ly + nz * lz) / (nl * ll), 0, 1)
shade = 0.55 + 0.6 * shade

col = np.zeros((M, M, 3), np.float32)
grass_c = np.array([0.47, 0.52, 0.30])
high_c = np.array([0.56, 0.55, 0.40])
c_land = grass_c + (high_c - grass_c) * smoothstep(8, 36, H2)[..., None]
layers = [
    (big(sand), np.array([0.85, 0.78, 0.58])),
    (big(rock), np.array([0.55, 0.53, 0.50])),
    (big(path), np.array([0.70, 0.62, 0.46])),
    (big(paved), np.array([0.66, 0.60, 0.55])),
    (big(concrete), np.array([0.62, 0.62, 0.60])),
]
col[:] = c_land
for wgt, c in layers:
    col = col * (1 - wgt[..., None]) + c * wgt[..., None]
col *= shade[..., None]

depth = np.clip(-H2 / 9.0, 0, 1)
shallow, deep = np.array([0.30, 0.66, 0.70]), np.array([0.07, 0.22, 0.36])
sea = shallow + (deep - shallow) * np.power(depth, 0.6)[..., None]
foam = smoothstep(0.6, 0.0, np.abs(H2 - 0.2))[..., None] * 0.25
water = smoothstep(0.5, -0.1, H2)[..., None]
col = col * (1 - water) + (sea + foam) * water
img = Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8), "RGB")
d = ImageDraw.Draw(img, "RGBA")

P = lambda x, z: ((x + HALF) * PX, (z + HALF) * PX)

# Végétation.
for x, z, hgt, _ in veg["pins"]:
    cx, cz = P(x, z)
    rr = hgt * 0.42 * PX
    d.ellipse([cx - rr, cz - rr, cx + rr, cz + rr], fill=(46, 70, 38, 235), outline=(30, 46, 26, 255))
for x, z, s in veg["buissons"]:
    cx, cz = P(x, z)
    rr = max(1.5, s * PX)
    d.ellipse([cx - rr, cz - rr, cx + rr, cz + rr], fill=(70, 92, 52, 200))
for x, z, s, _ in veg["rochers"]:
    cx, cz = P(x, z)
    rr = s * 0.7 * PX
    d.ellipse([cx - rr, cz - rr, cx + rr, cz + rr], fill=(120, 116, 108, 220))

# Bâtiments.
STYLE = {
    "bat": ((88, 84, 82, 255), (210, 204, 196, 255)),
    "hangar": ((96, 76, 66, 255), (200, 180, 160, 255)),
    "bunker": ((92, 94, 92, 255), (170, 170, 166, 255)),
    "quai": ((112, 88, 60, 255), (150, 122, 86, 255)),
    "conteneur": ((150, 70, 52, 255), (60, 40, 30, 255)),
    "mur": ((150, 140, 128, 255), None),
    "bassins": ((176, 196, 200, 200), (230, 230, 226, 255)),
    "tombes": ((182, 176, 166, 160), None),
    "grue": ((196, 150, 40, 255), None),
}
for t, poly, circ, b in FOOT:
    if poly:
        fill, outline = STYLE[t]
        if t == "conteneur":
            fill = [(150, 70, 52, 255), (52, 92, 120, 255), (70, 110, 70, 255)][int(abs(b["x"] * 7 + b["z"] * 3)) % 3]
        d.polygon([P(*q) for q in poly], fill=fill, outline=outline)
        if t == "bassins":
            # Cloisons entre bassins.
            p0, p1, p2, p3 = poly
            for k in range(1, b["nx"]):
                f = k / b["nx"]
                a = (p0[0] + (p1[0] - p0[0]) * f, p0[1] + (p1[1] - p0[1]) * f)
                c2 = (p3[0] + (p2[0] - p3[0]) * f, p3[1] + (p2[1] - p3[1]) * f)
                d.line([P(*a), P(*c2)], fill=(230, 230, 226, 255), width=2)
            for k in range(1, b["nz"]):
                f = k / b["nz"]
                a = (p0[0] + (p3[0] - p0[0]) * f, p0[1] + (p3[1] - p0[1]) * f)
                c2 = (p1[0] + (p2[0] - p1[0]) * f, p1[1] + (p2[1] - p1[1]) * f)
                d.line([P(*a), P(*c2)], fill=(230, 230, 226, 255), width=2)
    else:
        x, z, rr = circ
        cx, cz = P(x, z)
        rr *= PX
        if t == "emplacement":
            d.ellipse([cx - rr, cz - rr, cx + rr, cz + rr], outline=(160, 160, 156, 255), width=3)
        elif t == "tas":
            d.ellipse([cx - rr, cz - rr, cx + rr, cz + rr], fill=(240, 238, 230, 255))
        elif t == "fontaine":
            d.ellipse([cx - rr, cz - rr, cx + rr, cz + rr], fill=(120, 170, 180, 255), outline=(200, 196, 186, 255), width=2)
        else:
            d.ellipse([cx - rr, cz - rr, cx + rr, cz + rr], fill=(80, 78, 76, 255), outline=(220, 214, 204, 255), width=2)

img.save(os.path.join(MAP, "carte_fond.png"))


# Quadrillage façon carte militaire : colonnes A–J, lignes 1–10 (cases de 64 m).
def font(size, bold=True):
    name = "DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf"
    for base in ("/usr/share/fonts/truetype/dejavu/", "/usr/share/fonts/dejavu/"):
        if os.path.exists(base + name):
            return ImageFont.truetype(base + name, size)
    return ImageFont.load_default()


GRID = 10
step = M / GRID
d = ImageDraw.Draw(img, "RGBA")
for k in range(1, GRID):
    d.line([(k * step, 0), (k * step, M)], fill=(255, 255, 255, 60), width=1)
    d.line([(0, k * step), (M, k * step)], fill=(255, 255, 255, 60), width=1)
f_grid = font(18)
for k in range(GRID):
    letter = "ABCDEFGHIJ"[k]
    d.text((k * step + step / 2, 14), letter, font=f_grid, fill=(255, 255, 255, 200), anchor="mm")
    d.text((14, k * step + step / 2), str(k + 1), font=f_grid, fill=(255, 255, 255, 200), anchor="mm")


def shop_icon(draw, x, z, s=11):
    cx, cz = P(x, z)
    draw.rounded_rectangle([cx - s, cz - s, cx + s, cz + s], radius=4, fill=(255, 196, 40, 255), outline=(40, 30, 10, 255), width=2)
    draw.text((cx, cz + 1), "€", font=font(int(s * 1.5)), fill=(40, 30, 10, 255), anchor="mm")


for s in DATA["boutiques"]:
    shop_icon(d, s["x"], s["z"])

# Version jeu : sans les noms (le jeu affiche les siens), avec le quadrillage et les boutiques.
img.save(os.path.join(MAP, "carte.png"))

# Version documentée : noms des lieux et légende, recadrée sur l'île.
doc = img.copy()
d = ImageDraw.Draw(doc, "RGBA")
f_label = font(26)
for p in DATA["lieux"]:
    cx, cz = P(p["x"] + p["etiquette"][0], p["z"] + p["etiquette"][1])
    d.text((cx, cz), p["nom"].upper(), font=f_label, fill=(255, 255, 255, 255), anchor="mm",
           stroke_width=4, stroke_fill=(20, 24, 28, 255))
f_small = font(18, bold=False)
d.text(P(-40, -186), "l'Îlot", font=f_small, fill=(255, 255, 255, 230), anchor="mm", stroke_width=3, stroke_fill=(20, 24, 28, 255))
d.text(P(45, 168), "Anse du Port", font=f_small, fill=(230, 245, 250, 230), anchor="mm", stroke_width=3, stroke_fill=(15, 50, 70, 255))
d.text(P(-200, -150), "Calanque", font=f_small, fill=(230, 245, 250, 230), anchor="mm", stroke_width=3, stroke_fill=(15, 50, 70, 255))

# Légende (en bas à gauche) et échelle.
lx0, ly0 = 40, M - 210
d.rounded_rectangle([lx0, ly0, lx0 + 330, ly0 + 170], radius=10, fill=(16, 20, 24, 210))
d.text((lx0 + 18, ly0 + 22), DATA["nom"].upper(), font=font(22), fill=(255, 255, 255, 255), anchor="lm")
shop_icon(d, (lx0 + 30) / PX - HALF, (ly0 + 62) / PX - HALF, 10)
d.text((lx0 + 52, ly0 + 62), "Station d'achat", font=f_small, fill=(240, 240, 240, 255), anchor="lm")
d.rectangle([lx0 + 20, ly0 + 88, lx0 + 40, ly0 + 104], fill=(88, 84, 82, 255), outline=(210, 204, 196, 255))
d.text((lx0 + 52, ly0 + 96), "Bâtiment (accessible)", font=f_small, fill=(240, 240, 240, 255), anchor="lm")
d.ellipse([lx0 + 22, ly0 + 120, lx0 + 38, ly0 + 136], fill=(46, 70, 38, 255))
d.text((lx0 + 52, ly0 + 128), "Pins parasols", font=f_small, fill=(240, 240, 240, 255), anchor="lm")
sx0 = M - 60 - 100 * PX
d.line([(sx0, M - 50), (sx0 + 100 * PX, M - 50)], fill=(255, 255, 255, 255), width=4)
d.text((sx0 + 50 * PX, M - 72), "100 m", font=f_small, fill=(255, 255, 255, 255), anchor="mm",
       stroke_width=3, stroke_fill=(20, 24, 28, 255))
d.text((M - 60, 60), "N ▲", font=font(26), fill=(255, 255, 255, 255), anchor="rm", stroke_width=3, stroke_fill=(20, 24, 28, 255))
doc.save(os.path.join(ROOT, "docs", "carte.png"))

print("Île générée :", N, "x", N, "points de relief,",
      len(veg["pins"]), "pins,", len(veg["buissons"]), "buissons,", len(veg["rochers"]), "rochers,",
      sum(len(p["batiments"]) for p in DATA["lieux"]), "éléments construits.")
print("Hauteur max : %.1f m" % h.max())

# ----------------------------------------------------------------------------------------------
# Icône de l'application : la silhouette de l'île sur la mer, soleil couchant.
# ----------------------------------------------------------------------------------------------
I = 256
icon = Image.new("RGB", (I, I))
grad = np.linspace(0, 1, I)[:, None, None]
sky = np.array([0.95, 0.62, 0.32]) * (1 - grad) + np.array([0.08, 0.2, 0.32]) * grad
icon = Image.fromarray((np.repeat(sky, I, axis=1) * 255).astype(np.uint8), "RGB")
di = ImageDraw.Draw(icon)
di.ellipse([150, 52, 214, 116], fill=(255, 214, 120))
di.rectangle([0, 150, I, I], fill=(18, 58, 84))
# Silhouette de l'île : profil du relief pris sur une ligne est-ouest.
row = h[int((-40 + HALF) / CELL)]
pts = [(0, 150)]
for k in range(I):
    x = int(k / I * N)
    pts.append((k, 150 - max(0.0, row[x]) * 2.2))
pts.append((I, 150))
di.polygon(pts, fill=(28, 38, 40))
for k in range(5):
    y = 168 + k * 18
    di.line([(20 + k * 6, y), (236 - k * 10, y)], fill=(120, 190, 200), width=3)
icon.save(os.path.join(ROOT, "icon.png"))
