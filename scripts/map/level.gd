class_name Level
## A built map, as the rest of the game reads it. ClassicMap / ProcGen plan it (the same
## kind and seed give the same map on every peer) and MapBuilder builds it.

const SIZE_ORDER := ["classic", "small", "medium", "large"]
const DEFAULT_SIZE := "medium"
const SIZE_NAMES := {"classic": "Classic", "small": "Procedural: Small", "medium": "Procedural: Medium", "large": "Procedural: Large"}
const RULES: MapRules = preload("res://assets/tuning/map_rules.tres")
# Teams start at least this far apart (m).
const MIN_SPAWN_DIST := {"classic": 70.0, "small": 30.0, "medium": 50.0, "large": 60.0}
const SPAWN_GRID := 4.0  # m between respawn candidates
## Building colours by theme, for the minimap.
const THEME_COLORS := {
	"warehouse": Color(0.5, 0.6, 0.62), "school": Color(0.72, 0.36, 0.3), "sports": Color(0.36, 0.5, 0.74),
	"theater": Color(0.46, 0.3, 0.62), "bank": Color(0.66, 0.66, 0.6), "diner": Color(0.3, 0.64, 0.64),
	"arcade": Color(0.5, 0.3, 0.66), "club": Color(0.34, 0.26, 0.42), "bar": Color(0.42, 0.32, 0.3),
	"apartments": Color(0.78, 0.62, 0.42), "mall": Color(0.82, 0.76, 0.64), "motel": Color(0.82, 0.48, 0.46),
	"tenement": Color(0.46, 0.38, 0.4), "office": Color(0.42, 0.56, 0.76), "casino": Color(0.82, 0.42, 0.44),
	"water": Color(0.6, 0.62, 0.6), "library": Color(0.62, 0.46, 0.32),
}

var layout: MapLayout
var root: Node3D
var bounds := Rect2()
var spawn_dots: Array = []    # Vector3: the team spawn zones
var spawn_points: Array = []  # Vector3: respawn candidates
var objectives: Array = []    # {pos: Vector3, name}
var doors: Array = []
var buildings: Array = []     # {id, name, theme, rect, floors, floor_h, color}
var lights: Array = []
var min_spawn_dist := 50.0


static func valid_size(size: String) -> bool:
	return size in SIZE_ORDER


static func size_name(size: String) -> String:
	return SIZE_NAMES.get(size, size)


static func plan(kind: String, map_seed: int) -> MapLayout:
	return ClassicMap.build(RULES) if kind == "classic" else ProcGen.generate(kind, map_seed, RULES)


func build(parent: Node3D, kind: String, map_seed: int) -> void:
	layout = plan(kind, map_seed)
	root = MapBuilder.build(layout, RULES, parent)
	bounds = layout.bounds
	doors = MapBuilder.doors
	lights = MapBuilder.lights
	min_spawn_dist = MIN_SPAWN_DIST.get(kind, 50.0)
	for p: Vector2 in layout.spawns:
		spawn_dots.append(Vector3(p.x, 0.0, p.y))
	var x := bounds.position.x + 2.0
	while x < bounds.end.x - 1.0:
		var z := bounds.position.y + 2.0
		while z < bounds.end.y - 1.0:
			spawn_points.append(Vector3(x, 0.05, z))
			z += SPAWN_GRID
		x += SPAWN_GRID
	for o in layout.objectives:
		objectives.append({"pos": Vector3(o.pos.x, o.y, o.pos.y), "name": o.get("name", "")})
	for b in layout.buildings:
		b["color"] = THEME_COLORS.get(b.theme, Color(0.55, 0.55, 0.6))
		b["name"] = MapLayout.display_name(b.name)
		buildings.append(b)


## An upper-floor Tag spot can land on a wall or a piece of furniture: it moves to the
## ground floor, which the generator keeps clear. Needs physics to know the new bodies.
func settle_objectives() -> void:
	await root.get_tree().physics_frame
	await root.get_tree().physics_frame
	var probe := CapsuleShape3D.new()
	probe.radius = 0.36
	probe.height = 1.76
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = probe
	query.collision_mask = GeoMask.SOLID
	var space := root.get_world_3d().direct_space_state
	for o: Dictionary in objectives:
		query.transform = Transform3D(Basis.IDENTITY, o.pos + Vector3(0, 0.95, 0))
		if not space.intersect_shape(query, 1).is_empty():
			o.pos.y = 0.0
