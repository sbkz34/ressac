class_name LargageUI
extends Control
## Choix de la classe à l'ouverture d'un largage, en partie : 5 cartes en bandeau bas (le haut
## de l'écran reste dégagé, la partie continue derrière). Croix gauche / droite et A, ou toucher
## une carte.

signal picked(k: int)
signal closed

var cards: Array[Button] = []
var _focus := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func build() -> void:
	for n in get_children():
		remove_child(n)
		n.queue_free()
	cards.clear()
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.05, 0.08, 0.82)
	shade.anchor_left = 0.0
	shade.anchor_right = 1.0
	shade.anchor_top = 0.42
	shade.anchor_bottom = 1.0
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var m := MarginContainer.new()
	m.anchor_left = 0.0
	m.anchor_right = 1.0
	m.anchor_top = 0.42
	m.anchor_bottom = 1.0
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 26)
	m.add_theme_constant_override("margin_top", 12)
	m.add_theme_constant_override("margin_bottom", 14)
	add_child(m)
	var col := UIStyle.vbox(m, 10)
	var head := UIStyle.hbox(col, 16)
	UIStyle.label(head, "LARGAGE DE CLASSE", "titre", 32, UIStyle.OR)
	UIStyle.label(head, "la partie continue derrière : restez à couvert", "texte", 16, Color(0.8, 0.83, 0.86)).size_flags_vertical = Control.SIZE_SHRINK_END
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(sp)
	var close := UIStyle.action(head, "Fermer", false, 130)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func(): closed.emit())
	var row := UIStyle.hbox(col, 12)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for k in Loadouts.SLOTS:
		var d := Loadouts.get_one(k)
		var b := UIStyle.card(row, Vector2(0, 0), k == 0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := UIStyle.vbox(UIStyle.inside(b, 12), 4)
		var top := UIStyle.hbox(v, 8)
		UIStyle.label(top, str(k + 1), "titre", 24, UIStyle.OR)
		UIStyle.label(top, String(d.nom).to_upper(), "titre", 22)
		var img := UIStyle.weapon_image(v, d.principale, Vector2(0, 70))
		img.size_flags_vertical = Control.SIZE_EXPAND_FILL
		UIStyle.label(v, String(Armes.info(d.principale).nom), "gras", 14)
		UIStyle.label(v, "+ " + String(Armes.info(d.secondaire).nom), "texte", 13, UIStyle.DOUX)
		var icons := UIStyle.hbox(v, 6)
		for a in d.atouts:
			UIStyle.icon(icons, a, 22, UIStyle.OR)
		b.focus_entered.connect(_on_focus.bind(k))
		b.pressed.connect(_on_press.bind(k))
		cards.append(b)
	_focus = 0
	cards[0].grab_focus.call_deferred()


func _on_focus(k: int) -> void:
	_focus = k
	for i in cards.size():
		UIStyle.style_card(cards[i], i == k)


## A (ou un toucher) prend la classe.
func _on_press(k: int) -> void:
	picked.emit(k)
