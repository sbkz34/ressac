extends Node
## Global (autoload « G ») : couches de collision, commandes, mode d'entrée, sons, options de lancement.

signal input_mode_changed(mode: String)

const L_WORLD := 1
const L_PLAYER := 2

var input_mode := "kbm"   # "kbm", "pad" ou "touch"
var tour_mode := false
var check_mode := false
var screenshot_dir := ""
var data: Dictionary = {}

var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
const ANY_DEVICE := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a == "--tour":
			tour_mode = true
		elif a == "--check":
			check_mode = true
		elif a.begins_with("--shots="):
			screenshot_dir = a.substr(8)
	data = load_json("res://data/ile.json")
	_setup_input()
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	if OS.has_feature("mobile"):
		input_mode = "touch"


func load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Fichier introuvable : %s" % path)
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


## Nom d'un lieu et case du quadrillage (A–J, 1–10) pour une position.
func where(p: Vector3) -> String:
	var lieu := ""
	var best := INF
	for l in data.get("lieux", []):
		var d := Vector2(p.x - l.x, p.z - l.z).length()
		if d < float(l.rayon) * 0.9 and d < best:
			best = d
			lieu = l.nom
	var half := float(data.get("monde", 640)) / 2.0
	var step := float(data.get("monde", 640)) / 10.0
	var col := clampi(int((p.x + half) / step), 0, 9)
	var row := clampi(int((p.z + half) / step), 0, 9)
	var cell := "%s%d" % ["ABCDEFGHIJ"[col], row + 1]
	return cell if lieu == "" else "%s · %s" % [lieu, cell]


# ------------------------------------------------------------------------------------------------
# Sons (ceux de Dernière Vague)
# ------------------------------------------------------------------------------------------------
func sound(name: String) -> AudioStream:
	if not _sounds.has(name):
		var path := "res://assets/sfx/%s.wav" % name
		_sounds[name] = load(path) if ResourceLoader.exists(path) else null
	return _sounds[name]


func play(name: String, volume_db := 0.0, pitch := 1.0) -> void:
	var s := sound(name)
	if s == null:
		return
	var p := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


# ------------------------------------------------------------------------------------------------
# Commandes : clavier / souris, manette (n'importe quel numéro de manette), tactile à part
# ------------------------------------------------------------------------------------------------
func _add(action: String, deadzone := 0.2) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, deadzone)


func _key(action: String, keycode: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = keycode
	InputMap.action_add_event(action, e)


func _btn(action: String, button: JoyButton) -> void:
	var e := InputEventJoypadButton.new()
	e.device = ANY_DEVICE
	e.button_index = button
	InputMap.action_add_event(action, e)


func _axis(action: String, axis: JoyAxis, value: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = ANY_DEVICE
	e.axis = axis
	e.axis_value = value
	InputMap.action_add_event(action, e)


func _setup_input() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right"]:
		_add(a, 0.15)
	_key("move_forward", KEY_W); _key("move_forward", KEY_UP)
	_key("move_back", KEY_S); _key("move_back", KEY_DOWN)
	_key("move_left", KEY_A); _key("move_left", KEY_LEFT)
	_key("move_right", KEY_D); _key("move_right", KEY_RIGHT)
	_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	for a in ["look_left", "look_right", "look_up", "look_down"]:
		_add(a, 0.12)
	_axis("look_left", JOY_AXIS_RIGHT_X, -1.0)
	_axis("look_right", JOY_AXIS_RIGHT_X, 1.0)
	_axis("look_up", JOY_AXIS_RIGHT_Y, -1.0)
	_axis("look_down", JOY_AXIS_RIGHT_Y, 1.0)
	_add("jump"); _key("jump", KEY_SPACE); _btn("jump", JOY_BUTTON_A)
	_add("sprint"); _key("sprint", KEY_SHIFT); _btn("sprint", JOY_BUTTON_LEFT_STICK)
	_add("descend"); _key("descend", KEY_C); _key("descend", KEY_CTRL); _btn("descend", JOY_BUTTON_B)
	_add("drone"); _key("drone", KEY_F); _btn("drone", JOY_BUTTON_Y)
	_add("carte"); _key("carte", KEY_M); _key("carte", KEY_TAB); _btn("carte", JOY_BUTTON_BACK)
	_add("pause"); _key("pause", KEY_ESCAPE); _btn("pause", JOY_BUTTON_START)
	# Les claviers AZERTY : ZQSD en plus de WASD.
	_key("move_forward", KEY_Z)
	_key("move_left", KEY_Q)


func _input(event: InputEvent) -> void:
	var mode := input_mode
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and abs(event.axis_value) > 0.4):
		mode = "pad"
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		mode = "touch"
	elif event is InputEventKey or (event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION):
		mode = "kbm"
	if mode != input_mode:
		input_mode = mode
		input_mode_changed.emit(mode)
