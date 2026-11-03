class_name MusicMenu
extends Control
## Custom music: add songs, build a playlist (enable / reorder / remove / preview),
## and choose what plays during matches.

var on_back: Callable
var _list: VBoxContainer
var _status: Label
var _dialog: FileDialog
var _preview: AudioStreamPlayer
var _preview_file := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var v := UiKit.centered_panel(self, Vector2(860, 620))
	v.add_child(UiKit.label("MUSIC", 34, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))

	var modes := ["builtin", "custom", "both"]
	var mode_names := ["Built-in Tag Rush beat", "My playlist", "My playlist + built-in beat"]
	v.add_child(UiKit.option_row("Play during matches", mode_names, maxi(0, modes.find(str(Settings.g("music_mode")))), func(i): _set_mode(modes[i])))
	v.add_child(UiKit.check_row("Shuffle playlist", Settings.g("music_shuffle"), _set_shuffle))
	v.add_child(UiKit.slider_row("Music volume", 0.0, 1.0, 0.01, Settings.g("music_volume"), func(x): Settings.s("music_volume", x)))

	v.add_child(HSeparator.new())
	var head := UiKit.hbox(10)
	head.add_child(UiKit.label("PLAYLIST", 18, UiKit.ACCENT))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	head.add_child(UiKit.button("+ Add Songs...", _open_dialog, 180))
	head.add_child(UiKit.button("Open Music Folder", _open_folder, 200))
	v.add_child(head)

	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 300)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	_list = UiKit.vbox(4)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_list)

	var formats := "Supported: OGG, MP3, WAV (any bit depth)"
	if MusicLibrary.has_ffmpeg():
		formats += ", plus FLAC, M4A/AAC, Opus, WMA, AIFF and more via ffmpeg."
	else:
		formats += ". Install ffmpeg (ffmpeg.org) to also import FLAC, M4A/AAC, Opus, WMA, AIFF and more."
	var fl := UiKit.label(formats, 14, UiKit.MUTED)
	fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(fl)
	_status = UiKit.label("", 15, UiKit.ACCENT)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_status)

	var row := UiKit.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(UiKit.button("Back", _back, 200))
	v.add_child(row)

	_preview = AudioStreamPlayer.new()
	_preview.bus = "Music"
	add_child(_preview)
	_preview.finished.connect(_refresh)

	_dialog = FileDialog.new()
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.use_native_dialog = true
	_dialog.title = "Add songs"
	_dialog.filters = MusicLibrary.file_filters()
	_dialog.files_selected.connect(_on_files_selected)
	_dialog.file_selected.connect(func(p: String): _on_files_selected(PackedStringArray([p])))
	add_child(_dialog)
	Sfx.import_finished.connect(_on_import_finished)
	if Sfx.importing():
		_status.text = "Importing songs..."
	_refresh()


func _set_mode(mode: String) -> void:
	Settings.s("music_mode", mode)
	Settings.music_changed.emit()


func _set_shuffle(on: bool) -> void:
	Settings.s("music_shuffle", on)
	Settings.music_changed.emit()


func _back() -> void:
	_preview.stop()
	if on_back.is_valid():
		on_back.call()


func _open_dialog() -> void:
	_dialog.popup_centered_ratio(0.7)


func _open_folder() -> void:
	OS.shell_open(MusicLibrary.folder_path())


## Imports run on a background thread in Sfx (see Sfx.import_songs), so closing
## this menu mid-import is fine and the game never freezes.
func _on_files_selected(paths: PackedStringArray) -> void:
	if not Sfx.import_songs(paths):
		_status.text = "Still importing the previous songs, please wait."
		return
	_status.text = "Importing %d file(s)..." % paths.size()


func _on_import_finished(added: int, errors: Array, mode_switched: bool) -> void:
	if mode_switched:
		_rebuild()
		return
	var msg := "Added %d song(s)." % added
	if not errors.is_empty():
		msg += "  " + "  ".join(errors)
	_status.text = msg
	_refresh()


func _rebuild() -> void:
	# Recreate the menu so the mode dropdown reflects the change.
	var fresh := MusicMenu.new()
	fresh.on_back = on_back
	get_tree().root.get_node("Main").replace_overlay(self, fresh)


func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var tracks: Array = Settings.music_tracks()
	if tracks.is_empty():
		_list.add_child(UiKit.label("No songs yet. Click \"+ Add Songs...\" to import music from your computer.", 16, UiKit.MUTED))
		return
	for i in tracks.size():
		var t: Dictionary = tracks[i]
		var row := UiKit.hbox(8)
		var on := CheckBox.new()
		on.button_pressed = t.get("enabled", true)
		on.tooltip_text = "Include in playlist"
		on.toggled.connect(_set_enabled.bind(i))
		row.add_child(on)
		var name_l := UiKit.label("%d.  %s" % [i + 1, t.get("name", "?")], 17)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.clip_text = true
		row.add_child(name_l)
		var playing: bool = _preview.playing and _preview_file == str(t.get("file", ""))
		row.add_child(UiKit.button("Stop" if playing else "Preview", _toggle_preview.bind(i), 100))
		var up := UiKit.button("Up", _move.bind(i, -1), 56)
		up.disabled = i == 0
		row.add_child(up)
		var down := UiKit.button("Down", _move.bind(i, 1), 70)
		down.disabled = i == tracks.size() - 1
		row.add_child(down)
		row.add_child(UiKit.button("Remove", _remove.bind(i), 90))
		_list.add_child(row)


func _set_enabled(on: bool, i: int) -> void:
	var tracks: Array = Settings.music_tracks()
	if i < tracks.size():
		tracks[i]["enabled"] = on
		Settings.set_music_tracks(tracks)


func _move(i: int, d: int) -> void:
	var tracks: Array = Settings.music_tracks()
	var j := i + d
	if j < 0 or j >= tracks.size():
		return
	var tmp = tracks[i]
	tracks[i] = tracks[j]
	tracks[j] = tmp
	Settings.set_music_tracks(tracks)
	_refresh()


func _remove(i: int) -> void:
	var tracks: Array = Settings.music_tracks()
	if i >= tracks.size():
		return
	var t: Dictionary = tracks[i]
	if _preview_file == str(t.get("file", "")):
		_preview.stop()
	MusicLibrary.remove_file(str(t.get("file", "")))
	tracks.remove_at(i)
	Settings.set_music_tracks(tracks)
	_status.text = "Removed %s." % t.get("name", "song")
	_refresh()


func _toggle_preview(i: int) -> void:
	var tracks: Array = Settings.music_tracks()
	if i >= tracks.size():
		return
	var file := str(tracks[i].get("file", ""))
	if _preview.playing and _preview_file == file:
		_preview.stop()
	else:
		var s := MusicLibrary.load_stream(file)
		if s == null:
			_status.text = "Could not load that song."
			return
		_preview.stream = s
		_preview.play()
		_preview_file = file
	_refresh()
