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
		var touching := 0
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
					# Neighbours either touch (a strip mall) or leave at least an alley, never overlap.
					var g := _gap(r, rects[k])
					if r.grow(-1.0).intersects(rects[k]):
						_fail("%s overlaps %s" % [tag, l.buildings[k][1]])
					elif g > 0.5 and g < 14.0:
						_fail("%s is %.1f m from %s (too narrow for an alley)" % [tag, g / 10.0, l.buildings[k][1]])
					elif g <= 0.5 and not r.grow(-1.0).intersects(rects[k]):
						touching += 1
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
		stats[size] = "%.1f buildings per city, %d touching pairs" % [nb / 20.0, touching]
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
	await _check_mantles()
	_check_dock_doors()
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


## Mantling finds the top of a thin wall, not the floor behind it: a window sill
## (with the room's floor behind) and a roof parapet (with the roof behind).
func _check_mantles() -> void:
	var stage := Node3D.new()
	add_child(stage)
	stage.position = Vector3(0, 300, 0)
	var floor := StaticBody3D.new()
	floor.collision_layer = MapBuilder.L_FLOOR
	var fs := CollisionShape3D.new()
	fs.shape = BoxShape3D.new()
	fs.shape.size = Vector3(30, 0.2, 4)
	fs.position = Vector3(0, -0.1, -2.15)  # the floor inside / the roof, behind the wall
	floor.add_child(fs)
	stage.add_child(floor)
	var window: Node3D = load("res://assets/building/wall_window_small.tscn").instantiate()
	stage.add_child(window)
	var parapet: Node3D = load("res://assets/building/parapet.tscn").instantiate()
	parapet.position = Vector3(8, 0, 0)
	stage.add_child(parapet)
	var p: Player = load("res://assets/models/player.tscn").instantiate()
	p.peer_id = 999
	stage.add_child(p)
	p.set_process(false)  # a remote player follows its (missing) network updates
	var cases := [["window sill", Vector3(0, 0.2, 0.15 + Player.RADIUS + 0.02), 0.6], ["roof parapet", Vector3(8, -0.4, 0.15 + Player.RADIUS + 0.02), 1.5]]
	for c in cases:
		p.position = c[1]
		await get_tree().physics_frame
		await get_tree().physics_frame
		var h: float = p._mantle_height(Vector3(0, 0, -1))
		if absf(h - float(c[2])) > 0.05:
			_fail("mantle at a %s: climbs %.2f m, should be %.2f m" % [c[0], h, c[2]])
		else:
			print("CITY mantle at a %s: %.2f m" % [c[0], h])
	stage.queue_free()


## Loading dock doors (4 m wide) only on the ground floor, wholly inside their building.
func _check_dock_doors() -> void:
	var n := 0
	var parent := Node3D.new()
	add_child(parent)
	for seed in range(1, 16):
		var mb := MapBuilder.new()
		mb.build(parent, "large", seed * 31)
		for d in mb.wide_decor:
			n += 1
			var face: Vector3 = d[0]
			var along: Vector3 = d[1]
			var inside := false
			for b in mb.buildings:
				var r: Rect2 = b.rect.grow(0.05)
				if r.has_point(Vector2(face.x - along.x, face.z - along.z)) and r.has_point(Vector2(face.x + along.x, face.z + along.z)):
					inside = true
			if face.y > 0.5 or not inside:
				_fail("seed %d: loading dock door at %s is %s" % [seed * 31, face, "above the ground floor" if face.y > 0.5 else "past its building's wall"])
		for c in parent.get_children():
			c.free()
	parent.free()
	print("CITY loading dock doors checked: %d" % n)
