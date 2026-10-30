class_name GunShapes
extends RefCounted
## Silhouettes de profil de chaque arme (reprises de Dernière Vague), en rectangles en mètres
## (x vers la bouche du canon, y vers le haut), extrudées pour les modèles 3D.



const KIND_OF := {
	"p9": "pistol", "taureau": "revolver", "vipere": "smg", "ouragan": "smg2", "k14": "rifle",
	"faucon": "ar", "grele": "shotgun", "machoire": "double", "titan": "lmg", "aiguille": "sniper",
	"desint": "wonder", "uzi": "uzi", "rpg": "launcher", "hache": "axe", "sabre": "blade",
}


static func shape(weapon_id: String, acc: Array = []) -> Dictionary:
	var kind: String = KIND_OF.get(weapon_id, "pistol")
	var parts: Array = []
	var grip := Vector2.ZERO
	var muzzle := Vector2.ZERO
	var depth := 0.045
	match kind:
		"pistol":
			parts = [
				_r(0.11, 0.035, 0.22, 0.05, 0.0, "metal", "bolt"),
				_r(0.04, -0.035, 0.045, 0.1, -0.25, "dark"),
				_r(0.03, -0.075, 0.035, 0.03, -0.25, "metal", "mag"),
				_r(0.085, -0.012, 0.045, 0.02, 0.0, "dark"),
			]
			grip = Vector2(0.04, -0.04); muzzle = Vector2(0.23, 0.04); depth = 0.032
		"revolver":
			parts = [
				_r(0.19, 0.045, 0.2, 0.03, 0.0, "metal"),
				_r(0.08, 0.035, 0.07, 0.06, 0.0, "metal", "cyl"),
				_r(0.05, 0.05, 0.1, 0.035, 0.0, "metal"),
				_r(0.0, -0.03, 0.05, 0.1, -0.4, "wood"),
			]
			grip = Vector2(0.0, -0.035); muzzle = Vector2(0.3, 0.045); depth = 0.04
		"smg":
			parts = [
				_r(0.3, 0.03, 0.34, 0.08, 0.0, "dark"),
				_r(0.53, 0.04, 0.14, 0.03, 0.0, "metal"),
				_r(0.33, -0.09, 0.04, 0.16, 0.0, "metal", "mag"),
				_r(0.19, -0.065, 0.045, 0.11, -0.2, "dark"),
				_r(0.07, 0.02, 0.14, 0.035, 0.0, "metal"),
				_r(0.3, 0.085, 0.1, 0.02, 0.0, "metal", "bolt"),
			]
			grip = Vector2(0.19, -0.06); muzzle = Vector2(0.61, 0.04)
		"smg2":
			parts = [
				_r(0.28, 0.035, 0.3, 0.09, 0.0, "dark"),
				_r(0.48, 0.04, 0.12, 0.05, 0.0, "dark"),
				_r(0.58, 0.04, 0.1, 0.03, 0.0, "metal"),
				_r(0.3, -0.1, 0.045, 0.18, 0.12, "metal", "mag"),
				_r(0.17, -0.06, 0.045, 0.11, -0.2, "dark"),
				_r(0.06, 0.03, 0.12, 0.06, 0.0, "dark"),
			]
			grip = Vector2(0.17, -0.055); muzzle = Vector2(0.64, 0.04)
		"rifle":
			parts = [
				_r(0.12, -0.015, 0.26, 0.08, 0.08, "wood"),
				_r(0.46, 0.02, 0.44, 0.06, 0.0, "wood"),
				_r(0.8, 0.04, 0.32, 0.025, 0.0, "metal"),
				_r(0.4, 0.06, 0.24, 0.03, 0.0, "metal", "bolt"),
				_r(0.4, -0.05, 0.05, 0.08, 0.0, "metal", "mag"),
			]
			grip = Vector2(0.28, -0.03); muzzle = Vector2(0.96, 0.04)
		"ar":
			parts = [
				_r(0.08, 0.0, 0.17, 0.085, 0.0, "dark"),
				_r(0.35, 0.03, 0.36, 0.08, 0.0, "dark"),
				_r(0.6, 0.035, 0.18, 0.06, 0.0, "dark"),
				_r(0.77, 0.04, 0.17, 0.025, 0.0, "metal"),
				_r(0.39, -0.1, 0.05, 0.15, 0.28, "metal", "mag"),
				_r(0.24, -0.065, 0.045, 0.1, -0.25, "dark"),
				_r(0.36, 0.09, 0.09, 0.035, 0.0, "metal", "bolt"),
			]
			grip = Vector2(0.24, -0.06); muzzle = Vector2(0.86, 0.04)
		"shotgun":
			parts = [
				_r(0.12, -0.02, 0.26, 0.08, 0.1, "wood"),
				_r(0.37, 0.02, 0.26, 0.07, 0.0, "metal"),
				_r(0.72, 0.045, 0.5, 0.035, 0.0, "metal"),
				_r(0.68, 0.005, 0.42, 0.022, 0.0, "metal"),
				_r(0.64, 0.0, 0.2, 0.055, 0.0, "wood", "pump"),
			]
			grip = Vector2(0.26, -0.03); muzzle = Vector2(0.97, 0.045)
		"double":
			parts = [
				_r(0.12, -0.02, 0.26, 0.085, 0.12, "wood"),
				_r(0.33, 0.02, 0.18, 0.07, 0.0, "metal"),
				_r(0.68, 0.055, 0.56, 0.03, 0.0, "metal", "barrel"),
				_r(0.68, 0.025, 0.56, 0.03, 0.0, "metal", "barrel"),
				_r(0.56, 0.0, 0.3, 0.04, 0.0, "wood", "barrel"),
			]
			grip = Vector2(0.24, -0.03); muzzle = Vector2(0.96, 0.04)
		"lmg":
			parts = [
				_r(0.08, 0.0, 0.18, 0.09, 0.0, "dark"),
				_r(0.4, 0.03, 0.46, 0.1, 0.0, "dark"),
				_r(0.82, 0.04, 0.38, 0.04, 0.0, "metal"),
				_r(0.44, -0.08, 0.14, 0.12, 0.0, "metal", "mag"),
				_r(0.46, 0.11, 0.12, 0.025, 0.0, "metal", "bolt"),
				_r(0.25, -0.07, 0.05, 0.1, -0.25, "dark"),
			]
			grip = Vector2(0.25, -0.06); muzzle = Vector2(1.01, 0.04); depth = 0.06
		"sniper":
			parts = [
				_r(0.13, -0.015, 0.27, 0.09, 0.08, "wood"),
				_r(0.48, 0.02, 0.42, 0.06, 0.0, "wood"),
				_r(0.93, 0.035, 0.5, 0.025, 0.0, "metal"),
				_r(0.45, 0.1, 0.32, 0.05, 0.0, "dark"),
				_r(0.36, 0.055, 0.03, 0.03, 0.0, "metal", "bolt"),
			]
			grip = Vector2(0.3, -0.03); muzzle = Vector2(1.18, 0.035)
		"wonder":
			parts = [
				_r(0.25, 0.03, 0.3, 0.12, 0.0, "metal"),
				_r(0.42, 0.03, 0.03, 0.16, 0.0, "glow"),
				_r(0.47, 0.03, 0.03, 0.15, 0.0, "glow"),
				_r(0.52, 0.03, 0.03, 0.14, 0.0, "glow"),
				_r(0.59, 0.03, 0.08, 0.05, 0.0, "glow"),
				_r(0.15, -0.08, 0.05, 0.11, -0.2, "dark"),
				_r(0.25, 0.11, 0.17, 0.05, 0.0, "glow", "mag"),
			]
			grip = Vector2(0.15, -0.07); muzzle = Vector2(0.65, 0.03); depth = 0.07
		"uzi":
			parts = [
				_r(0.12, 0.03, 0.22, 0.065, 0.0, "dark"),
				_r(0.26, 0.035, 0.07, 0.025, 0.0, "metal"),
				_r(0.08, -0.04, 0.045, 0.09, -0.1, "dark"),
				_r(0.072, -0.115, 0.035, 0.08, -0.1, "metal", "mag"),
				_r(0.14, 0.07, 0.08, 0.015, 0.0, "metal", "bolt"),
				_r(0.0, 0.025, 0.05, 0.03, 0.0, "metal"),
			]
			grip = Vector2(0.08, -0.04); muzzle = Vector2(0.3, 0.035); depth = 0.035
		"launcher":
			parts = [
				_r(0.35, 0.06, 0.95, 0.09, 0.0, "metal"),
				_r(0.4, 0.06, 0.3, 0.11, 0.0, "wood"),
				_r(0.86, 0.06, 0.08, 0.12, 0.0, "dark"),
				_r(-0.12, 0.06, 0.06, 0.12, 0.0, "dark"),
				_r(0.97, 0.06, 0.14, 0.075, 0.0, "glow", "mag"),
				_r(1.07, 0.06, 0.07, 0.04, 0.0, "glow", "mag"),
				_r(0.3, -0.04, 0.045, 0.1, -0.15, "wood"),
				_r(0.52, -0.03, 0.04, 0.08, 0.0, "wood"),
				_r(0.42, 0.13, 0.07, 0.04, 0.0, "dark"),
			]
			grip = Vector2(0.3, -0.04); muzzle = Vector2(0.92, 0.06); depth = 0.1
		"axe":
			parts = [
				_r(0.25, 0.0, 0.62, 0.035, 0.0, "wood"),
				_r(-0.06, 0.0, 0.04, 0.05, 0.0, "dark"),
				_r(0.52, 0.06, 0.1, 0.16, 0.0, "metal"),
				_r(0.52, 0.17, 0.22, 0.06, 0.0, "metal"),
				_r(0.52, -0.05, 0.06, 0.06, 0.0, "dark"),
			]
			grip = Vector2(0.0, 0.0); muzzle = Vector2(0.55, 0.18); depth = 0.035
		"blade":
			parts = [
				_r(0.03, 0.0, 0.13, 0.035, 0.0, "dark"),
				_r(-0.045, 0.0, 0.03, 0.045, 0.0, "metal"),
				_r(0.105, 0.0, 0.025, 0.11, 0.0, "metal"),
				_r(0.37, 0.005, 0.5, 0.032, 0.0, "metal"),
				_r(0.76, 0.02, 0.3, 0.026, 0.08, "metal"),
			]
			grip = Vector2(0.02, 0.0); muzzle = Vector2(0.9, 0.03); depth = 0.02
	var sight := -100.0
	if not acc.is_empty():
		var r := _accessoires(parts, grip, muzzle, acc)
		muzzle = r[0]
		sight = r[1]
	return {"parts": parts, "grip": grip, "muzzle": muzzle, "depth": depth, "kind": kind, "sight": sight}


## Ajoute les accessoires à la silhouette : canon puis bouche au bout du canon, viseur sur le
## dessus, chargeur sous le chargeur d'origine, crosse à l'arrière. Renvoie [la nouvelle bouche,
## la hauteur de la ligne de visée du viseur posé (-100 : pas de viseur)].
static func _accessoires(parts: Array, grip: Vector2, muzzle: Vector2, acc: Array) -> Array:
	var top := -10.0
	var top_x := grip.x + 0.1
	var rear := 10.0
	var rear_y := grip.y + 0.03
	var mag: Dictionary = {}
	for p in parts:
		var hi: float = p.p.y + p.s.y / 2.0
		if hi > top and p.p.x > grip.x - 0.02 and p.p.x < muzzle.x - 0.08:
			top = hi
			top_x = p.p.x
		var back: float = p.p.x - p.s.x / 2.0
		if back < rear:
			rear = back
			rear_y = p.p.y
		if p.role == "mag" and mag.is_empty():
			mag = p
	if top < -5.0:
		top = muzzle.y + 0.03
	var has := func(id: String) -> bool: return acc.has(id)
	var sight := -100.0
	if has.call("canon_long"):
		parts.append(_r(muzzle.x + 0.07, muzzle.y, 0.14, 0.022, 0.0, "metal"))
		muzzle.x += 0.14
	if has.call("canon_court"):
		parts.append(_r(muzzle.x - 0.07, muzzle.y, 0.14, 0.05, 0.0, "dark"))
	if has.call("silencieux"):
		parts.append(_r(muzzle.x + 0.1, muzzle.y, 0.2, 0.042, 0.0, "dark"))
		muzzle.x += 0.2
	if has.call("compensateur"):
		parts.append(_r(muzzle.x + 0.035, muzzle.y, 0.07, 0.05, 0.0, "dark"))
		parts.append(_r(muzzle.x + 0.035, muzzle.y + 0.027, 0.012, 0.012, 0.0, "metal"))
		muzzle.x += 0.07
	# Viseurs : une vitre (on vise au travers) et un point lumineux dessus.
	if has.call("point_rouge"):
		parts.append(_r(top_x, top + 0.006, 0.055, 0.012, 0.0, "dark"))
		parts.append(_r(top_x + 0.022, top + 0.03, 0.008, 0.036, 0.0, "verre"))
		parts.append(_r(top_x + 0.012, top + 0.05, 0.032, 0.006, 0.0, "dark"))
		parts.append(_dot(top_x + 0.027, top + 0.03))
		sight = top + 0.03
	if has.call("holo"):
		parts.append(_r(top_x, top + 0.008, 0.1, 0.016, 0.0, "dark"))
		parts.append(_r(top_x + 0.045, top + 0.036, 0.008, 0.048, 0.0, "verre"))
		parts.append(_r(top_x - 0.045, top + 0.036, 0.008, 0.048, 0.0, "verre"))
		parts.append(_r(top_x, top + 0.064, 0.1, 0.008, 0.0, "dark"))
		parts.append(_dot(top_x + 0.05, top + 0.036))
		sight = top + 0.036
	if has.call("lunette"):
		parts.append(_r(top_x - 0.03, top + 0.012, 0.025, 0.024, 0.0, "metal"))
		parts.append(_r(top_x + 0.07, top + 0.012, 0.025, 0.024, 0.0, "metal"))
		parts.append(_r(top_x + 0.02, top + 0.045, 0.28, 0.045, 0.0, "dark"))
		parts.append(_r(top_x + 0.17, top + 0.045, 0.03, 0.055, 0.0, "dark"))
		sight = top + 0.045
	if not mag.is_empty():
		var mp: Vector2 = mag.p
		var ms: Vector2 = mag.s
		var a: float = mag.a
		var down := Vector2(sin(a), -cos(a))
		if has.call("chargeur_etendu"):
			parts.append(_r(mp.x + down.x * (ms.y / 2.0 + 0.04), mp.y + down.y * (ms.y / 2.0 + 0.04), ms.x * 0.95, 0.08, a, "metal", "mag"))
		if has.call("chargeur_rapide"):
			parts.append(_r(mp.x - down.x * 0.0, mp.y + down.y * (ms.y * 0.15), ms.x + 0.012, 0.025, a, "glow", "mag"))
	if has.call("crosse_stable"):
		parts.append(_r(rear - 0.08, rear_y - 0.01, 0.16, 0.085, 0.0, "dark"))
	if has.call("crosse_legere"):
		parts.append(_r(rear - 0.07, rear_y + 0.02, 0.15, 0.018, 0.0, "metal"))
		parts.append(_r(rear - 0.14, rear_y - 0.01, 0.018, 0.07, 0.0, "metal"))
	return [muzzle, sight]


## A rectangle; role marks the moving parts used by the reload animations
## ("mag", "bolt", "pump", "barrel", "cyl").
static func _r(x: float, y: float, w: float, h: float, a: float, mat: String, role := "") -> Dictionary:
	return {"p": Vector2(x, y), "s": Vector2(w, h), "a": a, "m": mat, "role": role}


## Point rouge d'un viseur : un petit carré au milieu (pas une barre sur toute la largeur de l'arme).
static func _dot(x: float, y: float) -> Dictionary:
	var r := _r(x, y, 0.002, 0.0055, 0.0, "reticule")
	r["d"] = 0.0055
	return r


## Builds the 3D model: the barrel points along -Z, the grip is at the origin.
static func build_model(weapon_id: String, mats: Dictionary, scale := 1.0, acc: Array = []) -> Node3D:
	var sh := shape(weapon_id, acc)
	var root := Node3D.new()
	var grip: Vector2 = sh.grip
	var top := -10.0
	var roles := {}
	for part in sh.parts:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var s: Vector2 = part.s
		bm.size = Vector3(float(part.get("d", sh.depth)), s.y, s.x) * scale
		mi.mesh = bm
		mi.material_override = mats.get(part.m, Armes.reticule() if part.m == "reticule" else mats.get("metal"))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var p: Vector2 = (part.p - grip) * scale
		mi.position = Vector3(0, p.y, -p.x)
		mi.rotation.x = part.a
		var role: String = part.get("role", "")
		var parent := root
		if role != "":
			# Moving parts get their own pivot so the animation can move them as a group.
			if not roles.has(role):
				var pivot := Node3D.new()
				pivot.name = role
				root.add_child(pivot)
				roles[role] = pivot
			parent = roles[role]
		parent.add_child(mi)
		if part.p.x > grip.x - 0.05 or sh.kind in ["pistol", "revolver"]:
			top = maxf(top, (part.p.y - grip.y + s.y / 2) * scale)
	var m: Vector2 = (sh.muzzle - grip) * scale
	root.set_meta("muzzle", Vector3(0, m.y, -m.x))
	root.set_meta("length", (sh.muzzle.x) * scale)
	# Avec un viseur, l'œil se place sur sa ligne de visée (pas au-dessus de son cadre).
	if float(sh.sight) > -50.0:
		top = (float(sh.sight) - grip.y) * scale - 0.018
	root.set_meta("top", top)
	return root


## Flat chalk drawing (for the walls): the drawing faces +Z, centred on its own bounds.
static func build_drawing(weapon_id: String, mat: Material, scale := 1.0) -> Node3D:
	var sh := shape(weapon_id)
	var root := Node3D.new()
	var length: float = sh.muzzle.x
	for part in sh.parts:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var s: Vector2 = part.s
		bm.size = Vector3(s.x, s.y, 0.01) * scale
		mi.mesh = bm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var p: Vector2 = part.p
		mi.position = Vector3(p.x - length / 2, p.y, 0) * scale
		mi.rotation.z = part.a
		root.add_child(mi)
	return root
