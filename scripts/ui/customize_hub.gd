class_name CustomizeHub
extends Control
## Customization menu (assets/ui/customize_hub.tscn), laid out like Settings: one
## tab per screen. The Player tab has your name; the others are the Music,
## Colours, Crosshair, Spray and Skybox screens, each placed in its tab as an
## instance of its own scene, with its own dim backdrop, title and Back button
## hidden (this menu's Back closes them all).

var main
var back_to_pause := false


func _ready() -> void:
	%NameEdit.text = str(Settings.g("player_name"))
	%NameEdit.placeholder_text = Net.default_name()  # an empty box means this name
	for c in %Tabs.get_children():
		if c != %Tabs.get_node("Player"):
			_embed(c)


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


func _on_name_changed(t: String) -> void:
	Net.set_player_name(t)


func _on_back_pressed() -> void:
	# Let each screen tidy up as its own Back would (save colours, stop the music preview).
	for c in %Tabs.get_children():
		if c.has_method("_on_back_pressed"):
			c._on_back_pressed()
	if back_to_pause and Game.in_match:
		main.open_pause()
	else:
		main.close_overlay()
