class_name BatStats
extends WeaponStats

## Base damage of a hit.
@export var dmg := 0.0
## Swing reach, in metres.
@export var reach := 0.0
## Damage is multiplied by this for every m/s above your sprint speed.
@export var speed_factor := 1.0
## Host: extra m/s allowed over the attacker's last known speed.
@export var speed_slack := 0.0
## Damage of the gun launched by a bat kill.
@export var thrown_damage := 0.0
