class_name PropLibrary
## Reads the prop scenes in assets/ once, into plain mesh and collision data, so they can be baked
## into a building's batched meshes instead of adding dozens of nodes per prop.

static var _cache := {}


## {parts: [{v, n, i, color, glow, slot, lighten}], shapes: [[size, Transform3D, layer]], half: Vector2, top: float}
static func get_prop(path: String) -> Dictionary:
	if not _cache.has(path):
		_cache[path] = _read(path)
	return _cache[path]


static func _read(path: String) -> Dictionary:
	var scene: PackedScene = load(path)
	var root: Node = scene.instantiate()
	var out := {"parts": [], "shapes": [], "half": Vector2.ZERO, "top": 0.0}
	_walk(root, Transform3D.IDENTITY, out)
	root.free()
	return out


static func _walk(node: Node, parent: Transform3D, out: Dictionary) -> void:
	var xform := parent
	if node is Node3D:
		xform = parent * node.transform
		if node is MeshInstance3D and node.mesh != null and node.visible:
			_add_mesh(node, xform, out)
		elif node is CollisionShape3D and node.shape != null and not node.disabled:
			_add_shape(node.shape, xform, out, GeoMask.BOUNCE if node.get_parent().collision_layer == GeoMask.BOUNCE else GeoMask.WALL)
	for child in node.get_children():
		_walk(child, xform, out)


static func _add_mesh(mi: MeshInstance3D, xform: Transform3D, out: Dictionary) -> void:
	var mesh: Mesh = mi.mesh
	for surface in mesh.get_surface_count():
		var arrays: Array = (mesh as PrimitiveMesh).get_mesh_arrays() if mesh is PrimitiveMesh else mesh.surface_get_arrays(surface)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
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
		var material: Material = mi.material_override if mi.material_override else mesh.surface_get_material(surface)
		var color := Color.WHITE
		if material is StandardMaterial3D:
			color = material.albedo_color
		out.parts.append({"v": v, "n": n, "i": arrays[Mesh.ARRAY_INDEX], "color": color,
			"glow": mi.get_meta("glow", false) or (material is StandardMaterial3D and material.emission_enabled),
			"slot": mi.get_meta("slot", ""), "lighten": float(mi.get_meta("slot_lighten", 0.0))})


## Collision boxes, as the level uses boxes throughout. Round shapes become an inscribed box.
static func _add_shape(shape: Shape3D, xform: Transform3D, out: Dictionary, layer: int) -> void:
	var scale := xform.basis.get_scale()
	var size := Vector3.ZERO
	if shape is BoxShape3D:
		size = shape.size
	elif shape is CylinderShape3D:
		size = Vector3(shape.radius * 1.5, shape.height, shape.radius * 1.5)
	elif shape is SphereShape3D:
		size = Vector3.ONE * shape.radius * 1.5
	else:
		return
	var placed := Transform3D(xform.basis.orthonormalized(), xform.origin)
	out.shapes.append([size * scale, placed, layer])
	# A collision box can reach past the mesh, and the footprint has to cover both.
	for corner in 8:
		var offset := Vector3(1 if corner & 1 else -1, 1 if corner & 2 else -1, 1 if corner & 4 else -1) * size * scale * 0.5
		var p: Vector3 = placed * offset
		out.half.x = maxf(out.half.x, absf(p.x))
		out.half.y = maxf(out.half.y, absf(p.z))
