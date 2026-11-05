class_name Weapons
## Weapon definitions. All guns are hitscan.
## Spread values are cone half-angles in degrees (hip / aimed).

const ORDER := ["ar", "smg", "shotgun", "sniper", "bat"]

const DATA := {
	"ar": {
		"name": "Assault Rifle",
		"desc": "20 / 25 head dmg (less past 25m): 5 body shots or 4 headshots. 9.5 rounds/s, 20 rounds. Best at mid range.",
		"body": 20.0, "head": 25.0, "falloff": 25.0, "body_far": 15.0, "head_far": 20.0, "rps": 9.5, "zoom": 1.5,
		"mag": 20, "reload": 2.1, "hip": 2.0, "ads": 0.25, "range": 300.0, "kick": 0.55,
	},
	"smg": {
		"name": "SMG",
		"desc": "17 / 21 head dmg (less past 25m): 6 body shots or 5 headshots. 14 rounds/s. Matches the AR up to mid range.",
		# Kill times match the AR up to 25 m (6 shots at 14/s vs the AR's 5 at 9.5/s);
		# past that it takes twelve body shots, and its wider aim and shorter range hurt more.
		"body": 17.0, "head": 21.0, "falloff": 25.0, "body_far": 9.0, "head_far": 12.0, "rps": 14.0, "zoom": 1.2,
		"mag": 40, "reload": 1.8, "hip": 1.7, "ads": 0.9, "range": 200.0, "kick": 0.35,
	},
	"shotgun": {
		"name": "Shotgun",
		"desc": "13 pellets, 15 dmg each up close (less past 10m). 1 shot/s.",
		"pellets": 13, "cone": 12.0, "rps": 1.0, "zoom": 1.15,
		"mag": 6, "reload": 2.6, "hip": 0.0, "ads": 0.0, "range": 120.0, "kick": 2.5,
	},
	"sniper": {
		"name": "Sniper",
		"desc": "100 dmg, headshots kill. Pierces a wall and every player in line. One round: it reloads after every shot.",
		# One round, so every shot is followed by a reload (2.5 s, the same pace as
		# its 0.4 shots/s, which only matters for the host's hit-rate check).
		"dmg": 100.0, "dmg_low": 90.0, "dmg_head": 150.0, "rps": 0.4, "zoom": 2.5,
		"mag": 1, "reload": 2.5, "hip": 4.0, "ads": 0.0, "range": 400.0, "kick": 3.5,
	},
	"bat": {
		"name": "Spiked Bat",
		"desc": "35 dmg, more the faster you're moving. 150 HP, +10% speed. Kills launch the victim's gun.",
		"dmg": 35.0, "rps": 2.25, "zoom": 1.0, "reach": 7.0,
		"mag": 0, "reload": 0.0, "hip": 0.0, "ads": 0.0, "range": 7.0, "kick": 0.0,
	},
}

const MAX_DAMAGE := {
	"ar": 25.0, "smg": 21.0, "shotgun": 195.0, "sniper": 150.0, "bat": 300.0, "thrown": 70.0,
}
# Spiked Bat momentum damage: 35 at or below your sprint speed, multiplied by 1.1
# for every m/s above it (compounding), capped at BAT_MAX_DAMAGE.
const BAT_SPEED_FACTOR := 1.1
const BAT_MAX_DAMAGE := 300.0
const BAT_SPEED_SLACK := 2.5  # server: extra m/s allowed over the attacker's last known speed

const THROWN_DAMAGE := 70.0
const BAT_SPEED_MULT := 1.10
const BAT_MAX_HP := 150.0
const DEFAULT_MAX_HP := 100.0


static func max_hp(weapon_id: String) -> float:
	return BAT_MAX_HP if weapon_id == "bat" else DEFAULT_MAX_HP


static func bat_damage(speed: float, sprint_speed: float) -> float:
	var over := maxf(0.0, speed - sprint_speed)
	return minf(float(DATA.bat.dmg) * pow(BAT_SPEED_FACTOR, over), BAT_MAX_DAMAGE)


static func display_name(id: String) -> String:
	if id == "thrown":
		return "Thrown Gun"
	if id == "suicide":
		return "Suicide"
	return DATA.get(id, {}).get("name", id)


static func shotgun_pellet_damage(dist: float) -> float:
	if dist <= 10.0:
		return 15.0
	if dist <= 15.0:
		return 10.5
	return 6.0
