class_name Interiors
extends RefCounted
## What goes inside MapBuilder's buildings: ceiling lights and wall decor on every
## storey, and the furniture layout for each building type (the _lay_* functions).
## MapBuilder builds the shell (walls, stairs, rooms) and calls decorate_interior()
## and furnish_floor() for each building; this file only decides where the
## scenes in assets/furniture/ go.

var mb: MapBuilder


func _init(builder: MapBuilder) -> void:
	mb = builder


# ================================================================ interior decor

## Decor theme per building type (scenes in assets/furniture/decor/):
## [ceiling light, wall pieces, floor pieces against the walls, rug on each storey]
const THEME_DECOR := {
	"warehouse": ["industrial_lamp", ["safety_sign", "fire_extinguisher", "wall_pipes", "loading_dock_door"], ["pallet_stack", "trash_can"], false],
	"school": ["ceiling_panel", ["bulletin_board", "wall_clock", "poster", "whiteboard"], ["vending_machine", "trash_can", "water_cooler"], false],
	"theater": ["pendant_lamp", ["movie_poster", "curtain", "wall_lamp"], ["trash_can"], false],
	"bank": ["ceiling_panel", ["picture_frame", "wall_clock"], ["water_cooler"], true],
	"diner": ["pendant_lamp", ["neon_sign", "poster", "wall_clock", "wall_tv"], ["jukebox"], false],
	"arcade": ["ceiling_panel", ["neon_sign", "poster"], ["vending_machine", "trash_can"], false],
	"club": ["pendant_lamp", ["neon_sign", "wall_tv"], ["speaker_stack"], false],
	"bar": ["pendant_lamp", ["neon_sign", "wall_shelf_bottles", "dartboard", "wall_tv"], ["jukebox"], false],
	"apartments": ["pendant_lamp", ["picture_frame", "wall_lamp", "poster"], [], true],
	"mall": ["ceiling_panel", ["poster", "neon_sign", "banner"], ["mannequin", "trash_can"], false],
	"motel": ["pendant_lamp", ["picture_frame", "wall_lamp"], ["vending_machine"], true],
	"rundown": ["pendant_lamp", ["graffiti_panel", "poster", "wall_pipes"], ["trash_can"], false],
	"rundown2": ["pendant_lamp", ["graffiti_panel", "poster", "wall_pipes"], ["trash_can"], false],
	"office": ["ceiling_panel", ["whiteboard", "picture_frame", "wall_clock"], ["water_cooler", "vending_machine", "trash_can"], false],
	"casino": ["chandelier", ["neon_sign", "picture_frame", "curtain"], ["vending_machine"], false],
	"library": ["pendant_lamp", ["picture_frame", "wall_clock", "bulletin_board"], [], true],
	"water": ["industrial_lamp", ["valve_panel", "wall_pipes", "safety_sign"], [], false],
	"sports": ["industrial_lamp", ["banner"], [], false],
}
const LIGHT_STEP := 6.0     # ceiling light spacing (m)
const P_WALL_DECOR := 0.27  # chance a solid wall module gets a wall piece
const P_FLOOR_DECOR := 0.12 # chance it gets a floor piece instead


## Decorates a building's storeys: ceiling mb.lights on a grid (clear of the stair
## holes and room walls), themed pieces on the solid exterior wall modules, floor
## pieces against the walls where no furniture stands, a rug for some types and an
## exit sign over every street door. Lights, signs, frames and rugs are visual only.
func decorate_interior(type: String, floors: int, fh: float, inner: Rect2, stairs: Array, door_spots: Array, floor_zones: Array, floor_cells: Array, floor_walls: Array) -> void:
	var theme: Array = THEME_DECOR.get(type, [])
	if theme.is_empty():
		return
	var light: String = theme[0]
	if light == "industrial_lamp" and fh < 5.5:
		light = "ceiling_panel"  # long drops only in tall halls
	var wall_items: Array = theme[1]
	var floor_items: Array = theme[2]
	var light_yaw := 0.0 if mb._ax else -PI * 0.5
	var nx := maxi(1, roundi(inner.size.x / LIGHT_STEP))
	var nz := maxi(1, roundi(inner.size.y / LIGHT_STEP))
	for k in floors:
		var y := k * fh
		var ceil_y := (k + 1) * fh - MapBuilder.SLAB_T
		var walls: Array = floor_walls[k]
		# Ceiling mb.lights
		for i in nx:
			for j in nz:
				var c := inner.position + Vector2((i + 0.5) * inner.size.x / nx, (j + 0.5) * inner.size.y / nz)
				var spot := Rect2(c - Vector2(0.8, 0.8), Vector2(1.6, 1.6))
				if mb._hits_any(spot, stairs, 0.3) or mb._hits_any(spot, walls, 0.0):
					continue
				mb._prefab("furniture/decor/" + light, MapBuilder._at(Vector3(c.x, ceil_y, c.y), light_yaw))
		if type == "club" and fh >= 5.0:
			var mid := inner.get_center()
			if not mb._hits_any(Rect2(mid - Vector2.ONE, Vector2(2, 2)), stairs, 0.3):
				mb._prefab("furniture/decor/disco_ball", MapBuilder._at(Vector3(mid.x, ceil_y, mid.y)))
		# Rug somewhere clear (under furniture is fine)
		if theme[3]:
			for _attempt in 6:
				var rc := Vector2(mb.rng.randf_range(inner.position.x + 2.0, inner.end.x - 2.0), mb.rng.randf_range(inner.position.y + 2.0, inner.end.y - 2.0))
				var turn := mb.rng.randf() < 0.5
				var half := Vector2(0.9, 1.3) if turn else Vector2(1.3, 0.9)
				if not _blocked(Rect2(rc - half, half * 2.0), floor_zones[k]):
					mb._prefab("furniture/decor/rug", MapBuilder._at(Vector3(rc.x, y, rc.y), PI * 0.5 if turn else 0.0))
					break
	# Wall modules: a wall piece, a floor piece against the wall, or nothing
	var slots := {}    # [storey, face position] of every solid module, to find neighbours
	var covered := {}  # ...and the ones a wide piece covers
	for ws: Array in mb._wall_slots:
		slots[_slot_key(ws[2], ws[0])] = true
	for ws: Array in mb._wall_slots:
		var face: Vector3 = ws[0]
		var inward: Vector3 = ws[1]
		var k: int = ws[2]
		if covered.has(_slot_key(k, face)):
			continue  # behind a loading dock door
		var zones: Array = floor_zones[k]
		var xf := MapBuilder._at(face, MapBuilder._yaw_to(inward))
		var roll := mb.rng.randf()
		if roll < 0.03:
			if not _blocked(_wall_foot(face, inward, 0.4), zones):
				mb._prefab("furniture/decor/fire_extinguisher", xf)
		elif roll < 0.03 + P_WALL_DECOR:
			var item: String = wall_items[mb.rng.randi() % wall_items.size()]
			if item in WIDE_WALL_ITEMS and not _wide_slot_free(slots, covered, ws):
				continue  # it would hang over a corner, a window or the floor above
			if not _blocked(_wall_foot(face, inward, 0.4), zones):
				mb._prefab("furniture/decor/" + item, xf)
		elif roll < 0.03 + P_WALL_DECOR + P_FLOOR_DECOR and not floor_items.is_empty():
			var foot := _wall_foot(face, inward, 1.2)
			if not _blocked(foot, zones) and not mb._hits_any(foot, floor_cells[k], 0.2):
				mb._prefab("furniture/decor/" + floor_items[mb.rng.randi() % floor_items.size()], xf)
				floor_cells[k].append(foot)
	# Exit signs over the street mb.doors, on the inside
	for ds in door_spots:
		var side: int = ds[0]
		var t: float = ds[1]
		var p: Vector3 = [
			Vector3(t, 0, inner.position.y), Vector3(t, 0, inner.end.y),
			Vector3(inner.position.x, 0, t), Vector3(inner.end.x, 0, t),
		][side]
		var inward: Vector3 = [Vector3.BACK, Vector3.FORWARD, Vector3.RIGHT, Vector3.LEFT][side]
		mb._prefab("furniture/decor/exit_sign", MapBuilder._at(p + Vector3(0, MapBuilder.DOOR_H + 0.35, 0), MapBuilder._yaw_to(inward)))


## Wall pieces wider than their 2 m module (the 4 m loading dock door). They go
## only on the ground floor, on a module with solid wall on both sides, and
## never overlap each other.
const WIDE_WALL_ITEMS := ["loading_dock_door"]


static func _slot_key(storey: int, face: Vector3) -> Vector3i:
	return Vector3i(roundi(face.x * 10.0), storey, roundi(face.z * 10.0))


## True (and the three modules are marked covered) if a wide piece fits on wall slot ws.
func _wide_slot_free(slots: Dictionary, covered: Dictionary, ws: Array) -> bool:
	var face: Vector3 = ws[0]
	var inward: Vector3 = ws[1]
	if int(ws[2]) != 0:
		return false
	var along := Vector3(inward.z, 0.0, -inward.x) * MapBuilder.MODULE
	var keys := [_slot_key(0, face - along), _slot_key(0, face), _slot_key(0, face + along)]
	for k: Vector3i in keys:
		if not slots.has(k) or covered.has(k):
			return false  # missing (a corner, a window, a door) or under another wide piece
	for k: Vector3i in keys:
		covered[k] = true
	mb.wide_decor.append([face, along])
	return true


## Floor rect in front of a wall module: 1.9 m along the wall, depth into the room.
static func _wall_foot(face: Vector3, inward: Vector3, depth: float) -> Rect2:
	var hx := absf(inward.z) * 0.95 + absf(inward.x) * depth * 0.5
	var hz := absf(inward.x) * 0.95 + absf(inward.z) * depth * 0.5
	var c := Vector2(face.x + inward.x * depth * 0.5, face.z + inward.z * depth * 0.5)
	return Rect2(c.x - hx, c.y - hz, hx * 2.0, hz * 2.0)


# ================================================================ furniture

func _blocked(r: Rect2, zones: Array) -> bool:
	for z: Rect2 in zones:
		if z.intersects(r):
			return true
	return false



## Interior layouts, laid out the way real places are (furniture scenes in
## assets/furniture/): stores have aisles of shelves and checkouts by the door,
## motel and apartment rooms are furnished rooms, classrooms face a board, and so
## on, with walkways kept open. Everything works in the building's own u (long
## axis) / v coordinates, and every piece is only placed where its footprint is
## clear of the stairs, doorways, room walls, the Tag and other furniture.
## lay holds the building being furnished: {umax, vmax, rooms: [[u0, u1, door_u]],
## mb.doors: [Vector2 uv of each street door], stairs_far: bool, S}.
var lay := {}
var _fzones: Array = []
var _fy := 0.0
var _finner := Rect2()
var _last_xf := Transform3D()
var _placed: Array = []   # transforms of everything placed by the last _run


func furnish_floor(type: String, k: int, inner: Rect2, y: float, fh: float, zones: Array, rooms_here: bool) -> void:
	_fzones = zones
	_fy = y
	_finner = inner
	var rooms: Array = lay.rooms if rooms_here else []
	match type:
		"warehouse":
			_lay_warehouse(k)
		"school":
			_lay_school(k, rooms)
		"motel":
			_lay_motel(k, rooms)
		"apartments":
			_lay_apartments(k, rooms)
		"rundown", "rundown2":
			_lay_rundown(k, rooms)
		"mall":
			_lay_store(k)
		"office":
			_lay_office(k)
		"bank":
			_lay_bank(k)
		"diner":
			_lay_diner(k)
		"bar":
			_lay_bar(k)
		"club":
			_lay_club(k)
		"arcade":
			_lay_arcade(k)
		"casino":
			_lay_casino(k)
		"library":
			_lay_library(k)
		"theater":
			_lay_theater(k, fh)
		_:
			_scatter(["crate"], 4)


# ------------------------------------------------------------------ placement helpers

func _ud() -> Vector3:
	return Vector3(1, 0, 0) if mb._ax else Vector3(0, 0, 1)


func _vd() -> Vector3:
	return Vector3(0, 0, 1) if mb._ax else Vector3(1, 0, 0)


## World footprint of furniture scene `name` placed at p (xz) with yaw.
func _foot_at(name: String, p: Vector2, yaw: float) -> Rect2:
	var f := Prefabs.footprint("furniture/" + name)
	var b := Basis(Vector3.UP, yaw)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for corner: Vector2 in [f.position, Vector2(f.end.x, f.position.y), Vector2(f.position.x, f.end.y), f.end]:
		var w := b * Vector3(corner.x, 0, corner.y)
		lo = lo.min(Vector2(w.x, w.z))
		hi = hi.max(Vector2(w.x, w.z))
	return Rect2(p + lo, hi - lo)


## Places `name` at (u, v) with its local +Z along `face`, if its footprint (plus
## `margin` of walking room) is clear. Returns true if it was placed.
func _put(name: String, u: float, v: float, face: Vector3, slots := {}, margin := 0.15, solid := true, check_zones := true) -> bool:
	var p := mb._uv(u, v)
	var yaw := MapBuilder._yaw_to(face)
	var foot := _foot_at(name, p, yaw)
	if not _finner.grow(0.02).encloses(foot):
		return false
	var room := foot.grow(margin)
	if (check_zones and _blocked(room, _fzones)) or mb._hits_any(foot, mb._occupied, margin):
		return false
	_last_xf = MapBuilder._at(Vector3(p.x, _fy, p.y), yaw)
	mb._prefab("furniture/" + name, _last_xf, slots)
	_placed.append(_last_xf)
	if solid:
		mb._occupied.append(foot)
	return true


## A run of `name` along u at v (or along v at u when along_u is false), spaced
## by its width plus gap. Every `skip`th slot is left open as a cross aisle.
func _run(name: String, along_u: bool, fixed: float, from: float, to: float, face: Vector3, gap := 0.1, skip := 0, slots := {}) -> int:
	var w := Prefabs.footprint("furniture/" + name).size.x
	_placed = []
	var t := from + w * 0.5
	var i := 0
	var placed := 0
	while t + w * 0.5 <= to + 0.01:
		if skip <= 0 or i % skip != skip - 1:
			var ok := _put(name, t, fixed, face, slots) if along_u else _put(name, fixed, t, face, slots)
			if ok:
				placed += 1
		t += w + gap
		i += 1
	return placed


## Rows of `name` along u, stepping across v, for shops, shelves and seating.
func _rows(name: String, v0: float, v1: float, u0: float, u1: float, step_v: float, face: Vector3, gap := 0.1, skip := 0, slots := {}) -> void:
	var v := v0
	while v <= v1 + 0.01:
		_run(name, true, v, u0, u1, face, gap, skip, slots)
		v += step_v


## A grid of `name` (cubicles, tables, booths in the open).
func _grid(name: String, u0: float, u1: float, v0: float, v1: float, step_u: float, step_v: float, face: Vector3, slots := {}) -> void:
	var u := u0
	while u <= u1 + 0.01:
		var v := v0
		while v <= v1 + 0.01:
			_put(name, u, v, face, slots)
			v += step_v
		u += step_u


## Up to n of the given items dropped at random clear spots (for messy places).
func _scatter(names: Array, n: int, slots := {}) -> void:
	var placed := 0
	for i in n * 8:
		if placed >= n:
			break
		var u := mb.rng.randf_range(1.0, float(lay.umax) - 1.0)
		var v := mb.rng.randf_range(1.0, float(lay.vmax) - 1.0)
		var face := _vd() if mb.rng.randf() < 0.5 else _ud()
		if _put(names[mb.rng.randi() % names.size()], u, v, face, slots):
			placed += 1


## The main street door in u/v (ground floor), and the way into the building from it.
func _main_door() -> Array:
	if lay.doors.is_empty():
		return []
	return lay.doors[0]  # [uv, inward direction (world)]


## The u range layouts work in: the whole floor less a little wall clearance.
## (The stairwells are keep-clear zones, so anything that would overlap them is
## simply skipped.)
func _clear_u0() -> float:
	return 0.6


func _clear_u1() -> float:
	return float(lay.umax) - 0.6


## A desk or counter facing the main door, a few metres in (receptions, cashiers).
func _by_door(name: String, inset: float, facing_door := true) -> bool:
	var d := _main_door()
	if d.is_empty():
		return false
	var uv: Vector2 = d[0]  # (u, v) of the door on the inside of the wall
	var inward: Vector3 = d[1]
	var face := -inward if facing_door else inward
	var side := Vector3(inward.z, 0, -inward.x)
	for off: float in [0.0, 2.0, -2.0, 4.0, -4.0]:
		var u := uv.x + side.dot(_ud()) * off + inward.dot(_ud()) * inset
		var v := uv.y + side.dot(_vd()) * off + inward.dot(_vd()) * inset
		if _put(name, u, v, face):
			return true
	return false


# ------------------------------------------------------------------ building types

func _lay_warehouse(k: int) -> void:
	var um: float = lay.umax
	var vm: float = lay.vmax
	if k > 0:
		# Mezzanine offices: desks along the back wall, a meeting table.
		_run("desk_chair", true, vm - 0.45, _clear_u0(), _clear_u1(), -_vd(), 0.6)
		_put("table_chairs", um * 0.5, vm * 0.45, _vd(), {"main": MapBuilder.DARKWOOD})
		_scatter(["crate"], 2, {"color": MapBuilder.CARDBOARD})
		return
	# Rack rows with forklift aisles; a cross aisle every 4th rack.
	var v := 1.3
	while v < vm - 1.0:
		var n := _run("rack", true, v, 1.0, um - 1.0, _vd(), 0.0, 4)
		if n > 0:
			_fill_racks()
			# A yellow line down the aisle beside the racks (visual only).
			var lc := mb._uv(um * 0.5, v + 1.55)
			if v + 2.2 < vm:
				mb._prefab("furniture/decor/floor_line", MapBuilder._at(Vector3(lc.x, _fy, lc.y), MapBuilder._yaw_x(_vd()), Vector3(1, 1, um - 2.0)))
		v += 4.6
	_by_door("forklift", 4.0, false)
	_scatter(["crate"], 4, {"color": MapBuilder.CARDBOARD})


## Cardboard boxes on the shelves of the racks the last _run placed.
func _fill_racks() -> void:
	for xf: Transform3D in _placed:
		for h: float in [0.15, 1.3, 2.45]:
			for s: float in [-1.0, 0.1, 1.1]:
				if mb.rng.randf() < 0.75:
					var bh := mb.rng.randf_range(0.5, 0.95)
					mb._prefab("furniture/rack_box", xf * Transform3D(Basis.from_scale(Vector3(1.0, bh, 1.0)), Vector3(s, h + 0.04, 0)))


func _lay_school(k: int, rooms: Array) -> void:
	var vm: float = lay.vmax
	if rooms.is_empty():
		_classroom(_clear_u0(), _clear_u1() - 0.3, MapBuilder.STAIR_W + 1.0, vm - 0.3, _clear_u0() - 0.5)
	else:
		for r: Array in rooms:
			_classroom(r[0] + 0.3, r[1] - 0.3, MapBuilder.ROOM_V + 0.4, vm - 0.3, r[0] + (0.11 if r[0] > 0.0 else 0.02))
	# Lockers along the front wall, by the corridor.
	_run("lockers", true, 0.3, _clear_u0(), _clear_u1(), _vd(), 0.0, 5)
	if k == 0:
		_by_door("front_desk", 3.0)


## Board on the room's left wall, teacher's desk in front of it, rows of desks
## facing it, and a bookshelf at the back.
func _classroom(u0: float, u1: float, v0: float, v1: float, wall_u: float) -> void:
	if u1 - u0 < 4.5 or v1 - v0 < 3.0:
		return
	var vm := (v0 + v1) * 0.5
	_put("chalkboard", wall_u + 1.2, vm, -_ud(), {}, 0.0, false, false)  # its board sits 1.2 m behind its origin
	_put("desk_chair", u0 + 1.6, vm, -_ud())
	var u := u0 + 3.2
	while u <= u1 - 0.6:
		var v := v0 + 0.6
		while v <= v1 - 0.6:
			_put("school_desk", u, v, _ud(), {}, 0.05)
			v += 1.15
		u += 1.25
	_put("school_shelf", u1 - 0.3, vm, _ud(), {}, 0.05)


func _lay_motel(k: int, rooms: Array) -> void:
	var vm: float = lay.vmax
	for r: Array in rooms:
		var mid: float = (r[0] + r[1]) * 0.5
		# Two beds with their heads on the back wall and a nightstand between them
		# (one bed in a narrow room), the TV dresser on the side wall facing them,
		# an A/C unit under the window and a rug at the foot of the beds.
		var blanket := Color("c0453a").lerp(Color("4a6a9a"), mb.rng.randf())
		var twin: bool = r[1] - r[0] >= 5.6
		if _put("bed", mid - (1.15 if twin else -0.3), vm - 1.1, -_vd(), {"blanket": blanket}):
			mb._prefab("furniture/nightstand", _last_xf)
		if twin:
			_put("bed", mid + 1.35, vm - 1.1, -_vd(), {"blanket": blanket})
		var rug := mb._uv(mid + 0.1, vm - 3.0)
		if vm - 3.0 > MapBuilder.ROOM_V + 1.6:
			mb._prefab("furniture/decor/rug", MapBuilder._at(Vector3(rug.x, _fy, rug.y), MapBuilder._yaw_x(_ud())))
		_put("decor/wall_ac", r[0] + 0.9, vm - 0.02, -_vd(), {}, 0.0, true, false)
		_put("dresser_tv", r[1] - 0.9, maxf(MapBuilder.ROOM_V + 2.0, vm - 3.2), _ud(), {}, 0.05)
	if k == 0:
		_by_door("front_desk", 3.0)
		_put("potted_plant", _clear_u0() + 0.6, 1.0, _vd())
	if rooms.is_empty():
		_grid("bed", _clear_u0() + 1.5, _clear_u1() - 1.5, 2.0, vm - 1.5, 4.0, 3.5, -_vd())


func _lay_apartments(k: int, rooms: Array) -> void:
	var vm: float = lay.vmax
	if k == 0 or rooms.is_empty():
		# Lobby: reception, sofas along the wall, plants.
		if k == 0:
			_by_door("front_desk", 3.0)
		_put("lounge_set", (_clear_u0() + _clear_u1()) * 0.5, vm - 1.6, _vd(), {"main": Color("7a8a6a").lerp(Color("8a5a3c"), mb.rng.randf())})
		_put("waiting_chairs", _clear_u0() + 1.6, vm - 0.45, _vd())
		_put("potted_plant", _clear_u0() + 0.6, vm - 0.6, _vd())
		_put("potted_plant", _clear_u1() - 0.6, vm - 0.6, _vd())
		return
	var kind := 0
	for r: Array in rooms:
		var mid: float = (r[0] + r[1]) * 0.5
		match kind % 3:
			0:  # bedroom
				if _put("bed", mid + 0.3, vm - 1.1, -_vd(), {"blanket": MapBuilder.BLUE.lerp(Color("c27aa0"), mb.rng.randf())}):
					mb._prefab("furniture/nightstand", _last_xf)
				_put("dresser_tv", r[1] - 0.9, maxf(MapBuilder.ROOM_V + 2.0, vm - 3.2), _ud(), {}, 0.05)
			1:  # living room: sofa on the back wall facing a TV, a rug in between
				if _put("sofa", mid, vm - 0.55, _vd(), {"main": Color("7a8a6a").lerp(Color("8a5a3c"), mb.rng.randf())}):
					mb._prefab("furniture/tv_stand", _last_xf)
					var rug := mb._uv(mid, vm - 1.9)
					mb._prefab("furniture/decor/rug", MapBuilder._at(Vector3(rug.x, _fy, rug.y), MapBuilder._yaw_x(_ud())))
				_put("potted_plant", r[0] + 0.7, vm - 0.7, _vd())
			2:  # kitchen + dining table
				_put("kitchen", mid - 0.3, vm - 0.4, _vd(), {}, 0.05)
				if not _put("kitchen_island", mid, vm - 2.4, _vd()):
					_put("table_chairs", mid, (MapBuilder.ROOM_V + vm) * 0.5 - 0.3, _vd(), {"main": MapBuilder.LIGHTWOOD})
		kind += 1


func _lay_rundown(k: int, rooms: Array) -> void:
	var vm: float = lay.vmax
	if rooms.is_empty():
		_scatter(["mattress", "sofa", "rundown_tv", "crate"], 5, {"main": Color("6a5a3a"), "color": MapBuilder.CARDBOARD})
		_scatter(["trash_bag"], 5)
		return
	for r: Array in rooms:
		var mid: float = (r[0] + r[1]) * 0.5
		if mb.rng.randf() < 0.75:
			_put("mattress", mid + mb.rng.randf_range(-1.0, 1.0), vm - 1.1, _vd())
		if mb.rng.randf() < 0.35:
			_put("rundown_tv", r[0] + 1.5, (MapBuilder.ROOM_V + vm) * 0.5, _ud())
		elif mb.rng.randf() < 0.4:
			_put("sofa", mid, MapBuilder.ROOM_V + 1.6, -_vd(), {"main": Color("6a5a3a")})
		for i in mb.rng.randi_range(0, 3):
			_put("trash_bag", mb.rng.randf_range(r[0] + 0.6, r[1] - 0.6), mb.rng.randf_range(MapBuilder.ROOM_V + 0.6, vm - 0.6), _vd(), {}, 0.0)
	_scatter(["trash_bag"], 3)


## A real shop floor: aisles of shelves and clothes rails with cross aisles,
## display tables near the front, and checkouts by the door.
func _lay_store(k: int) -> void:
	var vm: float = lay.vmax
	var u0 := _clear_u0() + 1.0
	var u1 := _clear_u1() - 1.0
	if k == 0:
		for i in 3:
			if not _by_door("checkout_counter", 3.2 + i * 0.01, true):
				break
		_by_door("display_stand", 6.5, true)
	var v := 2.4
	var row := 0
	while v < vm - 1.5:
		if row % 2 == 0:
			_run("clothes_shelf", true, v, u0, u1, _vd(), 0.0, 3)
		else:
			_run("clothes_rack", true, v, u0, u1, _vd(), 0.6, 3)
		v += 3.6
		row += 1
	_put("mall_bench", (u0 + u1) * 0.5, vm - 0.6, -_vd())
	_put("potted_plant", u0 - 0.4, vm - 0.7, _vd())


func _lay_office(k: int) -> void:
	var vm: float = lay.vmax
	if k == 0:
		# Lobby: reception desk with the company's logo wall, a lounge, plants.
		if not _by_door("reception_desk", 4.5):
			_by_door("front_desk", 3.0)
		_put("lounge_set", _clear_u0() + 3.0, vm - 1.6, _vd())
		_put("potted_plant", _clear_u1() - 0.6, 0.7, _vd())
		_put("potted_plant", _clear_u0() + 0.6, 0.7, _vd())
		_grid("office_cubicle", _clear_u0() + 2.2, _clear_u1() - 2.2, vm * 0.5, vm - 2.0, 5.4, 4.8, _vd())
		return
	# Open-plan floor: cubicles, a meeting table at one end, copiers, a break corner.
	_put("conference_table", _clear_u1() - 2.6, vm - 2.0, _vd())
	_grid("office_cubicle", _clear_u0() + 2.2, _clear_u1() - 5.5, 2.6, vm - 2.0, 5.4, 4.8, _vd())
	_run("copier", true, vm - 0.4, _clear_u0(), _clear_u0() + 4.0, -_vd(), 1.0)
	_put("lounge_set", _clear_u1() - 2.6, 1.8, -_vd())
	_put("potted_plant", _clear_u1() - 0.6, 0.7, _vd())


func _lay_bank(k: int) -> void:
	var um: float = lay.umax
	var vm: float = lay.vmax
	if k > 0:
		_run("desk_chair", true, vm - 0.45, _clear_u0(), _clear_u1(), -_vd(), 1.0)
		_put("conference_table", um * 0.5, vm * 0.4, _vd())
		return
	# Teller counters across the back of the hall, the vault behind them in the
	# corner, bankers' desks on the side, a waiting bench and plants by the door.
	_put("vault", um - 2.2, vm - 2.6, _vd())
	_run("teller_counter", true, vm - 2.4, um * 0.3, um * 0.75, _vd(), 0.0)
	# The queue: two lines of posts and belts in front of the tellers.
	_put("queue_stanchions", um * 0.5, vm - 4.6, _vd(), {}, 0.1)
	_put("queue_stanchions", um * 0.5, vm - 5.9, _vd(), {}, 0.1)
	_put("desk_chair", _clear_u0() + 1.0, vm * 0.45, -_ud())
	_put("desk_chair", _clear_u0() + 1.0, vm * 0.45 + 2.2, -_ud())
	_by_door("waiting_chairs", 4.0)
	# ATMs along the front wall.
	_run("atm", true, 0.3, _clear_u1() - 3.0, _clear_u1() - 0.3, _vd(), 0.3)
	_put("potted_plant", _clear_u0() + 0.6, 0.7, _vd())


func _lay_diner(k: int) -> void:
	var vm: float = lay.vmax
	if k > 0:
		_grid("table_chairs", _clear_u0() + 1.5, _clear_u1() - 1.5, 2.0, vm - 2.0, 3.2, 3.2, _vd(), {"main": MapBuilder.WOOD})
		return
	# Black and white checked floor (visual only), then the counter with stools
	# along the back and booths along the front windows.
	var du := 2.0
	while du < float(lay.umax) - 1.0:
		var dv := 2.0
		while dv < vm - 1.0:
			var dp := mb._uv(du, dv)
			mb._prefab("furniture/decor/checker_floor", MapBuilder._at(Vector3(dp.x, _fy, dp.y)))
			dv += 4.0
		du += 4.0
	_run("diner_counter", true, vm - 1.5, _clear_u0() + 1.0, _clear_u1() - 1.0, -_vd(), 0.0, 4)
	_run("diner_booth", true, 0.75, _clear_u0(), _clear_u1(), _vd(), 0.2)
	_grid("table_chairs", _clear_u0() + 2.0, _clear_u1() - 2.0, vm * 0.5 - 0.2, vm * 0.5 - 0.2, 3.4, 3.0, _vd(), {"main": MapBuilder.WOOD})


func _lay_bar(k: int) -> void:
	var vm: float = lay.vmax
	_run("bar_counter", true, vm - 1.5, _clear_u0() + 1.0, _clear_u1() - 1.0, -_vd(), 0.0, 3)
	_grid("pool_table", _clear_u0() + 2.5, _clear_u1() - 2.5, vm * 0.45, vm * 0.45, 4.0, 3.0, _ud())
	_run("table_chairs", true, 1.2, _clear_u0() + 0.6, _clear_u1(), _vd(), 1.4, 0, {"main": MapBuilder.WOOD})


func _lay_club(k: int) -> void:
	var um: float = lay.umax
	var vm: float = lay.vmax
	# Dance floor in the middle (you can walk on it), bar on the back wall,
	# lounge sofas along the front wall.
	for du: float in [-1.5, 1.5]:
		for dv: float in [-1.5, 1.5]:
			_put("dance_floor", um * 0.5 + du, vm * 0.5 + dv, _vd(), {}, 0.0, false)
	mb._occupied.append(mb._uv_rect(um * 0.5 - 3.0, vm * 0.5 - 3.0, um * 0.5 + 3.0, vm * 0.5 + 3.0))
	_run("club_bar", true, vm - 0.45, _clear_u0() + 1.0, _clear_u1() - 1.0, _vd(), 0.0)
	# The DJ on a stage beyond the dance floor, facing it.
	if not _put("dj_booth", um * 0.5 + 5.6, vm * 0.5, -_ud(), {}, 0.2):
		_put("dj_booth", um * 0.5 - 5.6, vm * 0.5, _ud(), {}, 0.2)
	# Booths along the front wall, open side to the room.
	_run("club_booth", true, 1.2, _clear_u0(), _clear_u1(), _vd(), 0.8)


func _lay_arcade(k: int) -> void:
	var vm: float = lay.vmax
	# Cabinets along both long walls and back-to-back down the middle.
	_run("arcade_cabinets", true, 0.45, _clear_u0(), _clear_u1(), -_vd(), 0.4)
	_run("arcade_cabinets", true, vm - 0.45, _clear_u0(), _clear_u1(), _vd(), 0.4)
	var mid := vm * 0.5
	_run("arcade_cabinets", true, mid - 0.5, _clear_u0() + 1.5, _clear_u1() - 1.5, _vd(), 0.4, 4)
	_run("arcade_cabinets", true, mid + 0.45, _clear_u0() + 1.5, _clear_u1() - 1.5, -_vd(), 0.4, 4)
	_scatter(["air_hockey", "claw_machine"], 3)


func _lay_casino(k: int) -> void:
	var vm: float = lay.vmax
	if k == 0:
		_by_door("casino_counter", 3.0)
	# Back-to-back rows of slot machines with aisles, tables in the open middle.
	var v := 1.6
	var row := 0
	while v < vm * 0.45:
		_run("slot_machines", true, v, _clear_u0(), _clear_u1(), _vd() if row % 2 == 0 else -_vd(), 0.1, 4)  # pairs back to back
		v += 0.85 if row % 2 == 0 else 2.6
		row += 1
	# Patterned carpet over the floor (visual only).
	var cu := _clear_u0() + 2.0
	while cu < _clear_u1() - 1.8:
		var cv := 1.5
		while cv < vm - 1.3:
			var cp := mb._uv(cu, cv)
			if not _blocked(mb._uv_rect(cu - 1.9, cv - 1.4, cu + 1.9, cv + 1.4), _fzones):  # not over a stair hole
				mb._prefab("furniture/decor/casino_carpet", MapBuilder._at(Vector3(cp.x, _fy, cp.y), MapBuilder._yaw_x(_ud())))
			cv += 2.6
		cu += 3.6
	# Table games: card tables and roulette in turn.
	var gu := _clear_u0() + 2.0
	var gi := 0
	while gu <= _clear_u1() - 2.0:
		var gv := vm * 0.6
		while gv <= vm - 1.8:
			_put("roulette_table" if (gi % 2) == 1 else "card_table", gu, gv, _vd())
			gi += 1
			gv += 3.4
		gu += 3.6
	_scatter(["craps_table"], 2)


func _lay_library(k: int) -> void:
	var vm: float = lay.vmax
	if k == 0:
		_by_door("front_desk", 3.0)
	# Book stacks across the back, reading tables in front by the windows.
	_rows("bookshelf", vm * 0.5, vm - 1.0, _clear_u0() + 0.5, _clear_u1() - 0.5, 3.4, _vd(), 0.0, 4)
	_grid("reading_table", _clear_u0() + 2.2, _clear_u1() - 2.2, 2.0, vm * 0.5 - 2.0, 4.0, 2.8, _vd())


## Cinema: the screen on the far end wall (ground floor), rows of seats facing
## it with an aisle down the middle, and the concession stand by the door.
func _lay_theater(k: int, fh: float) -> void:
	var um: float = lay.umax
	var vm: float = lay.vmax
	if k == 0:
		var sw := minf(1.0, (vm - 1.0) / 8.4)
		var sp := mb._uv(um - 0.05, vm * 0.5)
		var screen_foot := mb._uv_rect(um - 1.0, vm * 0.5 - 4.2 * sw, um, vm * 0.5 + 4.2 * sw)
		if fh >= 5.0 and not _blocked(screen_foot, _fzones):  # never in front of a door or the stairs
			mb._prefab("furniture/theater_screen", MapBuilder._at(Vector3(sp.x, _fy, sp.y), MapBuilder._yaw_to(-_ud()), Vector3(sw, 1, 1)))
			mb._occupied.append(screen_foot)
		_by_door("concession_stand", 3.0)
		_by_door("ticket_kiosk", 1.6, false)
		_by_door("ticket_kiosk", 1.6, false)
	var u := um - 5.0 if k == 0 else um - 2.0
	var last := um * 0.45 if k == 0 else _clear_u0() + 1.0
	while u >= last:
		# Two blocks of seats with a centre aisle.
		_run("theater_seats", false, u, 1.0, vm * 0.5 - 0.8, -_ud(), 0.0)
		_run("theater_seats", false, u, vm * 0.5 + 0.8, vm - 1.0, -_ud(), 0.0)
		u -= 1.15


func _desk_chair(c: Vector3, rot: bool) -> void:
	mb._prefab("furniture/desk_chair", MapBuilder._at_rot(c, rot))


func _school_desk(c: Vector3, rot: bool) -> void:
	mb._prefab("furniture/school_desk", MapBuilder._at_rot(c, rot))


## Warehouse rack (frame + shelves) with random cardboard boxes on the lower shelves.
func _rack(c: Vector3, rot: bool) -> void:
	var at := MapBuilder._at_rot(c, rot)
	mb._prefab("furniture/rack", at)
	for h: float in [0.15, 1.3, 2.45]:
		for s: float in [-1.0, 0.1, 1.1]:
			if mb.rng.randf() < 0.75:
				var bh := mb.rng.randf_range(0.5, 0.95)
				mb._prefab("furniture/rack_box", at * Transform3D(Basis.from_scale(Vector3(1.0, bh, 1.0)), Vector3(s, h + 0.04, 0)))


## 1-3 crates of random size (furniture/crate is a 1 m crate), sometimes stacked.
func _crates(c: Vector3) -> void:
	var n := mb.rng.randi_range(1, 3)
	for i in n:
		var s := mb.rng.randf_range(0.9, 1.25)
		var off := Vector3(mb.rng.randf_range(-0.9, 0.9), 0, mb.rng.randf_range(-0.9, 0.9))
		mb._prefab("furniture/crate", MapBuilder._at(c + off, 0.0, Vector3.ONE * s), {"color": MapBuilder.CARDBOARD if mb.rng.randf() < 0.6 else MapBuilder.WOOD})
		if mb.rng.randf() < 0.4:
			var s2 := s * 0.8
			mb._prefab("furniture/crate", MapBuilder._at(c + off + Vector3(0, s, 0), 0.0, Vector3.ONE * s2), {"color": MapBuilder.CARDBOARD})


func _forklift(c: Vector3, rot: bool) -> void:
	mb._prefab("furniture/forklift", MapBuilder._at_rot(c, rot))


func _sofa(c: Vector3, rot: bool, col: Color) -> void:
	mb._prefab("furniture/sofa", MapBuilder._at_rot(c, rot), {"main": col})


func _bed(c: Vector3, rot: bool, blanket: Color) -> void:
	mb._prefab("furniture/bed", MapBuilder._at_rot(c, rot), {"blanket": blanket})


func _table_chairs(c: Vector3, rot: bool, col: Color) -> void:
	mb._prefab("furniture/table_chairs", MapBuilder._at_rot(c, rot), {"main": col})


func _bookshelf(c: Vector3, rot: bool) -> void:
	mb._prefab("furniture/bookshelf", MapBuilder._at_rot(c, rot))  # random book colours


func _plant(c: Vector3) -> void:
	mb._prefab("furniture/potted_plant", MapBuilder._at(c))


func _vault(c: Vector3) -> void:
	mb._prefab("furniture/vault", MapBuilder._at(c))


## Arena: court with hoops, bleachers on both long sides (a ramp collides; the
## steps are visual), the scoreboard, banners and benches near the ends.
func furnish_sports(inner: Rect2, zones: Array) -> void:
	var c := inner.get_center()
	var c3 := Vector3(c.x, 0.0, c.y)
	mb._prefab("props/arena/court", MapBuilder._at(c3))
	mb._prefab("props/arena/bleachers", MapBuilder._at(c3))
	mb._prefab("props/arena/bleachers", MapBuilder._at(c3, PI))
	mb._prefab("props/arena/scoreboard", MapBuilder._at(c3))
	mb._label("SWIFTCURRENT RAPIDS", Vector3(c.x, 7.5, inner.position.y + 0.2), 0.0, 160, Color("9fd0ff"))
	mb._label("SWIFTCURRENT RAPIDS", Vector3(c.x, 7.5, inner.end.y - 0.2), PI, 160, Color("9fd0ff"))
	for s: float in [-1.0, 1.0]:
		for i in 3:
			var p := Vector3(c.x + s * (18.0 + i * 2.5), 0, c.y + mb.rng.randf_range(-6, 6))
			if not _blocked(Rect2(p.x - 1.5, p.z - 1.5, 3, 3), zones):
				mb._prefab("props/arena/bench", MapBuilder._at(p))


## Water works: tanks, two long pipes (stretched to the hall) and pumps.
func furnish_water(inner: Rect2, zones: Array) -> void:
	var c := inner.get_center()
	var tanks := [Vector2(-10, -3), Vector2(-3, 4), Vector2(5, -3), Vector2(12, 4)]
	for t in tanks:
		var p := Vector3(c.x + t.x, 0, c.y + t.y)
		if _blocked(Rect2(p.x - 3, p.z - 3, 6, 6), zones):
			continue
		mb._prefab("props/water/tank", MapBuilder._at(p))
	# Pipes between tanks (low enough to vault over with a jump)
	mb._prefab("props/water/pipe", MapBuilder._at(Vector3(c.x, 0, c.y), 0.0, Vector3(inner.size.x - 14.0, 1, 1)))
	mb._prefab("props/water/pipe", MapBuilder._at(Vector3(c.x + 2, 0, c.y + 6.8), 0.0, Vector3(inner.size.x - 18.0, 1, 1)))
	for i in 5:
		var p := Vector3(mb.rng.randf_range(inner.position.x + 2, inner.end.x - 2), 0, mb.rng.randf_range(inner.position.y + 2, inner.end.y - 2))
		if _blocked(Rect2(p.x - 1.5, p.z - 1.5, 3, 3), zones):
			continue
		mb._prefab("props/water/pump", MapBuilder._at(p))
