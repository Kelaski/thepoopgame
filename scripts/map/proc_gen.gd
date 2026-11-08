class_name ProcGen
## Builds a MapLayout from a seed using the Classic map's rules and themes: blocks split by
## roads, lots split by alleys, then a themed building per lot. Same seed = same map on every peer.

## Which themes can appear, with the floor range and floor height the Classic map gives them.
const PRESETS := [
	["warehouse", "Warehouse", 1, 3, 6.0], ["school", "School", 2, 4, 4.0], ["theater", "Theater", 1, 3, 5.0],
	["bank", "Bank", 1, 3, 4.5], ["diner", "Diner", 1, 1, 4.5], ["arcade", "Arcade", 1, 3, 4.0],
	["club", "Nightclub", 1, 3, 4.5], ["bar", "Bar", 1, 1, 4.0], ["apartments", "Apartments", 3, 7, 3.6],
	["mall", "Mall", 2, 4, 5.0], ["motel", "Motel", 1, 3, 3.8], ["tenement", "Tenements", 2, 5, 3.6],
	["office", "Office", 3, 7, 3.8], ["casino", "Casino", 2, 7, 4.5], ["water", "Water Works", 1, 1, 7.0],
	["library", "Library", 1, 3, 4.5], ["gym", "Gym", 1, 3, 5.0],
]
const SMALL_THEMES := ["diner", "bar", "arcade", "bank", "library", "motel", "tenement"]
const BIG_THEMES := ["warehouse", "gym", "mall", "casino", "office", "school", "water", "theater", "apartments", "club"]
const PARK_NAMES := ["Sky Hill Park", "Maple Grove Park", "Riverside Park", "Sunset Park", "Cedar Ridge Park", "Harbor Point Park", "Willow Bend Park", "Lakeview Park", "Oak Hollow Park", "Meadow Park"]
## How much of its block a park takes up. What's left goes to buildings.
const PARK_SHARES := [1.0, 1.0, 0.66, 0.5]
const MAX_ATTEMPTS := 40
const MAX_REPEATS := 2
const NEIGHBOUR_DISTANCE := 13.0
## A park grows to within this of whatever's around it, if there's at least PARK_MIN_GROWTH to take.
const PARK_MARGIN := 1.0
const PARK_MIN_GROWTH := 2.0


## size_name is "small", "medium" or "large". Retries deterministically until the map is valid.
static func generate(size_name: String, map_seed: int, rules: MapRules) -> MapLayout:
	var without_cranes: MapLayout = null
	for attempt in MAX_ATTEMPTS:
		var layout := _attempt(size_name, map_seed + attempt * 7919, rules)
		layout.map_seed = map_seed
		if layout.validate().is_empty() and _all_objectives_fair(layout, 10.0):
			if layout.bridges.size() >= rules.crane_min:
				return layout
			without_cranes = layout
	if without_cranes:
		return without_cranes
	push_error("ProcGen: no valid map found for seed %d" % map_seed)
	return ClassicMap.build(rules)


static func _attempt(size_name: String, attempt_seed: int, rules: MapRules) -> MapLayout:
	var rng := RandomNumberGenerator.new()
	rng.seed = attempt_seed
	var size: Vector2 = {"small": rules.small_size, "medium": rules.medium_size, "large": rules.large_size}.get(size_name, rules.medium_size)
	var layout := MapLayout.new()
	layout.kind = size_name
	layout.bounds = Rect2(-size * 0.5, size)
	var blocks: Array[Rect2] = []
	_split_blocks(layout.bounds, rules, rng, layout, blocks)
	layout.connect_roads(rules.road_width * 0.5 + rules.road_clearance + 1.0)
	# The block nearest the middle holds the main park, like the Classic map's zone 19.
	blocks.sort_custom(func(a: Rect2, b: Rect2): return a.get_center().length() < b.get_center().length())
	var names := PARK_NAMES.duplicate()
	_shuffle(names, rng)
	var alley_points: Array[Vector2] = []
	var lots: Array[Rect2] = []
	var park_rect := _carve_park(blocks[0], rules, rng, lots, alley_points)
	layout.parks.append(_park_plan(park_rect, names.pop_back(), rng))
	for i in range(1, blocks.size()):
		_split_lots(blocks[i], rules, rng, lots, alley_points)
	var next_id := 1
	var used := {}
	_shuffle(lots, rng)
	for lot in lots:
		var building := _building_for(lot, next_id, rng, rules, used, _themes_near(lot, layout))
		if building.is_empty():
			# Every building type is on the map twice: this lot becomes a pocket park instead.
			if names.is_empty():
				names = PARK_NAMES.duplicate()
			layout.parks.append(_park_plan(lot.grow(-0.5), names.pop_back(), rng))
			continue
		layout.buildings.append(building)
		next_id += 1
	_place_objectives(layout, alley_points, park_rect, rng)
	_place_spawns(layout, alley_points, rules, rng)
	_place_bridges(layout, rules, rng)
	layout.raise_objectives(rng)
	layout.expand_edges(rules.edge_expansion)
	_grow_parks(layout, rng)
	return layout


## A park takes up the empty ground around it, then gets its features laid out for the new size.
static func _grow_parks(layout: MapLayout, rng: RandomNumberGenerator) -> void:
	for i in layout.parks.size():
		var park: Dictionary = layout.parks[i]
		var grown := _fill_around(park.rect, layout, i)
		if grown != park.rect:
			layout.parks[i] = _park_plan(grown, park.name, rng)


static func _fill_around(start: Rect2, layout: MapLayout, own_index: int) -> Rect2:
	var obstacles: Array[Rect2] = []
	for b in layout.buildings:
		obstacles.append(b.rect)
	for i in layout.parks.size():
		if i != own_index:
			obstacles.append(layout.parks[i].rect)
	for road in layout.roads:
		var pts: PackedVector2Array = road.points
		for k in pts.size() - 1:
			obstacles.append(Rect2(pts[k], Vector2.ZERO).expand(pts[k + 1]).grow(road.width * 0.5))
	var area := layout.bounds.grow(-PARK_MARGIN)
	var r := start
	# Each side in turn, up to the first thing in its way.
	var left := area.position.x
	var up := area.position.y
	var right := area.end.x
	var down := area.end.y
	for o in obstacles:
		if o.position.y < r.end.y and o.end.y > r.position.y:
			if o.end.x <= r.position.x:
				left = maxf(left, o.end.x + PARK_MARGIN)
			elif o.position.x >= r.end.x:
				right = minf(right, o.position.x - PARK_MARGIN)
	if r.position.x - left >= PARK_MIN_GROWTH:
		r = r.expand(Vector2(left, r.position.y))
	if right - r.end.x >= PARK_MIN_GROWTH:
		r = r.expand(Vector2(right, r.position.y))
	for o in obstacles:
		if o.position.x < r.end.x and o.end.x > r.position.x:
			if o.end.y <= r.position.y:
				up = maxf(up, o.end.y + PARK_MARGIN)
			elif o.position.y >= r.end.y:
				down = minf(down, o.position.y - PARK_MARGIN)
	if r.position.y - up >= PARK_MIN_GROWTH:
		r = r.expand(Vector2(r.position.x, up))
	if down - r.end.y >= PARK_MIN_GROWTH:
		r = r.expand(Vector2(r.position.x, down))
	return r


## Takes a varied share of a block for the park and passes the rest on to be built on.
static func _carve_park(block: Rect2, rules: MapRules, rng: RandomNumberGenerator, lots: Array[Rect2], alleys: Array[Vector2]) -> Rect2:
	var share: float = PARK_SHARES[rng.randi_range(0, PARK_SHARES.size() - 1)]
	var along_x := block.size.x >= block.size.y
	var length := block.size.x if along_x else block.size.y
	var left_over := length * (1.0 - share) - rules.alley_max
	if left_over < rules.lot_min:
		return block.grow(-1.0)
	var park := block
	var rest := block
	if along_x:
		park.size.x = length - left_over - rules.alley_max
		rest.position.x = block.end.x - left_over
		rest.size.x = left_over
	else:
		park.size.y = length - left_over - rules.alley_max
		rest.position.y = block.end.y - left_over
		rest.size.y = left_over
	_split_lots(rest, rules, rng, lots, alleys)
	return park.grow(-1.0)


## A park's features, each in its own quarter of the lawn: the paths run between the quarters.
## Too small a quarter simply goes without.
static func _park_plan(rect: Rect2, park_name: String, rng: RandomNumberGenerator) -> Dictionary:
	const PATH_CLEARANCE := 2.0
	const MIN_FEATURE := 3.0
	# Big parks have a loop path near the edge, so their features sit inside it.
	var edge_clearance := ParkBuilder.LOOP_INSET + ParkBuilder.LOOP_WIDTH if minf(rect.size.x, rect.size.y) >= ParkBuilder.LOOP_MIN_SIZE else 1.6
	var quarter_size := rect.size * 0.5 - Vector2.ONE * (PATH_CLEARANCE + edge_clearance)
	var c := rect.get_center()
	var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	_shuffle(corners, rng)
	var quarter := func(corner: Vector2) -> Rect2:
		if quarter_size.x < MIN_FEATURE or quarter_size.y < MIN_FEATURE:
			return Rect2()
		var near := c + corner * PATH_CLEARANCE
		return Rect2(Vector2(minf(near.x, near.x + corner.x * quarter_size.x), minf(near.y, near.y + corner.y * quarter_size.y)), quarter_size)
	var pond: Rect2 = quarter.call(corners[0])
	if pond.has_area():
		pond = pond.grow_individual(0.0, 0.0, -pond.size.x * rng.randf_range(0.1, 0.4), -pond.size.y * rng.randf_range(0.1, 0.4))
	var court: Rect2 = quarter.call(corners[2])
	if court.size.x < ParkBuilder.COURT_MIN.x and court.size.y < ParkBuilder.COURT_MIN.x or minf(court.size.x, court.size.y) < ParkBuilder.COURT_MIN.y:
		court = Rect2()
	return {"name": park_name, "rect": rect, "pond": pond, "playground": quarter.call(corners[1]), "court": court}


static func _split_blocks(rect: Rect2, rules: MapRules, rng: RandomNumberGenerator, layout: MapLayout, out: Array[Rect2]) -> void:
	var gap := rules.road_width + rules.road_clearance * 2.0
	var along_x := rect.size.x >= rect.size.y
	var length := rect.size.x if along_x else rect.size.y
	if length <= rules.block_max and rect.size.x * rect.size.y < rules.block_max * rules.block_max * 0.8:
		out.append(rect)
		return
	if length < rules.lot_min * 2.0 + gap:
		out.append(rect)
		return
	var cut := length * rng.randf_range(0.4, 0.6)
	var a := rect
	var b := rect
	var line := PackedVector2Array()
	if along_x:
		a.size.x = cut - gap * 0.5
		b.position.x += cut + gap * 0.5
		b.size.x = length - cut - gap * 0.5
		line.append(Vector2(rect.position.x + cut, rect.position.y))
		line.append(Vector2(rect.position.x + cut, rect.end.y))
	else:
		a.size.y = cut - gap * 0.5
		b.position.y += cut + gap * 0.5
		b.size.y = length - cut - gap * 0.5
		line.append(Vector2(rect.position.x, rect.position.y + cut))
		line.append(Vector2(rect.end.x, rect.position.y + cut))
	layout.roads.append({"points": line, "width": rules.road_width})
	_split_blocks(a, rules, rng, layout, out)
	_split_blocks(b, rules, rng, layout, out)


static func _split_lots(rect: Rect2, rules: MapRules, rng: RandomNumberGenerator, out: Array[Rect2], alleys: Array[Vector2]) -> void:
	var along_x := rect.size.x >= rect.size.y
	var length := rect.size.x if along_x else rect.size.y
	# Some neighbours stand wall to wall, like a strip mall.
	var gap := 0.0 if rng.randf() < rules.strip_chance else rng.randf_range(rules.alley_min, rules.alley_max)
	if length <= rules.lot_max or length < rules.lot_min * 2.0 + gap:
		out.append(rect)
		return
	var cut := length * rng.randf_range(0.38, 0.62)
	var a := rect
	var b := rect
	if along_x:
		a.size.x = cut - gap * 0.5
		b.position.x += cut + gap * 0.5
		b.size.x = length - cut - gap * 0.5
		if gap > 0.0:
			alleys.append(Vector2(rect.position.x + cut, rect.get_center().y))
	else:
		a.size.y = cut - gap * 0.5
		b.position.y += cut + gap * 0.5
		b.size.y = length - cut - gap * 0.5
		if gap > 0.0:
			alleys.append(Vector2(rect.get_center().x, rect.position.y + cut))
	_split_lots(a, rules, rng, out, alleys)
	_split_lots(b, rules, rng, out, alleys)


## What's already standing beside this lot, or just across the road from it.
static func _themes_near(lot: Rect2, layout: MapLayout) -> Array:
	var near := []
	for other in layout.buildings:
		if (other.rect as Rect2).intersects(lot.grow(NEIGHBOUR_DISTANCE)):
			near.append(other.theme)
	return near


## Each theme appears at most twice on a map, and never next to itself. Returns {} when none is left.
static func _building_for(lot: Rect2, id: int, rng: RandomNumberGenerator, rules: MapRules, used: Dictionary, near: Array) -> Dictionary:
	var big := lot.size.x * lot.size.y > 340.0 and minf(lot.size.x, lot.size.y) > 14.0
	var preferred: Array = BIG_THEMES if big else SMALL_THEMES
	var fresh := func(list: Array) -> Array: return list.filter(func(t): return int(used.get(t, 0)) < MAX_REPEATS and t not in near)
	var choices: Array = fresh.call(preferred)
	if choices.is_empty():
		choices = fresh.call(BIG_THEMES + SMALL_THEMES)
	if choices.is_empty():
		return {}
	var theme: String = choices[rng.randi_range(0, choices.size() - 1)]
	used[theme] = int(used.get(theme, 0)) + 1
	var preset: Array = PRESETS[0]
	for p in PRESETS:
		if p[0] == theme:
			preset = p
	var floors := mini(rng.randi_range(preset[2], preset[3]), rules.max_floors)
	var h := fit_storey(lot, preset[4] * rules.floor_height_scale, rules)
	return {"id": id, "name": "%s %d" % [preset[1], id], "theme": theme, "rect": lot, "floors": floors, "floor_h": h, "floor_hs": storey_heights(theme, floors, lot, h, rules)}


## Each storey's height, ground first. Big halls get a taller ground floor (RoomPlans.TALL_GROUND).
static func storey_heights(theme: String, floors: int, rect: Rect2, h: float, rules: MapRules) -> Array:
	var out := []
	for level in floors:
		out.append(h)
	if RoomPlans.TALL_GROUND.has(theme):
		out[0] = maxf(h, fit_storey(rect, RoomPlans.TALL_GROUND[theme] * rules.floor_height_scale, rules))
	return out


## A building's storey heights, ground first.
static func storeys(b: Dictionary) -> Array:
	if b.has("floor_hs"):
		return b.floor_hs
	var out := []
	for level in b.floors:
		out.append(b.floor_h)
	return out


## Height of the roof.
static func height(b: Dictionary) -> float:
	var total := 0.0
	for h: float in storeys(b):
		total += h
	return total


## Height of a storey's floor.
static func level_y(b: Dictionary, level: int) -> float:
	var y := 0.0
	var hs := storeys(b)
	for i in mini(level, hs.size()):
		y += hs[i]
	return y


## A storey height whose ramp still fits this footprint at a comfortable slope.
static func fit_storey(rect: Rect2, wanted: float, rules: MapRules) -> float:
	var run := maxf(rect.size.x, rect.size.y) - rules.wall_thickness * 2.0 - rules.stair_landing * 2.0
	return minf(wanted, maxf(run * tan(deg_to_rad(rules.stair_max_slope_deg)), rules.min_floor_height))


## Like the sketch's red dots: mostly inside buildings, plus the park and an alley.
static func _place_objectives(layout: MapLayout, alleys: Array[Vector2], park_rect: Rect2, rng: RandomNumberGenerator) -> void:
	layout.objectives.append({"pos": park_rect.get_center() - park_rect.size * Vector2(0.15, 0.1), "name": layout.parks[0].name})
	if not alleys.is_empty():
		layout.objectives.append({"pos": alleys[rng.randi_range(0, alleys.size() - 1)], "name": "Alley"})
	var ids := range(layout.buildings.size())
	_shuffle(ids, rng)
	var want := clampi(layout.buildings.size() / 2, 3, 9)
	for i in mini(want, ids.size()):
		var b: Dictionary = layout.buildings[ids[i]]
		layout.objectives.append({"pos": (b.rect as Rect2).get_center(), "name": b.name})


## Like the sketch's purple dots: street corners and alleys, well apart.
static func _place_spawns(layout: MapLayout, alleys: Array[Vector2], rules: MapRules, rng: RandomNumberGenerator) -> void:
	var candidates: Array[Vector2] = alleys.duplicate()
	for road in layout.roads:
		var a: Vector2 = road.points[0]
		var b: Vector2 = road.points[1]
		for t in [0.15, 0.5, 0.85]:
			candidates.append(a.lerp(b, t))
	_shuffle(candidates, rng)
	for c in candidates:
		if not layout.bounds.grow(-4.0).has_point(c) or _in_building(layout, c):
			continue
		var clear := true
		for s in layout.spawns:
			clear = clear and s.distance_to(c) >= rules.spawn_spacing
		if clear:
			layout.spawns.append(c)


static func _place_bridges(layout: MapLayout, rules: MapRules, rng: RandomNumberGenerator) -> void:
	var limit: int = {"small": rules.crane_limit_small, "medium": rules.crane_limit_medium, "large": rules.crane_limit_large}.get(layout.kind, rules.crane_limit_medium)
	var pairs := []
	for i in layout.buildings.size():
		for j in range(i + 1, layout.buildings.size()):
			var a: Dictionary = layout.buildings[i]
			var b: Dictionary = layout.buildings[j]
			if BuildingBuilder.has_roof_access(a.theme, a.floors) and BuildingBuilder.has_roof_access(b.theme, b.floors) and bridge_is_clear(layout, a, b, rules):
				pairs.append([a.id, b.id])
	_shuffle(pairs, rng)
	for slot in limit:
		if not pairs.is_empty() and (slot < rules.crane_min or rng.randf() < rules.crane_chance):
			layout.bridges.append(pairs.pop_back())


## Beam thickness, also how far its underside clears the parapets.
const BEAM_THICKNESS := 0.12


## Roof-to-roof beam ends (top surface), or [] if the two buildings do not face each other closely
## enough. The low end rests just past its parapet and the high end just past its own, so the beam
## clears both parapets at any slope.
static func bridge_points(a: Dictionary, b: Dictionary, rules: MapRules) -> Array:
	var ra: Rect2 = a.rect
	var rb: Rect2 = b.rect
	var ya: float = height(a) + rules.parapet_height + BEAM_THICKNESS + 0.01
	var yb: float = height(b) + rules.parapet_height + BEAM_THICKNESS + 0.01
	var from := Vector2.ZERO  # on a's outer face
	var to := Vector2.ZERO    # on b's outer face
	var overlap_x := minf(ra.end.x, rb.end.x) - maxf(ra.position.x, rb.position.x)
	var overlap_z := minf(ra.end.y, rb.end.y) - maxf(ra.position.y, rb.position.y)
	if overlap_x > rules.bridge_width + 1.0:
		var x := (maxf(ra.position.x, rb.position.x) + minf(ra.end.x, rb.end.x)) * 0.5
		from = Vector2(x, ra.end.y if ra.end.y <= rb.position.y else ra.position.y)
		to = Vector2(x, rb.position.y if ra.end.y <= rb.position.y else rb.end.y)
	elif overlap_z > rules.bridge_width + 1.0:
		var z := (maxf(ra.position.y, rb.position.y) + minf(ra.end.y, rb.end.y)) * 0.5
		from = Vector2(ra.end.x if ra.end.x <= rb.position.x else ra.position.x, z)
		to = Vector2(rb.position.x if ra.end.x <= rb.position.x else rb.end.x, z)
	else:
		return []
	var span := from.distance_to(to)
	if span > rules.bridge_max_gap or span < 3.0 or rad_to_deg(atan2(absf(ya - yb), span)) > rules.bridge_max_slope_deg:
		return []
	const OVER_PARAPET := 0.35
	var dir := (to - from) / span
	if ya <= yb:
		var slope := (yb - ya) / (span + OVER_PARAPET)
		var a_end := from - dir * OVER_PARAPET
		var b_end := to + dir * OVER_PARAPET
		return [Vector3(a_end.x, ya, a_end.y), Vector3(b_end.x, yb + slope * OVER_PARAPET, b_end.y)]
	var slope := (ya - yb) / (span + OVER_PARAPET)
	var a_end := from - dir * OVER_PARAPET
	var b_end := to + dir * OVER_PARAPET
	return [Vector3(a_end.x, ya + slope * OVER_PARAPET, a_end.y), Vector3(b_end.x, yb, b_end.y)]


## bridge_points, plus: no third building stands in the beam's way.
static func bridge_is_clear(layout: MapLayout, a: Dictionary, b: Dictionary, rules: MapRules) -> bool:
	var ends: Array = bridge_points(a, b, rules)
	if ends.size() != 2:
		return false
	var low: float = minf(ends[0].y, ends[1].y) - 1.0
	for other in layout.buildings:
		if other.id == a.id or other.id == b.id or height(other) + rules.parapet_height < low:
			continue
		if MapLayout._segment_hits_rect(Vector2(ends[0].x, ends[0].z), Vector2(ends[1].x, ends[1].z), (other.rect as Rect2).grow(0.5)):
			return false
	return true


static func _in_building(layout: MapLayout, p: Vector2) -> bool:
	for b in layout.buildings:
		if (b.rect as Rect2).grow(1.5).has_point(p):
			return true
	return false


## Every objective needs two spawns within the fairness tolerance.
static func _all_objectives_fair(layout: MapLayout, tolerance: float) -> bool:
	if layout.spawns.size() < 4:
		return false
	for o in layout.objectives:
		var found := false
		for i in layout.spawns.size():
			for j in range(i + 1, layout.spawns.size()):
				found = found or absf(layout.spawns[i].distance_to(o.pos) - layout.spawns[j].distance_to(o.pos)) <= tolerance
		if not found:
			return false
	return true


static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = items[i]
		items[i] = items[j]
		items[j] = t
