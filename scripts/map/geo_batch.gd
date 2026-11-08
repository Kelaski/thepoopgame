class_name GeoBatch extends RefCounted
## Collects shapes, then bakes them into one mesh per material and one static body per collision
## layer. A building stays a handful of nodes however many parts it has.

const WALL := 2
const FLOOR := 1
const BOUNDARY := 16

const FACES := [
	[Vector3.RIGHT, Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(1, 1, 1), Vector3(1, -1, 1)],
	[Vector3.LEFT, Vector3(-1, -1, 1), Vector3(-1, 1, 1), Vector3(-1, 1, -1), Vector3(-1, -1, -1)],
	[Vector3.UP, Vector3(-1, 1, -1), Vector3(-1, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, -1)],
	[Vector3.DOWN, Vector3(-1, -1, 1), Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, -1, 1)],
	[Vector3.BACK, Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(-1, 1, 1), Vector3(-1, -1, 1)],
	[Vector3.FORWARD, Vector3(-1, -1, -1), Vector3(-1, 1, -1), Vector3(1, 1, -1), Vector3(1, -1, -1)],
]

## Test hook: when set to an Array, every shape is also recorded as [tag, center, size, basis, mat].
static var recorder: Variant = null
## Which object shapes belong to. Parts of one object may touch each other; different objects may not.
static var tag := ""

var _surfaces := {}  # material key -> {v: PackedVector3Array, n: PackedVector3Array, i: PackedInt32Array}
var _shapes := {}    # layer -> Array of [size, Transform3D]
var _mesh_faces := {}  # layer -> PackedVector3Array: every mesh shape's triangles, placed
var _hulls := {}       # layer -> Array of PackedVector3Array: each convex shape's points, placed
var box_count := 0


## layer: WALL, FLOOR, BOUNDARY, or 0 for visual only. An empty mat means invisible collision.
static var _glass: StandardMaterial3D

func box(mat: String, center: Vector3, size: Vector3, layer := WALL, basis := Basis.IDENTITY) -> void:
	_register(mat, center, size, layer, basis)
	if mat == "":
		return
	var s := _surface(mat)
	var half := size * 0.5
	for face in FACES:
		var normal: Vector3 = basis * face[0]
		for c in range(1, 5):
			s.v.append(center + basis * (face[c] * half))
			s.n.append(normal)
		var base: int = s.v.size() - 4
		# Godot treats clockwise triangles as front-facing.
		for offset in [0, 2, 1, 0, 3, 2]:
			s.i.append(base + offset)


## A box with chamfered edges, so props catch the light like soft cartoon shapes.
func rounded(mat: String, center: Vector3, size: Vector3, bevel: float, layer := WALL, basis := Basis.IDENTITY) -> void:
	_register(mat, center, size, layer, basis)
	var s := _surface(mat)
	var h := size * 0.5
	var i := h - Vector3.ONE * minf(bevel, minf(h.x, minf(h.y, h.z)) * 0.8)
	# Each corner has three points, one on each face that meets there.
	var point := func(sx: int, sy: int, sz: int, axis: int) -> Vector3:
		var p := Vector3(sx * (h.x if axis == 0 else i.x), sy * (h.y if axis == 1 else i.y), sz * (h.z if axis == 2 else i.z))
		return center + basis * p
	for axis in 3:
		for side: int in [-1, 1]:
			var a: int = (axis + 1) % 3
			var b: int = (axis + 2) % 3
			var signs := [[-1, -1], [1, -1], [1, 1], [-1, 1]]
			var quad: Array[Vector3] = []
			for pair in signs:
				var v := [0, 0, 0]
				v[axis] = side
				v[a] = pair[0]
				v[b] = pair[1]
				quad.append(point.call(v[0], v[1], v[2], axis))
			_flat_quad(s, quad, center)
	for axis in 3:
		var a: int = (axis + 1) % 3
		var b: int = (axis + 2) % 3
		for sa: int in [-1, 1]:
			for sb: int in [-1, 1]:
				var low := [0, 0, 0]
				var high := [0, 0, 0]
				low[axis] = -1
				high[axis] = 1
				low[a] = sa
				low[b] = sb
				high[a] = sa
				high[b] = sb
				_flat_quad(s, [point.call(low[0], low[1], low[2], a), point.call(high[0], high[1], high[2], a), point.call(high[0], high[1], high[2], b), point.call(low[0], low[1], low[2], b)], center)
	for sx: int in [-1, 1]:
		for sy: int in [-1, 1]:
			for sz: int in [-1, 1]:
				_flat_tri(s, point.call(sx, sy, sz, 0), point.call(sx, sy, sz, 1), point.call(sx, sy, sz, 2), center)


## A round post, optionally tapered. Its local Y is its length. Collides as an inscribed box.
func cylinder(mat: String, center: Vector3, radius_bottom: float, radius_top: float, length: float, layer := WALL, basis := Basis.IDENTITY, sides := 10) -> void:
	var fit := maxf(radius_bottom, radius_top) * 1.5
	_register(mat, center, Vector3(fit, length, fit), layer, basis)
	var s := _surface(mat)
	var half := length * 0.5
	var slope := (radius_bottom - radius_top) / maxf(length, 0.001)
	for k in sides:
		var a0 := TAU * k / sides
		var a1 := TAU * (k + 1) / sides
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var n0: Vector3 = basis * (d0 + Vector3.UP * slope).normalized()
		var n1: Vector3 = basis * (d1 + Vector3.UP * slope).normalized()
		var b0 := center + basis * (d0 * radius_bottom + Vector3.DOWN * half)
		var b1 := center + basis * (d1 * radius_bottom + Vector3.DOWN * half)
		var t0 := center + basis * (d0 * radius_top + Vector3.UP * half)
		var t1 := center + basis * (d1 * radius_top + Vector3.UP * half)
		_tri(s, b0, t0, t1, n0, n0, n1)
		_tri(s, b0, t1, b1, n0, n1, n1)
		var up := basis * Vector3.UP
		_tri(s, center + up * half, t0, t1, up, up, up)
		_tri(s, center - up * half, b0, b1, -up, -up, -up)


## A smooth squashable ball: foliage, heads, bushes, rocks. Collides as an inscribed box.
func ball(mat: String, center: Vector3, size: Vector3, layer := 0, basis := Basis.IDENTITY) -> void:
	_register(mat, center, size * 0.7, layer, basis)
	var s := _surface(mat)
	const RINGS := 6
	const SEGMENTS := 10
	var half := size * 0.5
	var at := func(r: int, k: int) -> Vector3:
		var lat := PI * r / RINGS
		var lon := TAU * k / SEGMENTS
		return Vector3(sin(lat) * cos(lon), cos(lat), sin(lat) * sin(lon))
	for r in RINGS:
		for k in SEGMENTS:
			var d00: Vector3 = at.call(r, k)
			var d01: Vector3 = at.call(r, k + 1)
			var d10: Vector3 = at.call(r + 1, k)
			var d11: Vector3 = at.call(r + 1, k + 1)
			var pts: Array[Vector3] = []
			var norms: Array[Vector3] = []
			for d: Vector3 in [d00, d01, d11, d10]:
				pts.append(center + basis * (d * half))
				norms.append((basis * (d / half)).normalized())
			if r > 0:
				_tri(s, pts[0], pts[1], pts[2], norms[0], norms[1], norms[2])
			if r < RINGS - 1:
				_tri(s, pts[0], pts[2], pts[3], norms[0], norms[2], norms[3])


## Bakes one part of an imported prop. Its colour goes in the vertices, so a whole city of props
## shares one material and stays one draw call per building.
func add_part(part: Dictionary, xform: Transform3D, color: Color, glow: bool) -> void:
	var s := _surface("vc_glass" if part.see_through else ("vc_glow" if glow else "vc"))
	if not s.has("c"):
		s["c"] = PackedColorArray()
	var base: int = s.v.size()
	var normal_basis := xform.basis.inverse().transposed()
	var verts: PackedVector3Array = part.v
	var norms: PackedVector3Array = part.n
	var linear := color.srgb_to_linear()
	for k in verts.size():
		s.v.append(xform * verts[k])
		s.n.append((normal_basis * norms[k]).normalized())
		s.c.append(linear)
	for index in part.i:
		s.i.append(base + index)


## A collision box from an imported prop.
## Exact collision from a prop's mesh shape. All of a layer's triangles bake into one shape.
func add_mesh_shape(faces: PackedVector3Array, xform: Transform3D, layer: int) -> void:
	if not _mesh_faces.has(layer):
		_mesh_faces[layer] = PackedVector3Array()
	_mesh_faces[layer].append_array(xform * faces)


func add_hull_shape(points: PackedVector3Array, xform: Transform3D, layer: int) -> void:
	if not _hulls.has(layer):
		_hulls[layer] = []
	_hulls[layer].append(xform * points)


func add_shape(center: Vector3, size: Vector3, basis: Basis, layer: int) -> void:
	_register("", center, size, layer, basis)


## A flat-topped strip between edge a0-a1 and edge b0-b1, such as a stretch of road or kerb. It has side
## faces when y_low is under y_top. Visual only.
func strip(mat: String, a0: Vector2, a1: Vector2, b0: Vector2, b1: Vector2, y_low: float, y_top: float) -> void:
	var s := _surface(mat)
	var corner := func(p: Vector2, y: float) -> Vector3: return Vector3(p.x, y, p.y)
	var mid := (a0 + a1 + b0 + b1) * 0.25
	var below := Vector3(mid.x, y_top - 1.0, mid.y)
	_flat_quad(s, [corner.call(a0, y_top), corner.call(a1, y_top), corner.call(b1, y_top), corner.call(b0, y_top)], below)
	if y_low < y_top:
		var inside := Vector3(mid.x, (y_low + y_top) * 0.5, mid.y)
		_flat_quad(s, [corner.call(a0, y_low), corner.call(a1, y_low), corner.call(a1, y_top), corner.call(a0, y_top)], inside)
		_flat_quad(s, [corner.call(b0, y_low), corner.call(b1, y_low), corner.call(b1, y_top), corner.call(b0, y_top)], inside)


## Test hook: every triangle's vertices and stored normal, as [a, b, c, normal].
func triangles(mat: String) -> Array:
	var s: Dictionary = _surfaces[mat]
	var out := []
	for i in range(0, s.i.size(), 3):
		out.append([s.v[s.i[i]], s.v[s.i[i + 1]], s.v[s.i[i + 2]], s.n[s.i[i]]])
	return out


## Bakes everything under parent. Safe to call in headless mode.
func bake(parent: Node3D, node_name: String) -> void:
	var root := Node3D.new()
	root.name = node_name
	parent.add_child(root)
	for key in _surfaces:
		var s: Dictionary = _surfaces[key]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = s.v
		arrays[Mesh.ARRAY_NORMAL] = s.n
		arrays[Mesh.ARRAY_INDEX] = s.i
		if s.has("c"):
			arrays[Mesh.ARRAY_COLOR] = s.c
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, _glass_material() if key == "vc_glass" else MapMats.get_mat(key))
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		if key == "vc_glass":
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	var shared := {}
	var bodies := {}
	var body_for := func(layer: int) -> StaticBody3D:
		if not bodies.has(layer):
			var body := StaticBody3D.new()
			body.collision_layer = layer
			body.collision_mask = 0
			root.add_child(body)
			bodies[layer] = body
		return bodies[layer]
	for layer in _shapes:
		var body: StaticBody3D = body_for.call(layer)
		# One owner per box: each holds its own transform, while equal sizes share one shape.
		for entry in _shapes[layer]:
			var size: Vector3 = entry[0]
			if not shared.has(size):
				var shape := BoxShape3D.new()
				shape.size = size
				shared[size] = shape
			var own := body.create_shape_owner(body)
			body.shape_owner_add_shape(own, shared[size])
			body.shape_owner_set_transform(own, entry[1])
	for layer in _mesh_faces:
		var trimesh := ConcavePolygonShape3D.new()
		trimesh.set_faces(_mesh_faces[layer])
		trimesh.backface_collision = true
		var body: StaticBody3D = body_for.call(layer)
		body.shape_owner_add_shape(body.create_shape_owner(body), trimesh)
	for layer in _hulls:
		var body: StaticBody3D = body_for.call(layer)
		for points: PackedVector3Array in _hulls[layer]:
			var hull := ConvexPolygonShape3D.new()
			hull.points = points
			body.shape_owner_add_shape(body.create_shape_owner(body), hull)
	_surfaces.clear()
	_shapes.clear()
	_mesh_faces.clear()
	_hulls.clear()


## See-through prop parts (glass, water spray) keep their colour and alpha in the vertices.
static func _glass_material() -> StandardMaterial3D:
	if _glass == null:
		_glass = StandardMaterial3D.new()
		_glass.vertex_color_use_as_albedo = true
		_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glass.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		_glass.specular_mode = BaseMaterial3D.SPECULAR_TOON
		_glass.roughness = 0.2
	return _glass


func _register(mat: String, center: Vector3, size: Vector3, layer: int, basis: Basis) -> void:
	box_count += 1
	if recorder != null:
		recorder.append([tag, center, size, basis, mat])
	if layer != 0:
		if not _shapes.has(layer):
			_shapes[layer] = []
		_shapes[layer].append([size, Transform3D(basis, center)])


func _surface(mat: String) -> Dictionary:
	if not _surfaces.has(mat):
		_surfaces[mat] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "i": PackedInt32Array()}
	return _surfaces[mat]


## Adds one triangle, wound clockwise as seen from the side its normals face.
func _tri(s: Dictionary, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	var base: int = s.v.size()
	var flip := (b - a).cross(c - a).dot(na + nb + nc) > 0.0
	s.v.append_array([a, c, b] if flip else [a, b, c])
	s.n.append_array([na, nc, nb] if flip else [na, nb, nc])
	s.i.append_array([base, base + 1, base + 2])


func _flat_tri(s: Dictionary, a: Vector3, b: Vector3, c: Vector3, center: Vector3) -> void:
	var n := (b - a).cross(c - a).normalized()
	if n.dot((a + b + c) / 3.0 - center) < 0.0:
		n = -n
	_tri(s, a, b, c, n, n, n)


func _flat_quad(s: Dictionary, q: Array, center: Vector3) -> void:
	_flat_tri(s, q[0], q[1], q[2], center)
	_flat_tri(s, q[0], q[2], q[3], center)
