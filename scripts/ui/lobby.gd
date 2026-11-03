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
var _map_pick: OptionButton


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UiKit.MENU_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var v := UiKit.centered_panel(self, Vector2(900, 0))
	v.add_theme_constant_override("separation", 8)

	# Header row: title, then the join code (host) or a waiting note (clients).
	var head := UiKit.hbox(14)
	head.add_child(UiKit.label("LOBBY", 30, UiKit.ACCENT))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	if multiplayer.is_server():
		_codes = UiKit.label("", 22, UiKit.TEXT)
		head.add_child(_codes)
		head.add_child(UiKit.button("Copy Code", _copy_code, 130))
	else:
		head.add_child(UiKit.label("Waiting for the host to start the match.", 16, UiKit.MUTED))
	v.add_child(head)

	# Settings row: port (host), map size (host picks it, or /map; everyone sees it).
	var settings := UiKit.hbox(10)
	if multiplayer.is_server():
		settings.add_child(UiKit.label("Port (UDP)", 16))
		_port_edit = LineEdit.new()
		_port_edit.text = str(Net.hosted_port())
		_port_edit.custom_minimum_size.x = 90
		_port_edit.max_length = 5
		_port_edit.text_submitted.connect(func(_t: String): _apply_port())
		settings.add_child(_port_edit)
		settings.add_child(UiKit.button("Change Port", _apply_port, 130))
		if not Net.firewall_allowed():
			settings.add_child(UiKit.button("Allow Through Firewall", _allow_firewall, 210))
	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings.add_child(spacer2)
	settings.add_child(UiKit.label("Map", 16))
	if multiplayer.is_server():
		_map_pick = OptionButton.new()
		for sz in MapData.SIZE_ORDER:
			_map_pick.add_item(MapData.size_name(sz))
		_map_pick.selected = maxi(0, MapData.SIZE_ORDER.find(Game.map_size))
		_map_pick.custom_minimum_size.x = 140
		_map_pick.item_selected.connect(func(i: int): Game.server_set_map_size(MapData.SIZE_ORDER[i]))
		settings.add_child(_map_pick)
	_map_label = UiKit.label("", 16, UiKit.TEXT)
	settings.add_child(_map_label)
	if multiplayer.is_server():
		var city := OptionButton.new()
		city.add_item("Random city")
		city.add_item("Classic city")
		city.selected = 0 if Settings.g("map_random") else 1
		city.tooltip_text = "Random: a new city is generated every match. Classic: the hand-made city."
		city.item_selected.connect(func(i: int): Settings.s("map_random", i == 0))
		settings.add_child(city)
	v.add_child(settings)
	Game.map_size_changed.connect(_on_map_size_changed)
	_update_map_label()

	if multiplayer.is_server():
		_port_status = UiKit.label("", 13, UiKit.MUTED)
		_port_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_port_status.custom_minimum_size.x = 860
		v.add_child(_port_status)
		Net.codes_changed.connect(_update_codes)
		_update_codes()

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
		pc.custom_minimum_size = Vector2(0, 180)
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


## Short map description next to the map size; the full one is the tooltip.
const MAP_INFO := {
	"small": ["80 x 100 m", "About 80 x 100 m. Classic city: Bank, Meridian Tower and the park."],
	"medium": ["130 x 135 m", "About 130 x 135 m. Classic city: School, Bank, Diner, Arcade, Meridian Tower, Casino and the park."],
	"large": ["200 x 170 m", "200 x 170 m. Classic city: all 18 buildings and the park."],
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
	var info: Array = MAP_INFO.get(Game.map_size, ["", ""])
	# The host sees the size in the dropdown; clients get it in the label.
	if _map_pick:
		_map_pick.selected = maxi(0, MapData.SIZE_ORDER.find(Game.map_size))
		_map_pick.tooltip_text = info[1]
		_map_label.text = info[0]
	else:
		_map_label.text = "%s  (%s)" % [MapData.size_name(Game.map_size), info[0]]
	_map_label.tooltip_text = info[1]
	_map_label.mouse_filter = Control.MOUSE_FILTER_PASS


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
