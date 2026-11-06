class_name ChatHints
extends VBoxContainer
## Sits above a chat input. While the text starts with "/", lists the commands it could
## become, and Tab fills it in. Pressing Tab again cycles through the choices.

var input: LineEdit
var _cycle: Array = []
var _cycle_index := 0
var _last_fill := ""


func attach(line_edit: LineEdit) -> void:
	input = line_edit
	input.text_changed.connect(_show_for)


func _input(event: InputEvent) -> void:
	if input == null or not input.has_focus() or not event is InputEventKey:
		return
	if event.pressed and not event.echo and event.keycode == KEY_TAB and _complete():
		get_viewport().set_input_as_handled()


func _matching(text: String) -> Array:
	return Commands.matching(text.substr(1)) if text.begins_with("/") and not " " in text else []


func _complete() -> bool:
	if input.text != _last_fill or _cycle.is_empty():
		_cycle = _matching(input.text)
		_cycle_index = -1
	if _cycle.is_empty():
		return false
	_cycle_index = (_cycle_index + 1) % _cycle.size()
	var fill: String = "/" + _cycle[_cycle_index] + " "
	_last_fill = fill
	input.text = fill
	input.caret_column = fill.length()
	_show_for(fill)
	return true


func _show_for(text: String) -> void:
	for child in get_children():
		child.queue_free()
	var found := _matching(text)
	visible = not found.is_empty()
	for k: String in found:
		add_child(UiKit.label("%s  -  %s" % [Commands.LIST[k].usage, Commands.LIST[k].desc], 15, Color(1.0, 0.86, 0.5)))
	if visible:
		add_child(UiKit.label("Tab to complete", 13, UiKit.MUTED))
