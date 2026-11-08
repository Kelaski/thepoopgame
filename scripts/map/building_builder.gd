class_name BuildingBuilder extends RefCounted
## Turns one building plan into boxes: outer walls with few windows, floors with stair holes,
## rooms laid out for what the building is (RoomPlans), ramps, roof parapet and furniture.

## theme -> [outer wall, trim, floor, inner wall, plan (unused: RoomPlans decides), windows per side per floor]
## The doorway height the awning scene is built over.
const AWNING_DOOR_HEIGHT := 3.1
const THEMES := {
	"warehouse": ["corrugated", "trim", "concrete", "corrugated", "open", 0],
	"school": ["paint_red", "trim_cream", "tile_light", "plaster", "corridor", 1],
	"gym": ["plaster_blue", "trim_cream", "tile_dark", "plaster", "open", 1],
	"theater": ["plaster_purple", "gold", "carpet_red", "plaster_purple", "open", 0],
	"bank": ["concrete", "trim_cream", "tile_check", "plaster", "open", 1],
	"diner": ["plaster_teal", "trim_cream", "tile_check", "plaster", "open", 2],
	"arcade": ["plaster_purple", "trim", "carpet_blue", "plaster_purple", "open", 0],
	"club": ["paint_dark", "trim", "tile_dark", "plaster_purple", "open", 0],
	"bar": ["paint_dark", "wood_dark", "wood_floor", "paint_dark", "open", 1],
	"apartments": ["paint_tan", "trim_cream", "wood_floor", "plaster", "corridor", 2],
	"mall": ["plaster", "trim", "tile_light", "plaster", "open", 1],
	"motel": ["plaster_rose", "trim_cream", "carpet_blue", "plaster", "corridor", 1],
	"tenement": ["paint_dark", "trim", "wood_floor", "plaster", "corridor", 2],
	"office": ["plaster_blue", "trim", "carpet_blue", "plaster", "corridor", 2],
	"casino": ["plaster_rose", "gold", "carpet_red", "plaster_rose", "open", 0],
	"water": ["concrete", "trim", "concrete", "concrete", "open", 0],
	"library": ["paint_tan", "wood_dark", "wood_floor", "plaster", "open", 1],
}
## Awning cloth colours, painted onto assets/props/building/awning.tscn.
const AWNINGS := ["#e03d33", "#2e995c", "#3370d6", "#fab829"]
const DOOR_PAINTS := ["door_green", "door_red", "door_cream"]
## Small shops and the like: their stairs, if any, stop at the top floor.
const NO_ROOF_ACCESS := ["bank", "arcade", "club", "diner", "bar", "library"]
## Multi-storey buildings get this many more windows per side than their theme says.
const EXTRA_WINDOWS_UP_HIGH := 2
## Name boards fit their wall, with this much margin (m), and never go wider than the most.
const BOARD_MARGIN := 0.3
const BOARD_MAX_WIDTH := 7.0
const BOARD_FONT_SIZE := 40
const LABEL_PIXEL_SIZE := 0.008
const FAR_AWAY := Vector2(99999.0, 99999.0)
const STAIR_ATTEMPTS := 10
const RAMP_THICKNESS := 0.24
## The ground floor's finish sits this high, so a ramp starts on top of it.
const GROUND_FINISH := 0.03
## Over a flight to the roof, the roof stays closed until you'd have this much headroom left.
const ROOF_HEADROOM := 2.5

## Test hook: when set to an Array, every flight of stairs is recorded as [from, to, width], at ramp level.
static var flight_log: Variant = null
## Test hook: when set to an Array, every room is recorded as {theme, level, kind, rect, walled}.
static var room_log: Variant = null
## Rooms along a hall need at least this much depth.
const MIN_ROOM_DEPTH := 4.2
## Open areas bigger than this get pillars, for cover.
const PILLAR_AREA := 170.0
const DOORWAY := 1.0  # a door between parts of a home
## Homes at least this deep (m) put their back rooms behind the front one rather than beside it.
const DEEP_HOME := 6.2
## Rooms with no windows: private, or dark for a film.
## Free floor kept between the stairs and a walled room beside them (m).
const STAIR_SIDE := 1.4
## Walled rooms smaller than this (m2) get the narrow door.
const SMALL_ROOM := 25.0
## The narrowest strip left beside a room cut short: a comfortable hallway (m).
const MIN_STRIP := 2.6
const NO_WINDOWS := ["public_restroom", "restroom", "bathroom", "bath_rundown", "locker_m", "locker_f", "auditorium", "projection", "vault_room"]

var rules: MapRules
var geo := GeoBatch.new()
## Doorways to hang doors in: {pos: Vector3, along_x: bool}
var doors: Array = []
## Lamp positions, for the map's capped light budget.
var lights: Array[Vector3] = []
## Name boards to letter: {pos: Vector3, yaw: float, text: String, size: int}
var signs: Array = []

var _spec: Dictionary
var _rng: RandomNumberGenerator
var _rect: Rect2
var _keep_clear: Array[Rect2]
var _others: Array  # other buildings' rects
var _bounds: Rect2
var _theme: Array
var _stair: Dictionary
var _corridor := false
var _bridge_ends: Array[Vector3] = []
var _door_paint := ""
var _roof_access := true
var _floors := 1
var _hs: Array = []      # storey heights, ground first
var _mode := "zones"     # "corridor" (rooms both sides of a hall), "single" (one side) or "zones"
var _hall := {}          # the hall's frame, for hall layouts
var _runs: Array = []    # hall layouts: per level, per side, the rooms in order [{kind, from, to}]
var _plans: Array = []   # per level: {rooms, lines, doors, fits}
var _windows: Array = []  # per level: Rect2 around each window, kept clear of pictures


func _init(p_rules: MapRules) -> void:
	rules = p_rules


## A one-storey motel has no stairs at all.
static func has_roof_access(theme: String, floors: int) -> bool:
	return theme not in NO_ROOF_ACCESS and not (theme == "motel" and floors == 1)


func build(spec: Dictionary, layout: MapLayout, keep_clear: Array[Rect2]) -> void:
	_spec = spec
	_rect = spec.rect
	_rng = RandomNumberGenerator.new()
	_rng.seed = hash([layout.map_seed, spec.id, spec.theme])
	_keep_clear = keep_clear
	_bounds = layout.bounds
	_theme = THEMES.get(spec.theme, THEMES["warehouse"])
	_others = []
	for other in layout.buildings:
		if other.id != spec.id:
			_others.append(other.rect)
	_hs = ProcGen.storeys(spec)
	var n: int = _hs.size()
	var tallest: float = _hs.max()
	_mode = _pick_mode()
	_corridor = _mode != "zones"
	_hall = _hall_frame() if _corridor else {}
	_runs = []
	for level in n if _corridor else 0:
		_runs.append(_plan_runs(level))
	_bridge_ends.clear()
	for pair in layout.bridges:
		if spec.id in pair:
			for end in ProcGen.bridge_points(layout.building(pair[0]), layout.building(pair[1]), rules):
				if _rect.has_point(Vector2(end.x, end.z)):
					_bridge_ends.append(end)
	GeoBatch.tag = "building%d" % spec.id
	_floors = n
	_roof_access = has_roof_access(spec.theme, n)
	_door_paint = DOOR_PAINTS[_rng.randi_range(0, DOOR_PAINTS.size() - 1)]
	var entrances := _plan_floors(n, tallest)
	if _corridor and not entrances.all(func(e): return _into_hall(e.side, e.at)):
		# Its hall can't reach the street (neighbours or stairs at both ends): plan it open instead.
		_mode = "zones"
		_corridor = false
		_hall = {}
		_runs = []
		entrances = _plan_floors(n, tallest)
	_objectives_off_walls(layout)
	# A narrow hall has nowhere else for stairs, so its Tag spot gives way. Parks and alleys always remain.
	var stair_space := (_stair.hole as Rect2).grow(0.5)
	layout.objectives = layout.objectives.filter(func(o: Dictionary): return not stair_space.has_point(o.pos))
	_windows = []
	var y := 0.0
	for level in n:
		var h: float = _hs[level]
		_windows.append([] as Array[Rect2])
		# The top storey's walls stop a hair under the roof, so they can't fight with its surface.
		_outer_walls(level, y, h - (0.02 if level == n - 1 else 0.0), entrances if level == 0 else [])
		if level == 0:
			_shopfronts(entrances, h)
		_floor_slab(y, level == 0, _stair_hole() if level > 0 else Rect2())
		if _has_flight_from(level):
			_ramps(y, h)
		_build_level(level, y, h, _floor_blocked(entrances if level == 0 else []))
		y += h
	_floor_slab(y, false, _roof_hole() if _roof_access else Rect2(), "roof")
	_roof(y)


## Stairs, entrances and every floor's rooms, retried with new stairs until it all fits.
func _plan_floors(n: int, tallest: float) -> Array:
	var entrances := []
	for attempt in STAIR_ATTEMPTS:
		_stair = _plan_stairs(tallest, _corridor) if n > 1 or _roof_access else _no_stairs()
		_plans = []
		entrances = _plan_entrances()
		var fits := true
		for level in n:
			var plan := _plan_corridor(level) if _corridor else _plan_zones(level, entrances, attempt == STAIR_ATTEMPTS - 1)
			fits = fits and plan.fits
			_plans.append(plan)
		if _doors_swing_clear(entrances) and fits:
			break
	return entrances


## Tight buildings may need a different stair layout before their one door can open.
func _doors_swing_clear(entrances: Array) -> bool:
	for e in entrances:
		var line := _side_line(e.side)
		var p: Vector2 = line[0].lerp(line[1], e.at / line[0].distance_to(line[1]))
		if Rect2(p, Vector2.ZERO).grow(rules.door_width + 0.4).intersects(_stair.hole):
			return false
	return true


func _has_flight_from(level: int) -> bool:
	return level < _floors - 1 or (level == _floors - 1 and _roof_access)


## A hall with rooms both sides when there's depth for them, one side when there's only room for
## that, otherwise the building is zoned like an open hall.
func _pick_mode() -> String:
	if RoomPlans.program(_spec.theme).layout != "corridor":
		return "zones"
	var short := minf(_rect.size.x, _rect.size.y) - rules.wall_thickness * 2.0
	if short >= rules.corridor_width + MIN_ROOM_DEPTH * 2.0 + 0.4:
		return "corridor"
	if short >= rules.corridor_width + MIN_ROOM_DEPTH + 0.2:
		return "single"
	return "zones"


# ------------------------------------------------------------------ walls

## Axis-aligned wall from a to b (metres on the ground), outer face flush so runs stay smooth.
## openings: [{at: distance along the wall, w, bottom, top}]
func _wall(a: Vector2, b: Vector2, y: float, h: float, thick: float, mat: String, openings: Array) -> void:
	var length := a.distance_to(b)
	var dir := (b - a) / length
	# A floor-to-ceiling gap is kept even when it runs off the wall's end: it just shortens the wall.
	var clamped := []
	for o in openings:
		var from: float = maxf(o.at - o.w * 0.5, 0.0)
		var to: float = minf(o.at + o.w * 0.5, length)
		if o.top >= 99.0 and to > from:
			clamped.append({"at": (from + to) * 0.5, "w": to - from, "bottom": 0.0, "top": 99.0})
		elif o.at - o.w * 0.5 > 0.2 and o.at + o.w * 0.5 < length - 0.2:
			clamped.append(o)
	openings = clamped
	openings.sort_custom(func(p, q): return p.at < q.at)
	var cursor := 0.0
	for o in openings:
		var start: float = maxf(o.at - o.w * 0.5, cursor)
		var stop: float = o.at + o.w * 0.5
		if stop <= cursor:
			continue
		_wall_piece(a, dir, cursor, start, y, h, thick, mat)
		if o.bottom > 0.0:
			_wall_piece(a, dir, start, stop, y, o.bottom, thick, mat)
			_wall_piece(a, dir, start, stop, y + o.bottom - 0.08, 0.12, thick + 0.1, _theme[1])
		if o.top < h:
			_wall_piece(a, dir, start, stop, y + o.top, h - o.top, thick, mat)
			_wall_piece(a, dir, start, stop, y + o.top - 0.04, 0.12, thick + 0.1, _theme[1])
		cursor = stop
	_wall_piece(a, dir, cursor, length, y, h, thick, mat)


func _wall_piece(a: Vector2, dir: Vector2, from: float, to: float, y: float, h: float, thick: float, mat: String) -> void:
	if to - from < 0.01 or h < 0.01:
		return
	var mid := a + dir * (from + to) * 0.5
	var size := Vector3(to - from, h, thick) if absf(dir.x) > 0.5 else Vector3(thick, h, to - from)
	geo.box(mat, Vector3(mid.x, y + h * 0.5, mid.y), size)


## Where the ground-floor doors go: up to max_building_doors on sides with open air in front, clear
## of inner walls, stairs and neighbours. Every building gets at least one.
func _plan_entrances() -> Array:
	var out := []
	var sides := [0, 1, 2, 3]
	ProcGen._shuffle(sides, _rng)
	for side: int in sides:
		var length := _rect.size.x if side < 2 else _rect.size.y
		if out.size() >= rules.max_building_doors or length < 6.0 or not _side_is_open(side):
			continue
		for attempt in 12:
			var at := length * _rng.randf_range(0.25, 0.75)
			if _corridor and attempt == 0:
				at = _hall_end_at(side)
			if _entrance_fits(side, at) and _apart_from_entrances(side, at, out):
				out.append({"side": side, "at": at})
				break
	if out.is_empty():
		out.append(_fallback_entrance(sides))
	return out


## A tight spot: any open side will do, as long as the door can swing clear of the stairs.
func _fallback_entrance(sides: Array) -> Dictionary:
	var open := sides.filter(_side_is_open)
	var options: Array = open if not open.is_empty() else [0]
	for side: int in options:
		var line := _side_line(side)
		for share: float in [0.5, 0.35, 0.65, 0.2, 0.8]:
			var p: Vector2 = line[0].lerp(line[1], share)
			var at: float = line[0].distance_to(line[1]) * share
			if _corridor and share == 0.5:
				at = _hall_end_at(side)
				p = line[0].lerp(line[1], at / line[0].distance_to(line[1]))
			if not Rect2(p, Vector2.ZERO).grow(3.2).intersects(_stair.hole) and _into_hall(side, at):
				return {"side": side, "at": at}
	return {"side": options[0], "at": (_rect.size.x if options[0] < 2 else _rect.size.y) * 0.5}


## Two doors either side of a corner can't both swing out into the same spot.
func _apart_from_entrances(side: int, at: float, chosen: Array) -> bool:
	var p: Vector2 = _side_line(side)[0] + (_side_line(side)[1] - _side_line(side)[0]).normalized() * at
	for e in chosen:
		var q: Vector2 = _side_line(e.side)[0] + (_side_line(e.side)[1] - _side_line(e.side)[0]).normalized() * e.at
		if p.distance_to(q) < rules.door_width * 2.0 + 1.0:
			return false
	return true


## Where the middle of the hall meets this side, as a distance along it.
func _hall_end_at(side: int) -> float:
	var mid: float = (_hall.hall[0] + _hall.hall[1]) * 0.5
	if (side < 2) == _hall.along_x:
		return _rect.size.x * 0.5 if side < 2 else _rect.size.y * 0.5
	return mid - (_rect.position.y if side >= 2 else _rect.position.x)


## True if a doorway here opens into the hall: always so for open-plan buildings.
func _into_hall(side: int, at: float) -> bool:
	if not _corridor:
		return true
	var line := _side_line(side)
	var dir: Vector2 = (line[1] - line[0]).normalized()
	var p: Vector2 = line[0] + dir * at
	var hall := _span_rect(_hall.long_start, _hall.long_start + _hall.long, _hall.hall[0], _hall.hall[1], _hall.along_x).grow(rules.wall_thickness)
	var reach := rules.door_width * 0.5 + 0.3
	return hall.has_point(p + dir * reach) and hall.has_point(p - dir * reach)


func _entrance_fits(side: int, at: float) -> bool:
	if not _into_hall(side, at):
		return false
	# An open door's tip reaches past its hinge, since it swings beyond square.
	if not _clear_of_inner_walls(side, at, rules.door_width * 0.5 + 1.2):
		return false
	var line := _side_line(side)
	var p: Vector2 = line[0].lerp(line[1], at / line[0].distance_to(line[1]))
	var swing := Rect2(p, Vector2.ZERO).grow(rules.door_width + 1.1)
	# Doors swing both ways, so leave room for that from the stairs and from a neighbour's corner.
	for other in _others:
		if swing.intersects(other):
			return false
	return not Rect2(p, Vector2.ZERO).grow(3.2).intersects(_stair.hole)


## An awning over each entrance and a name board over the main one. Visual only, so walls stay smooth.
func _shopfronts(entrances: Array, h: float) -> void:
	var cloth: String = AWNINGS[_rng.randi_range(0, AWNINGS.size() - 1)]
	var lettered := false
	for e in entrances:
		var line := _side_line(e.side)
		var p: Vector2 = line[0].lerp(line[1], e.at / line[0].distance_to(line[1]))
		var out := _outward(e.side)
		_awning(cloth, p, out)
		var board_y := rules.door_height + 1.0
		if not lettered and h >= board_y + 0.4:
			lettered = true
			_name_board(e, board_y, out)


## The awning scene stands on the ground at the wall's outer face, with its front along +Z.
func _awning(cloth: String, door: Vector2, out: Vector2) -> void:
	var at := door + out * rules.wall_thickness * 0.5
	Clutter.place(geo, "awning", Vector3(at.x, rules.door_height - AWNING_DOOR_HEIGHT, at.y), atan2(out.x, out.y) / (PI * 0.5), cloth)


## A board sized to its lettering, moved along the wall if it would run off the end.
func _name_board(entrance: Dictionary, board_y: float, out: Vector2) -> void:
	var line := _side_line(entrance.side)
	var length: float = line[0].distance_to(line[1])
	var text := MapLayout.display_name(_spec.name).to_upper()
	var natural := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, BOARD_FONT_SIZE).x * LABEL_PIXEL_SIZE
	var widest := minf(length - BOARD_MARGIN * 2.0, BOARD_MAX_WIDTH)
	var text_width := minf(natural, widest - BOARD_MARGIN * 2.0)
	var font_size := int(BOARD_FONT_SIZE * text_width / natural)
	var board_w := text_width + BOARD_MARGIN * 2.0
	var at := clampf(entrance.at, board_w * 0.5 + BOARD_MARGIN, length - board_w * 0.5 - BOARD_MARGIN)
	var p: Vector2 = line[0].lerp(line[1], at / length)
	var along_x: bool = entrance.side < 2
	var height := 0.72 * float(font_size) / BOARD_FONT_SIZE
	var board := Vector3(board_w, height, 0.05) if along_x else Vector3(0.05, height, board_w)
	var off := rules.wall_thickness * 0.5 + 0.03
	geo.box("trim_cream", Vector3(p.x + out.x * off, board_y, p.y + out.y * off), board, 0)
	var yaw: float = [PI, 0.0, -PI * 0.5, PI * 0.5][entrance.side]
	signs.append({"pos": Vector3(p.x + out.x * (off + 0.04), board_y, p.y + out.y * (off + 0.04)), "yaw": yaw, "text": text, "size": font_size})


static func _outward(side: int) -> Vector2:
	return [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)][side]


func _clear_of_inner_walls(side: int, at: float, margin: float) -> bool:
	for offset in _inner_wall_offsets(side):
		if absf(at - offset) < margin:
			return false
	return true


## Where interior walls meet an outer side, as distances along that side.
func _inner_wall_offsets(side: int, level := 0) -> Array:
	var base := _rect.position.x if side < 2 else _rect.position.y
	var line := _side_line(side)
	var out := []
	if level < _plans.size():
		for l: Dictionary in _plans[level].lines:
			for end: Vector2 in [l.a, l.b]:
				if _on_side(end, side):
					out.append((end.x if side < 2 else end.y) - base)
		return out
	if not _corridor or level >= _runs.size():
		return out
	# Before a hall floor is planned: its hall walls and the walls between its rooms.
	var along_x: bool = _hall.along_x
	if (side < 2) == along_x:
		for si in 2:
			for i in range(1, _runs[level][si].size()):
				out.append(_hall.long_start + _runs[level][si][i].from - base)
	else:
		for c: float in _hall.hall:
			out.append(c - base)
	return out


## True if a point on an interior wall's line reaches this outer side.
func _on_side(p: Vector2, side: int) -> bool:
	var inner := _rect.grow(-rules.wall_thickness)
	match side:
		0: return absf(p.y - inner.position.y) < 0.06
		1: return absf(p.y - inner.end.y) < 0.06
		2: return absf(p.x - inner.position.x) < 0.06
	return absf(p.x - inner.end.x) < 0.06


func _side_is_open(side: int) -> bool:
	var probe := _rect
	match side:
		0: probe = Rect2(_rect.position - Vector2(0, 2.5), Vector2(_rect.size.x, 2.5))
		1: probe = Rect2(Vector2(_rect.position.x, _rect.end.y), Vector2(_rect.size.x, 2.5))
		2: probe = Rect2(_rect.position - Vector2(2.5, 0), Vector2(2.5, _rect.size.y))
		3: probe = Rect2(Vector2(_rect.end.x, _rect.position.y), Vector2(2.5, _rect.size.y))
	if not _bounds.grow(2.0).encloses(probe):
		return false
	for other in _others:
		if other.intersects(probe):
			return false
	return true


## True if a neighbouring building stands against this point of a wall.
func _in_contact(side: int, at: float) -> bool:
	var line := _side_line(side)
	var p: Vector2 = line[0].lerp(line[1], at / line[0].distance_to(line[1]))
	var outside := Rect2(p + _outward(side) * (rules.wall_thickness * 0.5 + 0.3), Vector2.ZERO).grow(1.1)
	for other in _others:
		if outside.intersects(other):
			return true
	return false


## True if a neighbouring building touches this side anywhere.
func _side_touches(side: int) -> bool:
	var line := _side_line(side)
	var length: float = line[0].distance_to(line[1])
	var at := 0.0
	while at <= length:
		if _in_contact(side, at):
			return true
		at += 1.0
	return false


## Side 0 = north (min z), 1 = south, 2 = west (min x), 3 = east.
func _side_line(side: int) -> Array:
	var t := rules.wall_thickness * 0.5
	match side:
		0: return [Vector2(_rect.position.x, _rect.position.y + t), Vector2(_rect.end.x, _rect.position.y + t)]
		1: return [Vector2(_rect.position.x, _rect.end.y - t), Vector2(_rect.end.x, _rect.end.y - t)]
		2: return [Vector2(_rect.position.x + t, _rect.position.y), Vector2(_rect.position.x + t, _rect.end.y)]
	return [Vector2(_rect.end.x - t, _rect.position.y), Vector2(_rect.end.x - t, _rect.end.y)]


func _outer_walls(level: int, y: float, h: float, entrances: Array) -> void:
	var windows: int = _theme[5] + (EXTRA_WINDOWS_UP_HIGH if _floors > 1 else 0)
	for side in 4:
		var line := _side_line(side)
		var length: float = line[0].distance_to(line[1])
		var openings := []
		for e in entrances:
			if e.side == side:
				openings.append({"at": e.at, "w": rules.door_width, "bottom": 0.0, "top": rules.door_height})
				var p: Vector2 = line[0].lerp(line[1], e.at / length)
				doors.append({"pos": Vector3(p.x, y, p.y), "along_x": side < 2, "paint": _door_paint})
		var offsets := _inner_wall_offsets(side, level)
		# Few windows, kept to one end of the side: the rest stays a clean wall-running surface.
		for w in windows:
			var at := length * (0.15 + 0.7 * (float(w) + _rng.randf()) / maxf(windows, 1))
			var clash := false
			for o in openings:
				clash = clash or absf(o.at - at) < 2.6
			for off in offsets:
				clash = clash or absf(off - at) < 1.2
			var spot: Vector2 = line[0].lerp(line[1], at / length)
			for room in _plans[level].rooms:
				clash = clash or (room.kind in NO_WINDOWS and (room.rect as Rect2).grow(rules.wall_thickness + 0.9).has_point(spot))
			if length > 7.0 and not clash and h > 3.0 and not _in_contact(side, at):
				openings.append({"at": at, "w": 1.6, "bottom": rules.window_bottom, "top": minf(rules.window_bottom + rules.window_height, h - 0.3)})
				var p: Vector2 = line[0].lerp(line[1], at / length)
				_windows[level].append(Rect2(p, Vector2.ZERO).grow(1.1))
		_wall(line[0], line[1], y, h, rules.wall_thickness, _theme[0], openings)
	_trim_bands(y + h - 0.1)


## A band hiding each floor line, on every side not pressed against a neighbour.
func _trim_bands(y: float) -> void:
	var c := _rect.get_center()
	var long_x := Vector3(_rect.size.x + 0.1, 0.2, 0.08)
	var long_z := Vector3(0.08, 0.2, _rect.size.y + 0.1)
	var bands := [
		[Vector3(c.x, y, _rect.position.y - 0.04), long_x], [Vector3(c.x, y, _rect.end.y + 0.04), long_x],
		[Vector3(_rect.position.x - 0.04, y, c.y), long_z], [Vector3(_rect.end.x + 0.04, y, c.y), long_z],
	]
	for side in 4:
		if not _side_touches(side):
			geo.box(_theme[1], bands[side][0], bands[side][1], 0)


# ------------------------------------------------------------------ floors

## Slab with its top at y, split around the stair hole. The ground floor is a thin finish.
func _floor_slab(y: float, ground: bool, hole: Rect2, surface := "") -> void:
	var r := _rect.grow(-0.02)
	var mat: String = surface if surface != "" else _theme[2]
	if ground:
		geo.box(mat, Vector3(r.get_center().x, GROUND_FINISH * 0.5, r.get_center().y), Vector3(r.size.x, GROUND_FINISH, r.size.y), 0)
		return
	var t := rules.slab_thickness
	if not hole.has_area():
		geo.box(mat, Vector3(r.get_center().x, y - t * 0.5, r.get_center().y), Vector3(r.size.x, t, r.size.y), GeoBatch.FLOOR)
		geo.box("plaster", Vector3(r.get_center().x, y - t - 0.005, r.get_center().y), Vector3(r.size.x, 0.01, r.size.y), 0)
		return
	var parts := [
		Rect2(r.position, Vector2(r.size.x, hole.position.y - r.position.y)),
		Rect2(Vector2(r.position.x, hole.end.y), Vector2(r.size.x, r.end.y - hole.end.y)),
		Rect2(Vector2(r.position.x, hole.position.y), Vector2(hole.position.x - r.position.x, hole.size.y)),
		Rect2(Vector2(hole.end.x, hole.position.y), Vector2(r.end.x - hole.end.x, hole.size.y)),
	]
	for part in parts:
		if part.size.x > 0.02 and part.size.y > 0.02:
			geo.box(mat, Vector3(part.get_center().x, y - t * 0.5, part.get_center().y), Vector3(part.size.x, t, part.size.y), GeoBatch.FLOOR)
			geo.box("plaster", Vector3(part.get_center().x, y - t - 0.005, part.get_center().y), Vector3(part.size.x, 0.01, part.size.y), 0)


func _floor_blocked(entrances: Array) -> Array[Rect2]:
	var blocked := _keep_clear.duplicate()
	blocked.append((_stair.zone as Rect2).grow(1.0))
	for e in entrances:
		var line := _side_line(e.side)
		var p: Vector2 = line[0].lerp(line[1], e.at / line[0].distance_to(line[1]))
		blocked.append(Rect2(p, Vector2.ZERO).grow(2.8))
	return blocked


func _roof(y: float) -> void:
	var r := _rect
	var ph := rules.parapet_height
	var t := 0.3
	# Starts just below the roof line, so it closes the small gap above the top storey's walls.
	var cy := y + (ph - 0.03) * 0.5
	var tall := ph + 0.03
	geo.box(_theme[1], Vector3(r.get_center().x, cy, r.position.y + t * 0.5), Vector3(r.size.x, tall, t))
	geo.box(_theme[1], Vector3(r.get_center().x, cy, r.end.y - t * 0.5), Vector3(r.size.x, tall, t))
	geo.box(_theme[1], Vector3(r.position.x + t * 0.5, cy, r.get_center().y), Vector3(t, tall, r.size.y))
	geo.box(_theme[1], Vector3(r.end.x - t * 0.5, cy, r.get_center().y), Vector3(t, tall, r.size.y))
	var blocked: Array[Rect2] = []
	if _roof_access:
		blocked.append(_roof_hole().grow(1.5))
	for end in _bridge_ends:
		blocked.append(Rect2(Vector2(end.x, end.z), Vector2.ZERO).grow(rules.bridge_width))
	var usable := r.grow(-1.0)
	var count := int(usable.get_area() / 55.0) + 1
	for i in count:
		var prefab: String = ["ac_unit", "hvac", "vent", "dish", "antenna", "water_tower", "ac_unit", "vent"][_rng.randi_range(0, 7)]
		var size := Clutter.size_of(prefab)
		var at := Vector2(_rng.randf_range(usable.position.x, usable.end.x - size.x), _rng.randf_range(usable.position.y, usable.end.y - size.y))
		var foot := Rect2(at, size)
		var free := true
		for other in blocked:
			free = free and not foot.grow(1.0).intersects(other)
		if free:
			blocked.append(foot)
			Clutter.place(geo, prefab, Vector3(foot.get_center().x, y, foot.get_center().y), 0)


# ------------------------------------------------------------------ stairs

## One plan repeated on every floor, placed clear of Tag and spawn spots.
func _plan_stairs(h: float, corridor: bool) -> Dictionary:
	var plan := {}
	for attempt in 12:
		plan = _stair_variant(h, corridor)
		var clear := true
		for spot in _keep_clear:
			clear = clear and not (plan.zone as Rect2).grow(0.4).intersects(spot)
		for end in _bridge_ends:
			clear = clear and not (plan.zone as Rect2).grow(rules.bridge_width).has_point(Vector2(end.x, end.z))
		if clear:
			break
	return plan


## For buildings with nowhere to go: every stair check passes, far away from everything.
func _no_stairs() -> Dictionary:
	var nowhere := Rect2(FAR_AWAY, Vector2.ZERO)
	return {"rect": nowhere, "hole": nowhere, "zone": nowhere, "wall_side": -1}


## Varied per building: a straight flight or a switchback, against either wall, climbing either way.
## Keeps the gentle slope when it fits, and always leaves a landing at each end to walk around onto it.
func _stair_variant(h: float, corridor: bool) -> Dictionary:
	var inner := _rect.grow(-rules.wall_thickness)
	var along_x := inner.size.x >= inner.size.y
	var long := inner.size.x if along_x else inner.size.y
	var short := inner.size.y if along_x else inner.size.x
	var width := clampf(short - 2.2, 2.0, rules.stair_width)
	var run := h / tan(deg_to_rad(rules.stair_slope_deg))
	var landing := rules.stair_landing
	var room := long - landing * 2.0
	var fits_switchback := not corridor and run * 0.5 <= room and short >= width * 2.0 + 2.5
	var switchback := fits_switchback and (run > room or _rng.randf() < 0.5)
	var flight := run * 0.5 if switchback else minf(run, room)
	var across := width * 2.0 if switchback else width
	var climbs_up := _rng.randf() < 0.5
	var far_side := _rng.randf() < 0.5
	# Against a hall wall in corridor plans, an outer wall in open halls, just off its face.
	var low := inner.position.y if along_x else inner.position.x
	var high := inner.end.y if along_x else inner.end.x
	var face_gap := 0.01
	if corridor:
		low = _hall.hall[0]
		high = _hall.hall[1]
		face_gap = 0.11
	var across_start := high - across - face_gap if far_side else low + face_gap
	var long_start := inner.position.x if along_x else inner.position.y
	var at := long_start + landing if climbs_up else long_start + long - landing - flight
	var rect := Rect2(at, across_start, flight, across) if along_x else Rect2(across_start, at, across, flight)
	# The hole above takes in a switchback's turning platform, so it has full headroom too.
	var turn := rules.stair_turn if switchback else 0.0
	var hole := rect
	if along_x:
		hole = rect.grow_individual(0.0 if climbs_up else turn, 0.0, turn if climbs_up else 0.0, 0.0)
	else:
		hole = rect.grow_individual(0.0, 0.0 if climbs_up else turn, 0.0, turn if climbs_up else 0.0)
	# The floor kept clear: the hole plus a landing at each end.
	var zone := hole.grow_individual(landing, 0.0, landing, 0.0) if along_x else hole.grow_individual(0.0, landing, 0.0, landing)
	return {"rect": rect, "hole": hole, "zone": zone, "along_x": along_x, "dir": 1.0 if climbs_up else -1.0, "switchback": switchback, "turn": turn, "wall_side": 1 if far_side else 0}


func _stair_hole() -> Rect2:
	return _stair.hole


## Roofs stay closed except where the last flight comes up: a switchback's upper flight, or just the
## top of a straight one, where you'd otherwise hit your head.
func _roof_hole() -> Rect2:
	var along_x: bool = _stair.along_x
	var r: Rect2 = _stair.rect
	var hole: Rect2 = _stair.hole
	if _stair.switchback:
		# A low top storey: the lower flight needs the open roof over it as well.
		if _spec.floor_h * 0.5 - rules.slab_thickness < ROOF_HEADROOM:
			return hole
		if along_x:
			return Rect2(hole.position.x, r.position.y + r.size.y * 0.5, hole.size.x, r.size.y * 0.5)
		return Rect2(r.position.x + r.size.x * 0.5, hole.position.y, r.size.x * 0.5, hole.size.y)
	var h: float = _hs[-1]
	var flight := r.size.x if along_x else r.size.y
	var covered := flight * clampf((h - ROOF_HEADROOM) / h, 0.0, 1.0)
	var climbs_up: bool = _stair.dir > 0.0
	if along_x:
		return r.grow_individual(-covered if climbs_up else 0.0, 0.0, 0.0 if climbs_up else -covered, 0.0)
	return r.grow_individual(0.0, -covered if climbs_up else 0.0, 0.0, 0.0 if climbs_up else -covered)


func _ramps(y: float, h: float) -> void:
	var outer_tag := GeoBatch.tag
	GeoBatch.tag = outer_tag + "_stairs"
	_ramp_flights(y, h)
	GeoBatch.tag = outer_tag


func _ramp_flights(y: float, h: float) -> void:
	var r: Rect2 = _stair.rect
	var along_x: bool = _stair.along_x
	var dir: float = _stair.dir
	var start := (r.position.x if along_x else r.position.y) if dir > 0.0 else (r.end.x if along_x else r.end.y)
	var stop := (r.end.x if along_x else r.end.y) if dir > 0.0 else (r.position.x if along_x else r.position.y)
	var across_low := r.position.y if along_x else r.position.x
	var across := r.size.y if along_x else r.size.x
	if not _stair.switchback:
		_ramp(start, stop, y, y + h, across_low + across * 0.5, across)
		return
	var half := across * 0.5
	var mid := y + h * 0.5
	var center := across_low + half
	_ramp(start, stop, y, mid, across_low + half * 0.5, half)
	_ramp(stop, start, mid, y + h, across_low + half * 1.5, half)
	# The platform where it turns.
	var turn: float = _stair.turn
	var platform_c := stop + dir * turn * 0.5
	var pos := Vector3(platform_c, mid - 0.12, center) if along_x else Vector3(center, mid - 0.12, platform_c)
	var size := Vector3(turn, 0.24, across) if along_x else Vector3(across, 0.24, turn)
	geo.box("concrete", pos, size, GeoBatch.FLOOR)


## A plain smooth ramp, good for sliding.
func _ramp(from_long: float, to_long: float, y0: float, y1: float, across_c: float, width: float) -> void:
	var along_x: bool = _stair.along_x
	var low_y := maxf(y0, GROUND_FINISH)
	var a := Vector3(from_long, low_y, across_c) if along_x else Vector3(across_c, low_y, from_long)
	var b := Vector3(to_long, y1, across_c) if along_x else Vector3(across_c, y1, to_long)
	if flight_log != null:
		flight_log.append([a, b, width, _spec.theme, ProcGen.height(_spec)])
	var forward := (b - a).normalized()
	var side := Vector3.UP.cross(forward).normalized()
	var up := forward.cross(side).normalized()
	geo.box("concrete", (a + b) * 0.5 - up * RAMP_THICKNESS * 0.5, Vector3(width, RAMP_THICKNESS, a.distance_to(b) + 0.02), GeoBatch.FLOOR, Basis(side, up, forward))


## The hall's frame: its long axis, its two walls (across), and where the rooms are on each side.
## Side 0 is beyond the hall's low wall, side 1 beyond its high wall; [] when that side has none.
func _hall_frame() -> Dictionary:
	var inner := _rect.grow(-rules.wall_thickness)
	var along_x := inner.size.x >= inner.size.y
	var low := inner.position.y if along_x else inner.position.x
	var high := inner.end.y if along_x else inner.end.x
	var cw := rules.corridor_width
	var hall: Array
	var sides: Array
	if _mode == "corridor":
		var mid := (low + high) * 0.5
		hall = [mid - cw * 0.5, mid + cw * 0.5]
		sides = [[low, hall[0]], [hall[1], high]]
	elif _rng.randf() < 0.5:
		hall = [low, low + cw]
		sides = [[], [hall[1], high]]
	else:
		hall = [high - cw, high]
		sides = [[low, hall[0]], []]
	return {"along_x": along_x, "long_start": inner.position.x if along_x else inner.position.y, "long": inner.size.x if along_x else inner.size.y, "hall": hall, "sides": sides, "inner": inner}


## The rooms along each side of a hall floor: what the floor must have once, then its repeating room.
func _plan_runs(level: int) -> Array:
	var def: Dictionary = RoomPlans.floor_def(_spec.theme, level)
	var once: Array = (def.once as Array).duplicate()
	var out := [[], []]
	for si in 2:
		if not (_hall.sides[si] as Array).is_empty():
			out[si] = _sequence(once, def.fill, _hall.long)
	return out


## Rooms filling one side's length, each a length from its kind's range. Must-haves that don't fit
## stay in `once` for the other side.
func _sequence(once: Array, fill: Array, total: float) -> Array:
	var rooms := []
	var used := 0.0
	var i := 0
	while total - used >= 2.5:
		var kind: String = once[0] if not once.is_empty() else fill[i % fill.size()]
		var span: Array = RoomPlans.room(kind).len
		if used + span[0] > total + 0.01:
			if once.is_empty():
				break
			once.pop_front()  # a must-have too long for what's left: the other side may have room
			continue
		if not once.is_empty():
			once.pop_front()
		else:
			i += 1
		var length := minf(_rng.randf_range(span[0], span[1]), total - used)
		rooms.append({"kind": kind, "len": length})
		used += length
	if rooms.is_empty():
		rooms.append({"kind": fill[0], "len": total})
		used = total
	# What's left over is shared out, so the rooms fill the side exactly.
	var k := total / used
	var at := 0.0
	for r in rooms:
		r["from"] = at
		at += r.len * k
		r["to"] = at
	return rooms


## A hall floor: the hall, then each side's rooms with a way in from the hall. A room whose hall
## wall is taken up by the stairs gets a doorway through to its neighbour instead.
func _plan_corridor(level: int) -> Dictionary:
	var along_x: bool = _hall.along_x
	var long_start: float = _hall.long_start
	var long: float = _hall.long
	var hall: Array = _hall.hall
	var rooms := []
	var lines := []
	var door_list := []
	var stair: Rect2 = _stair.zone
	var stair_from := (stair.position.x if along_x else stair.position.y) - long_start
	var stair_to := (stair.end.x if along_x else stair.end.y) - long_start
	var hall_rect := _span_rect(long_start, long_start + long, hall[0], hall[1], along_x)
	rooms.append({"kind": RoomPlans.program(_spec.theme).hall, "rect": _face(hall_rect), "front": 0 if along_x else 2, "solid": [true, true, true, true], "walled": false})
	for si in 2:
		var side: Array = _hall.sides[si]
		if side.is_empty():
			continue
		var wall_c: float = hall[si]
		var far: float = side[0] if si == 0 else side[1]
		var run: Array = _runs[level][si].duplicate(true)
		var fill: Array = RoomPlans.floor_def(_spec.theme, level).fill
		var mi := 0
		while run.size() > 1 and mi < run.size():
			if _room_door_spot(run[mi].from, run[mi].to, long, stair_from, stair_to, si == _stair.wall_side) >= 0.0:
				mi += 1
				continue
			var into: int = mi - 1 if mi > 0 else mi + 1
			run[into].from = minf(run[into].from, run[mi].from)
			run[into].to = maxf(run[into].to, run[mi].to)
			if run[mi].kind not in fill:
				run[into].kind = run[mi].kind
			run.remove_at(mi)
			mi = 0
		var openings := []
		var walled_off := []
		for ri in run.size():
			var r: Dictionary = run[ri]
			var info := RoomPlans.room(r.kind)
			var parts: Array = info.get("parts", [[r.kind, 1.0]])
			var depth := absf(far - wall_c)
			# A deep home: the part you walk into runs along the hall, the rest sit side by side behind it.
			var deep := parts.size() > 1 and depth >= DEEP_HOME
			# The part you walk into comes first, at whichever end its door fits.
			var spans := []
			var at := -1.0
			for flip: bool in [false, true]:
				spans = [[parts[0][0], r.from, r.to]] if deep else _part_spans(parts, r.from, r.to, flip)
				at = _room_door_spot(spans[0][1], spans[0][2], long, stair_from, stair_to, si == _stair.wall_side)
				if at >= 0.0:
					break
			var door_p := _pt(long_start + (at if at >= 0.0 else (r.from + r.to) * 0.5), wall_c, along_x)
			if at < 0.0:
				walled_off.append(ri)
			else:
				openings.append(_opening(at, info.opening, r.to - r.from))
				if info.opening == "door":
					door_list.append({"p": door_p, "along_x": along_x})
			if deep:
				_deep_home(parts, r.from, r.to, wall_c, far, door_p, rooms, lines, door_list)
				continue
			for k in spans.size():
				var sp: Array = spans[k]
				var rect := _span_rect(long_start + sp[1], long_start + sp[2], minf(wall_c, far), maxf(wall_c, far), along_x)
				rooms.append({"kind": sp[0], "rect": _face(rect), "front": _front_for(rect, door_p, sp[0]), "solid": [true, true, true, true], "walled": true})
				if k > 0:
					# Inside a home: a door between its parts, deep in then near the hall, so doors never line up.
					var boundary: float = long_start + (sp[2] if sp[1] < spans[k - 1][1] else sp[1])
					var t := 0.72 if k % 2 == 1 else 0.28
					lines.append({"a": _pt(boundary, wall_c, along_x), "b": _pt(boundary, far, along_x),
						"openings": [{"at": depth * t, "w": DOORWAY, "bottom": 0.0, "top": rules.door_height}]})
					door_list.append({"p": _pt(boundary, lerpf(wall_c, far, t), along_x), "along_x": not along_x, "w": DOORWAY})
		lines.append({"a": _pt(long_start, wall_c, along_x), "b": _pt(long_start + long, wall_c, along_x), "openings": openings})
		for i in range(1, run.size()):
			var cross: float = long_start + run[i].from
			var cross_openings := []
			if i in walled_off or (i - 1) in walled_off:
				cross_openings.append({"at": absf(far - wall_c) * 0.3, "w": rules.door_width, "bottom": 0.0, "top": rules.door_height})
				door_list.append({"p": _pt(cross, lerpf(wall_c, far, 0.3), along_x), "along_x": not along_x})
			lines.append({"a": _pt(cross, wall_c, along_x), "b": _pt(cross, far, along_x), "openings": cross_openings})
	return {"rooms": rooms, "lines": lines, "doors": door_list, "fits": true}


## The entered part along the hall, from..to, then the other parts side by side behind it, each
## with its own door from the entered part, so no room is a long thin slice and no doors line up.
func _deep_home(parts: Array, from: float, to: float, wall_c: float, far: float, door_p: Vector2, rooms: Array, lines: Array, door_list: Array) -> void:
	var along_x: bool = _hall.along_x
	var l0: float = _hall.long_start
	var depth := absf(far - wall_c)
	var split := far - signf(far - wall_c) * clampf(depth * 0.45, 3.0, 4.2)
	var front := _span_rect(l0 + from, l0 + to, minf(wall_c, split), maxf(wall_c, split), along_x)
	rooms.append({"kind": parts[0][0], "rect": _face(front), "front": _front_for(front, door_p, parts[0][0]), "solid": [true, true, true, true], "walled": true})
	var rest := 0.0
	for k in range(1, parts.size()):
		rest += float(parts[k][1])
	var a := from
	var openings := []
	for k in range(1, parts.size()):
		var b: float = to if k == parts.size() - 1 else a + (to - from) * float(parts[k][1]) / rest
		var rect := _span_rect(l0 + a, l0 + b, minf(split, far), maxf(split, far), along_x)
		var p := _pt(l0 + (a + b) * 0.5, split, along_x)
		openings.append({"at": (a + b) * 0.5 - from, "w": DOORWAY, "bottom": 0.0, "top": rules.door_height})
		door_list.append({"p": p, "along_x": along_x, "w": DOORWAY})
		rooms.append({"kind": parts[k][0], "rect": _face(rect), "front": _front_for(rect, p, parts[k][0]), "solid": [true, true, true, true], "walled": true})
		if k > 1:
			lines.append({"a": _pt(l0 + a, split, along_x), "b": _pt(l0 + a, far, along_x), "openings": []})
		a = b
	lines.append({"a": _pt(l0 + from, split, along_x), "b": _pt(l0 + to, split, along_x), "openings": openings})


## [[kind, from, to], ...] along a room, the first part at the start, or at the end when flipped.
func _part_spans(parts: Array, from: float, to: float, flip: bool) -> Array:
	const MIN_PART := 2.8
	var lengths := []
	for part: Array in parts:
		lengths.append(maxf((to - from) * part[1], MIN_PART if not lengths.is_empty() else 0.0))
	lengths[0] = (to - from) - (lengths.reduce(func(a, b): return a + b) - lengths[0])
	var out := []
	var at := to if flip else from
	for pi in parts.size():
		var part: Array = parts[pi]
		var length: float = lengths[pi]
		var a: float = at - length if flip else at
		out.append([part[0], a, a + length])
		at = a if flip else at + length
	return out


## A spot on the hall wall for this room's door, or -1 if the stairs take up all of it.
func _room_door_spot(from: float, to: float, long: float, stair_from: float, stair_to: float, on_stair_wall: bool) -> float:
	var margin := rules.door_width * 0.5 + 1.2  # an open door's tip reaches past its hinge
	var candidates := [lerpf(from, to, _rng.randf_range(0.3, 0.7)), from + margin, to - margin, (from + to) * 0.5]
	# Also clear of the hall's end, where a door from outside swings in.
	const END_CLEARANCE := 4.4
	for at: float in candidates:
		var off_stairs: bool = not on_stair_wall or at + margin < stair_from or at - margin > stair_to
		var inside := at - rules.door_width * 0.5 >= from + 0.6 and at + rules.door_width * 0.5 <= to - 0.6
		if inside and off_stairs and at > END_CLEARANCE and at < long - END_CLEARANCE:
			return at
	return -1.0


func _opening(at: float, kind: String, span: float) -> Dictionary:
	var w := rules.door_width
	if kind == "wide":
		w = clampf(span - 1.2, rules.door_width, 4.0)
	return {"at": at, "w": w, "bottom": 0.0, "top": rules.door_height}


## An open-plan floor: bands running back from the main entrance, split across into areas. Walled
## areas get their walls and a way in. A walled area can't hold the stairs or stand in an entrance's
## way: the plan reorders each band to avoid that, and on the last try the area is cut short of them.
func _plan_zones(level: int, entrances: Array, give_up: bool) -> Dictionary:
	var key := "floors" if RoomPlans.program(_spec.theme).layout == "zones" else "zones"
	var bands: Array = RoomPlans.floor_def(_spec.theme, level, key)
	var front: int = entrances[0].side if not entrances.is_empty() else 0
	var swings: Array[Rect2] = []
	if level == 0:
		for e in entrances:
			swings.append(Rect2(_entrance_point(e), Vector2.ZERO).grow(rules.door_width + 0.6))
	var cells := []
	var fits := false
	for order in 8:
		cells = _zone_cells(bands, front, order)
		fits = cells.all(func(c): return not c.walled or _cell_clear(c, swings))
		if fits:
			break
	if not fits and give_up:
		cells = _zone_cells(bands, front, 0)
		for c in cells.duplicate():
			if c.walled and not _cell_clear(c, swings):
				_cut_short(c, cells, swings)
		fits = true
	var lines := _zone_lines(cells)
	var door_list := []
	var rooms := []
	for c in cells:
		var door := Vector2.INF
		if c.walled:
			door = _zone_door(c, cells, lines, door_list, front)
		rooms.append({"kind": c.kind, "rect": _face(c.rect), "front": _front_for(c.rect, door, c.kind) if door != Vector2.INF else [1, 0, 3, 2][front],
			"solid": _cell_solid(c), "walled": c.walled})
	# A strip cut off a room, with no open floor beside it, is reached through that room.
	for c in cells:
		if c.has("cut_from") and not _touches_open(c, cells):
			_zone_door(c.cut_from, cells, lines, door_list, front, _side_facing(c.cut_from.rect, c.rect), c)
	var seeds: Array[Vector2] = []
	if level == 0:
		for e in entrances:
			seeds.append(_entrance_point(e) - _outward(e.side) * 1.0)
	else:
		seeds.append((_stair.zone as Rect2).get_center())
	_connect(cells, lines, door_list, front, seeds)
	return {"rooms": rooms, "lines": lines, "doors": door_list, "fits": fits}


## Every area must be reachable, from the street on the ground floor and from the stairs above it.
## An area cut off (say, a food court behind a row of shops) gets a door from a neighbour that can
## be reached; a walled room other than a restroom or auditorium becomes the way through first.
func _connect(cells: Array, lines: Array, door_list: Array, front: int, seeds: Array[Vector2]) -> void:
	var reached := {}
	for k in cells.size():
		for p in seeds:
			if (cells[k].rect as Rect2).grow(0.3).has_point(p):
				reached[k] = true
	for attempt in cells.size() * 2:
		# Spread through open floor and doorways.
		var grew := true
		while grew:
			grew = false
			for a: int in reached.keys():
				for b in cells.size():
					if not reached.has(b) and _linked(cells, a, b):
						reached[b] = true
						grew = true
		if reached.size() == cells.size():
			return
		# Then one new door from a reachable area into one that isn't.
		var fixed := false
		for prefer_plain: bool in [true, false]:
			for u in cells.size():
				if reached.has(u):
					continue
				for v: int in reached.keys():
					var through: int = v if not cells[u].walled else u
					if prefer_plain and cells[through].kind in ["public_restroom", "restroom", "auditorium"]:
						continue
					var other: int = u if through == v else v
					var side := _shared_side(cells[through].rect, cells[other].rect)
					if side >= 0 and cells[through].walled and _zone_door(cells[through], cells, lines, door_list, front, side, cells[other]) != Vector2.INF:
						reached[u] = true
						fixed = true
						break
				if fixed:
					break
			if fixed:
				break
		if not fixed:
			return


## True if you can walk from area a to area b: open floor beside open floor, or a doorway between.
func _linked(cells: Array, a: int, b: int) -> bool:
	if b in cells[a].get("links", []) or a in cells[b].get("links", []):
		return true
	if cells[a].walled or cells[b].walled:
		return false
	var shared := (cells[a].rect as Rect2).grow(0.05).intersection(cells[b].rect)
	return maxf(shared.size.x, shared.size.y) >= 1.8


## The side of a that runs alongside b for at least a doorway and its margins, or -1.
static func _shared_side(a: Rect2, b: Rect2) -> int:
	var shared := a.grow(0.06).intersection(b)
	if maxf(shared.size.x, shared.size.y) < 2.6 or minf(shared.size.x, shared.size.y) > 0.2:
		return -1
	return _side_facing(a, b)


## Shrinks a walled area to the biggest part clear of the stairs and entrance doors, one at a time.
## What's cut off becomes open floor. If too little is left, the area swaps places with an open one.
func _cut_short(c: Dictionary, cells: Array, swings: Array[Rect2], can_swap := true) -> void:
	var need := 7.0 if c.kind == "auditorium" else 2.6
	var obstacles: Array[Rect2] = [(_stair.zone as Rect2).grow(STAIR_SIDE)]
	for sw in swings:
		obstacles.append(sw.grow(0.15))
	var oi := 0
	while oi < obstacles.size():
		var o: Rect2 = obstacles[oi]
		oi += 1
		var r: Rect2 = c.rect
		if not r.intersects(o):
			continue
		var hit := r.intersection(o)
		var keep := Rect2()
		var rest := Rect2()
		var x0 := minf(hit.position.x, r.end.x - MIN_STRIP)
		var x1 := maxf(hit.end.x, r.position.x + MIN_STRIP)
		var y0 := minf(hit.position.y, r.end.y - MIN_STRIP)
		var y1 := maxf(hit.end.y, r.position.y + MIN_STRIP)
		for cut: Array in [[Rect2(r.position.x, r.position.y, x0 - r.position.x, r.size.y), Rect2(x0, r.position.y, r.end.x - x0, r.size.y)],
				[Rect2(x1, r.position.y, r.end.x - x1, r.size.y), Rect2(r.position.x, r.position.y, x1 - r.position.x, r.size.y)],
				[Rect2(r.position.x, r.position.y, r.size.x, y0 - r.position.y), Rect2(r.position.x, y0, r.size.x, r.end.y - y0)],
				[Rect2(r.position.x, y1, r.size.x, r.end.y - y1), Rect2(r.position.x, r.position.y, r.size.x, y1 - r.position.y)]]:
			var k: Rect2 = cut[0]
			if minf(k.size.x, k.size.y) >= need and k.get_area() >= 7.0 and k.get_area() > keep.get_area():
				keep = k
				rest = cut[1]
		if not keep.has_area() and c.kind == "auditorium" and need > 5.0:
			need = 5.0
			oi -= 1
			continue
		if not keep.has_area():
			if can_swap:
				_swap_or_open(c, cells, swings, need)
			else:
				c.walled = false
				c.kind = _open_kind(cells, c)
			return
		c.rect = _snap(keep)
		cells.append({"kind": "stair_hall", "rect": _snap(rest), "walled": false, "band": c.band, "cut_from": c})


## Trades places with the smallest clear area big enough for it: open floor first, then another
## walled room, which is then cut short itself. Opens up only when nothing fits.
func _swap_or_open(c: Dictionary, cells: Array, swings: Array[Rect2], need: float) -> void:
	for walled: bool in [false, true]:
		var best: Dictionary = {}
		for o in cells:
			var r: Rect2 = o.rect
			if o == c or o.walled != walled or o.has("cut_from") or o.kind in ["stair_hall", "public_restroom", "restroom", "auditorium"]:
				continue
			if minf(r.size.x, r.size.y) < need or not _cell_clear(o, swings):
				continue
			if best.is_empty() or r.get_area() < (best.rect as Rect2).get_area():
				best = o
		if best.is_empty():
			continue
		var kind: String = c.kind
		c.kind = best.kind
		c.walled = walled
		best.kind = kind
		best.walled = true
		if walled:
			_cut_short(c, cells, swings, false)
		return
	c.walled = false
	c.kind = _open_kind(cells, c)


static func _snap(r: Rect2) -> Rect2:
	var lo := r.position.snappedf(0.01)
	return Rect2(lo, r.end.snappedf(0.01) - lo)


## True if open floor runs alongside this area for at least a doorway's width.
func _touches_open(c: Dictionary, cells: Array) -> bool:
	for o in cells:
		if o != c and not o.walled:
			var shared := (c.rect as Rect2).grow(0.05).intersection(o.rect)
			if maxf(shared.size.x, shared.size.y) >= 1.8:
				return true
	return false


## The side of a that faces b, when they share an edge.
static func _side_facing(a: Rect2, b: Rect2) -> int:
	if absf(a.position.y - b.end.y) < 0.06:
		return 0
	if absf(a.end.y - b.position.y) < 0.06:
		return 1
	if absf(a.position.x - b.end.x) < 0.06:
		return 2
	return 3


func _entrance_point(e: Dictionary) -> Vector2:
	var line := _side_line(e.side)
	return line[0].lerp(line[1], e.at / line[0].distance_to(line[1]))


## Splits the floor into the plan's bands and areas. Bands and areas too thin to use join a neighbour.
## order 0-7 rearranges each band's areas: reversed from 4 up, then rotated by order % 4.
func _zone_cells(bands: Array, front: int, order: int) -> Array:
	var inner := _rect.grow(-rules.wall_thickness)
	var depth: float = inner.size.x if front >= 2 else inner.size.y
	var width: float = inner.size.y if front >= 2 else inner.size.x
	var list := []
	for b: Array in bands:
		list.append([float(b[0]), (b[1] as Array).duplicate(true)])
	while list.size() > 1:
		var thin := -1
		for i in list.size():
			if list[i][0] * depth < 2.8:
				thin = i
		if thin < 0:
			break
		var into := thin - 1 if thin > 0 else 1
		list[into][0] += list[thin][0]
		list.remove_at(thin)
	var cells := []
	var d0 := 0.0
	for bi in list.size():
		var bd: float = list[bi][0] * depth
		var row: Array = list[bi][1]
		if order >= 4:
			row.reverse()
		for turn in order % 4 % maxi(row.size(), 1):
			row.push_back(row.pop_front())
		while row.size() > 1:
			var thin := -1
			for i in row.size():
				if float(row[i][1]) * width < 2.6:
					thin = i
			if thin < 0:
				break
			var into := thin - 1 if thin > 0 else 1
			row[into][1] = float(row[into][1]) + float(row[thin][1])
			row.remove_at(thin)
		var a0 := 0.0
		for ci in row.size():
			var w: float = float(row[ci][1]) * width
			if ci == row.size() - 1:
				w = width - a0
			var rect := _band_rect(inner, front, d0, d0 + bd, a0, a0 + w)
			cells.append({"kind": row[ci][0], "rect": rect, "walled": RoomPlans.walled(row[ci][0]), "band": bi})
			a0 += w
		d0 += bd
	return cells


## A rectangle d0..d1 back from the front side and a0..a1 across it, snapped to the centimetre.
func _band_rect(inner: Rect2, front: int, d0: float, d1: float, a0: float, a1: float) -> Rect2:
	var r: Rect2
	match front:
		0: r = Rect2(inner.position.x + a0, inner.position.y + d0, a1 - a0, d1 - d0)
		1: r = Rect2(inner.position.x + a0, inner.end.y - d1, a1 - a0, d1 - d0)
		2: r = Rect2(inner.position.x + d0, inner.position.y + a0, d1 - d0, a1 - a0)
		_: r = Rect2(inner.end.x - d1, inner.position.y + a0, d1 - d0, a1 - a0)
	var lo := r.position.snappedf(0.01)
	return Rect2(lo, r.end.snappedf(0.01) - lo)


func _cell_clear(c: Dictionary, swings: Array[Rect2]) -> bool:
	if (c.rect as Rect2).grow(STAIR_SIDE - 0.05).intersects(_stair.zone):
		return false
	for s in swings:
		if (c.rect as Rect2).grow(0.1).intersects(s):
			return false
	return true


func _open_kind(cells: Array, c: Dictionary) -> String:
	for other in cells:
		if not other.walled and other.band == c.band:
			return other.kind
	for other in cells:
		if not other.walled:
			return other.kind
	return "living"


## The walls of walled areas, one per line, so neighbours never get two walls on top of each other.
func _zone_lines(cells: Array) -> Array:
	var inner := _rect.grow(-rules.wall_thickness)
	var runs := {}
	for c in cells:
		if not c.walled:
			continue
		var r: Rect2 = c.rect
		for e: Array in [["x", r.position.x, r.position.y, r.end.y], ["x", r.end.x, r.position.y, r.end.y], ["z", r.position.y, r.position.x, r.end.x], ["z", r.end.y, r.position.x, r.end.x]]:
			var on_edge: bool = absf(e[1] - (inner.position.x if e[0] == "x" else inner.position.y)) < 0.06 or absf(e[1] - (inner.end.x if e[0] == "x" else inner.end.y)) < 0.06
			if not on_edge:
				var key := "%s%.2f" % [e[0], e[1]]
				if not runs.has(key):
					runs[key] = []
				runs[key].append([e[2], e[3]])
	var lines := []
	for key: String in runs:
		var spans: Array = runs[key]
		spans.sort_custom(func(p, q): return p[0] < q[0])
		var merged := []
		for sp: Array in spans:
			if not merged.is_empty() and sp[0] <= merged[-1][1] + 0.05:
				merged[-1][1] = maxf(merged[-1][1], sp[1])
			else:
				merged.append(sp.duplicate())
		var c := float(key.substr(1))
		for sp: Array in merged:
			if key.begins_with("x"):
				lines.append({"a": Vector2(c, sp[0]), "b": Vector2(c, sp[1]), "openings": []})
			else:
				lines.append({"a": Vector2(sp[0], c), "b": Vector2(sp[1], c), "openings": []})
	return lines


## A way into a walled area: on the side facing the entrance if it can, else another inner side.
## The other side of the opening must be open floor, clear of the stairs.
## A door can be asked for on one side (only_side) and into one neighbour (target). Each door's far
## side is recorded in the area's "links", by index into cells.
func _zone_door(c: Dictionary, cells: Array, lines: Array, door_list: Array, front: int, only_side := -1, target: Dictionary = {}) -> Vector2:
	var inner := _rect.grow(-rules.wall_thickness)
	var r: Rect2 = c.rect
	var kind: String = RoomPlans.room(c.kind).opening
	# Small rooms get the narrow door, so it doesn't fill half the room when it opens.
	var narrow := kind == "door" and r.get_area() < SMALL_ROOM
	var order: Array = [only_side] if only_side >= 0 else [front, [2, 3, 0, 1][front], [3, 2, 1, 0][front], [1, 0, 3, 2][front]]
	for strict: bool in [true, false]:
		for w: int in order:
			if _is_outer(r, w):
				continue
			var a := _edge(r, w)[0] as Vector2
			var b := _edge(r, w)[1] as Vector2
			var length := a.distance_to(b)
			var op := _opening(0.0, kind, length)
			if narrow:
				op.w = DOORWAY
			var half: float = op.w * 0.5 + 0.6
			if length < half * 2.0:
				continue
			var n := _normal(w)
			for t: float in [0.5, 0.3, 0.7, 0.4, 0.6, 0.2, 0.8, 0.15, 0.85]:
				var along := length * t
				if along < half or length - along < half:
					continue
				var p := a.lerp(b, t)
				var q := p + n * 0.8
				var ok := inner.has_point(q) and not Rect2(p, Vector2.ZERO).grow(half).intersects(_stair.zone.grow(0.2))
				if not target.is_empty():
					ok = ok and (target.rect as Rect2).has_point(q)
				for other in cells:
					if strict and other != c and other.walled and (other.rect as Rect2).has_point(q):
						ok = false
				for d in door_list:
					ok = ok and p.distance_to(d.p) > 2.0
				for l in lines:
					ok = ok and l.a.distance_to(p) >= half and l.b.distance_to(p) >= half
				if not ok:
					continue
				for l in lines:
					var on: bool = Geometry2D.get_closest_point_to_segment(p, l.a, l.b).distance_to(p) < 0.02
					if on:
						var o := _opening(p.distance_to(l.a), kind, length)
						o.w = op.w
						l.openings.append(o)
						break
				if kind == "door":
					door_list.append({"p": p, "along_x": w < 2, "w": op.w})
				for k in cells.size():
					if (cells[k].rect as Rect2).has_point(q):
						c["links"] = c.get("links", []) + [k]
				return p
	return Vector2.INF


## Which of a rectangle's sides are walls: the building's own walls, or all four if it's walled.
func _cell_solid(c: Dictionary) -> Array:
	var out := []
	for w in 4:
		out.append(c.walled or _is_outer(c.rect, w))
	return out


## The side rows face: the wall furthest from the way in, an inner wall if there is one (outer walls
## have windows).
func _front_for(rect: Rect2, door: Vector2, kind := "") -> int:
	for outer_ok: bool in [kind in NO_WINDOWS, true]:
		var best := -1
		var best_d := -1.0
		for w in 4:
			if _is_outer(rect, w) and not outer_ok:
				continue
			var e := _edge(rect, w)
			var d := ((e[0] as Vector2) + (e[1] as Vector2)).distance_to(door * 2.0) * 0.5
			if d > best_d:
				best_d = d
				best = w
		if best >= 0 and best_d > 1.0:
			return best
	return 0


## Side w of a rectangle as two points: 0 -Z, 1 +Z, 2 -X, 3 +X.
static func _edge(r: Rect2, w: int) -> Array:
	match w:
		0: return [r.position, Vector2(r.end.x, r.position.y)]
		1: return [Vector2(r.position.x, r.end.y), r.end]
		2: return [r.position, Vector2(r.position.x, r.end.y)]
	return [Vector2(r.end.x, r.position.y), r.end]


static func _normal(w: int) -> Vector2:
	return [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)][w]


func _is_outer(r: Rect2, w: int) -> bool:
	var inner := _rect.grow(-rules.wall_thickness)
	match w:
		0: return absf(r.position.y - inner.position.y) < 0.06
		1: return absf(r.end.y - inner.end.y) < 0.06
		2: return absf(r.position.x - inner.position.x) < 0.06
	return absf(r.end.x - inner.end.x) < 0.06


## The floor inside a room's walls: inner walls are 0.2 thick, centred on the room's edge.
func _face(r: Rect2) -> Rect2:
	var cut := []
	for w in 4:
		cut.append(0.0 if _is_outer(r, w) else 0.1)
	return r.grow_individual(-cut[2], -cut[0], -cut[3], -cut[1])


static func _span_rect(l0: float, l1: float, c0: float, c1: float, along_x: bool) -> Rect2:
	return Rect2(l0, c0, l1 - l0, c1 - c0) if along_x else Rect2(c0, l0, c1 - c0, l1 - l0)


## Builds a planned floor: its inner walls and doors, then each room's furniture and lamps.
func _build_level(level: int, y: float, h: float, blocked: Array[Rect2]) -> void:
	var plan: Dictionary = _plans[level]
	var ceiling := h - rules.slab_thickness
	for d in plan.doors:
		var door := {"pos": Vector3(d.p.x, y, d.p.y), "along_x": d.along_x, "paint": _door_paint}
		if d.has("w"):
			door["w"] = d.w
		doors.append(door)
	for l in plan.lines:
		var openings: Array = (l.openings as Array).duplicate()
		var dir: Vector2 = (l.b - l.a).normalized()
		# The doorway and the floor either side of it, so nothing stands in the way.
		for o in openings:
			var c: Vector2 = l.a + dir * o.at
			# An open door stands a little past square, so it reaches back along the wall past its hinge.
			var half := Vector2(o.w * 0.5 + 0.45, o.w + 0.2) if absf(dir.x) > 0.5 else Vector2(o.w + 0.2, o.w * 0.5 + 0.45)
			blocked.append(Rect2(c - half, half * 2.0))
		_wall(l.a, l.b, y, ceiling, 0.2, _theme[3], openings)
	for room in plan.rooms:
		var r: Rect2 = room.rect
		var faces_front: bool = (Interiors.PLANS.get(room.kind, []) as Array).any(func(st): return st[0] == "head")
		if not room.walled and not faces_front and r.get_area() > PILLAR_AREA:
			_pillars(r, y, ceiling, blocked)
		# Margins round stairs, entrances and Tag spots outside a walled room don't reach through its walls.
		var room_blocked: Array[Rect2] = []
		room_blocked.assign(blocked.filter(func(b): return not room.walled or r.grow(rules.wall_thickness + 0.1).has_point(b.get_center())))
		# Too small for a row of stalls: a single toilet and sink, like a cafe's restroom.
		var kind: String = "restroom" if room.kind == "public_restroom" and r.get_area() < 12.0 else room.kind
		var placed := Interiors.furnish(geo, kind, r, y, ceiling, room.front, _rng, rules, room_blocked, _stair.hole, room.solid, _windows[level])
		_ceiling_lamps(y + h, r)
		if room_log != null:
			room_log.append({"theme": _spec.theme, "level": level, "y": y, "kind": room.kind, "rect": r, "walled": room.walled, "building": _spec.id, "placed": placed, "front": room.front, "blocked": room_blocked.filter(func(b): return b.intersects(r))})


## Columns on a grid through a big open area: cover, and they break up long sight lines.
func _pillars(area: Rect2, y: float, ceiling: float, blocked: Array[Rect2]) -> void:
	const SPACING := 11.0
	var nx := int(area.size.x / SPACING)
	var nz := int(area.size.y / SPACING)
	for ix in range(1, nx):
		for iz in range(1, nz):
			var p := area.position + Vector2(area.size.x * ix / nx, area.size.y * iz / nz)
			var foot := Rect2(p, Vector2.ZERO).grow(0.45)
			var free := true
			for other in blocked:
				free = free and not foot.intersects(other)
			if free:
				geo.box("trim", Vector3(p.x, y + ceiling * 0.5, p.y), Vector3(0.7, ceiling, 0.7))
				blocked.append(foot)


## A Tag spot on or beside an inner wall moves to the middle of the nearest roomy area on its floor,
## so walls never need a gap for it.
func _objectives_off_walls(layout: MapLayout) -> void:
	for level in _floors:
		var plan: Dictionary = _plans[level]
		for o: Dictionary in layout.objectives:
			if not _rect.has_point(o.pos) or absf(o.get("y", 0.0) - ProcGen.level_y(_spec, level)) > 0.05:
				continue
			var near_wall: bool = plan.lines.any(func(l): return Geometry2D.get_closest_point_to_segment(o.pos, l.a, l.b).distance_to(o.pos) < 1.4)
			if not near_wall:
				continue
			var best := Vector2.INF
			for open_only: bool in [true, false]:
				for room in plan.rooms:
					var r: Rect2 = room.rect
					var c := r.get_center()
					var fine: bool = not (open_only and room.walled) and room.kind not in NO_WINDOWS and room.kind != "stair_hall"
					if fine and minf(r.size.x, r.size.y) >= 3.0 and not (_stair.zone as Rect2).grow(1.0).has_point(c) and c.distance_to(o.pos) < best.distance_to(o.pos):
						best = c
				if best != Vector2.INF:
					break
			if best == Vector2.INF:
				continue
			for i in _keep_clear.size():
				if _keep_clear[i].get_center().is_equal_approx(o.pos):
					_keep_clear[i] = Rect2(best, Vector2.ZERO).grow(rules.keep_clear_radius)
			o.pos = best


## Lamps down the middle of an area, each one a real light. Rows run further apart in big rooms.
func _ceiling_lamps(ceiling_y: float, area: Rect2) -> void:
	const SPACING := 8.0
	var along_x := area.size.x >= area.size.y
	var count := maxi(int((area.size.x if along_x else area.size.y) / SPACING), 1)
	var rows := maxi(int((area.size.y if along_x else area.size.x) / SPACING), 1)
	var lamp_y := ceiling_y - rules.slab_thickness - 0.05
	for i in count:
		for row in rows:
			var t := (i + 0.5) / count
			var u := (row + 0.5) / rows
			var p := area.position + area.size * (Vector2(t, u) if along_x else Vector2(u, t))
			if not _stair.hole.grow(0.5).has_point(p):
				Clutter.place(geo, "ceiling_lamp", Vector3(p.x, lamp_y, p.y), 0)
				lights.append(Vector3(p.x, lamp_y - 0.4, p.y))


static func _pt(long_value: float, across: float, along_x: bool) -> Vector2:
	return Vector2(long_value, across) if along_x else Vector2(across, long_value)
