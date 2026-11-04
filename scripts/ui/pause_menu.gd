class_name PauseMenu
extends Control
## Pause overlay (assets/ui/pause_menu.tscn): Resume, Settings, Customization,
## End Match (host) and Quit (Close Server for the host) in the middle, and a small
## music player in the bottom-right corner.

var main


func _ready() -> void:
	var host := multiplayer.is_server()
	%EndMatchButton.visible = host
	%CloseServerButton.visible = host
	%QuitButton.visible = not host
	%Volume.set_value_no_signal(float(Settings.g("music_volume")))
	_refresh_player()


func _on_resume_pressed() -> void:
	main.close_overlay()


func _on_settings_pressed() -> void:
	main.open_settings(true)


func _on_customize_pressed() -> void:
	main.open_customize(true)


func _on_end_match_pressed() -> void:
	main.close_overlay()
	Game.server_end_match()


func _on_leave_pressed() -> void:
	main.leave_to_menu()


func _on_prev_pressed() -> void:
	Sfx.prev_track()


func _on_play_pressed() -> void:
	Sfx.toggle_pause()
	_refresh_player()


func _on_next_pressed() -> void:
	Sfx.skip_track()


func _on_volume_changed(x: float) -> void:
	Settings.s("music_volume", x)


func _process(_delta: float) -> void:
	_refresh_player()


func _refresh_player() -> void:
	if not Sfx.music_active():
		%SongTitle.text = "No music playing"
	else:
		%SongTitle.text = ("Paused: " if Sfx.is_paused() else "") + Sfx.current_title
	%PlayButton.text = ">" if Sfx.is_paused() else "||"
