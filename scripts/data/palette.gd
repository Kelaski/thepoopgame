class_name Palette
## Every customizable colour in the game, grouped for the Customize Colours menu.
## Overrides are stored in Settings ("colors": key -> html colour). Anything not
## overridden uses the default listed here.

# [key, label, default, group]
const SLOTS := [
	["ui_accent", "Accent / highlights", Color("ffd23f"), "Menus"],
	["ui_panel", "Panel background", Color(0.08, 0.09, 0.11, 0.93), "Menus"],
	["ui_panel_soft", "Tab / inner panel", Color(0.12, 0.13, 0.16, 0.95), "Menus"],
	["ui_button", "Button", Color("2b2f38"), "Menus"],
	["ui_button_hover", "Button (hover)", Color("3b414e"), "Menus"],
	["ui_text", "Text", Color("f2efe8"), "Menus"],
	["ui_muted", "Secondary text", Color("a9a59c"), "Menus"],
	["ui_menu_bg", "Menu backdrop", Color("1b2430"), "Menus"],
	["team_red", "Red team", Color("c0453a"), "Teams & Tag"],
	["team_blue", "Blue team", Color("4f7fae"), "Teams & Tag"],
	["tag", "The Tag / Runner", Color("ffd23f"), "Teams & Tag"],
	["sky_top", "Sky (top)", Color("5b8fd0"), "World"],
	["sky_horizon", "Sky (horizon) / fog", Color("cfe3f2"), "World"],
	["sun", "Sunlight", Color("fff1dc"), "World"],
	["world_ground", "Sidewalks / ground", Color("b9b4a6"), "World"],
	["world_road", "Roads", Color("3c3d42"), "World"],
	["world_lines", "Road lines", Color("e8c84a"), "World"],
	["world_grass", "Park grass", Color("6aa84f"), "World"],
	["world_outside", "Outside the fence", Color("7f9a5a"), "World"],
]

# Parts of each building style that can be recoloured (see MapBuilder.STYLES).
const BUILDING_PARTS := ["wall", "roof", "floor", "trim"]

const PRESETS := {
	"Default": {},
	"Midnight": {
		"ui_accent": "9d7bff", "ui_panel": "0d0b1aee", "ui_panel_soft": "17142af2", "ui_button": "241f3d",
		"ui_button_hover": "342c57", "ui_menu_bg": "0b0916", "sky_top": "101a3a", "sky_horizon": "3a3f6a",
		"sun": "9fb0ff", "world_ground": "6f6c78", "world_grass": "2f5a3a", "world_outside": "263a2c",
	},
	"Neon": {
		"ui_accent": "39ffd0", "ui_panel": "0a0f14ee", "ui_button": "102029", "ui_button_hover": "17414d",
		"ui_menu_bg": "05080c", "team_red": "ff2d7a", "team_blue": "2de2ff", "tag": "f6ff3a",
		"sky_top": "1b0b3a", "sky_horizon": "ff4fd8", "world_lines": "39ffd0", "world_road": "15151c",
	},
	"Pastel": {
		"ui_accent": "ff9ec7", "ui_panel": "3b3550ee", "ui_button": "534a6e", "ui_button_hover": "6c608f",
		"ui_menu_bg": "2e2940", "team_red": "f28b82", "team_blue": "8ab4f8", "tag": "fff59d",
		"sky_top": "a7c7ff", "sky_horizon": "ffe1f0", "world_ground": "e6ddd0", "world_grass": "a8d5a2",
	},
	"Desert": {
		"ui_accent": "f2a541", "ui_menu_bg": "3a2a1c", "sky_top": "6aa6d8", "sky_horizon": "f4dcb0",
		"sun": "ffe0a8", "world_ground": "d8bf8a", "world_grass": "a7a052", "world_outside": "c9a66b",
	},
}


static func default_of(key: String) -> Color:
	for s in SLOTS:
		if s[0] == key:
			return s[2]
	if key.begins_with("bld_"):
		var parts := key.split("_")
		# bld_<type>_<part>; type may itself contain no underscores
		var type := key.substr(4, key.length() - 5 - parts[parts.size() - 1].length())
		var part: String = parts[parts.size() - 1]
		if MapBuilder.STYLES.has(type):
			return MapBuilder.STYLES[type].get(part, Color.WHITE)
	return Color.WHITE


static func get_color(key: String) -> Color:
	return Settings.color(key, default_of(key))


static func building_key(type: String, part: String) -> String:
	return "bld_%s_%s" % [type, part]
