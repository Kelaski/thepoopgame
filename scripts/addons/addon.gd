class_name Addon
extends Resource
## One addon: its numbers and what it does. Each has a script here in scripts/addons/ and a
## file in assets/tuning/addons/ to edit in Godot's Inspector. Timers and speeds are in
## seconds, metres and m/s. p is the Player using the addon, and slot is which of the
## player's two addon slots it's in. An addon only writes the parts below it needs.

@export var display_name := ""


## Text for the loadout screen, built from the numbers.
func describe() -> String:
	return ""


# ---- Active addons

## The key was pressed while it's off cooldown.
func use(_p) -> void:
	pass


## The key was pressed while it's running: true if that switched it off.
func switch_off(_p) -> bool:
	return false


## Runs every physics tick. By default the timers simply count down.
func tick(p, slot: int, delta: float) -> void:
	p.addon_active[slot] = maxf(0.0, p.addon_active[slot] - delta)
	p.addon_cd[slot] = maxf(0.0, p.addon_cd[slot] - delta)


## [label, fraction 0..1, state] for the HUD bar while running, or [] for the usual cooldown and ready bar.
func status(_p, _slot: int) -> Array:
	return []


# ---- Passive addons

func speed_mult(_p) -> float:
	return 1.0


func gravity_mult() -> float:
	return 1.0


## Air control below running speed (steering with A and D).
func air_accel_mult() -> float:
	return 1.0


## Air strafing while turning the camera.
func air_strafe_mult() -> float:
	return 1.0


func speed_cap_bonus() -> float:
	return 0.0


func extra_wall_jumps() -> int:
	return 0


## Reload time multiplier for a weapon.
func reload_mult(_p, _weapon: String) -> float:
	return 1.0


## Re-chamber time multiplier for a weapon.
func rechamber_mult(_weapon: String) -> float:
	return 1.0


func on_kill(_p) -> void:
	pass


func bonus_hp() -> float:
	return 0.0


func head_mult() -> float:
	return 1.0


func blast_mult() -> float:
	return 1.0


## Host: seconds added to the wait before health regen, after this many kills.
func regen_delay(_kills: int) -> float:
	return 0.0
