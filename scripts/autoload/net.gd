extends Node
## Multiplayer over Steam (GodotSteam, addons/godotsteam). The host is also a player
## (peer id 1). The server owns the roster (names, teams, loadouts, K/D) and broadcasts it.
##
## Hosting creates a Steam lobby. Players join through an invite, through Steam's
## friends list ("Join Game"), or by picking the lobby in Join Game. All game traffic
## goes through Steam's relay (SteamMultiplayerPeer), so nobody needs open ports,
## UPnP or firewall rules, and nobody's IP address is shown to anyone.
##
## Debug builds can also run a local ENet match from the command line
## (main.gd: --host --port=N / --join=IP:PORT), so two copies can be tested on one
## PC: Steam only allows one copy per account.

signal roster_changed
signal joined_ok
signal join_failed(reason: String)
signal disconnected(reason: String)
signal chat_message(from_id: int, text: String, team_only: bool)
signal spray_updated(id: int)
signal lobby_list_received(lobbies: Array)  # [{id, name, version, players, max}], see find_lobbies()
signal invite_accepted(lobby: int)          # accepted a Steam invite / "Join Game" while running
signal pings_changed                        # new ping numbers (about once a second)

const APP_ID := 480            # Spacewar, Valve's shared test app, until Tag Rush has its own
const LOBBY_GAME := "tagrush"  # lobby tag: app 480 is shared by many games, so lobbies are filtered by it
const MAX_PER_TEAM := 8
const MAX_PLAYERS := 16
const REGISTER_TIMEOUT := 5.0  # seconds a new connection has to register (and show its version)
const LOCAL_PORT := 27015      # debug-only local matches

## Who can find and join the lobby (the host picks in the lobby).
enum Privacy { PUBLIC, FRIENDS, INVITE }
const PRIVACY_NAMES := ["Public", "Friends only", "Invite only"]

var steam_ok := false   # Steam is running and signed in
var steam_error := ""   # why not, shown on the main menu
var lobby_id := 0       # the Steam lobby we're in (0 = none / local match)
var _hosting := false   # waiting for Steam to create our lobby
var _joining := 0       # lobby we asked Steam to enter
var _reject_reason := ""

var players := {}  # peer id -> {name, team, weapon, addon (primary), addon2 (secondary), kills, deaths}
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
	_init_steam()


# ------------------------------------------------------------------ ping
# The host times a round trip to each player once a second and shares the
# numbers every 5 s (so the lobby and scoreboard don't flicker): everyone's game
# goes through the host, so that's the ping that counts.
const PING_INTERVAL := 1.0
const PING_SHOW_INTERVAL := 5.0
var pings := {}  # peer id -> round trip to the host in ms (the host itself isn't listed)
var _measured := {}  # host: the latest (smoothed) measurements, shared every PING_SHOW_INTERVAL
var _ping_acc := 0.0
var _ping_show_acc := PING_SHOW_INTERVAL  # the first numbers go out straight away


func _process(delta: float) -> void:
	if not online or not multiplayer.is_server():
		return
	_ping_acc += delta
	_ping_show_acc += delta
	if _ping_acc < PING_INTERVAL:
		return
	_ping_acc = 0.0
	for id in _measured.keys():
		if not players.has(id):
			_measured.erase(id)
	if _ping_show_acc >= PING_SHOW_INTERVAL and not _measured.is_empty():
		_ping_show_acc = 0.0
		_sync_pings.rpc(_measured)
		_on_pings(_measured.duplicate())
	_ping.rpc(Time.get_ticks_usec())


## "42 ms" for a player, "host" for the host, "-" until it's been measured.
func ping_text(id: int) -> String:
	if id == 1:
		return "host"
	return "%d ms" % pings[id] if pings.has(id) else "-"


@rpc("authority", "call_remote", "unreliable")
func _ping(t: int) -> void:
	_pong.rpc_id(1, t)


@rpc("any_peer", "call_remote", "unreliable")
func _pong(t: int) -> void:
	var id := multiplayer.get_remote_sender_id()
	var now := Time.get_ticks_usec()
	if not multiplayer.is_server() or not players.has(id) or t > now or now - t > 10_000_000:
		return  # a time we never sent
	var ms := (now - t) / 1000.0
	_measured[id] = roundi(lerpf(float(_measured.get(id, ms)), ms, 0.5))  # smoothed a little


@rpc("authority", "call_remote", "unreliable")
func _sync_pings(p: Dictionary) -> void:
	_on_pings(p)


func _on_pings(p: Dictionary) -> void:
	pings = p
	pings_changed.emit()


func _exit_tree() -> void:
	leave()


# ------------------------------------------------------------ Steam

func _init_steam() -> void:
	if not Engine.has_singleton("Steam"):
		steam_error = "Steam support is missing from this build."
		return
	# embed_callbacks: GodotSteam runs Steam's callbacks every frame for us.
	var r: Dictionary = Steam.steamInitEx(APP_ID, true)
	if int(r.get("status", -1)) != 0:  # 0 = OK
		steam_error = "Couldn't connect to Steam. Start Steam and sign in, then restart Tag Rush to play online."
		push_warning("Steam init failed: %s" % r)
		return
	steam_ok = true
	# Your name is your Steam name (kept up to date) unless you've typed your own.
	if not Settings.g("custom_name") and Sanitize.player_name(steam_name()) != "":
		Settings.s("player_name", Sanitize.player_name(steam_name()))
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.join_requested.connect(_on_join_requested)
	Steam.lobby_match_list.connect(_on_lobby_match_list)


## Your Steam name (used as the default player name).
func steam_name() -> String:
	return Steam.getPersonaName() if steam_ok else ""


## The name you get when you don't type one: your Steam name, or "Player".
func default_name() -> String:
	var s := Sanitize.player_name(steam_name())
	return s if s != "" else "Player"


## A name box changed: a typed name is kept, an empty box goes back to the default.
func set_player_name(t: String) -> void:
	var custom := t.strip_edges() != ""
	Settings.s("custom_name", custom, false)
	Settings.s("player_name", t if custom else default_name())


## A lobby Steam asked us to join when it launched the game ("+connect_lobby <id>"
## on the command line, from an invite or the friends list), or 0.
func launch_lobby() -> int:
	var args := OS.get_cmdline_args()
	var i := args.find("+connect_lobby")
	if i >= 0 and i + 1 < args.size() and args[i + 1].is_valid_int():
		return int(args[i + 1])
	return 0


static func _lobby_type(p: int) -> int:
	match p:
		Privacy.FRIENDS:
			return Steam.LOBBY_TYPE_FRIENDS_ONLY
		Privacy.INVITE:
			return Steam.LOBBY_TYPE_PRIVATE
	return Steam.LOBBY_TYPE_PUBLIC


## Host: changes who can find / join the lobby (saved for next time).
func set_privacy(p: int) -> void:
	p = clampi(p, 0, PRIVACY_NAMES.size() - 1)
	Settings.s("lobby_privacy", p)
	if is_server() and lobby_id != 0:
		Steam.setLobbyType(lobby_id, _lobby_type(p))


func privacy() -> int:
	return clampi(int(Settings.g("lobby_privacy")), 0, PRIVACY_NAMES.size() - 1)


## Asks Steam for open Tag Rush lobbies; answers with lobby_list_received.
func find_lobbies() -> void:
	if not steam_ok:
		lobby_list_received.emit.call_deferred([])
		return
	Steam.addRequestLobbyListStringFilter("game", LOBBY_GAME, Steam.LOBBY_COMPARISON_EQUAL)
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	Steam.addRequestLobbyListResultCountFilter(50)
	Steam.requestLobbyList()


func _on_lobby_match_list(lobbies: Array) -> void:
	var out := []
	for id in lobbies:
		# Lobby data is written by whoever made the lobby: treat it as untrusted text.
		out.append({
			"id": int(id),
			"name": Sanitize.player_name(Steam.getLobbyData(id, "name")),
			"version": Sanitize.text(Steam.getLobbyData(id, "version")).left(16),
			"players": Steam.getNumLobbyMembers(id),
			"max": Steam.getLobbyMemberLimit(id),
		})
	lobby_list_received.emit(out)


## Online Steam friends you can invite: [{id, name, playing}] (playing = in Tag Rush).
func invitable_friends() -> Array:
	var out := []
	if not steam_ok:
		return out
	for i in Steam.getFriendCount(Steam.FRIEND_FLAG_IMMEDIATE):
		var fid: int = Steam.getFriendByIndex(i, Steam.FRIEND_FLAG_IMMEDIATE)
		if Steam.getFriendPersonaState(fid) == Steam.PERSONA_STATE_OFFLINE:
			continue
		var game: Dictionary = Steam.getFriendGamePlayed(fid)
		var fname: String = Steam.getFriendPersonaName(fid)
		if fname == "" or fname.is_valid_int():
			fname = "Steam friend"  # Steam hasn't sent their name yet (it gives the ID meanwhile)
		out.append({"id": fid, "name": fname, "playing": int(game.get("id", 0)) == APP_ID})
	out.sort_custom(func(a, b): return a.playing and not b.playing if a.playing != b.playing else a.name.naturalnocasecmp_to(b.name) < 0)
	return out


func invite(friend_id: int) -> bool:
	return steam_ok and lobby_id != 0 and Steam.inviteUserToLobby(lobby_id, friend_id)


## Steam's own invite window (needs the Steam overlay, which isn't always there).
func open_invite_overlay() -> bool:
	if not steam_ok or lobby_id == 0 or not Steam.isOverlayEnabled():
		return false
	Steam.activateGameOverlayInviteDialog(lobby_id)
	return true


func _on_join_requested(lobby: int, _friend: int) -> void:
	invite_accepted.emit(lobby)


func _on_lobby_created(result: int, id: int) -> void:
	if not _hosting:
		if result == Steam.RESULT_OK:
			Steam.leaveLobby(id)  # cancelled before Steam answered
		return
	_hosting = false
	if result != Steam.RESULT_OK:
		join_failed.emit("Steam couldn't create a lobby (error %d). Try again." % result)
		return
	var peer := SteamMultiplayerPeer.new()
	var err := peer.create_host(0)
	if err != OK:
		Steam.leaveLobby(id)
		join_failed.emit("Couldn't start hosting (error %d)." % err)
		return
	lobby_id = id
	Steam.setLobbyJoinable(id, true)
	Steam.setLobbyData(id, "game", LOBBY_GAME)
	Steam.setLobbyData(id, "version", GameVersion.CURRENT)
	Steam.setLobbyData(id, "name", Sanitize.player_name(Settings.g("player_name")))
	_start_server(peer)


func _on_lobby_joined(lobby: int, _permissions: int, _locked: bool, response: int) -> void:
	if lobby != _joining:
		# Cancelled before Steam answered: don't stay in it as a ghost member.
		if response == Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS and not _hosting and lobby != lobby_id:
			Steam.leaveLobby(lobby)
		return
	_joining = 0
	if response != Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		join_failed.emit(_enter_error(response))
		return
	var fail := ""
	var version := Sanitize.text(Steam.getLobbyData(lobby, "version")).left(16)
	if Steam.getLobbyData(lobby, "game") != LOBBY_GAME:
		fail = "That isn't a Tag Rush lobby."
	elif version != GameVersion.CURRENT:
		fail = "Version mismatch: the host is on %s, you're on %s. Update to the same version." % [version, GameVersion.CURRENT]
	var owner: int = Steam.getLobbyOwner(lobby)
	if fail == "" and owner == Steam.getSteamID():
		fail = "That's your own lobby."
	var peer := SteamMultiplayerPeer.new()
	if fail == "" and peer.create_client(owner, 0) != OK:
		fail = "Couldn't connect to the host."
	if fail != "":
		Steam.leaveLobby(lobby)
		join_failed.emit(fail)
		return
	lobby_id = lobby
	multiplayer.multiplayer_peer = peer
	online = true
	players.clear()
	_reject_reason = ""
	# connected_to_server (-> _on_connected) or connection_failed follows.


static func _enter_error(response: int) -> String:
	match response:
		2:
			return "That lobby doesn't exist any more."
		3:
			return "You're not allowed into that lobby (it may be friends or invite only)."
		4:
			return "The lobby is full."
		6:
			return "You're banned from that lobby."
	return "Couldn't join the lobby (Steam error %d)." % response


## True if steam_id is in our lobby (server: only lobby members may play).
func _in_lobby(steam_id: int) -> bool:
	for i in Steam.getNumLobbyMembers(lobby_id):
		if Steam.getLobbyMemberByIndex(lobby_id, i) == steam_id:
			return true
	return false


# ------------------------------------------------------------ hosting / joining

func my_id() -> int:
	return multiplayer.get_unique_id()


func is_server() -> bool:
	return online and multiplayer.is_server()


## Sender of the current RPC; falls back to the local id for local calls.
func sender() -> int:
	var s := remote_sender()
	return s if s != 0 else multiplayer.get_unique_id()


# ------------------------------------------------------------------ host relay
# Messages a client sends to everyone (movement, shots, doors, grapples) go to
# the host, which runs them and passes them on to everyone else. Clients aren't
# guaranteed a working connection to each other over Steam (lobbies of 3+ saw
# other players frozen while the host saw everyone), but every client always
# reaches the host. Handlers ask remote_sender() who really sent a message.

## Methods a client may send through the host: method -> [argument count, the
## sender must own the node (a player's own state)].
const RELAYED := {
	"_net_state": [6, true],
	"_grapple_net": [3, true],
	"_grapple_yank": [0, false],
	"fx_shot": [3, false],
	"door_rpc": [3, false],
	"_fx_projectile": [4, false], "uav_pulse": [2, false],
}
var _relay_from := 0  # while a relayed message runs: who originally sent it


## The original sender of the message being handled (0 for a local call).
func remote_sender() -> int:
	return _relay_from if _relay_from != 0 else multiplayer.get_remote_sender_id()


## Sends node.method(args) to everyone else: directly from the host, through
## the host from a client. With local it also runs here first (like call_local).
func to_all(node: Node, method: StringName, args: Array, reliable: bool, local := false) -> void:
	if local:
		node.callv(method, args)
	if not online:
		return
	if multiplayer.is_server():
		for pid in multiplayer.get_peers():
			_send_relayed(pid, multiplayer.get_unique_id(), node.get_path(), method, args, reliable)
	elif reliable:
		_relay_r.rpc_id(1, 0, node.get_path(), method, args)
	else:
		_relay_u.rpc_id(1, 0, node.get_path(), method, args)


## Sends node.method(args) to one peer, through the host if we're a client.
func to_peer(target: int, node: Node, method: StringName, args: Array) -> void:
	if multiplayer.is_server():
		_send_relayed(target, multiplayer.get_unique_id(), node.get_path(), method, args, true)
	else:
		_relay_r.rpc_id(1, target, node.get_path(), method, args)


func _send_relayed(pid: int, from: int, path: NodePath, method: StringName, args: Array, reliable: bool) -> void:
	if reliable:
		_relayed_r.rpc_id(pid, from, path, method, args)
	else:
		_relayed_u.rpc_id(pid, from, path, method, args)


# Client -> host. target 0 = everyone, otherwise that one peer.
@rpc("any_peer", "call_remote", "reliable")
func _relay_r(target: int, path: NodePath, method: StringName, args: Array) -> void:
	_on_relay(target, path, method, args, true)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _relay_u(target: int, path: NodePath, method: StringName, args: Array) -> void:
	_on_relay(target, path, method, args, false)


func _on_relay(target: int, path: NodePath, method: StringName, args: Array, reliable: bool) -> void:
	var from := multiplayer.get_remote_sender_id()
	if not multiplayer.is_server() or not players.has(from) or not _run_relayed(from, path, method, args, target != 0 and target != 1):
		return
	if target != 0:
		if target != 1 and players.has(target):
			_send_relayed(target, from, path, method, args, reliable)
		return
	for pid in multiplayer.get_peers():
		if pid != from:
			_send_relayed(pid, from, path, method, args, reliable)


# Host -> client: a message from player `from`, passed on by the host.
@rpc("authority", "call_remote", "reliable")
func _relayed_r(from: int, path: NodePath, method: StringName, args: Array) -> void:
	_run_relayed(from, path, method, args, false)


@rpc("authority", "call_remote", "unreliable_ordered")
func _relayed_u(from: int, path: NodePath, method: StringName, args: Array) -> void:
	_run_relayed(from, path, method, args, false)


## Runs a relayed message here as if `from` had sent it. Returns false if it
## isn't allowed. check_only: the host just checks a message meant for someone else.
func _run_relayed(from: int, path: NodePath, method: StringName, args: Array, check_only: bool) -> bool:
	var rule: Array = RELAYED.get(String(method), [])
	var node := get_node_or_null(path)
	if rule.is_empty() or node == null or args.size() != int(rule[0]) or not node.has_method(method):
		return false
	if rule[1] and node.get_multiplayer_authority() != from:
		return false
	if check_only or from == multiplayer.get_unique_id():
		return true
	_relay_from = from
	node.callv(method, args)
	_relay_from = 0
	return true


## Starts hosting: asks Steam for a lobby. Finishes in _on_lobby_created, which
## emits joined_ok (or join_failed). Returns an error message, or "".
func host() -> String:
	leave()
	if not steam_ok:
		return steam_error
	_hosting = true
	Steam.createLobby(_lobby_type(privacy()), MAX_PLAYERS)
	return ""


## Joins a Steam lobby (from Join Game or an invite). Finishes in _on_lobby_joined.
func join_lobby(id: int) -> String:
	leave()
	if not steam_ok:
		return steam_error
	if id <= 0:
		return "That lobby doesn't exist any more."
	_joining = id
	Steam.joinLobby(id)
	return ""


## Debug builds only: a local ENet match for testing two copies on one PC.
func host_local(port: int) -> String:
	leave()
	if not OS.is_debug_build():
		return "Local matches are only for testing."
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		return "Could not host on port %d (error %d). Is it already in use?" % [port, err]
	_start_server(peer)
	return ""


func join_local(ip: String, port: int) -> String:
	leave()
	if not OS.is_debug_build():
		return "Local matches are only for testing."
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		return "Could not start connection (error %d)." % err
	multiplayer.multiplayer_peer = peer
	online = true
	players.clear()
	_reject_reason = ""
	return ""


func _start_server(peer: MultiplayerPeer) -> void:
	multiplayer.multiplayer_peer = peer
	online = true
	players.clear()
	_add_player(1, Settings.g("player_name"), Settings.g("weapon"), Settings.g("addon"), Settings.g("addon2"))
	Game._set_map_size_local(str(Settings.g("map_size")))
	roster_changed.emit()
	upload_my_spray()
	joined_ok.emit()


func leave() -> void:
	_hosting = false
	_joining = 0
	if lobby_id != 0 and steam_ok:
		Steam.leaveLobby(lobby_id)
	lobby_id = 0
	sprays.clear()
	_spray_tex.clear()
	_chat_times.clear()
	_spray_up_at.clear()
	pings.clear()
	_measured.clear()
	_ping_show_acc = PING_SHOW_INTERVAL
	if multiplayer.multiplayer_peer and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	online = false
	players.clear()


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
	register.rpc_id(1, Settings.g("player_name"), Settings.g("weapon"), Settings.g("addon"), GameVersion.CURRENT, Settings.g("addon2"))
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
	join_failed.emit("Couldn't connect to the host. Try again, or ask them to invite you.")


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

## addon2 comes last (with a default), so an older build still gets as far as the
## version check and is told to update.
@rpc("any_peer", "reliable")
func register(pname: String, weapon: String, addon: String, version: String, addon2 := "") -> void:
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
	# Anyone can open a Steam connection to the host, so only members of our lobby
	# (which follows its Public / Friends / Invite rule) get in.
	var peer := multiplayer.multiplayer_peer
	if peer is SteamMultiplayerPeer and not _in_lobby(peer.get_steam_id_for_peer_id(id)):
		_reject(id, "Join the host's lobby to play.")
		return
	_add_player(id, pname, weapon, addon, addon2)
	_broadcast()
	for sid in sprays:
		_spray_data.rpc_id(id, sid, sprays[sid])
	Game.send_map_size_to(id)
	Game.on_player_joined(id)


func _add_player(id: int, pname: String, weapon: String, addon: String, addon2: String) -> void:
	pname = Sanitize.player_name(pname)
	if pname == "":
		pname = "Player %d" % (players.size() + 1)
	# Names are unique in a lobby, so nobody can pass themselves off as someone else.
	var taken := []
	for pid in players:
		taken.append(str(players[pid].name).to_lower())
	var base := pname.left(Sanitize.MAX_NAME - 4)
	var n := 2
	while pname.to_lower() in taken:
		pname = "%s (%d)" % [base, n]
		n += 1
	var team := 0 if team_count(0) <= team_count(1) else 1
	if not Weapons.DATA.has(weapon):
		weapon = "ar"
	if Addons.slot_of(addon) != 0:
		addon = Addons.DEFAULT_ACTIVE
	if Addons.slot_of(addon2) != 1:
		addon2 = Addons.DEFAULT_PASSIVE
	players[id] = {"name": pname, "team": team, "weapon": weapon, "addon": addon, "addon2": addon2, "kills": 0, "deaths": 0}


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
func request_loadout(weapon: String, addon: String, addon2: String) -> void:
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
	if Addons.slot_of(addon) == 0:
		players[id].addon = addon
	if Addons.slot_of(addon2) == 1:
		players[id].addon2 = addon2
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
