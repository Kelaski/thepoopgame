class_name CrosshairEditor
extends Control
## Counter-Strike style crosshair editor with live preview, share codes, custom
## crosshair images and custom sniper scopes.

const SCENE := "res://assets/ui/crosshair_editor.tscn"

var on_back: Callable
var _preview_spread := 0.0

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

var _dialog_target := ""
var start_status := ""  # message carried over when the editor rebuilds itself


## The setting rows are SettingSlider / SettingCheck / SettingOption nodes in
## assets/ui/crosshair_editor.tscn; this fills in the colour row and the preview.
func _ready() -> void:
	var opt: OptionButton = %ColorPreset
	opt.clear()
	for n in COLOR_NAMES:
		opt.add_item(n)
	opt.add_item("Custom")
	var ci := COLOR_PRESETS.find(str(Settings.g("crosshair_color")))
	opt.selected = ci if ci >= 0 else COLOR_NAMES.size()
	%ColorPicker.color = Settings.crosshair_color()
	%Preview.draw.connect(_draw_preview)
	%Dialog.filters = UserImages.file_filters()
	%Status.text = start_status


func _process(_delta: float) -> void:
	%Preview.queue_redraw()


func _on_spread_changed(x: float) -> void:
	_preview_spread = x


func _on_color_picked(col: Color) -> void:
	Settings.s("crosshair_color", col.to_html(false))

func _draw_preview() -> void:
	var pv: Control = %Preview
	var s := pv.size
	# Sky / wall / ground backdrop so the crosshair can be judged against the game.
	pv.draw_rect(Rect2(0, 0, s.x, s.y * 0.45), Palette.get_color("sky_top"))
	pv.draw_rect(Rect2(0, s.y * 0.45, s.x * 0.55, s.y * 0.55), Color("c8a36b"))
	pv.draw_rect(Rect2(s.x * 0.55, s.y * 0.45, s.x * 0.45, s.y * 0.55), Color("3c3d42"))
	pv.draw_rect(Rect2(s.x * 0.6, s.y * 0.25, s.x * 0.18, s.y * 0.45), Mats.team_color(1))
	Crosshair.draw_crosshair(pv, (s * 0.5).floor(), _preview_spread)
	pv.draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 1, 0.3), false, 2.0)


func _on_color_preset(i: int) -> void:
	if i < COLOR_PRESETS.size():
		_apply("crosshair_color", COLOR_PRESETS[i])


func _apply(key: String, value) -> void:
	Settings.s(key, value)


func _on_upload_crosshair_pressed() -> void:
	_pick(UserImages.CROSSHAIR)


func _on_upload_scope_pressed() -> void:
	_pick(UserImages.SCOPE)


func _on_remove_crosshair_pressed() -> void:
	_remove(UserImages.CROSSHAIR)


func _on_remove_scope_pressed() -> void:
	_remove(UserImages.SCOPE)


func _pick(target: String) -> void:
	_dialog_target = target
	%Dialog.title = "Choose a crosshair image" if target == UserImages.CROSSHAIR else "Choose a scope image"
	%Dialog.popup_centered_ratio(0.7)


func _on_file_selected(path: String) -> void:
	var max_size := 256 if _dialog_target == UserImages.CROSSHAIR else 2048
	var err := UserImages.import_image(path, _dialog_target, max_size)
	if err != "":
		%Status.text = err
		return
	if _dialog_target == UserImages.CROSSHAIR:
		Settings.s("xh_style", "image")
		%Status.text = "Custom crosshair set."
		_rebuild()
	else:
		Settings.s("scope_custom", true)
		%Status.text = "Custom scope set."
		_rebuild()


func _remove(target: String) -> void:
	UserImages.remove(target)
	if target == UserImages.CROSSHAIR and str(Settings.g("xh_style")) == "image":
		Settings.s("xh_style", "classic")
	if target == UserImages.SCOPE:
		Settings.s("scope_custom", false)
	_rebuild()


func _on_reset_pressed() -> void:
	for k in CODE_FIELDS.keys():
		Settings.values[k] = Settings.DEFAULTS[k]
	Settings.s("scope_custom", false)
	_rebuild()


## Share codes are base64 JSON. Pasted codes are parsed as data only: unknown keys
## are ignored and every value is type-checked and clamped.
func _on_copy_code_pressed() -> void:
	var d := {}
	for k in CODE_FIELDS.keys():
		d[k] = Settings.g(k)
	DisplayServer.clipboard_set("TAGXH-" + Marshalls.utf8_to_base64(JSON.stringify(d)))
	%Status.text = "Share code copied to the clipboard."


func _on_paste_code_pressed() -> void:
	var code := DisplayServer.clipboard_get().strip_edges().left(4096)
	if not code.begins_with("TAGXH-"):
		%Status.text = "The clipboard doesn't contain a crosshair code."
		return
	var parsed = JSON.parse_string(Marshalls.base64_to_utf8(code.substr(6)))
	if not (parsed is Dictionary):
		%Status.text = "That crosshair code is invalid."
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
	%Status.text = "Applied %d settings from the code." % applied
	_rebuild()


func _rebuild() -> void:
	var fresh: CrosshairEditor = load(SCENE).instantiate()
	fresh.on_back = on_back
	get_tree().root.get_node("Main").replace_overlay(self, fresh)
	fresh.start_status = %Status.text


func _on_back_pressed() -> void:
	if on_back.is_valid():
		on_back.call()
