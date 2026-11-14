class_name ClassicMap
## The handcrafted Classic map, transcribed from the design sketch. Coordinates are
## sketch pixels (2000 x 1691). The layout is fixed: only the scale comes from MapRules.

const SKETCH_SIZE := Vector2(2000, 1691)
const SEED := 19

## [zone number, name, theme, [x0, y0, x1, y1], floors, floor height]
const ZONES := [
	[1, "Warehouse", "warehouse", [15, 15, 470, 235], 2, 6.0],
	[2, "School", "school", [560, 30, 880, 260], 3, 4.0],
	[3, "Gym", "gym", [1335, 55, 1955, 445], 2, 5.0],
	[4, "Movie Theater", "theater", [65, 400, 360, 745], 2, 5.0],
	[5, "Bank", "bank", [435, 400, 650, 770], 2, 4.5],
	[6, "Diner", "diner", [1315, 645, 1505, 785], 1, 4.5],
	[7, "Arcade", "arcade", [1525, 645, 1715, 780], 2, 4.0],
	[8, "Nightclub", "club", [1725, 645, 1895, 770], 2, 4.5],
	[9, "Bar", "bar", [1905, 645, 1985, 770], 1, 4.0],
	[10, "Apartments", "apartments", [75, 900, 380, 1320], 5, 3.6],
	[11, "Mall", "mall", [105, 1375, 395, 1680], 3, 5.0],
	[12, "Motel", "motel", [1865, 945, 1985, 1350], 2, 3.8],
	[13, "East Tenements", "tenement", [1495, 1405, 1810, 1540], 4, 3.6],
	[14, "South Tenements", "tenement", [1495, 1600, 1850, 1680], 3, 3.6],
	[15, "Office Tower", "office", [595, 945, 1030, 1205], 5, 3.8],
	[16, "Casino", "casino", [1175, 950, 1635, 1245], 5, 4.5],
	[17, "Water Treatment", "water", [590, 1400, 985, 1630], 1, 7.0],
	[18, "Library", "library", [1065, 1405, 1315, 1630], 2, 4.5],
]
const PARK := {"name": "Central Park", "rect": [790, 335, 1160, 775], "pond": [1005, 600, 1105, 740], "playground": [815, 365, 895, 410]}
## Black lines on the sketch.
const ROADS := [
	[[0, 280], [100, 300], [690, 320], [725, 400], [730, 835]],
	[[0, 800], [200, 838], [2000, 838]],
	[[975, 0], [965, 225], [1225, 250], [1250, 350], [1250, 838]],
	[[1250, 570], [1930, 570], [2000, 590]],
	[[470, 838], [470, 1100], [480, 1310], [480, 1691]],
	[[480, 1310], [1390, 1310], [1390, 1691]],
	[[1700, 838], [1735, 1300], [1390, 1310]],
]
## Purple dots.
const SPAWNS := [[363, 160], [1263, 160], [906, 275], [1273, 618], [380, 722],
	[1640, 913], [541, 1243], [48, 1330], [1880, 1542], [1034, 1648]]
## Red dots.
const OBJECTIVES := [[262, 96, "Warehouse"], [1696, 286, "Sports Complex"], [1065, 580, "Park"], [558, 670, "Bank"],
	[1463, 1075, "Casino"], [771, 1117, "Office Tower"], [248, 1459, "Mall"], [1666, 1577, "Tenement Alley"]]
## Where crane beams can go, rooftop to rooftop. Each one is there by chance.
const BRIDGES := [[4, 10], [15, 16], [15, 17], [13, 14], [1, 2]]


static func build(rules: MapRules) -> MapLayout:
	return SketchMap.build({"kind": "classic", "seed": SEED, "size": SKETCH_SIZE, "zones": ZONES, "parks": [PARK], "roads": ROADS,
		"spawns": SPAWNS, "objectives": OBJECTIVES, "bridges": BRIDGES}, rules)
