class_name PingMarker
extends Node3D
## A teammate's ping (assets/models/ping_marker.tscn): an icon and the distance
## to it, drawn through walls so you can always find it. It pops in, bobs gently
## and fades out at the end of its life, then frees itself.

const POP_TIME := 0.15
const FADE_TIME := 0.6

var title := ""      # "ENEMY", "DANGER", "TAG" or "" for a plain location ping
var color := Color.WHITE
var life := 6.0
var age := 0.0

@onready var icon: Sprite3D = $Icon
@onready var label: Label3D = $Label


func setup(col: Color, text: String, lifetime: float) -> void:
	color = col
	title = text
	life = lifetime


func _ready() -> void:
	icon.modulate = color
	label.modulate = color.lightened(0.6)
	_update()


func _process(delta: float) -> void:
	age += delta
	if age >= life:
		queue_free()
		return
	_update()


## How visible the ping is right now (0..1): used by the minimap too.
func alpha() -> float:
	return clampf((life - age) / FADE_TIME, 0.0, 1.0)


func _update() -> void:
	var a := alpha()
	var pop := clampf(age / POP_TIME, 0.0, 1.0)
	icon.scale = Vector3.ONE * lerpf(1.8, 1.0, pop)
	icon.position.y = 0.6 + sin(age * 4.0) * 0.05
	icon.modulate.a = a
	label.modulate.a = a
	label.outline_modulate.a = 0.85 * a
	var cam := get_viewport().get_camera_3d()
	var dist := 0
	if cam:
		dist = roundi(cam.global_position.distance_to(global_position))
	label.text = ("%s\n" % title if title != "" else "") + "%d m" % dist
