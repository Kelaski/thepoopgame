class_name UnstoppableAddon
extends Addon

## Added to the speed cap.
@export var cap_bonus := 10.0


func describe() -> String:
	return "+%.0f m/s speed cap." % cap_bonus


func speed_cap_bonus() -> float:
	return cap_bonus
