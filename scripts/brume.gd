class_name Brume
extends Node3D
## La Brume : un brouillard toxique venu de la mer qui referme l'aire de jeu en 6 phases.
## Chaque phase : une attente (le prochain cercle est connu), puis un resserrement. Hors du
## cercle, on perd des points de vie à travers l'armure, de plus en plus vite. Le dernier cercle
## se referme sur un des lieux prévus pour les fins de partie (docs/carte.md).

signal phase_started(n: int)     # attente de la phase n (1 à 6)
signal closing_started(n: int)   # la Brume avance
signal closed                    # plus rien à respirer

## [attente (s), resserrement (s), rayon à la fin (m), dégâts par seconde hors zone]
const PHASES := [
	[90.0, 60.0, 220.0, 2.0],
	[70.0, 50.0, 140.0, 4.0],
	[60.0, 45.0, 85.0, 7.0],
	[50.0, 40.0, 45.0, 11.0],
	[40.0, 35.0, 20.0, 16.0],
	[30.0, 40.0, 0.0, 25.0],
]
const START_RADIUS := 400.0
## Lieux de fin de partie et leur poids. Le Lazaret, au centre (où commence la Brume), est plus
## rare ; la fin d'une partie n'est jamais celle de la précédente.
const FINALS := {"lazaret": 0.6, "cimetiere": 1.0, "citerne": 1.0, "cabanons": 1.0, "salins": 1.0,
	"port": 1.0, "batterie": 1.0, "semaphore": 0.8, "conserverie": 0.8}
static var _derniere := ""

var center := Vector2(0, -10)
var radius := START_RADIUS
var next_center := Vector2(0, -10)
var next_radius := START_RADIUS
var phase := 0                   # 1 à 6 (0 : pas commencée)
var closing := false
var finished := false
var time_left := 0.0             # avant la fin de l'attente ou du resserrement
var time_scale := 1.0            # les tests accélèrent la partie
var final_point := Vector2.ZERO
var final_place := ""
var rng := RandomNumberGenerator.new()
var _from_center := Vector2.ZERO
var _from_radius := 0.0
var _wall: MeshInstance3D


func _ready() -> void:
	_wall = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 300.0
	cm.radial_segments = 72
	cm.rings = 1
	cm.cap_top = false
	cm.cap_bottom = false
	_wall.mesh = cm
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/brume.gdshader")
	_wall.material_override = m
	_wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_wall)
	_update_wall()


func start(seed_value: int) -> void:
	rng.seed = seed_value
	var lieu: Dictionary = {}
	var total := 0.0
	for k in FINALS:
		if k != _derniere:
			total += float(FINALS[k])
	var r := rng.randf() * total
	var id := ""
	for k in FINALS:
		if k == _derniere:
			continue
		id = k
		r -= float(FINALS[k])
		if r <= 0.0:
			break
	_derniere = id
	for l in G.data.lieux:
		if l.id == id:
			lieu = l
	final_place = String(lieu.get("nom", ""))
	final_point = Vector2(float(lieu.x), float(lieu.z)) + Vector2(rng.randf_range(-10, 10), rng.randf_range(-10, 10))
	center = Vector2(0, -10)
	radius = START_RADIUS
	phase = 0
	finished = false
	_begin_phase(1)


func _begin_phase(n: int) -> void:
	phase = n
	closing = false
	var p: Array = PHASES[n - 1]
	time_left = float(p[0])
	next_radius = float(p[2])
	# Le centre avance vers le point final, avec un peu de hasard, sans jamais sortir du cercle
	# actuel : le prochain cercle est toujours entièrement dans celui-ci.
	var room := radius - next_radius
	var to_final := final_point - center
	var step := to_final.limit_length(room)
	var wiggle := room - step.length()
	if wiggle > 1.0:
		step += Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, wiggle * 0.6)
	next_center = center + step.limit_length(room)
	if n == PHASES.size():
		next_center = final_point if final_point.distance_to(center) <= room else next_center
	phase_started.emit(n)


func _physics_process(delta: float) -> void:
	if phase == 0 or finished:
		return
	time_left -= delta * time_scale
	if closing:
		var dur := float(PHASES[phase - 1][1])
		var k := clampf(1.0 - time_left / dur, 0.0, 1.0)
		center = _from_center.lerp(next_center, k)
		radius = lerpf(_from_radius, next_radius, k)
	if time_left <= 0.0:
		if not closing:
			closing = true
			_from_center = center
			_from_radius = radius
			time_left = float(PHASES[phase - 1][1])
			closing_started.emit(phase)
		else:
			center = next_center
			radius = next_radius
			if phase >= PHASES.size():
				finished = true
				closed.emit()
			else:
				_begin_phase(phase + 1)
	_update_wall()


func _update_wall() -> void:
	if _wall == null:
		return
	_wall.visible = radius > 0.5 and phase > 0
	_wall.position = Vector3(center.x, 120.0, center.y)
	_wall.scale = Vector3(maxf(radius, 0.5), 1.0, maxf(radius, 0.5))


func is_outside(p: Vector3) -> bool:
	if phase == 0:
		return false
	return Vector2(p.x, p.z).distance_to(center) > radius


## Distance jusqu'à la zone sûre (0 si on y est).
func distance_to_safety(p: Vector3) -> float:
	return maxf(0.0, Vector2(p.x, p.z).distance_to(center) - radius)


func dps() -> float:
	if phase == 0:
		return 0.0
	return float(PHASES[phase - 1][3])


func status_text() -> String:
	if phase == 0:
		return ""
	if finished:
		return "La Brume a tout recouvert"
	var t := int(ceil(time_left))
	var clock := "%d:%02d" % [t / 60, t % 60]
	if closing:
		return "Phase %d/%d · la Brume avance · %s" % [phase, PHASES.size(), clock]
	return "Phase %d/%d · la Brume avance dans %s" % [phase, PHASES.size(), clock]
