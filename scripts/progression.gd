class_name Progression
## Progression du joueur, gardée d'une partie à l'autre (user://progression.json) : niveau et
## expérience, défis à paliers, camouflages d'armes débloqués par les éliminations, statistiques.
## Les points se comptent à la fin de chaque partie (ou quand on la quitte).

const PATH := "user://progression.json"
const NIVEAU_MAX := 55

## Expérience d'une partie.
const XP_ELIM := 100
const XP_TETE := 10
const XP_CONTRAT := 300
const XP_COFFRE := 25
const XP_MINUTE := 60
const XP_PLACE := [[1, 2000], [3, 800], [5, 400], [10, 150]]

## Défis : statistique cumulée, paliers et expérience de chaque palier.
const DEFIS := [
	{"id": "parties", "nom": "Jouer %s parties", "stat": "parties", "paliers": [1, 10, 50, 100], "xp": [300, 800, 2000, 4000]},
	{"id": "eliminations", "nom": "Éliminer %s ennemis", "stat": "eliminations", "paliers": [10, 50, 150, 500], "xp": [500, 1000, 2500, 5000]},
	{"id": "tetes", "nom": "Toucher %s fois à la tête", "stat": "tetes", "paliers": [25, 100, 300, 1000], "xp": [400, 1000, 2000, 4000]},
	{"id": "degats", "nom": "Infliger %s points de dégâts", "stat": "degats", "paliers": [2500, 10000, 50000, 200000], "xp": [400, 1000, 2500, 5000]},
	{"id": "contrats", "nom": "Remplir %s contrats", "stat": "contrats", "paliers": [1, 5, 20, 50], "xp": [400, 1000, 2500, 5000]},
	{"id": "coffres", "nom": "Ouvrir %s coffres", "stat": "coffres", "paliers": [10, 50, 150, 400], "xp": [300, 800, 2000, 4000]},
	{"id": "victoires", "nom": "Gagner %s parties", "stat": "victoires", "paliers": [1, 3, 10, 25], "xp": [1500, 3000, 6000, 10000]},
	{"id": "top5", "nom": "Finir %s fois dans les 5 premiers", "stat": "top5", "paliers": [1, 5, 15, 40], "xp": [600, 1500, 3000, 6000]},
	{"id": "explosifs", "nom": "Éliminer %s ennemis à la grenade ou à la frappe", "stat": "elim_explosif", "paliers": [3, 15, 50], "xp": [500, 1500, 3000]},
	{"id": "tyroliennes", "nom": "Prendre %s tyroliennes", "stat": "tyroliennes", "paliers": [3, 15, 50], "xp": [300, 1000, 2500]},
]

## Camouflages : débloqués arme par arme, au nombre d'éliminations avec cette arme.
const CAMOS := [
	{"id": "", "nom": "Aucun", "elim": 0},
	{"id": "sable", "nom": "Sable", "elim": 5},
	{"id": "foret", "nom": "Forêt", "elim": 15},
	{"id": "marine", "nom": "Marine", "elim": 30},
	{"id": "tigre", "nom": "Tigre", "elim": 60},
	{"id": "or", "nom": "Or", "elim": 100},
]

## Statistiques cumulées (et leur nom à l'écran, dans l'ordre d'affichage).
const STATS := ["parties", "victoires", "top5", "eliminations", "morts", "tirs", "touches", "tetes", "degats",
	"contrats", "coffres", "tyroliennes", "elim_explosif", "temps", "meilleure_serie"]

static var data := {}


static func _vide() -> Dictionary:
	var st := {}
	for k in STATS:
		st[k] = 0
	return {"xp": 0, "stats": st, "armes": {}, "camos": {}, "defis": {}}


static func charger() -> void:
	data = _vide()
	if G.check_mode or not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		for k in ["xp", "armes", "camos", "defis"]:
			if d.has(k):
				data[k] = d[k]
		if d.get("stats") is Dictionary:
			for k in d.stats:
				data.stats[k] = d.stats[k]


static func enregistrer() -> void:
	if G.check_mode:
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


static func _d() -> Dictionary:
	if data.is_empty():
		charger()
	return data


static func remettre_a_zero() -> void:
	data = _vide()
	enregistrer()


# ------------------------------------------------------------------------------------------------
# Niveau
# ------------------------------------------------------------------------------------------------
## Expérience pour passer du niveau n au suivant.
static func xp_pour(n: int) -> int:
	return 800 + 120 * (n - 1)


## [niveau, xp dans le niveau, xp pour le suivant] pour un total d'expérience.
static func niveau_de(xp: int) -> Array:
	var n := 1
	var left := xp
	while n < NIVEAU_MAX and left >= xp_pour(n):
		left -= xp_pour(n)
		n += 1
	return [n, left, xp_pour(n)]


static func niveau() -> int:
	return int(niveau_de(int(_d().xp))[0])


static func stat(k: String) -> float:
	return float(_d().stats.get(k, 0))


# ------------------------------------------------------------------------------------------------
# Défis
# ------------------------------------------------------------------------------------------------
## Palier atteint d'un défi (0 : aucun).
static func palier(defi: Dictionary) -> int:
	return int(_d().defis.get(defi.id, 0))


## Objectif suivant d'un défi (le dernier s'il est terminé), et s'il est terminé.
static func objectif(defi: Dictionary) -> Array:
	var p := palier(defi)
	var paliers: Array = defi.paliers
	return [int(paliers[mini(p, paliers.size() - 1)]), p >= paliers.size()]


static func texte_defi(defi: Dictionary) -> String:
	return _texte(defi, int(objectif(defi)[0]))


## Nom d'un défi pour un objectif (au singulier pour 1).
static func _texte(defi: Dictionary, n: int) -> String:
	var t := String(defi.nom) % _nombre(n)
	if n == 1:
		for w in ["parties", "contrats", "ennemis", "coffres", "tyroliennes"]:
			t = t.replace(" " + w, " " + w.left(-1))
	return t


static func _nombre(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


# ------------------------------------------------------------------------------------------------
# Camouflages
# ------------------------------------------------------------------------------------------------
static func elim_arme(id: String) -> int:
	return int(_d().armes.get(id, 0))


static func camo_debloque(id: String, camo: String) -> bool:
	for c in CAMOS:
		if c.id == camo:
			return elim_arme(id) >= int(c.elim)
	return false


## Camouflage choisi pour une arme ("" : aucun).
static func camo(id: String) -> String:
	var c := String(_d().camos.get(id, ""))
	return c if camo_debloque(id, c) else ""


static func choisir_camo(id: String, c: String) -> bool:
	if not camo_debloque(id, c):
		return false
	_d().camos[id] = c
	enregistrer()
	return true


static func camo_nom(c: String) -> String:
	for x in CAMOS:
		if x.id == c:
			return String(x.nom)
	return "Aucun"


# ------------------------------------------------------------------------------------------------
# Fin de partie
# ------------------------------------------------------------------------------------------------
## Compte une partie : statistiques, expérience, défis et camouflages. Renvoie le détail pour
## l'écran de fin : {lignes: [[texte, xp]], total, avant: [niveau, xp, besoin], apres, defis, camos}.
static func compter(s: Dictionary, victoire: bool) -> Dictionary:
	var d := _d()
	var st: Dictionary = d.stats
	var avant := niveau_de(int(d.xp))
	var lignes := []
	var add := func(texte: String, xp: int) -> void:
		if xp > 0:
			lignes.append([texte, xp])
	var elim := int(s.get("eliminations", 0))
	var tetes := int(s.get("tetes", 0))
	var contrats := int(s.get("contrats", 0))
	var coffres := int(s.get("coffres", 0))
	var minutes := int(float(s.get("temps", 0.0)) / 60.0)
	add.call("Éliminations × %d" % elim, elim * XP_ELIM)
	add.call("Tirs à la tête × %d" % tetes, tetes * XP_TETE)
	add.call("Contrats × %d" % contrats, contrats * XP_CONTRAT)
	add.call("Coffres × %d" % coffres, coffres * XP_COFFRE)
	add.call("Temps de jeu : %d min" % minutes, minutes * XP_MINUTE)
	var place := int(s.get("place", 0))
	var total := int(s.get("total", 1))
	if total > 1 and place > 0:
		for pl in XP_PLACE:
			if place <= int(pl[0]):
				add.call("Victoire" if place == 1 else "Classement : %de" % place, int(pl[1]))
				break
	# Statistiques cumulées.
	st.parties = int(st.parties) + 1
	if victoire and total > 1:
		st.victoires = int(st.victoires) + 1
	if total > 1 and place > 0 and place <= 5:
		st.top5 = int(st.top5) + 1
	for k in ["eliminations", "morts", "tirs", "touches", "tetes", "degats", "contrats", "coffres", "tyroliennes", "elim_explosif"]:
		st[k] = float(st.get(k, 0)) + float(s.get(k, 0))
	st.temps = float(st.temps) + float(s.get("temps", 0.0))
	st.meilleure_serie = maxi(int(st.meilleure_serie), int(s.get("serie", 0)))
	# Éliminations par arme : camouflages débloqués.
	var camos := []
	var armes: Dictionary = s.get("armes", {})
	for id in armes:
		var before := elim_arme(id)
		var after := before + int(armes[id])
		d.armes[id] = after
		for c in CAMOS:
			if int(c.elim) > before and int(c.elim) <= after:
				camos.append("%s : %s" % [Armes.info(id).nom, c.nom])
	# Défis : chaque palier franchi rapporte son expérience.
	var defis := []
	for df in DEFIS:
		var p := palier(df)
		var paliers: Array = df.paliers
		while p < paliers.size() and float(st.get(df.stat, 0)) >= float(paliers[p]):
			var xp := int(df.xp[p])
			p += 1
			d.defis[df.id] = p
			defis.append(texte_defi_palier(df, p - 1))
			add.call("Défi : %s" % defis[-1], xp)
	var gain := 0
	for l in lignes:
		gain += int(l[1])
	d.xp = int(d.xp) + gain
	enregistrer()
	return {"lignes": lignes, "total": gain, "avant": avant, "apres": niveau_de(int(d.xp)), "defis": defis, "camos": camos}


static func texte_defi_palier(df: Dictionary, p: int) -> String:
	return _texte(df, int(df.paliers[p]))
