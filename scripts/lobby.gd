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
var ecran_classes: EcranClasses
var _title: Label
var _sub: Label
var _first: Button
var bots_button: Button
var level_button: Button


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
	_title = _label(_root, "RESSAC", 84, Color(1, 0.86, 0.5))
	_title.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_title.position = Vector2(70, 40)
	_sub = _label(_root, "Île du Lazaret · Résurgence", 26, Color(1, 1, 1, 0.85))
	_sub.position = Vector2(76, 138)
	_menu = _column(Vector2(70, 210))
	_first = _button(_menu, "Jouer — Résurgence", func(): play.emit())
	# (Les boutons sont des membres : une fonction anonyme copie les variables locales au
	# moment où elle est créée, avant que le bouton existe.)
	bots_button = _button(_menu, _bots_text(), _next_bots)
	level_button = _button(_menu, _level_text(), _next_level)
	_button(_menu, "Entraînement (champ de tir)", func(): training.emit())
	_button(_menu, "Classes", _show_classes)
	_button(_menu, "Réglages", func(): settings.emit())
	_button(_menu, "Quitter", func(): get_tree().quit())
	ecran_classes = EcranClasses.new()
	_root.add_child(ecran_classes)
	ecran_classes.closed.connect(show_menu)


func _next_bots() -> void:
	var opts := [0, 7, 15, 23]
	var k := opts.find(int(G.settings.bots))
	G.set_setting("bots", opts[(k + 1) % opts.size()])
	bots_button.text = _bots_text()


func _next_level() -> void:
	G.set_setting("difficulte", (int(G.settings.difficulte) + 1) % 3)
	level_button.text = _level_text()


func _bots_text() -> String:
	var n := int(G.settings.bots)
	return "Adversaires : %s" % ("aucun (seul contre la Brume)" if n == 0 else "%d bots" % n)


func _level_text() -> String:
	return "Difficulté des bots : %s" % ["facile", "normale", "difficile"][clampi(int(G.settings.difficulte), 0, 2)]


func show_menu() -> void:
	visible = true
	_menu.visible = true
	_title.visible = true
	_sub.visible = true
	ecran_classes.visible = false
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


# ------------------------------------------------------------------------------------------------
# Classes (écran dédié : ecran_classes.gd)
# ------------------------------------------------------------------------------------------------
func _show_classes(k := 0) -> void:
	_menu.visible = false
	_title.visible = false
	_sub.visible = false
	ecran_classes.open(k)


## Ouvre directement le choix de l'arme principale d'une classe (captures).
func _edit(k: int) -> void:
	_show_classes(k)
	ecran_classes._open_arme("principale")
