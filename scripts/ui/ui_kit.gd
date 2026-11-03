class_name UiKit
## Shared UI theme + small widget helpers (all UI is built in code).

const BG := Color(0.08, 0.09, 0.11, 0.93)
const BG_SOFT := Color(0.12, 0.13, 0.16, 0.95)
const ACCENT := Color("ffd23f")
const TEXT := Color("f2efe8")
const MUTED := Color("a9a59c")


static func _sb(col: Color, radius := 8, margin := 10.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin + 4.0
	s.content_margin_right = margin + 4.0
	s.content_margin_top = margin
	s.content_margin_bottom = margin
	return s


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18
	var panel := _sb(BG, 12, 18.0)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	var bn := _sb(Color("2b2f38"), 8, 8.0)
	var bh := _sb(Color("3b414e"), 8, 8.0)
	var bp := _sb(ACCENT.darkened(0.1), 8, 8.0)
	var bd := _sb(Color("1f2228"), 8, 8.0)
	var bf := _sb(Color(0, 0, 0, 0), 8, 8.0)
	bf.border_color = ACCENT
	bf.set_border_width_all(2)
	for type in ["Button", "OptionButton"]:
		t.set_stylebox("normal", type, bn)
		t.set_stylebox("hover", type, bh)
		t.set_stylebox("pressed", type, bp)
		t.set_stylebox("hover_pressed", type, bp)
		t.set_stylebox("disabled", type, bd)
		t.set_stylebox("focus", type, bf)
		t.set_color("font_color", type, TEXT)
		t.set_color("font_hover_color", type, Color.WHITE)
		t.set_color("font_pressed_color", type, Color("1a1a1a"))
		t.set_color("font_hover_pressed_color", type, Color("1a1a1a"))
		t.set_color("font_focus_color", type, TEXT)
		t.set_color("font_disabled_color", type, MUTED)
	var le := _sb(Color("1c1f25"), 6, 8.0)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", bf)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "TabContainer", _sb(BG_SOFT, 8, 14.0))
	t.set_stylebox("tab_selected", "TabContainer", _sb(Color("3b414e"), 6, 8.0))
	t.set_stylebox("tab_unselected", "TabContainer", _sb(Color("22252b"), 6, 8.0))
	t.set_stylebox("tab_hovered", "TabContainer", _sb(Color("2f343e"), 6, 8.0))
	t.set_color("font_selected_color", "TabContainer", ACCENT)
	t.set_color("font_unselected_color", "TabContainer", TEXT)
	t.set_stylebox("panel", "PopupMenu", _sb(BG_SOFT, 6, 6.0))
	return t


static func label(text: String, size := 18, color := TEXT, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	return l


static func outlined(text: String, size := 20, color := TEXT, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := label(text, size, color, align)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func button(text: String, cb: Callable, min_w := 240.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 44)
	b.pressed.connect(cb)
	return b


static func vbox(sep := 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


## Full-screen centred panel; returns the VBox to fill.
static func centered_panel(parent: Control, min_size := Vector2(480, 0)) -> VBoxContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(cc)
	var pc := PanelContainer.new()
	pc.custom_minimum_size = min_size
	cc.add_child(pc)
	var v := vbox(12)
	pc.add_child(v)
	return v


static func slider_row(text: String, min_v: float, max_v: float, step: float, value: float, cb: Callable, fmt := "%.2f") -> HBoxContainer:
	var h := hbox(12)
	var l := label(text)
	l.custom_minimum_size.x = 260
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(260, 28)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(s)
	var val := label(fmt % value, 18, ACCENT)
	val.custom_minimum_size.x = 70
	h.add_child(val)
	s.value_changed.connect(func(v: float): _on_slider(v, val, cb, fmt))
	return h


static func _on_slider(v: float, val: Label, cb: Callable, fmt: String) -> void:
	val.text = fmt % v
	cb.call(v)


static func check_row(text: String, value: bool, cb: Callable) -> HBoxContainer:
	var h := hbox(12)
	var l := label(text)
	l.custom_minimum_size.x = 260
	h.add_child(l)
	var c := CheckButton.new()
	c.button_pressed = value
	c.toggled.connect(cb)
	h.add_child(c)
	return h


static func option_row(text: String, items: Array, selected: int, cb: Callable) -> HBoxContainer:
	var h := hbox(12)
	var l := label(text)
	l.custom_minimum_size.x = 260
	h.add_child(l)
	var o := OptionButton.new()
	for it in items:
		o.add_item(str(it))
	o.selected = selected
	o.custom_minimum_size.x = 200
	o.item_selected.connect(cb)
	h.add_child(o)
	return h


static func format_time(t: float) -> String:
	var s := int(ceil(maxf(t, 0.0)))
	return "%d:%02d" % [s / 60, s % 60]
