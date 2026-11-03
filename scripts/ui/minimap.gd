class_name Minimap
extends Control
## North-up minimap of the whole city. Shows the Runner to everyone at all times,
## your teammates, the objective / dropped Tag, and yourself.

const S := 1.2
const OFF := Vector2(MapData.HALF_X, MapData.HALF_Z)

var _acc := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(MapData.HALF_X * 2.0, MapData.HALF_Z * 2.0) * S
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_acc += delta
	if _acc >= 0.05:
		_acc = 0.0
		queue_redraw()


func _p(v: Vector3) -> Vector2:
	return (Vector2(v.x, v.z) + OFF) * S


func _r(r: Rect2) -> Rect2:
	return Rect2((r.position + OFF) * S, r.size * S)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.12, 0.14, 0.85))
	var w = Game.world
	if w == null or w.builder == null:
		return
	for r: Rect2 in w.builder.road_rects:
		draw_rect(_r(r), Color(0.24, 0.25, 0.29))
	draw_rect(_r(w.builder.park_rect), Color(0.32, 0.55, 0.28))
	for b in w.builder.buildings:
		var rr := _r(b.rect)
		draw_rect(rr, (b.color as Color).darkened(0.35))
		draw_rect(rr, Color(0, 0, 0, 0.5), false, 1.0)
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
