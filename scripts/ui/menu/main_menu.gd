class_name MainMenu
extends Control
## First screen (assets/ui/main_menu.tscn): host a lobby or browse for one, settings, quit.
## All play goes through Steam, which supplies your name.

var main
var message := ""


func _ready() -> void:
	%Host.disabled = not Net.steam_ok
	%Find.disabled = not Net.steam_ok
	%Host.pressed.connect(main.host_game)
	%Find.pressed.connect(%ServerBrowser.open.bind(main))
	%Settings.pressed.connect(main.open_settings.bind(false))
	%Quit.pressed.connect(get_tree().quit)
	%Message.text = message
	MenuKit.paint_accents(self)
