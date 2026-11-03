class_name SkyboxMenu
extends Control
## Custom skybox: upload a 360° equirectangular panorama to replace the sky.
## Changes apply instantly (also mid-match). Only you see your skybox.

var on_back: Callable
var _preview: TextureRect
var _status: Label
var _dialog: FileDialog


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var v := UiKit.centered_panel(self, Vector2(640, 0))
	v.add_child(UiKit.label("SKYBOX", 34, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	var help := UiKit.label("Use a 360° panorama (equirectangular, about 2:1 wide), like the HDRIs from Poly Haven. PNG, JPG, WebP, BMP, TGA, HDR or EXR. Images are resized to fit 4096 px. Only you see your skybox.", 15, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size.x = 600
	v.add_child(help)

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(500, 260)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(frame)
	_preview = TextureRect.new()
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.custom_minimum_size = Vector2(470, 235)
	frame.add_child(_preview)

	var row := UiKit.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(UiKit.button("Choose Image...", _pick, 200))
	row.add_child(UiKit.button("Remove", _remove, 120))
	v.add_child(row)
	v.add_child(UiKit.check_row("Use custom skybox", Settings.g("sky_custom"), func(x): Settings.s("sky_custom", x)))
	v.add_child(UiKit.slider_row("Rotation", 0, 360, 1, Settings.g("sky_rotation"), func(x): Settings.s("sky_rotation", x), "%.0f°"))
	v.add_child(UiKit.slider_row("Brightness", 0.2, 3.0, 0.05, Settings.g("sky_energy"), func(x): Settings.s("sky_energy", x)))
	var note := UiKit.label("The sky also lights the world, so a darker skybox makes the map darker. The fog colour is set by \"Sky (horizon) / fog\" in Customize Colours.", 14, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 600
	v.add_child(note)
	_status = UiKit.label("", 15, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_status)
	var back := UiKit.hbox(10)
	back.alignment = BoxContainer.ALIGNMENT_CENTER
	back.add_child(UiKit.button("Back", _back, 200))
	v.add_child(back)

	_dialog = FileDialog.new()
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.use_native_dialog = true
	_dialog.title = "Choose a skybox panorama"
	_dialog.filters = UserImages.file_filters(UserImages.SKY_EXTENSIONS)
	_dialog.file_selected.connect(_on_file)
	add_child(_dialog)
	_refresh()


func _refresh() -> void:
	_preview.texture = UserImages.texture(UserImages.SKYBOX)
	if _preview.texture == null and _status.text == "":
		_status.text = "No custom skybox set - using the default sky."


func _pick() -> void:
	_dialog.popup_centered_ratio(0.7)


func _on_file(path: String) -> void:
	_status.text = "Importing..."
	await get_tree().process_frame
	var err := UserImages.import_image(path, UserImages.SKYBOX, UserImages.SKYBOX_MAX)
	if err != "":
		_status.text = err
		return
	_status.text = "Skybox updated."
	_refresh()
	_rebuild_with_custom_on()


func _rebuild_with_custom_on() -> void:
	# Turn the custom sky on and rebuild so the checkbox reflects it.
	Settings.s("sky_custom", true)
	_rebuild()


func _remove() -> void:
	UserImages.remove(UserImages.SKYBOX)
	_status.text = "Custom skybox removed."
	Settings.s("sky_custom", false)
	_rebuild()


func _rebuild() -> void:
	var fresh := SkyboxMenu.new()
	fresh.on_back = on_back
	get_tree().root.get_node("Main").replace_overlay(self, fresh)
	fresh._status.text = _status.text


func _back() -> void:
	if on_back.is_valid():
		on_back.call()
