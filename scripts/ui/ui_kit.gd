class_name UiKit
## The in-game theme (MenuKit adds the menus' look on top) + small widget helpers. The screens are scenes in assets/ui;
## these helpers build the parts that are generated at runtime (lists, rows).

# Live palette (Settings > Colours). Call refresh() after changes.
static var BG := Color(0.08, 0.09, 0.11, 0.93)
static var BG_SOFT := Color(0.12, 0.13, 0.16, 0.95)
static var ACCENT := Color("ffd23f")
static var TEXT := Color("f2efe8")
static var MUTED := Color("a9a59c")
static var BUTTON := Color("2b2f38")
static var BUTTON_HOVER := Color("3b414e")
static var MENU_BG := Color("1b2430")


static func refresh() -> void:
	ACCENT = Palette.get_color("ui_accent")
	BG = Palette.get_color("ui_panel")
	BG_SOFT = Palette.get_color("ui_panel_soft")
	BUTTON = Palette.get_color("ui_button")
	BUTTON_HOVER = Palette.get_color("ui_button_hover")
	TEXT = Palette.get_color("ui_text")
	MUTED = Palette.get_color("ui_muted")
	MENU_BG = Palette.get_color("ui_menu_bg")


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
	var le := _sb(BUTTON.darkened(0.35), 6, 8.0)
	var focus := _sb(Color(0, 0, 0, 0), 8, 8.0)
	focus.border_color = ACCENT
	focus.set_border_width_all(2)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", focus)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_color", "Label", TEXT)
	# Type variations used by the scenes in assets/ui (Theme Type Variation in the
	# Inspector), so palette changes recolour every screen.
	for v: Array in [["TitleLabel", ACCENT], ["AccentLabel", ACCENT], ["MutedLabel", MUTED]]:
		t.set_type_variation(v[0], "Label")
		t.set_color("font_color", v[0], v[1])
	t.set_font_size("font_size", "TitleLabel", 34)
	# Outlined labels for the HUD and chat (readable over the game).
	for v: Array in [["HudLabel", Color.WHITE], ["HudAccentLabel", ACCENT], ["HudMutedLabel", MUTED]]:
		t.set_type_variation(v[0], "Label")
		t.set_color("font_color", v[0], v[1])
		t.set_constant("outline_size", v[0], 6)
		t.set_color("font_outline_color", v[0], Color(0, 0, 0, 0.85))
	return t


## color = null uses the theme's text colour (and follows palette changes).
static func label(text: String, size := 18, color = null, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	if color != null:
		l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	return l


static func outlined(text: String, size := 20, color = null, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
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


static func hbox(sep := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func format_time(t: float) -> String:
	var s := int(ceil(maxf(t, 0.0)))
	return "%d:%02d" % [s / 60, s % 60]
