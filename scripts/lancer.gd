class_name Lancer
extends Node3D
## Équipement lancé : grenade (explose au bout de 2,5 s, dégâts selon la distance, à travers
## l'armure comme une balle) ou fumigène (nuage opaque pendant 14 s, que les bots
## ne verront pas à travers). Trajectoire calculée à la main : rebonds sur le décor, freinage.

const GRAVITY := 18.0
const FUSE := 2.5
const BLAST_RADIUS := 6.5
const BLAST_DAMAGE := 160.0
const SMOKE_RADIUS := 7.0
const SMOKE_TIME := 14.0

var kind := "grenade"
var velocity := Vector3.ZERO
var thrower: Node3D
var _t := 0.0
var _mesh: MeshInstance3D
var _rest := false
var _exclude: Array[RID] = []


static func throw(parent: Node, k: String, from: Vector3, dir: Vector3, by: Node3D, exclude: Array[RID]) -> Lancer:
	var l := Lancer.new()
	l.kind = k
	l.thrower = by
	l._exclude = exclude
	l.velocity = dir.normalized() * 17.0 + Vector3(0, 3.5, 0)
	parent.add_child(l)
	l.global_position = from
	return l


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var m := StandardMaterial3D.new()
	if kind == "grenade":
		var sm := SphereMesh.new()
		sm.radius = 0.06
		sm.height = 0.13
		_mesh.mesh = sm
		m.albedo_color = Color(0.2, 0.26, 0.14)
	else:
		var cm := CylinderMesh.new()
		cm.top_radius = 0.045
		cm.bottom_radius = 0.045
		cm.height = 0.16
		_mesh.mesh = cm
		m.albedo_color = Color(0.55, 0.58, 0.6)
	_mesh.material_override = m
	add_child(_mesh)


func _physics_process(delta: float) -> void:
	_t += delta
	if not _rest:
		velocity.y -= GRAVITY * delta
		var step := velocity * delta
		var q := PhysicsRayQueryParameters3D.create(global_position, global_position + step * 1.2, G.L_WORLD, _exclude)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if hit:
			global_position = hit.position + hit.normal * 0.07
			velocity = velocity.bounce(hit.normal) * 0.35
			if velocity.length() < 1.2 and hit.normal.y > 0.6:
				_rest = true
				velocity = Vector3.ZERO
		else:
			global_position += step
		_mesh.rotation += Vector3(7, 3, 0) * delta
		if global_position.y < -12.0:
			queue_free()
			return
	if kind == "grenade" and _t >= FUSE:
		_explode()
	elif kind == "fumigene" and (_rest or _t > 2.0):
		_smoke()


func _explode() -> void:
	var at := global_position + Vector3(0, 0.2, 0)
	G.play_at("grenade_explode", global_position, 4.0)
	var space := get_world_3d().direct_space_state
	for c in get_tree().get_nodes_in_group("combattant"):
		var s: Sante = c.sante
		if s == null or s.dead:
			continue
		var target: Vector3 = c.global_position + Vector3(0, 1.0, 0)
		var d := at.distance_to(target)
		if d > BLAST_RADIUS:
			continue
		var q := PhysicsRayQueryParameters3D.create(at, target, G.L_WORLD, _exclude)
		if not space.intersect_ray(q).is_empty():
			continue   # à l'abri derrière un mur
		var k := 1.0 - clampf((d - 1.5) / (BLAST_RADIUS - 1.5), 0.0, 1.0)
		s.take(BLAST_DAMAGE * k, "torse", "grenade", false, thrower)
	# Boule de feu et poussière.
	var fire := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	fire.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.6, 0.2, 0.85)
	fire.material_override = m
	get_parent().add_child(fire)
	fire.global_position = at
	var tw := fire.create_tween().set_parallel(true)
	tw.tween_property(fire, "scale", Vector3.ONE * 7.0, 0.35)
	tw.tween_property(m, "albedo_color", Color(0.35, 0.3, 0.28, 0.0), 0.6)
	tw.chain().tween_callback(fire.queue_free)
	queue_free()


func _smoke() -> void:
	G.play_at("decoy", global_position, -2.0, 0.6)
	var cloud := Node3D.new()
	cloud.add_to_group("fumee")
	cloud.set_meta("rayon", SMOKE_RADIUS)
	get_parent().add_child(cloud)
	cloud.global_position = global_position
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.82, 0.83, 0.82, 0.0)
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var rng := RandomNumberGenerator.new()
	for k in 9:
		var puff := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		sm.radial_segments = 10
		sm.rings = 5
		puff.mesh = sm
		puff.material_override = m
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cloud.add_child(puff)
		puff.position = Vector3(rng.randf_range(-3, 3), rng.randf_range(0.8, 3.0), rng.randf_range(-3, 3))
		puff.scale = Vector3.ONE * 0.5
		puff.create_tween().tween_property(puff, "scale", Vector3.ONE * rng.randf_range(3.2, 4.5), 2.5)
	var tw := cloud.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.92, 1.5)
	tw.tween_interval(SMOKE_TIME - 4.0)
	tw.tween_property(m, "albedo_color:a", 0.0, 2.5)
	tw.tween_callback(cloud.queue_free)
	queue_free()
