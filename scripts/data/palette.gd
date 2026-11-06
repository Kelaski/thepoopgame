class_name Palette
## Every customizable colour in the game, grouped for the Colours tab in Settings.
## Overrides are stored in Settings ("colors": key -> html colour). Anything not
## overridden uses the default listed here.

# [key, label, default, group]
const SLOTS := [
	["ui_accent", "Accent / highlights", Color("ffd23f"), "Menus"],
	["ui_panel", "Panel background", Color(0.055, 0.06, 0.075, 0.92), "Menus"],
	["ui_panel_soft", "Tab / inner panel", Color(0.12, 0.13, 0.16, 0.95), "Menus"],
	["ui_button", "Button", Color(1, 1, 1, 0.06), "Menus"],
	["ui_button_hover", "Button (hover)", Color("bf9d2f"), "Menus"],
	["ui_text", "Text", Color("f2efe8"), "Menus"],
	["ui_muted", "Secondary text", Color("a9a59c"), "Menus"],
	["ui_menu_bg", "Menu backdrop", Color(0.04, 0.045, 0.06), "Menus"],
	["team_red", "Red team", Color("c0453a"), "Teams & Tag"],
	["team_blue", "Blue team", Color("4f7fae"), "Teams & Tag"],
	["tag", "The Tag / Runner", Color("ffd23f"), "Teams & Tag"],
]

const PRESETS := {
	"Default": {},
	"Midnight": {
		"ui_accent": "9d7bff", "ui_panel": "0d0b1aee", "ui_panel_soft": "17142af2", "ui_button": "241f3d",
		"ui_button_hover": "342c57", "ui_menu_bg": "0b0916",
	},
	"Neon": {
		"ui_accent": "39ffd0", "ui_panel": "0a0f14ee", "ui_button": "102029", "ui_button_hover": "17414d",
		"ui_menu_bg": "05080c", "team_red": "ff2d7a", "team_blue": "2de2ff", "tag": "f6ff3a",
	},
	"Pastel": {
		"ui_accent": "ff9ec7", "ui_panel": "3b3550ee", "ui_button": "534a6e", "ui_button_hover": "6c608f",
		"ui_menu_bg": "2e2940", "team_red": "f28b82", "team_blue": "8ab4f8", "tag": "fff59d",
	},
	"Desert": {
		"ui_accent": "f2a541", "ui_menu_bg": "3a2a1c",
	},
}


static func default_of(key: String) -> Color:
	for s in SLOTS:
		if s[0] == key:
			return s[2]
	return Color.WHITE


static func get_color(key: String) -> Color:
	return Settings.color(key, default_of(key))
