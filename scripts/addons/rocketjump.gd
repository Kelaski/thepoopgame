class_name RocketJumpAddon
extends Addon

## How high your next jump lifts you.
@export var height := 8.0
@export var cd := 10.0


func describe() -> String:
	return "Your next jump launches you %.0fm up. %.0fs cooldown." % [height, cd]


func use(p) -> void:
	if not p.rocket_armed:
		p.rocket_armed = true
		Sfx.play("addon", -4.0, 1.5)


func status(p, _slot: int) -> Array:
	return ["ROCKET: JUMP!", 1.0, "active"] if p.rocket_armed else []
