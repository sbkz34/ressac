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
var icons_dir := ""             # --icones=DIR : rendus des armes (profil, fond transparent)
var perf_mode := false         # --perf : mesures de rendu à quelques points de vue (avec écran)
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
	"qualite": 1,           # 0 performance, 1 équilibrée, 2 qualité (résolution 3D, ombres)
	"sens_ads": 0.55,       # sensibilité en visant, par rapport à la normale
	"inverser_y": false,
	"visee_bascule": false, # viser : maintenir (faux) ou appuyer une fois (vrai)
	"assistance": 1,        # assistance à la visée : 0 aucune, 1 normale, 2 forte
	"minicarte_nord": false,  # mini-carte : nord fixe en haut (vrai) ou tourne avec la vue
	"sprint_auto": false,   # courir dès que le stick est poussé à fond
	"plaques_toutes": true, # maintenir : poser les plaques d'affilée (faux : une par appui)
	"vol_general": 0.8,
	"vol_armes": 0.8,
	"vol_pas": 0.85,
	"vol_ui": 0.75,
	"vol_ambiance": 0.65,
	"tactile": {},          # boutons tactiles déplacés : nom -> [x, y, taille] (x, y en part de l'écran)
	"tactile_opacite": 1.0,
	"touches": {},          # touches changées : "pad:action" / "clavier:action" -> touche
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
		elif a.begins_with("--icones="):
			icons_dir = a.substr(9)
		elif a == "--perf":
			perf_mode = true
		elif a == "--sim":
			sim_mode = true
			check_mode = true
		elif a.begins_with("--shots="):
			screenshot_dir = a.substr(8)
	data = load_json("res://data/ile.json")
	_setup_input()
	for row in BINDABLE:
		for a in [row[1], row[2]]:
			if a != "" and not _default_events.has(a):
				_default_events[a] = InputMap.action_get_events(a).duplicate()
	if not check_mode:
		_load_settings()
	apply_bindings()
	_setup_buses()
	apply_volumes()
	settings_changed.connect(apply_volumes)
	for i in 8:
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
# Touches réattribuables (manette et clavier / souris, séparément)
# ------------------------------------------------------------------------------------------------
## [libellé, action à la manette, action au clavier] ("" : pas réglable de ce côté).
const BINDABLE := [
	["Tirer", "fire", "fire"],
	["Viser", "ads", "ads"],
	["Sauter, escalader, parachute", "jump", "jump"],
	["Accroupi, glissade", "crouch", "crouch"],
	["Sprint, sprint tactique", "sprint", "sprint"],
	["Ramasser, ouvrir (manette : et recharger)", "use", "interact"],
	["Recharger", "", "reload"],
	["Changer d'arme (manette : maintenir = plaque)", "arme_plaque", "swap"],
	["Plaque d'armure (maintenir)", "plate", "plate"],
	["Grenade", "lethal", "lethal"],
	["Fumigène", "tactical", "tactical"],
	["Carte", "carte", "carte"],
	["Pause", "pause", "pause"],
]
const PAD_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3", JOY_BUTTON_BACK: "Select", JOY_BUTTON_START: "Start",
	JOY_BUTTON_DPAD_UP: "Croix haut", JOY_BUTTON_DPAD_DOWN: "Croix bas", JOY_BUTTON_DPAD_LEFT: "Croix gauche",
	JOY_BUTTON_DPAD_RIGHT: "Croix droite", JOY_BUTTON_MISC1: "LT", JOY_BUTTON_PADDLE1: "RT",
	JOY_BUTTON_GUIDE: "Accueil",
}
var _default_events := {}


static func is_pad_event(e: InputEvent) -> bool:
	return e is InputEventJoypadButton or e is InputEventJoypadMotion


static func is_kb_event(e: InputEvent) -> bool:
	return e is InputEventKey or e is InputEventMouseButton


## Nom lisible d'une touche.
static func event_name(e: InputEvent) -> String:
	if e is InputEventJoypadButton:
		return PAD_NAMES.get((e as InputEventJoypadButton).button_index, "Bouton %d" % (e as InputEventJoypadButton).button_index)
	if e is InputEventJoypadMotion:
		var m := e as InputEventJoypadMotion
		if m.axis == JOY_AXIS_TRIGGER_LEFT:
			return "LT"
		if m.axis == JOY_AXIS_TRIGGER_RIGHT:
			return "RT"
		return "Axe %d%s" % [m.axis, "+" if m.axis_value > 0 else "−"]
	if e is InputEventKey:
		var k := e as InputEventKey
		var code: Key = k.keycode if k.physical_keycode == KEY_NONE else k.physical_keycode
		# Disposition du clavier (AZERTY…) : seulement là où le système sait la donner.
		if k.physical_keycode != KEY_NONE and OS.has_feature("pc") and DisplayServer.get_name() != "headless":
			code = DisplayServer.keyboard_get_keycode_from_physical(k.physical_keycode)
		var n := OS.get_keycode_string(code)
		return {"Space": "Espace", "Shift": "Maj", "Ctrl": "Ctrl", "Escape": "Échap", "Tab": "Tab", "Enter": "Entrée"}.get(n, n)
	if e is InputEventMouseButton:
		return {MOUSE_BUTTON_LEFT: "Clic gauche", MOUSE_BUTTON_RIGHT: "Clic droit", MOUSE_BUTTON_MIDDLE: "Clic molette",
			MOUSE_BUTTON_WHEEL_UP: "Molette haut", MOUSE_BUTTON_WHEEL_DOWN: "Molette bas",
			MOUSE_BUTTON_XBUTTON1: "Souris 4", MOUSE_BUTTON_XBUTTON2: "Souris 5"}.get((e as InputEventMouseButton).button_index, "Souris")
	return "?"


## Touche actuelle d'une action, côté manette ou clavier ("" si aucune).
func binding_name(action: String, pad: bool) -> String:
	if action == "" or not InputMap.has_action(action):
		return ""
	for e in InputMap.action_get_events(action):
		if (pad and is_pad_event(e)) or (not pad and is_kb_event(e)):
			return event_name(e)
	return ""


static func _ser(e: InputEvent) -> Dictionary:
	if e is InputEventJoypadButton:
		return {"t": "bouton", "i": (e as InputEventJoypadButton).button_index}
	if e is InputEventJoypadMotion:
		return {"t": "axe", "i": (e as InputEventJoypadMotion).axis, "v": signf((e as InputEventJoypadMotion).axis_value)}
	if e is InputEventKey:
		return {"t": "touche", "i": (e as InputEventKey).physical_keycode}
	if e is InputEventMouseButton:
		return {"t": "souris", "i": (e as InputEventMouseButton).button_index}
	return {}


static func _deser(d: Dictionary) -> InputEvent:
	match String(d.get("t", "")):
		"bouton":
			var b := InputEventJoypadButton.new()
			b.device = ANY_DEVICE
			b.button_index = int(d.i)
			return b
		"axe":
			var m := InputEventJoypadMotion.new()
			m.device = ANY_DEVICE
			m.axis = int(d.i)
			m.axis_value = float(d.v)
			return m
		"touche":
			var k := InputEventKey.new()
			k.physical_keycode = int(d.i)
			return k
		"souris":
			var mb := InputEventMouseButton.new()
			mb.button_index = int(d.i)
			return mb
	return null


func _set_side(action: String, pad: bool, events: Array) -> void:
	for e in InputMap.action_get_events(action):
		if (pad and is_pad_event(e)) or (not pad and is_kb_event(e)):
			InputMap.action_erase_event(action, e)
	for e in events:
		InputMap.action_add_event(action, e)


func _same(a: InputEvent, b: InputEvent) -> bool:
	return _ser(a) == _ser(b) or (a is InputEventJoypadMotion and b is InputEventJoypadMotion \
		and (a as InputEventJoypadMotion).axis == (b as InputEventJoypadMotion).axis)


## Remet toutes les actions réglables comme au départ, puis applique les touches changées.
func apply_bindings() -> void:
	for a in _default_events:
		var pad_ev := []
		var kb_ev := []
		for e in _default_events[a]:
			if is_pad_event(e):
				pad_ev.append(e)
			elif is_kb_event(e):
				kb_ev.append(e)
		_set_side(a, true, pad_ev)
		_set_side(a, false, kb_ev)
	var t: Dictionary = settings.get("touches", {})
	for key in t:
		var parts := String(key).split(":")
		if parts.size() != 2 or not InputMap.has_action(parts[1]):
			continue
		var e := _deser(t[key])
		if e:
			_set_side(parts[1], parts[0] == "pad", [e])


## Donne une nouvelle touche à une action. Si une autre action réglable l'utilisait déjà,
## elle prend l'ancienne touche de celle-ci (échange).
func rebind(action: String, pad: bool, e: InputEvent) -> void:
	var side := "pad" if pad else "clavier"
	var old: InputEvent = null
	for x in InputMap.action_get_events(action):
		if (pad and is_pad_event(x)) or (not pad and is_kb_event(x)):
			old = x
			break
	var t: Dictionary = settings.get("touches", {}).duplicate()
	for row in BINDABLE:
		var other: String = row[1] if pad else row[2]
		if other == "" or other == action:
			continue
		for x in InputMap.action_get_events(other):
			if ((pad and is_pad_event(x)) or (not pad and is_kb_event(x))) and _same(x, e):
				if old:
					t["%s:%s" % [side, other]] = _ser(old)
				else:
					t.erase("%s:%s" % [side, other])
	t["%s:%s" % [side, action]] = _ser(e)
	settings.touches = t
	apply_bindings()
	save_settings()
	settings_changed.emit()


func reset_bindings() -> void:
	settings.touches = {}
	apply_bindings()
	save_settings()
	settings_changed.emit()


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


# ------------------------------------------------------------------------------------------------
# Volumes par catégorie (bus audio)
# ------------------------------------------------------------------------------------------------
const BUSES := {"Armes": "vol_armes", "Pas": "vol_pas", "Interface": "vol_ui", "Ambiance": "vol_ambiance"}


func _setup_buses() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")


func apply_volumes() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(settings.vol_general), 0.0001)))
	for b in BUSES:
		var i := AudioServer.get_bus_index(b)
		if i >= 0:
			AudioServer.set_bus_volume_db(i, linear_to_db(maxf(float(settings[BUSES[b]]), 0.0001)))


## Catégorie d'un son (pour son volume).
static func bus_of(name: String) -> String:
	if name.begins_with("pas_") or name in ["step", "jump_land", "brasse", "plouf"]:
		return "Pas"
	if name.begins_with("marque_") or name in ["killmarker", "hitmarker", "buy", "denied", "armure_brisee", "coeur",
			"powerup_pick", "box", "perk", "round_start", "round_end"]:
		return "Interface"
	if name.begins_with("vent_") or name in ["moteur_avion", "voile", "sortie_avion", "decoy", "ambient", "thunder"]:
		return "Ambiance"
	return "Armes"


func play_at(name: String, pos: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
	var s := sound(name)
	if s == null:
		return
	var p := _players3d[_next_3d]
	_next_3d = (_next_3d + 1) % _players3d.size()
	p.bus = bus_of(name)
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
	p.bus = bus_of(name)
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
	_add("swap"); _key("swap", KEY_1); _key("swap", KEY_2)
	_mouse("swap", MOUSE_BUTTON_WHEEL_UP); _mouse("swap", MOUSE_BUTTON_WHEEL_DOWN)
	# Manette : Y appuyé = changer d'arme, Y maintenu = poser des plaques (comme Warzone).
	_add("arme_plaque"); _btn("arme_plaque", JOY_BUTTON_Y)
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
