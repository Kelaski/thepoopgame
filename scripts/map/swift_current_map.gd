class_name SwiftCurrentMap
## A handcrafted map loosely based on Swift Current, Saskatchewan: the Trans-Canada Highway along the
## north, Railway St and Cheadle St crossing Central Ave downtown, and Riverside Park following the
## creek down the east side. Places are named after the town's; the layout is squeezed to fit, not
## surveyed. North is up. Coordinates are sketch pixels (2100 x 1750), like ClassicMap's.

const SKETCH_SIZE := Vector2(2100, 1750)
const SEED := 306

## [zone number, name, theme, [x0, y0, x1, y1], floors, floor height]
const ZONES := [
	# North of the highway.
	[1, "Swift Current Mall", "mall", [40, 30, 560, 240], 2, 5.0],
	[2, "Safari Inn", "motel", [640, 60, 940, 240], 2, 3.8],
	[3, "Living Sky Casino", "casino", [1060, 25, 1560, 240], 3, 4.5],
	[4, "Wheatland Mall", "mall", [1660, 30, 2060, 240], 2, 5.0],
	# Between the highway and Railway St.
	[5, "Comp High School", "school", [40, 400, 420, 730], 3, 4.0],
	[6, "Elmwood Apartments", "apartments", [540, 365, 930, 540], 5, 3.6],
	[7, "CPR Freight Shed", "warehouse", [540, 600, 930, 735], 1, 6.0],
	[8, "City Hall", "office", [1060, 365, 1480, 560], 4, 3.8],
	[9, "Rooming House", "tenement", [1060, 620, 1250, 735], 3, 3.6],
	[10, "Imperial Tavern", "bar", [1300, 620, 1480, 735], 1, 4.0],
	[11, "iPlex", "gym", [1600, 365, 2060, 730], 2, 5.0],
	# Downtown, between Railway St and Cheadle St.
	[12, "Chinook Library", "library", [40, 850, 420, 1010], 2, 4.5],
	[13, "Speedy Creek Diner", "diner", [40, 1070, 220, 1195], 1, 4.5],
	[14, "Central Arcade", "arcade", [260, 1070, 420, 1195], 2, 4.0],
	[15, "Lyric Theatre", "theater", [540, 850, 760, 1190], 2, 5.0],
	[16, "Credit Union", "bank", [1060, 850, 1260, 1190], 2, 4.5],
	[17, "Frontier Dance Hall", "club", [1310, 850, 1480, 1010], 2, 4.5],
	[18, "Herbert St Walk-ups", "tenement", [1310, 1060, 1480, 1190], 3, 3.6],
	# The south side.
	[19, "Museum", "library", [40, 1310, 420, 1500], 1, 4.5],
	[20, "Water Treatment", "water", [40, 1560, 420, 1730], 1, 7.0],
	[21, "Great Plains College", "school", [540, 1310, 940, 1540], 2, 4.0],
	[22, "South Side Tenements", "tenement", [540, 1600, 940, 1730], 3, 3.6],
	[23, "Kinetic Park Stockade", "warehouse", [1060, 1310, 1480, 1500], 1, 6.0],
	[24, "Creekside Motel", "motel", [1060, 1560, 1360, 1730], 2, 3.8],
	[25, "Elmwood Clubhouse", "bar", [1400, 1560, 1480, 1730], 1, 4.0],
]
## Riverside Park's pond is the creek. Features keep to one quarter of a park, clear of its paths.
const PARKS := [
	{"name": "Riverside Park", "rect": [1650, 850, 2080, 1730], "pond": [1890, 1320, 2020, 1670], "playground": [1710, 920, 1840, 1020], "court": [1890, 920, 2020, 1010]},
	{"name": "Memorial Park", "rect": [805, 850, 945, 1195]},
]
const ROADS := [
	[[0, 330], [700, 300], [2100, 300]],
	[[1000, 0], [1000, 1750]],
	[[0, 790], [2100, 790]],
	[[0, 1250], [1540, 1250]],
	[[480, 309], [480, 1750]],
	[[1540, 300], [1540, 1750]],
]
const ROAD_NAMES := ["Trans-Canada Hwy", "Central Ave", "Railway St", "Cheadle St", "11th Ave NW", "Memorial Dr"]
const SPAWNS := [[600, 150], [1610, 140], [480, 575], [1275, 590], [1990, 790], [60, 1250],
	[1000, 1020], [1540, 1000], [480, 1650], [1000, 1700], [1540, 1640], [230, 1040]]
const OBJECTIVES := [[300, 135, "Swift Current Mall"], [1310, 130, "Living Sky Casino"], [230, 565, "Comp High School"],
	[1830, 550, "iPlex"], [650, 1020, "Lyric Theatre"], [1160, 1020, "Credit Union"], [1760, 1500, "Riverside Park"],
	[740, 1425, "Great Plains College"], [1260, 1405, "Kinetic Park"], [230, 1645, "Water Treatment"]]
## Where crane beams can go, rooftop to rooftop. Each one is there by chance.
const BRIDGES := [[17, 18], [1, 2], [21, 22], [9, 10], [12, 14], [8, 9]]


static func build(rules: MapRules) -> MapLayout:
	return SketchMap.build({"kind": "swiftcurrent", "seed": SEED, "size": SKETCH_SIZE, "zones": ZONES, "parks": PARKS, "roads": ROADS,
		"road_names": ROAD_NAMES, "spawns": SPAWNS, "objectives": OBJECTIVES, "bridges": BRIDGES}, rules)
