extends Node
## Multiplayer using ENet. The host is also a player (peer id 1).
## The server owns the roster (names, teams, loadouts, K/D) and broadcasts it.
##
## Online only: joining is by code (see JoinCode). When you host, the game looks up
## your public address, asks your router to open the port with UPnP, and tells you
## in the lobby what (if anything) still stands in the way.

signal roster_changed
signal joined_ok
signal join_failed(reason: String)
signal disconnected(reason: String)
signal chat_message(from_id: int, text: String, team_only: bool)
signal spray_updated(id: int)
signal codes_changed  # online_code / port_status updated (lookups finished)

# 27015 is the usual Source / Steam game server port, so many players already have
# it forwarded; when they don't, UPnP opens it. The host can change it in the lobby.
const DEFAULT_PORT := 27015
const MAX_PER_TEAM := 8
const MAX_PLAYERS := 16
const UPNP_TIMEOUT_MS := 2000
const REGISTER_TIMEOUT := 5.0  # seconds a new connection has to register (and show its version)
const PUBLIC_IP_URL := "https://api.ipify.org"  # replies with your public IPv4 address as plain text
const FIREWALL_RULE := "Tag Rush"

var online_code := ""  # host: the join code (public address + port)
var port_status := ""  # host: what's happening with the router / firewall, shown in the lobby
var public_ip := ""
var _ip_lookup_done := false
var _upnp_state := 0    # 0 = working, 1 = port opened, -1 = failed
var _upnp_ip := ""      # address the router reports (differs from public_ip behind CGNAT)
var _upnp_msg := ""
var _upnp: UPNP = null  # router we opened the port on
var _mapped_port := 0
var _host_port := 0
var _upnp_gen := 0
var _upnp_thread: Thread = null
var _close_thread: Thread = null
var _ip_http: HTTPRequest = null
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
var _code_salt := 0  # scrambles this lobby's join code (new each time you host)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _exit_tree() -> void:
	if _upnp_thread:
		_upnp_thread.wait_to_finish()
		_upnp_thread = null
	_release_port()
	if _close_thread:
		_close_thread.wait_to_finish()


# ------------------------------------------------------------ Windows Firewall

func _firewall_applies() -> bool:
	return OS.get_name() == "Windows" and DisplayServer.get_name() != "headless"


## True if our inbound allow rule for this exact executable exists (or this isn't
## Windows). Reading the rules needs no admin rights.
func firewall_allowed() -> bool:
	if not _firewall_applies():
		return true
	var out := []
	if OS.execute("netsh", ["advfirewall", "firewall", "show", "rule", "name=" + FIREWALL_RULE, "verbose"], out) != 0:
		return false
	var exe := OS.get_executable_path().replace("/", "\\").to_lower()
	return "".join(PackedStringArray(out)).to_lower().contains(exe)


## Asks Windows (an administrator / UAC prompt) to let the game accept connections:
## removes any inbound rules Windows made for this program earlier (a dismissed
## "allow access" prompt leaves a block rule behind, and block rules win), then
## adds an allow rule for every network type.
func request_firewall_access() -> void:
	if not _firewall_applies():
		return
	# In a .cmd file a % starts a variable, so double any in the path.
	var exe := OS.get_executable_path().replace("/", "\\").replace("%", "%%")
	var script := "@echo off\r\n"
	script += "netsh advfirewall firewall delete rule name=all dir=in program=\"%s\"\r\n" % exe
	script += "netsh advfirewall firewall add rule name=\"%s\" dir=in action=allow program=\"%s\" enable=yes profile=any\r\n" % [FIREWALL_RULE, exe]
	var path := ProjectSettings.globalize_path("user://allow_firewall.cmd").replace("/", "\\")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(script)
	f.close()
	var ps := "Start-Process -FilePath '%s' -Verb RunAs -WindowStyle Hidden" % path.replace("'", "''")
	OS.create_process("powershell.exe", ["-NoProfile", "-WindowStyle", "Hidden", "-Command", ps])


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
	_code_salt = JoinCode.new_salt()  # a different join code for every lobby
	# Only the host takes incoming connections, so only hosting asks Windows
	# for the firewall rule (players who just join never see the prompt).
	if not firewall_allowed():
		request_firewall_access()
	players.clear()
	_add_player(1, Settings.g("player_name"), Settings.g("weapon"), Settings.g("addon"))
	Game._set_map_size_local(str(Settings.g("map_size")))
	roster_changed.emit()
	upload_my_spray()
	_host_port = port
	_upnp_state = 0
	_upnp_ip = ""
	_upnp_msg = ""
	_ip_lookup_done = false
	_refresh_status()
	_lookup_public_ip()
	if _upnp_thread:
		_upnp_thread.wait_to_finish()  # a previous lookup is still finishing (rare)
	_upnp_gen += 1
	_upnp_thread = Thread.new()
	_upnp_thread.start(_upnp_open.bind(port, _upnp_gen))
	return ""


func hosted_port() -> int:
	return _host_port


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
	if _ip_http:
		_ip_http.cancel_request()
	online_code = ""
	port_status = ""
	_host_port = 0
	sprays.clear()
	_spray_tex.clear()
	_chat_times.clear()
	_spray_up_at.clear()
	if multiplayer.multiplayer_peer and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	online = false
	players.clear()


# ------------------------------------------------------------ public address

func _lookup_public_ip() -> void:
	if _ip_http == null:
		_ip_http = HTTPRequest.new()
		_ip_http.timeout = 8.0
		add_child(_ip_http)
		_ip_http.request_completed.connect(_on_ip_reply)
	else:
		_ip_http.cancel_request()
	if _ip_http.request(PUBLIC_IP_URL) != OK:
		_ip_lookup_done = true
		_refresh_status()


func _on_ip_reply(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var ip := body.get_string_from_utf8().strip_edges()
	if result == HTTPRequest.RESULT_SUCCESS and code == 200 and JoinCode.encode(ip, DEFAULT_PORT) != "":
		public_ip = ip
	_ip_lookup_done = true
	_refresh_status()


## Private / shared ranges: an address like this from the router means there's
## another router (or the internet provider's CGNAT) in front of it.
static func is_private_ip(ip: String) -> bool:
	var p := ip.split(".")
	if p.size() != 4:
		return true
	var a := int(p[0])
	var b := int(p[1])
	return a == 10 or a == 127 or (a == 172 and b >= 16 and b <= 31) or (a == 192 and b == 168) or (a == 100 and b >= 64 and b <= 127) or (a == 169 and b == 254)


## Builds the join code and the lobby's explanation from the two lookups.
func _refresh_status() -> void:
	if not is_server():
		return
	var addr := public_ip
	if addr == "" and _upnp_ip != "" and not is_private_ip(_upnp_ip):
		addr = _upnp_ip
	online_code = JoinCode.encode(addr, _host_port, _code_salt) if addr != "" else ""
	var lines := []
	if not _ip_lookup_done and addr == "":
		lines.append("Looking up your public address...")
	elif addr == "":
		lines.append("Couldn't look up your public address. Check your internet connection.")
	match _upnp_state:
		1:
			if _upnp_ip != "" and public_ip != "" and _upnp_ip != public_ip:
				lines.append("Your internet provider shares your address with other customers (CGNAT), so players probably can't reach you. Ask your provider for a public IP, or let someone else host.")
		-1:
			lines.append("%s Forward UDP port %d to this PC in your router's settings." % [_upnp_msg, _host_port])
	if not firewall_allowed():
		lines.append("Windows Firewall may block players: accept the prompt, or press Allow Through Firewall.")
	port_status = " ".join(PackedStringArray(lines))
	codes_changed.emit()


# ------------------------------------------------------------ UPnP (router port)

## Runs on a thread: finds the router, opens the port and asks for the address it
## has on the internet. Discovery can take a couple of seconds.
func _upnp_open(port: int, gen: int) -> void:
	var u := UPNP.new()
	var res := {"ok": false, "ip": "", "msg": ""}
	var err := u.discover(UPNP_TIMEOUT_MS, 2, "InternetGatewayDevice")
	if err != UPNP.UPNP_RESULT_SUCCESS or u.get_gateway() == null or not u.get_gateway().is_valid_gateway():
		res.msg = "Couldn't open the port automatically (UPnP is off or unsupported on your router)."
	elif u.add_port_mapping(port, port, "Tag Rush", "UDP", 0) != UPNP.UPNP_RESULT_SUCCESS:
		res.msg = "Your router refused to open port %d automatically." % port
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
	if res.ok and not still_hosting:
		_close_port_async(u, port)  # left before the router answered
		return
	if not still_hosting:
		return
	if res.ok:
		_upnp = u
		_mapped_port = port
		_upnp_state = 1
		_upnp_ip = str(res.ip)
	else:
		_upnp_state = -1
		_upnp_msg = str(res.msg)
	_refresh_status()


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
	# The router object is passed as an argument so the thread keeps it alive (a
	# Callable on its method alone doesn't hold a reference).
	_close_thread.start(_delete_mapping.bind(u, port))


static func _delete_mapping(u: UPNP, port: int) -> void:
	u.delete_port_mapping(port, "UDP")


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
	if players.has(id):
		return  # already registered (re-registering would reset their team mid-match)
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
	# Loadouts may only change in the lobby, in the pre-round countdown, or while dead.
	if Game.in_match and Game.is_alive(id) and Game.phase != Game.Phase.PREROUND:
		return
	if Weapons.DATA.has(weapon):
		players[id].weapon = weapon
	if Addons.DATA.has(addon):
		players[id].addon = addon
	if Game.in_match and Game.is_alive(id):
		Game.hp[id] = Game.max_hp_of(id)  # swapped in the countdown: full health for the new weapon (the bat has 150)
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
