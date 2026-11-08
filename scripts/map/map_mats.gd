class_name MapMats
## Shared level materials, one per key, so a whole building batches into a few draw calls.
## Clean saturated colours: the style comes from flat paint, toon light and ink lines.

const SHADER: Shader = preload("res://assets/world/toon_world.gdshader")

## key -> [color, color2, pattern, pattern scale]
const TABLE := {
	# Outer walls.
	"paint_red": [Color(0.72, 0.3, 0.26), Color(0.72, 0.3, 0.26), 0, 1.0],
	"paint_tan": [Color(0.85, 0.68, 0.46), Color(0.85, 0.68, 0.46), 0, 1.0],
	"paint_dark": [Color(0.38, 0.32, 0.36), Color(0.38, 0.32, 0.36), 0, 1.0],
	"plaster": [Color(0.93, 0.87, 0.74), Color(0.9, 0.84, 0.7), 7, 0.4],
	"plaster_teal": [Color(0.3, 0.66, 0.66), Color(0.27, 0.61, 0.61), 7, 0.4],
	"plaster_blue": [Color(0.36, 0.5, 0.74), Color(0.33, 0.46, 0.7), 7, 0.4],
	"plaster_rose": [Color(0.88, 0.5, 0.48), Color(0.84, 0.46, 0.45), 7, 0.4],
	"plaster_purple": [Color(0.46, 0.3, 0.62), Color(0.42, 0.27, 0.58), 7, 0.4],
	"concrete": [Color(0.72, 0.71, 0.67), Color(0.67, 0.66, 0.62), 7, 0.4],
	"corrugated": [Color(0.56, 0.66, 0.68), Color(0.46, 0.56, 0.58), 4, 1.0],
	"corrugated_red": [Color(0.78, 0.36, 0.28), Color(0.64, 0.28, 0.22), 4, 1.0],
	"roof": [Color(0.42, 0.42, 0.45), Color(0.38, 0.38, 0.41), 7, 0.6],
	# Trim.
	"trim": [Color(0.24, 0.26, 0.32), Color(0.2, 0.2, 0.25), 0, 1.0],
	"trim_cream": [Color(0.97, 0.92, 0.78), Color(0.9, 0.85, 0.72), 0, 1.0],
	# Floors.
	"tile_light": [Color(0.86, 0.85, 0.8), Color(0.66, 0.66, 0.63), 2, 0.8],
	"tile_dark": [Color(0.32, 0.34, 0.4), Color(0.2, 0.2, 0.24), 2, 0.8],
	"tile_check": [Color(0.93, 0.92, 0.88), Color(0.26, 0.26, 0.3), 2, 1.0],
	"wood_floor": [Color(0.62, 0.42, 0.26), Color(0.62, 0.42, 0.26), 0, 1.0],
	"carpet_red": [Color(0.66, 0.2, 0.24), Color(0.6, 0.17, 0.22), 7, 1.0],
	"carpet_blue": [Color(0.26, 0.36, 0.6), Color(0.23, 0.32, 0.55), 7, 1.0],
	"court": [Color(0.8, 0.56, 0.32), Color(0.8, 0.56, 0.32), 0, 1.0],
	# City.
	"asphalt": [Color(0.3, 0.29, 0.33), Color(0.27, 0.26, 0.3), 6, 1.0],
	"pavement": [Color(0.74, 0.7, 0.64), Color(0.54, 0.5, 0.45), 9, 0.8],
	"road_line": [Color(0.97, 0.8, 0.28), Color(0.97, 0.8, 0.28), 0, 1.0],
	"road_white": [Color(0.95, 0.94, 0.9), Color(0.95, 0.94, 0.9), 0, 1.0],
	"kerb": [Color(0.72, 0.69, 0.62), Color(0.72, 0.69, 0.62), 0, 1.0],
	"grass": [Color(0.42, 0.72, 0.3), Color(0.36, 0.65, 0.27), 5, 0.5],
	"foliage": [Color(0.26, 0.62, 0.24), Color(0.26, 0.62, 0.24), 0, 1.0],
	"foliage_light": [Color(0.46, 0.72, 0.26), Color(0.46, 0.72, 0.26), 0, 1.0],
	"hedge": [Color(0.2, 0.48, 0.24), Color(0.2, 0.48, 0.24), 0, 1.0],
	"flower_red": [Color(0.92, 0.27, 0.32), Color(0.92, 0.27, 0.32), 0, 1.0],
	"flower_yellow": [Color(0.98, 0.84, 0.26), Color(0.98, 0.84, 0.26), 0, 1.0],
	"flower_pink": [Color(0.95, 0.52, 0.74), Color(0.95, 0.52, 0.74), 0, 1.0],
	"soil": [Color(0.4, 0.28, 0.2), Color(0.4, 0.28, 0.2), 0, 1.0],
	"rock": [Color(0.6, 0.6, 0.62), Color(0.6, 0.6, 0.62), 0, 1.0],
	"water": [Color(0.22, 0.66, 0.92), Color(0.3, 0.74, 0.96), 5, 0.3],
	"sand": [Color(0.94, 0.82, 0.56), Color(0.9, 0.78, 0.52), 5, 1.0],
	"grass_far": [Color(0.4, 0.68, 0.28), Color(0.36, 0.62, 0.26), 5, 0.06],
	# Materials for props.
	"bark": [Color(0.5, 0.33, 0.2), Color(0.34, 0.22, 0.13), 8, 4.0],
	"wood": [Color(0.56, 0.36, 0.2), Color(0.56, 0.36, 0.2), 0, 1.0],
	"wood_dark": [Color(0.36, 0.23, 0.14), Color(0.36, 0.23, 0.14), 0, 1.0],
	"metal": [Color(0.66, 0.7, 0.75), Color(0.6, 0.64, 0.7), 0, 1.0],
	"metal_dark": [Color(0.27, 0.29, 0.34), Color(0.24, 0.25, 0.3), 0, 1.0],
	"crane_base": [Color(0.96, 0.72, 0.14), Color(0.14, 0.14, 0.16), 10, 1.1],
	"crane": [Color(0.98, 0.74, 0.16), Color(0.86, 0.62, 0.12), 0, 1.0],
	"white": [Color(0.95, 0.95, 0.92), Color(0.9, 0.9, 0.87), 0, 1.0],
	"black": [Color(0.12, 0.12, 0.15), Color(0.12, 0.12, 0.15), 0, 1.0],
	"red": [Color(0.84, 0.22, 0.2), Color(0.7, 0.16, 0.14), 0, 1.0],
	"blue": [Color(0.22, 0.46, 0.84), Color(0.18, 0.36, 0.7), 0, 1.0],
	"teal": [Color(0.2, 0.68, 0.66), Color(0.2, 0.68, 0.66), 0, 1.0],
	"green": [Color(0.2, 0.58, 0.36), Color(0.14, 0.46, 0.28), 0, 1.0],
	"yellow": [Color(0.98, 0.78, 0.2), Color(0.86, 0.66, 0.14), 0, 1.0],
	"orange": [Color(0.98, 0.56, 0.16), Color(0.86, 0.46, 0.12), 0, 1.0],
	"purple": [Color(0.56, 0.3, 0.76), Color(0.46, 0.22, 0.64), 0, 1.0],
	"pink": [Color(0.94, 0.5, 0.68), Color(0.94, 0.5, 0.68), 0, 1.0],
	"fabric": [Color(0.5, 0.58, 0.68), Color(0.46, 0.53, 0.63), 0, 1.0],
	"rubber": [Color(0.16, 0.16, 0.18), Color(0.16, 0.16, 0.18), 0, 1.0],
	"glass": [Color(0.56, 0.82, 0.94), Color(0.56, 0.82, 0.94), 0, 1.0],
	"paper": [Color(0.96, 0.93, 0.82), Color(0.96, 0.93, 0.82), 0, 1.0],
	"chalkboard": [Color(0.14, 0.34, 0.26), Color(0.14, 0.34, 0.26), 0, 1.0],
	"gold": [Color(0.98, 0.78, 0.28), Color(0.86, 0.66, 0.22), 0, 1.0],
	"rug_dark": [Color(0.24, 0.25, 0.28), Color(0.24, 0.25, 0.28), 0, 1.0],
	"rug_red": [Color(0.78, 0.26, 0.26), Color(0.78, 0.26, 0.26), 0, 1.0],
	"rug_blue": [Color(0.26, 0.42, 0.72), Color(0.26, 0.42, 0.72), 0, 1.0],
	"rug_green": [Color(0.3, 0.56, 0.42), Color(0.3, 0.56, 0.42), 0, 1.0],
	"sign_red": [Color(0.86, 0.14, 0.14), Color(0.86, 0.14, 0.14), 0, 1.0],
	"sign_green": [Color(0.1, 0.46, 0.28), Color(0.1, 0.46, 0.28), 0, 1.0],
	"door_green": [Color(0.16, 0.46, 0.34), Color(0.16, 0.46, 0.34), 0, 1.0],
	"door_red": [Color(0.66, 0.2, 0.17), Color(0.66, 0.2, 0.17), 0, 1.0],
	"door_cream": [Color(0.9, 0.84, 0.68), Color(0.9, 0.84, 0.68), 0, 1.0],
	"door_inset": [Color(0.3, 0.25, 0.21), Color(0.3, 0.25, 0.21), 0, 1.0],
	"road_far": [Color(0.3, 0.29, 0.33), Color(0.3, 0.29, 0.33), 0, 1.0],
	"fence": [Color(0.13, 0.42, 0.2), Color(0.13, 0.42, 0.2), 0, 1.0],
	"fence_post": [Color(0.09, 0.3, 0.14), Color(0.09, 0.3, 0.14), 0, 1.0],
	# Imported props carry their colour in the vertices.
	"vc": [Color.WHITE, Color.WHITE, 0, 1.0],
	"vc_glow": [Color.WHITE, Color.WHITE, 0, 1.0],
	# Glowing.
	"lamp": [Color(1.0, 0.9, 0.66), Color(1, 1, 1), 0, 1.0],
	"screen": [Color(0.36, 0.82, 0.98), Color(1, 1, 1), 0, 1.0],
	"neon": [Color(1.0, 0.25, 0.68), Color(1, 1, 1), 0, 1.0],
	"traffic_red": [Color(1.0, 0.2, 0.15), Color(1, 1, 1), 0, 1.0],
	"traffic_green": [Color(0.2, 1.0, 0.45), Color(1, 1, 1), 0, 1.0],
}
## Materials that glow; lamps and screens get brighter at night.
const GLOW := {"vc_glow": 1.0, "lamp": 1.2, "screen": 1.0, "neon": 1.6, "traffic_red": 1.5, "traffic_green": 1.5}

static var _cache := {}


static func get_mat(key: String) -> Material:
	if not _cache.has(key):
		var row: Array = TABLE.get(key, TABLE["concrete"])
		_cache[key] = make(row[0], row[1], row[2], row[3], float(GLOW.get(key, 0.0)))
	return _cache[key]


static func make(c: Color, c2: Color, pattern := 0, scale := 1.0, glow := 0.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("color", Vector3(c.r, c.g, c.b))
	mat.set_shader_parameter("color2", Vector3(c2.r, c2.g, c2.b))
	mat.set_shader_parameter("pattern", pattern)
	mat.set_shader_parameter("pattern_scale", scale)
	mat.set_shader_parameter("glow", glow)
	return mat


## Called by the time-of-day blend.
static func set_night(night: float) -> void:
	var lamp: ShaderMaterial = get_mat("lamp")
	lamp.set_shader_parameter("glow", lerpf(0.5, float(GLOW["lamp"]) * 2.0, night))
