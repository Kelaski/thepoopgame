class_name AerodynamicAddon
extends Addon

## Multiplier on steering with A and D below running speed.
@export var air := 1.6
## Multiplier on air strafing while turning the camera.
@export var strafe := 1.6


func describe() -> String:
	return "Much more air control."


func air_accel_mult() -> float:
	return air


func air_strafe_mult() -> float:
	return strafe
