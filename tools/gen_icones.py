#!/usr/bin/env python3
"""Icônes des atouts et des équipements (pictogrammes au trait, blancs : le jeu les teinte).

    python3 tools/gen_icones.py   → assets/ui/icones/*.svg
Les rendus des armes (assets/ui/armes/*.png) viennent du jeu : godot --path . -- --icones=DIR
"""
import json
import os

ICONES = {
    "double_temps": "M14 12l12 12-12 12M26 12l12 12-12 12M3 18h7M1 24h9M3 30h7",
    "pillard": "M18 9h12l-3 6c7 3 11 9 11 15 0 7-6 11-14 11s-14-4-14-11c0-6 4-12 11-15zM19 15h10M24 30m-5 0a5 5 0 1 0 10 0a5 5 0 1 0-10 0",
    "ravitailleur": "M6 13h22v6H6zM6 22h22v6H6zM6 31h22v6H6zM39 19v12M33 25h12",
    "fixation": "M11 8h22v32H11zM25 13l-7 11h9l-7 11",
    "robuste": "M24 40S8 30 8 19a8 8 0 0 1 16-3 8 8 0 0 1 16 3c0 11-16 21-16 21zM24 19v11M18.5 24.5h11",
    "dur_a_cuire": "M24 6l15 6v10c0 10-7 17-15 20C16 39 9 32 9 22V12zM15 23c3-3 6 3 9 0s6 3 9 0",
    "amorti": "M24 5v21M17 19l7 7 7-7M7 34c6 4 28 4 34 0M10 41h28",
    "tete_froide": "M24 24m-13 0a13 13 0 1 0 26 0a13 13 0 1 0-26 0M24 4v9M24 35v9M4 24h9M35 24h9M24 24m-2 0a2 2 0 1 0 4 0a2 2 0 1 0-4 0",
    "fouineur": "M6 28h18v13H6zM6 28l4-6h10l4 6M31 16m-8 0a8 8 0 1 0 16 0a8 8 0 1 0-16 0M37 22l7 7",
    "grenade": "M24 30m-11 0a11 11 0 1 0 22 0a11 11 0 1 0-22 0M20 19v-5h8v5M28 14l8-4M18 30h12",
    "fumigene": "M10 22h13v20H10zM10 22v-4h13v4M27 21a5 5 0 1 1 6-7 5 5 0 1 1 7 6 4 4 0 0 1-2 7h-9a4 4 0 0 1-2-6z",
}

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "ui", "icones")
os.makedirs(ROOT, exist_ok=True)
for name, d in ICONES.items():
    svg = ('<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 48 48">'
           f'<path d="{d}" fill="none" stroke="#ffffff" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/></svg>\n')
    with open(os.path.join(ROOT, name + ".svg"), "w") as f:
        f.write(svg)
with open(os.path.join(ROOT, "icones.json"), "w") as f:
    json.dump(ICONES, f, ensure_ascii=False, indent=1)
print(len(ICONES), "icônes")
