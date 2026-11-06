class_name MenuKit
## The menus' look: flat dark panels, sharp corners, one bold accent. Built on UiKit's
## theme, so label variations keep working; the in-game HUD keeps UiKit's own look.

const LINE := Color(1, 1, 1, 0.12)

static var _theme: Theme


static func theme() -> Theme:
	if _theme == null:
		_theme = Theme.new()
	_theme.merge_with(UiKit.make_theme())
	_base_styles(_theme)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Segoe UI", "Helvetica Neue", "Arial", "Liberation Sans"])
	font.font_weight = 600
	_theme.default_font = font
	_theme.default_font_size = 18
	var a := Palette.get_color("ui_accent")
	var panel := Palette.get_color("ui_panel")
	var button := Palette.get_color("ui_button")
	var hover := Palette.get_color("ui_button_hover")
	var t := _theme
	t.set_stylebox("panel", "PanelContainer", box(panel, 20, 0.0, LINE))
	t.set_stylebox("panel", "Panel", box(panel, 0, 0.0, LINE))
	t.set_stylebox("normal", "Button", box(button, 12))
	t.set_stylebox("hover", "Button", box(hover, 12))
	t.set_stylebox("pressed", "Button", box(a, 12))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), 12, 2.0, a))
	t.set_stylebox("disabled", "Button", box(Color(1, 1, 1, 0.03), 12))
	# Text on the accent stays readable whichever colour the accent is.
	var on_accent := Color(0.05, 0.05, 0.07) if a.get_luminance() > 0.5 else Color.WHITE
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", on_accent)
	t.set_color("font_selected_color", "TabContainer", on_accent)
	t.set_stylebox("normal", "LineEdit", box(Color(0, 0, 0, 0.5), 10, 1.0, LINE))
	t.set_stylebox("focus", "LineEdit", box(Color(0, 0, 0, 0.5), 10, 2.0, a))
	t.set_stylebox("normal", "OptionButton", box(button, 12))
	t.set_stylebox("hover", "OptionButton", box(hover, 12))
	t.set_stylebox("pressed", "OptionButton", box(a, 12))
	t.set_stylebox("panel", "TabContainer", box(panel, 16))
	t.set_stylebox("tab_selected", "TabContainer", box(a, 14))
	t.set_stylebox("tab_unselected", "TabContainer", box(Color(1, 1, 1, 0.05), 14))
	t.set_stylebox("tab_hovered", "TabContainer", box(hover, 14))
	t.set_stylebox("grabber_area", "HSlider", _groove(a))
	t.set_stylebox("grabber_area_highlight", "HSlider", _groove(a))
	t.set_stylebox("slider", "HSlider", _groove(Color(1, 1, 1, 0.15)))
	# A faint box behind the tick, so an unticked option can still be seen on the dark panels.
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		t.set_stylebox(state, "CheckBox", box(Color(1, 1, 1, 0.1), 2))
	return t


## Everything a menu widget needs that the flat look below doesn't replace.
static func _base_styles(t: Theme) -> void:
	var bn := UiKit._sb(UiKit.BUTTON, 8, 8.0)
	var bh := UiKit._sb(UiKit.BUTTON_HOVER, 8, 8.0)
	var bp := UiKit._sb(UiKit.ACCENT.darkened(0.1), 8, 8.0)
	var bd := UiKit._sb(UiKit.BUTTON.darkened(0.3), 8, 8.0)
	var bf := UiKit._sb(Color(0, 0, 0, 0), 8, 8.0)
	bf.border_color = UiKit.ACCENT
	bf.set_border_width_all(2)
	for type in ["Button", "OptionButton"]:
		t.set_stylebox("normal", type, bn)
		t.set_stylebox("hover", type, bh)
		t.set_stylebox("pressed", type, bp)
		t.set_stylebox("hover_pressed", type, bp)
		t.set_stylebox("disabled", type, bd)
		t.set_stylebox("focus", type, bf)
		t.set_color("font_color", type, UiKit.TEXT)
		t.set_color("font_hover_color", type, Color.WHITE)
		t.set_color("font_pressed_color", type, Color("1a1a1a"))
		t.set_color("font_hover_pressed_color", type, Color("1a1a1a"))
		t.set_color("font_focus_color", type, UiKit.TEXT)
		t.set_color("font_disabled_color", type, UiKit.MUTED)
	t.set_stylebox("panel", "TabContainer", UiKit._sb(UiKit.BG_SOFT, 8, 14.0))
	t.set_stylebox("tab_selected", "TabContainer", UiKit._sb(UiKit.BUTTON_HOVER, 6, 8.0))
	t.set_stylebox("tab_unselected", "TabContainer", UiKit._sb(UiKit.BUTTON.darkened(0.2), 6, 8.0))
	t.set_stylebox("tab_hovered", "TabContainer", UiKit._sb(UiKit.BUTTON, 6, 8.0))
	t.set_color("font_color", "CheckButton", UiKit.TEXT)
	t.set_color("font_color", "CheckBox", UiKit.TEXT)
	t.set_stylebox("panel", "ItemList", UiKit._sb(UiKit.BG_SOFT, 6, 6.0))
	t.set_color("font_selected_color", "TabContainer", UiKit.ACCENT)
	t.set_color("font_unselected_color", "TabContainer", UiKit.TEXT)
	# Dropdown lists: fully opaque with a border, so the options never blend into
	# the menu (or the match) behind them.
	var pop := UiKit._sb(Color(UiKit.BG_SOFT, 1.0).darkened(0.15), 6, 6.0)
	pop.set_border_width_all(1)
	pop.border_color = Color(UiKit.ACCENT, 0.6)
	t.set_stylebox("panel", "PopupMenu", pop)
	t.set_stylebox("hover", "PopupMenu", UiKit._sb(Color(UiKit.ACCENT, 0.35), 4, 4.0))
	t.set_color("font_color", "PopupMenu", UiKit.TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_font_size("font_size", "PopupMenu", 18)
	t.set_type_variation("MenuBackground", "Panel")
	var bg := StyleBoxFlat.new()
	bg.bg_color = UiKit.MENU_BG
	t.set_stylebox("panel", "MenuBackground", bg)


static func box(color: Color, margin: int, border := 0.0, border_color := Color.TRANSPARENT) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = color
	b.content_margin_left = margin
	b.content_margin_right = margin
	b.content_margin_top = margin * 0.6
	b.content_margin_bottom = margin * 0.6
	b.border_color = border_color
	b.set_border_width_all(int(border))
	return b


## A slider track takes its thickness from the stylebox's margins.
static func _groove(color: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = color
	b.content_margin_top = 3
	b.content_margin_bottom = 3
	return b


## Headings in the "accent" group follow the menu colour.
static func paint_accents(root: Node) -> void:
	for label in root.get_tree().get_nodes_in_group("accent"):
		label.add_theme_color_override("font_color", Palette.get_color("ui_accent"))
