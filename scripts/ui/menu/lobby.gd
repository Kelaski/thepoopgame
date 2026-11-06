class_name Lobby
extends Control
## Before a match (assets/ui/lobby.tscn): team rosters with each player's loadout and ping, your
## own loadout, chat, Steam invites, and the host's privacy, map and start. Every slot is pre-sized
## and text is cut with an ellipsis, so long names and loadouts can't change the layout.

const ROW := preload("res://assets/ui/menu/lobby_row.tscn")
const FRIEND_ROW := preload("res://assets/ui/menu/friend_row.tscn")

var main
var _rows: Array = [[], []]  # per team, per slot


func _ready() -> void:
	var teams: Array[VBoxContainer] = [%TeamA, %TeamB]
	for team in 2:
		for slot in Net.MAX_PER_TEAM:
			var row: LobbyRow = ROW.instantiate()
			teams[team].add_child(row)
			_rows[team].append(row)
	%JoinA.text = "Join %s" % Mats.team_name(0)
	%JoinB.text = "Join %s" % Mats.team_name(1)
	%JoinA.pressed.connect(func() -> void: Net.request_team.rpc_id(1, 0))
	%JoinB.pressed.connect(func() -> void: Net.request_team.rpc_id(1, 1))
	%ChatInput.max_length = Sanitize.MAX_CHAT
	%ChatInput.text_submitted.connect(func(t: String) -> void:
		Net.send_chat(t, false)
		%ChatInput.clear())
	%Hints.attach(%ChatInput)
	Net.chat_message.connect(_on_chat)
	Net.roster_changed.connect(refresh)
	Net.pings_changed.connect(refresh)
	Game.map_size_changed.connect(func(_size: String) -> void: refresh())
	for n in Net.PRIVACY_NAMES:
		%Privacy.add_item(n)
	%Privacy.selected = Net.privacy()
	%Privacy.item_selected.connect(Net.set_privacy)
	for size: String in Level.SIZE_ORDER:
		%Map.add_item(Level.size_name(size))
	%Map.item_selected.connect(func(i: int) -> void: Game.server_set_map_size(Level.SIZE_ORDER[i]))
	%Start.pressed.connect(Game.server_start_match)
	%Shuffle.pressed.connect(func() -> void: Net.request_shuffle.rpc_id(1))
	%Invite.pressed.connect(_toggle_invites)
	%InviteClose.pressed.connect(func() -> void: %InvitePanel.visible = false)
	%Settings.pressed.connect(main.open_settings.bind(false))
	%Leave.pressed.connect(main.leave_to_menu)
	MenuKit.paint_accents(self)
	refresh()


func _on_chat(from_id: int, text: String, _team_only: bool) -> void:
	%ChatLog.add_text(("%s: %s\n" % [Net.name_of(from_id), text]) if from_id != 0 else "%s\n" % text)


func refresh() -> void:
	var filled := [0, 0]
	for id: int in Net.players:
		var p: Dictionary = Net.players[id]
		var team: int = p.team
		if filled[team] >= _rows[team].size():
			continue
		var row: LobbyRow = _rows[team][filled[team]]
		filled[team] += 1
		row.fill(str(p.name) + ("  (you)" if id == multiplayer.get_unique_id() else "") + ("  (host)" if id == 1 else ""),
			"%s  /  %s  /  %s" % [Weapons.display_name(p.weapon), Addons.display_name(p.active), Addons.display_name(p.get("passive", ""))],
			"HOST" if id == 1 else Net.ping_text(id))
	for team in 2:
		for slot in range(filled[team], _rows[team].size()):
			(_rows[team][slot] as LobbyRow).fill("", "", "")
	var host := multiplayer.is_server()
	%Privacy.visible = host
	%Map.visible = host
	%Map.selected = maxi(0, Level.SIZE_ORDER.find(Game.map_size))
	%Start.visible = host
	%Shuffle.visible = host
	%Invite.disabled = Net.lobby_id == 0  # invites need a Steam lobby, not a local test match
	%Status.text = "%d / %d players" % [Net.players.size(), Net.MAX_PLAYERS] if host else "%s map. Waiting for the host to start..." % Level.size_name(Game.map_size)


## Invite friends: Steam's own invite window when the overlay is there, otherwise a list of online friends.
func _toggle_invites() -> void:
	if Net.open_invite_overlay():
		return
	%InvitePanel.visible = not %InvitePanel.visible
	if not %InvitePanel.visible:
		return
	for child in %InviteList.get_children():
		child.queue_free()
	var friends := Net.invitable_friends()
	if friends.is_empty():
		%InviteList.add_child(UiKit.label("None of your Steam friends are online.", 16, UiKit.MUTED))
	for f: Dictionary in friends:
		var row: Control = FRIEND_ROW.instantiate()
		(row.get_node("Name") as Label).text = Sanitize.player_name(f.name)
		row.get_node("Playing").visible = f.playing
		var b: Button = row.get_node("InviteButton")
		b.pressed.connect(_invite.bind(f.id, b))
		%InviteList.add_child(row)


func _invite(friend_id: int, b: Button) -> void:
	b.disabled = true
	b.text = "Invited" if Net.invite(friend_id) else "Failed"
