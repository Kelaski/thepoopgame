class_name KillstreakAddon
extends Addon

## Added to your speed per kill (0.04 = 4%).
@export var speed := 0.04
## Taken off your reload time per kill (0.05 = 5%).
@export var reload := 0.05
## Added to the delay before health regen per kill.
@export var regen_delay_per_kill := 1.0
## Kills past this many add nothing.
@export var max_stacks := 5


func describe() -> String:
	return "Kills give speed and faster reloads, but slower health regen. Resets on death."


func speed_mult(p) -> float:
	return 1.0 + p._streak * speed


func reload_mult(p, _weapon: String) -> float:
	return maxf(0.1, 1.0 - p._streak * reload)


func on_kill(p) -> void:
	p._streak = mini(p._streak + 1, max_stacks)


func regen_delay(kills: int) -> float:
	return kills * regen_delay_per_kill


func status(p, _slot: int) -> Array:
	return ["STREAK x%d" % p._streak, float(p._streak) / max_stacks, "passive"]
