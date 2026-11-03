class_name Crosshair
extends Control
## Dynamic crosshair, hitmarkers and the sniper scope overlay.

var mode := "normal"   # normal, dot, bat, scope, none
var spread := 0.0
var hit_t := 0.0
var hit_kill := false
var hit_head := false
var cooldown := 0.0  # 0..1 remaining time until the next shot (sniper)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func hit(head: bool, kill: bool) -> void:
	hit_t = 0.25 if not kill else 0.45
	hit_head = head
	hit_kill = kill


func _process(delta: float) -> void:
	hit_t = maxf(0.0, hit_t - delta)
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var col: Color = Settings.crosshair_color()
	var arm := float(Settings.g("crosshair_size"))
	var outline := Color(0, 0, 0, 0.8)
	match mode:
		"normal":
			var gap := 4.0 + spread * 5.0
			for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				draw_line(c + d * (gap - 1.0), c + d * (gap + arm + 1.0), outline, 4.0)
				draw_line(c + d * gap, c + d * (gap + arm), col, 2.0)
			draw_circle(c, 1.5, col)
		"dot":
			draw_circle(c, 3.0, outline)
			draw_circle(c, 2.0, col)
		"bat":
			draw_arc(c, 11.0, 0.0, TAU, 28, outline, 4.0)
			draw_arc(c, 11.0, 0.0, TAU, 28, col, 2.0)
		"scope":
			var r := minf(size.x, size.y) * 0.44
			var thick := size.length()
			draw_arc(c, r + thick * 0.5, 0.0, TAU, 96, Color(0, 0, 0, 1), thick)
			draw_arc(c, r, 0.0, TAU, 96, Color(0.05, 0.05, 0.05), 6.0)
			draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), Color(0, 0, 0, 0.9), 1.5)
			draw_line(c + Vector2(0, -r), c + Vector2(0, r), Color(0, 0, 0, 0.9), 1.5)
			draw_circle(c, 2.0, Color(1, 0.2, 0.2))
	if cooldown > 0.0:
		var rr := 18.0
		draw_arc(c, rr, 0.0, TAU, 40, Color(0, 0, 0, 0.55), 4.0)
		var done := 1.0 - cooldown
		draw_arc(c, rr, -PI * 0.5, -PI * 0.5 + TAU * done, 40, Color(1.0, 0.82, 0.25, 0.95), 3.0)
	if hit_t > 0.0:
		var hc := Color(1, 1, 1, hit_t * 4.0)
		if hit_head:
			hc = Color(1, 0.85, 0.2, hit_t * 4.0)
		if hit_kill:
			hc = Color(1, 0.25, 0.2, minf(1.0, hit_t * 3.0))
		var sz := 14.0 if hit_kill else 11.0
		for d: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var dn := d.normalized()
			draw_line(c + dn * 6.0, c + dn * sz, hc, 2.5)
