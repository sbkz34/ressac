class_name Arsenal
extends Node
## Armes, munitions, plaques et argent du joueur, et tout le combat : tir (balles instantanées,
## dispersion, recul, chute des dégâts avec la distance), visée, rechargement, changement d'arme,
## plaques d'armure, ramassage du butin et coffres, assistance à la visée (manette, tactile).
## Lit les mêmes Intentions que le mouvement : un bot pourra tirer par le même chemin.

signal hit(kind: String, amount: float)   # "corps", "tete", "armure", "brise", "elimination"
signal changed
signal notice(text: String)
signal shop_requested(station: Node3D)
signal loadout_requested(crate: Coffre)
signal contract_requested(tablette: Node3D)

const REACH := 2.0
const SPRINT_OUT := 0.14       # délai avant de tirer en sortant du sprint
const PLATE_TIME := 1.1
const SWAP_TIME := 0.45
const RANGE := 450.0
const ASSIST_SLOW := 0.55      # ralentissement de la visée près d'une cible
const ASSIST_CONE := 5.0       # degrés
const SNAP_CONE := 8.0

var joueur: Joueur
var view: WeaponView
var sante: Sante
var slots: Array = [{}, {}]
var cur := 0
var reserve := {}
var plates := 0
var argent := 0
var perks: Array = []          # atouts de la classe récupérée
var letal := ""                # équipement létal (grenade) et son nombre
var letal_n := 0
var tactique := ""             # équipement tactique (fumigène)
var tactique_n := 0
var gas_mask := 0.0            # secondes de protection du masque à gaz restantes
var ads := 0.0
var spread := 0.0              # dispersion actuelle en degrés (réticule)
var reloading := false
var reload_t := 0.0
var plate_t := 0.0
var target_item: Node3D        # butin (arme) ou coffre à portée de main
var assist_target: Node3D
var shots_fired := 0
var pillage: Pillage
var is_bot := false
var _scan_t := 0.0

var _fire_cd := 0.0
var _swap_t := 0.0
var _sprint_out := 0.0
var _semi_ready := true
var _bloom := 0.0
var _exclude: Array[RID] = []
var _ads_pressed_t := 99.0
var _was_ads := false
var _dry := false
var _plate_wait := false


func setup(j: Joueur, hitboxes: Array[Area3D], bot := false) -> void:
	joueur = j
	sante = j.sante
	is_bot = bot
	view = VueVide.new() if bot else WeaponView.new()
	view.name = "VueArme"
	j.cam.add_child(view)
	_exclude = [j.get_rid()]
	for a in hitboxes:
		_exclude.append(a.get_rid())
	for k in Armes.MUNITIONS:
		reserve[k] = 0


## Son d'une action : au joueur directement ; pour un bot, seulement les sons qui s'entendent
## de loin (tirs), placés à sa position.
func _snd(name: String, vol := 0.0, pitch := 1.0, audible := false) -> void:
	if not is_bot:
		G.play(name, vol, pitch)
	elif audible:
		G.play_at(name, joueur.global_position + Vector3(0, 1.5, 0), vol + 6.0, pitch)


func has_perk(id: String) -> bool:
	return perks.has(id)


func plate_time() -> float:
	return PLATE_TIME * (0.5 if has_perk("fixation") else 1.0)


func plates_max() -> int:
	return 7 if has_perk("ravitailleur") else Armes.PLAQUES_PORTEES


## Équipement de départ (Résurgence : un pistolet, une plaque sur soi, deux dans le sac).
## Aussi à chaque réapparition : la classe et les atouts sont perdus avec le sac.
func starting_kit() -> void:
	perks = []
	letal = ""
	letal_n = 0
	tactique = ""
	tactique_n = 0
	gas_mask = 0.0
	sante.regen_delay = Sante.REGEN_DELAY
	slots = [Armes.nouvelle("p9", 0), {}]
	cur = 0
	for k in reserve:
		reserve[k] = 0
	reserve["pistolet"] = 45
	plates = 2
	argent = 0
	sante.reset(1)
	reloading = false
	plate_t = 0.0
	view.set_weapon(current(), false)
	changed.emit()


## Largage de classe : les deux armes de la classe (légendaires, chargeurs pleins, munitions),
## ses atouts et ses équipements.
func apply_loadout(d: Dictionary) -> void:
	slots = [Armes.nouvelle(d.principale, Loadouts.RARETE, Loadouts.acc_de(d, "principale")),
		Armes.nouvelle(d.secondaire, Loadouts.RARETE, Loadouts.acc_de(d, "secondaire"))]
	cur = 0
	perks = d.atouts.duplicate()
	letal = d.get("letal", "grenade")
	letal_n = 1
	tactique = d.get("tactique", "fumigene")
	tactique_n = 1
	for id in [d.principale, d.secondaire]:
		var kind: String = Armes.info(id).munition
		reserve[kind] = maxi(int(reserve[kind]), int(Armes.MUNITIONS[kind].lot) * 2)
	sante.regen_delay = 2.5 if has_perk("robuste") else Sante.REGEN_DELAY
	reloading = false
	_swap_t = SWAP_TIME
	view.set_weapon(current())
	notice.emit("Classe « %s »" % d.get("nom", ""))
	changed.emit()


## À la mort : tout ce qu'on porte part dans un sac au sol.
func drop_everything() -> Dictionary:
	var bag := {"armes": [], "munitions": reserve.duplicate(), "plaques": plates, "argent": argent}
	for w in slots:
		if not w.is_empty():
			bag.armes.append(w.duplicate())
	return bag


func current() -> Dictionary:
	return slots[cur]


func other() -> Dictionary:
	return slots[1 - cur]


func can_use_weapon() -> bool:
	if joueur.swimming or joueur.is_drone():
		return false
	return joueur.etat in [Joueur.Etat.SOL, Joueur.Etat.GLISSADE, Joueur.Etat.PARACHUTE, Joueur.Etat.TYROLIENNE]


## Multiplicateur de vitesse de déplacement (arme en main, visée, plaque).
func move_mult() -> float:
	var w := current()
	var m := 1.0 if w.is_empty() else float(Armes.de(w).vitesse)
	m *= lerpf(1.0, 0.6, ads)
	if plate_t > 0.0:
		m *= 0.8
	return m


func blocks_sprint() -> bool:
	return ads > 0.3 or plate_t > 0.0


# ------------------------------------------------------------------------------------------------
# Simulation (un pas de physique)
# ------------------------------------------------------------------------------------------------
func simulate(i: Intentions, delta: float) -> void:
	_fire_cd = maxf(0.0, _fire_cd - delta)
	_swap_t = maxf(0.0, _swap_t - delta)
	_sprint_out = maxf(0.0, _sprint_out - delta)
	_bloom = maxf(0.0, _bloom - delta * 3.0)
	var allowed := can_use_weapon()
	view.visible = allowed or joueur.etat == Joueur.Etat.ESCALADE
	var w := current()
	var a := {} if w.is_empty() else Armes.de(w)

	# Visée.
	var want_ads := i.ads_held and allowed and not w.is_empty() and plate_t <= 0.0 and joueur.etat != Joueur.Etat.GLISSADE
	_ads_pressed_t = 0.0 if (want_ads and not _was_ads) else _ads_pressed_t + delta
	_was_ads = want_ads
	if not w.is_empty():
		var t := float(a.ads)
		ads = move_toward(ads, 1.0 if want_ads else 0.0, delta / maxf(t, 0.05))
	else:
		ads = 0.0
	view.ads = ads
	if want_ads and joueur.sprinting:
		joueur.stop_sprint()

	# Changement d'arme (annule le rechargement).
	if i.swap and not other().is_empty() and plate_t <= 0.0:
		cur = 1 - cur
		reloading = false
		_bloom = 0.0
		_swap_t = SWAP_TIME
		view.set_weapon(current())
		changed.emit()
		w = current()
		a = Armes.de(w)

	# Action : ramasser / ouvrir ; le même bouton recharge quand il n'y a rien à portée (manette).
	# (Les bots ne cherchent autour d'eux que de temps en temps : ils sont nombreux.)
	_scan_t -= delta
	var scan := not is_bot or _scan_t <= 0.0 or i.interact
	if scan:
		target_item = _find_interactable()
	if (i.interact or i.use) and target_item:
		_interact(target_item)
	elif i.reload or (i.use and target_item == null):
		start_reload()

	# Équipements lancés.
	if (i.lethal and letal_n > 0) or (i.tactical and tactique_n > 0):
		if allowed and plate_t <= 0.0:
			var k := letal if i.lethal and letal_n > 0 else tactique
			if k == letal and i.lethal:
				letal_n -= 1
			else:
				tactique_n -= 1
			var cam := joueur.cam
			Lancer.throw(get_tree().current_scene, k, cam.global_position - cam.global_basis.z * 0.5,
				-cam.global_basis.z, joueur, _exclude)
			_snd("knife", -8.0, 0.8)
			changed.emit()
	if gas_mask > 0.0 and joueur.in_gas:
		gas_mask = maxf(0.0, gas_mask - delta)

	# Plaques : maintenir pour en mettre une, puis la suivante.
	# Une plaque par appui (réglage) : il faut relâcher avant la suivante.
	if not i.plate_held:
		_plate_wait = false
	if i.plate_held and not _plate_wait and plates > 0 and sante.armor < sante.armor_max - 0.01 and (allowed or joueur.etat == Joueur.Etat.SOL):
		if plate_t <= 0.0:
			reloading = false
			view.play_anim("swap", plate_time())
			_snd("mag_out", -6.0, 0.7)
		plate_t += delta
		if joueur.sprinting:
			joueur.stop_sprint()
		if plate_t >= plate_time():
			if sante.insert_plate():
				plates -= 1
				_snd("plank_place", -3.0, 1.3)
				changed.emit()
				if not is_bot and not bool(G.settings.get("plaques_toutes", true)):
					_plate_wait = true
			plate_t = 0.0
	else:
		plate_t = 0.0

	# Rechargement.
	if reloading:
		reload_t -= delta
		if reload_t <= 0.0:
			_finish_reload()

	# Tir.
	if not i.fire_held:
		_semi_ready = true
		_dry = false
	if i.fire_held and allowed and not w.is_empty() and plate_t <= 0.0:
		if joueur.sprinting:
			joueur.stop_sprint()
			_sprint_out = SPRINT_OUT
		var trigger := bool(a.auto) or _semi_ready
		if int(w.chargeur) <= 0:
			if not reloading and int(reserve[a.munition]) > 0:
				start_reload()
			elif not _dry and not reloading:
				_snd("dryfire", -6.0)
				_dry = true
		elif reloading and trigger:
			reloading = false   # tirer interrompt le rechargement s'il reste des balles
			view.set_weapon(w, false)
		if trigger and not reloading and _fire_cd <= 0.0 and _swap_t <= 0.0 and _sprint_out <= 0.0 and int(w.chargeur) > 0:
			_shoot(w, a)
			_semi_ready = false

	_update_spread(w, a)
	if not is_bot:
		_update_assist()
	if scan:
		_auto_pickup()
		_scan_t = 0.2


func _update_spread(w: Dictionary, a: Dictionary) -> void:
	if w.is_empty():
		spread = 0.0
		return
	var base := lerpf(float(a.disp), float(a.disp_ads), ads) * (0.75 if has_perk("tete_froide") else 1.0)
	var move := clampf(joueur.hspeed / 6.0, 0.0, 1.5) * 1.6 * (1.0 - ads * 0.75)
	var air := 0.0 if joueur.is_on_floor() or joueur.etat == Joueur.Etat.PARACHUTE else 2.0
	spread = base + move + air + _bloom * (1.0 - ads * 0.6)


# ------------------------------------------------------------------------------------------------
# Tir
# ------------------------------------------------------------------------------------------------
func _shoot(w: Dictionary, a: Dictionary) -> void:
	w.chargeur = int(w.chargeur) - 1
	_fire_cd = float(a.rof)
	shots_fired += 1
	var cam := joueur.cam
	var origin := cam.global_position
	var fwd := -cam.global_basis.z
	var right := cam.global_basis.x
	var up := cam.global_basis.y
	var best := ""
	var total := 0.0
	for p in int(a.plombs):
		var r := deg_to_rad(spread) * sqrt(randf())
		var th := randf() * TAU
		var dir := (fwd + (right * cos(th) + up * sin(th)) * tan(r)).normalized()
		var res := _ray(origin, dir)
		var end := origin + dir * RANGE
		if not res.is_empty():
			end = res.position
			var col: Object = res.collider
			if col is Area3D and col.has_meta("sante"):
				var s: Sante = col.get_meta("sante")
				var zone: String = col.get_meta("zone")
				var on_armor := s.armor > 0.0
				var dmg := Armes.degats_de(w, origin.distance_to(end), zone)
				total += s.take(dmg, zone, "balle", false, joueur)
				var kind := "corps"
				if s.dead:
					kind = "elimination"
				elif on_armor and s.armor <= 0.0:
					kind = "brise"
				elif on_armor:
					kind = "armure"
				elif zone == "tete":
					kind = "tete"
				best = _stronger(best, kind)
			else:
				Fx.impact(get_tree().current_scene, end, res.normal)
		Fx.tracer(get_tree().current_scene, view.muzzle_global(), end)
	if best != "":
		hit.emit(best, total)
		if not is_bot:
			var m: Array = {"corps": ["marque_corps", -5.0], "tete": ["marque_tete", -4.0], "armure": ["marque_armure", -4.0],
				"brise": ["armure_brisee", -2.0], "elimination": ["killmarker", -1.0]}.get(best, ["marque_corps", -5.0])
			_snd(String(m[0]), float(m[1]), randf_range(0.97, 1.03))
	# Silencieux : tir étouffé (plus bas, plus aigu) et absent de la mini-carte des autres.
	var silent := bool(a.get("silencieux", false))
	if silent:
		_snd(String(a.son), -15.0, randf_range(1.25, 1.35), true)
	else:
		_snd(String(a.son), -5.0, randf_range(0.96, 1.04), true)
		G.report_shot(joueur)
	view.shot(float(a.recul))
	_bloom = minf(_bloom + 0.35 * float(a.recul), 4.0)
	# Recul : la visée monte, avec un peu de dérive latérale.
	var k := float(a.recul) * lerpf(0.45, 0.22, ads) * (0.75 if has_perk("tete_froide") else 1.0)
	joueur.add_recoil(k, randf_range(-0.35, 0.35) * k)
	if int(w.chargeur) <= 0 and int(reserve[a.munition]) > 0:
		start_reload()
	changed.emit()


static func _stronger(a: String, b: String) -> String:
	var order := ["", "corps", "armure", "tete", "brise", "elimination"]
	return a if order.find(a) >= order.find(b) else b


func _ray(origin: Vector3, dir: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * RANGE, G.L_WORLD | G.L_HITBOX, _exclude)
	q.collide_with_areas = true
	return joueur.get_world_3d().direct_space_state.intersect_ray(q)


func start_reload() -> void:
	var w := current()
	if w.is_empty() or reloading:
		return
	var a := Armes.de(w)
	var size := Armes.chargeur_de(w)
	if int(w.chargeur) >= size or int(reserve[a.munition]) <= 0:
		return
	reloading = true
	reload_t = float(a.recharge) * (0.85 if int(w.chargeur) > 0 else 1.0)
	view.play_reload(reload_t, int(w.chargeur) == 0, size - int(w.chargeur))


func _finish_reload() -> void:
	reloading = false
	var w := current()
	if w.is_empty():
		return
	var a := Armes.de(w)
	var need := Armes.chargeur_de(w) - int(w.chargeur)
	var take := mini(need, int(reserve[a.munition]))
	w.chargeur = int(w.chargeur) + take
	reserve[a.munition] = int(reserve[a.munition]) - take
	changed.emit()


# ------------------------------------------------------------------------------------------------
# Butin
# ------------------------------------------------------------------------------------------------
func _find_interactable() -> Node3D:
	if pillage == null or not can_use_weapon():
		return null
	var p := joueur.global_position + Vector3(0, 0.6, 0)
	var fwd := -joueur.global_basis.z
	var best: Node3D = null
	var best_score := INF
	for b in pillage.items:
		if b.type != Butin.Type.ARME:
			continue
		var score := _reach_score(p, fwd, b.global_position)
		if score < best_score:
			best_score = score
			best = b
	for c in pillage.chests:
		if not is_instance_valid(c) or not c.can_open():
			continue
		var score := _reach_score(p, fwd, c.global_position + Vector3(0, 0.3, 0))
		if score < best_score:
			best_score = score
			best = c
	if not is_bot:
		for t in pillage.contrats:
			if not is_instance_valid(t):
				continue
			var score := _reach_score(p, fwd, (t as Node3D).global_position + Vector3(0, 0.2, 0))
			if score < best_score:
				best_score = score
				best = t
	if joueur.etat == Joueur.Etat.SOL:
		for an in pillage.tyroliennes:
			var score := _reach_score(p, fwd, an.global_position) * 1.1
			if score < best_score:
				best_score = score
				best = an
	for st in pillage.shops:
		var score := _reach_score(p, fwd, st.global_position + Vector3(0, 0.6, 0)) * 0.9
		if score < best_score:
			best_score = score
			best = st
	return best


## Distance pondérée par l'angle : on prend ce qu'on regarde plutôt que ce qui est derrière soi.
func _reach_score(p: Vector3, fwd: Vector3, target: Vector3) -> float:
	var d := target - p
	var dist := d.length()
	if dist > REACH:
		return INF
	var flat := Vector3(d.x, 0, d.z)
	var facing := 1.0 if flat.length() < 0.3 else fwd.dot(flat.normalized())
	if facing < -0.2 and dist > 1.0:
		return INF
	return dist * (2.0 - facing)


func interact_label() -> String:
	if target_item is Butin:
		var b := target_item as Butin
		if not other().is_empty() and not current().is_empty():
			return "Échanger contre : %s" % b.label()
		return "Ramasser : %s" % b.label()
	if target_item is Coffre:
		return (target_item as Coffre).label()
	if target_item and target_item.has_meta("boutique"):
		return "Station d'achat"
	if target_item and target_item.is_in_group("contrat"):
		return target_item.call("label")
	if target_item and target_item.has_meta("tyrolienne"):
		return "Tyrolienne : monter" if target_item.get_meta("monte") else "Tyrolienne : descendre"
	return ""


func _interact(t: Node3D) -> void:
	if t is Coffre:
		var c := t as Coffre
		if c.largage:
			loadout_requested.emit(c)
			return
		if c.ravitaillement:
			refill()
		c.open_chest()
		return
	if t.has_meta("boutique"):
		shop_requested.emit(t)
		return
	if t.is_in_group("contrat"):
		contract_requested.emit(t)
		return
	if t.has_meta("tyrolienne"):
		joueur.start_zip(t.get_meta("tyrolienne"), bool(t.get_meta("monte")))
		return
	var b := t as Butin
	var w := b.arme.duplicate()
	var pos := b.global_position
	pillage.remove(b)
	if current().is_empty():
		slots[cur] = w
	elif other().is_empty():
		cur = 1 - cur
		slots[cur] = w
	else:
		# Les deux mains sont prises : on pose l'arme en main à la place de la nouvelle.
		pillage.spawn(Butin.make_arme(slots[cur]), pos, randf() * TAU)
		slots[cur] = w
	reloading = false
	_swap_t = SWAP_TIME
	view.set_weapon(current())
	_snd("buy", -8.0)
	notice.emit(Armes.nom_complet(w))
	changed.emit()


## Champ de tir : munitions et plaques au maximum.
func refill() -> void:
	for k in reserve:
		reserve[k] = int(Armes.MUNITIONS[k].max)
	plates = plates_max()
	sante.reset(Armes.PLAQUES_MAX)
	notice.emit("Ravitaillé")
	changed.emit()


func _auto_pickup() -> void:
	if pillage == null or not can_use_weapon():
		return
	var p := joueur.global_position
	for b in pillage.items.duplicate():
		if b.type == Butin.Type.ARME:
			continue
		if p.distance_squared_to(b.global_position) > 1.5 * 1.5 or absf(p.y - b.global_position.y) > 1.2:
			continue
		match b.type:
			Butin.Type.MUNITIONS:
				var room := int(Armes.MUNITIONS[b.munition].max) - int(reserve[b.munition])
				if room <= 0:
					continue
				var gain := int(round(b.quantite * (1.5 if has_perk("pillard") else 1.0)))
				var take := mini(room, gain)
				reserve[b.munition] = int(reserve[b.munition]) + take
				b.quantite = 0 if take >= gain else b.quantite - take
				notice.emit("+%d %s" % [take, String(Armes.MUNITIONS[b.munition].nom).to_lower()])
			Butin.Type.PLAQUE:
				var room := plates_max() - plates
				if room <= 0:
					continue
				var take := mini(room, b.quantite)
				plates += take
				b.quantite -= take
				notice.emit("+%d plaque%s" % [take, "s" if take > 1 else ""])
			Butin.Type.ARGENT:
				var gain := int(round(b.quantite * (1.5 if has_perk("pillard") else 1.0)))
				argent = mini(Armes.ARGENT_MAX, argent + gain)
				notice.emit("+%d €" % gain)
				b.quantite = 0
		_snd("powerup_pick", -14.0, 1.4)
		if b.quantite <= 0:
			pillage.remove(b)
		changed.emit()


# ------------------------------------------------------------------------------------------------
# Assistance à la visée (manette et tactile)
# ------------------------------------------------------------------------------------------------
func _update_assist() -> void:
	assist_target = null
	var level := int(G.settings.get("assistance", 1))
	if not can_use_weapon() or level == 0:
		return
	var k := 1.5 if level == 2 else 1.0
	var cam := joueur.cam
	var fwd := -cam.global_basis.z
	var best := INF
	for c in get_tree().get_nodes_in_group("combattant"):
		var t := c as Node3D
		if t == joueur or not _assist_ok(t):
			continue
		var to: Vector3 = Bot.aim_point(t) - cam.global_position
		var dist := to.length()
		if dist > 120.0:
			continue
		var ang := rad_to_deg(fwd.angle_to(to))
		var cone := maxf(ASSIST_CONE * 0.6 * k, rad_to_deg(atan(1.2 * k / dist)))
		if ang < maxf(cone, SNAP_CONE * k) and ang < best and _visible(cam.global_position, Bot.aim_point(t)):
			best = ang
			assist_target = t
	# En épaulant : la visée se cale sur la cible proche (comme sur console).
	if assist_target and _ads_pressed_t < 0.2 and ads > 0.15 and G.input_mode != "kbm":
		joueur.snap_towards(Bot.aim_point(assist_target), 0.6 if level == 2 else 0.45)


## Mannequins et adversaires vivants, au sol ou sous la voile.
func _assist_ok(t: Node3D) -> bool:
	if t is Cible:
		return (t as Cible).alive()
	if t is Joueur:
		var jj := t as Joueur
		return not jj.sante.dead and jj.etat != Joueur.Etat.AVION and jj.etat != Joueur.Etat.DRONE
	return false


func _visible(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, G.L_WORLD, _exclude)
	return joueur.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Ralentissement de la visée quand le réticule passe sur une cible.
func look_scale() -> float:
	if assist_target == null or G.input_mode == "kbm":
		return 1.0
	var to: Vector3 = Bot.aim_point(assist_target) - joueur.cam.global_position
	var ang := rad_to_deg((-joueur.cam.global_basis.z).angle_to(to))
	return ASSIST_SLOW if ang < ASSIST_CONE else 1.0


func _process(delta: float) -> void:
	if view and joueur:
		view.update_view(delta, joueur.hspeed, joueur.sprinting, joueur.is_on_floor())
		var w := current()
		view.hidden_by_scope = not w.is_empty() and (w.id == "aiguille" or w.get("acc", []).has("lunette")) and ads > 0.9
