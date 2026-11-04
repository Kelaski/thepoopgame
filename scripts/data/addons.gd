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
		"desc": "Passive +15% move speed, and reloads (and the shotgun re-chambering between shots) are 35% faster; 30% faster with the sniper. Ability key: +35% for 6s. 24s cooldown from activation.",
		"active": true,
	},
	"skywalker": {
		"name": "Skywalker",
		"desc": "Passive double jump: extra height while keeping your current momentum. Recharges when you land.",
		"active": false,
	},
	"stalker": {
		"name": "Stalker",
		"desc": "Passive: see wide red trails behind every enemy that linger for 6s. Walls and floors hide them. Ability key: see the outline of every player through walls for 4s. 14s cooldown from activation.",
		"active": true,
	},
	"phantom": {
		"name": "Phantom",
		"desc": "Ability key: phase for 2s. Run through walls and doors; double-tap crouch to drop through floors. 23s cooldown.",
		"active": true,
	},
	"grapple": {
		"name": "Grapple",
		"desc": "Hold the ability key: throw a grappling hook (27m range, up to 20 m/s). It latches onto whatever it hits and reels you in while you steer: hook something above you to swing, and get a pop up at the end to climb ledges. Release the key (or jump) to let go with your momentum. Hooking an enemy yanks them towards you. 6.5s cooldown from a hit; a miss only costs 1s.",
		"active": true,
	},
}

const HIDER_TIME := 15.0
const HIDER_CD := 12.0
const TRACK_PASSIVE := 1.15
const TRACK_ACTIVE := 1.35
const TRACK_TIME := 6.0
const TRACK_CD := 24.0
# Trackstar's reloads and the shotgun / sniper re-chambering between shots are
# faster: these are time multipliers (0.65 = 35% faster). The bat never reloads.
const TRACK_RELOAD_MULT := 0.65
const TRACK_SNIPER_MULT := 0.70
const RECHAMBER_WEAPONS := ["shotgun", "sniper"]
const PHANTOM_TIME := 2.0
const PHANTOM_CD := 23.0
const STALKER_TRAIL_TIME := 6.0  # seconds each piece of trail lingers
const STALKER_SCAN_TIME := 4.0   # ability: every player's outline shows through walls for this long
const STALKER_SCAN_CD := 14.0    # ...and it's ready again this long after activation
const SKYWALKER_CD := 5.0
const GRAPPLE_RANGE := 27.0
const GRAPPLE_CD := 6.5          # starts when the hook latches on
const GRAPPLE_MISS_CD := 1.0
const GRAPPLE_HOOK_SPEED := 110.0  # thrown hook speed (m/s): ~0.27 s to full range
const GRAPPLE_PULL := 42.0       # reel-in acceleration (m/s^2)
const GRAPPLE_STEER := 14.0      # air steering while on the rope (m/s^2)
const GRAPPLE_MAX_SPEED := 20.0  # the most speed the grapple can give you (m/s)
const GRAPPLE_MAX_TIME := 2.5    # the rope lets go after this long
const GRAPPLE_ARRIVE := 2.0      # within this distance you pop off the end
const GRAPPLE_END_POP := 6.5     # upward speed at the end, to clear ledges
const GRAPPLE_YANK := 11.0       # speed a hooked enemy is pulled towards you


## Trackstar's time multiplier for reloading / re-chambering with weapon.
static func track_mult(weapon: String) -> float:
	return TRACK_SNIPER_MULT if weapon == "sniper" else TRACK_RELOAD_MULT


static func display_name(id: String) -> String:
	return DATA.get(id, {}).get("name", id)
