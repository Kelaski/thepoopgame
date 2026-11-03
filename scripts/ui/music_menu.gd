class_name MusicMenu
extends Control
## Custom music: add songs, build a playlist (enable / reorder / remove / preview),
## and choose what plays during matches.

const SCENE := "res://assets/ui/music_menu.tscn"

var on_back: Callable
var _preview_file := ""


## Layout, the mode / shuffle / volume rows and the dialogs are in
## assets/ui/music_menu.tscn; the playlist rows are listed from Settings.
func _ready() -> void:
	var formats := "Supported: OGG, MP3, WAV (any bit depth)"
	if MusicLibrary.has_ffmpeg():
		formats += ", plus FLAC, M4A/AAC, Opus, WMA, AIFF and more via ffmpeg."
	else:
		formats += ". Install ffmpeg (ffmpeg.org) to also import FLAC, M4A/AAC, Opus, WMA, AIFF and more."
	%Formats.text = formats
	%Dialog.filters = MusicLibrary.file_filters()
	Sfx.import_finished.connect(_on_import_finished)
	if Sfx.importing():
		%Status.text = "Importing songs..."
	_refresh()


func _on_mode_selected(_mode: Variant) -> void:
	Settings.music_changed.emit()


func _on_shuffle_toggled(_on: bool) -> void:
	Settings.music_changed.emit()


func _on_preview_finished() -> void:
	_refresh()


func _on_file_selected(p: String) -> void:
	_on_files_selected(PackedStringArray([p]))

func _on_back_pressed() -> void:
	%Player.stop()
	if on_back.is_valid():
		on_back.call()


func _on_add_pressed() -> void:
	%Dialog.popup_centered_ratio(0.7)


func _on_folder_pressed() -> void:
	OS.shell_open(MusicLibrary.folder_path())


## Imports run on a background thread in Sfx (see Sfx.import_songs), so closing
## this menu mid-import is fine and the game never freezes.
func _on_files_selected(paths: PackedStringArray) -> void:
	if not Sfx.import_songs(paths):
		%Status.text = "Still importing the previous songs, please wait."
		return
	%Status.text = "Importing %d file(s)..." % paths.size()


func _on_import_finished(added: int, errors: Array, mode_switched: bool) -> void:
	if mode_switched:
		_rebuild()
		return
	var msg := "Added %d song(s)." % added
	if not errors.is_empty():
		msg += "  " + "  ".join(errors)
	%Status.text = msg
	_refresh()


func _rebuild() -> void:
	# Recreate the menu so the mode dropdown reflects the change.
	var fresh: MusicMenu = load(SCENE).instantiate()
	fresh.on_back = on_back
	get_tree().root.get_node("Main").replace_overlay(self, fresh)


func _refresh() -> void:
	for c in %List.get_children():
		c.queue_free()
	var tracks: Array = Settings.music_tracks()
	if tracks.is_empty():
		%List.add_child(UiKit.label("No songs yet. Click \"+ Add Songs...\" to import music from your computer.", 16, UiKit.MUTED))
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
		var playing: bool = %Player.playing and _preview_file == str(t.get("file", ""))
		row.add_child(UiKit.button("Stop" if playing else "Preview", _toggle_preview.bind(i), 100))
		var up := UiKit.button("Up", _move.bind(i, -1), 56)
		up.disabled = i == 0
		row.add_child(up)
		var down := UiKit.button("Down", _move.bind(i, 1), 70)
		down.disabled = i == tracks.size() - 1
		row.add_child(down)
		row.add_child(UiKit.button("Remove", _remove.bind(i), 90))
		%List.add_child(row)


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
		%Player.stop()
	MusicLibrary.remove_file(str(t.get("file", "")))
	tracks.remove_at(i)
	Settings.set_music_tracks(tracks)
	%Status.text = "Removed %s." % t.get("name", "song")
	_refresh()


func _toggle_preview(i: int) -> void:
	var tracks: Array = Settings.music_tracks()
	if i >= tracks.size():
		return
	var file := str(tracks[i].get("file", ""))
	if %Player.playing and _preview_file == file:
		%Player.stop()
	else:
		var s := MusicLibrary.load_stream(file)
		if s == null:
			%Status.text = "Could not load that song."
			return
		%Player.stream = s
		%Player.play()
		_preview_file = file
	_refresh()
