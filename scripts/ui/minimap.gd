class_name Minimap
extends Control
## North-up minimap of the playable area (scaled to fit whatever map size is
## loaded). Shows the Runner to everyone at all times, your teammates, the
## objective / dropped Tag, and yourself. Its size follows the "Minimap size"
## setting, and location names are drawn on the buildings and park.

const WIDGET := Vector2(288, 245)  # size at 1.0x (the old 1.2x)
const MIN_SCALE := 0.6
const MAX_SCALE := 2.0
const LABEL_SIZE := 9.0            # font size at 1.0x (shrunk further to fit small buildings)
const LABEL_MIN := 5

var _acc := 0.0
var _scale := 1.2
var _ui_scale := 1.0              # the player's minimap size setting
var _origin := Vector2.ZERO   # map-space point drawn at the widget's top-left
var _pad := Vector2.ZERO      # centring offset inside the widget
var _area_px := Rect2()       # the playable area on the widget: everything is clipped to it


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


## A widget-space rect cut to the playable area, so nothing spills past the map's edge.
func _clip(r: Rect2) -> Rect2:
	return r.intersection(_area_px)


## Location names centred on each building (and the park). Names wider than their
## building are split onto two lines, and shrunk until they fit inside it, so
## neighbouring names never overlap.
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
	if width > rect.size.x and cut > 0:
		lines = [text.left(cut), text.substr(cut + 1)]
	# Shrink until every line fits the building's width and the block its height.
	while fs > LABEL_MIN:
		var widest := 0.0
		for line: String in lines:
			widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
		if widest <= rect.size.x and font.get_height(fs) * lines.size() <= rect.size.y + 2.0:
			break
		fs -= 1
	var line_h := font.get_height(fs)
	var y := rect.get_center().y - line_h * lines.size() * 0.5 + font.get_ascent(fs)
	for line: String in lines:
		var lw := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := Vector2(rect.get_center().x - lw * 0.5, y).round()
		draw_string_outline(font, pos, line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, 0.85))
		draw_string(font, pos, line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.9))
		y += line_h


## Roads with curbs and centre dashes, car parks, and the park's paths, court,
## sandpit, pond and fountain plaza.
func _draw_ground(builder) -> void:
	var dash := maxf(1.0, 3.0 * _scale)
	for r: Rect2 in builder.road_rects:
		var rr := _r(r)
		draw_rect(_clip(rr.grow(maxf(1.0, 1.2 * _scale))), Color(0.33, 0.33, 0.35))  # sidewalk / curb
	for r: Rect2 in builder.road_rects:
		draw_rect(_clip(_r(r)), Color(0.2, 0.21, 0.24))
	for r: Rect2 in builder.road_rects:
		var rr := _r(r)
		var c := rr.get_center()
		var along_x := rr.size.x >= rr.size.y
		var length := rr.size.x if along_x else rr.size.y
		if length < dash * 4.0:
			continue
		var d := 0.0
		while d + dash <= length:
			if along_x:
				draw_line(Vector2(rr.position.x + d, c.y), Vector2(rr.position.x + d + dash, c.y), Color(0.78, 0.7, 0.35, 0.55), 1.0)
			else:
				draw_line(Vector2(c.x, rr.position.y + d), Vector2(c.x, rr.position.y + d + dash), Color(0.78, 0.7, 0.35, 0.55), 1.0)
			d += dash * 2.0
	for m: Array in builder.map_marks:
		if m[0] == "lot":
			var lr := _clip(_r(m[1]))
			draw_rect(lr, Color(0.26, 0.27, 0.3))
			draw_rect(lr, Color(0.55, 0.55, 0.5, 0.4), false, 1.0)
	if not builder.has_park:
		return
	var pr := _r(builder.park_rect)
	draw_rect(pr, Color(0.32, 0.55, 0.28))
	draw_rect(pr, Color(0.22, 0.4, 0.2), false, 1.0)
	for m: Array in builder.map_marks:
		var r := _r(m[1])
		match m[0]:
			"path":
				draw_rect(r, Color(0.72, 0.68, 0.58))
			"sand":
				draw_rect(r, Color(0.86, 0.76, 0.5))
			"court":
				draw_rect(r, Color(0.86, 0.5, 0.25))
				draw_rect(r, Color(1, 1, 1, 0.6), false, 1.0)
				draw_line(Vector2(r.position.x, r.get_center().y), Vector2(r.end.x, r.get_center().y), Color(1, 1, 1, 0.6), 1.0)
	for m: Array in builder.map_marks:
		var r := _r(m[1])
		match m[0]:
			"plaza":
				draw_circle(r.get_center(), r.size.x * 0.5, Color(0.8, 0.76, 0.66))
				draw_circle(r.get_center(), r.size.x * 0.22, Color(0.37, 0.72, 0.9))
			"pond":
				_draw_ellipse(r, Color(0.25, 0.55, 0.8))


func _draw_ellipse(r: Rect2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := i * TAU / 24.0
		pts.append(r.get_center() + Vector2(cos(a) * r.size.x * 0.5, sin(a) * r.size.y * 0.5))
	draw_colored_polygon(pts, col)


## Buildings: a soft shadow, the walls in the building's colour (taller ones
## lighter) and a roof inset.
func _draw_buildings(builder) -> void:
	var tallest := 1
	for b in builder.buildings:
		tallest = maxi(tallest, int(b.floors))
	var sh := maxf(1.0, 0.8 * _scale)
	for b in builder.buildings:
		draw_rect(_clip(_r(b.rect).grow(0.5)), Color(0, 0, 0, 0.3))
		draw_rect(_clip(Rect2(_r(b.rect).position + Vector2(sh, sh), _r(b.rect).size)), Color(0, 0, 0, 0.35))
	for b in builder.buildings:
		var rr := _r(b.rect)
		var h := float(b.floors) / tallest
		var base := (b.color as Color).darkened(0.45 - 0.25 * h)
		draw_rect(rr, base)
		var inset := maxf(1.0, 1.1 * _scale)
		if rr.size.x > inset * 4.0 and rr.size.y > inset * 4.0:
			draw_rect(rr.grow(-inset), base.lightened(0.12))
		draw_rect(rr, Color(0, 0, 0, 0.55), false, 1.0)


func _draw() -> void:
	# A dark backing like the HUD panels, with the map fitted inside it.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.035, 0.05, 0.62))
	var w = Game.world
	if w == null or w.builder == null:
		return
	var area: Rect2 = w.builder.bounds
	var inner := Rect2(Vector2(6, 6), size - Vector2(12, 12))
	_scale = minf(inner.size.x / area.size.x, inner.size.y / area.size.y)
	_origin = area.position
	_pad = inner.position + (inner.size - area.size * _scale) * 0.5
	_area_px = _r(area)
	draw_rect(_area_px, Color(0.17, 0.18, 0.2))
	_draw_ground(w.builder)
	_draw_buildings(w.builder)
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
	# Enemies your team's UAV last saw
	for pos: Vector3 in w.uav_dots():
		draw_circle(_p(pos), 5.0, Color(0, 0, 0, 0.8))
		draw_circle(_p(pos), 4.0, Color(1.0, 0.2, 0.15))
	# Runner: always visible to everyone
	if Game.holder != 0 and w.players.has(Game.holder):
		var rp = w.players[Game.holder]
		var c := _p(rp.global_position)
		var r := 7.0 + sin(t * 8.0) * 1.5
		var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
		draw_colored_polygon(pts, Mats.TAG_COLOR)
		pts.append(pts[0])
		draw_polyline(pts, Mats.team_color(rp.team), 2.0)
	# Team pings: diamonds in the ping's colour, fading out with the marker
	for pg: Array in w.pings:
		var m = pg[2]
		if not is_instance_valid(m):
			continue
		var pc := _p(m.global_position)
		var a: float = m.alpha()
		var pts := PackedVector2Array([pc + Vector2(0, -6), pc + Vector2(6, 0), pc + Vector2(0, 6), pc + Vector2(-6, 0)])
		draw_colored_polygon(pts, Color(m.color, a))
		pts.append(pts[0])
		draw_polyline(pts, Color(0, 0, 0, 0.85 * a), 1.5)
	# Self arrow
	if lp and lp.alive:
		var c := _p(lp.global_position)
		var f := Vector2(-sin(lp.yaw), -cos(lp.yaw))
		var rt := Vector2(-f.y, f.x)
		var tri := PackedVector2Array([c + f * 8.0, c - f * 5.0 + rt * 5.0, c - f * 5.0 - rt * 5.0])
		draw_colored_polygon(tri, Color.WHITE)
		tri.append(tri[0])
		draw_polyline(tri, Color.BLACK, 1.5)
	draw_rect(_area_px, Color(0, 0, 0, 0.6), false, 1.0)
