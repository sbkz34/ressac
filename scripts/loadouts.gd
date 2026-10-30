class_name Loadouts
extends RefCounted
## Les classes préparées au lobby (5 emplacements) et ce qu'elles contiennent : arme principale,
## arme secondaire, un atout par colonne, un équipement létal, un tactique. Enregistrées dans
## user://loadouts.cfg. On les récupère en partie avec un largage de classe.

const SLOTS := 5
const PATH := "user://loadouts.cfg"
const RARETE := 3   # les armes de classe sont des armes « montées » : rareté légendaire

## Trois colonnes d'atouts, un par colonne (comme dans le mode d'origine).
const ATOUTS := {
	"double_temps": {"nom": "Double Temps", "col": 0, "desc": "Sprint tactique deux fois plus long."},
	"pillard": {"nom": "Pillard", "col": 0, "desc": "Munitions et argent ramassés : +50 %."},
	"ravitailleur": {"nom": "Ravitailleur", "col": 0, "desc": "7 plaques dans le sac au lieu de 5."},
	"fixation": {"nom": "Fixation rapide", "col": 1, "desc": "Plaques posées deux fois plus vite."},
	"robuste": {"nom": "Robuste", "col": 1, "desc": "La santé remonte après 2,5 s au lieu de 4,5 s."},
	"dur_a_cuire": {"nom": "Dur à cuire", "col": 1, "desc": "Dégâts de la Brume divisés par deux."},
	"amorti": {"nom": "Amorti", "col": 2, "desc": "Aucun dégât de chute."},
	"tete_froide": {"nom": "Tête froide", "col": 2, "desc": "Dispersion et recul réduits de 25 %."},
	"fouineur": {"nom": "Fouineur", "col": 2, "desc": "Coffres proches visibles sur la carte et à l'écran."},
}

const EQUIPEMENTS := {
	"grenade": {"nom": "Grenade", "type": "letal"},
	"fumigene": {"nom": "Fumigène", "type": "tactique"},
}

const PRINCIPALES := ["faucon", "titan", "vipere", "ouragan", "uzi", "k14", "aiguille", "grele"]
const SECONDAIRES := ["p9", "taureau", "uzi", "vipere", "grele"]

const DEFAUTS := [
	{"nom": "Assaut", "principale": "faucon", "secondaire": "p9", "atouts": ["double_temps", "fixation", "tete_froide"], "letal": "grenade", "tactique": "fumigene"},
	{"nom": "Courte portée", "principale": "vipere", "secondaire": "grele", "atouts": ["double_temps", "robuste", "amorti"], "letal": "grenade", "tactique": "fumigene"},
	{"nom": "Tireur", "principale": "aiguille", "secondaire": "ouragan", "atouts": ["ravitailleur", "fixation", "tete_froide"], "letal": "grenade", "tactique": "fumigene"},
	{"nom": "Lourd", "principale": "titan", "secondaire": "taureau", "atouts": ["ravitailleur", "dur_a_cuire", "tete_froide"], "letal": "grenade", "tactique": "fumigene"},
	{"nom": "Fouille", "principale": "k14", "secondaire": "uzi", "atouts": ["pillard", "robuste", "fouineur"], "letal": "grenade", "tactique": "fumigene"},
]

static var list: Array = []


static func load_all() -> Array:
	list = DEFAUTS.duplicate(true)
	if G.check_mode:
		return list
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		for k in SLOTS:
			var d = cf.get_value("loadouts", str(k), null)
			if d is Dictionary and _valid(d):
				list[k] = d
	return list


static func save_all() -> void:
	if G.check_mode:
		return
	var cf := ConfigFile.new()
	for k in list.size():
		cf.set_value("loadouts", str(k), list[k])
	cf.save(PATH)


static func get_one(k: int) -> Dictionary:
	if list.is_empty():
		load_all()
	return list[clampi(k, 0, list.size() - 1)]


static func _valid(d: Dictionary) -> bool:
	if not (d.has("principale") and d.has("secondaire") and d.has("atouts") and d.atouts is Array and d.atouts.size() == 3):
		return false
	if not Armes.ARMES.has(d.principale) or not Armes.ARMES.has(d.secondaire):
		return false
	for k in 3:
		if not ATOUTS.has(d.atouts[k]) or int(ATOUTS[d.atouts[k]].col) != k:
			return false
	return true


## Accessoires d'une arme de la classe (ceux choisis à l'armurier, sinon ceux par défaut).
static func acc_de(d: Dictionary, slot: String) -> Array:
	var arme: String = d[slot]
	var all: Dictionary = d.get("acc", {})
	var key := "%s:%s" % [slot, arme]
	if all.has(key) and all[key] is Array:
		return (all[key] as Array).filter(func(x): return Accessoires.choix(arme, String(Accessoires.info(x).get("e", ""))).has(x))
	return Accessoires.defaut(arme)


## Copie de la classe avec les accessoires d'une de ses armes changés.
static func avec_acc(d: Dictionary, slot: String, acc: Array) -> Dictionary:
	var out := d.duplicate(true)
	var all: Dictionary = out.get("acc", {})
	all["%s:%s" % [slot, String(d[slot])]] = acc.duplicate()
	out["acc"] = all
	return out


## Atouts proposés dans une colonne.
static func column(col: int) -> Array:
	var out := []
	for id in ATOUTS:
		if int(ATOUTS[id].col) == col:
			out.append(id)
	return out


static func summary(d: Dictionary) -> String:
	var atouts := []
	for a in d.atouts:
		atouts.append(ATOUTS[a].nom)
	return "%s · %s\n%s" % [Armes.info(d.principale).nom, Armes.info(d.secondaire).nom, " · ".join(atouts)]
