extends Node
## Multiplayer using ENet. The host is also a player (peer id 1).
## The server owns the roster (names, teams, loadouts, K/D) and broadcasts it.
##
## Joining is by code (see JoinCode). When you host, the game asks your router to
## open the port with UPnP and builds an online code from your public address;
## a LAN code is always available for players on the same network.

signal roster_changed
signal joined_ok
signal join_failed(reason: String)
signal disconnected(reason: String)
signal chat_message(from_id: int, text: String, team_only: bool)
signal spray_updated(id: int)
signal codes_changed  # the UPnP lookup finished (online_code / port_status updated)

# 27015 is the usual Source / Steam game server port, so many routers and players
# already have it open; when they don't, UPnP opens it.
const DEFAULT_PORT := 27015
const MAX_PER_TEAM := 8
const MAX_PLAYERS := 16
const UPNP_TIMEOUT_MS := 2000
const REGISTER_TIMEOUT := 5.0  # seconds a new connection has to register (and show its version)

var lan_code := ""     # host: code for players on the same network
var online_code := ""  # host: code for players anywhere (needs the port open)
var port_status := ""  # host: what happened with the router, shown in the lobby
var _upnp: UPNP = null  # router we opened the port on
var _mapped_port := 0
var _host_port := 0
var _upnp_gen := 0
var _upnp_thread: Thread = null
var _close_thread: Thread = null
var _reject_reason := ""

var players := {}  # peer id -> {name, team, weapon, addon, kills, deaths}
var sprays := {}   # peer id -> PackedByteArray (validated PNG)
var _spray_tex := {}
var _chat_times := {}  # server: peer id -> recent message timestamps (rate limit)
var _spray_up_at := {}  # server: peer id -> time of last accepted spray upload

const CHAT_BURST := 5        # messages allowed...
const CHAT_WINDOW := 4.0     # ...per this many seconds
const SPRAY_UPLOAD_INTERVAL := 3.0  # seconds between spray uploads per player
var online := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_request_firewall_access()


func _exit_tree() -> void:
	if _upnp_thread:
		_upnp_thread.wait_to_finish()
		_upnp_thread = null
	_release_port()
	if _close_thread:
		_close_thread.wait_to_finish()


## Windows asks for firewall access the first time a program listens for
## connections. Listening for a moment at startup makes that prompt appear as soon
## as the game opens, instead of in the middle of hosting.
func _request_firewall_access() -> void:
	if OS.get_name() != "Windows" or DisplayServer.get_name() == "headless":
		return
	var probe := PacketPeerUDP.new()
	if probe.bind(DEFAULT_PORT) == OK:
		probe.close()


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
	Game._set_map_size_local(str(Settings.g("map_size")))
	roster_changed.emit()
	upload_my_spray()
	_host_port = port
	var ips := local_ips()
	lan_code = JoinCode.encode(ips[0], port) if not ips.is_empty() else ""
	online_code = ""
	port_status = "Opening port %d on your router..." % port
	if _upnp_thread:
		_upnp_thread.wait_to_finish()  # a previous lookup is still finishing (rare)
	_upnp_gen += 1
	_upnp_thread = Thread.new()
	_upnp_thread.start(_upnp_open.bind(port, _upnp_gen))
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
	_reject_reason = ""
	return ""


func leave() -> void:
	_release_port()
	lan_code = ""
	online_code = ""
	port_status = ""
	sprays.clear()
	_spray_tex.clear()
	_chat_times.clear()
	_spray_up_at.clear()
	if multiplayer.multiplayer_peer and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	online = false
	players.clear()


## LAN addresses, most likely home-network ones (192.168.x / 10.x) first.
func local_ips() -> Array:
	var out := []
	for ip in IP.get_local_addresses():
		if ip.count(".") == 3 and not ip.begins_with("127.") and not ip.begins_with("169.254"):
			out.append(ip)
	out.sort_custom(func(a, b): return _lan_rank(a) < _lan_rank(b))
	return out


func _lan_rank(ip: String) -> int:
	if ip.begins_with("192.168."):
		return 0
	if ip.begins_with("10."):
		return 1
	return 2


# ------------------------------------------------------------ UPnP (router port)

## Runs on a thread: finds the router, opens the port and asks for the public
## address. Discovery can take a couple of seconds.
func _upnp_open(port: int, gen: int) -> void:
	var u := UPNP.new()
	var res := {"ok": false, "ip": "", "msg": ""}
	var err := u.discover(UPNP_TIMEOUT_MS, 2, "InternetGatewayDevice")
	if err != UPNP.UPNP_RESULT_SUCCESS or u.get_gateway() == null or not u.get_gateway().is_valid_gateway():
		res.msg = "Couldn't find your router (UPnP is off or unsupported)."
	elif u.add_port_mapping(port, port, "Tag Rush", "UDP", 0) != UPNP.UPNP_RESULT_SUCCESS:
		res.msg = "Your router refused to open port %d." % port
	else:
		res.ok = true
		res.ip = u.query_external_address()
	_upnp_done.call_deferred(u, port, res, gen)


func _upnp_done(u: UPNP, port: int, res: Dictionary, gen: int) -> void:
	if gen != _upnp_gen:
		# A newer host() replaced this lookup (and already waited for its thread).
		if res.ok:
			_close_port_async(u, port)
		return
	_upnp_thread.wait_to_finish()
	_upnp_thread = null
	var still_hosting := is_server() and port == _host_port
	if not res.ok:
		if still_hosting:
			port_status = "%s Friends on other networks need UDP port %d forwarded to this PC." % [res.msg, port]
			codes_changed.emit()
		return
	if not still_hosting:
		_close_port_async(u, port)  # left before the router answered
		return
	_upnp = u
	_mapped_port = port
	online_code = JoinCode.encode(str(res.ip), port)
	if online_code == "":
		port_status = "Port %d is open, but your router didn't report a public address." % port
	else:
		port_status = "Port %d opened on your router automatically." % port
	codes_changed.emit()


func _release_port() -> void:
	if _upnp == null:
		return
	_close_port_async(_upnp, _mapped_port)
	_upnp = null
	_mapped_port = 0


func _close_port_async(u: UPNP, port: int) -> void:
	if _close_thread:
		_close_thread.wait_to_finish()
	_close_thread = Thread.new()
	_close_thread.start(u.delete_port_mapping.bind(port, "UDP"))


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
	register.rpc_id(1, Settings.g("player_name"), Settings.g("weapon"), Settings.g("addon"), GameVersion.CURRENT)
	upload_my_spray()
	joined_ok.emit()
	# Reverse check: a host on an older build never answers the registration.
	get_tree().create_timer(REGISTER_TIMEOUT + 1.0).timeout.connect(_check_accepted.bind(multiplayer.multiplayer_peer))


func _check_accepted(peer: MultiplayerPeer) -> void:
	if online and multiplayer.multiplayer_peer == peer and not players.has(my_id()) and _reject_reason == "":
		leave()
		disconnected.emit("The host didn't accept you. They're probably on a different version (you're on %s)." % GameVersion.CURRENT)


func _on_connection_failed() -> void:
	leave()
	join_failed.emit("Could not connect. Check the code, and that the host's port is open.")


func _on_server_disconnected() -> void:
	var reason := _reject_reason if _reject_reason != "" else "Lost connection to the host."
	_reject_reason = ""
	leave()
	disconnected.emit(reason)


## Server tells a client why it's being turned away, just before disconnecting it.
@rpc("authority", "reliable")
func _rejected(reason: String) -> void:
	_reject_reason = Sanitize.text(reason)


func _reject(id: int, reason: String) -> void:
	_rejected.rpc_id(id, reason)
	# Give the message a moment to arrive before dropping the connection.
	get_tree().create_timer(0.5).timeout.connect(_drop_peer.bind(id))


func _drop_peer(id: int) -> void:
	if multiplayer.is_server() and id in multiplayer.get_peers():
		multiplayer.multiplayer_peer.disconnect_peer(id)


func _on_peer_connected(id: int) -> void:
	# Wait for the client to register (which carries its version). Builds from
	# before 0.2.0 can't register at all (different RPC), so anyone who hasn't
	# registered in time is on another version and gets dropped.
	if multiplayer.is_server():
		get_tree().create_timer(REGISTER_TIMEOUT).timeout.connect(_check_registered.bind(id))


func _check_registered(id: int) -> void:
	if multiplayer.is_server() and not players.has(id) and id in multiplayer.get_peers():
		_reject(id, "Couldn't join: you're probably on a different version. The host is on %s." % GameVersion.CURRENT)


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	if players.has(id):
		players.erase(id)
		sprays.erase(id)
		_chat_times.erase(id)
		_spray_up_at.erase(id)
		_spray_data.rpc(id, PackedByteArray())
		Game.on_player_left(id)
		_broadcast()


# ------------------------------------------------------------------ roster RPCs

@rpc("any_peer", "reliable")
func register(pname: String, weapon: String, addon: String, version: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if version != GameVersion.CURRENT:
		_reject(id, "Version mismatch: the host is on %s, you're on %s. Update to the same version." % [GameVersion.CURRENT, version.left(16)])
		return
	if players.size() >= MAX_PLAYERS:
		_reject(id, "The lobby is full (%d players)." % MAX_PLAYERS)
		return
	_add_player(id, pname, weapon, addon)
	_broadcast()
	for sid in sprays:
		_spray_data.rpc_id(id, sid, sprays[sid])
	Game.send_map_size_to(id)
	Game.on_player_joined(id)


func _add_player(id: int, pname: String, weapon: String, addon: String) -> void:
	pname = Sanitize.player_name(pname)
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


# ------------------------------------------------------------------ chat

## Send a chat message (or a /command). The server sanitizes, rate-limits and
## relays it; commands are run from a fixed whitelist (see Commands).
func send_chat(text: String, team_only: bool) -> void:
	text = Sanitize.text(text)
	if text == "" or not online:
		return
	chat_send.rpc_id(1, text, team_only)


@rpc("any_peer", "call_local", "reliable")
func chat_send(text: String, team_only: bool) -> void:
	if not multiplayer.is_server():
		return
	var id := sender()
	if not players.has(id):
		return
	var now := Time.get_ticks_msec() / 1000.0
	var times: Array = _chat_times.get(id, [])
	times = times.filter(func(t): return now - t < CHAT_WINDOW)
	if times.size() >= CHAT_BURST:
		_system_to(id, "You're sending messages too fast.")
		return
	times.append(now)
	_chat_times[id] = times
	text = Sanitize.text(text)
	if text == "":
		return
	if text.begins_with("/"):
		for line in Commands.run(id, text):
			_system_to(id, str(line))
		return
	var team := team_of(id)
	for pid in players:
		if not team_only or players[pid].team == team:
			_chat_receive.rpc_id(pid, id, text, team_only)


func _system_to(id: int, text: String) -> void:
	_chat_receive.rpc_id(id, 0, text, false)


@rpc("authority", "call_local", "reliable")
func _chat_receive(from_id: int, text: String, team_only: bool) -> void:
	chat_message.emit(from_id, Sanitize.text(text), team_only)


# ------------------------------------------------------------------ sprays

func upload_my_spray() -> void:
	if not online:
		return
	var b := UserImages.spray_bytes()
	if UserImages.valid_spray_bytes(b):
		upload_spray.rpc_id(1, b)


@rpc("any_peer", "call_local", "reliable")
func upload_spray(bytes: PackedByteArray) -> void:
	if not multiplayer.is_server():
		return
	var id := sender()
	if not players.has(id) or not UserImages.valid_spray_bytes(bytes):
		return
	# Rate limit before decoding: each accepted upload is decoded here and resent to everyone.
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_spray_up_at.get(id, -100.0)) < SPRAY_UPLOAD_INTERVAL:
		return
	if sprays.get(id, PackedByteArray()) == bytes:
		return
	_spray_up_at[id] = now
	if UserImages.decode_spray(bytes) == null:
		return
	sprays[id] = bytes
	_spray_data.rpc(id, bytes)


@rpc("authority", "call_local", "reliable")
func _spray_data(id: int, bytes: PackedByteArray) -> void:
	_spray_tex.erase(id)
	if bytes.is_empty() or not UserImages.valid_spray_bytes(bytes):
		sprays.erase(id)
	else:
		sprays[id] = bytes
	spray_updated.emit(id)


func spray_texture(id: int) -> Texture2D:
	if _spray_tex.has(id):
		return _spray_tex[id]
	if not sprays.has(id):
		return null
	var tex := UserImages.decode_spray(sprays[id])
	_spray_tex[id] = tex
	return tex
