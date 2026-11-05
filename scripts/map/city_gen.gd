class_name CityGen
## Random city layouts: a new one every match. The host picks the seed and every
## peer builds the same city from it. Layouts use the same format as the classic
## city (MapData.classic_layout), in sketch pixels (1 px = 0.1 m) inside the map
## size's area, so MapBuilder handles both the same way.
##
##  * Roads: the map is split again and again (the longer side each time) until
##    the blocks are city-block sized. The first split is a wide avenue running
##    fence to fence; later ones are streets that only cross their own part of
##    the map, so streets end in T-junctions and blocks come in uneven sizes.
##  * Blocks are lined with buildings right behind the sidewalk (a street wall),
##    in one row or two rows back to back, with narrow alleys between them. Deep
##    blocks keep a service lane or a car park behind the rows.
##  * Buildings are sized in whole wall modules (MapBuilder.MODULE) so they don't
##    move when snapped, and they get taller towards the middle of the map.
##  * One block near the middle becomes the park; a few lots become plazas.
##  * Spawn zones are spread far apart on junctions and plazas.
##  * Tag spots go in the park, inside buildings (on any floor) and on plazas.
##  * Crane bridges join the roofs of tall buildings facing each other across a road.

const ROAD := 60.0       # street width (6 m)
const AVENUE := 80.0     # the first, widest road (8 m)
const SIDEWALK := 30.0   # sidewalk between the road and the buildings (3 m)
const EDGE := 30.0       # gap between the fence and the outermost blocks
const BLOCK_MAX := {"small": 400.0, "medium": 480.0, "large": 560.0}  # a block is split again while its long side is longer than this...
const BLOCK_MIN := 230.0 # ...and no side may end up shorter than this
const CROSS_CHANCE := 0.6  # a new street lines up with one across the road (a crossroads)
const MOD := 20.0        # wall module (2 m) in px
const POST := 6.0        # corner posts (0.3 m each end)
const LOT_MODS := [6, 15]   # building width along the street, in modules (12.6-30.6 m)
const DEPTH_MODS := [6, 11] # building depth back from the street (12.6-22.6 m)
# Gap between neighbours: [px, chance]. 0 = they touch, like a strip mall or a terrace.
const ALLEYS := [[0.0, 0.4], [30.0, 0.42], [45.0, 0.12], [70.0, 0.06]]
const PARK_MIN := Vector2(300, 340)
const PARK_MAX := Vector2(450, 540)
const TALL_MAX := Vector2(306, 246)  # footprint cap for 4+ storey buildings

# [type, label, min floors, max floors, floor height]
const TYPES := [
	["warehouse", "Warehouse", 1, 2, 6.0],
	["school", "School", 2, 3, 4.0],
	["theater", "Cinema", 2, 2, 5.0],
	["bank", "Bank", 2, 2, 4.5],
	["diner", "Diner", 1, 1, 4.5],
	["arcade", "Arcade", 1, 2, 4.0],
	["club", "Nightclub", 1, 2, 4.5],
	["bar", "Bar", 1, 1, 4.0],
	["apartments", "Apartments", 3, 5, 4.0],
	["mall", "Mall", 2, 3, 5.0],
	["motel", "Motel", 2, 2, 4.0],
	["rundown", "Tenements", 3, 4, 4.0],
	["rundown2", "Flats", 3, 3, 4.0],
	["office", "Tower", 4, 5, 4.0],
	["casino", "Casino", 3, 5, 4.5],
	["library", "Library", 2, 2, 4.5],
]
const WATER := ["water", "Water Works", 1, 1, 7.0]  # needs a big lot

const PREFIXES := [
	"Harbor", "Maple", "Union", "Kingsway", "Riverside", "Golden", "Eastside", "Westgate",
	"Old Town", "Northside", "Swiftcurrent", "Copper", "Lakeview", "Station", "Granite",
	"Liberty", "Elm Street", "Market", "Bayview", "Summit", "Ironwood", "Crescent",
]
const PARK_NAMES := ["Swiftcurrent Park", "Maple Green", "Union Square Park", "Riverside Commons", "Liberty Park"]
# Types whose ground floor is open (no rooms), so a Tag spot can sit inside.
const TAG_TYPES := ["warehouse", "bank", "mall", "office", "casino", "library", "theater", "diner", "arcade", "club", "water"]
const COUNTS := {
	# Plenty of spawn zones, so each round can find two the same distance from the
	# Tag and out of each other's sight (Game._server_begin_round), and rounds rotate.
	"small": {"spawns": 12, "tags": 3, "bridges": 1},
	"medium": {"spawns": 14, "tags": 4, "bridges": 3},
	"large": {"spawns": 18, "tags": 8, "bridges": 6},
}


## Where roads meet: the square shared by a street running along x and one along z,
## whether they cross or one ends at the other's edge (a T). Each one once.
## slack: how far apart two road edges may be and still meet (same units as the rects).
static func junction_rects(roads: Array, slack: float) -> Array:
	var out := []
	for a: Rect2 in roads:
		if a.size.y <= a.size.x:
			continue  # a: runs along z
		for b: Rect2 in roads:
			if b.size.x <= b.size.y:
				continue  # b: runs along x
			if not a.grow(slack).intersects(b):
				continue  # they don't meet
			var a_through := a.position.y <= b.position.y + slack and a.end.y >= b.end.y - slack
			var b_through := b.position.x <= a.position.x + slack and b.end.x >= a.end.x - slack
			if not (a_through or b_through):
				continue  # two road ends at a corner: not a junction
			var j := Rect2(a.position.x, b.position.y, a.size.x, b.size.y)
			var dup := false
			for o: Rect2 in out:
				dup = dup or o.get_center().distance_to(j.get_center()) < slack * 2.0
			if not dup:
				out.append(j)
	return out


## How good a generated city is, for the host's pick of the best of a few:
## enough buildings, Tag spots and spawn zones, a park, and junctions of both
## kinds (T-junctions and crossroads).
static func score(layout: Dictionary) -> float:
	var roads := []
	for rd in layout.roads:
		roads.append(Rect2(rd[0], rd[1], rd[2] - rd[0], rd[3] - rd[1]))
	var ts := 0
	var crosses := 0
	for j: Rect2 in junction_rects(roads, 1.0):
		var arms := 0
		for d: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
			var probe := j.get_center() + Vector2(d.x * (j.size.x * 0.5 + 40.0), d.y * (j.size.y * 0.5 + 40.0))
			for r: Rect2 in roads:
				if r.has_point(probe):
					arms += 1
					break
		if arms >= 4:
			crosses += 1
		elif arms == 3:
			ts += 1
	var s := float(layout.buildings.size())
	s += 3.0 * layout.objectives.size() + layout.spawn_dots.size()
	s += 5.0 if not layout.park.is_empty() else 0.0
	s += 2.0 * mini(ts, 8) + 4.0 * mini(crosses, 5)
	return s


## Distance from p to the nearest of pts (INF if there are none).
static func _nearest(p: Vector2, pts: Array) -> float:
	var d := INF
	for q: Vector2 in pts:
		d = minf(d, p.distance_to(q))
	return d


static func generate(size: String, seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var a: Array = MapData.SIZES[size].rect
	var area := Rect2(a[0], a[1], a[2] - a[0], a[3] - a[1])
	var counts: Dictionary = COUNTS.get(size, COUNTS.large)
	var inner := area.grow(-EDGE)
	var roads := []
	var blocks := []
	_split(rng, inner, area, 0, roads, blocks, float(BLOCK_MAX.get(size, 560.0)))
	var road_rects := []
	for rd in roads:
		road_rects.append(Rect2(rd[0], rd[1], rd[2] - rd[0], rd[3] - rd[1]))
	var junctions := []
	for j: Rect2 in junction_rects(road_rects, 1.0):
		junctions.append(j.get_center())

	# The park: the block nearest the middle that's big enough.
	var park := Rect2()
	var best := INF
	for bl: Rect2 in blocks:
		var room := bl.grow(-SIDEWALK)
		if room.size.x < PARK_MIN.x or room.size.y < PARK_MIN.y:
			continue
		var d := bl.get_center().distance_to(area.get_center()) + rng.randf_range(0.0, 120.0)
		if d < best:
			best = d
			park = bl
	var park_rect := []
	if park.size != Vector2.ZERO:
		var room := park.grow(-SIDEWALK)
		var ps := Vector2(minf(room.size.x, PARK_MAX.x), minf(room.size.y, PARK_MAX.y))
		var pp := room.get_center() - ps * 0.5
		park_rect = [pp.x, pp.y, pp.x + ps.x, pp.y + ps.y]

	# Lots -> buildings / plazas / car parks.
	var buildings := []
	var plazas := []
	var parking := []
	var dumpsters := []
	var bag := []
	var names := []
	var prefixes := PREFIXES.duplicate()
	_shuffle(rng, prefixes)
	var centre := area.get_center()
	var reach := area.size.length() * 0.5
	for bl: Rect2 in blocks:
		if bl == park:
			continue
		var room := bl.grow(-SIDEWALK)
		var plan := _block_lots(rng, room)
		parking.append_array(plan.parking)
		dumpsters.append_array(plan.dumpsters)
		var lots: Array = plan.lots
		var li := 0
		while li < lots.size():
			var lot: Rect2 = lots[li]
			li += 1
			var roll := rng.randf()
			if roll < 0.04:
				plazas.append(lot)
				continue
			if roll < 0.07:
				parking.append(lot)
				continue
			var t: Array
			if lot.size.x >= 380.0 and lot.size.y >= 220.0 and rng.randf() < 0.2:
				t = WATER
			else:
				if bag.is_empty():
					bag = TYPES.duplicate()
					_shuffle(rng, bag)
				t = bag.pop_back()
			# Taller towards the middle of the map (within the type's range).
			var downtown := 1.0 - clampf(lot.get_center().distance_to(centre) / reach, 0.0, 1.0)
			var floors := clampi(int(round(lerpf(float(t[2]), float(t[3]), clampf(downtown * 1.3 + rng.randf_range(-0.35, 0.35), 0.0, 1.0)))), int(t[2]), int(t[3]))
			var rect := _footprint(rng, lot, floors)
			# A tall building leaves part of its lot over: another building goes there.
			var spare := _spare_lot(lot, rect)
			if spare.has_area():
				lots.append(spare)
			# Names must be unique (Tag spots are named after them): past the last
			# prefix, step on until the prefix + type pair is new.
			var pi := buildings.size()
			var bname := ""
			for _k in prefixes.size():
				bname = "%s %s" % [prefixes[pi % prefixes.size()], t[1]]
				if bname not in names:
					break
				pi += 1
			names.append(bname)
			buildings.append([buildings.size() + 1, bname, t[0], [rect.position.x, rect.position.y, rect.end.x, rect.end.y], floors, t[4]])
		plazas.append_array(plan.plazas)

	# Spawn zones: spread out over junctions and plazas.
	var spawn_cands := junctions.duplicate()
	for p: Rect2 in plazas:
		spawn_cands.append(p.get_center())
	# Points along every road too (small maps have only one or two junctions).
	for rd in roads:
		var rr := Rect2(rd[0], rd[1], rd[2] - rd[0], rd[3] - rd[1])
		var horizontal := rr.size.x > rr.size.y
		var length := rr.size.x if horizontal else rr.size.y
		var t := 120.0
		while t < length - 120.0:
			spawn_cands.append(Vector2(rr.position.x + t, rr.get_center().y) if horizontal else Vector2(rr.get_center().x, rr.position.y + t))
			t += 160.0
	var spawns := _spread(rng, spawn_cands, int(counts.spawns))
	var spawn_dots := []
	for p: Vector2 in spawns:
		spawn_dots.append([p.x, p.y])

	# Tag spots: the park, inside open-plan buildings, and plazas.
	var tag_cands := []
	var tag_names := []
	var tag_floors := []  # storeys of the building each candidate is in (1 outdoors)
	var park_name: String = PARK_NAMES[rng.randi() % PARK_NAMES.size()]
	if not park_rect.is_empty():
		var pr := Rect2(park_rect[0], park_rect[1], park_rect[2] - park_rect[0], park_rect[3] - park_rect[1])
		# Same relative spot as the classic park's Tag (by the pond).
		tag_cands.append(pr.position + Vector2(275.0 * pr.size.x / 370.0, 243.0 * pr.size.y / 440.0))
		tag_names.append(park_name)
		tag_floors.append(1)
	for b in buildings:
		var r: Array = b[3]
		# Big enough that the middle is clear of the stairwell at the end.
		if b[2] in TAG_TYPES and maxf(r[2] - r[0], r[3] - r[1]) >= 240.0 and minf(r[2] - r[0], r[3] - r[1]) >= 140.0:
			tag_cands.append(Vector2((r[0] + r[2]) * 0.5, (r[1] + r[3]) * 0.5))
			tag_names.append(b[1])
			tag_floors.append(int(b[4]))
	for i in plazas.size():
		var p: Rect2 = plazas[i]
		if p.size.x >= 100.0 and p.size.y >= 100.0:
			tag_cands.append(p.get_center())
			tag_names.append("%s Plaza" % prefixes[(buildings.size() + i) % prefixes.size()])
			tag_floors.append(1)
	# Keep Tag spots at least 15 m from spawn zones, then spread them out.
	var far := []
	for c: Vector2 in tag_cands:
		if _nearest(c, spawns) >= 150.0:
			far.append(c)
	# Not enough places (small maps)? Streets too, away from the junctions.
	if far.size() < int(counts.tags):
		var n := 0
		for rd in roads:
			var rr := Rect2(rd[0], rd[1], rd[2] - rd[0], rd[3] - rd[1])
			var horizontal := rr.size.x > rr.size.y
			for f: float in [0.33, 0.67]:
				var c := Vector2(rr.position.x + rr.size.x * f, rr.get_center().y) if horizontal else Vector2(rr.get_center().x, rr.position.y + rr.size.y * f)
				var ok := true
				for j: Vector2 in junctions:
					ok = ok and c.distance_to(j) >= 120.0
				if ok:
					if _nearest(c, spawns) >= 150.0:
						far.append(c)
					tag_cands.append(c)
					tag_names.append("%s %s" % [prefixes[(buildings.size() + plazas.size() + n) % prefixes.size()], "Avenue" if rr.size.x > ROAD + 1.0 and rr.size.y > ROAD + 1.0 else "Street"])
					tag_floors.append(1)
					n += 1
	# Still short (lots of spawn zones on a small map)? The candidates farthest from
	# any spawn zone make up the rest.
	if far.size() < int(counts.tags):
		var rest := tag_cands.filter(func(c): return not c in far)
		rest.sort_custom(func(a, b): return _nearest(a, spawns) > _nearest(b, spawns))
		far.append_array(rest.slice(0, int(counts.tags) - far.size()))
	var picked := _spread(rng, far, int(counts.tags))
	# [x, y, name, storey]: a Tag spot in a building sits on any of its floors
	# (0 = ground), so it can be up on the 3rd floor of a tower.
	var objectives := []
	for p: Vector2 in picked:
		var i := tag_cands.find(p)
		objectives.append([p.x, p.y, tag_names[i], rng.randi_range(0, int(tag_floors[i]) - 1)])

	return {
		"buildings": buildings,
		"roads": roads,
		"spawn_dots": spawn_dots,
		"objectives": objectives,
		"park": park_rect,
		"park_name": park_name,
		"bridges": _bridges(rng, buildings, int(counts.bridges)),
		"dumpsters": dumpsters,
		"parking": parking,
	}


## Splits r (inside the fence's area) into blocks with roads between them: across
## the longer side, somewhere in its middle 30-70 %, while that side is longer than
## block_max (BLOCK_MAX for the map size; sometimes a bit more, so block sizes vary). The first road is an
## avenue. A road that reaches the edge of the map runs on to the fence.
static func _split(rng: RandomNumberGenerator, r: Rect2, area: Rect2, depth: int, roads: Array, blocks: Array, block_max: float) -> void:
	var w := AVENUE if depth == 0 else ROAD
	var across_x := r.size.x >= r.size.y  # the road runs along z, cutting x
	var long := r.size.x if across_x else r.size.y
	var limit := block_max * (1.0 if depth < 2 else rng.randf_range(0.85, 1.25))
	if long <= limit or long - w < BLOCK_MIN * 2.0:
		blocks.append(r)
		return
	var lo := maxf(0.3 * long, BLOCK_MIN)
	var hi := minf(0.7 * long, long - BLOCK_MIN - w)
	var cut := roundf(rng.randf_range(lo, hi))
	# Often line up with a street the same width across the road: the two meet in a
	# crossroads (traffic lights) instead of two T-junctions (stop signs).
	if depth > 0 and rng.randf() < CROSS_CHANCE:
		for rd in roads:
			var runs_z: bool = rd[2] - rd[0] < rd[3] - rd[1]
			var width: float = (rd[2] - rd[0]) if runs_z else (rd[3] - rd[1])
			var c: float = (rd[0] - r.position.x) if across_x else (rd[1] - r.position.y)
			if runs_z == across_x and absf(width - w) < 0.5 and c >= lo and c <= hi:
				cut = c
				break
	var a: Rect2
	var b: Rect2
	var road: Rect2
	if across_x:
		a = Rect2(r.position, Vector2(cut, r.size.y))
		road = Rect2(r.position.x + cut, r.position.y, w, r.size.y)
		b = Rect2(road.end.x, r.position.y, r.end.x - road.end.x, r.size.y)
	else:
		a = Rect2(r.position, Vector2(r.size.x, cut))
		road = Rect2(r.position.x, r.position.y + cut, r.size.x, w)
		b = Rect2(r.position.x, road.end.y, r.size.x, r.end.y - road.end.y)
	# Ends at the edge of the playable area run on to the fence.
	var inner := area.grow(-EDGE)
	if across_x:
		if is_equal_approx(road.position.y, inner.position.y):
			road = Rect2(road.position.x, area.position.y, road.size.x, road.end.y - area.position.y)
		if is_equal_approx(road.end.y, inner.end.y):
			road.size.y = area.end.y - road.position.y
	else:
		if is_equal_approx(road.position.x, inner.position.x):
			road = Rect2(area.position.x, road.position.y, road.end.x - area.position.x, road.size.y)
		if is_equal_approx(road.end.x, inner.end.x):
			road.size.x = area.end.x - road.position.x
	roads.append([road.position.x, road.position.y, road.end.x, road.end.y])
	_split(rng, a, area, depth + 1, roads, blocks, block_max)
	_split(rng, b, area, depth + 1, roads, blocks, block_max)


## Lots along a block's streets: {lots, plazas, parking, dumpsters} (Rect2 / Vector2).
## Shallow blocks get one row across the whole depth; deep ones a row facing each
## of the two long streets, back to back, with a service lane (dumpsters) or a car
## park between them.
static func _block_lots(rng: RandomNumberGenerator, room: Rect2) -> Dictionary:
	var out := {"lots": [], "plazas": [], "parking": [], "dumpsters": []}
	var along_x := room.size.x >= room.size.y
	var long := room.size.x if along_x else room.size.y
	var short := room.size.y if along_x else room.size.x
	var dmin := DEPTH_MODS[0] * MOD + POST
	var depths: Array = []  # [offset from the near edge, depth]
	if short >= dmin * 2.0 + 30.0:
		var d1 := _mods_fit(rng, minf((short - 30.0) * 0.5, DEPTH_MODS[1] * MOD + POST), DEPTH_MODS)
		var d2 := _mods_fit(rng, minf(short - d1 - 30.0, DEPTH_MODS[1] * MOD + POST), DEPTH_MODS)
		depths = [[0.0, d1], [short - d2, d2]]
		var gap := Rect2()
		if along_x:
			gap = Rect2(room.position.x, room.position.y + d1, long, short - d1 - d2)
		else:
			gap = Rect2(room.position.x + d1, room.position.y, short - d1 - d2, long)
		var gw := short - d1 - d2
		if gw >= 150.0 and long >= 250.0 and rng.randf() < 0.6:
			out.parking.append(gap)
		else:
			# Service lane: a few dumpsters along it.
			for i in rng.randi_range(1, 3):
				var t := rng.randf_range(0.15, 0.85) * long
				var c := Vector2(room.position.x + t, room.position.y + d1 + gw * 0.5) if along_x else Vector2(room.position.x + d1 + gw * 0.5, room.position.y + t)
				if gw >= 40.0:
					out.dumpsters.append([c.x, c.y])
	else:
		# One row as deep as the block allows (no empty yard behind it).
		var d := floorf((minf(short, (DEPTH_MODS[1] + 3) * MOD + POST) - POST) / MOD) * MOD + POST
		depths = [[0.0 if rng.randf() < 0.5 else short - d, d]]
		if short - d >= 120.0:
			var yard := Rect2()
			var off: float = d if depths[0][0] == 0.0 else 0.0
			yard = Rect2(room.position.x, room.position.y + off, long, short - d) if along_x else Rect2(room.position.x + off, room.position.y, short - d, long)
			if short - d >= 150.0 and rng.randf() < 0.6:
				out.parking.append(yard.grow(-10.0))  # a car park behind the buildings
			else:
				out.plazas.append(yard)
	for row: Array in depths:
		for span: Vector2 in _row_spans(rng, long):
			var r := Rect2()
			if along_x:
				r = Rect2(room.position.x + span.x, room.position.y + row[0], span.y, row[1])
			else:
				r = Rect2(room.position.x + row[0], room.position.y + span.x, row[1], span.y)
			out.lots.append(r)
	return out


## Building widths along a row of `long` px: [start, width] spans of whole modules
## with an alley after each one. Whatever is left at the end stays open.
static func _row_spans(rng: RandomNumberGenerator, long: float) -> Array:
	var spans := []
	var x := 0.0
	var wmin := LOT_MODS[0] * MOD + POST
	while long - x >= wmin:
		var n := rng.randi_range(LOT_MODS[0], LOT_MODS[1])
		var w := n * MOD + POST
		if x + w > long:
			w = floorf((long - x - POST) / MOD) * MOD + POST
		# A short leftover after this one would be a useless sliver: take it in.
		var rest := long - x - w
		if rest > 0.0 and rest < wmin + 30.0:
			w = floorf((long - x - POST) / MOD) * MOD + POST
		spans.append(Vector2(x, w))
		x += w + _alley(rng)
	return spans


static func _alley(rng: RandomNumberGenerator) -> float:
	var roll := rng.randf()
	for a: Array in ALLEYS:
		if roll < a[1]:
			return a[0]
		roll -= a[1]
	return ALLEYS[1][0]


## A depth of whole modules, at most `room` px, within [lo, hi] modules.
static func _mods_fit(rng: RandomNumberGenerator, room: float, mods: Array) -> float:
	var hi := mini(int(mods[1]), int(floorf((room - POST) / MOD)))
	var n := rng.randi_range(mini(int(mods[0]), hi), hi)
	return n * MOD + POST


## What's left of lot beside a building that doesn't fill it (a capped tall one),
## past an alley, as a lot of whole modules; empty if it's too small to build on.
static func _spare_lot(lot: Rect2, b: Rect2) -> Rect2:
	var wmin := LOT_MODS[0] * MOD + POST
	var gap := 30.0  # a spare lot keeps an alley
	var best := Rect2()
	# Beside it (along x), then in front of / behind it (along z).
	var w := lot.size.x - b.size.x - gap
	if w >= wmin:
		var x := lot.position.x if b.position.x > lot.position.x else b.end.x + gap
		best = Rect2(x, lot.position.y, floorf((w - POST) / MOD) * MOD + POST, lot.size.y)
	var h := lot.size.y - b.size.y - gap
	if h >= wmin and h * lot.size.x > best.get_area():
		var y := lot.position.y if b.position.y > lot.position.y else b.end.y + gap
		best = Rect2(lot.position.x, y, lot.size.x, floorf((h - POST) / MOD) * MOD + POST)
	return best


## Building footprint in a lot: the whole lot (it's already sized in modules), but
## 4+ storey buildings are capped at TALL_MAX so their height does the work; a
## capped one keeps to the street side of its lot.
static func _footprint(rng: RandomNumberGenerator, lot: Rect2, floors: int) -> Rect2:
	var w := lot.size.x
	var h := lot.size.y
	if floors >= 4:
		var cap := TALL_MAX if w >= h else Vector2(TALL_MAX.y, TALL_MAX.x)
		if w > cap.x:
			w = floorf((cap.x - POST) / MOD) * MOD + POST
		if h > cap.y:
			h = floorf((cap.y - POST) / MOD) * MOD + POST
	var x := lot.position.x + (0.0 if rng.randf() < 0.5 else lot.size.x - w)
	var y := lot.position.y + (0.0 if rng.randf() < 0.5 else lot.size.y - h)
	return Rect2(x, y, w, h)


## Farthest-point picking: starts from a random candidate, then keeps taking the
## one furthest from everything picked so far.
static func _spread(rng: RandomNumberGenerator, cands: Array, count: int) -> Array:
	var out := []
	if cands.is_empty():
		return out
	out.append(cands[rng.randi() % cands.size()])
	while out.size() < mini(count, cands.size()):
		var best_c = null
		var best_d := -1.0
		for c: Vector2 in cands:
			var d := INF
			for o: Vector2 in out:
				d = minf(d, c.distance_to(o))
			if d > best_d:
				best_d = d
				best_c = c
		if best_d <= 0.0:
			break
		out.append(best_c)
	return out


## Crane bridges between buildings of 2+ storeys that face each other across a road, with
## nothing in between. Shortest gaps first; each building gets at most one.
static func _bridges(rng: RandomNumberGenerator, buildings: Array, count: int) -> Array:
	var cands := []
	for i in buildings.size():
		for k in range(i + 1, buildings.size()):
			var a: Array = buildings[i]
			var b: Array = buildings[k]
			if a[4] < 2 or b[4] < 2:
				continue
			var ra := Rect2(a[3][0], a[3][1], a[3][2] - a[3][0], a[3][3] - a[3][1])
			var rb := Rect2(b[3][0], b[3][1], b[3][2] - b[3][0], b[3][3] - b[3][1])
			var gap := -1.0
			var between := Rect2()
			var overlap_z := minf(ra.end.y, rb.end.y) - maxf(ra.position.y, rb.position.y)
			var overlap_x := minf(ra.end.x, rb.end.x) - maxf(ra.position.x, rb.position.x)
			if overlap_z >= 80.0 and (ra.end.x <= rb.position.x or rb.end.x <= ra.position.x):
				var w := ra if ra.end.x <= rb.position.x else rb
				var e := rb if w == ra else ra
				gap = e.position.x - w.end.x
				between = Rect2(w.end.x, maxf(ra.position.y, rb.position.y), gap, overlap_z)
			elif overlap_x >= 80.0 and (ra.end.y <= rb.position.y or rb.end.y <= ra.position.y):
				var nn := ra if ra.end.y <= rb.position.y else rb
				var s := rb if nn == ra else ra
				gap = s.position.y - nn.end.y
				between = Rect2(maxf(ra.position.x, rb.position.x), nn.end.y, overlap_x, gap)
			if gap < 60.0 or gap > 320.0:
				continue
			var blocked := false
			for c in buildings:
				var rc := Rect2(c[3][0], c[3][1], c[3][2] - c[3][0], c[3][3] - c[3][1])
				if c != a and c != b and rc.intersects(between):
					blocked = true
			if not blocked:
				cands.append([gap + rng.randf_range(0.0, 40.0), a[0], b[0]])
	cands.sort_custom(func(x, y): return x[0] < y[0])
	var used := {}
	var out := []
	for c in cands:
		if out.size() >= count:
			break
		if used.has(c[1]) or used.has(c[2]):
			continue
		used[c[1]] = true
		used[c[2]] = true
		out.append([c[1], c[2], "planks" if rng.randf() < 0.5 else "metal"])
	return out


## Fisher-Yates with our own rng, so the result depends only on the seed.
static func _shuffle(rng: RandomNumberGenerator, arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
