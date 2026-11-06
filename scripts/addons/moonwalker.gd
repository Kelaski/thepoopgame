class_name MoonwalkerAddon
extends Addon

## Gravity multiplier.
@export var gravity := 0.7
## Air control multiplier.
@export var air := 1.2


func describe() -> String:
	return "%.0f%% less gravity, %.0f%% more air control." % [(1.0 - gravity) * 100.0, (air - 1.0) * 100.0]


func gravity_mult() -> float:
	return gravity


func air_accel_mult() -> float:
	return air


func air_strafe_mult() -> float:
	return air
