class_name SprayMenu
extends Control
## Upload the image you spray on walls with the Spray key (assets/ui/spray_menu.tscn).

const SCENE := "res://assets/ui/spray_menu.tscn"

var on_back: Callable


func _ready() -> void:
	%Help.text = "Press %s in a match to spray this image on the wall you're looking at (5 second cooldown). Everyone in the match sees it. Your newest spray replaces your previous one." % Settings.bind_text("spray")
	%Dialog.filters = UserImages.file_filters()
	_refresh()


func _refresh() -> void:
	%Preview.texture = UserImages.texture(UserImages.SPRAY)
	if %Preview.texture == null and %Status.text == "":
		%Status.text = "No spray set."


func _on_choose_pressed() -> void:
	%Dialog.popup_centered_ratio(0.7)


func _on_file_selected(path: String) -> void:
	var err := UserImages.import_image(path, UserImages.SPRAY, 128)
	if err != "":
		%Status.text = err
		return
	%Status.text = "Spray updated."
	Net.upload_my_spray()
	_refresh()


func _on_remove_pressed() -> void:
	UserImages.remove(UserImages.SPRAY)
	%Status.text = "Spray removed."
	_refresh()


func _on_back_pressed() -> void:
	if on_back.is_valid():
		on_back.call()
