class_name EcranClasses
extends Control
## Écran des classes du lobby (maquette « Ressac — écrans de classes ») : les 5 classes à
## gauche, l'arme principale en grand au centre (rendu, jauges), l'arme secondaire, les atouts
## et l'équipement à droite. Choisir une arme ou les atouts ouvre une vue dédiée. Manette
## (croix, A, B, X), tactile et souris. Chaque changement est enregistré tout de suite.

signal closed

var _sel := 0
var _view := "liste"              # "liste", "arme", "atouts", "armurier"
var _slot := "principale"         # emplacement en cours de choix
var _preview := ""                # arme regardée dans le choix
var _class_cards: Array[Button] = []
var _center: VBoxContainer
var _right: VBoxContainer
var _detail: VBoxContainer
var _weapon_cards := {}
var _perk_cards := {}
var _body: Control
var _hint: Label
var _first_focus: Control
var _apercu: ApercuArme
var _emp := "bouche"              # emplacement choisi à l'armurier
var _acc_preview: Array = []       # configuration regardée à l'armurier
var _emp_cards := {}
var _opt_box: VBoxContainer
var _arm_stats: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	G.input_mode_changed.connect(func(_m): _update_hint())


func open(k := 0) -> void:
	_sel = clampi(k, 0, Loadouts.SLOTS - 1)
	visible = true
	_show("liste")


func _cls() -> Dictionary:
	return Loadouts.get_one(_sel)


## L'arme d'un emplacement de la classe, avec ses accessoires.
func _arme(d: Dictionary, slot: String) -> Dictionary:
	return Armes.nouvelle(String(d[slot]), Loadouts.RARETE, Loadouts.acc_de(d, slot))


func _save(d: Dictionary) -> void:
	Loadouts.list[_sel] = d
	Loadouts.save_all()


# ------------------------------------------------------------------------------------------------
# Charpente commune : en-tête, corps, pied
# ------------------------------------------------------------------------------------------------
func _show(view: String) -> void:
	_view = view
	for n in get_children():
		remove_child(n)
		n.queue_free()
	_class_cards.clear()
	_weapon_cards.clear()
	_perk_cards.clear()
	_first_focus = null
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 28)
	m.add_theme_constant_override("margin_top", 18)
	m.add_theme_constant_override("margin_bottom", 14)
	add_child(m)
	var col := UIStyle.vbox(m, 12)
	var head := UIStyle.hbox(col, 16)
	var d := _cls()
	match view:
		"liste":
			UIStyle.label(head, "CLASSES", "titre", 34, UIStyle.OR)
			UIStyle.label(head, "récupérées en partie avec un largage de classe", "texte", 17, UIStyle.DOUX).size_flags_vertical = Control.SIZE_SHRINK_END
		"arme":
			UIStyle.label(head, "%d · %s" % [_sel + 1, String(d.nom).to_upper()], "titre2", 22, UIStyle.DOUX)
			UIStyle.label(head, "ARME %s" % ("PRINCIPALE" if _slot == "principale" else "SECONDAIRE"), "titre", 34, UIStyle.TEXTE)
			UIStyle.label(head, "les armes de classe sont toujours légendaires", "texte", 17, UIStyle.DOUX).size_flags_vertical = Control.SIZE_SHRINK_END
		"armurier":
			UIStyle.label(head, "%d · %s" % [_sel + 1, String(d.nom).to_upper()], "titre2", 22, UIStyle.DOUX)
			UIStyle.label(head, "ARMURIER", "titre", 34, UIStyle.TEXTE)
			for slot in ["principale", "secondaire"]:
				var tb := UIStyle.action(head, String(Armes.info(String(d[slot])).nom), slot == _slot, 0)
				tb.add_theme_font_size_override("font_size", 18)
				tb.pressed.connect(_open_armurier.bind(slot))
		"atouts":
			UIStyle.label(head, "%d · %s" % [_sel + 1, String(d.nom).to_upper()], "titre2", 22, UIStyle.DOUX)
			UIStyle.label(head, "ATOUTS", "titre", 34, UIStyle.TEXTE)
			UIStyle.label(head, "un atout par colonne", "texte", 17, UIStyle.DOUX).size_flags_vertical = Control.SIZE_SHRINK_END
	_body = UIStyle.hbox(col, 14)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	match view:
		"liste": _build_liste()
		"arme": _build_arme()
		"atouts": _build_atouts()
		"armurier": _build_armurier()
	var foot := UIStyle.hbox(col, 12)
	_hint = UIStyle.label(foot, "", "texte", 16, Color(0.8, 0.83, 0.86))
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	match view:
		"liste":
			UIStyle.action(foot, "Rétablir la classe d'origine", false, 260).pressed.connect(_reset_class)
			UIStyle.action(foot, "Retour", false, 150).pressed.connect(func(): closed.emit())
		"arme":
			UIStyle.action(foot, "Annuler", false, 150).pressed.connect(func(): _show("liste"))
		"atouts", "armurier":
			UIStyle.action(foot, "Terminé", true, 180).pressed.connect(func(): _show("liste"))
	_update_hint()
	if _first_focus:
		_first_focus.grab_focus.call_deferred()


func _update_hint() -> void:
	if _hint == null or not is_instance_valid(_hint):
		return
	var pad: bool = G.input_mode == "pad"
	var touch: bool = G.input_mode == "touch"
	match _view:
		"liste":
			_hint.text = "Toucher une classe, puis une arme ou un atout pour le changer" if touch else (
				"Croix : naviguer · A : modifier · X : rétablir · B : retour" if pad else "Clic : modifier · Échap : retour")
		"arme":
			_hint.text = "Toucher une arme pour la voir, « Équiper » pour la prendre" if touch else (
				"A : équiper · B : annuler" if pad else "Clic : voir · double clic ou « Équiper » : prendre · Échap : annuler")
		"atouts":
			_hint.text = "Toucher un atout pour le choisir" if touch else ("A : choisir · B : terminé" if pad else "Clic : choisir · Échap : terminé")
		"armurier":
			_hint.text = "Toucher un emplacement, puis un accessoire" if touch else (
				"Croix : emplacement, puis accessoire · A : poser · B : terminé" if pad else "Clic : poser · Échap : terminé")


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and (event as InputEventKey).physical_keycode == KEY_ESCAPE):
		if _view == "liste":
			closed.emit()
		else:
			_show("liste")
		get_viewport().set_input_as_handled()
	elif _view == "liste" and event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_X:
		_reset_class()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------------------------------------
# Liste des classes
# ------------------------------------------------------------------------------------------------
func _build_liste() -> void:
	var left := UIStyle.vbox(_body, 8)
	left.custom_minimum_size = Vector2(320, 0)
	for k in Loadouts.SLOTS:
		var d := Loadouts.get_one(k)
		var b := UIStyle.card(left, Vector2(320, 0), k == _sel)
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var row := UIStyle.hbox(UIStyle.inside(b, 10), 10)
		var num := UIStyle.label(row, str(k + 1), "titre", 32, UIStyle.OR if k == _sel else Color(0.45, 0.5, 0.56))
		num.custom_minimum_size = Vector2(22, 0)
		num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var mid := UIStyle.vbox(row, 4)
		mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		UIStyle.label(mid, String(d.nom).to_upper(), "titre", 21)
		var icons := UIStyle.hbox(mid, 6)
		for a in d.atouts:
			UIStyle.icon(icons, a, 22, UIStyle.OR if k == _sel else UIStyle.DOUX)
		UIStyle.weapon_image(row, d.principale, Vector2(140, 54)).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.focus_entered.connect(_select.bind(k))
		b.pressed.connect(_select.bind(k))
		_class_cards.append(b)
		if k == _sel:
			_first_focus = b
	_center = UIStyle.vbox(_body, 12)
	_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right = UIStyle.vbox(_body, 8)
	_right.custom_minimum_size = Vector2(340, 0)
	_fill_detail()


func _select(k: int) -> void:
	if k == _sel and _center.get_child_count() > 0:
		return
	_sel = k
	for i in _class_cards.size():
		var b := _class_cards[i]
		UIStyle.style_card(b, i == _sel)
		var row := b.get_child(0).get_child(0)
		(row.get_child(0) as Label).add_theme_color_override("font_color", UIStyle.OR if i == _sel else Color(0.45, 0.5, 0.56))
		for ic in row.get_child(1).get_child(1).get_children():
			(ic as TextureRect).modulate = UIStyle.OR if i == _sel else UIStyle.DOUX
	_fill_detail()


func _fill_detail() -> void:
	for c in [_center, _right]:
		for n in c.get_children():
			c.remove_child(n)
			n.queue_free()
	var d := _cls()
	# Arme principale, en grand.
	var prim := UIStyle.card(_center, Vector2(0, 0))
	prim.size_flags_vertical = Control.SIZE_EXPAND_FILL
	prim.pressed.connect(_open_arme.bind("principale"))
	var pv := UIStyle.vbox(UIStyle.inside(prim, 14), 4)
	var top := UIStyle.hbox(pv, 10)
	UIStyle.label(top, "ARME PRINCIPALE", "gras", 13, UIStyle.DOUX)
	var chip := PanelContainer.new()
	var cs := UIStyle.box(UIStyle.LEGENDAIRE, UIStyle.LEGENDAIRE, 0, 4)
	cs.content_margin_top = 1
	cs.content_margin_bottom = 1
	cs.content_margin_left = 7
	cs.content_margin_right = 7
	chip.add_theme_stylebox_override("panel", cs)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.label(chip, "LÉGENDAIRE", "gras", 12, Color(0.08, 0.08, 0.08))
	top.add_child(chip)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(sp)
	UIStyle.label(top, "Changer ›", "gras", 15, UIStyle.OR)
	var a := Armes.info(d.principale)
	var name_row := UIStyle.hbox(pv, 12)
	UIStyle.label(name_row, String(a.nom), "titre", 36)
	UIStyle.label(name_row, "%s · chargeur %d" % [a.type, Armes.chargeur_de(_arme(d, "principale"))], "texte", 15, UIStyle.DOUX).size_flags_vertical = Control.SIZE_SHRINK_END
	_apercu = ApercuArme.new()
	_apercu.custom_minimum_size = Vector2(0, 130)
	_apercu.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pv.add_child(_apercu)
	_apercu.montrer(_arme(d, "principale"))
	_stats_grid(pv, _arme(d, "principale"), {})
	# Accessoires de l'arme principale (vers l'armurier).
	var accb := UIStyle.card(_center, Vector2(0, 64))
	accb.pressed.connect(_open_armurier.bind("principale"))
	var ar := UIStyle.hbox(UIStyle.inside(accb, 10), 8)
	UIStyle.label(ar, "ACCESSOIRES", "gras", 13, UIStyle.DOUX).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var acc := Loadouts.acc_de(d, "principale")
	for e in Accessoires.emplacements(String(d.principale)):
		var cell := UIStyle.vbox(ar, 0)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UIStyle.label(cell, String(Accessoires.NOMS_EMPLACEMENTS[e]).to_upper(), "gras", 11, UIStyle.DOUX)
		var on := Accessoires.sur(acc, e)
		UIStyle.label(cell, String(Accessoires.info(on).nom) if on != "" else "—", "titre", 17, UIStyle.TEXTE if on != "" else UIStyle.DOUX)
	UIStyle.label(ar, "Armurier ›", "gras", 15, UIStyle.OR).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Arme secondaire.
	var sec := UIStyle.card(_center, Vector2(0, 96))
	sec.pressed.connect(_open_arme.bind("secondaire"))
	var sr := UIStyle.hbox(UIStyle.inside(sec, 12), 16)
	UIStyle.weapon_image(sr, d.secondaire, Vector2(200, 74))
	var sv := UIStyle.vbox(sr, 2)
	sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UIStyle.label(sv, "ARME SECONDAIRE", "gras", 13, UIStyle.DOUX)
	var sa := Armes.info(d.secondaire)
	UIStyle.label(sv, String(sa.nom), "titre", 26)
	UIStyle.label(sv, "%s · chargeur %d · %d accessoires" % [sa.type, Armes.chargeur_de(_arme(d, "secondaire")), Loadouts.acc_de(d, "secondaire").size()], "texte", 14, UIStyle.DOUX)
	# Atouts.
	UIStyle.label(_right, "ATOUTS", "gras", 13, UIStyle.DOUX)
	for c in 3:
		var id: String = d.atouts[c]
		var at: Dictionary = Loadouts.ATOUTS[id]
		var pb := UIStyle.card(_right, Vector2(340, 0))
		pb.size_flags_vertical = Control.SIZE_EXPAND_FILL
		pb.pressed.connect(_open_atouts)
		var pr := UIStyle.hbox(UIStyle.inside(pb, 10), 12)
		UIStyle.icon_badge(pr, id, 56).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var pvb := UIStyle.vbox(pr, 2)
		pvb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pvb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		UIStyle.label(pvb, String(at.nom), "titre", 21)
		var desc := UIStyle.label(pvb, String(at.desc), "texte", 14, UIStyle.DOUX)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(240, 0)
	UIStyle.label(_right, "ÉQUIPEMENT", "gras", 13, UIStyle.DOUX)
	var gear := UIStyle.hbox(_right, 8)
	for g in [["grenade", "Létal", "Grenade"], ["fumigene", "Tactique", "Fumigène"]]:
		var p := UIStyle.panel(gear, Vector2(166, 66))
		var gr := UIStyle.hbox(p, 10)
		UIStyle.icon(gr, g[0], 32, Color(0.9, 0.92, 0.94)).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var gv := UIStyle.vbox(gr, 0)
		UIStyle.label(gv, g[1], "texte", 12, UIStyle.DOUX)
		UIStyle.label(gv, g[2], "titre", 19)


## Jauges d'une arme (et, dans le choix, comparées à l'arme équipée `ref`).
func _stats_grid(parent: Node, w: Dictionary, ref: Dictionary, columns := 3) -> void:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 8)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(grid)
	var id: String = w.id
	var s := UIStyle.stats(w)
	var r := UIStyle.stats(ref) if not ref.is_empty() else []
	var same: bool = ref.is_empty() or (ref.id == w.id and ref.get("acc", []) == w.get("acc", []))
	for k in UIStyle.STATS.size():
		var cell := UIStyle.vbox(grid, 3)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row := UIStyle.hbox(cell, 6)
		var nm := UIStyle.label(row, UIStyle.STATS[k], "texte", 14, Color(0.8, 0.83, 0.86))
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var txt := UIStyle.ttk_text(id) if k == 5 else str(int(round(s[k])))
		var color := UIStyle.TEXTE
		if not same:
			var diff := int(round(s[k])) - int(round(r[k]))
			if diff != 0:
				color = UIStyle.MIEUX if diff > 0 else UIStyle.MOINS
				txt += "  %s%d" % ["+" if diff > 0 else "−", absi(diff)]
		UIStyle.label(row, txt, "gras", 14, color)
		var j := UIStyle.Jauge.new()
		j.value = s[k]
		j.color = color
		if not ref.is_empty():
			j.ref = r[k]
		cell.add_child(j)


func _reset_class() -> void:
	_save(Loadouts.DEFAUTS[_sel].duplicate(true))
	_show("liste")


# ------------------------------------------------------------------------------------------------
# Choix d'une arme
# ------------------------------------------------------------------------------------------------
func _open_arme(slot: String) -> void:
	_slot = slot
	_preview = String(_cls()[slot])
	_show("arme")


func _build_arme() -> void:
	var d := _cls()
	var current: String = d[_slot]
	var ids: Array = Loadouts.PRINCIPALES if _slot == "principale" else Loadouts.SECONDAIRES
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(grid)
	for id in ids:
		var a := Armes.info(id)
		var b := UIStyle.card(grid, Vector2(0, 150), id == _preview)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := UIStyle.vbox(UIStyle.inside(b, 10), 2)
		var top := UIStyle.hbox(v, 6)
		var t := UIStyle.label(top, String(a.type).to_upper(), "gras", 12, UIStyle.DOUX)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if id == current:
			UIStyle.label(top, "ÉQUIPÉE", "gras", 12, UIStyle.OR)
		var img := UIStyle.weapon_image(v, id, Vector2(0, 74))
		img.size_flags_vertical = Control.SIZE_EXPAND_FILL
		UIStyle.label(v, String(a.nom).get_slice(" ", String(a.nom).get_slice_count(" ") - 1) if id != "uzi" else "Mini Uzi", "titre", 20)
		b.focus_entered.connect(_preview_weapon.bind(id))
		b.pressed.connect(func():
			if _preview == id:
				_equip(id)
			else:
				_preview_weapon(id))
		_weapon_cards[id] = b
		if id == _preview:
			_first_focus = b
	var side := UIStyle.panel(_body, Vector2(420, 0))
	_detail = UIStyle.vbox(side, 8)
	_fill_weapon_detail()


func _preview_weapon(id: String) -> void:
	_preview = id
	for k in _weapon_cards:
		UIStyle.style_card(_weapon_cards[k], k == id)
	_fill_weapon_detail()


func _fill_weapon_detail() -> void:
	for n in _detail.get_children():
		_detail.remove_child(n)
		n.queue_free()
	var id := _preview
	var a := Armes.info(id)
	var d := _cls()
	var current: String = d[_slot]
	var cand_d := d.duplicate(true)
	cand_d[_slot] = id
	var cand := _arme(cand_d, _slot)
	UIStyle.weapon_image(_detail, id, Vector2(0, 130))
	UIStyle.label(_detail, String(a.nom), "titre", 30)
	UIStyle.label(_detail, "%s · chargeur %d · élimine en %s" % [a.type, Armes.chargeur_de(cand), UIStyle.ttk_text(id)], "texte", 15, UIStyle.DOUX)
	if id != current:
		var leg := UIStyle.hbox(_detail, 14)
		UIStyle.label(leg, "▮ arme équipée", "texte", 13, UIStyle.OR)
		UIStyle.label(leg, "bleu : mieux", "texte", 13, UIStyle.MIEUX)
		UIStyle.label(leg, "orange : moins bien", "texte", 13, UIStyle.MOINS)
	_stats_grid(_detail, cand, _arme(d, _slot), 2)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.add_child(sp)
	var eq := UIStyle.action(_detail, "ÉQUIPÉE" if id == current else "ÉQUIPER", true, 0)
	eq.disabled = id == current
	eq.pressed.connect(_equip.bind(id))


func _equip(id: String) -> void:
	var d := _cls().duplicate(true)
	d[_slot] = id
	_save(d)
	G.play("buy", -10.0)
	_show("liste")


# ------------------------------------------------------------------------------------------------
# Choix des atouts
# ------------------------------------------------------------------------------------------------
func _open_atouts() -> void:
	_show("atouts")


const COLONNES := ["MOBILITÉ ET BUTIN", "SURVIE", "TACTIQUE"]


func _build_atouts() -> void:
	var d := _cls()
	for c in 3:
		var colv := UIStyle.vbox(_body, 10)
		colv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var head := UIStyle.hbox(colv, 10)
		UIStyle.label(head, str(c + 1), "titre", 22, UIStyle.OR)
		UIStyle.label(head, COLONNES[c], "titre", 22)
		for id in Loadouts.column(c):
			var on: bool = d.atouts[c] == id
			var b := UIStyle.card(colv, Vector2(0, 0), on)
			b.size_flags_vertical = Control.SIZE_EXPAND_FILL
			var row := UIStyle.hbox(UIStyle.inside(b, 12), 12)
			UIStyle.icon_badge(row, id, 60, on).size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var v := UIStyle.vbox(row, 4)
			v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			UIStyle.label(v, String(Loadouts.ATOUTS[id].nom), "titre", 23)
			var desc := UIStyle.label(v, String(Loadouts.ATOUTS[id].desc), "texte", 15, Color(0.8, 0.83, 0.86))
			desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc.custom_minimum_size = Vector2(200, 0)
			b.pressed.connect(_pick_perk.bind(c, id))
			_perk_cards[id] = b
			if on and c == 0:
				_first_focus = b


func _pick_perk(c: int, id: String) -> void:
	var d := _cls().duplicate(true)
	d.atouts[c] = id
	_save(d)
	for other in Loadouts.column(c):
		var b: Button = _perk_cards[other]
		UIStyle.style_card(b, other == id)
		var badge := b.get_child(0).get_child(0).get_child(0) as PanelContainer
		var on: bool = other == id
		badge.add_theme_stylebox_override("panel", UIStyle.badge_style(on))
		(badge.get_child(0) as TextureRect).modulate = UIStyle.OR if on else Color(0.8, 0.83, 0.86)


# ------------------------------------------------------------------------------------------------
# Armurier : un accessoire par emplacement, aperçu 3D et jauges comparées en direct
# ------------------------------------------------------------------------------------------------
func _open_armurier(slot: String) -> void:
	_slot = slot
	var arme := String(_cls()[slot])
	var emps := Accessoires.emplacements(arme)
	if not emps.has(_emp):
		_emp = emps[0] if not emps.is_empty() else "bouche"
	_acc_preview = Loadouts.acc_de(_cls(), slot)
	_show("armurier")


func _build_armurier() -> void:
	var d := _cls()
	var arme := String(d[_slot])
	var acc := Loadouts.acc_de(d, _slot)
	# Les emplacements.
	var left := UIStyle.vbox(_body, 8)
	left.custom_minimum_size = Vector2(290, 0)
	_emp_cards.clear()
	for e in Accessoires.EMPLACEMENTS:
		var possible := not Accessoires.choix(arme, e).is_empty()
		var b := UIStyle.card(left, Vector2(290, 0), e == _emp and possible)
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		b.disabled = not possible
		var v := UIStyle.vbox(UIStyle.inside(b, 10), 2)
		v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		UIStyle.label(v, String(Accessoires.NOMS_EMPLACEMENTS[e]).to_upper(), "gras", 12, UIStyle.DOUX)
		var on := Accessoires.sur(acc, e)
		var txt := "Indisponible" if not possible else (String(Accessoires.info(on).nom) if on != "" else "Aucun")
		UIStyle.label(v, txt, "titre", 21, UIStyle.TEXTE if on != "" else UIStyle.DOUX)
		if possible:
			b.focus_entered.connect(_pick_emp.bind(e))
			b.pressed.connect(_pick_emp.bind(e))
			if e == _emp:
				_first_focus = b
		_emp_cards[e] = b
	# Aperçu et jauges.
	var mid := UIStyle.panel(_body)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mv := UIStyle.vbox(mid, 6)
	UIStyle.label(mv, String(Armes.info(arme).nom), "titre", 28)
	_apercu = ApercuArme.new()
	_apercu.custom_minimum_size = Vector2(0, 160)
	_apercu.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mv.add_child(_apercu)
	_arm_stats = UIStyle.vbox(mv, 4)
	# Les accessoires de l'emplacement choisi.
	var right := UIStyle.vbox(_body, 8)
	right.custom_minimum_size = Vector2(330, 0)
	_opt_box = right
	_fill_options()
	_preview_acc(acc)


func _pick_emp(e: String) -> void:
	if e == _emp:
		return
	_emp = e
	for k in _emp_cards:
		UIStyle.style_card(_emp_cards[k], k == e)
	_fill_options()
	_preview_acc(Loadouts.acc_de(_cls(), _slot))


func _fill_options() -> void:
	for n in _opt_box.get_children():
		_opt_box.remove_child(n)
		n.queue_free()
	var d := _cls()
	var arme := String(d[_slot])
	var acc := Loadouts.acc_de(d, _slot)
	var current := Accessoires.sur(acc, _emp)
	UIStyle.label(_opt_box, String(Accessoires.NOMS_EMPLACEMENTS[_emp]).to_upper(), "gras", 13, UIStyle.DOUX)
	var ids := [""] + Accessoires.choix(arme, _emp)
	for id in ids:
		var b := UIStyle.card(_opt_box, Vector2(330, 0), id == current)
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var v := UIStyle.vbox(UIStyle.inside(b, 10), 2)
		v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var row := UIStyle.hbox(v, 8)
		var nm := UIStyle.label(row, "Aucun" if id == "" else String(Accessoires.info(id).nom), "titre", 21)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if id == current:
			UIStyle.label(row, "POSÉ", "gras", 12, UIStyle.OR)
		if id != "":
			var desc := UIStyle.label(v, String(Accessoires.info(id).desc), "texte", 14, UIStyle.DOUX)
			desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc.custom_minimum_size = Vector2(290, 0)
		var with := Accessoires.poser(acc, _emp, id)
		b.focus_entered.connect(_preview_acc.bind(with))
		b.mouse_entered.connect(_preview_acc.bind(with))
		b.pressed.connect(_poser.bind(id))


## Aperçu d'une configuration : modèle 3D et jauges comparées à la configuration posée.
func _preview_acc(acc: Array) -> void:
	_acc_preview = acc
	var d := _cls()
	var w := Armes.nouvelle(String(d[_slot]), Loadouts.RARETE, acc)
	_apercu.montrer(w)
	for n in _arm_stats.get_children():
		_arm_stats.remove_child(n)
		n.queue_free()
	_stats_grid(_arm_stats, w, _arme(d, _slot), 3)


func _poser(id: String) -> void:
	var d := _cls()
	var acc := Accessoires.poser(Loadouts.acc_de(d, _slot), _emp, id)
	_save(Loadouts.avec_acc(d, _slot, acc))
	G.play("mag_in", -10.0)
	var e := _emp
	_show("armurier")
	if _emp_cards.has(e):
		_emp_cards[e].grab_focus.call_deferred()
