class_name Butin
extends Node3D
## Un objet au sol : arme (ramassée en appuyant sur Action), munitions, plaque d'armure ou
## argent (ramassés en passant dessus). Les armes flottent et tournent, avec un faisceau à la
## couleur de leur rareté visible de loin.

enum Type { ARME, MUNITIONS, PLAQUE, ARGENT }

var type: int = Type.MUNITIONS
var arme: Dictionary = {}
var munition := "pistolet"
var quantite := 0
var _spin: Node3D
var _t := 0.0


static func make_arme(w: Dictionary) -> Butin:
	var b := Butin.new()
	b.type = Type.ARME
	b.arme = w.duplicate()
	return b


static func make_munitions(kind: String, n: int) -> Butin:
	var b := Butin.new()
	b.type = Type.MUNITIONS
	b.munition = kind
	b.quantite = n
	return b


static func make_plaque(n := 1) -> Butin:
	var b := Butin.new()
	b.type = Type.PLAQUE
	b.quantite = n
	return b


static func make_argent(n: int) -> Butin:
	var b := Butin.new()
	b.type = Type.ARGENT
	b.quantite = n
	return b


func label() -> String:
	match type:
		Type.ARME: return Armes.nom_complet(arme)
		Type.MUNITIONS: return "%s ×%d" % [Armes.MUNITIONS[munition].nom, quantite]
		Type.PLAQUE: return "Plaque d'armure" if quantite == 1 else "Plaques d'armure ×%d" % quantite
		_: return "%d €" % quantite


func color() -> Color:
	match type:
		Type.ARME: return Armes.RARETES[int(arme.rarete)].couleur
		Type.MUNITIONS: return Armes.MUNITIONS[munition].couleur
		Type.PLAQUE: return Color(0.35, 0.6, 1.0)
		_: return Color(0.45, 0.85, 0.4)


func _flat(c: Color, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.7
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static var _gun_mats := {}


## Matière des armes au sol : métal sombre teinté par la rareté.
static func _gun_mat(rarete: int) -> StandardMaterial3D:
	if not _gun_mats.has(rarete):
		var m := StandardMaterial3D.new()
		var c: Color = Armes.RARETES[rarete].couleur
		m.albedo_color = Color(0.16, 0.16, 0.17).lerp(c, 0.28)
		m.metallic = 0.4
		m.roughness = 0.5
		_gun_mats[rarete] = m
	return _gun_mats[rarete]


func _box(parent: Node3D, size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.position = pos
	return mi


func _ready() -> void:
	add_to_group("butin")
	_spin = Node3D.new()
	add_child(_spin)
	var c := color()
	match type:
		Type.ARME:
			# Un seul maillage par modèle d'arme (partagé, comme les armes des bots) : un appel de
			# dessin par arme au sol au lieu d'un par pièce.
			var model := MeshInstance3D.new()
			model.mesh = BotCorps.gun_mesh(arme.id, arme.get("acc", []))
			model.material_override = _gun_mat(int(arme.rarete))
			_spin.add_child(model)
			model.rotation.y = PI / 2
			model.position = Vector3(-0.3, 0, 0)
			_spin.position.y = 0.4
			# Faisceau de rareté.
			var beam := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.02
			cm.bottom_radius = 0.06
			cm.height = 2.2
			cm.radial_segments = 6
			cm.rings = 1
			beam.mesh = cm
			var bc := c
			bc.a = 0.45
			beam.material_override = _flat(bc, true)
			beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			beam.visibility_range_begin = 3.5   # visible de loin, effacé quand on est dessus
			beam.visibility_range_end = 110.0
			add_child(beam)
			beam.position.y = 1.1
		Type.MUNITIONS:
			_box(_spin, Vector3(0.32, 0.16, 0.2), Vector3(0, 0.08, 0), _flat(Color(0.22, 0.24, 0.2)))
			_box(_spin, Vector3(0.33, 0.04, 0.21), Vector3(0, 0.17, 0), _flat(c))
		Type.PLAQUE:
			for k in quantite:
				var p := _box(_spin, Vector3(0.3, 0.36, 0.05), Vector3(k * 0.07, 0.2, k * 0.05), _flat(Color(0.22, 0.3, 0.42)))
				p.rotation.x = -0.35
			_box(_spin, Vector3(0.16, 0.06, 0.055), Vector3(0, 0.3, -0.04), _flat(c))
		Type.ARGENT:
			for k in 3:
				_box(_spin, Vector3(0.17, 0.035, 0.08), Vector3(0.02 * k, 0.02 + 0.036 * k, 0.01 * k), _flat(Color(0.35, 0.62, 0.32)))
	# Nom affiché de près.
	var l := Label3D.new()
	l.text = label()
	l.font_size = 32
	l.outline_size = 8
	l.pixel_size = 0.004
	l.modulate = c.lightened(0.3)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.visibility_range_end = 5.0
	l.no_depth_test = false
	add_child(l)
	l.position.y = 0.95 if type == Type.ARME else 0.6
	# Économie pour les téléphones : l'objet lui-même ne se dessine que de près (son faisceau,
	# lui, reste visible de loin).
	for g in _spin.find_children("*", "GeometryInstance3D", true, false):
		var gi := g as GeometryInstance3D
		gi.visibility_range_end = 38.0
		gi.visibility_range_end_margin = 4.0
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(delta: float) -> void:
	_t += delta
	if type == Type.ARME:
		_spin.rotation.y += delta * 0.8
		_spin.position.y = 0.4 + sin(_t * 2.0) * 0.04
