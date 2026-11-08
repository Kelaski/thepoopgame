class_name MapRules extends Resource
## Structural numbers shared by the Classic map and the procedural generator.

@export_group("Classic")
## Metres per pixel of the design sketch.
@export var classic_scale := 0.1
@export var classic_road_width := 6.0

@export_group("Procedural sizes (m)")
@export var small_size := Vector2(57, 71)
@export var medium_size := Vector2(91, 95)
@export var large_size := Vector2(140, 119)
## Added to a map's whole size, in open ground between the outermost buildings and the fence.
@export var edge_expansion := 0.2
@export var road_width := 6.0
@export var road_clearance := 3.0
@export var block_max := 62.4
@export var lot_max := 39.8
@export var lot_min := 12.6
@export var alley_min := 3.4
@export var alley_max := 4.9
@export var spawn_spacing := 10.0
## Chance that a split between two lots has no alley at all, so the buildings stand wall to wall.
@export var strip_chance := 0.35

@export_group("Buildings")
@export var max_floors := 7
@export var wall_thickness := 0.35
@export var slab_thickness := 0.3
## The doorway. map/door.tscn is built to fit it, a hair smaller each way.
@export var door_width := 1.7
@export var door_height := 2.45
@export var corridor_width := 5.0
@export var stair_width := 2.0
@export var stair_slope_deg := 30.0
## Tight buildings get lower storeys rather than a ramp steeper than this.
@export var stair_max_slope_deg := 36.0
## ...but never lower than this.
@export var min_floor_height := 4.0
## Free floor at each end of a flight, enough to walk around the rail and turn onto it.
@export var stair_landing := 1.5
## Depth of the platform where a switchback turns.
@export var stair_turn := 1.4
## Entrances per building, at most.
@export var max_building_doors := 2
@export var parapet_height := 0.5
@export var clutter_gap := 1.1
@export var keep_clear_radius := 2.2

## Storey heights are multiplied by this.
@export var floor_height_scale := 1.0
## Windows start here above the floor and are as tall as a player.
@export var window_bottom := 1.3
@export var window_height := 1.9

@export_group("Bridges and cranes")
## Each of a map's crane slots (its limit for that size) is filled with this chance.
@export var crane_chance := 0.35
## Every map gets at least this many.
@export var crane_min := 2
@export var crane_limit_small := 3
@export var crane_limit_medium := 5
@export var crane_limit_large := 7
@export var bridge_width := 2.4
@export var bridge_max_gap := 22.0
@export var bridge_max_slope_deg := 32.0

@export_group("Boundary")
@export var fence_margin := 3.0
@export var fence_height := 5.0
@export var boundary_height := 140.0

@export_group("Lighting")
@export var max_interior_lights := 500
@export var lamp_spacing := 28.0
