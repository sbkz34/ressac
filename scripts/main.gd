extends Node3D
## Point d'entrée : construit l'île, puis le lobby. Depuis le lobby : une partie de Résurgence
## contre des bots (Brume, réapparitions, achats, largages) ou l'entraînement libre au champ de tir.
## Options (après « -- ») :
##   --check              vérifications automatiques (sans écran), affiche « [check] OK »
##   --tour --shots=DIR   prend des captures dans DIR puis quitte
##   --bake-nav           recalcule le maillage de navigation des bots (assets/map/navigation.res)
##   --sim [--scale=N]    partie de 23 bots accélérée, sans écran (réglages) ; --sim --visee : précision

var ile: Ile
var player: Joueur
var hud: Hud
var lobby: Lobby
var avion: Avion
var pillage: Pillage
var partie: Partie
var nav: NavIle
var rng := RandomNumberGenerator.new()
var mode := "lobby"
var _lobby_cam: Camera3D
var _orbit := 0.0
var _training_respawn := -1.0
var bots: Array[Joueur] = []


func _ready() -> void:
	rng.randomize()
	var t0 := Time.get_ticks_msec()
	ile = Ile.new()
	ile.name = "Ile"
	add_child(ile)
	ile.build()
	print("[ile] construite en %d ms : %d bâtiments, %d rampes" % [Time.get_ticks_msec() - t0, ile.stats.batiments, ile.stats.rampes])
	nav = NavIle.new()
	nav.name = "Navigation"
	add_child(nav)
	if G.bake_nav:
		await get_tree().physics_frame
		await get_tree().physics_frame
		var t1 := Time.get_ticks_msec()
		var err := nav.bake_from(ile)
		var nm := nav.navigation_mesh
		print("[nav] %d polygones, %d sommets, %d ms, enregistrement : %s" % [nm.get_polygon_count(), nm.get_vertices().size(), Time.get_ticks_msec() - t1, error_string(err)])
		get_tree().quit(0 if err == OK else 1)
		return
	nav.load_mesh()
	player = Joueur.new()
	player.name = "Joueur"
	add_child(player)
	pillage = Pillage.new()
	pillage.name = "Pillage"
	add_child(pillage)
	pillage.shops.assign(ile.shops)
	for t in ile.tyroliennes:
		pillage.tyroliennes.append(t.ancre_bas)
		pillage.tyroliennes.append(t.ancre_haut)
		# Lien de navigation : les bots passent par la tyrolienne pour monter ou descendre.
		var link := NavigationLink3D.new()
		link.bidirectional = true
		nav.add_child(link)
		link.global_position = Vector3.ZERO
		link.start_position = t.bas
		link.end_position = t.haut
	player.arsenal.pillage = pillage
	player.sante.died.connect(_on_player_died)
	hud = Hud.new()
	add_child(hud)
	hud.attach(player)
	hud.set_pillage(pillage)
	hud.request_plane.connect(start_plane)
	hud.request_visit.connect(start_visit)
	hud.request_lobby.connect(show_lobby)
	hud.request_settings_closed.connect(func(): lobby.show_menu())
	lobby = Lobby.new()
	add_child(lobby)
	lobby.play.connect(start_partie)
	lobby.training.connect(start_training)
	lobby.settings.connect(func():
		lobby.visible = false
		hud.open_settings(false))
	_lobby_cam = Camera3D.new()
	_lobby_cam.far = 2200.0
	_lobby_cam.fov = 60.0
	add_child(_lobby_cam)
	Loadouts.load_all()
	G.settings_changed.connect(_apply_quality)
	_apply_quality()
	# La physique doit avoir enregistré les formes avant de lancer des rayons.
	await get_tree().physics_frame
	await get_tree().physics_frame
	pillage.populate(ile, 1234 if G.check_mode or G.tour_mode else randi())
	pillage.build_range(ile)
	print("[butin] %d objets, %d coffres, %d mannequins" % [pillage.items.size(), pillage.chests.size(), pillage.targets.size()])
	player.arsenal.starting_kit()
	start_visit()
	if G.icons_dir != "":
		_icones(G.icons_dir)
	elif G.perf_mode:
		_perf()
	elif G.sim_mode:
		_sim()
	elif G.check_mode:
		_set_mode("entrainement")
		_check()
	elif G.tour_mode:
		_set_mode("entrainement")
		_tour()
	else:
		show_lobby()


const QUALITES := ["Performance", "Équilibrée", "Qualité"]


## Qualité graphique : résolution du rendu 3D (l'interface reste nette) et ombres du soleil.
func _apply_quality() -> void:
	var q := clampi(int(G.settings.qualite), 0, 2)
	var vp := get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = [0.6, 0.75, 1.0][q]
	var sun := ile.sun
	sun.shadow_enabled = q > 0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if q == 2 else DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 70.0 if q == 2 else 45.0


func _set_mode(m: String) -> void:
	mode = m
	hud.mode = m
	var in_lobby := m == "lobby"
	hud.visible = not in_lobby
	lobby.visible = in_lobby
	player.ui_block = in_lobby
	_lobby_cam.current = in_lobby
	player.cam.current = not in_lobby
	if in_lobby:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func show_lobby() -> void:
	_end_partie()
	_drop_plane()
	hud.close_panel()
	get_tree().paused = false
	_set_mode("lobby")
	lobby.show_menu()


func _end_partie() -> void:
	if partie:
		partie.stop()
		partie.queue_free()
		partie = null
		hud.set_partie(null)
	_clear_bots()


func _clear_bots() -> void:
	for b in bots:
		if is_instance_valid(b):
			b.queue_free()
	bots.clear()
	Bot.reset_claims()


## Les adversaires : des combattants comme le joueur, pilotés chacun par un Bot.
func _spawn_bots(n: int, level: int, seed_value: int) -> void:
	var used: Array = []
	for k in n:
		var b := Joueur.new()
		b.is_bot = true
		b.nom = Bot.random_name(rng, used)
		used.append(b.nom)
		b.name = "Bot_%d" % k
		add_child(b)
		b.spawn_at(Vector3(0, -50 - k * 3, 0), 0.0)
		b.arsenal.pillage = pillage
		b.arsenal.starting_kit()
		var brain := Bot.new()
		brain.name = "Bot"
		b.add_child(brain)
		brain.setup(b, nav, partie, pillage, ile, level, seed_value + k * 7919)
		if partie:
			partie.add_combatant(b)
		bots.append(b)


## Une partie de Résurgence : île remise à neuf, Brume, bots, saut d'avion.
## `n_bots` / `level` : -1 pour les réglages du lobby.
func start_partie(n_bots := -1, level := -1) -> void:
	_end_partie()
	_set_mode("partie")
	pillage.clear()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var seed_value := randi() if not G.check_mode else 4321
	pillage.populate(ile, seed_value)
	pillage.build_range(ile)
	partie = Partie.new()
	partie.name = "Partie"
	add_child(partie)
	partie.setup(player, pillage, ile)
	partie.ended.connect(func(victory: bool, stats: Dictionary): hud.show_end(victory, stats))
	var n := int(G.settings.bots) if n_bots < 0 else n_bots
	_spawn_bots(clampi(n, 0, 23), int(G.settings.difficulte) if level < 0 else level, seed_value)
	hud.set_partie(partie)
	player.arsenal.starting_kit()
	partie.start(seed_value)
	start_plane()


## Entraînement : au champ de tir de la Batterie, sans Brume.
func start_training() -> void:
	_end_partie()
	_set_mode("entrainement")
	player.arsenal.starting_kit()
	_spawn_at_range()


func _spawn_at_range() -> void:
	_drop_plane()
	var cdt: Dictionary = G.data.champ_de_tir
	var line := Vector3(float(cdt.x), 0, float(cdt.z)) - Vector3(-sin(deg_to_rad(float(cdt.cap))), 0, -cos(deg_to_rad(float(cdt.cap)))) * 2.5
	line.y = ile.ground_at(line.x, line.z) + 0.1
	player.spawn_at(line, deg_to_rad(float(cdt.cap)))
	player.ui_block = false


func _on_player_died() -> void:
	# En entraînement, on revient au champ de tir au bout de 3 s.
	if mode == "entrainement":
		player.spectate(player.global_position)
		_training_respawn = 3.0


func _process(delta: float) -> void:
	if _lobby_cam == null:
		return
	if mode == "lobby":
		_orbit += delta * 0.04
		_lobby_cam.global_position = Vector3(cos(_orbit) * 330.0, 150.0, sin(_orbit) * 330.0 - 10.0)
		_lobby_cam.look_at(Vector3(0, 10, -10))
	if _training_respawn > 0.0:
		_training_respawn -= delta
		if _training_respawn <= 0.0:
			player.arsenal.starting_kit()
			_spawn_at_range()


func start_visit() -> void:
	_drop_plane()
	var dep: Dictionary = G.data.depart
	player.spawn_at(Vector3(dep.x, ile.ground_at(dep.x, dep.z) + 0.1, dep.z), deg_to_rad(float(dep.cap)))
	if mode != "lobby":
		player.ui_block = false


## Un avion traverse l'île sur un trajet tiré au sort ; le joueur est sur la rampe.
func start_plane(angle := NAN, offset := NAN) -> void:
	_drop_plane()
	var route := Avion.random_route(rng)
	avion = Avion.new()
	avion.name = "Avion"
	add_child(avion)
	avion.setup(route[0] if is_nan(angle) else angle, route[1] if is_nan(offset) else offset)
	player.ui_block = false
	player.board(avion)
	for b in bots:
		b.board(avion)
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

	# Navigation des bots : du Lazaret, on rejoint chaque lieu à pied ; on monte les escaliers.
	var from := nav.closest(Vector3(0, 15, -10))
	for l in G.data.lieux:
		var target := nav.closest(Vector3(float(l.x), float(l.h) + 0.5, float(l.z)))
		var path := nav.path(from, target)
		# (la cible peut tomber dans un bâtiment plein, comme le phare : on accepte d'arriver à côté)
		if path.size() < 2 or path[path.size() - 1].distance_to(target) > 6.0:
			_fail("navigation : pas de chemin vers %s (%d points)" % [l.nom, path.size()])
		elif target.distance_to(Vector3(float(l.x), float(l.h), float(l.z))) > 25.0:
			_fail("navigation : %s loin du maillage (%.0f m)" % [l.nom, target.distance_to(Vector3(float(l.x), float(l.h), float(l.z)))])
	var port2: Dictionary = G.data.lieux.filter(func(l): return l.id == "port")[0]
	var upstairs := Vector3(float(port2.x) + 20.0 - 2.5, float(port2.h) + 3.2 + 0.1, float(port2.z) - 8.0 + 2.0)
	var up_target := nav.closest(upstairs)
	var up_path := nav.path(nav.closest(Vector3(float(port2.x) + 20.0, float(port2.h), float(port2.z) - 2.0)), up_target)
	if absf(up_target.y - upstairs.y) > 0.6 or up_path.size() < 2 or up_path[up_path.size() - 1].distance_to(up_target) > 1.0:
		_fail("navigation : l'étage de la capitainerie n'est pas joignable (%s)" % up_target)

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
	player.spawn_at(base + Vector3(3.85, 0.1, -4.0 + 0.65), PI)
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
	# En eau profonde, on reste en nage (pas d'aller-retour nage / marche à la surface).
	var toggles := [0]
	var was_sw := [player.swimming]
	i.move = Vector2(0.3, -1)
	await _until(func():
		if player.swimming != was_sw[0]:
			toggles[0] += 1
			was_sw[0] = player.swimming
		return false, 3.0)
	i.move = Vector2.ZERO
	if toggles[0] > 0:
		_fail("nage : %d bascules nage / marche en 3 s" % toggles[0])
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
	var ground_w := pillage.spawn(Butin.make_arme(Armes.nouvelle("faucon", 1, [])), player.global_position + Vector3(0, 0, -1.2))
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
	var size := Armes.chargeur_de(ar.current())
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

	# ---------------------------------------------------------------------------------------
	# Jalon 3 : chutes, équipements, achats, largages, Brume, réapparitions
	# ---------------------------------------------------------------------------------------
	# Chute de 18 m (haut du château d'eau) sans parachute : lourds dégâts, à travers l'armure.
	var ci2: Dictionary = G.data.lieux.filter(func(l): return l.id == "citerne")[0]
	var tank_top := Vector3(float(ci2.x), float(ci2.h) + 18.2, float(ci2.z) + 3.0)
	for amorti in [false, true]:
		ar.starting_kit()
		if amorti:
			ar.perks = ["amorti"]
		player.spawn_at(tank_top, PI)
		await _wait(0.2)
		i.move = Vector2(0, -1)
		await _until(func(): return not player.is_on_floor(), 2.0)
		i.move = Vector2.ZERO
		await _until(func(): return player.is_on_floor(), 4.0)
		await _wait(0.1)
		var hp := player.sante.hp
		if amorti and hp < 99.9:
			_fail("Amorti : %.0f de vie après la chute" % hp)
		if not amorti and (hp > 30.0 or hp <= 0.0 or player.sante.armor < 49.0):
			_fail("chute de 18 m : %.0f de vie, %.0f d'armure" % [hp, player.sante.armor])
	ar.starting_kit()

	# Grenade lancée au pied du mannequin à 10 m.
	var cdt2: Dictionary = G.data.champ_de_tir
	var line2 := Vector3(float(cdt2.x), 0, float(cdt2.z))
	line2.y = ile.ground_at(line2.x, line2.z) + 0.1
	player.spawn_at(line2, deg_to_rad(float(cdt2.cap)))
	await _wait(0.2)
	var g10: Cible = pillage.targets.filter(func(t): return float(t.get_meta("distance")) == 10.0)[0]
	g10.sante.reset(3)
	ar.letal = "grenade"
	ar.letal_n = 1
	player.look_at_point(g10.global_position)
	i.lethal = true
	await _wait(3.2)
	if ar.letal_n != 0 or g10.sante.armor > 149.0:
		_fail("grenade : il en reste %d, armure du mannequin %.0f" % [ar.letal_n, g10.sante.armor])

	# Station d'achat du Lazaret : gilet de plaques, puis un largage de classe.
	var station: Node3D = ile.shops[0]
	ar.starting_kit()
	ar.argent = 6000
	player.spawn_at(station.global_position + Vector3(0, 0.1, 1.6), 0.0)
	await _wait(0.2)
	if ar.target_item != station:
		_fail("station d'achat : pas proposée (%s)" % ar.interact_label())
	await _press("interact")
	if hud._panel_kind != "achat":
		_fail("station d'achat : la fenêtre ne s'ouvre pas")
	hud.close_panel()
	var p0 := ar.plates
	Boutique.buy(ar, "gilet", station, pillage)
	if ar.plates != mini(p0 + 3, ar.plates_max()) or ar.argent != 5100:
		_fail("achat du gilet : %d plaques, %d €" % [ar.plates, ar.argent])
	if not Boutique.buy(ar, "largage", station, pillage) or ar.argent != 600:
		_fail("achat du largage : %d €" % ar.argent)
	if Boutique.buy(ar, "masque", station, pillage):
		_fail("achat sans assez d'argent accepté")
	var crate: Coffre = pillage.chests[pillage.chests.size() - 1]
	if not crate.largage:
		_fail("largage : pas de caisse")
	await _until(func(): return crate.can_open(), 15.0)
	var cfront := Vector3(crate.global_position.x, 0, crate.global_position.z) - Vector3(station.global_position.x, 0, station.global_position.z)
	player.spawn_at(crate.global_position + Vector3(0, 0.1, 0) - cfront.normalized() * 1.6, atan2(-cfront.x, -cfront.z))
	await _wait(0.2)
	if ar.target_item != crate:
		_fail("largage : caisse pas proposée (%s)" % ar.interact_label())
	await _press("interact")
	if hud._panel_kind != "classe" or not hud.largage.is_visible_in_tree() or hud.largage.cards.size() != Loadouts.SLOTS:
		_fail("largage : pas de choix de classe")
	else:
		hud.largage.cards[0].pressed.emit()
	var d0 := Loadouts.get_one(0)
	if ar.current().get("id", "") != d0.principale or int(ar.current().get("rarete", 0)) != Loadouts.RARETE or ar.perks != d0.atouts or player.ui_block:
		_fail("classe : %s, atouts %s" % [ar.current(), ar.perks])
	if crate.can_open():
		_fail("largage : la caisse s'ouvre encore")

	# Partie accélérée : cercles emboîtés, largage offert en phase 2, dégâts de la Brume,
	# mort et réapparition, plus de réapparition en phase 5.
	await start_partie(0)
	partie.brume.time_scale = 40.0
	var nested_ok := [true]
	var circles := []
	partie.brume.phase_started.connect(func(n):
		var b := partie.brume
		circles.append([n, b.center, b.radius, b.next_center, b.next_radius])
		if b.center.distance_to(b.next_center) + b.next_radius > b.radius + 0.05:
			nested_ok[0] = false)
	var ended_with := []
	partie.ended.connect(func(v: bool, _s: Dictionary): ended_with.append(v))
	player.spawn_at(Vector3(0, ile.ground_at(0, -15) + 0.1, -15), 0.0)
	var drops0 := pillage.chests.filter(func(c): return c.largage).size()
	await _until(func(): return partie.brume.phase >= 2, 10.0)
	await _wait(0.1)
	if pillage.chests.filter(func(c): return c.largage).size() != drops0 + 1:
		_fail("phase 2 : pas de largage offert")
	await _until(func(): return partie.brume.phase >= 3 and partie.brume.closing, 20.0)
	var b := partie.brume
	var out := b.center + (Vector2(0, -15) - b.center).normalized() * (b.radius + 25.0)
	if (Vector2(0, -15) - b.center).length() < 1.0:
		out = b.center + Vector2(b.radius + 25.0, 0)
	player.spawn_at(Vector3(out.x, ile.ground_at(out.x, out.y) + 0.2, out.y), 0.0)
	player.sante.reset(3)
	await _wait(1.0)
	if not player.in_gas or player.sante.hp > 99.0 or player.sante.armor < 149.0:
		_fail("Brume : dans la Brume %s, %.0f de vie, %.0f d'armure" % [player.in_gas, player.sante.hp, player.sante.armor])
	# Mort : sac au sol, compte à rebours, retour en chute libre dans la zone.
	var items0 := pillage.items.size()
	var dead_at := player.global_position
	player.sante.take(500.0, "torse", "brume", true)
	await _wait(0.1)
	if partie.respawn_left <= 0.0 or pillage.items.size() <= items0:
		_fail("mort : réapparition %.1f s, %d objets du sac" % [partie.respawn_left, pillage.items.size() - items0])
	await _until(func(): return partie.respawn_left < 0.0, 40.0)
	await _wait(0.1)
	var back := player.global_position
	if player.etat != Joueur.Etat.CHUTE_LIBRE or player.sante.dead or ar.current().get("id", "") != "p9":
		_fail("réapparition : état %d, arme %s" % [player.etat, ar.current()])
	if Vector2(back.x, back.z).distance_to(partie.last_drop.center) > float(partie.last_drop.radius) + 1.0:
		_fail("réapparition hors de la zone sûre")
	if Vector2(back.x, back.z).distance_to(Vector2(dead_at.x, dead_at.z)) < 1.0 and back.y < 100.0:
		_fail("réapparition : pas de largage en altitude")
	await _until(func(): return player.etat == Joueur.Etat.SOL, 60.0)
	player.sante.invulnerable = true
	await _until(func(): return partie.brume.phase >= Partie.REDEPLOY_PHASE, 60.0)
	player.sante.invulnerable = false
	player.sante.take(500.0, "torse", "brume", true)
	await _wait(0.1)
	if partie.running or ended_with != [false]:
		_fail("phase 5 : la mort devrait finir la partie (%s)" % [ended_with])
	if not nested_ok[0] or circles.size() < 5:
		_fail("Brume : cercles mal emboîtés (%d phases vues)" % circles.size())
	hud.close_panel()
	# Victoire : rester en vie jusqu'à la fermeture complète.
	await start_partie(0)
	partie.brume.time_scale = 300.0
	var won := []
	partie.ended.connect(func(v: bool, _s: Dictionary): won.append(v))
	player.spawn_at(Vector3(0, ile.ground_at(0, -15) + 0.1, -15), 0.0)
	player.sante.invulnerable = true
	await _until(func(): return not partie.running, 30.0)
	player.sante.invulnerable = false
	if won != [true] or hud._panel_kind != "fin":
		_fail("victoire : %s" % [won])
	show_lobby()
	await _wait(0.1)
	if mode != "lobby" or not lobby.visible or partie != null:
		_fail("retour au lobby")
	_set_mode("entrainement")
	player.ui_block = false

	# ---------------------------------------------------------------------------------------
	# Jalon 4 : bots
	# ---------------------------------------------------------------------------------------
	await _check_manette()
	var bot_stats := await _check_bots()

	# Manette : Y maintenu pose une plaque, Y bref change d'arme (par les vraies commandes).
	var ar2 := player.arsenal
	ar2.starting_kit()
	ar2.slots = [Armes.nouvelle("faucon", 0), Armes.nouvelle("p9", 0)]
	ar2.cur = 0
	_spawn_at_range()
	await _wait(0.3)
	player.scripted = null
	var armor0 := player.sante.armor
	Input.action_press("arme_plaque")
	await _wait(Joueur.HOLD_PLATE + ar2.plate_time() + 0.3)
	Input.action_release("arme_plaque")
	await _wait(0.2)
	if player.sante.armor < armor0 + 49.0 or ar2.cur != 0:
		_fail("Y maintenu : armure %.0f → %.0f, arme %d" % [armor0, player.sante.armor, ar2.cur])
	Input.action_press("arme_plaque")
	await _wait(0.08)
	Input.action_release("arme_plaque")
	await _wait(0.2)
	if ar2.cur != 1:
		_fail("Y bref : pas de changement d'arme")
	player.scripted = Intentions.new()
	# Touches : en donner une déjà prise l'échange ; « par défaut » remet tout.
	var xb := InputEventJoypadButton.new()
	xb.button_index = JOY_BUTTON_X
	G.rebind("jump", true, xb)
	if G.binding_name("jump", true) != "X" or G.binding_name("use", true) != "A":
		_fail("touches : saut %s, ramasser %s" % [G.binding_name("jump", true), G.binding_name("use", true)])
	var kk := InputEventKey.new()
	kk.physical_keycode = KEY_V
	G.rebind("plate", false, kk)
	if G.binding_name("plate", false) != "V" or not InputMap.action_has_event("plate", kk):
		_fail("touches : plaque au clavier %s" % G.binding_name("plate", false))
	G.reset_bindings()
	if G.binding_name("jump", true) != "A" or G.binding_name("use", true) != "X" or G.binding_name("plate", false) != "4":
		_fail("touches : rétablissement (%s, %s, %s)" % [G.binding_name("jump", true), G.binding_name("use", true), G.binding_name("plate", false)])
	hud.open_pause()
	hud.open_settings(true)
	hud.reglages._switch("commandes")
	hud.reglages.open_binds.emit()
	await get_tree().process_frame
	if hud._binds_grid.get_child_count() != 3 * (G.BINDABLE.size() + 1):
		_fail("écran des touches : %d cases" % hud._binds_grid.get_child_count())
	hud.close_binds()
	if not hud.reglages.visible:
		_fail("touches : pas de retour aux réglages")
	# Réglages : chaque onglet se construit ; un réglage changé s'applique (volume, sensibilité).
	for t in EcranReglages.ONGLETS:
		hud.reglages._switch(t)
		await get_tree().process_frame
		if hud.reglages._content.get_child_count() < 4:
			_fail("réglages : onglet %s vide" % t)
	hud.reglages._switch("son")
	await get_tree().process_frame
	(hud.reglages._first as HSlider).value = 0.5
	if absf(AudioServer.get_bus_volume_db(0) - linear_to_db(0.5)) > 0.1:
		_fail("réglages : volume général non appliqué")
	G.settings.vol_general = 0.8
	G.apply_volumes()
	# Disposition tactile : déplacer un bouton l'enregistre.
	hud.reglages.open_touch_layout.emit()
	if not hud.touch.editing:
		_fail("disposition tactile : pas d'édition")
	hud.touch._edit_sel = "saut"
	hud.touch._entry("saut")[0] = 0.5
	hud.touch._resize(1.2)
	hud.touch.finish_edit()
	var lay: Dictionary = G.settings.tactile
	if not lay.has("saut") or absf(float(lay.saut[0]) - 0.5) > 0.001 or float(lay.saut[2]) < 1.15:
		_fail("disposition tactile : %s" % [lay])
	G.settings.tactile = {}
	await get_tree().process_frame
	hud.reglages.visible = false
	hud._on_settings_closed()
	hud.close_pause()

	# Lobby : écran des classes (choisir une classe, une arme, un atout, rétablir).
	show_lobby()
	await _wait(0.1)
	var ec := lobby.ecran_classes
	lobby._show_classes(0)
	await get_tree().process_frame
	ec._class_cards[2].grab_focus()
	await get_tree().process_frame
	if ec._sel != 2 or not ec.visible or lobby._menu.visible:
		_fail("classes : sélection au focus (%d)" % ec._sel)
	ec._open_arme("principale")
	await get_tree().process_frame
	var other_w: String = "uzi" if Loadouts.get_one(2).principale != "uzi" else "faucon"
	ec._weapon_cards[other_w].pressed.emit()
	ec._weapon_cards[other_w].pressed.emit()   # le premier montre, le second équipe
	await get_tree().process_frame
	if Loadouts.get_one(2).principale != other_w or ec._view != "liste":
		_fail("classes : arme non équipée (%s, vue %s)" % [Loadouts.get_one(2).principale, ec._view])
	ec._open_atouts()
	await get_tree().process_frame
	var other_p: String = Loadouts.column(1).filter(func(x): return x != Loadouts.get_one(2).atouts[1])[0]
	ec._perk_cards[other_p].pressed.emit()
	if Loadouts.get_one(2).atouts[1] != other_p:
		_fail("classes : atout non choisi")
	# Armurier : poser un silencieux sur l'arme principale, il est sur l'arme du largage.
	ec._open_armurier("principale")
	await get_tree().process_frame
	ec._pick_emp("bouche")
	ec._poser("silencieux")
	var dacc := Loadouts.get_one(2)
	if not Loadouts.acc_de(dacc, "principale").has("silencieux"):
		_fail("armurier : silencieux pas posé (%s)" % [Loadouts.acc_de(dacc, "principale")])
	var tmp_ar := player.arsenal
	tmp_ar.apply_loadout(dacc)
	if not tmp_ar.current().get("acc", []).has("silencieux") or not bool(Armes.de(tmp_ar.current()).silencieux):
		_fail("armurier : l'arme de la classe n'a pas le silencieux")
	# Effets : chargeur étendu, canon long ; silencieux absent de la mini-carte des autres.
	var base_w := Armes.nouvelle("faucon", 0, [])
	var ext_w := Armes.nouvelle("faucon", 3, ["canon_long", "chargeur_etendu"])
	if Armes.chargeur_de(ext_w) <= Armes.chargeur_de(base_w) or float(Armes.de(ext_w).portee[1]) <= float(Armes.de(base_w).portee[1]):
		_fail("accessoires : chargeur %d / %d, portée %.0f" % [Armes.chargeur_de(ext_w), Armes.chargeur_de(base_w), Armes.de(ext_w).portee[1]])
	tmp_ar.starting_kit()
	G.shots.clear()
	tmp_ar.slots = [Armes.nouvelle("faucon", 3, ["silencieux"]), {}]
	tmp_ar.cur = 0
	tmp_ar._shoot(tmp_ar.current(), Armes.de(tmp_ar.current()))
	if not G.shots.is_empty():
		_fail("silencieux : tir signalé sur la mini-carte")
	tmp_ar.slots = [Armes.nouvelle("faucon", 0, []), {}]
	tmp_ar._shoot(tmp_ar.current(), Armes.de(tmp_ar.current()))
	if G.shots.is_empty():
		_fail("tir sans silencieux absent de la mini-carte")
	tmp_ar.starting_kit()
	ec._show("liste")
	ec._reset_class()
	if Loadouts.get_one(2) != Loadouts.DEFAUTS[2]:
		_fail("classes : rétablissement")
	ec.closed.emit()
	await get_tree().process_frame
	if ec.visible or not lobby._menu.visible:
		_fail("classes : retour au menu")
	_set_mode("entrainement")
	player.ui_block = false

	# Lobby : le bouton Réglages ouvre un menu visible, et le refermer ramène au lobby.
	show_lobby()
	await _wait(0.1)
	lobby.settings.emit()
	await get_tree().process_frame
	if not hud.visible or not hud.reglages.is_visible_in_tree() or hud._frame.visible:
		_fail("lobby : réglages invisibles (hud %s, réglages %s)" % [hud.visible, hud.reglages.is_visible_in_tree()])
	hud.reglages.visible = false
	hud._on_settings_closed()
	await get_tree().process_frame
	if hud.visible or not lobby.visible or get_tree().paused:
		_fail("lobby : retour des réglages (hud %s, lobby %s)" % [hud.visible, lobby.visible])
	_set_mode("entrainement")
	player.ui_block = false

	# Lobby : les boutons du nombre de bots et de la difficulté font le tour des choix.
	var bots0 := int(G.settings.bots)
	var seen := []
	for k in 4:
		lobby.bots_button.pressed.emit()
		seen.append(int(G.settings.bots))
	if seen.size() != 4 or seen[3] != bots0 or seen[0] == bots0 or not lobby.bots_button.text.contains(str(seen[3])):
		_fail("lobby : nombre de bots %s, bouton « %s »" % [seen, lobby.bots_button.text])
	var lvl0 := int(G.settings.difficulte)
	lobby.level_button.pressed.emit()
	if int(G.settings.difficulte) == lvl0:
		_fail("lobby : difficulté inchangée")
	for k in 2:
		lobby.level_button.pressed.emit()
	if int(G.settings.difficulte) != lvl0:
		_fail("lobby : la difficulté ne revient pas à %d" % lvl0)

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
		print("[check] bots : %s" % bot_stats)
	get_tree().quit(0 if _errors.is_empty() else 1)


## Manette : courbes de réponse et zones mortes, visée appliquée à chaque image (la caméra suit
## tout de suite), accélération en bout de course, assistance rotationnelle en se déplaçant.
func _check_manette() -> void:
	# Courbes.
	for c in ["dynamique", "standard", "lineaire"]:
		if Joueur.pad_curve(Vector2(0.05, 0), 0.07, c) != Vector2.ZERO or absf(Joueur.pad_curve(Vector2(1, 0), 0.07, c).x - 1.0) > 0.001:
			_fail("courbe %s : zones mortes" % c)
		var prev := 0.0
		for k in range(8, 100, 4):
			var v := Joueur.pad_curve(Vector2(k / 100.0, 0), 0.07, c).x
			if v < prev:
				_fail("courbe %s : pas croissante" % c)
			prev = v
	var mid := Vector2(0.4, 0)
	if not (Joueur.pad_curve(mid, 0.07, "standard").x < Joueur.pad_curve(mid, 0.07, "dynamique").x and Joueur.pad_curve(mid, 0.07, "dynamique").x < Joueur.pad_curve(mid, 0.07, "lineaire").x):
		_fail("courbes mal ordonnées")
	# Le vrai stick : la vue (et la caméra) tourne dès l'image suivante, puis accélère au bord.
	_set_mode("entrainement")
	_spawn_at_range()
	player.scripted = null
	await _wait(0.2)
	G.input_mode = "pad"
	var y0 := player._yaw
	Input.action_press("look_left", 1.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var y1 := player._yaw
	var cam_yaw := atan2(-(-player.cam.global_basis.z).x, -(-player.cam.global_basis.z).z)
	if absf(y1 - y0) < 0.001 or absf(wrapf(cam_yaw - y1, -PI, PI)) > 0.002:
		_fail("visée : la caméra ne suit pas tout de suite (%.4f → %.4f, caméra %.4f)" % [y0, y1, cam_yaw])
	await _wait(0.1)
	var a0 := player._yaw
	await _wait(0.2)
	var early := (player._yaw - a0) / 0.2
	await _wait(0.5)
	var a1 := player._yaw
	await _wait(0.2)
	var late := (player._yaw - a1) / 0.2
	Input.action_release("look_left")
	if late < early * 1.4:
		_fail("accélération en bout de course : %.1f puis %.1f °/s" % [rad_to_deg(early), rad_to_deg(late)])
	# Assistance rotationnelle : en se déplaçant de côté, la vue suit le mannequin.
	var err := []
	for level in [0, 1]:
		G.settings.assistance = level
		_spawn_at_range()
		var dummy: Node3D = null
		for t in pillage.targets:
			if (t as Cible).alive() and (dummy == null or t.global_position.distance_to(player.global_position) < dummy.global_position.distance_to(player.global_position)):
				dummy = t
		player.scripted = Intentions.new()
		player.look_at_point(Bot.aim_point(dummy))
		await _wait(0.3)
		player.scripted.move = Vector2(1, 0)
		await _wait(0.45)
		player.scripted.move = Vector2.ZERO
		var to: Vector3 = Bot.aim_point(dummy) - player.cam.global_position
		err.append(rad_to_deg((-player.cam.global_basis.z).angle_to(to)))
	G.settings.assistance = 1
	player.scripted = null
	if err[1] > err[0] * 0.75:
		_fail("assistance rotationnelle : écart %.2f° sans, %.2f° avec" % [err[0], err[1]])
	G.input_mode = "kbm"
	# Redéploiement pendant un changement d'arme : l'arme affichée est bien le P9.
	var arv := player.arsenal
	arv.slots = [Armes.nouvelle("faucon", 3), Armes.nouvelle("vipere", 2)]
	arv.cur = 0
	arv.view.set_weapon(arv.current(), false)
	arv.view.set_weapon(arv.other(), true)
	await _wait(0.1)
	arv.starting_kit()
	await _wait(0.8)
	if arv.view.shown != WeaponView.key_of(arv.current()) or arv.current().id != "p9":
		_fail("redéploiement : arme affichée %s au lieu du P9" % arv.view.shown)
	arv.view._build(Armes.nouvelle("titan", 3))
	await _wait(0.2)
	if arv.view.shown != WeaponView.key_of(arv.current()):
		_fail("arme affichée pas resynchronisée (%s)" % arv.view.shown)
	print("[check] manette : %.0f puis %.0f °/s au bord, écart en strafant %.1f° sans assistance, %.1f° avec" % [rad_to_deg(early), rad_to_deg(late), err[0], err[1]])


## Progression : niveaux, expérience d'une partie, défis, camouflages (sur l'arme en main),
## écran du lobby ; mesures de performances.
func _check_progression() -> String:
	if Progression.niveau_de(0) != [1, 0, 800] or Progression.niveau_de(800) != [2, 0, 920]:
		_fail("niveaux : %s, %s" % [Progression.niveau_de(0), Progression.niveau_de(800)])
	Progression.data = Progression._vide()
	var r := Progression.compter({"eliminations": 12, "tetes": 30, "contrats": 1, "coffres": 4, "temps": 600.0,
		"place": 1, "total": 16, "armes": {"faucon": 16}, "tirs": 100, "touches": 60, "degats": 3000.0, "serie": 5}, true)
	var sum := 0
	for l in r.lignes:
		sum += int(l[1])
	if int(r.total) != sum or r.defis.size() != 7 or r.camos.size() != 2 or int(r.apres[0]) < 5 or int(Progression.data.xp) != sum:
		_fail("progression : %d XP (somme %d), %d défis, camos %s, niveau %s" % [int(r.total), sum, r.defis.size(), r.camos, r.apres])
	if Progression.stat("victoires") != 1 or Progression.stat("meilleure_serie") != 5 or Progression.stat("top5") != 1:
		_fail("progression : statistiques %s" % [Progression.data.stats])
	if Progression.choisir_camo("faucon", "or") or not Progression.choisir_camo("faucon", "foret") or Progression.camo("faucon") != "foret":
		_fail("camouflages : choix %s" % Progression.camo("faucon"))
	# Le camouflage se voit sur l'arme en main.
	var ar := player.arsenal
	ar.slots = [Armes.nouvelle("faucon", 0, []), {}]
	ar.cur = 0
	ar.view.set_weapon(ar.current(), false)
	var camo_mat: Material = Armes.materiaux(0, "foret").metal
	if not ar.view._gun.find_children("*", "MeshInstance3D", true, false).any(func(mi): return mi.material_override == camo_mat):
		_fail("camouflage absent de l'arme en main")
	# Écran du lobby : les trois onglets se construisent.
	show_lobby()
	await _wait(0.1)
	for tab in ["defis", "camos", "stats"]:
		lobby._show_progression(tab)
		await _wait(0.1)
		if not lobby.ecran_progression.visible or lobby.ecran_progression._content.get_child_count() == 0:
			_fail("écran progression : onglet %s vide" % tab)
	if lobby.ecran_progression._apercu != null:
		_fail("écran progression : aperçu resté d'un autre onglet")
	lobby.ecran_progression._close()
	await _wait(0.1)
	if not lobby._menu.visible or not lobby._niveau.text.begins_with("NIVEAU %d" % Progression.niveau()):
		_fail("lobby : niveau %s" % lobby._niveau.text)
	# Mesures de performances.
	_set_mode("entrainement")
	G.set_setting("mesures", true)
	await _wait(0.5)
	if not hud._perf.visible or not hud._perf.text.contains("appels de dessin"):
		_fail("mesures de performances : %s" % hud._perf.text)
	G.set_setting("mesures", false)
	Progression.data = Progression._vide()
	return "progression : %d XP pour une partie test" % sum


## Tyroliennes : posées au sol et sur une plateforme, le joueur monte et descend, lâche le câble ;
## un bot qui veut aller au sommet passe par la tyrolienne (lien de navigation).
func _check_tyroliennes() -> String:
	if ile.tyroliennes.size() != 3 or pillage.tyroliennes.size() != 6:
		_fail("tyroliennes : %d" % ile.tyroliennes.size())
		return ""
	for t in ile.tyroliennes:
		var g := ile.ground_at(t.bas.x, t.bas.z)
		var top := ile.ground_at(t.haut.x, t.haut.z, t.haut.y + 1.5)
		var chest := ile.ground_at(t.coffre.x, t.coffre.z, t.coffre.y + 1.5)
		if absf(g - t.bas.y) > 0.4 or g < 0.5 or absf(top - t.haut.y) > 0.35 or absf(chest - t.coffre.y) > 0.6:
			_fail("%s : pied %.1f / sol %.1f, sommet %.1f / %.1f, coffre %.1f / %.1f" % [t.name, t.bas.y, g, t.haut.y, top, t.coffre.y, chest])
	if not pillage.chests.any(func(c): return c.global_position.distance_to(ile.tyroliennes[0].coffre) < 0.5):
		_fail("tyrolienne : pas de coffre au sommet")
	_set_mode("entrainement")
	var t: Tyrolienne = ile.tyroliennes[2]
	var ar := player.arsenal
	player.scripted = Intentions.new()
	player.sante.invulnerable = true
	player.spawn_at(t.bas + Vector3(0, 0.1, 0), 0.0)
	player.look_at_point(t.ancre_bas.global_position)
	await _wait(0.3)
	if ar.target_item != t.ancre_bas or ar.interact_label() != "Tyrolienne : monter":
		_fail("tyrolienne : pas proposée au pied (%s)" % [ar.target_item])
	player.scripted.interact = true
	await _wait(0.1)
	if player.etat != Joueur.Etat.TYROLIENNE:
		_fail("tyrolienne : on ne s'accroche pas")
	var t_up := await _until(func(): return player.etat == Joueur.Etat.SOL, 12.0)
	await _wait(0.3)
	if player.global_position.distance_to(t.haut) > 1.0 or not player.is_on_floor():
		_fail("tyrolienne : arrivée %s au lieu de %s" % [player.global_position, t.haut])
	player.look_at_point(t.ancre_haut.global_position)
	await _wait(0.2)
	if ar.target_item != t.ancre_haut:
		_fail("tyrolienne : pas proposée en haut (%s)" % [ar.target_item])
	player.scripted.interact = true
	await _until(func(): return player.etat == Joueur.Etat.TYROLIENNE, 1.0)
	await _until(func(): return player.etat == Joueur.Etat.SOL, 12.0)
	await _wait(0.3)
	if player.global_position.distance_to(t.bas) > 1.0:
		_fail("tyrolienne : descente arrivée %s" % [player.global_position])
	# Lâcher le câble en montant : on retombe.
	player.start_zip(t, true)
	await _wait(0.9)
	var y_drop := player.global_position.y
	player.scripted.jump = true
	await _wait(0.1)
	if player.etat == Joueur.Etat.TYROLIENNE or y_drop < t.bas.y + 3.0:
		_fail("tyrolienne : lâcher (%d, %.1f m)" % [player.etat, y_drop - t.bas.y])
	await _until(func(): return player.is_on_floor(), 6.0)
	player.sante.invulnerable = false
	player.sante.reset(0)
	player.scripted = null
	# Un bot va au sommet du Phare par la tyrolienne, guette, puis redescend.
	var tp: Tyrolienne = ile.tyroliennes[0]
	player.spawn_at(t.bas + Vector3(0, 0.1, 0), 0.0)
	_spawn_bots(1, 1, 31)
	var bz := bots[0]
	var brain := bz.get_node("Bot") as Bot
	var dir := (tp.bas - tp.haut)
	dir.y = 0
	var start := tp.bas + dir.normalized() * 12.0
	bz.spawn_at(Vector3(start.x, ile.ground_at(start.x, start.z) + 0.1, start.z), 0.0)
	await _wait(0.2)
	brain._think_t = 999.0
	brain._set_goal(tp.haut, "errance")
	var rode := [false]
	var t_bot := await _until(func():
		rode[0] = rode[0] or bz.etat == Joueur.Etat.TYROLIENNE
		return bz.global_position.distance_to(tp.haut) < 3.0 and bz.etat == Joueur.Etat.SOL, 30.0)
	if t_bot < 0.0 or not rode[0]:
		_fail("bot : n'atteint pas le sommet du Phare (%s, %s, %.0f m)" % [brain.state, rode[0], bz.global_position.distance_to(tp.haut)])
	await _wait(0.5)
	if brain._perch_t <= 0.0:
		_fail("bot : ne guette pas en haut (%s)" % brain.state)
	brain._perch_t = 0.0
	brain._think_t = 999.0
	brain._set_goal(start, "errance")
	var down := await _until(func(): return bz.global_position.distance_to(start) < 4.0, 30.0)
	if down < 0.0:
		_fail("bot : ne redescend pas (%s, %.0f m)" % [brain.state, bz.global_position.distance_to(start)])
	_clear_bots()
	await _wait(0.1)
	return "tyrolienne en %.1f s, bot au sommet en %.1f s" % [t_up, t_bot]


## Contrats (reconnaissance, trésor, prime) et séries de la boutique (drone, frappe).
func _check_contrats() -> String:
	await start_partie(2, 1)
	partie.brume.time_scale = 0.0
	var ct := partie.contrats
	var ar := player.arsenal
	await _until(func(): return bots[0].etat == Joueur.Etat.SOL and bots[1].etat == Joueur.Etat.SOL, 60.0)
	for bt in bots:
		(bt.get_node("Bot") as Bot).set_physics_process(false)
		bt.scripted = Intentions.new()
		bt.sante.invulnerable = true
	var base := Vector3(0, ile.ground_at(0, -15) + 0.1, -15)
	player.spawn_at(base, 0.0)
	player.ui_block = false
	var tabs := pillage.contrats.size()
	if tabs < 4:
		_fail("contrats : %d tablettes" % tabs)
	var take := func(kind: String) -> void:
		var t := Contrats.Tablette.new()
		t.kind = kind
		pillage.add_child(t)
		ct.prendre(t)
	# Reconnaissance : tenir la zone, l'argent tombe et les ennemis sont révélés.
	var money := ar.argent
	take.call("recon")
	if ct.actif != "recon" or ct.markers().is_empty() or ct.status() == "":
		_fail("reconnaissance : contrat pas lancé (%s)" % ct.actif)
	player.spawn_at(ct.zone + Vector3(0, 0.2, 0), 0.0)
	var t_rec := await _until(func(): return ct.actif == "", Contrats.RECON_TEMPS + 6.0)
	if t_rec < 0.0 or ar.argent != money + Contrats.RECOMPENSE.recon or not ct.revele():
		_fail("reconnaissance : %.1f s, %d €, révélés %s" % [t_rec, ar.argent - money, ct.revele()])
	# Trésor : ouvrir les trois coffres.
	money = ar.argent
	take.call("tresor")
	if ct.actif != "tresor" or ct.coffres.size() != 3:
		_fail("trésor : %d coffres" % ct.coffres.size())
	for c in ct.coffres.duplicate():
		c.open_chest()
		await _wait(0.05)
	if ct.actif != "" or ar.argent != money + Contrats.RECOMPENSE.tresor:
		_fail("trésor : %s, %d €" % [ct.actif, ar.argent - money])
	# Prime : le joueur abat la cible.
	money = ar.argent
	take.call("prime")
	var target := ct.cible
	if ct.actif != "prime" or target == null:
		_fail("prime : pas de cible")
	else:
		target.sante.invulnerable = false
		target.sante.take(500.0, "torse", "balle", true, player)
		await _wait(0.1)
		if ct.actif != "" or ar.argent != money + Contrats.RECOMPENSE.prime or int(partie.stats.get("contrats", 0)) != 3:
			_fail("prime : %s, %d €" % [ct.actif, ar.argent - money])
	# Séries : drone (ennemis révélés), frappe (choix sur la carte, dégâts comptés au joueur).
	ct.revele_jusqu = 0.0
	ar.argent = 9000
	var station := Node3D.new()
	add_child(station)
	if not Boutique.buy(ar, "drone", station, pillage) or not ct.revele():
		_fail("drone : pas d'ennemis révélés")
	if not Boutique.buy(ar, "frappe", station, pillage) or ct.frappes != 1 or not hud._map.visible or not hud._map.targeting:
		_fail("frappe : carte de visée pas ouverte (%d frappes)" % ct.frappes)
	station.queue_free()
	var victim := bots[0]
	if victim.sante.dead:
		victim = bots[1]
	victim.sante.invulnerable = false
	victim.sante.reset(0)
	victim.spawn_at(base + Vector3(40, 0, 0), 0.0)
	victim.global_position.y = ile.ground_at(victim.global_position.x, victim.global_position.z) + 0.1
	await _wait(0.5)
	hud._frappe_chosen(Vector2(victim.global_position.x, victim.global_position.z))
	if ct.frappes != 0 or hud._map.visible or player.ui_block:
		_fail("frappe : carte toujours ouverte")
	await _until(func(): return victim.sante.dead, 6.0)
	if not victim.sante.dead or victim.sante.last_attacker != player:
		_fail("frappe : cible %s, %.0f PV, par %s" % [victim.sante.dead, victim.sante.hp, victim.sante.last_attacker])
	# Recul : le rang dans la rafale suit les tirs et repart de zéro après une pause.
	await _until(func(): return bots[0].etat == Joueur.Etat.SOL and bots[1].etat == Joueur.Etat.SOL, 40.0)
	player.scripted = Intentions.new()
	ar.slots = [Armes.nouvelle("faucon", 0, []), {}]
	ar.cur = 0
	ar.reserve["fusil"] = 240
	await _wait(0.8)
	player.look_at_point(player.global_position + Vector3(0, 1.5, -30))
	player.scripted.fire_held = true
	await _wait(0.5)
	player.scripted.fire_held = false
	var burst := ar.burst_n
	await _wait(0.6)
	await _press_hold_fire()
	if burst < 4 or ar.burst_n != 1:
		_fail("recul : rafale de %d tirs, puis %d" % [burst, ar.burst_n])
	# Caméra de la mort : on suit le bot qui vous a éliminé, puis celui qui l'abat ; elle s'arrête
	# au redéploiement.
	player.scripted.fire_held = false
	var killer := bots[0]
	var avenger := bots[1]
	for bt in [killer, avenger]:
		bt.sante.invulnerable = false
		bt.sante.reset(0)
	killer.spawn_at(player.global_position + Vector3(6, 0.2, 6), 0.0)
	await _wait(0.2)
	player.sante.invulnerable = false
	player.sante.take(900.0, "torse", "balle", true, killer)
	await _wait(0.3)
	if hud.kc_target != killer or not hud._killcam.current or not hud._kc_box.visible:
		_fail("caméra de la mort : pas sur le tueur (%s)" % [hud.kc_target])
	killer.sante.take(900.0, "torse", "balle", true, avenger)
	await _wait(0.3)
	if hud.kc_target != avenger:
		_fail("caméra de la mort : ne passe pas au suivant (%s)" % [hud.kc_target])
	partie.info[player].respawn = 0.05
	await _wait(0.3)
	if hud.kc_target != null or not player.cam.current or player.sante.dead:
		_fail("caméra de la mort : toujours active après le redéploiement")
	player.scripted = null
	_end_partie()
	await _wait(0.1)
	return "contrats : %d tablettes, reconnaissance en %.1f s" % [tabs, t_rec]


func _check_bots() -> String:
	var out := []
	var lz: Dictionary = G.data.lieux.filter(func(l): return l.id == "lazaret")[0]
	var lzp := Vector3(float(lz.x), float(lz.h) + 0.2, float(lz.z))
	player.scripted = Intentions.new()
	player.spawn_at(Vector3(300, 40, 300), 0.0)   # à l'écart
	pillage.clear()
	await _wait(0.1)
	pillage.populate(ile, 1234)
	pillage.build_range(ile)

	# Pillage : un bot posé au Lazaret avec le kit de départ trouve vite une meilleure arme.
	_spawn_bots(1, 1, 11)
	var b0 := bots[0]
	b0.spawn_at(lzp, 0.0)
	var t_loot := await _until(func(): return Bot.weapon_score(b0.arsenal.slots[0]) > 2.0 or Bot.weapon_score(b0.arsenal.slots[1]) > 2.0, 30.0)
	if t_loot < 0.0:
		_fail("bot : pas d'arme ramassée en 30 s (%s, %s)" % [b0.arsenal.slots, (b0.get_node("Bot") as Bot).state])
	out.append("arme en %.1f s" % t_loot)
	_clear_bots()
	await _wait(0.1)

	# Tir : au champ de tir, un bot armé d'un Faucon abat un mannequin (armure complète).
	var cdt: Dictionary = G.data.champ_de_tir
	var line := Vector3(float(cdt.x), 0, float(cdt.z))
	line.y = ile.ground_at(line.x, line.z) + 0.1
	var downed := [0]
	for t in pillage.targets:
		t.sante.reset(3)
		t.sante.died.connect(func(): downed[0] += 1)
	_spawn_bots(1, 1, 12)
	b0 = bots[0]
	var brain0 := b0.get_node("Bot") as Bot
	brain0.target_dummies = true
	b0.spawn_at(line, deg_to_rad(float(cdt.cap)) + 0.4)
	b0.arsenal.slots = [Armes.nouvelle("faucon", 2, []), {}]
	b0.arsenal.reserve["fusil"] = 240
	var t_dummy := await _until(func(): return downed[0] >= 1, 40.0)
	if t_dummy < 0.0:
		_fail("bot : aucun mannequin abattu en 40 s (%d tirs, état %s)" % [b0.arsenal.shots_fired, brain0.state])
	out.append("mannequin en %.1f s (%d tirs)" % [t_dummy, b0.arsenal.shots_fired])
	_clear_bots()
	await _wait(0.1)

	# Duel à 30 m dans la cour du Lazaret : l'un des deux tombe, l'élimination revient à l'autre.
	_spawn_bots(2, 1, 13)
	var duel := [bots[0], bots[1]]
	duel[0].spawn_at(lzp + Vector3(-15, 0, -4), -PI / 2)
	duel[1].spawn_at(lzp + Vector3(15, 0, -4), PI / 2)
	for d in duel:
		d.arsenal.slots = [Armes.nouvelle("faucon", 1, []), {}]
		d.arsenal.reserve["fusil"] = 240
		d.sante.reset(3)
	var t_duel := await _until(func(): return duel[0].sante.dead or duel[1].sante.dead, 30.0)
	if t_duel < 0.0:
		_fail("duel : personne ne tombe en 30 s (%s / %s)" % [(duel[0].get_node("Bot") as Bot).state, (duel[1].get_node("Bot") as Bot).state])
	else:
		var loser: Joueur = duel[0] if duel[0].sante.dead else duel[1]
		var winner: Joueur = duel[1] if loser == duel[0] else duel[0]
		if loser.sante.last_attacker != winner:
			_fail("duel : élimination mal attribuée")
		out.append("duel en %.1f s" % t_duel)
	_clear_bots()
	await _wait(0.1)

	# Partie : un bot hors du prochain cercle rejoint la zone sûre ; le joueur abat un bot,
	# l'élimination lui est comptée et part dans le fil.
	await start_partie(2, 1)
	partie.brume.time_scale = 0.0
	await _until(func(): return bots[0].etat == Joueur.Etat.SOL and bots[1].etat == Joueur.Etat.SOL, 60.0)
	var br := partie.brume
	br.next_center = Vector2(lzp.x, lzp.z)
	br.next_radius = 40.0
	var far := Vector2(lzp.x, lzp.z) + Vector2(70, 0)
	var gas_bot := bots[0]
	gas_bot.spawn_at(Vector3(far.x, ile.ground_at(far.x, far.y) + 0.2, far.y), 0.0)
	gas_bot.sante.invulnerable = true
	var t_gas := await _until(func(): return Vector2(gas_bot.global_position.x, gas_bot.global_position.z).distance_to(br.next_center) < br.next_radius * 0.9, 30.0)
	if t_gas < 0.0:
		_fail("Brume : le bot ne rejoint pas la zone sûre (%s, %.0f m)" % [(gas_bot.get_node("Bot") as Bot).state, Vector2(gas_bot.global_position.x, gas_bot.global_position.z).distance_to(br.next_center)])
	out.append("zone sûre en %.1f s" % t_gas)
	var prey := bots[1]
	(prey.get_node("Bot") as Bot).set_physics_process(false)
	prey.scripted = Intentions.new()
	prey.spawn_at(lzp + Vector3(9, 0, -7), 0.0)
	prey.sante.reset(0)
	player.spawn_at(lzp + Vector3(9, 0, 5), 0.0)
	player.ui_block = false
	player.arsenal.slots = [Armes.nouvelle("faucon", 2, []), {}]
	player.arsenal.cur = 0
	player.arsenal.reserve["fusil"] = 240
	var feed := []
	partie.killed.connect(func(k, v, _c, by_p, _on_p): feed.append([k, v, by_p]))
	await _wait(0.6)
	player.scripted.fire_held = true
	await _until(func():
		player.look_at_point(prey.global_position + Vector3(0, 1.2, 0))
		return prey.sante.dead, 4.0)
	player.scripted.fire_held = false
	if not prey.sante.dead or int(partie.stats.eliminations) != 1 or feed.is_empty() or not feed[0][2]:
		_fail("élimination du joueur : %s, %d élim., fil %s" % [prey.sante.dead, int(partie.stats.get("eliminations", 0)), feed])
	elif partie.respawn_open and float(partie.info[prey].respawn) <= 0.0:
		_fail("bot éliminé : pas de réapparition prévue")
	# En quittant la partie, elle compte pour la progression (élimination au Faucon).
	var elim0 := Progression.stat("eliminations")
	var faucon0 := Progression.elim_arme("faucon")
	var parties0 := Progression.stat("parties")
	_end_partie()
	await _wait(0.1)
	if Progression.stat("eliminations") != elim0 + 1 or Progression.elim_arme("faucon") != faucon0 + 1 or Progression.stat("parties") != parties0 + 1:
		_fail("progression : partie mal comptée (%s)" % [Progression.data.stats])
	out.append(await _check_progression())

	# Contrats et séries.
	out.append(await _check_contrats())
	# Tyroliennes.
	out.append(await _check_tyroliennes())

	# Partie accélérée à 24 : elle va jusqu'au bout (dernier debout), sans blocage.
	var t0 := Time.get_ticks_msec()
	await start_partie(23, 1)
	partie.brume.time_scale = 12.0
	player.sante.invulnerable = true
	var kills := [0]
	partie.killed.connect(func(k, _v, _c, _a, _b):
		if k != "":
			kills[0] += 1)
	var looted := [0]
	var t_end := await _until(func():
		for bb in bots:
			if Bot.weapon_score(bb.arsenal.current()) > 2.0:
				looted[0] = maxi(looted[0], 1)
		return not partie.running, 240.0)
	player.sante.invulnerable = false
	if t_end < 0.0 or kills[0] < 5:
		_fail("partie à 24 : fin %s, %d éliminations, %d en jeu" % [t_end, kills[0], partie.remaining()])
	out.append("partie à 24 : %.0f s de jeu, %d éliminations, %d ms de calcul" % [t_end, kills[0], Time.get_ticks_msec() - t0])
	hud.close_panel()
	show_lobby()
	await _wait(0.1)
	_set_mode("entrainement")
	player.ui_block = false
	player.scripted = Intentions.new()
	return ", ".join(out)


## --sim [--scale=N] : une partie complète de 23 bots (le joueur, invulnérable, ne joue pas) ;
## affiche l'état des bots régulièrement et le temps de calcul. --sim --visee : précision des
## bots selon la difficulté et la distance.
func _sim() -> void:
	if OS.get_cmdline_user_args().has("--visee"):
		await _lab_aim()
		get_tree().quit()
		return
	var scale := 8.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scale="):
			scale = float(a.substr(8))
	await start_partie(23, 1)
	partie.brume.time_scale = scale
	player.scripted = Intentions.new()
	player.sante.invulnerable = true
	var t0 := Time.get_ticks_msec()
	var feed := []
	partie.killed.connect(func(k, v, c, _a, _b): feed.append("%s>%s(%s)" % [k, v, c]))
	var sec := 0
	while partie and partie.running and sec < 900:
		await _wait(5.0)
		sec += 5
		var states := {}
		var guns := {}
		for b in bots:
			var brain := b.get_node("Bot") as Bot
			states[brain.state] = int(states.get(brain.state, 0)) + 1
			var w := b.arsenal.current()
			var id: String = w.get("id", "-")
			guns[id] = int(guns.get(id, 0)) + 1
		print("[sim] t=%d s phase %d · en jeu %d · %s · armes %s · %d ms réels · %s" % [sec, partie.brume.phase, partie.remaining(), states, guns, Time.get_ticks_msec() - t0, " ".join(feed)])
		feed.clear()
	print("[sim] fin : %s, %d ms" % [partie.stats if partie else {}, Time.get_ticks_msec() - t0])
	get_tree().quit()


## --perf : appels de dessin, objets, triangles et temps de calcul à quelques points de vue,
## pendant une partie à 16.
func _perf() -> void:
	await start_partie(15, 1)
	partie.brume.time_scale = 0.0
	await _until(func(): return bots.all(func(b): return b.etat == Joueur.Etat.SOL), 60.0)
	player.scripted = Intentions.new()
	var lz: Dictionary = G.data.lieux.filter(func(l): return l.id == "lazaret")[0]
	var views := [
		["lazaret_cour", Vector3(float(lz.x) + 8, float(lz.h) + 0.1, float(lz.z) + 6), Vector3(float(lz.x), float(lz.h) + 1.5, float(lz.z) - 30)],
		["lazaret_vers_ile", Vector3(float(lz.x), float(lz.h) + 0.1, float(lz.z) + 30), Vector3(150, 10, 100)],
		["port", Vector3(30, 3.5, 140), Vector3(80, 3, 80)],
		["cabanons", Vector3(-120, 7, 95), Vector3(-160, 6, 80)],
		["salins_vers_ile", Vector3(160, 2, 120), Vector3(-100, 10, -60)],
		["semaphore_haut", Vector3(150, 47, -130), Vector3(0, 5, 50)],
	]
	var mi_count := [0]
	var count := func(n: Node, f: Callable) -> void:
		if n is MeshInstance3D or n is MultiMeshInstance3D:
			mi_count[0] += 1
		for c in n.get_children():
			f.call(c, f)
	count.call(self, count)
	print("[perf] %d MeshInstance3D / MultiMeshInstance3D dans la scène" % mi_count[0])
	var by := {}
	for n in find_children("*", "GeometryInstance3D", true, false):
		var top: Node = n
		while top.get_parent() != self and top.get_parent() != null:
			top = top.get_parent()
		var key: String = String(top.name).rstrip("0123456789_@")
		if top == ile:
			key = "Ile/" + String(n.get_parent().name).rstrip("0123456789_@").left(14)
		var tri := 0
		if n is MeshInstance3D and (n as MeshInstance3D).mesh:
			var m := (n as MeshInstance3D).mesh
			for si in m.get_surface_count():
				var arr := m.surface_get_arrays(si)
				tri += (arr[Mesh.ARRAY_INDEX].size() if arr[Mesh.ARRAY_INDEX] else arr[Mesh.ARRAY_VERTEX].size()) / 3
		elif n is MultiMeshInstance3D:
			var mm := (n as MultiMeshInstance3D).multimesh
			var arr2 := mm.mesh.surface_get_arrays(0)
			tri = (arr2[Mesh.ARRAY_INDEX].size() if arr2[Mesh.ARRAY_INDEX] else arr2[Mesh.ARRAY_VERTEX].size()) / 3 * mm.instance_count
		var e: Array = by.get(key, [0, 0])
		by[key] = [e[0] + 1, e[1] + tri]
	for k in by:
		print("[perf]   %-22s %5d objets %8d triangles" % [k, by[k][0], by[k][1]])
	for v in views:
		player.spawn_at(v[1], 0.0)
		player.look_at_point(v[2])
		for k in 20:
			await get_tree().process_frame
		var dc := 0
		var ob := 0
		var pr := 0
		var cpu := 0.0
		var phys := 0.0
		for k in 10:
			await get_tree().process_frame
			dc += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			ob += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
			pr += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
			cpu += Performance.get_monitor(Performance.TIME_PROCESS)
			phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		print("[perf] %-18s %5d appels  %5d objets  %7d k triangles  process %.1f ms  physique %.1f ms" % [v[0], dc / 10, ob / 10, pr / 10000, cpu * 100.0, phys * 100.0])
		if OS.get_cmdline_user_args().has("--detail") and (v[0] == "lazaret_cour" or v[0] == "salins_vers_ile"):
			var groups := {"butin": [pillage], "bots": bots, "ombres": [ile.sun]}
			var veg := []
			var bat := []
			for c in ile.get_children():
				if c is MultiMeshInstance3D:
					veg.append(c)
				elif c is MeshInstance3D:
					bat.append(c)
			groups["vegetation"] = veg
			groups["batiments"] = bat
			groups["terrain"] = [ile.terrain]
			for gname in groups:
				for nd in groups[gname]:
					if nd is DirectionalLight3D:
						nd.shadow_enabled = false
					else:
						nd.visible = false
				for k in 6:
					await get_tree().process_frame
				var dc2 := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
				var ob2 := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
				print("[perf]     sans %-11s -%4d appels  -%4d objets" % [gname, dc / 10 - dc2, ob / 10 - ob2])
				for nd in groups[gname]:
					if nd is DirectionalLight3D:
						nd.shadow_enabled = int(G.settings.qualite) > 0
					else:
						nd.visible = true
	get_tree().quit()


## --icones=DIR : chaque arme vue de profil (vrai modèle du jeu), fond transparent, en PNG.
func _icones(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var vp := SubViewport.new()
	vp.size = Vector2i(720, 270)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.environment.ambient_light_energy = 0.7
	vp.add_child(env)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.6
	vp.add_child(key)
	key.look_at_from_position(Vector3(4, 5, 2.5), Vector3.ZERO)
	var rim := DirectionalLight3D.new()
	rim.light_energy = 1.1
	rim.light_color = Color(0.85, 0.92, 1.0)
	vp.add_child(rim)
	rim.look_at_from_position(Vector3(-3, 3, -4), Vector3.ZERO)
	# Matières plus claires que dans le jeu : on lit les volumes sur un fond de menu sombre.
	var mk := func(c: Color, metal: float, rough: float) -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.metallic = metal
		m.roughness = rough
		return m
	var wood: StandardMaterial3D = (Armes.materiaux(0).wood as StandardMaterial3D).duplicate()
	wood.albedo_color = Color(1.0, 0.82, 0.68)
	var mats := {"metal": mk.call(Color(0.46, 0.48, 0.52), 0.55, 0.38), "dark": mk.call(Color(0.2, 0.21, 0.23), 0.3, 0.55),
		"wood": wood, "glow": mk.call(Color(1.0, 0.8, 0.35), 0.0, 0.5), "verre": Armes.verre()}
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(cam)
	cam.current = true
	for id in Armes.ARMES:
		var model := GunShapes.build_model(id, mats, 1.0)
		vp.add_child(model)
		var box := AABB()
		var first := true
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			box = b if first else box.merge(b)
			first = false
		var c := box.get_center()
		# Trois quarts, un peu au-dessus : on voit le dessus et le flanc.
		cam.size = maxf(box.size.z * 1.12 * 270.0 / 720.0, box.size.y * 1.35)
		cam.global_position = c + Vector3(5, 1.6, -1.1)
		cam.look_at(c, Vector3.UP)
		for k in 4:
			await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("%s/%s.png" % [dir, id])
		print("[icones] ", id)
		model.queue_free()
	get_tree().quit()


## Précision d'un bot (Faucon) sur le joueur immobile, par difficulté et distance.
func _lab_aim() -> void:
	_set_mode("entrainement")
	var lz: Dictionary = G.data.lieux.filter(func(l): return l.id == "lazaret")[0]
	var lzp := Vector3(float(lz.x) + 9, float(lz.h) + 0.2, float(lz.z))
	for lvl in 3:
		for dist in [10.0, 25.0, 50.0]:
			_spawn_bots(1, lvl, 5)
			var b := bots[0]
			b.arsenal.slots = [Armes.nouvelle("faucon", 1), {}]
			b.arsenal.reserve["fusil"] = 240
			player.scripted = Intentions.new()
			player.spawn_at(lzp + Vector3(0, 0, -dist * 0.5), 0.0)
			player.sante.reset(3)
			player.sante.invulnerable = false
			b.spawn_at(lzp + Vector3(0, 0, dist * 0.5), 0.0)
			var hits := [0]
			var c := func(_a, _z, _o, _b, _k):
				hits[0] += 1
				player.sante.hp = 100.0
				player.sante.armor = 150.0
			player.sante.damaged.connect(c)
			await _wait(6.0)
			player.sante.damaged.disconnect(c)
			print("[aim] niveau %d, %d m : %d/%d (%.0f %%)" % [lvl, int(dist), hits[0], b.arsenal.shots_fired, 100.0 * hits[0] / maxf(1, b.arsenal.shots_fired)])
			_clear_bots()
			await _wait(0.1)


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
	ar.slots = [Armes.nouvelle("faucon", 3, ["compensateur", "canon_long", "holo", "chargeur_etendu", "crosse_stable"]), Armes.nouvelle("aiguille", 3)]
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
	# Jalon 3 : lobby, classes, Brume, achats, largage, fin de partie.
	show_lobby()
	await _shot(dir, "30_lobby")
	lobby._show_classes()
	await _shot(dir, "31_classes")
	lobby._edit(0)
	lobby.ecran_classes._preview_weapon("vipere")
	await _shot(dir, "31b_classe")
	lobby.ecran_classes._open_atouts()
	await _shot(dir, "31c_atouts")
	lobby.ecran_classes._open_armurier("principale")
	lobby.ecran_classes._pick_emp("viseur")
	await _shot(dir, "31d_armurier")
	lobby.ecran_classes._show("liste")
	await start_partie(0)
	partie.brume.time_scale = 80.0
	await _until(func(): return partie.brume.phase >= 3 and partie.brume.closing, 30.0)
	partie.brume.time_scale = 0.0
	var b := partie.brume
	var dir2 := (Vector2(0, -15) - b.center).normalized()
	if dir2 == Vector2.ZERO:
		dir2 = Vector2(1, 0)
	var inside := b.center + dir2 * (b.radius - 25.0)
	player.spawn_at(Vector3(inside.x, ile.ground_at(inside.x, inside.y) + 0.1, inside.y), atan2(-dir2.x, -dir2.y))
	player.sante.invulnerable = true
	await _wait(0.3)
	await _shot(dir, "32_brume")
	var outside := b.center + dir2 * (b.radius + 20.0)
	player.spawn_at(Vector3(outside.x, ile.ground_at(outside.x, outside.y) + 0.1, outside.y), atan2(dir2.x, dir2.y))
	await _wait(0.3)
	await _shot(dir, "33_dans_la_brume")
	hud.toggle_map()
	await _shot(dir, "34_carte_brume")
	hud.toggle_map()
	var station: Node3D = ile.shops[0]
	player.spawn_at(station.global_position + Vector3(0, 0.1, 1.6), 0.0)
	player.arsenal.argent = 5200
	hud.open_shop(station)
	await _shot(dir, "35_boutique")
	hud.close_panel()
	var crate := pillage.spawn_largage(player.global_position + Vector3(4, 0, 0))
	hud.open_loadout_choice(crate)
	await _shot(dir, "36_largage")
	hud.close_panel()
	# Progression d'exemple (non enregistrée) pour les captures.
	var saved := Progression.data.duplicate(true)
	Progression.data = Progression._vide()
	var rep := Progression.compter({"eliminations": 9, "tetes": 22, "contrats": 2, "coffres": 6, "temps": 612.0,
		"place": 1, "total": 16, "armes": {"faucon": 7, "vipere": 2}, "tirs": 240, "touches": 130, "degats": 2900.0, "serie": 4}, true)
	hud.show_end(true, {"temps": 612.0, "phase": 6, "morts": 2, "argent": 3150, "place": 1, "total": 16, "eliminations": 9, "progression": rep})
	await _shot(dir, "37_fin")
	Progression.data.armes["faucon"] = 34
	Progression.data.camos["faucon"] = "foret"
	hud.close_panel()
	_set_mode("lobby")
	lobby.show_menu()
	await _shot(dir, "30b_lobby_niveau")
	lobby._show_progression("defis")
	await _shot(dir, "49_defis")
	lobby._show_progression("camos")
	await _wait(0.3)
	await _shot(dir, "49b_camouflages")
	lobby._show_progression("stats")
	await _shot(dir, "49c_statistiques")
	lobby.ecran_progression._close()
	Progression.data = saved
	_set_mode("partie")
	hud.close_panel()
	player.sante.invulnerable = false
	hud.mode = "partie"
	hud.open_pause()
	await _shot(dir, "24_pause")
	hud.open_settings(true)
	hud.reglages._switch("son")
	await _shot(dir, "41_reglages")
	hud.reglages._switch("commandes")
	await _shot(dir, "41b_reglages_commandes")
	hud.reglages.open_touch_layout.emit()
	await _shot(dir, "42_disposition")
	hud.touch.finish_edit()
	hud.reglages.visible = false
	hud._on_settings_closed()
	hud.close_pause()
	# Jalon 4 : les bots (silhouettes, armes en main) et un échange de tirs.
	show_lobby()
	_set_mode("entrainement")
	player.scripted = Intentions.new()
	var lzc: Dictionary = G.data.lieux.filter(func(l): return l.id == "lazaret")[0]
	var base := Vector3(float(lzc.x), float(lzc.h), float(lzc.z))
	player.spawn_at(base + Vector3(0, 0.1, 6), 0.0)
	_spawn_bots(3, 1, 7)
	var poses := [[Vector3(-2.2, 0, -2), "faucon", Joueur.Posture.DEBOUT], [Vector3(1.0, 0, -4), "vipere", Joueur.Posture.ACCROUPI],
		[Vector3(3.6, 0, -1.5), "aiguille", Joueur.Posture.DEBOUT]]
	for k in 3:
		var bt := bots[k]
		(bt.get_node("Bot") as Bot).set_physics_process(false)
		bt.scripted = Intentions.new()
		bt.spawn_at(base + poses[k][0] + Vector3(0, 0.1, 0), 0.0)
		bt.arsenal.slots = [Armes.nouvelle(poses[k][1], 2), {}]
		bt.arsenal.cur = 0
		bt._set_posture(poses[k][2], true)
		bt.look_at_point(player.global_position + Vector3(0, 1.5, 0) + Vector3(k - 1, 0, 0) * 3.0)
	await _wait(0.2)
	player.look_at_point(base + Vector3(0.8, 1.0, -2.5))
	await _shot(dir, "38_bots")
	# Duel : deux bots à 25 m, vus de côté.
	for k in 3:
		(bots[k].get_node("Bot") as Bot).set_physics_process(k < 2)
	bots[2].spawn_at(base + Vector3(30, 0.1, 30), 0.0)
	bots[0].spawn_at(base + Vector3(-12, 0.1, -6), -PI / 2)
	bots[1].spawn_at(base + Vector3(12, 0.1, -6), PI / 2)
	for k in 2:
		bots[k].arsenal.slots = [Armes.nouvelle("faucon", 2), {}]
		bots[k].arsenal.reserve["fusil"] = 240
	player.spawn_at(base + Vector3(0, 0.1, 10), 0.0)
	player.look_at_point(base + Vector3(0, 1.2, -6))
	await _wait(1.6)
	await _shot(dir, "39_duel", 1)
	_clear_bots()
	# Partie à 16 : compteur, fil des éliminations, indicateur de dégâts.
	await start_partie(15, 1)
	player.scripted = Intentions.new()
	await _wait(2.0)
	partie.killed.emit("Goéland", "Mistral", "balle", false, false)
	partie.killed.emit(player.nom, "Rascasse", "balle", true, false)
	partie.killed.emit("Corsaire", "Cigale", "grenade", false, false)
	partie.killed.emit("", "Galet", "brume", false, false)
	partie.stats.eliminations = 1
	hud._cross.add_damage(player.global_position + player.global_basis.x * -20.0)
	player.sante.hp = 28.0
	var now := Time.get_ticks_msec() / 1000.0
	G.shots[1] = [player.global_position + Vector3(40, 0, -30), now, bots[0]]
	G.shots[2] = [player.global_position + Vector3(-50, 0, -60), now - 1.5, bots[1]]
	await _shot(dir, "40_partie_bots", 2)
	# Contrats : une tablette au sol, puis la carte (zone, ennemis révélés, visée de la frappe).
	player.sante.hp = 100.0
	var lz0: Dictionary = G.data.lieux[0]
	var gp := Vector3(float(lz0.x) + 6.0, 0, float(lz0.z) + 6.0)
	player.spawn_at(Vector3(gp.x, ile.ground_at(gp.x, gp.z) + 0.1, gp.z), 0.0)
	for k in 5:
		var bk := bots[k]
		(bk.get_node("Bot") as Bot).set_physics_process(false)
		bk.scripted = Intentions.new()
		var ang := k * 1.3
		var bp := gp + Vector3(cos(ang), 0, sin(ang)) * (60.0 + k * 25.0)
		bk.spawn_at(Vector3(bp.x, ile.ground_at(bp.x, bp.z) + 0.1, bp.z), 0.0)
	await _wait(0.5)
	var tab: Node3D = pillage.contrats[0]
	var fwd := -player.global_basis.z
	var tp := player.global_position + Vector3(fwd.x, 0, fwd.z).normalized() * 2.2
	tab.global_position = Vector3(tp.x, ile.ground_at(tp.x, tp.z), tp.z)
	player.look_at_point(tab.global_position + Vector3(0, 0.3, 0))
	await _wait(0.4)
	await _shot(dir, "43_tablette")
	(tab as Contrats.Tablette).kind = "recon"
	partie.contrats.prendre(tab)
	partie.contrats.drone()
	partie._serie("frappe")
	await _wait(0.3)
	await _shot(dir, "44_carte_contrat")
	hud.toggle_map()
	# Tyrolienne du Phare : au pied, pendant la montée, au sommet.
	var tz: Tyrolienne = ile.tyroliennes[0]
	var back := Vector3(tz.bas.x - tz.haut.x, 0, tz.bas.z - tz.haut.z).normalized()
	var foot := tz.bas + back * 9.0 + back.cross(Vector3.UP) * 3.0
	player.spawn_at(Vector3(foot.x, ile.ground_at(foot.x, foot.z) + 0.1, foot.z), 0.0)
	player.look_at_point(tz.bord + Vector3(0, -7.0, 0))
	await _wait(0.5)
	await _shot(dir, "45_tyrolienne")
	player.spawn_at(tz.bas + Vector3(0, 0.1, 0), 0.0)
	player.start_zip(tz, true)
	await _wait(1.1)
	player.look_at_point(tz.bord + Vector3(0, 1.5, 0))
	await _shot(dir, "46_tyrolienne_montee", 2)
	await _until(func(): return player.etat == Joueur.Etat.SOL, 8.0)
	var outward := Vector3(tz.haut.x - ile.lantern.global_position.x, 0, tz.haut.z - ile.lantern.global_position.z).normalized()
	player.look_at_point(tz.haut + outward.rotated(Vector3.UP, 0.9) * 40.0 + Vector3(0, -14.0, 0))
	await _wait(0.4)
	await _shot(dir, "47_sommet_phare")
	# Caméra de la mort : un bot vous élimine, on le suit.
	var kb := bots[1]
	kb.arsenal.slots = [Armes.nouvelle("faucon", 2), {}]
	kb.arsenal.cur = 0
	kb.arsenal.view.set_weapon(kb.arsenal.current(), false)
	var kp := gp + Vector3(-14, 0, 10)
	kb.spawn_at(Vector3(kp.x, ile.ground_at(kp.x, kp.z) + 0.1, kp.z), 0.0)
	player.spawn_at(Vector3(gp.x, ile.ground_at(gp.x, gp.z) + 0.1, gp.z), 0.0)
	await _wait(0.3)
	kb.look_at_point(player.global_position + Vector3(0, 1.2, 0))
	kb.sante.hp = 64.0
	kb.sante.armor = 30.0
	player.sante.invulnerable = false
	player.sante.take(900.0, "torse", "balle", true, kb)
	await _wait(1.5)
	await _shot(dir, "48_camera_mort")
	show_lobby()
	player.scripted = null
	get_tree().quit()
