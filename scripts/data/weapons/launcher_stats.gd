class_name LauncherStats
extends WeaponStats

## Damage of the blast.
@export var dmg := 0.0
## Speed (m/s) of a grenade fired while standing still.
@export var launch_speed := 0.0
## Added launch speed for each m/s the shooter is moving (1 = all of it).
@export var shooter_speed_scale := 0.0
## Grenade gravity (m/s^2). It doesn't change with launch speed.
@export var grenade_gravity := 0.0
## An enemy this close (m) to the grenade sets it off.
@export var proximity_radius := 0.0
## Players within this distance (m) of the blast are hit and launched.
@export var blast_radius := 0.0
## Speed (m/s) a blast launches a player away from its centre.
@export var knockback_speed := 0.0
## Extra upward speed (m/s) from a blast.
@export var knockback_lift := 0.0
## A grenade that hits nothing explodes after this many seconds.
@export var max_life := 0.0
