class_name SharpshooterAddon
extends Addon

## Headshot damage multiplier.
@export var mult := 1.2


func describe() -> String:
	return "Headshots do %.1fx damage." % mult


func head_mult() -> float:
	return mult
