class_name SettingCheck
extends HBoxContainer
## A labelled on/off row (assets/ui/rows/setting_check.tscn). If `setting` is set,
## it shows that setting and saves changes to it; either way it emits toggled.

signal toggled(on: bool)

@export var setting := ""
@export var label_text := "Setting"


func _ready() -> void:
	%Name.text = label_text
	var c: CheckButton = %Check
	if setting != "":
		c.button_pressed = bool(Settings.g(setting))
	c.toggled.connect(_on_toggled)


func _on_toggled(on: bool) -> void:
	if setting != "":
		Settings.s(setting, on)
	toggled.emit(on)
