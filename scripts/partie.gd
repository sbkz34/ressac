class_name Partie
extends Node
## Une partie de Résurgence : le joueur et les bots. La Brume, les dégâts hors zone, la mort
## (sac de butin au sol), la réapparition en parachute tant qu'elle est ouverte (jusqu'au début
## de la phase 5), le largage de classe offert à chacun au début de la phase 2, le fil des
## éliminations et la fin : dernier debout (ou, sans adversaire, survivre à la Brume).

signal ended(victory: bool, stats: Dictionary)
signal message(text: String)
signal killed(killer: String, victim: String, cause: String, by_player: bool, on_player: bool)

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
var respawn_left := -1.0           # compte à rebours du joueur (négatif : vivant)
var time := 0.0
var deaths := 0
var stats := {}
var last_drop := {}                # zone visée au dernier redéploiement (tests)
var combatants: Array[Joueur] = []
var info := {}                     # combattant -> {respawn, out, kills, deaths}
var rng := RandomNumberGenerator.new()
var contrats: Contrats


func setup(p: Joueur, pl: Pillage, i: Ile) -> void:
	player = p
	pillage = pl
	ile = i
	brume = Brume.new()
	brume.name = "Brume"
	add_child(brume)
	brume.phase_started.connect(_on_phase)
	brume.closing_started.connect(func(_n): message.emit("La Brume avance !"))
	brume.closed.connect(_on_closed)
	add_combatant(player)
	contrats = Contrats.new()
	contrats.name = "Contrats"
	add_child(contrats)
	contrats.message.connect(func(t): message.emit(t))
	player.arsenal.contract_requested.connect(func(t): contrats.prendre(t))
	Boutique.series = _serie


func add_combatant(c: Joueur) -> void:
	combatants.append(c)
	info[c] = {"respawn": -1.0, "out": false, "kills": 0, "deaths": 0}
	c.sante.died.connect(_on_died.bind(c))


func start(seed_value: int) -> void:
	rng.seed = seed_value
	running = true
	respawn_open = true
	respawn_left = -1.0
	time = 0.0
	deaths = 0
	stats = {"temps": 0.0, "morts": 0, "phase": 1, "argent": 0, "eliminations": 0,
		"place": 0, "total": combatants.size()}
	brume.start(seed_value)
	contrats.setup(self)
	contrats.spawn_tablettes()
	message.emit("Fin de partie prévue : %s" % brume.final_place)


func respawn_time() -> float:
	return RESPAWN_BASE + RESPAWN_PER_PHASE * maxi(0, brume.phase - 1)


## Combattants encore dans la partie (vivants ou en attente de redéploiement).
func remaining() -> int:
	var n := 0
	for c in combatants:
		if not info[c].out:
			n += 1
	return n


func is_alive(c: Joueur) -> bool:
	return not c.sante.dead and float(info[c].respawn) < 0.0 and not info[c].out


func _physics_process(delta: float) -> void:
	if not running:
		return
	time += delta
	for c in combatants:
		var inf: Dictionary = info[c]
		if inf.out:
			c.in_gas = false
			continue
		var alive := not c.sante.dead and float(inf.respawn) < 0.0
		var flying := c.etat in [Joueur.Etat.AVION, Joueur.Etat.CHUTE_LIBRE, Joueur.Etat.PARACHUTE]
		c.in_gas = alive and c.etat != Joueur.Etat.AVION and brume.is_outside(c.global_position)
		if c.in_gas and not flying:
			var a := c.arsenal
			if a.gas_mask <= 0.0:
				var k := 0.5 if a.has_perk("dur_a_cuire") else 1.0
				c.sante.take(brume.dps() * k * delta, "torse", "brume", true)
		if float(inf.respawn) >= 0.0:
			inf.respawn = float(inf.respawn) - delta
			if float(inf.respawn) < 0.0:
				_redeploy(c)
	respawn_left = float(info[player].respawn)
	# Dernier debout (une fois les réapparitions fermées).
	if combatants.size() > 1 and not respawn_open and remaining() == 1 and is_alive(player):
		_finish(true)


func _on_phase(n: int) -> void:
	stats.phase = n
	if n == 2:
		# Largage offert à chacun au début de la phase 2, près de soi (dans la zone sûre).
		for c in combatants:
			if not is_alive(c) or c.etat == Joueur.Etat.AVION:
				continue
			var p := c.global_position + Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-12, 12))
			var crate := pillage.spawn_largage(p)
			crate.set_meta("pour", c)
		message.emit("Largage de classe offert : il arrive près de vous")
	if n == REDEPLOY_PHASE:
		respawn_open = false
		message.emit("Plus de réapparition : chaque vie compte")
	else:
		message.emit("Phase %d : la Brume se resserrera dans %d s" % [n, int(brume.time_left)])


func _on_died(c: Joueur) -> void:
	if not running or not info.has(c):
		return
	var inf: Dictionary = info[c]
	inf.deaths = int(inf.deaths) + 1
	var cause: String = c.sante.last_cause
	var by := c.sante.last_attacker as Joueur
	# La Brume ou une chute achèvent quelqu'un touché il y a peu : l'élimination revient au tireur.
	if by == c or not is_instance_valid(by) or not info.has(by) or c.sante.attacker_age > 10.0:
		by = null
	if by:
		info[by].kills = int(info[by].kills) + 1
		if by == player:
			stats.eliminations = int(stats.eliminations) + 1
		var bb := by.get_node_or_null("Bot") as Bot
		if bb:
			bb.kills += 1
	killed.emit(by.nom if by else "", c.nom, cause, by == player, c == player)
	var where := c.global_position
	pillage.spawn_bag(where, c.arsenal.drop_everything())
	c.arsenal.slots = [{}, {}]
	c.arsenal.view.set_weapon({}, false)
	c.spectate(where)
	if c == player:
		deaths += 1
		stats.morts = deaths
	if respawn_open:
		inf.respawn = respawn_time()
		if c == player:
			respawn_left = inf.respawn
			var what: String = {"brume": "la Brume", "chute": "une chute", "grenade": "une grenade"}.get(cause, "des balles")
			if by:
				what = "%s (%s)" % [by.nom, {"grenade": "grenade"}.get(cause, "balles")]
			message.emit("Tué par %s. Redéploiement dans %d s" % [what, int(respawn_left)])
		return
	# Plus de réapparition : éliminé pour de bon.
	inf.out = true
	c.in_gas = false
	if c == player:
		stats.place = remaining() + 1
		_finish(false)


## Retour en jeu : en chute libre au-dessus d'un point de la zone sûre, avec le kit de départ.
func _redeploy(c: Joueur) -> void:
	var cc := brume.next_center if brume.closing else brume.center
	var r := maxf(5.0, (brume.next_radius if brume.closing else brume.radius) * 0.7)
	var at := Vector2.ZERO
	for k in 20:
		at = cc + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, r)
		if ile.terrain.height_at(at.x, at.y) > 1.0:
			break
	c.ui_block = false
	c.arsenal.starting_kit()
	c.start_freefall(Vector3(at.x, REDEPLOY_HEIGHT, at.y))
	if c == player:
		last_drop = {"center": cc, "radius": r}
		respawn_left = -1.0
		message.emit("Redéploiement !")


func _on_closed() -> void:
	# Seul sur l'île : survivre jusqu'au bout suffit. Sinon la Brume départage les derniers.
	if running and combatants.size() == 1 and is_alive(player):
		stats.place = 1
		_finish(true)


func _finish(victory: bool) -> void:
	if not running:
		return
	running = false
	stats.temps = time
	stats.argent = player.arsenal.argent
	stats.total = combatants.size()
	if victory:
		stats.place = 1
	for c in combatants:
		c.in_gas = false
	ended.emit(victory, stats)


## Séries achetées par le joueur à une station.
func _serie(id: String) -> void:
	match id:
		"drone": contrats.drone()
		"frappe":
			contrats.frappes += 1
			contrats.changed.emit()
			message.emit("Frappe prête : choisissez la cible sur la carte")


func stop() -> void:
	Boutique.series = Callable()
	running = false
	for c in combatants:
		c.in_gas = false
	brume.phase = 0
	brume.finished = true
	brume._update_wall()
