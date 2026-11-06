class_name WeaponStats
extends Resource
## What every weapon has. Each weapon has a file in assets/tuning/weapons/: open it in Godot and
## edit the values in the Inspector. Weapon types add their own fields (scripts/data/weapons/).

@export var name := ""
## The most damage the host accepts from one shot. Raise it if you raise the damage.
@export var max_damage := 50.0

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

@export_group("Sound")
## Shot volume (dB) right next to the shooter. Only used if sound_fade_distance is above 0.
@export var sound_near_db := 0.0
## Shot volume (dB) at sound_fade_distance and any distance past it, so it's never silent.
@export var sound_far_db := 0.0
## Distance (m) over which the shot fades from near to far volume. 0 = normal sound falloff.
@export var sound_fade_distance := 0.0
