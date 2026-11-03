extends Node
## Persistent player settings and rebindable controls.
## Everything is stored in user://settings.cfg.

signal changed
signal colors_changed
signal music_changed

const PATH := "user://settings.cfg"

# [action, label, kind ("k" = keyboard physical key, "m" = mouse button), default code]
const ACTIONS := [
	["move_forward", "Move Forward", "k", KEY_W],
	["move_back", "Move Back", "k", KEY_S],
	["move_left", "Move Left", "k", KEY_A],
	["move_right", "Move Right", "k", KEY_D],
	["jump", "Jump / Double Jump", "k", KEY_SPACE],
	["crouch", "Crouch / Slide", "k", KEY_CTRL],
	["sprint", "Sprint", "k", KEY_SHIFT],
	["lean_left", "Lean Left", "k", KEY_Q],
	["lean_right", "Lean Right", "k", KEY_C],
	["addon", "Use Addon", "k", KEY_F],
	["interact", "Interact / Doors", "k", KEY_E],
	["fire", "Fire", "m", MOUSE_BUTTON_LEFT],
	["aim", "Aim Down Sights", "m", MOUSE_BUTTON_RIGHT],
	["reload", "Reload", "k", KEY_R],
	["scoreboard", "Scoreboard", "k", KEY_TAB],
	["loadout", "Loadout Menu (while dead)", "k", KEY_B],
	["spray", "Spray", "k", KEY_T],
	["chat", "Chat (all)", "k", KEY_ENTER],
	["team_chat", "Chat (team)", "k", KEY_Y],
]

const DEFAULTS := {
	"player_name": "Player",
	"last_ip": "127.0.0.1",
	"port": 7777,
	"weapon": "ar",
	"map_size": "large",  # last map size chosen when hosting
	"addon": "trackstar",
	# Controls
	"sensitivity": 0.10,
	"ads_sens_mult": 0.85,
	"invert_y": false,
	"toggle_aim": false,
	"toggle_crouch": false,
	"auto_sprint": false,
	# Video
	"fov": 100.0,
	"brightness": 1.0,
	"fullscreen": false,
	"vsync": true,
	"max_fps": 144,
	"render_scale": 1.0,
	"shadows": true,
	"msaa": 0,
	"view_distance": 260.0,
	"show_fps": true,
	# Audio
	"master_volume": 0.8,
	"sfx_volume": 1.0,
	"ui_volume": 0.8,
	"music_volume": 0.45,
	# Music: "builtin" (the game's beat), "custom" (your playlist) or "both"
	"music_mode": "builtin",
	"music_shuffle": false,
	"music_tracks": [],   # [{name, file, enabled}]
	# Colour overrides: key -> html colour (see Palette)
	"colors": {},
	# HUD
	"crosshair_color": "ffffff",
	# Crosshair editor (Counter-Strike style)
	"xh_style": "classic",      # classic, circle, dot, image
	"xh_length": 8.0,
	"xh_thickness": 2.0,
	"xh_gap": 4.0,
	"xh_alpha": 1.0,
	"xh_outline": true,
	"xh_outline_thickness": 1.0,
	"xh_dot": true,
	"xh_dot_size": 2.0,
	"xh_tstyle": false,
	"xh_dynamic": true,
	"xh_image_scale": 1.0,
	"scope_custom": false,
	"scope_scale": 1.0,
	# Custom skybox (equirectangular panorama in user://skybox.png)
	"sky_custom": false,
	"sky_rotation": 0.0,
	"sky_energy": 1.0,
	"hitmarker_sound": true,
}

const MOUSE_NAMES := {
	MOUSE_BUTTON_LEFT: "Mouse Left",
	MOUSE_BUTTON_RIGHT: "Mouse Right",
	MOUSE_BUTTON_MIDDLE: "Mouse Middle",
	MOUSE_BUTTON_WHEEL_UP: "Wheel Up",
	MOUSE_BUTTON_WHEEL_DOWN: "Wheel Down",
	MOUSE_BUTTON_XBUTTON1: "Mouse 4",
	MOUSE_BUTTON_XBUTTON2: "Mouse 5",
}

var values := {}
var binds := {}  # action -> [kind, code]
var _last_fullscreen = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	load_settings()
	apply_all()


func _setup_buses() -> void:
	for bus in ["SFX", "UI", "Music"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")


func g(key: String):
	return values.get(key, DEFAULTS.get(key))


func s(key: String, v, save_now := true) -> void:
	values[key] = v
	apply_all()
	if save_now:
		save_settings()
	changed.emit()


func load_settings() -> void:
	values = DEFAULTS.duplicate(true)
	binds.clear()
	for a in ACTIONS:
		binds[a[0]] = [a[2], a[3]]
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		for k in DEFAULTS.keys():
			if cf.has_section_key("settings", k):
				values[k] = cf.get_value("settings", k)
		for a in ACTIONS:
			if cf.has_section_key("binds", a[0]):
				var b = cf.get_value("binds", a[0])
				if b is Array and b.size() == 2:
					binds[a[0]] = b
	_apply_binds()


func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in values.keys():
		cf.set_value("settings", k, values[k])
	for a in binds.keys():
		cf.set_value("binds", a, binds[a])
	cf.save(PATH)


func set_bind(action: String, kind: String, code: int) -> void:
	# If another action already uses this input, swap the bindings.
	for other in binds.keys():
		if other != action and binds[other][0] == kind and binds[other][1] == code:
			binds[other] = binds[action].duplicate()
	binds[action] = [kind, code]
	_apply_binds()
	save_settings()
	changed.emit()


func reset_binds() -> void:
	for a in ACTIONS:
		binds[a[0]] = [a[2], a[3]]
	_apply_binds()
	save_settings()
	changed.emit()


func reset_all() -> void:
	values = DEFAULTS.duplicate(true)
	reset_binds()
	apply_all()
	save_settings()
	changed.emit()
	colors_changed.emit()
	music_changed.emit()


# ------------------------------------------------------------------ colours

func color(key: String, fallback: Color) -> Color:
	var c: Dictionary = values.get("colors", {})
	if c.has(key):
		return Color.from_string(str(c[key]), fallback)
	return fallback


func set_color(key: String, c: Color, save_now := true) -> void:
	var d: Dictionary = values.get("colors", {}).duplicate()
	d[key] = c.to_html(true)
	values["colors"] = d
	if save_now:
		save_settings()
	colors_changed.emit()


func clear_color(key: String) -> void:
	var d: Dictionary = values.get("colors", {}).duplicate()
	d.erase(key)
	values["colors"] = d
	save_settings()
	colors_changed.emit()


func set_colors(d: Dictionary) -> void:
	values["colors"] = d.duplicate()
	save_settings()
	colors_changed.emit()


# ------------------------------------------------------------------ music

func music_tracks() -> Array:
	return values.get("music_tracks", []).duplicate(true)


func set_music_tracks(tracks: Array) -> void:
	values["music_tracks"] = tracks.duplicate(true)
	save_settings()
	music_changed.emit()


func _apply_binds() -> void:
	for a in ACTIONS:
		var action: String = a[0]
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, make_event(binds[action]))


func make_event(b: Array) -> InputEvent:
	if b[0] == "m":
		var m := InputEventMouseButton.new()
		m.button_index = b[1]
		return m
	var k := InputEventKey.new()
	k.physical_keycode = b[1]
	return k


func bind_text(action: String) -> String:
	var b: Array = binds.get(action, ["k", 0])
	if b[0] == "m":
		return MOUSE_NAMES.get(b[1], "Mouse %d" % b[1])
	return OS.get_keycode_string(b[1])


func apply_all() -> void:
	if DisplayServer.get_name() != "headless":
		var fs: bool = g("fullscreen")
		if _last_fullscreen != fs:
			_last_fullscreen = fs
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fs else DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if g("vsync") else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(g("max_fps"))
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_scale = clampf(float(g("render_scale")), 0.5, 1.0)
		var msaa_levels := [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X]
		vp.msaa_3d = msaa_levels[clampi(int(g("msaa")), 0, 2)]
	_set_bus("Master", g("master_volume"))
	_set_bus("SFX", g("sfx_volume"))
	_set_bus("UI", g("ui_volume"))
	_set_bus("Music", g("music_volume"))


func _set_bus(bus: String, v) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i >= 0:
		var lin := clampf(float(v), 0.0, 1.0)
		AudioServer.set_bus_mute(i, lin <= 0.001)
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(lin, 0.001)))


func crosshair_color() -> Color:
	return Color.from_string(str(g("crosshair_color")), Color.WHITE)
