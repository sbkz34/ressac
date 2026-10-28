class_name Partie
extends Node
## Une partie de Résurgence en solo : la Brume, les dégâts hors zone, la mort (sac de butin au
## sol), la réapparition en parachute tant qu'elle est ouverte (jusqu'au début de la phase 5),
## le largage de classe offert au début de la phase 2, et la fin de partie.

signal ended(victory: bool, stats: Dictionary)
signal message(text: String)

const REDEPLOY_PHASE := 5          # à partir de cette phase, plus de réapparition
const RESPAWN_BASE := 10.0
const RESPAWN_PER_PHASE := 5.0
const REDEPLOY_HEIGHT := 160.0

var player: Joueur
var pillage: Pillage
var ile: Ile
var brume: Brume
var running := false
var respawn_open := true
var respawn_left := -1.0           # compte à rebours (négatif : vivant)
var time := 0.0
var deaths := 0
var stats := {}
var last_drop := {}                # zone visée au dernier redéploiement (tests)
var rng := RandomNumberGenerator.new()


func setup(p: Joueur, pl: Pillage, i: Ile) -> void:
	player = p
	pillage = pl
	ile = i
	brume = Brume.new()
	brume.name = "Brume"
	add_child(brume)
	brume.phase_started.connect(_on_phase)
	brume.closing_started.connect(func(n): message.emit("La Brume avance !"))
	brume.closed.connect(_on_closed)
	player.sante.died.connect(_on_died)


func start(seed_value: int) -> void:
	rng.seed = seed_value
	running = true
	respawn_open = true
	respawn_left = -1.0
	time = 0.0
	deaths = 0
	stats = {"temps": 0.0, "morts": 0, "phase": 1, "argent": 0}
	brume.start(seed_value)
	message.emit("Fin de partie prévue : %s" % brume.final_place)


func respawn_time() -> float:
	return RESPAWN_BASE + RESPAWN_PER_PHASE * maxi(0, brume.phase - 1)


func _physics_process(delta: float) -> void:
	if not running:
		return
	time += delta
	var alive := not player.sante.dead and respawn_left < 0.0
	var flying := player.etat in [Joueur.Etat.AVION, Joueur.Etat.CHUTE_LIBRE, Joueur.Etat.PARACHUTE]
	player.in_gas = alive and brume.is_outside(player.global_position)
	if player.in_gas and not flying:
		var a := player.arsenal
		if a.gas_mask <= 0.0:
			var k := 0.5 if a.has_perk("dur_a_cuire") else 1.0
			player.sante.take(brume.dps() * k * delta, "torse", "brume", true)
	if respawn_left >= 0.0:
		respawn_left -= delta
		if respawn_left < 0.0:
			_redeploy()


func _on_phase(n: int) -> void:
	stats.phase = n
	if n == 2:
		# Largage offert à tous au début de la phase 2, près de soi (dans la zone sûre).
		if not player.sante.dead and respawn_left < 0.0:
			var p := player.global_position + Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-12, 12))
			pillage.spawn_largage(p)
			message.emit("Largage de classe offert : il arrive près de vous")
	if n == REDEPLOY_PHASE:
		respawn_open = false
		message.emit("Plus de réapparition : chaque vie compte")
	else:
		message.emit("Phase %d : la Brume se resserrera dans %d s" % [n, int(brume.time_left)])


func _on_died() -> void:
	if not running:
		return
	deaths += 1
	stats.morts = deaths
	var where := player.global_position
	pillage.spawn_bag(where, player.arsenal.drop_everything())
	player.arsenal.slots = [{}, {}]
	player.arsenal.view.set_weapon({}, false)
	var cause: String = {"brume": "la Brume", "chute": "une chute", "grenade": "une grenade"}.get(player.sante.last_cause, "des balles")
	if respawn_open:
		respawn_left = respawn_time()
		player.spectate(where)
		message.emit("Tué par %s. Redéploiement dans %d s" % [cause, int(respawn_left)])
	else:
		player.spectate(where)
		_finish(false)


## Retour en jeu : en chute libre au-dessus d'un point de la zone sûre, avec le kit de départ.
func _redeploy() -> void:
	var c := brume.next_center if brume.closing else brume.center
	var r := maxf(5.0, (brume.next_radius if brume.closing else brume.radius) * 0.7)
	last_drop = {"center": c, "radius": r}
	var at := Vector2.ZERO
	for k in 20:
		at = c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, r)
		if ile.terrain.height_at(at.x, at.y) > 1.0:
			break
	player.ui_block = false
	player.arsenal.starting_kit()
	player.start_freefall(Vector3(at.x, REDEPLOY_HEIGHT, at.y))
	message.emit("Redéploiement !")


func _on_closed() -> void:
	if running and not player.sante.dead and respawn_left < 0.0:
		_finish(true)


func _finish(victory: bool) -> void:
	if not running:
		return
	running = false
	stats.temps = time
	stats.argent = player.arsenal.argent
	player.in_gas = false
	ended.emit(victory, stats)


func stop() -> void:
	running = false
	player.in_gas = false
	brume.phase = 0
	brume.finished = true
	brume._update_wall()
