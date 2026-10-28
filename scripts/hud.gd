class_name Hud
extends CanvasLayer
## Interface de la visite : lieu et case du quadrillage, boussole, aide aux commandes,
## images par seconde, et la carte tactique plein écran (assets/map/carte.png).

var player: Explorateur
var touch: TouchControls
var _place: Label
var _compass: Label
var _help: Label
var _fps: Label
var _map: MapView


func _ready() -> void:
	layer = 5
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_place = _label(root, 30, Color(1, 1, 1))
	_place.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place.offset_top = 16
	_compass = _label(root, 22, Color(1, 0.85, 0.45))
	_compass.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_compass.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_compass.offset_top = 56
	_help = _label(root, 18, Color(1, 1, 1, 0.8))
	_help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_help.offset_left = 20
	_help.offset_top = -48
	_help.offset_bottom = -16
	_fps = _label(root, 16, Color(1, 1, 1, 0.6))
	_fps.position = Vector2(14, 10)
	touch = TouchControls.new()
	root.add_child(touch)
	touch.map_pressed.connect(toggle_map)
	_map = MapView.new()
	_map.visible = false
	root.add_child(_map)
	G.input_mode_changed.connect(func(_m): _update_help())
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


func attach(p: Explorateur) -> void:
	player = p
	player.touch = touch
	_map.player = p
	touch.drone_pressed.connect(func(): player.set_flying(not player.flying); _update_help())


func toggle_map() -> void:
	_map.visible = not _map.visible


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("carte"):
		toggle_map()
	if event.is_action_pressed("drone"):
		_update_help.call_deferred()


func _update_help() -> void:
	var flying := player != null and player.flying
	match G.input_mode:
		"pad":
			_help.text = ("Y : marcher  ·  A / B : monter / descendre  ·  L3 : rapide  ·  Select : carte" if flying
				else "Y : drone  ·  A : sauter  ·  L3 : sprint  ·  Select : carte")
		"touch":
			_help.text = ""
		_:
			_help.text = ("F : marcher  ·  Espace / C : monter / descendre  ·  Maj : rapide  ·  M : carte" if flying
				else "ZQSD / WASD  ·  Espace : sauter  ·  Maj : sprint  ·  F : drone  ·  M : carte")


func _process(_delta: float) -> void:
	if player == null:
		return
	var p := player.global_position
	_place.text = G.where(p) + ("  ·  DRONE" if player.flying else "")
	var heading := fposmod(-rad_to_deg(player.rotation.y), 360.0)
	var names := ["N", "NE", "E", "SE", "S", "SO", "O", "NO"]
	_compass.text = "%s  %d°  ·  alt. %d m" % [names[int(round(heading / 45.0)) % 8], int(heading), int(p.y)]
	_fps.text = "%d i/s" % Engine.get_frames_per_second()
	touch.flying = player.flying


class MapView:
	extends Control
	## Carte tactique : l'image générée, les noms des lieux et la position du joueur.
	var player: Node3D
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
		if player:
			var pp: Vector2 = to_map.call(player.global_position.x, player.global_position.z)
			var fwd := -player.global_basis.z
			var dir := Vector2(fwd.x, fwd.z).normalized()
			var perp := Vector2(-dir.y, dir.x)
			var s := side / 70.0
			draw_colored_polygon(PackedVector2Array([pp + dir * s * 1.4, pp - dir * s * 0.8 + perp * s, pp - dir * s * 0.8 - perp * s]), Color(0.2, 0.9, 1.0))
			draw_polyline(PackedVector2Array([pp + dir * s * 1.4, pp - dir * s * 0.8 + perp * s, pp - dir * s * 0.8 - perp * s, pp + dir * s * 1.4]), Color(0, 0, 0), 2.0)
