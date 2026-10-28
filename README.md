# Ressac

Battle royale mobile pour Android dans l'esprit du mode Résurgence : une petite île, des parties
courtes, et on revient en jeu après une mort tant que la réapparition est ouverte. Solo contre
des bots d'abord, multijoueur ensuite. Fait avec Godot 4.6 (rendu « Compatibility », adapté aux
GPU Mali), avec les graphismes et les sons de [Dernière Vague](https://github.com/sbkz34/derniere-vague).

**Télécharger l'APK :** [ressac.apk](../../releases/latest/download/ressac.apk)

- [Plan du projet](PLAN.md) — règles gardées (shop, loadouts, cancel slide, parachute), jalons, choix techniques.
- [La carte](docs/carte.md) — l'Île du Lazaret, ses lieux et comment la modifier.

![L'Île du Lazaret](docs/carte.png)

## État actuel : jalon 0, la carte

On visite l'île à pied ou en drone. La carte tactique montre sa position.

| Action | Manette | Clavier / souris | Tactile |
|---|---|---|---|
| Se déplacer | Stick gauche | ZQSD / WASD | Stick à gauche de l'écran |
| Regarder | Stick droit | Souris (clic pour capturer) | Glisser à droite de l'écran |
| Sauter / monter (drone) | A | Espace | SAUT |
| Descendre (drone) | B | C | BAS |
| Sprint / drone rapide | Clic stick gauche | Maj | Stick poussé au bord |
| Drone | Y | F | DRONE |
| Carte | Select | M ou Tab | CARTE |

## Développement

- `data/ile.json` décrit l'île ; `python3 tools/gen_island.py` génère le relief, les sols, la
  végétation et les cartes (`assets/map/`, `docs/carte.png`).
- `tools/gen_assets.py` (repris de Dernière Vague) génère les textures et les sons.
- Vérifications : `godot --headless --path . -- --check` (relief, escaliers, nage, drone).
- Captures de chaque lieu : `godot --path . -- --tour --shots=/tmp/captures`.
- Chaque push sur `main` vérifie l'île, compile l'APK (GitHub Actions) et publie une release.

## Aperçu

| | |
|---|---|
| ![Le Lazaret](docs/captures/01_lazaret.jpg) | ![La cour du Lazaret](docs/captures/02_lazaret_cour.jpg) |
| ![Le Port](docs/captures/08_port.jpg) | ![La Conserverie](docs/captures/07_conserverie.jpg) |
| ![Les Cabanons](docs/captures/10_cabanons.jpg) | ![Le Phare](docs/captures/03_phare.jpg) |
