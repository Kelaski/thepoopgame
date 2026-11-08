class_name RoomPlans
## What each kind of building needs, floor by floor, and what each kind of room is.
##
## Corridor buildings (school, office, apartments, motel, tenements) put rooms along a hall. Each
## floor lists rooms it must have once, then a room it repeats until the floor is full. Room lengths
## along the hall come from each kind's range, so rooms differ in size.
##
## Zoned buildings (everything else) split each floor into bands running back from the main
## entrance. A band is [share of the depth, [[kind, share of the width], ...]]. Walled kinds get
## walls and a way in; the rest are open areas of the same hall.
##
## A floor list's last entry repeats for any floors above it.

## kind -> {opening: "door" | "wide" (a shopfront) | "" (an open area with no walls of its own),
##          len: [min, max] along a hall, parts: [[kind, share of the length], ...] (first is entered)}
const ROOMS := {
	# shared
	"public_restroom": {"opening": "door", "len": [4.6, 6.0]},
	"restroom": {"opening": "door", "len": [2.6, 3.4]},
	"storage": {"opening": "door", "len": [3.2, 4.4]},
	"break_room": {"opening": "door", "len": [5.0, 6.5]},
	"meeting_room": {"opening": "door", "len": [5.0, 6.5]},
	"manager_office": {"opening": "door", "len": [4.0, 5.0]},
	"bathroom": {"opening": "door"},
	"bedroom": {"opening": "door"},
	# school
	"classroom": {"opening": "door", "len": [7.0, 9.5]},
	"science_lab": {"opening": "door", "len": [8.0, 10.0]},
	"cafeteria": {"opening": "door", "len": [10.0, 14.0]},
	"principal_office": {"opening": "door", "len": [4.0, 5.5]},
	"teachers_lounge": {"opening": "door", "len": [5.0, 6.5]},
	"school_library": {"opening": "door", "len": [9.0, 12.0]},
	"school_hall": {"opening": ""},
	# office
	"lobby_reception": {"opening": "door", "len": [7.0, 9.0]},
	"open_office": {"opening": "door", "len": [8.0, 12.0]},
	"copy_room": {"opening": "door", "len": [3.0, 4.0]},
	"office_hall": {"opening": ""},
	# homes
	"apartment": {"opening": "door", "len": [9.5, 12.0], "parts": [["apt_living", 0.48], ["bedroom", 0.3], ["bathroom", 0.22]]},
	"studio_apartment": {"opening": "door", "len": [6.5, 8.0], "parts": [["apt_living", 0.68], ["bathroom", 0.32]]},
	"apt_living": {"opening": ""},
	"laundry": {"opening": "door", "len": [4.0, 5.5]},
	"mail_room": {"opening": "door", "len": [3.2, 4.2]},
	"apt_hall": {"opening": ""},
	"guest_room": {"opening": "door", "len": [6.0, 7.5], "parts": [["guest_bed", 0.64], ["bathroom", 0.36]]},
	"guest_bed": {"opening": ""},
	"motel_lobby": {"opening": "door", "len": [6.0, 8.0]},
	"vending_nook": {"opening": "door", "len": [2.6, 3.2]},
	"motel_hall": {"opening": ""},
	"squat_unit": {"opening": "door", "len": [6.0, 7.5], "parts": [["squat_living", 0.66], ["bath_rundown", 0.34]]},
	"squat_living": {"opening": ""},
	"bath_rundown": {"opening": "door"},
	"boiler_room": {"opening": "door", "len": [4.0, 5.5]},
	"tenement_hall": {"opening": ""},
	# zoned
	"dining": {"opening": ""}, "kitchen_diner": {"opening": "door"},
	"bar_room": {"opening": ""}, "pool_area": {"opening": ""},
	"arcade_floor": {"opening": ""}, "prize_counter": {"opening": ""}, "party_room": {"opening": "door"},
	"club_entry": {"opening": ""}, "dance_floor": {"opening": ""}, "club_bar": {"opening": ""}, "vip_lounge": {"opening": "door"}, "coat_check": {"opening": "door"},
	"bank_lobby": {"opening": ""}, "teller_area": {"opening": ""}, "vault_room": {"opening": "door"},
	"theater_lobby": {"opening": ""}, "auditorium": {"opening": "door"}, "projection": {"opening": "door"}, "staff_lounge": {"opening": ""},
	"gym_reception": {"opening": ""}, "locker_m": {"opening": "door"}, "locker_f": {"opening": "door"}, "weights_area": {"opening": ""}, "cardio_area": {"opening": ""}, "studio": {"opening": "door"}, "rest_area": {"opening": ""},
	"casino_lobby": {"opening": ""}, "cashier": {"opening": "door"}, "slots_area": {"opening": ""}, "table_games": {"opening": ""}, "casino_lounge": {"opening": ""},
	"mall_atrium": {"opening": ""}, "shop_clothes": {"opening": "wide"}, "shop_general": {"opening": "wide"}, "food_court": {"opening": ""},
	"loading_dock": {"opening": ""}, "storage_racks": {"opening": ""}, "warehouse_office": {"opening": "door"},
	"pump_hall": {"opening": ""}, "control_room": {"opening": "door"},
	"library_desk": {"opening": ""}, "stacks": {"opening": ""}, "reading_area": {"opening": ""}, "study_room": {"opening": "door"},
	"living": {"opening": ""},
	"stair_hall": {"opening": ""},
}

const PROGRAMS := {
	"school": {"layout": "corridor", "hall": "school_hall",
		"floors": [{"once": ["public_restroom", "principal_office", "cafeteria"], "fill": ["classroom"]},
			{"once": ["public_restroom", "teachers_lounge", "school_library"], "fill": ["classroom", "classroom", "science_lab"]},
			{"once": ["public_restroom", "storage"], "fill": ["classroom", "science_lab"]}],
		"zones": [[[0.62, [["classroom", 1.0]]], [0.38, [["principal_office", 0.4], ["public_restroom", 0.6]]]]]},
	"office": {"layout": "corridor", "hall": "office_hall",
		"floors": [{"once": ["lobby_reception", "public_restroom", "break_room"], "fill": ["open_office", "meeting_room"]},
			{"once": ["public_restroom", "break_room", "copy_room"], "fill": ["open_office", "manager_office", "meeting_room", "manager_office"]}],
		"zones": [[[0.6, [["open_office", 1.0]]], [0.4, [["meeting_room", 0.5], ["public_restroom", 0.5]]]]]},
	"apartments": {"layout": "corridor", "hall": "apt_hall",
		"floors": [{"once": ["mail_room", "laundry"], "fill": ["apartment", "studio_apartment"]},
			{"once": [], "fill": ["apartment", "apartment", "studio_apartment"]}],
		"zones": [[[0.6, [["apt_living", 1.0]]], [0.4, [["bedroom", 0.62], ["bathroom", 0.38]]]]]},
	"motel": {"layout": "corridor", "hall": "motel_hall",
		"floors": [{"once": ["motel_lobby", "manager_office", "vending_nook", "laundry", "public_restroom"], "fill": ["guest_room"]},
			{"once": [], "fill": ["guest_room"]}],
		"zones": [[[0.5, [["motel_lobby", 0.55], ["laundry", 0.45]]], [0.5, [["guest_bed", 0.7], ["bathroom", 0.3]]]]]},
	"tenement": {"layout": "corridor", "hall": "tenement_hall",
		"floors": [{"once": ["boiler_room"], "fill": ["squat_unit"]}, {"once": [], "fill": ["squat_unit"]}],
		"zones": [[[0.65, [["squat_living", 1.0]]], [0.35, [["storage", 0.6], ["bath_rundown", 0.4]]]]]},
	"diner": {"layout": "zones", "floors": [
		[[0.64, [["dining", 1.0]]], [0.36, [["kitchen_diner", 0.56], ["public_restroom", 0.44]]]]]},
	"bar": {"layout": "zones", "floors": [
		[[0.6, [["bar_room", 1.0]]], [0.4, [["pool_area", 0.5], ["storage", 0.2], ["public_restroom", 0.3]]]]]},
	"arcade": {"layout": "zones", "floors": [
		[[0.7, [["arcade_floor", 1.0]]], [0.3, [["prize_counter", 0.5], ["public_restroom", 0.5]]]],
		[[0.65, [["arcade_floor", 1.0]]], [0.35, [["party_room", 0.6], ["storage", 0.4]]]]]},
	"club": {"layout": "zones", "floors": [
		[[0.26, [["club_entry", 0.45], ["coat_check", 0.19], ["public_restroom", 0.36]]], [0.74, [["dance_floor", 0.64], ["club_bar", 0.36]]]],
		[[0.6, [["vip_lounge", 1.0]]], [0.4, [["manager_office", 0.4], ["public_restroom", 0.6]]]]]},
	"bank": {"layout": "zones", "floors": [
		[[0.5, [["bank_lobby", 1.0]]], [0.5, [["teller_area", 0.48], ["vault_room", 0.3], ["restroom", 0.22]]]],
		[[0.55, [["open_office", 1.0]]], [0.45, [["manager_office", 0.35], ["meeting_room", 0.4], ["restroom", 0.25]]]]]},
	"theater": {"layout": "zones", "floors": [
		[[0.3, [["theater_lobby", 0.6], ["public_restroom", 0.4]]], [0.7, [["auditorium", 1.0]]]],
		[[0.3, [["projection", 0.4], ["staff_lounge", 0.35], ["storage", 0.25]]], [0.7, [["auditorium", 1.0]]]]]},
	"gym": {"layout": "zones", "floors": [
		[[0.22, [["gym_reception", 0.5], ["locker_m", 0.25], ["locker_f", 0.25]]], [0.78, [["weights_area", 0.52], ["cardio_area", 0.48]]]],
		[[0.55, [["cardio_area", 0.5], ["studio", 0.5]]], [0.45, [["weights_area", 0.5], ["rest_area", 0.24], ["public_restroom", 0.26]]]]]},
	"casino": {"layout": "zones", "floors": [
		[[0.28, [["casino_lobby", 0.5], ["cashier", 0.24], ["public_restroom", 0.26]]], [0.72, [["slots_area", 0.5], ["table_games", 0.5]]]],
		[[0.62, [["table_games", 0.5], ["slots_area", 0.5]]], [0.38, [["casino_lounge", 0.6], ["public_restroom", 0.4]]]]]},
	"mall": {"layout": "zones", "floors": [
		[[0.36, [["mall_atrium", 1.0]]], [0.38, [["shop_clothes", 0.34], ["shop_general", 0.33], ["shop_clothes", 0.33]]], [0.26, [["food_court", 0.6], ["public_restroom", 0.4]]]],
		[[0.36, [["shop_general", 0.5], ["shop_clothes", 0.5]]], [0.38, [["mall_atrium", 1.0]]], [0.26, [["food_court", 0.6], ["public_restroom", 0.4]]]]]},
	"warehouse": {"layout": "zones", "floors": [
		[[0.18, [["loading_dock", 1.0]]], [0.64, [["storage_racks", 1.0]]], [0.18, [["warehouse_office", 0.5], ["break_room", 0.3], ["restroom", 0.2]]]],
		[[0.75, [["storage_racks", 1.0]]], [0.25, [["warehouse_office", 0.6], ["storage", 0.4]]]]]},
	"water": {"layout": "zones", "floors": [
		[[0.74, [["pump_hall", 1.0]]], [0.26, [["control_room", 0.5], ["storage", 0.3], ["restroom", 0.2]]]]]},
	"library": {"layout": "zones", "floors": [
		[[0.26, [["library_desk", 0.6], ["public_restroom", 0.4]]], [0.74, [["stacks", 0.6], ["reading_area", 0.4]]]],
		[[0.68, [["stacks", 1.0]]], [0.32, [["reading_area", 0.55], ["study_room", 0.45]]]]]},
}

## Big open rooms need headroom: their ground floor is taller than the storeys above it.
const TALL_GROUND := {"theater": 7.5, "gym": 6.5, "mall": 6.0, "casino": 5.5, "club": 5.5}


static func program(theme: String) -> Dictionary:
	return PROGRAMS.get(theme, PROGRAMS["warehouse"])


static func floor_def(theme: String, level: int, key := "floors") -> Variant:
	var list: Array = program(theme)[key]
	return list[mini(level, list.size() - 1)]


static func room(kind: String) -> Dictionary:
	return ROOMS.get(kind, {"opening": ""})


static func walled(kind: String) -> bool:
	return room(kind).opening != ""
