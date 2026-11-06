extends Node
## Root controller: screen flow (menu -> lobby -> match), overlays, mouse capture.
##
## Optional command-line flags (after "--"):
##   --host            host a Steam lobby immediately
##   --name=NAME       player name (debug builds only; otherwise it's your Steam name)
##   --autostart=N     host starts the match once N players are connected
## Debug builds only, for testing two copies on one PC without Steam:
##   --host --port=PORT   host a local match     --join=IP[:PORT]   join one
## Steam adds "+connect_lobby <id>" when it launches the game from an invite.

# Every screen is a scene in assets/ui (its script holds the behaviour).
const MAIN_MENU_SCENE := preload("res://assets/ui/menu/main_menu.tscn")
const CONNECTING_SCENE := preload("res://assets/ui/menu/connecting.tscn")
const LOBBY_SCENE := preload("res://assets/ui/menu/lobby.tscn")
const HUD_SCENE := preload("res://assets/ui/hud/hud.tscn")
const PAUSE_SCENE := preload("res://assets/ui/menu/pause_menu.tscn")
const SETTINGS_SCENE := preload("res://assets/ui/menu/settings_menu.tscn")
const CHAT_SCENE := preload("res://assets/ui/hud/chat_box.tscn")
const VERSION_SCENE := preload("res://assets/ui/hud/version_label.tscn")
const UPDATE_SCENE := preload("res://assets/ui/menu/update_screen.tscn")

var ui_layer: CanvasLayer
var ui_root: Control
var menu_root: Control  # menus are laid out for 1920 x 1080 and scaled to the 1600 x 900 canvas
var _music_started := false
var screen: Control
var overlay: Control
var world: World
var hud: Hud
var _autostart := 0
var _settings_back_to_pause := false
const MENU_SCALE := 1600.0 / 1920.0


func _ready() -> void:
	name = "Main"
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	ui_root = Control.new()
	ui_root.name = "UI"
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.refresh()
	Mats.refresh()
	ui_root.theme = UiKit.make_theme()
	ui_layer.add_child(ui_root)
	Settings.colors_changed.connect(_on_colors_changed)
	var chat: ChatBox = CHAT_SCENE.instantiate()
	chat.name = "Chat"
	ui_root.add_child(chat)
	menu_root = Control.new()
	menu_root.name = "Menus"
	menu_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_root.scale = Vector2.ONE * MENU_SCALE
	ui_root.add_child(menu_root)
	ui_root.resized.connect(_fit_menus)
	_fit_menus()
	_add_version_label()
	Net.joined_ok.connect(_on_joined)
	Net.join_failed.connect(_on_join_failed)
	Net.disconnected.connect(_on_disconnected)
	Net.invite_accepted.connect(join_lobby)
	Net.roster_changed.connect(_on_roster_changed)
	Game.match_started.connect(_on_match_started)
	Game.match_ended.connect(_on_match_ended)
	if not _handle_cmdline():
		_after_update(show_main_menu.bind(""))


func _fit_menus() -> void:
	menu_root.size = ui_root.size / MENU_SCALE


## Exported builds check for a newer version first (assets/ui/update_screen.tscn),
## then carry on with `next`.
func _after_update(next: Callable) -> void:
	if not UpdateScreen.applies():
		next.call()
		return
	var u: UpdateScreen = UPDATE_SCENE.instantiate()
	u.finished.connect(next)
	_set_screen(u)


## Game version in the bottom-left corner of every screen (menus, lobby and
## matches), on its own layer (assets/ui/version_label.tscn) so menu backgrounds
## never cover it.
func _add_version_label() -> void:
	var layer: CanvasLayer = VERSION_SCENE.instantiate()
	add_child(layer)
	layer.get_node("Label").text = "v" + GameVersion.CURRENT


func _handle_cmdline() -> bool:
	var host := false
	var join_addr := ""
	var port := 0
	for a in OS.get_cmdline_user_args():
		if a == "--host":
			host = true
		elif a.begins_with("--join="):
			join_addr = a.substr(7)
		elif a.begins_with("--name="):
			if OS.is_debug_build():
				Net.name_override = a.substr(7)
		elif a.begins_with("--port="):
			port = int(a.substr(7))
		elif a.begins_with("--autostart="):
			_autostart = int(a.substr(12))
	var lobby := Net.launch_lobby()
	if lobby != 0:  # started from Steam's "Join Game": update first, or the host may refuse our version
		_after_update(join_lobby.bind(lobby))
		return true
	if OS.is_debug_build() and (port > 0 or join_addr != ""):
		return _local_cmdline(host, port, join_addr)
	if host:
		host_game()
		return true
	return false


## Debug builds: local ENet matches (see the flags at the top).
func _local_cmdline(host: bool, port: int, join_addr: String) -> bool:
	if port <= 0:
		port = Net.LOCAL_PORT
	var err := ""
	if host:
		err = Net.host_local(port)
	elif join_addr != "":
		var bits := join_addr.split(":")
		show_connecting()
		err = Net.join_local(bits[0], int(bits[1]) if bits.size() > 1 else port)
	else:
		return false
	if err != "":
		show_main_menu(err)
	return true


# ================================================================ screens

func _set_screen(c: Control) -> void:
	if screen:
		screen.queue_free()
	screen = c
	if c:
		c.theme = MenuKit.theme()
		menu_root.add_child(c)
	_update_mouse()


func show_main_menu(message := "") -> void:
	close_overlay()
	var m: MainMenu = MAIN_MENU_SCENE.instantiate()
	m.main = self
	m.message = message if message != "" or Net.steam_ok else Net.steam_error
	_set_screen(m)


func show_lobby() -> void:
	close_overlay()
	var l: Lobby = LOBBY_SCENE.instantiate()
	l.main = self
	_set_screen(l)


func show_connecting() -> void:
	var c: Control = CONNECTING_SCENE.instantiate()
	c.get_node("%CancelButton").pressed.connect(leave_to_menu.bind(""))
	_set_screen(c)


## Host a Steam lobby. Shows "Connecting" until Steam has made the lobby
## (Net.joined_ok -> lobby, or Net.join_failed -> main menu).
func host_game() -> void:
	show_connecting()
	var err: String = Net.host()
	if err != "":
		show_main_menu(err)


## Join a Steam lobby: from the server browser, an invite, or Steam's friends list. Leaves
## whatever we're in first (an invite can arrive mid-match).
func join_lobby(lobby: int) -> void:
	_teardown_world()
	Game.reset_local()
	close_overlay()
	show_connecting()
	var err: String = Net.join_lobby(lobby)
	if err != "":
		show_main_menu(err)


func leave_to_menu(message := "") -> void:
	_teardown_world()
	Net.leave()
	Game.reset_local()
	show_main_menu(message)


func _on_joined() -> void:
	if not Game.in_match:
		show_lobby()


func _on_join_failed(reason: String) -> void:
	leave_to_menu(reason)


func _on_disconnected(reason: String) -> void:
	leave_to_menu(reason)


func _on_roster_changed() -> void:
	if _autostart > 0 and multiplayer.is_server() and not Game.in_match and Net.players.size() >= _autostart:
		_autostart = 0
		Game.server_start_match()


# ================================================================ match

func _on_match_started() -> void:
	_teardown_world()
	_set_screen(null)
	close_overlay()
	Mats.refresh()
	world = World.new()
	world.name = "World"
	add_child(world)
	hud = HUD_SCENE.instantiate()
	hud.main = self
	ui_root.add_child(hud)
	ui_root.move_child(hud, 0)
	_update_mouse()


func _on_match_ended() -> void:
	_teardown_world()
	Game.in_match = false
	Game.phase = Game.Phase.LOBBY
	if Net.online:
		show_lobby()
	else:
		show_main_menu()


func _teardown_world() -> void:
	if hud:
		hud.queue_free()
		hud = null
	if world:
		remove_child(world)  # free the "World" name immediately so RPC paths stay valid
		world.queue_free()
		world = null
	Game.world = null


# ================================================================ overlays & input

func open_pause() -> void:
	var p: PauseMenu = PAUSE_SCENE.instantiate()
	p.main = self
	_set_overlay(p)


const COLORS_APPLY_INTERVAL := 0.1
var _colors_dirty := false
var _colors_cooldown := 0.0


## Colour pickers fire on every drag step, so the theme is rebuilt at most every
## COLORS_APPLY_INTERVAL seconds.
func _on_colors_changed() -> void:
	_colors_dirty = true


func _process(delta: float) -> void:
	if not _music_started and Sfx.songs_ready() and DisplayServer.get_name() != "headless":
		_music_started = true  # from launch, through menus and matches
		Sfx.start_music()
	_colors_cooldown = maxf(0.0, _colors_cooldown - delta)
	if _colors_dirty and _colors_cooldown <= 0.0:
		_colors_dirty = false
		_colors_cooldown = COLORS_APPLY_INTERVAL
		_apply_colors()


func _apply_colors() -> void:
	UiKit.refresh()
	# Team / Tag colours are part of the map's materials, so mid-match changes wait
	# for the next match (see _on_match_started) to keep HUD and models consistent.
	if not Game.in_match:
		Mats.refresh()
	ui_root.theme = UiKit.make_theme()
	MenuKit.theme()
	MenuKit.paint_accents(self)


func open_settings(back_to_pause: bool, tab := "") -> void:
	_settings_back_to_pause = back_to_pause
	var s: SettingsMenu = SETTINGS_SCENE.instantiate()
	s.on_back = _settings_back
	s.start_tab = tab
	_set_overlay(s)


func _settings_back() -> void:
	if _settings_back_to_pause and Game.in_match:
		open_pause()
	else:
		close_overlay()


func _set_overlay(c: Control) -> void:
	if overlay:
		overlay.queue_free()
	overlay = c
	c.theme = MenuKit.theme()
	menu_root.add_child(c)
	_update_mouse()


## Swaps the open menu for a freshly built one (menus rebuild themselves to show
## changed settings). Falls back to a plain swap if old isn't the current overlay.
func replace_overlay(old: Control, fresh: Control) -> void:
	if overlay == old:
		_set_overlay(fresh)
	elif overlay is SettingsMenu and overlay.is_ancestor_of(old):
		overlay.replace_tab(old, fresh)
	else:
		old.get_parent().add_child(fresh)
		old.queue_free()


func close_overlay() -> void:
	if overlay:
		overlay.queue_free()
		overlay = null
	_update_mouse()


func _update_mouse() -> void:
	var loadout_open := hud != null and hud.loadout_open
	Game.ui_open = overlay != null or loadout_open
	if DisplayServer.get_name() == "headless":
		return
	if Game.in_match and world and not Game.ui_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_action_pressed("music_player") and not event.echo and not Game.typing:
		if Game.in_match and world and overlay == null:
			open_settings(true, "Music")
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.is_action_pressed("pause") and not event.echo:
		if Game.in_match and world:
			if overlay:
				close_overlay()
			elif hud and hud.loadout_open:
				hud.set_loadout_open(false)
			else:
				open_pause()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if Game.in_match and world and not Game.ui_open and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			_update_mouse()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and Game.in_match and overlay == null and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
