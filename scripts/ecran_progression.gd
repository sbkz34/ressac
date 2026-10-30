class_name EcranProgression
extends Control
## Écran « Progression » du lobby : niveau et expérience en tête, puis trois onglets — Défis
## (paliers et avancement), Camouflages (arme par arme, aperçu 3D) et Statistiques.
## Manette : LB / RB change d'onglet, B revient.

signal closed

const ONGLETS := ["defis", "camos", "stats"]
const TITRES := {"defis": "DÉFIS", "camos": "CAMOUFLAGES", "stats": "STATISTIQUES"}
const ARMES := ["p9", "taureau", "vipere", "ouragan", "uzi", "faucon", "titan", "k14", "aiguille", "grele"]

var _tab := "defis"
var _arme := "faucon"
var _content: Control
var _first: Control
var _apercu: ApercuArme
var _camo_box: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false


func open(tab := "") -> void:
	if tab != "":
		_tab = tab
	visible = true
	_build()


func _build() -> void:
	for n in get_children():
		remove_child(n)
		n.queue_free()
	_apercu = null
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.05, 0.08, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 28)
	m.add_theme_constant_override("margin_top", 16)
	m.add_theme_constant_override("margin_bottom", 14)
	add_child(m)
	var col := UIStyle.vbox(m, 10)
	# En tête : niveau, barre d'expérience, onglets.
	var head := UIStyle.hbox(col, 18)
	UIStyle.label(head, "PROGRESSION", "titre", 34, UIStyle.OR)
	var nv := Progression.niveau_de(int(Progression._d().xp))
	var lvl := UIStyle.vbox(head, 2)
	lvl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lvl.size_flags_vertical = Control.SIZE_SHRINK_END
	var lt := UIStyle.label(lvl, "NIVEAU %d   ·   %s / %s XP" % [int(nv[0]), Progression._nombre(int(nv[1])), Progression._nombre(int(nv[2]))], "gras", 18)
	if int(nv[0]) >= Progression.NIVEAU_MAX:
		lt.text = "NIVEAU %d (maximum)" % int(nv[0])
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	bar.max_value = float(nv[2])
	bar.value = float(nv[1])
	var fill := StyleBoxFlat.new()
	fill.bg_color = UIStyle.OR
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.12)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)
	lvl.add_child(bar)
	var tabs := UIStyle.hbox(col, 8)
	for t in ONGLETS:
		var b := UIStyle.card(tabs, Vector2(230, 50), t == _tab)
		var l := UIStyle.label(UIStyle.inside(b, 10), TITRES[t], "titre", 22)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b.pressed.connect(_switch.bind(t))
	var hint := UIStyle.label(tabs, "LB / RB : onglet", "texte", 14, UIStyle.DOUX)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var body := Control.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	_content = body
	_first = null
	match _tab:
		"defis": _defis(body)
		"camos": _camos(body)
		"stats": _stats(body)
	var foot := UIStyle.hbox(col, 12)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(sp)
	var back := UIStyle.action(foot, "Retour", true, 180)
	back.pressed.connect(_close)
	if _first == null:
		_first = back
	_first.grab_focus.call_deferred()


func _switch(t: String) -> void:
	_tab = t
	_build()


func _close() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventJoypadButton and event.pressed:
		var bi := (event as InputEventJoypadButton).button_index
		if bi == JOY_BUTTON_LEFT_SHOULDER or bi == JOY_BUTTON_RIGHT_SHOULDER:
			var k := ONGLETS.find(_tab)
			_switch(ONGLETS[(k + (1 if bi == JOY_BUTTON_RIGHT_SHOULDER else -1) + ONGLETS.size()) % ONGLETS.size()])
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and (event as InputEventKey).physical_keycode == KEY_ESCAPE):
		_close()
		get_viewport().set_input_as_handled()


func _full(parent: Control, n: Control) -> void:
	n.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(n)


# ------------------------------------------------------------------------------------------------
# Défis
# ------------------------------------------------------------------------------------------------
func _defis(body: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_full(body, scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for df in Progression.DEFIS:
		var o := Progression.objectif(df)
		var done: bool = o[1]
		var target := int(o[0])
		var have := Progression.stat(String(df.stat))
		var p := Progression.palier(df)
		var b := UIStyle.card(grid, Vector2(560, 92), done)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := UIStyle.vbox(UIStyle.inside(b, 12), 4)
		var top := UIStyle.hbox(v, 10)
		var name := UIStyle.label(top, Progression.texte_defi(df), "gras", 19)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.clip_text = true
		UIStyle.label(top, "TERMINÉ" if done else "+%s XP" % Progression._nombre(int(df.xp[mini(p, df.xp.size() - 1)])), "gras", 16,
			UIStyle.OR if not done else Color(0.55, 0.9, 1.0))
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 8)
		bar.max_value = float(target)
		bar.value = minf(have, float(target))
		var fill := StyleBoxFlat.new()
		fill.bg_color = UIStyle.OR if not done else Color(0.55, 0.9, 1.0)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(1, 1, 1, 0.12)
		bar.add_theme_stylebox_override("fill", fill)
		bar.add_theme_stylebox_override("background", bg)
		v.add_child(bar)
		UIStyle.label(v, "%s / %s   ·   palier %d / %d" % [Progression._nombre(int(minf(have, target))), Progression._nombre(target),
			mini(p + (0 if done else 1), df.paliers.size()), df.paliers.size()], "texte", 14, UIStyle.DOUX)
		if _first == null:
			_first = b


# ------------------------------------------------------------------------------------------------
# Camouflages
# ------------------------------------------------------------------------------------------------
func _camos(body: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_full(body, row)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.custom_minimum_size = Vector2(380, 0)
	row.add_child(scroll)
	var list := UIStyle.vbox(scroll, 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id in ARMES:
		var b := UIStyle.card(list, Vector2(360, 56), id == _arme)
		var h := UIStyle.hbox(UIStyle.inside(b, 10), 10)
		var n := UIStyle.label(h, Armes.info(id).nom, "gras", 18)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.clip_text = true
		var c := Progression.camo(id)
		UIStyle.label(h, "%d élim.%s" % [Progression.elim_arme(id), "  ·  " + Progression.camo_nom(c) if c != "" else ""], "texte", 15, UIStyle.DOUX)
		b.pressed.connect(_pick_arme.bind(id))
		b.focus_entered.connect(_preview.bind(id, ""))
		if id == _arme:
			_first = b
	var right := UIStyle.vbox(row, 10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pv := UIStyle.panel(right)
	pv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_apercu = ApercuArme.new()
	_apercu.custom_minimum_size = Vector2(0, 200)
	pv.add_child(_apercu)
	_camo_box = UIStyle.hbox(right, 8)
	_fill_camos()
	_preview(_arme, "")


func _pick_arme(id: String) -> void:
	_arme = id
	_build()


func _fill_camos() -> void:
	for n in _camo_box.get_children():
		n.queue_free()
	var cur := Progression.camo(_arme)
	var have := Progression.elim_arme(_arme)
	for c in Progression.CAMOS:
		var ok := have >= int(c.elim)
		var b := UIStyle.card(_camo_box, Vector2(118, 96), c.id == cur)
		b.disabled = not ok
		var v := UIStyle.vbox(UIStyle.inside(b, 8), 4)
		var sw := ColorRect.new()
		sw.custom_minimum_size = Vector2(0, 30)
		sw.color = _swatch(String(c.id))
		if not ok:
			sw.color = sw.color.darkened(0.6)
		v.add_child(sw)
		UIStyle.label(v, String(c.nom), "gras", 16, UIStyle.TEXTE if ok else UIStyle.DOUX).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIStyle.label(v, "équipé" if c.id == cur else ("disponible" if ok else "%d élim." % int(c.elim)), "texte", 13,
			UIStyle.OR if c.id == cur else UIStyle.DOUX).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.focus_entered.connect(_preview.bind(_arme, String(c.id)))
		b.mouse_entered.connect(_preview.bind(_arme, String(c.id)))
		b.pressed.connect(func():
			Progression.choisir_camo(_arme, String(c.id))
			_build())


func _swatch(c: String) -> Color:
	if c == "":
		return Color(0.3, 0.31, 0.33)
	if c == "or":
		return Color(0.95, 0.74, 0.3)
	return (Armes.CAMO_TEINTES[c][0] as Color)


func _preview(id: String, c: String) -> void:
	if _apercu == null:
		return
	var w := {"id": id, "acc": Accessoires.defaut(id), "camo": c if c != "" else Progression.camo(id)}
	_apercu.montrer(w)


# ------------------------------------------------------------------------------------------------
# Statistiques
# ------------------------------------------------------------------------------------------------
func _stats(body: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_full(body, scroll)
	var v := UIStyle.vbox(scroll, 12)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	var s := func(k: String) -> float: return Progression.stat(k)
	var elim: float = s.call("eliminations")
	var morts: float = s.call("morts")
	var tirs: float = s.call("tirs")
	var touches: float = s.call("touches")
	var t := int(s.call("temps"))
	var tiles := [
		["Parties", Progression._nombre(int(s.call("parties")))],
		["Victoires", Progression._nombre(int(s.call("victoires")))],
		["Top 5", Progression._nombre(int(s.call("top5")))],
		["Éliminations", Progression._nombre(int(elim))],
		["Ratio élim. / morts", ("%.2f" % (elim / maxf(morts, 1.0))).replace(".", ",")],
		["Précision", "%d %%" % int(round(100.0 * touches / maxf(tirs, 1.0)))],
		["Tirs à la tête", "%d %%" % int(round(100.0 * s.call("tetes") / maxf(touches, 1.0)))],
		["Dégâts infligés", Progression._nombre(int(s.call("degats")))],
		["Meilleure série", Progression._nombre(int(s.call("meilleure_serie")))],
		["Temps de jeu", "%d h %02d" % [t / 3600, (t / 60) % 60]],
		["Contrats remplis", Progression._nombre(int(s.call("contrats")))],
		["Coffres ouverts", Progression._nombre(int(s.call("coffres")))],
		["Tyroliennes", Progression._nombre(int(s.call("tyroliennes")))],
		["Élim. explosives", Progression._nombre(int(s.call("elim_explosif")))],
		["Morts", Progression._nombre(int(morts))],
	]
	for tile in tiles:
		var p := UIStyle.panel(grid, Vector2(228, 0))
		var tv := UIStyle.vbox(p, 0)
		UIStyle.label(tv, String(tile[1]), "titre", 30, UIStyle.TEXTE)
		UIStyle.label(tv, String(tile[0]), "texte", 14, UIStyle.DOUX)
	# Armes favorites.
	var favs := []
	for id in ARMES:
		if Progression.elim_arme(id) > 0:
			favs.append([Progression.elim_arme(id), id])
	favs.sort()
	favs.reverse()
	if not favs.is_empty():
		UIStyle.label(v, "ARMES FAVORITES", "titre", 20, UIStyle.OR)
		var hr := UIStyle.hbox(v, 10)
		for k in mini(3, favs.size()):
			var p := UIStyle.panel(hr, Vector2(380, 0))
			var h := UIStyle.hbox(p, 10)
			UIStyle.weapon_image(h, String(favs[k][1]), Vector2(150, 56))
			var tv := UIStyle.vbox(h, 0)
			UIStyle.label(tv, Armes.info(String(favs[k][1])).nom, "gras", 17)
			UIStyle.label(tv, "%d éliminations" % int(favs[k][0]), "texte", 15, UIStyle.DOUX)
