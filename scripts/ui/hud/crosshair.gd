class_name Crosshair
extends Control
## Crosshair (Counter-Strike style options), custom crosshair image, hitmarkers,
## the sniper scope (default or a custom image) and the sniper next-shot ring.

const STYLES := ["classic", "circle", "dot", "image"]

var mode := "normal"   # normal, dot, bat, scope, none
var spread := 0.0
var hit_t := 0.0
var hit_kill := false
var hit_head := false
var cooldown := 0.0  # 0..1 remaining time until the next shot or round


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
	var c := (size * 0.5).floor()
	match mode:
		"normal":
			draw_crosshair(self, c, spread)
		"dot":
			if str(Settings.g("xh_style")) == "image":
				draw_crosshair(self, c, 0.0)
			else:
				var col := _color()
				var d := maxf(2.0, float(Settings.g("xh_dot_size")) + 1.0)
				if Settings.g("xh_outline"):
					draw_rect(Rect2(c - Vector2(d, d) * 0.5 - Vector2.ONE, Vector2(d, d) + Vector2.ONE * 2.0), Color(0, 0, 0, col.a))
				draw_rect(Rect2(c - Vector2(d, d) * 0.5, Vector2(d, d)), col)
		"bat":
			var col := _color()
			draw_arc(c, 11.0, 0.0, TAU, 28, Color(0, 0, 0, 0.8), 4.0)
			draw_arc(c, 11.0, 0.0, TAU, 28, col, 2.0)
		"scope":
			_draw_scope(c)
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


static func _color() -> Color:
	var col: Color = Settings.crosshair_color()
	col.a = clampf(float(Settings.g("xh_alpha")), 0.05, 1.0)
	return col


## Draws the configured crosshair on any CanvasItem (also used by the editor preview).
static func draw_crosshair(ci: CanvasItem, c: Vector2, spread_deg: float) -> void:
	var style := str(Settings.g("xh_style"))
	var col := _color()
	var outline := Color(0, 0, 0, col.a)
	var use_outline: bool = Settings.g("xh_outline")
	var ot := float(Settings.g("xh_outline_thickness"))
	var length := float(Settings.g("xh_length"))
	var th := maxf(1.0, float(Settings.g("xh_thickness")))
	var gap := float(Settings.g("xh_gap"))
	if Settings.g("xh_dynamic"):
		gap += spread_deg * 5.0
	if style == "image":
		var tex := UserImages.texture(UserImages.CROSSHAIR)
		if tex:
			var s := tex.get_size() * float(Settings.g("xh_image_scale"))
			ci.draw_texture_rect(tex, Rect2(c - s * 0.5, s), false, Color(1, 1, 1, col.a))
			return
		style = "classic"  # no image uploaded yet
	if style == "circle":
		var r := gap + length * 0.5
		if use_outline:
			ci.draw_arc(c, r, 0.0, TAU, 48, outline, th + ot * 2.0)
		ci.draw_arc(c, r, 0.0, TAU, 48, col, th)
	elif style == "classic":
		var arms := [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN]
		if not Settings.g("xh_tstyle"):
			arms.append(Vector2.UP)
		for d: Vector2 in arms:
			var rect: Rect2
			if d.x != 0.0:
				var x0 := gap if d.x > 0.0 else -gap - length
				rect = Rect2(c + Vector2(x0, -th * 0.5), Vector2(length, th))
			else:
				var y0 := gap if d.y > 0.0 else -gap - length
				rect = Rect2(c + Vector2(-th * 0.5, y0), Vector2(th, length))
			if use_outline:
				ci.draw_rect(rect.grow(ot), outline)
			ci.draw_rect(rect, col)
	if Settings.g("xh_dot") or style == "dot":
		var d := maxf(1.0, float(Settings.g("xh_dot_size")))
		var dr := Rect2(c - Vector2(d, d) * 0.5, Vector2(d, d))
		if use_outline:
			ci.draw_rect(dr.grow(ot), outline)
		ci.draw_rect(dr, col)


func _draw_scope(c: Vector2) -> void:
	var tex: Texture2D = null
	if Settings.g("scope_custom"):
		tex = UserImages.texture(UserImages.SCOPE)
	if tex:
		# Custom scope image: fit to the screen height, black bars fill the rest.
		var k := size.y / tex.get_size().y * float(Settings.g("scope_scale"))
		var s := tex.get_size() * k
		var rect := Rect2(c - s * 0.5, s)
		draw_rect(Rect2(0, 0, maxf(0.0, rect.position.x), size.y), Color.BLACK)
		draw_rect(Rect2(rect.end.x, 0, maxf(0.0, size.x - rect.end.x), size.y), Color.BLACK)
		if rect.position.y > 0.0:
			draw_rect(Rect2(0, 0, size.x, rect.position.y), Color.BLACK)
			draw_rect(Rect2(0, rect.end.y, size.x, size.y - rect.end.y), Color.BLACK)
		draw_texture_rect(tex, rect, false)
		return
	var r := minf(size.x, size.y) * 0.44
	var thick := size.length()
	draw_arc(c, r + thick * 0.5, 0.0, TAU, 96, Color(0, 0, 0, 1), thick)
	draw_arc(c, r, 0.0, TAU, 96, Color(0.05, 0.05, 0.05), 6.0)
	draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), Color(0, 0, 0, 0.9), 1.5)
	draw_line(c + Vector2(0, -r), c + Vector2(0, r), Color(0, 0, 0, 0.9), 1.5)
	draw_circle(c, 2.0, Color(1, 0.2, 0.2))
