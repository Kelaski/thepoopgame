class_name Door
extends Node3D
## Hinged door (assets/models/door.tscn). Opened with Interact, or slammed open by
## sprinting into it. State changes are broadcast by World.door_rpc so every peer
## sees the same thing.
##
## The scene is built for a DESIGN_W x DESIGN_H doorway with the hinge at the
## origin. setup() stretches it to the actual doorway: the Panel is scaled, the
## collision Shape resized, and the other parts (the knob) moved to match.

const OPEN_ANGLE := 100.0
const DESIGN_W := 1.7
const DESIGN_H := 2.45

var idx := 0
var target := 0.0
var angle := 0.0
var speed := 320.0
var base_yaw := 0.0
var width := 1.5
@onready var body: AnimatableBody3D = $Body


func setup(i: int, hinge: Vector3, yaw: float, w: float, h: float, col: Color) -> void:
	idx = i
	width = w
	base_yaw = yaw
	name = "Door%d" % i
	position = hinge
	rotation.y = yaw
	var b: AnimatableBody3D = get_node("Body")  # setup runs before _ready
	var k := Vector3(w / DESIGN_W, h / DESIGN_H, 1.0)
	b.position *= k
	for c in b.get_children():
		if c is CollisionShape3D and c.shape is BoxShape3D:
			c.shape.size *= k
		elif c.name == "Panel":
			c.scale = k
		elif c is Node3D:
			c.position *= k
	var panel := b.get_node_or_null("Panel") as GeometryInstance3D
	if panel:
		panel.material_override = Mats.toon(col)  # the building's door colour
	set_physics_process(false)


func is_open() -> bool:
	return absf(target) > 1.0


## Angle that swings the door away from a position (so it never hits the opener).
func away_from(pos: Vector3) -> float:
	var rel := pos - global_position
	var local := Basis(Vector3.UP, base_yaw).inverse() * rel
	return OPEN_ANGLE if local.z > 0.0 else -OPEN_ANGLE


func set_target(t: float, fast: bool) -> void:
	target = t
	speed = 900.0 if fast else 320.0
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	angle = move_toward(angle, target, speed * delta)
	rotation.y = base_yaw + deg_to_rad(angle)
	if is_equal_approx(angle, target):
		set_physics_process(false)
