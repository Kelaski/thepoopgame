class_name CustomizeHub
extends Control
## Small menu that links to all the customization screens.

var main
var back_to_pause := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var v := UiKit.centered_panel(self, Vector2(420, 0))
	v.add_child(UiKit.label("CUSTOMIZE", 34, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UiKit.button("Music & Playlist", func(): main.open_music(back_to_pause, true)))
	v.add_child(UiKit.button("Colours", func(): main.open_colors(back_to_pause, true)))
	v.add_child(UiKit.button("Crosshair Editor", func(): main.open_crosshair(back_to_pause, true)))
	v.add_child(UiKit.button("Spray", func(): main.open_spray(back_to_pause, true)))
	v.add_child(UiKit.button("Back", _back))


func _back() -> void:
	if back_to_pause and Game.in_match:
		main.open_pause()
	else:
		main.close_overlay()
