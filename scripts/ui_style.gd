class_name UIStyle
extends RefCounted
## Style commun des menus (lobby, classes, largage) : polices Barlow, couleurs, panneaux,
## boutons (le focus de la manette se voit), jauges segmentées, images des armes et icônes.

const OR := Color(1.0, 0.84, 0.42)            # accent (sélection, titres)
const LEGENDAIRE := Color(1.0, 0.72, 0.15)
const TEXTE := Color(0.95, 0.94, 0.92)
const DOUX := Color(0.66, 0.70, 0.74)         # texte secondaire (contraste suffisant sur fond sombre)
const FOND := Color(0.047, 0.086, 0.125, 0.9)
const BORD := Color(1, 1, 1, 0.12)
const MIEUX := Color(0.5, 0.72, 1.0)          # comparaison : bleu = mieux, orange = moins bien
const MOINS := Color(1.0, 0.63, 0.35)

static var _fonts := {}
static var _tex := {}


static func font(kind: String) -> Font:
	if not _fonts.has(kind):
		var path: String = {"titre": "res://assets/fonts/barlow_condensed_700.woff2",
			"titre2": "res://assets/fonts/barlow_condensed_600.woff2",
			"texte": "res://assets/fonts/barlow_500.woff2",
			"gras": "res://assets/fonts/barlow_600.woff2"}.get(kind, "")
		_fonts[kind] = load(path) if path != "" and ResourceLoader.exists(path) else ThemeDB.fallback_font
	return _fonts[kind]


static func label(parent: Node, text: String, kind := "texte", size := 16, color := TEXTE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(kind))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent:
		parent.add_child(l)
	return l


static func box(bg: Color, border: Color, width := 1, radius := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


static func panel(parent: Node, min_size := Vector2.ZERO) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(FOND, BORD))
	p.custom_minimum_size = min_size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent:
		parent.add_child(p)
	return p


## Bouton-carte : fond sombre, bord doré quand il est choisi ou qu'il a le focus (manette).
static func card(parent: Node, min_size: Vector2, selected := false) -> Button:
	var b := Button.new()
	b.custom_minimum_size = min_size
	b.clip_contents = true
	style_card(b, selected)
	if parent:
		parent.add_child(b)
	return b


static func style_card(b: Button, selected: bool) -> void:
	# Choisie : fond sombre teinté d'or (opaque : le décor ne délave pas la carte).
	var normal := box(Color(0.17, 0.15, 0.09, 0.96) if selected else FOND, OR if selected else Color(1, 1, 1, 0.1), 2)
	var hover := box(Color(0.21, 0.18, 0.1, 0.97) if selected else Color(0.09, 0.15, 0.21, 0.94), OR if selected else Color(1, 1, 1, 0.3), 2)
	var focus := box(Color(0, 0, 0, 0), Color(1, 1, 1, 0.95), 3)
	focus.draw_center = false
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("hover_pressed", hover)
	b.add_theme_stylebox_override("focus", focus)
	b.add_theme_stylebox_override("disabled", normal)


## Bouton d'action (Équiper, Retour…) : plein doré ou contour.
static func action(parent: Node, text: String, primary := true, min_w := 200.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 48)
	b.add_theme_font_override("font", font("titre"))
	b.add_theme_font_size_override("font_size", 22)
	var fg := Color(0.08, 0.08, 0.08) if primary else TEXTE
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(st, fg)
	var bg := OR if primary else Color(1, 1, 1, 0.04)
	var bd := OR if primary else Color(1, 1, 1, 0.35)
	b.add_theme_stylebox_override("normal", box(bg, bd, 1, 8))
	b.add_theme_stylebox_override("hover", box(bg.lightened(0.12), bd, 1, 8))
	b.add_theme_stylebox_override("pressed", box(bg.darkened(0.1), bd, 1, 8))
	var focus := box(Color(0, 0, 0, 0), Color(1, 1, 1, 0.95), 3, 8)
	focus.draw_center = false
	b.add_theme_stylebox_override("focus", focus)
	if parent:
		parent.add_child(b)
	return b


## Contenu d'une carte : une marge qui remplit la carte et ignore la souris (le bouton la reçoit).
static func inside(b: Control, margin := 10) -> MarginContainer:
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, margin)
	b.add_child(m)
	return m


static func vbox(parent: Node, sep := 6) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent:
		parent.add_child(v)
	return v


static func hbox(parent: Node, sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent:
		parent.add_child(h)
	return h


static func _texture(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]


## Rendu de l'arme (vrai modèle du jeu, de trois quarts).
static func weapon_image(parent: Node, id: String, size: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = _texture("res://assets/ui/armes/%s.png" % id)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = size
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent:
		parent.add_child(t)
	return t


## Icône d'atout ou d'équipement (pictogramme blanc, teinté).
static func icon(parent: Node, id: String, size: float, color := OR) -> TextureRect:
	var t := TextureRect.new()
	t.texture = _texture("res://assets/ui/icones/%s.svg" % id)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size, size)
	t.modulate = color
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent:
		parent.add_child(t)
	return t


static func badge_style(active: bool) -> StyleBoxFlat:
	var s := box(Color(1.0, 0.84, 0.42, 0.13) if active else Color(1, 1, 1, 0.06), Color(1.0, 0.84, 0.42, 0.6) if active else Color(1, 1, 1, 0.18), 2, 12)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


## Icône dans un cadre arrondi (atouts).
static func icon_badge(parent: Node, id: String, size: float, active := true) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", badge_style(active))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon(p, id, size - 12.0, OR if active else Color(0.8, 0.83, 0.86))
	if parent:
		parent.add_child(p)
	return p


# ------------------------------------------------------------------------------------------------
# Statistiques des armes (0 à 100), calculées depuis armes.gd
# ------------------------------------------------------------------------------------------------
const STATS := ["Dégâts", "Portée", "Cadence", "Mobilité", "Maniement", "Élimination"]


## Temps pour éliminer une cible en armure complète (secondes).
static func ttk(id: String) -> float:
	return float(Armes.coups_pour_tuer(id) - 1) * float(Armes.info(id).rof)


## Statistiques d'une arme précise (avec ses accessoires).
static func stats(w: Dictionary) -> Array:
	var id: String = w.id
	var a := Armes.de(w)
	var dmg := float(a.dmg) * float(a.plombs)
	var p1 := float(a.portee[1])
	var out := [
		100.0 * log(dmg / 15.0) / log(160.0 / 15.0),
		minf(100.0, p1 / 300.0 * 100.0) if p1 >= 100.0 else p1 / 120.0 * 60.0,
		minf(100.0, (1.0 / float(a.rof)) / 18.0 * 100.0),
		(float(a.vitesse) - 0.85) / (1.06 - 0.85) * 100.0,
		(0.45 - float(a.ads)) / 0.31 * 100.0,
		(1.8 - ttk(id)) / 1.2 * 100.0,
	]
	for k in out.size():
		out[k] = clampf(out[k], 0.0, 100.0)
	return out


static func ttk_text(id: String) -> String:
	return ("%.2f s" % ttk(id)).replace(".", ",")


## Jauge en 10 segments, avec un repère (arme équipée) et une couleur de comparaison.
class Jauge:
	extends Control
	var value := 0.0
	var ref := -1.0
	var color := Color(0.95, 0.94, 0.92)

	func _init() -> void:
		custom_minimum_size = Vector2(0, 8)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var n := 10
		var gap := 3.0
		var w := (size.x - gap * (n - 1)) / n
		var full := value / 10.0
		for k in n:
			var r := Rect2(k * (w + gap), 0, w, size.y)
			draw_rect(r, Color(1, 1, 1, 0.12))
			var f := clampf(full - k, 0.0, 1.0)
			if f > 0.0:
				draw_rect(Rect2(r.position, Vector2(w * f, size.y)), color)
		if ref >= 0.0:
			var x := ref / 100.0 * size.x
			draw_rect(Rect2(x - 1.5, -3, 3, size.y + 6), UIStyle.OR)
