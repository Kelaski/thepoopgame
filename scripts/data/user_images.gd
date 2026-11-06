class_name UserImages
## Player-supplied images (spray, custom crosshair, custom sniper scope).
## Imported images are decoded, converted to RGBA, downscaled and re-saved as PNG
## in user://, so only clean PNG data is ever stored, shown or sent to others.

const SPRAY := "user://spray.png"
const CROSSHAIR := "user://crosshair.png"
const SCOPE := "user://scope.png"
const SPRAY_MAX_BYTES := 65536
const PNG_MAGIC := [137, 80, 78, 71, 13, 10, 26, 10]
const EXTENSIONS := ["png", "jpg", "jpeg", "webp", "bmp", "tga", "svg"]

static var _cache := {}


static func file_filters(exts: Array = EXTENSIONS) -> PackedStringArray:
	var pats := PackedStringArray()
	for e in exts:
		pats.append("*." + e)
	return PackedStringArray([", ".join(pats) + " ; Images"])


## Imports src into dest, downscaled to fit max_size. Returns an error message or "".
static func import_image(src: String, dest: String, max_size: int) -> String:
	if not (src.get_extension().to_lower() in EXTENSIONS):
		return "Unsupported image type. Use %s." % ", ".join(PackedStringArray(EXTENSIONS)).to_upper()
	var img := Image.load_from_file(src)
	if img == null or img.is_empty():
		return "Could not read that image."
	img.convert(Image.FORMAT_RGBA8)
	_fit(img, max_size)
	if dest == SPRAY:
		# Keep sprays small enough to send to other players.
		var size := max_size
		while true:
			var bytes := img.save_png_to_buffer()
			if bytes.size() <= SPRAY_MAX_BYTES or size <= 32:
				break
			size = int(size * 0.75)
			_fit(img, size)
	if img.save_png(dest) != OK:
		return "Could not save the image."
	_cache.erase(dest)
	return ""


static func _fit(img: Image, max_size: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	if w > max_size or h > max_size:
		var k := float(max_size) / maxi(w, h)
		img.resize(maxi(1, int(w * k)), maxi(1, int(h * k)), Image.INTERPOLATE_LANCZOS)


static func exists(path: String) -> bool:
	return FileAccess.file_exists(path)


static func remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_cache.erase(path)


static func texture(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		return null
	var tex := ImageTexture.create_from_image(img)
	_cache[path] = tex
	return tex


static func spray_bytes() -> PackedByteArray:
	if not FileAccess.file_exists(SPRAY):
		return PackedByteArray()
	return FileAccess.get_file_as_bytes(SPRAY)


## True if the bytes look like a PNG within the spray size limits. The size in the
## header is checked first, so a small file claiming a huge image is never decoded.
static func valid_spray_bytes(b: PackedByteArray) -> bool:
	if b.size() < 24 or b.size() > SPRAY_MAX_BYTES:
		return false
	for i in PNG_MAGIC.size():
		if b[i] != PNG_MAGIC[i]:
			return false
	# IHDR width / height: big-endian u32 at bytes 16 and 20.
	var w := (b[16] << 24) | (b[17] << 16) | (b[18] << 8) | b[19]
	var h := (b[20] << 24) | (b[21] << 16) | (b[22] << 8) | b[23]
	return w > 0 and h > 0 and w <= 256 and h <= 256


## Decodes received spray bytes safely (PNG only, at most 256x256).
static func decode_spray(b: PackedByteArray) -> Texture2D:
	if not valid_spray_bytes(b):
		return null
	var img := Image.new()
	if img.load_png_from_buffer(b) != OK:
		return null
	if img.get_width() > 256 or img.get_height() > 256 or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)
