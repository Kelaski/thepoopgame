class_name HoloReticle
extends Sprite3D
## The reticle projected in the AR and SMG holo sights (assets/models/holo_reticle.tscn).
## Drawn inside the sight's frame, unshaded and bright enough to glow, in the
## style, colour, size and brightness from the crosshair editor's Holo Sight
## section (holo_style, holo_color, holo_size, holo_brightness).

const STYLES := ["dot", "circle_dot", "chevron", "cross"]
const RES := 128           # texture size in pixels
const BASE_SIZE := 0.02   # reticle width in metres at holo_size 1.0

static var _textures := {}  # style -> ImageTexture


func _ready() -> void:
	_apply()
	Settings.changed.connect(_apply)


func _apply() -> void:
	texture = texture_for(str(Settings.g("holo_style")))
	pixel_size = BASE_SIZE * clampf(float(Settings.g("holo_size")), 0.5, 2.0) / RES
	var c := Color.from_string(str(Settings.g("holo_color")), Color("ff3b30"))
	var glow := clampf(float(Settings.g("holo_brightness")), 0.5, 3.0)
	modulate = Color(c.r * glow, c.g * glow, c.b * glow, 1.0)


## White reticle image for a style (tinted by modulate), cached per style.
static func texture_for(style: String) -> ImageTexture:
	if not style in STYLES:
		style = "circle_dot"
	if _textures.has(style):
		return _textures[style]
	var img := Image.create(RES, RES, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var c := RES * 0.5
	for y in RES:
		for x in RES:
			var p := Vector2(x + 0.5 - c, y + 0.5 - c)
			var a := _coverage(style, p, c)
			if a > 0.0:
				img.set_pixel(x, y, Color(1, 1, 1, a))
	var tex := ImageTexture.create_from_image(img)
	_textures[style] = tex
	return tex


## How much of the reticle covers pixel p (centre-relative, in pixels), 0..1,
## with a pixel of soft edge so it stays smooth.
static func _coverage(style: String, p: Vector2, c: float) -> float:
	var d := p.length()
	var dot := clampf(c * 0.12 - d + 0.5, 0.0, 1.0)
	match style:
		"dot":
			return clampf(c * 0.14 - d + 0.5, 0.0, 1.0)
		"circle_dot":
			var ring := clampf(c * 0.085 - absf(d - c * 0.78) + 0.5, 0.0, 1.0)
			return maxf(dot, ring)
		"chevron":
			# An upward-pointing chevron with its tip on the aim point.
			var w := c * 0.08
			var arm := minf(_seg(p, Vector2.ZERO, Vector2(-c * 0.55, c * 0.45)), _seg(p, Vector2.ZERO, Vector2(c * 0.55, c * 0.45)))
			return clampf(w - arm + 0.5, 0.0, 1.0)
		"cross":
			var w := c * 0.07
			var gap := c * 0.22
			var bars := 0.0
			if absf(p.y) <= w and absf(p.x) >= gap and absf(p.x) <= c * 0.85:
				bars = 1.0
			if absf(p.x) <= w and absf(p.y) >= gap and absf(p.y) <= c * 0.85:
				bars = 1.0
			return maxf(dot, bars)
	return dot


static func _seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)
