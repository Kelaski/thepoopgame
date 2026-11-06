class_name MagnetAddon
extends Addon

@export var reach := 40.0
## How close to your crosshair (degrees) a teammate must be.
@export var aim_cone := 8.0
## The most time the pull takes.
@export var pull_time := 0.5
## Where the teammate stops, this far in front of you.
@export var stop_distance := 1.5
@export var cd := 15.0


func describe() -> String:
	return "Pull a teammate in sight to you. %.0fs cooldown." % cd


func use(p) -> void:
	var mate = p._aimed_teammate(reach, aim_cone)
	if mate:
		p.addon_cd[p.ACTIVE_SLOT] = cd
		Sfx.play("addon", -4.0, 1.2)
		Game.request_magnet.rpc_id(1, mate.peer_id)
