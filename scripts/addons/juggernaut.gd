class_name JuggernautAddon
extends Addon

@export var hp := 25.0


func describe() -> String:
	return "+%.0f max health." % hp


func bonus_hp() -> float:
	return hp
