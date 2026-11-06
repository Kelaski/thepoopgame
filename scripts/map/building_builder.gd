class_name BuildingBuilder extends RefCounted
## Turns one building plan into boxes: outer walls with few windows, floors with stair holes,
## interior rooms, ramps, roof parapet and contextual clutter.

## theme -> [outer wall, trim, floor, inner wall, plan, windows per side per floor]
## plan: "corridor" = rooms off a central hall; "open" = one big hall with pillars.
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
	var n: int = spec.floors
	var h: float = spec.floor_h
	var corridor := _uses_corridor()
	_corridor = corridor
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
	var entrances := []
	for attempt in STAIR_ATTEMPTS:
		_stair = _plan_stairs(h, corridor) if n > 1 or _roof_access else _no_stairs()
		entrances = _plan_entrances()
		if _doors_swing_clear(entrances):
			break
	# A narrow hall has nowhere else for stairs, so its Tag spot gives way. Parks and alleys always remain.
	var stair_space := (_stair.hole as Rect2).grow(0.5)
	layout.objectives = layout.objectives.filter(func(o: Dictionary): return not stair_space.has_point(o.pos))
	for level in n:
		var y := level * h
		# The top storey's walls stop a hair under the roof, so they can't fight with its surface.
		_outer_walls(y, h - (0.02 if level == n - 1 else 0.0), entrances if level == 0 else [])
		if level == 0:
			_shopfronts(entrances, h)
		_floor_slab(y, level == 0, _stair_hole() if level > 0 else Rect2())
		if _has_flight_from(level):
			_ramps(y, h)
		var blocked := _floor_blocked(entrances if level == 0 else [])
		if corridor:
			_corridor_floor(y, h, blocked)
		else:
			_open_floor(y, h, blocked)
	_floor_slab(n * h, false, _roof_hole() if _roof_access else Rect2(), "roof")
	_roof(n * h)


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


func _uses_corridor() -> bool:
	return _theme[4] == "corridor" and minf(_rect.size.x, _rect.size.y) >= rules.min_width_for_corridor


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
			if not Rect2(p, Vector2.ZERO).grow(3.2).intersects(_stair.hole):
				return {"side": side, "at": line[0].distance_to(line[1]) * share}
	return {"side": options[0], "at": (_rect.size.x if options[0] < 2 else _rect.size.y) * 0.5}


## Two doors either side of a corner can't both swing out into the same spot.
func _apart_from_entrances(side: int, at: float, chosen: Array) -> bool:
	var p: Vector2 = _side_line(side)[0] + (_side_line(side)[1] - _side_line(side)[0]).normalized() * at
	for e in chosen:
		var q: Vector2 = _side_line(e.side)[0] + (_side_line(e.side)[1] - _side_line(e.side)[0]).normalized() * e.at
		if p.distance_to(q) < rules.door_width * 2.0 + 1.0:
			return false
	return true


func _entrance_fits(side: int, at: float) -> bool:
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


## Where interior walls meet an outer side, as distances along that side. Corridor plans only.
func _inner_wall_offsets(side: int) -> Array:
	if not _corridor:
		return []
	var inner := _rect.grow(-rules.wall_thickness)
	var along_x: bool = inner.size.x >= inner.size.y
	var base := _rect.position.x if side < 2 else _rect.position.y
	var out := []
	if (side < 2) == along_x:
		var long := inner.size.x if along_x else inner.size.y
		var long_start := inner.position.x if along_x else inner.position.y
		var count := maxi(int(long / rules.room_length), 1)
		for i in range(1, count):
			out.append(long_start + long / count * i - base)
	else:
		var mid := inner.get_center().y if along_x else inner.get_center().x
		out.append(mid - rules.corridor_width * 0.5 - base)
		out.append(mid + rules.corridor_width * 0.5 - base)
	return out


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


func _outer_walls(y: float, h: float, entrances: Array) -> void:
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
		# Few windows, kept to one end of the side: the rest stays a clean wall-running surface.
		for w in windows:
			var at := length * (0.15 + 0.7 * (float(w) + _rng.randf()) / maxf(windows, 1))
			var clash := false
			for o in openings:
				clash = clash or absf(o.at - at) < 2.6
			if length > 7.0 and not clash and h > 3.0 and _clear_of_inner_walls(side, at, 1.2) and not _in_contact(side, at):
				openings.append({"at": at, "w": 1.6, "bottom": rules.window_bottom, "top": minf(rules.window_bottom + rules.window_height, h - 0.3)})
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
		var mid := inner.get_center().y if along_x else inner.get_center().x
		low = mid - rules.corridor_width * 0.5
		high = mid + rules.corridor_width * 0.5
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
	var h: float = _spec.floor_h
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
		flight_log.append([a, b, width, _spec.theme, _floors * _spec.floor_h])
	var forward := (b - a).normalized()
	var side := Vector3.UP.cross(forward).normalized()
	var up := forward.cross(side).normalized()
	geo.box("concrete", (a + b) * 0.5 - up * RAMP_THICKNESS * 0.5, Vector3(width, RAMP_THICKNESS, a.distance_to(b) + 0.02), GeoBatch.FLOOR, Basis(side, up, forward))


## Rooms either side of a central hall, each with a doorway. A room whose hall wall is taken up by
## the stairs gets a doorway through to its neighbour instead. Walls never cross a keep-clear spot.
func _corridor_floor(y: float, h: float, blocked: Array[Rect2]) -> void:
	var inner := _rect.grow(-rules.wall_thickness)
	var along_x: bool = inner.size.x >= inner.size.y
	var long := inner.size.x if along_x else inner.size.y
	var long_start := inner.position.x if along_x else inner.position.y
	var mid := inner.get_center().y if along_x else inner.get_center().x
	var half := rules.corridor_width * 0.5
	var low := (inner.position.y if along_x else inner.position.x)
	var high := (inner.end.y if along_x else inner.end.x)
	var count := maxi(int(long / rules.room_length), 1)
	var room_len := long / count
	var mat: String = _theme[3]
	var stair: Rect2 = _stair.zone
	var stair_from := (stair.position.x if along_x else stair.position.y) - long_start
	var stair_to := (stair.end.x if along_x else stair.end.y) - long_start
	var ceiling := h - rules.slab_thickness
	for side in 2:
		var wall_c := mid - half if side == 0 else mid + half
		var openings := []
		var walled_off := []
		for i in count:
			var at := _room_door_spot(room_len * i, room_len * (i + 1), long, stair_from, stair_to, side == _stair.wall_side)
			if at < 0.0:
				walled_off.append(i)
				continue
			openings.append({"at": at, "w": rules.door_width, "bottom": 0.0, "top": rules.door_height})
			var p := _pt(long_start + at, wall_c, along_x)
			doors.append({"pos": Vector3(p.x, y, p.y), "along_x": along_x, "paint": _door_paint})
			blocked.append(Rect2(p, Vector2.ZERO).grow(2.8))
		_add_gaps(openings, wall_c, long_start, along_x, y, h)
		_wall(_pt(long_start, wall_c, along_x), _pt(long_start + long, wall_c, along_x), y, ceiling, 0.2, mat, openings)
		for i in range(1, count):
			var cross := long_start + room_len * i
			var c0 := low if side == 0 else wall_c
			var c1 := wall_c if side == 0 else high
			var cross_openings := []
			_add_cross_gaps(cross_openings, cross, c0, along_x, y)
			if i in walled_off or (i - 1) in walled_off:
				var door_at := (c1 - c0) * 0.5
				cross_openings.append({"at": door_at, "w": rules.door_width, "bottom": 0.0, "top": rules.door_height})
				blocked.append(Rect2(_pt(cross, c0 + door_at, along_x), Vector2.ZERO).grow(1.4))
			_wall(_pt(cross, c0, along_x), _pt(cross, c1, along_x), y, ceiling, 0.2, mat, cross_openings)
	for side in 2:
		for i in count:
			var from := long_start + room_len * i
			var c0 := low if side == 0 else mid + half
			var c1 := mid - half if side == 0 else high
			var room := Rect2(from, c0, room_len, c1 - c0) if along_x else Rect2(c0, from, c1 - c0, room_len)
			Interiors.furnish(geo, _spec.theme, room.grow(-0.15), y, ceiling, 2 if along_x else 0, _rng, rules, blocked, _stair.hole)
			_ceiling_lamps(y + h, room)
	_ceiling_lamps(y + h, Rect2(long_start, mid - half, long, half * 2.0) if along_x else Rect2(mid - half, long_start, half * 2.0, long))


## A spot on the hall wall for this room's door, or -1 if the stairs take up all of it.
func _room_door_spot(from: float, to: float, long: float, stair_from: float, stair_to: float, on_stair_wall: bool) -> float:
	var margin := rules.door_width * 0.5 + 1.2  # an open door's tip reaches past its hinge
	var candidates := [lerpf(from, to, _rng.randf_range(0.3, 0.7)), from + margin, to - margin]
	# Also clear of the hall's end, where a door from outside swings in.
	const END_CLEARANCE := 4.4
	for at: float in candidates:
		var off_stairs: bool = not on_stair_wall or at + margin < stair_from or at - margin > stair_to
		if off_stairs and at > END_CLEARANCE and at < long - END_CLEARANCE:
			return at
	return -1.0


## One big hall: pillars and half walls to break sight lines, then clutter.
func _open_floor(y: float, h: float, blocked: Array[Rect2]) -> void:
	var inner := _rect.grow(-rules.wall_thickness)
	var spacing := 11.0
	var nx := int(inner.size.x / spacing)
	var nz := int(inner.size.y / spacing)
	for ix in range(1, nx):
		for iz in range(1, nz):
			var p := inner.position + Vector2(inner.size.x * ix / nx, inner.size.y * iz / nz)
			var foot := Rect2(p, Vector2.ZERO).grow(0.45)
			var free := true
			for other in blocked:
				free = free and not foot.intersects(other)
			if free:
				var column := h - rules.slab_thickness
				geo.box("trim", Vector3(p.x, y + column * 0.5, p.y), Vector3(0.7, column, 0.7))
				blocked.append(foot)
	# A low partition: cover to mantle over, breaks long lines of sight.
	if inner.get_area() > 150.0:
		var length := minf(inner.size.x * 0.4, 9.0)
		var p := inner.position + inner.size * Vector2(_rng.randf_range(0.3, 0.6), _rng.randf_range(0.3, 0.7))
		var foot := Rect2(p - Vector2(length * 0.5, 0.15), Vector2(length, 0.3))
		var free := true
		for other in blocked:
			free = free and not foot.grow(0.6).intersects(other)
		if free:
			geo.box(_theme[3], Vector3(p.x, y + 0.6, p.y), Vector3(length, 1.2, 0.3))
			blocked.append(foot)
	Interiors.furnish(geo, _spec.theme, inner.grow(-0.2), y, h - rules.slab_thickness, _rng.randi_range(0, 3), _rng, rules, blocked, _stair.hole)
	_ceiling_lamps(y + h, inner)


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


## Adds a gap wherever a keep-clear spot sits on a hall wall, so Tag and spawn spots stay open.
func _add_gaps(openings: Array, wall_c: float, long_start: float, along_x: bool, _y: float, _h: float) -> void:
	for clear in _keep_clear:
		var c: Vector2 = clear.get_center()
		var across := c.y if along_x else c.x
		var along := c.x if along_x else c.y
		if absf(across - wall_c) < clear.size.x * 0.5:
			openings.append({"at": along - long_start, "w": clear.size.x, "bottom": 0.0, "top": 99.0})


func _add_cross_gaps(openings: Array, cross: float, c0: float, along_x: bool, _y: float) -> void:
	for clear in _keep_clear:
		var c: Vector2 = clear.get_center()
		var along := c.x if along_x else c.y
		var across := c.y if along_x else c.x
		if absf(along - cross) < clear.size.x * 0.5:
			openings.append({"at": across - c0, "w": clear.size.x, "bottom": 0.0, "top": 99.0})


static func _pt(long_value: float, across: float, along_x: bool) -> Vector2:
	return Vector2(long_value, across) if along_x else Vector2(across, long_value)
