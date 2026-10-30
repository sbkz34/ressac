class_name EcranReglages
extends Control
## Écran des réglages (lobby et pause) : quatre onglets, Affichage, Commandes, Son, Jeu.
## Chaque réglage s'applique et s'enregistre tout de suite. Manette : LB / RB change d'onglet,
## croix haut / bas choisit un réglage, gauche / droite change sa valeur, B revient.

signal closed
signal open_binds              # écran « Touches » (dans le HUD)
signal open_touch_layout       # disposition des commandes tactiles

const ONGLETS := ["affichage", "commandes", "son", "jeu"]
const TITRES := {"affichage": "AFFICHAGE", "commandes": "COMMANDES", "son": "SON", "jeu": "JEU"}

var _tab := "affichage"
var _tabs := {}
var _content: VBoxContainer
var _first: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS


func open(tab := "") -> void:
	if tab != "":
		_tab = tab
	visible = true
	_build()


func _build() -> void:
	for n in get_children():
		remove_child(n)
		n.queue_free()
	_tabs.clear()
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.05, 0.08, 0.86)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 28)
	m.add_theme_constant_override("margin_top", 18)
	m.add_theme_constant_override("margin_bottom", 14)
	add_child(m)
	var col := UIStyle.vbox(m, 12)
	var head := UIStyle.hbox(col, 16)
	UIStyle.label(head, "RÉGLAGES", "titre", 34, UIStyle.OR)
	UIStyle.label(head, "appliqués et enregistrés tout de suite", "texte", 17, UIStyle.DOUX).size_flags_vertical = Control.SIZE_SHRINK_END
	var body := UIStyle.hbox(col, 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var nav := UIStyle.vbox(body, 8)
	nav.custom_minimum_size = Vector2(240, 0)
	for t in ONGLETS:
		var b := UIStyle.card(nav, Vector2(240, 60), t == _tab)
		var l := UIStyle.label(UIStyle.inside(b, 14), TITRES[t], "titre", 24)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b.pressed.connect(_switch.bind(t))
		_tabs[t] = b
	var hint := UIStyle.label(nav, "LB / RB : onglet\nhaut / bas : réglage\ngauche / droite : valeur", "texte", 14, UIStyle.DOUX)
	hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hint.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	var panel := UIStyle.panel(body)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	panel.add_child(scroll)
	_content = UIStyle.vbox(scroll, 2)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_first = null
	match _tab:
		"affichage": _affichage()
		"commandes": _commandes()
		"son": _son()
		"jeu": _jeu()
	var foot := UIStyle.hbox(col, 12)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(sp)
	UIStyle.action(foot, "Retour", true, 180).pressed.connect(func():
		visible = false
		closed.emit())
	if _first:
		_first.grab_focus.call_deferred()


func _switch(t: String) -> void:
	_tab = t
	_build()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var k := ONGLETS.find(_tab)
	if event is InputEventJoypadButton and event.pressed:
		var bi := (event as InputEventJoypadButton).button_index
		if bi == JOY_BUTTON_LEFT_SHOULDER or bi == JOY_BUTTON_RIGHT_SHOULDER:
			_switch(ONGLETS[(k + (1 if bi == JOY_BUTTON_RIGHT_SHOULDER else -1) + ONGLETS.size()) % ONGLETS.size()])
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and (event as InputEventKey).physical_keycode == KEY_ESCAPE):
		visible = false
		closed.emit()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------------------------------------
# Lignes de réglage
# ------------------------------------------------------------------------------------------------
func _row(label: String, aide: String) -> HBoxContainer:
	var row := UIStyle.hbox(_content, 18)
	row.custom_minimum_size = Vector2(0, 64)
	var v := UIStyle.vbox(row, 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UIStyle.label(v, label, "gras", 18)
	if aide != "":
		UIStyle.label(v, aide, "texte", 14, UIStyle.DOUX)
	return row


func _slider(label: String, aide: String, key: String, lo: float, hi: float, step: float, fmt: Callable) -> HSlider:
	var row := _row(label, aide)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(G.settings[key])
	s.custom_minimum_size = Vector2(300, 36)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var grab := StyleBoxFlat.new()
	grab.bg_color = UIStyle.OR
	s.add_theme_stylebox_override("grabber_area", grab)
	s.add_theme_stylebox_override("grabber_area_highlight", grab)
	row.add_child(s)
	var val := UIStyle.label(row, fmt.call(s.value), "gras", 17)
	val.custom_minimum_size = Vector2(70, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value_changed.connect(func(v: float):
		val.text = fmt.call(v)
		G.set_setting(key, v))
	if _first == null:
		_first = s
	return s


## Choix parmi quelques valeurs : bouton « ‹ valeur › » (A ou gauche / droite pour changer).
func _choice(label: String, aide: String, key: String, values: Array, names: Array) -> Button:
	var row := _row(label, aide)
	var b := UIStyle.action(row, "", false, 300)
	b.add_theme_font_override("font", UIStyle.font("gras"))
	b.add_theme_font_size_override("font_size", 18)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var show := func() -> void:
		var i := values.find(G.settings[key])
		b.text = "‹  %s  ›" % names[maxi(i, 0)]
	show.call()
	var step := func(dir: int) -> void:
		var i := values.find(G.settings[key])
		G.set_setting(key, values[(maxi(i, 0) + dir + values.size()) % values.size()])
		show.call()
	b.pressed.connect(step.bind(1))
	b.gui_input.connect(func(e: InputEvent):
		if e.is_action_pressed("ui_right"):
			step.call(1)
			b.accept_event()
		elif e.is_action_pressed("ui_left"):
			step.call(-1)
			b.accept_event())
	if _first == null:
		_first = b
	return b


func _link(label: String, aide: String, text: String, cb: Callable) -> void:
	var row := _row(label, aide)
	var b := UIStyle.action(row, text, false, 300)
	b.add_theme_font_size_override("font_size", 18)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(cb)
	if _first == null:
		_first = b


static func _pct(v: float) -> String:
	return "%d %%" % int(round(v * 100.0))


static func _x(v: float) -> String:
	return ("%.2f" % v).replace(".", ",")


# ------------------------------------------------------------------------------------------------
# Onglets
# ------------------------------------------------------------------------------------------------
func _affichage() -> void:
	_slider("Taille de l'interface", "Tous les éléments à l'écran grandissent ou rapetissent.", "hud_scale", 0.6, 1.5, 0.05, _pct)
	_slider("Marge des bords", "Écarte l'interface des bords et de l'encoche.", "hud_margin", 0.0, 0.1, 0.005, _pct)
	_choice("Qualité graphique", "Résolution du rendu 3D et ombres (l'interface reste nette).", "qualite", [0, 1, 2],
		["Performance (60 %)", "Équilibrée (75 %)", "Qualité (100 %)"])
	_choice("Images par seconde", "Compteur à côté de la mini-carte.", "show_fps", [true, false], ["Affichées", "Masquées"])
	_choice("Mesures de performances", "Temps de calcul (processeur, carte graphique), appels de dessin, triangles.", "mesures", [false, true], ["Masquées", "Affichées"])
	_choice("Mini-carte", "Elle tourne avec la vue, ou le nord reste en haut.", "minicarte_nord", [false, true], ["Tourne avec la vue", "Nord en haut"])


func _commandes() -> void:
	_slider("Sensibilité manette", "Vitesse de rotation au stick droit.", "sens_pad", 0.3, 2.5, 0.05, _x)
	_choice("Courbe de réponse (manette)", "Dynamique : précise au centre, rapide au bord. Linéaire : proportionnelle au stick.", "courbe",
		["dynamique", "standard", "lineaire"], ["Dynamique", "Standard (lente au centre)", "Linéaire"])
	_slider("Zone morte du stick droit", "La plus petite possible sans que la vue dérive toute seule.", "zone_morte", 0.0, 0.25, 0.01, _pct)
	_slider("Sensibilité verticale", "Par rapport à l'horizontale.", "sens_vert", 0.5, 1.5, 0.05, _x)
	_choice("Accélération en bout de course", "Stick poussé à fond : la vue tourne de plus en plus vite (pour les demi-tours).", "accel_pad",
		[true, false], ["Oui", "Non"])
	_choice("Vibrations de la manette", "Tirs, touches, éliminations, dégâts reçus, réceptions.", "vibrations", [true, false], ["Oui", "Non"])
	_slider("Sensibilité en visant", "Par rapport à la sensibilité normale.", "sens_ads", 0.3, 1.0, 0.05, _x)
	_slider("Sensibilité tactile", "Glisser à droite de l'écran.", "sens_touch", 0.3, 2.5, 0.05, _x)
	_slider("Sensibilité souris", "", "sens_mouse", 0.3, 2.5, 0.05, _x)
	_choice("Viser (manette, clavier)", "Maintenir la gâchette, ou appuyer une fois.", "visee_bascule", [false, true], ["Maintenir", "Appuyer une fois"])
	_choice("Assistance à la visée", "Manette et tactile.", "assistance", [0, 1, 2], ["Désactivée", "Normale", "Forte"])
	_choice("Inverser l'axe vertical", "", "inverser_y", [false, true], ["Non", "Oui"])
	_link("Touches", "Changer les touches de la manette et du clavier.", "Changer les touches", func(): open_binds.emit())
	_link("Disposition tactile", "Déplacer les boutons, régler leur taille et leur opacité.", "Modifier la disposition", func(): open_touch_layout.emit())


func _son() -> void:
	_slider("Volume général", "", "vol_general", 0.0, 1.0, 0.05, _pct)
	_slider("Tirs et explosions", "Les vôtres et ceux des autres.", "vol_armes", 0.0, 1.0, 0.05, _pct)
	_slider("Pas et mouvements", "Pour entendre venir les autres.", "vol_pas", 0.0, 1.0, 0.05, _pct)
	_slider("Interface et marqueurs", "Marqueurs de touche, achats, battements de cœur.", "vol_ui", 0.0, 1.0, 0.05, _pct)
	_slider("Ambiance", "Vent, avion, parachute.", "vol_ambiance", 0.0, 1.0, 0.05, _pct)


func _jeu() -> void:
	_choice("Adversaires", "Nombre de bots dans une partie.", "bots", [0, 7, 15, 23], ["Aucun", "7 bots", "15 bots", "23 bots"])
	_choice("Difficulté des bots", "", "difficulte", [0, 1, 2], ["Facile", "Normale", "Difficile"])
	_choice("Sprint automatique", "Courir dès que le stick est poussé à fond.", "sprint_auto", [false, true], ["Non", "Oui"])
	_choice("Plaques d'armure", "En maintenant : toutes d'affilée, ou une par appui.", "plaques_toutes", [true, false], ["Toutes d'affilée", "Une par appui"])
