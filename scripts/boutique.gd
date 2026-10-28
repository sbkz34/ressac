class_name Boutique
extends RefCounted
## Ce qu'on achète aux stations d'achat, avec l'argent ramassé.

const ARTICLES := [
	{"id": "largage", "nom": "Largage de classe", "prix": 4500, "desc": "Une caisse avec vos classes descend près de la station."},
	{"id": "gilet", "nom": "Gilet de plaques", "prix": 900, "desc": "3 plaques d'armure dans le sac."},
	{"id": "munitions", "nom": "Munitions", "prix": 500, "desc": "Toutes les munitions au maximum."},
	{"id": "masque", "nom": "Masque à gaz", "prix": 1200, "desc": "25 s sans dégâts dans la Brume."},
	{"id": "grenade", "nom": "Grenade", "prix": 600, "desc": "Équipement létal (2 au maximum)."},
	{"id": "fumigene", "nom": "Fumigène", "prix": 400, "desc": "Équipement tactique (2 au maximum)."},
]


static func article(id: String) -> Dictionary:
	for a in ARTICLES:
		if a.id == id:
			return a
	return {}


## Pourquoi on ne peut pas acheter (texte vide : on peut).
static func refusal(a: Arsenal, id: String) -> String:
	var art := article(id)
	if art.is_empty():
		return "Article inconnu"
	if a.argent < int(art.prix):
		return "Pas assez d'argent"
	match id:
		"gilet":
			if a.plates >= a.plates_max():
				return "Sac de plaques plein"
		"munitions":
			var full := true
			for k in a.reserve:
				if int(a.reserve[k]) < int(Armes.MUNITIONS[k].max):
					full = false
			if full:
				return "Munitions déjà au maximum"
		"masque":
			if a.gas_mask > 0.0:
				return "Masque déjà porté"
		"grenade":
			if a.letal == "grenade" and a.letal_n >= 2:
				return "Déjà 2 grenades"
		"fumigene":
			if a.tactique == "fumigene" and a.tactique_n >= 2:
				return "Déjà 2 fumigènes"
	return ""


static func buy(a: Arsenal, id: String, station: Node3D, pillage: Pillage) -> bool:
	if refusal(a, id) != "":
		G.play("denied", -6.0)
		return false
	a.argent -= int(article(id).prix)
	match id:
		"largage":
			var at := station.global_position + Vector3(3.5, 0, 0).rotated(Vector3.UP, randf() * TAU)
			pillage.spawn_largage(at)
			a.notice.emit("Largage en approche")
		"gilet":
			a.plates = mini(a.plates_max(), a.plates + 3)
		"munitions":
			for k in a.reserve:
				a.reserve[k] = int(Armes.MUNITIONS[k].max)
		"masque":
			a.gas_mask = 25.0
		"grenade":
			if a.letal != "grenade":
				a.letal = "grenade"
				a.letal_n = 0
			a.letal_n += 1
		"fumigene":
			if a.tactique != "fumigene":
				a.tactique = "fumigene"
				a.tactique_n = 0
			a.tactique_n += 1
	G.play("buy", -4.0)
	a.changed.emit()
	return true
