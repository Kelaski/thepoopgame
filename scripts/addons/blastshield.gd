class_name BlastShieldAddon
extends Addon

## Explosive damage multiplier (0.5 = half).
@export var mult := 0.5


func describe() -> String:
	return "%.0f%% less explosive damage." % ((1.0 - mult) * 100.0)


func blast_mult() -> float:
	return mult
