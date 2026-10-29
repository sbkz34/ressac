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
signal request_lobby
signal request_settings_closed

var mode := "lobby"            # "lobby", "partie" ou "entrainement" : change le menu pause
var partie: Partie
var pillage: Pillage
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
var _cross: Crosshair
var _vitals: Vitals
var _prompt: Label
var _notice: Label
var _money: Label
var _notice_t := 0.0
var _pause: Control
var _pause_box: VBoxContainer
var _drone_btn: Button
var _first_button: Button
var _plane_btn: Button
var _visit_btn: Button
var _lobby_btn: Button
var _brume_lbl: Label
var _respawn_lbl: Label
var _gas: ColorRect
var _panel: Control
var _panel_box: VBoxContainer
var _panel_kind := ""
var _station: Node3D
var _crate: Coffre
var _alive_lbl: Label
var _binds: Control
var _binds_box: VBoxContainer
var _binds_grid: GridContainer
var _capture := {}             # touche en attente : {action, pad, t}
var _mini: MiniMap
var _hurt: HurtOverlay
var _feed: Label
var _feed_lines: Array = []       # [texte, temps restant]


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
	_mini = MiniMap.new()
	_mini.position = Vector2(4, 4)
	_mini.size = Vector2(MiniMap.SIDE, MiniMap.SIDE)
	_frame.add_child(_mini)
	_fps = _label(_frame, 16, Color(1, 1, 1, 0.7))
	_fps.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_fps.offset_left = MiniMap.SIDE + 14
	_fps.offset_top = 4
	_state = _label(_frame, 24, Color(1, 1, 1))
	_state.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_state.offset_left = -400
	_state.offset_right = 400
	_state.offset_top = -168
	_state.offset_bottom = -134
	_tac = ProgressBar.new()
	_tac.show_percentage = false
	_tac.max_value = 1.0
	_tac.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_tac.offset_left = -70
	_tac.offset_right = 70
	_tac.offset_top = -130
	_tac.offset_bottom = -122
	_tac.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.45)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(1, 0.8, 0.25)
	_tac.add_theme_stylebox_override("background", bg)
	_tac.add_theme_stylebox_override("fill", fill)
	_frame.add_child(_tac)
	_money = _label(_frame, 18, Color(0.6, 0.95, 0.55))
	_money.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_money.offset_left = 4
	_money.offset_top = MiniMap.SIDE + 10
	_alive_lbl = _label(_frame, 20, Color(1, 1, 1))
	_alive_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_alive_lbl.offset_left = 4
	_alive_lbl.offset_top = MiniMap.SIDE + 32
	_feed = _label(_frame, 16, Color(1, 1, 1, 0.92))
	_feed.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_feed.offset_left = 4
	_feed.offset_top = MiniMap.SIDE + 58
	_vitals = Vitals.new()
	_vitals.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_vitals.offset_left = -300
	_vitals.offset_right = 300
	_vitals.offset_top = -112
	_vitals.offset_bottom = -36
	_frame.add_child(_vitals)
	_prompt = _label(_frame, 22, Color(1, 0.92, 0.7))
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.offset_left = -400
	_prompt.offset_right = 400
	_prompt.offset_top = 60
	_prompt.offset_bottom = 92
	_notice = _label(_frame, 20, Color(1, 1, 1))
	_notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.offset_left = -400
	_notice.offset_right = 400
	_notice.offset_top = 100
	_notice.offset_bottom = 128
	_brume_lbl = _label(_frame, 19, Color(0.85, 0.95, 0.6))
	_brume_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_brume_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_brume_lbl.offset_top = 68
	_respawn_lbl = _label(_frame, 34, Color(1, 0.9, 0.6))
	_respawn_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_respawn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_respawn_lbl.offset_left = -500
	_respawn_lbl.offset_right = 500
	_respawn_lbl.offset_top = -40
	_respawn_lbl.offset_bottom = 10
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

	_hurt = HurtOverlay.new()
	_hurt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hurt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hurt)
	move_child(_hurt, 0)
	_gas = ColorRect.new()
	_gas.color = Color(0.72, 0.8, 0.35, 0.0)
	_gas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_gas)
	move_child(_gas, 0)
	_cross = Crosshair.new()
	_cross.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cross)
	move_child(_cross, 0)
	_map = MapView.new()
	_map.visible = false
	add_child(_map)
	_build_pause()
	_build_binds()
	_build_panel()

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
	_mini.player = p
	_hurt.sante = p.sante
	player.state_changed.connect(func(_e): _update_help())
	_cross.arsenal = p.arsenal
	_vitals.arsenal = p.arsenal
	p.arsenal.hit.connect(_cross.on_hit)
	p.arsenal.notice.connect(notify)
	p.arsenal.shop_requested.connect(open_shop)
	p.arsenal.loadout_requested.connect(open_loadout_choice)
	p.sante.damaged.connect(func(_a, _z, on_armor: bool, broken: bool, _k):
		var by := p.sante.last_attacker as Node3D
		if by and is_instance_valid(by) and by != p and p.sante.last_cause in ["balle", "grenade"]:
			_cross.add_damage(by.global_position)
			_hurt.flash()
			# Son de sa propre armure qui encaisse ou qui cède.
			if broken:
				G.play("armure_brisee", -5.0, 0.8)
			elif on_armor:
				G.play("marque_armure", -12.0, 0.75))


func notify(t: String) -> void:
	_notice.text = t
	_notice_t = 2.5


func set_partie(p: Partie) -> void:
	partie = p
	_map.partie = p
	_mini.partie = p
	_feed_lines.clear()
	_feed.text = ""
	if p:
		p.message.connect(notify)
		p.killed.connect(_on_killed)


## Fil des éliminations, en haut à gauche (les plus récentes en bas).
func _on_killed(killer: String, victim: String, cause: String, by_player: bool, on_player: bool) -> void:
	var t := ""
	var gren := " (grenade)" if cause == "grenade" else ""
	if by_player:
		t = "Vous avez éliminé %s%s" % [victim, gren]
	elif on_player and killer != "":
		t = "%s vous a éliminé%s" % [killer, gren]
	elif killer != "":
		t = "%s a éliminé %s%s" % [killer, victim, gren]
	else:
		if on_player:
			t = {"brume": "Vous succombez à la Brume", "chute": "Vous vous écrasez"}.get(cause, "Vous êtes éliminé")
		else:
			t = "%s %s" % [victim, {"brume": "succombe à la Brume", "chute": "s'écrase"}.get(cause, "est éliminé")]
	if by_player:
		notify("Élimination : %s" % victim)
	_feed_lines.append([t, 7.0])
	while _feed_lines.size() > 5:
		_feed_lines.pop_front()
	_refresh_feed()


func _refresh_feed() -> void:
	var lines := []
	for l in _feed_lines:
		lines.append(l[0])
	_feed.text = "\n".join(lines)


func set_avion(a: Avion) -> void:
	avion = a
	_map.avion = a
	_mini.avion = a


func set_pillage(p: Pillage) -> void:
	pillage = p
	_map.pillage = p
	_mini.pillage = p


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
	_mini.visible = not _map.visible


func open_pause() -> void:
	if _pause.visible:
		return
	close_panel()
	_pause.visible = true
	_map.visible = false
	# Depuis le lobby, l'interface de jeu est masquée : on ne montre que le menu.
	if mode == "lobby":
		visible = true
		_frame.visible = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var training := mode == "entrainement"
	_plane_btn.visible = training
	_visit_btn.visible = training
	_drone_btn.visible = training
	_lobby_btn.visible = mode != "lobby"
	_lobby_btn.text = "Abandonner la partie (lobby)" if mode == "partie" else "Retour au lobby"
	_first_button.text = "Fermer" if mode == "lobby" else "Reprendre"
	_drone_btn.text = "Quitter le drone" if player and player.is_drone() else "Mode drone (visite libre)"
	_layout()
	_first_button.grab_focus.call_deferred()


func close_pause() -> void:
	_pause.visible = false
	get_tree().paused = false
	_frame.visible = true
	if mode == "lobby":
		visible = false
		request_settings_closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if _binds.visible:
		if _capture.is_empty() and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
			close_binds()
			get_viewport().set_input_as_handled()
		return
	if _pause.visible:
		if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
			close_pause()
			get_viewport().set_input_as_handled()
		return
	if mode == "lobby":
		return
	if _panel.visible:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
			if _panel_kind != "fin":
				close_panel()
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
	_plane_btn = _button("Nouveau saut en parachute", func(): close_pause(); request_plane.emit())
	_visit_btn = _button("Visite libre (au Lazaret)", func(): close_pause(); request_visit.emit())
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
	var q_btn: Button = _button("", func(): pass)
	q_btn.text = _quality_text()
	q_btn.pressed.connect(func():
		G.set_setting("qualite", (int(G.settings.qualite) + 1) % 3)
		q_btn.text = _quality_text())
	_button("Touches (manette, clavier)", open_binds)
	_lobby_btn = _button("Retour au lobby", func(): close_pause(); request_lobby.emit())
	_button("Quitter le jeu", func(): get_tree().quit())


# ------------------------------------------------------------------------------------------------
# Touches : une case par action et par côté (manette, clavier / souris)
# ------------------------------------------------------------------------------------------------
func _build_binds() -> void:
	_binds = Control.new()
	_binds.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_binds.visible = false
	add_child(_binds)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.05, 0.08, 0.9)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_binds.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_binds.add_child(center)
	_binds_box = VBoxContainer.new()
	_binds_box.add_theme_constant_override("separation", 10)
	center.add_child(_binds_box)
	var title := _label(_binds_box, 32, Color(1, 0.85, 0.45))
	title.text = "TOUCHES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hint := _label(_binds_box, 17, Color(1, 1, 1, 0.75))
	hint.text = "Choisir une case, puis appuyer sur la nouvelle touche (5 s pour annuler). Une touche déjà prise est échangée."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(980, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_binds_box.add_child(scroll)
	_binds_grid = GridContainer.new()
	_binds_grid.columns = 3
	_binds_grid.add_theme_constant_override("h_separation", 12)
	_binds_grid.add_theme_constant_override("v_separation", 6)
	_binds_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_binds_grid)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_binds_box.add_child(row)
	for pair in [["Rétablir les touches par défaut", func(): G.reset_bindings(); _fill_binds()], ["Retour", close_binds]]:
		var b := Button.new()
		b.text = pair[0]
		b.add_theme_font_size_override("font_size", 20)
		b.custom_minimum_size = Vector2(360, 50)
		b.pressed.connect(pair[1])
		row.add_child(b)


func _quality_text() -> String:
	return "Qualité graphique : %s" % ["Performance (60 %, sans ombres)", "Équilibrée (75 %)", "Qualité (100 %)"][clampi(int(G.settings.qualite), 0, 2)]


func open_binds() -> void:
	_pause.visible = false
	_binds.visible = true
	_capture = {}
	_fill_binds()
	var vp := get_viewport().get_visible_rect().size
	var h := _binds_box.get_combined_minimum_size()
	var sc := minf(clampf(float(G.settings.hud_scale), 0.5, 2.0), minf(vp.y * 0.96 / maxf(h.y, 1.0), vp.x * 0.96 / maxf(h.x, 1.0)))
	_binds_box.scale = Vector2(sc, sc)
	_binds_box.pivot_offset = h / 2


func close_binds() -> void:
	_capture = {}
	_binds.visible = false
	_pause.visible = true
	_update_help()
	_first_button.grab_focus.call_deferred()


func _fill_binds() -> void:
	var focus_first: Button = null
	for n in _binds_grid.get_children():
		_binds_grid.remove_child(n)
		n.queue_free()
	for h in ["Action", "Manette", "Clavier et souris"]:
		var l := _label(_binds_grid, 17, Color(1, 0.85, 0.45))
		l.text = h
	for r in G.BINDABLE:
		var l := _label(_binds_grid, 19, Color(1, 1, 1))
		l.text = r[0]
		l.custom_minimum_size = Vector2(470, 0)
		for side in [true, false]:
			var action: String = r[1] if side else r[2]
			var b := Button.new()
			b.custom_minimum_size = Vector2(230, 44)
			b.add_theme_font_size_override("font_size", 19)
			var waiting: bool = not _capture.is_empty() and _capture.action == action and _capture.pad == side
			if action == "":
				b.text = "—"
				b.disabled = true
			else:
				b.text = "Appuyez…" if waiting else G.binding_name(action, side)
				b.pressed.connect(func(): _start_capture(action, side))
			_binds_grid.add_child(b)
			if focus_first == null and not b.disabled:
				focus_first = b
	if focus_first and _capture.is_empty():
		focus_first.grab_focus.call_deferred()


func _start_capture(action: String, pad: bool) -> void:
	_capture = {"action": action, "pad": pad, "t": 0.0}
	_fill_binds()


## Pendant la capture, la prochaine touche du bon côté devient la nouvelle touche de l'action.
func _input(event: InputEvent) -> void:
	if _capture.is_empty() or float(_capture.t) < 0.2:
		return
	var pad: bool = _capture.pad
	var e: InputEvent = null
	if pad:
		if event is InputEventJoypadButton and event.pressed:
			var b := InputEventJoypadButton.new()
			b.device = G.ANY_DEVICE
			b.button_index = (event as InputEventJoypadButton).button_index
			e = b
		elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.6 \
				and (event.axis == JOY_AXIS_TRIGGER_LEFT or event.axis == JOY_AXIS_TRIGGER_RIGHT):
			var m := InputEventJoypadMotion.new()
			m.device = G.ANY_DEVICE
			m.axis = (event as InputEventJoypadMotion).axis
			m.axis_value = 1.0
			e = m
	else:
		if event is InputEventKey and event.pressed and not event.echo:
			if (event as InputEventKey).physical_keycode == KEY_ESCAPE:
				_capture = {}
				_fill_binds()
				get_viewport().set_input_as_handled()
				return
			var k := InputEventKey.new()
			k.physical_keycode = (event as InputEventKey).physical_keycode
			e = k
		elif event is InputEventMouseButton and event.pressed:
			var mb := InputEventMouseButton.new()
			mb.button_index = (event as InputEventMouseButton).button_index
			e = mb
	if e:
		G.rebind(String(_capture.action), pad, e)
		_capture = {}
		_fill_binds()
		get_viewport().set_input_as_handled()
	elif G.is_pad_event(event) or G.is_kb_event(event):
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------------------------------------
# Fenêtres en jeu (achat, choix de classe, fin de partie) : le jeu continue derrière
# ------------------------------------------------------------------------------------------------
func _build_panel() -> void:
	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.visible = false
	add_child(_panel)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.05, 0.08, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(center)
	_panel_box = VBoxContainer.new()
	_panel_box.custom_minimum_size = Vector2(620, 0)
	_panel_box.add_theme_constant_override("separation", 8)
	center.add_child(_panel_box)


func _panel_begin(kind: String, title: String) -> void:
	_panel_kind = kind
	for n in _panel_box.get_children():
		_panel_box.remove_child(n)
		n.queue_free()
	var t := _label(_panel_box, 32, Color(1, 0.85, 0.45))
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.visible = true
	_map.visible = false
	if player:
		player.ui_block = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _panel_button(text: String, cb: Callable, disabled := false, small := false) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = disabled
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 17 if small else 21)
	b.custom_minimum_size = Vector2(620, 46 if small else 58)
	b.pressed.connect(cb)
	_panel_box.add_child(b)
	return b


func _panel_end() -> void:
	# Taille du texte et de la fenêtre comme le reste de l'interface, sans dépasser l'écran.
	var vp := get_viewport().get_visible_rect().size
	var h := _panel_box.get_combined_minimum_size().y
	var ps := minf(clampf(float(G.settings.hud_scale), 0.5, 2.0), vp.y * 0.95 / maxf(h, 1.0))
	_panel_box.scale = Vector2(ps, ps)
	_panel_box.pivot_offset = _panel_box.get_combined_minimum_size() / 2
	for n in _panel_box.get_children():
		if n is Button and not n.disabled:
			n.grab_focus.call_deferred()
			break


func close_panel() -> void:
	if not _panel.visible:
		return
	_panel.visible = false
	_panel_kind = ""
	if player and not (partie and partie.respawn_left >= 0.0):
		player.ui_block = false


func open_shop(station: Node3D) -> void:
	_station = station
	var a := player.arsenal
	_panel_begin("achat", "STATION D'ACHAT · %d €" % a.argent)
	for art in Boutique.ARTICLES:
		var why := Boutique.refusal(a, art.id)
		var text := "%s — %d €\n%s" % [art.nom, art.prix, art.desc if why == "" else why]
		_panel_button(text, func():
			if Boutique.buy(a, art.id, _station, pillage):
				open_shop(_station), why != "")
	_panel_button("Fermer", close_panel, false, true)
	_panel_end()


func open_loadout_choice(crate: Coffre) -> void:
	_crate = crate
	_panel_begin("classe", "LARGAGE DE CLASSE")
	for k in Loadouts.SLOTS:
		var d := Loadouts.get_one(k)
		_panel_button("%s\n%s" % [d.nom, Loadouts.summary(d)], func():
			if is_instance_valid(_crate) and _crate.can_open():
				_crate.open_chest()
				player.arsenal.apply_loadout(d)
			close_panel())
	_panel_button("Fermer", close_panel, false, true)
	_panel_end()


func show_end(victory: bool, stats: Dictionary) -> void:
	var place := int(stats.get("place", 0))
	var total := int(stats.get("total", 1))
	var title := "VICTOIRE — DERNIER DEBOUT" if victory else "ÉLIMINÉ"
	if not victory and place > 0 and total > 1:
		title = "ÉLIMINÉ — %de SUR %d" % [place, total]
	_panel_begin("fin", title)
	var t := int(stats.get("temps", 0.0))
	var lines := []
	if total > 1:
		lines.append("Classement : %s / %d" % ["1er" if place == 1 else "%de" % place, total])
		lines.append("Éliminations : %d" % int(stats.get("eliminations", 0)))
	lines.append_array([
		"Temps de survie : %d min %02d s" % [t / 60, t % 60],
		"Phase atteinte : %d / %d" % [int(stats.get("phase", 1)), Brume.PHASES.size()],
		"Réapparitions : %d" % int(stats.get("morts", 0)),
		"Argent en poche : %d €" % int(stats.get("argent", 0)),
	])
	for l in lines:
		var lbl := _label(_panel_box, 22, Color(1, 1, 1))
		lbl.text = l
	_panel_button("Retour au lobby", func():
		close_panel()
		request_lobby.emit())
	_panel_end()


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
	if G.input_mode == "touch":
		return {"jump": "SAUT", "crouch": "ACCROUPI", "sprint": "SPRINT", "carte": "CARTE", "pause": "II",
			"use": "ACTION", "interact": "ACTION", "reload": "RECH.", "plate": "PLAQUE"}.get(action, action)
	var pad := G.input_mode == "pad"
	if pad and action in ["interact", "reload"]:
		action = "use"
	var n := G.binding_name(action, pad)
	return n if n != "" else action


func _update_help() -> void:
	if G.input_mode == "touch" or player == null:
		_help.text = ""
		return
	if player.is_drone():
		_help.text = "%s / %s : monter / descendre  ·  %s : rapide  ·  F : quitter le drone" % [key_name("jump"), key_name("crouch"), key_name("sprint")]
		return
	var k := func(a: String) -> String: return key_name(a)
	if G.input_mode == "pad":
		_help.text = "%s tirer · %s viser · %s ramasser / recharger · %s arme (maintenir : plaque) · %s sauter · %s accroupi, glissade · %s sprint · %s carte" % [
			k.call("fire"), k.call("ads"), k.call("use"), G.binding_name("arme_plaque", true), k.call("jump"), k.call("crouch"), k.call("sprint"), k.call("carte")]
	else:
		_help.text = "%s tirer · %s viser · %s ramasser · %s recharger · %s arme · %s plaque · %s sauter · %s accroupi, glissade · %s sprint · %s carte" % [
			k.call("fire"), k.call("ads"), k.call("interact"), k.call("reload"), k.call("swap"), k.call("plate"), k.call("jump"), k.call("crouch"), k.call("sprint"), k.call("carte")]


func _process(delta: float) -> void:
	if not _capture.is_empty():
		_capture.t = float(_capture.t) + delta
		if float(_capture.t) > 5.2:
			_capture = {}
			_fill_binds()
	if player == null:
		return
	_vitals.visible = player.etat != Joueur.Etat.DRONE
	_cross.visible = not _map.visible and not _panel.visible
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
	var a := player.arsenal
	# Brume, réapparition, voile toxique.
	var in_match := partie != null and partie.running
	_brume_lbl.text = partie.brume.status_text() if in_match else ""
	if in_match and player.in_gas:
		_brume_lbl.text = "DANS LA BRUME — zone sûre à %d m%s" % [int(partie.brume.distance_to_safety(player.global_position)),
			" · masque %d s" % int(a.gas_mask) if a.gas_mask > 0.0 else ""]
	_brume_lbl.modulate = Color(1, 0.45, 0.35) if player.in_gas else Color(1, 1, 1)
	_gas.color.a = (0.22 + 0.06 * sin(Time.get_ticks_msec() / 250.0)) if player.in_gas else 0.0
	if partie and partie.respawn_left >= 0.0:
		_respawn_lbl.text = "Redéploiement dans %d s" % int(ceil(partie.respawn_left))
	elif partie and not partie.running and player.sante.dead:
		_respawn_lbl.text = "Éliminé"
	else:
		_respawn_lbl.text = ""
	if a.letal_n > 0:
		tl["grenade"] = "GREN. %d" % a.letal_n
	if a.tactique_n > 0:
		tl["fumigene"] = "FUMI. %d" % a.tactique_n
	if a.target_item:
		tl["action"] = "OUVRIR" if a.target_item is Coffre else "PRENDRE"
		var k := key_name("interact")
		_prompt.text = "%s : %s" % [k, a.interact_label()]
	else:
		_prompt.text = ""
		var w := a.current()
		if not w.is_empty() and int(w.chargeur) == 0 and a.can_use_weapon():
			_prompt.text = "Recharger (%s)" % key_name("reload") if int(a.reserve[Armes.info(w.id).munition]) > 0 else "Plus de munitions"
		elif a.plates > 0 and a.plate_t <= 0.0 and player.sante.armor < player.sante.armor_max - 1.0 and a.can_use_weapon():
			# Rappel : comment remettre une plaque (maintenir).
			var how := "%s ou %s" % [G.binding_name("arme_plaque", true), G.binding_name("plate", true)] if G.input_mode == "pad" else key_name("plate")
			_prompt.text = "Plaque : maintenir %s" % how
	if _panel.visible:
		_prompt.text = ""
	if not a.can_use_weapon():
		for k in ["tir", "viser", "recharger", "arme", "plaque", "grenade", "fumigene"]:
			tl[k] = ""
	touch.labels = tl
	_money.text = "%d €" % a.argent
	if in_match and partie.combatants.size() > 1:
		_alive_lbl.text = "%d EN JEU  ·  %d ÉLIM." % [partie.remaining(), int(partie.stats.get("eliminations", 0))]
	else:
		_alive_lbl.text = ""
	if not _feed_lines.is_empty():
		var changed := false
		for l in _feed_lines:
			l[1] = float(l[1]) - delta
		while not _feed_lines.is_empty() and float(_feed_lines[0][1]) <= 0.0:
			_feed_lines.pop_front()
			changed = true
		if changed:
			_refresh_feed()
	_notice_t -= delta
	_notice.modulate.a = clampf(_notice_t, 0.0, 1.0)
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
	var partie: Partie
	var pillage: Pillage
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
		var px_per_m := side / world
		if partie and partie.running and partie.brume.phase > 0:
			var b := partie.brume
			var c: Vector2 = to_map.call(b.center.x, b.center.y)
			draw_arc(c, b.radius * px_per_m, 0, TAU, 96, Color(0.85, 0.95, 0.55, 0.95), 3.0)
			var nc: Vector2 = to_map.call(b.next_center.x, b.next_center.y)
			_dashed_circle(nc, b.next_radius * px_per_m, Color(1, 1, 1, 0.9))
		if pillage:
			var fouineur: bool = player and player.arsenal.has_perk("fouineur")
			for ch in pillage.chests:
				if not is_instance_valid(ch) or not ch.can_open():
					continue
				var cp: Vector2 = to_map.call(ch.global_position.x, ch.global_position.z)
				if ch.largage:
					draw_circle(cp, side / 80.0, Color(0.4, 1.0, 0.5))
					draw_arc(cp, side / 50.0, 0, TAU, 24, Color(0.4, 1.0, 0.5), 2.0)
				elif fouineur and ch.global_position.distance_to(player.global_position) < 90.0:
					draw_rect(Rect2(cp - Vector2.ONE * side / 140.0, Vector2.ONE * side / 70.0), Color(1, 0.8, 0.3))
		# Tirs ennemis récents (sans silencieux).
		for sh in G.recent_shots():
			if sh[2] == player:
				continue
			var sp: Vector2 = to_map.call(sh[0].x, sh[0].z)
			draw_circle(sp, side / 110.0, Color(1, 0.15, 0.1, 1.0 - float(sh[1]) / G.SHOT_VISIBLE))
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


	func _dashed_circle(c: Vector2, r: float, col: Color) -> void:
		if r < 1.0:
			draw_circle(c, 3.0, col)
			return
		var n := 48
		for k in n:
			if k % 2 == 0:
				draw_arc(c, r, TAU * k / n, TAU * (k + 1) / n, 4, col, 2.0)

class MiniMap:
	extends Control
	## Mini-carte en haut à gauche, qui tourne avec la vue (le haut = devant soi) : le relief,
	## la Brume (cercle actuel et suivant), les largages, les tirs ennemis récents en rouge.
	const SIDE := 190.0
	const RANGE := 110.0        # mètres du centre au bord
	var player: Joueur
	var partie: Partie
	var pillage: Pillage
	var avion: Avion
	var _tex: Texture2D
	var _tex_ppm := 2.0         # pixels de l'image par mètre

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true
		_tex = load("res://assets/map/carte_fond.png")
		_tex_ppm = float(_tex.get_width()) / float(G.data.get("monde", 640))

	func _process(_d: float) -> void:
		if is_visible_in_tree():
			queue_redraw()

	func _draw() -> void:
		if player == null:
			return
		var c := size / 2.0
		var k := size.x / 2.0 / RANGE              # pixels de l'écran par mètre
		var yaw := player.rotation.y
		var pp := player.global_position
		var half := float(G.data.get("monde", 640)) / 2.0
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.16, 0.28))
		draw_set_transform(c, yaw, Vector2.ONE * (k / _tex_ppm))
		draw_texture(_tex, -Vector2(pp.x + half, pp.z + half) * _tex_ppm, Color(1, 1, 1, 0.92))
		draw_set_transform_matrix(Transform2D.IDENTITY)
		var to_s := func(x: float, z: float) -> Vector2:
			return c + Vector2(x - pp.x, z - pp.z).rotated(yaw) * k
		if partie and partie.running and partie.brume.phase > 0:
			var b := partie.brume
			draw_arc(to_s.call(b.center.x, b.center.y), b.radius * k, 0, TAU, 96, Color(0.85, 0.95, 0.55, 0.95), 2.5)
			draw_arc(to_s.call(b.next_center.x, b.next_center.y), b.next_radius * k, 0, TAU, 96, Color(1, 1, 1, 0.75), 1.5)
		if pillage:
			for ch in pillage.chests:
				if is_instance_valid(ch) and ch.largage and ch.can_open():
					draw_circle(to_s.call(ch.global_position.x, ch.global_position.z), 4.0, Color(0.4, 1.0, 0.5))
		if is_instance_valid(avion):
			draw_circle(to_s.call(avion.global_position.x, avion.global_position.z), 4.0, Color(1, 0.8, 0.2))
		# Tirs ennemis : un point rouge qui s'estompe.
		for sh in G.recent_shots():
			if sh[2] == player:
				continue
			var sp: Vector2 = to_s.call(sh[0].x, sh[0].z)
			var a := 1.0 - float(sh[1]) / G.SHOT_VISIBLE
			draw_circle(sp, 5.0, Color(1, 0.12, 0.08, a))
			draw_arc(sp, 5.0, 0, TAU, 12, Color(0, 0, 0, a * 0.8), 1.0)
		# Soi-même au centre, tourné vers le haut ; le nord sur le bord.
		var s := 7.0
		var tri := PackedVector2Array([c + Vector2(0, -s * 1.4), c + Vector2(s, s), c + Vector2(-s, s)])
		draw_colored_polygon(tri, Color(0.2, 0.9, 1.0))
		draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color(0, 0, 0), 1.5)
		var north := Vector2(0, -1).rotated(yaw)
		var edge := c + north * (size.x / 2.0 - 11.0)
		var font := ThemeDB.fallback_font
		draw_circle(edge, 9.0, Color(0, 0, 0, 0.55))
		draw_string(font, edge + Vector2(-5, 5), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.85, 0.45))
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.5), false, 2.0)


class HurtOverlay:
	extends ColorRect
	## Bords de l'écran qui rougissent quand la vie baisse (et battent sous 35 points), plus un
	## éclat rouge à chaque coup reçu.
	var sante: Sante
	var _flash := 0.0
	var _mat: ShaderMaterial

	func _ready() -> void:
		var sh := Shader.new()
		sh.code = """shader_type canvas_item;
uniform float niveau = 0.0;
uniform float eclat = 0.0;
void fragment() {
	vec2 uv = (UV - 0.5) * vec2(1.0, 0.8);
	float edge = smoothstep(0.22, 0.72, length(uv));
	float a = edge * (0.75 * niveau + 0.45 * eclat) + 0.06 * niveau;
	COLOR = vec4(0.7, 0.0, 0.0, clamp(a, 0.0, 0.85));
}"""
		_mat = ShaderMaterial.new()
		_mat.shader = sh
		material = _mat
		color = Color(1, 1, 1, 1)

	func flash() -> void:
		_flash = 1.0

	func _process(delta: float) -> void:
		_flash = maxf(0.0, _flash - delta * 2.5)
		var lvl := 0.0
		if sante and not sante.dead:
			lvl = clampf((60.0 - sante.hp) / 60.0, 0.0, 1.0)
			if sante.hp < 35.0:
				lvl *= 0.8 + 0.2 * sin(Time.get_ticks_msec() / 1000.0 * TAU * 1.4)
		visible = lvl > 0.01 or _flash > 0.01
		_mat.set_shader_parameter("niveau", lvl)
		_mat.set_shader_parameter("eclat", _flash)


class Crosshair:
	extends Control
	## Réticule au centre de l'écran : quatre traits écartés selon la dispersion, un point en
	## visée, la lunette du fusil de précision, et les marqueurs de touche (blanc : corps,
	## jaune : tête, bleu : armure, bleu épais : armure brisée, rouge : élimination).
	var arsenal: Arsenal
	var _hit_t := 0.0
	var _hit_kind := ""
	var _dmg: Array = []          # [position de l'attaquant, temps restant]

	## Touché : un arc rouge autour du centre indique d'où vient le tir.
	func add_damage(from: Vector3) -> void:
		for d in _dmg:
			if (d[0] as Vector3).distance_to(from) < 3.0:
				d[0] = from
				d[1] = 1.6
				return
		_dmg.append([from, 1.6])
	const COLORS := {"corps": Color(1, 1, 1), "tete": Color(1, 0.85, 0.2), "armure": Color(0.45, 0.7, 1.0),
		"brise": Color(0.3, 0.6, 1.0), "elimination": Color(1, 0.25, 0.2)}

	func on_hit(kind: String, _amount: float) -> void:
		_hit_kind = kind
		_hit_t = 0.22 if kind != "elimination" else 0.45

	func _process(delta: float) -> void:
		_hit_t = maxf(0.0, _hit_t - delta)
		for d in _dmg:
			d[1] = float(d[1]) - delta
		_dmg = _dmg.filter(func(d): return float(d[1]) > 0.0)
		queue_redraw()

	func _draw() -> void:
		if arsenal == null:
			return
		var c := size / 2
		var j := arsenal.joueur
		for d in _dmg:
			var local := j.global_basis.inverse() * ((d[0] as Vector3) - j.global_position)
			var ang := atan2(local.x, -local.z) - PI / 2.0
			var r := minf(size.x, size.y) * 0.2
			var col := Color(1, 0.15, 0.1, clampf(float(d[1]), 0.0, 1.0) * 0.85)
			draw_arc(c, r, ang - 0.32, ang + 0.32, 16, col, 9.0)
		if not arsenal.can_use_weapon():
			return
		if arsenal.view.hidden_by_scope:
			var r := minf(size.x, size.y) * 0.42
			var w := maxf(size.x, size.y) * 1.5
			draw_arc(c, r + w / 2, 0, TAU, 72, Color(0, 0, 0), w)
			draw_line(c - Vector2(r, 0), c + Vector2(r, 0), Color(0, 0, 0, 0.85), 1.5)
			draw_line(c - Vector2(0, r), c + Vector2(0, r), Color(0, 0, 0, 0.85), 1.5)
		elif arsenal.ads < 0.6 and not arsenal.current().is_empty():
			# Écart des traits : la dispersion vue à l'écran.
			var cam := arsenal.joueur.cam
			var px := tan(deg_to_rad(arsenal.spread)) / tan(deg_to_rad(cam.fov / 2.0)) * size.y / 2.0
			var gap := clampf(px, 4.0, size.y * 0.3)
			var col := Color(1, 1, 1, 0.85 * (1.0 - arsenal.ads))
			if arsenal.assist_target:
				col = Color(1, 0.5, 0.45, col.a)
			for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				draw_line(c + d * gap, c + d * (gap + 9.0), Color(0, 0, 0, col.a * 0.6), 4.0)
				draw_line(c + d * gap, c + d * (gap + 9.0), col, 2.0)
		else:
			draw_circle(c, 2.0, Color(1, 1, 1, 0.9))
		if _hit_t > 0.0:
			var k := COLORS.get(_hit_kind, Color(1, 1, 1)) as Color
			k.a = clampf(_hit_t * 6.0, 0.0, 1.0)
			var s := 14.0 if _hit_kind in ["brise", "elimination"] else 10.0
			var t := 4.0 if _hit_kind in ["brise", "elimination"] else 2.5
			for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
				draw_line(c + d * 5.0, c + d * s, k, t)


class Vitals:
	extends Control
	## En bas au centre : plaques dans le sac, armure (3 segments), santé, arme en main et munitions.
	var arsenal: Arsenal

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if arsenal == null:
			return
		var font := ThemeDB.fallback_font
		var s := arsenal.sante
		var bw := 230.0
		var x0 := size.x / 2 - bw / 2 - 70
		var y := 30.0
		# Armure : trois segments.
		var seg := (bw - 8.0) / 3.0
		for k in 3:
			var r := Rect2(x0 + k * (seg + 4.0), y, seg, 10)
			draw_rect(r, Color(0, 0, 0, 0.5))
			var fill := clampf((s.armor - k * Armes.PLAQUE) / Armes.PLAQUE, 0.0, 1.0)
			if fill > 0.0:
				draw_rect(Rect2(r.position, Vector2(r.size.x * fill, r.size.y)), Color(0.35, 0.65, 1.0))
		# Santé.
		var hr := Rect2(x0, y + 14, bw, 12)
		draw_rect(hr, Color(0, 0, 0, 0.5))
		var hp := s.hp / Sante.HP_MAX
		draw_rect(Rect2(hr.position, Vector2(bw * hp, 12)), Color(1, 1, 1) if hp > 0.35 else Color(1, 0.35, 0.3))
		# Plaques dans le sac (et la plaque en cours de pose).
		var px := x0 - 56
		draw_rect(Rect2(px, y - 2, 16, 22), Color(0.35, 0.65, 1.0, 0.9))
		_text(font, Vector2(px + 20, y + 16), "×%d" % arsenal.plates, 18, Color(1, 1, 1))
		var gear := []
		if arsenal.letal_n > 0:
			gear.append("Grenade ×%d" % arsenal.letal_n)
		if arsenal.tactique_n > 0:
			gear.append("Fumigène ×%d" % arsenal.tactique_n)
		if arsenal.gas_mask > 0.0:
			gear.append("Masque %d s" % int(arsenal.gas_mask))
		if not gear.is_empty():
			_text(font, Vector2(x0, y + 46), " · ".join(gear), 14, Color(1, 1, 1, 0.75))
		if arsenal.plate_t > 0.0:
			var pr := Rect2(x0, y - 12, bw * arsenal.plate_t / arsenal.plate_time(), 5)
			draw_rect(pr, Color(0.6, 0.85, 1.0))
		# Arme et munitions.
		var w := arsenal.current()
		var ax := x0 + bw + 22
		if w.is_empty():
			_text(font, Vector2(ax, y + 14), "Mains nues", 18, Color(1, 1, 1, 0.7))
			return
		var a := Armes.info(w.id)
		var col: Color = Armes.RARETES[int(w.rarete)].couleur
		_text(font, Vector2(ax, y + 2), String(a.nom), 16, col)
		var mag := int(w.chargeur)
		var res := int(arsenal.reserve[a.munition])
		var mag_col := Color(1, 1, 1) if mag > Armes.taille_chargeur(w.id, int(w.rarete)) / 4 else Color(1, 0.45, 0.35)
		_text(font, Vector2(ax, y + 30), "%d" % mag, 28, mag_col)
		_text(font, Vector2(ax + 16 + 16 * str(mag).length(), y + 30), "/ %d" % res, 18, Color(1, 1, 1, 0.75))
		if arsenal.reloading:
			_text(font, Vector2(ax, y + 48), "rechargement…", 15, Color(1, 0.9, 0.6))
		var o := arsenal.other()
		if not o.is_empty():
			_text(font, Vector2(ax + 120, y + 48), "↻ %s" % String(Armes.info(o.id).nom), 13, Color(1, 1, 1, 0.55))

	func _text(font: Font, at: Vector2, t: String, fs: int, col: Color) -> void:
		draw_string_outline(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, 0.8))
		draw_string(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
