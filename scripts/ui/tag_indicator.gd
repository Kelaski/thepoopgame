class_name TagIndicator
extends Control
## Points you to the Tag while it's lying on the ground after being dropped
## (assets/ui/tag_indicator.tscn, part of the HUD). On screen, an arrow bobs above
## it with the distance; off screen, an arrow at the edge of the screen points the
## way to turn.

const EDGE_MARGIN := 56.0
const ARROW := 16.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not Game.in_match or Game.phase != Game.Phase.DROPPED or Game.holder != 0:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var target := Game.tag_pos + Vector3(0, 1.4, 0)
	var t := Time.get_ticks_msec() * 0.001
	var col := Mats.TAG_COLOR
	var outline := Color(0, 0, 0, 0.85)
	var rect := Rect2(Vector2(EDGE_MARGIN, EDGE_MARGIN), size - Vector2(EDGE_MARGIN, EDGE_MARGIN) * 2.0)
	var centre := size * 0.5
	var behind := cam.is_position_behind(target)
	var sp := cam.unproject_position(target)
	if not behind and rect.has_point(sp):
		# On screen: a downward arrow bobbing above the Tag, and how far it is.
		var tip := sp + Vector2(0, -10.0 + sin(t * 5.0) * 4.0)
		var tri := PackedVector2Array([tip, tip + Vector2(-ARROW * 0.7, -ARROW), tip + Vector2(ARROW * 0.7, -ARROW)])
		draw_colored_polygon(tri, col)
		tri.append(tri[0])
		draw_polyline(tri, outline, 2.0)
		var font := ThemeDB.fallback_font
		var label := "TAG  %d m" % roundi(cam.global_position.distance_to(Game.tag_pos))
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var lp := tip + Vector2(-w * 0.5, -ARROW - 8.0)
		draw_string_outline(font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, outline)
		draw_string(font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)
		return
	# Off screen (or behind you): an arrow on the screen edge pointing the way.
	var dir := sp - centre
	if behind:
		dir = -dir
	if dir.length() < 1.0:
		dir = Vector2(0, 1)
	dir = dir.normalized()
	var half := rect.size * 0.5
	var k := minf(half.x / maxf(absf(dir.x), 0.001), half.y / maxf(absf(dir.y), 0.001))
	var pos := centre + dir * k
	var pulse := 1.0 + sin(t * 6.0) * 0.12
	var side := Vector2(-dir.y, dir.x)
	var a := ARROW * 1.4 * pulse
	var arrow := PackedVector2Array([pos + dir * a, pos - dir * a * 0.6 + side * a * 0.8, pos - dir * a * 0.25, pos - dir * a * 0.6 - side * a * 0.8])
	draw_colored_polygon(arrow, col)
	arrow.append(arrow[0])
	draw_polyline(arrow, outline, 2.0)
