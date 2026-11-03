class_name Weapons
## Weapon definitions. All guns are hitscan.
## Spread values are cone half-angles in degrees (hip / aimed).

const ORDER := ["ar", "smg", "shotgun", "sniper", "bat"]

const DATA := {
	"ar": {
		"name": "Assault Rifle",
		"desc": "33 body / 45 head. 9.5 rounds/s. 1.5x holo sight.",
		"body": 33.0, "head": 45.0, "rps": 9.5, "zoom": 1.5,
		"mag": 30, "reload": 2.1, "hip": 2.0, "ads": 0.25, "range": 300.0, "kick": 0.55,
	},
	"smg": {
		"name": "SMG",
		"desc": "19 body / 26 head. 13 rounds/s. 1.2x holo sight.",
		"body": 19.0, "head": 26.0, "rps": 13.0, "zoom": 1.2,
		"mag": 40, "reload": 1.8, "hip": 2.6, "ads": 0.9, "range": 200.0, "kick": 0.35,
	},
	"shotgun": {
		"name": "Shotgun",
		"desc": "13 pellets in a 12 degree cone. 15 dmg each <10m, 10.5 <15m, 6 beyond. 1.25 shots/s. 1.15x irons.",
		"pellets": 13, "cone": 12.0, "rps": 1.25, "zoom": 1.15,
		"mag": 6, "reload": 2.6, "hip": 0.0, "ads": 0.0, "range": 120.0, "kick": 2.5,
	},
	"sniper": {
		"name": "Sniper",
		"desc": "100 dmg at any range. Pierces 1 wall and every player in line. 0.4 shots/s. 2.5x scope.",
		"dmg": 100.0, "rps": 0.4, "zoom": 2.5,
		"mag": 5, "reload": 2.8, "hip": 4.0, "ads": 0.0, "range": 400.0, "kick": 3.5,
	},
	"bat": {
		"name": "Spiked Bat",
		"desc": "45 dmg per swing, 2.25 swings/s, 7m reach. +10% move speed. A killing swing launches the victim's gun (70 dmg).",
		"dmg": 45.0, "rps": 2.25, "zoom": 1.0, "reach": 7.0,
		"mag": 0, "reload": 0.0, "hip": 0.0, "ads": 0.0, "range": 7.0, "kick": 0.0,
	},
}

const MAX_DAMAGE := {
	"ar": 45.0, "smg": 26.0, "shotgun": 195.0, "sniper": 100.0, "bat": 45.0, "thrown": 70.0,
}

const THROWN_DAMAGE := 70.0
const BAT_SPEED_MULT := 1.10


static func display_name(id: String) -> String:
	if id == "thrown":
		return "Thrown Gun"
	return DATA.get(id, {}).get("name", id)


static func shotgun_pellet_damage(dist: float) -> float:
	if dist <= 10.0:
		return 15.0
	if dist <= 15.0:
		return 10.5
	return 6.0
