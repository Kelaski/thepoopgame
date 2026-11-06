class_name ParkBuilder extends RefCounted
## Lays out one park: lawn, cross paths meeting at a plaza, pond, a sandy playground, name signs at
## the entrances, then benches, lamps, flowers, trees and hedges wherever they fit.
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
# Grass, then paths, sit barely above the ground, so the park's paths are flush with the pavement.
const GRASS_TOP := 0.015
const PATH_TOP := 0.025

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
	_pond(park.pond)
	_playground(park.playground)
	_signs(str(park.name), layout)
	_fountain()
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
	_geo.box("water", Vector3(c.x, GRASS_TOP + 0.01, c.y), Vector3(pond.size.x, 0.02, pond.size.y), 0)
	for edge: Array in [[0.0, -0.5, 1.0, 0.0], [0.0, 0.5, 1.0, 0.0], [-0.5, 0.0, 0.0, 1.0], [0.5, 0.0, 0.0, 1.0]]:
		var e := c + pond.size * Vector2(edge[0], edge[1])
		_geo.box("rock", Vector3(e.x, 0.12, e.y), Vector3(edge[2] * pond.size.x + 0.4, 0.24, edge[3] * pond.size.y + 0.4), 0)
	_taken.append(pond.grow(0.4))
	for i in 6:
		var a := _rng.randf() * TAU
		var at := c + Vector2(cos(a), sin(a)) * (pond.size * 0.5 + Vector2.ONE * 0.9)
		_place("reeds" if i % 2 == 0 else "rock_pile", at.clamp(pond.position - Vector2.ONE, pond.end + Vector2.ONE), 0)


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
		_place("hedge", Vector2(x, r.position.y + 0.8), 0)
		_place("hedge", Vector2(x, r.end.y - 0.8), 0)
		x += 4.2
	var z := r.position.y + 2.8
	while z < r.end.y - 2.5:
		_place("hedge", Vector2(r.position.x + 0.8, z), 1)
		_place("hedge", Vector2(r.end.x - 0.8, z), 1)
		z += 4.2


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
