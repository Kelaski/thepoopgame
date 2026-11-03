class_name SkyboxMenu
extends Control
## Custom skybox (assets/ui/skybox_menu.tscn): upload a 360° equirectangular
## panorama to replace the sky. Changes apply instantly (also mid-match). Only you
## see your skybox.

const SCENE := "res://assets/ui/skybox_menu.tscn"

var on_back: Callable


func _ready() -> void:
	%Dialog.filters = UserImages.file_filters(UserImages.SKY_EXTENSIONS)
	_refresh()


func _refresh() -> void:
	%Preview.texture = UserImages.texture(UserImages.SKYBOX)
	if %Preview.texture == null and %Status.text == "":
		%Status.text = "No custom skybox set - using the default sky."


func _on_choose_pressed() -> void:
	%Dialog.popup_centered_ratio(0.7)


func _on_file_selected(path: String) -> void:
	%Status.text = "Importing..."
	await get_tree().process_frame
	var err := UserImages.import_image(path, UserImages.SKYBOX, UserImages.SKYBOX_MAX)
	if err != "":
		%Status.text = err
		return
	%Status.text = "Skybox updated."
	_refresh()
	Settings.s("sky_custom", true)
	%UseCustom.get_node("%Check").set_pressed_no_signal(true)


func _on_remove_pressed() -> void:
	UserImages.remove(UserImages.SKYBOX)
	%Status.text = "Custom skybox removed."
	Settings.s("sky_custom", false)
	%UseCustom.get_node("%Check").set_pressed_no_signal(false)
	_refresh()


func _on_back_pressed() -> void:
	if on_back.is_valid():
		on_back.call()
