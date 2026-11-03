class_name ColorsMenu
extends Control
## Colour customization for menus, teams/Tag and the sky.
## Menu and sky colours update live; team colours apply when the next match loads.

var on_back: Callable
var _pickers := {}  # key -> ColorPickerButton


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var v := UiKit.centered_panel(self, Vector2(860, 620))
	v.add_child(UiKit.label("CUSTOMIZE COLOURS", 34, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))

	var presets := UiKit.hbox(8)
	presets.alignment = BoxContainer.ALIGNMENT_CENTER
	presets.add_child(UiKit.label("Presets:", 16, UiKit.MUTED))
	for preset in Palette.PRESETS.keys():
		presets.add_child(UiKit.button(preset, _apply_preset.bind(preset), 110))
	v.add_child(presets)

	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(820, 430)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(tabs)
	for group in ["Menus", "Teams & Tag", "Sky"]:
		var box := UiKit.vbox(8)
		for slot in Palette.SLOTS:
			if slot[3] == group:
				box.add_child(_row(slot[0], slot[1]))
		if group == "Sky":
			box.add_child(UiKit.label("Sky and fog colours change instantly. For a picture skybox, use Customize > Skybox.", 14, UiKit.MUTED))
		tabs.add_child(_tab(group, box))

	var row := UiKit.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(UiKit.button("Back", _back, 200))
	row.add_child(UiKit.button("Reset All Colours", _reset_all, 240))
	v.add_child(row)


func _tab(title: String, content: Control) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.name = title
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(content)
	return sc


func _row(key: String, text: String) -> HBoxContainer:
	var h := UiKit.hbox(12)
	var l := UiKit.label(text)
	l.custom_minimum_size.x = 300
	h.add_child(l)
	h.add_child(_picker(key))
	h.add_child(UiKit.button("Reset", _reset_one.bind(key), 90))
	return h


func _picker(key: String) -> ColorPickerButton:
	var p := ColorPickerButton.new()
	p.custom_minimum_size = Vector2(110, 34)
	p.color = Palette.get_color(key)
	p.edit_alpha = key.begins_with("ui_panel")
	p.color_changed.connect(_on_color_changed.bind(key))
	p.popup_closed.connect(Settings.save_settings)
	_pickers[key] = p
	return p


func _on_color_changed(c: Color, key: String) -> void:
	Settings.set_color(key, c, false)


func _reset_one(key: String) -> void:
	Settings.clear_color(key)
	_sync_pickers()


func _reset_all() -> void:
	Settings.set_colors({})
	_sync_pickers()


func _apply_preset(preset: String) -> void:
	Settings.set_colors(Palette.PRESETS.get(preset, {}))
	_sync_pickers()


func _sync_pickers() -> void:
	for key in _pickers:
		_pickers[key].color = Palette.get_color(key)


func _back() -> void:
	Settings.save_settings()
	if on_back.is_valid():
		on_back.call()
