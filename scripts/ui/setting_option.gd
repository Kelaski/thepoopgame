class_name SettingOption
extends HBoxContainer
## A labelled dropdown row (assets/ui/rows/setting_option.tscn). `items` are the
## names shown and `values` what gets saved to `setting` for each (same order).
## Emits selected with the chosen value.

signal selected(value: Variant)

@export var setting := ""
@export var label_text := "Setting"
@export var items: PackedStringArray = []
@export var values: Array = []


func _ready() -> void:
	%Name.text = label_text
	var o: OptionButton = %Option
	o.clear()
	for it in items:
		o.add_item(it)
	if setting != "":
		o.selected = maxi(0, values.find(Settings.g(setting)))
	o.item_selected.connect(_on_selected)


func _on_selected(i: int) -> void:
	var v: Variant = values[i] if i < values.size() else i
	if setting != "":
		Settings.s(setting, v)
	selected.emit(v)
