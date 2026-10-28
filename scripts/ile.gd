class_name Ile
extends Node3D
## Construit l'Île du Lazaret à partir de data/ile.json : relief, lieux et bâtiments,
## stations d'achat, végétation, ciel et lumière. Même méthode que Dernière Vague (tout en
## code, textures de Dernière Vague en placage triplanaire), mais en extérieur et en plein jour.

const T := 0.3          # épaisseur des murs
const FH := 3.2         # hauteur d'étage par défaut
const DOOR_W := 1.6
const DOOR_H := 2.4

var data: Dictionary
var terrain: Terrain
var sun: DirectionalLight3D
var env: Environment
var shops: Array[Node3D] = []
var lantern: Node3D
var stats := {"batiments": 0, "rampes": 0}

var mats := {}


# ------------------------------------------------------------------------------------------------
# Matériaux
# ------------------------------------------------------------------------------------------------
func _tex_mat(path: String, tint := Color(1, 1, 1), scale := 0.4, rough := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(path)
	m.albedo_color = tint
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(scale, scale, scale)
	m.roughness = rough
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


func _flat(c: Color, rough := 0.9, emission := Color(0, 0, 0), energy := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
	return m


func _make_materials() -> void:
	mats.enduit = _tex_mat("res://assets/tex/enduit.png", Color(1.0, 0.96, 0.88), 0.35)
	mats.enduit_ocre = _tex_mat("res://assets/tex/enduit.png", Color(0.98, 0.8, 0.6), 0.35)
	mats.enduit_rose = _tex_mat("res://assets/tex/enduit.png", Color(0.95, 0.78, 0.74), 0.35)
	mats.pierre = _tex_mat("res://assets/tex/pierre.png", Color(1.0, 0.97, 0.9), 0.3)
	mats.brick = _tex_mat("res://assets/tex/brick.png", Color(0.95, 0.85, 0.8), 0.5)
	mats.concrete = _tex_mat("res://assets/tex/concrete.png", Color(1.0, 0.98, 0.94), 0.3)
	mats.dalle = _tex_mat("res://assets/tex/concrete.png", Color(0.78, 0.76, 0.72), 0.3)
	mats.metal = _tex_mat("res://assets/tex/metal.png", Color(0.85, 0.88, 0.9), 0.5, 0.5)
	mats.metal.metallic = 0.3
	mats.wood = _tex_mat("res://assets/tex/wood.png", Color(1, 1, 1), 0.6, 0.8)
	mats.plancher = _tex_mat("res://assets/tex/wood.png", Color(0.8, 0.74, 0.66), 0.35, 0.8)
	mats.tuiles = _tex_mat("res://assets/tex/tuiles.png", Color(1, 1, 1), 0.45, 0.85)
	mats.volet_vert = _flat(Color(0.2, 0.36, 0.3))
	mats.volet_bleu = _flat(Color(0.24, 0.38, 0.5))
	mats.rouge = _flat(Color(0.62, 0.12, 0.1), 0.7)
	mats.jaune = _tex_mat("res://assets/tex/metal.png", Color(0.95, 0.72, 0.15), 0.5, 0.6)
	mats.vitre = _flat(Color(0.9, 0.95, 1.0), 0.1, Color(1.0, 0.92, 0.6), 2.5)
	mats.sel = _flat(Color(0.95, 0.94, 0.9), 0.7)
	mats.eau_bassin = _flat(Color(0.55, 0.75, 0.78), 0.08)
	mats.ecran = _flat(Color(1.0, 0.75, 0.15), 0.4, Color(1.0, 0.7, 0.1), 3.0)
	mats.tronc = _flat(Color(0.32, 0.24, 0.18), 1.0)
	mats.pin = _flat(Color(0.12, 0.2, 0.09), 0.95)
	mats.buisson = _flat(Color(0.2, 0.26, 0.12), 1.0)
	mats.roche = _tex_mat("res://assets/tex/pierre.png", Color(0.9, 0.88, 0.84), 0.25)
	mats.coques = [_flat(Color(0.86, 0.86, 0.82)), _flat(Color(0.2, 0.36, 0.55)), _flat(Color(0.7, 0.2, 0.15))]
	mats.conteneurs = [
		_tex_mat("res://assets/tex/metal.png", Color(0.75, 0.3, 0.22), 0.5, 0.6),
		_tex_mat("res://assets/tex/metal.png", Color(0.25, 0.42, 0.58), 0.5, 0.6),
		_tex_mat("res://assets/tex/metal.png", Color(0.32, 0.5, 0.32), 0.5, 0.6),
		_tex_mat("res://assets/tex/metal.png", Color(0.82, 0.62, 0.25), 0.5, 0.6),
	]


func mat(key: String) -> Material:
	return mats.get(key, mats.enduit)


# ------------------------------------------------------------------------------------------------
# Construction
# ------------------------------------------------------------------------------------------------
func build() -> void:
	data = G.data
	_make_materials()
	_environment()
	terrain = Terrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.build(float(data.monde), float(data.cellule))
	for lieu in data.lieux:
		_build_lieu(lieu)
	for s in data.boutiques:
		_shop(Vector3(s.x, 0, s.z))
	_vegetation()
	merge_static(24.0)


func _environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.24, 0.42, 0.68)
	sm.sky_horizon_color = Color(0.86, 0.74, 0.6)
	sm.ground_horizon_color = Color(0.78, 0.76, 0.72)
	sm.ground_bottom_color = Color(0.62, 0.68, 0.7)
	sm.sun_angle_max = 20.0
	sm.sun_curve = 0.12
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.86, 0.8, 0.72)
	env.ambient_light_sky_contribution = 0.45
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.78, 0.74, 0.68)
	env.fog_density = 0.0009
	env.fog_sky_affect = 0.0
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_hdr_threshold = 1.2
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.05
	env.adjustment_contrast = 1.05
	we.environment = env
	add_child(we)
	# Fin d'après-midi : soleil bas à l'ouest, lumière dorée, ombres longues.
	sun = DirectionalLight3D.new()
	sun.name = "Soleil"
	sun.light_color = Color(1.0, 0.88, 0.72)
	sun.light_energy = 1.25
	sun.rotation_degrees = Vector3(-32, -62, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 70.0
	sun.shadow_bias = 0.08
	add_child(sun)


# ------------------------------------------------------------------------------------------------
# Primitives (comme dans Dernière Vague)
# ------------------------------------------------------------------------------------------------
func box(parent: Node3D, center: Vector3, size: Vector3, m: Material, collide := true) -> Node3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.set_meta("merge", true)
	if not collide:
		parent.add_child(mi)
		mi.position = center
		return mi
	var body := StaticBody3D.new()
	body.collision_layer = G.L_WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	body.add_child(mi)
	parent.add_child(body)
	body.position = center
	return body


func cylinder(parent: Node3D, center: Vector3, r_bottom: float, height: float, m: Material,
		collide := true, r_top := -1.0, segments := 14) -> Node3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_bottom if r_top < 0.0 else r_top
	cm.bottom_radius = r_bottom
	cm.height = height
	cm.radial_segments = segments
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = m
	mi.set_meta("merge", true)
	if not collide:
		parent.add_child(mi)
		mi.position = center
		return mi
	var body := StaticBody3D.new()
	body.collision_layer = G.L_WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = maxf(r_bottom, cm.top_radius)
	shape.height = height
	cs.shape = shape
	body.add_child(cs)
	body.add_child(mi)
	parent.add_child(body)
	body.position = center
	return body


## Mur droit de a à b (au sol local, aligné sur un axe), d'une hauteur h à partir de y0,
## avec des ouvertures [début, fin, bas, haut] mesurées le long du mur depuis a.
func wall(parent: Node3D, a: Vector3, b: Vector3, openings: Array, m: Material, y0: float, h: float,
		thick := T) -> void:
	var length := a.distance_to(b)
	var axis := (b - a) / length
	openings.sort_custom(func(x, y): return x[0] < y[0])
	var cursor := 0.0
	for o in openings:
		if o[0] > cursor:
			_wall_piece(parent, a, axis, length, cursor, o[0], y0, y0 + h, m, thick)
		if o[2] > 0.0:
			_wall_piece(parent, a, axis, length, o[0], o[1], y0, y0 + o[2], m, thick)
		if o[3] < h:
			_wall_piece(parent, a, axis, length, o[0], o[1], y0 + o[3], y0 + h, m, thick)
		cursor = o[1]
	if cursor < length:
		_wall_piece(parent, a, axis, length, cursor, length, y0, y0 + h, m, thick)


func _wall_piece(parent: Node3D, a: Vector3, axis: Vector3, length: float, s: float, e: float,
		y0: float, y1: float, m: Material, thick: float) -> void:
	var s2 := s - (thick / 2 if s <= 0.001 else 0.0)
	var e2 := e + (thick / 2 if e >= length - 0.001 else 0.0)
	var mid := a + axis * ((s2 + e2) / 2) + Vector3(0, (y0 + y1) / 2, 0)
	var seg := e2 - s2
	var size := Vector3(seg, y1 - y0, thick) if abs(axis.x) > 0.5 else Vector3(thick, y1 - y0, seg)
	box(parent, mid, size, m)


## Plaque horizontale de rectangle (x0, z0)–(x1, z1) avec un trou rectangulaire (ou aucun).
func slab(parent: Node3D, x0: float, z0: float, x1: float, z1: float, y: float, thick: float,
		m: Material, hole := Rect2()) -> void:
	if hole.size == Vector2.ZERO:
		box(parent, Vector3((x0 + x1) / 2, y - thick / 2, (z0 + z1) / 2), Vector3(x1 - x0, thick, z1 - z0), m)
		return
	var hx0 := hole.position.x
	var hz0 := hole.position.y
	var hx1 := hole.end.x
	var hz1 := hole.end.y
	var parts := [
		[x0, z0, hx0, z1], [hx1, z0, x1, z1],     # à gauche et à droite du trou
		[hx0, z0, hx1, hz0], [hx0, hz1, hx1, z1], # devant et derrière
	]
	for p in parts:
		if p[2] - p[0] > 0.05 and p[3] - p[1] > 0.05:
			box(parent, Vector3((p[0] + p[2]) / 2, y - thick / 2, (p[1] + p[3]) / 2),
				Vector3(p[2] - p[0], thick, p[3] - p[1]), m)


## Rampe d'escalier montant de (x, y0, z0) vers +z sur une longueur au sol `run`.
func ramp(parent: Node3D, x: float, z0: float, y0: float, run: float, rise: float, width: float, m: Material) -> void:
	var angle := atan2(rise, run)
	var length := sqrt(run * run + rise * rise)
	var body := box(parent, Vector3(x, y0 + rise / 2 - 0.1, z0 + run / 2), Vector3(width, 0.2, length), m)
	body.rotation.x = -angle
	stats.rampes += 1


# ------------------------------------------------------------------------------------------------
# Lieux
# ------------------------------------------------------------------------------------------------
func _build_lieu(l: Dictionary) -> void:
	var root := Node3D.new()
	root.name = String(l.id).capitalize()
	add_child(root)
	root.position = Vector3(l.x, l.h, l.z)
	for b in l.batiments:
		var node := Node3D.new()
		root.add_child(node)
		node.position = Vector3(b.x, 0, b.z)
		node.rotation_degrees.y = float(b.get("r", 0))
		match String(b.t):
			"bat": _batiment(node, b)
			"hangar": _hangar(node, b)
			"bunker": _bunker(node, b)
			"phare": _phare(node, b)
			"mat": _mat(node, b)
			"citerne": _citerne(node)
			"cheminee": _cheminee(node, b)
			"quai": _quai(node, b, float(l.h))
			"grue": _grue(node)
			"conteneur": _conteneur(node, b)
			"mur": _mur(node, b)
			"tombes": _tombes(node, b)
			"bassins": _bassins(node, b)
			"tas": _tas(node)
			"fontaine": _fontaine(node)
			"emplacement": _emplacement(node)
			_: push_warning("Type de bâtiment inconnu : %s" % b.t)


## Bâtiment générique à étages : murs avec portes et fenêtres, planchers, rampe d'escalier
## le long d'un mur latéral, toit-terrasse avec parapet (accessible si "toit").
func _batiment(node: Node3D, b: Dictionary) -> void:
	stats.batiments += 1
	var w := float(b.w)
	var d := float(b.d)
	var floors := int(b.get("n", 1))
	var fh := float(b.get("fh", FH))
	var roof_access := bool(b.get("toit", false))
	var portes: Array = b.get("portes", [])
	var m := mat(String(b.get("m", "enduit")))
	# Variété des façades dans les villages : l'enduit change de teinte d'une maison à l'autre.
	if b.get("m", "") == "enduit":
		m = [mats.enduit, mats.enduit_ocre, mats.enduit_rose][int(absf(b.x * 3.0 + b.z * 7.0)) % 3]
	var x0 := -w / 2
	var x1 := w / 2
	var z0 := -d / 2
	var z1 := d / 2
	# Escalier : le long du mur est, sauf si seule une porte y est et pas à l'ouest.
	var stair_x := x1 - T / 2 - 0.8
	if portes.has("e") and not portes.has("w"):
		stair_x = x0 + T / 2 + 0.8
	var stair_side := "e" if stair_x > 0 else "w"
	var run := clampf(fh * 1.55, 3.0, d - T - 1.2)
	var sz0 := z0 + T / 2 + 0.5
	var has_stairs := floors > 1 or roof_access
	# Fondations jusque dans la pente.
	box(node, Vector3(0, -1.1, 0), Vector3(w + 0.2, 2.2, d + 0.2), mats.dalle)
	box(node, Vector3(0, 0.02, 0), Vector3(w - T, 0.04, d - T), mats.plancher if floors > 1 else mats.dalle, false)
	for k in floors:
		var y0 := k * fh
		# Plancher de l'étage (au-dessus du rez-de-chaussée), troué au-dessus de la rampe.
		if k > 0:
			slab(node, x0, z0, x1, z1, y0, 0.25, mats.dalle,
				Rect2(stair_x - 0.8, sz0 + run * 0.3, 1.6, run * 0.7 + 0.3))
			box(node, Vector3(0, y0 + 0.01, 0), Vector3(w - T, 0.02, d - T), mats.plancher, false)
		if has_stairs and (k < floors - 1 or roof_access):
			ramp(node, stair_x, sz0, y0, run, fh, 1.4, mats.dalle)
		var ground := k == 0
		for side in ["n", "s", "e", "w"]:
			var a: Vector3
			var e: Vector3
			match side:
				"n": a = Vector3(x0, 0, z0); e = Vector3(x1, 0, z0)
				"s": a = Vector3(x0, 0, z1); e = Vector3(x1, 0, z1)
				"w": a = Vector3(x0, 0, z0); e = Vector3(x0, 0, z1)
				"e": a = Vector3(x1, 0, z0); e = Vector3(x1, 0, z1)
			var length := a.distance_to(e)
			var openings := []
			var door := []
			if ground and portes.has(side):
				var c := length / 2
				if side == stair_side:
					# La porte ne doit pas tomber sur la rampe : on la décale derrière.
					var free0 := (sz0 - z0) + run + 0.6
					if c - DOOR_W / 2 < free0:
						c = (free0 + length - T) / 2
					if c + DOOR_W / 2 > length - T or c - DOOR_W / 2 < free0:
						c = -1.0
				if c > 0.0:
					door = [c - DOOR_W / 2, c + DOOR_W / 2]
					openings.append([door[0], door[1], 0.0, DOOR_H])
			# Fenêtres régulières, loin des angles et des portes.
			var count := int((length - 1.6) / 3.4)
			for i in count:
				var c := (i + 0.5) * (length / count) if count > 0 else 0.0
				if c < 1.0 or c > length - 1.0:
					continue
				if door.size() and c + 0.8 > door[0] - 0.4 and c - 0.8 < door[1] + 0.4:
					continue
				openings.append([c - 0.65, c + 0.65, 1.0, 2.2])
			wall(node, a, e, openings, m, y0, fh)
	# Toit-terrasse.
	var top := floors * fh
	if roof_access:
		slab(node, x0, z0, x1, z1, top, 0.25, mats.dalle, Rect2(stair_x - 0.8, sz0 + run * 0.3, 1.6, run * 0.7 + 0.3))
		for side in [[Vector3(x0, 0, z0), Vector3(x1, 0, z0)], [Vector3(x0, 0, z1), Vector3(x1, 0, z1)],
				[Vector3(x0, 0, z0), Vector3(x0, 0, z1)], [Vector3(x1, 0, z0), Vector3(x1, 0, z1)]]:
			wall(node, side[0], side[1], [], m, top, 1.0)
	else:
		slab(node, x0 - 0.15, z0 - 0.15, x1 + 0.15, z1 + 0.15, top + 0.25, 0.3, mats.dalle)
		var small := floors == 1 and fh <= 4.0 and w <= 10.0 and d <= 10.0
		if small:
			_toit_tuiles(node, w, d, top + 0.25)
		else:
			wall(node, Vector3(x0, 0, z0), Vector3(x1, 0, z0), [], m, top + 0.25, 0.5)
			wall(node, Vector3(x0, 0, z1), Vector3(x1, 0, z1), [], m, top + 0.25, 0.5)
			wall(node, Vector3(x0, 0, z0), Vector3(x0, 0, z1), [], m, top + 0.25, 0.5)
			wall(node, Vector3(x1, 0, z0), Vector3(x1, 0, z1), [], m, top + 0.25, 0.5)
	# Volets de couleur à côté des fenêtres des petites maisons (décor).
	if w <= 12.0 and d <= 12.0:
		var vm: Material = mats.volet_vert if int(absf(b.x + b.z)) % 2 == 0 else mats.volet_bleu
		for k in floors:
			for sx in [-1.0, 1.0]:
				box(node, Vector3(sx * (w / 4), k * fh + 1.6, z1 + T / 2 + 0.04), Vector3(0.5, 1.3, 0.06), vm, false)


func _toit_tuiles(node: Node3D, w: float, d: float, y: float) -> void:
	# Toit à deux pans (faîte selon x), tuiles de Dernière Vague.
	var slope := deg_to_rad(22.0)
	var half_d := d / 2 + 0.35
	var pan := half_d / cos(slope)
	for s in [-1.0, 1.0]:
		var b := box(node, Vector3(0, y + tan(slope) * half_d / 2, s * half_d / 2), Vector3(w + 0.7, 0.18, pan), mats.tuiles)
		b.rotation.x = s * slope
	# Pignons.
	for sx in [-1.0, 1.0]:
		var gable := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(d, tan(slope) * d / 2, 0.25)
		gable.mesh = pm
		gable.material_override = mats.enduit
		node.add_child(gable)
		gable.position = Vector3(sx * (w / 2 - 0.12), y + pm.size.y / 2, 0)
		gable.rotation.y = PI / 2


func _hangar(node: Node3D, b: Dictionary) -> void:
	stats.batiments += 1
	var w := float(b.w)
	var d := float(b.d)
	var h := float(b.h)
	var portes: Array = b.get("portes", [])
	var m := mat(String(b.get("m", "metal")))
	box(node, Vector3(0, -1.1, 0), Vector3(w + 0.2, 2.2, d + 0.2), mats.dalle)
	for side in ["n", "s", "e", "w"]:
		var a: Vector3
		var e: Vector3
		match side:
			"n": a = Vector3(-w / 2, 0, -d / 2); e = Vector3(w / 2, 0, -d / 2)
			"s": a = Vector3(-w / 2, 0, d / 2); e = Vector3(w / 2, 0, d / 2)
			"w": a = Vector3(-w / 2, 0, -d / 2); e = Vector3(-w / 2, 0, d / 2)
			"e": a = Vector3(w / 2, 0, -d / 2); e = Vector3(w / 2, 0, d / 2)
		var length := a.distance_to(e)
		var openings := []
		var door_w := minf(4.0, length - 2.0)
		if portes.has(side):
			openings.append([length / 2 - door_w / 2, length / 2 + door_w / 2, 0.0, minf(4.0, h - 1.0)])
		# Fenêtres hautes.
		var count := int(length / 5.0)
		for i in count:
			var c := (i + 0.5) * length / count
			if portes.has(side) and absf(c - length / 2) < door_w / 2 + 1.2:
				continue
			openings.append([c - 1.0, c + 1.0, h - 2.4, h - 1.0])
		wall(node, a, e, openings, m, 0.0, h)
	slab(node, -w / 2 - 0.3, -d / 2 - 0.3, w / 2 + 0.3, d / 2 + 0.3, h + 0.3, 0.3, mats.metal)
	# Couverture à l'intérieur : établis et cuves en rangées.
	var rows := int(d / 8.0)
	for i in rows:
		var z := -d / 2 + (i + 0.5) * d / rows
		if w >= 14.0:
			box(node, Vector3(-w / 4, 0.5, z), Vector3(w / 4, 1.0, 1.2), mats.metal)
			cylinder(node, Vector3(w / 4, 1.1, z), 1.1, 2.2, mats.metal)
		else:
			box(node, Vector3(w / 2 - 1.2, 0.6, z), Vector3(1.4, 1.2, 2.4), mats.wood)


func _bunker(node: Node3D, b: Dictionary) -> void:
	stats.batiments += 1
	var w := float(b.w)
	var d := float(b.d)
	var h := 2.7
	var th := 0.8
	var portes: Array = b.get("portes", [])
	box(node, Vector3(0, -1.1, 0), Vector3(w + 1.0, 2.2, d + 1.0), mats.concrete)
	for side in ["n", "s", "e", "w"]:
		var a: Vector3
		var e: Vector3
		match side:
			"n": a = Vector3(-w / 2, 0, -d / 2); e = Vector3(w / 2, 0, -d / 2)
			"s": a = Vector3(-w / 2, 0, d / 2); e = Vector3(w / 2, 0, d / 2)
			"w": a = Vector3(-w / 2, 0, -d / 2); e = Vector3(-w / 2, 0, d / 2)
			"e": a = Vector3(w / 2, 0, -d / 2); e = Vector3(w / 2, 0, d / 2)
		var length := a.distance_to(e)
		var openings := []
		if portes.has(side):
			openings.append([length / 2 - 0.8, length / 2 + 0.8, 0.0, 2.2])
		if side == "n":
			# Meurtrières face à la mer.
			for c in [length * 0.25, length * 0.75]:
				if not portes.has(side) or absf(c - length / 2) > 1.8:
					openings.append([c - 1.1, c + 1.1, 1.3, 1.7])
		wall(node, a, e, openings, mats.concrete, 0.0, h, th)
	slab(node, -w / 2 - 0.6, -d / 2 - 0.6, w / 2 + 0.6, d / 2 + 0.6, h + 0.6, 0.6, mats.concrete)
	# Talus de terre contre les flancs (couverture, et l'air enterré).
	for sx in [-1.0, 1.0]:
		var t := box(node, Vector3(sx * (w / 2 + 1.2), 0.6, 0), Vector3(2.2, 1.8, d * 0.8), mats.roche)
		t.rotation.z = sx * 0.5


func _phare(node: Node3D, b: Dictionary) -> void:
	var h := float(b.h)
	cylinder(node, Vector3(0, h / 2, 0), 3.4, h, mats.enduit, true, 2.6, 18)
	# Bande rouge et porte.
	var r_at := func(y: float) -> float: return 3.4 - 0.8 * y / h
	cylinder(node, Vector3(0, h * 0.62, 0), r_at.call(h * 0.62 - 1.0) + 0.04, 2.0, mats.rouge, false, r_at.call(h * 0.62 + 1.0) + 0.04, 18)
	box(node, Vector3(0, 1.2, 3.35), Vector3(1.3, 2.4, 0.2), mats.volet_vert, false)
	# Galerie et lanterne.
	cylinder(node, Vector3(0, h + 0.15, 0), 3.6, 0.3, mats.metal)
	cylinder(node, Vector3(0, h + 1.4, 0), 1.6, 2.2, mats.vitre, false, 1.6, 12)
	cylinder(node, Vector3(0, h + 2.9, 0), 1.8, 0.8, mats.rouge, false, 0.3, 12)
	for i in 12:
		var a := TAU * i / 12.0
		box(node, Vector3(cos(a) * 3.45, h + 0.8, sin(a) * 3.45), Vector3(0.08, 1.0, 0.08), mats.metal, false)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.9, 0.6)
	l.light_energy = 2.0
	l.omni_range = 14.0
	node.add_child(l)
	l.position = Vector3(0, h + 1.4, 0)
	lantern = node


func _mat(node: Node3D, b: Dictionary) -> void:
	var h := float(b.h)
	box(node, Vector3(0, 0.4, 0), Vector3(3.0, 0.8, 3.0), mats.concrete)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var leg := box(node, Vector3(sx * 0.6, h / 2, sz * 0.6), Vector3(0.12, h, 0.12), mats.rouge, false)
			leg.rotation = Vector3(sz * 0.02, 0, -sx * 0.02)
	var y := 2.5
	while y < h - 1.0:
		var s := 1.2 * (1.0 - y / h * 0.6)
		box(node, Vector3(0, y, 0), Vector3(s + 0.2, 0.08, 0.08), mats.metal, false)
		box(node, Vector3(0, y, 0), Vector3(0.08, 0.08, s + 0.2), mats.metal, false)
		y += 3.0
	box(node, Vector3(0, h + 0.3, 0), Vector3(0.3, 0.6, 0.3), mats.ecran, false)


func _citerne(node: Node3D) -> void:
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			box(node, Vector3(sx * 3.0, 6.5, sz * 3.0), Vector3(0.5, 13.0, 0.5), mats.concrete)
	box(node, Vector3(0, 6.0, 0), Vector3(6.2, 0.25, 0.25), mats.concrete, false)
	box(node, Vector3(0, 6.0, 0), Vector3(0.25, 0.25, 6.2), mats.concrete, false)
	cylinder(node, Vector3(0, 15.5, 0), 5.0, 5.0, mats.concrete, true, 5.0, 20)
	cylinder(node, Vector3(0, 18.6, 0), 5.2, 1.2, mats.dalle, false, 1.0, 20)
	# Échelle (décor).
	for i in 20:
		box(node, Vector3(3.3, 0.6 * i + 0.4, 3.3), Vector3(0.5, 0.05, 0.05), mats.metal, false)


func _cheminee(node: Node3D, b: Dictionary) -> void:
	var h := float(b.h)
	box(node, Vector3(0, 1.0, 0), Vector3(4.0, 2.0, 4.0), mats.brick)
	cylinder(node, Vector3(0, h / 2, 0), 1.8, h, mats.brick, true, 1.2, 14)
	cylinder(node, Vector3(0, h + 0.3, 0), 1.45, 0.6, mats.dalle, false, 1.45, 14)


func _quai(node: Node3D, b: Dictionary, ground_h: float) -> void:
	# Ponton en bois : le plancher est un peu sous le niveau du lieu, sur pilotis.
	var w := float(b.w)
	var d := float(b.d)
	var deck := -0.3
	var y_sea := -ground_h
	box(node, Vector3(0, deck - 0.2, 0), Vector3(w, 0.4, d), mats.wood)
	var piles := int(d / 4.0)
	for i in piles + 1:
		var z := -d / 2 + i * d / piles
		for sx in [-1.0, 1.0]:
			var top := deck - 0.4
			var bottom := y_sea - 6.0
			cylinder(node, Vector3(sx * (w / 2 - 0.3), (top + bottom) / 2, z), 0.25, top - bottom, mats.wood, true, -1.0, 6)
	# Bittes d'amarrage et barques le long du ponton.
	for i in int(d / 10.0):
		var z := -d / 2 + 5.0 + i * 10.0
		cylinder(node, Vector3(w / 2 - 0.5, deck + 0.3, z), 0.2, 0.6, mats.metal, false, -1.0, 6)
		if i % 2 == 0 and d > 20.0:
			_barque(node, Vector3(w / 2 + 2.2, y_sea + 0.25, z + 1.5), i)


func _barque(node: Node3D, p: Vector3, i: int) -> void:
	var hull := box(node, p, Vector3(1.8, 0.8, 5.0), mats.coques[i % 3], false)
	var bow := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(1.8, 1.2, 0.8)
	bow.mesh = pm
	bow.material_override = mats.coques[i % 3]
	node.add_child(bow)
	bow.position = p + Vector3(0, 0, -3.1)
	bow.rotation = Vector3(-PI / 2, 0, 0)
	box(node, p + Vector3(0, 0.3, 0), Vector3(1.5, 0.08, 4.4), mats.wood, false)
	hull.set_meta("merge", false)


func _grue(node: Node3D) -> void:
	box(node, Vector3(0, -0.3 + 1.0, 0), Vector3(3.0, 2.0, 3.0), mats.jaune)
	box(node, Vector3(0, 9.0, 0), Vector3(1.0, 16.0, 1.0), mats.jaune)
	box(node, Vector3(4.0, 17.3, 0), Vector3(16.0, 0.8, 0.8), mats.jaune, false)
	box(node, Vector3(-4.5, 16.6, 0), Vector3(2.0, 1.4, 1.4), mats.concrete, false)
	box(node, Vector3(10.0, 12.5, 0), Vector3(0.06, 9.0, 0.06), mats.metal, false)
	box(node, Vector3(10.0, 7.8, 0), Vector3(0.6, 0.6, 0.6), mats.metal, false)


func _conteneur(node: Node3D, b: Dictionary) -> void:
	var stack := int(b.get("n", 1))
	for k in stack:
		var m: Material = mats.conteneurs[(int(absf(b.x * 5.0 + b.z * 3.0)) + k) % mats.conteneurs.size()]
		var c := box(node, Vector3(0, 1.3 + k * 2.6, 0), Vector3(6.0, 2.6, 2.4), m)
		if k > 0:
			c.rotation.y = 0.06
	# Nervures (décor).
	for i in 7:
		box(node, Vector3(-2.7 + i * 0.9, 1.3, 1.23), Vector3(0.12, 2.4, 0.06), mats.metal, false)


func _mur(node: Node3D, b: Dictionary) -> void:
	var w := float(b.w)
	var h := float(b.get("h", 1.5))
	box(node, Vector3(0, (h - 1.0) / 2, 0), Vector3(w, h + 1.0, 0.5), mats.pierre)
	box(node, Vector3(0, h + 0.05, 0), Vector3(w + 0.1, 0.1, 0.6), mats.dalle, false)


func _tombes(node: Node3D, b: Dictionary) -> void:
	var w := float(b.w)
	var d := float(b.d)
	var i := 0
	var z := -d / 2 + 1.2
	while z < d / 2 - 1.0:
		var x := -w / 2 + 1.0
		while x < w / 2 - 0.5:
			box(node, Vector3(x, 0.3, z), Vector3(0.9, 0.6, 2.0), mats.pierre)
			if i % 3 == 0:
				box(node, Vector3(x, 1.1, z - 0.9), Vector3(0.12, 1.0, 0.12), mats.dalle, false)
				box(node, Vector3(x, 1.35, z - 0.9), Vector3(0.6, 0.12, 0.12), mats.dalle, false)
			else:
				box(node, Vector3(x, 0.9, z - 0.85), Vector3(0.8, 0.9, 0.15), mats.dalle)
			x += 2.2
			i += 1
		z += 3.2


func _bassins(node: Node3D, b: Dictionary) -> void:
	var w := float(b.w)
	var d := float(b.d)
	var nx := int(b.nx)
	var nz := int(b.nz)
	for i in nx + 1:
		var x := -w / 2 + i * w / nx
		box(node, Vector3(x, 0.15, 0), Vector3(0.5, 0.7, d), mats.dalle)
	for j in nz + 1:
		var z := -d / 2 + j * d / nz
		box(node, Vector3(0, 0.15, z), Vector3(w, 0.7, 0.5), mats.dalle)
	for i in nx:
		for j in nz:
			var cx := -w / 2 + (i + 0.5) * w / nx
			var cz := -d / 2 + (j + 0.5) * d / nz
			var m: Material = mats.eau_bassin if (i + j) % 3 != 1 else mats.sel
			box(node, Vector3(cx, 0.08, cz), Vector3(w / nx - 0.5, 0.04, d / nz - 0.5), m, false)


func _tas(node: Node3D) -> void:
	cylinder(node, Vector3(0, 1.1, 0), 3.0, 2.2, mats.sel, true, 0.25, 12)


func _fontaine(node: Node3D) -> void:
	cylinder(node, Vector3(0, 0.35, 0), 2.0, 0.7, mats.pierre, true, 2.0, 16)
	cylinder(node, Vector3(0, 0.66, 0), 1.75, 0.05, mats.eau_bassin, false, 1.75, 16)
	cylinder(node, Vector3(0, 1.2, 0), 0.3, 1.6, mats.pierre, true, 0.22, 8)


func _emplacement(node: Node3D) -> void:
	# Cuve de canon : parapet circulaire ouvert vers le sud, vieux canon rouillé au centre.
	for i in 12:
		var a := TAU * i / 12.0
		if absf(wrapf(a - PI / 2, -PI, PI)) < 0.4:
			continue
		var p := box(node, Vector3(cos(a) * 4.0, 0.6, sin(a) * 4.0), Vector3(2.2, 1.2, 0.7), mats.concrete)
		p.rotation.y = -a + PI / 2
	cylinder(node, Vector3(0, 0.5, 0), 1.0, 1.0, mats.metal)
	var barrel := cylinder(node, Vector3(0, 1.2, -2.0), 0.18, 4.0, mats.metal, false, 0.14, 8)
	barrel.rotation.x = PI / 2 - 0.12


# ------------------------------------------------------------------------------------------------
# Stations d'achat (le magasin du mode Résurgence ; l'achat viendra au jalon 2)
# ------------------------------------------------------------------------------------------------
func _shop(p: Vector3) -> void:
	var node := Node3D.new()
	node.name = "StationAchat"
	add_child(node)
	p.y = terrain.height_at(p.x, p.z)
	node.position = p
	box(node, Vector3(0, -0.4, 0), Vector3(2.4, 0.8, 1.6), mats.dalle)
	box(node, Vector3(0, 1.05, 0), Vector3(1.4, 2.1, 0.8), mats.metal)
	var screen := box(node, Vector3(0, 1.45, 0.41), Vector3(1.1, 0.8, 0.02), mats.ecran, false)
	screen.set_meta("merge", false)
	var label := Label3D.new()
	label.text = "ACHATS"
	label.font_size = 64
	label.outline_size = 12
	label.modulate = Color(1.0, 0.78, 0.2)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = false
	label.pixel_size = 0.012
	label.no_depth_test = false
	node.add_child(label)
	label.position = Vector3(0, 3.0, 0)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.75, 0.3)
	light.light_energy = 1.2
	light.omni_range = 5.0
	node.add_child(light)
	light.position = Vector3(0, 1.6, 1.0)
	shops.append(node)


# ------------------------------------------------------------------------------------------------
# Végétation : pins parasols, buissons, rochers (data/vegetation.json)
# ------------------------------------------------------------------------------------------------
func _multimesh(mesh: Mesh, m: Material, xforms: Array) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = m
	add_child(mmi)


func _vegetation() -> void:
	var veg := G.load_json("res://data/vegetation.json")
	var trunks := []
	var crowns := []
	var crowns2 := []
	var colliders := StaticBody3D.new()
	colliders.name = "Arbres"
	colliders.collision_layer = G.L_WORLD
	colliders.collision_mask = 0
	add_child(colliders)
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = 0.35
	trunk_shape.height = 6.0
	for t in veg.get("pins", []):
		var x := float(t[0])
		var z := float(t[1])
		var h := float(t[2])
		var yaw := deg_to_rad(float(t[3]))
		var y := terrain.height_at(x, z)
		# Tronc légèrement penché (les pins parasols poussent de travers), couronne plate.
		var lean := Basis(Vector3(cos(yaw), 0, sin(yaw)), 0.12)
		var tb := lean * Basis.from_scale(Vector3(1, h, 1))
		trunks.append(Transform3D(tb, Vector3(x, y - 0.3, z) + lean * Vector3(0, h / 2, 0)))
		var top := Vector3(x, y, z) + lean * Vector3(0, h, 0)
		var cs := h * 0.42
		crowns.append(Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(cs, cs * 0.32, cs)), top))
		crowns2.append(Transform3D(Basis(Vector3.UP, yaw + 1.0) * Basis.from_scale(Vector3(cs * 0.7, cs * 0.28, cs * 0.75)),
			top + Vector3(cs * 0.25, cs * 0.12, -cs * 0.2)))
		var c := CollisionShape3D.new()
		c.shape = trunk_shape
		colliders.add_child(c)
		c.position = Vector3(x, y + 3.0, z)
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.16
	trunk_mesh.bottom_radius = 0.28
	trunk_mesh.height = 1.0
	trunk_mesh.radial_segments = 6
	trunk_mesh.rings = 1
	_multimesh(trunk_mesh, mats.tronc, trunks)
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 1.0
	crown_mesh.height = 2.0
	crown_mesh.radial_segments = 10
	crown_mesh.rings = 5
	_multimesh(crown_mesh, mats.pin, crowns)
	_multimesh(crown_mesh, mats.pin, crowns2)

	var bushes := []
	for t in veg.get("buissons", []):
		var x := float(t[0])
		var z := float(t[1])
		var s := float(t[2])
		bushes.append(Transform3D(Basis.from_scale(Vector3(s * 0.9, s * 0.55, s * 0.8)), Vector3(x, terrain.height_at(x, z) + s * 0.15, z)))
	var bush_mesh := SphereMesh.new()
	bush_mesh.radius = 1.0
	bush_mesh.height = 2.0
	bush_mesh.radial_segments = 7
	bush_mesh.rings = 4
	_multimesh(bush_mesh, mats.buisson, bushes)

	var rocks := []
	var rock_body := StaticBody3D.new()
	rock_body.name = "Rochers"
	rock_body.collision_layer = G.L_WORLD
	rock_body.collision_mask = 0
	add_child(rock_body)
	for t in veg.get("rochers", []):
		var x := float(t[0])
		var z := float(t[1])
		var s := float(t[2])
		var yaw := deg_to_rad(float(t[3]))
		var y := terrain.height_at(x, z)
		rocks.append(Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(s * 1.3, s * 0.7, s)), Vector3(x, y + s * 0.15, z)))
		if s > 1.2:
			var c := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(s * 1.8, s * 1.0, s * 1.4)
			c.shape = bs
			rock_body.add_child(c)
			c.position = Vector3(x, y + s * 0.2, z)
			c.rotation.y = yaw
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 1.0
	rock_mesh.height = 2.0
	rock_mesh.radial_segments = 6
	rock_mesh.rings = 3
	_multimesh(rock_mesh, mats.roche, rocks)


# ------------------------------------------------------------------------------------------------
# Moins d'appels de dessin pour les téléphones (repris de Dernière Vague)
# ------------------------------------------------------------------------------------------------
func merge_static(cell := 24.0) -> void:
	var groups := {}
	var inv := global_transform.affine_inverse()
	for nd in find_children("*", "MeshInstance3D", true, false):
		var mi := nd as MeshInstance3D
		if not mi.has_meta("merge") or not mi.get_meta("merge") or mi.mesh == null or mi.material_override == null:
			continue
		var xf := inv * mi.global_transform
		var c := xf.origin
		var key := [mi.material_override, int(floor(c.x / cell)), int(floor(c.z / cell))]
		if not groups.has(key):
			groups[key] = []
		groups[key].append([mi, xf])
	for key in groups:
		var items: Array = groups[key]
		if items.size() < 2:
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for it in items:
			st.append_from(it[0].mesh, 0, it[1])
		var merged := MeshInstance3D.new()
		merged.mesh = st.commit()
		merged.material_override = key[0]
		add_child(merged)
		for it in items:
			var mi: MeshInstance3D = it[0]
			mi.get_parent().remove_child(mi)
			mi.free()


## Hauteur du sol ou du toit sous un point (rayon vers le bas), pour poser le joueur.
func ground_at(x: float, z: float, from_y := 120.0) -> float:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, from_y, z), Vector3(x, -30, z), G.L_WORLD)
	var hit := space.intersect_ray(q)
	return hit.position.y if hit else terrain.height_at(x, z)
