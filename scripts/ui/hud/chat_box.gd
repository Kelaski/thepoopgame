class_name ChatBox
extends Control
## Chat window (bottom-left). Enter = all chat, Right Shift + Enter = team chat (the
## chat key is rebindable; team chat is always Right Shift + it).
## Typing "/" at the start shows command autocomplete: Tab completes,
## Up / Down choose, Enter sends, Esc cancels.
## Messages are shown as plain text in Labels (no BBCode), so nothing a player
## types can be interpreted as markup or code.

const MAX_LINES := 40
const SHOW_LINES := 8
const FADE_TIME := 10.0

var typing := false
var team_only := false
var _rshift := false  # Right Shift held (Godot can't tell the two Shifts apart from the Enter event)

# Layout is in assets/ui/chat_box.tscn; message and suggestion rows are added in code.
@onready var _log: VBoxContainer = %Log
@onready var _suggest_panel: PanelContainer = %SuggestPanel
@onready var _suggest_box: VBoxContainer = %SuggestBox
@onready var _input_row: HBoxContainer = %InputRow
@onready var _prefix: Label = %Prefix
@onready var _edit: LineEdit = %Edit
var _matches: Array = []
var _sel := 0


func _ready() -> void:
	_edit.max_length = Sanitize.MAX_CHAT
	Net.chat_message.connect(_on_message)
	Net.disconnected.connect(_on_disconnected)


func _on_disconnected(_reason: String) -> void:
	_clear()

func _process(delta: float) -> void:
	visible = Net.online and Game.in_match  # the lobby has its own chat
	for row in _log.get_children():
		var t: float = row.get_meta("t", 0.0) - delta
		row.set_meta("t", t)
		row.modulate.a = 1.0 if typing else clampf(t, 0.0, 1.0)
	# Only the most recent lines are shown.
	var n := _log.get_child_count()
	for i in n:
		_log.get_child(i).visible = i >= n - (SHOW_LINES + 4 if typing else SHOW_LINES)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	if event.keycode == KEY_SHIFT and event.location == KEY_LOCATION_RIGHT:
		_rshift = event.pressed
	if not event.pressed or event.echo:
		return
	if not typing:
		if not Net.online or Game.ui_open:
			return
		if event.is_action("chat"):
			# Right Shift + the chat key opens team chat (during a match).
			_open(_rshift and Game.in_match)
			get_viewport().set_input_as_handled()
		return
	match event.keycode:
		KEY_ESCAPE:
			_close()
			get_viewport().set_input_as_handled()
		KEY_TAB:
			_complete()
			get_viewport().set_input_as_handled()
		KEY_UP:
			if _suggest_panel.visible and not _matches.is_empty():
				_sel = posmod(_sel - 1, _matches.size())
				_show_suggestions()
				get_viewport().set_input_as_handled()
		KEY_DOWN:
			if _suggest_panel.visible and not _matches.is_empty():
				_sel = posmod(_sel + 1, _matches.size())
				_show_suggestions()
				get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_rshift = false  # the key-up never arrives if you alt-tab while holding it


func _open(team: bool) -> void:
	typing = true
	team_only = team
	Game.typing = true
	_prefix.text = "TEAM:" if team else "ALL:"
	_prefix.add_theme_color_override("font_color", Mats.team_color(Net.team_of(multiplayer.get_unique_id())).lightened(0.35) if team else UiKit.ACCENT)
	_edit.text = ""
	_input_row.visible = true
	_suggest_panel.visible = false
	_edit.grab_focus()


func _close() -> void:
	typing = false
	Game.typing = false
	_edit.release_focus()
	_edit.text = ""
	_input_row.visible = false
	_suggest_panel.visible = false


func _on_submit(text: String) -> void:
	# If a suggestion is highlighted and the command isn't typed out yet, complete it first.
	if _suggest_panel.visible and not _matches.is_empty():
		var typed := text.substr(1).split(" ", false)
		var cmd: String = typed[0].to_lower() if typed.size() > 0 else ""
		if cmd != _matches[_sel]:
			_complete()
			return
	Net.send_chat(text, team_only)
	_close()


func _on_text_changed(text: String) -> void:
	if text.begins_with("/") and not text.contains(" "):
		_matches = Commands.matching(text.substr(1))
		_sel = 0
		_show_suggestions()
	else:
		_matches = []
		_suggest_panel.visible = false


func _show_suggestions() -> void:
	for c in _suggest_box.get_children():
		c.queue_free()
	if _matches.is_empty():
		_suggest_panel.visible = true
		_suggest_box.add_child(UiKit.label("No matching commands", 15, UiKit.MUTED))
		return
	_suggest_panel.visible = true
	for i in _matches.size():
		var k: String = _matches[i]
		var info: Dictionary = Commands.LIST[k]
		var row := UiKit.hbox(10)
		var name_l := UiKit.label(info.usage, 16, UiKit.ACCENT if i == _sel else UiKit.TEXT)
		name_l.custom_minimum_size.x = 120
		row.add_child(name_l)
		row.add_child(UiKit.label(info.desc, 14, UiKit.MUTED))
		if i == _sel:
			row.add_child(UiKit.label("[Tab]", 13, UiKit.MUTED))
		_suggest_box.add_child(row)


func _complete() -> void:
	if _matches.is_empty():
		return
	_edit.text = "/" + str(_matches[_sel]) + " "
	_edit.caret_column = _edit.text.length()
	_suggest_panel.visible = false
	_matches = []


func _on_message(from_id: int, text: String, team: bool) -> void:
	var row := UiKit.hbox(6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if from_id == 0:
		var sys := UiKit.outlined(text, 16, Color("9fd0ff"), HORIZONTAL_ALIGNMENT_LEFT)
		sys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sys.custom_minimum_size.x = 520
		row.add_child(sys)
	else:
		var col := Mats.team_color(Net.team_of(from_id)).lightened(0.35)
		var who := ("(TEAM) " if team else "") + Net.name_of(from_id) + ":"
		row.add_child(UiKit.outlined(who, 16, col, HORIZONTAL_ALIGNMENT_LEFT))
		var msg := UiKit.outlined(text, 16, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
		msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		msg.custom_minimum_size.x = 380
		msg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(msg)
		Sfx.play("tick", -12.0, 1.4, "UI")
	row.set_meta("t", FADE_TIME)
	_log.add_child(row)
	while _log.get_child_count() > MAX_LINES:
		var old := _log.get_child(0)
		_log.remove_child(old)
		old.queue_free()


func _clear() -> void:
	_close()
	for c in _log.get_children():
		c.queue_free()
