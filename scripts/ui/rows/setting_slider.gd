class_name SettingSlider
extends HBoxContainer
## A labelled slider row (assets/ui/rows/setting_slider.tscn). If `setting` is set,
## it shows that setting and saves changes to it; either way it emits value_changed.

signal value_changed(value: float)

@export var setting := ""
@export var label_text := "Setting":
	set(v):
		label_text = v
		if is_node_ready():
			%Name.text = v
@export var min_value := 0.0
@export var max_value := 1.0
@export var step := 0.01
## printf-style format for the number shown on the right, e.g. "%.0f" or "%.2fx".
@export var format := "%.2f"
## Starting value when there's no setting.
@export var value := 0.0


func _ready() -> void:
	%Name.text = label_text
	var s: HSlider = %Slider
	s.min_value = min_value
	s.max_value = max_value
	s.step = step
	s.value = float(Settings.g(setting)) if setting != "" else value
	%Value.text = format % s.value
	s.value_changed.connect(_on_changed)


func _on_changed(v: float) -> void:
	%Value.text = format % v
	value = v
	if setting != "":
		Settings.s(setting, v)
	value_changed.emit(v)
