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

## Each dropdown's choices by setting: [names, saved values]. They live here as
## well as in the scenes because exported builds lost the arrays set on the
## instanced rows, leaving the dropdowns empty.
const CHOICES := {
	"msaa": [["Off", "2x", "4x"], [0, 1, 2]],
	"shadow_quality": [["Low (70 m)", "Medium (130 m)", "High (220 m)", "Ultra (320 m)"], [0, 1, 2, 3]],
	"interior_lights": [["Off", "Low", "High"], [0, 1, 2]],
	"music_mode": [["Tag Rush Theme", "My playlist", "My playlist + Tag Rush Theme"], ["builtin", "custom", "both"]],
	"xh_style": [["Classic", "Circle", "Dot only", "Custom image"], ["classic", "circle", "dot", "image"]],
	"holo_style": [["Dot", "Circle and dot", "Chevron", "Cross"], ["dot", "circle_dot", "chevron", "cross"]],
	"holo_color": [["Red", "Green", "Cyan", "Yellow", "Magenta", "White"], ["ff3b30", "4dff6a", "4de1ff", "ffd23f", "ff4df0", "ffffff"]],
}


func _ready() -> void:
	if CHOICES.has(setting):
		items = PackedStringArray(CHOICES[setting][0])
		values = (CHOICES[setting][1] as Array).duplicate()
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
