extends Node3D
## Point d'entrée : construit l'île, place le joueur au Lazaret.
## Options (après « -- ») :
##   --check              vérifications automatiques (sans écran), affiche « [check] OK »
##   --tour --shots=DIR   prend des captures de chaque lieu dans DIR puis quitte

var ile: Ile
var player: Explorateur
var hud: Hud


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	ile = Ile.new()
	ile.name = "Ile"
	add_child(ile)
	ile.build()
	print("[ile] construite en %d ms : %d bâtiments, %d rampes" % [Time.get_ticks_msec() - t0, ile.stats.batiments, ile.stats.rampes])
	player = Explorateur.new()
	player.name = "Joueur"
	add_child(player)
	hud = Hud.new()
	add_child(hud)
	hud.attach(player)
	# La physique doit avoir enregistré les formes avant de lancer des rayons.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var dep: Dictionary = G.data.depart
	player.spawn_at(Vector3(dep.x, ile.ground_at(dep.x, dep.z) + 0.1, dep.z), deg_to_rad(float(dep.cap)))
	if G.check_mode:
		_check()
	elif G.tour_mode:
		_tour()


# ------------------------------------------------------------------------------------------------
# Vérifications
# ------------------------------------------------------------------------------------------------
func _check() -> void:
	var errors: Array[String] = []
	var terrain := ile.terrain
	if terrain.n != 321:
		errors.append("relief : %d points au lieu de 321" % terrain.n)
	for l in G.data.lieux:
		var h := terrain.height_at(float(l.x), float(l.z))
		if absf(h - float(l.h)) > 0.6:
			errors.append("%s : sol à %.1f m au lieu de %.1f" % [l.nom, h, l.h])
	for s in G.data.boutiques:
		var g := ile.ground_at(float(s.x), float(s.z))
		var t := terrain.height_at(float(s.x), float(s.z))
		if g - t > 2.2:
			errors.append("station d'achat de %s posée sur un obstacle (%.1f m)" % [s.lieu, g - t])
	# Le joueur marche 3 s depuis le départ sans tomber ni rester bloqué.
	var start := player.global_position
	player.auto_input = Vector2(0, -1)
	await _wait(3.0)
	player.auto_input = Vector2.ZERO
	var moved := Vector2(player.global_position.x - start.x, player.global_position.z - start.z).length()
	if moved < 8.0 or player.global_position.y < start.y - 1.0:
		errors.append("départ : le joueur n'avance pas (%.1f m)" % moved)
	# On monte l'escalier de la capitainerie du Port jusqu'au premier étage.
	var port: Dictionary = G.data.lieux.filter(func(l): return l.id == "port")[0]
	var base := Vector3(float(port.x) + 20.0, float(port.h), float(port.z) - 8.0)
	player.spawn_at(base + Vector3(4.05, 0.1, -4.0 + 0.65), PI)
	await _wait(0.2)
	player.auto_input = Vector2(0, -1)
	await _wait(2.6)
	player.auto_input = Vector2.ZERO
	var climbed := player.global_position.y - base.y
	if climbed < 2.8:
		errors.append("escalier : le joueur n'est monté que de %.1f m" % climbed)
	# On nage : dans l'anse du Port, le joueur flotte et ne coule pas.
	player.spawn_at(Vector3(45, 1.0, 180), 0.0)
	await _wait(2.0)
	if player.global_position.y < -2.5 or not player.swimming:
		errors.append("nage : le joueur coule (%.1f m)" % player.global_position.y)
	# Le drone passe à travers tout et va vite.
	player.set_flying(true)
	player.spawn_at(Vector3(0, 40, 0), 0.0)
	player.auto_input = Vector2(0, -1)
	await _wait(1.5)
	player.auto_input = Vector2.ZERO
	if player.global_position.z > -15.0:
		errors.append("drone : trop lent (z = %.1f)" % player.global_position.z)
	player.set_flying(false)
	for l in G.data.lieux:
		var w := G.where(Vector3(float(l.x), 0, float(l.z)))
		if not w.begins_with(String(l.nom)):
			errors.append("nom de lieu : %s" % w)
	if errors.is_empty():
		print("[check] OK (montée de %.1f m, %d bâtiments)" % [climbed, ile.stats.batiments])
	else:
		for e in errors:
			print("[check] ECHEC : ", e)
	get_tree().quit(0 if errors.is_empty() else 1)


func _wait(seconds: float) -> void:
	var frames := int(seconds * Engine.physics_ticks_per_second)
	for i in frames:
		await get_tree().physics_frame


# ------------------------------------------------------------------------------------------------
# Captures
# ------------------------------------------------------------------------------------------------
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
		for i in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/%s.png" % [dir, s[0]])
		print("[tour] ", s[0])
	# Le joueur au départ, interface visible.
	cam.current = false
	player.cam.current = true
	hud.visible = true
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/20_joueur.png" % dir)
	hud.toggle_map()
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/21_carte.png" % dir)
	get_tree().quit()
