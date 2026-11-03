class_name CustomizeHub
extends Control
## Customization menu (assets/ui/customize_hub.tscn): player name and links to all
## the customization screens.

const SCENE := "res://assets/ui/customize_hub.tscn"

var main
var back_to_pause := false


func _ready() -> void:
	%NameEdit.text = str(Settings.g("player_name"))


func _on_name_changed(t: String) -> void:
	Settings.s("player_name", t)


func _on_music_pressed() -> void:
	main.open_music(back_to_pause, true)


func _on_colours_pressed() -> void:
	main.open_colors(back_to_pause, true)


func _on_crosshair_pressed() -> void:
	main.open_crosshair(back_to_pause, true)


func _on_spray_pressed() -> void:
	main.open_spray(back_to_pause, true)


func _on_skybox_pressed() -> void:
	main.open_skybox(back_to_pause, true)


func _on_back_pressed() -> void:
	if back_to_pause and Game.in_match:
		main.open_pause()
	else:
		main.close_overlay()
