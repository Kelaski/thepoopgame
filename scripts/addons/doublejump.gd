class_name DoubleJumpAddon
extends Addon

## Upward speed of the second jump.
@export var speed := 7.0


func describe() -> String:
	return "Jump again in the air, turning your speed the way you look."


func status(p, _slot: int) -> Array:
	return ["DOUBLE JUMP READY" if p.dj_ready else "LAND TO RECHARGE", 1.0 if p.dj_ready else 0.0, "passive"]
