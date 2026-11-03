class_name MapBuilder
extends RefCounted
## Builds the whole city procedurally (deterministic, so every peer builds the same map).
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
const MASK_WORLD := L_FLOOR | L_WALL | L_DOOR | L_SOLID

const WALL_T := 0.3
const SLAB_T := 0.3
const DOOR_W := 1.7
const DOOR_H := 2.45
const FURNITURE_VIS_RANGE := 75.0

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

var root: Node3D
var rng := RandomNumberGenerator.new()

# Output data used by the game
var spawn_dots: Array = []       # Vector3
var objectives: Array = []       # {pos: Vector3, name: String}
var spawn_points: Array = []     # Vector3 candidate respawn points
var doors: Array = []            # Door
var buildings: Array = []        # {id, name, rect: Rect2, floors, fh, top, color}
var road_rects: Array = []       # Rect2 (clipped to the map bounds)
var park_rect := Rect2()
var has_park := true
var map_size := MapData.DEFAULT_SIZE
var bounds := Rect2()            # playable area (inside the fence), metres
var min_spawn_dist := 70.0       # minimum distance between the two teams' spawn zones
var _active: Array = []          # MapData.BUILDINGS entries built for this size

# Chunk accumulators
var _chunk: Node3D
var _boxes: Array = []
var _fboxes: Array = []
var _cyls: Array = []
var _fcyls: Array = []
var _spheres: Array = []
var _floor_body: StaticBody3D
var _wall_body: StaticBody3D
var _solid_body: StaticBody3D
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
# Furniture-style props use the "detail" MultiMesh (with a visibility range) inside
# buildings; outdoor clutter must stay visible from anywhere, so it turns this off.
var _detail := true


func build(parent: Node3D, size := MapData.DEFAULT_SIZE) -> void:
	root = parent
	rng.seed = 424242
	map_size = size if MapData.valid_size(size) else MapData.DEFAULT_SIZE
	bounds = MapData.size_bounds(map_size)
	min_spawn_dist = MapData.SIZES[map_size].min_spawn_dist
	# Only buildings that fit entirely inside the fence are built.
	var excluded: Array = []
	for b in MapData.BUILDINGS:
		var br := MapData.px_rect(b[3])
		if bounds.encloses(br):
			_active.append(b)
		else:
			excluded.append(br)
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
	for d in MapData.SPAWN_DOTS:
		var p := MapData.px(d[0], d[1])
		if _usable_point(p, excluded):
			spawn_dots.append(Vector3(p.x, 0.0, p.y))
	for o in MapData.OBJECTIVES:
		var p := MapData.px(o[0], o[1])
		if _usable_point(p, excluded):
			objectives.append({"pos": Vector3(p.x, 0.0, p.y), "name": o[2]})
	for r in MapData.ROADS:
		var clipped := MapData.px_rect(r).intersection(bounds)
		if clipped.size.x > 1.0 and clipped.size.y > 1.0:
			road_rects.append(clipped)
	park_rect = MapData.px_rect(MapData.PARK_RECT)
	has_park = bounds.encloses(park_rect)

	_begin_chunk("Streets")
	_build_ground()
	_build_street_props()
	_end_chunk()

	for b in _active:
		_begin_chunk(b[1])
		_build_building(b)
		_end_chunk()

	if has_park:
		_begin_chunk("Park")
		_build_park()
		_end_chunk()

	_begin_chunk("Cranes")
	_build_cranes()
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
	_boxes = []
	_fboxes = []
	_cyls = []
	_fcyls = []
	_spheres = []


func _end_chunk() -> void:
	_make_mm(_box_mesh, _boxes, 0.0)
	_make_mm(_cyl_mesh, _cyls, 0.0)
	_make_mm(_box_mesh, _fboxes, FURNITURE_VIS_RANGE)
	_make_mm(_cyl_mesh, _fcyls, FURNITURE_VIS_RANGE)
	_make_mm(_sph_mesh, _spheres, 0.0)


func _make_mm(mesh: Mesh, items: Array, vis_range: float) -> void:
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
	mmi.material_override = Mats.vertex_toon()
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


## Axis-aligned (or rotated) box. layer 0 = visual only.
func box(c: Vector3, s: Vector3, col: Color, layer := L_WALL, detail := false, rot := Basis.IDENTITY) -> void:
	var vis := Transform3D(rot * Basis.from_scale(s), c)
	if detail:
		_fboxes.append([vis, col])
	else:
		_boxes.append([vis, col])
	if layer != 0:
		_add_shape(layer, _box_shape(s), Transform3D(rot, c))


func cyl(c: Vector3, r: float, h: float, col: Color, layer := L_WALL, detail := false) -> void:
	var vis := Transform3D(Basis.from_scale(Vector3(r * 2.0, h, r * 2.0)), c)
	if detail:
		_fcyls.append([vis, col])
	else:
		_cyls.append([vis, col])
	if layer != 0:
		_add_shape(layer, _cyl_shape(r, h), Transform3D(Basis.IDENTITY, c))


func sphere(c: Vector3, r: float, col: Color) -> void:
	_spheres.append([Transform3D(Basis.from_scale(Vector3(r, r * 0.85, r) * 2.0), c), col])


func _label(text: String, pos: Vector3, yaw: float, size := 96, col := Color.WHITE) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.012
	l.outline_size = 18
	l.modulate = col
	l.outline_modulate = Color(0.1, 0.1, 0.12)
	l.position = pos
	l.rotation.y = yaw
	l.double_sided = false
	l.visibility_range_end = 140.0
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
	box(Vector3(0, -0.53, 0), Vector3(700, 1.0, 700), Color("7f9a5a"), 0)
	# Roads with dashed centre lines
	for r: Rect2 in road_rects:
		box(Vector3(r.get_center().x, 0.012, r.get_center().y), Vector3(r.size.x, 0.024, r.size.y), ASPHALT, 0)
		var horizontal := r.size.x > r.size.y
		var length := r.size.x if horizontal else r.size.y
		var n := int(length / 6.0)
		for i in n:
			var t := (i + 0.5) * length / n
			if horizontal:
				box(Vector3(r.position.x + t, 0.03, r.get_center().y), Vector3(2.2, 0.02, 0.18), Color("e8c84a"), 0)
			else:
				box(Vector3(r.get_center().x, 0.03, r.position.y + t), Vector3(0.18, 0.02, 2.2), Color("e8c84a"), 0)
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
			box(pc, Vector3(0.15, 3.5, 0.15), post_col, 0)
		var center := Vector3(mid, 1.6, fixed) if horizontal else Vector3(fixed, 1.6, mid)
		var size := Vector3(length, 3.0, 0.06) if horizontal else Vector3(0.06, 3.0, length)
		box(center, size, fence_col, 0)
		var top := Vector3(mid, 3.45, fixed) if horizontal else Vector3(fixed, 3.45, mid)
		var top_size := Vector3(length, 0.1, 0.12) if horizontal else Vector3(0.12, 0.1, length)
		box(top, top_size, post_col, 0)
		var wall_c := Vector3(mid, 40, fixed + outward * 0.6) if horizontal else Vector3(fixed + outward * 0.6, 40, mid)
		var wall_s := Vector3(length + 4.0, 80, 1.0) if horizontal else Vector3(1.0, 80, length + 4.0)
		_add_shape(L_SOLID, _box_shape(wall_s), Transform3D(Basis.IDENTITY, wall_c))


func _near_any(p: Vector2, pts: Array, d: float) -> bool:
	for q in pts:
		var q2 := Vector2(q.x, q.z)
		if p.distance_to(q2) < d:
			return true
	return false


func _build_street_props() -> void:
	var car_cols := [Color("c0453a"), Color("4f7fae"), Color("e0b13c"), Color("ece6da"), Color("3a3d42"), Color("5a8a4a")]
	for r: Rect2 in road_rects:
		var horizontal := r.size.x > r.size.y
		var length := r.size.x if horizontal else r.size.y
		var t := 10.0
		while t < length - 8.0:
			t += rng.randf_range(7.0, 15.0)
			if t > length - 6.0:
				break
			var lane := rng.randf_range(-1.0, 1.0)
			var off := (r.size.y if horizontal else r.size.x) * 0.22 * (1.0 if lane > 0.0 else -1.0)
			var c2 := Vector2(r.position.x + t, r.get_center().y + off) if horizontal else Vector2(r.get_center().x + off, r.position.y + t)
			if _near_any(c2, spawn_dots, 7.0) or _near_any(c2, objectives.map(func(o): return o.pos), 7.0):
				continue
			if _in_building(c2, 1.5):
				continue
			if rng.randf() < 0.25:
				_van(Vector3(c2.x, 0, c2.y), horizontal, car_cols[rng.randi() % car_cols.size()])
			else:
				_car(Vector3(c2.x, 0, c2.y), horizontal, car_cols[rng.randi() % car_cols.size()])
	# Street lights along the main roads
	for r: Rect2 in road_rects:
		var horizontal := r.size.x > r.size.y
		var length := r.size.x if horizontal else r.size.y
		var t := 8.0
		while t < length:
			var far_side := int(t / 12.0) % 2 == 1
			var c2: Vector2
			if horizontal:
				c2 = Vector2(r.position.x + t, (r.end.y + 0.6) if far_side else (r.position.y - 0.6))
			else:
				c2 = Vector2((r.end.x + 0.6) if far_side else (r.position.x - 0.6), r.position.y + t)
			if not _in_building(c2, 0.5) and bounds.grow(-1.0).has_point(c2):
				cyl(Vector3(c2.x, 2.75, c2.y), 0.14, 5.5, DARKMETAL, L_WALL)
				box(Vector3(c2.x, 5.5, c2.y), Vector3(0.6, 0.18, 0.6), Color("fff2b0"), 0)
			t += 12.0
	# Dumpsters in alleys near the tenements and warehouse
	for p in [[1480, 1560], [1820, 1580], [480, 120], [1300, 900], [420, 860], [1030, 1380]]:
		var c := MapData.px(p[0], p[1])
		if not _in_building(c, 0.8) and bounds.grow(-2.0).has_point(c):
			box(Vector3(c.x, 0.7, c.y), Vector3(2.0, 1.4, 1.2), Color("3f6a4a"), L_WALL)
	_scatter_clutter()


## Sidewalk / open-ground clutter to break up long sight lines.
## Keeps clear of building entrances, spawn zones and objectives.
func _scatter_clutter() -> void:
	_detail = false
	var placed: Array = []
	var avoid_pts: Array = spawn_dots.duplicate()
	for o in objectives:
		avoid_pts.append(o.pos)
	var tries := 0
	# 420 props on the full 200 x 170 m map; scaled by area for smaller sizes.
	var target := maxi(80, int(420.0 * bounds.get_area() / (200.0 * 170.0)))
	while placed.size() < target and tries < 6000:
		tries += 1
		var p := Vector2(rng.randf_range(bounds.position.x + 2.0, bounds.end.x - 2.0), rng.randf_range(bounds.position.y + 2.0, bounds.end.y - 2.0))
		if _in_building(p, 2.6) or (has_park and park_rect.grow(0.5).has_point(p)):
			continue
		if _near_any(p, avoid_pts, 6.0):
			continue
		var too_close := false
		for q: Vector2 in placed:
			if q.distance_to(p) < 4.0:
				too_close = true
				break
		if too_close:
			continue
		var on_road := false
		for r: Rect2 in road_rects:
			if r.grow(0.3).has_point(p):
				on_road = true
				break
		var c := Vector3(p.x, 0.0, p.y)
		var rot := rng.randf() < 0.5
		var roll := rng.randf()
		if on_road:
			# Only roadworks / crashes on the road itself.
			if roll < 0.12:
				_p(c, rot, 0, 0.45, 0, 2.2, 0.9, 0.6, Color("c9c4b6"))
			elif roll < 0.18:
				for i in 3:
					cyl(c + Vector3(i * 0.7 - 0.7, 0.35, 0), 0.18, 0.7, Color("e06a2a"), 0, false)
			else:
				continue
		elif roll < 0.18:
			_bush(c)
		elif roll < 0.30:
			cyl(c + Vector3(0, 0.5, 0), 0.35, 1.0, Color("3a5a3a"), L_WALL, false)
			cyl(c + Vector3(0, 1.02, 0), 0.38, 0.06, DARKMETAL, 0, false)
		elif roll < 0.42:
			_p(c, rot, 0, 0.85, 0, 3.2, 1.7, 0.9, Color("4f7a3a"))
		elif roll < 0.52:
			_p(c, rot, 0, 0.4, 0, 1.4, 0.8, 1.4, Color("8a8478"))
			sphere(c + Vector3(0, 1.6, 0), 1.1, Color("5a9a45"))
			cyl(c + Vector3(0, 1.0, 0), 0.1, 0.8, Color("6b4a32"), 0, false)
		elif roll < 0.62:
			_p(c, rot, 0, 0.37, 0, 1.6, 0.74, 0.8, Color("6a7a8a"))
			_p(c, rot, 0, 0.23, 0.8, 0.45, 0.46, 0.45, DARKMETAL, 0)
			_p(c, rot, 0, 0.23, -0.8, 0.45, 0.46, 0.45, DARKMETAL, 0)
		elif roll < 0.70:
			_p(c, rot, 0, 0.55, 0, 0.5, 1.1, 0.45, [Color("3f6fa8"), Color("c0453a"), Color("e0b13c")][rng.randi() % 3])
		elif roll < 0.80:
			_crates(c)
		elif roll < 0.86:
			_p(c, rot, 0, 0.45, 0, 2.2, 0.9, 0.6, Color("c9c4b6"))
		elif roll < 0.93:
			_p(c, rot, 0, 1.25, -0.6, 3.2, 2.5, 0.06, Color("bfe3ef"))
			_p(c, rot, 0, 2.55, 0, 3.4, 0.1, 1.5, DARKMETAL, 0)
			_p(c, rot, 0, 0.25, -0.3, 2.6, 0.5, 0.45, WOOD)
		else:
			_p(c, rot, 0, 0.45, 0, 1.6, 0.9, 1.0, WOOD)
			_p(c, rot, 0, 2.3, 0, 2.4, 0.08, 2.4, [Color("c0453a"), Color("e0b13c"), Color("4f7fae")][rng.randi() % 3], 0)
			cyl(c + Vector3(0, 1.35, 0), 0.05, 1.9, METAL, 0, false)
		placed.append(p)
	_detail = true


## Leafy bush: blocks sight but not bullets.
func _bush(c: Vector3) -> void:
	var r := rng.randf_range(0.9, 1.3)
	sphere(c + Vector3(0, r * 0.75, 0), r, Color("4f8a3a").lerp(Color("6aa84f"), rng.randf()))
	sphere(c + Vector3(r * 0.6, r * 0.6, r * 0.3), r * 0.7, Color("5a9a45"))


func _van(c: Vector3, along_x: bool, col: Color) -> void:
	var L := 5.4
	var W := 2.1
	var size := Vector3(L, 2.3, W) if along_x else Vector3(W, 2.3, L)
	box(c + Vector3(0, 1.45, 0), size, col.lightened(0.15), L_WALL)
	var off := Vector3(L * 0.38, 1.6, 0) if along_x else Vector3(0, 1.6, L * 0.38)
	var win := Vector3(0.6, 0.5, W * 1.01) if along_x else Vector3(W * 1.01, 0.5, 0.6)
	box(c + off, win, Color("9ec4d6"), 0)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var w_off := Vector3(sx * L * 0.32, 0.35, sz * W * 0.5) if along_x else Vector3(sz * W * 0.5, 0.35, sx * L * 0.32)
			box(c + w_off, Vector3(0.7, 0.7, 0.25) if along_x else Vector3(0.25, 0.7, 0.7), BLACK, 0)


func _car(c: Vector3, along_x: bool, col: Color) -> void:
	var L := 4.3
	var W := 1.9
	var size := Vector3(L, 0.9, W) if along_x else Vector3(W, 0.9, L)
	box(c + Vector3(0, 0.75, 0), size, col, L_WALL)
	var cab := Vector3(L * 0.5, 0.65, W * 0.92) if along_x else Vector3(W * 0.92, 0.65, L * 0.5)
	box(c + Vector3(0, 1.5, 0), cab, Color("9ec4d6"), L_WALL)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var off := Vector3(sx * L * 0.32, 0.35, sz * W * 0.5) if along_x else Vector3(sz * W * 0.5, 0.35, sx * L * 0.32)
			box(c + off, Vector3(0.7, 0.7, 0.25) if along_x else Vector3(0.25, 0.7, 0.7), BLACK, 0)


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


func _slab(r: Rect2, y_top: float, col: Color, layer: int) -> void:
	box(Vector3(r.get_center().x, y_top - SLAB_T * 0.5, r.get_center().y), Vector3(r.size.x, SLAB_T, r.size.y), col, layer)


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
	var run := fh * 1.6
	var S := run + 2.4
	# Stairwells: one at the start of the long axis, and a second one at the far
	# end whenever the building is long enough.
	var flips := [false]
	if umax >= S * 2.0 + 6.0:
		flips.append(true)
	var stairs: Array = []
	var holes: Array = []
	for fl: bool in flips:
		_flip = fl
		stairs.append(_uv_rect(0, 0, S, 5.0))
		holes.append(_uv_rect(1.2, 0, 1.2 + run, 5.0))
	_flip = false

	# --- Objective inside this building?
	var obj_here: Array = []
	for o in objectives:
		if r.has_point(Vector2(o.pos.x, o.pos.z)):
			obj_here.append(o.pos)

	# --- Interior room layout (corridor + rooms) for residential/school buildings
	var room_floors := []
	if type in ["motel", "school"]:
		room_floors = range(floors)
	elif type in ["apartments", "rundown", "rundown2"]:
		room_floors = range(1, floors)
	var can_rooms := vmax - 6.5 >= 4.5
	var nrooms := maxi(1, int(umax / 6.0))
	var rw := umax / nrooms
	var rooms_on_ground := can_rooms and 0 in room_floors

	# --- Exterior doors (ground floor)
	var door_spots := []  # [side, t]
	for side in 4:
		var horizontal := side < 2
		var a0 := x0 if horizontal else z0 + WALL_T
		var a1 := x1 if horizontal else z1 - WALL_T
		var length := a1 - a0
		if length < 5.0:
			continue
		for frac: float in [0.5, 0.3, 0.7, 0.2, 0.8]:
			var t: float = a0 + length * frac
			var clear := _door_clear_rect(side, t, x0, z0, x1, z1)
			if rooms_on_ground and _door_hits_rooms(side, t, x0, z0, x1, z1, nrooms, rw, umax):
				continue
			if not _hits_any(clear, stairs, 0.4):
				door_spots.append([side, t])
				break

	# --- Floors / roof
	box(Vector3(inner.get_center().x, 0.015, inner.get_center().y), Vector3(inner.size.x, 0.03, inner.size.y), st.floor, 0)
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
			_slab(piece, y, st.roof if is_roof else st.floor, L_FLOOR)

	# --- Stair ramps, lane divider and hole railing (for every stairwell)
	for fl: bool in flips:
		_flip = fl
		_build_stairwell(floors, fh, run, top, st)
	_flip = false

	# --- Exterior walls
	_build_exterior_walls(type, floors, fh, x0, z0, x1, z1, door_spots, st)

	# --- Signs
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
		room_forbid.append(_uv_rect(0, 4.5, umax, 6.5))
		# partition line (v = 6.5) and cross walls
		room_forbid.append(_uv_rect(0, 6.0, umax, 7.0))
		for i in range(1, nrooms):
			room_forbid.append(_uv_rect(i * rw - 0.5, 6.5, i * rw + 0.5, vmax))
		for i in nrooms:
			var dc := (i + 0.5) * rw
			room_forbid.append(_uv_rect(dc - 1.3, 4.8, dc + 1.3, 8.2))
		for k in room_floors:
			var y0: float = k * fh
			var h := fh - SLAB_T
			var openings := []
			for i in nrooms:
				openings.append([(i + 0.5) * rw, DOOR_W - 0.1, 0.0, DOOR_H])
			# Partition along u at v = 6.5
			if _ax:
				_wall_side(true, _o.y + 6.5, _o.x, _o.x + umax, y0, h, _shift(openings, _o.x), st.trim.lerp(WHITE, 0.6), 0.15)
			else:
				_wall_side(false, _o.x + 6.5, _o.y, _o.y + umax, y0, h, _shift(openings, _o.y), st.trim.lerp(WHITE, 0.6), 0.15)
			for i in range(1, nrooms):
				var cu := i * rw
				if _ax:
					_wall_side(false, _o.x + cu, _o.y + 6.5, _o.y + vmax, y0, h, [], st.wall.lerp(WHITE, 0.5), 0.15)
				else:
					_wall_side(true, _o.y + cu, _o.x + 6.5, _o.x + vmax, y0, h, [], st.wall.lerp(WHITE, 0.5), 0.15)
			for i in nrooms:
				var dc: float = (i + 0.5) * rw
				var along: float = (_o.x if _ax else _o.y) + dc
				_make_door(_ax, (_o.y if _ax else _o.x) + 6.5, along, y0, st.door, DOOR_W - 0.2)

	# --- Furnish every storey (and specials)
	for k in floors:
		var y := k * fh
		var zones: Array = _forbid.duplicate()
		if k == 0:
			zones.append_array(obj_forbid)
		if k in room_floors and can_rooms:
			zones.append_array(room_forbid)
		if type == "sports":
			_furnish_sports(inner, zones)
			continue
		if type == "water":
			_furnish_water(inner, zones)
			continue
		_furnish_floor(type, k, inner, y, fh, zones)

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


func _build_stairwell(floors: int, fh: float, run: float, top: float, st: Dictionary) -> void:
	var theta := atan2(fh, run)
	var ramp_len := sqrt(run * run + fh * fh) + 0.2
	var flip_sgn := -1.0 if _flip else 1.0
	for k in floors:
		var h0 := k * fh
		var lane_a := k % 2 == 0
		var vc := 1.25 if lane_a else 3.75
		var sgn := 1.0 if lane_a else -1.0
		var um := 1.2 + run * 0.5
		var hm := h0 + fh * 0.5
		var cu := um + sgn * sin(theta) * SLAB_T * 0.5
		var cy := hm - cos(theta) * SLAB_T * 0.5
		var p := _uv(cu, vc)
		var rot: Basis
		var size: Vector3
		if _ax:
			rot = Basis(Vector3(0, 0, 1), sgn * flip_sgn * theta)
			size = Vector3(ramp_len, SLAB_T, 2.45)
		else:
			rot = Basis(Vector3(1, 0, 0), -sgn * flip_sgn * theta)
			size = Vector3(2.45, SLAB_T, ramp_len)
		box(Vector3(p.x, cy, p.y), size, st.trim.lerp(st.floor, 0.5), L_FLOOR, false, rot)
		# Divider between the two lanes for this storey
		var dv := _uv_rect(1.2, 2.45, 1.2 + run, 2.55)
		box(Vector3(dv.get_center().x, h0 + fh * 0.5, dv.get_center().y), Vector3(maxf(dv.size.x, 0.1), fh - SLAB_T, maxf(dv.size.y, 0.1)), st.trim, L_WALL)
		# Railing on the open edge of the hole (upper floors)
		if k >= 1:
			var rail := _uv_rect(1.2, 5.0, 1.2 + run, 5.12)
			box(Vector3(rail.get_center().x, h0 + 0.55, rail.get_center().y), Vector3(maxf(rail.size.x, 0.12), 1.1, maxf(rail.size.y, 0.12)), st.trim, L_WALL)
	# Roof railing around the stair hole
	var roof_rail := _uv_rect(1.2, 5.0, 1.2 + run, 5.12)
	box(Vector3(roof_rail.get_center().x, top + 0.55, roof_rail.get_center().y), Vector3(maxf(roof_rail.size.x, 0.12), 1.1, maxf(roof_rail.size.y, 0.12)), st.trim, L_WALL)


## Exterior walls with doors and irregular windows (about half as many as a
## regular grid, with varied position and size) so there is plenty of solid
## wall to run along.
func _build_exterior_walls(type: String, floors: int, fh: float, x0: float, z0: float, x1: float, z1: float, door_spots: Array, st: Dictionary) -> void:
	var top := floors * fh
	var win_every := 7.2
	if type in ["warehouse", "water", "sports"]:
		win_every = 12.0
	for k in floors:
		var y0 := k * fh
		for side in 4:
			var horizontal := side < 2
			var fixed: float
			if side == 0:
				fixed = z0 + WALL_T * 0.5
			elif side == 1:
				fixed = z1 - WALL_T * 0.5
			elif side == 2:
				fixed = x0 + WALL_T * 0.5
			else:
				fixed = x1 - WALL_T * 0.5
			var a0 := x0 if horizontal else z0 + WALL_T
			var a1 := x1 if horizontal else z1 - WALL_T
			var openings := []
			var side_doors := []
			if k == 0:
				for ds in door_spots:
					if ds[0] == side:
						side_doors.append(ds[1])
						openings.append([ds[1], DOOR_W, 0.0, DOOR_H])
			# Windows
			var win_bottom := 0.8
			var win_top := fh - 0.55
			if fh >= 6.0:
				win_bottom = fh - 4.4
				win_top = fh - 0.7
			var length := a1 - a0
			var n := maxi(1, int(length / win_every))
			var slot := length / n
			for i in n:
				if rng.randf() < 0.2:
					continue
				var w := rng.randf_range(1.2, 2.2)
				var t := a0 + (i + 0.5) * slot + rng.randf_range(-0.3, 0.3) * maxf(0.0, slot - w)
				var bottom := win_bottom + rng.randf_range(-0.2, 0.5)
				var top_w := maxf(bottom + 1.2, win_top - rng.randf_range(0.0, 0.6))
				var ok := t - w * 0.5 - a0 > 0.8 and a1 - t - w * 0.5 > 0.8
				for dt in side_doors:
					if absf(t - dt) < w * 0.5 + 1.4:
						ok = false
				if ok:
					openings.append([t, w, bottom, top_w])
			_wall_side(horizontal, fixed, a0, a1, y0, fh, openings, st.wall)
			# Trim band at each storey
			var band_c := Vector3((a0 + a1) * 0.5, y0 + fh - 0.12, fixed) if horizontal else Vector3(fixed, y0 + fh - 0.12, (a0 + a1) * 0.5)
			var band_out := -0.04 if (side == 0 or side == 2) else 0.04
			if horizontal:
				band_c.z += band_out
				box(band_c, Vector3(length, 0.28, WALL_T + 0.04), st.trim, 0)
			else:
				band_c.x += band_out
				box(band_c, Vector3(WALL_T + 0.04, 0.28, length), st.trim, 0)
			if k == 0:
				for dt in side_doors:
					_make_door(horizontal, fixed, dt, 0.0, st.door)
	# Roof parapet
	for side in 4:
		var horizontal := side < 2
		var fixed: float = [z0 + WALL_T * 0.5, z1 - WALL_T * 0.5, x0 + WALL_T * 0.5, x1 - WALL_T * 0.5][side]
		var a0 := x0 if horizontal else z0 + WALL_T
		var a1 := x1 if horizontal else z1 - WALL_T
		_wall_side(horizontal, fixed, a0, a1, top, 1.1, [], st.trim)


## True if an exterior door at (side, t) would be blocked by interior room walls.
func _door_hits_rooms(side: int, t: float, x0: float, z0: float, x1: float, z1: float, nrooms: int, rw: float, umax: float) -> bool:
	var p: Vector2
	if side < 2:
		p = Vector2(t, z0 if side == 0 else z1)
	else:
		p = Vector2(x0 if side == 2 else x1, t)
	var u := (p.x - _o.x) if _ax else (p.y - _o.y)
	var v := (p.y - _o.y) if _ax else (p.x - _o.x)
	if v > 6.5:
		for i in range(1, nrooms):
			if absf(u - i * rw) < 1.4:
				return true
	if absf(v - 6.5) < 1.4 and (u < 0.5 or u > umax - 0.5):
		return true
	return false


func _shift(openings: Array, off: float) -> Array:
	var out := []
	for o in openings:
		out.append([o[0] + off, o[1], o[2], o[3]])
	return out


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


## One wall line with rectangular openings: [centre, width, bottom, top] (relative to y0).
func _wall_side(horizontal: bool, fixed: float, a: float, bb: float, y0: float, h: float, openings: Array, col: Color, thick := WALL_T) -> void:
	openings.sort_custom(func(p, q): return p[0] < q[0])
	var cur := a
	for o in openings:
		var oa: float = maxf(o[0] - o[1] * 0.5, cur)
		var ob: float = minf(o[0] + o[1] * 0.5, bb)
		if ob <= oa:
			continue
		if oa > cur + 0.01:
			_wall_piece(horizontal, fixed, cur, oa, y0, y0 + h, col, thick)
		if o[2] > 0.01:
			_wall_piece(horizontal, fixed, oa, ob, y0, y0 + o[2], col, thick)
		if o[3] < h - 0.01:
			_wall_piece(horizontal, fixed, oa, ob, y0 + o[3], y0 + h, col, thick)
		cur = ob
	if bb > cur + 0.01:
		_wall_piece(horizontal, fixed, cur, bb, y0, y0 + h, col, thick)


func _wall_piece(horizontal: bool, fixed: float, a: float, bb: float, ya: float, yb: float, col: Color, thick: float) -> void:
	var length := bb - a
	var hgt := yb - ya
	if length < 0.02 or hgt < 0.02:
		return
	if horizontal:
		box(Vector3((a + bb) * 0.5, (ya + yb) * 0.5, fixed), Vector3(length, hgt, thick), col, L_WALL)
	else:
		box(Vector3(fixed, (ya + yb) * 0.5, (a + bb) * 0.5), Vector3(thick, hgt, length), col, L_WALL)


func _make_door(horizontal: bool, fixed: float, t: float, y0: float, col: Color, w := DOOR_W - 0.1) -> void:
	var d := Door.new()
	var hinge: Vector3
	var yaw: float
	if horizontal:
		hinge = Vector3(t - w * 0.5, y0, fixed)
		yaw = 0.0
	else:
		hinge = Vector3(fixed, y0, t - w * 0.5)
		yaw = -PI * 0.5
	d.setup(doors.size(), hinge, yaw, w, DOOR_H - 0.05, col)
	_chunk.add_child(d)
	doors.append(d)


# ================================================================ furniture

func _blocked(r: Rect2, zones: Array) -> bool:
	for z: Rect2 in zones:
		if z.intersects(r):
			return true
	return false


## Place a prefab part relative to a cell centre. rot = 90 degree rotation.
func _p(c: Vector3, rot: bool, lx: float, ly: float, lz: float, sx: float, sy: float, sz: float, col: Color, layer := L_WALL) -> void:
	var off := Vector3(lx, ly, lz)
	var s := Vector3(sx, sy, sz)
	if rot:
		off = Vector3(-lz, ly, lx)
		s = Vector3(sz, sy, sx)
	box(c + off, s, col, layer, _detail)


## Collision-only prefab part (visuals are built from smaller pieces).
func _pshape(c: Vector3, rot: bool, lx: float, ly: float, lz: float, sx: float, sy: float, sz: float) -> void:
	var off := Vector3(-lz, ly, lx) if rot else Vector3(lx, ly, lz)
	var s := Vector3(sz, sy, sx) if rot else Vector3(sx, sy, sz)
	_add_shape(L_WALL, _box_shape(s), Transform3D(Basis.IDENTITY, c + off))


func _pc(c: Vector3, rot: bool, lx: float, ly: float, lz: float, r: float, h: float, col: Color, layer := L_WALL) -> void:
	var off := Vector3(-lz, ly, lx) if rot else Vector3(lx, ly, lz)
	cyl(c + off, r, h, col, layer, _detail)


const CELL := {
	"warehouse": 4.2, "school": 3.6, "theater": 3.2, "bank": 3.8, "diner": 3.4, "arcade": 3.0,
	"club": 3.6, "bar": 3.2, "apartments": 3.8, "mall": 4.0, "motel": 3.6, "rundown": 3.4,
	"rundown2": 3.4, "office": 4.0, "casino": 3.6, "library": 3.6,
}


func _furnish_floor(type: String, k: int, inner: Rect2, y: float, fh: float, zones: Array) -> void:
	var cs: float = CELL.get(type, 3.6)
	var nx := int((inner.size.x - 1.0) / cs)
	var nz := int((inner.size.y - 1.0) / cs)
	if nx < 1 or nz < 1:
		return
	var ox := inner.position.x + (inner.size.x - nx * cs) * 0.5
	var oz := inner.position.y + (inner.size.y - nz * cs) * 0.5
	var vault_done := false
	for i in nx:
		for j in nz:
			var cx := ox + (i + 0.5) * cs
			var cz := oz + (j + 0.5) * cs
			var cell := Rect2(cx - cs * 0.5 + 0.2, cz - cs * 0.5 + 0.2, cs - 0.4, cs - 0.4)
			if _blocked(cell, zones):
				continue
			# Keep walkable aisles: skip every third column in most buildings.
			if i % 4 == 3 and type not in ["theater"]:
				continue
			if rng.randf() > 0.92:
				continue
			var c := Vector3(cx, y, cz)
			var rot := rng.randf() < 0.5
			if type == "bank" and k == 0 and not vault_done and i == nx - 1 and j == nz - 1:
				_vault(c)
				vault_done = true
				continue
			_furnish_cell(type, k, c, rot, fh)


func _furnish_cell(type: String, k: int, c: Vector3, rot: bool, fh: float) -> void:
	var roll := rng.randf()
	match type:
		"warehouse":
			if k > 0:
				if roll < 0.5:
					_desk_chair(c, rot)
				else:
					_crates(c)
			elif roll < 0.55:
				_rack(c, rot)
			elif roll < 0.85:
				_crates(c)
			else:
				_forklift(c, rot)
		"school":
			if roll < 0.7:
				for dx: float in [-0.8, 0.8]:
					for dz: float in [-0.8, 0.8]:
						_school_desk(c + Vector3(dx, 0, dz), rot)
			elif roll < 0.85:
				_p(c, rot, 0, 1.0, 0, 3.0, 2.0, 0.5, [BLUE, RED, Color("4a8a5a")][rng.randi() % 3])
			else:
				_desk_chair(c, rot)
				_p(c, rot, 0, 1.6, 1.2, 2.6, 1.2, 0.08, Color("2f4a3a"))
		"theater":
			if k == 0 or roll < 0.75:
				_p(c, rot, 0, 0.45, 0, 2.8, 0.5, 0.6, Color("9a2a35"))
				_p(c, rot, 0, 0.8, 0.28, 2.8, 0.7, 0.12, Color("7a1f2a"))
			else:
				_p(c, rot, 0, 0.55, 0, 2.6, 1.1, 0.8, LIGHTWOOD)
				_p(c, rot, 0, 1.3, 0, 0.6, 0.4, 0.5, Color("e8d26a"), 0)
		"bank":
			if k == 0 and roll < 0.45:
				_p(c, rot, 0, 0.55, 0, 3.2, 1.1, 0.8, DARKWOOD)
				_p(c, rot, 0, 1.45, 0, 3.2, 0.7, 0.05, Color("bfe3ef"), 0)
			elif roll < 0.85:
				_desk_chair(c, rot)
			else:
				_plant(c)
		"diner":
			if roll < 0.6:
				_p(c, rot, 0, 0.75, 0, 1.0, 0.06, 1.4, WHITE)
				_p(c, rot, 0, 0.37, 0, 0.2, 0.74, 0.2, METAL)
				for s: float in [-1.0, 1.0]:
					_p(c, rot, s * 0.9, 0.25, 0, 0.6, 0.5, 1.4, Color("c0453a"))
					_p(c, rot, s * 1.15, 0.8, 0, 0.15, 0.7, 1.4, Color("c0453a"))
			else:
				_p(c, rot, 0, 0.55, 0, 2.8, 1.1, 0.7, Color("d64545"))
				for s: float in [-1.0, 0.0, 1.0]:
					_pc(c, rot, s * 0.9, 0.35, 0.8, 0.22, 0.7, METAL)
		"arcade":
			if roll < 0.6:
				for s: float in [-0.8, 0.8]:
					_p(c, rot, s, 0.95, 0, 0.75, 1.9, 0.75, [Color("5a3d8a"), Color("2f6fa8"), Color("c0453a")][rng.randi() % 3])
					_p(c, rot, s, 1.35, -0.39, 0.55, 0.45, 0.04, SCREEN, 0)
			elif roll < 0.8:
				_p(c, rot, 0, 0.45, 0, 1.2, 0.9, 2.2, Color("2f6fa8"))
				_p(c, rot, 0, 0.91, 0, 1.1, 0.02, 2.1, WHITE, 0)
			else:
				_p(c, rot, 0, 1.1, 0, 1.3, 2.2, 1.3, Color("e04fa6"))
				_p(c, rot, 0, 1.5, 0, 1.2, 1.0, 1.2, Color("bfe3ef"), 0)
		"club":
			if k == 0 and roll < 0.3:
				_p(c, rot, 0, 0.03, 0, 3.0, 0.04, 3.0, [Color("e04fa6"), Color("49d6e0"), Color("e0b13c")][rng.randi() % 3], 0)
			elif roll < 0.6:
				_p(c, rot, 0, 0.55, 0, 2.6, 1.1, 0.7, BLACK)
				_p(c, rot, 0, 1.11, 0, 2.6, 0.04, 0.7, Color("e04fa6"), 0)
			else:
				_sofa(c, rot, Color("6a2a5a"))
		"bar":
			if roll < 0.4:
				_p(c, rot, 0, 0.55, 0, 2.6, 1.1, 0.7, DARKWOOD)
				for s: float in [-0.9, 0.0, 0.9]:
					_pc(c, rot, s, 0.38, 0.75, 0.2, 0.75, BLACK)
			elif roll < 0.7:
				_p(c, rot, 0, 0.45, 0, 1.4, 0.9, 2.5, DARKWOOD)
				_p(c, rot, 0, 0.91, 0, 1.25, 0.03, 2.3, FELT, 0)
			else:
				_table_chairs(c, rot, WOOD)
		"apartments":
			if roll < 0.3:
				_bed(c, rot, BLUE)
			elif roll < 0.55:
				_sofa(c, rot, Color("7a8a6a"))
				_p(c, rot, 0, 0.6, -1.3, 1.4, 0.8, 0.1, BLACK)
			elif roll < 0.8:
				_p(c, rot, 0, 0.45, 0, 2.6, 0.9, 0.65, WHITE)
				_p(c, rot, 1.6, 0.95, 0, 0.8, 1.9, 0.7, METAL)
			else:
				_table_chairs(c, rot, LIGHTWOOD)
		"mall":
			if roll < 0.45:
				_p(c, rot, 0, 0.8, 0, 3.0, 1.6, 0.9, WHITE)
				for s: float in [0.5, 1.0, 1.5]:
					_p(c, rot, 0, s, 0, 2.9, 0.12, 1.0, [RED, BLUE, GOLD, Color("4a8a5a")][rng.randi() % 4], 0)
			elif roll < 0.7:
				_p(c, rot, 0, 1.4, 0, 2.0, 0.05, 0.05, METAL, 0)
				_p(c, rot, 0, 0.8, 0, 2.0, 1.3, 0.5, [Color("c27aa0"), Color("6a8ac2"), Color("e0b13c")][rng.randi() % 3])
			elif roll < 0.85:
				_p(c, rot, 0, 0.55, 0, 2.0, 1.1, 2.0, Color("4f8fbf"))
			else:
				_p(c, rot, 0, 0.25, 0, 2.0, 0.5, 0.6, WOOD)
				_plant(c + Vector3(0, 0, 1.2))
		"motel":
			if roll < 0.55:
				_bed(c, rot, Color("c0453a"))
				_p(c, rot, 1.3, 0.3, -0.8, 0.5, 0.6, 0.5, DARKWOOD)
			else:
				_p(c, rot, 0, 0.45, 0, 1.6, 0.9, 0.55, DARKWOOD)
				_p(c, rot, 0, 1.15, 0, 0.9, 0.55, 0.12, BLACK, 0)
		"rundown", "rundown2":
			if roll < 0.3:
				_p(c, rot, 0, 0.12, 0, 1.4, 0.24, 2.0, Color("b8b08a"))
			elif roll < 0.55:
				_sofa(c, rot, Color("6a5a3a"))
			elif roll < 0.8:
				for i in rng.randi_range(2, 5):
					box(c + Vector3(rng.randf_range(-1, 1), 0.3, rng.randf_range(-1, 1)), Vector3(0.6, 0.6, 0.6), Color("2a2a2a"), 0, true)
				_crates(c)
			else:
				_p(c, rot, 0, 0.4, 0, 1.2, 0.8, 0.8, Color("6a5040"))
				_p(c, rot, 0, 1.2, 1.3, 2.4, 1.6, 0.05, [Color("d64545"), Color("49d6e0"), Color("e0b13c")][rng.randi() % 3], 0)
		"office":
			if roll < 0.75:
				for dx: float in [-0.9, 0.9]:
					for dz: float in [-0.7, 0.7]:
						_p(c, rot, dx, 0.37, dz, 1.6, 0.74, 0.75, WHITE)
						_p(c, rot, dx, 0.95, dz * 0.6, 0.55, 0.38, 0.05, BLACK, 0)
				_p(c, rot, 0, 0.7, 0, 3.4, 1.4, 0.06, Color("7a8a9a"))
				_p(c, rot, 0, 0.7, 0, 0.06, 1.4, 2.8, Color("7a8a9a"))
			elif roll < 0.88:
				_p(c, rot, 0, 0.55, 0, 1.0, 1.1, 0.7, Color("d8d8d8"))
				_plant(c + Vector3(1.0, 0, 0))
			else:
				_table_chairs(c, rot, DARKWOOD)
		"casino":
			if roll < 0.45:
				for s: float in [-1.05, -0.35, 0.35, 1.05]:
					_p(c, rot, s, 0.8, 0, 0.6, 1.6, 0.65, GOLD)
					_p(c, rot, s, 1.2, -0.34, 0.45, 0.45, 0.04, Color("ff7a4a"), 0)
			elif roll < 0.75:
				_pc(c, rot, 0, 0.42, 0, 1.2, 0.84, FELT)
				_pc(c, rot, 0, 0.86, 0, 0.35, 0.05, GOLD, 0)
			elif roll < 0.9:
				_p(c, rot, 0, 0.45, 0, 2.2, 0.9, 1.2, FELT)
			else:
				_p(c, rot, 0, 0.55, 0, 2.8, 1.1, 0.7, DARKWOOD)
		"library":
			if roll < 0.6:
				_bookshelf(c, rot)
			elif roll < 0.85:
				_table_chairs(c, rot, LIGHTWOOD)
			else:
				_desk_chair(c, rot)
				_p(c, rot, 0, 1.0, -0.2, 0.55, 0.4, 0.05, BLACK, 0)
		_:
			_crates(c)


func _desk_chair(c: Vector3, rot: bool) -> void:
	_p(c, rot, 0, 0.37, 0, 1.4, 0.74, 0.7, WOOD)
	_p(c, rot, 0, 0.75, 0, 1.45, 0.04, 0.75, LIGHTWOOD, 0)
	_p(c, rot, 0, 0.23, 0.75, 0.5, 0.46, 0.5, DARKMETAL)
	_p(c, rot, 0, 0.75, 0.98, 0.5, 0.6, 0.06, DARKMETAL, 0)


func _school_desk(c: Vector3, rot: bool) -> void:
	_p(c, rot, 0, 0.35, -0.1, 0.7, 0.7, 0.5, LIGHTWOOD)
	_p(c, rot, 0, 0.22, 0.35, 0.4, 0.44, 0.38, BLUE, 0)


func _rack(c: Vector3, rot: bool) -> void:
	_pshape(c, rot, 0, 1.8, 0, 3.4, 3.6, 1.1)
	for sx: float in [-1.65, 1.65]:
		for sz: float in [-0.5, 0.5]:
			_p(c, rot, sx, 1.8, sz, 0.1, 3.6, 0.1, Color("d66a2a"), 0)
	for h: float in [0.15, 1.3, 2.45, 3.55]:
		_p(c, rot, 0, h, 0, 3.4, 0.08, 1.1, Color("3a5a8a"), 0)
		if h < 3.0:
			for s: float in [-1.0, 0.1, 1.1]:
				if rng.randf() < 0.75:
					var bh := rng.randf_range(0.5, 0.95)
					_p(c, rot, s, h + 0.04 + bh * 0.5, 0, 0.9, bh, 0.9, CARDBOARD, 0)


func _crates(c: Vector3) -> void:
	var n := rng.randi_range(1, 3)
	for i in n:
		var s := rng.randf_range(0.9, 1.25)
		var off := Vector3(rng.randf_range(-0.9, 0.9), 0, rng.randf_range(-0.9, 0.9))
		box(c + off + Vector3(0, s * 0.5, 0), Vector3(s, s, s), CARDBOARD if rng.randf() < 0.6 else WOOD, L_WALL, _detail)
		if rng.randf() < 0.4:
			var s2 := s * 0.8
			box(c + off + Vector3(0, s + s2 * 0.5, 0), Vector3(s2, s2, s2), CARDBOARD, L_WALL, _detail)


func _forklift(c: Vector3, rot: bool) -> void:
	_p(c, rot, 0, 0.8, 0, 1.2, 1.3, 2.0, Color("e0b13c"))
	_p(c, rot, 0, 1.9, 0.3, 1.1, 0.08, 1.2, DARKMETAL, 0)
	_p(c, rot, 0, 1.6, -1.05, 1.0, 3.0, 0.15, DARKMETAL)
	_p(c, rot, 0, 0.12, -1.7, 0.9, 0.08, 1.2, DARKMETAL, 0)


func _sofa(c: Vector3, rot: bool, col: Color) -> void:
	_p(c, rot, 0, 0.25, 0, 2.2, 0.5, 0.9, col)
	_p(c, rot, 0, 0.7, 0.38, 2.2, 0.6, 0.18, col.darkened(0.15), 0)
	_p(c, rot, 0, 0.22, -1.1, 1.0, 0.44, 0.55, WOOD)


func _bed(c: Vector3, rot: bool, blanket: Color) -> void:
	_p(c, rot, 0, 0.25, 0, 1.6, 0.5, 2.1, DARKWOOD)
	_p(c, rot, 0, 0.56, 0.2, 1.5, 0.14, 1.6, blanket, 0)
	_p(c, rot, 0, 0.6, -0.75, 1.2, 0.18, 0.4, WHITE, 0)
	_p(c, rot, 0, 0.7, -1.02, 1.6, 0.9, 0.08, DARKWOOD, 0)


func _table_chairs(c: Vector3, rot: bool, col: Color) -> void:
	_p(c, rot, 0, 0.37, 0, 1.6, 0.74, 0.9, col)
	for s: float in [-1.0, 1.0]:
		_p(c, rot, s * 0.45, 0.23, 0.75, 0.45, 0.46, 0.45, col.darkened(0.2), 0)
		_p(c, rot, s * 0.45, 0.23, -0.75, 0.45, 0.46, 0.45, col.darkened(0.2), 0)


func _bookshelf(c: Vector3, rot: bool) -> void:
	for sz: float in [-0.45, 0.45]:
		_p(c, rot, 0, 1.1, sz, 3.0, 2.2, 0.45, DARKWOOD)
		for h: float in [0.35, 0.85, 1.35, 1.85]:
			_p(c, rot, 0, h, sz - signf(sz) * 0.24, 2.8, 0.36, 0.02, [RED, BLUE, Color("4a8a5a"), GOLD][rng.randi() % 4], 0)


func _plant(c: Vector3) -> void:
	cyl(c + Vector3(0, 0.3, 0), 0.3, 0.6, Color("a0522d"), L_WALL, true)
	sphere(c + Vector3(0, 1.0, 0), 0.55, Color("4a8a3a"))


func _vault(c: Vector3) -> void:
	box(c + Vector3(0, 1.3, 0), Vector3(3.0, 2.6, 3.0), Color("7a8288"), L_WALL, true)
	cyl(c + Vector3(0, 1.3, -1.55), 0.9, 0.12, Color("b0b8bc"), 0, true)
	box(c + Vector3(0, 2.75, 0), Vector3(1.0, 0.3, 0.6), GOLD, L_WALL, true)


func _furnish_sports(inner: Rect2, zones: Array) -> void:
	var c := inner.get_center()
	# Court
	var court := Rect2(c.x - 14.0, c.y - 7.5, 28.0, 15.0)
	box(Vector3(c.x, 0.04, c.y), Vector3(court.size.x, 0.04, court.size.y), Color("d9a768"), 0)
	box(Vector3(c.x, 0.065, c.y), Vector3(0.12, 0.02, court.size.y), WHITE, 0)
	cyl(Vector3(c.x, 0.065, c.y), 1.8, 0.02, Color("3f6fa8"), 0)
	for s: float in [-1.0, 1.0]:
		var hx := c.x + s * 13.4
		cyl(Vector3(hx + s * 0.6, 1.7, c.y), 0.1, 3.4, DARKMETAL, L_WALL)
		box(Vector3(hx, 3.4, c.y), Vector3(0.08, 1.05, 1.8), WHITE, L_WALL)
		cyl(Vector3(hx - s * 0.3, 3.05, c.y), 0.25, 0.04, Color("e06a2a"), 0)
		box(Vector3(hx - s * 2.9, 0.065, c.y), Vector3(5.8, 0.02, 4.9), Color("3f6fa8"), 0)
	# Bleachers along both long sides (ramp collision + visual steps)
	for s: float in [-1.0, 1.0]:
		var z_edge := c.y + s * 9.0
		var steps := 5
		for i in steps:
			var zc := z_edge + s * (i * 0.9 + 0.45)
			var hgt := (i + 1) * 0.5
			box(Vector3(c.x, hgt * 0.5, zc), Vector3(26.0, hgt, 0.9), Color("3f6fa8") if i % 2 == 0 else WHITE, 0)
		var run := steps * 0.9
		var rise := steps * 0.5
		var th := atan2(rise, run)
		var rot := Basis(Vector3(1, 0, 0), -s * th)
		var mid := Vector3(c.x, rise * 0.5 - 0.1, z_edge + s * run * 0.5)
		_add_shape(L_FLOOR, _box_shape(Vector3(26.0, 0.2, sqrt(run * run + rise * rise))), Transform3D(rot, mid))
		_add_shape(L_WALL, _box_shape(Vector3(26.0, rise, 0.3)), Transform3D(Basis.IDENTITY, Vector3(c.x, rise * 0.5, z_edge + s * (run + 0.15))))
	# Scoreboard + banner
	box(Vector3(c.x, 8.0, c.y), Vector3(3.0, 2.0, 3.0), BLACK, 0)
	box(Vector3(c.x, 8.0, c.y), Vector3(3.05, 1.2, 3.05), Color("e0b13c"), 0)
	_label("SWIFTCURRENT RAPIDS", Vector3(c.x, 7.5, inner.position.y + 0.2), 0.0, 160, Color("9fd0ff"))
	_label("SWIFTCURRENT RAPIDS", Vector3(c.x, 7.5, inner.end.y - 0.2), PI, 160, Color("9fd0ff"))
	# Equipment & benches near the ends
	for s: float in [-1.0, 1.0]:
		for i in 3:
			var p := Vector3(c.x + s * (18.0 + i * 2.5), 0, c.y + rng.randf_range(-6, 6))
			if not _blocked(Rect2(p.x - 1.5, p.z - 1.5, 3, 3), zones):
				_p(p, true, 0, 0.25, 0, 3.0, 0.5, 0.5, LIGHTWOOD)


func _furnish_water(inner: Rect2, zones: Array) -> void:
	var c := inner.get_center()
	var tanks := [Vector2(-10, -3), Vector2(-3, 4), Vector2(5, -3), Vector2(12, 4)]
	for t in tanks:
		var p := Vector3(c.x + t.x, 0, c.y + t.y)
		if _blocked(Rect2(p.x - 3, p.z - 3, 6, 6), zones):
			continue
		cyl(p + Vector3(0, 2.2, 0), 2.6, 4.4, Color("7fa8b8"), L_WALL, true)
		cyl(p + Vector3(0, 4.45, 0), 2.7, 0.1, DARKMETAL, 0, true)
		cyl(p + Vector3(0, 4.5, 0), 2.2, 0.06, Color("4a8ab0"), 0, true)
	# Pipes between tanks (low enough to vault over with a jump)
	box(Vector3(c.x, 0.5, c.y), Vector3(inner.size.x - 14.0, 0.5, 0.5), Color("3f7fa8"), L_WALL, true)
	box(Vector3(c.x + 2, 0.5, c.y + 6.8), Vector3(inner.size.x - 18.0, 0.5, 0.5), Color("3f7fa8"), L_WALL, true)
	# Pumps and control desks
	for i in 5:
		var p := Vector3(rng.randf_range(inner.position.x + 2, inner.end.x - 2), 0, rng.randf_range(inner.position.y + 2, inner.end.y - 2))
		if _blocked(Rect2(p.x - 1.5, p.z - 1.5, 3, 3), zones):
			continue
		box(p + Vector3(0, 0.6, 0), Vector3(1.4, 1.2, 1.0), Color("4a5a6a"), L_WALL, true)
		cyl(p + Vector3(0.9, 0.5, 0), 0.4, 1.0, Color("3f7fa8"), L_WALL, true)


# ================================================================ park (19)

func _build_park() -> void:
	var r := park_rect
	var x0 := r.position.x
	var z0 := r.position.y
	box(Vector3(r.get_center().x, 0.02, r.get_center().y), Vector3(r.size.x, 0.04, r.size.y), GRASS, 0)
	_label(MapData.PARK_NAME.to_upper(), Vector3(r.get_center().x, 3.0, r.end.y + 0.5), 0.0, 96, Color("d8f0c0"))
	# Basketball court (left side)
	var court := Rect2(x0 + 2.5, z0 + 13.0, 14.0, 26.0)
	var cc := court.get_center()
	box(Vector3(cc.x, 0.05, cc.y), Vector3(court.size.x, 0.06, court.size.y), Color("c0703a"), 0)
	box(Vector3(cc.x, 0.085, cc.y), Vector3(court.size.x, 0.02, 0.12), WHITE, 0)
	cyl(Vector3(cc.x, 0.085, cc.y), 1.8, 0.02, WHITE, 0)
	for s: float in [-1.0, 1.0]:
		var hz := cc.y + s * 12.4
		cyl(Vector3(cc.x, 1.7, hz + s * 0.6), 0.1, 3.4, DARKMETAL, L_WALL)
		box(Vector3(cc.x, 3.4, hz), Vector3(1.8, 1.05, 0.08), WHITE, L_WALL)
		cyl(Vector3(cc.x, 3.05, hz - s * 0.3), 0.25, 0.04, Color("e06a2a"), 0)
	# Chain fence around the court with gaps
	for s: float in [-1.0, 1.0]:
		box(Vector3(cc.x, 1.2, court.position.y - 0.4 if s < 0 else court.end.y + 0.4), Vector3(court.size.x - 4.0, 2.4, 0.08), Color("55625a"), L_WALL)
	# Playground tower (orange block on the sketch) - verticality
	var pg := MapData.px_rect([815, 360, 895, 412])
	var pc := pg.get_center()
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			cyl(Vector3(pc.x + sx * 1.4, 2.5, pc.y + sz * 1.0), 0.12, 5.0, Color("e06a2a"), L_WALL)
	box(Vector3(pc.x, 2.5, pc.y), Vector3(3.2, 0.2, 2.4), Color("e0b13c"), L_FLOOR)
	box(Vector3(pc.x, 5.0, pc.y), Vector3(3.6, 0.15, 2.8), Color("c0453a"), L_FLOOR)
	for sx: float in [-1.0, 1.0]:
		cyl(Vector3(pc.x + sx * 1.4, 3.1, pc.y + 1.0), 0.08, 1.0, Color("e06a2a"), 0)
		cyl(Vector3(pc.x + sx * 1.4, 3.1, pc.y - 1.0), 0.08, 1.0, Color("e06a2a"), 0)
	var th := atan2(2.5, 4.2)
	box(Vector3(pc.x + 1.6 + 2.1, 1.25, pc.y), Vector3(5.0, 0.2, 1.2), Color("3f6fa8"), L_FLOOR, false, Basis(Vector3(0, 0, 1), -th))
	box(Vector3(pc.x - 1.6 - 2.1, 1.25, pc.y), Vector3(5.0, 0.2, 1.2), Color("e06a2a"), L_FLOOR, false, Basis(Vector3(0, 0, 1), th))
	# Pond (blue blobs on the sketch) - shallow water, walkable
	for blob in [[1075, 620, 3.8], [1060, 665, 3.6], [1035, 700, 3.4], [1050, 725, 2.6]]:
		var p := MapData.px(blob[0], blob[1])
		cyl(Vector3(p.x, 0.05, p.y), blob[2] + 0.4, 0.06, Color("9a8a6a"), 0)
		cyl(Vector3(p.x, 0.07, p.y), blob[2], 0.06, Color("3fa8e0"), 0)
	# Trees and benches
	var avoid := [court.grow(1.5), pg.grow(3.0), MapData.px_rect([990, 580, 1110, 750]).grow(1.0)]
	for o in objectives:
		avoid.append(Rect2(o.pos.x - 3.0, o.pos.z - 3.0, 6.0, 6.0))
	var placed := 0
	var tries := 0
	while placed < 34 and tries < 400:
		tries += 1
		var p := Vector2(rng.randf_range(r.position.x + 1.5, r.end.x - 1.5), rng.randf_range(r.position.y + 1.5, r.end.y - 1.5))
		var bad := false
		for a: Rect2 in avoid:
			if a.has_point(p):
				bad = true
		if bad:
			continue
		avoid.append(Rect2(p.x - 2.5, p.y - 2.5, 5.0, 5.0))
		placed += 1
		if placed % 4 == 0:
			box(Vector3(p.x, 0.25, p.y), Vector3(1.8, 0.5, 0.6), WOOD, L_WALL)
			box(Vector3(p.x, 0.7, p.y + 0.28), Vector3(1.8, 0.5, 0.08), WOOD, 0)
		elif placed % 4 == 1:
			_bush(Vector3(p.x, 0, p.y))
		else:
			var h := rng.randf_range(2.5, 3.5)
			cyl(Vector3(p.x, h * 0.5, p.y), 0.25, h, Color("6b4a32"), L_WALL)
			sphere(Vector3(p.x, h + 1.0, p.y), rng.randf_range(1.6, 2.2), Color("4f8a3a").lerp(Color("7ab04a"), rng.randf()))


# ================================================================ cranes & rooftop bridges

# [building A id, building B id, material]
const BRIDGES := [
	[1, 2, "planks"],
	[10, 15, "planks"],
	[15, 16, "metal"],
	[13, 14, "metal"],
	[4, 5, "planks"],
	[17, 18, "metal"],
]


func _building(id: int) -> Dictionary:
	for b in buildings:
		if b.id == id:
			return b
	return {}


## Tower cranes holding building materials (planks / sheet metal) that bridge
## the gap between two rooftops. Deck ends rest on top of each roof's parapet;
## a crate on each roof makes it easy to climb up.
func _build_cranes() -> void:
	var avoid: Array = spawn_dots.duplicate()
	for o in objectives:
		avoid.append(o.pos)
	for br in BRIDGES:
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
			box(Vector3(end_p.x, roof_y + 0.3, end_p.z) + inward * 1.6, Vector3(1.1, 0.6, 1.1), WOOD, L_WALL)
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
			box(center + boff, bsize, LIGHTWOOD.lerp(WOOD, rng.randf()), 0, false, rot)
		# Cross battens underneath
		var n := int(length / 1.5)
		for i in n:
			var t := (float(i) + 0.5) / n - 0.5
			var bpos := center + d.normalized() * (t * length) + rot * Vector3(0, -0.1, 0)
			box(bpos, Vector3(0.12, 0.08, width + 0.1) if along_x else Vector3(width + 0.1, 0.08, 0.12), DARKWOOD, 0, false, rot)
	else:
		box(center, size, Color("9aa3a8"), 0, false, rot)
		var ribs := 6
		for i in ribs:
			var off := (float(i) - (ribs - 1) * 0.5) * (width / ribs)
			var rsize := Vector3(length, 0.05, 0.06) if along_x else Vector3(0.06, 0.05, length)
			var roff := Vector3(0, 0.09, off) if along_x else Vector3(off, 0.09, 0)
			box(center + rot * roff, rsize, Color("7d868c"), 0, false, rot)


## Thin box between two points (cables, slings).
func _strut(a: Vector3, b: Vector3, thick: float, col: Color) -> void:
	var d := b - a
	var len_d := d.length()
	if len_d < 0.01:
		return
	var y := d / len_d
	var ref := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := y.cross(ref).normalized()
	var z := x.cross(y).normalized()
	box((a + b) * 0.5, Vector3(thick, len_d, thick), col, 0, false, Basis(x, y, z))


func _crane(mid: Vector3, out: Vector3, p0: Vector3, p1: Vector3, material: String) -> void:
	var yellow := Color("e0b13c")
	var base := mid + out * 5.0
	base.y = 0.0
	var top_y := maxf(p0.y, p1.y) + 9.0
	# Concrete footing + mast
	box(base + Vector3(0, 0.5, 0), Vector3(3.2, 1.0, 3.2), Color("a8a49a"), L_WALL)
	_add_shape(L_WALL, _box_shape(Vector3(1.5, top_y - 1.0, 1.5)), Transform3D(Basis.IDENTITY, base + Vector3(0, (top_y + 1.0) * 0.5, 0)))
	for cx: float in [-0.7, 0.7]:
		for cz: float in [-0.7, 0.7]:
			box(base + Vector3(cx, (top_y + 1.0) * 0.5, cz), Vector3(0.14, top_y - 1.0, 0.14), yellow, 0)
	var y := 2.0
	while y < top_y - 1.0:
		_strut(base + Vector3(-0.7, y, -0.7), base + Vector3(0.7, y + 1.4, -0.7), 0.07, yellow)
		_strut(base + Vector3(0.7, y, 0.7), base + Vector3(-0.7, y + 1.4, 0.7), 0.07, yellow)
		_strut(base + Vector3(-0.7, y, 0.7), base + Vector3(-0.7, y + 1.4, -0.7), 0.07, yellow)
		_strut(base + Vector3(0.7, y, -0.7), base + Vector3(0.7, y + 1.4, 0.7), 0.07, yellow)
		y += 1.4
	# Slewing unit, cab, jib towards the bridge, counter-jib with weights
	box(base + Vector3(0, top_y, 0), Vector3(2.0, 1.0, 2.0), yellow.darkened(0.2), 0)
	box(base + Vector3(0, top_y + 0.2, 0) - out * 1.3, Vector3(1.2, 1.4, 1.2), Color("d8d2c8"), 0)
	var jib_end := base - out * 11.0 + Vector3(0, top_y + 0.6, 0)
	var cj_end := base + out * 6.0 + Vector3(0, top_y + 0.6, 0)
	_strut(base + Vector3(0, top_y + 0.6, 0), jib_end, 0.7, yellow)
	_strut(base + Vector3(0, top_y + 0.6, 0), cj_end, 0.6, yellow)
	box(cj_end - out * 1.0 + Vector3(0, -0.6, 0), Vector3(1.6, 1.6, 1.6), Color("8a8478"), 0)
	box(base + Vector3(0, top_y + 3.2, 0), Vector3(0.5, 4.0, 0.5), yellow, 0)
	_strut(base + Vector3(0, top_y + 5.2, 0), jib_end, 0.05, DARKMETAL)
	_strut(base + Vector3(0, top_y + 5.2, 0), cj_end, 0.05, DARKMETAL)
	# Hook over the bridge with slings down to the deck
	var hook_top := Vector3(mid.x, top_y + 0.2, mid.z)
	var hook := Vector3(mid.x, maxf(p0.y, p1.y) + 3.5, mid.z)
	box(Vector3(mid.x, top_y + 0.1, mid.z), Vector3(0.6, 0.3, 0.6), DARKMETAL, 0)
	_strut(hook_top, hook, 0.06, DARKMETAL)
	box(hook, Vector3(0.5, 0.4, 0.5), Color("c0453a"), 0)
	var dir := (p1 - p0).normalized()
	var span := p0.distance_to(p1)
	var a_pt := mid - dir * span * 0.3
	var b_pt := mid + dir * span * 0.3
	_strut(hook, a_pt + Vector3(0, 0.1, 0), 0.04, DARKMETAL)
	_strut(hook, b_pt + Vector3(0, 0.1, 0), 0.04, DARKMETAL)
	# A spare load hanging off the other side for flavour
	var spare := base - out * 8.5 + Vector3(0, top_y - 4.0, 0)
	_strut(Vector3(spare.x, top_y + 0.2, spare.z), spare + Vector3(0, 0.4, 0), 0.05, DARKMETAL)
	if material == "planks":
		box(spare, Vector3(2.4, 0.6, 1.0), LIGHTWOOD, 0)
	else:
		box(spare, Vector3(2.4, 0.4, 1.2), Color("9aa3a8"), 0)


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
