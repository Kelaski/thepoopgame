class_name Door
extends Node3D
## Hinged door. Opened with Interact, or slammed open by sprinting into it.
## State changes are broadcast by World.door_rpc so every peer sees the same thing.

const OPEN_ANGLE := 100.0

var idx := 0
var target := 0.0
var angle := 0.0
var speed := 320.0
var base_yaw := 0.0
var width := 1.5
var body: AnimatableBody3D

static var _mesh_cache := {}


func setup(i: int, hinge: Vector3, yaw: float, w: float, h: float, col: Color) -> void:
	idx = i
	width = w
	base_yaw = yaw
	name = "Door%d" % i
	position = hinge
	rotation.y = yaw
	body = AnimatableBody3D.new()
	body.collision_layer = MapBuilder.L_DOOR
	body.collision_mask = 0
	body.sync_to_physics = false
	body.position = Vector3(w * 0.5, h * 0.5, 0.0)
	add_child(body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(w, h, 0.08)
	cs.shape = bs
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = _box_mesh(Vector3(w, h, 0.08))
	mi.material_override = Mats.toon(col)
	body.add_child(mi)
	var knob := MeshInstance3D.new()
	knob.mesh = _box_mesh(Vector3(0.08, 0.08, 0.2))
	knob.material_override = Mats.toon(Color("d6a83a"))
	knob.position = Vector3(w * 0.4, -0.1, 0.0)
	body.add_child(knob)
	set_physics_process(false)


static func _box_mesh(s: Vector3) -> BoxMesh:
	var key := "%.2f_%.2f_%.2f" % [s.x, s.y, s.z]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var m := BoxMesh.new()
	m.size = s
	_mesh_cache[key] = m
	return m


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
