class_name Lobby
extends Control
## Lobby (assets/ui/lobby.tscn). The host picks who can join (Public / Friends
## only / Invite only), the map size and city, and starts the match; everyone can
## invite Steam friends and picks a team and a loadout. The team rosters are filled
## in from the network roster.

const FRIEND_ROW := preload("res://assets/ui/friend_row.tscn")

## What the classic city has at each size (the map pick's tooltip).
const MAP_INFO := {
	"small": "Classic city: Bank, Meridian Tower and the park.",
	"medium": "Classic city: School, Bank, Diner, Arcade, Meridian Tower, Casino and the park.",
	"large": "Classic city: all 18 buildings and the park.",
}

var main


func _ready() -> void:
	var host := multiplayer.is_server()
	for n: Control in [%PrivacyTitle, %PrivacyPick, %MapPick, %CityPick, %StartButton, %ShuffleButton]:
		n.visible = host
	%Waiting.visible = not host
	# Invites need a Steam lobby (not a local test match).
	%InviteButton.visible = Net.lobby_id != 0
	var privacy: OptionButton = %PrivacyPick
	privacy.clear()
	for n in Net.PRIVACY_NAMES:
		privacy.add_item(n)
	privacy.selected = Net.privacy()
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
	Net.roster_changed.connect(_refresh)
	_refresh()


func _on_privacy_selected(i: int) -> void:
	Net.set_privacy(i)


## Invite Friends: Steam's own invite window when the overlay is there, otherwise
## an in-game list of online friends.
func _on_invite_pressed() -> void:
	if Net.open_invite_overlay():
		return
	for c in %Friends.get_children():
		if c != %NoFriends:
			c.queue_free()
	var friends := Net.invitable_friends()
	%NoFriends.visible = friends.is_empty()
	for f: Dictionary in friends:
		var row: Control = FRIEND_ROW.instantiate()
		(row.get_node("Name") as Label).text = Sanitize.player_name(f.name)
		row.get_node("Playing").visible = f.playing
		var b: Button = row.get_node("InviteButton")
		b.pressed.connect(_invite.bind(f.id, b))
		%Friends.add_child(row)
	%InvitePopup.popup_centered()


func _invite(friend_id: int, b: Button) -> void:
	b.disabled = true
	b.text = "Invited" if Net.invite(friend_id) else "Failed"


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
	var info: String = MAP_INFO.get(Game.map_size, "")
	var label: Label = %MapLabel
	# The host sees the size in the dropdown; clients get it in the label.
	if multiplayer.is_server():
		%MapPick.selected = maxi(0, MapData.SIZE_ORDER.find(Game.map_size))
		%MapPick.tooltip_text = info
		label.text = ""
	else:
		label.text = MapData.size_name(Game.map_size)
	label.tooltip_text = info


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
			list.add_child(UiKit.label("%s%s   %s / %s / %s%s" % [p.name, tag, Weapons.display_name(p.weapon), Addons.display_name(p.addon), Addons.display_name(p.get("addon2", "")), me], 17))
	%Status.text = "%d / %d players" % [Net.players.size(), Net.MAX_PLAYERS]
