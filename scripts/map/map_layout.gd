class_name MapLayout extends RefCounted
## The plan of a map in metres (x, z on the ground). Classic and procedural maps both
## produce one of these, and MapBuilder turns it into the 3D level on every peer.

var kind := "classic"
var map_seed := 0
var bounds := Rect2()
## {points: PackedVector2Array, width: float}
var roads: Array = []
## {id, name, theme, rect: Rect2, floors: int, floor_h: float, floor_hs: storey heights, ground first}
var buildings: Array = []
## {name, rect: Rect2, pond: Rect2, playground: Rect2}
var parks: Array = []
## Team spawn spots (the sketch's purple dots).
var spawns: Array[Vector2] = []
## Tag spots (the sketch's red dots). {pos: Vector2, name: String}
var objectives: Array = []
## Crane-held beams between rooftops: [building id, building id].
var bridges: Array = []
## Where a road ends on another road: {pos, dir (along the arm, away from the junction), road, through}
var junctions: Array = []

const ROAD_NAMES := ["Main St", "Oak Ave", "Maple St", "Harbor Rd", "Elm St", "Union Ave", "Park Ln", "Mill Rd", "Pine St", "Station Rd", "Lake Ave", "King St", "Bay Rd", "Hill St", "Cedar Ave", "Dock St"]


## Runs each road end onto the road it nearly reaches, so every street meets at a proper junction,
## and names the roads.
func connect_roads(snap: float) -> void:
	for i in roads.size():
		var road: Dictionary = roads[i]
		road["name"] = ROAD_NAMES[i % ROAD_NAMES.size()]
		var pts: PackedVector2Array = road.points
		for end: int in [0, pts.size() - 1]:
			var best := Vector2.ZERO
			var best_d := snap
			var through := {}
			for other in roads:
				if other == road:
					continue
				var o_pts: PackedVector2Array = other.points
				for k in o_pts.size() - 1:
					var c := Geometry2D.get_closest_point_to_segment(pts[end], o_pts[k], o_pts[k + 1])
					if c.distance_to(pts[end]) < best_d:
						best_d = c.distance_to(pts[end])
						best = c
						through = other
			if through.is_empty():
				continue
			pts[end] = best
			var next := pts[1] if end == 0 else pts[pts.size() - 2]
			junctions.append({"pos": best, "dir": (next - best).normalized(), "road": road, "through": through})
		road.points = pts


## A Tag spot inside a building goes on a random floor, or on the roof if stairs reach it.
func raise_objectives(rng: RandomNumberGenerator) -> void:
	for o in objectives:
		o["y"] = 0.0
		for b in buildings:
			if (b.rect as Rect2).has_point(o.pos):
				var top: int = b.floors if BuildingBuilder.has_roof_access(b.theme, b.floors) else b.floors - 1
				o["y"] = ProcGen.level_y(b, rng.randi_range(0, top))


## Wider open ground around the map: moves the edges out by a share of its size, in total, split between
## both sides. Everything stays where it is, and roads that ran to the old edge reach the new one.
func expand_edges(share: float) -> void:
	var inner := bounds.grow(-4.0)
	var grown := bounds.grow_individual(bounds.size.x * share * 0.5, bounds.size.y * share * 0.5, bounds.size.x * share * 0.5, bounds.size.y * share * 0.5)
	for road in roads:
		var pts: PackedVector2Array = road.points
		for end: int in [0, pts.size() - 1]:
			if inner.has_point(pts[end]):
				continue
			var dir := (pts[end] - pts[1 if end == 0 else pts.size() - 2]).normalized()
			var to_edge := (grown.end.x - pts[end].x if dir.x > 0.0 else grown.position.x - pts[end].x) / dir.x if absf(dir.x) > 0.001 else INF
			var to_side := (grown.end.y - pts[end].y if dir.y > 0.0 else grown.position.y - pts[end].y) / dir.y if absf(dir.y) > 0.001 else INF
			pts[end] += dir * minf(to_edge, to_side)
		road.points = pts
	bounds = grown


## A building's name without the number procedural maps add.
static func display_name(raw: String) -> String:
	return raw.rstrip(" 0123456789")


func building(id: int) -> Dictionary:
	for b in buildings:
		if b.id == id:
			return b
	return {}


## Everything that must stay free of walls and clutter: spawn and Tag spots.
func keep_clear(radius: float) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for p in spawns:
		out.append(Rect2(p, Vector2.ZERO).grow(radius))
	for o in objectives:
		out.append(Rect2(o.pos, Vector2.ZERO).grow(radius))
	return out


## Structural rules every map must pass. Returns the list of problems (empty = valid).
func validate() -> Array[String]:
	var problems: Array[String] = []
	for i in buildings.size():
		var a: Rect2 = buildings[i].rect
		if not bounds.encloses(a):
			problems.append("Building %d leaves the map" % buildings[i].id)
		if buildings[i].floors > Level.RULES.max_floors:
			problems.append("Building %d is over %d stories" % [buildings[i].id, Level.RULES.max_floors])
		for j in range(i + 1, buildings.size()):
			if a.intersects(buildings[j].rect):
				problems.append("Buildings %d and %d overlap" % [buildings[i].id, buildings[j].id])
		for road in roads:
			if _road_hits(road, a):
				problems.append("Building %d sits on a road" % buildings[i].id)
				break
		for park in parks:
			if a.intersects(park.rect):
				problems.append("Building %d overlaps a park" % buildings[i].id)
	if spawns.size() < 2:
		problems.append("Needs at least 2 spawns")
	for p in spawns:
		if not bounds.grow(-1.0).has_point(p):
			problems.append("Spawn %s outside the map" % p)
	if objectives.is_empty():
		problems.append("Needs at least 1 objective")
	return problems


static func _road_hits(road: Dictionary, rect: Rect2) -> bool:
	var pts: PackedVector2Array = road.points
	var half: float = road.width * 0.5
	for i in pts.size() - 1:
		var grown := rect.grow(half - 0.01)
		if _segment_hits_rect(pts[i], pts[i + 1], grown):
			return true
	return false


static func _segment_hits_rect(a: Vector2, b: Vector2, r: Rect2) -> bool:
	if r.has_point(a) or r.has_point(b):
		return true
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(a, b, corners[i], corners[(i + 1) % 4]) != null:
			return true
	return false
