# Ressac — plan du projet

Battle royale mobile (APK Android, Godot 4.6) dans l'esprit du mode **Résurgence** de Warzone :
une petite île, des parties courtes et nerveuses, et surtout **on revient en jeu** après une mort
tant que la règle de réapparition le permet. Le *ressac*, c'est la vague qui revient.

On développe d'abord **en solo contre des bots**, puis le **multijoueur**. Le moteur, le style
graphique, les textures, les sons et une bonne partie du code viennent de
[Dernière Vague](https://github.com/sbkz34/derniere-vague).

> Inspiration de gameplay uniquement : l'île, les noms, les armes et tous les assets sont
> originaux (générés par code, comme dans Dernière Vague). Rien n'est repris d'Activision.

---

## 1. Ce qu'on garde du mode Résurgence

| Élément | Comment on le fait dans Ressac |
|---|---|
| **Réapparition** | À la mort, on regarde la partie depuis le ciel ; après un compte à rebours on est **largué en parachute** au bord de la zone. Le compte à rebours s'allonge à chaque phase (10 s → 20 s → 30 s). À la dernière phase, plus de réapparition : la dernière vie compte. En équipe, un coéquipier en vie accélère le retour en faisant des éliminations. |
| **Stations d'achat** | 5 sur l'île (voir la carte). On y dépense l'argent ramassé : largage de classe, plaques d'armure, kit d'auto-réanimation, drone de repérage, rachat d'un coéquipier, munitions. |
| **Loadouts** | Préparés **dans le lobby** (5 emplacements) : arme principale, arme secondaire, 3 atouts, un létal, un tactique. Récupérés en jeu par un **largage de classe** (acheté en station, ou offert à tous au début de la phase 2). |
| **Cancel slide** | Glissade en sprintant (accroupi), puis **annulation** (accroupi ou saut) qui remet en sprint sans perdre la vitesse. Fenêtre de temps et vitesses réglables. |
| **Parachute** | Saut depuis l'avion au début, au réapparition, et redéploiement depuis un point haut (au-delà de ~12 m de chute). On peut ouvrir, refermer et rouvrir. |

## 2. Boucle d'une partie

1. **Lobby** : choix des loadouts, de l'équipe (solo / duo / trio contre bots), lancement.
2. **Saut** : l'avion traverse l'île sur une ligne aléatoire, chacun saute où il veut.
3. **Pillage** : armes au sol, coffres, argent. Les lieux à fort butin (Lazaret, Conserverie) sont plus disputés.
4. **La Brume** : un brouillard toxique venu de la mer referme l'aire de jeu en 6 phases. Le cercle final tombe sur un lieu tiré au sort parmi ceux qui s'y prêtent.
5. **Réapparitions** jusqu'à la phase 5, puis dernière vie.
6. **Victoire** : dernière équipe en vie. Écran de fin, XP, défis (comme dans Dernière Vague).

Durée visée : **12 à 15 minutes**, 24 à 32 combattants (joueur + bots).

## 3. Ce qu'on reprend de Dernière Vague

| Dernière Vague | Dans Ressac |
|---|---|
| `tools/gen_assets.py`, `assets/tex`, `assets/sfx` | Repris tels quels (déjà dans le dépôt). Sable ajouté par `tools/gen_island.py`. |
| Construction des niveaux en code (`level.gd` : `box`, `wall`, `merge_static`) | Repris et étendus dans `scripts/ile.gd` (étages, rampes, toits, hangars, bunkers…). |
| Commandes manette / clavier / tactile (`game.gd`, `touch_controls.gd`) | Base reprise ; boutons propres au BR à ajouter (glissade, parachute, ping, carte). |
| Vues d'armes (`weapon_view.gd`, `gun_shapes.gd`), sons des armes | Repris au jalon 2 (sans couteau, boissons ni armes doubles), statistiques refaites pour le PvP dans `armes.gd`. Le joueur a été réécrit au jalon 1 (`joueur.gd`). |
| Bots de test (`--bot --god`), tests automatiques en CI | Même principe : `--check` existe déjà, on ajoutera des tests par jalon. |
| CI GitHub Actions → APK publié en release | En place (`.github/workflows/build.yml`). |
| Rendu Compatibility pour GPU Mali | Gardé : l'APK doit tourner sur le Poco X8 Pro à 60 i/s. |

## 4. Jalons

| # | Jalon | Contenu | Fini quand |
|---|---|---|---|
| **0** | **Carte** ✅ | Île du Lazaret générée (relief, 10 lieux, bâtiments à étages, végétation), carte tactique, visite à pied et en drone, tests automatiques, APK. | L'APK installé permet de visiter l'île à la manette et au tactile. |
| **1** | **Mouvement** ✅ | Contrôleur du joueur : sprint, sprint tactique, glissade + **cancel slide**, saut de glissade, escalade de rebords, accroupi / couché, **parachute** (ouvrir, couper, rouvrir, ouverture auto) et saut d'avion, redéploiement depuis un point haut. Menu pause : taille de l'interface, marges, zone sûre, sensibilités. | Tests auto : glissade + annulation garde la vitesse et recharge le sprint tactique ; escalade d'un conteneur ; saut d'avion → atterrissage sur l'île. |
| **2** | **Armes et combat** ✅ | 10 armes de Dernière Vague adaptées au PvP (dégâts par zone et selon la distance, raretés), santé + 3 plaques, régénération, visée et assistance, butin dans les bâtiments, coffres, champ de tir avec mannequins. | Tests auto : 9 balles de Faucon à 10 m, une balle d'Aiguille dans la tête à 70 m, plaques, ramassage, coffre. |
| 3 | Règles Résurgence | La Brume en 6 phases, réapparition en parachute, argent, **stations d'achat**, **loadouts au lobby** et largages de classe. | Une partie complète jouable seul (sans bots) du saut à la fin de la Brume. |
| 4 | Bots | IA : choisir un lieu, piller, se déplacer avec la zone, combattre (portée, couverture), acheter en station. Niveaux de difficulté. | Partie de 24 combattants qui se termine sans blocage en test automatique. |
| 5 | Mobile | Interface tactile complète, réglages, performances (objectif 60 i/s, < 300 appels de dessin), sons, menus, progression. | Partie fluide sur le Poco X8 Pro, manette GameSir et tactile. |
| 6 | Multijoueur | Serveur autoritaire Godot sans écran hébergé sur ton serveur, lobby, synchronisation (prédiction côté client), bots pour compléter les parties. | Partie à plusieurs téléphones + bots. |

## 5. Réglages du mouvement (jalon 1)

Toutes les valeurs sont des constantes en tête de `scripts/joueur.gd`, faciles à ajuster après
essai sur le téléphone.

| | Valeur |
|---|---|
| Marche / sprint / sprint tactique | 4,6 / 6,9 / 8,6 m/s (tactique : 3,5 s, recharge 8 s) |
| Accroupi / couché | 2,6 / 1,1 m/s (maintenir accroupi 0,4 s = couché) |
| Glissade | +2,4 m/s d'élan (max 11), freinage 7 m/s² après 0,2 s, accélère dans les descentes |
| Cancel slide | possible après 0,12 s ; on se relève en sprint avec l'élan, sprint tactique rechargé ; l'élan retombe de 3 m/s² |
| Escalade | rebords de 0,5 à 2,8 m |
| Chute libre | 26 à 52 m/s (regarder vers le bas pour plonger), 22 m/s à l'horizontale |
| Parachute | descente 6 m/s (pousser : plus vite), ouverture auto à 40 m (12 m si on l'a coupé) |
| Avion | 190 m d'altitude, 48 m/s, trajet tiré au sort, éjection en bout d'île |

## 6. Combat (jalon 2)

Toutes les valeurs sont dans `scripts/armes.gd` (armes, munitions, raretés) et
`scripts/sante.gd` (santé, régénération).

| | Valeur |
|---|---|
| Santé | 100, régénération après 4,5 s sans dégâts (35 par seconde) |
| Armure | 3 plaques de 50 ; une plaque répare un segment (1,1 s), 5 dans le sac au maximum |
| Zones | tête ×1,3 à ×2,6 selon l'arme, torse ×1, jambes ×0,8 |
| Distance | dégâts pleins jusqu'au début de la portée, puis baisse jusqu'au facteur de chute |
| Raretés | rare / épique / légendaire : chargeur ×1,2 / ×1,35 / ×1,5, dispersion et visée améliorées |
| Butin | 1 à 3 étoiles par lieu : 50 à 80 % des emplacements remplis, 1 à 3 coffres |
| Départ | pistolet P9, 45 balles, une plaque sur soi, deux dans le sac |

## 7. Choix techniques

- **Godot 4.6**, rendu *Compatibility* (GL ES 3), Android arm64 — comme Dernière Vague.
- **L'île vient de données** : `data/ile.json` décrit les masses de terre, collines, routes, lieux,
  bâtiments et stations d'achat. `tools/gen_island.py` en tire le relief, les sols, la végétation et
  la carte ; le jeu reconstruit les bâtiments à partir du même fichier. Modifier l'île = modifier
  le JSON puis relancer le script.
- **Pas de navigation pré-calculée au jalon 0** : elle viendra avec les bots (navmesh par zones).
- **Multijoueur** : API réseau haut niveau de Godot (ENet), serveur autoritaire. Depuis le jalon 1,
  la simulation du joueur (`joueur.gd`) lit une structure `Intentions` (`intentions.gd`) : manette,
  clavier, tactile, bots de test et, plus tard, joueurs distants passent par le même chemin.

## 8. Questions ouvertes

- Taille des équipes au lancement : solo seulement, ou duo/trio avec des bots coéquipiers ?
- Nombre de combattants par partie (24 ? 32 ?) — à confirmer avec les performances.
- Ambiance : fin d'après-midi (actuel), avec une variante de nuit plus tard comme dans Dernière Vague ?
