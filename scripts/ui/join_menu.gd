class_name JoinMenu
extends Control
## "Play Game": type the join code the host gave you.

var main
var message := ""
var _code: LineEdit


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UiKit.MENU_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var v := UiKit.centered_panel(self, Vector2(460, 0))
	v.add_child(UiKit.label("PLAY GAME", 40, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UiKit.label("Enter the join code from the host's lobby.", 16, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	_code = LineEdit.new()
	_code.text = str(Settings.g("last_code"))
	_code.placeholder_text = "e.g. 6C8-4HKQ"
	_code.max_length = 32
	_code.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code.add_theme_font_size_override("font_size", 30)
	_code.text_submitted.connect(func(_t: String): _join())
	v.add_child(_code)
	var row := UiKit.hbox(10)
	var join := UiKit.button("Join", _join, 200)
	join.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var back := UiKit.button("Back", func(): main.show_main_menu(), 200)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(join)
	row.add_child(back)
	v.add_child(row)
	if message != "":
		v.add_child(UiKit.label(message, 18, Color("ff7a6a"), HORIZONTAL_ALIGNMENT_CENTER))
	_code.grab_focus.call_deferred()
	_code.select_all()


func _join() -> void:
	main.join_code(_code.text)
