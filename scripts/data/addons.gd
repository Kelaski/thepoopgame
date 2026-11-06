class_name Addons
## Addon definitions. Every player picks one Active addon (used with the Use Addon
## key, E by default) and one Passive addon (no key). Swappable while dead.
## Each addon is a script in scripts/addons/ and a file in assets/tuning/addons/ (edit its numbers in the Inspector).

# Loaded when the game starts and left untyped: these scripts use Player and Game, which use Addons, and Godot refuses that loop at compile time.
static var GRAPPLE = load("res://assets/tuning/addons/grapple.tres")
static var WARP = load("res://assets/tuning/addons/warp.tres")
static var ROCKETJUMP = load("res://assets/tuning/addons/rocketjump.tres")
static var HIDER = load("res://assets/tuning/addons/hider.tres")
static var PHANTOM = load("res://assets/tuning/addons/phantom.tres")
static var BUBBLE = load("res://assets/tuning/addons/bubble.tres")
static var UAV = load("res://assets/tuning/addons/uav.tres")
static var MAGNET = load("res://assets/tuning/addons/magnet.tres")
static var INTERLINK = load("res://assets/tuning/addons/interlink.tres")
static var MOONWALKER = load("res://assets/tuning/addons/moonwalker.tres")
static var TRACKSTAR = load("res://assets/tuning/addons/trackstar.tres")
static var DOUBLEJUMP = load("res://assets/tuning/addons/doublejump.tres")
static var WALLHUGGER = load("res://assets/tuning/addons/wallhugger.tres")
static var AERODYNAMIC = load("res://assets/tuning/addons/aerodynamic.tres")
static var UNSTOPPABLE = load("res://assets/tuning/addons/unstoppable.tres")
static var RELOADER = load("res://assets/tuning/addons/reloader.tres")
static var COOLDOWNKILL = load("res://assets/tuning/addons/cooldownkill.tres")
static var JUGGERNAUT = load("res://assets/tuning/addons/juggernaut.tres")
static var SHARPSHOOTER = load("res://assets/tuning/addons/sharpshooter.tres")
static var KILLSTREAK = load("res://assets/tuning/addons/killstreak.tres")
static var BLASTSHIELD = load("res://assets/tuning/addons/blastshield.tres")

static var DATA := {
	"grapple": GRAPPLE,
	"warp": WARP,
	"rocketjump": ROCKETJUMP,
	"hider": HIDER,
	"phantom": PHANTOM,
	"bubble": BUBBLE,
	"uav": UAV,
	"magnet": MAGNET,
	"interlink": INTERLINK,
	"moonwalker": MOONWALKER,
	"trackstar": TRACKSTAR,
	"doublejump": DOUBLEJUMP,
	"wallhugger": WALLHUGGER,
	"aerodynamic": AERODYNAMIC,
	"unstoppable": UNSTOPPABLE,
	"reloader": RELOADER,
	"cooldownkill": COOLDOWNKILL,
	"juggernaut": JUGGERNAUT,
	"sharpshooter": SHARPSHOOTER,
	"killstreak": KILLSTREAK,
	"blastshield": BLASTSHIELD,
}

const ACTIVE := {
	"Mobility": ["grapple", "warp", "rocketjump"],
	"Tactical": ["hider", "phantom", "bubble"],
	"Support": ["uav", "magnet", "interlink"],
}
const PASSIVE := {
	"Movement": ["moonwalker", "trackstar", "doublejump", "wallhugger", "aerodynamic", "unstoppable"],
	"Perks": ["reloader", "cooldownkill", "juggernaut", "sharpshooter", "killstreak", "blastshield"],
}
const DEFAULT_ACTIVE := "grapple"
const DEFAULT_PASSIVE := "trackstar"

# Old saved ids that became a new addon.
const RENAMED := {"skywalker": "doublejump", "parry": "bubble"}

const RECHAMBER_WEAPONS := ["shotgun", "sniper", "gl"]


static func of(id: String) -> Addon:
	return DATA.get(id)


## Text for the loadout screen.
static func describe(id: String) -> String:
	return of(id).describe() if DATA.has(id) else ""


## 0 for an active addon, 1 for a passive one, -1 if it isn't an addon.
static func slot_of(id: String) -> int:
	for sub: String in ACTIVE:
		if id in ACTIVE[sub]:
			return 0
	for sub: String in PASSIVE:
		if id in PASSIVE[sub]:
			return 1
	return -1


## Support addons' cooldowns carry on through death, and only run while alive.
static func is_support(id: String) -> bool:
	return id in ACTIVE.Support


static func display_name(id: String) -> String:
	return of(id).display_name if DATA.has(id) else id
