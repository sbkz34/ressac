class_name Terrain
extends Node3D
## Relief de l'île : lit assets/map/hauteurs.png (généré par tools/gen_island.py),
## construit le maillage par morceaux (le téléphone n'affiche que ceux à l'écran)
## et une seule forme de collision. La mer est un grand plan dont la couleur suit la profondeur.

const H_MIN := -10.0
const H_RANGE := 64.0
const CHUNK := 32           # cases par morceau de maillage
const SEA_SIZE := 6000.0

var n := 0
var cell := 2.0
var half := 320.0
var heights := PackedFloat32Array()
var material: ShaderMaterial


func build(world: float, cell_size: float) -> void:
	cell = cell_size
	half = world / 2.0
	_load_heights()
	_make_material()
	_make_chunks()
	_make_collision()
	_make_sea()


func _load_heights() -> void:
	var tex: Texture2D = load("res://assets/map/hauteurs.png")
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	n = img.get_width()
	heights.resize(n * n)
	for z in n:
		for x in n:
			var c := img.get_pixel(x, z)
			var v := roundf(c.r * 255.0) * 256.0 + roundf(c.g * 255.0)
			heights[z * n + x] = v / 65535.0 * H_RANGE + H_MIN


func raw(ix: int, iz: int) -> float:
	return heights[clampi(iz, 0, n - 1) * n + clampi(ix, 0, n - 1)]


## Hauteur du sol (interpolée) en un point du monde.
func height_at(x: float, z: float) -> float:
	var fx := (x + half) / cell
	var fz := (z + half) / cell
	var ix := floori(fx)
	var iz := floori(fz)
	var tx := fx - ix
	var tz := fz - iz
	var a := lerpf(raw(ix, iz), raw(ix + 1, iz), tx)
	var b := lerpf(raw(ix, iz + 1), raw(ix + 1, iz + 1), tx)
	return lerpf(a, b, tz)


func normal_at(ix: int, iz: int) -> Vector3:
	var dx := raw(ix + 1, iz) - raw(ix - 1, iz)
	var dz := raw(ix, iz + 1) - raw(ix, iz - 1)
	return Vector3(-dx, 2.0 * cell, -dz).normalized()


func _tex(path: String) -> Texture2D:
	return load(path)


func _make_material() -> void:
	material = ShaderMaterial.new()
	material.shader = load("res://shaders/terrain.gdshader")
	material.set_shader_parameter("sols", _tex("res://assets/map/sols.png"))
	material.set_shader_parameter("sols2", _tex("res://assets/map/sols2.png"))
	material.set_shader_parameter("t_herbe", _tex("res://assets/tex/herbe.png"))
	material.set_shader_parameter("t_sable", _tex("res://assets/tex/sable.png"))
	material.set_shader_parameter("t_roche", _tex("res://assets/tex/pierre.png"))
	material.set_shader_parameter("t_chemin", _tex("res://assets/tex/dirt.png"))
	material.set_shader_parameter("t_paves", _tex("res://assets/tex/paves.png"))
	material.set_shader_parameter("t_beton", _tex("res://assets/tex/concrete.png"))
	material.set_shader_parameter("world_size", half * 2.0)


## Niveaux de détail. De près, chaque morceau (64 m) en pleine précision, puis un sommet sur
## deux ; au loin, des tuiles de 2 × 2 morceaux avec un sommet sur quatre, qui remplacent leurs
## morceaux (un seul appel de dessin au lieu de quatre, et quatre fois moins de triangles).
## Les niveaux grossiers ont une jupe (un rebord qui descend) pour cacher les raccords.
const NEAR := 140.0
const FAR := 300.0
const TILE := 2             # morceaux par côté de tuile lointaine


func _piece(cx: int, cz: int, w: int, d: int, step: int, begin: float, end: float) -> MeshInstance3D:
	var center := Vector3(-half + (cx + w / 2.0) * cell, 0, -half + (cz + d / 2.0) * cell)
	var mi := MeshInstance3D.new()
	mi.mesh = _chunk_mesh(cx, cz, w, d, step, center)
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_begin = begin
	mi.visibility_range_end = end
	mi.visibility_range_begin_margin = 8.0 if begin > 0.0 else 0.0
	mi.visibility_range_end_margin = 8.0 if end > 0.0 else 0.0
	add_child(mi)
	mi.position = center
	return mi


func _make_chunks() -> void:
	var cells := n - 1
	var span := CHUNK * TILE
	for tz in range(0, cells, span):
		for tx in range(0, cells, span):
			# La tuile lointaine ; ses morceaux ne s'affichent que tant qu'elle est cachée.
			var tile := _piece(tx, tz, mini(span, cells - tx), mini(span, cells - tz), 4, FAR, 0.0)
			for cz in range(tz, mini(tz + span, cells), CHUNK):
				for cx in range(tx, mini(tx + span, cells), CHUNK):
					var w := mini(CHUNK, cells - cx)
					var d := mini(CHUNK, cells - cz)
					for lod in [[1, 0.0, NEAR], [2, NEAR, 0.0]]:
						var mi := _piece(cx, cz, w, d, int(lod[0]), float(lod[1]), float(lod[2]))
						mi.visibility_parent = mi.get_path_to(tile)


func _chunk_mesh(cx: int, cz: int, w: int, d: int, step: int, center: Vector3) -> ArrayMesh:
	var cells := n - 1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var xs := []
	var zs := []
	for ix in range(cx, cx + w + 1, step):
		xs.append(ix)
	if xs[-1] != cx + w:
		xs.append(cx + w)
	for iz in range(cz, cz + d + 1, step):
		zs.append(iz)
	if zs[-1] != cz + d:
		zs.append(cz + d)
	var vert := func(ix: int, iz: int, drop: float) -> void:
		st.set_normal(normal_at(ix, iz))
		st.set_uv(Vector2(float(ix) / cells, float(iz) / cells))
		st.add_vertex(Vector3(-half + ix * cell, raw(ix, iz) - drop, -half + iz * cell) - center)
	for iz in zs:
		for ix in xs:
			vert.call(ix, iz, 0.0)
	var row := xs.size()
	for j in zs.size() - 1:
		for i in xs.size() - 1:
			var a := j * row + i
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(a + row)
			st.add_index(a + 1)
			st.add_index(a + row + 1)
			st.add_index(a + row)
	if step > 1:
		# Jupe : les bords redescendent de 3 m (cache les fentes avec le morceau voisin).
		var base := xs.size() * zs.size()
		var edges := [[], [], [], []]
		for ix in xs:
			edges[0].append([ix, zs[0]])
			edges[1].append([ix, zs[-1]])
		for iz in zs:
			edges[2].append([xs[0], iz])
			edges[3].append([xs[-1], iz])
		var k := base
		for e in edges:
			for p in e:
				vert.call(int(p[0]), int(p[1]), 0.0)
				vert.call(int(p[0]), int(p[1]), 3.0)
			for q in e.size() - 1:
				var t0: int = k + q * 2
				st.add_index(t0); st.add_index(t0 + 2); st.add_index(t0 + 1)
				st.add_index(t0 + 2); st.add_index(t0 + 3); st.add_index(t0 + 1)
				# Les deux faces (le sens dépend du bord).
				st.add_index(t0); st.add_index(t0 + 1); st.add_index(t0 + 2)
				st.add_index(t0 + 2); st.add_index(t0 + 1); st.add_index(t0 + 3)
			k += e.size() * 2
	return st.commit()


func _make_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "Sol"
	body.collision_layer = G.L_WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := HeightMapShape3D.new()
	shape.map_width = n
	shape.map_depth = n
	shape.map_data = heights
	cs.shape = shape
	# La forme est centrée et espacée d'un mètre : on l'étire à la taille d'une case.
	cs.scale = Vector3(cell, 1.0, cell)
	body.add_child(cs)
	add_child(body)


func _make_sea() -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Mer"
	var pm := PlaneMesh.new()
	pm.size = Vector2(SEA_SIZE, SEA_SIZE)
	pm.subdivide_width = 0
	pm.subdivide_depth = 0
	mi.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/mer.gdshader")
	m.set_shader_parameter("hauteurs", _tex("res://assets/map/hauteurs.png"))
	m.set_shader_parameter("world_size", half * 2.0)
	m.set_shader_parameter("h_min", H_MIN)
	m.set_shader_parameter("h_range", H_RANGE)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
