class_name Prefabs
## Template scenes for the map's props and furniture (assets/props, assets/furniture).
##
## The map places thousands of these, so they aren't added as nodes. Instead each
## scene is read once into a "recipe" and MapBuilder._prefab() stamps it into the
## same batched MultiMeshes and per-chunk collision bodies as everything else.
## What a template scene can contain:
##   * MeshInstance3D with a BoxMesh, CylinderMesh or SphereMesh. Its colour is
##     the material_override albedo. Optional metadata:
##       slot         colour filled in by the code (e.g. "body" on cars, "leaf"
##                    on tree crowns); slot_darken / slot_lighten shade it
##       slot_choices PackedColorArray: one is picked at random per placement
##       batch        "static" or "detail" (detail = furniture batch with a
##                    75 m draw distance); otherwise it follows where it's placed
##       glow         true = lit from within (bulbs, screens, neon): drawn unshaded
##                    and bright enough to bloom
##   * OmniLight3D: a real light, placed with the prefab (colour, energy and range
##     are used; shadows stay off). The player's Interior lights setting thins them.
##   * StaticBody3D with CollisionShape3D children (BoxShape3D, CylinderShape3D):
##     the body's collision_layer is the layer (1 floor, 2 wall, 16 solid).
##     Meshes without a body around them are visual only.
## Any node can be moved, rotated or scaled. Pieces can also be stretched when
## placed (MapBuilder passes a scaled transform), so walls, cables, decks and
## trunks fit any length; box and cylinder shapes are resized to match.

const ROOT := "res://assets/"

static var _recipes := {}


## Recipe for "props/vehicles/car" etc. (path under assets/, without .tscn):
## {"parts": [{kind, xform, color, slot, darken, lighten, choices, batch, glow}],
##  "shapes": [{kind, layer, size, xform}], "lights": [{pos, color, energy, range}]}
static func recipe(name: String) -> Dictionary:
	if _recipes.has(name):
		return _recipes[name]
	var ps: PackedScene = load(ROOT + name + ".tscn")
	var r := {"parts": [], "shapes": [], "lights": []}
	if ps == null:
		push_error("Prefab not found: " + name)
	else:
		var root := ps.instantiate()
		_collect(root, Transform3D.IDENTITY, 0, r)
		root.free()
	_recipes[name] = r
	return r


static func _collect(n: Node, xf: Transform3D, layer: int, r: Dictionary) -> void:
	for c in n.get_children():
		var cxf := xf * (c as Node3D).transform if c is Node3D else xf
		var lay := layer
		if c is CollisionObject3D:
			lay = c.collision_layer
		if c is MeshInstance3D and c.visible:
			_add_part(c, cxf, r)
		elif c is CollisionShape3D and c.shape and lay != 0 and not c.disabled:
			_add_shape(c.shape, cxf, lay, r)
		elif c is OmniLight3D and c.visible:
			r.lights.append({"pos": cxf.origin, "color": c.light_color, "energy": c.light_energy, "range": c.omni_range})
		_collect(c, cxf, lay, r)


static func _add_part(mi: MeshInstance3D, xf: Transform3D, r: Dictionary) -> void:
	var kind := ""
	var s := Vector3.ONE
	var m := mi.mesh
	if m is BoxMesh:
		kind = "box"
		s = m.size
	elif m is CylinderMesh:
		kind = "cyl"
		s = Vector3(m.top_radius * 2.0, m.height, m.top_radius * 2.0)
	elif m is SphereMesh:
		kind = "sphere"
		s = Vector3(m.radius * 2.0, m.height, m.radius * 2.0)
	else:
		push_warning("Prefab mesh %s: only BoxMesh, CylinderMesh and SphereMesh are batched" % mi.name)
		return
	var col := Color.WHITE
	var mat := mi.material_override
	if mat == null and m.get_surface_count() > 0:
		mat = m.surface_get_material(0)
	if mat is BaseMaterial3D:
		col = mat.albedo_color
	r.parts.append({
		"kind": kind,
		"xform": Transform3D(xf.basis * Basis.from_scale(s), xf.origin),
		"color": col,
		"slot": str(mi.get_meta("slot", "")),
		"darken": float(mi.get_meta("slot_darken", 0.0)),
		"lighten": float(mi.get_meta("slot_lighten", 0.0)),
		"choices": mi.get_meta("slot_choices", PackedColorArray()),
		"batch": str(mi.get_meta("batch", "")),
		"glow": bool(mi.get_meta("glow", false)),
	})


static func _add_shape(shape: Shape3D, xf: Transform3D, layer: int, r: Dictionary) -> void:
	if shape is BoxShape3D:
		r.shapes.append({"kind": "box", "layer": layer, "size": shape.size, "xform": xf})
	elif shape is CylinderShape3D:
		r.shapes.append({"kind": "cyl", "layer": layer, "size": Vector3(shape.radius, shape.height, shape.radius), "xform": xf})
	else:
		push_warning("Prefab shape %s: only box and cylinder shapes are supported" % shape)
