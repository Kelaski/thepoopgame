class_name MainMenu
extends Control
## Title screen (assets/ui/main_menu.tscn): Host Game, Join Game, Settings,
## Customization, Quit. Your player name is set in Customization; joining by code
## is under Join Game.

var main
var message := ""


func _ready() -> void:
	%Message.text = message
	%Message.visible = message != ""


func _on_host_pressed() -> void:
	main.host_game()


func _on_play_pressed() -> void:
	main.show_join_menu()


func _on_settings_pressed() -> void:
	main.open_settings(false)


func _on_customize_pressed() -> void:
	main.open_customize(false)


func _on_quit_pressed() -> void:
	get_tree().quit()
