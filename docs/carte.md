# L'Île du Lazaret

Île méditerranéenne compacte, environ **570 m × 340 m** (plus un îlot au nord). Un ancien lazaret
(hôpital de quarantaine) au centre, une côte nord en falaises et une côte sud en plages et en anses.
Fin d'après-midi, soleil bas à l'ouest.

![Carte de l'île](carte.png)

Quadrillage de **cases de 64 m**, colonnes A–J d'ouest en est, lignes 1–10 du nord au sud
(le jeu affiche « lieu · case » en haut de l'écran).

## Les lieux

| Lieu | Case | Altitude | Rôle en partie | Butin |
|---|---|---|---|---|
| **Le Lazaret** | F5 | 15 m | Point central. Quadrilatère d'ailes à 2–3 étages autour d'une cour pavée, chapelle d'isolement au nord, toits accessibles. Combats verticaux. Station d'achat dans la cour. | ★★★ |
| **La Conserverie** | I6 | 4 m | Usine sur la côte est : grand hangar en brique, hangar en tôle, bureaux, cheminée, quai avec grue et conteneurs. Station d'achat. | ★★★ |
| **Le Port** | F7 | 2,5 m | Fond de l'anse sud : trois pontons, capitainerie à toit-terrasse, hangars à bateaux, barques. Station d'achat. | ★★ |
| **Les Cabanons** | C7 | 6 m | Village de pêcheurs serré autour d'une fontaine : 13 maisons, toits en tuiles ou terrasses accessibles, ruelles. Station d'achat. | ★★ |
| **Le Sémaphore** | H3 | 38 m | Sommet de l'île : station radio, antenne visible de partout. Domine l'est. Station d'achat. | ★★ |
| **La Batterie** | C4 | 27 m | Fortifications sur la falaise nord-ouest : trois bunkers, deux cuves de canon, murets, tour d'observation. | ★★ |
| **La Citerne** | G5 | 18 m | Château d'eau et station de pompage, carrefour entre Lazaret, Sémaphore et Conserverie. | ★ |
| **Le Cimetière marin** | D6 | 11 m | Enclos muré avec chapelle, rangées de tombes : couverture basse entre le Lazaret et les Cabanons. | ★ |
| **Les Salins** | H7 | 1,4 m | Bassins de sel plats et découverts, cabane, tas de sel. Traversée exposée. | ★ |
| **Le Phare** | A5 | 20 m | Cap isolé à l'ouest : phare et maison du gardien. Vue sur tout le flanc ouest. | ★ |

## Pensée de la carte

- **Un centre fort, une couronne de lieux** : le Lazaret attire, tout le reste est à 100–250 m
  autour, reliés par des chemins de terre. Aucun lieu n'est à plus de ~35 s de sprint de son voisin le plus proche.
- **Points hauts** : Sémaphore (38 m), Batterie (27 m), Phare (20 m), toits du Lazaret. Chacun a un
  contre-jeu (pente boisée, murs, couverture au pied).
- **Côtes différentes** : falaises au nord (on ne remonte pas de la mer, la Brume y est mortelle),
  plages et pontons au sud (on peut nager et ressortir).
- **Stations d'achat** placées pour qu'il y en ait toujours une à portée quel que soit le cercle :
  centre (Lazaret), sud (Port), ouest (Cabanons), est (Conserverie), nord-est (Sémaphore).
- **Cercles finaux possibles** : Lazaret, Cimetière, Citerne, Cabanons, Salins (lieux où le combat
  final reste lisible). Pas de final au Phare ni sur l'îlot.
- **Pins parasols** en bosquets pour casser les lignes de tir entre les lieux, rochers sur les pentes.

## Modifier l'île

Tout part de `data/ile.json` :

- `masses` et `creux` : la forme de l'île (ellipses ajoutées / retirées), `collines` : le relief.
- `routes` : les chemins (lignes de points).
- `lieux` : position, rayon et altitude du plateau, type de sol, et la liste des `batiments`
  (coordonnées relatives au lieu, `r` = rotation en degrés). Types : `bat` (étages `n`, portes,
  `toit` accessible), `hangar`, `bunker`, `phare`, `mat`, `citerne`, `cheminee`, `quai`, `grue`,
  `conteneur`, `mur`, `tombes`, `bassins`, `tas`, `fontaine`, `emplacement`.
- `boutiques` : stations d'achat. `depart` : où commence la visite.

Puis :

```sh
python3 tools/gen_island.py          # relief, sols, végétation, cartes
godot --headless --path . -- --check # vérifications (escaliers, nage, drone…)
godot --path . -- --tour --shots=/tmp/captures   # captures de chaque lieu
```
