class_name TrackstarAddon
extends Addon

## Move speed multiplier (1.25 = 25% faster).
@export var speed := 1.25
## Reload and re-chamber time multiplier (0.65 = 35% faster).
@export var reload := 0.65
## The same, for the sniper.
@export var sniper_reload := 0.7


func describe() -> String:
	return "+%.0f%% move speed, faster reloads." % ((speed - 1.0) * 100.0)


func speed_mult(_p) -> float:
	return speed


func reload_mult(_p, weapon: String) -> float:
	return rechamber_mult(weapon)


func rechamber_mult(weapon: String) -> float:
	return sniper_reload if weapon == "sniper" else reload
