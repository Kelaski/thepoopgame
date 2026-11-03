extends Node
## Root controller: screen flow (menu -> lobby -> match), overlays, mouse capture.
##
## Optional command-line flags (after "--"):
##   --host            host immediately          --join=IP[:PORT]  join immediately
##   --name=NAME       player name               --port=PORT       port to host / join
##   --autostart=N     host starts the match once N players are connected

var ui_layer: CanvasLayer
var ui_root: Control
var screen: Control
var overlay: Control
var world: World
var hud: Hud
var _autostart := 0
var _settings_back_to_pause := false


func _ready() -> void:
	name = "Main"
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	ui_root = Control.new()
	ui_root.name = "UI"
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.theme = UiKit.make_theme()
	ui_layer.add_child(ui_root)
	add_child(BirdEvent.new())
	Net.joined_ok.connect(_on_joined)
	Net.join_failed.connect(_on_join_failed)
	Net.disconnected.connect(_on_disconnected)
	Net.roster_changed.connect(_on_roster_changed)
	Game.match_started.connect(_on_match_started)
	Game.match_ended.connect(_on_match_ended)
	if not _handle_cmdline():
		show_main_menu()


func _handle_cmdline() -> bool:
	var host := false
	var join_addr := ""
	var port := int(Settings.g("port"))
	for a in OS.get_cmdline_user_args():
		if a == "--host":
			host = true
		elif a.begins_with("--join="):
			join_addr = a.substr(7)
		elif a.begins_with("--name="):
			Settings.s("player_name", a.substr(7), false)
		elif a.begins_with("--port="):
			port = int(a.substr(7))
		elif a.begins_with("--autostart="):
			_autostart = int(a.substr(12))
	if host:
		host_game(port)
		return true
	if join_addr != "":
		var parts := join_addr.split(":")
		join_game(parts[0], int(parts[1]) if parts.size() > 1 else port)
		return true
	return false


# ================================================================ screens

func _set_screen(c: Control) -> void:
	if screen:
		screen.queue_free()
	screen = c
	if c:
		ui_root.add_child(c)
	_update_mouse()


func show_main_menu(message := "") -> void:
	close_overlay()
	var m := MainMenu.new()
	m.main = self
	m.message = message
	_set_screen(m)


func show_lobby() -> void:
	close_overlay()
	var l := Lobby.new()
	l.main = self
	_set_screen(l)


func show_connecting(ip: String, port: int) -> void:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var v := UiKit.centered_panel(c, Vector2(420, 0))
	v.add_child(UiKit.label("Connecting to %s:%d ..." % [ip, port], 22, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UiKit.button("Cancel", func(): leave_to_menu()))
	_set_screen(c)


func host_game(port: int) -> void:
	var err: String = Net.host(port)
	if err != "":
		show_main_menu(err)
		return
	Settings.s("port", port)
	show_lobby()


func join_game(ip: String, port: int) -> void:
	var err: String = Net.join(ip, port)
	if err != "":
		show_main_menu(err)
		return
	Settings.s("last_ip", ip, false)
	Settings.s("port", port)
	show_connecting(ip, port)


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
	world = World.new()
	world.name = "World"
	add_child(world)
	hud = Hud.new()
	hud.main = self
	ui_root.add_child(hud)
	Sfx.start_music()
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
	Sfx.stop_music()
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
	var p := PauseMenu.new()
	p.main = self
	_set_overlay(p)


func open_settings(back_to_pause: bool) -> void:
	_settings_back_to_pause = back_to_pause
	var s := SettingsMenu.new()
	s.on_back = _settings_back
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
	ui_root.add_child(c)
	_update_mouse()


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
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
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
