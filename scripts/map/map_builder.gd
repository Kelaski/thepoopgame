class_name MapBuilder
## Turns a MapLayout into the 3D level: ground, roads, buildings, parks, street props, cranes and the
## boundary fence, with grass, roads and a distant city beyond it.

const DOOR_SCENE: PackedScene = preload("res://assets/models/door.tscn")
const NARROW_DOOR_SCENE: PackedScene = preload("res://assets/models/door_narrow.tscn")
# Collision layers (Player's movement masks are built from these).
const L_FLOOR := 1   # interior floors and roofs (Phantom can drop through)
const L_WALL := 2    # walls + furniture (Phantom can pass through; sniper can pierce one)
const L_PLAYER := 4
const L_DOOR := 8
const L_SOLID := 16  # ground and boundary fence (never passable)
const L_BOUNCE := 32 # bounce pads: landing on one launches you up
const L_SKY := 64    # sky barrier: stops players, but grapples, shots and pings pass through
const MASK_WORLD := L_FLOOR | L_WALL | L_DOOR | L_SOLID
const SKY_HEIGHT := 90.0
const CRANE_JIB := 11.0  # how far the crane top scene's jib reaches (m)
const DOOR_WIDTH := 1.7
## Share of trees that died.
const DEAD_TREES := 0.3
## Share of street lamps still working.
const LIT_LAMPS := 0.55
## Length of one straight panel of the round fence (m).
const FENCE_PANEL := 4.0
const DOOR_HEIGHT := 2.45

static var doors: Array = []   # this game's Door nodes, in build order (the same on every peer)
static var lights: Array = []  # interior lights
const LETTERING: PackedScene = preload("res://assets/world/sign_lettering.tscn")
const STREET_LIGHT: PackedScene = preload("res://assets/world/street_light.tscn")
const INTERIOR_LIGHT: PackedScene = preload("res://assets/world/interior_light.tscn")
const FAR_GROUND: PackedScene = preload("res://assets/world/far_ground.tscn")
const SKYLINE: PackedScene = preload("res://assets/world/skyline.tscn")
const ROAD_TOP := 0.02
const KERB_TOP := 0.06
const KERB_WIDTH := 0.22
## How far past the fence the roads and grass run (m).
const FAR_REACH := 900.0


static func build(layout: MapLayout, rules: MapRules, parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "Level"
	doors = []
	lights = []
	parent.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([layout.map_seed, layout.kind])
	var city := GeoBatch.new()
	GeoBatch.tag = "ground"
	_ground(city, layout, rules)
	_roads(city, layout, rules)
	var keep_clear := layout.keep_clear(rules.keep_clear_radius)
	var street_lamps: Array[Vector3] = []
	for park in layout.parks:
		var builder := ParkBuilder.new(city, root, rng, keep_clear)
		builder.build(park, layout)
		street_lamps.append_array(builder.lamps)
	var light_spots: Array[Vector3] = []
	var door_spots: Array[Rect2] = []
	for spec in layout.buildings:
		var builder := BuildingBuilder.new(rules)
		builder.build(spec, layout, keep_clear)
		builder.geo.bake(root, "Building%d" % spec.id)
		light_spots.append_array(builder.lights)
		for sign_board in builder.signs:
			_letter(root, sign_board.text, sign_board.pos, sign_board.yaw, sign_board.size, Color(0.15, 0.13, 0.18))
		for door in builder.doors:
			_hang_door(root, door)
			door_spots.append(Rect2(Vector2(door.pos.x, door.pos.z), Vector2.ZERO).grow(2.8))
	door_spots.append_array(_bridges(city, layout, rules, rng, door_spots))
	_street_props(city, layout, rules, rng, root, door_spots, street_lamps)
	var exits := _road_exits(layout, rules)
	GeoBatch.tag = "fence"
	_fence(city, layout, rules, exits)
	GeoBatch.tag = "ground"
	_outbound_roads(city, exits)
	city.bake(root, "City")
	_interior_lights(root, light_spots, rules)
	_far_ground(root)
	var skyline: Skyline = SKYLINE.instantiate()
	root.add_child(skyline)
	skyline.build(layout, rng, exits)
	return root


static func _ground(geo: GeoBatch, layout: MapLayout, rules: MapRules) -> void:
	var outer := layout.bounds.grow(rules.fence_margin)
	var c := layout.bounds.get_center()
	var reach := _fence_radius(layout, rules) + 2.0
	outer = outer.merge(Rect2(c, Vector2.ZERO).grow(reach))
	# The ground is on the boundary layer: Phantom's floor drop stops on it. It's seen as a round disc.
	geo.box("", Vector3(outer.get_center().x, -0.5, outer.get_center().y), Vector3(outer.size.x, 1.0, outer.size.y), GeoBatch.BOUNDARY)
	geo.cylinder("pavement", Vector3(c.x, -0.5, c.y), reach, reach, 1.0, 0, Basis.IDENTITY, 96)
	geo.box("", Vector3(outer.get_center().x, SKY_HEIGHT + 0.5, outer.get_center().y), Vector3(outer.size.x + 4.0, 1.0, outer.size.y + 4.0), L_SKY)


# ------------------------------------------------------------------ roads

## The road surface and its kerbs share the same offset lines, so they meet exactly, bends included.
static func _roads(geo: GeoBatch, layout: MapLayout, rules: MapRules) -> void:
	var fence_outline := _fence_outline(layout, rules)
	for road in layout.roads:
		var pts: PackedVector2Array = road.points
		var half: float = road.width * 0.5
		var left := _offset_line(pts, half)
		var right := _offset_line(pts, -half)
		for i in pts.size() - 1:
			geo.strip("asphalt", left[i], left[i + 1], right[i], right[i + 1], ROAD_TOP, ROAD_TOP)
			var a := pts[i]
			var b := pts[i + 1]
			var dir := (b - a).normalized()
			var basis := Basis(Vector3.UP, atan2(dir.x, dir.y))
			# Centre dashes stop short of crossings.
			var dashes := int(a.distance_to(b) / 3.5)
			for d in dashes:
				var p := a.lerp(b, (d + 0.5) / dashes)
				if not _on_other_road(p, layout, road, 4.2):
					geo.box("road_line", Vector3(p.x, ROAD_TOP + 0.01, p.y), Vector3(0.14, 0.01, 1.7), 0, basis)
		# Run out to the fence, where the roads carry on, and open only where another road's edge is.
		var long_pts := _reach_past_map(pts, layout, rules.fence_margin + 1.0)
		var others := _other_road_outlines(layout, road)
		_kerb(geo, _offset_line(long_pts, half), _offset_line(long_pts, half + KERB_WIDTH), others, fence_outline)
		_kerb(geo, _offset_line(long_pts, -half), _offset_line(long_pts, -half - KERB_WIDTH), others, fence_outline)
	for junction in layout.junctions:
		_crossing(geo, junction)


## A road's centre line moved sideways, mitred at the bends so the edge stays parallel to the road.
static func _offset_line(pts: PackedVector2Array, offset: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in pts.size():
		var before := (pts[i] - pts[i - 1]).normalized() if i > 0 else (pts[1] - pts[0]).normalized()
		var after := (pts[i + 1] - pts[i]).normalized() if i < pts.size() - 1 else before
		var n0 := Vector2(-before.y, before.x)
		var n1 := Vector2(-after.y, after.x)
		var miter := (n0 + n1).normalized()
		out.append(pts[i] + miter * offset / maxf(miter.dot(n1), 0.5))
	return out


## A road's line with any end at the map's edge pushed on outward.
static func _reach_past_map(pts: PackedVector2Array, layout: MapLayout, reach: float) -> PackedVector2Array:
	var out := pts.duplicate()
	if not layout.inside(out[0], 4.0):
		out[0] += (out[0] - out[1]).normalized() * reach
	var last := out.size() - 1
	if not layout.inside(out[last], 4.0):
		out[last] += (out[last] - out[last - 1]).normalized() * reach
	return out


static func _other_road_outlines(layout: MapLayout, road: Dictionary) -> Array[PackedVector2Array]:
	var outlines: Array[PackedVector2Array] = []
	for other in layout.roads:
		if other != road:
			var pts: PackedVector2Array = other.points
			var outline := _offset_line(pts, other.width * 0.5)
			var far_side := _offset_line(pts, -other.width * 0.5)
			far_side.reverse()
			outline.append_array(far_side)
			outlines.append(outline)
	return outlines


## The sidewalk's raised lip along a road: a strip from `edge` out to `outer`. Geometry2D cuts it
## exactly at the edge of each road that joins, so kerbs always meet at the corners.
static func _kerb(geo: GeoBatch, edge: PackedVector2Array, outer: PackedVector2Array, others: Array[PackedVector2Array], fence: PackedVector2Array) -> void:
	for i in edge.size() - 1:
		var length := edge[i].distance_to(edge[i + 1])
		for piece: PackedVector2Array in kerb_pieces(edge[i], edge[i + 1], others, fence):
			var t0 := edge[i].distance_to(piece[0]) / length
			var t1 := edge[i].distance_to(piece[piece.size() - 1]) / length
			geo.strip("kerb", piece[0], piece[piece.size() - 1], outer[i].lerp(outer[i + 1], t0), outer[i].lerp(outer[i + 1], t1), 0.0, KERB_TOP)


## The parts of a line inside the fence and outside every other road.
static func kerb_pieces(a: Vector2, b: Vector2, others: Array[PackedVector2Array], fence: PackedVector2Array) -> Array[PackedVector2Array]:
	var pieces := Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([a, b]), fence)
	for outline in others:
		var remaining: Array[PackedVector2Array] = []
		for piece in pieces:
			remaining.append_array(Geometry2D.clip_polyline_with_polygon(piece, outline))
		pieces = remaining
	return pieces


## A zebra crossing centred across the road that joins, just back from the junction, and its stop line.
static func _crossing(geo: GeoBatch, junction: Dictionary) -> void:
	var dir: Vector2 = junction.dir
	var side := Vector2(-dir.y, dir.x)
	var basis := Basis(Vector3.UP, atan2(dir.x, dir.y))
	var width: float = junction.road.width
	var at: Vector2 = junction.pos + dir * (junction.through.width * 0.5 + 1.5)
	var stripes := int(width / 0.8)
	var pitch := width / stripes
	var y := ROAD_TOP + 0.01
	for s in stripes:
		var p := at + side * (-width * 0.5 + pitch * (s + 0.5))
		geo.box("road_white", Vector3(p.x, y, p.y), Vector3(pitch * 0.55, 0.01, 2.0), 0, basis)
	var stop: Vector2 = at + dir * 1.6
	geo.box("road_white", Vector3(stop.x, y, stop.y), Vector3(width, 0.01, 0.3), 0, basis)


## True if a point lies on a road other than the given one (a junction).
static func _on_other_road(p: Vector2, layout: MapLayout, road: Dictionary, margin := 0.0) -> bool:
	for other in layout.roads:
		if other == road:
			continue
		var pts: PackedVector2Array = other.points
		for i in pts.size() - 1:
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])) < other.width * 0.5 + margin:
				return true
	return false


# ------------------------------------------------------------------ small pieces

## The older game's tree: a trunk and a rounded crown, stretched to a varied height.
static func tree(geo: GeoBatch, p: Vector2, rng: RandomNumberGenerator) -> void:
	if rng.randf() < DEAD_TREES:
		Clutter.place(geo, "dead_tree", Vector3(p.x, 0, p.y), rng.randf_range(0.0, 4.0), "", Vector3.ONE * rng.randf_range(0.9, 1.25))
		return
	var height := rng.randf_range(2.8, 3.8)
	var spread := rng.randf_range(1.9, 2.3)
	var spin := rng.randf_range(0.0, 4.0)
	Clutter.place(geo, "tree_trunk", Vector3(p.x, 0, p.y), spin, "", Vector3(1.2, height / Clutter.PROP_SCALE, 1.2))
	Clutter.place(geo, "tree_crown", Vector3(p.x, height - 0.2, p.y), spin, "", Vector3.ONE * spread)


## Cracks across the roads, and weeds pushing up along the kerbs. Paint only.
static func _cracks_and_weeds(geo: GeoBatch, layout: MapLayout, rng: RandomNumberGenerator) -> void:
	var tag := GeoBatch.tag
	GeoBatch.tag = "ground"
	for road in layout.roads:
		var pts: PackedVector2Array = road.points
		var half: float = road.width * 0.5
		for i in pts.size() - 1:
			var a := pts[i]
			var b := pts[i + 1]
			var dir := (b - a).normalized()
			var normal := Vector2(-dir.y, dir.x)
			for n in int(a.distance_to(b) / 7.0):
				var p := a.lerp(b, rng.randf()) + normal * rng.randf_range(-half * 0.7, half * 0.7)
				if not layout.inside(p, 2.0) or _on_other_road(p, layout, road, 3.0):
					continue
				# A zigzag of three strokes.
				var heading := rng.randf_range(0.0, TAU)
				for k in 3:
					var length := rng.randf_range(0.5, 1.2)
					var d := Vector2(cos(heading), sin(heading))
					var mid := p + d * length * 0.5
					geo.box("crack", Vector3(mid.x, ROAD_TOP + 0.012, mid.y), Vector3(0.06, 0.004, length), 0, Basis(Vector3.UP, atan2(d.x, d.y)))
					p += d * length
					heading += rng.randf_range(-1.0, 1.0)
			for n in int(a.distance_to(b) / 5.0):
				var side := 1.0 if rng.randf() < 0.5 else -1.0
				var w := a.lerp(b, rng.randf()) + normal * side * (half + KERB_WIDTH + 0.15)
				if layout.inside(w, 2.0) and not _on_other_road(w, layout, road, 1.0):
					for k in 3:
						var tuft := w + Vector2(rng.randf_range(-0.25, 0.25), rng.randf_range(-0.25, 0.25))
						geo.box("foliage", Vector3(tuft.x, 0.12, tuft.y), Vector3(0.06, rng.randf_range(0.15, 0.3), 0.06), 0, Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.4, 0.4)))
	GeoBatch.tag = tag


## Open ground inside the fence, where nothing was built or the town has been cleared: ruined walls,
## rubble, wrecks, barrels and dead trees, spread on a loose grid.
static func _wasteland(geo: GeoBatch, layout: MapLayout, rng: RandomNumberGenerator, taken: Array[Rect2]) -> void:
	const SPACING := 9.0
	const RUINS := ["ruin_wall", "ruin_wall", "rubble_pile", "rubble_pile", "debris", "dead_tree", "barrels", "car"]
	var r := layout.bounds
	var x := r.position.x + SPACING * 0.5
	while x < r.end.x:
		var z := r.position.y + SPACING * 0.5
		while z < r.end.y:
			var p := Vector2(x, z) + Vector2(rng.randf_range(-2.5, 2.5), rng.randf_range(-2.5, 2.5))
			var prefab: String = RUINS[rng.randi_range(0, RUINS.size() - 1)]
			var size := Clutter.size_of(prefab)
			var radius := maxf(size.x, size.y) * 0.5 + 0.8
			if rng.randf() < 0.7 and layout.inside(p, radius + 1.0) and _free_spot(p, radius, taken, layout) and not _on_other_road(p, layout, {}, radius + 1.0):
				taken.append(Rect2(p, Vector2.ZERO).grow(radius))
				var paint: String = ["#8a4f2e", "#3b3633", "#7a3e24", "#5d7392"][rng.randi_range(0, 3)] if prefab == "car" else ""
				Clutter.place(geo, prefab, Vector3(p.x, 0, p.y), rng.randf_range(0.0, 4.0), paint)
			z += SPACING
		x += SPACING


## This game's hinged door in a rewrite doorway: the plan gives the doorway's centre, the door hangs from its hinge.
static func _hang_door(root: Node3D, door: Dictionary) -> void:
	var w: float = door.get("w", DOOR_WIDTH)
	var node: Door = (NARROW_DOOR_SCENE if w < 1.3 else DOOR_SCENE).instantiate()
	root.add_child(node)
	var hinge: Vector3 = door.pos + (Vector3(-w * 0.5, 0, 0) if door.along_x else Vector3(0, 0, w * 0.5))
	var row: Array = MapMats.TABLE.get(door.paint, MapMats.TABLE["concrete"])
	node.setup(doors.size(), hinge, 0.0 if door.along_x else PI * 0.5, w, DOOR_HEIGHT, row[0])
	doors.append(node)


## Lettering floating just off a sign's face, centred on `pos` and shrunk to fit `width` (m).
static func _letter(root: Node3D, text: String, pos: Vector3, yaw: float, size: int, color: Color, width := 0.0) -> void:
	var label: Label3D = LETTERING.instantiate()
	var font := ThemeDB.fallback_font
	var natural := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * label.pixel_size
	if width > 0.0 and natural > width:
		size = int(size * width / natural)
	label.text = text
	label.font_size = size
	label.modulate = color
	label.position = pos
	label.rotation.y = yaw
	root.add_child(label)


# ------------------------------------------------------------------ cranes

## Beams between rooftops, each hanging from a yellow tower crane beside it. Returns the ground the
## cranes and their road closures take up.
static func _bridges(geo: GeoBatch, layout: MapLayout, rules: MapRules, rng: RandomNumberGenerator, keep_out: Array[Rect2]) -> Array[Rect2]:
	var spots: Array[Rect2] = []
	var jibs: Array = []  # [from, to] on the ground, for keeping cranes out of each other's way
	var index := 0
	for pair in layout.bridges:
		var a := layout.building(pair[0])
		var b := layout.building(pair[1])
		if a.is_empty() or b.is_empty() or not ProcGen.bridge_is_clear(layout, a, b, rules):
			continue
		var ends: Array = ProcGen.bridge_points(a, b, rules)
		var from: Vector3 = ends[0]
		var to: Vector3 = ends[1]
		var forward := (to - from).normalized()
		var side := Vector3.UP.cross(forward).normalized()
		var up := forward.cross(side).normalized()
		var length := from.distance_to(to)
		var mat := "wood" if rng.randf() < 0.5 else "metal"
		index += 1
		GeoBatch.tag = "crane%d" % index
		var thick := ProcGen.BEAM_THICKNESS
		geo.box(mat, (from + to) * 0.5 - up * thick * 0.5, Vector3(rules.bridge_width, thick, length), GeoBatch.FLOOR, Basis(side, up, forward))
		_crane(geo, layout, from, to, side, index, spots, jibs, keep_out)
	return spots


## Stands clear of buildings, parks, spawns and other cranes, and rises above everything its jib can reach.
static func _crane(geo: GeoBatch, layout: MapLayout, from: Vector3, to: Vector3, side: Vector3, index: int, spots: Array[Rect2], jibs: Array, keep_out: Array[Rect2]) -> void:
	var mid := (from + to) * 0.5
	var base := Vector3.ZERO
	var found := false
	for offset in [7.0, -7.0, 11.0, -11.0, 15.0, -15.0, 19.0, -19.0]:
		var p: Vector3 = mid + side * offset
		var foot := Rect2(Vector2(p.x, p.z), Vector2.ZERO).grow(2.0)
		var free := layout.encloses(foot, 2.0)
		for b in layout.buildings:
			free = free and not (b.rect as Rect2).intersects(foot)
		for park in layout.parks:
			free = free and not (park.rect as Rect2).intersects(foot)
		for s in layout.spawns:
			free = free and s.distance_to(Vector2(p.x, p.z)) > 4.0
		for other in spots:
			free = free and not other.intersects(foot)
		for other in keep_out:
			free = free and not other.intersects(foot)
		# This jib must miss other towers, and other jibs must miss this tower.
		var mid_2d := Vector2(mid.x, mid.z)
		var at := Vector2(p.x, p.z)
		var jib_a := at - (mid_2d - at).normalized() * 6.0
		var jib_b := mid_2d + (mid_2d - at).normalized() * 8.0
		for other in spots:
			free = free and not MapLayout._segment_hits_rect(jib_a, jib_b, other)
		for jib in jibs:
			free = free and not MapLayout._segment_hits_rect(jib[0], jib[1], foot)
			free = free and Geometry2D.segment_intersects_segment(jib_a, jib_b, jib[0], jib[1]) == null
		if free:
			base = Vector3(p.x, 0, p.z)
			spots.append(foot)
			jibs.append([jib_a, jib_b])
			found = true
			break
	if not found:
		return
	# Each crane gets its own working height, so jibs can never meet.
	var jib_reach := Vector3(mid.x, 0, mid.z).distance_to(base) + 8.0
	var top := maxf(from.y, to.y) + 6.0
	for b in layout.buildings:
		if (b.rect as Rect2).grow(jib_reach).has_point(Vector2(base.x, base.z)):
			top = maxf(top, ProcGen.height(b) + 3.0)
	top += index * 2.2
	# Footing, mast (10 m tall in its scene, stretched to this crane) and a set of braces every 1.4 m.
	Clutter.place(geo, "crane_footing", base, 0.0)
	Clutter.place(geo, "crane_mast", base + Vector3.UP, 0.0, "", Vector3(1, (top - 1.0) / 10.0, 1))
	var y := 2.0
	while y < top - 1.0:
		Clutter.place(geo, "crane_braces", base + Vector3.UP * y, 0.0)
		y += 1.4
	# Slewing unit, cab, jib towards the beam (the scene's -X), counter-jib with weights.
	var over_mid := Vector3(mid.x, top, mid.z)
	var jib_dir := (Vector3(mid.x, 0, mid.z) - base).normalized()
	Clutter.place(geo, "crane_top", base + Vector3.UP * top, atan2(jib_dir.z, -jib_dir.x) / (PI * 0.5))
	# A crane standing further off than the scene's jib reaches gets a longer jib.
	var reach := Vector3(mid.x, 0, mid.z).distance_to(base) + 2.0
	if reach > CRANE_JIB:
		var basis := Basis(Vector3.UP, atan2(jib_dir.x, jib_dir.z))
		geo.box("crane", base + jib_dir * (CRANE_JIB + reach) * 0.5 + Vector3.UP * (top + 0.6), Vector3(0.7, 0.7, reach - CRANE_JIB), 0, basis)
	# Trolley and hook over the beam, with slings down to it; a spare load on the other side.
	var hook := Vector3(mid.x, maxf(from.y, to.y) + 3.5, mid.z)
	Clutter.place(geo, "crane_trolley", over_mid + Vector3.UP * 0.1, 0.0)
	Clutter.place(geo, "crane_hook", hook, 0.0)
	_cable(geo, over_mid + Vector3.UP * 0.2, hook, 0.06)
	_cable(geo, hook, from.lerp(to, 0.2), 0.04)
	_cable(geo, hook, from.lerp(to, 0.8), 0.04)
	var spare := base - jib_dir * 4.5 + Vector3.UP * (top - 4.0)
	_cable(geo, Vector3(spare.x, top + 0.2, spare.z), spare + Vector3.UP * 0.4, 0.05)
	Clutter.place(geo, "crane_load_planks" if index % 2 == 0 else "crane_load_metal", spare, 0.0)
	_close_road_at(geo, layout, Vector2(base.x, base.z), spots)


## A thin line between two points: visual only.
static func _cable(geo: GeoBatch, a: Vector3, b: Vector3, thick: float) -> void:
	var y := (b - a).normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	geo.box("black", (a + b) * 0.5, Vector3(thick, a.distance_to(b), thick), 0, Basis(x, y, x.cross(y)))


## A crane standing on a road gets a line of cones across the road on each side of it.
static func _close_road_at(geo: GeoBatch, layout: MapLayout, at: Vector2, spots: Array[Rect2]) -> void:
	const CONES := 5
	const SET_BACK := 3.4
	for road in layout.roads:
		var pts: PackedVector2Array = road.points
		for i in pts.size() - 1:
			var on_road := Geometry2D.get_closest_point_to_segment(at, pts[i], pts[i + 1])
			if at.distance_to(on_road) > road.width * 0.5 + 2.0:
				continue
			var dir := (pts[i + 1] - pts[i]).normalized()
			var across := Vector2(-dir.y, dir.x)
			for side: float in [-1.0, 1.0]:
				for c in CONES:
					var share := (float(c) + 0.5) / CONES - 0.5
					var p: Vector2 = on_road + dir * side * SET_BACK + across * share * road.width
					Clutter.place(geo, "cone", Vector3(p.x, 0, p.y), 0)
			spots.append(Rect2(on_road, Vector2.ZERO).grow(SET_BACK + road.width * 0.5))
			return


# ------------------------------------------------------------------ street props

## At each junction: a stop sign or traffic light by the stop line, and a street name sign.
static func _junction_signs(geo: GeoBatch, layout: MapLayout, taken: Array[Rect2], rng: RandomNumberGenerator, root: Node3D) -> void:
	for junction in layout.junctions:
		var dir: Vector2 = junction.dir
		var angle := atan2(dir.x, dir.y)
		var right := Vector2(cos(angle), -sin(angle))
		var half: float = junction.road.width * 0.5
		var back: float = junction.through.width * 0.5
		var stop_at: Vector2 = junction.pos + dir * (back + 3.4) - right * (half + 0.9)
		if _free_spot(stop_at, 0.5, taken, layout) and not _on_other_road(stop_at, layout, junction.road, 0.0):
			taken.append(Rect2(stop_at, Vector2.ZERO).grow(0.7))
			if rng.randf() < 0.5:
				# Its arm has to reach out over the road.
				var arm_turn := 1.0 if Clutter.reach_sign("traffic_light") > 0.0 else -1.0
				Clutter.place(geo, "traffic_light", Vector3(stop_at.x, 0, stop_at.y), angle / (PI * 0.5) + arm_turn)
			else:
				Clutter.place(geo, "stop_sign", Vector3(stop_at.x, 0, stop_at.y), angle / (PI * 0.5))
				var face := stop_at + dir * 0.08
				_letter(root, "STOP", Vector3(face.x, 2.42 * Clutter.PROP_SCALE, face.y), angle, 36, Color.WHITE, 0.58)
		var name_at: Vector2 = junction.pos + dir * (back + 0.9) + right * (half + 0.9)
		if _free_spot(name_at, 0.5, taken, layout) and not _on_other_road(name_at, layout, junction.road, 0.0):
			taken.append(Rect2(name_at, Vector2.ZERO).grow(0.7))
			Clutter.place(geo, "street_sign", Vector3(name_at.x, 0, name_at.y), angle / (PI * 0.5))
			var front := name_at + dir * 0.04
			var rear := name_at - dir * 0.04
			var board_y := 2.94 * Clutter.PROP_SCALE
			_letter(root, str(junction.road.name), Vector3(front.x, board_y, front.y), angle, 22, Color.WHITE, 1.45)
			_letter(root, str(junction.road.name), Vector3(rear.x, board_y, rear.y), angle + PI, 22, Color.WHITE, 1.45)


## Lamps, parked cars, street trees and everyday street furniture along every road.
static func _street_props(geo: GeoBatch, layout: MapLayout, rules: MapRules, rng: RandomNumberGenerator, root: Node3D, keep_out: Array[Rect2], lamp_lights: Array[Vector3]) -> void:
	var taken: Array[Rect2] = layout.keep_clear(rules.keep_clear_radius)
	taken.append_array(keep_out)
	for b in layout.buildings:
		taken.append((b.rect as Rect2).grow(1.0))
	for park in layout.parks:
		taken.append((park.rect as Rect2).grow(0.5))
	_junction_signs(geo, layout, taken, rng, root)
	const FURNITURE := ["trash_can", "hydrant_news", "mailbox", "bench", "parking_meter", "bus_stop", "phone_booth", "cone", "bollards", "rubble_pile", "debris", "debris", "rubble_pile", "barrels", "bench", "hydrant_news", "trash_can"]
	# Faded paint, rust and burnt-out shells.
	const CAR_COLORS := ["#a5605a", "#5d7392", "#b8b2a6", "#5e7d63", "#5f8c88", "#76618c", "#b47c48", "#3a3d46", "#8a4f2e", "#3b3633", "#7a3e24"]
	for road in layout.roads:
		var pts: PackedVector2Array = road.points
		var half: float = road.width * 0.5
		for i in pts.size() - 1:
			var a := pts[i]
			var b := pts[i + 1]
			var length := a.distance_to(b)
			var dir := (b - a) / length
			var normal := Vector2(-dir.y, dir.x)
			var road_turns := atan2(dir.x, dir.y) / (PI * 0.5)
			var count := int(length / rules.lamp_spacing)
			for n in count:
				var p: Vector2 = a.lerp(b, (n + 0.5) / maxf(count, 1)) + normal * (half + 1.0) * (1.0 if n % 2 == 0 else -1.0)
				if _free_spot(p, 0.5, taken, layout) and not _on_other_road(p, layout, road):
					taken.append(Rect2(p, Vector2.ZERO).grow(1.0))
					# The old lamp's head leans along one axis: turn it out over the road.
					var out_dir := normal if n % 2 != 0 else -normal
					var lean := Clutter.reach_sign("lamp_post")
					Clutter.place(geo, "lamp_post", Vector3(p.x, 0, p.y), atan2(out_dir.x * lean, out_dir.y * lean) / (PI * 0.5))
					if rng.randf() < LIT_LAMPS:
						lamp_lights.append(Vector3(p.x + out_dir.x, 6.4, p.y + out_dir.y))
			# Parked cars along the kerb, clear of the crossings.
			for n in int(length / 13.0):
				var side := 1.0 if rng.randf() < 0.5 else -1.0
				var p: Vector2 = a.lerp(b, rng.randf_range(0.1, 0.9)) + normal * side * (half - 1.15)
				var kind := rng.randf()
				var prefab := "car"
				if kind < 0.1:
					prefab = "bus"
				elif kind < 0.25:
					prefab = "taxi"
				elif kind < 0.4:
					prefab = "van"
				var radius := Clutter.size_of(prefab).y * 0.5 + 0.2
				if _free_spot(p, radius, taken, layout) and rng.randf() < 0.8 and not _on_other_road(p, layout, road, radius + 2.5):
					taken.append(Rect2(p, Vector2.ZERO).grow(radius))
					# Abandoned where they stopped, skewed across the kerb.
					var turned := road_turns + (2.0 if side < 0.0 else 0.0) + rng.randf_range(-0.25, 0.25)
					Clutter.place(geo, prefab, Vector3(p.x, 0, p.y), turned, CAR_COLORS[rng.randi_range(0, CAR_COLORS.size() - 1)])
			# Street trees and furniture on the pavement.
			for n in int(length / 3.5):
				var side := 1.0 if rng.randf() < 0.5 else -1.0
				var along: Vector2 = a.lerp(b, rng.randf_range(0.04, 0.96))
				var prefab: String = "street_tree" if rng.randf() < 0.3 else FURNITURE[rng.randi_range(0, FURNITURE.size() - 1)]
				var radius := 1.9 if prefab == "street_tree" else Clutter.size_of(prefab).length() * 0.5
				var p := along + normal * side * (half + 0.5 + radius)
				if _free_spot(p, radius, taken, layout) and not _on_other_road(p, layout, road, 0.5):
					taken.append(Rect2(p, Vector2.ZERO).grow(radius))
					# Backs to the buildings, faces to the road. Benches the other way: nobody sits facing traffic.
					var toward_road := side > 0.0 if prefab != "bench" else side < 0.0
					Clutter.place(geo, prefab, Vector3(p.x, 0, p.y), road_turns + (3.0 if toward_road else 1.0))
	_alley_clutter(geo, layout, rng, keep_out)
	_cracks_and_weeds(geo, layout, rng)
	_wasteland(geo, layout, rng, taken)
	# Billboards along the fence, facing in.
	var c := layout.bounds.get_center()
	var edge := layout.radius - 1.0 if layout.radius > 0.0 else minf(layout.bounds.size.x, layout.bounds.size.y) * 0.5 - 1.0
	var boards := [[c + Vector2(0, -edge), 0], [c + Vector2(0, edge), 2], [c + Vector2(-edge, 0), 1], [c + Vector2(edge, 0), 3]]
	for board in boards:
		var p: Vector2 = board[0] + Vector2(rng.randf_range(-20.0, 20.0), 0) * (1.0 if board[1] % 2 == 0 else 0.0) + Vector2(0, rng.randf_range(-20.0, 20.0)) * (1.0 if board[1] % 2 == 1 else 0.0)
		var size := Vector2(5.2, 0.5) if board[1] % 2 == 0 else Vector2(0.5, 5.2)
		var foot := Rect2(p - size * 0.5, size)
		var free := layout.encloses(foot)
		for other in taken:
			free = free and not foot.intersects(other)
		if free and not _on_other_road(p, layout, {}, 1.0):
			taken.append(foot)
			Clutter.place(geo, "billboard", Vector3(p.x, 0, p.y), board[1])
	_lamp_lights(root, lamp_lights)


## Dumpsters and crates belong in alleys: the gaps between two facing buildings with no road through.
static func _alley_clutter(geo: GeoBatch, layout: MapLayout, rng: RandomNumberGenerator, keep_out: Array[Rect2]) -> void:
	const CHANCE := 0.75
	const MAX_ALLEY := 10.0
	const MIN_ALLEY := 2.6
	const ALLEY_PROPS := 2
	var taken: Array[Rect2] = layout.keep_clear(2.2)
	taken.append_array(keep_out)
	var buildings: Array = layout.buildings
	for b in buildings:
		taken.append(b.rect)  # a third building can stand in the gap between two others
	for i in buildings.size():
		for j in range(i + 1, buildings.size()):
			var alley := _alley_between(buildings[i].rect, buildings[j].rect)
			var gap := minf(alley.size.x, alley.size.y)
			if gap < MIN_ALLEY or gap > MAX_ALLEY or maxf(alley.size.x, alley.size.y) < 3.0 or rng.randf() > CHANCE:
				continue
			var on_road := false
			for road in layout.roads:
				on_road = on_road or MapLayout._road_hits(road, alley)
			if on_road:
				continue
			for n in ALLEY_PROPS:
				_alley_prop(geo, layout, alley, rng, taken)


## One prop backed against either wall of an alley, leaving the rest of it to run through.
static func _alley_prop(geo: GeoBatch, layout: MapLayout, alley: Rect2, rng: RandomNumberGenerator, taken: Array[Rect2]) -> void:
	const PROPS := ["dumpster", "dumpster", "crates", "trash_bag", "pallet_stack", "barrels"]
	var prefab: String = PROPS[rng.randi_range(0, PROPS.size() - 1)]
	var runs_along_z := alley.size.y > alley.size.x
	var size := Clutter.size_of(prefab)
	var foot_size := Vector2(size.y, size.x) if runs_along_z else size
	var to_far_wall := rng.randf() < 0.5
	var along := rng.randf_range(0.2, 0.8)
	var p := Vector2.ZERO
	if runs_along_z:
		p.x = alley.end.x - foot_size.x * 0.5 - 0.05 if to_far_wall else alley.position.x + foot_size.x * 0.5 + 0.05
		p.y = lerpf(alley.position.y, alley.end.y, along)
	else:
		p.x = lerpf(alley.position.x, alley.end.x, along)
		p.y = alley.end.y - foot_size.y * 0.5 - 0.05 if to_far_wall else alley.position.y + foot_size.y * 0.5 + 0.05
	var foot := Rect2(p - foot_size * 0.5, foot_size)
	if alley.encloses(foot) and _free_rect(foot.grow(0.3), taken, layout):
		taken.append(foot)
		Clutter.place(geo, prefab, Vector3(p.x, 0, p.y), 1.0 if runs_along_z else 0.0)


## The space between two buildings that face each other, or an empty rect if they don't.
static func _alley_between(a: Rect2, b: Rect2) -> Rect2:
	var x0 := maxf(a.position.x, b.position.x)
	var x1 := minf(a.end.x, b.end.x)
	var z0 := maxf(a.position.y, b.position.y)
	var z1 := minf(a.end.y, b.end.y)
	if x1 > x0 and z1 < z0:
		return Rect2(x0, z1, x1 - x0, z0 - z1)
	if z1 > z0 and x1 < x0:
		return Rect2(x1, z0, x0 - x1, z1 - z0)
	return Rect2()


static func _free_spot(p: Vector2, radius: float, taken: Array[Rect2], layout: MapLayout) -> bool:
	return _free_rect(Rect2(p, Vector2.ZERO).grow(radius), taken, layout)


static func _free_rect(foot: Rect2, taken: Array[Rect2], layout: MapLayout) -> bool:
	if not layout.encloses(foot, 1.0):
		return false
	for other in taken:
		if foot.intersects(other):
			return false
	return true


# ------------------------------------------------------------------ lights

## Street lamps only shine at night: Game's time of day switches this group on.
static func _lamp_lights(root: Node3D, positions: Array[Vector3]) -> void:
	var holder := Node3D.new()
	holder.name = "StreetLights"
	root.add_child(holder)
	for p in positions:
		var light: OmniLight3D = STREET_LIGHT.instantiate()
		light.position = p
		holder.add_child(light)


## One warm light under each ceiling lamp (World applies the Interior lights setting).
static func _interior_lights(root: Node3D, positions: Array[Vector3], rules: MapRules) -> void:
	var holder := Node3D.new()
	holder.name = "InteriorLights"
	root.add_child(holder)
	var step := maxf(float(positions.size()) / rules.max_interior_lights, 1.0)
	var i := 0.0
	while i < positions.size():
		var light: OmniLight3D = INTERIOR_LIGHT.instantiate()
		light.position = positions[int(i)]
		holder.add_child(light)
		lights.append(light)
		i += step


# ------------------------------------------------------------------ boundary and beyond

## How far the fence stands from the middle of the map.
static func _fence_radius(layout: MapLayout, rules: MapRules) -> float:
	if layout.radius > 0.0:
		return layout.radius + rules.fence_margin
	return layout.bounds.size.length() * 0.5 + rules.fence_margin


## The fence line as a polygon: a circle with corners every few metres.
static func _fence_outline(layout: MapLayout, rules: MapRules) -> PackedVector2Array:
	var c := layout.bounds.get_center()
	var r := _fence_radius(layout, rules)
	var out := PackedVector2Array()
	var sides := maxi(int(TAU * r / FENCE_PANEL), 24)
	for k in sides:
		var a := TAU * k / sides
		out.append(c + Vector2(cos(a), sin(a)) * r)
	return out


## Solid green site hoarding round the map with posts, open where a road leaves through a barrier
## gate, plus a tall invisible wall no ability can pass.
static func _fence(geo: GeoBatch, layout: MapLayout, rules: MapRules, exits: Array) -> void:
	var ring := _fence_outline(layout, rules)
	var c := layout.bounds.get_center()
	for k in ring.size():
		var a := ring[k]
		var b := ring[(k + 1) % ring.size()]
		var mid := (a + b) * 0.5
		var along := (b - a).normalized()
		var out := (mid - c).normalized()
		var basis := Basis(Vector3.UP, atan2(-along.y, along.x))
		# 2 m thick: the sniper pierces up to 1 m of wall. Overlapping a little, so there's no gap.
		geo.box("", Vector3(mid.x + out.x, rules.boundary_height * 0.5 - 1.0, mid.y + out.y), Vector3(a.distance_to(b) + 1.0, rules.boundary_height, 2.0), GeoBatch.BOUNDARY, basis)
		var open := false
		for e in exits:
			open = open or Geometry2D.get_closest_point_to_segment(e.at, a, b).distance_to(e.at) < e.width * 0.5 + 0.2
		if not open:
			_fence_run(geo, a, b, rules)
	for e in exits:
		var fd: Vector2 = e.fence_dir
		var stretch := Vector3(e.width / (Clutter.size_of("road_gate").x), 1.0, 1.0)
		Clutter.place(geo, "road_gate", Vector3(e.at.x, 0, e.at.y), atan2(-fd.y, fd.x) / (PI * 0.5), "", stretch)


static func _fence_run(geo: GeoBatch, a: Vector2, b: Vector2, rules: MapRules) -> void:
	var mid := (a + b) * 0.5
	var along := (b - a).normalized()
	var basis := Basis(Vector3.UP, atan2(-along.y, along.x))
	var h := rules.fence_height
	geo.box("fence", Vector3(mid.x, h * 0.5, mid.y), Vector3(a.distance_to(b) + 0.06, h, 0.12), 0, basis)
	geo.box("fence_post", Vector3(a.x, h * 0.5 + 0.1, a.y), Vector3(0.22, h + 0.2, 0.22), 0, basis)


## Where roads run into the fence: {at: on the fence line, dir: outward along the road, away: straight
## out from the fence, fence_dir, width, from: the road's end}
static func _road_exits(layout: MapLayout, rules: MapRules) -> Array:
	var out := []
	var c := layout.bounds.get_center()
	var r := _fence_radius(layout, rules)
	for road in layout.roads:
		var pts: PackedVector2Array = road.points
		for pair in [[pts[0], pts[1]], [pts[pts.size() - 1], pts[pts.size() - 2]]]:
			var end: Vector2 = pair[0]
			if layout.inside(end, 4.0):
				continue
			var dir: Vector2 = (end - pair[1]).normalized()
			# Runs on along the road to the fence: where end + t dir meets the circle.
			var rel := end - c
			var qb := 2.0 * rel.dot(dir)
			var disc := qb * qb - 4.0 * (rel.dot(rel) - r * r)
			var t := (-qb + sqrt(maxf(disc, 0.0))) * 0.5
			var at := end + dir * maxf(t, 0.0)
			var away := (at - c).normalized()
			out.append({"at": at, "dir": dir, "away": away, "fence_dir": Vector2(-away.y, away.x), "width": road.width, "from": end})
	return out


## Beyond the fence each road carries on across the grass to the horizon. Out of reach.
static func _outbound_roads(geo: GeoBatch, exits: Array) -> void:
	for e in exits:
		var at: Vector2 = e.at
		var away: Vector2 = e.away
		# Up to the gate along the road, then straight out, so no two cross on the grass.
		var mid_in := ((e.from as Vector2) + at) * 0.5
		var length := (e.from as Vector2).distance_to(at)
		geo.box("road_far", Vector3(mid_in.x, 0.01, mid_in.y), Vector3(e.width, 0.02, length), 0, Basis(Vector3.UP, atan2(e.dir.x, e.dir.y)))
		geo.cylinder("road_far", Vector3(at.x, 0.01, at.y), e.width * 0.5, e.width * 0.5, 0.02, 0, Basis.IDENTITY, 16)
		var mid := at + away * FAR_REACH * 0.5
		var basis := Basis(Vector3.UP, atan2(away.x, away.y))
		geo.box("road_far", Vector3(mid.x, 0.01, mid.y), Vector3(e.width, 0.02, FAR_REACH), 0, basis)
		for n in 45:
			var p := at + away * (4.0 + n * 7.0)
			geo.box("road_line", Vector3(p.x, 0.03, p.y), Vector3(0.14, 0.02, 2.4), 0, basis)


## Grass out to the horizon, just under the map's ground and the roads.
static func _far_ground(root: Node3D) -> void:
	root.add_child(FAR_GROUND.instantiate())
