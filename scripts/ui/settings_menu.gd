class_name SettingsMenu
extends Control
## Settings overlay (assets/ui/settings_menu.tscn): Controls, Keybinds, Video,
## Audio and HUD tabs. Every setting row is a SettingSlider / SettingCheck /
## SettingOption in the scene; the keybind rows are listed from Settings.ACTIONS.

const SCENE := "res://assets/ui/settings_menu.tscn"

var on_back: Callable
var _waiting_action := ""
var _bind_buttons := {}


func _ready() -> void:
	_build_binds()


func _on_reset_all_pressed() -> void:
	Settings.reset_all()
	_rebuild()


func _on_reset_binds_pressed() -> void:
	Settings.reset_binds()
	_refresh_binds()


## Rebuilds the menu so every row shows the reset values.
func _rebuild() -> void:
	var fresh: SettingsMenu = load(SCENE).instantiate()
	fresh.on_back = on_back
	var main = get_tree().root.get_node_or_null("Main")
	if main:
		main.replace_overlay(self, fresh)


func _on_back_pressed() -> void:
	if on_back.is_valid():
		on_back.call()


func _build_binds() -> void:
	var list: VBoxContainer = %Binds
	for a in Settings.ACTIONS:
		var action: String = a[0]
		var h := UiKit.hbox(12)
		var l := UiKit.label(a[1])
		l.custom_minimum_size.x = 300
		h.add_child(l)
		var b := Button.new()
		b.text = Settings.bind_text(action)
		b.custom_minimum_size = Vector2(240, 38)
		b.pressed.connect(_start_rebind.bind(action))
		h.add_child(b)
		_bind_buttons[action] = b
		list.add_child(h)


func _start_rebind(action: String) -> void:
	_waiting_action = action
	_bind_buttons[action].text = "Press a key..."


func _refresh_binds() -> void:
	for action in _bind_buttons:
		_bind_buttons[action].text = Settings.bind_text(action)


func _input(event: InputEvent) -> void:
	if _waiting_action == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode != KEY_ESCAPE:
			var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			Settings.set_bind(_waiting_action, "k", code)
		_waiting_action = ""
		_refresh_binds()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		Settings.set_bind(_waiting_action, "m", event.button_index)
		_waiting_action = ""
		_refresh_binds()
		get_viewport().set_input_as_handled()
