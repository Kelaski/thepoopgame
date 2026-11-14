class_name SketchMap
## Turns a hand-drawn map into a MapLayout. A sketch is a dictionary in sketch pixels; only the
## scale and road width come from MapRules. ClassicMap and SwiftCurrentMap each hold one.
##   kind, seed, size: Vector2
##   zones: [id, name, theme, [x0, y0, x1, y1], floors, floor height]
##   parks: {name, rect, and optionally pond, playground, court}, each [x0, y0, x1, y1]
##   roads: lists of [x, y] points      road_names (optional): one per road
##   spawns: [x, y]      objectives: [x, y, name]
##   bridges: [zone id, zone id], where crane beams can go. Each one is there by chance.


static func build(sketch: Dictionary, rules: MapRules) -> MapLayout:
	var s := rules.classic_scale
	var size: Vector2 = sketch.size
	var layout := MapLayout.new()
	layout.kind = sketch.kind
	layout.map_seed = sketch.seed
	layout.bounds = Rect2(-size * 0.5 * s, size * s)
	for z in sketch.zones:
		var rect := _rect(z[3], size, s)
		layout.buildings.append({"id": z[0], "name": z[1], "theme": z[2], "rect": rect, "floors": z[4], "floor_h": ProcGen.fit_storey(rect, z[5] * rules.floor_height_scale, rules)})
		var b: Dictionary = layout.buildings[-1]
		b["floor_hs"] = ProcGen.storey_heights(b.theme, b.floors, b.rect, b.floor_h, rules)
	for park in sketch.parks:
		var plan := {"name": park.name, "rect": _rect(park.rect, size, s)}
		for part: String in ["pond", "playground", "court"]:
			plan[part] = _rect(park[part], size, s) if park.has(part) else Rect2()
		layout.parks.append(plan)
	for road in sketch.roads:
		var pts := PackedVector2Array()
		for p in road:
			pts.append(_pt(p[0], p[1], size, s))
		layout.roads.append({"points": pts, "width": rules.classic_road_width})
	for p in sketch.spawns:
		layout.spawns.append(_pt(p[0], p[1], size, s))
	for o in sketch.objectives:
		layout.objectives.append({"pos": _pt(o[0], o[1], size, s), "name": o[2]})
	var rng := RandomNumberGenerator.new()
	rng.seed = sketch.seed
	var bridges: Array = sketch.bridges
	for i in bridges.size():
		if i < rules.crane_min or rng.randf() < rules.crane_chance:
			layout.bridges.append(bridges[i])
	layout.connect_roads(rules.classic_road_width * 1.2)
	var road_names: Array = sketch.get("road_names", [])
	for i in mini(road_names.size(), layout.roads.size()):
		layout.roads[i]["name"] = road_names[i]
	layout.raise_objectives(rng)
	layout.expand_edges(rules.edge_expansion)
	return layout


static func _pt(x: float, y: float, size: Vector2, s: float) -> Vector2:
	return (Vector2(x, y) - size * 0.5) * s


static func _rect(r: Array, size: Vector2, s: float) -> Rect2:
	var a := _pt(r[0], r[1], size, s)
	return Rect2(a, _pt(r[2], r[3], size, s) - a)
