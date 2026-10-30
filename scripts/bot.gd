class_name Bot
extends Node
## Cerveau d'un bot : il pilote son combattant (un Joueur avec `is_bot`) en remplissant les
## mêmes Intentions qu'un joueur humain — mêmes règles de mouvement, de tir et de butin.
## Il saute de l'avion vers un lieu, pille (maillage de navigation), achète un largage de
## classe quand il a l'argent, fuit la Brume et se bat : perception (champ de vision, portée,
## ligne de vue, fumigènes), temps de réaction, visée imprécise qui s'affine, rafales,
## déplacements latéraux, grenades et repli pour remettre des plaques.

const NOMS := [
	"Goéland", "Mistral", "Bourrasque", "Calanque", "Sardine", "Corsaire", "Brisant", "Écume",
	"Maestrale", "Pointu", "Rascasse", "Garrigue", "Tramontane", "Cigale", "Pastis", "Galet",
	"Mouette", "Fanal", "Récif", "Marin", "Chalut", "Baliste", "Tartane", "Embrun", "Loup",
	"Jetée", "Cormoran", "Bastide", "Muge", "Varech", "Sémaphore", "Rocher",
]
## Par difficulté (facile, normal, difficile).
const REACTION := [0.65, 0.4, 0.25]       # s avant le premier tir sur une nouvelle cible
const AIM_ERR := [1.6, 1.0, 0.6]          # écart type de la visée, en degrés (au début de l'échange : ×3)
const SIGHT := [70.0, 100.0, 130.0]       # m
const TURN := [200.0, 280.0, 380.0]       # degrés par seconde au plus
const PAUSE := [0.4, 0.28, 0.18]          # pause entre deux rafales
const FOV := 115.0
const PERCEIVE_EVERY := 0.25
const LOOT_RADIUS := 70.0

static var _claims := {}                  # objet convoité -> bot (pour ne pas tous courir au même)
static var _drops := {}                   # lieu -> nombre de bots qui y sautent
static var _count := 0

var j: Joueur
var nav: NavIle
var partie: Partie
var pillage: Pillage
var ile: Ile
var level := 1
var target_dummies := false               # tests : tirer aussi sur les mannequins
var rng := RandomNumberGenerator.new()
var state := "attente"                    # affiché (débogage) : pillage, combat, gaz, achat…
var kills := 0

var _i := Intentions.new()
var _drop_target := Vector3.ZERO
var _drop_set := false
var _prev_plane_d := INF
var _goal := Vector3.ZERO
var _goal_kind := ""
var _goal_node: Node3D
var _path := PackedVector3Array()
var _pi := 0
var _path_goal := Vector3(INF, 0, 0)
var _repath_t := 0.0
var _think_t := 0.0
var _perceive_t := 0.0
var _stuck_t := 0.0
var _stuck_pos := Vector3.ZERO
var _stuck_n := 0
var _blacklist := {}
var _target: Node3D
var _target_visible := false
var _target_seen_t := 99.0                # depuis quand on ne la voit plus
var _target_first_t := 0.0                # temps passé sur cette cible
var _last_seen := Vector3.ZERO
var _react_t := 0.0
var _aim_off := Vector2.ZERO
var _aim_off_goal := Vector2.ZERO
var _aim_off_t := 0.0
var _burst_t := 0.0
var _pause_t := 0.0
var _strafe := 1.0
var _strafe_t := 0.0
var _throw := ""                          # équipement en cours de lancer
var _throw_pitch := 0.0
var _throw_yaw := 0.0
var _throw_t := 0.0
var _grenade_cd := 0.0
var _semi := false
var _crate: Coffre                        # largage acheté ou offert, à ouvrir
var _slide_t := 0.0
var _slide_phase := 0
var _idle_t := 0.0
var _walk_t := 0.0
var _unreachable := false
var _progress_d := INF
var _progress_t := 0.0
var _walk_ok := true
var _hurt_by_t := 99.0                   # depuis quand la cible nous a touchés


func _init() -> void:
	process_physics_priority = -10        # avant la simulation du combattant


func setup(joueur: Joueur, n: NavIle, p: Partie, pl: Pillage, i: Ile, lvl: int, seed_value: int) -> void:
	j = joueur
	ile = i
	nav = n
	partie = p
	pillage = pl
	level = clampi(lvl, 0, 2)
	rng.seed = seed_value
	_perceive_t = rng.randf() * PERCEIVE_EVERY
	_think_t = rng.randf() * 0.5
	j.scripted = _i
	j.sante.damaged.connect(_on_damaged)
	j.sante.died.connect(_on_died)
	j.arsenal.loadout_requested.connect(_on_loadout)


static func random_name(rng_: RandomNumberGenerator, used: Array) -> String:
	for k in 20:
		var n: String = NOMS[rng_.randi_range(0, NOMS.size() - 1)]
		if not used.has(n):
			return n
	_count += 1
	return "Bot %d" % _count


# ------------------------------------------------------------------------------------------------
# Boucle
# ------------------------------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if j == null or j.sante.dead:
		return
	var i := _i
	i.move = Vector2.ZERO
	i.fire_held = false
	i.ads_held = false
	i.plate_held = false
	i.jump_held = false
	i.crouch_held = false
	i.sprint_held = false
	match j.etat:
		Joueur.Etat.AVION:
			_plane()
		Joueur.Etat.CHUTE_LIBRE, Joueur.Etat.PARACHUTE:
			_sky(delta)
		Joueur.Etat.DRONE:
			pass
		_:
			_drop_set = false
			_ground(delta)


## Dans l'avion : on saute au plus près du lieu choisi.
func _plane() -> void:
	state = "avion"
	if not _drop_set:
		_drop_target = _pick_drop()
		_drop_set = true
		_prev_plane_d = INF
	var av := j.avion
	if not is_instance_valid(av):
		return
	var d := Vector2(av.global_position.x - _drop_target.x, av.global_position.z - _drop_target.z).length()
	if d < 110.0 or (d > _prev_plane_d + 0.01 and av.progress > 0.08):
		_i.jump = true
	_prev_plane_d = d


## Chute libre puis parachute : on se dirige vers le point visé.
func _sky(delta: float) -> void:
	state = "chute"
	if not _drop_set:
		_drop_target = _pick_drop()
		_drop_set = true
	var to := _drop_target - j.global_position
	var flat := Vector2(to.x, to.z)
	var agl := j.height_above_ground()
	var yaw_t := atan2(-to.x, -to.z)
	var pitch_t := deg_to_rad(-12.0)
	if j.etat == Joueur.Etat.CHUTE_LIBRE:
		if flat.length() < agl * 0.45:
			pitch_t = deg_to_rad(-70.0)      # au-dessus du point : on plonge
		_i.move = Vector2(0, -1) if flat.length() > 6.0 else Vector2.ZERO
		# Loin du but : on ouvre tôt, la voile porte plus loin que la chute libre.
		if flat.length() > agl * 0.85 + 70.0 and agl > 25.0 and agl < 150.0:
			_i.jump = true
	else:
		if flat.length() > agl * 1.4 + 8.0:
			_i.move = Vector2(0, -1)
		elif flat.length() < agl * 0.6:
			_i.move = Vector2(0, 1)
	_turn_to(yaw_t, pitch_t, 300.0, delta)


# ------------------------------------------------------------------------------------------------
# Au sol
# ------------------------------------------------------------------------------------------------
func _ground(delta: float) -> void:
	var i := _i
	var a := j.arsenal
	_grenade_cd = maxf(0.0, _grenade_cd - delta)
	_hurt_by_t += delta
	_perceive_t -= delta
	if _perceive_t <= 0.0:
		_perceive_t = PERCEIVE_EVERY
		_perceive()
	if _target and not _valid_target(_target):
		_target = null
	if _target:
		_target_seen_t = 0.0 if _target_visible else _target_seen_t + delta
		_target_first_t += delta
	# Un lancer en cours prend la main sur la visée.
	if _throw != "":
		_do_throw(delta)
		return
	var in_danger := partie != null and partie.brume.is_outside(j.global_position)
	if _target and _target_visible:
		_combat(delta, in_danger)
	elif _target and _target_seen_t < 7.0 and not in_danger:
		_pursue(delta)
	else:
		_target = null
		_think_t -= delta
		if _think_t <= 0.0 or (_goal_kind == "" and _think_t < 0.5):
			_think_t = 0.8
			_think()
		_errand(delta)
	_maintenance()
	_check_stuck(delta)


## Ce qu'il faut faire quand personne n'est en vue.
func _think() -> void:
	var a := j.arsenal
	var p := j.global_position
	# 1. La Brume : rester dans le prochain cercle (avec de la marge).
	if partie and partie.brume.phase > 0:
		var b := partie.brume
		var c := b.next_center
		var r := b.next_radius
		var flat := Vector2(p.x, p.z)
		var margin := 0.8 if b.closing else 0.92
		if r < 2.0 or flat.distance_to(c) > r * margin or b.is_outside(p):
			if _goal_kind != "gaz" or _goal.distance_to(p) < 3.0:
				var dest := c + (flat - c).limit_length(r * 0.45)
				_set_goal(_ground_point(dest), "gaz")
			state = "gaz"
			return
	# 2. Un largage à ouvrir (acheté, ou offert en phase 2).
	if _crate == null:
		_crate = _my_crate()
	if is_instance_valid(_crate) and _crate.can_open() and _crate.global_position.distance_to(p) < 160.0:
		_set_goal(_crate.global_position, "largage", _crate)
		state = "largage"
		return
	elif is_instance_valid(_crate) and not _crate.can_open() and _crate.is_open:
		_crate = null
	# 3. Assez d'argent pour une classe : à la station d'achat la plus proche.
	if a.perks.is_empty() and a.argent >= int(Boutique.article("largage").prix) and pillage:
		var st := _nearest(pillage.shops, p, 260.0)
		if st:
			_set_goal(st.global_position, "achat", st)
			state = "achat"
			return
	# 4. Le butin intéressant le plus proche.
	var best: Node3D = null
	var best_score := 0.0
	if pillage:
		var r2 := LOOT_RADIUS * LOOT_RADIUS
		for b in pillage.items:
			var d2 := b.global_position.distance_squared_to(p)
			if d2 > r2:
				continue
			var v := _item_value(b)
			if v <= 0.0:
				continue
			var d := sqrt(d2)
			if _blacklist.has(b.get_instance_id()) or _claimed_by_other(b):
				continue
			var s := v / (1.0 + d / 15.0)
			if s > best_score:
				best_score = s
				best = b
		for c in pillage.chests:
			if not is_instance_valid(c) or not c.can_open() or c.ravitaillement or c.largage:
				continue
			var d := c.global_position.distance_to(p)
			if d > LOOT_RADIUS or _blacklist.has(c.get_instance_id()) or _claimed_by_other(c):
				continue
			var s := 3.5 / (1.0 + d / 15.0)
			if s > best_score:
				best_score = s
				best = c
	if best and (partie == null or not partie.brume.is_outside(best.global_position)):
		if best != _goal_node:
			_claim(best)
		_set_goal(best.global_position, "pillage", best)
		state = "pillage"
		return
	# 5. Errer : un autre lieu (dans la zone sûre).
	if _goal_kind != "errance" or _goal.distance_to(p) < 4.0:
		_set_goal(_pick_wander(), "errance")
	state = "errance"


## Va vers le but et agit en arrivant (ramasser, ouvrir, acheter).
func _errand(delta: float) -> void:
	var a := j.arsenal
	if _goal_kind in ["pillage", "largage", "achat"] and not is_instance_valid(_goal_node):
		_goal_kind = ""
		return
	if _goal_kind == "pillage" and _goal_node is Butin and not pillage.items.has(_goal_node):
		_goal_kind = ""
		return
	var reach := 1.4 if _goal_kind in ["pillage", "largage", "achat"] else 2.5
	var arrived := _follow(_goal, delta, reach, _goal_kind == "errance" or _goal_kind == "gaz")
	if _unreachable and not arrived:
		if _goal_node:
			_blacklist[_goal_node.get_instance_id()] = true
		_goal_kind = ""
		_unreachable = false
		return
	if not arrived:
		return
	var p := j.global_position
	match _goal_kind:
		"pillage", "largage":
			var n := _goal_node
			if n is Butin and (n as Butin).type != Butin.Type.ARME:
				# Munitions, plaques, argent : ramassés en passant dessus.
				_move_towards(n.global_position, 0.5)
				_idle_t += delta
				if _idle_t > 1.5:
					_blacklist[n.get_instance_id()] = true
					_goal_kind = ""
				return
			_face(n.global_position + Vector3(0, 0.3, 0), delta)
			if n is Butin and not a.other().is_empty() and not a.current().is_empty() \
					and _weapon_value(a.current()) > _weapon_value(a.other()):
				_i.swap = true      # on lâchera la moins bonne des deux
				return
			_i.interact = true
			_idle_t += delta
			if _idle_t > 1.2:
				_blacklist[n.get_instance_id()] = true
				_goal_kind = ""
		"achat":
			_buy_at(_goal_node)
			_goal_kind = ""
		_:
			_goal_kind = ""


func _buy_at(station: Node3D) -> void:
	var a := j.arsenal
	if Boutique.buy(a, "largage", station, pillage):
		_crate = pillage.chests[pillage.chests.size() - 1]
	if a.plates < 3 and a.argent >= 900:
		Boutique.buy(a, "gilet", station, pillage)
	if a.letal_n == 0 and a.argent >= 1500:
		Boutique.buy(a, "grenade", station, pillage)


func _on_loadout(crate: Coffre) -> void:
	if not is_instance_valid(crate) or not crate.can_open():
		return
	crate.open_chest()
	var d: Dictionary = Loadouts.DEFAUTS[rng.randi_range(0, Loadouts.DEFAUTS.size() - 1)]
	j.arsenal.apply_loadout(d)
	if _crate == crate:
		_crate = null
	_goal_kind = ""


## Plaques, rechargement, arme vide.
func _maintenance() -> void:
	var a := j.arsenal
	var s := j.sante
	var calm := _target == null or _target_seen_t > 1.0
	if calm and a.plates > 0 and s.armor < s.armor_max - 1.0 and a.can_use_weapon():
		_i.plate_held = true
	var w := a.current()
	if w.is_empty():
		if not a.other().is_empty():
			_i.swap = true
		return
	var info := Armes.de(w)
	var size := Armes.chargeur_de(w)
	var reserve := int(a.reserve[info.munition])
	if int(w.chargeur) == 0 and reserve == 0 and not a.other().is_empty():
		var o := a.other()
		if int(o.chargeur) > 0 or int(a.reserve[Armes.info(o.id).munition]) > 0:
			_i.swap = true
	elif calm and not a.reloading and int(w.chargeur) < size * 0.6 and reserve > 0 and not _i.plate_held:
		_i.reload = true


# ------------------------------------------------------------------------------------------------
# Perception et combat
# ------------------------------------------------------------------------------------------------
func _eye() -> Vector3:
	return j.cam.global_position


static func aim_point(t: Node3D) -> Vector3:
	if t is Cible:
		return (t as Cible).aim_point()
	if t is Joueur:
		var jj := t as Joueur
		return jj.global_position + Vector3(0, Joueur.HEIGHTS[jj.posture] * 0.68, 0)
	return t.global_position + Vector3(0, 1.1, 0)


func _valid_target(t: Node3D) -> bool:
	if not is_instance_valid(t) or t == j:
		return false
	var s: Sante = t.get("sante")
	if s == null or s.dead:
		return false
	if t is Joueur:
		var e := (t as Joueur).etat
		return e != Joueur.Etat.AVION and e != Joueur.Etat.DRONE
	return t is Cible and target_dummies


func _perceive() -> void:
	var sight: float = SIGHT[level]
	var eye := _eye()
	var fwd := -j.cam.global_basis.z
	var best: Node3D = null
	var best_d := INF
	for c in j.get_tree().get_nodes_in_group("combattant"):
		var t := c as Node3D
		if not _valid_target(t):
			continue
		var at := aim_point(t)
		var d := eye.distance_to(at)
		if d > sight:
			continue
		var known := t == _target and _target_seen_t < 2.0
		# Mal armé (pistolet de départ) : on pille plutôt que d'aller chercher la bagarre loin.
		if d > _engage_range() and not (t == _target and _hurt_by_t < 5.0):
			continue
		var ang := rad_to_deg(fwd.angle_to(at - eye))
		if ang > FOV * 0.5 and not known and d > 6.0:
			continue
		if not _can_see(eye, at):
			continue
		# Une cible déjà engagée garde un petit avantage (on ne saute pas d'une cible à l'autre).
		var score := d * (0.7 if t == _target else 1.0)
		if score < best_d:
			best_d = score
			best = t
	if best:
		if best != _target:
			_engage(best)
		_target_visible = true
		_last_seen = best.global_position
	else:
		_target_visible = false


func _engage_range() -> float:
	var w := j.arsenal.current()
	var sight: float = SIGHT[level]
	if weapon_score(w) >= 2.5 or weapon_score(j.arsenal.other()) >= 2.5:
		return sight
	return minf(sight, 12.0)


func _engage(t: Node3D) -> void:
	_target = t
	_target_first_t = 0.0
	_target_seen_t = 0.0
	_react_t = float(REACTION[level]) * rng.randf_range(0.8, 1.3)
	_aim_off = Vector2(rng.randf_range(-1, 1), rng.randf_range(-0.6, 0.6)) * float(AIM_ERR[level]) * 3.0
	_aim_off_goal = _aim_off
	_burst_t = 0.0
	_pause_t = 0.0


func _can_see(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, G.L_WORLD, [j.get_rid()])
	if not j.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
		return false
	for f in j.get_tree().get_nodes_in_group("fumee"):
		var c: Vector3 = (f as Node3D).global_position + Vector3(0, 1.8, 0)
		var r: float = float(f.get_meta("rayon", 6.0)) * 0.75
		var seg := to - from
		var k := clampf((c - from).dot(seg) / maxf(seg.length_squared(), 0.001), 0.0, 1.0)
		if (from + seg * k).distance_to(c) < r:
			return false
	return true


func _on_damaged(_amount: float, _zone: String, _on_armor: bool, _broken: bool, _killed: bool) -> void:
	var by := j.sante.last_attacker as Node3D
	if by == null or not is_instance_valid(by) or by == j:
		return
	if _target == null or not _target_visible:
		# Touché par quelqu'un qu'on ne voyait pas : on se retourne vers lui.
		if _target != by:
			_engage(by)
		_last_seen = by.global_position
		_target_seen_t = 0.0
		_react_t = maxf(_react_t, float(REACTION[level]) * 1.3)
	if by == _target:
		_hurt_by_t = 0.0


func _on_died() -> void:
	_target = null
	_throw = ""
	_goal_kind = ""
	_path = PackedVector3Array()
	_crate = null
	_drop_set = false
	state = "mort"


func _combat(delta: float, in_danger: bool) -> void:
	state = "combat"
	var a := j.arsenal
	var w := a.current()
	var at := aim_point(_target)
	var eye := _eye()
	var d := eye.distance_to(at)
	var ideal := _ideal_range(w)
	# Erreur de visée : grande au début, elle se resserre ; plus grande si l'un ou l'autre bouge.
	var err := float(AIM_ERR[level]) * (1.0 + 2.0 * exp(-_target_first_t / 1.4))
	if _target is Joueur:
		err *= 1.0 + clampf((_target as Joueur).hspeed / 7.0, 0.0, 1.0) * 0.6
	err *= 1.0 + clampf(j.hspeed / 7.0, 0.0, 1.0) * 0.3
	err *= lerpf(1.0, 0.75, a.ads)
	_aim_off_t -= delta
	if _aim_off_t <= 0.0:
		_aim_off_t = rng.randf_range(0.25, 0.45)
		_aim_off_goal = Vector2(rng.randfn(0.0, err), rng.randfn(0.0, err * 0.6))
	_aim_off = _aim_off.lerp(_aim_off_goal, minf(1.0, delta * 5.0))
	var to := at - eye
	var yaw_t := atan2(-to.x, -to.z) + deg_to_rad(_aim_off.x)
	var pitch_t := atan2(to.y, Vector2(to.x, to.z).length()) + deg_to_rad(_aim_off.y)
	var miss := _turn_to(yaw_t, pitch_t, float(TURN[level]), delta)
	# Visée épaulée au-delà de 12 m (et toujours avec un fusil de précision).
	var want_ads: bool = not w.is_empty() and (d > 12.0 or w.id == "aiguille")
	_i.ads_held = want_ads
	# Tir : après le temps de réaction, quand la visée est posée, par rafales.
	_react_t -= delta
	var aligned := miss < maxf(1.2, rad_to_deg(atan(0.45 / maxf(d, 0.1))))
	var scoped: bool = w.is_empty() or w.id != "aiguille" or a.ads > 0.9
	if _react_t <= 0.0 and aligned and scoped and not w.is_empty() and d < float(Armes.de(w).portee[1]) * 2.2 + 20.0:
		if _pause_t > 0.0:
			_pause_t -= delta
		else:
			_burst_t += delta
			if Armes.info(w.id).auto:
				_i.fire_held = true
			else:
				_semi = not _semi
				_i.fire_held = _semi
			var burst_len := 0.6 if d < 20.0 else 0.3
			if _burst_t > burst_len * rng.randf_range(0.7, 1.3):
				_burst_t = 0.0
				_pause_t = float(PAUSE[level]) * rng.randf_range(0.6, 1.4) * (1.0 if d > 20.0 else 0.5)
	# Déplacement : se décaler, se rapprocher ou reculer selon la portée de l'arme.
	_strafe_t -= delta
	if _strafe_t <= 0.0:
		_strafe_t = rng.randf_range(0.7, 1.6)
		_strafe = -_strafe if rng.randf() < 0.7 else _strafe
	var flat_to := Vector3(to.x, 0, to.z).normalized()
	var side := flat_to.cross(Vector3.UP) * _strafe
	var dir := side
	var hurt := j.sante.hp + j.sante.armor < 70.0
	if in_danger and partie:
		var c := partie.brume.center
		dir = (Vector3(c.x, 0, c.y) - Vector3(j.global_position.x, 0, j.global_position.z)).normalized() + side * 0.3
	elif hurt and j.arsenal.plates > 0 and d > 8.0:
		dir = -flat_to + side * 0.5            # repli pour remettre des plaques
		if a.tactique_n > 0 and d > 12.0 and _grenade_cd <= 0.0:
			_start_throw("fumigene", flat_to, -25.0)
	elif d > ideal * 1.4:
		dir = flat_to + side * 0.5
	elif d < ideal * 0.5:
		dir = -flat_to + side * 0.6
	# Ne pas tomber d'un quai en se décalant (vérifié quelques fois par seconde : c'est coûteux).
	_walk_t -= delta
	if _walk_t <= 0.0:
		_walk_t = 0.3
		_walk_ok = _walkable(j.global_position + dir.normalized() * 1.6)
	if not _walk_ok:
		_walk_ok = true
		_strafe = -_strafe
		dir = -side if dir == side else Vector3.ZERO
	_move_dir(dir)
	# Grenade sur une cible à mi-distance, de temps en temps.
	if a.letal_n > 0 and _grenade_cd <= 0.0 and d > 9.0 and d < 26.0 and rng.randf() < delta * 0.25:
		_grenade_at(_target.global_position)


## La cible a disparu (derrière un mur) : on va voir où elle était, grenade à l'appui.
func _pursue(delta: float) -> void:
	state = "poursuite"
	var a := j.arsenal
	var d := j.global_position.distance_to(_last_seen)
	if a.letal_n > 0 and _grenade_cd <= 0.0 and _target_seen_t > 0.6 and d > 8.0 and d < 26.0 and rng.randf() < 0.5:
		_grenade_at(_last_seen)
		_grenade_cd = 6.0
		return
	if _follow(_last_seen, delta, 2.0, false):
		_target = null
		return
	_face(_last_seen + Vector3(0, 1.3, 0), delta, true)
	_i.ads_held = d < 30.0 and d > 8.0


func _grenade_at(p: Vector3) -> void:
	var to := p - j.global_position
	var flat := Vector2(to.x, to.z).length()
	# Angle de lancer : vitesse 17 m/s plus 3,5 m/s vers le haut, gravité 18.
	var best := 0.0
	var best_err := INF
	for k in range(-10, 50, 3):
		var pr := deg_to_rad(float(k))
		var vx := 17.0 * cos(pr)
		var vy := 17.0 * sin(pr) + 3.5
		var t := flat / maxf(vx, 0.1)
		var y := 1.4 + vy * t - 9.0 * t * t
		var e := absf(y - to.y)
		if e < best_err:
			best_err = e
			best = float(k)
	_start_throw("grenade", Vector3(to.x, 0, to.z).normalized(), best)
	_grenade_cd = 8.0


func _start_throw(kind: String, flat_dir: Vector3, pitch_deg: float) -> void:
	_throw = kind
	_throw_yaw = atan2(-flat_dir.x, -flat_dir.z)
	_throw_pitch = deg_to_rad(pitch_deg)
	_throw_t = 0.0
	_grenade_cd = maxf(_grenade_cd, 6.0)


func _do_throw(delta: float) -> void:
	state = "lancer"
	_throw_t += delta
	var miss := _turn_to(_throw_yaw, _throw_pitch, 400.0, delta)
	if miss < 2.5 or _throw_t > 0.8:
		if _throw == "grenade":
			_i.lethal = true
		else:
			_i.tactical = true
		_throw = ""


# ------------------------------------------------------------------------------------------------
# Déplacement
# ------------------------------------------------------------------------------------------------
func _set_goal(p: Vector3, kind: String, node: Node3D = null) -> void:
	if kind != _goal_kind or node != _goal_node or p.distance_to(_goal) > 3.0:
		_idle_t = 0.0
		_stuck_n = 0
		_unreachable = false
		_progress_d = INF
		_progress_t = 0.0
		_path = PackedVector3Array()
	_goal = p
	_goal_kind = kind
	_goal_node = node


## Suit le chemin vers `to` ; renvoie vrai une fois arrivé.
func _follow(to: Vector3, delta: float, reach: float, sprint: bool) -> bool:
	var p := j.global_position
	var flat := Vector2(to.x - p.x, to.z - p.z).length()
	if flat < reach and absf(to.y - p.y) < 2.0:
		return true
	_repath_t -= delta
	if _path.is_empty() or _repath_t <= 0.0 or _path_goal.distance_to(to) > 2.0:
		_repath_t = rng.randf_range(2.0, 3.0)
		_path_goal = to
		_path = nav.path(p, to) if nav else PackedVector3Array()
		_pi = 1
		# Le chemin s'arrête loin du but : il est hors du maillage (sur un toit, une étagère…).
		_unreachable = _path.size() > 0 and (Vector2(_path[-1].x - to.x, _path[-1].z - to.z).length() > reach + 0.8 \
				or absf(_path[-1].y - to.y) > 1.8)
	# Pas de progrès vers le but pendant longtemps : on abandonne.
	var d3 := p.distance_to(to)
	if d3 < _progress_d - 1.0:
		_progress_d = d3
		_progress_t = 0.0
	else:
		_progress_t += delta
		if _progress_t > 5.0:
			_unreachable = true
	var next := to
	if _path.size() >= 2:
		while _pi < _path.size() - 1 and Vector2(_path[_pi].x - p.x, _path[_pi].z - p.z).length() < 0.8:
			_pi += 1
		next = _path[mini(_pi, _path.size() - 1)]
		# Au bout du chemin (le maillage s'arrête à 0,35 m des murs) : tout droit vers le but.
		if _pi >= _path.size() - 1 and Vector2(next.x - p.x, next.z - p.z).length() < 0.8:
			next = to
	var dir := next - p
	var dflat := Vector2(dir.x, dir.z).length()
	if dir.y > 0.6 and dflat < 1.6:
		_i.jump = true       # un rebord : on l'escalade
	_move_dir(Vector3(dir.x, 0, dir.z))
	_face(Vector3(next.x, p.y + Joueur.EYES[j.posture], next.z) + Vector3(dir.x, 0, dir.z).normalized() * 4.0, delta, false)
	if sprint or flat > 12.0:
		if not j.sprinting and j.etat == Joueur.Etat.SOL and j.posture == Joueur.Posture.DEBOUT:
			_i.sprint = true
		_slide_cancel(delta, dflat)
	return false


## De temps en temps en courant en ligne droite : glissade puis annulation (comme un joueur).
func _slide_cancel(delta: float, ahead: float) -> void:
	if level == 0:
		return
	_slide_t -= delta
	if _slide_phase == 0 and _slide_t <= 0.0 and j.sprinting and j.hspeed > Joueur.SLIDE_MIN_SPEED and ahead > 7.0:
		_i.crouch = true
		_slide_phase = 1
		_slide_t = 0.3
	elif _slide_phase == 1 and _slide_t <= 0.0:
		if j.etat == Joueur.Etat.GLISSADE:
			_i.crouch = true
		_slide_phase = 0
		_slide_t = rng.randf_range(2.5, 6.0)


func _move_dir(world: Vector3) -> void:
	if world.length() < 0.01:
		_i.move = Vector2.ZERO
		return
	var local := j.global_basis.inverse() * world.normalized()
	_i.move = Vector2(local.x, local.z).limit_length(1.0)


func _move_towards(p: Vector3, scale := 1.0) -> void:
	var d := p - j.global_position
	_move_dir(Vector3(d.x, 0, d.z))
	_i.move *= scale


func _face(point: Vector3, delta: float, keep_pitch := false) -> void:
	var to := point - _eye()
	var pitch_t := 0.0 if not keep_pitch else atan2(to.y, Vector2(to.x, to.z).length())
	if not keep_pitch:
		pitch_t = clampf(atan2(to.y, maxf(Vector2(to.x, to.z).length(), 0.5)), -0.9, 0.5)
	_turn_to(atan2(-to.x, -to.z), pitch_t, 360.0, delta)


## Tourne la vue vers un lacet / tangage (radians), vitesse limitée ; renvoie l'écart en degrés.
func _turn_to(yaw_t: float, pitch_t: float, rate: float, delta: float) -> float:
	var dy := rad_to_deg(wrapf(yaw_t - j._yaw, -PI, PI))
	var dp := rad_to_deg(pitch_t - j._pitch)
	var k := minf(1.0, 14.0 * delta)
	var lim := rate * delta
	_i.look = Vector2(clampf(dy * k, -lim, lim), clampf(dp * k, -lim, lim))
	return Vector2(dy, dp).length()


func _walkable(p: Vector3) -> bool:
	if nav == null:
		return true
	var c := nav.closest(p)
	return Vector2(c.x - p.x, c.z - p.z).length() < 0.6 and absf(c.y - p.y) < 1.5


func _check_stuck(delta: float) -> void:
	if _i.move.length() < 0.3 or j.etat != Joueur.Etat.SOL:
		_stuck_t = 0.0
		_stuck_pos = j.global_position
		return
	_stuck_t += delta
	if _stuck_t < 1.2:
		return
	if j.global_position.distance_to(_stuck_pos) < 0.7:
		_stuck_n += 1
		_i.jump = true
		_path = PackedVector3Array()
		if _stuck_n >= 3 and _goal_node:
			_blacklist[_goal_node.get_instance_id()] = true
			_goal_kind = ""
		elif _stuck_n >= 3:
			_goal_kind = ""
		if _stuck_n >= 5:
			# Coincé pour de bon (rare) : on se replace sur le maillage le plus proche.
			var c := nav.closest(j.global_position) if nav else j.global_position
			j.global_position = c + Vector3(0, 0.2, 0)
			_stuck_n = 0
	else:
		_stuck_n = maxi(0, _stuck_n - 1)
	_stuck_t = 0.0
	_stuck_pos = j.global_position


# ------------------------------------------------------------------------------------------------
# Choix
# ------------------------------------------------------------------------------------------------
## Point du maillage au niveau du sol (pas sur un toit) à cet endroit.
func _ground_point(xz: Vector2) -> Vector3:
	var h := ile.ground_at(xz.x, xz.y) if ile else 0.0
	var p := Vector3(xz.x, maxf(h, 0.0) + 0.5, xz.y)
	return nav.closest(p) if nav else p


func _safe(xz: Vector2, margin := 1.0) -> bool:
	if partie == null or partie.brume.phase == 0:
		return true
	var b := partie.brume
	return xz.distance_to(b.next_center) < b.next_radius * margin


## Lieu d'atterrissage : un lieu au hasard (pondéré par le butin), dans la zone sûre.
func _pick_drop() -> Vector3:
	var lieux: Array = G.data.get("lieux", [])
	var pool := []
	var weights := []
	for l in lieux:
		var c := Vector2(float(l.x), float(l.z))
		if not _safe(c, 0.9):
			continue
		pool.append(l)
		# Les lieux riches attirent, mais on évite d'y sauter tous ensemble.
		weights.append((1.0 + float(l.get("butin", 1))) / (1.0 + 1.5 * int(_drops.get(l.id, 0))))
	if pool.is_empty():
		var b := partie.brume if partie else null
		var c2 := b.next_center if b else Vector2.ZERO
		return _ground_point(c2)
	var total := 0.0
	for w in weights:
		total += float(w)
	var r := rng.randf() * total
	var pick: Dictionary = pool[0]
	for k in pool.size():
		r -= float(weights[k])
		if r <= 0.0:
			pick = pool[k]
			break
	_drops[pick.id] = int(_drops.get(pick.id, 0)) + 1
	var off := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, float(pick.rayon) * 0.6)
	return _ground_point(Vector2(float(pick.x), float(pick.z)) + off)


func _pick_wander() -> Vector3:
	var lieux: Array = G.data.get("lieux", [])
	var p := j.global_position
	for k in 8:
		var l: Dictionary = lieux[rng.randi_range(0, lieux.size() - 1)]
		var c := Vector2(float(l.x), float(l.z)) + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, float(l.rayon) * 0.6)
		if _safe(c, 0.85) and c.distance_to(Vector2(p.x, p.z)) > 25.0:
			return _ground_point(c)
	if partie and partie.brume.phase > 0:
		var b := partie.brume
		return _ground_point(b.next_center + Vector2.from_angle(rng.randf() * TAU) * b.next_radius * rng.randf_range(0.0, 0.5))
	return _ground_point(Vector2(p.x, p.z) + Vector2.from_angle(rng.randf() * TAU) * 40.0)


func _nearest(nodes: Array, p: Vector3, max_d: float) -> Node3D:
	var best: Node3D = null
	var bd := max_d
	for n in nodes:
		var nn := n as Node3D
		if nn == null or not is_instance_valid(nn):
			continue
		var d := nn.global_position.distance_to(p)
		if d < bd:
			bd = d
			best = nn
	return best


func _my_crate() -> Coffre:
	if pillage == null:
		return null
	for c in pillage.chests:
		if is_instance_valid(c) and c.largage and c.can_open() and c.get_meta("pour", null) == j:
			return c
	return null


func _claim(n: Node3D) -> void:
	_claims[n.get_instance_id()] = get_instance_id()


func _claimed_by_other(n: Node3D) -> bool:
	var who: int = _claims.get(n.get_instance_id(), 0)
	if who == 0 or who == get_instance_id():
		return false
	var o := instance_from_id(who) as Bot
	return o != null and o._goal_node == n and not o.j.sante.dead


static func reset_claims() -> void:
	_claims.clear()
	_drops.clear()


# ------------------------------------------------------------------------------------------------
# Valeur des armes et du butin
# ------------------------------------------------------------------------------------------------
const VALEUR := {"p9": 1.0, "taureau": 2.0, "uzi": 3.2, "ouragan": 3.5, "vipere": 3.6, "grele": 3.0,
	"faucon": 4.6, "titan": 4.2, "k14": 4.0, "aiguille": 3.4}


static func weapon_score(w: Dictionary) -> float:
	if w.is_empty():
		return 0.0
	return float(VALEUR.get(w.id, 1.0)) + 0.7 * int(w.get("rarete", 0))


func _weapon_value(w: Dictionary) -> float:
	return weapon_score(w)


func _ideal_range(w: Dictionary) -> float:
	if w.is_empty():
		return 10.0
	var r: Array = Armes.de(w).portee
	return clampf(float(r[0]) * 0.8, 5.0, 60.0)


func _item_value(b: Butin) -> float:
	var a := j.arsenal
	match b.type:
		Butin.Type.ARME:
			var worst := minf(_weapon_value(a.slots[0]), _weapon_value(a.slots[1]))
			var gain := _weapon_value(b.arme) - worst
			return 3.0 + gain if gain > 0.8 else 0.0
		Butin.Type.MUNITIONS:
			for w in a.slots:
				if not w.is_empty() and Armes.info(w.id).munition == b.munition \
						and int(a.reserve[b.munition]) < int(Armes.MUNITIONS[b.munition].max) * 0.6:
					return 2.0
			return 0.0
		Butin.Type.PLAQUE:
			return 2.2 if a.plates < a.plates_max() else 0.0
		Butin.Type.ARGENT:
			return 1.6 if a.argent < 6000 else 0.4
	return 0.0
