class_name Coffre
extends Node3D
## Coffre de butin : une lueur dorée tant qu'il est fermé ; on l'ouvre avec Action et il
## répand son contenu devant lui (arme, munitions, plaques, argent).
## Variante « ravitaillement » (champ de tir) : remplit munitions et plaques, sans fin.
## Variante « largage » : la caisse de classe, qui descend du ciel sous un parachute et qu'on
## ouvre pour choisir une de ses classes.

signal opened(coffre: Coffre)

var is_open := false
var ravitaillement := false
var largage := false
var _falling := false
var _fall_to := 0.0
var _chute: Node3D
var _lid: Node3D
var _glow: MeshInstance3D
var _lid_t := 0.0


func _mat(c: Color, energy := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.7
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = energy
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	parent.add_child(mi)
	mi.position = pos
	return mi


func _ready() -> void:
	add_to_group("coffre")
	var wood := StandardMaterial3D.new()
	wood.albedo_texture = load("res://assets/tex/wood.png")
	wood.uv1_triplanar = true
	wood.uv1_scale = Vector3(3, 3, 3)
	wood.albedo_color = Color(0.55, 0.62, 0.45) if ravitaillement else Color(0.85, 0.7, 0.55)
	if largage:
		wood.albedo_color = Color(0.32, 0.4, 0.26)
		scale = Vector3(1.4, 1.4, 1.4)
	var metal := _mat(Color(0.2, 0.2, 0.22))
	_box(self, Vector3(0.9, 0.42, 0.55), Vector3(0, 0.21, 0), wood)
	for x in [-0.36, 0.36]:
		_box(self, Vector3(0.06, 0.44, 0.57), Vector3(x, 0.21, 0), metal)
	_lid = Node3D.new()
	add_child(_lid)
	_lid.position = Vector3(0, 0.42, 0.275)
	_box(_lid, Vector3(0.92, 0.14, 0.57), Vector3(0, 0.07, -0.285), wood)
	_box(_lid, Vector3(0.12, 0.1, 0.04), Vector3(0, 0.0, 0.0), metal)
	var c := Color(0.4, 0.9, 0.5) if ravitaillement else Color(1.0, 0.78, 0.3)
	if largage:
		c = Color(0.45, 1.0, 0.55)
	_glow = _box(self, Vector3(0.94, 0.02, 0.59), Vector3(0, 0.425, 0), _mat(c, 3.0))
	var body := StaticBody3D.new()
	body.collision_layer = G.L_WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.9, 0.5, 0.55)
	cs.shape = bs
	cs.position.y = 0.25
	body.add_child(cs)
	add_child(body)
	if largage:
		_make_largage_marks(c)
	if ravitaillement or largage:
		var l := Label3D.new()
		l.text = "LARGAGE DE CLASSE" if largage else "RAVITAILLEMENT"
		l.font_size = 40
		l.outline_size = 10
		l.pixel_size = 0.006
		l.modulate = c
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(l)
		l.position.y = 1.0


func _make_largage_marks(c: Color) -> void:
	# Fumée colorée visible de loin, et le parachute pendant la descente.
	var beam := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.6
	cm.bottom_radius = 0.15
	cm.height = 40.0
	cm.radial_segments = 8
	cm.rings = 1
	beam.mesh = cm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(c.r, c.g, c.b, 0.3)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.material_override = m
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.visibility_range_begin = 6.0
	add_child(beam)
	beam.position.y = 20.0
	_chute = Node3D.new()
	add_child(_chute)
	var canopy := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 2.2
	sm.height = 2.2
	sm.is_hemisphere = true
	canopy.mesh = sm
	var cm2 := StandardMaterial3D.new()
	cm2.albedo_color = Color(0.85, 0.85, 0.8)
	cm2.cull_mode = BaseMaterial3D.CULL_DISABLED
	canopy.material_override = cm2
	_chute.add_child(canopy)
	canopy.position.y = 4.0
	_chute.visible = false


## Fait descendre la caisse depuis `height` mètres au-dessus de sa position finale.
func drop_from(height: float) -> void:
	_fall_to = global_position.y
	global_position.y += height
	_falling = true
	if _chute:
		_chute.visible = true


func label() -> String:
	if largage:
		return "Ouvrir le largage : choisir une classe"
	return "Se ravitailler (munitions et plaques)" if ravitaillement else "Ouvrir le coffre"


func can_open() -> bool:
	if _falling:
		return false
	return ravitaillement or not is_open


func open_chest() -> void:
	if not can_open():
		return
	G.play("box", -6.0)
	if not ravitaillement:
		is_open = true
		_glow.visible = false
	opened.emit(self)


func _process(delta: float) -> void:
	if _falling:
		global_position.y = maxf(_fall_to, global_position.y - 9.0 * delta)
		if global_position.y <= _fall_to + 0.001:
			_falling = false
			_chute.visible = false
			G.play("jump_land", -4.0, 0.6)
	if is_open and _lid_t < 1.0:
		_lid_t = minf(1.0, _lid_t + delta * 3.0)
		_lid.rotation.x = 1.9 * ease(_lid_t, 0.5)
