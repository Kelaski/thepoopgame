class_name Clutter
## Places props, each a scene under assets/, baked into the level by PropLibrary.

## name -> [scene under res://assets/, extra quarter turns, extra scale]
const IMPORTS := {
	"school_desk": ["furniture/school_desk", 0, 1.0], "chalkboard": ["furniture/chalkboard", 0, 1.0], "lockers": ["furniture/lockers", 0, 1.0],
	"bookcase_low": ["furniture/school_shelf", 0, 1.0], "crates": ["furniture/crate", 0, 1.0],
	"forklift": ["furniture/forklift", 0, 1.0], "pallet_stack": ["furniture/decor/pallet_stack", 0, 1.0], "tank": ["props/water/tank", 0, 1.0],
	"pipes": ["props/water/pipe", 0, 2.0], "pump": ["props/water/pump", 0, 1.0], "valve_panel": ["furniture/decor/valve_panel", 0, 1.0],
	"seat_row": ["furniture/theater_seats", 0, 1.0], "screen_wall": ["furniture/theater_screen", 0, 1.0], "concession": ["furniture/concession_stand", 0, 1.0], "serving_counter": ["furniture/serving_counter", 0, 1.0], "food_stall": ["furniture/food_stall", 0, 1.0],
	"ticket_kiosk": ["furniture/ticket_kiosk", 0, 1.0], "teller_counter": ["furniture/teller_counter", 0, 1.0], "vault": ["furniture/vault", 2, 1.0],
	"atm": ["furniture/atm", 0, 1.0], "waiting_chairs": ["furniture/waiting_chairs", 0, 1.0], "stanchion": ["furniture/queue_stanchions", 0, 1.0],
	"cubicle": ["furniture/office_cubicle", 0, 1.0], "conference": ["furniture/conference_table", 0, 1.0], "copier": ["furniture/copier", 0, 1.0],
	"water_cooler": ["furniture/decor/water_cooler", 0, 1.0], "reception": ["furniture/front_desk", 0, 1.0], "plant": ["furniture/potted_plant", 0, 1.0],
	"booth": ["furniture/diner_booth", 0, 1.0], "counter": ["furniture/diner_counter", 0, 1.0], "jukebox": ["furniture/decor/jukebox", 0, 1.0],
	"bar_counter": ["furniture/bar_counter", 0, 1.0], "pool_table": ["furniture/pool_table", 0, 1.0], "arcade": ["furniture/arcade_cabinets", 2, 1.0],
	"claw_machine": ["furniture/claw_machine", 0, 1.0], "vending": ["furniture/decor/vending_machine", 0, 1.0], "air_hockey": ["furniture/air_hockey", 0, 1.0],
	"dj_booth": ["furniture/dj_booth", 0, 1.0], "club_sofa": ["furniture/club_booth", 0, 1.0], "speaker_stack": ["furniture/decor/speaker_stack", 0, 1.0],
	"bed": ["furniture/bed", 0, 1.0], "nightstand": ["furniture/nightstand", 0, 1.0], "sofa": ["furniture/sofa", 2, 1.0], "lounge_set": ["furniture/lounge_set", 0, 1.0],
	"tv_stand": ["furniture/tv_stand", 0, 1.0], "wall_tv": ["furniture/decor/wall_tv", 0, 1.0], "kitchen": ["furniture/kitchen", 0, 1.0], "kitchen_island": ["furniture/kitchen_island", 0, 1.0],
	"table_chairs": ["furniture/table_chairs", 0, 1.0], "dresser": ["furniture/dresser_tv", 0, 1.0], "mattress": ["furniture/mattress", 0, 1.0],
	"rundown_tv": ["furniture/rundown_tv", 0, 1.0], "trash_bag": ["furniture/trash_bag", 0, 1.0], "kiosk": ["props/street/kiosk", 0, 1.0],
	"display": ["furniture/display_stand", 0, 1.0], "clothes_rack": ["furniture/clothes_rack", 0, 1.0], "clothes_shelf": ["furniture/clothes_shelf", 0, 1.0],
	"checkout": ["furniture/checkout_counter", 0, 1.0], "mannequin": ["furniture/decor/mannequin", 0, 1.0], "mall_bench": ["furniture/mall_bench", 0, 1.0],
	"slots": ["furniture/slot_machines", 2, 1.0], "card_table": ["furniture/card_table", 0, 1.0], "roulette": ["furniture/roulette_table", 0, 1.0],
	"craps_table": ["furniture/craps_table", 0, 1.0], "bookshelf": ["furniture/bookshelf", 0, 1.0], "reading_table": ["furniture/reading_table", 0, 1.0],
	"desk_chair": ["furniture/desk_chair", 0, 1.0],
	"toilet_stall": ["furniture/fixtures/toilet_stall", 0, 1.0], "toilet": ["furniture/fixtures/toilet", 0, 1.0], "urinal": ["furniture/fixtures/urinal", 0, 1.0],
	"sink_counter": ["furniture/fixtures/sink_counter", 0, 1.0], "sink": ["furniture/fixtures/sink", 0, 1.0], "shower": ["furniture/fixtures/shower", 0, 1.0],
	"cafeteria_table": ["furniture/cafeteria_table", 0, 1.0], "kitchen_line": ["furniture/kitchen_line", 0, 1.0], "storage_shelf": ["furniture/storage_shelf", 0, 1.0],
	"bunk_bed": ["furniture/bunk_bed", 0, 1.0], "fridge": ["furniture/fridge", 0, 1.0], "picture_frame": ["furniture/decor/picture_frame", 0, 1.0],
	"wall_clock": ["furniture/decor/wall_clock", 0, 1.0], "poster": ["furniture/decor/poster", 0, 1.0], "notice_board": ["furniture/decor/notice_board", 0, 1.0],
	"whiteboard": ["furniture/decor/whiteboard", 0, 1.0],
	"treadmill": ["furniture/treadmill", 0, 1.0], "exercise_bike": ["furniture/exercise_bike", 0, 1.0], "bench_press": ["furniture/bench_press", 0, 1.0],
	"dumbbell_rack": ["furniture/dumbbell_rack", 0, 1.0], "punching_bag": ["furniture/punching_bag", 0, 1.0],
	"car": ["props/vehicles/car", 1, 1.0], "taxi": ["props/vehicles/taxi", 1, 1.0], "van": ["props/vehicles/van", 1, 1.0], "bus": ["props/vehicles/bus", 1, 1.0],
	"dumpster": ["props/street/dumpster", 0, 1.0], "hydrant_news": ["props/street/hydrant_news", 0, 1.0], "trash_can": ["props/street/bin", 0, 1.0],
	"mailbox": ["props/street/mailbox", 0, 1.0], "bench": ["props/park/bench", 0, 1.0], "parking_meter": ["props/street/parking_meter", 0, 1.0],
	"bus_stop": ["props/street/bus_shelter", 0, 1.0], "planter": ["props/street/planter_box", 0, 1.0], "cone": ["props/street/traffic_cone", 0, 1.0],
	"bike_rack": ["props/street/bike_rack", 0, 1.0], "bollards": ["props/street/bollards", 0, 1.0], "street_tree": ["props/street/tree_planter", 0, 1.5],
	"stop_sign": ["props/street/stop_sign", 0, 1.0], "road_gate": ["props/street/road_gate", 0, 1.0], "traffic_light": ["props/street/traffic_light", 0, 1.0], "lamp_post": ["props/street/lamp", 0, 1.0],
	"pallet_rack": ["props/misc/pallet_rack", 0, 1.0], "conveyor": ["props/misc/conveyor", 0, 1.0], "barrels": ["props/misc/barrels", 0, 1.0],
	"bleachers": ["props/misc/bleachers", 0, 1.0], "hoop": ["props/misc/hoop", 0, 1.0], "gym_mat": ["props/misc/gym_mat", 0, 1.0], "weight_rack": ["props/misc/weight_rack", 0, 1.0],
	"junk": ["props/misc/junk", 0, 1.0], "washer": ["props/misc/washer", 0, 1.0], "phone_booth": ["props/misc/phone_booth", 0, 1.0], "street_sign": ["props/misc/street_sign", 0, 1.0],
	"billboard": ["props/misc/billboard", 0, 1.0], "hedge": ["props/misc/hedge", 0, 1.0], "rock_pile": ["props/misc/rock_pile", 0, 1.0], "reeds": ["props/misc/reeds", 0, 1.0], "park_lamp": ["props/misc/park_lamp", 0, 1.0],
	"awning": ["props/building/awning", 0, 1.0], "ceiling_lamp": ["props/building/ceiling_lamp", 0, 1.0],
	"swing_set": ["props/playground/swing_set", 0, 1.0], "slide_toy": ["props/playground/slide_toy", 0, 1.0], "seesaw": ["props/playground/seesaw", 0, 1.0],
	"climbing_frame": ["props/playground/climbing_frame", 0, 1.0], "merry_go_round": ["props/playground/merry_go_round", 0, 1.0],
	"spring_rider": ["props/playground/spring_rider", 0, 1.0], "monkey_bars": ["props/playground/monkey_bars", 0, 1.0], "sandbox": ["props/playground/sandbox", 0, 1.0],
	"ac_unit": ["props/roof/ac_unit", 0, 1.0], "vent": ["props/roof/vent", 0, 1.0], "hvac": ["props/roof/hvac_condenser", 0, 1.0], "dish": ["props/roof/satellite_dish", 0, 1.0],
	"water_tower": ["props/roof/water_tower", 0, 1.0], "antenna": ["props/roof/antenna", 0, 1.0],
	"picnic_table": ["props/park/picnic_table", 0, 1.0], "picnic_umbrella": ["props/park/picnic_umbrella", 0, 1.0], "fountain": ["props/park/fountain", 0, 1.0],
	"gazebo": ["props/park/gazebo", 0, 1.0], "rubble_pile": ["props/ruins/rubble_pile", 0, 1.0], "debris": ["props/ruins/debris", 0, 1.0],
	"dead_tree": ["props/ruins/dead_tree", 0, 1.0], "ruin_wall": ["props/ruins/ruin_wall", 0, 1.0], "dock": ["props/park/dock", 0, 1.0], "pond_lilies": ["props/park/pond_lilies", 0, 1.0],
	"drinking_fountain": ["props/park/drinking_fountain", 0, 1.0], "info_board": ["props/park/info_board", 0, 1.0], "statue": ["props/park/statue", 0, 1.0], "flower_bed": ["props/park/flower_bed", 0, 1.0], "bush": ["props/nature/bush", 0, 1.0],
	"crane_footing": ["props/crane/footing", 0, 1.0], "crane_mast": ["props/crane/mast", 0, 1.0], "crane_braces": ["props/crane/mast_braces", 0, 1.0],
	"crane_top": ["props/crane/top", 0, 1.0], "crane_trolley": ["props/crane/trolley", 0, 1.0], "crane_hook": ["props/crane/hook", 0, 1.0],
	"crane_load_metal": ["props/crane/load_metal", 0, 1.0], "crane_load_planks": ["props/crane/load_planks", 0, 1.0],
	"tree_trunk": ["props/nature/tree_trunk", 0, 1.0], "tree_crown": ["props/nature/tree_crown", 0, 1.0],
}
## Walk-through props: bushes and small ground debris are baked as looks only, with no collision.
const NO_COLLISION := {"bush": true, "junk": true, "debris": true, "rubble_pile": true}
## Scales every prop together. Props are built at real size.
const PROP_SCALE := 1.0

static var _object_count := 0


static func _import(prefab: String) -> Dictionary:
	return PropLibrary.get_prop("res://assets/%s.tscn" % IMPORTS[prefab][0])


## Real footprint, symmetric about the prefab's origin, already including any built-in quarter turn.
static func size_of(prefab: String) -> Vector2:
	var row: Array = IMPORTS[prefab]
	var half: Vector2 = _import(prefab).half
	if row[1] % 2 == 1:
		half = Vector2(half.y, half.x)
	return half * 2.0 * PROP_SCALE * float(row[2])


static func height_of(prefab: String) -> float:
	return _import(prefab).top * PROP_SCALE * float(IMPORTS[prefab][2])


## +1 if most of an imported prop reaches along its +Z, -1 along -Z. For posts with an arm.
static func reach_sign(prefab: String) -> float:
	var total := 0.0
	for part in _import(prefab).parts:
		for v in part.v:
			total += v.z
	return 1.0 if total >= 0.0 else -1.0


## turns = quarter turns about Y (fractions allowed). pos is the footprint centre at floor level.
## paint ("#rrggbb") recolours the parts of a prop whose meta slot is "body".
## stretch multiplies the prop's size per axis, for fitting something like a gate to a road.
static func place(geo: GeoBatch, prefab: String, pos: Vector3, turns: float, paint := "", stretch := Vector3.ONE) -> void:
	var outer_tag := GeoBatch.tag
	_object_count += 1
	GeoBatch.tag = "prop#%d %s" % [_object_count, prefab]
	_bake(geo, prefab, pos, turns, paint, stretch)
	GeoBatch.tag = outer_tag


static func _bake(geo: GeoBatch, prefab: String, pos: Vector3, turns: float, paint: String, stretch: Vector3) -> void:
	var row: Array = IMPORTS[prefab]
	var prop := _import(prefab)
	var spin := Basis(Vector3.UP, (turns + row[1]) * PI * 0.5)
	var scale := Vector3.ONE * PROP_SCALE * float(row[2]) * stretch
	var xform := Transform3D(spin.scaled_local(scale), pos)
	for part in prop.parts:
		var color: Color = part.color
		if paint != "" and part.slot == "body":
			color = Color(paint).lightened(part.lighten)
		geo.add_part(part, xform, color, part.glow)
	if NO_COLLISION.has(prefab):
		return
	for shape in prop.shapes:
		var t: Transform3D = xform * shape[1]
		geo.add_shape(t.origin, shape[0] * scale, t.basis.orthonormalized(), shape[2])
	for mesh in prop.meshes:
		geo.add_mesh_shape(mesh[0], xform, mesh[1])
	for hull in prop.hulls:
		geo.add_hull_shape(hull[0], xform, hull[1])
