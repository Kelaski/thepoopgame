class_name Mats
## Shared, cached materials. Toon diffuse + soft rim for a clean cartoon look.
## Sharing materials keeps draw-state changes (and memory) low.

const TEAM_NAMES := ["Red", "Blue"]
# Live colours (customizable in Customize Colours). Call refresh() after changes.
static var TEAM_COLORS := [Color("c0453a"), Color("4f7fae")]
static var TAG_COLOR := Color("ffd23f")


static func refresh() -> void:
	TEAM_COLORS = [Palette.get_color("team_red"), Palette.get_color("team_blue")]
	TAG_COLOR = Palette.get_color("tag")

static var _cache := {}


static func toon(color: Color) -> StandardMaterial3D:
	var key := "toon_" + color.to_html()
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.roughness = 0.85
	m.rim_enabled = true
	m.rim = 0.35
	m.rim_tint = 0.6
	_cache[key] = m
	return m


## Material for MultiMesh instances: colour comes from per-instance colour.
static func vertex_toon() -> StandardMaterial3D:
	if _cache.has("vtoon"):
		return _cache["vtoon"]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color.WHITE
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.7
	_cache["vtoon"] = m
	return m


static func glow(color: Color, alpha := 1.0, no_depth := false) -> StandardMaterial3D:
	var key := "glow_%s_%.2f_%s" % [color.to_html(), alpha, no_depth]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = no_depth
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache[key] = m
	return m


## Material for glowing MultiMesh parts: unshaded, the (over-bright) instance
## colour is drawn as is so it blooms.
static func vertex_glow() -> StandardMaterial3D:
	if _cache.has("vglow"):
		return _cache["vglow"]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	_cache["vglow"] = m
	return m


## A material from assets/materials/ by name (for prefab parts with a
## "material" meta, such as "water"). Falls back to the plain toon material.
static func named(name: String) -> Material:
	var key := "named_" + name
	if _cache.has(key):
		return _cache[key]
	var path := "res://assets/materials/%s.tres" % name
	var m: Material = load(path) if ResourceLoader.exists(path) else vertex_toon()
	_cache[key] = m
	return m


static func vertex_unshaded(no_depth := false) -> StandardMaterial3D:
	var key := "vun_%s" % no_depth
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = no_depth
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache[key] = m
	return m


static func team_color(team: int) -> Color:
	if team < 0 or team > 1:
		return Color.GRAY
	return TEAM_COLORS[team]


static func team_name(team: int) -> String:
	if team < 0 or team > 1:
		return "Nobody"
	return TEAM_NAMES[team]
