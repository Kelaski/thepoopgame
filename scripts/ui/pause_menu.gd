class_name PauseMenu
extends Control

var main


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var v := UiKit.centered_panel(self, Vector2(380, 0))
	v.add_child(UiKit.label("PAUSED", 34, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UiKit.label("(the match keeps running)", 14, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UiKit.button("Resume", func(): main.close_overlay()))
	v.add_child(UiKit.button("Settings", func(): main.open_settings(true)))
	v.add_child(UiKit.button("Customize (music, colours, crosshair, spray, skybox)", func(): main.open_customize(true), 380))
	v.add_child(UiKit.button("Skip Song", func(): Sfx.skip_track()))
	if multiplayer.is_server():
		v.add_child(UiKit.button("End Match (back to lobby)", _end_match))
		v.add_child(UiKit.button("Close Server", func(): main.leave_to_menu()))
	else:
		v.add_child(UiKit.button("Leave Match", func(): main.leave_to_menu()))


func _end_match() -> void:
	main.close_overlay()
	Game.server_end_match()
