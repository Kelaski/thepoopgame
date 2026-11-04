extends Node
## Persistent player settings and rebindable controls.
## Everything is stored in user://settings.cfg.
##
## The default controls are the game's actions in Project Settings > Input Map
## (project.godot). Players can rebind them in Settings > Keybinds: a rebound
## action gets the player's key or mouse button instead (saved in settings.cfg),
## and resetting it brings back everything set in the Input Map.

signal changed
signal colors_changed
signal music_changed

const PATH := "user://settings.cfg"

# Rebindable actions, in the order the Keybinds tab lists them: [action, label].
# Their default keys / buttons are set in Project Settings > Input Map.
const ACTIONS := [
	["move_forward", "Move Forward"],
	["move_back", "Move Back"],
	["move_left", "Move Left"],
	["move_right", "Move Right"],
	["jump", "Jump / Double Jump"],
	["crouch", "Crouch / Slide"],
	["crouch_only", "Crouch"],
	["addon", "Use Primary Addon"],
	["addon2", "Use Secondary Addon"],
	["interact", "Interact / Doors"],
	["fire", "Fire"],
	["aim", "Aim Down Sights"],
	["reload", "Reload"],
	["ping", "Ping (double tap: danger)"],
	["scoreboard", "Scoreboard"],
	["loadout", "Loadout Menu (while dead)"],
	["spray", "Spray"],
	["chat", "Chat (hold Right Shift for team chat)"],
]

const DEFAULTS := {
	"player_name": "Player",
	"custom_name": false,  # the player typed their own name; otherwise it follows their Steam name
	"lobby_privacy": 0,  # who can join lobbies you host: Net.Privacy (public / friends / invite only)
	"weapon": "ar",
	"map_size": "large",  # last map size chosen when hosting
	"map_random": true,   # host: a new random city every match (false = the classic city)
	"addon": "grapple",     # primary addon (Addons.PRIMARY)
	"addon2": "trackstar",  # secondary addon (Addons.SECONDARY)
	# Controls
	"sensitivity": 0.10,
	"ads_sens_mult": 0.85,
	"invert_y": false,
	"toggle_aim": false,
	"toggle_crouch": false,
	# Video
	"fov": 100.0,
	"brightness": 1.0,
	"fullscreen": false,
	"vsync": true,
	"max_fps": 144,
	"render_scale": 1.0,
	"shadows": true,
	"shadow_quality": 2,  # 0 low, 1 medium, 2 high, 3 ultra (see World.SHADOW_QUALITY)
	"interior_lights": 2,  # 0 off, 1 low (every other lamp, shorter reach), 2 high
	"bloom": true,
	"msaa": 0,
	"view_distance": 260.0,
	"show_fps": true,
	"show_speed": true,  # speedometer above the health bar
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
	"minimap_scale": 1.0,      # 0.6 - 2.0
	"minimap_labels": true,    # location names on the minimap
	"crosshair_color": "ffffff",
	# Holo sight reticle (AR / SMG), set in the crosshair editor
	"holo_style": "circle_dot",
	"holo_color": "ff3b30",
	"holo_size": 1.0,
	"holo_brightness": 1.6,
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

# Saved keybinds are migrated when the defaults change: a bind still set to an old
# default moves to the new default (binds the player changed are kept).
const BINDS_VERSION := 3
const OLD_DEFAULT_BINDS := {
	2: {"addon": ["k", KEY_F]},
	3: {"addon": ["k", KEY_SHIFT], "interact": ["k", KEY_E]},  # 0.21.0: primary addon on E, doors on F
}
# Raising this wipes everyone's saved settings and binds back to the defaults once
# (1: 0.18.0, when leaning was removed and Interact moved back to E).
const RESET_VERSION := 1

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
var binds := {}  # action -> [kind ("k" key / "m" mouse button), code]: what's shown in Keybinds
var _default_events := {}  # action -> the Input Map's events (from project.godot)
var _default_binds := {}   # action -> [kind, code] of the Input Map's first key / button
var _last_fullscreen = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_read_input_map()
	load_settings()
	apply_all()


## Remembers the default controls from Project Settings > Input Map before any
## of the player's rebinds are applied.
func _read_input_map() -> void:
	for a in ACTIONS:
		var action: String = a[0]
		if not InputMap.has_action(action):
			push_warning("Input action \"%s\" is missing from Project Settings > Input Map" % action)
			InputMap.add_action(action, 0.2)
		var events := InputMap.action_get_events(action)
		_default_events[action] = events.duplicate()
		_default_binds[action] = ["k", 0]
		for ev in events:
			var b := _bind_of(ev)
			if not b.is_empty():
				_default_binds[action] = b
				break


## [kind, code] for a key or mouse-button event ([] for anything else).
static func _bind_of(ev: InputEvent) -> Array:
	if ev is InputEventMouseButton:
		return ["m", ev.button_index]
	if ev is InputEventKey:
		return ["k", ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode]
	return []


func default_bind(action: String) -> Array:
	return _default_binds.get(action, ["k", 0]).duplicate()


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
		binds[a[0]] = default_bind(a[0])
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK and int(cf.get_value("meta", "reset_version", 0)) < RESET_VERSION:
		save_settings.call_deferred()  # an update reset everything: start from the defaults
	elif cf.load(PATH) == OK:
		for k in DEFAULTS.keys():
			if cf.has_section_key("settings", k):
				values[k] = cf.get_value("settings", k)
		for a in ACTIONS:
			if cf.has_section_key("binds", a[0]):
				var b = cf.get_value("binds", a[0])
				if b is Array and b.size() == 2:
					binds[a[0]] = b
		_migrate_binds(int(cf.get_value("meta", "binds_version", 1)))
		_migrate_addons()
		if int(values.get("max_fps", 144)) <= 0:
			values["max_fps"] = 500  # the old "Unlimited"; the FPS cap is a 30-500 slider now
	_apply_binds()


## Before 0.21.0 there was one addon slot: a saved secondary addon moves to the
## secondary slot, and anything that isn't an addon any more goes back to the default.
func _migrate_addons() -> void:
	var a := str(values.addon)
	if Addons.slot_of(a) == 1:
		values["addon2"] = a
		values["addon"] = Addons.DEFAULT_PRIMARY
	if Addons.slot_of(str(values.addon)) != 0:
		values["addon"] = Addons.DEFAULT_PRIMARY
	if Addons.slot_of(str(values.addon2)) != 1:
		values["addon2"] = Addons.DEFAULT_SECONDARY


func _migrate_binds(saved_version: int) -> void:
	if saved_version >= BINDS_VERSION:
		return
	for a in ACTIONS:
		for ver: int in OLD_DEFAULT_BINDS:
			var old: Dictionary = OLD_DEFAULT_BINDS[ver]
			if ver > saved_version and old.has(a[0]) and binds[a[0]] == old[a[0]]:
				binds[a[0]] = default_bind(a[0])
	save_settings.call_deferred()


func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in values.keys():
		cf.set_value("settings", k, values[k])
	for a in binds.keys():
		cf.set_value("binds", a, binds[a])
	cf.set_value("meta", "binds_version", BINDS_VERSION)
	cf.set_value("meta", "reset_version", RESET_VERSION)
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
		binds[a[0]] = default_bind(a[0])
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


## Actions still on their default use every event from the Input Map (so extra
## keys or gamepad buttons added there keep working); rebound ones use the
## player's key or button.
func _apply_binds() -> void:
	for a in ACTIONS:
		var action: String = a[0]
		InputMap.action_erase_events(action)
		if binds[action] == _default_binds.get(action):
			for ev: InputEvent in _default_events.get(action, []):
				InputMap.action_add_event(action, ev)
		else:
			InputMap.action_add_event(action, make_event(binds[action]))


func make_event(b: Array) -> InputEvent:
	if b[0] == "m":
		var m := InputEventMouseButton.new()
		m.device = -1
		m.button_index = b[1]
		return m
	var k := InputEventKey.new()
	k.device = -1
	k.physical_keycode = b[1]
	if b[1] == KEY_SHIFT:
		# Right Shift is reserved for team chat (Right Shift + Enter), so a Shift
		# bind only means Left Shift.
		k.location = KEY_LOCATION_LEFT
	return k


func bind_text(action: String) -> String:
	var b: Array = binds.get(action, ["k", 0])
	if b[0] == "m":
		return MOUSE_NAMES.get(b[1], "Mouse %d" % b[1])
	if b[1] == KEY_SHIFT:
		return "Left Shift"
	return OS.get_keycode_string(b[1])


func apply_all() -> void:
	if DisplayServer.get_name() != "headless":
		var fs: bool = g("fullscreen")
		if _last_fullscreen != fs:
			_last_fullscreen = fs
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fs else DisplayServer.WINDOW_MODE_WINDOWED)
		# Only when it changes: setting it rebuilds the swap chain (a hitch on every slider step).
		var vs := DisplayServer.VSYNC_ENABLED if g("vsync") else DisplayServer.VSYNC_DISABLED
		if DisplayServer.window_get_vsync_mode() != vs:
			DisplayServer.window_set_vsync_mode(vs)
	# 30-500 (Settings > Video slider). Old saves with 0 (unlimited) get 500.
	var fps := int(g("max_fps"))
	Engine.max_fps = clampi(fps if fps > 0 else 500, 30, 500)
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
