class_name MainMenu
extends Control
## Title screen: Host Game, Play Game, Settings, Customization, Quit.
## Your player name is set in Customization; joining by code is under Play Game.

var main
var message := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UiKit.MENU_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var stripe := ColorRect.new()
	stripe.color = Color(1.0, 0.82, 0.25, 0.08)
	stripe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stripe.offset_top = 260
	stripe.offset_bottom = -420
	add_child(stripe)

	var v := UiKit.centered_panel(self, Vector2(420, 0))
	v.add_child(UiKit.label("TAG RUSH", 64, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UiKit.label("Grab the Tag. Protect your Runner. First to 4 rounds.", 18, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(HSeparator.new())
	v.add_child(UiKit.button("Host Game", func(): main.host_game()))
	v.add_child(UiKit.button("Play Game", func(): main.show_join_menu()))
	v.add_child(UiKit.button("Settings", func(): main.open_settings(false)))
	v.add_child(UiKit.button("Customization", func(): main.open_customize(false)))
	v.add_child(UiKit.button("Quit", func(): get_tree().quit()))
	if message != "":
		var m := UiKit.label(message, 18, Color("ff7a6a"), HORIZONTAL_ALIGNMENT_CENTER)
		m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		m.custom_minimum_size.x = 380
		v.add_child(m)

	var ver := UiKit.label("v" + GameVersion.CURRENT, 14, UiKit.MUTED)
	ver.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ver)
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ver.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ver.offset_left = -12
	ver.offset_right = -12
	ver.offset_top = -8
	ver.offset_bottom = -8
