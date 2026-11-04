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
const FOUNTAIN_SPRAY := preload("res://assets/props/park/fountain_spray.tscn")
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
var map_marks: Array = []      # [kind, Rect2]: park features and car parks for the minimap ("path", "court", "sand", "pond", "plaza", "lot")
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
var _specials := {}      # material name -> [[kind, transform, colour, detail]]: parts drawn with their own material
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
var _in: Interiors           # furnishes the buildings (scripts/map/interiors.gd), during build() only
var wide_decor: Array = []   # [wall face point, half width along the wall] of each wide wall piece (tests/city.gd checks them)


## Height of a Tag spot: the floor of the storey it names (o[3], 0 = ground) in
## the layout building it stands in, or the ground.
static func _storey_y(layout: Dictionary, o: Array) -> float:
	var k := int(o[3]) if o.size() > 3 else 0
	if k <= 0:
		return 0.0
	for b in layout.buildings:
		var r: Array = b[3]
		if o[0] > r[0] and o[0] < r[2] and o[1] > r[1] and o[1] < r[3]:
			return mini(k, int(b[4]) - 1) * float(b[5])
	return 0.0


## seed 0 builds the classic hand-made city; any other seed a random one
## (CityGen). Every peer passes the same size and seed, so they get the same map.
func build(parent: Node3D, size := MapData.DEFAULT_SIZE, seed := 0) -> void:
	root = parent
	_in = Interiors.new(self)
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
			objectives.append({"pos": Vector3(p.x, _storey_y(layout, o), p.y), "name": o[2]})
	if objectives.is_empty():
		# Every Tag spot fell in a removed building's lot: use the middle of the map
		# so a round can always start.
		var c := bounds.get_center()
		objectives.append({"pos": Vector3(c.x, 0.0, c.y), "name": "City Centre"})
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
	_in = null  # it points back at us: let both be freed


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
	_specials = {}


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
	# Parts with their own material (water): one batch per material and shape
	for mat_name: String in _specials:
		var mat: Material = Mats.named(mat_name)
		for kind: String in meshes:
			var items := []
			for g: Array in _specials[mat_name]:
				if g[0] == kind:
					items.append([g[1], g[2]])
			_make_mm(meshes[kind], items, 0.0, mat)


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
		if p.material != "":
			if not _specials.has(p.material):
				_specials[p.material] = []
			_specials[p.material].append([p.kind, t, col, detail])
			continue
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
	for ri in road_rects.size():
		var r: Rect2 = road_rects[ri]
		# Where roads overlap, only the first draws the surface (no flickering).
		var pieces: Array = [r]
		for rj in ri:
			var next: Array = []
			for pc: Rect2 in pieces:
				next.append_array(_subtract(pc, road_rects[rj]))
			pieces = next
		for pc: Rect2 in pieces:
			box(Vector3(pc.get_center().x, 0.012, pc.get_center().y), Vector3(pc.size.x, 0.024, pc.size.y), ASPHALT, DECOR)
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
##  * zebra crossings at the junctions, with traffic lights and street name signs
##    on the corners,
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
	_build_corners()
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


## Every junction corner on the sidewalk gets a traffic light, its mast arm over
## the road (the four corners' arms point round the junction like a pinwheel, so
## every approach has one), and some get a street name sign as well.
func _build_corners() -> void:
	for j: Rect2 in _junctions:
		for corner: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]:
			var c := j.get_center() + Vector2(j.size.x * 0.5 + 0.8, j.size.y * 0.5 + 0.8) * corner
			if _on_road(c, 0.3) or not _street_clear(c, 0.5, 0.4) or not bounds.grow(-2.0).has_point(c):
				continue
			# Arm direction for this corner (pinwheel), the light's local -Z.
			var arm: Vector3 = {Vector2(1, 1): Vector3(-1, 0, 0), Vector2(-1, 1): Vector3(0, 0, -1), Vector2(-1, -1): Vector3(1, 0, 0), Vector2(1, -1): Vector3(0, 0, 1)}[corner]
			_prefab("props/street/traffic_light", _at(Vector3(c.x, 0.0, c.y), _yaw_to(-arm)))
			if rng.randf() < 0.5:
				var sc := c + Vector2(arm.z, -arm.x) * 1.4  # a step along the curb
				if not _on_road(sc, 0.3) and _street_clear(sc, 0.5, 0.3):
					_prefab("props/street/street_sign", _at(Vector3(sc.x, 0.0, sc.y), _yaw_to(-arm)))


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
	var p2 := Vector2(c.x, c.z)
	if roll < 0.12 and _street_clear(Vector2(shelter_at.x, shelter_at.z), 0.6, 1.8):
		_prefab("props/street/bus_shelter", _at(shelter_at, _yaw_to(out)))
	elif roll < 0.32:
		_prefab("props/street/bench", _at(c, _yaw_to(out)))
	elif roll < 0.45:
		_prefab("props/street/bin", _at(c))
	elif roll < 0.58:
		_prefab("props/street/hydrant_news", _at(c, _yaw_x(dir)))
	elif roll < 0.64:
		_prefab("props/street/mailbox", _at(c))
	elif roll < 0.8:
		# A pair of parking meters along the curb.
		for k: float in [-1.2, 1.2]:
			var m := c + dir * k
			if _street_clear(Vector2(m.x, m.z), 0.6, 0.3):
				_prefab("props/street/parking_meter", _at(m, _yaw_to(-out)))
	elif roll < 0.9 and _street_clear(p2, 0.8, 1.6):
		_prefab("props/street/bike_rack", _at(c + out * 0.4, _yaw_x(dir)))
	elif _street_clear(p2, 0.8, 1.2):
		_prefab("props/street/planter_box", _at(c + out * 0.3, _yaw_x(dir)), {"leaf": Color("4f8a3a").lerp(Color("7ab04a"), rng.randf())})


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
		map_marks.append(["lot", lot])
		var inner := lot.grow(-1.0)
		if inner.size.x < 6.0 or inner.size.y < 6.0:
			continue
		var lot_pieces: Array = [lot]
		for rr: Rect2 in road_rects:
			var next: Array = []
			for pc: Rect2 in lot_pieces:
				next.append_array(_subtract(pc, rr))
			lot_pieces = next
		for pc: Rect2 in lot_pieces:
			box(Vector3(pc.get_center().x, 0.012, pc.get_center().y), Vector3(pc.size.x, 0.024, pc.size.y), ASPHALT, DECOR)
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
		elif roll < 0.72:
			_prefab("props/street/bench_pair", _at(c, _road_yaw(along_x)))
		elif roll < 0.8:
			_prefab("props/street/bollards", _at(c, _road_yaw(along_x)))
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

	# --- Exterior doors (ground floor), each in a whole wall module. Usually one,
	# sometimes two, on the sides that face a street.
	var door_spots := []  # [side, t, module]
	var side_spots := []
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
				side_spots.append([side, t, slot])
				break
	side_spots.sort_custom(func(a: Array, b: Array) -> bool: return _street_dist(a[0], x0, z0, x1, z1) < _street_dist(b[0], x0, z0, x1, z1))
	var n_doors := 1 if rng.randf() < 0.55 else 2
	for i in mini(n_doors, side_spots.size()):
		door_spots.append(side_spots[i])

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
	# The room partition (v = ROOM_V) meets the two end walls: no windows there.
	var solid := {}
	if can_rooms and not room_floors.is_empty():
		var ends := [2, 3] if _ax else [0, 1]
		var slot := int(ROOM_V / MODULE)
		for es: int in ends:
			solid[es] = [slot - 1, slot, slot + 1] if fmod(ROOM_V, MODULE) < 0.35 or fmod(ROOM_V, MODULE) > MODULE - 0.35 else [slot]
	_build_exterior_walls(type, floors, fh, x0, z0, x1, z1, door_spots, st, solid)

	# --- Signs: the name centred on each wall that has a street door (or on the
	# two long faces if a building has no door), and an awning over every door
	var sign_y := minf(top, fh) - 0.9
	var signed := []
	for ds in door_spots:
		var dside: int = ds[0]
		var dt: float = ds[1]
		var outward: Vector3 = [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT][dside]
		var door_c: Vector3 = [Vector3(dt, 0, z0), Vector3(dt, 0, z1), Vector3(x0, 0, dt), Vector3(x1, 0, dt)][dside]
		_prefab("building/door_awning", _at(door_c, _yaw_to(outward)), {"awning": st.trim})  # in the building's accent colour
		if dside in signed:
			continue
		signed.append(dside)
		var wall_c: Vector3 = [Vector3((x0 + x1) * 0.5, 0, z0), Vector3((x0 + x1) * 0.5, 0, z1), Vector3(x0, 0, (z0 + z1) * 0.5), Vector3(x1, 0, (z0 + z1) * 0.5)][dside]
		_label(bname.to_upper(), wall_c + outward * 0.08 + Vector3(0, sign_y, 0), _yaw_to(outward), 96)
	if door_spots.is_empty():
		_label(bname.to_upper(), Vector3((x0 + x1) * 0.5, minf(top, fh) - 0.9, z0 - 0.05), PI, 96)
		_label(bname.to_upper(), Vector3((x0 + x1) * 0.5, minf(top, fh) - 0.9, z1 + 0.05), 0.0, 96)

	# --- Rooftop clutter
	_roof_props(type, inner, top, stairs, floors)

	# --- Furniture forbidden zones
	_forbid = []
	for sr: Rect2 in stairs:
		_forbid.append(sr.grow(0.8))
	for ds in door_spots:
		_forbid.append(_door_clear_rect(ds[0], ds[1], x0, z0, x1, z1))
	var obj_forbid := []  # [clear area, floor height] for Tag spots in here
	for op in obj_here:
		obj_forbid.append([Rect2(op.x - 3.5, op.z - 3.5, 7.0, 7.0), op.y])

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
	_in.lay = {"umax": umax, "vmax": vmax, "rooms": lay_rooms, "doors": lay_doors, "stairs_far": flips.size() > 1, "S": S}
	var floor_zones := []
	var floor_cells := []
	var floor_walls := []
	for k in floors:
		var y := k * fh
		var zones: Array = _forbid.duplicate()
		var walls := []
		for of in obj_forbid:
			if absf(of[1] - y) < 0.5:
				zones.append(of[0])  # the Tag's floor stays clear around it
		if k in room_floors and can_rooms:
			zones.append_array(room_forbid)
			walls.append(_uv_rect(0, ROOM_V - 0.2, umax, ROOM_V + 0.2))
			for cu: float in room_walls:
				walls.append(_uv_rect(cu - 0.2, ROOM_V, cu + 0.2, vmax))
		floor_zones.append(zones)
		floor_walls.append(walls)
		_occupied = []
		if type == "sports":
			_in.furnish_sports(inner, zones)
		elif type == "water":
			_in.furnish_water(inner, zones)
		else:
			_in.furnish_floor(type, k, inner, y, fh, zones, k in room_floors and can_rooms)
		floor_cells.append(_occupied)
	_in.decorate_interior(type, floors, fh, inner, stairs, door_spots, floor_zones, floor_cells, floor_walls)

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
		var climb := ud if lane_a else -ud
		var across := Vector3(-ud.z, 0, ud.x)
		var guard := Basis(climb * run + Vector3.UP * fh, Vector3.UP * STAIR_GUARD_H, across)
		var gp := Vector3(dp.x, h0 + fh * 0.5 - 0.04, dp.y)
		_prefab("building/stair_guard", Transform3D(guard, gp), trim)
		var prism := PackedVector3Array()
		for gx: float in [-0.5, 0.5]:
			for gy: float in [0.0, 1.0]:
				for gz: float in [-0.05, 0.05]:
					prism.append(guard * Vector3(gx, gy, gz))
		var shape := ConvexPolygonShape3D.new()
		shape.points = prism
		_add_shape(L_WALL, shape, Transform3D(Basis.IDENTITY, gp))
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
func _build_exterior_walls(type: String, floors: int, fh: float, x0: float, z0: float, x1: float, z1: float, door_spots: Array, st: Dictionary, solid := {}) -> void:
	var top := floors * fh
	var p_win := 0.2 if type in ["warehouse", "water", "sports"] else 0.35
	# Big buildings (tall, or long walls) get fewer windows, so they don't read as glass boxes
	if floors >= 4 or maxi(_modules_along(x1 - x0), _modules_along(z1 - z0)) >= 10:
		p_win *= 0.55
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
		for s: int in solid.get(side, []):
			window_cols.erase(s)
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
		_prefab("building/corner_post", _at(Vector3(cx, 0, cz), 0.0, Vector3(1, top + 1.12, 1)), cols)


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


## Rooftops by kind of building (props in assets/props/roof), all cover to fight
## around, clear of the stairwell, the roof edges and the middle of each edge
## (where crane bridges land):
##  * commercial roofs: banks of big A/C condensers with ducts running off them,
##    a roof hatch and vents; skylights over big halls; satellite dishes and an
##    antenna on offices; pipe racks on industrial roofs
##  * bars, diners, arcades, clubs and motels: a billboard on the edge facing a street
##  * homes: a water tower on 4+ storeys, a roof terrace on apartments, TV antennas
##    and satellite dishes, and small A/C units
const ROOF_HOMES := ["apartments", "rundown", "rundown2", "motel"]
const ROOF_HALLS := ["mall", "warehouse", "library", "school", "theater", "casino"]
const ROOF_BILLBOARD := ["bar", "diner", "arcade", "club", "motel", "theater"]


func _roof_props(type: String, inner: Rect2, top: float, stairs: Array, floors: int) -> void:
	_roof_placed = []
	_roof_mids = []
	_roof_stairs = stairs
	var c := inner.get_center()
	for m: Vector2 in [Vector2(c.x, inner.position.y), Vector2(c.x, inner.end.y), Vector2(inner.position.x, c.y), Vector2(inner.end.x, c.y)]:
		_roof_mids.append(Rect2(m - Vector2(3.5, 3.5), Vector2(7, 7)))
	_roof_area = inner.grow(-1.4)
	_roof_top = top
	if _roof_area.size.x < 3.0 or _roof_area.size.y < 3.0:
		return
	if type in ROOF_BILLBOARD and inner.size.x >= 9.0 and inner.size.y >= 9.0:
		_roof_billboard(inner)
	if type in ROOF_HOMES:
		if floors >= 4:
			_roof_put("props/roof/water_tower", Vector2(1.4, 1.4), 1)
		if type == "apartments":
			_roof_put("props/roof/terrace_set", Vector2(2.6, 1.9), 1)
		_roof_put("props/roof/antenna", Vector2(0.5, 0.5), rng.randi_range(1, 2))
		_roof_put("props/roof/satellite_dish", Vector2(0.4, 0.4), rng.randi_range(1, 3))
		_roof_put("props/roof/ac_unit", Vector2(1.0, 1.0), rng.randi_range(1, 3))
		_roof_put("props/roof/roof_hatch", Vector2(0.75, 0.75), 1)
		return
	# Commercial: condenser banks first (the big cover), each with a duct run.
	var units := clampi(int(inner.get_area() / 120.0), 1, 6)
	for i in units:
		var p = _roof_put("props/roof/hvac_condenser", Vector2(1.35, 0.95), 1)
		if p != null:
			_roof_duct(p)
	if type in ROOF_HALLS:
		_roof_put("props/roof/skylight", Vector2(1.15, 0.8), clampi(int(inner.get_area() / 150.0), 1, 4))
	if type in ["water", "warehouse"]:
		_roof_put("props/roof/pipe_rack", Vector2(0.65, 0.5), 1, true)
	if type in ["office", "bank"]:
		_roof_put("props/roof/satellite_dish", Vector2(0.4, 0.4), rng.randi_range(1, 3))
		_roof_put("props/roof/antenna", Vector2(0.5, 0.5), 1 if floors >= 4 else 0)
	_roof_put("props/roof/vent", Vector2(0.5, 0.5), rng.randi_range(1, 3))
	_roof_put("props/roof/roof_hatch", Vector2(0.75, 0.75), 1)
	if floors >= 4 and type != "office":
		_roof_put("props/roof/water_tower", Vector2(1.4, 1.4), 1)


var _roof_placed: Array = []
var _roof_mids: Array = []
var _roof_stairs: Array = []
var _roof_area := Rect2()
var _roof_top := 0.0


## Puts up to n of a roof prop (footprint half-size `half`, before turning) at
## random clear spots; stretch = a 4-6 m long piece (stretched along its Z).
## Returns the last spot used (Vector2), or null.
func _roof_put(name: String, half: Vector2, n: int, stretch := false):
	var last = null
	var count := 0
	for attempt in 14 * maxi(n, 1):
		if count >= n:
			break
		var turn := rng.randi_range(0, 3)
		var length := rng.randf_range(4.0, 6.0) if stretch else 1.0
		var h := Vector2(half.x, half.y * length) if stretch else half
		if turn % 2 == 1:
			h = Vector2(h.y, h.x)
		if _roof_area.size.x < h.x * 2.0 + 0.2 or _roof_area.size.y < h.y * 2.0 + 0.2:
			return last
		var p := Vector2(rng.randf_range(_roof_area.position.x + h.x, _roof_area.end.x - h.x), rng.randf_range(_roof_area.position.y + h.y, _roof_area.end.y - h.y))
		var foot := Rect2(p - h, h * 2.0)
		if _hits_any(foot, _roof_stairs, 1.2) or _hits_any(foot, _roof_mids, 0.0) or _hits_any(foot, _roof_placed, 0.8):
			continue
		var scale := Vector3(1, 1, length) if stretch else Vector3.ONE
		_prefab(name, _at(Vector3(p.x, _roof_top, p.y), PI * 0.5 * turn, scale))
		_roof_placed.append(foot)
		last = p
		count += 1
	return last


## A duct (props/roof/duct_run, 1 m along its Z) from a condenser at p, 3-7 m
## along x or z, if the way is clear.
func _roof_duct(p: Vector2) -> void:
	for attempt in 4:
		var along_x := rng.randf() < 0.5
		var dir := 1.0 if rng.randf() < 0.5 else -1.0
		var length := rng.randf_range(3.0, 7.0)
		var start := p + (Vector2(dir * 1.6, 0) if along_x else Vector2(0, dir * 1.2))
		var mid := start + (Vector2(dir * length * 0.5, 0) if along_x else Vector2(0, dir * length * 0.5))
		var h := Vector2(length * 0.5, 0.45) if along_x else Vector2(0.45, length * 0.5)
		var foot := Rect2(mid - h, h * 2.0)
		if not _roof_area.encloses(foot) or _hits_any(foot, _roof_stairs, 1.2) or _hits_any(foot, _roof_mids, 0.0) or _hits_any(foot, _roof_placed, 0.3):
			continue
		_prefab("props/roof/duct_run", _at(Vector3(mid.x, _roof_top, mid.y), PI * 0.5 if along_x else 0.0, Vector3(1, 1, length)))
		_roof_placed.append(foot)
		return


## A billboard on the roof edge closest to a street, off the edge's middle (the
## bridge landing), facing out over the street.
func _roof_billboard(inner: Rect2) -> void:
	var best := -1
	var best_d := INF
	for side in 4:
		var d := _street_dist(side, inner.position.x, inner.position.y, inner.end.x, inner.end.y)
		if d < best_d:
			best_d = d
			best = side
	var horizontal := best < 2  # sides 0/1 run along x
	var edge_len := inner.size.x if horizontal else inner.size.y
	if edge_len < 9.0:
		return
	var t := (0.25 if rng.randf() < 0.5 else 0.75) * edge_len
	var p: Vector2
	var out: Vector3
	match best:
		0:
			p = Vector2(inner.position.x + t, inner.position.y + 1.0)
			out = Vector3.FORWARD
		1:
			p = Vector2(inner.position.x + t, inner.end.y - 1.0)
			out = Vector3.BACK
		2:
			p = Vector2(inner.position.x + 1.0, inner.position.y + t)
			out = Vector3.LEFT
		_:
			p = Vector2(inner.end.x - 1.0, inner.position.y + t)
			out = Vector3.RIGHT
	var h := Vector2(3.2, 0.9) if horizontal else Vector2(0.9, 3.2)
	var foot := Rect2(p - h, h * 2.0)
	if _hits_any(foot, _roof_stairs, 1.0) or _hits_any(foot, _roof_mids, 0.0):
		return
	_prefab("props/roof/billboard", _at(Vector3(p.x, _roof_top, p.y), _yaw_to(out)))
	_roof_placed.append(foot)


## How far the street is from the middle of a building side (0 if a road runs
## right past it): doors go on the sides closest to a street.
func _street_dist(side: int, x0: float, z0: float, x1: float, z1: float) -> float:
	var mid := Vector2((x0 + x1) * 0.5, (z0 + z1) * 0.5)
	var out: Vector2 = [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)][side]
	var edge: Vector2 = [Vector2(mid.x, z0), Vector2(mid.x, z1), Vector2(x0, mid.y), Vector2(x1, mid.y)][side]
	var probe := edge + out * 3.0
	var best := INF
	for r: Rect2 in road_rects:
		var cx := clampf(probe.x, r.position.x, r.end.x)
		var cz := clampf(probe.y, r.position.y, r.end.y)
		best = minf(best, probe.distance_to(Vector2(cx, cz)))
	return best


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
	_prefab("props/park/basketball_court", _at(Vector3(cc.x, 0, cc.y)))  # hoops, fence, lines, benches, ball rack, floodlights
	map_marks.append(["court", court])
	court.size.x += 1.6  # the team benches, ball rack and floodlights stand along its +X side
	var pg := Rect2(x0 + 6.5 * kx - 4.0, z0 + 5.1 * kz - 2.6, 8.0, 5.2)
	var pc := pg.get_center()
	var sand := pg.grow(1.2)  # props/park/sandpit is this size
	_prefab("props/park/sandpit", _at(Vector3(pc.x, 0, pc.y)))
	map_marks.append(["sand", sand])
	_prefab("props/park/playground", _at(Vector3(pc.x, 0, pc.y)))

	# Paths first: everything else keeps off them.
	var path_x := maxf(x0 + 19.5 * kx, court.end.x + 2.2)
	var path_z := (sand.end.y + court.position.y) * 0.5
	var cross := court.position.y - sand.end.y >= PATH_W + 1.0
	var paths := [Rect2(path_x - PATH_W * 0.5, z0, PATH_W, r.size.y)]
	if cross:
		paths.append(Rect2(x0, path_z - PATH_W * 0.5, r.size.x, PATH_W))
	_park_path(paths[0])
	for pr: Rect2 in paths:
		map_marks.append(["path", pr])
	for pi in range(1, paths.size()):
		for piece: Rect2 in _subtract(paths[pi], paths[0]):
			_park_path(piece)

	# Keep clear of the big pieces, the Tag and the spawn zones.
	var avoid := [court.grow(1.0), sand.grow(0.8)]
	for o in objectives:
		avoid.append(Rect2(o.pos.x - 3.5, o.pos.z - 3.5, 7.0, 7.0))
	for s: Vector3 in spawn_dots:
		avoid.append(Rect2(s.x - 3.0, s.z - 3.0, 6.0, 6.0))

	# The plaza and fountain sit on the main path, at the crossing if there's
	# room, otherwise wherever along the path it clears the court and sandpit.
	var plaza_r := 4.2
	var plaza_room := plaza_r + 0.6
	var plaza := Vector2.INF
	var want_z: float = path_z if cross else z0 + r.size.y * 0.25
	var best := INF
	var pz := z0 + plaza_room + 0.5
	while pz <= r.end.y - plaza_room - 0.5:
		var pr2 := Rect2(Vector2(path_x, pz) - Vector2.ONE * plaza_room, Vector2.ONE * plaza_room * 2.0)
		if r.encloses(pr2) and not court.intersects(pr2) and not sand.intersects(pr2) and not _hits_any(pr2, avoid.slice(2), 0.0):
			if absf(pz - want_z) < best:
				best = absf(pz - want_z)
				plaza = Vector2(path_x, pz)
		pz += 0.5
	var plaza_rect := Rect2()
	if plaza.is_finite():
		plaza_rect = Rect2(plaza - Vector2.ONE * (plaza_r + 2.2), Vector2.ONE * (plaza_r + 2.2) * 2.0)
		map_marks.append(["plaza", Rect2(plaza - Vector2.ONE * plaza_r, Vector2.ONE * plaza_r * 2.0)])

	# The pond: by default bottom right; moved off the paths and plaza (and shrunk
	# on small parks) so it never lies across a path.
	var pond := _place_pond(r, kx, kz, paths, plaza_rect, [court.grow(0.6), sand.grow(0.6)])
	if pond.has_area():
		avoid.append(pond.grow(0.8))
		map_marks.append(["pond", pond])
	if plaza.is_finite():
		_prefab("props/park/plaza", _at(Vector3(plaza.x, 0, plaza.y)))
		_prefab("props/park/fountain", _at(Vector3(plaza.x, 0, plaza.y)))
		var spray: Node3D = FOUNTAIN_SPRAY.instantiate()  # real particles, so a node rather than baked
		spray.position = Vector3(plaza.x, 0, plaza.y)
		_chunk.add_child(spray)
		# Benches round the fountain on the diagonals, facing it
		for i in 4:
			var ba := PI * 0.25 + i * PI * 0.5
			var bd := Vector3(cos(ba), 0, sin(ba))
			_prefab("props/park/bench", _at(Vector3(plaza.x, 0, plaza.y) + bd * 3.3, _yaw_to(bd)))
		# Flower beds on the plaza's diagonals, turned to follow it round
		for i in 4:
			var a := PI * 0.25 + i * PI * 0.5
			var d := Vector2(cos(a), sin(a))
			var fp := plaza + d * (plaza_r + 1.4)
			var fr := Rect2(fp - Vector2(1.3, 1.3), Vector2(2.6, 2.6))
			if r.grow(-0.5).encloses(fr) and not _hits_any(fr, avoid, 0.0) and not _hits_any(fr, paths, 0.2):
				_prefab("props/park/flower_bed", _at(Vector3(fp.x, 0, fp.y), _yaw_x(Vector3(-d.y, 0, d.x))))
		avoid.append(plaza_rect)
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
					# Benches beside the basketball court turn to watch the game
					var near := Vector2(clampf(c.x, court.position.x, court.end.x), clampf(c.y, court.position.y, court.end.y))
					var to_bench := c - near
					var face := away
					if to_bench.length() < 4.0:
						face = Vector3(signf(to_bench.x), 0, 0) if absf(to_bench.x) >= absf(to_bench.y) else Vector3(0, 0, signf(to_bench.y))
					_prefab("props/park/bench", _at(Vector3(c.x, 0, c.y), _yaw_to(face)))
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


## Places props/park/pond (local extent x -5.8..6.2, z -9.7..8.0 at scale 1,
## scaled by kx/kz) where it clears the paths, plaza and keep-out rects: first
## where the classic layout puts it, then shifted right of the main path and
## up/down, shrinking it if the park is too small. Returns its footprint (empty
## if there was no room).
func _place_pond(r: Rect2, kx: float, kz: float, paths: Array, plaza_rect: Rect2, keep_out: Array) -> Rect2:
	var blocks := keep_out.duplicate()
	for p: Rect2 in paths:
		blocks.append(p.grow(0.6))
	if plaza_rect.has_area():
		blocks.append(plaza_rect)
	var x_lo: float = (paths[0] as Rect2).end.x + 0.6
	for sc: float in [1.0, 0.85, 0.7, 0.55]:
		var sx := kx * sc
		var sz := kz * sc
		var cands := [Vector2(r.position.x + 26.5 * kx, r.position.y + 34.0 * kz)]
		var lo_x := x_lo + 5.8 * sx
		var hi_x := r.end.x - 0.8 - 6.2 * sx
		var lo_z := r.position.y + 0.8 + 9.7 * sz
		var hi_z := r.end.y - 0.8 - 8.0 * sz
		if lo_x <= hi_x and lo_z <= hi_z:
			for fz: float in [1.0, 0.5, 0.0]:
				for fx: float in [0.5, 0.0, 1.0]:
					cands.append(Vector2(lerpf(lo_x, hi_x, fx), lerpf(lo_z, hi_z, fz)))
		for c: Vector2 in cands:
			var foot := Rect2(c.x - 5.8 * sx, c.y - 9.7 * sz, 12.0 * sx, 17.7 * sz)
			if r.grow(-0.5).encloses(foot) and not _hits_any(foot, blocks, 0.0):
				_prefab("props/park/pond", _at(Vector3(c.x, 0, c.y), 0.0, Vector3(sx, 1, sz)))
				# A little wooden dock from the bank on the path side out over the water
				_prefab("props/park/pond_dock", _at(Vector3(c.x - 5.6 * sx, 0, c.y + 2.5 * sz), _yaw_x(Vector3.RIGHT)))
				return foot
	return Rect2()


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
