class_name BirdEvent
extends CanvasLayer
## Rare easter egg: the sweaty guy pops up on screen while the bird-chirping clip plays
## (the image stays up for the full length of the audio).
## Every time you spawn in or respawn there is a 1% chance; Ctrl+F4 triggers it at
## any time. Local only (other players don't see it).

const IMAGE_PATH := "res://assets/sweaty_guy.png"
const SOUND_PATH := "res://assets/birds_chirping.ogg"
const CHANCE := 0.01

static var instance: BirdEvent

var _rect: TextureRect
var _audio: AudioStreamPlayer
var _left := 0.0


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = TextureRect.new()
	_rect.texture = _load_texture()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.visible = false
	add_child(_rect)
	_audio = AudioStreamPlayer.new()
	_audio.bus = "UI"
	_audio.stream = _load_sound()
	add_child(_audio)
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


## Called whenever the local player spawns or respawns.
static func roll() -> void:
	if instance and randf() < CHANCE:
		instance.trigger()


func _load_sound() -> AudioStream:
	if ResourceLoader.exists(SOUND_PATH):
		var s = load(SOUND_PATH)
		if s is AudioStream:
			return s
	# Fallback: read the raw file through res:// (globalize_path only works in the editor).
	if FileAccess.file_exists(SOUND_PATH):
		return AudioStreamOggVorbis.load_from_file(SOUND_PATH)
	return null


func _load_texture() -> Texture2D:
	# Normal path: the editor imports the PNG.
	if ResourceLoader.exists(IMAGE_PATH):
		var tex = load(IMAGE_PATH)
		if tex is Texture2D:
			return tex
	# Fallback: read the raw file through res:// (e.g. before the editor has imported it;
	# globalize_path only works in the editor).
	if not FileAccess.file_exists(IMAGE_PATH):
		return null
	var img := Image.new()
	if img.load_png_from_buffer(FileAccess.get_file_as_bytes(IMAGE_PATH)) != OK:
		return null
	return ImageTexture.create_from_image(img)


func trigger() -> void:
	_rect.visible = true
	if _audio.stream:
		_audio.play()
		_left = _audio.stream.get_length()
	else:
		_left = 2.0


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F4 and event.ctrl_pressed:
		trigger()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _left > 0.0:
		_left -= delta
		if _left <= 0.0:
			_rect.visible = false
