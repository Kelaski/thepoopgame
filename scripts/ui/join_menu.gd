class_name JoinMenu
extends Control
## "Play Game" (assets/ui/join_menu.tscn): type the join code the host gave you.

const SCENE := "res://assets/ui/join_menu.tscn"

var main
var message := ""


func _ready() -> void:
	var code: LineEdit = %Code
	code.text = str(Settings.g("last_code"))
	%Message.text = message
	%Message.visible = message != ""
	code.grab_focus.call_deferred()
	code.select_all()


func _on_join_pressed() -> void:
	main.join_code(%Code.text)


func _on_code_submitted(_text: String) -> void:
	_on_join_pressed()


func _on_back_pressed() -> void:
	main.show_main_menu()
