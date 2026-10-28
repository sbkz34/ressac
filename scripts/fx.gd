class_name Fx
extends RefCounted
## Petits effets visuels éphémères : traçantes et impacts de balles (légers pour un téléphone).

static var _tracer_mat: StandardMaterial3D
static var _dust_mat: StandardMaterial3D


static func _mats() -> void:
	if _tracer_mat:
		return
	_tracer_mat = StandardMaterial3D.new()
	_tracer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tracer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_tracer_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_tracer_mat.albedo_color = Color(1.0, 0.85, 0.55, 0.7)
	_dust_mat = StandardMaterial3D.new()
	_dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_dust_mat.albedo_color = Color(0.75, 0.7, 0.6, 0.7)


static func tracer(parent: Node, from: Vector3, to: Vector3) -> void:
	if parent == null:
		return
	_mats()
	var length := from.distance_to(to)
	if length < 1.0:
		return
	# Un trait court qui file vers l'impact.
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var seg := minf(length, 6.0)
	bm.size = Vector3(0.025, 0.025, seg)
	mi.mesh = bm
	mi.material_override = _tracer_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = from
	mi.look_at(to, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT)
	var dir := (to - from).normalized()
	var start := from + dir * seg * 0.5
	var finish := to - dir * seg * 0.5
	mi.global_position = start
	var t := mi.create_tween()
	t.tween_property(mi, "global_position", finish, clampf(length / 600.0, 0.02, 0.4))
	t.tween_callback(mi.queue_free)


static func impact(parent: Node, at: Vector3, normal: Vector3) -> void:
	if parent == null:
		return
	_mats()
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	sm.radial_segments = 6
	sm.rings = 3
	mi.mesh = sm
	mi.material_override = _dust_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = at + normal * 0.05
	var t := mi.create_tween().set_parallel(true)
	t.tween_property(mi, "scale", Vector3.ONE * 3.0, 0.25)
	t.tween_property(mi, "global_position", at + normal * 0.35, 0.25)
	t.chain().tween_callback(mi.queue_free)
