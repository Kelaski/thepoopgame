class_name Skyline extends MultiMeshInstance3D
## The distant city: a ring of plain towers around the map, like the older game's, with lit windows
## from its shader. All one draw call, no collision. Roads run out between the towers.

const RING_GAP := 60.0
const RING_DEPTH := 90.0
const COLORS: Array[Color] = [Color("b85c4c"), Color("c98f4e"), Color("d4b483"), Color("6f8fae"), Color("5f9a8e"), Color("9a6f9e"), Color("a8a39a"), Color("7c8796")]
## Further towers fade toward this, like distant haze.
const HAZE := Color("a9b4c4")
const MAX_HAZE := 0.45
## Sizes come in whole floors and bays of the shader's window grid, so no window is ever cut in half.
const FLOOR_H := 3.6
const BAY_W := 3.2
## Clear ground kept along each road on its way out.
const ROAD_MARGIN := 6.0
const ROAD_REACH := 900.0


func build(layout: MapLayout, rng: RandomNumberGenerator, exits: Array) -> void:
	var towers := plots(layout, rng, exits)
	multimesh.instance_count = towers.size()
	for i in towers.size():
		var tower: Dictionary = towers[i]
		var foot: Rect2 = tower.foot
		var c := foot.get_center()
		multimesh.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(foot.size.x, tower.height, foot.size.y)), Vector3(c.x, tower.height * 0.5, c.y)))
		multimesh.set_instance_color(i, tower.color)


## Walks each side of a ring around the map, dropping towers of varied size and distance.
static func plots(layout: MapLayout, rng: RandomNumberGenerator, exits: Array) -> Array:
	var out := []
	var ring := layout.bounds.grow(RING_GAP)
	for side in 4:
		var horizontal := side < 2
		var from: float = (ring.position.x if horizontal else ring.position.y) - RING_DEPTH
		var to: float = (ring.end.x if horizontal else ring.end.y) + RING_DEPTH
		var fixed: float = [ring.position.y, ring.end.y, ring.position.x, ring.end.x][side]
		var outward := -1.0 if side % 2 == 0 else 1.0
		var t := from
		while t < to:
			var width := snappedf(rng.randf_range(12.0, 32.0), BAY_W)
			var depth := snappedf(rng.randf_range(12.0, 28.0), BAY_W)
			var height := snappedf(rng.randf_range(16.0, 55.0) if rng.randf() < 0.8 else rng.randf_range(60.0, 110.0), FLOOR_H)
			var distance := rng.randf_range(0.0, RING_DEPTH)
			var away := snappedf(fixed + outward * (distance + depth * 0.5) - depth * 0.5, BAY_W)
			var along := snappedf(t, BAY_W)
			var foot := Rect2(along, away, width, depth) if horizontal else Rect2(away, along, depth, width)
			t += width + rng.randf_range(3.0, 12.0)
			if not _on_a_road(foot, exits) and not _hits_another(foot, out):
				var color: Color = COLORS[rng.randi_range(0, COLORS.size() - 1)]
				out.append({"foot": foot, "height": height, "color": color.lerp(HAZE, MAX_HAZE * distance / RING_DEPTH)})
	return out


## Towers running into each other read as one building sliced in two.
static func _hits_another(foot: Rect2, towers: Array) -> bool:
	for tower in towers:
		if foot.grow(2.0).intersects(tower.foot):
			return true
	return false


static func _on_a_road(foot: Rect2, exits: Array) -> bool:
	for e in exits:
		if MapLayout._segment_hits_rect(e.at, (e.at as Vector2) + (e.away as Vector2) * ROAD_REACH, foot.grow(ROAD_MARGIN)):
			return true
	return false
