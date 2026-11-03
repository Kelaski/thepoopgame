class_name CrosshairEditor
extends Control
## Counter-Strike style crosshair editor with live preview, share codes, custom
## crosshair images and custom sniper scopes.

var on_back: Callable
var _preview: Control
var _preview_spread := 0.0
var _status: Label
var _dialog: FileDialog
var _dialog_target := ""

# Share-code fields: key -> [type, min, max] (strings list allowed values)
const CODE_FIELDS := {
	"xh_style": ["s", Crosshair.STYLES],
	"xh_length": ["f", 0.0, 40.0],
	"xh_thickness": ["f", 1.0, 10.0],
	"xh_gap": ["f", -10.0, 30.0],
	"xh_alpha": ["f", 0.05, 1.0],
	"xh_outline": ["b"],
	"xh_outline_thickness": ["f", 0.5, 4.0],
	"xh_dot": ["b"],
	"xh_dot_size": ["f", 1.0, 10.0],
	"xh_tstyle": ["b"],
	"xh_dynamic": ["b"],
	"xh_image_scale": ["f", 0.25, 3.0],
	"crosshair_color": ["c"],
}

const COLOR_PRESETS := ["ffffff", "4dff6a", "ffd23f", "4de1ff", "ff4df0", "ff5a4d"]
const COLOR_NAMES := ["White", "Green", "Yellow", "Cyan", "Magenta", "Red"]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var v := UiKit.centered_panel(self, Vector2(980, 640))
	v.add_child(UiKit.label("CROSSHAIR EDITOR", 34, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	var body := UiKit.hbox(18)
	v.add_child(body)

	# --- Controls
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(640, 470)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(sc)
	var c := UiKit.vbox(8)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(c)
	var style_names := ["Classic", "Circle", "Dot only", "Custom image"]
	c.add_child(UiKit.option_row("Style", style_names, maxi(0, Crosshair.STYLES.find(str(Settings.g("xh_style")))), func(i): _apply("xh_style", Crosshair.STYLES[i])))
	var col_row := UiKit.hbox(12)
	var cl := UiKit.label("Colour")
	cl.custom_minimum_size.x = 260
	col_row.add_child(cl)
	var opt := OptionButton.new()
	for n in COLOR_NAMES:
		opt.add_item(n)
	opt.add_item("Custom")
	var cur := str(Settings.g("crosshair_color"))
	var ci := COLOR_PRESETS.find(cur)
	opt.selected = ci if ci >= 0 else COLOR_NAMES.size()
	opt.item_selected.connect(_on_color_preset)
	col_row.add_child(opt)
	var pick := ColorPickerButton.new()
	pick.custom_minimum_size = Vector2(90, 32)
	pick.edit_alpha = false
	pick.color = Settings.crosshair_color()
	pick.color_changed.connect(func(col: Color): _apply("crosshair_color", col.to_html(false)))
	col_row.add_child(pick)
	c.add_child(col_row)
	c.add_child(UiKit.slider_row("Opacity", 0.05, 1.0, 0.05, Settings.g("xh_alpha"), func(x): _apply("xh_alpha", x)))
	c.add_child(UiKit.slider_row("Length", 0, 40, 1, Settings.g("xh_length"), func(x): _apply("xh_length", x), "%.0f"))
	c.add_child(UiKit.slider_row("Thickness", 1, 10, 0.5, Settings.g("xh_thickness"), func(x): _apply("xh_thickness", x), "%.1f"))
	c.add_child(UiKit.slider_row("Gap", -10, 30, 1, Settings.g("xh_gap"), func(x): _apply("xh_gap", x), "%.0f"))
	c.add_child(UiKit.check_row("Outline", Settings.g("xh_outline"), func(x): _apply("xh_outline", x)))
	c.add_child(UiKit.slider_row("Outline thickness", 0.5, 4, 0.5, Settings.g("xh_outline_thickness"), func(x): _apply("xh_outline_thickness", x), "%.1f"))
	c.add_child(UiKit.check_row("Centre dot", Settings.g("xh_dot"), func(x): _apply("xh_dot", x)))
	c.add_child(UiKit.slider_row("Dot size", 1, 10, 0.5, Settings.g("xh_dot_size"), func(x): _apply("xh_dot_size", x), "%.1f"))
	c.add_child(UiKit.check_row("T-style (no top line)", Settings.g("xh_tstyle"), func(x): _apply("xh_tstyle", x)))
	c.add_child(UiKit.check_row("Dynamic (spreads with accuracy)", Settings.g("xh_dynamic"), func(x): _apply("xh_dynamic", x)))

	c.add_child(HSeparator.new())
	c.add_child(UiKit.label("CUSTOM CROSSHAIR IMAGE", 16, UiKit.ACCENT))
	var ir := UiKit.hbox(8)
	ir.add_child(UiKit.button("Upload Image...", _pick.bind(UserImages.CROSSHAIR), 170))
	ir.add_child(UiKit.button("Remove", _remove.bind(UserImages.CROSSHAIR), 100))
	c.add_child(ir)
	c.add_child(UiKit.slider_row("Image scale", 0.25, 3.0, 0.05, Settings.g("xh_image_scale"), func(x): _apply("xh_image_scale", x)))
	c.add_child(UiKit.label("Select Style > Custom image to use it. Transparent PNGs work best (max 256 px).", 14, UiKit.MUTED))

	c.add_child(HSeparator.new())
	c.add_child(UiKit.label("CUSTOM SNIPER SCOPE", 16, UiKit.ACCENT))
	var sr := UiKit.hbox(8)
	sr.add_child(UiKit.button("Upload Scope...", _pick.bind(UserImages.SCOPE), 170))
	sr.add_child(UiKit.button("Remove", _remove.bind(UserImages.SCOPE), 100))
	c.add_child(sr)
	c.add_child(UiKit.check_row("Use custom scope", Settings.g("scope_custom"), func(x): _apply("scope_custom", x)))
	c.add_child(UiKit.slider_row("Scope scale", 0.5, 2.0, 0.05, Settings.g("scope_scale"), func(x): _apply("scope_scale", x)))
	c.add_child(UiKit.label("Use a transparent PNG: the see-through middle is the view, the rest covers the screen.", 14, UiKit.MUTED))

	# --- Preview
	var right := UiKit.vbox(8)
	body.add_child(right)
	right.add_child(UiKit.label("PREVIEW", 16, UiKit.ACCENT))
	_preview = Control.new()
	_preview.custom_minimum_size = Vector2(280, 280)
	_preview.clip_contents = true
	_preview.draw.connect(_draw_preview)
	right.add_child(_preview)
	right.add_child(UiKit.slider_row("Spread", 0.0, 4.0, 0.1, 0.0, func(x): _preview_spread = x, "%.1f"))
	right.add_child(UiKit.button("Copy Share Code", _copy_code, 280))
	right.add_child(UiKit.button("Paste Share Code", _paste_code, 280))
	right.add_child(UiKit.button("Reset Crosshair", _reset, 280))
	_status = UiKit.label("", 14, UiKit.ACCENT)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = 280
	right.add_child(_status)

	var row := UiKit.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(UiKit.button("Back", _back, 200))
	v.add_child(row)

	_dialog = FileDialog.new()
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.use_native_dialog = true
	_dialog.filters = UserImages.file_filters()
	_dialog.file_selected.connect(_on_file)
	add_child(_dialog)


func _process(_delta: float) -> void:
	_preview.queue_redraw()


func _draw_preview() -> void:
	var s := _preview.size
	# Sky / wall / ground backdrop so the crosshair can be judged against the game.
	_preview.draw_rect(Rect2(0, 0, s.x, s.y * 0.45), Palette.get_color("sky_top"))
	_preview.draw_rect(Rect2(0, s.y * 0.45, s.x * 0.55, s.y * 0.55), Color("c8a36b"))
	_preview.draw_rect(Rect2(s.x * 0.55, s.y * 0.45, s.x * 0.45, s.y * 0.55), Color("3c3d42"))
	_preview.draw_rect(Rect2(s.x * 0.6, s.y * 0.25, s.x * 0.18, s.y * 0.45), Mats.team_color(1))
	Crosshair.draw_crosshair(_preview, (s * 0.5).floor(), _preview_spread)
	_preview.draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 1, 0.3), false, 2.0)


func _on_color_preset(i: int) -> void:
	if i < COLOR_PRESETS.size():
		_apply("crosshair_color", COLOR_PRESETS[i])


func _apply(key: String, value) -> void:
	Settings.s(key, value)


func _pick(target: String) -> void:
	_dialog_target = target
	_dialog.title = "Choose a crosshair image" if target == UserImages.CROSSHAIR else "Choose a scope image"
	_dialog.popup_centered_ratio(0.7)


func _on_file(path: String) -> void:
	var max_size := 256 if _dialog_target == UserImages.CROSSHAIR else 2048
	var err := UserImages.import_image(path, _dialog_target, max_size)
	if err != "":
		_status.text = err
		return
	if _dialog_target == UserImages.CROSSHAIR:
		Settings.s("xh_style", "image")
		_status.text = "Custom crosshair set."
		_rebuild()
	else:
		Settings.s("scope_custom", true)
		_status.text = "Custom scope set."
		_rebuild()


func _remove(target: String) -> void:
	UserImages.remove(target)
	if target == UserImages.CROSSHAIR and str(Settings.g("xh_style")) == "image":
		Settings.s("xh_style", "classic")
	if target == UserImages.SCOPE:
		Settings.s("scope_custom", false)
	_rebuild()


func _reset() -> void:
	for k in CODE_FIELDS.keys():
		Settings.values[k] = Settings.DEFAULTS[k]
	Settings.s("scope_custom", false)
	_rebuild()


## Share codes are base64 JSON. Pasted codes are parsed as data only: unknown keys
## are ignored and every value is type-checked and clamped.
func _copy_code() -> void:
	var d := {}
	for k in CODE_FIELDS.keys():
		d[k] = Settings.g(k)
	DisplayServer.clipboard_set("TAGXH-" + Marshalls.utf8_to_base64(JSON.stringify(d)))
	_status.text = "Share code copied to the clipboard."


func _paste_code() -> void:
	var code := DisplayServer.clipboard_get().strip_edges().left(4096)
	if not code.begins_with("TAGXH-"):
		_status.text = "The clipboard doesn't contain a crosshair code."
		return
	var parsed = JSON.parse_string(Marshalls.base64_to_utf8(code.substr(6)))
	if not (parsed is Dictionary):
		_status.text = "That crosshair code is invalid."
		return
	var applied := 0
	for k in CODE_FIELDS.keys():
		if not parsed.has(k):
			continue
		var spec: Array = CODE_FIELDS[k]
		var val = parsed[k]
		match spec[0]:
			"f":
				if val is float or val is int:
					Settings.values[k] = clampf(float(val), spec[1], spec[2])
					applied += 1
			"b":
				if val is bool:
					Settings.values[k] = val
					applied += 1
			"s":
				if val is String and val in spec[1]:
					Settings.values[k] = val
					applied += 1
			"c":
				if val is String and val.length() <= 9 and val.is_valid_html_color():
					Settings.values[k] = val
					applied += 1
	Settings.s("xh_style", Settings.values["xh_style"])
	_status.text = "Applied %d settings from the code." % applied
	_rebuild()


func _rebuild() -> void:
	var fresh := CrosshairEditor.new()
	fresh.on_back = on_back
	get_tree().root.get_node("Main").replace_overlay(self, fresh)
	fresh._status.text = _status.text


func _back() -> void:
	if on_back.is_valid():
		on_back.call()
