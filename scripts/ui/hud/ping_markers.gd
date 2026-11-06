class_name PingMarkers
extends Control
## Your team's pings, drawn at their 3D positions: a ring and dot with the distance beside it,
## fading while you aim at them so they never cover a fight, and at the end of their life.

const AIM_FADE_INNER := 40.0
const AIM_FADE_OUTER := 130.0
const COLOR := Color(0.4, 1.0, 0.85)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var w = Game.world
	var cam := get_viewport().get_camera_3d()
	if w == null or cam == null:
		return
	var font := get_theme_default_font()
	var now := Time.get_ticks_msec() / 1000.0
	w.pings = w.pings.filter(func(p: Dictionary) -> bool: return p.until > now)
	for ping: Dictionary in w.pings:
		if cam.is_position_behind(ping.pos):
			continue
		var at := cam.unproject_position(ping.pos)
		var aim := clampf(inverse_lerp(AIM_FADE_INNER, AIM_FADE_OUTER, at.distance_to(size * 0.5)), 0.12, 1.0)
		var alpha := aim * clampf(ping.until - now, 0.0, 1.0)
		var color := Color(COLOR, alpha)
		draw_arc(at, 11.0, 0, TAU, 24, color, 2.5, true)
		draw_circle(at, 3.0, color)
		var label := "%dm" % roundi(cam.global_position.distance_to(ping.pos))
		draw_string_outline(font, at + Vector2(16, 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 3, Color(0, 0, 0, alpha))
		draw_string(font, at + Vector2(16, 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
