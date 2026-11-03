extends Node
## Root controller: screen flow (menu -> lobby -> match), overlays, mouse capture.
##
## Optional command-line flags (after "--"):
##   --host            host immediately          --join=CODE       join immediately
##   --name=NAME       player name               --port=PORT       port to host on
##   (--join also takes IP or IP:PORT)
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
	UiKit.refresh()
	Mats.refresh()
	ui_root.theme = UiKit.make_theme()
	ui_layer.add_child(ui_root)
	Settings.colors_changed.connect(_on_colors_changed)
	add_child(BirdEvent.new())
	var chat := ChatBox.new()
	chat.name = "Chat"
	ui_root.add_child(chat)
	_add_version_label()
	Net.joined_ok.connect(_on_joined)
	Net.join_failed.connect(_on_join_failed)
	Net.disconnected.connect(_on_disconnected)
	Net.roster_changed.connect(_on_roster_changed)
	Game.match_started.connect(_on_match_started)
	Game.match_ended.connect(_on_match_ended)
	if not _handle_cmdline():
		show_main_menu()


## Game version in the bottom-left corner of every screen (menus, lobby and
## matches), on its own layer so menu backgrounds never cover it.
func _add_version_label() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 11
	add_child(layer)
	var l := UiKit.outlined("v" + GameVersion.CURRENT, 12, UiKit.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(l)
	l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	l.offset_left = 6
	l.offset_right = 6
	l.offset_top = -3
	l.offset_bottom = -3


func _handle_cmdline() -> bool:
	var host := false
	var join_addr := ""
	var port := Net.DEFAULT_PORT
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
		join_code(join_addr)
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


## "Play Game": enter a join code.
func show_join_menu(message := "") -> void:
	close_overlay()
	var j := JoinMenu.new()
	j.main = self
	j.message = message
	_set_screen(j)


func show_connecting() -> void:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var v := UiKit.centered_panel(c, Vector2(420, 0))
	v.add_child(UiKit.label("Connecting ...", 22, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UiKit.button("Cancel", func(): leave_to_menu()))
	_set_screen(c)


func host_game(port := Net.DEFAULT_PORT) -> void:
	var err: String = Net.host(port)
	if err != "":
		show_main_menu(err)
		return
	show_lobby()


## Join with a code (or a plain IP / IP:PORT).
func join_code(code: String) -> void:
	var addr := JoinCode.parse(code)
	if addr.is_empty():
		show_join_menu("That isn't a valid join code.")
		return
	Settings.s("last_code", code.strip_edges().to_upper())
	join_game(addr.ip, addr.port)


func join_game(ip: String, port: int) -> void:
	var err: String = Net.join(ip, port)
	if err != "":
		show_join_menu(err)
		return
	show_connecting()


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


var _back_to_hub := false


## Customization screens. from_hub = Back returns to the Customize hub.
func open_customize(back_to_pause: bool) -> void:
	_settings_back_to_pause = back_to_pause
	var h := CustomizeHub.new()
	h.main = self
	h.back_to_pause = back_to_pause
	_set_overlay(h)


func open_music(back_to_pause: bool, from_hub := false) -> void:
	_open_custom(MusicMenu.new(), back_to_pause, from_hub)


func open_colors(back_to_pause: bool, from_hub := false) -> void:
	_open_custom(ColorsMenu.new(), back_to_pause, from_hub)


func open_crosshair(back_to_pause: bool, from_hub := false) -> void:
	_open_custom(CrosshairEditor.new(), back_to_pause, from_hub)


func open_spray(back_to_pause: bool, from_hub := false) -> void:
	_open_custom(SprayMenu.new(), back_to_pause, from_hub)


func open_skybox(back_to_pause: bool, from_hub := false) -> void:
	_open_custom(SkyboxMenu.new(), back_to_pause, from_hub)


func _open_custom(menu: Control, back_to_pause: bool, from_hub: bool) -> void:
	_settings_back_to_pause = back_to_pause
	_back_to_hub = from_hub
	menu.set("on_back", _custom_back)
	_set_overlay(menu)


func _custom_back() -> void:
	if _back_to_hub:
		open_customize(_settings_back_to_pause)
	else:
		_settings_back()


const COLORS_APPLY_INTERVAL := 0.1
var _colors_dirty := false
var _colors_cooldown := 0.0


## Colour pickers fire on every drag step, so the theme is rebuilt at most every
## COLORS_APPLY_INTERVAL seconds.
func _on_colors_changed() -> void:
	_colors_dirty = true


func _process(delta: float) -> void:
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


## Swaps the open menu for a freshly built one (menus rebuild themselves to show
## changed settings). Falls back to a plain swap if old isn't the current overlay.
func replace_overlay(old: Control, fresh: Control) -> void:
	if overlay == old:
		_set_overlay(fresh)
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
