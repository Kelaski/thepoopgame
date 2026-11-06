extends Node
## Quick checks high above the map, in one local match: repeat wall jumps off one wall, the
## arc on landing, and grenades that start inside something. Exits 0 on a pass:
##   godot --headless --path . res://tests/movement.tscn -- --host --port=27205 --autostart=1 --size=small

var _failed := 0
var _lp: Player


func _check(ok: bool, what: String) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failed += 1


func _box(size: Vector3, pos: Vector3, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	body.add_child(shape)
	Game.world.add_child(body)
	body.global_position = pos
	return body


func _ready() -> void:
	get_tree().create_timer(60.0).timeout.connect(func() -> void:
		print("TEST FAIL: timed out")
		get_tree().quit(1))
	Engine.time_scale = 6.0  # through the countdown quickly
	add_child((load("res://assets/main.tscn") as PackedScene).instantiate())
	while Game.phase != Game.Phase.RUSH:
		await get_tree().process_frame
	Engine.time_scale = 1.0
	_lp = Game.world.local_player()
	_lp.passive = "sharpshooter"  # no movement perks
	await _wall_jumps()
	await _landing()
	await _grenades()
	print("TEST PASS" if _failed == 0 else "TEST FAIL (%d)" % _failed)
	get_tree().quit(1 if _failed else 0)


## A long wall on our right: run along it, keep holding D, and kick off it again and again.
func _wall_jumps() -> void:
	_box(Vector3(1, 200, 400), Vector3(3.0, 300, -100), MapBuilder.L_WALL)
	_lp.yaw = 0.0
	_lp.global_position = Vector3(1.4, 300, 0)
	_lp.velocity = Vector3(0, 2, -9)
	_lp.wall_jumps = 0
	await get_tree().physics_frame
	Input.action_press("move_right")
	Input.action_press("move_forward")
	var best := 0
	for i in 200:  # about 3.3 s
		if _lp.wallrunning:
			_lp._jump_buffer_t = 0.1  # press jump whenever we're on the wall
		best = maxi(best, _lp.wall_jumps)
		_lp.velocity.y = maxf(_lp.velocity.y, -4.0)  # no floor up here: don't fall out of the test
		await get_tree().physics_frame
	Input.action_release("move_right")
	Input.action_release("move_forward")
	_check(best >= 3, "3 or more wall jumps off one wall in the air, holding D (%d)" % best)


## Landing while moving forward with D held: the heading arcs round to the right.
func _landing() -> void:
	_box(Vector3(80, 0.2, 80), Vector3(-60, 299.9, 0), MapBuilder.L_FLOOR)
	_lp.yaw = 0.0
	_lp.global_position = Vector3(-60, 300.6, 0)
	_lp.velocity = Vector3(0, -2, -12)
	await get_tree().physics_frame
	Input.action_press("move_right")
	while not _lp.is_on_floor():
		_lp.velocity.x = 0.0
		_lp.velocity.z = -12.0
		await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var v := Vector2(_lp.velocity.x, _lp.velocity.z)
	_check(v.y < -9.0 and v.x < 6.0, "you don't snap sideways on landing (%s)" % v)
	for i in 48:  # 0.8 s
		await get_tree().physics_frame
	Input.action_release("move_right")
	v = Vector2(_lp.velocity.x, _lp.velocity.z)
	_check(v.x > 3.0 and absf(v.y) < 1.0, "you arc round to the way you're holding (%s)" % v)


## A grenade starting inside a wall blows up there, instead of flying out of its far side.
func _grenades() -> void:
	var w = Game.world
	_box(Vector3(2, 2, 2), Vector3(0, 500, 0), MapBuilder.L_WALL)
	await get_tree().physics_frame
	await get_tree().physics_frame
	w.add_grenade(9001, 1, Vector3(0, 500, 0), Vector3(10, 0, 0))
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not w._grenades.has(9001), "a grenade inside a wall explodes")
	# Fired while pressed against a wall: it starts on our side.
	var at := Vector3(0, 500, 3.0)
	_check(_lp._grenade_start(at, Vector3(0, 0, -1)).z > 1.0, "a grenade never starts past a wall you're up against")
