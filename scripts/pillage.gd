class_name Pillage
extends Node3D
## Répartit le butin sur l'île au début d'une partie : objets au sol dans les bâtiments
## (emplacements relevés par l'île), coffres, et le champ de tir de la Batterie. Plus un lieu a
## d'étoiles (`butin` dans data/ile.json), plus il est rempli et plus ses armes sont rares.

const REMPLISSAGE := {1: 0.5, 2: 0.65, 3: 0.8}
const COFFRES := {1: 1, 2: 2, 3: 3}
## Chances de rareté (commune, rare, épique, légendaire) selon les étoiles du lieu.
const RARETE_PAR_ETOILES := {
	1: [60, 30, 9, 1],
	2: [45, 35, 16, 4],
	3: [30, 35, 25, 10],
	4: [0, 35, 45, 20],   # coffres
}
const ARMES_COURANTES := ["p9", "taureau", "vipere", "ouragan", "uzi", "faucon", "titan", "k14", "aiguille", "grele"]
const POIDS_ARMES := [10, 5, 9, 7, 8, 10, 4, 6, 3, 7]

var rng := RandomNumberGenerator.new()
var items: Array[Butin] = []
var chests: Array[Coffre] = []
var targets: Array[Cible] = []
var shops: Array[Node3D] = []   # stations d'achat de l'île (interactives)
var contrats: Array = []          # tablettes de contrat (contrats.gd)
var tyroliennes: Array[Node3D] = []   # points d'accroche des tyroliennes (tyrolienne.gd)


func _pick_weighted(weights: Array) -> int:
	var total := 0
	for w in weights:
		total += int(w)
	var r := rng.randi_range(1, total)
	for i in weights.size():
		r -= int(weights[i])
		if r <= 0:
			return i
	return weights.size() - 1


func random_weapon(stars: int) -> Dictionary:
	var id: String = ARMES_COURANTES[_pick_weighted(POIDS_ARMES)]
	var r := _pick_weighted(RARETE_PAR_ETOILES[clampi(stars, 1, 4)])
	return Armes.nouvelle(id, r, Accessoires.aleatoires(id, Accessoires.PAR_RARETE[r], rng))


func random_ammo_kind() -> String:
	return ["pistolet", "mitraillette", "fusil", "precision", "pompe"][_pick_weighted([5, 6, 6, 2, 3])]


# ------------------------------------------------------------------------------------------------
# Objets
# ------------------------------------------------------------------------------------------------
func spawn(b: Butin, pos: Vector3, yaw := 0.0) -> Butin:
	add_child(b)
	b.global_position = pos
	b.rotation.y = yaw
	items.append(b)
	return b


func remove(b: Butin) -> void:
	items.erase(b)
	b.queue_free()


## Une arme au sol, avec un lot de ses munitions à côté.
func spawn_weapon(w: Dictionary, pos: Vector3, with_ammo := true) -> void:
	spawn(Butin.make_arme(w), pos, rng.randf() * TAU)
	if with_ammo:
		var kind: String = Armes.info(w.id).munition
		var side := Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(0.35, 0.6))
		spawn(Butin.make_munitions(kind, int(Armes.MUNITIONS[kind].lot)), pos + side, rng.randf() * TAU)


func _random_item(pos: Vector3, stars: int) -> void:
	var r := rng.randf()
	if r < 0.36:
		spawn_weapon(random_weapon(stars), pos)
	elif r < 0.68:
		var kind := random_ammo_kind()
		spawn(Butin.make_munitions(kind, int(Armes.MUNITIONS[kind].lot)), pos, rng.randf() * TAU)
	elif r < 0.86:
		spawn(Butin.make_plaque(1 if rng.randf() < 0.75 else 3), pos, rng.randf() * TAU)
	else:
		spawn(Butin.make_argent(rng.randi_range(2, 8) * 50 * stars), pos, rng.randf() * TAU)


## Vide l'île (nouvelle partie).
func clear() -> void:
	for b in items:
		b.queue_free()
	for c in chests:
		c.queue_free()
	for t in targets:
		t.queue_free()
	items.clear()
	chests.clear()
	targets.clear()
	contrats.clear()
	for n in get_children():
		n.queue_free()


## Sac de butin à la mort : armes, munitions, plaques et argent répandus au sol.
func spawn_bag(at: Vector3, bag: Dictionary) -> void:
	var p = _settle(at + Vector3(0, 1.0, 0))
	var base: Vector3 = p if p != null else at
	var counter := [0]   # les fonctions anonymes copient les nombres : on passe par un tableau
	var spot := func() -> Vector3:
		counter[0] += 1
		var k: int = counter[0]
		return base + Vector3.FORWARD.rotated(Vector3.UP, k * 1.3) * (0.6 + 0.25 * k)
	for w in bag.armes:
		spawn(Butin.make_arme(w), spot.call(), rng.randf() * TAU)
	for kind in bag.munitions:
		if int(bag.munitions[kind]) > 0:
			spawn(Butin.make_munitions(kind, int(bag.munitions[kind])), spot.call(), rng.randf() * TAU)
	if int(bag.plaques) > 0:
		spawn(Butin.make_plaque(int(bag.plaques)), spot.call())
	if int(bag.argent) > 0:
		spawn(Butin.make_argent(int(bag.argent)), spot.call())


## Caisse de largage de classe qui descend du ciel à cet endroit.
func spawn_largage(at: Vector3) -> Coffre:
	var p = _settle(at + Vector3(0, 30.0, 0), 60.0)
	var c := Coffre.new()
	c.largage = true
	add_child(c)
	c.global_position = p if p != null else at
	c.drop_from(70.0)
	chests.append(c)
	return c


# ------------------------------------------------------------------------------------------------
# Remplissage de l'île
# ------------------------------------------------------------------------------------------------
func populate(ile: Ile, seed_value: int) -> void:
	rng.seed = seed_value
	for l in G.data.lieux:
		var id := String(l.id)
		var stars := int(l.get("butin", 1))
		var spots: Array = ile.loot_spots.get(id, []).duplicate()
		_shuffle(spots)
		var n := int(round(spots.size() * float(REMPLISSAGE[stars])))
		for k in n:
			var p = _settle(spots[k])
			if p != null:
				_random_item(p, stars)
		var cs: Array = ile.chest_spots.get(id, []).duplicate()
		_shuffle(cs)
		for k in mini(int(COFFRES[stars]), cs.size()):
			var c := Coffre.new()
			add_child(c)
			c.global_position = cs[k][0]
			c.rotation.y = cs[k][1]
			c.set_meta("etoiles", stars)
			c.opened.connect(_on_chest_opened)
			chests.append(c)
	# Un coffre au sommet de chaque tyrolienne.
	for t in ile.tyroliennes:
		var c := Coffre.new()
		add_child(c)
		c.global_position = t.coffre
		c.rotation.y = t.coffre_cap
		c.set_meta("etoiles", 3)
		c.opened.connect(_on_chest_opened)
		chests.append(c)


## Pose un emplacement sur la surface juste en dessous (ou rien s'il est au-dessus du vide).
func _settle(p: Vector3, depth := 1.5):
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.4, 0), p - Vector3(0, depth, 0), G.L_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or hit.normal.y < 0.7:
		return null
	return hit.position + Vector3(0, 0.02, 0)


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


func _on_chest_opened(c: Coffre) -> void:
	if c.ravitaillement:
		return
	# Le contenu jaillit devant le coffre : une arme rare (et ses munitions), plaques, argent.
	var front := -c.global_basis.z
	var right := c.global_basis.x
	var base := c.global_position + front * 0.9
	spawn_weapon(random_weapon(4), base)
	spawn(Butin.make_plaque(rng.randi_range(1, 2)), base + right * 0.7, rng.randf() * TAU)
	spawn(Butin.make_argent(rng.randi_range(4, 10) * 50), base - right * 0.7, rng.randf() * TAU)
	var kind := random_ammo_kind()
	spawn(Butin.make_munitions(kind, int(Armes.MUNITIONS[kind].lot)), base + front * 0.5, rng.randf() * TAU)


# ------------------------------------------------------------------------------------------------
# Champ de tir de la Batterie : mannequins à 10, 25, 50 et 70 m, toutes les armes en épique,
# une caisse de ravitaillement sans fin.
# ------------------------------------------------------------------------------------------------
func build_range(ile: Ile) -> void:
	var r: Dictionary = G.data.get("champ_de_tir", {})
	if r.is_empty():
		return
	var yaw := deg_to_rad(float(r.cap))
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var side := Vector3(-fwd.z, 0, fwd.x)
	var origin := Vector3(float(r.x), 0, float(r.z))
	var ground := func(p: Vector3) -> Vector3:
		return Vector3(p.x, ile.ground_at(p.x, p.z, p.y + 60.0), p.z)
	# Ligne de tir peinte au sol et panneau.
	var line_mat := StandardMaterial3D.new()
	line_mat.albedo_color = Color(0.95, 0.95, 0.9)
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var line := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.15, 0.02, 12.0)
	line.mesh = bm
	line.material_override = line_mat
	add_child(line)
	line.global_position = ground.call(origin) + Vector3(0, 0.01, 0)
	line.rotation.y = yaw
	var panel := Label3D.new()
	panel.text = "CHAMP DE TIR"
	panel.font_size = 72
	panel.outline_size = 14
	panel.pixel_size = 0.01
	panel.modulate = Color(1, 0.85, 0.45)
	panel.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(panel)
	panel.global_position = ground.call(origin - fwd * 2.0) + Vector3(0, 3.2, 0)
	# Mannequins décalés sur le côté pour que chacun soit visible depuis la ligne
	# (celui de 25 m se déplace).
	var offsets := [-4.5, -1.0, 2.5, 6.0]
	for n in r.distances.size():
		var dist: float = r.distances[n]
		var c := Cible.new()
		if int(dist) == 25:
			c.patrol = 2.5
		add_child(c)
		c.global_position = ground.call(origin + fwd * dist + side * float(offsets[n % offsets.size()]))
		c.look_at(c.global_position - fwd, Vector3.UP)
		c.set_meta("distance", float(dist))
		targets.append(c)
		var l := Label3D.new()
		l.text = "%d m" % int(dist)
		l.font_size = 64
		l.outline_size = 12
		l.pixel_size = 0.01
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(l)
		l.global_position = c.global_position + Vector3(0, 2.4, 0)
	# Râtelier : toutes les armes en épique, alignées derrière la ligne.
	var k := 0
	for id in ARMES_COURANTES:
		var p: Vector3 = origin - fwd * 1.6 + side * (float(k) - 4.5) * 1.1
		spawn_weapon(Armes.nouvelle(id, 2, Accessoires.aleatoires(id, 3, rng)), ground.call(p) + Vector3(0, 0.02, 0), false)
		k += 1
	var c := Coffre.new()
	c.ravitaillement = true
	add_child(c)
	c.global_position = ground.call(origin - fwd * 3.2 + side * 6.5)
	c.look_at(c.global_position - fwd, Vector3.UP)
	c.rotation.y += PI
	chests.append(c)
