class_name Interiors
## Lays rooms out the way the real places are arranged, instead of scattering furniture: classroom
## desks in rows facing a board, booths along diner walls, shelves in library aisles.
##
## A theme has one or more plans, chosen per room. Steps, applied in order:
##   ["rug", material, share of room]          flat rug in the middle
##   ["head", prefab]                          centred against the room's front wall
##   ["rows", prefab, pitch across, pitch deep, gap from front]   a grid facing the front wall
##   ["wall", prefab, how many]                backs to any wall
##   ["center", prefab]                        middle of the room
##   ["corners", prefab]                       each corner
##   ["lines", material]                       court markings

const PLANS := {
	"school": [
		[["head", "chalkboard"], ["rows", "school_desk", 2.0, 2.3, 3.2], ["wall", "bookcase_low", 1], ["wall", "plant", 1]],
		[["head", "chalkboard"], ["rows", "school_desk", 2.0, 2.3, 3.2], ["wall", "lockers", 2]],
	],
	"office": [
		[["rows", "cubicle", 5.2, 4.6, 1.2], ["corners", "plant"], ["wall", "copier", 1], ["wall", "water_cooler", 1]],
		[["rug", "rug_blue", 0.6], ["center", "conference"], ["wall", "plant", 2], ["wall", "bookshelf", 1]],
		[["wall", "reception", 1], ["wall", "waiting_chairs", 2], ["wall", "water_cooler", 1], ["corners", "plant"]],
	],
	"apartments": [
		[["rug", "rug_red", 0.5], ["wall", "bed", 1], ["wall", "nightstand", 1], ["wall", "dresser", 1], ["wall", "plant", 1]],
		[["rug", "rug_blue", 0.5], ["wall", "sofa", 1], ["wall", "tv_stand", 1], ["corners", "plant"], ["wall", "bookshelf", 1]],
		[["wall", "kitchen", 1], ["center", "table_chairs"]],
	],
	"motel": [
		[["rug", "rug_green", 0.5], ["wall", "bed", 2], ["wall", "nightstand", 1], ["wall", "dresser", 1]],
		[["wall", "washer", 2], ["wall", "crates", 1], ["wall", "vending", 1], ["wall", "trash_bag", 2]],
	],
	"tenement": [
		[["wall", "mattress", 1], ["wall", "junk", 2], ["wall", "trash_bag", 2], ["wall", "barrels", 1]],
		[["wall", "sofa", 1], ["wall", "rundown_tv", 1], ["wall", "kitchen", 1], ["wall", "trash_bag", 2]],
		[["wall", "crates", 2], ["wall", "mattress", 2], ["wall", "junk", 1]],
	],
	"warehouse": [[["rows", "pallet_rack", 6.6, 4.4, 2.0], ["corners", "crates"], ["wall", "forklift", 1], ["wall", "pallet_stack", 2], ["wall", "barrels", 2], ["wall", "conveyor", 1]]],
	"gym": [[["rows", "treadmill", 3.0, 13.5, 2.2], ["rows", "exercise_bike", 3.0, 13.5, 6.7], ["rows", "bench_press", 4.5, 13.5, 11.2], ["wall", "dumbbell_rack", 3], ["wall", "weight_rack", 2], ["wall", "punching_bag", 3], ["wall", "gym_mat", 3], ["wall", "vending", 1]]],
	"theater": [[["head", "screen_wall"], ["rows", "seat_row", 3.8, 2.2, 4.6], ["wall", "concession", 1], ["wall", "ticket_kiosk", 1], ["corners", "plant"]]],
	"bank": [[["rug", "rug_red", 0.4], ["head", "vault"], ["rows", "teller_counter", 4.6, 9.0, 4.4], ["wall", "atm", 2], ["wall", "waiting_chairs", 2], ["corners", "plant"], ["wall", "stanchion", 2]]],
	"diner": [[["center", "counter"], ["wall", "booth", 6], ["wall", "jukebox", 1], ["corners", "plant"], ["wall", "vending", 1]]],
	"arcade": [[["rug", "rug_blue", 0.5], ["rows", "arcade", 3.9, 3.6, 1.2], ["wall", "claw_machine", 3], ["center", "air_hockey"], ["wall", "vending", 1]]],
	"club": [[["rug", "rug_red", 0.45], ["head", "dj_booth"], ["wall", "club_sofa", 3], ["wall", "bar_counter", 1], ["wall", "speaker_stack", 2], ["corners", "plant"]]],
	"bar": [[["center", "pool_table"], ["wall", "bar_counter", 2], ["wall", "booth", 3], ["wall", "jukebox", 1]]],
	"mall": [[["rows", "kiosk", 6.0, 6.0, 2.0], ["wall", "clothes_shelf", 3], ["wall", "display", 2], ["wall", "clothes_rack", 2], ["wall", "checkout", 1], ["wall", "mannequin", 2], ["wall", "mall_bench", 2], ["corners", "planter"]]],
	"casino": [[["rug", "rug_red", 0.55], ["center", "roulette"], ["rows", "card_table", 5.0, 4.6, 2.6], ["wall", "slots", 6], ["wall", "craps_table", 2], ["corners", "plant"], ["wall", "bar_counter", 1]]],
	"water": [[["rows", "tank", 7.6, 7.6, 1.5], ["wall", "pipes", 3], ["wall", "pump", 3], ["wall", "valve_panel", 2], ["wall", "barrels", 2]]],
	"library": [[["rows", "bookshelf", 4.4, 3.4, 1.2], ["wall", "reading_table", 2], ["corners", "plant"], ["wall", "waiting_chairs", 1]]],
}
const WALL_MARGIN := 0.2
const EXTRA_WALL_ITEMS := 2


## front: the wall (0 -Z, 1 +Z, 2 -X, 3 +X) rooms face. blocked keeps doors, stairs and Tag spots clear.
static func furnish(geo: GeoBatch, theme: String, room: Rect2, y: float, ceiling: float, front: int, rng: RandomNumberGenerator, rules: MapRules, blocked: Array[Rect2], stairs: Rect2) -> void:
	var plans: Array = PLANS.get(theme, PLANS["warehouse"])
	var taken: Array[Rect2] = blocked.duplicate()
	var ctx := {"geo": geo, "room": room, "y": y, "ceiling": ceiling, "front": front, "rng": rng, "gap": rules.clutter_gap, "taken": taken, "stairs": stairs}
	var plan: Array = plans[rng.randi_range(0, plans.size() - 1)]
	for step in plan:
		match step[0]:
			"rug":
				_rug(ctx, step[1], step[2])
			"lines":
				_court_lines(ctx, step[1])
			"head":
				_along_wall(ctx, step[1], front, 0.5)
			"rows":
				_rows(ctx, step[1], step[2], step[3], step[4])
			"wall":
				for n in step[2]:
					_on_any_wall(ctx, step[1])
			"center":
				_try(ctx, step[1], room.get_center(), front)
			"corners":
				_corners(ctx, step[1])
	# A little more of what suits the room, wherever it still fits.
	var wall_items: Array = plan.filter(func(step: Array): return step[0] == "wall")
	for n in EXTRA_WALL_ITEMS if not wall_items.is_empty() else 0:
		_on_any_wall(ctx, wall_items[rng.randi_range(0, wall_items.size() - 1)][1])


## The turn that puts a prefab's back to the given wall, so it faces into the room.
static func _turns_for(wall: int) -> int:
	return [0, 2, 1, 3][wall]


static func _try(ctx: Dictionary, prefab: String, at: Vector2, wall: int) -> bool:
	var turns := _turns_for(wall)
	var size := Clutter.size_of(prefab)
	if turns % 2 == 1:
		size = Vector2(size.y, size.x)
	var foot := Rect2(at - size * 0.5, size)
	var room: Rect2 = ctx.room
	if not room.encloses(foot) or Clutter.height_of(prefab) > ctx.ceiling - 0.3:
		return false
	for other in ctx.taken:
		if foot.grow(ctx.gap * 0.5).intersects(other):
			return false
	ctx.taken.append(foot)
	Clutter.place(ctx.geo, prefab, Vector3(at.x, ctx.y, at.y), turns)
	return true


## Against a wall, at a share of the way along it.
static func _along_wall(ctx: Dictionary, prefab: String, wall: int, share: float) -> bool:
	var room: Rect2 = ctx.room
	var size := Clutter.size_of(prefab)
	var depth := size.y * 0.5 + WALL_MARGIN
	var at := Vector2.ZERO
	match wall:
		0: at = Vector2(lerpf(room.position.x, room.end.x, share), room.position.y + depth)
		1: at = Vector2(lerpf(room.position.x, room.end.x, share), room.end.y - depth)
		2: at = Vector2(room.position.x + depth, lerpf(room.position.y, room.end.y, share))
		_: at = Vector2(room.end.x - depth, lerpf(room.position.y, room.end.y, share))
	return _try(ctx, prefab, at, wall)


static func _on_any_wall(ctx: Dictionary, prefab: String) -> void:
	var rng: RandomNumberGenerator = ctx.rng
	for attempt in 10:
		if _along_wall(ctx, prefab, rng.randi_range(0, 3), rng.randf_range(0.12, 0.88)):
			return


static func _corners(ctx: Dictionary, prefab: String) -> void:
	var room: Rect2 = ctx.room.grow(-0.6)
	for at: Vector2 in [room.position, Vector2(room.end.x, room.position.y), room.end, Vector2(room.position.x, room.end.y)]:
		_try(ctx, prefab, at, ctx.front)


## A grid across the room, all facing the front wall, starting a set gap away from it.
static func _rows(ctx: Dictionary, prefab: String, across: float, deep: float, front_gap: float) -> void:
	var room: Rect2 = ctx.room
	var front: int = ctx.front
	var sideways: bool = front >= 2
	var width: float = room.size.y if sideways else room.size.x
	var depth: float = room.size.x if sideways else room.size.y
	var usable := width - 1.6
	var columns := int(usable / across)
	var first := (width - (columns - 1) * across) * 0.5
	var row_at := front_gap + deep * 0.5
	while row_at < depth - 1.0:
		for c in columns:
			var a := first + c * across
			var d: float = row_at if front % 2 == 0 else depth - row_at
			var at := room.position + (Vector2(d, a) if sideways else Vector2(a, d))
			_try(ctx, prefab, at, front)
		row_at += deep


## Shrinks to stay off the stairs, and goes without if it would end up too small.
static func _rug(ctx: Dictionary, mat: String, share: float) -> void:
	const MIN_SHARE := 0.25
	const STAIR_GAP := 0.3
	var room: Rect2 = ctx.room
	var c := room.get_center()
	var stairs: Rect2 = ctx.stairs
	if stairs.has_area():
		stairs = stairs.grow(STAIR_GAP)
	while Rect2(c - room.size * share * 0.5, room.size * share).intersects(stairs):
		share -= 0.05
		if share < MIN_SHARE:
			return
	var tag := GeoBatch.tag
	GeoBatch.tag = "ground"
	ctx.geo.box(mat, Vector3(c.x, ctx.y + 0.035, c.y), Vector3(room.size.x * share, 0.01, room.size.y * share), 0)
	GeoBatch.tag = tag


## Painted court lines: boundary, halfway line and a centre circle made of short strips.
static func _court_lines(ctx: Dictionary, mat: String) -> void:
	var room: Rect2 = ctx.room.grow(-1.6)
	var y: float = ctx.y + 0.04
	var tag := GeoBatch.tag
	GeoBatch.tag = "ground"
	var c := room.get_center()
	for row: Array in [[c.x, room.position.y, room.size.x, 0.1], [c.x, room.end.y, room.size.x, 0.1], [room.position.x, c.y, 0.1, room.size.y], [room.end.x, c.y, 0.1, room.size.y], [c.x, c.y, room.size.x, 0.1]]:
		ctx.geo.box(mat, Vector3(row[0], y, row[1]), Vector3(row[2], 0.01, row[3]), 0)
	for k in 16:
		var a := TAU * k / 16.0
		var p := c + Vector2(cos(a), sin(a)) * 2.4
		ctx.geo.box(mat, Vector3(p.x, y, p.y), Vector3(1.0, 0.01, 0.1), 0, Basis(Vector3.UP, -a + PI * 0.5))
	GeoBatch.tag = tag
