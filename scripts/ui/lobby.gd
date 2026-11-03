class_name Lobby
extends Control
## Lobby (assets/ui/lobby.tscn). The host sees the join code, port, map size and
## city choice and can start the match; everyone picks a team and a loadout.
## The team rosters are filled in from the network roster.

const SCENE := "res://assets/ui/lobby.tscn"

## Short map description next to the map size; the full one is the tooltip.
const MAP_INFO := {
	"small": ["80 x 100 m", "About 80 x 100 m. Classic city: Bank, Meridian Tower and the park."],
	"medium": ["130 x 135 m", "About 130 x 135 m. Classic city: School, Bank, Diner, Arcade, Meridian Tower, Casino and the park."],
	"large": ["200 x 170 m", "200 x 170 m. Classic city: all 18 buildings and the park."],
}

var main


func _ready() -> void:
	var host := multiplayer.is_server()
	for n: Control in [%Codes, %CopyButton, %PortLabel, %PortEdit, %ChangePortButton, %MapPick, %CityPick, %PortStatus, %StartButton, %ShuffleButton]:
		n.visible = host
	%Waiting.visible = not host
	%FirewallButton.visible = host and not Net.firewall_allowed()
	%PortEdit.text = str(Net.hosted_port())
	var pick: OptionButton = %MapPick
	pick.clear()
	for sz in MapData.SIZE_ORDER:
		pick.add_item(MapData.size_name(sz))
	%CityPick.selected = 0 if Settings.g("map_random") else 1
	for team in 2:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Mats.team_color(team).darkened(0.55)
		sb.set_corner_radius_all(10)
		sb.set_content_margin_all(14)
		get_node("%%Team%dPanel" % team).add_theme_stylebox_override("panel", sb)
		var title: Label = get_node("%%Team%dTitle" % team)
		title.text = "%s TEAM" % Mats.team_name(team).to_upper()
		title.add_theme_color_override("font_color", Mats.team_color(team).lightened(0.3))
		get_node("%%Join%dButton" % team).text = "Join %s" % Mats.team_name(team)
	Game.map_size_changed.connect(_on_map_size_changed)
	_update_map_label()
	if host:
		Net.codes_changed.connect(_update_codes)
		_update_codes()
	Net.roster_changed.connect(_refresh)
	_refresh()


func _update_codes() -> void:
	%Codes.text = "Join code:  %s" % (Net.online_code if Net.online_code != "" else "...")
	%PortStatus.text = Net.port_status


func _on_copy_pressed() -> void:
	if Net.online_code != "":
		DisplayServer.clipboard_set(Net.online_code)
		%PortStatus.text = "Copied %s. %s" % [Net.online_code, Net.port_status]


## Changing the port re-hosts the lobby, so anyone already here has to rejoin.
func _on_change_port_pressed() -> void:
	var err: String = main.change_port(int(%PortEdit.text))
	if err != "" and is_instance_valid(self):
		%PortStatus.text = err


func _on_port_submitted(_t: String) -> void:
	_on_change_port_pressed()


func _on_firewall_pressed() -> void:
	Net.request_firewall_access()
	%PortStatus.text = "Accept the Windows prompt to let players connect. %s" % Net.port_status


func _on_map_selected(i: int) -> void:
	Game.server_set_map_size(MapData.SIZE_ORDER[i])


func _on_city_selected(i: int) -> void:
	Settings.s("map_random", i == 0)


func _on_join_red_pressed() -> void:
	Net.request_team.rpc_id(1, 0)


func _on_join_blue_pressed() -> void:
	Net.request_team.rpc_id(1, 1)


func _on_start_pressed() -> void:
	Game.server_start_match()


func _on_shuffle_pressed() -> void:
	Net.request_shuffle.rpc_id(1)


func _on_settings_pressed() -> void:
	main.open_settings(false)


func _on_customize_pressed() -> void:
	main.open_customize(false)


func _on_leave_pressed() -> void:
	main.leave_to_menu()


func _on_map_size_changed(_size: String) -> void:
	_update_map_label()


func _update_map_label() -> void:
	var info: Array = MAP_INFO.get(Game.map_size, ["", ""])
	var label: Label = %MapLabel
	# The host sees the size in the dropdown; clients get it in the label.
	if multiplayer.is_server():
		%MapPick.selected = maxi(0, MapData.SIZE_ORDER.find(Game.map_size))
		%MapPick.tooltip_text = info[1]
		label.text = info[0]
	else:
		label.text = "%s  (%s)" % [MapData.size_name(Game.map_size), info[0]]
	label.tooltip_text = info[1]


func _refresh() -> void:
	for team in 2:
		var list: VBoxContainer = get_node("%%Team%dList" % team)
		for c in list.get_children():
			c.queue_free()
		for id in Net.players:
			var p: Dictionary = Net.players[id]
			if p.team != team:
				continue
			var tag := " (host)" if id == 1 else ""
			var me := "  < you" if id == multiplayer.get_unique_id() else ""
			list.add_child(UiKit.label("%s%s   %s / %s%s" % [p.name, tag, Weapons.display_name(p.weapon), Addons.display_name(p.addon), me], 17))
	%Status.text = "%d / %d players" % [Net.players.size(), Net.MAX_PLAYERS]
