class_name ParkBuilder extends RefCounted
## Lays out one park: lawn, cross paths meeting at a plaza and, in big parks, a loop path lined with
## trees; a pond with a stone rim, lily pads and a dock; a sandy playground; a basketball court; name
## signs, map boards and bike racks at the entrances; then benches, lamps, flowers, trees and hedges.
## Everything scales to the park's size, so a pocket park and a big central park both read well.

const SIGN_SCENE: PackedScene = preload("res://assets/world/park_sign.tscn")
const PATH_WIDTH := 2.4
const PLAZA_RADIUS := 3.6
## Biggest first, so the large pieces always get a spot.
const PLAY_EQUIPMENT := ["slide_toy", "swing_set", "monkey_bars", "merry_go_round", "climbing_frame", "seesaw", "sandbox", "spring_rider", "spring_rider"]
## A fountain needs a park at least this wide both ways.
const FOUNTAIN_MIN_SIZE := 12.0
const SIGN_FOOTPRINT := Vector2(4.4, 1.0)
const CANOPY := 2.8
## A hedge's middle this far in from the edge, so all of it fits inside the park.
const HEDGE_INSET := 0.95
# Grass, then paths, sit barely above the ground, so the park's paths are flush with the pavement.
const GRASS_TOP := 0.015
const PATH_TOP := 0.025
## The loop path: its outer edge this far in from the park's edge, this wide, in parks this big (m).
const LOOP_INSET := 3.6
const LOOP_WIDTH := 2.0
const LOOP_MIN_SIZE := 30.0
## A basketball court, and the least room it needs (long, short).
const COURT_SIZE := Vector2(14.0, 8.0)
const COURT_MIN := Vector2(9.0, 6.5)

## Where the park's lamps stand, for the map's street lights.
var lamps: Array[Vector3] = []

var _geo: GeoBatch
var _root: Node3D
var _rng: RandomNumberGenerator
var _rect: Rect2
var _center: Vector2
var _taken: Array[Rect2]


func _init(geo: GeoBatch, root: Node3D, rng: RandomNumberGenerator, keep_clear: Array[Rect2]) -> void:
	_geo = geo
	_root = root
	_rng = rng
	_taken = keep_clear.duplicate()


func build(park: Dictionary, layout: MapLayout) -> void:
	_rect = park.rect
	_center = _rect.get_center()
	_lawn_and_paths()
	_loop(park)
	_pond(park.pond)
	_playground(park.playground)
	_court(park.get("court", Rect2()))
	_signs(str(park.name), layout)
	_fountain()
	_plaza_extras()
	_path_furniture()
	_scatter(["gazebo", "statue", "picnic_umbrella", "picnic_table", "picnic_table", "picnic_table"], 2.5)
	_hedges()
	_trees_and_bushes()


func _lawn_and_paths() -> void:
	var c := _center
	_geo.box("grass", Vector3(c.x, GRASS_TOP * 0.5, c.y), Vector3(_rect.size.x, GRASS_TOP, _rect.size.y), 0)
	_geo.box("pavement", Vector3(c.x, PATH_TOP * 0.5, c.y), Vector3(PATH_WIDTH, PATH_TOP, _rect.size.y), 0)
	_geo.box("pavement", Vector3(c.x, PATH_TOP * 0.5, c.y), Vector3(_rect.size.x, PATH_TOP, PATH_WIDTH), 0)
	var radius := minf(PLAZA_RADIUS, minf(_rect.size.x, _rect.size.y) * 0.5 - 0.5)
	_geo.cylinder("pavement", Vector3(c.x, PATH_TOP * 0.5 + 0.002, c.y), radius, radius, PATH_TOP, 0, Basis.IDENTITY, 20)
	_taken.append(Rect2(c.x - PATH_WIDTH * 0.5 - 0.2, _rect.position.y, PATH_WIDTH + 0.4, _rect.size.y))
	_taken.append(Rect2(_rect.position.x, c.y - PATH_WIDTH * 0.5 - 0.2, _rect.size.x, PATH_WIDTH + 0.4))
	_taken.append(Rect2(c, Vector2.ZERO).grow(radius + 0.2))


func _pond(pond: Rect2) -> void:
	if not pond.has_area():
		return
	var c := pond.get_center()
	var r := pond.size * 0.5
	var oval := Basis.from_scale(Vector3(1.0, 1.0, r.y / r.x))
	_geo.cylinder("rock", Vector3(c.x, GRASS_TOP + 0.008, c.y), r.x + 0.35, r.x + 0.35, 0.016, 0, Basis.from_scale(Vector3(1.0, 1.0, (r.y + 0.35) / (r.x + 0.35))), 28)
	_geo.cylinder("water", Vector3(c.x, GRASS_TOP + 0.014, c.y), r.x, r.x, 0.012, 0, oval, 28)
	_taken.append(pond.grow(0.4))
	_dock(pond)
	if minf(pond.size.x, pond.size.y) > 4.0:
		var lilies := c + Vector2(r.x * 0.35 * (1.0 if _rng.randf() < 0.5 else -1.0), r.y * 0.3)
		Clutter.place(_geo, "pond_lilies", Vector3(lilies.x, GRASS_TOP, lilies.y), _rng.randi_range(0, 3))
	# Reeds and stones round the rim.
	for i in 10:
		var a := TAU * (i + _rng.randf() * 0.6) / 10.0
		var at := c + Vector2(cos(a) * (r.x + 0.9), sin(a) * (r.y + 0.9))
		_place("reeds" if i % 3 != 0 else "rock_pile", at, 0)


## A short wooden pier out over the water, from the bank nearest the park's middle that has room.
func _dock(pond: Rect2) -> void:
	if minf(pond.size.x, pond.size.y) < 3.0:
		return
	var c := pond.get_center()
	var outs := [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
	outs.sort_custom(func(a: Vector2, b: Vector2): return a.dot(_center - c) > b.dot(_center - c))
	var water := pond.grow(0.4)
	for out: Vector2 in outs:
		var at := c + out * ((pond.size * 0.5 * out.abs()).length() - 0.6)  # over the water, its back end on the rim
		var size := _turned_size("dock", _turns_to(-out))
		var foot := Rect2(at - size * 0.5, size)
		if _taken.any(func(t): return not t.is_equal_approx(water) and foot.intersects(t)):
			continue
		_taken.append(foot)
		Clutter.place(_geo, "dock", Vector3(at.x, 0, at.y), _turns_to(-out))
		return


## A painted basketball court with a hoop at each end, as big as its quarter allows.
func _court(area: Rect2) -> void:
	if not area.has_area():
		return
	var along_x := area.size.x >= area.size.y
	var long := minf(COURT_SIZE.x, area.size.x if along_x else area.size.y)
	var short := minf(COURT_SIZE.y, area.size.y if along_x else area.size.x)
	var size := Vector2(long, short) if along_x else Vector2(short, long)
	var c := area.get_center()
	var court := Rect2(c - size * 0.5, size)
	_taken.append(court.grow(0.6))
	var tag := GeoBatch.tag
	GeoBatch.tag = "ground"
	_geo.box("court", Vector3(c.x, PATH_TOP * 0.5 + 0.002, c.y), Vector3(size.x + 1.0, PATH_TOP, size.y + 1.0), 0)
	var line := 0.08
	var y := PATH_TOP + 0.004
	for e: Array in [[Vector2(0, -0.5), Vector2(1, 0)], [Vector2(0, 0.5), Vector2(1, 0)], [Vector2(-0.5, 0), Vector2(0, 1)], [Vector2(0.5, 0), Vector2(0, 1)]]:
		var p: Vector2 = c + size * (e[0] as Vector2)
		var s: Vector2 = size * (e[1] as Vector2) + Vector2.ONE * line
		_geo.box("road_white", Vector3(p.x, y, p.y), Vector3(s.x, 0.004, s.y), 0)
	var mid := Vector3(size.x * 0.0 + line, 0.004, size.y) if along_x else Vector3(size.x, 0.004, line)
	_geo.box("road_white", Vector3(c.x, y, c.y), mid, 0)
	_geo.cylinder("road_white", Vector3(c.x, y, c.y), 1.2, 1.2, 0.004, 0, Basis.IDENTITY, 20)
	_geo.cylinder("court", Vector3(c.x, y + 0.001, c.y), 1.1, 1.1, 0.004, 0, Basis.IDENTITY, 20)
	GeoBatch.tag = tag
	# A hoop at each end, its rim facing up the court.
	var ends := [Vector2(1, 0), Vector2(-1, 0)] if along_x else [Vector2(0, 1), Vector2(0, -1)]
	for d: Vector2 in ends:
		var at := c + d * (long * 0.5 - 0.3)
		Clutter.place(_geo, "hoop", Vector3(at.x, 0, at.y), _turns_to(-d))
	# Benches for the players along one side.
	var side := Vector2(0, 1) if along_x else Vector2(1, 0)
	for k: float in [-0.25, 0.25]:
		var at := c + side * (short * 0.5 + 1.3) + Vector2(side.y, side.x) * long * k
		_place("bench", at, _turns_to(-side))


## The quarter-turns that point a prop's front (+Z) along v.
static func _turns_to(v: Vector2) -> int:
	return posmod(roundi(atan2(v.x, v.y) / (PI * 0.5)), 4)


## A rectangle of path inside the park's edge, broken where a feature stands in its way.
func _loop(park: Dictionary) -> void:
	if minf(_rect.size.x, _rect.size.y) < LOOP_MIN_SIZE:
		return
	var ring := _rect.grow(-(LOOP_INSET + LOOP_WIDTH * 0.5))
	var avoid: Array[Rect2] = []
	for key: String in ["pond", "playground", "court"]:
		if (park.get(key, Rect2()) as Rect2).has_area():
			avoid.append((park[key] as Rect2).grow(0.8))
	var corners := [ring.position, Vector2(ring.end.x, ring.position.y), ring.end, Vector2(ring.position.x, ring.end.y)]
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var length := a.distance_to(b)
		var tiles := maxi(int(length / 2.0), 1)
		for t in tiles:
			var p := a.lerp(b, (t + 0.5) / tiles)
			var along := (b - a).normalized()
			var size := Vector2(absf(along.x) * (length / tiles + 0.02) + absf(along.y) * LOOP_WIDTH, absf(along.y) * (length / tiles + 0.02) + absf(along.x) * LOOP_WIDTH)
			var tile := Rect2(p - size * 0.5, size)
			if avoid.any(func(r): return r.intersects(tile)):
				continue
			# A hair under the cross paths, so they never flicker where they meet.
			_geo.box("pavement", Vector3(p.x, PATH_TOP * 0.5 - 0.002, p.y), Vector3(size.x, PATH_TOP - 0.004, size.y), 0)
			_taken.append(tile.grow(0.2))
	# Trees line the outside of the loop.
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var out := (a + b) * 0.5 - _center
		out = Vector2(signf(out.x), 0.0) if absf(out.x) * _rect.size.y > absf(out.y) * _rect.size.x else Vector2(0.0, signf(out.y))
		var length := a.distance_to(b)
		var d := 4.0
		while d < length - 3.0:
			var p := a.lerp(b, d / length) + out * (LOOP_WIDTH * 0.5 + 1.1)
			var trunk := Rect2(p, Vector2.ZERO).grow(0.5)
			if not _hits_taken(trunk) and _rect.grow(-1.6).has_point(p):
				_taken.append(trunk)
				MapBuilder.tree(_geo, p, _rng)
			d += 7.0


## A drinking fountain by the plaza.
func _plaza_extras() -> void:
	var radius := minf(PLAZA_RADIUS, minf(_rect.size.x, _rect.size.y) * 0.5 - 0.5)
	for corner: Vector2 in [Vector2(1, 1), Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1)]:
		if _place("drinking_fountain", _center + corner * Vector2(radius + 1.0, PATH_WIDTH * 0.5 + 0.8), 0):
			return


## As much equipment as the sand holds, each piece kept clear of the rest.
func _playground(play: Rect2) -> void:
	if not play.has_area():
		return
	var c := play.get_center()
	_geo.box("sand", Vector3(c.x, GRASS_TOP + 0.005, c.y), Vector3(play.size.x, 0.01, play.size.y), 0)
	for prefab: String in PLAY_EQUIPMENT:
		for attempt in 12:
			var turns := _rng.randi_range(0, 3)
			var size := _turned_size(prefab, turns)
			var room := play.grow(-0.2)
			if size.x > room.size.x or size.y > room.size.y:
				continue
			var at := Vector2(_rng.randf_range(room.position.x + size.x * 0.5, room.end.x - size.x * 0.5), _rng.randf_range(room.position.y + size.y * 0.5, room.end.y - size.y * 0.5))
			if _place(prefab, at, turns, play):
				break


## A name sign beside each path entrance that faces a road.
func _signs(park_name: String, layout: MapLayout) -> void:
	var half := _rect.size * 0.5
	var entrances: Array = []
	for out: Vector2 in [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]:
		var mouth := _center + out * (half * out.abs()).length()
		if _near_road(mouth, layout):
			entrances.append([mouth, out])
	for entrance: Array in entrances:
		var out: Vector2 = entrance[1]
		var side := Vector2(-out.y, out.x)
		var at: Vector2 = entrance[0] - out * 0.9 + side * (PATH_WIDTH * 0.5 + SIGN_FOOTPRINT.x * 0.5 + 0.3)
		var foot_size := Vector2(SIGN_FOOTPRINT.x, SIGN_FOOTPRINT.y) if out.x == 0.0 else Vector2(SIGN_FOOTPRINT.y, SIGN_FOOTPRINT.x)
		var foot := Rect2(at - foot_size * 0.5, foot_size)
		if not _rect.encloses(foot) or _hits_taken(foot):
			continue
		_taken.append(foot)
		var sign_node: ParkSign = SIGN_SCENE.instantiate()
		_root.add_child(sign_node)
		sign_node.position = Vector3(at.x, 0, at.y)
		sign_node.rotation.y = atan2(out.x, out.y)
		sign_node.setup(park_name)
		var other_side: Vector2 = entrance[0] - out * 1.0 - side * (PATH_WIDTH * 0.5 + 1.2)
		if _place("info_board", other_side, _turns_to(out)):
			_place("bike_rack", other_side - side * 2.4, _turns_to(out))


static func _near_road(point: Vector2, layout: MapLayout) -> bool:
	for road in layout.roads:
		var pts: PackedVector2Array = road.points
		for i in pts.size() - 1:
			if point.distance_to(Geometry2D.get_closest_point_to_segment(point, pts[i], pts[i + 1])) < road.width * 0.5 + 4.0:
				return true
	return false


func _fountain() -> void:
	if minf(_rect.size.x, _rect.size.y) < FOUNTAIN_MIN_SIZE:
		return
	var foot := Rect2(_center, Vector2.ZERO).grow(Clutter.size_of("fountain").x * 0.5)
	for spot in _taken.slice(0, _taken.size() - 3):  # all but the paths and plaza it stands on
		if foot.intersects(spot):
			return
	_taken.append(foot)
	Clutter.place(_geo, "fountain", Vector3(_center.x, 0, _center.y), 0)


## Benches, lamps, flower beds and bins facing the paths, spaced along them.
func _path_furniture() -> void:
	var off := PATH_WIDTH * 0.5 + 0.75
	var c := _center
	var d := 5.5
	while d < maxf(_rect.size.x, _rect.size.y) * 0.5:
		for s: float in [-1.0, 1.0]:
			_place("bench", c + Vector2(off, s * d), 3)
			_place("bench", c + Vector2(-off, s * (d + 2.5)), 1)
			_place("bench", c + Vector2(s * d, off), 2)
			_place("bench", c + Vector2(s * (d + 2.5), -off), 0)
			for at: Vector2 in [c + Vector2(off + 1.2, s * (d + 2.0)), c + Vector2(s * (d + 2.0), -off - 1.2)]:
				if _place("park_lamp", at, 0):
					lamps.append(Vector3(at.x, Clutter.height_of("park_lamp") - 0.2, at.y))
			_place("flower_bed", c + Vector2(-off - 0.2, s * (d - 1.0)), 1)
			_place("flower_bed", c + Vector2(s * (d - 1.0), off + 0.2), 0)
			_place("trash_can", c + Vector2(off, s * (d + 1.6)), 0)
		d += 6.0


func _scatter(prefabs: Array, margin: float) -> void:
	for prefab: String in prefabs:
		for attempt in 14:
			if _place(prefab, _spot(margin), _rng.randi_range(0, 3)):
				break


## Along the edge, leaving gaps for the paths.
func _hedges() -> void:
	var r := _rect
	var x := r.position.x + 2.0
	while x < r.end.x - 1.5:
		_place("hedge", Vector2(x, r.position.y + HEDGE_INSET), 0)
		_place("hedge", Vector2(x, r.end.y - HEDGE_INSET), 0)
		x += 3.4
	var z := r.position.y + 2.8
	while z < r.end.y - 2.5:
		_place("hedge", Vector2(r.position.x + HEDGE_INSET, z), 1)
		_place("hedge", Vector2(r.end.x - HEDGE_INSET, z), 1)
		z += 3.4


func _trees_and_bushes() -> void:
	for attempt in int(_rect.get_area() / 30.0):
		var p := _spot(CANOPY + 0.2)
		var foot := Rect2(p, Vector2.ZERO).grow(CANOPY)
		if not _hits_taken(foot):
			_taken.append(foot)
			MapBuilder.tree(_geo, p, _rng)
	for attempt in int(_rect.get_area() / 60.0):
		_place("bush", _spot(1.0), 0)


func _spot(margin: float) -> Vector2:
	var r := _rect.grow(-margin)
	if not r.has_area():
		return _center
	return Vector2(_rng.randf_range(r.position.x, r.end.x), _rng.randf_range(r.position.y, r.end.y))


func _turned_size(prefab: String, turns: int) -> Vector2:
	var size := Clutter.size_of(prefab)
	return Vector2(size.y, size.x) if turns % 2 == 1 else size


func _hits_taken(foot: Rect2) -> bool:
	for other in _taken:
		if foot.intersects(other):
			return true
	return false


## Places a prop if its footprint is free. Equipment passes its sandpit, which others must stay out of.
func _place(prefab: String, at: Vector2, turns: int, inside := Rect2()) -> bool:
	var size := _turned_size(prefab, turns)
	var foot := Rect2(at - size * 0.5, size)
	if not _rect.grow(-0.3).encloses(foot):
		return false
	if inside.has_area() and not inside.encloses(foot):
		return false
	if _hits_taken(foot.grow(0.25)):
		return false
	_taken.append(foot)
	Clutter.place(_geo, prefab, Vector3(at.x, 0, at.y), turns)
	return true
