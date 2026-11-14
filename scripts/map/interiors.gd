class_name Interiors
## Furnishes one room by what it's for: classroom desks in rows facing a board, stalls and sinks in
## restrooms, beds against walls in guest rooms. RoomPlans says which rooms a building has.
##
## Each room kind has a plan. Steps, in order:
##   ["rug", material, share of room]            flat rug in the middle
##   ["head", prefab]                            centred against the front wall
##   ["rows", prefab, pitch across, pitch deep, gap from front]   a grid facing the front wall
##   ["line", prefab, wall, gap, most]           side by side along one wall: "front", "back" or "side";
##                                               `most` is optional
##   ["wall", prefab, how many]                  backs to any solid wall
##   ["center", prefab]                          middle of the room
##   ["corners", prefab]                         each corner
##   ["tuck", prefab]                            back to a wall and its left side into a corner (showers)
##   ["hang", prefab, how many]                  on the walls, clear of windows and tall furniture
##   ["scatter", prefab, per 100 m2]             spread through the open floor
## Rows turn to whichever way fits more, unless the plan has a head item for them to face.

const PLANS := {
	# shared
	"public_restroom": [["line", "toilet_stall", "front", 0.0], ["line", "urinal", "side", 0.1, 4], ["line", "sink_counter", "back", 0.2], ["hang", "poster", 1]],
	"stair_hall": [["wall", "plant", 1], ["hang", "poster", 1]],
	"restroom": [["wall", "toilet", 1], ["wall", "sink", 1], ["hang", "picture_frame", 1]],
	"bathroom": [["tuck", "shower"], ["wall", "toilet", 1], ["wall", "sink", 1], ["hang", "picture_frame", 1]],
	"bath_rundown": [["wall", "toilet", 1], ["wall", "sink", 1], ["wall", "trash_bag", 1]],
	"storage": [["line", "storage_shelf", "back", 0.3], ["wall", "crates", 2], ["wall", "barrels", 1], ["wall", "trash_bag", 1]],
	"break_room": [["wall", "kitchen", 1], ["wall", "fridge", 1], ["center", "table_chairs"], ["wall", "vending", 1], ["wall", "water_cooler", 1], ["hang", "wall_clock", 1], ["hang", "notice_board", 1]],
	"meeting_room": [["rug", "rug_blue", 0.6], ["center", "conference"], ["hang", "whiteboard", 1], ["wall", "plant", 2], ["hang", "picture_frame", 1]],
	"manager_office": [["rug", "rug_red", 0.5], ["wall", "desk_chair", 1], ["wall", "bookcase_low", 1], ["wall", "waiting_chairs", 1], ["wall", "plant", 1], ["hang", "picture_frame", 2], ["hang", "wall_clock", 1]],
	"bedroom": [["rug", "rug_blue", 0.45], ["wall", "bed", 1], ["wall", "nightstand", 2], ["wall", "dresser", 1], ["hang", "picture_frame", 1]],
	# school
	"classroom": [["head", "whiteboard"], ["rows", "school_desk", 1.9, 2.1, 2.6], ["wall", "bookcase_low", 2], ["hang", "notice_board", 1], ["hang", "wall_clock", 1], ["hang", "poster", 2], ["corners", "plant"]],
	"science_lab": [["head", "chalkboard"], ["rows", "reading_table", 3.4, 3.0, 2.8], ["line", "storage_shelf", "back", 0.4], ["wall", "kitchen", 1], ["hang", "poster", 2], ["hang", "wall_clock", 1]],
	"cafeteria": [["rows", "cafeteria_table", 3.2, 2.8, 1.8], ["line", "serving_counter", "back", 0.6], ["wall", "vending", 2], ["wall", "trash_can", 2], ["hang", "poster", 3], ["hang", "wall_clock", 1]],
	"principal_office": [["rug", "rug_red", 0.5], ["wall", "desk_chair", 1], ["wall", "bookcase_low", 1], ["wall", "waiting_chairs", 1], ["wall", "plant", 1], ["hang", "picture_frame", 2], ["hang", "wall_clock", 1]],
	"teachers_lounge": [["wall", "kitchen", 1], ["wall", "fridge", 1], ["center", "table_chairs"], ["wall", "sofa", 1], ["wall", "copier", 1], ["hang", "notice_board", 1], ["hang", "wall_clock", 1]],
	"school_library": [["rows", "bookshelf", 4.2, 3.4, 1.2], ["line", "bookshelf", "back", 0.1], ["wall", "reading_table", 2], ["wall", "reception", 1], ["corners", "plant"], ["hang", "poster", 2]],
	"school_hall": [["line", "lockers", "back", 0.3], ["line", "lockers", "front", 0.3], ["wall", "water_cooler", 1], ["wall", "trash_can", 1], ["hang", "notice_board", 2], ["hang", "poster", 2]],
	# office
	"lobby_reception": [["rug", "rug_blue", 0.5], ["head", "reception"], ["wall", "waiting_chairs", 2], ["wall", "water_cooler", 1], ["corners", "plant"], ["hang", "picture_frame", 2], ["hang", "wall_clock", 1]],
	"open_office": [["rows", "cubicle", 5.2, 4.6, 1.2], ["corners", "plant"], ["wall", "copier", 1], ["wall", "water_cooler", 1], ["wall", "storage_shelf", 1], ["hang", "wall_clock", 1], ["hang", "picture_frame", 1]],
	"copy_room": [["wall", "copier", 2], ["line", "storage_shelf", "back", 0.3], ["wall", "trash_can", 1], ["hang", "notice_board", 1]],
	"office_hall": [["scatter", "waiting_chairs", 0.3], ["wall", "plant", 2], ["wall", "water_cooler", 1], ["hang", "picture_frame", 3]],
	# homes
	"apt_living": [["rug", "rug_red", 0.45], ["wall", "sofa", 1], ["hang", "wall_tv", 1], ["wall", "kitchen", 1], ["wall", "fridge", 1], ["center", "table_chairs"], ["wall", "bookcase_low", 1], ["corners", "plant"], ["hang", "picture_frame", 2]],
	"laundry": [["line", "washer", "back", 0.1], ["line", "washer", "front", 0.1], ["wall", "storage_shelf", 1], ["wall", "trash_bag", 1], ["hang", "notice_board", 1]],
	"mail_room": [["line", "lockers", "back", 0.1], ["wall", "trash_can", 1], ["hang", "notice_board", 1]],
	"apt_hall": [["scatter", "plant", 0.3], ["wall", "plant", 1], ["wall", "trash_bag", 1], ["hang", "picture_frame", 2]],
	"guest_bed": [["rug", "rug_green", 0.4], ["wall", "bed", 1], ["wall", "nightstand", 1], ["wall", "dresser", 1], ["wall", "waiting_chairs", 1], ["hang", "picture_frame", 1]],
	"motel_lobby": [["rug", "rug_green", 0.5], ["head", "reception"], ["wall", "waiting_chairs", 1], ["wall", "vending", 1], ["corners", "plant"], ["hang", "picture_frame", 1], ["hang", "wall_clock", 1]],
	"vending_nook": [["line", "vending", "back", 0.15], ["wall", "trash_can", 1]],
	"motel_hall": [["scatter", "plant", 0.3], ["wall", "plant", 1], ["wall", "trash_can", 1], ["hang", "picture_frame", 2]],
	"squat_living": [["wall", "mattress", 1], ["wall", "sofa", 1], ["wall", "rundown_tv", 1], ["wall", "junk", 1], ["wall", "trash_bag", 2], ["wall", "kitchen", 1], ["hang", "poster", 1]],
	"boiler_room": [["wall", "tank", 1], ["wall", "pipes", 2], ["wall", "valve_panel", 1], ["wall", "barrels", 1], ["wall", "storage_shelf", 1]],
	"tenement_hall": [["wall", "trash_bag", 2], ["wall", "junk", 1], ["hang", "poster", 2]],
	# diner, bar, arcade, club
	"dining": [["center", "counter"], ["line", "booth", "side", 0.25], ["line", "booth", "back", 0.25], ["wall", "jukebox", 1], ["corners", "plant"], ["hang", "picture_frame", 2], ["hang", "wall_clock", 1]],
	"kitchen_diner": [["line", "kitchen_line", "back", 0.1], ["wall", "fridge", 2], ["wall", "storage_shelf", 1], ["center", "kitchen_island"], ["wall", "trash_can", 1]],
	"bar_room": [["line", "bar_counter", "back", 0.3], ["wall", "booth", 2], ["center", "table_chairs"], ["wall", "jukebox", 1], ["hang", "poster", 2], ["hang", "picture_frame", 1]],
	"pool_area": [["center", "pool_table"], ["wall", "booth", 1], ["wall", "waiting_chairs", 1], ["hang", "poster", 2]],
	"arcade_floor": [["rug", "rug_blue", 0.6], ["rows", "arcade", 3.9, 3.4, 1.2], ["line", "claw_machine", "side", 0.3], ["wall", "vending", 1], ["hang", "poster", 3]],
	"prize_counter": [["head", "checkout"], ["wall", "display", 1], ["wall", "claw_machine", 1], ["center", "air_hockey"]],
	"party_room": [["rows", "table_chairs", 3.0, 3.0, 1.5], ["wall", "vending", 1], ["hang", "poster", 2]],
	"club_entry": [["head", "ticket_kiosk"], ["wall", "stanchion", 2], ["corners", "plant"], ["hang", "poster", 2]],
	"coat_check": [["line", "clothes_rack", "back", 0.2], ["head", "checkout"]],
	"dance_floor": [["scatter", "speaker_stack", 0.2], ["rug", "rug_red", 0.5], ["head", "dj_booth"], ["wall", "speaker_stack", 3], ["wall", "club_sofa", 1]],
	"club_bar": [["scatter", "table_chairs", 0.6], ["line", "bar_counter", "back", 0.3], ["wall", "club_sofa", 2], ["wall", "speaker_stack", 1]],
	"vip_lounge": [["rug", "rug_red", 0.5], ["wall", "club_sofa", 3], ["wall", "bar_counter", 1], ["corners", "plant"], ["hang", "picture_frame", 2]],
	# bank, theater, gym, casino
	"bank_lobby": [["scatter", "plant", 0.3], ["scatter", "waiting_chairs", 0.4], ["rug", "rug_red", 0.4], ["wall", "atm", 2], ["wall", "waiting_chairs", 2], ["center", "stanchion"], ["corners", "plant"], ["hang", "wall_clock", 1], ["hang", "picture_frame", 2]],
	"teller_area": [["scatter", "desk_chair", 0.8], ["scatter", "storage_shelf", 0.4], ["line", "teller_counter", "front", 0.4], ["wall", "desk_chair", 1], ["wall", "storage_shelf", 1], ["wall", "copier", 1]],
	"vault_room": [["head", "vault"], ["wall", "storage_shelf", 1]],
	"theater_lobby": [["head", "concession"], ["wall", "ticket_kiosk", 1], ["wall", "stanchion", 2], ["wall", "waiting_chairs", 1], ["corners", "plant"], ["hang", "poster", 4]],
	"auditorium": [["head", "screen_wall"], ["rows", "seat_row", 3.6, 2.0, 5.0]],
	"projection": [["head", "desk_chair"], ["line", "storage_shelf", "back", 0.3], ["wall", "speaker_stack", 1], ["hang", "poster", 1]],
	"staff_lounge": [["scatter", "lounge_set", 0.5], ["scatter", "table_chairs", 0.5], ["wall", "kitchen", 1], ["wall", "fridge", 1], ["center", "table_chairs"], ["wall", "sofa", 1], ["hang", "wall_tv", 1], ["hang", "notice_board", 1]],
	"gym_reception": [["scatter", "waiting_chairs", 0.5], ["head", "reception"], ["wall", "vending", 1], ["wall", "water_cooler", 1], ["corners", "plant"], ["hang", "poster", 2]],
	"locker_m": [["line", "lockers", "back", 0.2], ["line", "toilet_stall", "side", 0.0], ["line", "sink_counter", "front", 0.2], ["center", "mall_bench"], ["wall", "shower", 2]],
	"locker_f": [["line", "lockers", "back", 0.2], ["line", "toilet_stall", "side", 0.0], ["line", "sink_counter", "front", 0.2], ["center", "mall_bench"], ["wall", "shower", 2]],
	"weights_area": [["rug", "rug_dark", 0.5], ["rows", "bench_press", 3.4, 3.2, 2.2], ["line", "dumbbell_rack", "back", 0.4], ["wall", "weight_rack", 2], ["wall", "gym_mat", 1], ["hang", "wall_clock", 1]],
	"cardio_area": [["rows", "treadmill", 2.0, 3.2, 1.4], ["line", "exercise_bike", "back", 0.4], ["wall", "water_cooler", 1], ["hang", "poster", 2]],
	"studio": [["scatter", "punching_bag", 0.3], ["scatter", "gym_mat", 0.4], ["line", "gym_mat", "back", 0.4], ["line", "punching_bag", "side", 0.8], ["wall", "gym_mat", 2], ["hang", "wall_clock", 1]],
	"rest_area": [["scatter", "lounge_set", 0.5], ["scatter", "table_chairs", 0.6], ["wall", "sofa", 1], ["wall", "waiting_chairs", 2], ["center", "table_chairs"], ["wall", "vending", 1], ["wall", "water_cooler", 1], ["corners", "plant"]],
	"casino_lobby": [["rug", "rug_red", 0.5], ["wall", "atm", 2], ["center", "stanchion"], ["wall", "waiting_chairs", 1], ["corners", "plant"], ["hang", "picture_frame", 2]],
	"cashier": [["line", "teller_counter", "front", 0.4], ["wall", "vault", 1], ["wall", "storage_shelf", 1]],
	"slots_area": [["rug", "rug_red", 0.6], ["rows", "slots", 3.4, 2.6, 1.0], ["line", "slots", "back", 0.3]],
	"table_games": [["scatter", "card_table", 0.6], ["scatter", "craps_table", 0.3], ["rug", "rug_red", 0.65], ["center", "roulette"], ["rows", "card_table", 4.4, 4.2, 1.6], ["wall", "craps_table", 2]],
	"casino_lounge": [["scatter", "table_chairs", 0.6], ["line", "bar_counter", "back", 0.3], ["wall", "club_sofa", 2], ["center", "table_chairs"], ["corners", "plant"]],
	# mall, warehouse, water works, library
	"mall_atrium": [["scatter", "planter", 0.6], ["scatter", "mall_bench", 0.8], ["rows", "kiosk", 8.0, 7.5, 2.4], ["wall", "mall_bench", 3], ["corners", "planter"], ["wall", "trash_can", 2]],
	"shop_clothes": [["line", "clothes_shelf", "back", 0.3], ["wall", "clothes_rack", 2], ["wall", "mannequin", 2], ["head", "checkout"], ["center", "display"]],
	"shop_general": [["line", "storage_shelf", "back", 0.3], ["rows", "display", 3.0, 3.0, 2.0], ["head", "checkout"], ["hang", "poster", 1]],
	"food_court": [["line", "food_stall", "back", 0.5], ["rows", "table_chairs", 2.8, 2.8, 1.4], ["wall", "trash_can", 2], ["corners", "plant"]],
	"loading_dock": [["scatter", "pallet_stack", 0.8], ["wall", "pallet_stack", 3], ["wall", "forklift", 1], ["wall", "crates", 2], ["wall", "barrels", 1], ["wall", "conveyor", 1]],
	"storage_racks": [["scatter", "pallet_stack", 0.6], ["scatter", "crates", 0.8], ["rows", "pallet_rack", 6.4, 4.2, 2.0], ["corners", "crates"]],
	"warehouse_office": [["wall", "desk_chair", 2], ["wall", "storage_shelf", 1], ["wall", "water_cooler", 1], ["hang", "notice_board", 1], ["hang", "wall_clock", 1]],
	"pump_hall": [["scatter", "pump", 0.6], ["scatter", "barrels", 0.6], ["rows", "tank", 7.4, 7.4, 1.5], ["wall", "pipes", 3], ["wall", "pump", 3], ["wall", "valve_panel", 2]],
	"control_room": [["line", "desk_chair", "back", 0.4], ["wall", "valve_panel", 1], ["wall", "storage_shelf", 1], ["hang", "wall_clock", 1], ["hang", "notice_board", 1]],
	"library_desk": [["head", "reception"], ["wall", "waiting_chairs", 1], ["wall", "bookcase_low", 2], ["corners", "plant"], ["hang", "notice_board", 1]],
	"stacks": [["rows", "bookshelf", 4.2, 3.4, 1.2], ["line", "bookshelf", "back", 0.1], ["line", "bookshelf", "side", 0.1], ["line", "bookcase_low", "front", 0.2], ["scatter", "reading_table", 0.2]],
	"reading_area": [["rows", "reading_table", 3.6, 3.0, 1.4], ["line", "bookcase_low", "back", 0.2], ["corners", "plant"], ["hang", "picture_frame", 2], ["hang", "wall_clock", 1]],
	"study_room": [["center", "reading_table"], ["line", "bookcase_low", "back", 0.1], ["hang", "whiteboard", 1]],
	"living": [["rug", "rug_red", 0.45], ["wall", "sofa", 1], ["hang", "wall_tv", 1], ["wall", "kitchen", 1], ["center", "table_chairs"], ["hang", "picture_frame", 2]],
}
const WALL_MARGIN := 0.2
## Boards and pictures: these go flat on the wall, not a step out from it.
const ON_WALL := ["whiteboard", "chalkboard", "notice_board", "poster", "picture_frame", "wall_clock", "screen_wall", "wall_tv"]
## Furniture that hides a picture behind it.
const TALL := 1.4
## A TV needs nothing taller than this in front of it, and keeps this much floor clear (m).
const SCREEN_CLEAR := 0.95
const SCREEN_VIEW := 0.9
## Counters someone works behind: room for them between the counter and the wall (m).
const STAFF_GAP := {"reception": 1.1, "teller_counter": 1.1, "checkout": 1.0, "bar_counter": 1.1, "concession": 1.1, "serving_counter": 1.0, "food_stall": 0.3, "ticket_kiosk": 0.8}


static func prefabs() -> Array:
	var out := []
	for plan: Array in PLANS.values():
		for step: Array in plan:
			if step[0] in ["head", "rows", "line", "wall", "center", "corners", "hang"] and step[1] not in out:
				out.append(step[1])
	return out


## room: the floor inside its walls. front: the wall rows face (0 -Z, 1 +Z, 2 -X, 3 +X).
## solid: which of the four sides (same order) are real walls, for things that stand or hang on one.
## blocked keeps doors, stairs and Tag spots clear; windows are kept clear of pictures.
static func furnish(geo: GeoBatch, kind: String, room: Rect2, y: float, ceiling: float, front: int, rng: RandomNumberGenerator, rules: MapRules, blocked: Array[Rect2], stairs: Rect2, solid := [true, true, true, true], windows: Array[Rect2] = []) -> int:
	var plan: Array = PLANS.get(kind, [])
	# Wall decor goes up once the furniture stands, so nothing is put in front of it; things spread
	# through the floor go last, around the orderly rows and lines.
	plan = plan.filter(func(st): return st[0] not in ["hang", "scatter"]) + plan.filter(func(st): return st[0] == "hang") + plan.filter(func(st): return st[0] == "scatter")
	var has_head := plan.any(func(st): return st[0] == "head")
	var head_placed := false
	var taken: Array[Rect2] = blocked.duplicate()
	var ctx := {"geo": geo, "room": room, "y": y, "ceiling": ceiling, "front": front, "rng": rng, "gap": rules.clutter_gap, "taken": taken, "stairs": stairs,
		"solid": solid, "windows": windows, "blocked_count": blocked.size(), "tall": [] as Array[Rect2], "mid": [] as Array[Rect2], "hung": [] as Array[Rect2]}
	for step in plan:
		match step[0]:
			"rug":
				_rug(ctx, step[1], step[2])
			"head":
				head_placed = _head(ctx, step[1])
			"rows":
				# Seats and desks only face a screen or board that's really there.
				if not has_head or head_placed:
					_rows(ctx, step[1], step[2], step[3], step[4], has_head)
			"scatter":
				for n in roundi(room.get_area() / 100.0 * step[2]):
					_scatter(ctx, step[1])
			"line":
				_line(ctx, step[1], _relative_wall(front, step[2], rng), step[3], step[4] if step.size() > 4 else 99)
			"wall":
				for n in step[2]:
					_on_any_wall(ctx, step[1])
			"center":
				_try(ctx, step[1], room.get_center(), front)
			"corners":
				_corners(ctx, step[1])
			"tuck":
				_tuck(ctx, step[1])
			"hang":
				for n in step[2]:
					_hang(ctx, step[1])
	return ctx.taken.size() - blocked.size() + ctx.hung.size()


static func _relative_wall(front: int, which: String, rng: RandomNumberGenerator) -> int:
	var back: int = [1, 0, 3, 2][front]
	match which:
		"front":
			return front
		"back":
			return back
	var sides: Array = [2, 3] if front < 2 else [0, 1]
	return sides[rng.randi_range(0, 1)]


## The turn that puts a prefab's back to the given wall, so it faces into the room.
static func _turns_for(wall: int) -> int:
	return [0, 2, 1, 3][wall]


static func _footprint(prefab: String, at: Vector2, wall: int, stretch := Vector3.ONE) -> Rect2:
	var size := Clutter.size_of(prefab) * Vector2(stretch.x, stretch.z)
	if _turns_for(wall) % 2 == 1:
		size = Vector2(size.y, size.x)
	return Rect2(at - size * 0.5, size)


static func _try(ctx: Dictionary, prefab: String, at: Vector2, wall: int, gap := -1.0, stretch := Vector3.ONE) -> bool:
	var foot := _footprint(prefab, at, wall, stretch)
	var room: Rect2 = ctx.room
	if not room.encloses(foot) or Clutter.height_of(prefab) * stretch.y > ctx.ceiling - 0.3:
		return false
	var spacing: float = ctx.gap if gap < 0.0 else gap
	for other in ctx.taken:
		if foot.grow(spacing * 0.5).intersects(other):
			return false
	ctx.taken.append(foot)
	if Clutter.height_of(prefab) > TALL:
		ctx.tall.append(foot)
	if Clutter.height_of(prefab) > SCREEN_CLEAR:
		ctx.mid.append(foot)
	Clutter.place(ctx.geo, prefab, Vector3(at.x, ctx.y, at.y), _turns_for(wall), "", stretch)
	return true


static func _wall_point(room: Rect2, wall: int, share: float, depth: float) -> Vector2:
	match wall:
		0: return Vector2(lerpf(room.position.x, room.end.x, share), room.position.y + depth)
		1: return Vector2(lerpf(room.position.x, room.end.x, share), room.end.y - depth)
		2: return Vector2(room.position.x + depth, lerpf(room.position.y, room.end.y, share))
	return Vector2(room.end.x - depth, lerpf(room.position.y, room.end.y, share))


## Against a wall, at a share of the way along it.
static func _along_wall(ctx: Dictionary, prefab: String, wall: int, share: float) -> bool:
	return _try(ctx, prefab, _wall_point(ctx.room, wall, share, Clutter.size_of(prefab).y * 0.5 + WALL_MARGIN + STAFF_GAP.get(prefab, 0.0)), wall)


## Centred on the front wall. A board or screen too big for the room is scaled down to fit it.
static func _head(ctx: Dictionary, prefab: String) -> bool:
	var room: Rect2 = ctx.room
	var size := Clutter.size_of(prefab)
	var wall_length: float = room.size.x if ctx.front < 2 else room.size.y
	var k := minf(1.0, minf((wall_length - 0.6) / size.x, (ctx.ceiling - 0.4) / Clutter.height_of(prefab)))
	# Off-centre, or a little smaller, when a door or the stairs are in the way.
	for scale: float in [1.0, 0.8, 0.6]:
		var stretch := Vector3(k * scale, k * scale, 1.0)
		for share: float in [0.5, 0.4, 0.6, 0.3, 0.7, 0.2, 0.8]:
			var depth: float = size.y * 0.5 + (0.005 if prefab in ON_WALL else WALL_MARGIN + STAFF_GAP.get(prefab, 0.0))
			if _try(ctx, prefab, _wall_point(room, ctx.front, share, depth), ctx.front, -1.0, stretch):
				return true
	return false


## On a free spot of a grid through the open floor, square to the room and facing its front.
static func _scatter(ctx: Dictionary, prefab: String) -> void:
	var rng: RandomNumberGenerator = ctx.rng
	var area: Rect2 = ctx.room.grow(-1.0)
	var size := Clutter.size_of(prefab)
	var pitch := maxf(size.x, size.y) + 1.6
	var nx := int(area.size.x / pitch)
	var nz := int(area.size.y / pitch)
	if nx < 1 or nz < 1:
		return
	var spots := []
	for ix in nx:
		for iz in nz:
			spots.append(area.position + area.size * Vector2((ix + 0.5) / nx, (iz + 0.5) / nz))
	for attempt in mini(spots.size(), 12):
		if _try(ctx, prefab, spots.pop_at(rng.randi_range(0, spots.size() - 1)), ctx.front):
			return


static func _on_any_wall(ctx: Dictionary, prefab: String) -> void:
	var rng: RandomNumberGenerator = ctx.rng
	var walls := [0, 1, 2, 3].filter(func(w): return ctx.solid[w])
	if walls.is_empty():
		walls = [0, 1, 2, 3]
	for attempt in 24:
		if _along_wall(ctx, prefab, walls[rng.randi_range(0, walls.size() - 1)], rng.randf_range(0.12, 0.88)):
			return


## As many as fit side by side along one wall, centred on it.
static func _line(ctx: Dictionary, prefab: String, wall: int, gap: float, most := 99) -> void:
	var room: Rect2 = ctx.room
	var size := Clutter.size_of(prefab)
	var length: float = room.size.x if wall < 2 else room.size.y
	var count := mini(int((length - 0.4 + gap) / (size.x + gap)), most)
	if count < 1:
		return
	var used := count * size.x + (count - 1) * gap
	var depth: float = size.y * 0.5 + 0.05 + STAFF_GAP.get(prefab, 0.0)
	for i in count:
		var along := (length - used) * 0.5 + size.x * 0.5 + i * (size.x + gap)
		_try(ctx, prefab, _wall_point(room, wall, along / length, depth), wall, 0.02)


## Back to a wall, pushed along it until its solid left side meets the corner.
static func _tuck(ctx: Dictionary, prefab: String) -> void:
	var room: Rect2 = ctx.room
	var size := Clutter.size_of(prefab)
	for wall in [0, 1, 2, 3]:
		if not ctx.solid[wall]:
			continue
		var left := Basis(Vector3.UP, _turns_for(wall) * PI * 0.5) * Vector3.LEFT
		var length: float = room.size.x if wall < 2 else room.size.y
		var to_end: bool = (left.x if wall < 2 else left.z) > 0.0
		var along: float = length - size.x * 0.5 - 0.02 if to_end else size.x * 0.5 + 0.02
		if _try(ctx, prefab, _wall_point(room, wall, along / length, size.y * 0.5 + 0.02), wall):
			return


static func _corners(ctx: Dictionary, prefab: String) -> void:
	var room: Rect2 = ctx.room.grow(-0.6)
	for at: Vector2 in [room.position, Vector2(room.end.x, room.position.y), room.end, Vector2(room.position.x, room.end.y)]:
		_try(ctx, prefab, at, ctx.front)


## Pictures, clocks and boards: on a real wall, clear of windows, doors, tall furniture and each other.
static func _hang(ctx: Dictionary, prefab: String) -> void:
	var rng: RandomNumberGenerator = ctx.rng
	var room: Rect2 = ctx.room
	var size := Clutter.size_of(prefab)
	if Clutter.height_of(prefab) > ctx.ceiling - 0.1:
		return
	var walls := [0, 1, 2, 3].filter(func(w): return ctx.solid[w])
	for attempt in 14:
		if walls.is_empty():
			return
		var wall: int = walls[rng.randi_range(0, walls.size() - 1)]
		var at := _wall_point(room, wall, rng.randf_range(0.15, 0.85), size.y * 0.5 + 0.005)
		var foot := _footprint(prefab, at, wall)
		var clear := room.grow(0.1).encloses(foot)
		for other in ctx.windows + ctx.tall + ctx.hung:
			clear = clear and not foot.grow(0.3).intersects(other)
		if prefab == "wall_tv":
			for other in ctx.mid:
				clear = clear and not foot.grow(SCREEN_VIEW).intersects(other)
		# Doors and stairs: the blocked list taken started from.
		for other in (ctx.taken as Array).slice(0, ctx.blocked_count):
			clear = clear and not foot.intersects(other)
		if clear:
			ctx.hung.append(foot)
			if prefab == "wall_tv":
				ctx.taken.append(foot.grow(SCREEN_VIEW))
			Clutter.place(ctx.geo, prefab, Vector3(at.x, ctx.y, at.y), _turns_for(wall))
			return


## A grid across the room, all facing the front wall, starting a set gap away from it.
static func _rows(ctx: Dictionary, prefab: String, across: float, deep: float, front_gap: float, fixed: bool) -> void:
	var room: Rect2 = ctx.room
	var front: int = ctx.front
	if not fixed:
		# Free to turn: whichever way fits the most.
		var side: int = 2 if front < 2 else 0
		if _row_count(room, side, across, deep, front_gap) > _row_count(room, front, across, deep, front_gap):
			front = side
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


static func _row_count(room: Rect2, front: int, across: float, deep: float, front_gap: float) -> int:
	var width: float = room.size.y if front >= 2 else room.size.x
	var depth: float = room.size.x if front >= 2 else room.size.y
	return int((width - 1.6) / across) * maxi(int((depth - 1.0 - front_gap - deep * 0.5) / deep) + 1, 0)


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
