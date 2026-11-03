class_name MapData
## Map layout transcribed from the design sketch (2000 x 1700 px image).
## 1 px = 0.1 m, so the playable area is 200 m x 170 m centred on the origin.

const SCALE := 0.1

# Map sizes are cut-outs of the full layout (sketch pixels [x0, y0, x1, y1]).
# Buildings fully inside the cut-out are kept, the boundary fence moves in, and
# spawn zones / Tag spots / roads / crane bridges outside it are dropped.
#   large  - the whole city (200 x 170 m, 18 buildings + park, 10 spawns, 8 Tag spots)
#   medium - centre-north (130 x 136 m, 6 buildings + park, 5 spawns, 4 Tag spots)
#   small  - centre (81 x 102 m, 2 buildings + park, 3 spawns, 3 Tag spots)
const SIZES := {
	"small": {"name": "Small", "rect": [360, 250, 1170, 1270], "min_spawn_dist": 50.0},
	"medium": {"name": "Medium", "rect": [420, 0, 1720, 1360], "min_spawn_dist": 60.0},
	"large": {"name": "Large", "rect": [0, 0, 2000, 1700], "min_spawn_dist": 70.0},
}
const SIZE_ORDER := ["small", "medium", "large"]
const DEFAULT_SIZE := "large"
const HALF_X := 100.0
const HALF_Z := 85.0

# [id, name, type, [x0, y0, x1, y1] in sketch pixels, floors, floor height (m)]
const BUILDINGS := [
	[1, "Warehouse", "warehouse", [15, 15, 470, 235], 2, 6.0],
	[2, "Swiftcurrent K-12 School", "school", [560, 30, 880, 260], 3, 4.0],
	[3, "Rapids Arena (Swiftcurrent Rapids)", "sports", [1335, 55, 1955, 445], 1, 11.0],
	[4, "Movie Theater", "theater", [65, 400, 360, 745], 2, 5.0],
	[5, "Bank", "bank", [435, 400, 665, 770], 2, 4.5],
	[6, "Diner", "diner", [1315, 645, 1505, 785], 1, 4.5],
	[7, "Arcade", "arcade", [1525, 645, 1715, 780], 2, 4.0],
	[8, "Nightclub", "club", [1725, 645, 1895, 770], 2, 4.5],
	[9, "Bar", "bar", [1905, 645, 1985, 770], 1, 4.0],
	[10, "Riverside Apartments", "apartments", [75, 905, 375, 1300], 5, 4.0],
	[11, "Mall", "mall", [105, 1375, 395, 1680], 3, 5.0],
	[12, "Motel 6", "motel", [1865, 945, 1985, 1350], 2, 4.0],
	[13, "Eastside Tenements", "rundown", [1495, 1405, 1810, 1540], 4, 4.0],
	[14, "Southside Tenements", "rundown2", [1495, 1600, 1850, 1680], 3, 4.0],
	[15, "Meridian Tower", "office", [600, 945, 1025, 1195], 5, 4.0],
	[16, "Golden Rapids Casino", "casino", [1175, 950, 1625, 1235], 5, 4.5],
	[17, "Water Treatment Center", "water", [585, 1400, 985, 1630], 1, 7.0],
	[18, "Public Library", "library", [1060, 1405, 1305, 1630], 2, 4.5],
]

const PARK_RECT := [790, 335, 1160, 775]
const PARK_NAME := "Swiftcurrent Park"

# Purple dots: team spawn zones.
const SPAWN_DOTS := [
	[363, 160], [905, 275], [1263, 160], [1273, 617], [380, 720],
	[1640, 913], [540, 1243], [47, 1330], [1035, 1650], [1880, 1540],
]

# Red dots: possible objective (Tag) locations. [px, py, label]
const OBJECTIVES := [
	[262, 97, "Warehouse"],
	[1695, 285, "Rapids Arena"],
	[1065, 578, "Park"],
	[558, 670, "Bank"],
	[772, 1115, "Meridian Tower"],
	[1462, 1075, "Casino"],
	[248, 1460, "Mall"],
	[1665, 1575, "Tenement Alley"],
]

# Roads (black lines) as pixel rects [x0, y0, x1, y1].
const ROADS := [
	[0, 805, 2000, 860],
	[0, 268, 720, 330],
	[690, 300, 752, 832],
	[948, 0, 1002, 240],
	[948, 210, 1240, 272],
	[1195, 240, 1258, 832],
	[1230, 545, 2000, 600],
	[445, 832, 505, 1700],
	[470, 1285, 1745, 1342],
	[1683, 840, 1748, 1312],
	[1360, 1310, 1418, 1700],
]


static func px(x: float, y: float) -> Vector2:
	return Vector2(x * SCALE - HALF_X, y * SCALE - HALF_Z)


static func px_rect(r: Array) -> Rect2:
	var a := px(r[0], r[1])
	var b := px(r[2], r[3])
	return Rect2(a, b - a)


static func valid_size(size: String) -> bool:
	return SIZES.has(size)


static func size_name(size: String) -> String:
	return SIZES.get(size, SIZES[DEFAULT_SIZE]).name


## Playable area of a map size, in metres.
static func size_bounds(size: String) -> Rect2:
	var d: Dictionary = SIZES.get(size, SIZES[DEFAULT_SIZE])
	return px_rect(d.rect)
