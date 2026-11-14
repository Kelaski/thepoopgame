extends Node
## Maps: every kind builds, over several seeds, passing the layout rules, with spawn zones
## and Tag spots on open ground and doors placed. Run headless; exits 0 on a pass.

var _failed := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		print("FAIL ", what)
		_failed += 1


func _ready() -> void:
	# Same plan from the same seed on every peer.
	var a := Level.plan("medium", 12345)
	var b := Level.plan("medium", 12345)
	_check(a.buildings.size() == b.buildings.size() and a.spawns == b.spawns, "a seed gives the same map every time")
	for kind: String in Level.SIZE_ORDER:
		await _check_map(kind, 42)
		if not Level.handmade(kind):
			for map_seed in 30:  # planning is quick; the rules are checked on the plan
				for problem in Level.plan(kind, map_seed + 1).validate():
					_check(false, "%s %d: %s" % [kind, map_seed + 1, problem])
	print("TEST PASS" if _failed == 0 else "TEST FAIL (%d)" % _failed)
	get_tree().quit(1 if _failed else 0)


func _check_map(kind: String, map_seed: int) -> void:
	var what := "%s %d" % [kind, map_seed]
	var holder := Node3D.new()
	add_child(holder)
	var lv := Level.new()
	lv.build(holder, kind, map_seed)
	await lv.settle_objectives()
	await get_tree().physics_frame
	for problem in lv.layout.validate():
		_check(false, "%s: %s" % [what, problem])
	_check(lv.spawn_dots.size() >= 2 and not lv.objectives.is_empty() and not lv.doors.is_empty(), "%s: has spawns, Tag spots and doors" % what)
	var space := holder.get_world_3d().direct_space_state
	var shape := CapsuleShape3D.new()
	shape.radius = 0.38
	shape.height = 1.7
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collision_mask = MapBuilder.L_WALL | MapBuilder.L_FLOOR
	for dot: Vector3 in lv.spawn_dots:
		q.transform = Transform3D(Basis.IDENTITY, dot + Vector3(0, 1.0, 0))
		_check(space.intersect_shape(q, 1).is_empty(), "%s: spawn zone %s is open" % [what, dot])
	# The ground and the boundary stop everything; Phantom's floor drop stays on the ground.
	var ray := PhysicsRayQueryParameters3D.create(Vector3(lv.bounds.get_center().x, 5, lv.bounds.get_center().y), Vector3(lv.bounds.get_center().x, -5, lv.bounds.get_center().y), MapBuilder.L_SOLID)
	_check(not space.intersect_ray(ray).is_empty(), "%s: the ground is solid" % what)
	var c := lv.bounds.get_center()
	var edge := PhysicsRayQueryParameters3D.create(Vector3(c.x, 2, c.y), Vector3(lv.bounds.end.x + 20.0, 2, c.y), MapBuilder.L_SOLID)
	_check(not space.intersect_ray(edge).is_empty(), "%s: the fence holds" % what)
	print("MAP %s: %d buildings, %d Tag spots, %d spawn zones, %d doors, %.0fx%.0f" % [what, lv.buildings.size(), lv.objectives.size(), lv.spawn_dots.size(), lv.doors.size(), lv.bounds.size.x, lv.bounds.size.y])
	holder.free()
