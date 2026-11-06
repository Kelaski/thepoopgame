class_name ParkSign extends Node3D
## A carved park entrance sign: a dark board between cedar posts, with the park's name on both faces.

## The name is sized down to fit this width (m).
@export var text_width := 2.8

@onready var _front: Label3D = $Front
@onready var _back: Label3D = $Back


func setup(park_name: String) -> void:
	var text := park_name.to_upper()
	var natural := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _front.font_size).x * _front.pixel_size
	for label: Label3D in [_front, _back]:
		label.text = text
		if natural > text_width:
			label.font_size = int(label.font_size * text_width / natural)
