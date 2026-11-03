class_name CityGen
## Random city layouts: a new one every match. The host picks the seed and every
## peer builds the same city from it. Layouts use the same format as the classic
## city (MapData.classic_layout), in sketch pixels (1 px = 0.1 m) inside the map
## size's area, so MapBuilder handles both the same way.
##
##  * Roads: a grid with uneven block sizes, running fence to fence.
##  * Blocks are split into lots with alleys between them. A lot holds a building
##    (5-storey ones get smaller footprints), a plaza or a car park.
##  * One block near the middle becomes the park.
##  * Spawn zones are spread far apart on junctions and plazas.
##  * Tag spots go in the park, inside buildings and on plazas.
##  * Crane bridges join the roofs of tall buildings facing each other across a road.

const ROAD := 60.0       # road width (6 m)
const SIDEWALK := 30.0   # setback from the road (3 m)
const ALLEY := 50.0      # gap between buildings sharing a block (5 m)
const EDGE := 30.0       # gap between the fence and the outermost blocks
const BLOCK := 470.0     # typical block size (47 m)
const PARK_MIN := Vector2(300, 340)
const PARK_MAX := Vector2(450, 540)
const TALL_MAX := Vector2(300, 250)  # footprint cap for 4+ storey buildings

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
	"small": {"spawns": 3, "tags": 3, "bridges": 1},
	"medium": {"spawns": 5, "tags": 4, "bridges": 3},
	"large": {"spawns": 10, "tags": 8, "bridges": 6},
}


static func generate(size: String, seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var a: Array = MapData.SIZES[size].rect
	var area := Rect2(a[0], a[1], a[2] - a[0], a[3] - a[1])
	var counts: Dictionary = COUNTS.get(size, COUNTS.large)
	var cols := _spans(rng, area.position.x + EDGE, area.end.x - EDGE)
	var rows := _spans(rng, area.position.y + EDGE, area.end.y - EDGE)

	# Roads between the spans, fence to fence.
	var roads := []
	for i in cols.size() - 1:
		roads.append([cols[i][1], area.position.y, cols[i + 1][0], area.end.y])
	for i in rows.size() - 1:
		roads.append([area.position.x, rows[i][1], area.end.x, rows[i + 1][0]])
	var junctions := []
	for i in cols.size() - 1:
		for k in rows.size() - 1:
			junctions.append(Vector2((cols[i][1] + cols[i + 1][0]) * 0.5, (rows[k][1] + rows[k + 1][0]) * 0.5))

	var blocks := []
	for c in cols:
		for r in rows:
			blocks.append(Rect2(c[0], r[0], c[1] - c[0], r[1] - r[0]))

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
	var bag := []
	var prefixes := PREFIXES.duplicate()
	_shuffle(rng, prefixes)
	for bl: Rect2 in blocks:
		if bl == park:
			continue
		var room := bl.grow(-SIDEWALK)
		var along_x := room.size.x >= room.size.y
		var long := room.size.x if along_x else room.size.y
		var short := room.size.y if along_x else room.size.x
		# 1-3 lots along the block, and sometimes two rows of them.
		var n := clampi(int(long / 200.0), 1, 3)
		var m := 2 if short >= 400.0 and rng.randf() < 0.5 else 1
		var lot_len := (long - (n - 1) * ALLEY) / n
		var lot_dep := (short - (m - 1) * ALLEY) / m
		var lots := []
		for k in n:
			for j in m:
				var u := k * (lot_len + ALLEY)
				var w := j * (lot_dep + ALLEY)
				if along_x:
					lots.append(Rect2(room.position.x + u, room.position.y + w, lot_len, lot_dep))
				else:
					lots.append(Rect2(room.position.x + w, room.position.y + u, lot_dep, lot_len))
		for lot: Rect2 in lots:
			var roll := rng.randf()
			if lot.size.x < 140.0 or lot.size.y < 110.0 or roll < 0.1:
				plazas.append(lot)
				continue
			if roll < 0.17:
				parking.append(lot)
				continue
			var t: Array
			if lot.size.x >= 380.0 and lot.size.y >= 220.0 and rng.randf() < 0.15:
				t = WATER
			else:
				if bag.is_empty():
					bag = TYPES.duplicate()
					_shuffle(rng, bag)
				t = bag.pop_back()
			var floors := rng.randi_range(int(t[2]), int(t[3]))
			var rect := _footprint(rng, lot, floors)
			var prefix: String = prefixes[buildings.size() % prefixes.size()]
			buildings.append([buildings.size() + 1, "%s %s" % [prefix, t[1]], t[0], [rect.position.x, rect.position.y, rect.end.x, rect.end.y], floors, t[4]])

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
	var park_name: String = PARK_NAMES[rng.randi() % PARK_NAMES.size()]
	if not park_rect.is_empty():
		var pr := Rect2(park_rect[0], park_rect[1], park_rect[2] - park_rect[0], park_rect[3] - park_rect[1])
		# Same relative spot as the classic park's Tag (by the pond).
		tag_cands.append(pr.position + Vector2(275.0 * pr.size.x / 370.0, 243.0 * pr.size.y / 440.0))
		tag_names.append(park_name)
	for b in buildings:
		var r: Array = b[3]
		# Big enough that the middle is clear of the stairwell at the end.
		if b[2] in TAG_TYPES and maxf(r[2] - r[0], r[3] - r[1]) >= 240.0 and minf(r[2] - r[0], r[3] - r[1]) >= 140.0:
			tag_cands.append(Vector2((r[0] + r[2]) * 0.5, (r[1] + r[3]) * 0.5))
			tag_names.append(b[1])
	for i in plazas.size():
		var p: Rect2 = plazas[i]
		if p.size.x >= 100.0 and p.size.y >= 100.0:
			tag_cands.append(p.get_center())
			tag_names.append("%s Plaza" % prefixes[(buildings.size() + i) % prefixes.size()])
	# Keep Tag spots at least 15 m from spawn zones, then spread them out.
	var far := []
	for c: Vector2 in tag_cands:
		var ok := true
		for s: Vector2 in spawns:
			if c.distance_to(s) < 150.0:
				ok = false
		if ok:
			far.append(c)
	var picked := _spread(rng, far, int(counts.tags))
	if picked.size() < 2:
		picked = _spread(rng, tag_cands, int(counts.tags))
	var objectives := []
	for p: Vector2 in picked:
		objectives.append([p.x, p.y, tag_names[tag_cands.find(p)]])

	return {
		"buildings": buildings,
		"roads": roads,
		"spawn_dots": spawn_dots,
		"objectives": objectives,
		"park": park_rect,
		"park_name": park_name,
		"bridges": _bridges(rng, buildings, int(counts.bridges)),
		"dumpsters": [],
		"parking": parking,
	}


## Splits [a, b] into block spans of roughly BLOCK px with a road between each.
static func _spans(rng: RandomNumberGenerator, a: float, b: float) -> Array:
	var length := b - a
	var n := maxi(2, int(round((length + ROAD) / (BLOCK + ROAD))))
	var weights := []
	var total := 0.0
	for i in n:
		var w := rng.randf_range(0.75, 1.3)
		weights.append(w)
		total += w
	var usable := length - ROAD * (n - 1)
	var out := []
	var x := a
	for i in n:
		var w: float = usable * weights[i] / total
		out.append([x, x + w])
		x += w + ROAD
	return out


## Building footprint inside a lot: set back a little from random sides, and
## 4+ storey buildings capped at TALL_MAX so their height does the work.
static func _footprint(rng: RandomNumberGenerator, lot: Rect2, floors: int) -> Rect2:
	var w := lot.size.x - rng.randf_range(0.0, 40.0)
	var h := lot.size.y - rng.randf_range(0.0, 40.0)
	if floors >= 4:
		# Long side capped at TALL_MAX.x, short side at TALL_MAX.y.
		if w >= h:
			w = minf(w, TALL_MAX.x)
			h = minf(h, TALL_MAX.y)
		else:
			w = minf(w, TALL_MAX.y)
			h = minf(h, TALL_MAX.x)
	w = minf(maxf(w, 120.0), lot.size.x)
	h = minf(maxf(h, 100.0), lot.size.y)
	var x := lot.position.x + rng.randf_range(0.0, lot.size.x - w)
	var y := lot.position.y + rng.randf_range(0.0, lot.size.y - h)
	return Rect2(roundf(x), roundf(y), roundf(w), roundf(h))


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
