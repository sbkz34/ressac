extends Node3D
## Point d'entrée : construit l'île et lance un saut d'avion (ou la visite libre).
## Options (après « -- ») :
##   --check              vérifications automatiques (sans écran), affiche « [check] OK »
##   --tour --shots=DIR   prend des captures de chaque lieu dans DIR puis quitte

var ile: Ile
var player: Joueur
var hud: Hud
var avion: Avion
var pillage: Pillage
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	var t0 := Time.get_ticks_msec()
	ile = Ile.new()
	ile.name = "Ile"
	add_child(ile)
	ile.build()
	print("[ile] construite en %d ms : %d bâtiments, %d rampes" % [Time.get_ticks_msec() - t0, ile.stats.batiments, ile.stats.rampes])
	player = Joueur.new()
	player.name = "Joueur"
	add_child(player)
	pillage = Pillage.new()
	pillage.name = "Pillage"
	add_child(pillage)
	player.arsenal.pillage = pillage
	hud = Hud.new()
	add_child(hud)
	hud.attach(player)
	hud.request_plane.connect(start_plane)
	hud.request_visit.connect(start_visit)
	# La physique doit avoir enregistré les formes avant de lancer des rayons.
	await get_tree().physics_frame
	await get_tree().physics_frame
	pillage.populate(ile, 1234 if G.check_mode or G.tour_mode else randi())
	pillage.build_range(ile)
	print("[butin] %d objets, %d coffres, %d mannequins" % [pillage.items.size(), pillage.chests.size(), pillage.targets.size()])
	player.arsenal.starting_kit()
	start_visit()
	if G.check_mode:
		_check()
	elif G.tour_mode:
		_tour()
	else:
		start_plane()


func start_visit() -> void:
	_drop_plane()
	var dep: Dictionary = G.data.depart
	player.spawn_at(Vector3(dep.x, ile.ground_at(dep.x, dep.z) + 0.1, dep.z), deg_to_rad(float(dep.cap)))


## Un avion traverse l'île sur un trajet tiré au sort ; le joueur est sur la rampe.
func start_plane(angle := NAN, offset := NAN) -> void:
	_drop_plane()
	var route := Avion.random_route(rng)
	avion = Avion.new()
	avion.name = "Avion"
	add_child(avion)
	avion.setup(route[0] if is_nan(angle) else angle, route[1] if is_nan(offset) else offset)
	player.board(avion)
	hud.set_avion(avion)


func _drop_plane() -> void:
	if is_instance_valid(avion):
		avion.queue_free()
	avion = null
	hud.set_avion(null)


# ------------------------------------------------------------------------------------------------
# Vérifications
# ------------------------------------------------------------------------------------------------
var _errors: Array[String] = []


func _fail(msg: String) -> void:
	_errors.append(msg)
	print("[check] ECHEC : ", msg)


func _wait(seconds: float) -> void:
	var frames := int(seconds * Engine.physics_ticks_per_second)
	for i in frames:
		await get_tree().physics_frame


func _press(what: String) -> void:
	match what:
		"jump": player.scripted.jump = true
		"crouch": player.scripted.crouch = true
		"sprint": player.scripted.sprint = true
		"interact": player.scripted.interact = true
		"reload": player.scripted.reload = true
	await get_tree().physics_frame


func _press_hold_fire() -> void:
	player.scripted.fire_held = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.scripted.fire_held = false
	await get_tree().physics_frame


## Attend qu'une condition soit vraie (au plus `timeout` secondes) ; renvoie le temps écoulé ou -1.
func _until(cond: Callable, timeout: float) -> float:
	var frames := int(timeout * Engine.physics_ticks_per_second)
	for i in frames:
		if cond.call():
			return float(i) / Engine.physics_ticks_per_second
		await get_tree().physics_frame
	return -1.0


func _check() -> void:
	var terrain := ile.terrain
	var i := Intentions.new()
	player.scripted = i
	if terrain.n != 321:
		_fail("relief : %d points au lieu de 321" % terrain.n)
	for l in G.data.lieux:
		var h := terrain.height_at(float(l.x), float(l.z))
		if absf(h - float(l.h)) > 0.6:
			_fail("%s : sol à %.1f m au lieu de %.1f" % [l.nom, h, l.h])
	for s in G.data.boutiques:
		var g := ile.ground_at(float(s.x), float(s.z))
		var t := terrain.height_at(float(s.x), float(s.z))
		if g - t > 2.2:
			_fail("station d'achat de %s posée sur un obstacle (%.1f m)" % [s.lieu, g - t])
	for l in G.data.lieux:
		var w := G.where(Vector3(float(l.x), 0, float(l.z)))
		if not w.begins_with(String(l.nom)):
			_fail("nom de lieu : %s" % w)

	# Marche depuis le départ.
	var start := player.global_position
	i.move = Vector2(0, -1)
	await _wait(3.0)
	i.move = Vector2.ZERO
	var moved := Vector2(player.global_position.x - start.x, player.global_position.z - start.z).length()
	if moved < 8.0 or player.global_position.y < start.y - 1.0:
		_fail("départ : le joueur n'avance pas (%.1f m)" % moved)

	# Escalier de la capitainerie du Port.
	var port: Dictionary = G.data.lieux.filter(func(l): return l.id == "port")[0]
	var base := Vector3(float(port.x) + 20.0, float(port.h), float(port.z) - 8.0)
	player.spawn_at(base + Vector3(4.05, 0.1, -4.0 + 0.65), PI)
	await _wait(0.2)
	i.move = Vector2(0, -1)
	await _wait(2.6)
	i.move = Vector2.ZERO
	var climbed := player.global_position.y - base.y
	if climbed < 2.8:
		_fail("escalier : le joueur n'est monté que de %.1f m" % climbed)

	# Piste d'essai : à l'ouest du Lazaret, plat et dégagé, vers le nord.
	var lane := Vector3(48, 0, 25)
	lane.y = ile.ground_at(lane.x, lane.z) + 0.1

	# Sprint puis glissade : la glissade donne un coup de vitesse et finit accroupi.
	player.spawn_at(lane, 0.0)
	await _wait(0.1)
	i.move = Vector2(0, -1)
	await _press("sprint")
	await _wait(1.0)
	var run_speed := player.hspeed
	if absf(run_speed - Joueur.SPRINT) > 0.3 or not player.sprinting:
		_fail("sprint : %.2f m/s au lieu de %.1f" % [run_speed, Joueur.SPRINT])
	await _press("crouch")
	await _wait(0.1)
	var slide_speed := player.hspeed
	if player.etat != Joueur.Etat.GLISSADE or slide_speed < run_speed + 1.5:
		_fail("glissade : état %d, %.2f m/s" % [player.etat, slide_speed])
	await _until(func(): return player.etat != Joueur.Etat.GLISSADE, 2.0)
	if player.etat != Joueur.Etat.SOL or player.posture != Joueur.Posture.ACCROUPI:
		_fail("fin de glissade : état %d, posture %d" % [player.etat, player.posture])
	i.move = Vector2.ZERO

	# Cancel slide : on se relève en sprint sans perdre l'élan, le sprint tactique est rechargé.
	player.spawn_at(lane, 0.0)
	await _wait(0.1)
	i.move = Vector2(0, -1)
	await _press("sprint")
	await _wait(0.8)
	await _press("sprint")   # sprint tactique, puis glissade : la recharge démarre
	await _wait(0.4)
	await _press("crouch")
	await _wait(0.3)
	if player.tac_ready():
		_fail("glissade : le sprint tactique aurait dû se recharger")
	await _press("crouch")
	var cancel_speed := player.hspeed
	if player.etat != Joueur.Etat.SOL or player.posture != Joueur.Posture.DEBOUT or not player.sprinting:
		_fail("cancel slide : état %d, posture %d, sprint %s" % [player.etat, player.posture, player.sprinting])
	if cancel_speed < Joueur.SPRINT + 1.0:
		_fail("cancel slide : élan perdu (%.2f m/s)" % cancel_speed)
	if not player.tac_ready():
		_fail("cancel slide : le sprint tactique n'est pas rechargé")
	await _wait(0.3)
	var kept := player.hspeed
	if kept < Joueur.SPRINT + 0.3:
		_fail("cancel slide : l'élan retombe trop vite (%.2f m/s)" % kept)
	await _press("sprint")
	await _wait(0.8)
	if player.tac_left <= 0.0 or absf(player.hspeed - Joueur.TAC_SPRINT) > 0.4:
		_fail("sprint tactique : %.2f m/s" % player.hspeed)
	# Saut de glissade : on garde la vitesse en l'air.
	await _press("crouch")
	await _wait(0.2)
	await _press("jump")
	await _wait(0.1)
	if player.is_on_floor() or player.hspeed < Joueur.SPRINT:
		_fail("saut de glissade : %.2f m/s, au sol %s" % [player.hspeed, player.is_on_floor()])
	i.move = Vector2.ZERO
	await _wait(1.0)

	# Couché : maintenir accroupi ; un appui remonte accroupi, sauter remet debout.
	player.spawn_at(lane, 0.0)
	await _wait(0.1)
	i.crouch = true
	i.crouch_held = true
	await _wait(0.6)
	i.crouch_held = false
	if player.posture != Joueur.Posture.COUCHE:
		_fail("couché : posture %d" % player.posture)
	await _press("crouch")
	var p1 := player.posture
	await _press("jump")
	if p1 != Joueur.Posture.ACCROUPI or player.posture != Joueur.Posture.DEBOUT:
		_fail("se relever : %d puis %d" % [p1, player.posture])

	# Escalade : sur le conteneur de la cour du Lazaret (2,6 m).
	var lz: Dictionary = G.data.lieux.filter(func(l): return l.id == "lazaret")[0]
	var box_x := float(lz.x) + 13.0 + 1.2
	player.spawn_at(Vector3(box_x + 1.6, float(lz.h) + 0.1, float(lz.z) - 12.0), PI / 2)
	await _wait(0.1)
	i.move = Vector2(0, -1)
	await _wait(0.3)
	await _press("jump")
	var t_mantle := await _until(func(): return player.etat == Joueur.Etat.SOL and player.global_position.y > float(lz.h) + 2.4, 1.5)
	i.move = Vector2.ZERO
	if t_mantle < 0.0:
		_fail("escalade : hauteur %.2f m" % (player.global_position.y - float(lz.h)))

	# Chute libre depuis 150 m : ouverture automatique vers 40 m, atterrissage en douceur.
	player.start_freefall(Vector3(0, 150, -70))
	var opened_at := -1.0
	var max_chute_v := 0.0   # vitesse de descente juste avant de toucher le sol
	for k in 60 * 40:
		await get_tree().physics_frame
		if player.etat == Joueur.Etat.PARACHUTE:
			if opened_at < 0.0:
				opened_at = player.height_above_ground()
			max_chute_v = -player.velocity.y
		if player.etat == Joueur.Etat.SOL:
			break
	if opened_at < 25.0 or opened_at > Joueur.AUTO_DEPLOY + 2.0:
		_fail("ouverture automatique à %.1f m" % opened_at)
	if player.etat != Joueur.Etat.SOL or max_chute_v > 12.0:
		_fail("atterrissage : état %d, %.1f m/s sous la voile" % [player.etat, max_chute_v])

	# Ouvrir, couper, rouvrir.
	player.start_freefall(Vector3(30, 200, -70))
	await _wait(0.2)
	await _press("jump")
	var s1 := player.etat
	await _wait(0.5)
	await _press("crouch")
	var s2 := player.etat
	await _wait(0.5)
	await _press("jump")
	var s3 := player.etat
	if s1 != Joueur.Etat.PARACHUTE or s2 != Joueur.Etat.CHUTE_LIBRE or s3 != Joueur.Etat.PARACHUTE:
		_fail("parachute ouvrir/couper/rouvrir : %d %d %d" % [s1, s2, s3])
	await _until(func(): return player.etat == Joueur.Etat.SOL, 60.0)

	# Redéploiement : on saute du haut du château d'eau de la Citerne (18 m) et on ouvre.
	var ci: Dictionary = G.data.lieux.filter(func(l): return l.id == "citerne")[0]
	player.spawn_at(Vector3(float(ci.x), float(ci.h) + 18.2, float(ci.z) + 3.0), PI)
	await _wait(0.2)
	var on_tank := player.global_position.y
	i.move = Vector2(0, -1)
	await _until(func(): return not player.is_on_floor() and player.global_position.y < on_tank - 1.0, 3.0)
	i.move = Vector2.ZERO
	await _press("jump")
	if player.etat != Joueur.Etat.PARACHUTE:
		_fail("redéploiement depuis la Citerne : état %d (%.1f m au-dessus du sol)" % [player.etat, player.height_above_ground()])
	await _until(func(): return player.etat == Joueur.Etat.SOL, 30.0)

	# Avion : on saute au-dessus de l'île et on atterrit dessus.
	start_plane(0.0, 0.0)
	await _until(func(): return avion.progress >= 0.45, 30.0)
	await _press("jump")
	if player.etat != Joueur.Etat.CHUTE_LIBRE:
		_fail("saut d'avion : état %d" % player.etat)
	var t_land := await _until(func(): return player.etat == Joueur.Etat.SOL, 60.0)
	var ground := terrain.height_at(player.global_position.x, player.global_position.z)
	if t_land < 0.0 or ground < 0.5:
		_fail("atterrissage après l'avion : %.1f s, sol à %.1f m" % [t_land, ground])
	# Sans rien faire, on est éjecté au bout de l'île.
	start_plane(PI / 2, 30.0)
	var t_eject := await _until(func(): return player.etat != Joueur.Etat.AVION, 30.0)
	if t_eject < 0.0:
		_fail("éjection automatique de l'avion")
	_drop_plane()

	# Nage, drone.
	player.spawn_at(Vector3(45, 1.0, 180), 0.0)
	await _wait(2.0)
	if player.global_position.y < -2.5 or not player.swimming:
		_fail("nage : le joueur coule (%.1f m)" % player.global_position.y)
	player.set_drone(true)
	player.spawn_at(Vector3(0, 40, 0), 0.0)
	player.set_drone(true)
	i.move = Vector2(0, -1)
	await _wait(1.5)
	i.move = Vector2.ZERO
	if player.global_position.z > -15.0:
		_fail("drone : trop lent (z = %.1f)" % player.global_position.z)
	player.set_drone(false)

	# ---------------------------------------------------------------------------------------
	# Combat
	# ---------------------------------------------------------------------------------------
	var ar := player.arsenal
	ar.starting_kit()
	var kinds := {}
	ar.hit.connect(func(k: String, _a: float): kinds[k] = true)

	# Butin : chaque lieu en a, et chaque objet repose sur une surface.
	for l in G.data.lieux:
		var n := 0
		for b in pillage.items:
			if Vector2(b.global_position.x - float(l.x), b.global_position.z - float(l.z)).length() < float(l.rayon) + 10.0:
				n += 1
		if n < 2:
			_fail("butin : seulement %d objets au %s" % [n, l.nom])
	var floating := 0
	for b in pillage.items:
		var q := PhysicsRayQueryParameters3D.create(b.global_position + Vector3(0, 0.3, 0), b.global_position - Vector3(0, 0.6, 0), G.L_WORLD)
		if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			floating += 1
			print("[check] objet en l'air : ", b.label(), " ", b.global_position, " ", G.where(b.global_position))
	if floating > 0:
		_fail("butin : %d objets ne reposent sur rien" % floating)

	# Ramasser une arme posée devant soi (la main libre la prend).
	player.spawn_at(lane, 0.0)
	await _wait(0.2)
	var ground_w := pillage.spawn(Butin.make_arme(Armes.nouvelle("faucon", 1)), player.global_position + Vector3(0, 0, -1.2))
	await _wait(0.1)
	if ar.target_item != ground_w:
		_fail("ramassage : l'arme devant soi n'est pas proposée")
	await _press("interact")
	if ar.current().get("id", "") != "faucon" or ar.other().get("id", "") != "p9" or is_instance_valid(ground_w) and not ground_w.is_queued_for_deletion():
		_fail("ramassage : %s / %s" % [ar.current(), ar.other()])

	# Munitions ramassées en passant dessus.
	ar.reserve["fusil"] = 0
	pillage.spawn(Butin.make_munitions("fusil", 60), player.global_position + Vector3(0, 0.02, 0))
	await _wait(0.1)
	if int(ar.reserve["fusil"]) != 60:
		_fail("munitions : %d au lieu de 60" % ar.reserve["fusil"])

	# Rechargement : le chargeur se remplit depuis la réserve.
	ar.current().chargeur = 5
	await _press("reload")
	await _wait(2.4)
	var size := Armes.taille_chargeur("faucon", 1)
	if int(ar.current().chargeur) != size or int(ar.reserve["fusil"]) != 60 - (size - 5):
		_fail("rechargement : %d dans le chargeur, %d en réserve" % [ar.current().chargeur, ar.reserve["fusil"]])

	# Champ de tir : fusil d'assaut sur le mannequin à 10 m, en visant, recul compensé.
	ar.refill()
	var cdt: Dictionary = G.data.champ_de_tir
	var line := Vector3(float(cdt.x), 0, float(cdt.z))
	line.y = ile.ground_at(line.x, line.z) + 0.1
	player.spawn_at(line, deg_to_rad(float(cdt.cap)))
	await _wait(0.2)
	var t10: Cible = pillage.targets.filter(func(t): return float(t.get_meta("distance")) == 10.0)[0]
	var t70: Cible = pillage.targets.filter(func(t): return float(t.get_meta("distance")) == 70.0)[0]
	ar.slots[ar.cur] = Armes.nouvelle("faucon", 0)
	ar.view.set_weapon(ar.current(), false)
	i.ads_held = true
	await _wait(0.5)
	var shots0 := ar.shots_fired
	i.fire_held = true
	var killed_in := -1
	for k in 120:
		player.look_at_point(t10.aim_point())
		await get_tree().physics_frame
		if t10.sante.dead:
			killed_in = ar.shots_fired - shots0
			break
	i.fire_held = false
	var expected := Armes.coups_pour_tuer("faucon", 10.0)
	if killed_in != expected:
		_fail("Faucon à 10 m : %d balles au lieu de %d" % [killed_in, expected])
	for k in ["armure", "brise", "elimination"]:
		if not kinds.has(k):
			_fail("marqueur de touche manquant : %s" % k)

	# Fusil de précision : une balle dans la tête à 70 m traverse l'armure pleine.
	ar.slots[ar.cur] = Armes.nouvelle("aiguille", 0)
	ar.view.set_weapon(ar.current(), false)
	await _wait(1.6)
	player.look_at_point(t70.global_position + Vector3(0, 1.62, 0))
	await _wait(0.05)
	player.look_at_point(t70.global_position + Vector3(0, 1.62, 0))
	await _press_hold_fire()
	if not t70.sante.dead:
		_fail("Aiguille : la tête à 70 m ne tue pas (armure %.0f, vie %.0f)" % [t70.sante.armor, t70.sante.hp])
	i.ads_held = false

	# Portée : le fusil à pompe ne fait presque plus rien à 25 m.
	if Armes.degats("grele", 25.0, "torse") > 0.5 * Armes.degats("grele", 3.0, "torse"):
		_fail("Grêle : pas assez de perte de dégâts à 25 m")
	# En visant, on se déplace moins vite.
	ar.ads = 1.0
	var mm := ar.move_mult()
	ar.ads = 0.0
	if mm > 0.65:
		_fail("visée : vitesse %.2f" % mm)

	# Plaques : l'armure prend les dégâts, une plaque répare un segment, la vie se régénère.
	var s := player.sante
	s.reset(3)
	s.take(120.0)
	if absf(s.armor - 30.0) > 0.1 or s.hp < 99.9:
		_fail("armure : %.0f d'armure, %.0f de vie après 120 dégâts" % [s.armor, s.hp])
	var plates0 := ar.plates
	i.plate_held = true
	await _wait(Arsenal.PLATE_TIME * 2.0 + 0.15)
	i.plate_held = false
	if absf(s.armor - 100.0) > 0.1 or ar.plates != plates0 - 2:
		_fail("plaques : armure %.0f, %d dans le sac" % [s.armor, ar.plates])
	s.take(150.0)
	var hurt := s.hp
	await _wait(Sante.REGEN_DELAY + 2.0)
	if hurt > 60.0 or s.hp < 99.9:
		_fail("régénération : %.0f puis %.0f" % [hurt, s.hp])

	# Coffre : on l'ouvre, il répand son contenu.
	var chest: Coffre = pillage.chests.filter(func(c): return not c.ravitaillement)[0]
	var front := -chest.global_basis.z
	player.spawn_at(chest.global_position + front * 1.3 + Vector3(0, 0.1, 0), atan2(front.x, front.z))
	await _wait(0.2)
	var near_weapons := func() -> int:
		return pillage.items.filter(func(b): return b.type == Butin.Type.ARME and b.global_position.distance_to(chest.global_position) < 2.5).size()
	var before: int = near_weapons.call()
	if ar.target_item != chest:
		_fail("coffre : pas proposé (%s)" % ar.interact_label())
	await _press("interact")
	if not chest.is_open or near_weapons.call() < before + 1:
		_fail("coffre : ouvert %s, %d armes en plus" % [chest.is_open, near_weapons.call() - before])
	i.ads_held = false
	i.fire_held = false

	# Interface : avec une grande taille et une marge, le cadre reste dans l'écran.
	G.settings.hud_scale = 1.3
	G.settings.hud_margin = 0.05
	G.settings_changed.emit()
	await get_tree().process_frame
	var vp := get_viewport().get_visible_rect().size
	var fr := hud.frame_rect()
	if fr.position.x < vp.x * 0.05 - 0.5 or fr.end.x > vp.x - vp.x * 0.05 + 0.5 or fr.end.y > vp.y + 0.5:
		_fail("interface : cadre %s pour un écran %s" % [fr, vp])
	G.settings.hud_scale = 1.5
	G.settings_changed.emit()
	var menu_h: float = hud._pause_box.get_combined_minimum_size().y * hud._pause_box.scale.y
	if menu_h > vp.y:
		_fail("menu pause plus haut que l'écran (%.0f px)" % menu_h)

	player.scripted = null
	if _errors.is_empty():
		print("[check] OK (glissade %.1f m/s, cancel %.1f m/s, escalier %.1f m, parachute ouvert à %.0f m, Faucon %d balles, %d objets au sol)" % [slide_speed, cancel_speed, climbed, opened_at, killed_in, pillage.items.size()])
	get_tree().quit(0 if _errors.is_empty() else 1)


# ------------------------------------------------------------------------------------------------
# Captures
# ------------------------------------------------------------------------------------------------
func _shot(dir: String, name: String, frames := 8) -> void:
	for k in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])
	print("[tour] ", name)


func _tour() -> void:
	var dir := G.screenshot_dir if G.screenshot_dir != "" else "user://captures"
	DirAccess.make_dir_recursive_absolute(dir)
	var cam := Camera3D.new()
	cam.far = 2200.0
	cam.fov = 70.0
	add_child(cam)
	cam.current = true
	hud.visible = false
	var shots := [
		["00_vue_generale", Vector3(-150, 210, 330), Vector3(10, 0, -10)],
		["01_lazaret", Vector3(-60, 55, 50), Vector3(0, 16, -15)],
		["02_lazaret_cour", Vector3(-6, 16.7, -2), Vector3(8, 18, -30)],
		["03_phare", Vector3(-215, 38, -5), Vector3(-262, 30, -38)],
		["04_batterie", Vector3(-100, 42, -70), Vector3(-140, 28, -112)],
		["05_semaphore", Vector3(105, 52, -90), Vector3(155, 46, -132)],
		["06_citerne", Vector3(52, 26, -22), Vector3(80, 28, -50)],
		["07_conserverie", Vector3(275, 26, 55), Vector3(212, 6, 2)],
		["08_port", Vector3(5, 20, 175), Vector3(45, 3, 105)],
		["09_port_quai", Vector3(43, 4.0, 150), Vector3(55, 4, 95)],
		["10_cabanons", Vector3(-95, 30, 130), Vector3(-140, 6, 85)],
		["11_cabanons_ruelle", Vector3(-148, 7.7, 95), Vector3(-120, 8, 70)],
		["12_salins", Vector3(110, 22, 150), Vector3(170, 1, 100)],
		["13_cimetiere", Vector3(-50, 22, 45), Vector3(-75, 11, 12)],
		["14_cote_nord", Vector3(-20, 12, -150), Vector3(120, 30, -150)],
	]
	for s in shots:
		cam.global_position = s[1]
		cam.look_at(s[2])
		await _shot(dir, s[0])
	# Le joueur : sur la rampe de l'avion, sous la voile, puis l'interface et la carte.
	cam.current = false
	player.cam.current = true
	hud.visible = true
	G.input_mode = "touch"
	G.input_mode_changed.emit("touch")
	start_plane(0.3, 0.0)
	await _until(func(): return avion.progress > 0.28, 20.0)
	await _shot(dir, "20_avion")
	player.start_freefall(Vector3(-20, 60, 40))
	await _until(func(): return player.etat == Joueur.Etat.PARACHUTE, 10.0)
	player._pitch = deg_to_rad(40.0)
	await _shot(dir, "21_parachute")
	start_visit()
	player.scripted = Intentions.new()
	player.scripted.move = Vector2(0, -1)
	player.scripted.sprint = true
	await _wait(0.6)
	player.scripted.crouch = true
	await _wait(0.15)
	await _shot(dir, "22_glissade", 1)
	player.scripted = null
	hud.toggle_map()
	await _shot(dir, "23_carte")
	hud.toggle_map()
	# Combat : champ de tir, visée, lunette, butin dans un bâtiment.
	var ar := player.arsenal
	ar.refill()
	var cdt: Dictionary = G.data.champ_de_tir
	var line := Vector3(float(cdt.x), 0, float(cdt.z))
	line.y = ile.ground_at(line.x, line.z) + 0.1
	player.spawn_at(line, deg_to_rad(float(cdt.cap)))
	ar.slots = [Armes.nouvelle("faucon", 2), Armes.nouvelle("aiguille", 3)]
	ar.cur = 0
	ar.view.set_weapon(ar.current(), false)
	player.scripted = Intentions.new()
	var t50: Cible = pillage.targets.filter(func(t): return float(t.get_meta("distance")) == 50.0)[0]
	player.look_at_point(t50.aim_point())
	await _shot(dir, "25_champ_de_tir")
	player.scripted.ads_held = true
	await _wait(0.6)
	player.look_at_point(t50.aim_point())
	await _shot(dir, "26_visee")
	player.scripted.ads_held = false
	ar.cur = 1
	ar.view.set_weapon(ar.current(), false)
	await _wait(0.3)
	player.scripted.ads_held = true
	await _wait(0.8)
	var t70: Cible = pillage.targets.filter(func(t): return float(t.get_meta("distance")) == 70.0)[0]
	player.look_at_point(t70.global_position + Vector3(0, 1.5, 0))
	await _shot(dir, "27_lunette")
	player.scripted.ads_held = false
	# Butin au rez-de-chaussée d'un bâtiment du Lazaret.
	var lz: Dictionary = G.data.lieux.filter(func(l): return l.id == "lazaret")[0]
	var best: Butin = null
	for b in pillage.items:
		if b.type == Butin.Type.ARME and absf(b.global_position.y - float(lz.h)) < 0.3 \
				and Vector2(b.global_position.x - float(lz.x), b.global_position.z - float(lz.z)).length() < 40.0:
			best = b
			break
	if best:
		player.spawn_at(best.global_position + Vector3(2.2, 0.05, 0.4), PI / 2)
		player.look_at_point(best.global_position + Vector3(0, 0.3, 0))
		await _wait(0.2)
		await _shot(dir, "28_butin")
	player.scripted = null
	hud.open_pause()
	await _shot(dir, "24_pause")
	get_tree().quit()
