class_name Hud
extends CanvasLayer
## Interface : lieu et case du quadrillage, boussole, état du joueur (sprint tactique,
## glissade, parachute…), jauge de sprint tactique, i/s, commandes tactiles, carte tactique
## et menu pause avec les réglages d'affichage.
##
## Tout ce qui est près des bords vit dans `_frame`, un cadre qui respecte la zone sûre du
## téléphone (encoche, coins arrondis) plus une marge réglable, et qui est mis à l'échelle
## selon le réglage « Taille de l'interface ».

signal request_plane
signal request_visit

var player: Joueur
var touch: TouchControls
var avion: Avion
var _frame: Control
var _place: Label
var _compass: Label
var _state: Label
var _tac: ProgressBar
var _help: Label
var _fps: Label
var _map: MapView
var _pause: Control
var _pause_box: VBoxContainer
var _drone_btn: Button
var _first_button: Button


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_frame = Control.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)

	_place = _label(_frame, 28, Color(1, 1, 1))
	_place.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place.offset_top = 4
	_compass = _label(_frame, 20, Color(1, 0.85, 0.45))
	_compass.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_compass.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_compass.offset_top = 40
	_fps = _label(_frame, 16, Color(1, 1, 1, 0.7))
	_fps.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_fps.offset_left = 4
	_fps.offset_top = 4
	_state = _label(_frame, 24, Color(1, 1, 1))
	_state.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_state.offset_left = -400
	_state.offset_right = 400
	_state.offset_top = -118
	_state.offset_bottom = -84
	_tac = ProgressBar.new()
	_tac.show_percentage = false
	_tac.max_value = 1.0
	_tac.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_tac.offset_left = -70
	_tac.offset_right = 70
	_tac.offset_top = -80
	_tac.offset_bottom = -72
	_tac.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.45)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(1, 0.8, 0.25)
	_tac.add_theme_stylebox_override("background", bg)
	_tac.add_theme_stylebox_override("fill", fill)
	_frame.add_child(_tac)
	_help = _label(_frame, 17, Color(1, 1, 1, 0.8))
	_help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_help.offset_top = -30
	_help.offset_bottom = -4
	_help.offset_left = 4

	touch = TouchControls.new()
	touch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.add_child(touch)
	touch.map_pressed.connect(toggle_map)
	touch.pause_pressed.connect(open_pause)

	_map = MapView.new()
	_map.visible = false
	add_child(_map)
	_build_pause()

	G.input_mode_changed.connect(func(_m): _update_help())
	G.settings_changed.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_update_help()


func _label(parent: Control, size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func attach(p: Joueur) -> void:
	player = p
	player.touch = touch
	_map.player = p
	player.state_changed.connect(func(_e): _update_help())


func set_avion(a: Avion) -> void:
	avion = a
	_map.avion = a


# ------------------------------------------------------------------------------------------------
# Zone sûre, marges et échelle
# ------------------------------------------------------------------------------------------------
## Bords à éviter (encoche, coins arrondis), en pixels de l'interface : [gauche, haut, droite, bas].
func safe_insets(vp: Vector2) -> Array:
	if not OS.has_feature("mobile"):
		return [0.0, 0.0, 0.0, 0.0]
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	if win.x <= 0 or win.y <= 0 or safe.size.x <= 0:
		return [0.0, 0.0, 0.0, 0.0]
	var f := vp.x / float(win.x)
	return [safe.position.x * f, safe.position.y * f, maxf(0.0, win.x - safe.end.x) * f, maxf(0.0, win.y - safe.end.y) * f]


func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	var ins := safe_insets(vp)
	var m := float(G.settings.hud_margin) * vp.x
	var left := maxf(ins[0], m)
	var top := maxf(ins[1], m * 0.5)
	var right := maxf(ins[2], m)
	var bottom := maxf(ins[3], m * 0.5)
	var s := clampf(float(G.settings.hud_scale), 0.5, 2.0)
	_frame.position = Vector2(left, top)
	_frame.scale = Vector2(s, s)
	_frame.size = (vp - Vector2(left + right, top + bottom)) / s
	if _pause:
		# Le menu suit la taille de l'interface, sans jamais dépasser de l'écran.
		var h := _pause_box.get_combined_minimum_size().y
		var ps := minf(s, vp.y * 0.96 / maxf(h, 1.0))
		_pause_box.scale = Vector2(ps, ps)
		_pause_box.pivot_offset = _pause_box.get_combined_minimum_size() / 2
	_fps.visible = bool(G.settings.show_fps)


## Rectangle (en pixels de l'écran) dans lequel l'interface est dessinée : pour les tests.
func frame_rect() -> Rect2:
	return Rect2(_frame.position, _frame.size * _frame.scale)


# ------------------------------------------------------------------------------------------------
# Carte et menu pause
# ------------------------------------------------------------------------------------------------
func toggle_map() -> void:
	_map.visible = not _map.visible


func open_pause() -> void:
	if _pause.visible:
		return
	_pause.visible = true
	_map.visible = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_drone_btn.text = "Quitter le drone" if player and player.is_drone() else "Mode drone (visite libre)"
	_first_button.grab_focus.call_deferred()


func close_pause() -> void:
	_pause.visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if _pause.visible:
		if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
			close_pause()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("carte"):
		toggle_map()
	elif event.is_action_pressed("pause"):
		open_pause()
		get_viewport().set_input_as_handled()


func _build_pause() -> void:
	_pause = Control.new()
	_pause.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.visible = false
	add_child(_pause)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.05, 0.08, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(center)
	_pause_box = VBoxContainer.new()
	_pause_box.custom_minimum_size = Vector2(520, 0)
	_pause_box.add_theme_constant_override("separation", 8)
	center.add_child(_pause_box)
	var title := _label(_pause_box, 34, Color(1, 0.85, 0.45))
	title.text = "PAUSE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_first_button = _button("Reprendre", close_pause)
	_button("Nouveau saut en parachute", func(): close_pause(); request_plane.emit())
	_button("Visite libre (au Lazaret)", func(): close_pause(); request_visit.emit())
	_drone_btn = _button("Mode drone (visite libre)", func():
		close_pause()
		if player:
			player.set_drone(not player.is_drone()))
	_slider("Taille de l'interface", "hud_scale", 0.6, 1.5, 0.05, "%d %%", 100.0)
	_slider("Marge des bords", "hud_margin", 0.0, 0.1, 0.005, "%d %%", 100.0)
	_slider("Sensibilité manette", "sens_pad", 0.3, 2.5, 0.05, "%.2f", 1.0)
	_slider("Sensibilité tactile", "sens_touch", 0.3, 2.5, 0.05, "%.2f", 1.0)
	_slider("Sensibilité souris", "sens_mouse", 0.3, 2.5, 0.05, "%.2f", 1.0)
	var fps := CheckButton.new()
	fps.text = "Afficher les images par seconde"
	fps.button_pressed = bool(G.settings.show_fps)
	fps.add_theme_font_size_override("font_size", 20)
	fps.toggled.connect(func(on: bool): G.set_setting("show_fps", on))
	_pause_box.add_child(fps)
	_button("Quitter le jeu", func(): get_tree().quit())


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 22)
	b.custom_minimum_size = Vector2(0, 52)
	b.pressed.connect(cb)
	_pause_box.add_child(b)
	return b


func _slider(text: String, key: String, lo: float, hi: float, step: float, fmt: String, mult: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var l := _label(row, 20, Color(1, 1, 1))
	l.custom_minimum_size = Vector2(250, 0)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(G.settings[key])
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(0, 40)
	var show := func(v: float): l.text = "%s  %s" % [text, fmt % (v * mult)]
	show.call(s.value)
	s.value_changed.connect(func(v: float):
		show.call(v)
		G.set_setting(key, v))
	row.add_child(s)
	_pause_box.add_child(row)


# ------------------------------------------------------------------------------------------------
# Textes selon l'état
# ------------------------------------------------------------------------------------------------
func key_name(action: String) -> String:
	match G.input_mode:
		"pad":
			return {"jump": "A", "crouch": "B", "sprint": "L3", "carte": "Select", "pause": "Start"}.get(action, action)
		"touch":
			return {"jump": "SAUT", "crouch": "ACCROUPI", "sprint": "SPRINT", "carte": "CARTE", "pause": "II"}.get(action, action)
		_:
			return {"jump": "Espace", "crouch": "C", "sprint": "Maj", "carte": "M", "pause": "Échap"}.get(action, action)


func _update_help() -> void:
	if G.input_mode == "touch" or player == null:
		_help.text = ""
		return
	if player.is_drone():
		_help.text = "%s / %s : monter / descendre  ·  %s : rapide  ·  F : quitter le drone" % [key_name("jump"), key_name("crouch"), key_name("sprint")]
		return
	_help.text = "%s : sauter / escalader  ·  %s : accroupi, glissade, annuler (maintenir : couché)  ·  %s : sprint (encore : tactique)  ·  %s : carte  ·  %s : pause" % [
		key_name("jump"), key_name("crouch"), key_name("sprint"), key_name("carte"), key_name("pause")]


func _process(_delta: float) -> void:
	if player == null:
		return
	var p := player.global_position
	_place.text = G.where(p)
	var heading := fposmod(-rad_to_deg(player.rotation.y), 360.0)
	var names := ["N", "NE", "E", "SE", "S", "SO", "O", "NO"]
	_compass.text = "%s  %d°  ·  alt. %d m" % [names[int(round(heading / 45.0)) % 8], int(heading), int(p.y)]
	_fps.text = "%d i/s  ·  %.1f m/s" % [Engine.get_frames_per_second(), player.hspeed]
	var st := ""
	var tl := {}
	match player.etat:
		Joueur.Etat.AVION:
			st = "AVION — %s : sauter" % key_name("jump")
			tl = {"saut": "SAUTER", "accroupi": "", "sprint": ""}
		Joueur.Etat.CHUTE_LIBRE:
			st = "CHUTE LIBRE · %d m — %s : ouvrir le parachute" % [int(player.height_above_ground()), key_name("jump")]
			tl = {"saut": "OUVRIR", "accroupi": "", "sprint": ""}
		Joueur.Etat.PARACHUTE:
			st = "PARACHUTE · %d m — %s : couper" % [int(player.height_above_ground()), key_name("crouch")]
			tl = {"saut": "", "accroupi": "COUPER", "sprint": ""}
		Joueur.Etat.GLISSADE:
			st = "GLISSADE"
			tl = {"accroupi": "ANNULER"}
		Joueur.Etat.ESCALADE:
			st = "ESCALADE"
		Joueur.Etat.DRONE:
			st = "DRONE"
			tl = {"saut": "MONTER", "accroupi": "BAS", "sprint": "RAPIDE"}
		_:
			if player.swimming:
				st = "NAGE"
			elif player.tac_left > 0.0:
				st = "SPRINT TACTIQUE"
			elif player.sprinting:
				st = "SPRINT"
				if player.tac_ready():
					tl = {"sprint": "TACTIQUE"}
			elif player.posture == Joueur.Posture.ACCROUPI:
				st = "ACCROUPI"
			elif player.posture == Joueur.Posture.COUCHE:
				st = "COUCHÉ"
	_state.text = st
	touch.labels = tl
	# Jauge : se vide pendant le sprint tactique, se remplit pendant la recharge.
	var on_ground := player.etat == Joueur.Etat.SOL or player.etat == Joueur.Etat.GLISSADE
	_tac.visible = on_ground and (player.sprinting or player.tac_left > 0.0 or player.tac_cooldown > 0.0)
	if player.tac_left > 0.0:
		_tac.value = player.tac_left / Joueur.TAC_DURATION
	else:
		_tac.value = 1.0 - player.tac_cooldown / Joueur.TAC_COOLDOWN
	_tac.modulate = Color(1, 1, 1) if player.tac_ready() or player.tac_left > 0.0 else Color(0.6, 0.6, 0.6)


class MapView:
	extends Control
	## Carte tactique : l'image générée, les noms des lieux, le joueur et le trajet de l'avion.
	var player: Node3D
	var avion: Avion
	var _tex: Texture2D

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tex = load("res://assets/map/carte.png")

	func _process(_d: float) -> void:
		if visible:
			queue_redraw()

	func _draw() -> void:
		if size.x < 10.0 or size.y < 10.0:
			return
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))
		var side := minf(size.x, size.y) * 0.94
		var origin := (size - Vector2(side, side)) / 2
		draw_texture_rect(_tex, Rect2(origin, Vector2(side, side)), false)
		var world := float(G.data.get("monde", 640))
		var to_map := func(x: float, z: float) -> Vector2:
			return origin + Vector2((x / world + 0.5) * side, (z / world + 0.5) * side)
		var font := ThemeDB.fallback_font
		var fs := int(side / 42.0)
		for l in G.data.get("lieux", []):
			var off: Array = l.get("etiquette", [0, -28])
			var pt: Vector2 = to_map.call(float(l.x) + float(off[0]), float(l.z) + float(off[1])) + Vector2(0, fs * 0.35)
			var txt := String(l.nom).to_upper()
			var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string_outline(font, pt + Vector2(-w / 2, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, 0.9))
			draw_string(font, pt + Vector2(-w / 2, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1))
		if is_instance_valid(avion):
			var a: Vector2 = to_map.call(avion.start.x, avion.start.z)
			var b: Vector2 = to_map.call(avion.end.x, avion.end.z)
			draw_dashed_line(a, b, Color(1, 1, 1, 0.8), 3.0, 14.0)
			var ap: Vector2 = to_map.call(avion.global_position.x, avion.global_position.z)
			draw_circle(ap, side / 90.0, Color(1, 0.8, 0.2))
		if player:
			var pp: Vector2 = to_map.call(player.global_position.x, player.global_position.z)
			var fwd := -player.global_basis.z
			var dir := Vector2(fwd.x, fwd.z).normalized()
			var perp := Vector2(-dir.y, dir.x)
			var s := side / 70.0
			draw_colored_polygon(PackedVector2Array([pp + dir * s * 1.4, pp - dir * s * 0.8 + perp * s, pp - dir * s * 0.8 - perp * s]), Color(0.2, 0.9, 1.0))
			draw_polyline(PackedVector2Array([pp + dir * s * 1.4, pp - dir * s * 0.8 + perp * s, pp - dir * s * 0.8 - perp * s, pp + dir * s * 1.4]), Color(0, 0, 0), 2.0)
