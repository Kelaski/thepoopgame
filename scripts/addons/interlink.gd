class_name InterlinkAddon
extends Addon

## Damage and healing are shared while you're this close.
@export var reach := 25.0
## How far away you can aim at a teammate to link.
@export var pick_reach := 40.0
## How close to your crosshair (degrees) a teammate must be.
@export var aim_cone := 8.0
## Respawn time for both of you after a shared death.
@export var respawn_time := 10.0
## Starts whenever the link breaks.
@export var cd := 25.0


func describe() -> String:
	return "Link to a teammate: within %.0fm you share damage, healing and death. %.0fs cooldown." % [reach, cd]


func use(p) -> void:
	var mate = p._aimed_teammate(pick_reach, aim_cone)
	if mate:
		Sfx.play("addon", -4.0, 1.2)
		Game.request_link.rpc_id(1, mate.peer_id)


func switch_off(p) -> bool:
	if not Game.links.has(p.peer_id):
		return false
	Game.request_unlink.rpc_id(1)
	return true


func status(p, _slot: int) -> Array:
	return ["LINKED: %s" % Net.name_of(Game.links[p.peer_id]), 1.0, "active"] if Game.links.has(p.peer_id) else []
