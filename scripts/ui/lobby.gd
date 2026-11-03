class_name Lobby
extends Control

var main
var _teams: Array = []
var _start: Button
var _status: Label
var _map_label: Label
var _codes: Label
var _port_status: Label
var _port_edit: LineEdit


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UiKit.MENU_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var v := UiKit.centered_panel(self, Vector2(820, 0))
	v.add_child(UiKit.label("LOBBY", 40, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	if multiplayer.is_server():
		var code_row := UiKit.hbox(12)
		code_row.alignment = BoxContainer.ALIGNMENT_CENTER
		_codes = UiKit.label("", 24, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		code_row.add_child(_codes)
		code_row.add_child(UiKit.button("Copy Code", _copy_code, 140))
		v.add_child(code_row)
		_port_status = UiKit.label("", 15, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		_port_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_port_status.custom_minimum_size.x = 760
		v.add_child(_port_status)
		var port_row := UiKit.hbox(10)
		port_row.alignment = BoxContainer.ALIGNMENT_CENTER
		port_row.add_child(UiKit.label("Port (UDP)", 16))
		_port_edit = LineEdit.new()
		_port_edit.text = str(Net.hosted_port())
		_port_edit.custom_minimum_size.x = 110
		_port_edit.max_length = 5
		_port_edit.text_submitted.connect(func(_t: String): _apply_port())
		port_row.add_child(_port_edit)
		port_row.add_child(UiKit.button("Change Port", _apply_port, 150))
		if not Net.firewall_allowed():
			port_row.add_child(UiKit.button("Allow Through Firewall", _allow_firewall, 240))
		v.add_child(port_row)
		Net.codes_changed.connect(_update_codes)
		_update_codes()
	else:
		v.add_child(UiKit.label("Connected. Waiting for the host to start the match.", 16, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	# Map size: the host picks it here (or with /map); everyone else sees it.
	if multiplayer.is_server():
		var names := []
		for sz in MapData.SIZE_ORDER:
			names.append(MapData.size_name(sz))
		v.add_child(UiKit.option_row("Map size", names, maxi(0, MapData.SIZE_ORDER.find(Game.map_size)), func(i): Game.server_set_map_size(MapData.SIZE_ORDER[i])))
	_map_label = UiKit.label("", 15, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_map_label)
	Game.map_size_changed.connect(_on_map_size_changed)
	_update_map_label()

	var cols := UiKit.hbox(16)
	v.add_child(cols)
	for team in 2:
		var pc := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Mats.team_color(team).darkened(0.55)
		sb.set_corner_radius_all(10)
		sb.set_content_margin_all(14)
		pc.add_theme_stylebox_override("panel", sb)
		pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pc.custom_minimum_size = Vector2(0, 260)
		cols.add_child(pc)
		var tv := UiKit.vbox(6)
		pc.add_child(tv)
		tv.add_child(UiKit.label("%s TEAM" % Mats.team_name(team).to_upper(), 22, Mats.team_color(team).lightened(0.3)))
		var list := UiKit.vbox(4)
		list.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tv.add_child(list)
		tv.add_child(UiKit.button("Join %s" % Mats.team_name(team), func(): Net.request_team.rpc_id(1, team), 160))
		_teams.append(list)

	v.add_child(HSeparator.new())
	v.add_child(LoadoutPanel.new())
	v.add_child(HSeparator.new())
	var row := UiKit.hbox(10)
	v.add_child(row)
	if multiplayer.is_server():
		_start = UiKit.button("START MATCH", func(): Game.server_start_match(), 220)
		row.add_child(_start)
		row.add_child(UiKit.button("Shuffle Teams", func(): Net.request_shuffle.rpc_id(1), 180))
	row.add_child(UiKit.button("Settings", func(): main.open_settings(false), 130))
	row.add_child(UiKit.button("Customize", func(): main.open_customize(false), 150))
	row.add_child(UiKit.button("Leave", func(): main.leave_to_menu(), 140))
	_status = UiKit.label("", 15, UiKit.MUTED)
	v.add_child(_status)
	Net.roster_changed.connect(_refresh)
	_refresh()


const MAP_INFO := {
	"small": "Small: Bank, Meridian Tower and the park (about 80 x 100 m).",
	"medium": "Medium: School, Bank, Diner, Arcade, Meridian Tower, Casino and the park (about 130 x 135 m).",
	"large": "Large: the whole city - 18 buildings and the park (200 x 170 m).",
}


func _update_codes() -> void:
	_codes.text = "Join code:  %s" % (Net.online_code if Net.online_code != "" else "...")
	_port_status.text = Net.port_status


func _copy_code() -> void:
	if Net.online_code != "":
		DisplayServer.clipboard_set(Net.online_code)
		_port_status.text = "Copied %s. %s" % [Net.online_code, Net.port_status]


## Changing the port re-hosts the lobby, so anyone already here has to rejoin.
func _apply_port() -> void:
	var err: String = main.change_port(int(_port_edit.text))
	if err != "" and is_instance_valid(_port_status):
		_port_status.text = err


func _allow_firewall() -> void:
	Net.request_firewall_access()
	_port_status.text = "Accept the Windows prompt to let players connect. %s" % Net.port_status


func _on_map_size_changed(_size: String) -> void:
	_update_map_label()


func _update_map_label() -> void:
	_map_label.text = "Map: " + MAP_INFO.get(Game.map_size, MapData.size_name(Game.map_size))


func _refresh() -> void:
	for team in 2:
		var list: VBoxContainer = _teams[team]
		for c in list.get_children():
			c.queue_free()
		for id in Net.players:
			var p: Dictionary = Net.players[id]
			if p.team != team:
				continue
			var tag := " (host)" if id == 1 else ""
			var me := "  < you" if id == multiplayer.get_unique_id() else ""
			list.add_child(UiKit.label("%s%s   %s / %s%s" % [p.name, tag, Weapons.display_name(p.weapon), Addons.display_name(p.addon), me], 17))
	_status.text = "%d / %d players" % [Net.players.size(), Net.MAX_PLAYERS]
