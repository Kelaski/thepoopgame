class_name BirdEvent
extends CanvasLayer
## Rare easter egg: the sweaty guy pops up on screen for 2 seconds with birds chirping.
## While in a match there is a 1% chance every ROLL_INTERVAL seconds, and Ctrl+F4
## triggers it at any time. Local only (other players don't see it).

const IMAGE_PATH := "res://assets/sweaty_guy.png"
const SHOW_TIME := 2.0
const CHANCE := 0.01
const ROLL_INTERVAL := 30.0

var _rect: TextureRect
var _left := 0.0
var _roll_acc := 0.0


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


func _load_texture() -> Texture2D:
	# Normal path: the editor imports the PNG.
	if ResourceLoader.exists(IMAGE_PATH):
		var tex = load(IMAGE_PATH)
		if tex is Texture2D:
			return tex
	# Fallback: read the raw file (e.g. before the editor has imported it).
	var img := Image.load_from_file(ProjectSettings.globalize_path(IMAGE_PATH))
	if img:
		return ImageTexture.create_from_image(img)
	return null


func trigger() -> void:
	_left = SHOW_TIME
	_rect.visible = true
	Sfx.play("birds", 0.0, 1.0, "UI")


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F4 and event.ctrl_pressed:
		trigger()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _left > 0.0:
		_left -= delta
		if _left <= 0.0:
			_rect.visible = false
	if Game.in_match:
		_roll_acc += delta
		if _roll_acc >= ROLL_INTERVAL:
			_roll_acc = 0.0
			if randf() < CHANCE:
				trigger()
