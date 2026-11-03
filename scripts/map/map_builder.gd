class_name MapBuilder
extends RefCounted
## Builds the whole city procedurally (deterministic, so every peer builds the same map).
## Props and furniture are template scenes in assets/props and assets/furniture,
## placed with _prefab() (see Prefabs); this file decides where they go.
##
## Performance notes:
##  * All static boxes / cylinders / spheres of a building are drawn with a handful of
##    MultiMeshInstance3D nodes (one draw call each) using a single shared material.
##  * Furniture lives in its own MultiMesh with a visibility range so far-away interiors
##    are not drawn at all.
##  * Collision uses shape owners on one StaticBody3D per layer per building instead of
##    thousands of CollisionShape3D nodes, and box shapes are shared by size.

# Physics layers (bit values)
const L_FLOOR := 1   # interior floors and roofs (Phantom can drop through)
const L_WALL := 2    # walls + furniture (Phantom can pass through; sniper can pierce one)
const L_PLAYER := 4
const L_DOOR := 8
const L_SOLID := 16  # ground and boundary fence (never passable)
const L_BOUNCE := 32 # bounce pads (umbrella and awning tops): landing on one launches you up
const L_SKY := 64    # sky barrier: stops players, but grapples, shots and pings pass through
const SKY_CLEARANCE := 35.0  # the sky barrier is this far above the tallest structure
const MASK_WORLD := L_FLOOR | L_WALL | L_DOOR | L_SOLID
const DOOR_SCENE := preload("res://assets/models/door.tscn")
const SIGN_SCENE := preload("res://assets/models/building_sign.tscn")
const DECOR := 0    # visual only, no collision: flat floor markings, bleacher steps (a ramp covers them); foliage never collides

const WALL_T := 0.3
const SLAB_T := 0.3
const DOOR_W := 1.7
const DOOR_H := 2.45
# Modular buildings (assets/building): walls are made of MODULE-wide pieces that
# are MODULE_H tall, so building sides are a whole number of modules plus a
# WALL_T corner at each end. Stairs are STAIR_RUN x STAIR_RISE segments.
const MODULE := 2.0
const MODULE_H := 4.0
const STAIR_RUN := 0.8
const STAIR_RISE := 0.5
const STAIR_W := 5.8        # stairwell width across its two lanes (stair_segment is STAIR_W / 2 - 0.05 wide)
const STAIR_LANDING := 2.6  # landing before and after each flight: the way onto the stairs
const ROOM_V := STAIR_W + 1.5  # rooms start this far in, leaving a corridor past the stairwell
const STAIR_GUARD_H := 1.3  # sloped wall between the stair lanes: this high above the steps (body, not head)
const ROOM_MODULES := 3  # interior rooms are 3 modules (6 m) wide
const WINDOW_PIECES := ["building/wall_window_small", "building/wall_window_wide", "building/wall_window_tall"]
const FURNITURE_VIS_RANGE := 140.0
const GLOW_BOOST := 3.0  # glowing parts are drawn with their brightest channel at this level, so they bloom

const STYLES := {
	"warehouse": {"wall": Color("9c8b74"), "floor": Color("7a7670"), "roof": Color("5e5a52"), "trim": Color("6b5d4b"), "door": Color("5b6b74")},
	"school": {"wall": Color("c8a36b"), "floor": Color("b8b2a4"), "roof": Color("6a6560"), "trim": Color("8c3b2e"), "door": Color("3f6fa8")},
	"sports": {"wall": Color("3f6fa8"), "floor": Color("c99a5b"), "roof": Color("d9dde0"), "trim": Color("f0f0f0"), "door": Color("2f4f78")},
	"theater": {"wall": Color("7c2d3a"), "floor": Color("4a2f3a"), "roof": Color("3d3438"), "trim": Color("e0b13c"), "door": Color("2a1e22")},
	"bank": {"wall": Color("d6d0c2"), "floor": Color("e6e1d6"), "roof": Color("7a756c"), "trim": Color("9a8a5c"), "door": Color("6b5d3b")},
	"diner": {"wall": Color("4fb3a9"), "floor": Color("e8e2d6"), "roof": Color("6a6560"), "trim": Color("d64545"), "door": Color("d64545")},
	"arcade": {"wall": Color("5a3d8a"), "floor": Color("2f2a40"), "roof": Color("3a3448"), "trim": Color("49d6e0"), "door": Color("49d6e0")},
	"club": {"wall": Color("2e2b3a"), "floor": Color("1f1d29"), "roof": Color("2a2830"), "trim": Color("e04fa6"), "door": Color("e04fa6")},
	"bar": {"wall": Color("6b4a32"), "floor": Color("5a4030"), "roof": Color("4a3a30"), "trim": Color("c99a5b"), "door": Color("3a2a20")},
	"apartments": {"wall": Color("e3d8c4"), "floor": Color("c2a27a"), "roof": Color("6f6a66"), "trim": Color("8a9aa8"), "door": Color("7a5a3c")},
	"mall": {"wall": Color("d8d2c8"), "floor": Color("ece7dd"), "roof": Color("8a8580"), "trim": Color("4f8fbf"), "door": Color("4f8fbf")},
	"motel": {"wall": Color("e8c9a0"), "floor": Color("9c7b62"), "roof": Color("7a4a3a"), "trim": Color("c0453a"), "door": Color("c0453a")},
	"rundown": {"wall": Color("8a6f5a"), "floor": Color("6e6253"), "roof": Color("4f4a44"), "trim": Color("5b5b5b"), "door": Color("5a4a3a")},
	"rundown2": {"wall": Color("7a7f6a"), "floor": Color("6a6555"), "roof": Color("4a4c44"), "trim": Color("6a4a4a"), "door": Color("4a5a4a")},
	"office": {"wall": Color("9fb4c4"), "floor": Color("b9b9b9"), "roof": Color("5c6670"), "trim": Color("40505e"), "door": Color("40505e")},
	"casino": {"wall": Color("b0283a"), "floor": Color("7a1f2c"), "roof": Color("4a2a2e"), "trim": Color("e0b13c"), "door": Color("e0b13c")},
	"water": {"wall": Color("a7b0b3"), "floor": Color("8c9396"), "roof": Color("6e7679"), "trim": Color("3f7fa8"), "door": Color("3f7fa8")},
	"library": {"wall": Color("a46b4a"), "floor": Color("8c6a4f"), "roof": Color("5a4a40"), "trim": Color("e3d8c4"), "door": Color("5a3a28")},
}

const WOOD := Color("8a5a3c")
const DARKWOOD := Color("5b3a29")
const LIGHTWOOD := Color("c29a6b")
const METAL := Color("8c949a")
const DARKMETAL := Color("4a5056")
const WHITE := Color("ece6da")
const BLACK := Color("2a2a2e")
const SCREEN := Color("6fd6ff")
const FELT := Color("2f7a45")
const GOLD := Color("d6a83a")
const RED := Color("b8433a")
const BLUE := Color("4a6a9a")
const CARDBOARD := Color("b48a5a")
const GRASS := Color("6aa84f")
const CONCRETE := Color("b9b4a6")
const ASPHALT := Color("3c3d42")
const TAXI := Color("f2c230")
const CAR_GAP := 1.4  # min space between vehicles: a crouched player is 0.76 m wide
const CAR_COLORS := [Color("c0453a"), Color("4f7fae"), Color("e0b13c"), Color("ece6da"), Color("3a3d42"), Color("5a8a4a"), Color("9aa3a8"), Color("1f2a44")]

var root: Node3D
var rng := RandomNumberGenerator.new()

# Output data used by the game
var spawn_dots: Array = []       # Vector3
var objectives: Array = []       # {pos: Vector3, name: String}
var spawn_points: Array = []     # Vector3 candidate respawn points
var doors: Array = []            # Door
var lights: Array = []           # OmniLight3D from lamp prefabs (World thins them per the Interior lights setting)
var night_lights: Array = []     # OmniLight3D that only shine in the evening and at night (street lamps)
var buildings: Array = []        # {id, name, rect: Rect2, floors, fh, top, color}
var road_rects: Array = []       # Rect2 (clipped to the map bounds)
var park_rect := Rect2()
var has_park := true
var map_size := MapData.DEFAULT_SIZE
var bounds := Rect2()            # playable area (inside the fence), metres
var min_spawn_dist := 70.0       # minimum distance between the two teams' spawn zones
var _active: Array = []          # layout building entries built for this size

# Chunk accumulators
var _chunk: Node3D
var _boxes: Array = []
var _fboxes: Array = []
var _cyls: Array = []
var _fcyls: Array = []
var _spheres: Array = []
var _glows: Array = []   # [kind, transform, colour, detail]: glowing parts
var _floor_body: StaticBody3D
var _wall_body: StaticBody3D
var _solid_body: StaticBody3D
var _bounce_body: StaticBody3D
var _shape_cache := {}
var _box_mesh: BoxMesh
var _cyl_mesh: CylinderMesh
var _sph_mesh: SphereMesh

# Stairwell frame of the building currently being built
var _ax := true
var _o := Vector2.ZERO
var _flip := false   # mirror u (second stairwell at the far end)
var _umax := 0.0
var _forbid: Array = []
var _wall_slots: Array = []   # [inner face point at floor level, inward normal, storey] per solid wall module
var _occupied: Array = []     # Rect2: furniture cells used on the storey being furnished
# Furniture-style props use the "detail" MultiMesh (with a visibility range) inside
# buildings; outdoor clutter must stay visible from anywhere, so it turns this off.
var _detail := true
# Street dressing
var _avoid: Array = []       # Vector3: spawn zones + Tag spots
var _junctions: Array = []   # Rect2: where roads cross
var _door_pts: Array = []    # Vector2: ground-floor door centres (props keep clear)
var _lots: Array = []        # Rect2: car parks (cut building lots, or from the layout)
var _car_rects: Array = []   # Rect2: footprint of every vehicle placed so far
var _dumpsters: Array = []   # sketch-pixel points from the layout
var park_name := MapData.PARK_NAME
var bridges: Array = []      # [building A id, building B id, material]
var sky_height := 0.0        # height of the sky barrier
var _tallest := 0.0          # top of the tallest structure built so far


## seed 0 builds the classic hand-made city; any other seed a random one
## (CityGen). Every peer passes the same size and seed, so they get the same map.
func build(parent: Node3D, size := MapData.DEFAULT_SIZE, seed := 0) -> void:
	root = parent
	rng.seed = 424242 if seed == 0 else seed
	map_size = size if MapData.valid_size(size) else MapData.DEFAULT_SIZE
	bounds = MapData.size_bounds(map_size)
	min_spawn_dist = MapData.SIZES[map_size].min_spawn_dist
	var layout := MapData.classic_layout() if seed == 0 else CityGen.generate(map_size, seed)
	park_name = str(layout.park_name)
	bridges = layout.bridges
	_dumpsters = layout.dumpsters
	for p in layout.parking:
		_lots.append(MapData.px_rect([p.position.x, p.position.y, p.end.x, p.end.y]))
	# Only buildings that fit entirely inside the fence are built. Every building
	# is snapped to the module grid first (see snap_rect_px).
	var excluded: Array = []
	for src in layout.buildings:
		var b: Array = src.duplicate()
		b[3] = snap_rect_px(src[3])
		var br := MapData.px_rect(b[3])
		if bounds.encloses(br):
			_active.append(b)
		else:
			excluded.append(br)
			var lot := br.intersection(bounds.grow(-2.0))
			if lot.size.x > 8.0 and lot.size.y > 8.0:
				_lots.append(lot)
	_box_mesh = BoxMesh.new()
	_cyl_mesh = CylinderMesh.new()
	_cyl_mesh.top_radius = 0.5
	_cyl_mesh.bottom_radius = 0.5
	_cyl_mesh.height = 1.0
	_cyl_mesh.radial_segments = 10
	_cyl_mesh.rings = 1
	_sph_mesh = SphereMesh.new()
	_sph_mesh.radius = 0.5
	_sph_mesh.height = 1.0
	_sph_mesh.radial_segments = 10
	_sph_mesh.rings = 5

	_solid_body = StaticBody3D.new()
	_solid_body.name = "SolidGround"
	_solid_body.collision_layer = L_SOLID
	_solid_body.collision_mask = 0
	root.add_child(_solid_body)

	# Spawn zones and Tag spots: inside the fence and not in a removed building's lot.
	for d in layout.spawn_dots:
		var p := MapData.px(d[0], d[1])
		if _usable_point(p, excluded):
			spawn_dots.append(Vector3(p.x, 0.0, p.y))
	for o in layout.objectives:
		var p := MapData.px(o[0], o[1])
		if _usable_point(p, excluded):
			objectives.append({"pos": Vector3(p.x, 0.0, p.y), "name": o[2]})
	for r in layout.roads:
		var clipped := MapData.px_rect(r).intersection(bounds)
		if clipped.size.x > 1.0 and clipped.size.y > 1.0:
			road_rects.append(clipped)
	has_park = not layout.park.is_empty()
	if has_park:
		park_rect = MapData.px_rect(layout.park)
		has_park = bounds.encloses(park_rect)

	_begin_chunk("Streets")
	_build_ground()
	_end_chunk()

	for b in _active:
		_begin_chunk(b[1])
		_build_building(b)
		_end_chunk()

	# After the buildings, so street props can keep clear of their doors.
	_begin_chunk("StreetProps")
	_build_street_props()
	_end_chunk()

	if has_park:
		_begin_chunk("Park")
		_build_park()
		_end_chunk()

	_begin_chunk("Cranes")
	_build_cranes()
	_end_chunk()

	_begin_chunk("Boundary")
	_build_boundary()
	_end_chunk()

	_build_spawn_points()


# ================================================================ primitives

func _begin_chunk(nm: String) -> void:
	_chunk = Node3D.new()
	_chunk.name = nm.validate_node_name().replace(" ", "_")
	root.add_child(_chunk)
	_floor_body = StaticBody3D.new()
	_floor_body.name = "Floors"
	_floor_body.collision_layer = L_FLOOR
	_floor_body.collision_mask = 0
	_chunk.add_child(_floor_body)
	_wall_body = StaticBody3D.new()
	_wall_body.name = "Walls"
	_wall_body.collision_layer = L_WALL
	_wall_body.collision_mask = 0
	_chunk.add_child(_wall_body)
	_bounce_body = StaticBody3D.new()
	_bounce_body.name = "BouncePads"
	_bounce_body.collision_layer = L_BOUNCE
	_bounce_body.collision_mask = 0
	_chunk.add_child(_bounce_body)
	_boxes = []
	_fboxes = []
	_cyls = []
	_fcyls = []
	_spheres = []
	_glows = []


func _end_chunk() -> void:
	_make_mm(_box_mesh, _boxes, 0.0)
	_make_mm(_cyl_mesh, _cyls, 0.0)
	_make_mm(_box_mesh, _fboxes, FURNITURE_VIS_RANGE)
	_make_mm(_cyl_mesh, _fcyls, FURNITURE_VIS_RANGE)
	_make_mm(_sph_mesh, _spheres, 0.0)
	# Glowing parts: one batch per shape and draw distance
	var meshes := {"box": _box_mesh, "cyl": _cyl_mesh, "sphere": _sph_mesh}
	for kind: String in meshes:
		for detail: bool in [false, true]:
			var items := []
			for g: Array in _glows:
				if g[0] == kind and g[3] == detail:
					items.append([g[1], g[2]])
			_make_mm(meshes[kind], items, FURNITURE_VIS_RANGE if detail else 0.0, Mats.vertex_glow())


func _make_mm(mesh: Mesh, items: Array, vis_range: float, mat: Material = null) -> void:
	if items.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i][0])
		mm.set_instance_color(i, items[i][1])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat if mat else Mats.vertex_toon()
	if mat or vis_range > 0.0:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if vis_range > 0.0:
		mmi.visibility_range_end = vis_range
		mmi.visibility_range_end_margin = 5.0
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_chunk.add_child(mmi)


func _body_for(layer: int) -> StaticBody3D:
	if layer == L_FLOOR:
		return _floor_body
	if layer == L_WALL:
		return _wall_body
	if layer == L_BOUNCE:
		return _bounce_body
	return _solid_body


func _add_shape(layer: int, shape: Shape3D, xf: Transform3D) -> void:
	var body := _body_for(layer)
	var oid := body.create_shape_owner(body)
	body.shape_owner_add_shape(oid, shape)
	body.shape_owner_set_transform(oid, xf)


func _box_shape(s: Vector3) -> BoxShape3D:
	var key := Vector3i(roundi(s.x * 100.0), roundi(s.y * 100.0), roundi(s.z * 100.0))
	if _shape_cache.has(key):
		return _shape_cache[key]
	var b := BoxShape3D.new()
	b.size = s
	_shape_cache[key] = b
	return b


func _cyl_shape(r: float, h: float) -> CylinderShape3D:
	var key := "c%d_%d" % [roundi(r * 100.0), roundi(h * 100.0)]
	if _shape_cache.has(key):
		return _shape_cache[key]
	var c := CylinderShape3D.new()
	c.radius = r
	c.height = h
	_shape_cache[key] = c
	return c


## Axis-aligned (or rotated) box. layer DECOR = visual only.
func box(c: Vector3, s: Vector3, col: Color, layer := L_WALL, detail := false, rot := Basis.IDENTITY) -> void:
	var vis := Transform3D(rot * Basis.from_scale(s), c)
	if detail:
		_fboxes.append([vis, col])
	else:
		_boxes.append([vis, col])
	if layer != DECOR:
		_add_shape(layer, _box_shape(s), Transform3D(rot, c))


func cyl(c: Vector3, r: float, h: float, col: Color, layer := L_WALL, detail := false) -> void:
	var vis := Transform3D(Basis.from_scale(Vector3(r * 2.0, h, r * 2.0)), c)
	if detail:
		_fcyls.append([vis, col])
	else:
		_cyls.append([vis, col])
	if layer != DECOR:
		_add_shape(layer, _cyl_shape(r, h), Transform3D(Basis.IDENTITY, c))


## Places a template scene (see Prefabs) with transform xf, which may be scaled to
## stretch it. slots fills in colour slots, e.g. {"body": col}. Parts follow the
## current _detail unless the scene says which batch they belong in.
func _prefab(name: String, xf: Transform3D, slots := {}) -> void:
	var r := Prefabs.recipe(name)
	for p: Dictionary in r.parts:
		var col: Color = p.color
		var choices: PackedColorArray = p.choices
		if not choices.is_empty():
			col = choices[rng.randi() % choices.size()]
		elif p.slot != "" and slots.has(p.slot):
			col = slots[p.slot]
			if p.darken > 0.0:
				col = col.darkened(p.darken)
			if p.lighten > 0.0:
				col = col.lightened(p.lighten)
		var t: Transform3D = xf * p.xform
		var detail: bool = _detail if p.batch == "" else p.batch == "detail"
		if p.glow:
			var gain := GLOW_BOOST / maxf(0.05, maxf(col.r, maxf(col.g, col.b)))
			_glows.append([p.kind, t, Color(col.r * gain, col.g * gain, col.b * gain), detail])
			continue
		match p.kind:
			"box":
				(_fboxes if detail else _boxes).append([t, col])
			"cyl":
				(_fcyls if detail else _cyls).append([t, col])
			"sphere":
				_spheres.append([t, col])
	for s: Dictionary in r.shapes:
		var t: Transform3D = xf * s.xform
		var sc := t.basis.get_scale()
		var rot := t.basis.orthonormalized()
		var size: Vector3 = s.size * sc
		if s.kind == "box":
			_add_shape(s.layer, _box_shape(size), Transform3D(rot, t.origin))
		else:
			_add_shape(s.layer, _cyl_shape(size.x, size.y), Transform3D(rot, t.origin))
	for li: Dictionary in r.lights:
		var l := OmniLight3D.new()
		l.position = xf * (li.pos as Vector3)
		l.light_color = li.color
		l.light_energy = li.energy
		l.omni_range = li.range
		l.light_specular = 0.2
		l.light_bake_mode = Light3D.BAKE_DISABLED
		l.distance_fade_enabled = true
		l.distance_fade_length = 8.0
		_chunk.add_child(l)
		if li.night:
			l.set_meta("energy", li.energy)
			l.distance_fade_begin = 50.0
			l.visible = false
			night_lights.append(l)
		else:
			lights.append(l)


## Transform for a prop at c: yaw (radians) and optional stretch.
static func _at(c: Vector3, yaw := 0.0, scale := Vector3.ONE) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(scale), c)


## Furniture-style placement: rot = turned 90 degrees (same as _p's remap).
static func _at_rot(c: Vector3, rot: bool) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, -PI * 0.5) if rot else Basis.IDENTITY, c)


## Yaw that turns a prop's local +Z towards out (props facing away from the road).
static func _yaw_to(out: Vector3) -> float:
	return atan2(out.x, out.z)


## Yaw that turns a prop's local +X along dir.
static func _yaw_x(dir: Vector3) -> float:
	return atan2(-dir.z, dir.x)



## A name sign (assets/models/building_sign.tscn: style it there).
func _label(text: String, pos: Vector3, yaw: float, size := 96, col := Color.WHITE) -> void:
	var l: Label3D = SIGN_SCENE.instantiate()
	l.text = text
	l.font_size = size
	l.modulate = col
	l.position = pos
	l.rotation.y = yaw
	_chunk.add_child(l)


# ================================================================ ground & streets

func _usable_point(p: Vector2, excluded: Array) -> bool:
	if not bounds.grow(-2.0).has_point(p):
		return false
	for r: Rect2 in excluded:
		if r.has_point(p):
			return false
	return true


func _build_ground() -> void:
	var bc := bounds.get_center()
	# Playable ground (concrete / sidewalk)
	box(Vector3(bc.x, -0.5, bc.y), Vector3(bounds.size.x + 4.0, 1.0, bounds.size.y + 4.0), CONCRETE, L_SOLID)
	# Scenery ground outside the fence
	box(Vector3(0, -0.53, 0), Vector3(700, 1.0, 700), Color("7f9a5a"), DECOR)
	# Roads with dashed centre lines (none inside junctions: they stay clear)
	_find_junctions()
	for r: Rect2 in road_rects:
		box(Vector3(r.get_center().x, 0.012, r.get_center().y), Vector3(r.size.x, 0.024, r.size.y), ASPHALT, DECOR)
		var horizontal := r.size.x > r.size.y
		var length := r.size.x if horizontal else r.size.y
		var n := int(length / 6.0)
		for i in n:
			var t := (i + 0.5) * length / n
			var dc := Vector2(r.position.x + t, r.get_center().y) if horizontal else Vector2(r.get_center().x, r.position.y + t)
			if _hits_any(Rect2(dc - Vector2(1.2, 1.2), Vector2(2.4, 2.4)), _junctions, 0.5):
				continue
			if horizontal:
				box(Vector3(dc.x, 0.03, dc.y), Vector3(2.2, 0.02, 0.18), Color("e8c84a"), DECOR)
			else:
				box(Vector3(dc.x, 0.03, dc.y), Vector3(0.18, 0.02, 2.2), Color("e8c84a"), DECOR)
	# Boundary fence: visual chain-link panels + tall invisible collision walls.
	var fence_col := Color("55625a")
	var post_col := Color("8c949a")
	# Sides: 0 = north (min z), 1 = south (max z), 2 = west (min x), 3 = east (max x)
	for side in 4:
		var horizontal := side < 2
		var fixed: float = [bounds.position.y, bounds.end.y, bounds.position.x, bounds.end.x][side]
		var outward := -1.0 if side % 2 == 0 else 1.0
		var mid := bc.x if horizontal else bc.y
		var length := bounds.size.x if horizontal else bounds.size.y
		var n := maxi(1, int(length / 4.0))
		for i in n + 1:
			var t := mid - length / 2.0 + i * length / n
			var pc := Vector3(t, 1.75, fixed) if horizontal else Vector3(fixed, 1.75, t)
			box(pc, Vector3(0.15, 3.5, 0.15), post_col, L_WALL)
		var center := Vector3(mid, 1.6, fixed) if horizontal else Vector3(fixed, 1.6, mid)
		var size := Vector3(length, 3.0, 0.06) if horizontal else Vector3(0.06, 3.0, length)
		box(center, size, fence_col, L_WALL)
		var top := Vector3(mid, 3.45, fixed) if horizontal else Vector3(fixed, 3.45, mid)
		var top_size := Vector3(length, 0.1, 0.12) if horizontal else Vector3(0.12, 0.1, length)
		box(top, top_size, post_col, L_WALL)


## Invisible walls round the map, flush with the inside of the fence posts so
## there's nothing to stand on along the top of the fence, rising up to a sky
## barrier SKY_CLEARANCE above the tallest structure. The sky barrier stops
## players but nothing else: grapples, shots, sprays and pings pass through it.
func _build_boundary() -> void:
	for b in buildings:
		_tallest = maxf(_tallest, float(b.top) + 1.1)  # roof + parapet
	sky_height = _tallest + SKY_CLEARANCE
	var bc := bounds.get_center()
	const POST_HALF := 0.075  # fence posts are 0.15 m thick, centred on the fence line
	const THICK := 2.0
	for side in 4:
		var horizontal := side < 2
		var fixed: float = [bounds.position.y, bounds.end.y, bounds.position.x, bounds.end.x][side]
		var outward := -1.0 if side % 2 == 0 else 1.0
		var mid := bc.x if horizontal else bc.y
		var length := bounds.size.x if horizontal else bounds.size.y
		var off := fixed + outward * (THICK * 0.5 - POST_HALF)  # inner face flush with the posts' inner side
		var c := Vector3(mid, sky_height * 0.5, off) if horizontal else Vector3(off, sky_height * 0.5, mid)
		var s := Vector3(length + THICK * 2.0, sky_height + 4.0, THICK) if horizontal else Vector3(THICK, sky_height + 4.0, length + THICK * 2.0)
		_add_shape(L_SOLID, _box_shape(s), Transform3D(Basis.IDENTITY, c))
	var sky := StaticBody3D.new()
	sky.name = "SkyBarrier"
	sky.collision_layer = L_SKY
	sky.collision_mask = 0
	_chunk.add_child(sky)
	var shape := CollisionShape3D.new()
	shape.shape = _box_shape(Vector3(bounds.size.x + 8.0, 2.0, bounds.size.y + 8.0))
	shape.position = Vector3(bc.x, sky_height + 1.0, bc.y)
	sky.add_child(shape)


func _near_any(p: Vector2, pts: Array, d: float) -> bool:
	for q in pts:
		var q2 := Vector2(q.x, q.z)
		if p.distance_to(q2) < d:
			return true
	return false


## Street dressing, built after the buildings so nothing ends up in front of a door:
##  * stop-and-go traffic in both lanes of every road (cars, taxis, vans, buses),
##    with gaps you can slip through and clear junctions,
##  * zebra crossings at the junctions,
##  * a sidewalk strip along every road: lamps and street trees at regular spacing,
##    with benches, bins, hydrants, newspaper boxes, mailboxes and bus shelters,
##  * parking lots where a building was cut out (smaller maps),
##  * a few planters, benches and kiosks in the open squares, dumpsters in alleys.
func _build_street_props() -> void:
	_detail = false
	_avoid = spawn_dots.duplicate()
	for o in objectives:
		_avoid.append(o.pos)
	_find_junctions()
	_build_crosswalks()
	_build_traffic()
	_build_sidewalks()
	_build_parking_lots()
	_build_squares()
	for p in _dumpsters:
		var c := MapData.px(p[0], p[1])
		if _street_clear(c, 0.8, 1.2) and not _on_road(c, 0.5):
			_prefab("props/street/dumpster", _at(Vector3(c.x, 0.0, c.y)))
	_detail = true


## True if a prop of radius r at p stands on open ground: inside the fence, bmargin
## away from buildings, clear of doors, spawn zones and Tag spots, out of the park.
func _street_clear(p: Vector2, bmargin: float, r: float) -> bool:
	if not bounds.grow(-1.0 - r).has_point(p) or _in_building(p, bmargin + r):
		return false
	if has_park and park_rect.grow(0.5 + r).has_point(p):
		return false
	for d: Vector2 in _door_pts:
		if d.distance_to(p) < 2.6 + r:
			return false
	return not _near_any(p, _avoid, 5.0 + r)


func _on_road(p: Vector2, grow: float) -> bool:
	for r: Rect2 in road_rects:
		if r.grow(grow).has_point(p):
			return true
	return false


func _in_junction(p: Vector2, grow: float) -> bool:
	for j: Rect2 in _junctions:
		if j.grow(grow).has_point(p):
			return true
	return false



func _find_junctions() -> void:
	_junctions.clear()
	for i in road_rects.size():
		for k in range(i + 1, road_rects.size()):
			var a: Rect2 = road_rects[i]
			var b: Rect2 = road_rects[k]
			if a.intersects(b):
				var o := a.intersection(b)
				if o.size.x > 2.0 and o.size.y > 2.0:
					_junctions.append(o)


## Zebra crossings across every road just outside each junction it runs into.
func _build_crosswalks() -> void:
	var paint := Color("e8e4d8")
	for j: Rect2 in _junctions:
		for r: Rect2 in road_rects:
			if not r.intersects(j):
				continue
			var horizontal := r.size.x > r.size.y
			var width := r.size.y if horizontal else r.size.x
			for side: float in [-1.0, 1.0]:
				var mid: Vector2
				if horizontal:
					mid = Vector2(j.position.x - 1.6 if side < 0 else j.end.x + 1.6, r.get_center().y)
				else:
					mid = Vector2(r.get_center().x, j.position.y - 1.6 if side < 0 else j.end.y + 1.6)
				if not r.has_point(mid) or _in_junction(mid, 0.3):
					continue
				var n := int(width / 0.9)
				for k in n:
					var o := (k + 0.5) * width / n - width * 0.5
					if horizontal:
						box(Vector3(mid.x, 0.034, mid.y + o), Vector3(2.4, 0.02, 0.45), paint, DECOR)
					else:
						box(Vector3(mid.x + o, 0.034, mid.y), Vector3(0.45, 0.02, 2.4), paint, DECOR)


## Footprint of a vehicle centred at c2: body length x width plus the wheels,
## which stick out 0.125 m on each side.
func _vehicle_rect(c2: Vector2, along_x: bool, vlen: float, vwid: float) -> Rect2:
	var s := Vector2(vlen, vwid + 0.25) if along_x else Vector2(vwid + 0.25, vlen)
	return Rect2(c2 - s * 0.5, s)


## Every vehicle keeps at least CAR_GAP to every other one (front, back and side
## to side), so you can always slide between two cars.
func _vehicle_space_ok(rect: Rect2) -> bool:
	for o: Rect2 in _car_rects:
		if o.grow(CAR_GAP).intersects(rect):
			return false
	return true


## Stopped traffic in both lanes of every road: about half the spots are taken,
## every vehicle is at least CAR_GAP from the next one (so the two lanes are
## staggered rather than side by side), and junctions, crossings, spawn zones
## and Tag spots stay clear.
func _build_traffic() -> void:
	for r: Rect2 in road_rects:
		var horizontal := r.size.x > r.size.y
		var length := r.size.x if horizontal else r.size.y
		var width := r.size.y if horizontal else r.size.x
		for lane: float in [-1.0, 1.0]:
			var off := lane * width * 0.25
			var t := rng.randf_range(1.0, 6.0)
			while t < length - 2.0:
				var roll := rng.randf()
				var vlen := 10.5 if roll < 0.07 else (5.4 if roll < 0.25 else 4.3)
				var mid_t := t + vlen * 0.5
				var c2 := Vector2(r.position.x + mid_t, r.get_center().y + off) if horizontal else Vector2(r.get_center().x + off, r.position.y + mid_t)
				var fits := t + vlen < length - 0.5 and not _near_any(c2, _avoid, 7.0 + vlen * 0.5)
				for s: float in [-0.5, 0.0, 0.5]:
					var q := c2 + (Vector2(vlen * s, 0.0) if horizontal else Vector2(0.0, vlen * s))
					if _in_junction(q, 3.2) or not bounds.grow(-1.0).has_point(q):
						fits = false
				var vwid := 2.5 if vlen > 10.0 else (2.1 if vlen > 5.0 else 1.9)
				var rect := _vehicle_rect(c2, horizontal, vlen, vwid)
				if not fits or not _vehicle_space_ok(rect):
					t += 2.0
					continue
				if rng.randf() < 0.55:
					_car_rects.append(rect)
					var c := Vector3(c2.x, 0.0, c2.y)
					if vlen > 10.0:
						_bus(c, horizontal, [Color("c0453a"), Color("3f6fa8"), Color("e0b13c")][rng.randi() % 3])
					elif vlen > 5.0:
						_van(c, horizontal, CAR_COLORS[rng.randi() % CAR_COLORS.size()])
					elif rng.randf() < 0.2:
						_prefab("props/vehicles/taxi", _at(c, _road_yaw(horizontal)))
					else:
						_car(c, horizontal, CAR_COLORS[rng.randi() % CAR_COLORS.size()])
					t += vlen + CAR_GAP + rng.randf_range(0.2, 2.5)
				else:
					t += rng.randf_range(6.0, 14.0)


## Every 6 m along both curbs: lamp, tree, furniture, tree, lamp...
func _build_sidewalks() -> void:
	for r: Rect2 in road_rects:
		var horizontal := r.size.x > r.size.y
		var length := r.size.x if horizontal else r.size.y
		for side: float in [-1.0, 1.0]:
			var edge: float
			if horizontal:
				edge = r.end.y if side > 0 else r.position.y
			else:
				edge = r.end.x if side > 0 else r.position.x
			var slot := 0
			var t := 3.0
			while t < length - 1.0:
				var a := (r.position.x if horizontal else r.position.y) + t
				var p := Vector2(a, edge + side * 0.7) if horizontal else Vector2(edge + side * 0.7, a)
				_sidewalk_item(p, horizontal, side, slot)
				slot += 1
				t += 6.0


## One sidewalk slot at p (on the curb line). "out" points away from the road.
func _sidewalk_item(p: Vector2, along_x: bool, side: float, slot: int) -> void:
	if _on_road(p, 0.3) or not _street_clear(p, 0.6, 0.5):
		return
	var c := Vector3(p.x, 0.0, p.y)
	var out := Vector3(0, 0, side) if along_x else Vector3(side, 0, 0)
	match slot % 4:
		0:
			_prefab("props/street/lamp", _at(c, _yaw_to(out)))
		1, 3:
			_prefab("props/street/tree_planter", _at(c))
			var r := rng.randf_range(1.1, 1.4)
			_crown(c + Vector3(0, 3.1, 0), r, Color("4f8a3a").lerp(Color("7ab04a"), rng.randf()))
		2:
			_street_furniture(c, out, along_x)


func _street_furniture(c: Vector3, out: Vector3, along_x: bool) -> void:
	var dir := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
	var roll := rng.randf()
	var shelter_at := c + out * 1.0
	if roll < 0.15 and _street_clear(Vector2(shelter_at.x, shelter_at.z), 0.6, 1.8):
		_prefab("props/street/bus_shelter", _at(shelter_at, _yaw_to(out)))
	elif roll < 0.45:
		_prefab("props/street/bench", _at(c, _yaw_to(out)))
	elif roll < 0.65:
		_prefab("props/street/bin", _at(c))
	elif roll < 0.85:
		_prefab("props/street/hydrant_news", _at(c, _yaw_x(dir)))
	else:
		_prefab("props/street/mailbox", _at(c))


## A tree crown (props/nature/tree_crown, radius 1) scaled to radius r.
func _crown(c: Vector3, r: float, col: Color) -> void:
	_prefab("props/nature/tree_crown", _at(c, 0.0, Vector3.ONE * r), {"leaf": col})


## Props laid out along a road face along X; on roads running along Z they turn.
static func _road_yaw(along_x: bool) -> float:
	return 0.0 if along_x else -PI * 0.5


## Car parks (lots cut from a smaller map, or from a random city): rows of wide
## 3.6 m bays back to back with 1.5 m between the rows, 6 m aisles, a bit under
## half the bays taken, and every car at least CAR_GAP from the next.
func _build_parking_lots() -> void:
	var line := Color("d8d4c8")
	for lot: Rect2 in _lots:
		var inner := lot.grow(-1.0)
		if inner.size.x < 6.0 or inner.size.y < 6.0:
			continue
		box(Vector3(lot.get_center().x, 0.012, lot.get_center().y), Vector3(lot.size.x, 0.024, lot.size.y), ASPHALT, DECOR)
		var rows_x := inner.size.x >= inner.size.y
		var row_len := inner.size.x if rows_x else inner.size.y
		var depth := inner.size.y if rows_x else inner.size.x
		var bays := int(row_len / 3.6)  # wide bays: room to slide between parked cars
		var row := 0
		var d := 2.3
		while d < depth - 2.0 and bays > 0:
			for k in bays + 1:
				var u := k * row_len / bays
				var lc := Vector2(inner.position.x + u, inner.position.y + d) if rows_x else Vector2(inner.position.x + d, inner.position.y + u)
				box(Vector3(lc.x, 0.03, lc.y), Vector3(0.1, 0.02, 4.4) if rows_x else Vector3(4.4, 0.02, 0.1), line, DECOR)
			for k in bays:
				var u := (k + 0.5) * row_len / bays
				var c2 := Vector2(inner.position.x + u, inner.position.y + d) if rows_x else Vector2(inner.position.x + d, inner.position.y + u)
				var rect := _vehicle_rect(c2, not rows_x, 4.3, 1.9)
				if rng.randf() < 0.45 and _street_clear(c2, 0.5, 1.2) and _vehicle_space_ok(rect):
					_car_rects.append(rect)
					_car(Vector3(c2.x, 0.0, c2.y), not rows_x, CAR_COLORS[rng.randi() % CAR_COLORS.size()])
			d += 5.8 if row % 2 == 0 else 10.6  # back-to-back rows 1.5 m apart, then a 6 m aisle
			row += 1


## Open ground away from the roads: a few big tree planters, benches around a bin
## and kiosks, spread out (at least 9 m apart). Dumpsters go next to buildings.
func _build_squares() -> void:
	var placed: Array = []
	var target := maxi(20, int(90.0 * bounds.get_area() / (200.0 * 170.0)))
	var tries := 0
	while placed.size() < target and tries < 3000:
		tries += 1
		var p := Vector2(rng.randf_range(bounds.position.x + 2.0, bounds.end.x - 2.0), rng.randf_range(bounds.position.y + 2.0, bounds.end.y - 2.0))
		if _on_road(p, 4.0) or not _street_clear(p, 2.6, 1.5):
			continue
		var crowded := false
		for lot: Rect2 in _lots:
			if lot.grow(1.0).has_point(p):
				crowded = true
		for q: Vector2 in placed:
			if q.distance_to(p) < 9.0:
				crowded = true
		if crowded:
			continue
		var c := Vector3(p.x, 0.0, p.y)
		var along_x := rng.randf() < 0.5
		var roll := rng.randf()
		if _in_building(p, 6.0) and roll < 0.25:
			_prefab("props/street/dumpster", _at(c, _road_yaw(along_x)))
		elif roll < 0.55:
			_prefab("props/street/square_planter", _at(c))
			var r := rng.randf_range(1.5, 1.9)
			_crown(c + Vector3(0, 3.4, 0), r, Color("4f8a3a").lerp(Color("7ab04a"), rng.randf()))
		elif roll < 0.8:
			_prefab("props/street/bench_pair", _at(c, _road_yaw(along_x)))
		else:
			_prefab("props/street/kiosk", _at(c, _road_yaw(along_x)))  # random awning colour
		placed.append(p)


## Leafy bush (props/nature/bush, scaled to a random size): blocks sight but not bullets.
func _bush(c: Vector3) -> void:
	var r := rng.randf_range(0.9, 1.3)
	_prefab("props/nature/bush", _at(c, 0.0, Vector3.ONE * r), {"leaf": Color("4f8a3a").lerp(Color("6aa84f"), rng.randf())})


func _van(c: Vector3, along_x: bool, col: Color) -> void:
	_prefab("props/vehicles/van", _at(c, _road_yaw(along_x)), {"body": col})


func _bus(c: Vector3, along_x: bool, col: Color) -> void:
	_prefab("props/vehicles/bus", _at(c, _road_yaw(along_x)), {"body": col})


func _car(c: Vector3, along_x: bool, col: Color) -> void:
	_prefab("props/vehicles/car", _at(c, _road_yaw(along_x)), {"body": col})


## True if p is inside (or within margin of) a building that exists on this map size.
func _in_building(p: Vector2, margin: float) -> bool:
	for b in _active:
		var r := MapData.px_rect(b[3]).grow(margin)
		if r.has_point(p):
			return true
	return false


# ================================================================ buildings

func _uv(u: float, v: float) -> Vector2:
	if _flip:
		u = _umax - u
	if _ax:
		return Vector2(_o.x + u, _o.y + v)
	return Vector2(_o.x + v, _o.y + u)


func _uv_rect(u0: float, v0: float, u1: float, v1: float) -> Rect2:
	var a := _uv(u0, v0)
	var c := _uv(u1, v1)
	return Rect2(minf(a.x, c.x), minf(a.y, c.y), absf(c.x - a.x), absf(c.y - a.y))


func _subtract(a: Rect2, h: Rect2) -> Array:
	var hc := a.intersection(h)
	if hc.size.x <= 0.01 or hc.size.y <= 0.01:
		return [a]
	var out := []
	# top / bottom strips (z), left / right strips (x)
	if hc.position.y > a.position.y + 0.01:
		out.append(Rect2(a.position.x, a.position.y, a.size.x, hc.position.y - a.position.y))
	if hc.end.y < a.end.y - 0.01:
		out.append(Rect2(a.position.x, hc.end.y, a.size.x, a.end.y - hc.end.y))
	if hc.position.x > a.position.x + 0.01:
		out.append(Rect2(a.position.x, hc.position.y, hc.position.x - a.position.x, hc.size.y))
	if hc.end.x < a.end.x - 0.01:
		out.append(Rect2(hc.end.x, hc.position.y, a.end.x - hc.end.x, hc.size.y))
	return out


## A slab piece (building/floor_slab, 1 x 1 m) stretched over r with its top at y.
func _slab(r: Rect2, y_top: float, col: Color) -> void:
	_prefab("building/floor_slab", _rect_xf(r, y_top), {"color": col})


static func _rect_xf(r: Rect2, y: float) -> Transform3D:
	return Transform3D(Basis.from_scale(Vector3(r.size.x, 1.0, r.size.y)), Vector3(r.get_center().x, y, r.get_center().y))


## Number of MODULE-wide wall modules along one side of a building.
static func _modules_along(length: float) -> int:
	return maxi(1, roundi((length - WALL_T * 2.0) / MODULE))


## Snaps a building rect (sketch pixels) to the module grid around its centre:
## each side becomes n modules plus a corner post at each end (moves each wall by
## at most half a module).
static func snap_rect_px(r: Array) -> Array:
	var c := Vector2((r[0] + r[2]) * 0.5, (r[1] + r[3]) * 0.5)
	var s := Vector2(r[2] - r[0], r[3] - r[1]) * MapData.SCALE
	var w := (maxi(3, roundi((s.x - WALL_T * 2.0) / MODULE)) * MODULE + WALL_T * 2.0) / MapData.SCALE
	var h := (maxi(3, roundi((s.y - WALL_T * 2.0) / MODULE)) * MODULE + WALL_T * 2.0) / MapData.SCALE
	return [c.x - w * 0.5, c.y - h * 0.5, c.x + w * 0.5, c.y + h * 0.5]


## Buildings are assembled from the modular pieces in assets/building: wall
## modules (solid, windows, door), fillers for tall storeys, corner posts, trim
## bands, parapets, floor slabs, stair segments, dividers, rails and interior
## walls. The building's style colours fill the pieces' colour slots.
func _build_building(b: Array) -> void:
	var bid: int = b[0]
	var bname: String = b[1]
	var type: String = b[2]
	var r := MapData.px_rect(b[3])
	var floors: int = b[4]
	var fh: float = b[5]
	var st: Dictionary = STYLES[type]
	var x0 := r.position.x
	var z0 := r.position.y
	var x1 := r.end.x
	var z1 := r.end.y
	var top := floors * fh
	buildings.append({"id": bid, "name": bname, "rect": r, "floors": floors, "fh": fh, "top": top, "color": st.wall, "type": type})

	var inner := Rect2(x0 + WALL_T, z0 + WALL_T, r.size.x - WALL_T * 2.0, r.size.y - WALL_T * 2.0)
	_ax = r.size.x >= r.size.y
	_o = inner.position
	var umax := inner.size.x if _ax else inner.size.y
	var vmax := inner.size.y if _ax else inner.size.x
	_umax = umax
	var run := fh * 1.6  # = (fh / STAIR_RISE) segments of STAIR_RUN
	var S := run + STAIR_LANDING * 2.0
	# Stairwells: one at the start of the long axis, and a second one at the far
	# end whenever the building is long enough.
	var flips := [false]
	if umax >= S * 2.0 + 6.0:
		flips.append(true)
	var stairs: Array = []
	var holes: Array = []
	for fl: bool in flips:
		_flip = fl
		stairs.append(_uv_rect(0, 0, S, STAIR_W))
		holes.append(_uv_rect(STAIR_LANDING, 0, STAIR_LANDING + run, STAIR_W))
	_flip = false

	# --- Objective inside this building?
	var obj_here: Array = []
	for o in objectives:
		if r.has_point(Vector2(o.pos.x, o.pos.z)):
			obj_here.append(o.pos)

	# --- Interior room layout (corridor + rooms) for residential/school buildings:
	# rooms of ROOM_MODULES modules (the last one takes any spare), door in the middle.
	var room_floors := []
	if type in ["motel", "school"]:
		room_floors = range(floors)
	elif type in ["apartments", "rundown", "rundown2"]:
		room_floors = range(1, floors)
	var can_rooms := vmax - ROOM_V >= 4.5
	var nmod := roundi(umax / MODULE)
	var nrooms := maxi(1, nmod / ROOM_MODULES)
	var room_walls := []  # u of the walls between rooms
	var room_doors := []  # module index of each room's door
	for i in nrooms:
		var m0 := i * ROOM_MODULES
		var m1 := nmod if i == nrooms - 1 else m0 + ROOM_MODULES
		room_doors.append((m0 + m1 - 1) / 2)
		if i > 0:
			room_walls.append(m0 * MODULE)
	var rooms_on_ground := can_rooms and 0 in room_floors

	# --- Exterior doors (ground floor), each in a whole wall module
	var door_spots := []  # [side, t, module]
	for side in 4:
		var horizontal := side < 2
		var a0 := (x0 if horizontal else z0) + WALL_T
		var n := _modules_along((x1 - x0) if horizontal else (z1 - z0))
		if n < 3:
			continue
		for frac: float in [0.5, 0.3, 0.7, 0.2, 0.8]:
			var slot := clampi(int(frac * n), 1, n - 2)
			var t: float = a0 + (slot + 0.5) * MODULE
			var clear := _door_clear_rect(side, t, x0, z0, x1, z1)
			if rooms_on_ground and _door_hits_rooms(side, t, x0, z0, x1, z1, room_walls, umax):
				continue
			if not _hits_any(clear, stairs, 0.4):
				door_spots.append([side, t, slot])
				break

	# --- Floors / roof (slabs around the stair holes)
	_prefab("building/floor_finish", _rect_xf(inner, 0.0), {"color": st.floor})
	for k in range(1, floors + 1):
		var y := k * fh
		var is_roof := k == floors
		var area := r if is_roof else inner
		var pieces: Array = [area]
		for hole: Rect2 in holes:
			var next: Array = []
			for pc: Rect2 in pieces:
				next.append_array(_subtract(pc, hole))
			pieces = next
		for piece: Rect2 in pieces:
			_slab(piece, y, st.roof if is_roof else st.floor)

	# --- Stair segments, lane divider and hole railing (for every stairwell)
	for fl: bool in flips:
		_flip = fl
		_build_stairwell(floors, fh, run, top, st)
	_flip = false

	# --- Exterior walls
	_wall_slots = []
	_build_exterior_walls(type, floors, fh, x0, z0, x1, z1, door_spots, st)

	# --- Signs: the name centred over every street door (or on the two long
	# faces if a building has no door)
	var sign_y := minf(DOOR_H + 0.75, minf(top, fh) - 0.45)
	for ds in door_spots:
		var dside: int = ds[0]
		var dt: float = ds[1]
		var outward: Vector3 = [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT][dside]
		var face_c: Vector3 = [Vector3(dt, 0, z0), Vector3(dt, 0, z1), Vector3(x0, 0, dt), Vector3(x1, 0, dt)][dside]
		_label(bname.to_upper(), face_c + outward * 0.08 + Vector3(0, sign_y, 0), _yaw_to(outward), 80)
	if door_spots.is_empty():
		_label(bname.to_upper(), Vector3((x0 + x1) * 0.5, minf(top, fh) - 0.9, z0 - 0.05), PI, 96)
		_label(bname.to_upper(), Vector3((x0 + x1) * 0.5, minf(top, fh) - 0.9, z1 + 0.05), 0.0, 96)

	# --- Furniture forbidden zones
	_forbid = []
	for sr: Rect2 in stairs:
		_forbid.append(sr.grow(0.8))
	for ds in door_spots:
		_forbid.append(_door_clear_rect(ds[0], ds[1], x0, z0, x1, z1))
	var obj_forbid := []
	for op in obj_here:
		obj_forbid.append(Rect2(op.x - 3.5, op.z - 3.5, 7.0, 7.0))

	# --- Interior rooms
	var room_forbid := []
	if can_rooms and not room_floors.is_empty():
		# Always keep the corridor beside the partition walkable.
		room_forbid.append(_uv_rect(0, ROOM_V - 2.0, umax, ROOM_V))
		# partition line (v = ROOM_V) and cross walls
		room_forbid.append(_uv_rect(0, ROOM_V - 0.5, umax, ROOM_V + 0.5))
		for cu: float in room_walls:
			room_forbid.append(_uv_rect(cu - 0.5, ROOM_V, cu + 0.5, vmax))
		for dm: int in room_doors:
			var dc := (dm + 0.5) * MODULE
			room_forbid.append(_uv_rect(dc - 1.3, ROOM_V - 1.7, dc + 1.3, ROOM_V + 1.7))
		var partition := {"color": st.trim.lerp(WHITE, 0.6)}
		var cross := {"color": st.wall.lerp(WHITE, 0.5)}
		var u_yaw := 0.0 if _ax else -PI * 0.5   # walls running along u
		var v_yaw := -PI * 0.5 if _ax else 0.0   # walls running along v
		for k in room_floors:
			var y0: float = k * fh
			var h := fh - SLAB_T
			# Partition along u at v = ROOM_V: one module per MODULE, doors in the room middles.
			for m in nmod:
				var p := _uv((m + 0.5) * MODULE, ROOM_V)
				var at := Vector3(p.x, y0, p.y)
				if m in room_doors:
					_prefab("building/wall_interior_door", _at(at, u_yaw), partition)
					_prefab("building/wall_interior", _at(at + Vector3(0, DOOR_H, 0), u_yaw, Vector3(MODULE, h - DOOR_H, 1)), partition)
					var along: float = (_o.x if _ax else _o.y) + (m + 0.5) * MODULE
					_make_door(_ax, (_o.y if _ax else _o.x) + ROOM_V, along, y0, st.door, DOOR_W - 0.1)
				else:
					_prefab("building/wall_interior", _at(at, u_yaw, Vector3(MODULE, h, 1)), partition)
			# Walls between rooms, from the partition to the outer wall.
			for cu: float in room_walls:
				var p := _uv(cu, (ROOM_V + vmax) * 0.5)
				_prefab("building/wall_interior", _at(Vector3(p.x, y0, p.y), v_yaw, Vector3(vmax - ROOM_V, h, 1)), cross)

	# --- Furnish every storey (and specials), then decorate
	# Layout info for the furnishing (rooms, street doors, stairwells), in u/v.
	var bounds_u := [0.0] + room_walls + [umax]
	var lay_rooms := []
	for i in room_doors.size():
		lay_rooms.append([bounds_u[i], bounds_u[i + 1], (room_doors[i] + 0.5) * MODULE])
	var lay_doors := []
	for ds in door_spots:
		var side: int = ds[0]
		var tt: float = ds[1]
		var wp: Vector2 = [Vector2(tt, inner.position.y), Vector2(tt, inner.end.y), Vector2(inner.position.x, tt), Vector2(inner.end.x, tt)][side]
		var inward: Vector3 = [Vector3.BACK, Vector3.FORWARD, Vector3.RIGHT, Vector3.LEFT][side]
		var duv := Vector2(wp.x - _o.x, wp.y - _o.y) if _ax else Vector2(wp.y - _o.y, wp.x - _o.x)
		lay_doors.append([duv, inward])
	_lay = {"umax": umax, "vmax": vmax, "rooms": lay_rooms, "doors": lay_doors, "stairs_far": flips.size() > 1, "S": S}
	var floor_zones := []
	var floor_cells := []
	var floor_walls := []
	for k in floors:
		var y := k * fh
		var zones: Array = _forbid.duplicate()
		var walls := []
		if k == 0:
			zones.append_array(obj_forbid)
		if k in room_floors and can_rooms:
			zones.append_array(room_forbid)
			walls.append(_uv_rect(0, ROOM_V - 0.2, umax, ROOM_V + 0.2))
			for cu: float in room_walls:
				walls.append(_uv_rect(cu - 0.2, ROOM_V, cu + 0.2, vmax))
		floor_zones.append(zones)
		floor_walls.append(walls)
		_occupied = []
		if type == "sports":
			_furnish_sports(inner, zones)
		elif type == "water":
			_furnish_water(inner, zones)
		else:
			_furnish_floor(type, k, inner, y, fh, zones, k in room_floors and can_rooms)
		floor_cells.append(_occupied)
	_decorate_interior(type, floors, fh, inner, stairs, door_spots, floor_zones, floor_cells, floor_walls)

	# --- Respawn candidates on every floor + roof
	for k in floors + 1:
		var y := k * fh + 0.1
		for i in 4:
			var p := Vector2(rng.randf_range(inner.position.x + 1.0, inner.end.x - 1.0), rng.randf_range(inner.position.y + 1.0, inner.end.y - 1.0))
			if _hits_any(Rect2(p, Vector2.ZERO), stairs, 1.0):
				continue
			spawn_points.append(Vector3(p.x, y, p.y))


func _hits_any(r: Rect2, rects: Array, grow: float) -> bool:
	for o: Rect2 in rects:
		if r.intersects(o.grow(grow)):
			return true
	return false


## World direction of the stairwell's +u axis (u runs along the building's long
## side; the second stairwell is mirrored).
func _u_dir() -> Vector3:
	var s := -1.0 if _flip else 1.0
	return Vector3(s, 0, 0) if _ax else Vector3(0, 0, s)


## Two-lane stairwell: each storey is fh / STAIR_RISE stair segments, alternating
## lanes (lane A climbs towards +u, lane B back towards -u), with a divider between
## the lanes and a rail along the open edge of the stair hole.
func _build_stairwell(floors: int, fh: float, run: float, top: float, st: Dictionary) -> void:
	var steps := {"color": st.trim.lerp(st.floor, 0.5)}
	var trim := {"color": st.trim}
	var ud := _u_dir()
	var u_yaw := _yaw_x(ud)
	var segs := roundi(fh / STAIR_RISE)
	var rails := roundi(run / STAIR_RUN)
	for k in floors:
		var h0 := k * fh
		var lane_a := k % 2 == 0
		var vc := STAIR_W * (0.25 if lane_a else 0.75)
		for i in segs:
			var u := STAIR_LANDING + STAIR_RUN * i if lane_a else STAIR_LANDING + run - STAIR_RUN * i
			var p := _uv(u, vc)
			_prefab("building/stair_segment", _at(Vector3(p.x, h0 + STAIR_RISE * i, p.y), _yaw_x(ud if lane_a else -ud)), steps)
		# Between the lanes: a sloped wall that follows this flight, STAIR_GUARD_H
		# above the steps (stair_divider is a 1 m box standing on its origin,
		# tilted to the flight and stretched along it).
		var dp := _uv(STAIR_LANDING + run * 0.5, STAIR_W * 0.5)
		var slope := atan2(fh, run)
		var tilt := Basis(Vector3(0, 0, 1), slope if lane_a else -slope)
		var guard := Basis(Vector3.UP, u_yaw) * tilt * Basis.from_scale(Vector3(sqrt(run * run + fh * fh), STAIR_GUARD_H * cos(slope), 1))
		_prefab("building/stair_divider", Transform3D(guard, Vector3(dp.x, h0 + fh * 0.5 - 0.05, dp.y)), trim)
		# Railing on the open edge of the hole (upper floors)
		if k >= 1:
			_stair_rail(h0, rails, u_yaw, trim)
	_stair_rail(top, rails, u_yaw, trim)  # around the roof hole


func _stair_rail(y: float, count: int, yaw: float, cols: Dictionary) -> void:
	for j in count:
		var p := _uv(STAIR_LANDING + STAIR_RUN * (j + 0.5), STAIR_W + 0.06)
		_prefab("building/rail_section", _at(Vector3(p.x, y, p.y), yaw), cols)


## Exterior walls: on every storey each MODULE slot of each side gets a wall
## module: a door (ground floor), one of the building's window style, or solid.
## Windows skip the end slots and the slots next to doors, and are rarer right
## after another window, so there's plenty of solid wall to run along. Storeys
## taller than MODULE_H get a filler on top; a trim band runs along each storey,
## corner posts fill the corners and a parapet runs round the roof.
func _build_exterior_walls(type: String, floors: int, fh: float, x0: float, z0: float, x1: float, z1: float, door_spots: Array, st: Dictionary) -> void:
	var top := floors * fh
	var p_win := 0.2 if type in ["warehouse", "water", "sports"] else 0.35
	var window: String = WINDOW_PIECES[rng.randi() % WINDOW_PIECES.size()]
	var cols := {"wall": st.wall, "trim": st.trim}
	for side in 4:
		var horizontal := side < 2
		var fixed: float = [z0 + WALL_T * 0.5, z1 - WALL_T * 0.5, x0 + WALL_T * 0.5, x1 - WALL_T * 0.5][side]
		var a0 := (x0 if horizontal else z0) + WALL_T
		var n := _modules_along((x1 - x0) if horizontal else (z1 - z0))
		var yaw := 0.0 if horizontal else -PI * 0.5
		var door_slots := []
		for ds in door_spots:
			if ds[0] == side:
				door_slots.append(ds[2])
		var window_cols := _window_columns(n, p_win)
		for k in floors:
			var y0 := k * fh
			for i in n:
				var t := a0 + (i + 0.5) * MODULE
				var at := Vector3(t, y0, fixed) if horizontal else Vector3(fixed, y0, t)
				var piece := "building/wall_solid"
				var near_door := k == 0 and ((i - 1) in door_slots or (i + 1) in door_slots)
				if k == 0 and i in door_slots:
					piece = "building/wall_door"
				elif i in window_cols and not near_door:
					piece = window
				if piece == "building/wall_solid":
					var inward: Vector3 = [Vector3.BACK, Vector3.FORWARD, Vector3.RIGHT, Vector3.LEFT][side]
					_wall_slots.append([at + inward * WALL_T * 0.5, inward, k])
				_prefab(piece, _at(at, yaw), cols)
				if fh > MODULE_H:
					_prefab("building/wall_filler", _at(at + Vector3(0, MODULE_H, 0), yaw, Vector3(1, fh - MODULE_H, 1)), cols)
				_prefab("building/trim_band", _at(at + Vector3(0, fh - 0.26, 0), yaw), cols)
				if k == floors - 1:
					_prefab("building/parapet", _at(Vector3(at.x, top, at.z), yaw), cols)
		for slot: int in door_slots:
			_make_door(horizontal, fixed, a0 + (slot + 0.5) * MODULE, 0.0, st.door)
	for c: Vector2 in [Vector2(x0, z0), Vector2(x1, z0), Vector2(x0, z1), Vector2(x1, z1)]:
		var cx := c.x + (WALL_T * 0.5 if c.x == x0 else -WALL_T * 0.5)
		var cz := c.y + (WALL_T * 0.5 if c.y == z0 else -WALL_T * 0.5)
		_prefab("building/corner_post", _at(Vector3(cx, 0, cz), 0.0, Vector3(1, top + 1.1, 1)), cols)


## Which wall modules of an n-module side get windows: about the same share as
## before (p of the inner modules), but evenly spaced and in the same columns on
## every storey. A building picks either single windows or pairs. The end
## modules always stay solid.
func _window_columns(n: int, p: float) -> Array:
	var inner_n := n - 2
	if inner_n <= 0:
		return []
	var count := clampi(roundi(inner_n * p), 1 if inner_n >= 3 else 0, inner_n)
	var cols := []
	if rng.randf() < 0.4 and count >= 2 and inner_n >= 5:
		var pairs := count / 2
		for j in pairs:
			var c := 1 + int((j + 0.5) * inner_n / float(pairs))
			cols.append(clampi(c - 1, 1, n - 2))
			cols.append(clampi(c, 1, n - 2))
	else:
		for j in count:
			cols.append(1 + int((j + 0.5) * inner_n / float(count)))
	return cols


## True if an exterior door at (side, t) would be blocked by interior room walls.
func _door_hits_rooms(side: int, t: float, x0: float, z0: float, x1: float, z1: float, room_walls: Array, umax: float) -> bool:
	var p: Vector2
	if side < 2:
		p = Vector2(t, z0 if side == 0 else z1)
	else:
		p = Vector2(x0 if side == 2 else x1, t)
	var u := (p.x - _o.x) if _ax else (p.y - _o.y)
	var v := (p.y - _o.y) if _ax else (p.x - _o.x)
	if v > ROOM_V:
		for cu: float in room_walls:
			if absf(u - cu) < 1.4:
				return true
	if absf(v - ROOM_V) < 1.4 and (u < 0.5 or u > umax - 0.5):
		return true
	return false


func _door_clear_rect(side: int, t: float, x0: float, z0: float, x1: float, z1: float) -> Rect2:
	match side:
		0:
			return Rect2(t - 1.4, z0, 2.8, 2.8)
		1:
			return Rect2(t - 1.4, z1 - 2.8, 2.8, 2.8)
		2:
			return Rect2(x0, t - 1.4, 2.8, 2.8)
		_:
			return Rect2(x1 - 2.8, t - 1.4, 2.8, 2.8)


## Doors are exactly the size of their opening (w must match the opening width),
## so they sit flush with the frame with no gap at the sides or top.
func _make_door(horizontal: bool, fixed: float, t: float, y0: float, col: Color, w := DOOR_W) -> void:
	var d: Door = DOOR_SCENE.instantiate()
	var hinge: Vector3
	var yaw: float
	if horizontal:
		hinge = Vector3(t - w * 0.5, y0, fixed)
		yaw = 0.0
	else:
		hinge = Vector3(fixed, y0, t - w * 0.5)
		yaw = -PI * 0.5
	d.setup(doors.size(), hinge, yaw, w, DOOR_H, col)
	_chunk.add_child(d)
	doors.append(d)
	if y0 < 1.0:
		var centre := hinge + Basis(Vector3.UP, yaw).x * w * 0.5
		_door_pts.append(Vector2(centre.x, centre.z))


# ================================================================ interior decor

## Decor theme per building type (scenes in assets/furniture/decor/):
## [ceiling light, wall pieces, floor pieces against the walls, rug on each storey]
const THEME_DECOR := {
	"warehouse": ["industrial_lamp", ["safety_sign", "fire_extinguisher", "wall_pipes"], ["pallet_stack", "trash_can"], false],
	"school": ["ceiling_panel", ["bulletin_board", "wall_clock", "poster", "whiteboard"], ["vending_machine", "trash_can", "water_cooler"], false],
	"theater": ["pendant_lamp", ["movie_poster", "curtain", "wall_lamp"], ["trash_can"], false],
	"bank": ["ceiling_panel", ["picture_frame", "wall_clock"], ["water_cooler"], true],
	"diner": ["pendant_lamp", ["neon_sign", "poster", "wall_clock"], ["jukebox"], false],
	"arcade": ["ceiling_panel", ["neon_sign", "poster"], ["vending_machine", "trash_can"], false],
	"club": ["pendant_lamp", ["neon_sign"], ["speaker_stack"], false],
	"bar": ["pendant_lamp", ["neon_sign", "wall_shelf_bottles", "dartboard"], ["jukebox"], false],
	"apartments": ["pendant_lamp", ["picture_frame", "wall_lamp", "poster"], [], true],
	"mall": ["ceiling_panel", ["poster", "neon_sign", "banner"], ["mannequin", "trash_can"], false],
	"motel": ["pendant_lamp", ["picture_frame", "wall_lamp"], ["vending_machine"], true],
	"rundown": ["pendant_lamp", ["graffiti_panel", "poster", "wall_pipes"], ["trash_can"], false],
	"rundown2": ["pendant_lamp", ["graffiti_panel", "poster", "wall_pipes"], ["trash_can"], false],
	"office": ["ceiling_panel", ["whiteboard", "picture_frame", "wall_clock"], ["water_cooler", "vending_machine", "trash_can"], false],
	"casino": ["pendant_lamp", ["neon_sign", "picture_frame", "curtain"], [], true],
	"library": ["pendant_lamp", ["picture_frame", "wall_clock", "bulletin_board"], [], true],
	"water": ["industrial_lamp", ["valve_panel", "wall_pipes", "safety_sign"], [], false],
	"sports": ["industrial_lamp", ["banner"], [], false],
}
const LIGHT_STEP := 6.0     # ceiling light spacing (m)
const P_WALL_DECOR := 0.27  # chance a solid wall module gets a wall piece
const P_FLOOR_DECOR := 0.12 # chance it gets a floor piece instead


## Decorates a building's storeys: ceiling lights on a grid (clear of the stair
## holes and room walls), themed pieces on the solid exterior wall modules, floor
## pieces against the walls where no furniture stands, a rug for some types and an
## exit sign over every street door. Lights, signs, frames and rugs are visual only.
func _decorate_interior(type: String, floors: int, fh: float, inner: Rect2, stairs: Array, door_spots: Array, floor_zones: Array, floor_cells: Array, floor_walls: Array) -> void:
	var theme: Array = THEME_DECOR.get(type, [])
	if theme.is_empty():
		return
	var light: String = theme[0]
	if light == "industrial_lamp" and fh < 5.5:
		light = "ceiling_panel"  # long drops only in tall halls
	var wall_items: Array = theme[1]
	var floor_items: Array = theme[2]
	var light_yaw := 0.0 if _ax else -PI * 0.5
	var nx := maxi(1, roundi(inner.size.x / LIGHT_STEP))
	var nz := maxi(1, roundi(inner.size.y / LIGHT_STEP))
	for k in floors:
		var y := k * fh
		var ceil_y := (k + 1) * fh - SLAB_T
		var walls: Array = floor_walls[k]
		# Ceiling lights
		for i in nx:
			for j in nz:
				var c := inner.position + Vector2((i + 0.5) * inner.size.x / nx, (j + 0.5) * inner.size.y / nz)
				var spot := Rect2(c - Vector2(0.8, 0.8), Vector2(1.6, 1.6))
				if _hits_any(spot, stairs, 0.3) or _hits_any(spot, walls, 0.0):
					continue
				_prefab("furniture/decor/" + light, _at(Vector3(c.x, ceil_y, c.y), light_yaw))
		if type == "club" and fh >= 5.0:
			var mid := inner.get_center()
			if not _hits_any(Rect2(mid - Vector2.ONE, Vector2(2, 2)), stairs, 0.3):
				_prefab("furniture/decor/disco_ball", _at(Vector3(mid.x, ceil_y, mid.y)))
		# Rug somewhere clear (under furniture is fine)
		if theme[3]:
			for _attempt in 6:
				var rc := Vector2(rng.randf_range(inner.position.x + 2.0, inner.end.x - 2.0), rng.randf_range(inner.position.y + 2.0, inner.end.y - 2.0))
				var turn := rng.randf() < 0.5
				var half := Vector2(0.9, 1.3) if turn else Vector2(1.3, 0.9)
				if not _blocked(Rect2(rc - half, half * 2.0), floor_zones[k]):
					_prefab("furniture/decor/rug", _at(Vector3(rc.x, y, rc.y), PI * 0.5 if turn else 0.0))
					break
	# Wall modules: a wall piece, a floor piece against the wall, or nothing
	for ws: Array in _wall_slots:
		var face: Vector3 = ws[0]
		var inward: Vector3 = ws[1]
		var k: int = ws[2]
		var zones: Array = floor_zones[k]
		var xf := _at(face, _yaw_to(inward))
		var roll := rng.randf()
		if roll < 0.03:
			if not _blocked(_wall_foot(face, inward, 0.4), zones):
				_prefab("furniture/decor/fire_extinguisher", xf)
		elif roll < 0.03 + P_WALL_DECOR:
			if not _blocked(_wall_foot(face, inward, 0.4), zones):
				_prefab("furniture/decor/" + wall_items[rng.randi() % wall_items.size()], xf)
		elif roll < 0.03 + P_WALL_DECOR + P_FLOOR_DECOR and not floor_items.is_empty():
			var foot := _wall_foot(face, inward, 1.2)
			if not _blocked(foot, zones) and not _hits_any(foot, floor_cells[k], 0.2):
				_prefab("furniture/decor/" + floor_items[rng.randi() % floor_items.size()], xf)
				floor_cells[k].append(foot)
	# Exit signs over the street doors, on the inside
	for ds in door_spots:
		var side: int = ds[0]
		var t: float = ds[1]
		var p: Vector3 = [
			Vector3(t, 0, inner.position.y), Vector3(t, 0, inner.end.y),
			Vector3(inner.position.x, 0, t), Vector3(inner.end.x, 0, t),
		][side]
		var inward: Vector3 = [Vector3.BACK, Vector3.FORWARD, Vector3.RIGHT, Vector3.LEFT][side]
		_prefab("furniture/decor/exit_sign", _at(p + Vector3(0, DOOR_H + 0.35, 0), _yaw_to(inward)))


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
## _lay holds the building being furnished: {umax, vmax, rooms: [[u0, u1, door_u]],
## doors: [Vector2 uv of each street door], stairs_far: bool, S}.
var _lay := {}
var _fzones: Array = []
var _fy := 0.0
var _finner := Rect2()
var _last_xf := Transform3D()
var _placed: Array = []   # transforms of everything placed by the last _run


func _furnish_floor(type: String, k: int, inner: Rect2, y: float, fh: float, zones: Array, rooms_here: bool) -> void:
	_fzones = zones
	_fy = y
	_finner = inner
	var rooms: Array = _lay.rooms if rooms_here else []
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
	return Vector3(1, 0, 0) if _ax else Vector3(0, 0, 1)


func _vd() -> Vector3:
	return Vector3(0, 0, 1) if _ax else Vector3(1, 0, 0)


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
	var p := _uv(u, v)
	var yaw := _yaw_to(face)
	var foot := _foot_at(name, p, yaw)
	if not _finner.grow(0.02).encloses(foot):
		return false
	var room := foot.grow(margin)
	if (check_zones and _blocked(room, _fzones)) or _hits_any(foot, _occupied, margin):
		return false
	_last_xf = _at(Vector3(p.x, _fy, p.y), yaw)
	_prefab("furniture/" + name, _last_xf, slots)
	_placed.append(_last_xf)
	if solid:
		_occupied.append(foot)
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
		var u := rng.randf_range(1.0, float(_lay.umax) - 1.0)
		var v := rng.randf_range(1.0, float(_lay.vmax) - 1.0)
		var face := _vd() if rng.randf() < 0.5 else _ud()
		if _put(names[rng.randi() % names.size()], u, v, face, slots):
			placed += 1


## The main street door in u/v (ground floor), and the way into the building from it.
func _main_door() -> Array:
	if _lay.doors.is_empty():
		return []
	return _lay.doors[0]  # [uv, inward direction (world)]


## The u range layouts work in: the whole floor less a little wall clearance.
## (The stairwells are keep-clear zones, so anything that would overlap them is
## simply skipped.)
func _clear_u0() -> float:
	return 0.6


func _clear_u1() -> float:
	return float(_lay.umax) - 0.6


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
	var um: float = _lay.umax
	var vm: float = _lay.vmax
	if k > 0:
		# Mezzanine offices: desks along the back wall, a meeting table.
		_run("desk_chair", true, vm - 0.45, _clear_u0(), _clear_u1(), -_vd(), 0.6)
		_put("table_chairs", um * 0.5, vm * 0.45, _vd(), {"main": DARKWOOD})
		_scatter(["crate"], 2, {"color": CARDBOARD})
		return
	# Rack rows with forklift aisles; a cross aisle every 4th rack.
	var v := 1.3
	while v < vm - 1.0:
		var n := _run("rack", true, v, 1.0, um - 1.0, _vd(), 0.0, 4)
		if n > 0:
			_fill_racks()
		v += 4.6
	_by_door("forklift", 4.0, false)
	_scatter(["crate"], 4, {"color": CARDBOARD})


## Cardboard boxes on the shelves of the racks the last _run placed.
func _fill_racks() -> void:
	for xf: Transform3D in _placed:
		for h: float in [0.15, 1.3, 2.45]:
			for s: float in [-1.0, 0.1, 1.1]:
				if rng.randf() < 0.75:
					var bh := rng.randf_range(0.5, 0.95)
					_prefab("furniture/rack_box", xf * Transform3D(Basis.from_scale(Vector3(1.0, bh, 1.0)), Vector3(s, h + 0.04, 0)))


func _lay_school(k: int, rooms: Array) -> void:
	var vm: float = _lay.vmax
	if rooms.is_empty():
		_classroom(_clear_u0(), _clear_u1() - 0.3, STAIR_W + 1.0, vm - 0.3, _clear_u0() - 0.5)
	else:
		for r: Array in rooms:
			_classroom(r[0] + 0.3, r[1] - 0.3, ROOM_V + 0.4, vm - 0.3, r[0] + (0.11 if r[0] > 0.0 else 0.02))
	# Lockers along the front wall, by the corridor.
	_run("school_shelf", true, 0.28, _clear_u0(), _clear_u1(), _vd(), 0.3)
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
	var vm: float = _lay.vmax
	for r: Array in rooms:
		var mid: float = (r[0] + r[1]) * 0.5
		# Bed with its head on the back wall and a nightstand beside it, the TV
		# dresser on the side wall facing it, a rug at the foot of the bed.
		if _put("bed", mid + 0.3, vm - 1.1, -_vd(), {"blanket": Color("c0453a").lerp(Color("4a6a9a"), rng.randf())}):
			_prefab("furniture/nightstand", _last_xf)
			var rug := _uv(mid + 0.3, vm - 3.0)
			if vm - 3.0 > ROOM_V + 1.6:
				_prefab("furniture/decor/rug", _at(Vector3(rug.x, _fy, rug.y), _yaw_x(_ud())))
		_put("dresser_tv", r[1] - 0.9, maxf(ROOM_V + 2.0, vm - 3.2), _ud(), {}, 0.05)
	if k == 0:
		_by_door("front_desk", 3.0)
		_put("potted_plant", _clear_u0() + 0.6, 1.0, _vd())
	if rooms.is_empty():
		_grid("bed", _clear_u0() + 1.5, _clear_u1() - 1.5, 2.0, vm - 1.5, 4.0, 3.5, -_vd())


func _lay_apartments(k: int, rooms: Array) -> void:
	var vm: float = _lay.vmax
	if k == 0 or rooms.is_empty():
		# Lobby: reception, sofas along the wall, plants.
		if k == 0:
			_by_door("front_desk", 3.0)
		_run("sofa", true, vm - 0.5, _clear_u0() + 1.0, _clear_u1() - 1.0, _vd(), 3.0, 0, {"main": Color("7a8a6a")})
		_put("potted_plant", _clear_u0() + 0.6, vm - 0.6, _vd())
		_put("potted_plant", _clear_u1() - 0.6, vm - 0.6, _vd())
		return
	var kind := 0
	for r: Array in rooms:
		var mid: float = (r[0] + r[1]) * 0.5
		match kind % 3:
			0:  # bedroom
				if _put("bed", mid + 0.3, vm - 1.1, -_vd(), {"blanket": BLUE.lerp(Color("c27aa0"), rng.randf())}):
					_prefab("furniture/nightstand", _last_xf)
				_put("dresser_tv", r[1] - 0.9, maxf(ROOM_V + 2.0, vm - 3.2), _ud(), {}, 0.05)
			1:  # living room: sofa on the back wall facing a TV, a rug in between
				if _put("sofa", mid, vm - 0.55, _vd(), {"main": Color("7a8a6a").lerp(Color("8a5a3c"), rng.randf())}):
					_prefab("furniture/tv_stand", _last_xf)
					var rug := _uv(mid, vm - 1.9)
					_prefab("furniture/decor/rug", _at(Vector3(rug.x, _fy, rug.y), _yaw_x(_ud())))
				_put("potted_plant", r[0] + 0.7, vm - 0.7, _vd())
			2:  # kitchen + dining table
				_put("kitchen", mid - 0.3, vm - 0.4, _vd(), {}, 0.05)
				_put("table_chairs", mid, (ROOM_V + vm) * 0.5 - 0.3, _vd(), {"main": LIGHTWOOD})
		kind += 1


func _lay_rundown(k: int, rooms: Array) -> void:
	var vm: float = _lay.vmax
	if rooms.is_empty():
		_scatter(["mattress", "sofa", "rundown_tv", "crate"], 5, {"main": Color("6a5a3a"), "color": CARDBOARD})
		_scatter(["trash_bag"], 5)
		return
	for r: Array in rooms:
		var mid: float = (r[0] + r[1]) * 0.5
		if rng.randf() < 0.75:
			_put("mattress", mid + rng.randf_range(-1.0, 1.0), vm - 1.1, _vd())
		if rng.randf() < 0.35:
			_put("rundown_tv", r[0] + 1.5, (ROOM_V + vm) * 0.5, _ud())
		elif rng.randf() < 0.4:
			_put("sofa", mid, ROOM_V + 1.6, -_vd(), {"main": Color("6a5a3a")})
		for i in rng.randi_range(0, 3):
			_put("trash_bag", rng.randf_range(r[0] + 0.6, r[1] - 0.6), rng.randf_range(ROOM_V + 0.6, vm - 0.6), _vd(), {}, 0.0)
	_scatter(["trash_bag"], 3)


## A real shop floor: aisles of shelves and clothes rails with cross aisles,
## display tables near the front, and checkouts by the door.
func _lay_store(k: int) -> void:
	var vm: float = _lay.vmax
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
	var vm: float = _lay.vmax
	if k == 0:
		_by_door("front_desk", 3.0)
	_grid("office_cubicle", _clear_u0() + 2.2, _clear_u1() - 2.2, 2.6, vm - 2.0, 5.4, 4.8, _vd())
	_run("copier", true, vm - 0.4, _clear_u0(), _clear_u0() + 4.0, -_vd(), 1.0)
	_put("table_chairs", _clear_u1() - 1.2, vm - 1.8, _vd(), {"main": DARKWOOD})
	_put("potted_plant", _clear_u1() - 0.6, 0.7, _vd())


func _lay_bank(k: int) -> void:
	var um: float = _lay.umax
	var vm: float = _lay.vmax
	if k > 0:
		_run("desk_chair", true, vm - 0.45, _clear_u0(), _clear_u1(), -_vd(), 1.0)
		_put("table_chairs", um * 0.5, vm * 0.4, _vd(), {"main": DARKWOOD})
		return
	# Teller counters across the back of the hall, the vault behind them in the
	# corner, bankers' desks on the side, a waiting bench and plants by the door.
	_put("vault", um - 2.2, vm - 2.6, _vd())
	_run("teller_counter", true, vm - 2.4, um * 0.3, um * 0.75, _vd(), 0.0)
	_put("desk_chair", _clear_u0() + 1.0, vm * 0.45, -_ud())
	_put("desk_chair", _clear_u0() + 1.0, vm * 0.45 + 2.2, -_ud())
	_by_door("mall_bench", 4.0)
	_put("potted_plant", _clear_u1() - 0.6, 0.7, _vd())


func _lay_diner(k: int) -> void:
	var vm: float = _lay.vmax
	if k > 0:
		_grid("table_chairs", _clear_u0() + 1.5, _clear_u1() - 1.5, 2.0, vm - 2.0, 3.2, 3.2, _vd(), {"main": WOOD})
		return
	# Counter with stools along the back, booths along the front windows.
	_run("diner_counter", true, vm - 1.5, _clear_u0() + 1.0, _clear_u1() - 1.0, -_vd(), 0.0, 4)
	_run("diner_booth", true, 0.75, _clear_u0(), _clear_u1(), _vd(), 0.2)
	_grid("table_chairs", _clear_u0() + 2.0, _clear_u1() - 2.0, vm * 0.5 - 0.2, vm * 0.5 - 0.2, 3.4, 3.0, _vd(), {"main": WOOD})


func _lay_bar(k: int) -> void:
	var vm: float = _lay.vmax
	_run("bar_counter", true, vm - 1.5, _clear_u0() + 1.0, _clear_u1() - 1.0, -_vd(), 0.0, 3)
	_grid("pool_table", _clear_u0() + 2.5, _clear_u1() - 2.5, vm * 0.45, vm * 0.45, 4.0, 3.0, _ud())
	_run("table_chairs", true, 1.2, _clear_u0() + 0.6, _clear_u1(), _vd(), 1.4, 0, {"main": WOOD})


func _lay_club(k: int) -> void:
	var um: float = _lay.umax
	var vm: float = _lay.vmax
	# Dance floor in the middle (you can walk on it), bar on the back wall,
	# lounge sofas along the front wall.
	for du: float in [-1.5, 1.5]:
		for dv: float in [-1.5, 1.5]:
			_put("dance_floor", um * 0.5 + du, vm * 0.5 + dv, _vd(), {}, 0.0, false)
	_occupied.append(_uv_rect(um * 0.5 - 3.0, vm * 0.5 - 3.0, um * 0.5 + 3.0, vm * 0.5 + 3.0))
	_run("club_bar", true, vm - 0.45, _clear_u0() + 1.0, _clear_u1() - 1.0, _vd(), 0.0)
	_run("sofa", true, 0.55, _clear_u0(), _clear_u1(), -_vd(), 2.5, 0, {"main": Color("6a2a5a")})


func _lay_arcade(k: int) -> void:
	var vm: float = _lay.vmax
	# Cabinets along both long walls and back-to-back down the middle.
	_run("arcade_cabinets", true, 0.45, _clear_u0(), _clear_u1(), -_vd(), 0.4)
	_run("arcade_cabinets", true, vm - 0.45, _clear_u0(), _clear_u1(), _vd(), 0.4)
	var mid := vm * 0.5
	_run("arcade_cabinets", true, mid - 0.5, _clear_u0() + 1.5, _clear_u1() - 1.5, _vd(), 0.4, 4)
	_run("arcade_cabinets", true, mid + 0.45, _clear_u0() + 1.5, _clear_u1() - 1.5, -_vd(), 0.4, 4)
	_scatter(["air_hockey", "claw_machine"], 3)


func _lay_casino(k: int) -> void:
	var vm: float = _lay.vmax
	if k == 0:
		_by_door("casino_counter", 3.0)
	# Back-to-back rows of slot machines with aisles, tables in the open middle.
	var v := 1.6
	var row := 0
	while v < vm * 0.45:
		_run("slot_machines", true, v, _clear_u0(), _clear_u1(), _vd() if row % 2 == 0 else -_vd(), 0.1, 4)  # pairs back to back
		v += 0.85 if row % 2 == 0 else 2.6
		row += 1
	_grid("card_table", _clear_u0() + 2.0, _clear_u1() - 2.0, vm * 0.6, vm - 1.8, 3.6, 3.4, _vd())
	_scatter(["craps_table"], 2)


func _lay_library(k: int) -> void:
	var vm: float = _lay.vmax
	if k == 0:
		_by_door("front_desk", 3.0)
	# Book stacks across the back, reading tables in front by the windows.
	_rows("bookshelf", vm * 0.5, vm - 1.0, _clear_u0() + 0.5, _clear_u1() - 0.5, 3.4, _vd(), 0.0, 4)
	_grid("table_chairs", _clear_u0() + 1.8, _clear_u1() - 1.8, 2.0, vm * 0.5 - 2.0, 3.4, 2.8, _ud(), {"main": LIGHTWOOD})


## Cinema: the screen on the far end wall (ground floor), rows of seats facing
## it with an aisle down the middle, and the concession stand by the door.
func _lay_theater(k: int, fh: float) -> void:
	var um: float = _lay.umax
	var vm: float = _lay.vmax
	if k == 0:
		var sw := minf(1.0, (vm - 1.0) / 8.4)
		var sp := _uv(um - 0.05, vm * 0.5)
		if fh >= 5.0:
			_prefab("furniture/theater_screen", _at(Vector3(sp.x, _fy, sp.y), _yaw_to(-_ud()), Vector3(sw, 1, 1)))
			_occupied.append(_uv_rect(um - 1.0, vm * 0.5 - 4.2 * sw, um, vm * 0.5 + 4.2 * sw))
		_by_door("concession_stand", 3.0)
	var u := um - 5.0 if k == 0 else um - 2.0
	var last := um * 0.45 if k == 0 else _clear_u0() + 1.0
	while u >= last:
		# Two blocks of seats with a centre aisle.
		_run("theater_seats", false, u, 1.0, vm * 0.5 - 0.8, -_ud(), 0.0)
		_run("theater_seats", false, u, vm * 0.5 + 0.8, vm - 1.0, -_ud(), 0.0)
		u -= 1.15


func _desk_chair(c: Vector3, rot: bool) -> void:
	_prefab("furniture/desk_chair", _at_rot(c, rot))


func _school_desk(c: Vector3, rot: bool) -> void:
	_prefab("furniture/school_desk", _at_rot(c, rot))


## Warehouse rack (frame + shelves) with random cardboard boxes on the lower shelves.
func _rack(c: Vector3, rot: bool) -> void:
	var at := _at_rot(c, rot)
	_prefab("furniture/rack", at)
	for h: float in [0.15, 1.3, 2.45]:
		for s: float in [-1.0, 0.1, 1.1]:
			if rng.randf() < 0.75:
				var bh := rng.randf_range(0.5, 0.95)
				_prefab("furniture/rack_box", at * Transform3D(Basis.from_scale(Vector3(1.0, bh, 1.0)), Vector3(s, h + 0.04, 0)))


## 1-3 crates of random size (furniture/crate is a 1 m crate), sometimes stacked.
func _crates(c: Vector3) -> void:
	var n := rng.randi_range(1, 3)
	for i in n:
		var s := rng.randf_range(0.9, 1.25)
		var off := Vector3(rng.randf_range(-0.9, 0.9), 0, rng.randf_range(-0.9, 0.9))
		_prefab("furniture/crate", _at(c + off, 0.0, Vector3.ONE * s), {"color": CARDBOARD if rng.randf() < 0.6 else WOOD})
		if rng.randf() < 0.4:
			var s2 := s * 0.8
			_prefab("furniture/crate", _at(c + off + Vector3(0, s, 0), 0.0, Vector3.ONE * s2), {"color": CARDBOARD})


func _forklift(c: Vector3, rot: bool) -> void:
	_prefab("furniture/forklift", _at_rot(c, rot))


func _sofa(c: Vector3, rot: bool, col: Color) -> void:
	_prefab("furniture/sofa", _at_rot(c, rot), {"main": col})


func _bed(c: Vector3, rot: bool, blanket: Color) -> void:
	_prefab("furniture/bed", _at_rot(c, rot), {"blanket": blanket})


func _table_chairs(c: Vector3, rot: bool, col: Color) -> void:
	_prefab("furniture/table_chairs", _at_rot(c, rot), {"main": col})


func _bookshelf(c: Vector3, rot: bool) -> void:
	_prefab("furniture/bookshelf", _at_rot(c, rot))  # random book colours


func _plant(c: Vector3) -> void:
	_prefab("furniture/potted_plant", _at(c))


func _vault(c: Vector3) -> void:
	_prefab("furniture/vault", _at(c))


## Arena: court with hoops, bleachers on both long sides (a ramp collides; the
## steps are visual), the scoreboard, banners and benches near the ends.
func _furnish_sports(inner: Rect2, zones: Array) -> void:
	var c := inner.get_center()
	var c3 := Vector3(c.x, 0.0, c.y)
	_prefab("props/arena/court", _at(c3))
	_prefab("props/arena/bleachers", _at(c3))
	_prefab("props/arena/bleachers", _at(c3, PI))
	_prefab("props/arena/scoreboard", _at(c3))
	_label("SWIFTCURRENT RAPIDS", Vector3(c.x, 7.5, inner.position.y + 0.2), 0.0, 160, Color("9fd0ff"))
	_label("SWIFTCURRENT RAPIDS", Vector3(c.x, 7.5, inner.end.y - 0.2), PI, 160, Color("9fd0ff"))
	for s: float in [-1.0, 1.0]:
		for i in 3:
			var p := Vector3(c.x + s * (18.0 + i * 2.5), 0, c.y + rng.randf_range(-6, 6))
			if not _blocked(Rect2(p.x - 1.5, p.z - 1.5, 3, 3), zones):
				_prefab("props/arena/bench", _at(p))


## Water works: tanks, two long pipes (stretched to the hall) and pumps.
func _furnish_water(inner: Rect2, zones: Array) -> void:
	var c := inner.get_center()
	var tanks := [Vector2(-10, -3), Vector2(-3, 4), Vector2(5, -3), Vector2(12, 4)]
	for t in tanks:
		var p := Vector3(c.x + t.x, 0, c.y + t.y)
		if _blocked(Rect2(p.x - 3, p.z - 3, 6, 6), zones):
			continue
		_prefab("props/water/tank", _at(p))
	# Pipes between tanks (low enough to vault over with a jump)
	_prefab("props/water/pipe", _at(Vector3(c.x, 0, c.y), 0.0, Vector3(inner.size.x - 14.0, 1, 1)))
	_prefab("props/water/pipe", _at(Vector3(c.x + 2, 0, c.y + 6.8), 0.0, Vector3(inner.size.x - 18.0, 1, 1)))
	for i in 5:
		var p := Vector3(rng.randf_range(inner.position.x + 2, inner.end.x - 2), 0, rng.randf_range(inner.position.y + 2, inner.end.y - 2))
		if _blocked(Rect2(p.x - 1.5, p.z - 1.5, 3, 3), zones):
			continue
		_prefab("props/water/pump", _at(p))


# ================================================================ park (19)

const PATH_W := 2.6  # width of props/park/path (paving and kerbs)


## The park, laid out like a real city park (classic 37 x 44 m layout scaled to
## this one; the court, playground and pond keep their size):
## * two paved paths, north-south between the court and the pond and east-west
##   below the playground, meeting at a round plaza with a fountain and flower beds
## * benches and bins along the paths, and lamp posts that light up at night
## * a row of trees round the edge (gaps where the paths come in), and trees and
##   bushes dotted over the lawns
## * picnic tables with umbrellas on the open lawns (the umbrella tops bounce you)
## * the basketball court, the playground on a sandpit, and the pond
func _build_park() -> void:
	_detail = false  # park props are always drawn (no furniture draw distance)
	var r := park_rect
	var x0 := r.position.x
	var z0 := r.position.y
	var kx := r.size.x / 37.0
	var kz := r.size.y / 44.0
	# The ground pieces are scenes in assets/props/park/: lawn (stretched to the
	# park), path (stretched to each path), plaza, sandpit and pond (scaled with
	# the park). All visual only.
	_prefab("props/park/lawn", _at(Vector3(r.get_center().x, 0, r.get_center().y), 0.0, Vector3(r.size.x, 1, r.size.y)))
	_label(park_name.to_upper(), Vector3(r.get_center().x, 3.0, r.end.y + 0.5), 0.0, 96, Color("d8f0c0"))
	# Basketball court (left), playground on a sandpit (top left), pond (bottom right)
	var court := Rect2(x0 + 2.5 * kx, z0 + minf(13.0 * kz, r.size.y - 27.0), 14.0, 26.0)
	var cc := court.get_center()
	_prefab("props/park/basketball_court", _at(Vector3(cc.x, 0, cc.y)))  # with hoops and fence
	var pg := Rect2(x0 + 6.5 * kx - 4.0, z0 + 5.1 * kz - 2.6, 8.0, 5.2)
	var pc := pg.get_center()
	var sand := pg.grow(1.2)  # props/park/sandpit is this size
	_prefab("props/park/sandpit", _at(Vector3(pc.x, 0, pc.y)))
	_prefab("props/park/playground", _at(Vector3(pc.x, 0, pc.y)))
	_prefab("props/park/pond", _at(Vector3(x0 + 26.5 * kx, 0, z0 + 34.0 * kz), 0.0, Vector3(kx, 1, kz)))
	var pond := Rect2(x0 + 20.0 * kx, z0 + 24.5 * kz, 12.0 * kx, 17.0 * kz)

	# Keep clear of the big pieces, the Tag and the spawn zones.
	var avoid := [court.grow(1.0), sand.grow(0.8), pond.grow(0.8)]
	for o in objectives:
		avoid.append(Rect2(o.pos.x - 3.5, o.pos.z - 3.5, 7.0, 7.0))
	for s: Vector3 in spawn_dots:
		avoid.append(Rect2(s.x - 3.0, s.z - 3.0, 6.0, 6.0))

	# Paths, and the plaza where they meet
	var path_x := maxf(x0 + 19.5 * kx, court.end.x + 2.2)
	var path_z := (sand.end.y + court.position.y) * 0.5
	var cross := court.position.y - sand.end.y >= PATH_W + 1.0
	var paths := [Rect2(path_x - PATH_W * 0.5, z0, PATH_W, r.size.y)]
	if cross:
		paths.append(Rect2(x0, path_z - PATH_W * 0.5, r.size.x, PATH_W))
	for pr: Rect2 in paths:
		_park_path(pr)
	var plaza := Vector2(path_x, path_z if cross else z0 + r.size.y * 0.25)
	var plaza_r := 4.2
	if not _hits_any(Rect2(plaza - Vector2.ONE * 2.4, Vector2(4.8, 4.8)), avoid.slice(3), 0.0):
		_prefab("props/park/plaza", _at(Vector3(plaza.x, 0, plaza.y)))
		_prefab("props/park/fountain", _at(Vector3(plaza.x, 0, plaza.y)))
		# Flower beds on the plaza's diagonals, turned to follow it round
		for i in 4:
			var a := PI * 0.25 + i * PI * 0.5
			var d := Vector2(cos(a), sin(a))
			var fp := plaza + d * (plaza_r + 1.4)
			var fr := Rect2(fp - Vector2(1.3, 1.3), Vector2(2.6, 2.6))
			if r.grow(-0.5).encloses(fr) and not _hits_any(fr, avoid, 0.0):
				_prefab("props/park/flower_bed", _at(Vector3(fp.x, 0, fp.y), _yaw_x(Vector3(-d.y, 0, d.x))))
		avoid.append(Rect2(plaza - Vector2.ONE * (plaza_r + 2.2), Vector2.ONE * (plaza_r + 2.2) * 2.0))
	var path_keep := []
	for pr: Rect2 in paths:
		path_keep.append(pr.grow(0.4))

	# Along both sides of each path: benches (some with a bin) and lamp posts
	for pi in paths.size():
		var pr: Rect2 = paths[pi]
		var others := path_keep.duplicate()
		others.remove_at(pi)
		var along_z: bool = pr.size.y > pr.size.x
		var length: float = pr.size.y if along_z else pr.size.x
		var n := int(length / 7.0)
		for i in n:
			var t := (i + 0.5) * length / n
			for side: float in [-1.0, 1.0]:
				var off := PATH_W * 0.5 + 0.55
				var c := Vector2(pr.get_center().x + side * off, pr.position.y + t) if along_z else Vector2(pr.position.x + t, pr.get_center().y + side * off)
				var away := Vector3(side, 0, 0) if along_z else Vector3(0, 0, side)
				var foot := Rect2(c - Vector2(0.9, 0.9), Vector2(1.8, 1.8))
				if not r.grow(-0.8).has_point(c) or _hits_any(foot, avoid, 0.0) or _hits_any(foot, others, 0.0):
					continue
				if (i + (1 if side > 0.0 else 0)) % 2 == 0:
					_prefab("props/park/bench", _at(Vector3(c.x, 0, c.y), _yaw_to(away)))
					if i % 2 == 0:
						var bin := c + (Vector2(0, 1.4) if along_z else Vector2(1.4, 0))
						_prefab("props/street/bin", _at(Vector3(bin.x, 0, bin.y)))
				else:
					_prefab("props/street/lamp", _at(Vector3(c.x, 0, c.y), _yaw_to(away)))
				avoid.append(foot)

	# Picnic tables with umbrellas on the open lawns right of the main path
	var spots := []
	var lx := path_x + PATH_W * 0.5 + 1.0
	var lw := r.end.x - lx - 1.5
	var lawns := [Rect2(lx, z0 + 1.5, lw, path_z - PATH_W * 0.5 - 1.0 - (z0 + 1.5)),
		Rect2(lx, path_z + PATH_W * 0.5 + 1.0, lw, pond.position.y - 1.0 - (path_z + PATH_W * 0.5 + 1.0))]
	for lawn: Rect2 in lawns:
		if lawn.size.x < 3.4 or lawn.size.y < 3.4:
			continue
		var cols := maxi(1, int(lawn.size.x / 4.6))
		var rows := maxi(1, int(lawn.size.y / 4.6))
		for i in cols:
			for j in rows:
				spots.append(lawn.position + Vector2((i + 0.5) * lawn.size.x / cols, (j + 0.5) * lawn.size.y / rows))
	var tables := 0
	for sp: Vector2 in spots:
		var foot := Rect2(sp - Vector2(1.7, 1.7), Vector2(3.4, 3.4))
		if tables >= 6 or _hits_any(foot, avoid, 0.0) or _hits_any(foot, path_keep, 0.0):
			continue
		_prefab("props/park/picnic_umbrella", _at(Vector3(sp.x, 0, sp.y), rng.randf_range(-0.3, 0.3)))
		avoid.append(foot)
		tables += 1

	# A row of trees round the edge, with gaps where the paths come in
	var edge := r.grow(-1.6)
	for side in 4:
		var horizontal := side < 2
		var length := edge.size.x if horizontal else edge.size.y
		var n := maxi(1, int(length / 5.5))
		for i in n + 1:
			var t := float(i) / n
			var p := Vector2(edge.position.x + t * edge.size.x, edge.position.y if side == 0 else edge.end.y) if horizontal else Vector2(edge.position.x if side == 2 else edge.end.x, edge.position.y + t * edge.size.y)
			var foot := Rect2(p - Vector2(1.0, 1.0), Vector2(2.0, 2.0))
			if _hits_any(foot, avoid, 0.0) or _hits_any(foot, path_keep, 1.2):
				continue
			_park_tree(p)
			avoid.append(foot.grow(0.8))
	# Trees and bushes dotted over the lawns
	var placed := 0
	var tries := 0
	while placed < 16 and tries < 300:
		tries += 1
		var p := Vector2(rng.randf_range(r.position.x + 3.0, r.end.x - 3.0), rng.randf_range(r.position.y + 3.0, r.end.y - 3.0))
		var foot := Rect2(p - Vector2(1.5, 1.5), Vector2(3.0, 3.0))
		if _hits_any(foot, avoid, 0.0) or _hits_any(foot, path_keep, 0.5):
			continue
		avoid.append(foot.grow(1.0))
		placed += 1
		if placed % 3 == 0:
			_bush(Vector3(p.x, 0, p.y))
		else:
			_park_tree(p)
	# Bushes along the outside of the court fence
	for i in 5:
		var p := Vector2(court.position.x - 0.9, court.position.y + (i + 0.5) * court.size.y / 5.0)
		if r.grow(-0.5).has_point(p) and not _hits_any(Rect2(p - Vector2.ONE * 0.6, Vector2.ONE * 1.2), avoid.slice(3), 0.0):
			_bush(Vector3(p.x, 0, p.y))
	_detail = true


## A paved park path: props/park/path (1 m long along local Z) stretched to the
## path's length and turned to run along it.
func _park_path(pr: Rect2) -> void:
	var c := pr.get_center()
	var along_z := pr.size.y > pr.size.x
	var length := pr.size.y if along_z else pr.size.x
	_prefab("props/park/path", _at(Vector3(c.x, 0, c.y), 0.0 if along_z else PI * 0.5, Vector3(1, 1, length)))


## Park tree: a trunk stretched to a random height and a leafy crown.
func _park_tree(p: Vector2) -> void:
	var h := rng.randf_range(2.5, 3.6)
	_prefab("props/nature/tree_trunk", _at(Vector3(p.x, 0, p.y), 0.0, Vector3(1, h, 1)))
	_crown(Vector3(p.x, h + 1.0, p.y), rng.randf_range(1.6, 2.3), Color("4f8a3a").lerp(Color("7ab04a"), rng.randf()))


# ================================================================ cranes & rooftop bridges

func _building(id: int) -> Dictionary:
	for b in buildings:
		if b.id == id:
			return b
	return {}


## Tower cranes holding building materials (planks / sheet metal) that bridge
## the gap between two rooftops. Deck ends rest on top of each roof's parapet;
## a crate on each roof makes it easy to climb up.
func _build_cranes() -> void:
	_detail = false
	var avoid: Array = spawn_dots.duplicate()
	for o in objectives:
		avoid.append(o.pos)
	for br in bridges:
		var a := _building(br[0])
		var b := _building(br[1])
		if a.is_empty() or b.is_empty():
			continue
		var ra: Rect2 = a.rect
		var rb: Rect2 = b.rect
		var ya: float = a.top + 1.15
		var yb: float = b.top + 1.15
		var p0: Vector3
		var p1: Vector3
		var along_x := true
		if ra.end.x <= rb.position.x or rb.end.x <= ra.position.x:
			var west := ra if ra.end.x <= rb.position.x else rb
			var east := rb if west == ra else ra
			var yw := ya if west == ra else yb
			var ye := yb if west == ra else ya
			var z := (maxf(ra.position.y, rb.position.y) + minf(ra.end.y, rb.end.y)) * 0.5
			p0 = Vector3(west.end.x - 1.0, yw, z)
			p1 = Vector3(east.position.x + 1.0, ye, z)
		else:
			along_x = false
			var north := ra if ra.end.y <= rb.position.y else rb
			var south := rb if north == ra else ra
			var yn := ya if north == ra else yb
			var ys := yb if north == ra else ya
			var x := (maxf(ra.position.x, rb.position.x) + minf(ra.end.x, rb.end.x)) * 0.5
			p0 = Vector3(x, yn, north.end.y - 1.0)
			p1 = Vector3(x, ys, south.position.y + 1.0)
		_bridge_deck(p0, p1, along_x, br[2])
		# Crates on each roof to climb onto the parapet / deck.
		for end_p: Vector3 in [p0, p1]:
			var inward := (p0 - p1) if end_p == p0 else (p1 - p0)
			inward.y = 0.0
			inward = inward.normalized()
			var roof_y := end_p.y - 1.15
			_prefab("props/crane/roof_crate", _at(Vector3(end_p.x, roof_y, end_p.z) + inward * 1.6))
		# Crane beside the bridge, on the side away from spawns and objectives.
		var mid := (p0 + p1) * 0.5
		var perp := Vector3(0, 0, 1) if along_x else Vector3(1, 0, 0)
		var best_side := 1.0
		var best_score := -INF
		for side: float in [1.0, -1.0]:
			var base := Vector2(mid.x, mid.z) + Vector2(perp.x, perp.z) * side * 5.0
			var score := 0.0
			if _in_building(base, 1.5):
				score -= 1000.0
			for q in avoid:
				score += minf(Vector2(q.x, q.z).distance_to(base), 20.0)
			if score > best_score:
				best_score = score
				best_side = side
		_crane(mid, perp * best_side, p0, p1, br[2])
	_detail = true


func _bridge_deck(p0: Vector3, p1: Vector3, along_x: bool, material: String) -> void:
	var d := p1 - p0
	var length := d.length() + 0.4
	var center := (p0 + p1) * 0.5
	var rot: Basis
	if along_x:
		rot = Basis(Vector3(0, 0, 1), atan2(d.y, d.x))
	else:
		rot = Basis(Vector3(1, 0, 0), -atan2(d.y, d.z))
	var width := 1.9
	var size := Vector3(length, 0.14, width) if along_x else Vector3(width, 0.14, length)
	# Collision: one solid walkway.
	_add_shape(L_FLOOR, _box_shape(size), Transform3D(rot, center))
	if material == "planks":
		var boards := 5
		for i in boards:
			var off := (float(i) - (boards - 1) * 0.5) * (width / boards)
			var bsize := Vector3(length - rng.randf_range(0.0, 0.5), 0.12, width / boards - 0.05) if along_x else Vector3(width / boards - 0.05, 0.12, length - rng.randf_range(0.0, 0.5))
			var boff := Vector3(0, 0, off) if along_x else Vector3(off, 0, 0)
			_beam(center + boff, rot, bsize, LIGHTWOOD.lerp(WOOD, rng.randf()))
		# Cross battens underneath
		var n := int(length / 1.5)
		for i in n:
			var t := (float(i) + 0.5) / n - 0.5
			var bpos := center + d.normalized() * (t * length) + rot * Vector3(0, -0.1, 0)
			_beam(bpos, rot, Vector3(0.12, 0.08, width + 0.1) if along_x else Vector3(width + 0.1, 0.08, 0.12), DARKWOOD)
	else:
		_beam(center, rot, size, Color("9aa3a8"))
		var ribs := 6
		for i in ribs:
			var off := (float(i) - (ribs - 1) * 0.5) * (width / ribs)
			var rsize := Vector3(length, 0.05, 0.06) if along_x else Vector3(0.06, 0.05, length)
			var roff := Vector3(0, 0.09, off) if along_x else Vector3(off, 0.09, 0)
			_beam(center + rot * roff, rot, rsize, Color("7d868c"))


## A beam (props/crane/beam: a 1 m cube) stretched to size, turned by basis and
## coloured: deck boards, battens, plates, ribs and the struts below.
func _beam(c: Vector3, basis: Basis, size: Vector3, col: Color) -> void:
	_prefab("props/crane/beam", Transform3D(basis * Basis.from_scale(size), c), {"color": col})


## Thin beam between two points (cables, slings, jibs).
func _strut(a: Vector3, b: Vector3, thick: float, col: Color) -> void:
	var d := b - a
	var len_d := d.length()
	if len_d < 0.01:
		return
	var y := d / len_d
	var ref := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := y.cross(ref).normalized()
	var z := x.cross(y).normalized()
	_beam((a + b) * 0.5, Basis(x, y, z), Vector3(thick, len_d, thick), col)


func _crane(mid: Vector3, out: Vector3, p0: Vector3, p1: Vector3, material: String) -> void:
	var yellow := Color("e0b13c")
	var base := mid + out * 5.0
	base.y = 0.0
	var top_y := maxf(p0.y, p1.y) + 9.0
	_tallest = maxf(_tallest, top_y + 4.0)  # the crane top (cab and jib) stands ~4 m above top_y
	# Footing, mast (props/crane/mast is 10 m tall, stretched to this crane) and
	# one set of braces every 1.4 m.
	_prefab("props/crane/footing", _at(base))
	_prefab("props/crane/mast", _at(base + Vector3(0, 1.0, 0), 0.0, Vector3(1, (top_y - 1.0) / 10.0, 1)))
	var y := 2.0
	while y < top_y - 1.0:
		_prefab("props/crane/mast_braces", _at(base + Vector3(0, y, 0)))
		y += 1.4
	# Slewing unit, cab, jib towards the bridge (the scene's -X), counter-jib with weights
	_prefab("props/crane/top", _at(base + Vector3(0, top_y, 0), _yaw_x(out)))
	# Hook over the bridge with slings down to the deck
	var hook_top := Vector3(mid.x, top_y + 0.2, mid.z)
	var hook := Vector3(mid.x, maxf(p0.y, p1.y) + 3.5, mid.z)
	_prefab("props/crane/trolley", _at(Vector3(mid.x, top_y + 0.1, mid.z)))
	_strut(hook_top, hook, 0.06, DARKMETAL)
	_prefab("props/crane/hook", _at(hook))
	var dir := (p1 - p0).normalized()
	var span := p0.distance_to(p1)
	var a_pt := mid - dir * span * 0.3
	var b_pt := mid + dir * span * 0.3
	_strut(hook, a_pt + Vector3(0, 0.1, 0), 0.04, DARKMETAL)
	_strut(hook, b_pt + Vector3(0, 0.1, 0), 0.04, DARKMETAL)
	# A spare load hanging off the other side for flavour
	var spare := base - out * 8.5 + Vector3(0, top_y - 4.0, 0)
	_strut(Vector3(spare.x, top_y + 0.2, spare.z), spare + Vector3(0, 0.4, 0), 0.05, DARKMETAL)
	_prefab("props/crane/load_planks" if material == "planks" else "props/crane/load_metal", _at(spare))


# ================================================================ spawn points

func _build_spawn_points() -> void:
	var x := bounds.position.x + 4.0
	while x <= bounds.end.x - 4.0:
		var z := bounds.position.y + 4.0
		while z <= bounds.end.y - 4.0:
			var p := Vector2(x, z)
			if not _in_building(p, 1.2):
				spawn_points.append(Vector3(x, 0.1, z))
			z += 6.0
		x += 6.0
