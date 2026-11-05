class_name Addons
## Addon definitions. Every player picks one Active addon (used with the Use Addon
## key, E by default) and one Passive addon (no key). Swappable while dead.
## All the numbers live in assets/tuning/addons.tres (edit them in the Inspector).

const T: AddonTuning = preload("res://assets/tuning/addons.tres")

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

const NAMES := {
	"grapple": "Grapple", "warp": "Warp", "rocketjump": "Rocket Jump",
	"hider": "Hider", "phantom": "Phantom", "bubble": "Bubble",
	"uav": "UAV", "magnet": "Magnet", "interlink": "Interlink",
	"moonwalker": "Moonwalker", "trackstar": "Trackstar", "doublejump": "Double Jump",
	"wallhugger": "Wallhugger", "aerodynamic": "Aerodynamic", "unstoppable": "Unstoppable",
	"reloader": "Reload on Kill", "cooldownkill": "Cooldown on Kill", "juggernaut": "Juggernaut",
	"sharpshooter": "Sharpshooter", "killstreak": "Killstreak", "blastshield": "Blast Shield",
}

# Old saved ids that became a new addon.
const RENAMED := {"skywalker": "doublejump", "parry": "bubble"}

const RECHAMBER_WEAPONS := ["shotgun", "sniper", "gl"]


## Text for the loadout screen, built from the tuned numbers.
static func describe(id: String) -> String:
	match id:
		"grapple":
			return "Hold to grapple (%.0fm) and swing. Hooking an enemy pulls them in. %.1fs cooldown." % [T.grapple_range, T.grapple_cd]
		"warp":
			return "Blink %.0fm the way you're looking, keeping all your speed that way. Leaves a blue afterimage for %.0fs. %.0fs cooldown." % [T.warp_dist, T.warp_afterimage_time, T.warp_cd]
		"rocketjump":
			return "Your next jump rockets you %.0fm up. %.0fs cooldown." % [T.rocket_height, T.rocket_cd]
		"hider":
			return "%.0fs nearly invisible: %.0f%% visible moving, %.0f%% still or crouched. A Tag you carry fades too. Firing ends it. %.0fs cooldown." % [T.hider_time, T.hider_moving_opacity * 100.0, T.hider_still_opacity * 100.0, T.hider_cd]
		"phantom":
			return "Phase through walls for %.0fs. Press again to end it early. If it ends inside something you take %.0f damage/s, doubling every second until you're out. %.0fs cooldown." % [T.phantom_time, T.phantom_stuck_dps, T.phantom_cd]
		"bubble":
			return "A %.0fs, %.0f HP shield. Nothing can push you while it's up. %.0fs cooldown." % [T.bubble_time, T.bubble_health, T.bubble_cd]
		"uav":
			return "Support. %d pulses reveal enemies to your team, through walls and on the minimap, where the pulse reached them. %.0fs cooldown (runs only while alive, kept through death)." % [T.uav_pulses, T.uav_cd]
		"magnet":
			return "Support. Aim at a teammate in sight to pull them to you. %.0fs cooldown (runs only while alive, kept through death)." % T.magnet_cd
		"interlink":
			return "Support. Aim at a teammate to link. Within %.0fm you share all damage and healing, even death (%.0fs respawn). Press again to break it. %.0fs cooldown (runs only while alive, kept through death)." % [T.interlink_range, T.interlink_respawn_time, T.interlink_cd]
		"moonwalker":
			return "%.0f%% less gravity and %.0f%% more air control." % [(1.0 - T.moon_gravity) * 100.0, (T.moon_air - 1.0) * 100.0]
		"trackstar":
			return "+%.0f%% move speed and faster reloads." % ((T.track_speed - 1.0) * 100.0)
		"doublejump":
			return "Jump again in the air. All your speed turns the way you're looking. Recharges when you land."
		"wallhugger":
			return "%d more wall jumps before gravity starts pulling harder." % T.wallhugger_extra_jumps
		"aerodynamic":
			return "Much more air control, with both the camera and A / D."
		"unstoppable":
			return "Speed cap raised by %.0f m/s." % T.unstoppable_cap_bonus
		"reloader":
			return "A kill reloads your weapon and cancels any reload or re-chamber, so you can fire right away. Then %.0fs until it can work again." % T.reloader_cd
		"cooldownkill":
			return "A kill takes %.0fs off your active addon's cooldown." % T.cooldown_per_kill
		"juggernaut":
			return "+%.0f max health." % T.juggernaut_hp
		"sharpshooter":
			return "Headshots do %.1fx damage." % T.sharpshooter_mult
		"killstreak":
			return "Each kill until you die: +%.0f%% speed and %.0f%% faster reloads, but health regen starts %.0fs later. Up to %d kills." % [T.streak_speed * 100.0, T.streak_reload * 100.0, T.streak_regen_delay, T.streak_max_stacks]
		"blastshield":
			return "Explosive damage is cut by %.0f%%." % ((1.0 - T.blast_shield_mult) * 100.0)
	return ""


## Trackstar's time multiplier for reloading / re-chambering with weapon.
static func track_mult(weapon: String) -> float:
	return T.track_sniper_mult if weapon == "sniper" else T.track_reload_mult


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
	return NAMES.get(id, id)
