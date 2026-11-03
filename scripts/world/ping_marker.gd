class_name PingMarker
extends Node3D
## A teammate's ping (assets/models/ping_marker.tscn): an icon drawn through walls
## so you can always find it. It pops in, bobs gently, fades while you aim right
## at it (like teammate names, so it never covers a fight) and fades out at the
## end of its life, then frees itself.

const POP_TIME := 0.15
const FADE_TIME := 0.6

var title := ""      # "ENEMY", "DANGER", "TAG" or "" (kept for the kind; not drawn)
var color := Color.WHITE
var life := 6.0
var age := 0.0

var _aim_fade := 1.0

@onready var icon: Sprite3D = $Icon


func setup(col: Color, text: String, lifetime: float) -> void:
	color = col
	title = text
	life = lifetime


func _ready() -> void:
	icon.modulate = color
	_update(0.0)


func _process(delta: float) -> void:
	age += delta
	if age >= life:
		queue_free()
		return
	_update(delta)


## How visible the ping is right now (0..1): used by the minimap too.
func alpha() -> float:
	return clampf((life - age) / FADE_TIME, 0.0, 1.0)


func _update(delta: float) -> void:
	var pop := clampf(age / POP_TIME, 0.0, 1.0)
	icon.scale = Vector3.ONE * lerpf(1.8, 1.0, pop)
	icon.position.y = 0.6 + sin(age * 4.0) * 0.05
	# Same fade as teammate names while it's near the crosshair.
	var cam := get_viewport().get_camera_3d()
	var target := 1.0
	if cam:
		var ang := rad_to_deg((-cam.global_basis.z).angle_to(icon.global_position - cam.global_position))
		var k := clampf((ang - Player.NAMEPLATE_FADE_NEAR) / (Player.NAMEPLATE_FADE_FAR - Player.NAMEPLATE_FADE_NEAR), 0.0, 1.0)
		target = lerpf(Player.NAMEPLATE_MIN_ALPHA, 1.0, k)
	_aim_fade = target if delta <= 0.0 else lerpf(_aim_fade, target, clampf(delta * 12.0, 0.0, 1.0))
	icon.modulate.a = alpha() * _aim_fade
