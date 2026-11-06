class_name SettingsMenu
extends Control
## Settings overlay (assets/ui/settings_menu.tscn). Every setting row is a SettingSlider /
## SettingCheck / SettingOption in the scene; the keybind rows are listed from Settings.ACTIONS.
## The View model tab is here too, and the Music, Colours, Crosshair and Spray tabs are each an
## instance of their own screen, with its own backdrop, title and Back button hidden.

const SCENE := "res://assets/ui/menu/settings_menu.tscn"

var on_back: Callable
var start_tab := ""  # the tab to open on
var _waiting_action := ""
var _bind_buttons := {}


func _ready() -> void:
	_build_binds()
	_build_presets()
	for tab_name in ["Music", "Colours", "Crosshair", "Spray"]:
		_embed(%Tabs.get_node(tab_name))
	for id: String in Weapons.ORDER:
		%PreviewWeapon.add_item(Weapons.display_name(id))
	%PreviewWeapon.item_selected.connect(func(i: int) -> void: %Preview.show_weapon(Weapons.ORDER[i]))
	%ResetView.pressed.connect(func() -> void:
		for key: String in ["viewmodel_x", "viewmodel_y", "viewmodel_z"]:
			Settings.s(key, 0.0)
		_rebuild())
	if start_tab != "":
		%Tabs.current_tab = %Tabs.get_node(start_tab).get_index()
	MenuKit.paint_accents(self)


## The quality preset row, at the top of the Video tab.
func _build_presets() -> void:
	var row := UiKit.hbox(12)
	var label := UiKit.label("Quality preset")
	label.custom_minimum_size.x = 260
	row.add_child(label)
	var pick := OptionButton.new()
	var names: Array = Settings.VIDEO_PRESETS.keys()
	for n: String in names:
		pick.add_item(n)
	pick.selected = -1
	pick.item_selected.connect(func(i: int) -> void:
		Settings.apply_preset(names[i])
		start_tab = "Video"
		_rebuild())
	row.add_child(pick)
	var video: Node = %Tabs.get_node("Video/VideoContent")
	video.add_child(row)
	video.move_child(row, 0)


## Strips a screen's own frame so it sits inside a tab.
func _embed(menu: Control) -> void:
	menu.set("on_back", Callable())
	for path in ["Dim", "Center/Panel/Content/Title"]:
		var n := menu.get_node_or_null(path) as CanvasItem
		if n:
			n.visible = false
	var back := menu.find_child("BackButton", true, false) as Control
	if back:
		back.visible = false
		# A row that only held the Back button goes too.
		var row := back.get_parent() as Control
		if row and row != menu and row.get_children().all(func(x): return not (x as CanvasItem).visible):
			row.visible = false
	var panel := menu.get_node_or_null("Center/Panel") as PanelContainer
	if panel:
		panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())


## A screen rebuilding itself (the crosshair editor and music menu do) swaps the
## fresh copy into the same tab.
func replace_tab(old: Control, fresh: Control) -> void:
	var tabs: TabContainer = %Tabs
	var i := old.get_index()
	var tab_name := old.name
	tabs.remove_child(old)
	old.queue_free()
	fresh.name = tab_name
	tabs.add_child(fresh)
	tabs.move_child(fresh, i)
	_embed(fresh)
	tabs.current_tab = i


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
	fresh.start_tab = start_tab if start_tab != "" else str(%Tabs.get_current_tab_control().name)
	var main = get_tree().root.get_node_or_null("Main")
	if main:
		main.replace_overlay(self, fresh)


func _on_back_pressed() -> void:
	# Let each screen tidy up as its own Back would (save colours, stop the music preview).
	for c in %Tabs.get_children():
		if c.has_method("_on_back_pressed"):
			c._on_back_pressed()
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
