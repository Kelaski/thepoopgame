class_name SprayMenu
extends Control
## Upload the image you spray on walls with the Spray key (T by default).

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
	var v := UiKit.centered_panel(self, Vector2(560, 0))
	v.add_child(UiKit.label("SPRAY", 34, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	var help := UiKit.label("Press %s in a match to spray this image on the wall you're looking at (5 second cooldown). Everyone in the match sees it. Your newest spray replaces your previous one." % Settings.bind_text("spray"), 15, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size.x = 520
	v.add_child(help)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(260, 260)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(frame)
	_preview = TextureRect.new()
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.custom_minimum_size = Vector2(230, 230)
	frame.add_child(_preview)
	var row := UiKit.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(UiKit.button("Choose Image...", _pick, 200))
	row.add_child(UiKit.button("Remove", _remove, 120))
	v.add_child(row)
	var fmt := UiKit.label("PNG, JPG, WebP, BMP, TGA or SVG. Images are resized to fit 128 px; transparent PNGs look best.", 14, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	fmt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fmt.custom_minimum_size.x = 520
	v.add_child(fmt)
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
	_dialog.title = "Choose a spray image"
	_dialog.filters = UserImages.file_filters()
	_dialog.file_selected.connect(_on_file)
	add_child(_dialog)
	_refresh()


func _refresh() -> void:
	_preview.texture = UserImages.texture(UserImages.SPRAY)
	if _preview.texture == null and _status.text == "":
		_status.text = "No spray set."


func _pick() -> void:
	_dialog.popup_centered_ratio(0.7)


func _on_file(path: String) -> void:
	var err := UserImages.import_image(path, UserImages.SPRAY, 128)
	if err != "":
		_status.text = err
		return
	_status.text = "Spray updated."
	Net.upload_my_spray()
	_refresh()


func _remove() -> void:
	UserImages.remove(UserImages.SPRAY)
	_status.text = "Spray removed."
	_refresh()


func _back() -> void:
	if on_back.is_valid():
		on_back.call()
