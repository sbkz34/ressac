# Ressac

Battle royale mobile pour Android dans l'esprit du mode Résurgence : une petite île, des parties
courtes, et on revient en jeu après une mort tant que la réapparition est ouverte. Solo contre
des bots d'abord, multijoueur ensuite. Fait avec Godot 4.6 (rendu « Compatibility », adapté aux
GPU Mali), avec les graphismes et les sons de [Dernière Vague](https://github.com/sbkz34/derniere-vague).

**Télécharger l'APK :** [ressac.apk](../../releases/latest/download/ressac.apk)

- [Plan du projet](PLAN.md) — règles gardées (shop, loadouts, cancel slide, parachute), jalons, choix techniques.
- [La carte](docs/carte.md) — l'Île du Lazaret, ses lieux et comment la modifier.

![L'Île du Lazaret](docs/carte.png)

## État actuel : jalon 2, les armes et le combat

Chaque partie commence dans l'avion qui traverse l'île : saut, chute libre, parachute. Sur l'île,
**158 objets** répartis dans les bâtiments (armes de toutes raretés, munitions, plaques d'armure,
argent) et **19 coffres** ; les lieux à 3 étoiles (Lazaret, Conserverie) sont les mieux fournis.
Au **champ de tir de la Batterie**, des mannequins en armure à 10, 25 (mobile), 50 et 70 m,
toutes les armes en épique et une caisse de ravitaillement sans fin.

Mouvement du jalon 1 : sprint, sprint tactique, glissade et **cancel slide**, escalade de rebords,
accroupi / couché, nage, parachute (ouvrir, couper, rouvrir), redéploiement depuis un point haut.

| Action | Manette | Clavier / souris | Tactile |
|---|---|---|---|
| Se déplacer / regarder | Sticks | ZQSD / souris | Stick à gauche / glisser à droite |
| Tirer / viser | RT / LT | Clic gauche / clic droit | TIR (on peut glisser dessus pour viser) / VISER |
| Ramasser, ouvrir un coffre | X | E ou F | ACTION (apparaît quand c'est possible) |
| Recharger | X (quand il n'y a rien à ramasser) | R | RECH. |
| Changer d'arme | Y | 1, 2, molette | ARME |
| Plaque d'armure (maintenir) | RB | 4 ou X | PLAQUE |
| Sauter, escalader, sauter de l'avion, ouvrir le parachute | A | Espace | SAUT |
| Accroupi · glissade en courant · annuler la glissade · couper le parachute (maintenir : couché) | B | C | ACCROUPI |
| Sprint (encore une fois en courant : sprint tactique) | L3 | Maj | SPRINT ou stick poussé au bord |
| Carte · pause et réglages | Select · Start | M · Échap | CARTE · II |

**Cancel slide** : en sprint, glisser (B), puis appuyer de nouveau sur B pendant la glissade : on
se relève en sprint sans perdre l'élan, et le sprint tactique est rechargé.

**Combat** : santé 100 qui remonte après 4,5 s sans dégâts, armure jusqu'à 150 en trois plaques
de 50 qui ne remontent pas. Dégâts par zone (tête, torse, jambes) et selon la distance. Marqueurs
de touche : blanc (corps), jaune (tête), bleu (armure), bleu épais (armure brisée), rouge
(élimination). À la manette et au tactile, la visée ralentit sur une cible et se cale dessus
quand on épaule.

| Arme | Type | Coups au torse (armure pleine) | Temps pour éliminer |
|---|---|---|---|
| Fusil d'assaut Faucon | Fusil d'assaut | 9 | 0,72 s |
| Mitrailleuse Titan | Mitrailleuse | 8 | 0,67 s |
| Mitraillette Vipère | Mitraillette | 11 | 0,75 s |
| Mitraillette Ouragan | Mitraillette | 12 | 0,66 s |
| Mini Uzi | Mitraillette | 13 | 0,66 s |
| Carabine K14 | Fusil tactique | 5 | 0,88 s |
| Fusil de précision Aiguille | Fusil de précision | 2 (1 dans la tête) | 1,15 s |
| Fusil à pompe Grêle | Fusil à pompe | 2 à bout portant | 0,85 s |
| Pistolet P9 | Pistolet | 10 | 1,26 s |
| Revolver Taureau | Pistolet | 5 | 1,68 s |

Raretés : commune, rare (bleu), épique (violet), légendaire (or) — chargeur plus grand, moins de
dispersion, visée plus rapide.

| | |
|---|---|
| ![Champ de tir](docs/captures/25_champ_de_tir.jpg) | ![Visée](docs/captures/26_visee.jpg) |
| ![Lunette](docs/captures/27_lunette.jpg) | ![Butin](docs/captures/28_butin.jpg) |
| ![Saut d'avion](docs/captures/20_avion.jpg) | ![Glissade](docs/captures/22_glissade.jpg) |

## Développement

- `data/ile.json` décrit l'île ; `python3 tools/gen_island.py` génère le relief, les sols, la
  végétation et les cartes (`assets/map/`, `docs/carte.png`).
- `tools/gen_assets.py` (repris de Dernière Vague) génère les textures et les sons.
- Vérifications : `godot --headless --fixed-fps 60 --path . -- --check` (relief, escaliers, glissade,
  cancel slide, sprint tactique, escalade, parachute, redéploiement, avion, nage, drone, interface,
  butin, ramassage, rechargement, balles pour éliminer au champ de tir, tête au fusil de précision,
  plaques, régénération, coffres).
- Captures de chaque lieu : `godot --path . -- --tour --shots=/tmp/captures`.
- Chaque push sur `main` vérifie l'île, compile l'APK (GitHub Actions) et publie une release.

## Aperçu de l'île

| | |
|---|---|
| ![Le Lazaret](docs/captures/01_lazaret.jpg) | ![La cour du Lazaret](docs/captures/02_lazaret_cour.jpg) |
| ![Le Port](docs/captures/08_port.jpg) | ![La Conserverie](docs/captures/07_conserverie.jpg) |
| ![Les Cabanons](docs/captures/10_cabanons.jpg) | ![Le Phare](docs/captures/03_phare.jpg) |
