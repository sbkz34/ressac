class_name TouchControls
extends Control
## Commandes tactiles : stick à gauche (poussé au bord = sprint), glisser à droite pour regarder,
## boutons SAUT, ACCROUPI (appui : accroupi / glissade / annuler ; maintenu : couché), SPRINT
## (en courant : sprint tactique), TIR (on peut viser en glissant le doigt dessus), VISER
## (bascule), RECH., ARME, PLAQUE (maintenir), ACTION (quand il y a quelque chose à ramasser),
## CARTE et PAUSE. Les libellés suivent la situation (avion, parachute, drone). Masquées dès
## qu'on joue à la manette ou au clavier.

signal map_pressed
signal pause_pressed

var move := Vector2.ZERO
var sprint_edge := false
var labels := {}              # libellés imposés par le HUD selon l'état du joueur
var ads_on := false           # VISER est une bascule
var _fire_last := {}          # doigt sur TIR -> dernière position (pour viser en tirant)

var _stick_id := -1
var _stick_origin := Vector2.ZERO
var _look_id := -1
var _look_last := Vector2.ZERO
var _look_acc := Vector2.ZERO
var _button_ids := {}         # doigt -> bouton
var _pressed := {}            # boutons appuyés depuis la dernière lecture
const STICK_R := 90.0
const NAMES := {"saut": "SAUT", "accroupi": "ACCROUPI", "sprint": "SPRINT", "carte": "CARTE", "pause": "II",
	"tir": "TIR", "viser": "VISER", "recharger": "RECH.", "arme": "ARME", "plaque": "PLAQUE", "action": ""}


## Libellé affiché (vide : bouton masqué et inactif).
func label_of(k: String) -> String:
	return String(labels.get(k, NAMES.get(k, "")))


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	G.input_mode_changed.connect(_on_mode)
	_on_mode(G.input_mode)


func _on_mode(mode: String) -> void:
	visible = mode == "touch"
	if not visible:
		_release_all()


func _release_all() -> void:
	_stick_id = -1
	_look_id = -1
	move = Vector2.ZERO
	sprint_edge = false
	_button_ids.clear()
	_pressed.clear()
	_fire_last.clear()
	ads_on = false
	queue_redraw()


func consume_look() -> Vector2:
	var d := _look_acc
	_look_acc = Vector2.ZERO
	return d


## Vrai une seule fois par appui.
func take(btn: String) -> bool:
	if _pressed.get(btn, false):
		_pressed[btn] = false
		return true
	return false


func held(btn: String) -> bool:
	return _button_ids.values().has(btn)


func _buttons() -> Dictionary:
	var s := size
	var r := minf(s.x, s.y) * 0.075
	return {
		"saut": [Vector2(s.x - r * 1.5, s.y - r * 1.7), r],
		"accroupi": [Vector2(s.x - r * 4.0, s.y - r * 1.2), r * 0.8],
		"sprint": [Vector2(s.x - r * 1.4, s.y - r * 4.4), r * 0.72],
		"tir": [Vector2(s.x - r * 3.4, s.y - r * 4.6), r * 1.15],
		"viser": [Vector2(s.x - r * 6.0, s.y - r * 3.4), r * 0.75],
		"recharger": [Vector2(s.x - r * 1.2, s.y * 0.38), r * 0.6],
		"arme": [Vector2(s.x - r * 7.6, s.y - r * 4.6), r * 0.62],
		"plaque": [Vector2(s.x - r * 9.3, s.y - r * 3.3), r * 0.62],
		"action": [Vector2(s.x * 0.62, s.y * 0.62), r * 0.75],
		"carte": [Vector2(s.x - r * 1.0, r * 1.0), r * 0.6],
		"pause": [Vector2(s.x - r * 2.6, r * 1.0), r * 0.6],
	}


func _hit_button(p: Vector2) -> String:
	var b := _buttons()
	for k in b:
		if label_of(k) != "" and p.distance_to(b[k][0]) < b[k][1] * 1.15:
			return k
	return ""


func _local(p: Vector2) -> Vector2:
	# Le HUD peut être mis à l'échelle et décalé (marges) : on ramène le doigt dans ce repère.
	return get_global_transform_with_canvas().affine_inverse() * p


func _input(event: InputEvent) -> void:
	if not visible or get_tree().paused:
		return
	if event is InputEventScreenTouch:
		var p := _local(event.position)
		if event.pressed:
			var btn := _hit_button(p)
			if btn != "":
				_button_ids[event.index] = btn
				_pressed[btn] = true
				if btn == "carte":
					map_pressed.emit()
				elif btn == "pause":
					pause_pressed.emit()
				elif btn == "viser":
					ads_on = not ads_on
				elif btn == "tir":
					_fire_last[event.index] = event.position
			elif p.x < size.x * 0.45 and _stick_id == -1:
				_stick_id = event.index
				_stick_origin = p
			elif _look_id == -1:
				_look_id = event.index
				_look_last = event.position
		else:
			_button_ids.erase(event.index)
			_fire_last.erase(event.index)
			if event.index == _stick_id:
				_stick_id = -1
				move = Vector2.ZERO
				sprint_edge = false
			if event.index == _look_id:
				_look_id = -1
		queue_redraw()
	elif event is InputEventScreenDrag:
		if event.index == _stick_id:
			var v: Vector2 = (_local(event.position) - _stick_origin) / STICK_R
			sprint_edge = v.length() > 1.05 and v.y < -0.5
			move = v.limit_length(1.0)
			queue_redraw()
		elif event.index == _look_id:
			_look_acc += event.position - _look_last
			_look_last = event.position
		elif _fire_last.has(event.index):
			# Le pouce sur TIR peut aussi orienter la visée.
			_look_acc += event.position - _fire_last[event.index]
			_fire_last[event.index] = event.position


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	if _stick_id != -1:
		draw_circle(_stick_origin, STICK_R, Color(1, 1, 1, 0.12))
		draw_arc(_stick_origin, STICK_R, 0, TAU, 40, Color(1, 1, 1, 0.35), 2.0)
		draw_circle(_stick_origin + move * STICK_R, 34, Color(1, 0.85, 0.4, 0.5) if sprint_edge else Color(1, 1, 1, 0.4))
	var b := _buttons()
	for k in b:
		var text := label_of(k)
		if text == "":
			continue
		var on: bool = held(k) or (k == "viser" and ads_on)
		draw_circle(b[k][0], b[k][1], Color(0, 0, 0, 0.55 if on else 0.32))
		draw_arc(b[k][0], b[k][1], 0, TAU, 40, Color(1, 1, 1, 0.6), 2.0)
		var fs := int(b[k][1] * (0.5 if k == "pause" else 0.3))
		draw_string(font, b[k][0] + Vector2(-b[k][1], fs * 0.35), text, HORIZONTAL_ALIGNMENT_CENTER, b[k][1] * 2, fs, Color(1, 1, 1, 0.9))
