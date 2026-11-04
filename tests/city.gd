extends Node
## Random city layouts are sound: no buildings overlapping each other, standing on
## a road or crossing the fence; every building faces a street; spawn zones and
## Tag spots aren't inside buildings. 20 seeds per size, then one full build of a
## large city (timed). Exits 0 on a pass:
##   godot --headless --path . res://tests/city.tscn

var _fails := 0


func _fail(why: String) -> void:
	_fails += 1
	if _fails <= 15:
		printerr("FAIL ", why)


static func _r(a: Array) -> Rect2:
	return Rect2(a[0], a[1], a[2] - a[0], a[3] - a[1])


func _ready() -> void:
	var stats := {}
	for size in ["small", "medium", "large"]:
		var a: Array = MapData.SIZES[size].rect
		var area := Rect2(a[0], a[1], a[2] - a[0], a[3] - a[1])
		var nb := 0
		var nt := 0
		for seed in range(1, 21):
			var l := CityGen.generate(size, seed * 7919)
			var rects := []
			for b in l.buildings:
				rects.append(_r(b[3]))
			var roads := []
			for r in l.roads:
				roads.append(_r(r))
			nb += rects.size()
			for i in rects.size():
				var r: Rect2 = rects[i]
				var tag := "%s seed %d %s" % [size, seed, l.buildings[i][1]]
				if not area.encloses(r):
					_fail("%s crosses the fence" % tag)
				for k in range(i + 1, rects.size()):
					if r.grow(14.0).intersects(rects[k]):  # at least 2.8 m between buildings... minus snapping slack
						_fail("%s is too close to %s" % [tag, l.buildings[k][1]])
				var near := INF
				for rd: Rect2 in roads:
					if rd.grow(10.0).intersects(r):
						_fail("%s stands on a road" % tag)
					near = minf(near, _gap(r, rd))
				# Faces a street (or backs onto the fence, at the edge of the map).
				var edge := minf(minf(r.position.x - area.position.x, area.end.x - r.end.x), minf(r.position.y - area.position.y, area.end.y - r.end.y))
				if near > 80.0 and edge > 80.0:
					_fail("%s is %.0f m from any street" % [tag, near / 10.0])
			var seen := {}
			for b in l.buildings:
				if seen.has(b[1]):
					_fail("%s seed %d: two buildings named %s" % [size, seed, b[1]])
				seen[b[1]] = true
			for d in l.spawn_dots + l.objectives:
				var p := Vector2(d[0], d[1])
				for i in rects.size():
					var b: Array = l.buildings[i]
					if rects[i].has_point(p) and not (d.size() > 2 and d[2] == b[1]):
						_fail("%s seed %d: point %s inside %s" % [size, seed, p, b[1]])
			for rd: Rect2 in roads:
				for rd2: Rect2 in roads:
					if rd != rd2 and rd.intersects(rd2):
						nt += 1
		stats[size] = "%.1f buildings per city" % (nb / 20.0)
	print("CITY ", stats)
	var t0 := Time.get_ticks_msec()
	var parent := Node3D.new()
	add_child(parent)
	var mb := MapBuilder.new()
	mb.build(parent, "large", 12345)
	print("CITY large build: %d buildings, %d lights, %d ms" % [mb.buildings.size(), mb.lights.size(), Time.get_ticks_msec() - t0])
	parent.free()  # the checks below build their own cities in the same space
	await get_tree().physics_frame
	await _check_sniper_walls()
	await _check_upper_tags()
	print("TEST PASS" if _fails == 0 else "TEST FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails else 0)


## Gap between two rects (0 if they touch or overlap).
static func _gap(a: Rect2, b: Rect2) -> float:
	var dx := maxf(0.0, maxf(b.position.x - a.end.x, a.position.x - b.end.x))
	var dy := maxf(0.0, maxf(b.position.y - a.end.y, a.position.y - b.end.y))
	return Vector2(dx, dy).length()


## The server's wall check for hits: the sniper gets through one wall, never two.
func _check_sniper_walls() -> void:
	var walls := Node3D.new()
	add_child(walls)
	walls.position = Vector3(0, 500, 0)  # far above the city
	for x in [0.0, 4.0]:
		var body := StaticBody3D.new()
		body.collision_layer = MapBuilder.L_WALL
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(MapBuilder.WALL_T, 4, 4)
		shape.shape = box
		body.add_child(shape)
		body.position = Vector3(x, 0, 0)
		walls.add_child(body)
	await get_tree().physics_frame
	var space := walls.get_world_3d().direct_space_state
	var o := Vector3(-3, 500, 0)
	var one := Game.in_sight(space, o, Vector3(2, 500, 0), true)
	var two := Game.in_sight(space, o, Vector3(7, 500, 0), true)
	var rifle := Game.in_sight(space, o, Vector3(2, 500, 0), false)
	if not one or two or rifle:
		_fail("wall check: sniper through one wall %s, two walls %s, rifle through one %s" % [one, two, rifle])
	walls.queue_free()


## Tag spots up a building's floors stand on that floor, with room to stand.
func _check_upper_tags() -> void:
	var up := 0
	var total := 0
	for seed in range(1, 21):
		for o in CityGen.generate("large", seed * 7919).objectives:
			total += 1
			up += 1 if o[3] > 0 else 0
	print("CITY Tag spots above the ground floor: %d of %d" % [up, total])
	if up == 0:
		_fail("no Tag spot is ever above the ground floor")
	var parent := Node3D.new()
	add_child(parent)
	for seed in range(1, 11):
		var mb := MapBuilder.new()
		mb.build(parent, "large", seed)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var space := parent.get_world_3d().direct_space_state
		var body := CapsuleShape3D.new()
		body.radius = 0.4
		body.height = 1.7
		for o in mb.objectives:
			var p: Vector3 = o.pos
			if p.y < 0.1:
				continue
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 1.0, 0), p - Vector3(0, 0.5, 0), MapBuilder.L_FLOOR | MapBuilder.L_SOLID))
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = body
			q.transform = Transform3D(Basis.IDENTITY, p + Vector3(0, 0.95, 0))
			q.collision_mask = MapBuilder.L_WALL | MapBuilder.L_FLOOR | MapBuilder.L_SOLID
			var blocked := not space.intersect_shape(q, 1).is_empty()
			if hit.is_empty() or absf(hit.position.y - p.y) > 0.2 or blocked:
				_fail("seed %d: Tag spot %s at %.1f m up: floor %s, blocked %s" % [seed, o.name, p.y, "missing" if hit.is_empty() else "%.2f" % hit.position.y, blocked])
		for c in parent.get_children():
			c.free()
