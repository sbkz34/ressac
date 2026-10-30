class_name Joueur
extends CharacterBody3D
## Contrôleur du joueur (jalon 1) : sprint, sprint tactique, accroupi / couché, glissade et
## annulation de glissade (cancel slide), saut de glissade, escalade de rebords, nage,
## chute libre, parachute (ouvrir, couper, rouvrir), saut d'avion, redéploiement depuis un
## point haut, et le drone de visite.
##
## La simulation lit une structure Intentions : celle du joueur local (manette, clavier,
## tactile) ou celle imposée par un test / un bot (`scripted`).

signal state_changed(etat: int)
signal landed

enum Etat { SOL, GLISSADE, ESCALADE, CHUTE_LIBRE, PARACHUTE, AVION, DRONE, TYROLIENNE }
enum Posture { DEBOUT, ACCROUPI, COUCHE }

# Vitesses (m/s). Marche et sprint reprennent Dernière Vague.
const WALK := 4.6
const SPRINT := 6.9
const TAC_SPRINT := 8.6
const CROUCH := 2.6
const PRONE := 1.1
const SWIM := 3.0
const ACCEL := 60.0             # au sol, vers la vitesse voulue
const AIR_ACCEL := 9.0
const MOMENTUM_DECAY := 3.0     # au-dessus de la vitesse voulue, l'élan se perd doucement
const GRAVITY := 18.0
const JUMP := 6.0
# Sprint tactique.
const TAC_DURATION := 3.5
const TAC_COOLDOWN := 8.0
# Glissade.
const SLIDE_MIN_SPEED := 5.5    # il faut courir
const SLIDE_BOOST := 2.4
const SLIDE_MAX := 11.0
const SLIDE_FRICTION := 7.0     # après les 0,2 premières secondes
const SLIDE_END_SPEED := 3.2
const SLIDE_MAX_TIME := 1.1
const SLIDE_CANCEL_MIN := 0.12  # délai avant de pouvoir annuler
const SLIDE_REBOOST := 0.35     # temps entre deux glissades pour retrouver l'élan
const SLIDE_STEER := 1.6
# Escalade.
const MANTLE_MIN := 0.5
const MANTLE_MAX := 2.8
# Chute libre et parachute.
const FREE_V_MIN := 26.0        # vitesse de chute à plat
const FREE_V_MAX := 52.0        # tête la première
const FREE_H := 22.0
const CHUTE_V := 6.0
const CHUTE_H := 9.0
const AUTO_DEPLOY := 40.0       # ouverture automatique (hauteur au-dessus du sol)
const AUTO_DEPLOY_LATE := 12.0  # si on a déjà ouvert puis coupé pendant cette chute
const REDEPLOY_HEIGHT := 12.0   # sauter dans le vide de plus haut que ça permet d'ouvrir
# Divers.
const WATER_LEVEL := -1.25
const FALL_SAFE := 15.0         # vitesse de chute sans dégâts (≈ 6 m)
const FALL_DAMAGE := 9.0        # points de vie par m/s au-delà
const DRONE_SPEED := 22.0
const DRONE_FAST := 65.0
const LOOK_PAD := 150.0
const LOOK_MOUSE := 0.12
const BASE_FOV := 78.0
const HEIGHTS := {Posture.DEBOUT: 1.8, Posture.ACCROUPI: 1.2, Posture.COUCHE: 0.8}
const EYES := {Posture.DEBOUT: 1.6, Posture.ACCROUPI: 1.05, Posture.COUCHE: 0.45}

var etat: int = Etat.SOL
var _zip_pts := PackedVector3Array()   # tyrolienne : trajet (pieds) et distance parcourue
var _zip_s := 0.0
var _zip_up := true
var posture: int = Posture.DEBOUT
var sprinting := false
var swimming := false
var tac_left := 0.0
var tac_cooldown := 0.0
var slide_t := 0.0
var slide_speed := 0.0
var slide_dir := Vector2.ZERO
var since_slide := 10.0
var chute_opened_once := false
var avion: Avion
var scripted: Intentions     # tests et bots : remplace les commandes locales
var touch: TouchControls
var head: Node3D
var cam: Camera3D
var canopy: Node3D
var hspeed := 0.0             # vitesse horizontale réelle (affichage, tests)
var sante: Sante
var arsenal: Arsenal
var hitboxes: Array[Area3D] = []
var in_gas := false           # dans la Brume (réglé par la partie)
var is_bot := false           # combattant piloté par un Bot (pas de caméra ni de vue d'arme)
var nom := "Vous"
var corps: BotCorps           # silhouette visible des autres (bots)
var ui_block := false         # un menu (achat, classe) est ouvert : les commandes locales sont coupées

var _local := Intentions.new()
var _shape: CollisionShape3D
var _shapes := {}
var _yaw := 0.0
var _pitch := 0.0
var _roll := 0.0
var _crouch_hold := 0.0
var _hold_from_ground := false
var _air_t := 0.0
var _mantle_from := Vector3.ZERO
var _mantle_to := Vector3.ZERO
var _mantle_t := 0.0
var _mantle_dur := 0.0
var _mantle_posture: int = Posture.DEBOUT
var _mantle_sprint := false
var _step := 0.0
var _fall_peak := 0.0
var _snap := Vector2.ZERO     # rotation (degrés) encore à appliquer : assistance, recul
var _hb_on := true
var _y_t := -1.0               # Y maintenu depuis (négatif : relâché)
var _ads_toggle := false
const HOLD_PLATE := 0.25       # au-delà, Y pose des plaques au lieu de changer d'arme
var _floor_kind := "terre"     # sol sous les pieds : "terre", "dur" ou "eau" (bruit des pas)
var _stroke := 0.0


func _ready() -> void:
	add_to_group("combattant")
	collision_layer = G.L_PLAYER
	collision_mask = G.L_WORLD
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.5
	for p in HEIGHTS:
		var cap := CapsuleShape3D.new()
		cap.radius = 0.4
		cap.height = HEIGHTS[p]
		_shapes[p] = cap
	_shape = CollisionShape3D.new()
	add_child(_shape)
	_apply_shape(Posture.DEBOUT)
	head = Node3D.new()
	head.position.y = EYES[Posture.DEBOUT]
	add_child(head)
	cam = Camera3D.new()
	cam.fov = BASE_FOV
	cam.near = 0.08
	cam.far = 2200.0
	head.add_child(cam)
	cam.current = not is_bot
	_make_canopy()
	sante = Sante.new()
	sante.name = "Sante"
	add_child(sante)
	hitboxes = Sante.make_hitboxes(self, sante)
	arsenal = Arsenal.new()
	arsenal.name = "Arsenal"
	add_child(arsenal)
	arsenal.setup(self, hitboxes, is_bot)
	if is_bot:
		corps = BotCorps.new()
		add_child(corps)
	else:
		var sons := SonsJoueur.new()
		sons.name = "Sons"
		sons.joueur = self
		add_child(sons)


func _apply_shape(p: int) -> void:
	_shape.shape = _shapes[p]
	_shape.position.y = HEIGHTS[p] / 2.0
	# Les zones de touche suivent la posture (on est plus petit accroupi ou couché).
	var k: float = HEIGHTS[p] / HEIGHTS[Posture.DEBOUT]
	for a in hitboxes:
		a.position.y = float(a.get_meta("base_y")) * k


func spawn_at(p: Vector3, yaw: float) -> void:
	_set_etat(Etat.SOL)
	collision_mask = G.L_WORLD
	_set_posture(Posture.DEBOUT, true)
	global_position = p
	velocity = Vector3.ZERO
	sprinting = false
	tac_left = 0.0
	tac_cooldown = 0.0
	_yaw = yaw
	_pitch = 0.0
	rotation.y = _yaw
	head.rotation = Vector3.ZERO
	canopy.visible = false


func _set_etat(e: int) -> void:
	if e == etat:
		return
	etat = e
	canopy.visible = e == Etat.PARACHUTE
	collision_mask = 0 if e == Etat.DRONE or e == Etat.ESCALADE or e == Etat.AVION or e == Etat.TYROLIENNE else G.L_WORLD
	state_changed.emit(e)


func _set_posture(p: int, force := false) -> bool:
	if p == posture and not force:
		return true
	if not force and HEIGHTS[p] > HEIGHTS[posture] and not _fits(global_position, HEIGHTS[p]):
		return false
	posture = p
	_apply_shape(p)
	return true


## Une capsule de cette hauteur tient-elle à cet endroit (pieds en `feet`) ?
func _fits(feet: Vector3, height: float) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = height
	q.shape = cap
	q.transform = Transform3D(Basis(), feet + Vector3(0, height / 2.0 + 0.06, 0))
	q.collision_mask = G.L_WORLD
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func set_drone(on: bool) -> void:
	if on:
		_set_etat(Etat.DRONE)
		_set_posture(Posture.DEBOUT, true)
	else:
		_set_etat(Etat.SOL)
	velocity = Vector3.ZERO


## Mort en attente de réapparition : la caméra survole l'endroit, sans commandes.
func spectate(at: Vector3) -> void:
	set_drone(true)
	ui_block = true
	sprinting = false
	global_position = at + Vector3(0, 14.0, 10.0)
	look_at_point(at)


func is_drone() -> bool:
	return etat == Etat.DRONE


func tac_ready() -> bool:
	return tac_left <= 0.0 and tac_cooldown <= 0.0


func stop_sprint() -> void:
	sprinting = false
	_end_tac()


## Recul d'une arme : la visée monte (et dérive un peu), en degrés.
func add_recoil(pitch_deg: float, yaw_deg: float) -> void:
	_snap += Vector2(yaw_deg, pitch_deg)


## Assistance à la visée : tourne la vue d'une fraction de l'écart vers un point.
func snap_towards(point: Vector3, fraction: float) -> void:
	var to := point - cam.global_position
	var yaw_t := atan2(-to.x, -to.z)
	var pitch_t := atan2(to.y, Vector2(to.x, to.z).length())
	var dy := rad_to_deg(wrapf(yaw_t - _yaw, -PI, PI))
	var dp := rad_to_deg(pitch_t - _pitch)
	_snap += Vector2(dy, dp) * fraction


## Tests : regarder exactement un point.
func look_at_point(point: Vector3) -> void:
	var to := point - (global_position + Vector3(0, EYES[posture], 0))
	_yaw = atan2(-to.x, -to.z)
	_pitch = atan2(to.y, Vector2(to.x, to.z).length())
	rotation.y = _yaw
	head.rotation.x = _pitch
	_snap = Vector2.ZERO


# ------------------------------------------------------------------------------------------------
# Commandes locales (accumulées entre deux pas de physique)
# ------------------------------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not OS.has_feature("mobile") and G.input_mode == "kbm" \
			and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var s := LOOK_MOUSE * float(G.settings.sens_mouse)
		_local.look += Vector2(-event.relative.x * s, -event.relative.y * s * (-1.0 if bool(G.settings.inverser_y) else 1.0))
	if event.is_action_pressed("drone"):
		set_drone(etat != Etat.DRONE)


## Sons du mouvement : au joueur directement ; ceux d'un bot s'entendent de près (pas, réceptions).
func _snd(name: String, vol := 0.0, pitch := 1.0) -> void:
	if not is_bot:
		G.play(name, vol, pitch)
		return
	var cam3 := get_viewport().get_camera_3d()
	if cam3 and cam3.global_position.distance_squared_to(global_position) < 28.0 * 28.0:
		G.play_at(name, global_position + Vector3(0, 0.3, 0), vol + 6.0, pitch)


func _process(delta: float) -> void:
	if is_bot or get_tree().paused:
		return
	var i := _local
	if ui_block:
		i.move = Vector2.ZERO
		i.fire_held = false
		i.ads_held = false
		i.plate_held = false
		i.jump_held = false
		i.crouch_held = false
		return
	var stick := Input.get_vector("look_left", "look_right", "look_down", "look_up")
	var assist := arsenal.look_scale()
	if stick != Vector2.ZERO:
		var curved := stick * stick.length()   # précis au centre, rapide en bout de course
		var s := LOOK_PAD * float(G.settings.sens_pad) * delta * assist * lerpf(1.0, float(G.settings.sens_ads), arsenal.ads)
		i.look += Vector2(-curved.x * s, curved.y * s * 0.75 * (-1.0 if bool(G.settings.inverser_y) else 1.0))
	i.move = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	i.jump = i.jump or Input.is_action_just_pressed("jump")
	i.crouch = i.crouch or Input.is_action_just_pressed("crouch")
	i.sprint = i.sprint or Input.is_action_just_pressed("sprint")
	i.jump_held = Input.is_action_pressed("jump")
	i.crouch_held = Input.is_action_pressed("crouch")
	i.sprint_held = Input.is_action_pressed("sprint")
	i.fire_held = Input.is_action_pressed("fire")
	# Viser : maintenir, ou appuyer une fois (réglage).
	if bool(G.settings.visee_bascule):
		if Input.is_action_just_pressed("ads"):
			_ads_toggle = not _ads_toggle
		if not arsenal.can_use_weapon() or sprinting:
			_ads_toggle = false
		i.ads_held = _ads_toggle
	else:
		i.ads_held = Input.is_action_pressed("ads")
	# Sprint automatique : stick poussé à fond vers l'avant.
	if bool(G.settings.sprint_auto) and i.move.y < -0.9 and not sprinting and etat == Etat.SOL and posture == Posture.DEBOUT:
		i.sprint = true
	i.reload = i.reload or Input.is_action_just_pressed("reload")
	i.swap = i.swap or Input.is_action_just_pressed("swap")
	i.interact = i.interact or Input.is_action_just_pressed("interact")
	i.use = i.use or Input.is_action_just_pressed("use")
	i.plate_held = Input.is_action_pressed("plate")
	# Y : appui bref = changer d'arme (au relâchement), maintenu = poser des plaques.
	if Input.is_action_just_pressed("arme_plaque"):
		_y_t = 0.0
	if _y_t >= 0.0:
		if Input.is_action_pressed("arme_plaque"):
			_y_t += delta
			if _y_t >= HOLD_PLATE:
				i.plate_held = true
		else:
			if _y_t < HOLD_PLATE:
				i.swap = true
			_y_t = -1.0
	i.lethal = i.lethal or Input.is_action_just_pressed("lethal")
	i.tactical = i.tactical or Input.is_action_just_pressed("tactical")
	if touch and touch.visible:
		var d := touch.consume_look() * 0.18 * float(G.settings.sens_touch) * assist * lerpf(1.0, float(G.settings.sens_ads), arsenal.ads)
		i.look += Vector2(-d.x, -d.y * (-1.0 if bool(G.settings.inverser_y) else 1.0))
		if touch.move.length() > i.move.length():
			i.move = touch.move
		i.jump = i.jump or touch.take("saut")
		i.crouch = i.crouch or touch.take("accroupi")
		# Pousser le stick tout au bord lance le sprint ; le bouton SPRINT aussi (et en
		# sprintant, il déclenche le sprint tactique).
		i.sprint = i.sprint or touch.take("sprint") or (touch.sprint_edge and not sprinting and etat == Etat.SOL)
		i.jump_held = i.jump_held or touch.held("saut")
		i.crouch_held = i.crouch_held or touch.held("accroupi")
		i.fire_held = i.fire_held or touch.held("tir")
		i.ads_held = i.ads_held or touch.ads_on
		i.reload = i.reload or touch.take("recharger")
		i.swap = i.swap or touch.take("arme")
		i.interact = i.interact or touch.take("action")
		i.plate_held = i.plate_held or touch.held("plaque")
		i.lethal = i.lethal or touch.take("grenade")
		i.tactical = i.tactical or touch.take("fumigene")


func _look(d: Vector2) -> void:
	_yaw += deg_to_rad(d.x)
	_pitch = clampf(_pitch + deg_to_rad(d.y), deg_to_rad(-88), deg_to_rad(88))
	rotation.y = _yaw


# ------------------------------------------------------------------------------------------------
# Simulation
# ------------------------------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	var i := scripted if scripted else _local
	_look(i.look)
	tac_cooldown = maxf(0.0, tac_cooldown - delta)
	since_slide += delta
	match etat:
		Etat.AVION: _sim_avion(i)
		Etat.CHUTE_LIBRE: _sim_chute_libre(i, delta)
		Etat.PARACHUTE: _sim_parachute(i, delta)
		Etat.ESCALADE: _sim_escalade(delta)
		Etat.DRONE: _sim_drone(i, delta)
		Etat.GLISSADE: _sim_glissade(i, delta)
		Etat.TYROLIENNE: _sim_tyrolienne(i, delta)
		_: _sim_sol(i, delta)
	arsenal.simulate(i, delta)
	if _snap != Vector2.ZERO:
		var step := _snap * minf(1.0, 25.0 * delta)
		_look(step)
		_snap -= step
		if _snap.length() < 0.01:
			_snap = Vector2.ZERO
	i.consume()
	hspeed = Vector2(velocity.x, velocity.z).length()
	_update_camera(delta)
	if corps:
		corps.follow(self)
	# Mort, dans l'avion ou en spectateur : on ne peut pas être touché (ni arrêter les balles).
	var hb := not sante.dead and etat != Etat.AVION and etat != Etat.DRONE
	if hb != _hb_on:
		_hb_on = hb
		for a in hitboxes:
			a.collision_layer = G.L_HITBOX if hb else 0


func _wish_dir(i: Intentions) -> Vector2:
	var d := global_basis * Vector3(i.move.x, 0, i.move.y)
	var v := Vector2(d.x, d.z)
	return v.limit_length(1.0)


func _forward2() -> Vector2:
	var f := -global_basis.z
	return Vector2(f.x, f.z).normalized()


func _sim_sol(i: Intentions, delta: float) -> void:
	var on_floor := is_on_floor()
	var hv := Vector2(velocity.x, velocity.z)
	var was_swimming := swimming
	swimming = _update_swimming(was_swimming)
	if swimming and not was_swimming:
		if velocity.y < -3.0 or hspeed > 5.0:
			_snd("plouf", -4.0 if velocity.y < -8.0 else -9.0, randf_range(0.9, 1.1))
		sprinting = false
		_end_tac()
		_set_posture(Posture.DEBOUT, true)
	_air_t = 0.0 if on_floor else _air_t + delta

	# Accroupi : appui = glissade si on court, sinon bascule debout / accroupi ; maintenu = couché.
	if i.crouch and not swimming:
		_hold_from_ground = true
		_crouch_hold = 0.0
		if on_floor and sprinting and posture == Posture.DEBOUT and hv.length() >= SLIDE_MIN_SPEED:
			_start_slide(hv)
			return
		match posture:
			Posture.DEBOUT: _set_posture(Posture.ACCROUPI)
			Posture.ACCROUPI: _set_posture(Posture.DEBOUT)
			Posture.COUCHE: _set_posture(Posture.ACCROUPI)
		sprinting = false
		_end_tac()
	if i.crouch_held and _hold_from_ground and on_floor and not swimming:
		_crouch_hold += delta
		if _crouch_hold >= 0.4 and posture != Posture.COUCHE:
			_set_posture(Posture.COUCHE)
			_hold_from_ground = false
	elif not i.crouch_held:
		_hold_from_ground = false

	# Sprint : appui = courir ; en courant, appui = sprint tactique.
	if i.sprint and not swimming and not arsenal.blocks_sprint():
		if sprinting and tac_ready() and posture == Posture.DEBOUT:
			tac_left = TAC_DURATION * (2.0 if arsenal.has_perk("double_temps") else 1.0)
		elif not sprinting and (posture == Posture.DEBOUT or _set_posture(Posture.DEBOUT)):
			sprinting = true
	if sprinting and (i.move.y > -0.3 or posture != Posture.DEBOUT or swimming):
		sprinting = false
		_end_tac()
	if tac_left > 0.0:
		tac_left -= delta
		if tac_left <= 0.0:
			_end_tac()

	# Saut : depuis accroupi on se relève ; près d'un rebord on escalade ; en l'air au-dessus
	# du vide on ouvre le parachute.
	if i.jump and not swimming:
		if on_floor or _air_t < 0.12:
			if posture != Posture.DEBOUT:
				_set_posture(Posture.DEBOUT)
			elif not _try_mantle():
				velocity.y = JUMP
				_air_t = 1.0
		elif not _try_mantle():
			if velocity.y < 0.0 and height_above_ground() >= REDEPLOY_HEIGHT:
				_open_chute()
				return
	elif i.jump_held and not on_floor and not swimming and velocity.y < 2.0 and i.move.y < -0.3:
		_try_mantle()   # en l'air, maintenir saut en avançant agrippe le rebord
	if etat != Etat.SOL:
		return

	# Déplacement horizontal.
	var speed := WALK
	if swimming:
		speed = SWIM
	elif posture == Posture.ACCROUPI:
		speed = CROUCH
	elif posture == Posture.COUCHE:
		speed = PRONE
	elif tac_left > 0.0:
		speed = TAC_SPRINT
	elif sprinting:
		speed = SPRINT
	if not sprinting and i.move.y > 0.2:
		speed *= 0.85    # on recule moins vite
	if not swimming:
		speed *= arsenal.move_mult()
	var wish := _wish_dir(i)
	var target := wish * speed
	if on_floor or swimming:
		if hv.length() > speed + 0.2 and target.length() > 0.1 and hv.normalized().dot(target.normalized()) > 0.3:
			# Élan (après une glissade annulée par exemple) : on le garde et on tourne.
			var s := move_toward(hv.length(), speed, MOMENTUM_DECAY * delta)
			hv = hv.normalized().slerp(target.normalized(), minf(1.0, 6.0 * delta)) * s
		else:
			hv = hv.move_toward(target, ACCEL * delta)
	else:
		var n := hv.move_toward(target, AIR_ACCEL * delta)
		if target.length() > 0.1 and n.length() < hv.length():
			n = n.normalized() * hv.length()    # en l'air, on dirige sans freiner
		hv = n
	velocity.x = hv.x
	velocity.z = hv.y

	if swimming:
		velocity.y = move_toward(velocity.y, (WATER_LEVEL + 0.15 - global_position.y) * 4.0, 30.0 * delta)
		if i.jump_held:
			velocity.y = 2.5
	elif not on_floor:
		velocity.y -= GRAVITY * delta
		_fall_peak = maxf(_fall_peak, -velocity.y)
	move_and_slide()
	if on_floor and is_on_wall() and hv.length() > 0.5 and not swimming:
		_step_up(Vector3(hv.x, 0, hv.y))
	if is_on_floor() and not on_floor:
		if _fall_peak > 9.0:
			_snd("jump_land", -6.0)
			landed.emit()
		# Dégâts de chute (à travers l'armure) au-delà de ~6 m.
		if _fall_peak > FALL_SAFE and not arsenal.has_perk("amorti"):
			sante.take((_fall_peak - FALL_SAFE) * FALL_DAMAGE, "jambes", "chute", true)
			_snd("hurt", -2.0)
		_fall_peak = 0.0
	_footsteps(delta)


## Monte les petites marches (bord de quai, muret bas, seuil) sans avoir à sauter, comme le
## maillage de navigation des bots le suppose (0,45 m au plus).
func _step_up(dir: Vector3) -> void:
	var step := dir.normalized() * 0.25
	for h in [0.25, 0.45]:
		var t := global_transform
		if not test_move(t, Vector3(0, h, 0)) and not test_move(t.translated(Vector3(0, h, 0)), step):
			global_position += Vector3(0, h, 0) + step
			velocity.y = 0.0
			return


## Nage : on nage quand l'eau est assez profonde pour ne plus avoir pied (avec une marge entre
## l'entrée et la sortie, sinon on alterne nage et marche à la surface).
func _update_swimming(was: bool) -> bool:
	if global_position.y > WATER_LEVEL + 0.45:
		return false
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.6, 0), global_position - Vector3(0, 4.0, 0), G.L_WORLD, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var floor_y: float = hit.position.y if hit else -100.0
	var depth := WATER_LEVEL - floor_y
	if was:
		return depth > 1.15
	return depth > 1.35 and global_position.y < WATER_LEVEL + 0.05


## Sol sous les pieds (pour le bruit des pas) : le terrain, un sol construit, ou de l'eau.
func _detect_floor() -> void:
	if global_position.y < WATER_LEVEL + 0.35:
		_floor_kind = "eau"
		return
	for k in get_slide_collision_count():
		var c := get_slide_collision(k)
		if c.get_normal().y > 0.6:
			var col := c.get_collider() as Node
			_floor_kind = "terre" if col and col.name == "Sol" else "dur"
			return


func _footsteps(delta: float) -> void:
	var hs := Vector2(velocity.x, velocity.z).length()
	if swimming:
		_stroke += delta * (1.0 if hs > 1.0 else 0.0)
		if _stroke > 1.1:
			_stroke = 0.0
			_snd("brasse", -16.0, randf_range(0.9, 1.1))
		return
	if is_on_floor() and hs > 1.0 and posture != Posture.COUCHE:
		_step += hs * delta
		if _step > (2.4 if sprinting else 1.9):
			_step = 0.0
			_detect_floor()
			var vol := -17.0
			if sprinting:
				vol = -14.0
			elif posture == Posture.ACCROUPI:
				vol = -25.0
			_snd("pas_%s_%d" % [_floor_kind, randi_range(1, 4)], vol, randf_range(0.92, 1.08))


func _end_tac() -> void:
	if tac_left > 0.0:
		tac_left = 0.0
		tac_cooldown = TAC_COOLDOWN


# ------------------------------------------------------------------------------------------------
# Glissade et annulation
# ------------------------------------------------------------------------------------------------
func _start_slide(hv: Vector2) -> void:
	var boost := SLIDE_BOOST if since_slide >= SLIDE_REBOOST else 0.0
	slide_dir = hv.normalized()
	slide_speed = minf(hv.length() + boost, SLIDE_MAX)
	slide_t = 0.0
	sprinting = false
	if tac_left > 0.0:
		tac_left = 0.0
		tac_cooldown = TAC_COOLDOWN
	_set_posture(Posture.ACCROUPI, true)
	_set_etat(Etat.GLISSADE)
	_snd("jump_land", -10.0, 0.6)


func _sim_glissade(i: Intentions, delta: float) -> void:
	slide_t += delta
	# Annuler : accroupi (on se relève en sprint, l'élan est gardé et le sprint tactique
	# se recharge) ou saut (on saute avec l'élan de la glissade).
	if slide_t >= SLIDE_CANCEL_MIN and (i.crouch or i.jump):
		if _fits(global_position, HEIGHTS[Posture.DEBOUT]):
			_set_posture(Posture.DEBOUT)
			_set_etat(Etat.SOL)
			since_slide = 0.0
			velocity.x = slide_dir.x * slide_speed
			velocity.z = slide_dir.y * slide_speed
			if i.jump:
				velocity.y = JUMP
				_air_t = 1.0
				sprinting = true
			else:
				sprinting = true
				tac_cooldown = 0.0
			return
	if slide_t > 0.2:
		slide_speed -= SLIDE_FRICTION * delta
	if is_on_floor():
		# Dans une descente, on prend de la vitesse ; en montée on en perd.
		var n := get_floor_normal()
		slide_speed += GRAVITY * Vector2(n.x, n.z).dot(slide_dir) * 0.9 * delta
	var wish := _wish_dir(i)
	if wish.length() > 0.2 and wish.normalized().dot(slide_dir) > 0.0:
		slide_dir = slide_dir.slerp(wish.normalized(), minf(1.0, SLIDE_STEER * delta))
	slide_speed = clampf(slide_speed, 0.0, SLIDE_MAX + 3.0)
	velocity.x = slide_dir.x * slide_speed
	velocity.z = slide_dir.y * slide_speed
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()
	var real := Vector2(get_real_velocity().x, get_real_velocity().z).length()
	slide_speed = minf(slide_speed, real + 0.6)   # un mur arrête la glissade
	_air_t = 0.0 if is_on_floor() else _air_t + delta
	if slide_speed < SLIDE_END_SPEED or (slide_t > SLIDE_MAX_TIME and slide_speed < SPRINT + 1.0) or _air_t > 0.25:
		_set_etat(Etat.SOL)
		since_slide = 0.0
		if _air_t > 0.25:
			_set_posture(Posture.DEBOUT)


# ------------------------------------------------------------------------------------------------
# Escalade de rebords
# ------------------------------------------------------------------------------------------------
## Cherche un rebord franchissable devant soi : {"to": position des pieds, "posture": ...}.
func find_ledge() -> Dictionary:
	var space := get_world_3d().direct_space_state
	var f2 := _forward2()
	var fwd := Vector3(f2.x, 0, f2.y)
	var feet := global_position
	var wall: Dictionary = {}
	for h in [0.55, 1.1, 1.7, 2.3]:
		var q := PhysicsRayQueryParameters3D.create(feet + Vector3(0, h, 0), feet + Vector3(0, h, 0) + fwd * 0.95, G.L_WORLD, [get_rid()])
		wall = space.intersect_ray(q)
		if wall:
			break
	if wall.is_empty() or absf(wall.normal.y) > 0.5:
		return {}
	var probe := Vector3(wall.position.x, feet.y, wall.position.z) + fwd * 0.45
	var q2 := PhysicsRayQueryParameters3D.create(probe + Vector3(0, MANTLE_MAX + 0.5, 0), probe + Vector3(0, 0.2, 0), G.L_WORLD, [get_rid()])
	var top := space.intersect_ray(q2)
	if top.is_empty() or top.normal.y < 0.7:
		return {}
	var rise: float = top.position.y - feet.y
	if rise < MANTLE_MIN or rise > MANTLE_MAX:
		return {}
	var to := Vector3(probe.x, top.position.y + 0.04, probe.z) + fwd * 0.1
	if _fits(to, HEIGHTS[Posture.DEBOUT]):
		return {"to": to, "posture": Posture.DEBOUT}
	if _fits(to, HEIGHTS[Posture.ACCROUPI]):
		return {"to": to, "posture": Posture.ACCROUPI}
	return {}


func _try_mantle() -> bool:
	if posture == Posture.COUCHE:
		return false
	var l := find_ledge()
	if l.is_empty():
		return false
	_mantle_from = global_position
	_mantle_to = l.to
	_mantle_posture = l.posture
	_mantle_sprint = sprinting
	_mantle_t = 0.0
	_mantle_dur = 0.22 + 0.12 * (_mantle_to.y - _mantle_from.y)
	velocity = Vector3.ZERO
	_set_etat(Etat.ESCALADE)
	_snd("pas_dur_%d" % randi_range(1, 4), -12.0, 0.8)
	return true


func _sim_escalade(delta: float) -> void:
	_mantle_t += delta
	var k := clampf(_mantle_t / _mantle_dur, 0.0, 1.0)
	# On monte d'abord (70 %), puis on passe par-dessus.
	var up := ease(clampf(k / 0.7, 0.0, 1.0), 0.6)
	var over := ease(clampf((k - 0.55) / 0.45, 0.0, 1.0), 1.6)
	var p := _mantle_from.lerp(_mantle_to, over)
	p.y = lerpf(_mantle_from.y, _mantle_to.y, up)
	global_position = p
	if k >= 1.0:
		_set_etat(Etat.SOL)
		_set_posture(_mantle_posture, true)
		sprinting = _mantle_sprint and _mantle_posture == Posture.DEBOUT
		var f2 := _forward2() * (4.0 if sprinting else 1.5)
		velocity = Vector3(f2.x, 0, f2.y)


# ------------------------------------------------------------------------------------------------
# Tyrolienne
# ------------------------------------------------------------------------------------------------
func start_zip(t: Tyrolienne, monte: bool) -> void:
	if etat != Etat.SOL:
		return
	_zip_pts = t.trajet(monte)
	_zip_s = 0.0
	_zip_up = monte
	sprinting = false
	_end_tac()
	_set_posture(Posture.DEBOUT, true)
	velocity = Vector3.ZERO
	_set_etat(Etat.TYROLIENNE)
	_snd("tyrolienne", -8.0, 1.0 if monte else 1.12)


func is_zipping() -> bool:
	return etat == Etat.TYROLIENNE


## Le long du câble (le premier ou le dernier petit segment, sur la plateforme, plus lentement).
## Sauter lâche le câble.
func _sim_tyrolienne(i: Intentions, delta: float) -> void:
	var a := _zip_pts[0]
	var cable_from := 1 if _zip_up else 2      # segment du câble : bas→bord (montée) ou bord→bas
	var seg := 0
	var acc := 0.0
	var s := _zip_s
	while seg < _zip_pts.size() - 2 and s > _zip_pts[seg].distance_to(_zip_pts[seg + 1]):
		s -= _zip_pts[seg].distance_to(_zip_pts[seg + 1])
		acc += _zip_pts[seg].distance_to(_zip_pts[seg + 1])
		seg += 1
	var on_cable := (seg + 1) == cable_from
	var speed := (Tyrolienne.VITESSE_MONTEE if _zip_up else Tyrolienne.VITESSE_DESCENTE) if on_cable else Tyrolienne.VITESSE_BORD
	if on_cable:
		speed *= clampf(0.35 + s / 4.0, 0.35, 1.0)    # démarrage
	var dir := (_zip_pts[seg + 1] - _zip_pts[seg]).normalized()
	if i.jump and on_cable:
		_set_etat(Etat.SOL)
		velocity = Vector3(dir.x, 0, dir.z) * speed * 0.6
		_air_t = 1.0
		return
	_zip_s += speed * delta
	var total := 0.0
	for k in _zip_pts.size() - 1:
		total += _zip_pts[k].distance_to(_zip_pts[k + 1])
	if _zip_s >= total:
		global_position = _zip_pts[-1] + Vector3(0, 0.05, 0)
		velocity = Vector3.ZERO
		_set_etat(Etat.SOL)
		return
	var p := a
	var left := _zip_s
	for k in _zip_pts.size() - 1:
		var l := _zip_pts[k].distance_to(_zip_pts[k + 1])
		if left <= l:
			p = _zip_pts[k].lerp(_zip_pts[k + 1], left / maxf(l, 0.001))
			break
		left -= l
	velocity = dir * speed
	global_position = p


# ------------------------------------------------------------------------------------------------
# Chute libre, parachute, avion
# ------------------------------------------------------------------------------------------------
## Hauteur au-dessus du sol ou de la mer.
func height_above_ground() -> float:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.2, 0), global_position - Vector3(0, 600, 0), G.L_WORLD, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var ground := maxf(hit.position.y if hit else -600.0, 0.0)
	return global_position.y - ground


func board(plane: Avion) -> void:
	avion = plane
	# On regarde vers l'avant de l'avion, un peu vers le bas : l'île défile devant.
	var d := plane.velocity_vector()
	_yaw = atan2(-d.x, -d.z)
	_pitch = deg_to_rad(-24.0)
	rotation.y = _yaw
	sprinting = false
	_set_posture(Posture.DEBOUT, true)
	_set_etat(Etat.AVION)
	velocity = Vector3.ZERO
	chute_opened_once = false


## Saut dans le vide depuis l'avion, ou largage de réapparition.
func start_freefall(from: Vector3, initial_velocity := Vector3.ZERO) -> void:
	global_position = from
	velocity = initial_velocity
	chute_opened_once = false
	_set_posture(Posture.DEBOUT, true)
	_set_etat(Etat.CHUTE_LIBRE)
	avion = null


func _sim_avion(i: Intentions) -> void:
	if not is_instance_valid(avion):
		start_freefall(global_position)
		return
	global_position = avion.ramp_position()
	if i.jump or avion.must_jump():
		var v := avion.velocity_vector() * 0.3
		start_freefall(avion.global_position + avion.global_basis * Vector3(0, -3.0, 14.0), v)
		_snd("sortie_avion", -8.0, randf_range(0.95, 1.05))


func _sim_chute_libre(i: Intentions, delta: float) -> void:
	var dive := clampf(-_pitch / deg_to_rad(75.0), 0.0, 1.0)   # regarder vers le bas = plonger
	velocity.y = move_toward(velocity.y, -lerpf(FREE_V_MIN, FREE_V_MAX, dive), 22.0 * delta)
	var wish := _wish_dir(i)
	var hv := Vector2(velocity.x, velocity.z).move_toward(wish * FREE_H * (1.0 - dive * 0.5), 10.0 * delta)
	velocity.x = hv.x
	velocity.z = hv.y
	move_and_slide()
	var agl := height_above_ground()
	if is_on_floor() or global_position.y < 0.2:
		_land()
		return
	if i.jump and agl > 3.0:
		_open_chute()
	elif agl < (AUTO_DEPLOY_LATE if chute_opened_once else AUTO_DEPLOY):
		_open_chute()


func _open_chute() -> void:
	chute_opened_once = true
	sprinting = false
	_end_tac()
	_set_posture(Posture.DEBOUT, true)
	_set_etat(Etat.PARACHUTE)
	_snd("voile", -6.0, randf_range(0.95, 1.05))


func _sim_parachute(i: Intentions, delta: float) -> void:
	var push := clampf(-i.move.y, 0.0, 1.0)
	var brake := clampf(i.move.y, 0.0, 1.0)
	velocity.y = move_toward(velocity.y, -(CHUTE_V + 3.0 * push - 1.5 * brake), 18.0 * delta)
	var f2 := _forward2()
	var right := Vector2(-f2.y, f2.x)
	var dir := (f2 + right * i.move.x * 0.7).normalized()
	var hv := Vector2(velocity.x, velocity.z).move_toward(dir * (CHUTE_H + 6.0 * push - 5.0 * brake), 7.0 * delta)
	velocity.x = hv.x
	velocity.z = hv.y
	if i.crouch:
		_set_etat(Etat.CHUTE_LIBRE)   # couper le parachute (on peut le rouvrir)
		return
	move_and_slide()
	if is_on_floor() or global_position.y < 0.2:
		_land()


func _land() -> void:
	_set_etat(Etat.SOL)
	_fall_peak = 0.0
	velocity.y = 0.0
	_snd("jump_land", -4.0)
	landed.emit()


func _sim_drone(i: Intentions, delta: float) -> void:
	var fast := i.sprint_held or sprinting
	if i.sprint:
		sprinting = not sprinting
	var speed := DRONE_FAST if fast else DRONE_SPEED
	var dir := cam.global_basis * Vector3(i.move.x, 0, i.move.y)
	dir.y += (1.0 if i.jump_held else 0.0) - (1.0 if i.crouch_held else 0.0)
	velocity = velocity.lerp(dir.limit_length(1.0) * speed, minf(1.0, delta * 6.0))
	global_position += velocity * delta
	global_position.y = clampf(global_position.y, -8.0, 260.0)
	var limit := float(G.data.get("monde", 640)) / 2.0 + 150.0
	global_position.x = clampf(global_position.x, -limit, limit)
	global_position.z = clampf(global_position.z, -limit, limit)


# ------------------------------------------------------------------------------------------------
# Caméra
# ------------------------------------------------------------------------------------------------
func _update_camera(delta: float) -> void:
	var eye: float = EYES[posture]
	var fov := BASE_FOV
	var roll := 0.0
	match etat:
		Etat.GLISSADE:
			eye = 0.85
			roll = -4.0
			fov += 6.0
		Etat.CHUTE_LIBRE:
			fov += 12.0 * clampf(-velocity.y / FREE_V_MAX, 0.0, 1.0)
		Etat.AVION:
			fov += 4.0
		Etat.TYROLIENNE:
			fov += 6.0
	if swimming:
		eye = 1.45
	if etat == Etat.SOL and sprinting:
		fov += 10.0 if tac_left > 0.0 else 4.0
	var w := arsenal.current()
	if not w.is_empty() and arsenal.ads > 0.0:
		fov = lerpf(fov, float(Armes.de(w).ads_fov), arsenal.ads)
	head.position.y = lerpf(head.position.y, eye, minf(1.0, 14.0 * delta))
	cam.fov = lerpf(cam.fov, fov, minf(1.0, (20.0 if arsenal.ads > 0.0 else 8.0) * delta))
	_roll = lerpf(_roll, roll, minf(1.0, 10.0 * delta))
	head.rotation = Vector3(_pitch, 0, deg_to_rad(_roll))


# ------------------------------------------------------------------------------------------------
# Voile du parachute (visible en levant les yeux)
# ------------------------------------------------------------------------------------------------
func _make_canopy() -> void:
	canopy = Node3D.new()
	canopy.name = "Voile"
	add_child(canopy)
	canopy.position = Vector3(0, 4.6, -2.0)
	var cols := [Color(0.95, 0.45, 0.12), Color(0.95, 0.93, 0.88)]
	var cells := 7
	for k in cells:
		var a := lerpf(-0.75, 0.75, (k + 0.5) / cells)
		var seg := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.25, 0.12, 2.6)
		seg.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = cols[k % 2]
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		seg.material_override = m
		canopy.add_child(seg)
		seg.position = Vector3(sin(a) * 4.2, cos(a) * 1.6 - 1.6, 0)
		seg.rotation.z = -a * 0.9
	var line_mat := StandardMaterial3D.new()
	line_mat.albedo_color = Color(0.15, 0.15, 0.15)
	for side in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			var ln := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.03, 5.4, 0.03)
			ln.mesh = bm
			ln.material_override = line_mat
			canopy.add_child(ln)
			ln.position = Vector3(side * 1.6, -3.3, z * 0.9)
			ln.rotation.z = side * 0.42
	canopy.visible = false
