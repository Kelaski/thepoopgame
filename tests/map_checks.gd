extends Node
## The rules a generated town must keep, checked on maps built for real: rooms have what they're for,
## every door can swing and be walked up to, every flight of stairs is usable and every floor can
## be walked to. Run headless; exits 0 on a pass.
##   one of each size:  godot --headless --path . res://tests/map_checks.tscn
##   all 25 maps:       godot --headless --path . res://tests/map_checks.tscn -- --full
##   chosen maps:       godot --headless --path . res://tests/map_checks.tscn -- large:4 small:1,2

const QUICK := {"classic": [1], "small": [1], "medium": [2], "large": [3]}
const FULL_SEEDS := [1, 2, 3, 4, 5, 6, 7, 8]
const SECLUDED := ["public_restroom", "restroom", "auditorium"]
const WANTED := ["screen_wall", "bookshelf", "toilet_stall", "toilet", "shower"]
const WALK_STEP := 0.5

var _failed := 0
var _walker := PhysicsShapeQueryParameters3D.new()


func _check(ok: bool, what: String) -> void:
	if not ok:
		print("FAIL ", what)
		_failed += 1


func _ready() -> void:
	var walker_shape := CapsuleShape3D.new()
	walker_shape.radius = 0.3
	walker_shape.height = 1.5
	_walker.shape = walker_shape
	_walker.collision_mask = GeoMask.WALL
	var maps := _maps_to_check()
	for kind: String in maps:
		for map_seed: int in maps[kind]:
			await _check_map(kind, map_seed)
	print("TEST PASS" if _failed == 0 else "TEST FAIL (%d)" % _failed)
	get_tree().quit(1 if _failed else 0)


func _maps_to_check() -> Dictionary:
	var args := OS.get_cmdline_user_args()
	if args.has("--full"):
		return {"classic": [1], "small": FULL_SEEDS, "medium": FULL_SEEDS, "large": FULL_SEEDS}
	var chosen := {}
	for arg in args:
		if ":" in arg:
			chosen[arg.get_slice(":", 0)] = Array(arg.get_slice(":", 1).split(",")).map(func(x): return int(x))
	return chosen if not chosen.is_empty() else QUICK


func _check_map(kind: String, map_seed: int) -> void:
	var what := "%s %d" % [kind, map_seed]
	BuildingBuilder.room_log = []
	BuildingBuilder.flight_log = []
	var log := []
	GeoBatch.recorder = log
	var holder := Node3D.new()
	add_child(holder)
	var lv := Level.new()
	lv.build(holder, kind, map_seed)
	GeoBatch.recorder = null
	_check_rooms(what, log)
	# Physics needs a couple of frames to know the new bodies.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := get_viewport().world_3d.direct_space_state
	_check_doors(what, lv, space)
	_check_flights(what, lv, space)
	_check_walks(what, lv, space)
	print("MAP %s: %d doors, %d flights, %d rooms" % [what, lv.doors.size(), BuildingBuilder.flight_log.size(), BuildingBuilder.room_log.size()])
	holder.free()


# ------------------------------------------------------------------ rooms

func _check_rooms(what: String, log: Array) -> void:
	var props := {}
	for e: Array in log:
		var tag := String(e[0])
		if tag.begins_with("prop#") and tag.get_slice(" ", 1) in WANTED:
			if not props.has(tag.get_slice(" ", 1)):
				props[tag.get_slice(" ", 1)] = []
			props[tag.get_slice(" ", 1)].append(e)
	var library_shelves := {}  # building id -> bookshelves in all its library rooms
	for r: Dictionary in BuildingBuilder.room_log:
		var tag := "%s b%d L%d %s %s" % [what, r.building, r.level, r.kind, r.rect]
		var blocked := "front %d blocked %s" % [r.front, r.blocked]
		_check(r.kind not in SECLUDED or r.walled, "%s is open to the floor" % tag)
		_check(r.kind != "auditorium" or _count(props, "screen_wall", r) > 0, "%s has no screen (%s)" % [tag, blocked])
		_check(r.kind != "public_restroom" or _count(props, "toilet_stall", r) + _count(props, "toilet", r) > 0, "%s has no toilets (%s)" % [tag, blocked])
		_check(r.kind != "bathroom" or (_count(props, "toilet", r) > 0 and _count(props, "shower", r) > 0), "%s lacks a toilet or shower (%s)" % [tag, blocked])
		_check(minf(r.rect.size.x, r.rect.size.y) >= 2.2, "%s is a squeeze" % tag)
		if r.kind in ["stacks", "school_library"]:
			library_shelves[r.building] = library_shelves.get(r.building, 0) + _count(props, "bookshelf", r)
	for building: int in library_shelves:
		_check(library_shelves[building] > 0, "%s b%d: a library with no bookshelves" % [what, building])


## How many of a prop stand in a room. A prop is many boxes, so they're counted by its tag.
func _count(props: Dictionary, prefab: String, r: Dictionary) -> int:
	var area := (r.rect as Rect2).grow(0.05)
	var found := {}
	for e: Array in props.get(prefab, []):
		if area.has_point(Vector2(e[1].x, e[1].z)) and e[1].y > r.y - 0.1 and e[1].y < r.y + 3.5:
			found[e[0]] = true
	return found.size()


# ------------------------------------------------------------------ doors

## Open either way nothing may stand in the door's path, and the floor each side must be clear.
func _check_doors(what: String, lv: Level, space: PhysicsDirectSpaceState3D) -> void:
	for door: Door in lv.doors:
		var hinge := door.global_position
		for angle: float in [Door.OPEN_ANGLE, -Door.OPEN_ANGLE, 0.0]:
			var box := BoxShape3D.new()
			var q := PhysicsShapeQueryParameters3D.new()
			var basis := Basis(Vector3.UP, door.base_yaw + deg_to_rad(angle))
			if angle == 0.0:
				box.size = Vector3(door.width - 0.3, 1.2, 2.0)
				q.transform = Transform3D(basis, hinge + basis * Vector3(door.width * 0.5, 0.9, 0))
			else:
				# Starts past the hinge, which always sits in its own wall.
				box.size = Vector3(door.width - 0.35, 2.0, 0.06)
				q.transform = Transform3D(basis, hinge + basis * Vector3(0.25 + (door.width - 0.35) * 0.5, 1.2, 0))
			q.shape = box
			q.collision_mask = GeoMask.WALL
			var hit := space.get_rest_info(q)
			if not hit.is_empty():
				_check(false, "%s: door at %s, %s, hits something at %s" % [what, hinge.snappedf(0.01), "walking up to it" if angle == 0.0 else "swinging", (hit.point as Vector3).snappedf(0.01)])
				break


# ------------------------------------------------------------------ stairs

func _flights_in(b: Dictionary) -> Array:
	var r: Rect2 = b.rect
	return BuildingBuilder.flight_log.filter(func(f): return r.has_point(Vector2(f[0].x, f[0].z)))


## Every floor but the top has a flight up, with room to walk onto it, along it and off it.
func _check_flights(what: String, lv: Level, space: PhysicsDirectSpaceState3D) -> void:
	for b in lv.layout.buildings:
		if b.floors >= 2:
			var tops := {}
			for f: Array in _flights_in(b):
				tops[snappedf(maxf(f[0].y, f[1].y), 0.1)] = true
			_check(tops.size() >= b.floors - 1, "%s b%d %s: %d floors but stairs reach only %d" % [what, b.id, b.theme, b.floors, tops.size() + 1])
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.6
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = capsule
	for f: Array in BuildingBuilder.flight_log:
		var a: Vector3 = f[0]
		var b: Vector3 = f[1]
		var dir := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
		q.collision_mask = GeoMask.WALL | GeoMask.FLOOR
		for t: float in [0.15, 0.35, 0.5, 0.65, 0.85]:
			q.transform = Transform3D(Basis.IDENTITY, a.lerp(b, t) + Vector3(0, 1.15, 0))
			if not space.get_rest_info(q).is_empty():
				_check(false, "%s %s: something on the stairs at %s" % [what, f[3], a.lerp(b, t).snappedf(0.01)])
				break
		q.collision_mask = GeoMask.WALL
		for end: Vector3 in [a - dir * 0.9, b + dir * 0.9]:
			q.transform = Transform3D(Basis.IDENTITY, end + Vector3(0, 1.0, 0))
			_check(space.get_rest_info(q).is_empty(), "%s %s: the end of the stairs at %s is blocked" % [what, f[3], end.snappedf(0.01)])


# ------------------------------------------------------------------ walking the floors

## From the street to the first flight, and from the top of each flight to the next one up.
func _check_walks(what: String, lv: Level, space: PhysicsDirectSpaceState3D) -> void:
	for b in lv.layout.buildings:
		if b.floors < 2:
			continue
		var flights := _flights_in(b)
		flights.sort_custom(func(f, g): return minf(f[0].y, f[1].y) < minf(g[0].y, g[1].y))
		var tops := []
		var bottoms := []
		# A switchback is two flights, joined half way up: only the ends on a floor count.
		for f: Array in flights:
			var lo: Vector3 = f[0] if f[0].y < f[1].y else f[1]
			var hi: Vector3 = f[1] if f[0].y < f[1].y else f[0]
			var dir := Vector3(hi.x - lo.x, 0, hi.z - lo.z).normalized()
			var floor_y := ProcGen.level_y(b, _level_at(b, lo.y))
			if absf(lo.y - floor_y) < 0.2 or lo.y < 0.2:
				bottoms.append(Vector3(lo.x, maxf(floor_y, 0.0), lo.z) - dir)
			if absf(hi.y - ProcGen.level_y(b, _level_at(b, hi.y))) < 0.2:
				tops.append(hi + dir)
		if bottoms.is_empty():
			continue
		var r: Rect2 = b.rect
		_check(_walk(bottoms[0], r, space, func(c: Vector2): return not r.has_point(c)), "%s b%d %s: the street can't reach the stairs at %s" % [what, b.id, b.theme, bottoms[0].snappedf(0.01)])
		for i in tops.size():
			if i + 1 < bottoms.size():
				var goal := Vector2(bottoms[i + 1].x, bottoms[i + 1].z)
				_check(_walk(tops[i], r, space, func(c: Vector2): return c.distance_to(goal) < 0.6), "%s b%d %s: floor %d can't reach the next stairs up" % [what, b.id, b.theme, i + 1])


func _level_at(b: Dictionary, y: float) -> int:
	var best := 0
	for level in b.floors + 1:
		if ProcGen.level_y(b, level) <= y + 0.1:
			best = level
	return best


## Flood fill on a grid at the start's height until done(cell) is true. Doors don't block it.
func _walk(start: Vector3, r: Rect2, space: PhysicsDirectSpaceState3D, done: Callable) -> bool:
	var area := r.grow(2.5)
	var seen := {}
	var todo := [Vector2(start.x, start.z)]
	while not todo.is_empty():
		var c: Vector2 = todo.pop_back()
		var key := Vector2i((c / WALK_STEP).round())
		if seen.has(key) or not area.has_point(c):
			continue
		seen[key] = true
		_walker.transform = Transform3D(Basis.IDENTITY, Vector3(c.x, start.y + 1.25, c.y))
		if not space.intersect_shape(_walker, 1).is_empty():
			continue
		if done.call(c):
			return true
		for d: Vector2 in [Vector2(WALK_STEP, 0), Vector2(-WALK_STEP, 0), Vector2(0, WALK_STEP), Vector2(0, -WALK_STEP)]:
			todo.append(c + d)
	return false
