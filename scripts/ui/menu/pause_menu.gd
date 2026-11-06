class_name PauseMenu
extends Control
## Pause overlay (assets/ui/pause_menu.tscn): Resume, Settings, Music player, End Match (host) and
## Leave (Close Server for the host), with the music controls in the corner.

var main


func _ready() -> void:
	var host := multiplayer.is_server()
	%EndMatch.visible = host
	%Leave.text = "Close Server" if host else "Leave game"
	%Resume.pressed.connect(main.close_overlay)
	%Settings.pressed.connect(main.open_settings.bind(true))
	%Music.pressed.connect(main.open_settings.bind(true, "Music"))
	%EndMatch.pressed.connect(func() -> void:
		main.close_overlay()
		Game.server_end_match())
	%Leave.pressed.connect(main.leave_to_menu.bind(""))
	MenuKit.paint_accents(self)
