class_name PropLibrary
## Reads the prop scenes in assets/ once, into plain mesh and collision data, so they can be baked
## into a building's batched meshes instead of adding dozens of nodes per prop.

static var _cache := {}


## {parts: [{v, n, i, color, glow, slot, lighten}], shapes: [[size, Transform3D, layer]], meshes: [[faces, layer]], hulls: [[points, layer]], half: Vector2, top: float}
static func get_prop(path: String) -> Dictionary:
	if not _cache.has(path):
		_cache[path] = _read(path)
	return _cache[path]


static func _read(path: String) -> Dictionary:
	var scene: PackedScene = load(path)
	var root: Node = scene.instantiate()
	var out := {"parts": [], "shapes": [], "meshes": [], "hulls": [], "half": Vector2.ZERO, "top": 0.0}
	_walk(root, Transform3D.IDENTITY, out)
	root.free()
	return out


static func _walk(node: Node, parent: Transform3D, out: Dictionary) -> void:
	var xform := parent
	if node is Node3D:
		xform = parent * node.transform
		if node is MeshInstance3D and node.mesh != null and node.visible:
			_add_mesh(node, node.mesh, xform, out)
		elif node is MultiMeshInstance3D and node.multimesh != null and node.multimesh.mesh != null and node.visible:
			for k in node.multimesh.instance_count:
				_add_mesh(node, node.multimesh.mesh, xform * node.multimesh.get_instance_transform(k), out)
		elif node is CollisionShape3D and node.shape != null and not node.disabled:
			_add_shape(node.shape, xform, out, GeoMask.BOUNCE if node.get_parent().get("collision_layer") == GeoMask.BOUNCE else GeoMask.WALL | GeoMask.PROP)
	for child in node.get_children():
		_walk(child, xform, out)


static func _add_mesh(mi: GeometryInstance3D, mesh: Mesh, xform: Transform3D, out: Dictionary) -> void:
	for surface in mesh.get_surface_count():
		var primitive: int = mesh.surface_get_primitive_type(surface) if mesh is ArrayMesh else Mesh.PRIMITIVE_TRIANGLES
		if primitive != Mesh.PRIMITIVE_TRIANGLES and primitive != Mesh.PRIMITIVE_TRIANGLE_STRIP:
			continue  # lines and points have nothing to bake
		var arrays: Array = mesh.surface_get_arrays(surface)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var order := _indices(arrays, verts.size(), primitive)
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else _flat_normals(verts, order)
		var v := PackedVector3Array()
		var n := PackedVector3Array()
		v.resize(verts.size())
		n.resize(verts.size())
		var normal_basis := xform.basis.inverse().transposed()
		for k in verts.size():
			var p: Vector3 = xform * verts[k]
			v[k] = p
			n[k] = (normal_basis * norms[k]).normalized()
			out.half.x = maxf(out.half.x, absf(p.x))
			out.half.y = maxf(out.half.y, absf(p.z))
			out.top = maxf(out.top, p.y)
		var material: Material = mi.get_active_material(surface) if mi is MeshInstance3D else mi.material_override
		if material == null:
			material = mesh.surface_get_material(surface)
		var color := Color.WHITE
		if material is StandardMaterial3D:
			color = material.albedo_color
		out.parts.append({"v": v, "n": n, "i": order, "color": color,
			"glow": mi.get_meta("glow", false) or (material is StandardMaterial3D and material.emission_enabled),
			"see_through": material is BaseMaterial3D and material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED,
			"slot": mi.get_meta("slot", ""), "lighten": float(mi.get_meta("slot_lighten", 0.0))})


## Triangle lists, in order if the mesh has no index list. Strips become lists.
static func _indices(arrays: Array, count: int, primitive: int = Mesh.PRIMITIVE_TRIANGLES) -> PackedInt32Array:
	var order := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null:
		order = arrays[Mesh.ARRAY_INDEX]
	else:
		order.resize(count)
		for k in count:
			order[k] = k
	if primitive != Mesh.PRIMITIVE_TRIANGLE_STRIP:
		return order
	var list := PackedInt32Array()
	for k in order.size() - 2:
		var flip := k % 2 == 1
		list.append_array([order[k + 1 if flip else k], order[k if flip else k + 1], order[k + 2]])
	return list


## For a mesh made without normals.
static func _flat_normals(verts: PackedVector3Array, order: PackedInt32Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(verts.size())
	for k in range(0, order.size() - 2, 3):
		var a: Vector3 = verts[order[k]]
		var nrm := (verts[order[k + 2]] - a).cross(verts[order[k + 1]] - a).normalized()
		for j in 3:
			out[order[k + j]] = nrm
	return out


## Boxes stay boxes; everything else keeps its exact form as triangles, however the prop is scaled.
static func _round_faces(shape: Shape3D) -> PackedVector3Array:
	var mesh: PrimitiveMesh
	if shape is CylinderShape3D:
		mesh = CylinderMesh.new()
		mesh.top_radius = shape.radius
		mesh.bottom_radius = shape.radius
		mesh.height = shape.height
		mesh.radial_segments = 16
		mesh.rings = 1
	elif shape is SphereShape3D:
		mesh = SphereMesh.new()
		mesh.radius = shape.radius
		mesh.height = shape.radius * 2.0
		mesh.radial_segments = 10
		mesh.rings = 5
	else:
		mesh = CapsuleMesh.new()
		mesh.radius = shape.radius
		mesh.height = shape.height
		mesh.radial_segments = 12
		mesh.rings = 3
	return mesh.get_faces()


## The points in prop space (scale included), which the footprint has to cover too.
static func _placed_points(points: PackedVector3Array, xform: Transform3D, out: Dictionary) -> PackedVector3Array:
	var placed := PackedVector3Array()
	placed.resize(points.size())
	for k in points.size():
		var p: Vector3 = xform * points[k]
		placed[k] = p
		out.half.x = maxf(out.half.x, absf(p.x))
		out.half.y = maxf(out.half.y, absf(p.z))
	return placed


static func _add_shape(shape: Shape3D, xform: Transform3D, out: Dictionary, layer: int) -> void:
	var scale := xform.basis.get_scale()
	var size := Vector3.ZERO
	if shape is BoxShape3D:
		size = shape.size
	elif shape is CylinderShape3D or shape is SphereShape3D or shape is CapsuleShape3D:
		out.meshes.append([_placed_points(_round_faces(shape), xform, out), layer])
		return
	elif shape is ConcavePolygonShape3D:
		out.meshes.append([_placed_points(shape.get_faces(), xform, out), layer])
		return
	elif shape is ConvexPolygonShape3D:
		out.hulls.append([_placed_points(shape.points, xform, out), layer])
		return
	else:
		push_warning("PropLibrary: a %s can't be used as prop collision" % shape.get_class())
		return
	var placed := Transform3D(xform.basis.orthonormalized(), xform.origin)
	out.shapes.append([size * scale, placed, layer])
	# A collision box can reach past the mesh, and the footprint has to cover both.
	for corner in 8:
		var offset := Vector3(1 if corner & 1 else -1, 1 if corner & 2 else -1, 1 if corner & 4 else -1) * size * scale * 0.5
		var p: Vector3 = placed * offset
		out.half.x = maxf(out.half.x, absf(p.x))
		out.half.y = maxf(out.half.y, absf(p.z))
