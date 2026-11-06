class_name WarpAddon
extends Addon

@export var dist := 15.0
@export var cd := 8.0
## How long the afterimage and trail stay where you left.
@export var afterimage_time := 1.0
@export var afterimage_color := Color(0.5, 0.85, 1.0, 0.6)


func describe() -> String:
	return "Blink %.0fm the way you're looking. %.0fs cooldown." % [dist, cd]


## Blink the way you're looking, stopping just short of anything solid (even while Phantom is
## phasing you), with all your speed turned that way.
func use(p) -> void:
	var dir: Vector3 = p.aim_dir()
	if p.is_on_floor() and dir.y < 0.0:
		dir = Vector3(dir.x, 0.0, dir.z).normalized()  # aiming down on the ground: along it
	var mask: int = p.collision_mask
	p.collision_mask = p.MASK_FULL
	var hit: KinematicCollision3D = p.move_and_collide(dir * dist, true, 0.05)
	p.collision_mask = mask
	var travel: Vector3 = dir * dist if hit == null else hit.get_travel()
	if travel.length() < 0.5:
		return  # right up against a wall: nothing happens, no cooldown
	if Game.world:
		Game.world.add_afterimage(p)
		Game.world.add_warp_trail(p.global_position, p.global_position + travel)
	p.global_position += travel
	p._prev_pos = p.global_position
	p._cur_pos = p.global_position
	p.velocity = dir * p.velocity.length()
	if p.wallrunning:
		p._end_wallrun()
	p._mantle_t = 0.0
	p._end_grapple()
	p.addon_cd[p.ACTIVE_SLOT] = cd
	Sfx.play("warp", -3.0)
	Game.report_warp.rpc_id(1, p.global_position)
	p._on_moved()
