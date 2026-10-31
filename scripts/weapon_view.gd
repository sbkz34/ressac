class_name WeaponView
extends Node3D
## Bras et arme à la première personne, attachés à la caméra (repris de Dernière Vague, sans le
## couteau, les boissons, les grenades, les armes doubles ni les armes de mêlée). Purement visuel :
## l'arsenal du joueur dit ce qui se passe (tir, rechargement, changement d'arme) et la vue anime.

var _gun: Node3D
var _gun_holder: Node3D
var _arms: Node3D
var _flash: MeshInstance3D
var _flash_light: OmniLight3D
var _kind := "pistol"
var _muzzle := Vector3.ZERO

var ads := 0.0
var hidden_by_scope := false
var _kick := 0.0
var _kick_rot := 0.0
var _bob := 0.0
var _sway := Vector2.ZERO
var _flash_t := 0.0
var shown := ""           # clé de l'arme affichée
var _land := 0.0          # creux à la réception d'un saut ou d'une chute
var _land_v := 0.0
var _roll_kick := 0.0     # recul : petite rotation de côté
var _breath := 0.0
var strafe := 0.0         # vitesse latérale (m/s, + à droite) : l'arme penche un peu
var vertical := 0.0       # vitesse verticale : l'arme flotte en l'air
var _anim := ""          # "", "reload", "swap", "knife", "drink"
var _anim_t := 0.0
var _anim_len := 1.0
var _pending_weapon: Dictionary = {}
var _pending_set := false
var _roles := {}           # moving parts: "mag", "bolt", "pump", "barrel", "cyl"
var _rest := {}
var _left: Node3D
var _left_rest := Vector3.ZERO
var _top := 0.1
var _reload_empty := false
var _marks: Array = []     # [phase 0..1, sound] played during the reload
var _mark_i := 0
var _skin: StandardMaterial3D
var _sleeve: StandardMaterial3D
var _glove: StandardMaterial3D
# Ultimate akimbo: a second gun in the left hand.
var _gun2: Node3D
var _flash2: MeshInstance3D
var _flash_two := false
var _akimbo := false
var _flash_mat: StandardMaterial3D
# Melee weapons: swing animation (right or left hand).
var _melee := false
var _heavy := false
var _swing_on := false
var _swing_left := false
var _swing_t := 0.0
var _swing_len := 0.5
var _swing_wf := 0.3

const ONE_HAND := ["pistol", "revolver", "uzi"]


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_skin = StandardMaterial3D.new()
	_skin.albedo_color = Color(0.72, 0.55, 0.42)
	_skin.roughness = 0.8
	_sleeve = StandardMaterial3D.new()
	_sleeve.albedo_color = Color(0.17, 0.2, 0.14)
	_sleeve.roughness = 0.9
	_glove = StandardMaterial3D.new()
	_glove.albedo_color = Color(0.08, 0.07, 0.06)
	_glove.roughness = 0.9
	_gun_holder = Node3D.new()
	add_child(_gun_holder)

	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.albedo_color = Color(1.0, 0.75, 0.3, 0.9)
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	_flash = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.18, 0.18)
	_flash.mesh = q
	_flash.material_override = fm
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash.visible = false
	_flash_mat = fm
	_flash2 = MeshInstance3D.new()
	_flash2.mesh = q
	_flash2.material_override = fm
	_flash2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash2.visible = false
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color(1.0, 0.75, 0.4)
	_flash_light.light_energy = 2.5
	_flash_light.omni_range = 5.0
	_flash_light.visible = false
	add_child(_flash_light)



func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.position = pos
	return mi


## Clé de l'arme affichée (modèle, rareté, accessoires, camouflage).
static func key_of(w: Dictionary) -> String:
	if w.is_empty():
		return ""
	return "%s|%d|%s|%s" % [w.id, int(w.get("rarete", 0)), ",".join(PackedStringArray(w.get("acc", []))), Progression.camo(String(w.id))]


## Vrai quand aucune animation ne doit encore changer l'arme affichée.
func settled() -> bool:
	return not _pending_set and _anim != "swap"


func _build(w: Dictionary) -> void:
	shown = key_of(w)
	if _gun:
		_gun.queue_free()
		_gun = null
	if _gun2:
		_gun2.queue_free()
		_gun2 = null
	if _flash.get_parent():
		_flash.get_parent().remove_child(_flash)
	if _flash2.get_parent():
		_flash2.get_parent().remove_child(_flash2)
	_swing_on = false
	if w.is_empty():
		return
	var sh := GunShapes.shape(w.id)
	_kind = sh.kind
	_akimbo = false
	_melee = false
	_heavy = false
	var mats := Armes.materiaux(int(w.get("rarete", 0)), Progression.camo(String(w.id)))
	var model_scale := 1.0
	_gun = GunShapes.build_model(w.id, mats, model_scale, w.get("acc", []))
	_gun_holder.add_child(_gun)
	_muzzle = _gun.get_meta("muzzle")
	_top = _gun.get_meta("top")
	_roles.clear()
	_rest.clear()
	for role in ["mag", "bolt", "pump", "barrel", "cyl"]:
		var n := _gun.get_node_or_null(role) as Node3D
		if n:
			_roles[role] = n
			_rest[role] = n.transform
	_left = null
	_gun.add_child(_flash)
	_flash.position = _muzzle + Vector3(0, 0, -0.06)
	# Right hand on the grip, forearm going down and back; left hand forward on the gun
	# (or under the right hand for pistols). Akimbo and melee: one hand per weapon.
	_hand(_gun, false)
	var length: float = _gun.get_meta("length")
	if _akimbo:
		_gun2 = GunShapes.build_model(w.id, mats, model_scale)
		_gun_holder.add_child(_gun2)
		_gun2.position = Vector3(-2.0 * hip_pos().x, 0, 0)
		_hand(_gun2, true)
		_gun2.add_child(_flash2)
		_flash2.position = _muzzle + Vector3(0, 0, -0.06)
	elif _melee:
		pass
	elif _kind in ONE_HAND:
		_box(_gun, Vector3(-0.045, -0.05, 0.03), Vector3(0.06, 0.07, 0.08), _glove)
	else:
		var left := Node3D.new()
		_gun.add_child(left)
		left.position = Vector3(-0.02, -0.035, -min(0.42, length * 0.45))
		left.rotation = Vector3(0, -0.3, 0.3)
		_left = left
		_left_rest = left.position
		_box(left, Vector3(0, 0, 0), Vector3(0.07, 0.075, 0.09), _glove)
		var l_arm := _box(left, Vector3(-0.05, -0.08, 0.14), Vector3(0.075, 0.075, 0.24), _skin)
		l_arm.rotation.x = 0.5
		var l_sleeve := _box(left, Vector3(-0.08, -0.16, 0.3), Vector3(0.095, 0.095, 0.22), _sleeve)
		l_sleeve.rotation.x = 0.5


## Hand on the grip with the forearm going down and back (mirrored for the left hand).
func _hand(gun: Node3D, mirror: bool) -> void:
	var sx := -1.0 if mirror else 1.0
	var hand := Node3D.new()
	gun.add_child(hand)
	_box(hand, Vector3(0.0, -0.03, 0.02), Vector3(0.07, 0.085, 0.09), _glove)
	var arm := _box(hand, Vector3(0.03 * sx, -0.12, 0.13), Vector3(0.075, 0.075, 0.24), _skin)
	arm.rotation.x = 0.6
	var sleeve := _box(hand, Vector3(0.05 * sx, -0.22, 0.27), Vector3(0.095, 0.095, 0.22), _sleeve)
	sleeve.rotation.x = 0.6


## Launcher: the warhead shows only while a rocket is loaded.
func set_loaded(on: bool) -> void:
	if _kind == "launcher" and _anim != "reload" and _roles.has("mag"):
		var n: Node3D = _roles.mag
		if is_instance_valid(n):
			n.visible = on


func set_weapon(w: Dictionary, animate := true) -> void:
	if not animate or _gun == null:
		# Une arme posée directement annule un changement d'arme en cours (sinon l'ancienne
		# reviendrait à la fin de l'animation, par exemple après une mort et un redéploiement).
		_pending_set = false
		_pending_weapon = {}
		_build(w)
		_anim = ""
		return
	_pending_weapon = w
	_pending_set = true
	play_anim("swap", 0.5)


## Arrête une animation sans changement d'arme en attente (plaque annulée).
func stop_anim() -> void:
	if _anim == "swap" and not _pending_set:
		_anim = ""


func play_anim(name: String, length: float) -> void:
	_reset_parts()
	_anim = name
	_anim_t = 0.0
	_anim_len = max(0.05, length)


## Reload with moving parts and timed sounds. empty: the chamber was empty (bolt / pump at the
## end); shells: rounds to load for weapons loaded one by one.
func play_reload(length: float, empty: bool, shells: int) -> void:
	play_anim("reload", length)
	_reload_empty = empty
	_marks.clear()
	_mark_i = 0
	match _kind:
		"shotgun":
			var n := clampi(shells, 1, 6)
			for i in n:
				_marks.append([0.15 + 0.65 * (i + 0.5) / n, "shell_in"])
			if empty:
				_marks.append([0.88, "pump"])
		"double":
			_marks = [[0.06, "break_open"], [0.42, "shell_in"], [0.56, "shell_in"], [0.82, "break_close"]]
		"revolver":
			_marks = [[0.06, "cylinder"], [0.38, "shell_in"], [0.5, "shell_in"], [0.62, "shell_in"], [0.84, "break_close"]]
		"wonder":
			_marks = [[0.08, "energy_reload"]]
		"sniper":
			_marks = [[0.06, "bolt"], [0.25, "mag_out"], [0.58, "mag_in"], [0.82, "bolt"]]
		_:
			_marks = [[0.12, "mag_out"], [0.56, "mag_in"]]
			if empty:
				_marks.append([0.76, "bolt"])


func _reset_parts() -> void:
	for role in _roles:
		var n: Node3D = _roles[role]
		if is_instance_valid(n):
			n.transform = _rest[role]
			n.visible = true
	if _left and is_instance_valid(_left):
		_left.position = _left_rest


static func _ramp(p: float, a: float, b: float) -> float:
	return clampf((p - a) / (b - a), 0.0, 1.0)


## Moves the weapon's parts for reload phase p (0..1); returns extra [position, rotation].
func _reload_pose(p: float) -> Array:
	var hold := _ramp(p, 0.0, 0.12) * (1.0 - _ramp(p, 0.88, 1.0))
	# Muzzle up, turned and rolled towards the player: the magazine well faces the camera.
	var pos := Vector3(-0.05, -0.01, 0.03) * hold
	var rot := Vector3(0.22, 0.22, 0.32) * hold
	while _mark_i < _marks.size() and p >= _marks[_mark_i][0]:
		G.play(_marks[_mark_i][1], -3.0, randf_range(0.95, 1.05))
		_mark_i += 1
	if _akimbo:
		# Both guns go down out of view and come back loaded.
		return [Vector3(0, -0.32, 0.08) * hold, Vector3(-0.6, 0, 0) * hold]
	match _kind:
		"shotgun":
			rot.z += 0.35 * hold
			for m in _marks:
				if m[1] == "shell_in":
					var k := 1.0 - absf(p - m[0]) / 0.05
					if k > 0.0:
						rot.x += 0.06 * k
			if _roles.has("pump") and _reload_empty:
				var back := _ramp(p, 0.86, 0.9) * (1.0 - _ramp(p, 0.92, 0.97))
				_roles.pump.transform = _rest.pump.translated_local(Vector3(0, 0, 0.09 * back))
			if _left:
				_left.position = _left_rest.lerp(Vector3(-0.05, -0.02, -0.15), hold * (1.0 - _ramp(p, 0.84, 0.88)))
		"double":
			var open := _ramp(p, 0.04, 0.16) * (1.0 - _ramp(p, 0.78, 0.86))
			if _roles.has("barrel"):
				var t: Transform3D = _rest.barrel
				_roles.barrel.transform = t.rotated_local(Vector3.RIGHT, -0.55 * open)
			rot.x += 0.25 * open
		"revolver":
			var out := _ramp(p, 0.04, 0.14) * (1.0 - _ramp(p, 0.8, 0.88))
			if _roles.has("cyl"):
				_roles.cyl.transform = _rest.cyl.translated_local(Vector3(-0.045 * out, 0, 0))
			rot.z += 0.3 * out
		"wonder":
			var lift := _ramp(p, 0.08, 0.3) * (1.0 - _ramp(p, 0.55, 0.75))
			if _roles.has("mag"):
				_roles.mag.transform = _rest.mag.translated_local(Vector3(0.06 * lift, 0.14 * lift, 0))
				_roles.mag.visible = lift < 0.95
		_:
			# Magazine: drops out, gone for a moment, a fresh one slides back in.
			if _roles.has("mag"):
				var drop := _ramp(p, 0.12, 0.3)
				var insert := _ramp(p, 0.42, 0.56)
				var off := 0.0
				if p < 0.42:
					off = -0.32 * drop
				else:
					off = -0.32 * (1.0 - insert)
				_roles.mag.transform = _rest.mag.translated_local(Vector3(0, off, 0.04 * absf(off)))
				_roles.mag.visible = not (p > 0.3 and p < 0.42)
				if _left:
					# The left hand goes for the new magazine and pushes it in.
					var reach := _ramp(p, 0.1, 0.22) * (1.0 - _ramp(p, 0.6, 0.72))
					var mag_pos: Vector3 = _rest.mag.origin + Vector3(-0.03, -0.06 + off, 0.03)
					_left.position = _left_rest.lerp(mag_pos, reach)
			var cock := 0.0
			if _kind == "sniper":
				cock = _ramp(p, 0.04, 0.1) * (1.0 - _ramp(p, 0.12, 0.18)) + _ramp(p, 0.8, 0.86) * (1.0 - _ramp(p, 0.88, 0.94))
			elif _reload_empty:
				cock = _ramp(p, 0.74, 0.79) * (1.0 - _ramp(p, 0.8, 0.84))
			if _roles.has("bolt") and cock > 0.0:
				_roles.bolt.transform = _rest.bolt.translated_local(Vector3(0, 0, 0.06 * cock))
			rot.y += 0.12 * cock
	return [pos, rot]


func shot(kick: float, guns := 1) -> void:
	_flash_two = guns >= 2
	_kick = min(_kick + 0.03 + kick * 0.01, 0.12)
	_kick_rot = min(_kick_rot + 0.04 + kick * 0.02, 0.35)
	_roll_kick = clampf(_roll_kick + randf_range(-1.0, 1.0) * (0.02 + kick * 0.01), -0.12, 0.12)
	_flash_t = 0.05
	_flash.rotation.z = randf() * TAU
	# Smaller, dimmer flash when aiming: it sits right in front of the eye.
	_flash.scale = Vector3.ONE * randf_range(0.8, 1.3) * lerpf(1.0, 0.3, ads)
	_flash2.rotation.z = randf() * TAU
	_flash2.scale = _flash.scale
	_flash_light.light_energy = lerpf(2.5, 0.8, ads)


func muzzle_global(left := false) -> Vector3:
	if left and _gun2:
		return _gun2.to_global(_muzzle)
	if _gun:
		return _gun.to_global(_muzzle)
	return global_position


## Mouvement de la vue (degrés) : l'arme traîne un peu derrière, puis revient.
func add_sway(look_delta: Vector2) -> void:
	_sway -= look_delta * 0.006
	_sway = _sway.limit_length(0.09)


## Réception : l'arme plonge puis remonte, d'autant plus que la chute était rapide.
func land(speed: float) -> void:
	_land_v -= clampf(speed * 0.012, 0.02, 0.12) * 10.0


func hip_pos() -> Vector3:
	if _melee:
		return Vector3(0.28, -0.32, -0.5)
	if _akimbo:
		return Vector3(0.21, -0.17, -0.5)
	if _kind == "launcher":
		return Vector3(0.22, -0.19, -0.55)
	if _kind in ONE_HAND:
		return Vector3(0.17, -0.2, -0.5)
	if _kind == "wonder":
		return Vector3(0.2, -0.25, -0.46)
	return Vector3(0.19, -0.23, -0.36)


## Aiming: the gun is centred with its top edge just below the crosshair, so the target stays
## visible (the sniper shows its scope instead).
func ads_pos() -> Vector3:
	if _melee or _akimbo:
		return hip_pos()
	if _kind == "sniper":
		return Vector3(0.0, -0.13, -0.24)
	var z := -0.42 if _kind in ONE_HAND else -0.3
	return Vector3(0.0, -(_top + 0.018), z)


func update_view(delta: float, speed: float, sprinting: bool, on_floor: bool) -> void:
	var base := hip_pos().lerp(ads_pos(), ads)
	var rot := Vector3.ZERO
	# Walk bob.
	if on_floor and speed > 0.5:
		_bob += delta * speed * (1.3 if sprinting else 1.9)
	var bob_amt := (0.012 if not sprinting else 0.03) * (1.0 - ads * 0.85) * clampf(speed / 4.0, 0.0, 1.5)
	base += Vector3(cos(_bob) * bob_amt, abs(sin(_bob)) * bob_amt, 0)
	if sprinting:
		base += Vector3(-0.05, -0.04, 0.05)
		rot += Vector3(-0.25, 0.6, 0.15)
		# Au sprint, l'arme se balance plus franchement d'un côté à l'autre.
		rot.z += sin(_bob) * 0.06
	# Respiration au repos (très discrète en visant).
	_breath += delta
	var still := 1.0 - clampf(speed / 3.0, 0.0, 1.0)
	base.y += sin(_breath * 1.6) * 0.004 * still * (1.0 - ads * 0.7)
	rot.x += sin(_breath * 0.8) * 0.01 * still * (1.0 - ads * 0.8)
	# Déplacement latéral : l'arme penche ; en l'air elle flotte.
	rot.z += clampf(-strafe * 0.018, -0.1, 0.1) * (1.0 - ads * 0.7)
	if not on_floor:
		base.y += clampf(-vertical * 0.004, -0.04, 0.04)
	# Réception (ressort amorti).
	_land_v += (-_land * 120.0 - _land_v * 14.0) * delta
	_land += _land_v * delta
	base.y += _land * (1.0 - ads * 0.6)
	rot.x += _land * 1.5 * (1.0 - ads * 0.6)
	# Recoil.
	_kick = move_toward(_kick, 0.0, delta * 0.6)
	_kick_rot = move_toward(_kick_rot, 0.0, delta * 3.0)
	_roll_kick = move_toward(_roll_kick, 0.0, delta * 0.8)
	base.z += _kick
	rot.x += _kick_rot
	rot.z += _roll_kick
	# Sway follows the look motion and settles back.
	_sway = _sway.lerp(Vector2.ZERO, clamp(delta * 8.0, 0.0, 1.0))
	rot.y += _sway.x * (1.0 - ads * 0.7)
	rot.x += _sway.y * (1.0 - ads * 0.7)
	rot.z += _sway.x * 0.6 * (1.0 - ads * 0.7)
	# One-shot animations.
	if _anim != "":
		_anim_t += delta
		var p: float = clamp(_anim_t / _anim_len, 0.0, 1.0)
		var dip := sin(p * PI)
		match _anim:
			"reload":
				var pose := _reload_pose(p)
				base += pose[0]
				rot += pose[1]
			"swap":
				base += Vector3(0, -0.45, 0.1) * dip
				rot += Vector3(-0.6, 0, 0) * dip
				if p >= 0.5 and _pending_set:
					_build(_pending_weapon)
					_pending_set = false
		if p >= 1.0:
			if _anim == "reload":
				_reset_parts()
			if _anim == "swap" and _pending_set:
				_build(_pending_weapon)
				_pending_set = false
			_anim = ""
	_gun_holder.position = _gun_holder.position.lerp(base, clamp(delta * 18.0, 0.0, 1.0))
	_gun_holder.rotation = _gun_holder.rotation.lerp(rot, clamp(delta * 14.0, 0.0, 1.0))
	_gun_holder.visible = not hidden_by_scope
	# Muzzle flash.
	if _flash_t > 0.0:
		_flash_t -= delta
		_flash.visible = true
		_flash2.visible = _flash_two and _gun2 != null
		_flash_light.visible = true
		_flash_light.global_position = muzzle_global()
	else:
		_flash.visible = false
		_flash2.visible = false
		_flash_light.visible = false
