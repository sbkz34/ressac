class_name TouchControls
extends Control
## Commandes tactiles : stick à gauche (poussé au bord = sprint), glisser à droite pour regarder,
## boutons SAUT / DRONE / CARTE (et HAUT / BAS en drone). Masquées dès qu'on joue à la manette.

signal map_pressed
signal drone_pressed

var move := Vector2.ZERO
var sprint := false
var jump_pressed := false
var jump_held := false
var down_held := false
var flying := false

var _stick_id := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _look_id := -1
var _look_last := Vector2.ZERO
var _look_acc := Vector2.ZERO
var _button_ids := {}   # index du doigt -> nom du bouton
const STICK_R := 90.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	sprint = false
	jump_held = false
	down_held = false
	_button_ids.clear()
	queue_redraw()


func consume_look() -> Vector2:
	var d := _look_acc
	_look_acc = Vector2.ZERO
	return d


func _buttons() -> Dictionary:
	var s := size
	var r := minf(s.x, s.y) * 0.075
	var b := {
		"saut": [Vector2(s.x - r * 1.6, s.y - r * 1.6), r],
		"drone": [Vector2(s.x - r * 4.0, s.y - r * 1.2), r * 0.75],
		"carte": [Vector2(s.x - r * 1.3, r * 1.4), r * 0.7],
	}
	if flying:
		b["bas"] = [Vector2(s.x - r * 1.6, s.y - r * 4.0), r * 0.8]
	return b


func _hit_button(p: Vector2) -> String:
	var b := _buttons()
	for k in b:
		if p.distance_to(b[k][0]) < b[k][1] * 1.15:
			return k
	return ""


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			var btn := _hit_button(event.position)
			if btn != "":
				_button_ids[event.index] = btn
				_press(btn, true)
			elif event.position.x < size.x * 0.45 and _stick_id == -1:
				_stick_id = event.index
				_stick_origin = event.position
				_stick_pos = event.position
			elif _look_id == -1:
				_look_id = event.index
				_look_last = event.position
		else:
			if _button_ids.has(event.index):
				_press(_button_ids[event.index], false)
				_button_ids.erase(event.index)
			if event.index == _stick_id:
				_stick_id = -1
				move = Vector2.ZERO
				sprint = false
			if event.index == _look_id:
				_look_id = -1
		queue_redraw()
	elif event is InputEventScreenDrag:
		if event.index == _stick_id:
			_stick_pos = event.position
			var v: Vector2 = (_stick_pos - _stick_origin) / STICK_R
			sprint = v.length() > 1.05 and v.y < -0.5
			move = v.limit_length(1.0)
			queue_redraw()
		elif event.index == _look_id:
			_look_acc += event.position - _look_last
			_look_last = event.position


func _press(btn: String, down: bool) -> void:
	match btn:
		"saut":
			jump_held = down
			if down:
				jump_pressed = true
		"bas":
			down_held = down
		"drone":
			if down:
				drone_pressed.emit()
		"carte":
			if down:
				map_pressed.emit()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	if _stick_id != -1:
		draw_circle(_stick_origin, STICK_R, Color(1, 1, 1, 0.12))
		draw_arc(_stick_origin, STICK_R, 0, TAU, 40, Color(1, 1, 1, 0.35), 2.0)
		draw_circle(_stick_origin + move * STICK_R, 34, Color(1, 1, 1, 0.4))
	var b := _buttons()
	var labels := {"saut": "MONTER" if flying else "SAUT", "drone": "MARCHE" if flying else "DRONE", "carte": "CARTE", "bas": "BAS"}
	for k in b:
		var held := _button_ids.values().has(k)
		draw_circle(b[k][0], b[k][1], Color(0, 0, 0, 0.35 if not held else 0.55))
		draw_arc(b[k][0], b[k][1], 0, TAU, 40, Color(1, 1, 1, 0.6), 2.0)
		var fs := int(b[k][1] * 0.32)
		draw_string(font, b[k][0] + Vector2(-b[k][1], fs * 0.35), labels[k], HORIZONTAL_ALIGNMENT_CENTER, b[k][1] * 2, fs, Color(1, 1, 1, 0.9))
