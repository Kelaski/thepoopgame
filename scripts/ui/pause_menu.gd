class_name PauseMenu
extends Control
## Pause overlay: Resume, Settings, Customization, End Match (host) and Quit
## (Close Server for the host) in the middle, and a small music player in the
## bottom-right corner.

var main
var _title: Label
var _play_btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var v := UiKit.centered_panel(self, Vector2(340, 0))
	v.add_child(UiKit.label("PAUSED", 34, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UiKit.label("(the match keeps running)", 14, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UiKit.button("Resume", func(): main.close_overlay()))
	v.add_child(UiKit.button("Settings", func(): main.open_settings(true)))
	v.add_child(UiKit.button("Customization", func(): main.open_customize(true)))
	if multiplayer.is_server():
		v.add_child(UiKit.button("End Match", _end_match))
		v.add_child(UiKit.button("Close Server", func(): main.leave_to_menu()))
	else:
		v.add_child(UiKit.button("Quit", func(): main.leave_to_menu()))
	_build_music_player()


func _end_match() -> void:
	main.close_overlay()
	Game.server_end_match()


## Bottom-right: what's playing, previous / play-pause / next, and music volume.
func _build_music_player() -> void:
	var pc := PanelContainer.new()
	add_child(pc)
	pc.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	pc.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pc.grow_vertical = Control.GROW_DIRECTION_BEGIN
	pc.offset_left = -20
	pc.offset_right = -20
	pc.offset_top = -20
	pc.offset_bottom = -20
	pc.custom_minimum_size.x = 320
	var v := UiKit.vbox(8)
	pc.add_child(v)
	v.add_child(UiKit.label("MUSIC", 14, UiKit.ACCENT))
	_title = UiKit.label("", 16)
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.custom_minimum_size.x = 296
	v.add_child(_title)
	var row := UiKit.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(UiKit.button("|<", func(): Sfx.prev_track(), 70))
	_play_btn = UiKit.button("||", _toggle_play, 90)
	row.add_child(_play_btn)
	row.add_child(UiKit.button(">|", func(): Sfx.skip_track(), 70))
	v.add_child(row)
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.01
	vol.value = float(Settings.g("music_volume"))
	vol.custom_minimum_size = Vector2(296, 24)
	vol.value_changed.connect(func(x: float): Settings.s("music_volume", x))
	var vrow := UiKit.hbox(8)
	vrow.add_child(UiKit.label("Volume", 14, UiKit.MUTED))
	vrow.add_child(vol)
	vol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(vrow)
	_refresh_player()


func _toggle_play() -> void:
	Sfx.toggle_pause()
	_refresh_player()


func _process(_delta: float) -> void:
	_refresh_player()


func _refresh_player() -> void:
	if not Sfx.music_active():
		_title.text = "No music playing"
	else:
		_title.text = ("Paused: " if Sfx.is_paused() else "") + Sfx.current_title
	_play_btn.text = ">" if Sfx.is_paused() else "||"
