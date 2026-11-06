class_name CooldownKillAddon
extends Addon

## Taken off your active addon's cooldown per kill.
@export var per_kill := 5.0


func describe() -> String:
	return "Kills take %.0fs off your active cooldown." % per_kill


func on_kill(p) -> void:
	p.addon_cd[p.ACTIVE_SLOT] = maxf(0.0, p.addon_cd[p.ACTIVE_SLOT] - per_kill)
