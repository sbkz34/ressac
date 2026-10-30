class_name ApercuArme
extends SubViewportContainer
## Aperçu 3D d'une arme dans les menus : le vrai modèle avec ses accessoires, de trois quarts,
## éclairé comme un studio, qui oscille doucement. Un petit monde à part (sa propre caméra).

var _vp: SubViewport
var _cam: Camera3D
var _pivot: Node3D
var _model: Node3D
var _key := ""
var _t := 0.0
var _box := AABB()
static var _mats := {}


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_2X
	_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.environment.ambient_light_energy = 0.7
	_vp.add_child(env)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.6
	_vp.add_child(key)
	key.transform = Transform3D(Basis.looking_at(-Vector3(4, 5, 2.5).normalized()), Vector3.ZERO)
	var rim := DirectionalLight3D.new()
	rim.light_energy = 1.1
	rim.light_color = Color(0.85, 0.92, 1.0)
	_vp.add_child(rim)
	rim.transform = Transform3D(Basis.looking_at(-Vector3(-3, 3, -4).normalized()), Vector3.ZERO)
	_pivot = Node3D.new()
	_vp.add_child(_pivot)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_vp.add_child(_cam)
	_cam.current = true
	resized.connect(_fit)


## Matières claires des menus (les volumes se lisent sur un fond sombre).
static func menu_mats() -> Dictionary:
	if _mats.is_empty():
		var mk := func(c: Color, metal: float, rough: float) -> StandardMaterial3D:
			var m := StandardMaterial3D.new()
			m.albedo_color = c
			m.metallic = metal
			m.roughness = rough
			return m
		var wood: StandardMaterial3D = (Armes.materiaux(0).wood as StandardMaterial3D).duplicate()
		wood.albedo_color = Color(1.0, 0.82, 0.68)
		var glow: StandardMaterial3D = mk.call(Color(1.0, 0.3, 0.2), 0.0, 0.5)
		glow.emission_enabled = true
		glow.emission = Color(1.0, 0.25, 0.15)
		glow.emission_energy_multiplier = 2.0
		_mats = {"metal": mk.call(Color(0.46, 0.48, 0.52), 0.55, 0.38), "dark": mk.call(Color(0.2, 0.21, 0.23), 0.3, 0.55),
			"wood": wood, "glow": glow, "verre": Armes.verre()}
	return _mats


## Montre une arme (avec ses accessoires).
func montrer(w: Dictionary) -> void:
	var acc: Array = w.get("acc", [])
	var camo := String(w.get("camo", Progression.camo(String(w.get("id", "")))))
	var key := "%s|%s|%s" % [w.get("id", ""), ",".join(PackedStringArray(acc)), camo]
	if key == _key:
		return
	_key = key
	if _model:
		_model.queue_free()
	var mats := menu_mats()
	if camo != "":
		mats = mats.duplicate()
		mats.metal = Armes.camo_mat(camo)
		mats.wood = mats.metal
		mats.dark = Armes.camo_mat(camo)
		mats.dark.albedo_color = Color(0.62, 0.62, 0.62)
	_model = GunShapes.build_model(String(w.get("id", "p9")), mats, 1.0, acc)
	_pivot.add_child(_model)
	var box := AABB()
	var first := true
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		var b: AABB = m3.transform * m3.get_aabb()
		var n: Node = m3.get_parent()
		while n != _model and n is Node3D:
			b = (n as Node3D).transform * b
			n = n.get_parent()
		box = b if first else box.merge(b)
		first = false
	_model.position = -box.get_center()
	_box = box
	_fit()


## Cadrage : l'arme remplit la largeur de l'aperçu (refait quand l'aperçu change de taille).
func _fit() -> void:
	if size.x < 2.0 or size.y < 2.0:
		return
	var aspect := size.x / size.y
	_cam.size = maxf(_box.size.z * 1.18 / maxf(aspect, 0.5), _box.size.y * 1.5)
	_cam.transform = Transform3D(Basis(), Vector3(5, 1.6, -1.1)).looking_at(Vector3.ZERO, Vector3.UP)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	_pivot.rotation.y = sin(_t * 0.6) * 0.22
