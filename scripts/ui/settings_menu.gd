class_name SettingsMenu
extends Control
## Settings overlay: controls, keybinds (click to rebind), video, audio, HUD.

var on_back: Callable
var _waiting_action := ""
var _bind_buttons := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var v := UiKit.centered_panel(self, Vector2(860, 620))
	v.add_child(UiKit.label("SETTINGS", 34, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(820, 500)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(tabs)
	tabs.add_child(_tab("Controls", _controls()))
	tabs.add_child(_tab("Keybinds", _keybinds()))
	tabs.add_child(_tab("Video", _video()))
	tabs.add_child(_tab("Audio", _audio()))
	tabs.add_child(_tab("HUD", _hud()))
	var row := UiKit.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(UiKit.button("Back", _back, 200))
	row.add_child(UiKit.button("Reset All to Defaults", _reset_all, 260))
	v.add_child(row)


func _reset_all() -> void:
	Settings.reset_all()
	_rebuild()


func _reset_binds() -> void:
	Settings.reset_binds()
	_refresh_binds()


func _rebuild() -> void:
	var cb := on_back
	var parent := get_parent()
	var fresh := SettingsMenu.new()
	fresh.on_back = cb
	var main = get_tree().root.get_node_or_null("Main")
	if main and main.overlay == self:
		main.overlay = fresh
	parent.add_child(fresh)
	queue_free()


func _back() -> void:
	if on_back.is_valid():
		on_back.call()


func _tab(title: String, content: Control) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.name = title
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(content)
	return sc


func _controls() -> VBoxContainer:
	var v := UiKit.vbox(10)
	v.add_child(UiKit.slider_row("Mouse sensitivity", 0.01, 0.6, 0.005, Settings.g("sensitivity"), func(x): Settings.s("sensitivity", x), "%.3f"))
	v.add_child(UiKit.slider_row("ADS sensitivity multiplier", 0.2, 2.0, 0.05, Settings.g("ads_sens_mult"), func(x): Settings.s("ads_sens_mult", x)))
	v.add_child(UiKit.check_row("Invert Y axis", Settings.g("invert_y"), func(x): Settings.s("invert_y", x)))
	v.add_child(UiKit.check_row("Toggle aim (instead of hold)", Settings.g("toggle_aim"), func(x): Settings.s("toggle_aim", x)))
	v.add_child(UiKit.check_row("Toggle crouch (instead of hold)", Settings.g("toggle_crouch"), func(x): Settings.s("toggle_crouch", x)))
	v.add_child(UiKit.check_row("Always sprint", Settings.g("auto_sprint"), func(x): Settings.s("auto_sprint", x)))
	return v


func _keybinds() -> VBoxContainer:
	var v := UiKit.vbox(6)
	v.add_child(UiKit.label("Click a binding, then press the new key or mouse button (Esc cancels).", 15, UiKit.MUTED))
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
		v.add_child(h)
	v.add_child(UiKit.label("Esc (pause) is fixed.", 14, UiKit.MUTED))
	v.add_child(UiKit.button("Reset Keybinds", _reset_binds, 220))
	return v


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


func _video() -> VBoxContainer:
	var v := UiKit.vbox(10)
	v.add_child(UiKit.slider_row("Field of view (horizontal)", 90, 120, 1, Settings.g("fov"), func(x): Settings.s("fov", x), "%.0f"))
	v.add_child(UiKit.slider_row("Brightness", 0.5, 1.8, 0.05, Settings.g("brightness"), func(x): Settings.s("brightness", x)))
	v.add_child(UiKit.check_row("Fullscreen", Settings.g("fullscreen"), func(x): Settings.s("fullscreen", x)))
	v.add_child(UiKit.check_row("V-Sync", Settings.g("vsync"), func(x): Settings.s("vsync", x)))
	var caps := [30, 60, 120, 144, 165, 240, 0]
	var cap_names := ["30", "60", "120", "144", "165", "240", "Unlimited"]
	v.add_child(UiKit.option_row("Max FPS", cap_names, maxi(0, caps.find(int(Settings.g("max_fps")))), func(i): Settings.s("max_fps", caps[i])))
	v.add_child(UiKit.slider_row("Render scale (lower = faster)", 0.5, 1.0, 0.05, Settings.g("render_scale"), func(x): Settings.s("render_scale", x)))
	v.add_child(UiKit.option_row("Anti-aliasing (MSAA)", ["Off", "2x", "4x"], int(Settings.g("msaa")), func(i): Settings.s("msaa", i)))
	v.add_child(UiKit.check_row("Shadows", Settings.g("shadows"), func(x): Settings.s("shadows", x)))
	v.add_child(UiKit.slider_row("View distance (m)", 120, 400, 10, Settings.g("view_distance"), func(x): Settings.s("view_distance", x), "%.0f"))
	return v


func _audio() -> VBoxContainer:
	var v := UiKit.vbox(10)
	v.add_child(UiKit.slider_row("Master volume", 0.0, 1.0, 0.01, Settings.g("master_volume"), func(x): Settings.s("master_volume", x)))
	v.add_child(UiKit.slider_row("Effects volume", 0.0, 1.0, 0.01, Settings.g("sfx_volume"), func(x): Settings.s("sfx_volume", x)))
	v.add_child(UiKit.slider_row("Interface volume", 0.0, 1.0, 0.01, Settings.g("ui_volume"), func(x): Settings.s("ui_volume", x)))
	v.add_child(UiKit.slider_row("Music volume", 0.0, 1.0, 0.01, Settings.g("music_volume"), func(x): Settings.s("music_volume", x)))
	v.add_child(UiKit.check_row("Hitmarker sound", Settings.g("hitmarker_sound"), func(x): Settings.s("hitmarker_sound", x)))
	return v


func _hud() -> VBoxContainer:
	var v := UiKit.vbox(10)
	v.add_child(UiKit.check_row("Show FPS counter", Settings.g("show_fps"), func(x): Settings.s("show_fps", x)))
	v.add_child(UiKit.label("Crosshair style, colour, size, custom images and sniper scopes are in Customize > Crosshair Editor.", 15, UiKit.MUTED))
	return v
