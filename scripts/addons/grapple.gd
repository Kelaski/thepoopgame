class_name GrappleAddon
extends Addon

@export var reach := 27.0
## Starts when the hook latches on.
@export var cd := 6.5
## Cooldown after a throw that hits nothing.
@export var miss_cd := 1.0
@export var hook_speed := 110.0
## Reel-in acceleration.
@export var pull := 42.0
## Air steering on the rope.
@export var steer := 14.0
## The most speed the grapple can give you.
@export var max_speed := 22.0
## The rope lets go after this long.
@export var max_time := 2.5
## Within this distance you pop off the end.
@export var arrive := 2.0
## Upward speed at the end, to clear ledges.
@export var end_pop := 6.5
## Speed a hooked enemy is pulled towards you.
@export var yank := 11.0


func describe() -> String:
	return "Hold to grapple (%.0fm) and swing. %.1fs cooldown." % [reach, cd]


func use(p) -> void:
	if p.grapple_state == p.Hook.NONE:
		p._fire_grapple()


func status(p, _slot: int) -> Array:
	if p.grapple_state == p.Hook.FLYING:
		return ["HOOK OUT", 1.0 - p._hook_dist / reach, "active"]
	if p.grapple_state == p.Hook.ATTACHED:
		return ["GRAPPLING", p.grapple_t / max_time, "active"]
	return []
