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


func _make_chunks() -> void:
	var cells := n - 1
	for cz in range(0, cells, CHUNK):
		for cx in range(0, cells, CHUNK):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var w := mini(CHUNK, cells - cx)
			var d := mini(CHUNK, cells - cz)
			for iz in range(cz, cz + d + 1):
				for ix in range(cx, cx + w + 1):
					st.set_normal(normal_at(ix, iz))
					st.set_uv(Vector2(float(ix) / cells, float(iz) / cells))
					st.add_vertex(Vector3(-half + ix * cell, raw(ix, iz), -half + iz * cell))
			var row := w + 1
			for j in d:
				for i in w:
					var a := j * row + i
					st.add_index(a)
					st.add_index(a + 1)
					st.add_index(a + row)
					st.add_index(a + 1)
					st.add_index(a + row + 1)
					st.add_index(a + row)
			var mi := MeshInstance3D.new()
			mi.mesh = st.commit()
			mi.material_override = material
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)


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
