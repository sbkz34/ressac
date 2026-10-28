class_name Avion
extends Node3D
## Avion de largage : traverse l'île en ligne droite à 190 m d'altitude. Le joueur saute
## quand il veut depuis la rampe arrière ; passé le bout de l'île, il est éjecté.

const ALTITUDE := 190.0
const SPEED := 48.0
const HALF_LENGTH := 560.0
const EJECT_AT := 0.82          # fraction du trajet où l'on saute d'office

var start := Vector3.ZERO
var end := Vector3.ZERO
var progress := 0.0
var _props: Array[Node3D] = []


## Trajet passant à `offset` mètres du centre de l'île, dans la direction `angle` (radians).
func setup(angle: float, offset: float) -> void:
	var dir := Vector3(sin(angle), 0, -cos(angle))
	var side := Vector3(-dir.z, 0, dir.x)
	var center := Vector3(0, ALTITUDE, -10) + side * offset
	start = center - dir * HALF_LENGTH
	end = center + dir * HALF_LENGTH
	global_position = start
	look_at(end, Vector3.UP)
	_build()


static func random_route(rng: RandomNumberGenerator) -> Array:
	return [rng.randf() * TAU, rng.randf_range(-90.0, 90.0)]


func _mat(c: Color, metal := 0.2) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = 0.6
	return m


func _box(size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	add_child(mi)
	mi.position = pos
	return mi


func _build() -> void:
	# Vieux cargo bimoteur gris-vert (l'avant est vers -z, comme look_at).
	var body := _mat(Color(0.42, 0.46, 0.4))
	var dark := _mat(Color(0.12, 0.13, 0.12))
	_box(Vector3(3.6, 3.4, 22.0), Vector3(0, 0, 0), body)
	_box(Vector3(3.0, 2.6, 3.0), Vector3(0, 0.1, -12.2), body)
	_box(Vector3(2.0, 0.8, 1.2), Vector3(0, 0.9, -12.0), _mat(Color(0.2, 0.3, 0.4), 0.6))
	_box(Vector3(30.0, 0.45, 4.2), Vector3(0, 1.2, -2.0), body)
	_box(Vector3(11.0, 0.35, 2.6), Vector3(0, 1.4, 10.5), body)
	_box(Vector3(0.35, 4.0, 3.2), Vector3(0, 3.2, 10.8), body)
	# Rampe arrière ouverte.
	var ramp := _box(Vector3(3.2, 0.2, 4.0), Vector3(0, -1.9, 12.6), dark)
	ramp.rotation.x = 0.35
	for sx in [-1.0, 1.0]:
		_box(Vector3(1.4, 1.4, 4.6), Vector3(sx * 6.0, 0.7, -3.4), body)
		var prop := Node3D.new()
		add_child(prop)
		prop.position = Vector3(sx * 6.0, 0.7, -5.9)
		for k in 3:
			var blade := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.25, 3.6, 0.08)
			blade.mesh = bm
			blade.material_override = dark
			prop.add_child(blade)
			blade.rotation.z = k * TAU / 3.0
		_props.append(prop)


func velocity_vector() -> Vector3:
	return (end - start).normalized() * SPEED


## Là où se tient le joueur : derrière et au-dessus de l'appareil, l'île défile dessous
## (vue de largage, le saut part de la rampe).
func ramp_position() -> Vector3:
	return global_position + global_basis * Vector3(0, 2.2, 30.0)


func must_jump() -> bool:
	return progress >= EJECT_AT


func _physics_process(delta: float) -> void:
	progress += SPEED * delta / (HALF_LENGTH * 2.0)
	global_position = start.lerp(end, minf(progress, 1.0))
	for p in _props:
		p.rotation.z += 40.0 * delta
	if progress >= 1.0:
		queue_free()
