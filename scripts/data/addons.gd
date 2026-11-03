class_name Addons
## Movement addon definitions (one per player, swappable while dead).

const ORDER := ["hider", "trackstar", "skywalker", "stalker", "phantom"]

const DATA := {
	"hider": {
		"name": "Hider",
		"desc": "F: 15s of invisibility. Fully invisible while still or crouch-walking, 10% visible while moving. Ends early if you fire. 12s cooldown after it ends.",
		"active": true,
	},
	"trackstar": {
		"name": "Trackstar",
		"desc": "Passive +15% move speed. F: +35% for 6s. 30s cooldown from activation.",
		"active": true,
	},
	"skywalker": {
		"name": "Skywalker",
		"desc": "Passive double jump: extra height while keeping your current momentum. Recharges when you land.",
		"active": false,
	},
	"stalker": {
		"name": "Stalker",
		"desc": "Passive: see red trails behind every enemy that fade 15m behind them. Walls and floors hide them. All trails look the same.",
		"active": false,
	},
	"phantom": {
		"name": "Phantom",
		"desc": "F: phase for 2s. Run through walls and doors; double-tap crouch to drop through floors. 23s cooldown.",
		"active": true,
	},
}

const HIDER_TIME := 15.0
const HIDER_CD := 12.0
const TRACK_PASSIVE := 1.15
const TRACK_ACTIVE := 1.35
const TRACK_TIME := 6.0
const TRACK_CD := 30.0
const PHANTOM_TIME := 2.0
const PHANTOM_CD := 23.0
const STALKER_TRAIL := 15.0
const SKYWALKER_CD := 5.0


static func display_name(id: String) -> String:
	return DATA.get(id, {}).get("name", id)
