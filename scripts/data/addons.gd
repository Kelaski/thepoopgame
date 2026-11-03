class_name Addons
## Movement addon definitions (one per player, swappable while dead).
## "Ability key" is Use Addon (Left Shift by default).

const ORDER := ["hider", "trackstar", "skywalker", "stalker", "phantom", "grapple"]

const DATA := {
	"hider": {
		"name": "Hider",
		"desc": "Ability key: 15s of invisibility. Fully invisible while still or crouch-walking, 10% visible while moving. Ends early if you fire. 12s cooldown after it ends.",
		"active": true,
	},
	"trackstar": {
		"name": "Trackstar",
		"desc": "Passive +15% move speed. Ability key: +35% for 6s. 30s cooldown from activation.",
		"active": true,
	},
	"skywalker": {
		"name": "Skywalker",
		"desc": "Passive double jump: extra height while keeping your current momentum. Recharges when you land.",
		"active": false,
	},
	"stalker": {
		"name": "Stalker",
		"desc": "Passive: see wide red trails behind every enemy that linger for 6s. Walls and floors hide them. All trails look the same.",
		"active": false,
	},
	"phantom": {
		"name": "Phantom",
		"desc": "Ability key: phase for 2s. Run through walls and doors; double-tap crouch to drop through floors. 23s cooldown.",
		"active": true,
	},
	"grapple": {
		"name": "Grapple",
		"desc": "Ability key: fire a grappling hook (20m range) that latches onto whatever it hits and pulls you to it. Jump lets go. 17s cooldown from a hit; a miss only costs 1s.",
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
const STALKER_TRAIL_TIME := 6.0  # seconds each piece of trail lingers
const SKYWALKER_CD := 5.0
const GRAPPLE_RANGE := 20.0
const GRAPPLE_CD := 17.0
const GRAPPLE_MISS_CD := 1.0
const GRAPPLE_SPEED := 20.0      # pull speed (m/s)
const GRAPPLE_ACCEL := 70.0      # how quickly you reach the pull speed
const GRAPPLE_MAX_TIME := 1.6    # the hook lets go after this long
const GRAPPLE_ARRIVE := 1.6      # lets go within this distance of the hook


static func display_name(id: String) -> String:
	return DATA.get(id, {}).get("name", id)
