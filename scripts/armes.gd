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

## Motifs de recul : dérive latérale tir après tir (multipliée par la force du recul), et montée
## qui s'accentue sur les premiers tirs. Le motif se répète au-delà de sa longueur.
const MOTIFS := {
	"faucon": [0.0, 0.25, 0.4, 0.35, 0.15, -0.1, -0.35, -0.45, -0.3, 0.0, 0.3, 0.45],
	"titan": [0.0, -0.2, -0.35, -0.3, -0.1, 0.15, 0.3, 0.25, 0.05, -0.15],
	"vipere": [0.0, 0.3, -0.2, 0.35, -0.3, 0.25, -0.35, 0.3, -0.2, 0.35],
	"ouragan": [0.0, -0.15, -0.3, -0.4, -0.25, 0.1, 0.35, 0.45, 0.2, -0.1],
	"uzi": [0.0, 0.45, -0.4, 0.5, -0.5, 0.35, -0.45, 0.5, -0.35, 0.45],
	"p9": [0.0, 0.2, -0.15, 0.25],
	"taureau": [0.0, -0.3, 0.2],
	"k14": [0.0, 0.25, 0.1, -0.2],
	"aiguille": [0.0],
	"grele": [0.0, 0.2],
}
## Montée du recul selon le rang dans la rafale (les premiers tirs sont plus doux).
const MONTEE := [0.75, 0.85, 1.0, 1.1, 1.18, 1.22, 1.25]
## Balancement de la visée épaulée (degrés) par type d'arme : les armes lourdes et longues bougent.
const BALANCEMENT := {"Fusil de précision": 0.32, "Fusil tactique": 0.18, "Mitrailleuse": 0.14,
	"Fusil d'assaut": 0.08, "Fusil à pompe": 0.06, "Mitraillette": 0.05, "Pistolet": 0.07}


## Recul du tir de rang `n` dans la rafale : (dérive latérale, facteur de montée).
static func recul_motif(id: String, n: int) -> Vector2:
	var m: Array = MOTIFS.get(id, [0.0])
	return Vector2(float(m[n % m.size()]), float(MONTEE[mini(n, MONTEE.size() - 1)]))


## Amplitude du balancement en visée pour cette arme (degrés).
static func balancement(w: Dictionary) -> float:
	if w.is_empty():
		return 0.0
	var b := float(BALANCEMENT.get(String(info(String(w.id)).type), 0.06))
	if w.get("acc", []).has("crosse_stable"):
		b *= 0.7
	return b


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
## Raretés : la couleur du butin et des armes, et le nombre d'accessoires (accessoires.gd).
const RARETES := [
	{"nom": "commune", "couleur": Color(0.82, 0.82, 0.8)},
	{"nom": "rare", "couleur": Color(0.3, 0.6, 1.0)},
	{"nom": "épique", "couleur": Color(0.72, 0.35, 1.0)},
	{"nom": "légendaire", "couleur": Color(1.0, 0.72, 0.15)},
]

const PLAQUE := 50.0
const PLAQUES_MAX := 3          # sur soi
const PLAQUES_PORTEES := 5      # dans le sac
const ARGENT_MAX := 99999


static func info(id: String) -> Dictionary:
	return ARMES.get(id, ARMES["p9"])


## Une arme précise (au sol, en main) : identifiant, rareté, accessoires, balles dans le
## chargeur. Sans accessoires donnés, ils sont tirés au sort selon la rareté.
static func nouvelle(id: String, rarete := 0, acc = null) -> Dictionary:
	var a: Array = acc if acc is Array else Accessoires.aleatoires(id, Accessoires.PAR_RARETE[clampi(rarete, 0, 3)])
	var w := {"id": id, "rarete": rarete, "acc": a.duplicate()}
	w["chargeur"] = chargeur_de(w)
	return w


## Taille du chargeur de base (sans accessoires).
static func taille_chargeur(id: String, _rarete := 0) -> int:
	return int(info(id).chargeur)


static func chargeur_de(w: Dictionary) -> int:
	return int(de(w).chargeur)


static var _eff := {}


## Caractéristiques d'une arme précise : la base, modifiée par ses accessoires.
static func de(w: Dictionary) -> Dictionary:
	if w.is_empty():
		return info("p9")
	var acc: Array = w.get("acc", [])
	var key := "%s|%s" % [w.id, ",".join(PackedStringArray(acc))]
	if _eff.has(key):
		return _eff[key]
	var a := info(w.id).duplicate(true)
	var m := {"portee": 1.0, "ads": 1.0, "vitesse": 1.0, "recul": 1.0, "disp": 1.0, "disp_ads": 1.0,
		"chargeur": 1.0, "recharge": 1.0, "fov": 1.0}
	var silent := false
	for id in acc:
		var mods: Dictionary = Accessoires.info(id).get("mods", {})
		for k in mods:
			if k == "silencieux":
				silent = true
			elif m.has(k):
				m[k] = float(m[k]) * float(mods[k])
	a.portee = [float(a.portee[0]) * m.portee, float(a.portee[1]) * m.portee]
	a.ads = float(a.ads) * m.ads
	a.vitesse = float(a.vitesse) * m.vitesse
	a.recul = float(a.recul) * m.recul
	a.disp = float(a.disp) * m.disp
	a.disp_ads = float(a.disp_ads) * m.disp_ads
	a.chargeur = int(round(float(a.chargeur) * m.chargeur))
	a.recharge = float(a.recharge) * m.recharge
	a.ads_fov = float(a.ads_fov) * m.fov
	a.silencieux = silent
	_eff[key] = a
	return a


## Dégâts d'une balle de cette arme précise (portée modifiée par les accessoires).
static func degats_de(w: Dictionary, dist: float, zone: String) -> float:
	return _degats(de(w), dist, zone)


static func nom_complet(w: Dictionary) -> String:
	if w.is_empty():
		return ""
	var n: int = w.get("acc", []).size()
	if n == 0:
		return "%s (%s)" % [info(w.id).nom, RARETES[int(w.rarete)].nom]
	return "%s (%s · %d accessoire%s)" % [info(w.id).nom, RARETES[int(w.rarete)].nom, n, "s" if n > 1 else ""]


## Dégâts d'une balle selon la distance et la zone touchée.
static func degats(id: String, dist: float, zone: String) -> float:
	return _degats(info(id), dist, zone)


static func _degats(a: Dictionary, dist: float, zone: String) -> float:
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
static var _verre: StandardMaterial3D


## Vitre des viseurs : presque transparente, légèrement bleutée.
static func verre() -> StandardMaterial3D:
	if _verre == null:
		_verre = StandardMaterial3D.new()
		_verre.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_verre.albedo_color = Color(0.55, 0.75, 0.9, 0.12)
		_verre.roughness = 0.1
		_verre.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return _verre


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


## Teintes des camouflages (taches en trois tons ; « tigre » en bandes ; « or » métallique).
const CAMO_TEINTES := {
	"sable": [Color(0.78, 0.68, 0.5), Color(0.62, 0.52, 0.36), Color(0.47, 0.38, 0.26)],
	"foret": [Color(0.32, 0.38, 0.22), Color(0.2, 0.26, 0.14), Color(0.4, 0.32, 0.2)],
	"marine": [Color(0.24, 0.32, 0.45), Color(0.14, 0.19, 0.28), Color(0.42, 0.5, 0.6)],
	"tigre": [Color(0.9, 0.5, 0.12), Color(0.08, 0.07, 0.06), Color(0.95, 0.75, 0.4)],
}
static var _camo_tex := {}


## Texture procédurale d'un camouflage (bruit seuillé en trois couleurs franches).
static func camo_texture(c: String) -> Texture2D:
	if _camo_tex.has(c):
		return _camo_tex[c]
	var cols: Array = CAMO_TEINTES[c]
	var noise := FastNoiseLite.new()
	noise.seed = hash(c)
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.035 if c != "tigre" else 0.05
	noise.fractal_octaves = 2
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	for y in 128:
		for x in 128:
			var v: float
			if c == "tigre":
				v = noise.get_noise_2d(x * 0.35, y * 2.2)   # étiré : des bandes
			else:
				v = noise.get_noise_2d(x, y)
			var k := 0 if v < -0.12 else (1 if v < 0.18 else 2)
			img.set_pixel(x, y, cols[k])
	var tex := ImageTexture.create_from_image(img)
	_camo_tex[c] = tex
	return tex


## Matériau du corps d'une arme avec un camouflage.
static func camo_mat(c: String) -> StandardMaterial3D:
	if c == "or":
		return _mat(Color(0.95, 0.74, 0.3), 0.95, 0.22, Color(1.0, 0.75, 0.3), 0.08)
	var m := StandardMaterial3D.new()
	m.albedo_texture = camo_texture(c)
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(3.0, 3.0, 3.0)
	m.roughness = 0.65
	m.metallic = 0.15
	return m


static var _reticule: StandardMaterial3D


## Point rouge des viseurs : rouge vif, sans ombrage (il se voit dans toutes les lumières).
static func reticule() -> StandardMaterial3D:
	if _reticule == null:
		_reticule = StandardMaterial3D.new()
		_reticule.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_reticule.albedo_color = Color(1.0, 0.08, 0.06)
	return _reticule


static func materiaux(rarete: int, camo := "") -> Dictionary:
	if camo != "" and (CAMO_TEINTES.has(camo) or camo == "or"):
		var key := "%d|%s" % [rarete, camo]
		if not _mats.has(key):
			var base: Dictionary = materiaux(rarete).duplicate()
			var body := camo_mat(camo)
			var shade := camo_mat(camo)
			shade.albedo_color = Color(0.62, 0.62, 0.62)
			base.metal = body
			base.wood = body
			base.dark = shade
			_mats[key] = base
		return _mats[key]
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
	var m := {"metal": metal, "dark": dark, "wood": wood, "glow": glow, "verre": verre()}
	_mats[rarete] = m
	return m
