class_name Cible
extends Node3D
## Mannequin d'entraînement : mêmes zones de touche, même santé et même armure (3 plaques)
## qu'un adversaire. Il peut faire des allers-retours, tombe quand il est éliminé et se relève
## au bout de quelques secondes avec une armure neuve. Les bots du jalon 4 reprendront ses zones.

const RESPAWN := 3.0

var sante: Sante
var patrol := 0.0          # demi-longueur de l'aller-retour (0 : immobile)
var patrol_speed := 2.4
var plates := 3
var _body: Node3D
var _vest: Array[MeshInstance3D] = []
var _hit_mat: StandardMaterial3D
var _base := Vector3.ZERO
var _base_set := false
var _t := 0.0
var _down_t := 0.0
var _flash := 0.0
var _hitboxes: Array[Area3D] = []


func _ready() -> void:
	add_to_group("cible")
	sante = Sante.new()
	add_child(sante)
	sante.reset(plates)
	sante.died.connect(_on_died)
	sante.damaged.connect(func(_a, _z, _o, _b, _k): _flash = 0.12)
	sante.changed.connect(_update_vest)
	_build()
	_hitboxes = Sante.make_hitboxes(_body, sante)
	_update_vest()


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	return m


func _box(size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	_body.add_child(mi)
	mi.position = pos
	return mi


func _build() -> void:
	_body = Node3D.new()
	add_child(_body)
	var cloth := _mat(Color(0.78, 0.66, 0.46))
	var dark := _mat(Color(0.25, 0.22, 0.2))
	_hit_mat = _mat(Color(1, 1, 1, 0.55))
	_hit_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hit_mat.emission_enabled = true
	_hit_mat.emission = Color(1, 0.4, 0.3)
	_box(Vector3(0.18, 0.84, 0.2), Vector3(-0.11, 0.42, 0), cloth)
	_box(Vector3(0.18, 0.84, 0.2), Vector3(0.11, 0.42, 0), cloth)
	_box(Vector3(0.48, 0.64, 0.26), Vector3(0, 1.16, 0), cloth)
	_box(Vector3(0.13, 0.6, 0.14), Vector3(-0.32, 1.12, 0), cloth)
	_box(Vector3(0.13, 0.6, 0.14), Vector3(0.32, 1.12, 0), cloth)
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.13
	sm.height = 0.27
	head.mesh = sm
	head.material_override = cloth
	_body.add_child(head)
	head.position = Vector3(0, 1.62, 0)
	# Cible peinte sur la poitrine.
	_box(Vector3(0.2, 0.2, 0.02), Vector3(0, 1.2, -0.15), _mat(Color(0.75, 0.15, 0.1)))
	# Gilet : une plaque visible par plaque d'armure restante (bleue).
	var plate_mat := _mat(Color(0.25, 0.45, 0.85))
	for k in 3:
		_vest.append(_box(Vector3(0.44, 0.17, 0.05), Vector3(0, 1.38 - k * 0.2, -0.16), plate_mat))
	# Socle.
	var foot := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.35
	cm.bottom_radius = 0.4
	cm.height = 0.08
	foot.mesh = cm
	foot.material_override = dark
	add_child(foot)
	foot.position.y = 0.04


func _update_vest() -> void:
	var n := int(ceil(sante.armor / Armes.PLAQUE - 0.001))
	for k in _vest.size():
		_vest[k].visible = k < n


## Point visé par l'assistance à la visée (le torse).
func aim_point() -> Vector3:
	return _body.global_position + _body.global_basis * Vector3(0, 1.2, 0)


func alive() -> bool:
	return not sante.dead


func _on_died() -> void:
	_down_t = RESPAWN
	for a in _hitboxes:
		a.collision_layer = 0


func _physics_process(delta: float) -> void:
	if not _base_set:
		_base = position
		_base_set = true
	if _down_t > 0.0:
		_down_t -= delta
		_body.rotation.x = lerpf(_body.rotation.x, -PI / 2, minf(1.0, 10.0 * delta))
		if _down_t <= 0.0:
			_body.rotation.x = 0.0
			sante.reset(plates)
			for a in _hitboxes:
				a.collision_layer = G.L_HITBOX
		return
	if patrol > 0.0:
		_t += delta * patrol_speed / patrol
		position = _base + global_basis.x * sin(_t) * patrol
	if _flash > 0.0:
		_flash -= delta
	for c in _body.get_children():
		if c is MeshInstance3D and not _vest.has(c):
			(c as MeshInstance3D).material_overlay = _hit_mat if _flash > 0.0 else null
