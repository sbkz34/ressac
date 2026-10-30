class_name Accessoires
extends RefCounted
## Accessoires d'armes : 5 emplacements (bouche, canon, viseur, chargeur, crosse), chacun avec
## un avantage et une contrepartie. Une arme en porte selon sa rareté (commune 0, rare 2,
## épique 3, légendaire 5) ; les armes de classe portent ceux choisis à l'armurier.
##
## Effets (multiplicateurs sur armes.gd) : portee, ads (temps pour viser), vitesse (déplacement),
## recul, disp (dispersion sans viser), disp_ads, chargeur, recharge ; fov : champ de vision en
## visée ; silencieux : pas de point sur la mini-carte des autres, tir plus discret.

const EMPLACEMENTS := ["bouche", "canon", "viseur", "chargeur", "crosse"]
const NOMS_EMPLACEMENTS := {"bouche": "Bouche", "canon": "Canon", "viseur": "Viseur", "chargeur": "Chargeur", "crosse": "Crosse"}
const PAR_RARETE := [0, 2, 3, 5]

const LISTE := {
	"silencieux": {"e": "bouche", "nom": "Silencieux", "desc": "Invisible sur la mini-carte des autres, tir étouffé.",
		"mods": {"silencieux": true, "portee": 0.88}},
	"compensateur": {"e": "bouche", "nom": "Compensateur", "desc": "Moins de recul vertical.",
		"mods": {"recul": 0.75, "ads": 1.05}},
	"canon_long": {"e": "canon", "nom": "Canon long", "desc": "Plus de portée, visée un peu plus lente.",
		"mods": {"portee": 1.3, "ads": 1.12, "vitesse": 0.97}},
	"canon_court": {"e": "canon", "nom": "Canon court", "desc": "Plus mobile et rapide à viser, moins de portée.",
		"mods": {"portee": 0.8, "ads": 0.88, "vitesse": 1.04}},
	"point_rouge": {"e": "viseur", "nom": "Point rouge", "desc": "Visée nette et un peu plus rapide.",
		"mods": {"ads": 0.95, "disp_ads": 0.9}},
	"holo": {"e": "viseur", "nom": "Holographique", "desc": "Léger grossissement, visée plus précise.",
		"mods": {"fov": 0.85, "disp_ads": 0.8, "ads": 1.03}},
	"lunette": {"e": "viseur", "nom": "Lunette ×4", "desc": "Fort grossissement, visée plus lente.",
		"mods": {"fov": 0.55, "disp_ads": 0.6, "ads": 1.25}},
	"chargeur_etendu": {"e": "chargeur", "nom": "Chargeur étendu", "desc": "+50 % de balles, rechargement plus long.",
		"mods": {"chargeur": 1.5, "recharge": 1.2}},
	"chargeur_rapide": {"e": "chargeur", "nom": "Chargeur rapide", "desc": "Rechargement 25 % plus rapide.",
		"mods": {"recharge": 0.75}},
	"crosse_stable": {"e": "crosse", "nom": "Crosse stable", "desc": "Moins de recul et de dispersion, un peu plus lourde.",
		"mods": {"recul": 0.8, "disp": 0.85, "vitesse": 0.97}},
	"crosse_legere": {"e": "crosse", "nom": "Crosse légère", "desc": "Plus rapide à viser et à déplacer, plus de recul.",
		"mods": {"ads": 0.88, "vitesse": 1.04, "recul": 1.12}},
}

## Accessoires par défaut des classes (5 par arme principale, adaptés à son rôle).
const PAR_DEFAUT := {
	"faucon": ["compensateur", "canon_long", "holo", "chargeur_etendu", "crosse_stable"],
	"titan": ["compensateur", "canon_long", "holo", "chargeur_rapide", "crosse_stable"],
	"vipere": ["silencieux", "canon_court", "point_rouge", "chargeur_etendu", "crosse_legere"],
	"ouragan": ["silencieux", "canon_court", "point_rouge", "chargeur_rapide", "crosse_legere"],
	"uzi": ["silencieux", "canon_court", "point_rouge", "chargeur_etendu", "crosse_legere"],
	"k14": ["silencieux", "canon_long", "lunette", "chargeur_etendu", "crosse_stable"],
	"aiguille": ["silencieux", "canon_long", "chargeur_rapide", "crosse_stable"],
	"grele": ["compensateur", "canon_court", "point_rouge", "chargeur_etendu", "crosse_stable"],
	"p9": ["silencieux", "point_rouge", "chargeur_etendu", "canon_long"],
	"taureau": ["compensateur", "point_rouge", "chargeur_rapide", "canon_long"],
}


static func info(id: String) -> Dictionary:
	return LISTE.get(id, {})


## Accessoires possibles pour une arme et un emplacement (les pistolets n'ont pas de crosse ;
## le fusil de précision garde sa lunette).
static func choix(arme: String, emplacement: String) -> Array:
	var type := String(Armes.info(arme).type)
	if emplacement == "crosse" and type == "Pistolet":
		return []
	if emplacement == "viseur" and arme == "aiguille":
		return []
	if emplacement == "viseur" and type == "Pistolet":
		return ["point_rouge"]
	var out := []
	for id in LISTE:
		if LISTE[id].e == emplacement:
			out.append(id)
	return out


static func emplacements(arme: String) -> Array:
	return EMPLACEMENTS.filter(func(e): return not choix(arme, e).is_empty())


## Tirage au sort de n accessoires (un par emplacement) pour une arme trouvée au sol.
static func aleatoires(arme: String, n: int, rng: RandomNumberGenerator = null) -> Array:
	var slots := emplacements(arme)
	var out := []
	for k in mini(n, slots.size()):
		var i := rng.randi_range(0, slots.size() - 1) if rng else randi_range(0, slots.size() - 1)
		var e: String = slots[i]
		slots.remove_at(i)
		var c := choix(arme, e)
		out.append(c[rng.randi_range(0, c.size() - 1) if rng else randi_range(0, c.size() - 1)])
	return out


static func defaut(arme: String) -> Array:
	return (PAR_DEFAUT.get(arme, []) as Array).filter(func(a): return choix(arme, String(LISTE[a].e)).has(a))


## Accessoire posé sur un emplacement ("" s'il est vide).
static func sur(acc: Array, emplacement: String) -> String:
	for a in acc:
		if LISTE.has(a) and LISTE[a].e == emplacement:
			return a
	return ""


## Remplace (ou retire, avec "") l'accessoire d'un emplacement.
static func poser(acc: Array, emplacement: String, id: String) -> Array:
	var out := acc.filter(func(a): return LISTE.has(a) and LISTE[a].e != emplacement)
	if id != "":
		out.append(id)
	out.sort_custom(func(a, b): return EMPLACEMENTS.find(LISTE[a].e) < EMPLACEMENTS.find(LISTE[b].e))
	return out
