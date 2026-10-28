class_name Armes
extends RefCounted
## Armurerie de Ressac : les armes de Dernière Vague (mêmes modèles, mêmes sons), rééquilibrées
## pour le combat entre joueurs. Santé 100 + armure jusqu'à 150 (3 plaques de 50) : un fusil
## d'assaut tue en ~9 balles dans le torse (≈ 0,75 s), un tir de précision dans la tête traverse
## une armure pleine.
##
## dmg : dégâts par balle (ou plomb) dans le torse, à courte portée.
## portee : [début de la baisse, fin de la baisse] en mètres ; chute : facteur au-delà.
## rof : secondes entre deux tirs ; ads : temps pour viser (s) ; vitesse : déplacement.

const ZONES := {"tete": 1.4, "torse": 1.0, "jambes": 0.8}

const MUNITIONS := {
	"pistolet": {"nom": "Balles de pistolet", "max": 120, "lot": 30, "couleur": Color(0.85, 0.75, 0.35)},
	"mitraillette": {"nom": "Balles de mitraillette", "max": 240, "lot": 60, "couleur": Color(0.35, 0.6, 0.95)},
	"fusil": {"nom": "Balles de fusil", "max": 240, "lot": 60, "couleur": Color(0.45, 0.8, 0.35)},
	"precision": {"nom": "Balles de précision", "max": 40, "lot": 10, "couleur": Color(0.9, 0.35, 0.3)},
	"pompe": {"nom": "Cartouches", "max": 32, "lot": 8, "couleur": Color(0.9, 0.55, 0.2)},
}

const ARMES := {
	"p9": {"nom": "Pistolet P9", "type": "Pistolet", "munition": "pistolet", "auto": false,
		"dmg": 26.0, "tete": 1.5, "rof": 0.14, "chargeur": 15, "recharge": 1.4,
		"portee": [12.0, 35.0], "chute": 0.7, "disp": 1.6, "disp_ads": 0.35, "plombs": 1,
		"recul": 1.0, "ads": 0.14, "ads_fov": 62.0, "vitesse": 1.0, "son": "pistol"},
	"taureau": {"nom": "Revolver Taureau", "type": "Pistolet", "munition": "pistolet", "auto": false,
		"dmg": 62.0, "tete": 1.5, "rof": 0.42, "chargeur": 6, "recharge": 2.4,
		"portee": [20.0, 45.0], "chute": 0.75, "disp": 1.8, "disp_ads": 0.25, "plombs": 1,
		"recul": 4.0, "ads": 0.18, "ads_fov": 58.0, "vitesse": 1.0, "son": "revolver"},
	"vipere": {"nom": "Mitraillette Vipère", "type": "Mitraillette", "munition": "mitraillette", "auto": true,
		"dmg": 24.0, "tete": 1.3, "rof": 0.075, "chargeur": 32, "recharge": 2.0,
		"portee": [12.0, 30.0], "chute": 0.65, "disp": 2.6, "disp_ads": 0.8, "plombs": 1,
		"recul": 0.7, "ads": 0.2, "ads_fov": 60.0, "vitesse": 1.04, "son": "smg"},
	"ouragan": {"nom": "Mitraillette Ouragan", "type": "Mitraillette", "munition": "mitraillette", "auto": true,
		"dmg": 21.0, "tete": 1.3, "rof": 0.06, "chargeur": 40, "recharge": 2.2,
		"portee": [10.0, 25.0], "chute": 0.62, "disp": 3.0, "disp_ads": 1.0, "plombs": 1,
		"recul": 0.6, "ads": 0.2, "ads_fov": 60.0, "vitesse": 1.04, "son": "smg"},
	"uzi": {"nom": "Mini Uzi", "type": "Mitraillette", "munition": "mitraillette", "auto": true,
		"dmg": 20.0, "tete": 1.3, "rof": 0.055, "chargeur": 32, "recharge": 1.7,
		"portee": [8.0, 20.0], "chute": 0.6, "disp": 3.2, "disp_ads": 1.2, "plombs": 1,
		"recul": 0.6, "ads": 0.16, "ads_fov": 62.0, "vitesse": 1.06, "son": "smg"},
	"faucon": {"nom": "Fusil d'assaut Faucon", "type": "Fusil d'assaut", "munition": "fusil", "auto": true,
		"dmg": 30.0, "tete": 1.4, "rof": 0.09, "chargeur": 30, "recharge": 2.3,
		"portee": [35.0, 70.0], "chute": 0.75, "disp": 2.4, "disp_ads": 0.3, "plombs": 1,
		"recul": 1.0, "ads": 0.25, "ads_fov": 55.0, "vitesse": 0.96, "son": "rifle"},
	"titan": {"nom": "Mitrailleuse Titan", "type": "Mitrailleuse", "munition": "fusil", "auto": true,
		"dmg": 32.0, "tete": 1.3, "rof": 0.095, "chargeur": 75, "recharge": 4.5,
		"portee": [40.0, 80.0], "chute": 0.75, "disp": 3.4, "disp_ads": 0.5, "plombs": 1,
		"recul": 1.2, "ads": 0.38, "ads_fov": 55.0, "vitesse": 0.86, "son": "lmg"},
	"k14": {"nom": "Carabine K14", "type": "Fusil tactique", "munition": "precision", "auto": false,
		"dmg": 62.0, "tete": 1.6, "rof": 0.22, "chargeur": 10, "recharge": 2.2,
		"portee": [60.0, 120.0], "chute": 0.8, "disp": 2.2, "disp_ads": 0.1, "plombs": 1,
		"recul": 2.4, "ads": 0.3, "ads_fov": 45.0, "vitesse": 0.95, "son": "carbine"},
	"aiguille": {"nom": "Fusil de précision Aiguille", "type": "Fusil de précision", "munition": "precision", "auto": false,
		"dmg": 140.0, "tete": 2.6, "rof": 1.15, "chargeur": 5, "recharge": 3.0,
		"portee": [150.0, 300.0], "chute": 0.85, "disp": 9.0, "disp_ads": 0.0, "plombs": 1,
		"recul": 6.0, "ads": 0.45, "ads_fov": 24.0, "vitesse": 0.9, "son": "sniper"},
	"grele": {"nom": "Fusil à pompe Grêle", "type": "Fusil à pompe", "munition": "pompe", "auto": false,
		"dmg": 20.0, "tete": 1.2, "rof": 0.85, "chargeur": 6, "recharge": 2.8,
		"portee": [6.0, 16.0], "chute": 0.3, "disp": 5.5, "disp_ads": 4.2, "plombs": 8,
		"recul": 5.0, "ads": 0.2, "ads_fov": 64.0, "vitesse": 0.97, "son": "shotgun"},
}

## Raretés : la couleur du butin et des armes, et un petit bonus (chargeur, dispersion, visée).
const RARETES := [
	{"nom": "commune", "couleur": Color(0.82, 0.82, 0.8), "chargeur": 1.0, "disp": 1.0, "ads": 1.0},
	{"nom": "rare", "couleur": Color(0.3, 0.6, 1.0), "chargeur": 1.2, "disp": 0.92, "ads": 0.95},
	{"nom": "épique", "couleur": Color(0.72, 0.35, 1.0), "chargeur": 1.35, "disp": 0.85, "ads": 0.9},
	{"nom": "légendaire", "couleur": Color(1.0, 0.72, 0.15), "chargeur": 1.5, "disp": 0.78, "ads": 0.85},
]

const PLAQUE := 50.0
const PLAQUES_MAX := 3          # sur soi
const PLAQUES_PORTEES := 5      # dans le sac
const ARGENT_MAX := 99999


static func info(id: String) -> Dictionary:
	return ARMES.get(id, ARMES["p9"])


## Une arme précise (au sol, en main) : identifiant, rareté, balles dans le chargeur.
static func nouvelle(id: String, rarete := 0) -> Dictionary:
	return {"id": id, "rarete": rarete, "chargeur": taille_chargeur(id, rarete)}


static func taille_chargeur(id: String, rarete: int) -> int:
	return int(round(float(info(id).chargeur) * float(RARETES[rarete].chargeur)))


static func nom_complet(w: Dictionary) -> String:
	if w.is_empty():
		return ""
	return "%s (%s)" % [info(w.id).nom, RARETES[int(w.rarete)].nom]


## Dégâts d'une balle selon la distance et la zone touchée.
static func degats(id: String, dist: float, zone: String) -> float:
	var a := info(id)
	var r0: float = a.portee[0]
	var r1: float = a.portee[1]
	var f := 1.0
	if dist > r0:
		f = lerpf(1.0, float(a.chute), clampf((dist - r0) / maxf(r1 - r0, 0.01), 0.0, 1.0))
	var z: float = a.tete if zone == "tete" else float(ZONES.get(zone, 1.0))
	return float(a.dmg) * f * z


## Coups au torse pour éliminer un adversaire en armure complète (affichage, équilibrage).
static func coups_pour_tuer(id: String, dist := 5.0) -> int:
	var per := degats(id, dist, "torse") * float(info(id).plombs)
	return int(ceil((100.0 + PLAQUE * PLAQUES_MAX) / per))


# ------------------------------------------------------------------------------------------------
# Matériaux des modèles, teintés selon la rareté
# ------------------------------------------------------------------------------------------------
static var _mats := {}


static func _mat(c: Color, metal: float, rough: float, glow := Color(0, 0, 0), energy := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = glow
		m.emission_energy_multiplier = energy
	return m


static func materiaux(rarete: int) -> Dictionary:
	if _mats.has(rarete):
		return _mats[rarete]
	var tint: Color = RARETES[rarete].couleur
	var metal := _mat(Color(0.2, 0.21, 0.23), 0.7, 0.35)
	var dark := _mat(Color(0.06, 0.06, 0.065), 0.0, 0.6)
	var wood := StandardMaterial3D.new()
	wood.albedo_texture = load("res://assets/tex/wood.png")
	wood.albedo_color = Color(0.85, 0.7, 0.6)
	wood.uv1_triplanar = true
	wood.uv1_scale = Vector3(4, 4, 4)
	wood.roughness = 0.7
	if rarete > 0:
		# Les armes rares portent leur couleur sur le métal (comme les améliorations de Dernière Vague).
		metal = _mat(tint.darkened(0.35), 0.45, 0.3, tint, 0.15)
		if rarete >= 2:
			wood = _mat(tint.darkened(0.55), 0.3, 0.4, tint, 0.08)
	var glow := _mat(tint, 0.0, 0.5, tint, 2.5)
	var m := {"metal": metal, "dark": dark, "wood": wood, "glow": glow}
	_mats[rarete] = m
	return m
