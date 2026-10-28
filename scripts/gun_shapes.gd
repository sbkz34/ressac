class_name GunShapes
extends RefCounted
## Silhouettes de profil de chaque arme (reprises de Dernière Vague), en rectangles en mètres
## (x vers la bouche du canon, y vers le haut), extrudées pour les modèles 3D.



const KIND_OF := {
	"p9": "pistol", "taureau": "revolver", "vipere": "smg", "ouragan": "smg2", "k14": "rifle",
	"faucon": "ar", "grele": "shotgun", "machoire": "double", "titan": "lmg", "aiguille": "sniper",
	"desint": "wonder", "uzi": "uzi", "rpg": "launcher", "hache": "axe", "sabre": "blade",
}


static func shape(weapon_id: String) -> Dictionary:
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
	return {"parts": parts, "grip": grip, "muzzle": muzzle, "depth": depth, "kind": kind}


## A rectangle; role marks the moving parts used by the reload animations
## ("mag", "bolt", "pump", "barrel", "cyl").
static func _r(x: float, y: float, w: float, h: float, a: float, mat: String, role := "") -> Dictionary:
	return {"p": Vector2(x, y), "s": Vector2(w, h), "a": a, "m": mat, "role": role}


## Builds the 3D model: the barrel points along -Z, the grip is at the origin.
static func build_model(weapon_id: String, mats: Dictionary, scale := 1.0) -> Node3D:
	var sh := shape(weapon_id)
	var root := Node3D.new()
	var grip: Vector2 = sh.grip
	var top := -10.0
	var roles := {}
	for part in sh.parts:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var s: Vector2 = part.s
		bm.size = Vector3(sh.depth, s.y, s.x) * scale
		mi.mesh = bm
		mi.material_override = mats.get(part.m, mats.get("metal"))
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
