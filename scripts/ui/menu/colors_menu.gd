class_name ColorsMenu
extends Control
## Colour customization (assets/ui/colors_menu.tscn) for menus and teams/Tag. The
## preset buttons and colour rows are listed from Palette.
## Menu colours update live; team colours apply when the next match loads.

const TABS := {"Menus": "%MenusList", "Teams & Tag": "%TeamsList"}

var on_back: Callable
var _pickers := {}  # key -> ColorPickerButton


func _ready() -> void:
	for preset in Palette.PRESETS.keys():
		%Presets.add_child(UiKit.button(preset, _apply_preset.bind(preset), 110))
	for slot in Palette.SLOTS:
		var list: VBoxContainer = get_node_or_null(TABS.get(slot[3], ""))
		if list:
			list.add_child(_row(slot[0], slot[1]))


func _row(key: String, text: String) -> HBoxContainer:
	var h := UiKit.hbox(12)
	var l := UiKit.label(text)
	l.custom_minimum_size.x = 300
	h.add_child(l)
	var p := ColorPickerButton.new()
	p.custom_minimum_size = Vector2(110, 34)
	p.color = Palette.get_color(key)
	p.edit_alpha = key.begins_with("ui_panel")
	p.color_changed.connect(_on_color_changed.bind(key))
	p.popup_closed.connect(Settings.save_settings)
	_pickers[key] = p
	h.add_child(p)
	h.add_child(UiKit.button("Reset", _reset_one.bind(key), 90))
	return h


func _on_color_changed(c: Color, key: String) -> void:
	Settings.set_color(key, c, false)


func _reset_one(key: String) -> void:
	Settings.clear_color(key)
	_sync_pickers()


func _on_reset_all_pressed() -> void:
	Settings.set_colors({})
	_sync_pickers()


func _apply_preset(preset: String) -> void:
	Settings.set_colors(Palette.PRESETS.get(preset, {}))
	_sync_pickers()


func _sync_pickers() -> void:
	for key in _pickers:
		_pickers[key].color = Palette.get_color(key)


func _on_back_pressed() -> void:
	Settings.save_settings()
	if on_back.is_valid():
		on_back.call()
