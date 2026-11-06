class_name DamageIndicator
extends Control
## Red arcs around the crosshair pointing to whoever just shot you. Each arc keeps
## tracking its shooter while it fades, and is drawn relative to where you're facing
## (up = in front of you, down = behind you).

const SHOW_TIME := 2.2
const FADE_TIME := 0.6
const RADIUS := 120.0
const HALF_ARC := deg_to_rad(20.0)
const WIDTH := 7.0
const COLOR := Color(0.95, 0.12, 0.08)

var _hits := {}  # shooter id -> {"pos": Vector3, "t": float}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Game.local_damaged_by.connect(_on_damaged_by)


func _on_damaged_by(shooter: int, pos: Vector3) -> void:
	_hits[shooter] = {"pos": pos, "t": SHOW_TIME}


func _process(delta: float) -> void:
	if _hits.is_empty():
		return
	for id in _hits.keys():
		_hits[id].t -= delta
		if _hits[id].t <= 0.0:
			_hits.erase(id)
		elif Game.world and Game.world.players.has(id):
			_hits[id].pos = Game.world.players[id].global_position
	queue_redraw()


func _draw() -> void:
	var lp = Game.world.local_player() if Game.world else null
	if lp == null or not lp.alive:
		return
	var c := size * 0.5
	var basis := Basis(Vector3.UP, lp.yaw)
	for id in _hits:
		var h: Dictionary = _hits[id]
		var d: Vector3 = h.pos - lp.global_position
		# Angle from straight ahead, clockwise; screen angle 0 is +X, so ahead is -PI/2.
		var a := atan2(basis.x.dot(d), -basis.z.dot(d)) - PI * 0.5
		var col := COLOR
		col.a = 0.85 * clampf(float(h.t) / FADE_TIME, 0.0, 1.0)
		draw_arc(c, RADIUS, a - HALF_ARC, a + HALF_ARC, 24, col, WIDTH, true)
		# Small pointer in the middle of the arc.
		var dir := Vector2(cos(a), sin(a))
		var side := Vector2(-dir.y, dir.x)
		var tip := c + dir * (RADIUS + WIDTH + 9.0)
		var base := c + dir * (RADIUS + WIDTH * 0.5)
		draw_colored_polygon(PackedVector2Array([tip, base + side * 8.0, base - side * 8.0]), col)
