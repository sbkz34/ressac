class_name Lobby
extends CanvasLayer
## Le lobby : jouer une partie de Résurgence contre des bots (nombre et difficulté), s'entraîner au
## champ de tir, préparer ses 5 classes (armes, atouts), régler l'affichage. Se joue à la
## manette (croix + A / B), au tactile et à la souris.

signal play
signal training
signal settings

var _root: Control
var _menu: VBoxContainer
var _classes: VBoxContainer
var _editor: VBoxContainer
var _editing := 0
var _pickers := {}
var _first: Button


func _ready() -> void:
	layer = 8
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.05, 0.08, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)
	var title := _label(_root, "RESSAC", 84, Color(1, 0.86, 0.5))
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	title.position = Vector2(70, 40)
	var sub := _label(_root, "Île du Lazaret · Résurgence", 26, Color(1, 1, 1, 0.85))
	sub.position = Vector2(76, 138)
	_menu = _column(Vector2(70, 210))
	_first = _button(_menu, "Jouer — Résurgence", func(): play.emit())
	var bots_btn: Button
	bots_btn = _button(_menu, _bots_text(), func():
		var opts := [0, 7, 15, 23]
		var k := opts.find(int(G.settings.bots))
		G.set_setting("bots", opts[(k + 1) % opts.size()])
		bots_btn.text = _bots_text())
	var lvl_btn: Button
	lvl_btn = _button(_menu, _level_text(), func():
		G.set_setting("difficulte", (int(G.settings.difficulte) + 1) % 3)
		lvl_btn.text = _level_text())
	_button(_menu, "Entraînement (champ de tir)", func(): training.emit())
	_button(_menu, "Classes", _show_classes)
	_button(_menu, "Réglages", func(): settings.emit())
	_button(_menu, "Quitter", func(): get_tree().quit())
	_classes = _column(Vector2(70, 210))
	_editor = _column(Vector2(70, 190))
	_classes.visible = false
	_editor.visible = false


func _bots_text() -> String:
	var n := int(G.settings.bots)
	return "Adversaires : %s" % ("aucun (seul contre la Brume)" if n == 0 else "%d bots" % n)


func _level_text() -> String:
	return "Difficulté des bots : %s" % ["facile", "normale", "difficile"][clampi(int(G.settings.difficulte), 0, 2)]


func show_menu() -> void:
	visible = true
	_menu.visible = true
	_classes.visible = false
	_editor.visible = false
	_first.grab_focus.call_deferred()


func _label(parent: Control, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 8)
	parent.add_child(l)
	return l


func _column(at: Vector2) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.position = at
	v.custom_minimum_size = Vector2(480, 0)
	v.add_theme_constant_override("separation", 10)
	_root.add_child(v)
	return v


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 24)
	b.custom_minimum_size = Vector2(480, 54)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		if _editor.visible:
			_show_classes()
		elif _classes.visible:
			show_menu()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------------------------------------
# Classes
# ------------------------------------------------------------------------------------------------
func _clear(c: Control) -> void:
	for n in c.get_children():
		c.remove_child(n)
		n.queue_free()


func _show_classes() -> void:
	_menu.visible = false
	_editor.visible = false
	_classes.visible = true
	_clear(_classes)
	_label(_classes, "CLASSES — récupérées en partie avec un largage", 24, Color(1, 0.86, 0.5))
	var first: Button = null
	for k in Loadouts.SLOTS:
		var d := Loadouts.get_one(k)
		var b := _button(_classes, "%s\n%s" % [d.nom, Loadouts.summary(d)], _edit.bind(k))
		b.custom_minimum_size = Vector2(620, 92)
		b.add_theme_font_size_override("font_size", 18)
		if first == null:
			first = b
	_button(_classes, "Retour", show_menu)
	first.grab_focus.call_deferred()


func _edit(k: int) -> void:
	_editing = k
	_classes.visible = false
	_editor.visible = true
	_clear(_editor)
	_pickers.clear()
	var d := Loadouts.get_one(k)
	_label(_editor, "Classe %d — %s" % [k + 1, d.nom], 26, Color(1, 0.86, 0.5))
	_picker("principale", "Arme principale", Loadouts.PRINCIPALES, d.principale, func(id): return Armes.info(id).nom)
	_picker("secondaire", "Arme secondaire", Loadouts.SECONDAIRES, d.secondaire, func(id): return Armes.info(id).nom)
	for col in 3:
		_picker("atout%d" % col, "Atout %d" % (col + 1), Loadouts.column(col), d.atouts[col],
			func(id): return "%s — %s" % [Loadouts.ATOUTS[id].nom, Loadouts.ATOUTS[id].desc])
	_label(_editor, "Létal : grenade · Tactique : fumigène", 18, Color(1, 1, 1, 0.75))
	var save := _button(_editor, "Enregistrer", _save)
	_button(_editor, "Annuler", _show_classes)
	(_pickers["principale"] as OptionButton).grab_focus.call_deferred()
	save.custom_minimum_size = Vector2(480, 50)


func _picker(key: String, title: String, ids: Array, current: String, name_of: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var l := _label(row, title, 20, Color(1, 1, 1))
	l.custom_minimum_size = Vector2(190, 0)
	var o := OptionButton.new()
	o.add_theme_font_size_override("font_size", 18)
	o.custom_minimum_size = Vector2(560, 46)
	for i in ids.size():
		o.add_item(String(name_of.call(ids[i])), i)
		o.set_item_metadata(i, ids[i])
		if ids[i] == current:
			o.select(i)
	row.add_child(o)
	_editor.add_child(row)
	_pickers[key] = o


func _save() -> void:
	var d := Loadouts.get_one(_editing).duplicate(true)
	var pick := func(key: String) -> String:
		var o: OptionButton = _pickers[key]
		return String(o.get_item_metadata(o.selected))
	d.principale = pick.call("principale")
	d.secondaire = pick.call("secondaire")
	d.atouts = [pick.call("atout0"), pick.call("atout1"), pick.call("atout2")]
	Loadouts.list[_editing] = d
	Loadouts.save_all()
	G.play("buy", -6.0)
	_show_classes()
