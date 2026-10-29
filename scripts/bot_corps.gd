class_name BotCorps
extends Node3D
## Silhouette d'un combattant vu par les autres : un seul maillage par posture (debout,
## accroupi, couché), fusionné une fois pour toutes et partagé, plus l'arme en main (un maillage
## par modèle d'arme, partagé aussi). Deux appels de dessin par combattant, pour tenir à
## 24 sur un téléphone.

## Tenues : [vêtements, gilet] (kaki, sable, ardoise, brique).
const TENUES := [
	[Color(0.34, 0.4, 0.27), Color(0.22, 0.26, 0.18)], [Color(0.55, 0.47, 0.33), Color(0.36, 0.3, 0.2)],
	[Color(0.27, 0.31, 0.38), Color(0.17, 0.19, 0.24)], [Color(0.46, 0.27, 0.22), Color(0.28, 0.18, 0.15)],
]

static var _meshes := {}         # posture × tenue -> ArrayMesh (couleurs dans les sommets)
static var _guns := {}           # id d'arme -> ArrayMesh
static var _mat: StandardMaterial3D
static var _gun_mat: StandardMaterial3D

var _body: MeshInstance3D
var _gun: MeshInstance3D
var _gun_id := ""
var _posture := -1
var _tenue := 0


static func _box(st: SurfaceTool, size: Vector3, pos: Vector3, col: Color, rot_x := 0.0) -> void:
	var bm := BoxMesh.new()
	bm.size = size
	var arrays := bm.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var b := Basis(Vector3.RIGHT, rot_x)
	for k in idx:
		st.set_color(col)
		st.set_normal(b * norms[k])
		st.add_vertex(b * verts[k] + pos)


## Combattant debout (1,8 m), accroupi ou couché, en boîtes colorées.
static func _make(posture: int, tenue: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cloth: Color = TENUES[tenue][0]
	var vest: Color = TENUES[tenue][1]
	var skin := Color(0.78, 0.6, 0.47)
	var dark := Color(0.12, 0.12, 0.12)
	match posture:
		Joueur.Posture.DEBOUT:
			_box(st, Vector3(0.18, 0.84, 0.2), Vector3(-0.11, 0.42, 0), cloth)
			_box(st, Vector3(0.18, 0.84, 0.2), Vector3(0.11, 0.42, 0), cloth)
			_box(st, Vector3(0.48, 0.64, 0.28), Vector3(0, 1.16, 0), cloth)
			_box(st, Vector3(0.5, 0.42, 0.32), Vector3(0, 1.2, 0), vest)
			_box(st, Vector3(0.36, 0.42, 0.18), Vector3(0, 1.18, 0.2), dark)        # sac
			_box(st, Vector3(0.13, 0.55, 0.14), Vector3(-0.31, 1.1, -0.12), cloth, -0.8)
			_box(st, Vector3(0.13, 0.55, 0.14), Vector3(0.31, 1.1, -0.12), cloth, -0.8)
			_box(st, Vector3(0.22, 0.24, 0.24), Vector3(0, 1.62, 0), skin)
			_box(st, Vector3(0.27, 0.12, 0.29), Vector3(0, 1.75, 0), dark)          # casque
		Joueur.Posture.ACCROUPI:
			_box(st, Vector3(0.18, 0.45, 0.4), Vector3(-0.11, 0.25, -0.08), cloth)
			_box(st, Vector3(0.18, 0.45, 0.4), Vector3(0.11, 0.25, 0.08), cloth)
			_box(st, Vector3(0.48, 0.6, 0.3), Vector3(0, 0.78, 0.02), cloth, 0.2)
			_box(st, Vector3(0.5, 0.4, 0.33), Vector3(0, 0.8, 0.02), vest, 0.2)
			_box(st, Vector3(0.36, 0.4, 0.18), Vector3(0, 0.8, 0.22), dark, 0.2)
			_box(st, Vector3(0.13, 0.5, 0.14), Vector3(-0.31, 0.78, -0.18), cloth, -0.9)
			_box(st, Vector3(0.13, 0.5, 0.14), Vector3(0.31, 0.78, -0.18), cloth, -0.9)
			_box(st, Vector3(0.22, 0.24, 0.24), Vector3(0, 1.17, -0.05), skin)
			_box(st, Vector3(0.27, 0.12, 0.29), Vector3(0, 1.3, -0.05), dark)
		_:
			_box(st, Vector3(0.4, 0.22, 1.7), Vector3(0, 0.13, 0.15), cloth)
			_box(st, Vector3(0.5, 0.26, 0.5), Vector3(0, 0.2, -0.25), vest)
			_box(st, Vector3(0.36, 0.2, 0.36), Vector3(0, 0.34, 0.05), dark)
			_box(st, Vector3(0.22, 0.22, 0.24), Vector3(0, 0.25, -0.65), skin)
			_box(st, Vector3(0.27, 0.12, 0.29), Vector3(0, 0.37, -0.65), dark)
	return st.commit()


## Maillage fusionné d'un modèle d'arme, partagé (bots, armes au sol).
static func gun_mesh(id: String) -> ArrayMesh:
	if not _guns.has(id):
		_guns[id] = _make_gun(id)
	return _guns[id]


static func _make_gun(id: String) -> ArrayMesh:
	# Le modèle de l'arme (silhouette de Dernière Vague) fusionné en un seul maillage.
	var model := GunShapes.build_model(id, Armes.materiaux(0), 1.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stack: Array = [[model, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var it: Array = stack.pop_back()
		var n: Node3D = it[0]
		var xf: Transform3D = it[1]
		for c in n.get_children():
			var cx: Transform3D = xf * (c as Node3D).transform
			if c is MeshInstance3D and (c as MeshInstance3D).mesh:
				st.append_from((c as MeshInstance3D).mesh, 0, cx)
			stack.append([c, cx])
	model.free()
	return st.commit()


static func _materials() -> void:
	if _mat:
		return
	_mat = StandardMaterial3D.new()
	_mat.vertex_color_use_as_albedo = true
	_mat.roughness = 0.9
	_gun_mat = StandardMaterial3D.new()
	_gun_mat.albedo_color = Color(0.12, 0.12, 0.13)
	_gun_mat.metallic = 0.4
	_gun_mat.roughness = 0.5


func _ready() -> void:
	_materials()
	_body = MeshInstance3D.new()
	_body.material_override = _mat
	_tenue = randi() % TENUES.size()
	_body.visibility_range_end = 320.0
	add_child(_body)
	_gun = MeshInstance3D.new()
	_gun.material_override = _gun_mat
	_gun.visibility_range_end = 120.0
	add_child(_gun)


## Suit l'état du combattant : posture, arme en main, visée, visibilité.
func follow(j: Joueur) -> void:
	var hidden := j.etat == Joueur.Etat.AVION or j.etat == Joueur.Etat.DRONE or j.sante.dead
	visible = not hidden
	if hidden:
		return
	var p := j.posture
	if j.etat == Joueur.Etat.GLISSADE:
		p = Joueur.Posture.ACCROUPI
	if p != _posture:
		_posture = p
		var key := p * 10 + _tenue
		if not _meshes.has(key):
			_meshes[key] = _make(p, _tenue)
		_body.mesh = _meshes[key]
	var w := j.arsenal.current()
	var id: String = w.get("id", "")
	if id != _gun_id:
		_gun_id = id
		if id == "":
			_gun.mesh = null
		else:
			if not _guns.has(id):
				_guns[id] = _make_gun(id)
			_gun.mesh = _guns[id]
	# L'arme suit la visée (tangage de la tête), à hauteur d'épaule selon la posture.
	var shoulder := {Joueur.Posture.DEBOUT: 1.38, Joueur.Posture.ACCROUPI: 0.98, Joueur.Posture.COUCHE: 0.32}
	_gun.position = Vector3(0.18, float(shoulder[p]), -0.32)
	_gun.rotation.x = j.head.rotation.x
	_gun.visible = j.etat != Joueur.Etat.PARACHUTE and j.etat != Joueur.Etat.CHUTE_LIBRE
