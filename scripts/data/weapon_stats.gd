class_name WeaponStats
extends Resource
## One weapon's numbers. Each weapon has a file in assets/tuning/weapons/: open it
## in Godot and edit the values in the Inspector. Fields a weapon doesn't use stay 0.

@export var name := ""

@export_group("Damage")
## Body damage (AR).
@export var body := 0.0
## Head damage (AR).
@export var head := 0.0
## Past this distance (m) the far damage below applies (AR).
@export var falloff := 0.0
@export var body_far := 0.0
@export var head_far := 0.0
## Damage per hit: the sniper's body shot, the bat's base hit, the grenade's blast.
@export var dmg := 0.0
## Sniper: lower-body damage.
@export var dmg_low := 0.0
## Sniper: head damage.
@export var dmg_head := 0.0
## The most damage the host accepts from one shot. Raise it if you raise the damage.
@export var max_damage := 50.0

@export_group("Shotgun pellets")
@export var pellets := 0
## Full width of the pellet cone, in degrees.
@export var cone := 0.0
## Pellet damage up to pellet_near_dist.
@export var pellet_near := 0.0
## Pellet damage up to pellet_mid_dist.
@export var pellet_mid := 0.0
## Pellet damage beyond pellet_mid_dist.
@export var pellet_far := 0.0
@export var pellet_near_dist := 0.0
@export var pellet_mid_dist := 0.0

@export_group("Firing and aim")
## Shots per second. A rate of 0.5 means 2 seconds between shots.
@export var rps := 1.0
@export var zoom := 1.0
## Spread half-angle from the hip, in degrees.
@export var hip := 0.0
## Spread half-angle when aiming, in degrees.
@export var ads := 0.0
## How far shots reach, in metres.
@export var max_range := 100.0
## Recoil.
@export var kick := 0.0
## Bat: swing reach, in metres.
@export var reach := 0.0

@export_group("Ammo and reload")
@export var mag := 0
## Seconds to refill the whole magazine. Unused if reload_per_round is above 0.
@export var reload := 0.0
## Seconds to load one round. Above 0, the weapon reloads round by round, and firing cancels the reload.
@export var reload_per_round := 0.0

@export_group("Player")
@export var max_hp := 100.0
## Move speed multiplier while holding this weapon.
@export var speed_mult := 1.0

@export_group("Bat momentum")
## Damage is multiplied by this for every m/s above your sprint speed.
@export var speed_factor := 1.0
## Host: extra m/s allowed over the attacker's last known speed.
@export var speed_slack := 0.0
## Damage of the gun launched by a bat kill.
@export var thrown_damage := 0.0

@export_group("Sound")
## Shot volume (dB) right next to the shooter. Only used if sound_fade_distance is above 0.
@export var sound_near_db := 0.0
## Shot volume (dB) at sound_fade_distance and any distance past it, so it's never silent.
@export var sound_far_db := 0.0
## Distance (m) over which the shot fades from near to far volume. 0 = normal sound falloff.
@export var sound_fade_distance := 0.0

@export_group("Grenade")
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
