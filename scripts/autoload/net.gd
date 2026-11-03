extends Node
## LAN / direct-IP multiplayer using ENet. The host is also a player (peer id 1).
## The server owns the roster (names, teams, loadouts, K/D) and broadcasts it.

signal roster_changed
signal joined_ok
signal join_failed(reason: String)
signal disconnected(reason: String)

const DEFAULT_PORT := 7777
const MAX_PER_TEAM := 8
const MAX_PLAYERS := 16

var players := {}  # peer id -> {name, team, weapon, addon, kills, deaths}
var online := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func my_id() -> int:
	return multiplayer.get_unique_id()


func is_server() -> bool:
	return online and multiplayer.is_server()


## Sender of the current RPC; falls back to the local id for local calls.
func sender() -> int:
	var s := multiplayer.get_remote_sender_id()
	return s if s != 0 else multiplayer.get_unique_id()


func host(port: int) -> String:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		return "Could not host on port %d (error %d). Is it already in use?" % [port, err]
	multiplayer.multiplayer_peer = peer
	online = true
	players.clear()
	_add_player(1, Settings.g("player_name"), Settings.g("weapon"), Settings.g("addon"))
	roster_changed.emit()
	return ""


func join(ip: String, port: int) -> String:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		return "Could not start connection (error %d)." % err
	multiplayer.multiplayer_peer = peer
	online = true
	players.clear()
	return ""


func leave() -> void:
	if multiplayer.multiplayer_peer and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	online = false
	players.clear()


func local_ips() -> Array:
	var out := []
	for ip in IP.get_local_addresses():
		if ip.count(".") == 3 and not ip.begins_with("127.") and not ip.begins_with("169.254"):
			out.append(ip)
	return out


func team_count(team: int) -> int:
	var c := 0
	for id in players:
		if players[id].team == team:
			c += 1
	return c


func team_of(id: int) -> int:
	if players.has(id):
		return players[id].team
	return -1


func name_of(id: int) -> String:
	if players.has(id):
		return players[id].name
	return "?"


# ------------------------------------------------------------ connection events

func _on_connected() -> void:
	register.rpc_id(1, Settings.g("player_name"), Settings.g("weapon"), Settings.g("addon"))
	joined_ok.emit()


func _on_connection_failed() -> void:
	leave()
	join_failed.emit("Could not connect to the server.")


func _on_server_disconnected() -> void:
	leave()
	disconnected.emit("Lost connection to the host.")


func _on_peer_connected(_id: int) -> void:
	pass  # Wait for the client to register.


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	if players.has(id):
		players.erase(id)
		Game.on_player_left(id)
		_broadcast()


# ------------------------------------------------------------------ roster RPCs

@rpc("any_peer", "reliable")
func register(pname: String, weapon: String, addon: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if players.size() >= MAX_PLAYERS:
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	_add_player(id, pname, weapon, addon)
	_broadcast()
	Game.on_player_joined(id)


func _add_player(id: int, pname: String, weapon: String, addon: String) -> void:
	pname = pname.strip_edges().left(20)
	if pname == "":
		pname = "Player %d" % (players.size() + 1)
	var team := 0 if team_count(0) <= team_count(1) else 1
	if not Weapons.DATA.has(weapon):
		weapon = "ar"
	if not Addons.DATA.has(addon):
		addon = "trackstar"
	players[id] = {"name": pname, "team": team, "weapon": weapon, "addon": addon, "kills": 0, "deaths": 0}


func _broadcast() -> void:
	sync_roster.rpc(players)
	roster_changed.emit()


func broadcast_roster() -> void:
	if multiplayer.is_server():
		_broadcast()


@rpc("authority", "reliable")
func sync_roster(p: Dictionary) -> void:
	players = p
	roster_changed.emit()


@rpc("any_peer", "call_local", "reliable")
func request_team(team: int) -> void:
	if not multiplayer.is_server():
		return
	var id := sender()
	if not players.has(id) or team < 0 or team > 1:
		return
	if Game.in_match:
		return
	if players[id].team != team and team_count(team) < MAX_PER_TEAM:
		players[id].team = team
		_broadcast()


@rpc("any_peer", "call_local", "reliable")
func request_loadout(weapon: String, addon: String) -> void:
	if not multiplayer.is_server():
		return
	var id := sender()
	if not players.has(id):
		return
	# Loadouts may only change in the lobby or while dead.
	if Game.in_match and Game.is_alive(id):
		return
	if Weapons.DATA.has(weapon):
		players[id].weapon = weapon
	if Addons.DATA.has(addon):
		players[id].addon = addon
	_broadcast()


@rpc("any_peer", "call_local", "reliable")
func request_shuffle() -> void:
	if not multiplayer.is_server() or sender() != 1 or Game.in_match:
		return
	var ids := players.keys()
	ids.shuffle()
	for i in ids.size():
		players[ids[i]].team = i % 2
	_broadcast()
