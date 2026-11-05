class_name Weapons
## Weapon definitions. All guns but the grenade launcher are hitscan. The numbers
## live in assets/tuning/weapons/*.tres (edit them in the Inspector).

const ORDER := ["ar", "shotgun", "sniper", "gl", "bat"]

const DATA := {
	"ar": preload("res://assets/tuning/weapons/ar.tres"),
	"shotgun": preload("res://assets/tuning/weapons/shotgun.tres"),
	"sniper": preload("res://assets/tuning/weapons/sniper.tres"),
	"gl": preload("res://assets/tuning/weapons/grenade_launcher.tres"),
	"bat": preload("res://assets/tuning/weapons/bat.tres"),
}

const DEFAULT_MAX_HP := 100.0  # before a player has a weapon


## Text for the loadout screen, built from the tuned numbers.
static func describe(id: String) -> String:
	var w: WeaponStats = DATA.get(id)
	if w == null:
		return ""
	match id:
		"ar":
			return "%.0f / %.0f head dmg (less past %.0fm). %.1f rounds/s, %d rounds. Best at mid range." % [w.body, w.head, w.falloff, w.rps, w.mag]
		"shotgun":
			return "%d pellets, %.0f dmg each up close. %.1f shots/s. Loads %.1fs per shell; firing stops the reload." % [w.pellets, w.pellet_near, w.rps, w.reload_per_round]
		"sniper":
			return "%.0f dmg, headshots kill. Pierces a wall and every player in line. One round: it reloads after every shot." % w.dmg
		"gl":
			return "%d rounds, %.1fs between shots, %.1fs per shell. Arcing grenades do %.0f dmg and launch anyone nearby. The faster you move, the further they fly. They never hurt you or your team." % [w.mag, 1.0 / w.rps, w.reload_per_round, w.dmg]
		"bat":
			return "%.0f dmg, more the faster you're moving. %.0f HP, +%.0f%% speed. Kills launch the victim's gun." % [w.dmg, w.max_hp, (w.speed_mult - 1.0) * 100.0]
	return ""


## The most damage the host accepts from one shot.
static func max_damage(id: String) -> float:
	if id == "thrown":
		return DATA.bat.thrown_damage
	return DATA[id].max_damage if DATA.has(id) else 50.0


static func max_hp(weapon_id: String) -> float:
	return DATA[weapon_id].max_hp if DATA.has(weapon_id) else DEFAULT_MAX_HP


## Bat momentum: base damage, compounding for every m/s above your sprint speed, up to its cap.
static func bat_damage(speed: float, sprint_speed: float) -> float:
	var over := maxf(0.0, speed - sprint_speed)
	return minf(DATA.bat.dmg * pow(DATA.bat.speed_factor, over), DATA.bat.max_damage)


static func display_name(id: String) -> String:
	match id:
		"thrown": return "Thrown Gun"
		"suicide": return "Suicide"
		"stuck": return "Stuck in a Wall"
	return DATA[id].name if DATA.has(id) else id


static func shotgun_pellet_damage(dist: float) -> float:
	var w: WeaponStats = DATA.shotgun
	if dist <= w.pellet_near_dist:
		return w.pellet_near
	return w.pellet_mid if dist <= w.pellet_mid_dist else w.pellet_far


## How fast a grenade leaves the launcher when the shooter moves at shooter_speed.
static func grenade_speed(shooter_speed: float) -> float:
	return DATA.gl.launch_speed + shooter_speed * DATA.gl.shooter_speed_scale
