class_name Coffre
extends Node3D
## Coffre de butin : une lueur dorée tant qu'il est fermé ; on l'ouvre avec Action et il
## répand son contenu devant lui (arme, munitions, plaques, argent).
## Variante « ravitaillement » (champ de tir) : remplit munitions et plaques, sans fin.

signal opened(coffre: Coffre)

var is_open := false
var ravitaillement := false
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
	if ravitaillement:
		var l := Label3D.new()
		l.text = "RAVITAILLEMENT"
		l.font_size = 40
		l.outline_size = 10
		l.pixel_size = 0.006
		l.modulate = c
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(l)
		l.position.y = 1.0


func label() -> String:
	return "Se ravitailler (munitions et plaques)" if ravitaillement else "Ouvrir le coffre"


func can_open() -> bool:
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
	if is_open and _lid_t < 1.0:
		_lid_t = minf(1.0, _lid_t + delta * 3.0)
		_lid.rotation.x = 1.9 * ease(_lid_t, 0.5)
