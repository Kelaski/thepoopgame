class_name Minimap
extends Control
## North-up minimap of the playable area (scaled to fit whatever map size is
## loaded). Shows the Runner to everyone at all times, your teammates, the
## objective / dropped Tag, and yourself. Its size follows the "Minimap size"
## setting, and location names are drawn on the buildings and park.

const WIDGET := Vector2(240, 204)  # size at 1.0x
const MIN_SCALE := 0.6
const MAX_SCALE := 2.0
const LABEL_SIZE := 9.0            # font size at 1.0x

var _acc := 0.0
var _scale := 1.2
var _ui_scale := 1.0              # the player's minimap size setting
var _origin := Vector2.ZERO   # map-space point drawn at the widget's top-left
var _pad := Vector2.ZERO      # centring offset inside the widget


func _init() -> void:
	custom_minimum_size = WIDGET
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	var k := clampf(float(Settings.g("minimap_scale")), MIN_SCALE, MAX_SCALE)
	if not is_equal_approx(k, _ui_scale) or custom_minimum_size != WIDGET * k:
		_ui_scale = k
		custom_minimum_size = WIDGET * k
		size = custom_minimum_size
	_acc += delta
	if _acc >= 0.05:
		_acc = 0.0
		queue_redraw()


func _p(v: Vector3) -> Vector2:
	return (Vector2(v.x, v.z) - _origin) * _scale + _pad


func _r(r: Rect2) -> Rect2:
	return Rect2((r.position - _origin) * _scale + _pad, r.size * _scale)


## Location names centred on each building (and the park). Names wider than their
## building are split onto two lines.
func _draw_labels(builder) -> void:
	var font := ThemeDB.fallback_font
	var fs := int(round(LABEL_SIZE * _ui_scale))
	for b in builder.buildings:
		_draw_label(font, fs, str(b.name), _r(b.rect))
	if builder.has_park:
		_draw_label(font, fs, builder.park_name, _r(builder.park_rect))


func _draw_label(font: Font, fs: int, text: String, rect: Rect2) -> void:
	var lines := [text]
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var cut := text.find(" ", text.length() / 2)
	if cut < 0:
		cut = text.rfind(" ")
	if width > rect.size.x + 6.0 and cut > 0:
		lines = [text.left(cut), text.substr(cut + 1)]
	var line_h := font.get_height(fs)
	var y := rect.get_center().y - line_h * lines.size() * 0.5 + font.get_ascent(fs)
	for line: String in lines:
		var lw := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := Vector2(rect.get_center().x - lw * 0.5, y).round()
		draw_string_outline(font, pos, line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, 0.85))
		draw_string(font, pos, line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.9))
		y += line_h


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.12, 0.14, 0.85))
	var w = Game.world
	if w == null or w.builder == null:
		return
	var area: Rect2 = w.builder.bounds
	_scale = minf(size.x / area.size.x, size.y / area.size.y)
	_origin = area.position
	_pad = (size - area.size * _scale) * 0.5
	draw_rect(_r(area), Color(0.16, 0.18, 0.2, 0.9))
	for r: Rect2 in w.builder.road_rects:
		draw_rect(_r(r), Color(0.24, 0.25, 0.29))
	if w.builder.has_park:
		draw_rect(_r(w.builder.park_rect), Color(0.32, 0.55, 0.28))
	for b in w.builder.buildings:
		var rr := _r(b.rect)
		draw_rect(rr, (b.color as Color).darkened(0.35))
		draw_rect(rr, Color(0, 0, 0, 0.5), false, 1.0)
	if Settings.g("minimap_labels"):
		_draw_labels(w.builder)
	var t := Time.get_ticks_msec() * 0.001
	# Objective / dropped Tag
	if Game.holder == 0 and Game.objective >= 0:
		var tp := _p(Game.tag_pos)
		var pulse := 6.0 + sin(t * 6.0) * 2.0
		draw_circle(tp, pulse + 2.0, Color(0, 0, 0, 0.7))
		draw_circle(tp, pulse, Mats.TAG_COLOR)
	var lp = w.local_player()
	# Teammates
	if lp:
		for id in w.players:
			var p = w.players[id]
			if p == lp or p.team != lp.team or not p.alive:
				continue
			draw_circle(_p(p.global_position), 4.0, Color(0, 0, 0, 0.8))
			draw_circle(_p(p.global_position), 3.0, Mats.team_color(p.team).lightened(0.3))
	# Runner: always visible to everyone
	if Game.holder != 0 and w.players.has(Game.holder):
		var rp = w.players[Game.holder]
		var c := _p(rp.global_position)
		var r := 7.0 + sin(t * 8.0) * 1.5
		var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
		draw_colored_polygon(pts, Mats.TAG_COLOR)
		pts.append(pts[0])
		draw_polyline(pts, Mats.team_color(rp.team), 2.0)
	# Self arrow
	if lp and lp.alive:
		var c := _p(lp.global_position)
		var f := Vector2(-sin(lp.yaw), -cos(lp.yaw))
		var rt := Vector2(-f.y, f.x)
		var tri := PackedVector2Array([c + f * 8.0, c - f * 5.0 + rt * 5.0, c - f * 5.0 - rt * 5.0])
		draw_colored_polygon(tri, Color.WHITE)
		tri.append(tri[0])
		draw_polyline(tri, Color.BLACK, 1.5)
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.35), false, 2.0)
