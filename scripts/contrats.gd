class_name Contrats
extends Node
## Contrats (comme dans Warzone) et séries achetées, pour le joueur.
##
## Des tablettes sont posées sur l'île ; en prendre une lance un contrat (un à la fois) :
##  - Prime : éliminer un adversaire désigné ; sa zone approximative est sur la carte.
##  - Chasse au trésor : ouvrir trois coffres signalés, l'un après l'autre.
##  - Reconnaissance : tenir une zone ; elle révèle ensuite les ennemis proches.
## Séries (station d'achat) : drone de repérage (ennemis visibles 30 s), frappe de précision
## (on choisit la cible sur la carte).

signal message(text: String)
signal changed

const TABLETTES := 8
const TYPES := {"prime": "Prime", "tresor": "Chasse au trésor", "recon": "Reconnaissance"}
const DUREE := {"prime": 120.0, "tresor": 150.0, "recon": 120.0}
const RECOMPENSE := {"prime": 1500, "tresor": 1000, "recon": 800}
const RECON_RAYON := 7.0
const RECON_TEMPS := 12.0

var partie: Partie
var pillage: Pillage
var ile: Ile
var player: Joueur
var rng := RandomNumberGenerator.new()
var actif := ""                   # type du contrat en cours ("" : aucun)
var temps := 0.0                  # temps restant
var cible: Joueur                 # prime
var zone := Vector3.ZERO          # prime : zone approximative ; recon : zone à tenir
var zone_rayon := 0.0
var progression := 0.0            # recon : 0 à 1
var coffres: Array[Coffre] = []   # trésor
var ouverts := 0
var revele_jusqu := 0.0           # drone de repérage / reconnaissance : ennemis visibles
var frappes := 0                  # frappes de précision achetées, pas encore utilisées
var _zone_t := 0.0
var _now := 0.0


func setup(p: Partie) -> void:
	partie = p
	pillage = p.pillage
	ile = p.ile
	player = p.player
	rng.seed = hash(p.rng.seed) + 7


## Tablettes posées dans les lieux, sur des emplacements de butin.
func spawn_tablettes() -> void:
	var spots := []
	for l in G.data.lieux:
		for p in ile.loot_spots.get(String(l.id), []):
			spots.append(p)
	for k in TABLETTES:
		if spots.is_empty():
			break
		var p = pillage._settle(spots.pop_at(rng.randi_range(0, spots.size() - 1)))
		if p == null:
			continue
		var t := Tablette.new()
		t.kind = (TYPES.keys())[k % TYPES.size()]
		pillage.add_child(t)
		t.global_position = p
		t.rotation.y = rng.randf() * TAU
		pillage.contrats.append(t)


func revele() -> bool:
	return _now < revele_jusqu


# ------------------------------------------------------------------------------------------------
# Contrats
# ------------------------------------------------------------------------------------------------
func prendre(t: Tablette) -> void:
	if actif != "":
		message.emit("Un contrat est déjà en cours")
		return
	if not is_instance_valid(t):
		return
	var kind := t.kind
	pillage.contrats.erase(t)
	t.queue_free()
	match kind:
		"prime": _start_prime()
		"tresor": _start_tresor()
		"recon": _start_recon()
	if actif != "":
		G.play("perk", -4.0)
		temps = DUREE[actif]
		changed.emit()


func _start_prime() -> void:
	var best: Joueur = null
	var best_d := INF
	for c in partie.combatants:
		if c == player or not partie.is_alive(c) or c.etat == Joueur.Etat.AVION:
			continue
		var d := c.global_position.distance_to(player.global_position)
		# Ni trop près ni trop loin : une vraie traque.
		var score := absf(d - 140.0)
		if d > 50.0 and score < best_d:
			best_d = score
			best = c
	if best == null:
		message.emit("Aucune cible pour une prime")
		return
	actif = "prime"
	cible = best
	zone_rayon = 40.0
	_zone_t = 0.0
	_update_zone()
	cible.sante.died.connect(_on_cible_died, CONNECT_ONE_SHOT)
	message.emit("Prime : éliminez %s (zone sur la carte)" % cible.nom)


func _update_zone() -> void:
	if is_instance_valid(cible):
		zone = cible.global_position + Vector3(rng.randf_range(-22, 22), 0, rng.randf_range(-22, 22))


func _on_cible_died() -> void:
	if actif != "prime":
		return
	if cible.sante.last_attacker == player:
		_reussi()
	else:
		_echec("La cible a été éliminée par un autre")


func _start_tresor() -> void:
	var spots := []
	for l in G.data.lieux:
		var c := Vector3(float(l.x), 0, float(l.z))
		var d := Vector2(c.x - player.global_position.x, c.z - player.global_position.z).length()
		if d < 40.0 or d > 230.0 or partie.brume.is_outside(c):
			continue
		for p in ile.loot_spots.get(String(l.id), []):
			spots.append(p)
	if spots.size() < 3:
		message.emit("Pas de trésor à portée")
		return
	actif = "tresor"
	ouverts = 0
	coffres.clear()
	for k in 3:
		var p = pillage._settle(spots.pop_at(rng.randi_range(0, spots.size() - 1)))
		if p == null:
			continue
		var c := Coffre.new()
		pillage.add_child(c)
		c.global_position = p
		c.set_meta("tresor", true)
		c.opened.connect(pillage._on_chest_opened)
		c.opened.connect(_on_tresor_opened)
		pillage.chests.append(c)
		coffres.append(c)
	message.emit("Chasse au trésor : ouvrez les 3 coffres signalés")


func _on_tresor_opened(c: Coffre) -> void:
	if actif != "tresor" or not coffres.has(c):
		return
	ouverts += 1
	changed.emit()
	if ouverts >= coffres.size():
		_reussi()
	else:
		message.emit("Trésor : %d / %d" % [ouverts, coffres.size()])


func _start_recon() -> void:
	var best := Vector3.ZERO
	var best_s := INF
	for l in G.data.lieux:
		var c := Vector3(float(l.x), 0, float(l.z))
		var d := Vector2(c.x - player.global_position.x, c.z - player.global_position.z).length()
		if partie.brume.is_outside(c) or d < 60.0:
			continue
		var s := absf(d - 130.0) + rng.randf() * 40.0
		if s < best_s:
			best_s = s
			best = c
	if best_s == INF:
		message.emit("Pas de zone à reconnaître")
		return
	actif = "recon"
	zone = Vector3(best.x, ile.ground_at(best.x, best.z), best.z)
	zone_rayon = RECON_RAYON
	progression = 0.0
	message.emit("Reconnaissance : tenez la zone signalée")


func _reussi() -> void:
	var gain: int = RECOMPENSE[actif]
	player.arsenal.argent = mini(Armes.ARGENT_MAX, player.arsenal.argent + gain)
	player.arsenal.changed.emit()
	if actif == "recon":
		revele_jusqu = _now + 20.0
	message.emit("%s réussi : +%d €%s" % [TYPES[actif], gain, " · ennemis révélés" if actif == "recon" else ""])
	G.play("buy", -2.0)
	partie.stats["contrats"] = int(partie.stats.get("contrats", 0)) + 1
	_fin()


func _echec(why: String) -> void:
	message.emit("%s échoué : %s" % [TYPES[actif], why])
	_fin()


func _fin() -> void:
	actif = ""
	cible = null
	coffres.clear()
	changed.emit()


func _physics_process(delta: float) -> void:
	_now = partie.time if partie else 0.0
	if actif == "" or partie == null or not partie.running:
		return
	temps -= delta
	if player.sante.dead:
		_echec("vous avez été éliminé")
		return
	if temps <= 0.0:
		_echec("temps écoulé")
		return
	match actif:
		"prime":
			_zone_t -= delta
			if _zone_t <= 0.0:
				_zone_t = 10.0
				_update_zone()
		"recon":
			var d := Vector2(player.global_position.x - zone.x, player.global_position.z - zone.z).length()
			if d < zone_rayon and absf(player.global_position.y - zone.y) < 4.0:
				progression = minf(1.0, progression + delta / RECON_TEMPS)
				if progression >= 1.0:
					_reussi()


## Ligne d'état pour l'interface.
func status() -> String:
	if actif == "":
		return ""
	var t := int(ceil(temps))
	var clock := "%d:%02d" % [t / 60, t % 60]
	match actif:
		"prime": return "PRIME : %s · %s" % [cible.nom if is_instance_valid(cible) else "?", clock]
		"tresor": return "TRÉSOR : %d / %d coffres · %s" % [ouverts, coffres.size(), clock]
		"recon": return "RECONNAISSANCE : %d %% · %s" % [int(progression * 100.0), clock]
	return ""


## Repères pour les cartes : [position, rayon, couleur].
func markers() -> Array:
	var out := []
	match actif:
		"prime": out.append([zone, zone_rayon, Color(1.0, 0.75, 0.2)])
		"recon": out.append([zone, zone_rayon * 2.0, Color(0.4, 0.85, 1.0)])
		"tresor":
			for c in coffres:
				if is_instance_valid(c) and c.can_open():
					out.append([c.global_position, 4.0, Color(1.0, 0.84, 0.42)])
	return out


# ------------------------------------------------------------------------------------------------
# Séries
# ------------------------------------------------------------------------------------------------
func drone() -> void:
	revele_jusqu = maxf(revele_jusqu, _now) + 30.0
	message.emit("Drone de repérage : ennemis visibles 30 s")
	G.play("power_on", -4.0)


## Frappe de précision : trois obus le long d'une ligne, après 3 s d'alerte.
func frappe(at: Vector3) -> void:
	if frappes <= 0:
		return
	frappes -= 1
	changed.emit()
	var ground := Vector3(at.x, ile.ground_at(at.x, at.z), at.z)
	message.emit("Frappe de précision en approche")
	var mark := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 9.0
	cm.bottom_radius = 9.0
	cm.height = 0.15
	mark.mesh = cm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1, 0.15, 0.1, 0.35)
	mark.material_override = m
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pillage.add_child(mark)
	mark.global_position = ground + Vector3(0, 0.2, 0)
	var dir := Vector3.FORWARD.rotated(Vector3.UP, rng.randf() * TAU)
	var tw := mark.create_tween()
	tw.tween_interval(3.0)
	for k in 3:
		var p := ground + dir * (k - 1) * 8.0
		tw.tween_callback(_obus.bind(p))
		tw.tween_interval(0.25)
	tw.tween_callback(mark.queue_free)


func _obus(p: Vector3) -> void:
	var l := Lancer.new()
	l.kind = "grenade"
	l.thrower = player
	pillage.add_child(l)
	l.global_position = Vector3(p.x, ile.ground_at(p.x, p.z) + 0.3, p.z)
	l._explode()


# ------------------------------------------------------------------------------------------------
# Tablette de contrat (objet au sol)
# ------------------------------------------------------------------------------------------------
class Tablette:
	extends Node3D
	var kind := "prime"
	var _t := 0.0
	var _screen: MeshInstance3D

	func _ready() -> void:
		add_to_group("contrat")
		var stand := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.5, 0.06, 0.36)
		stand.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.15, 0.15, 0.16)
		stand.material_override = m
		add_child(stand)
		stand.position.y = 0.05
		_screen = MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.42, 0.02, 0.28)
		_screen.mesh = sm
		var g := StandardMaterial3D.new()
		var c: Color = {"prime": Color(1.0, 0.65, 0.2), "tresor": Color(1.0, 0.84, 0.42), "recon": Color(0.4, 0.85, 1.0)}[kind]
		g.albedo_color = c
		g.emission_enabled = true
		g.emission = c
		g.emission_energy_multiplier = 1.6
		_screen.material_override = g
		add_child(_screen)
		_screen.position.y = 0.09
		for mi in [stand, _screen]:
			(mi as MeshInstance3D).visibility_range_end = 60.0
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var l := Label3D.new()
		l.text = "Contrat : %s" % Contrats.TYPES[kind]
		l.font_size = 32
		l.outline_size = 8
		l.pixel_size = 0.004
		l.modulate = c.lightened(0.3)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.visibility_range_end = 6.0
		add_child(l)
		l.position.y = 0.6

	func label() -> String:
		return "Prendre le contrat : %s" % Contrats.TYPES[kind]
