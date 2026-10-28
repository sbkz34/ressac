extends Node
## Global (autoload « G ») : couches de collision, commandes, mode d'entrée, réglages, sons,
## options de lancement.

signal input_mode_changed(mode: String)
signal settings_changed

const L_WORLD := 1
const L_PLAYER := 2
const L_HITBOX := 4    # zones de touche des combattants (tête, torse, jambes)

var input_mode := "kbm"   # "kbm", "pad" ou "touch"
var tour_mode := false
var check_mode := false
var bake_nav := false
var sim_mode := false          # --sim : partie accélérée de bots sans écran (réglages, mesures)
var screenshot_dir := ""
var data: Dictionary = {}

## Réglages du joueur, enregistrés dans user://settings.cfg.
var settings := {
	"hud_scale": 1.0,       # taille de l'interface (0,7 à 1,5)
	"hud_margin": 0.03,     # marge ajoutée sur les bords, en part de la largeur de l'écran
	"sens_pad": 1.0,
	"sens_touch": 1.0,
	"sens_mouse": 1.0,
	"show_fps": true,
	"bots": 15,             # adversaires dans une partie (0 à 23)
	"difficulte": 1,        # 0 facile, 1 normal, 2 difficile
}
const SETTINGS_PATH := "user://settings.cfg"

var shots := {}                # tireur (id) -> [position, heure] : tirs récents, pour les cartes
const SHOT_VISIBLE := 3.5      # secondes pendant lesquelles un tir reste sur la carte
var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _players3d: Array[AudioStreamPlayer3D] = []
var _next_3d := 0
const ANY_DEVICE := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a == "--tour":
			tour_mode = true
		elif a == "--check":
			check_mode = true
		elif a == "--bake-nav":
			bake_nav = true
		elif a == "--sim":
			sim_mode = true
			check_mode = true
		elif a.begins_with("--shots="):
			screenshot_dir = a.substr(8)
	data = load_json("res://data/ile.json")
	_setup_input()
	if not check_mode:
		_load_settings()
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	# Sons des autres combattants : placés dans l'espace, atténués avec la distance.
	for i in 20:
		var p3 := AudioStreamPlayer3D.new()
		p3.unit_size = 12.0
		p3.max_distance = 320.0
		p3.attenuation_filter_cutoff_hz = 6000.0
		add_child(p3)
		_players3d.append(p3)
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
# Réglages
# ------------------------------------------------------------------------------------------------
func set_setting(key: String, value) -> void:
	settings[key] = value
	save_settings()
	settings_changed.emit()


func _load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) != OK:
		return
	for k in settings:
		settings[k] = cf.get_value("reglages", k, settings[k])


func save_settings() -> void:
	if check_mode:
		return
	var cf := ConfigFile.new()
	for k in settings:
		cf.set_value("reglages", k, settings[k])
	cf.save(SETTINGS_PATH)


# ------------------------------------------------------------------------------------------------
# Sons (ceux de Dernière Vague)
# ------------------------------------------------------------------------------------------------
func sound(name: String) -> AudioStream:
	if not _sounds.has(name):
		var path := "res://assets/sfx/%s.wav" % name
		_sounds[name] = load(path) if ResourceLoader.exists(path) else null
	return _sounds[name]


func report_shot(by: Node3D) -> void:
	shots[by.get_instance_id()] = [by.global_position, Time.get_ticks_msec() / 1000.0, by]


## Tirs encore visibles : [position, âge en secondes, tireur].
func recent_shots() -> Array:
	var now := Time.get_ticks_msec() / 1000.0
	var out := []
	for k in shots.keys():
		var sh: Array = shots[k]
		var age := now - float(sh[1])
		if age > SHOT_VISIBLE or not is_instance_valid(sh[2]):
			shots.erase(k)
		else:
			out.append([sh[0], age, sh[2]])
	return out


func play_at(name: String, pos: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
	var s := sound(name)
	if s == null:
		return
	var p := _players3d[_next_3d]
	_next_3d = (_next_3d + 1) % _players3d.size()
	p.stream = s
	p.global_position = pos
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


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
# Commandes : clavier / souris, manette (n'importe quel numéro de manette), tactile à part.
# Disposition de la manette proche de Warzone : A sauter, B accroupi (maintenir = couché),
# L3 sprint (encore L3 en sprintant = sprint tactique), RT tirer, LT viser, X ramasser ou
# recharger, Y changer d'arme, croix haut plaque d'armure, RB grenade, LB fumigène,
# Select carte, Start pause.
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


func _mouse(action: String, button: MouseButton) -> void:
	var e := InputEventMouseButton.new()
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
	_add("crouch"); _key("crouch", KEY_C); _key("crouch", KEY_CTRL); _btn("crouch", JOY_BUTTON_B)
	_add("drone"); _key("drone", KEY_F9)
	# Combat : RT tirer, LT viser, X ramasser ou recharger, Y changer d'arme, croix haut plaque,
	# RB grenade, LB fumigène.
	_add("fire", 0.3); _mouse("fire", MOUSE_BUTTON_LEFT); _axis("fire", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_add("ads", 0.3); _mouse("ads", MOUSE_BUTTON_RIGHT); _axis("ads", JOY_AXIS_TRIGGER_LEFT, 1.0)
	# Manettes dont les gâchettes sont de simples boutons (Android : L2 / R2 = boutons 15 / 16).
	_btn("ads", JOY_BUTTON_MISC1); _btn("fire", JOY_BUTTON_PADDLE1)
	_add("reload"); _key("reload", KEY_R)
	_add("interact"); _key("interact", KEY_E); _key("interact", KEY_F)
	_add("use"); _btn("use", JOY_BUTTON_X)
	_add("swap"); _key("swap", KEY_1); _key("swap", KEY_2); _btn("swap", JOY_BUTTON_Y)
	_mouse("swap", MOUSE_BUTTON_WHEEL_UP); _mouse("swap", MOUSE_BUTTON_WHEEL_DOWN)
	_add("plate"); _key("plate", KEY_4); _key("plate", KEY_X); _btn("plate", JOY_BUTTON_DPAD_UP)
	_add("lethal"); _key("lethal", KEY_G); _btn("lethal", JOY_BUTTON_RIGHT_SHOULDER)
	_add("tactical"); _key("tactical", KEY_T); _btn("tactical", JOY_BUTTON_LEFT_SHOULDER)
	_add("carte"); _key("carte", KEY_M); _key("carte", KEY_TAB); _btn("carte", JOY_BUTTON_BACK)
	_add("pause"); _key("pause", KEY_ESCAPE); _key("pause", KEY_P); _btn("pause", JOY_BUTTON_START)
	# Les claviers AZERTY : ZQSD en plus de WASD.
	_key("move_forward", KEY_Z)
	_key("move_left", KEY_Q)
	# Menus : A valide et B revient, quel que soit le numéro de la manette.
	_btn("ui_accept", JOY_BUTTON_A)
	_btn("ui_cancel", JOY_BUTTON_B)
	for pair in [["ui_up", JOY_BUTTON_DPAD_UP], ["ui_down", JOY_BUTTON_DPAD_DOWN],
			["ui_left", JOY_BUTTON_DPAD_LEFT], ["ui_right", JOY_BUTTON_DPAD_RIGHT]]:
		_btn(pair[0], pair[1])


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
