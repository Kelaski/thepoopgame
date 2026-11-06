class_name GameAddons
extends GameState
## The host's checks on addons: cooldowns, range and sight, Bubble's shield, Phantom and links.

const ABILITY_SLACK := 0.5
const WARP_POS_SLACK := 8.0     # m the host's view of a warping player can lag behind them
const AIM_RANGE_SLACK := 4.0    # m: the host's view of both players can lag a little
const BUBBLE_LATENCY := 0.1     # s added to a Bubble on the host, for shots already on their way
var _ability_at := {}     # server: id -> {ability: host time last used}
var _bubble := {}         # server: id -> [host time it ends, health left]
var _phantom_until := {}  # server: id -> host time their phase ends
var _phantom_stuck := {}  # server: id -> [seconds stuck, damage owed]
var _link_owner := {}     # server: who used Interlink -> their partner
var links := {}           # id -> partner, both ways (replicated)


func _ability_ok(id: int, slot_key: String, ability: String, cd: float) -> bool:
	if not (phase in [Phase.RUSH, Phase.HELD, Phase.DROPPED]) or not alive_ids.get(id, false):
		return false
	if not Net.players.has(id) or Net.players[id].get(slot_key, "") != ability:
		return false
	var used: Dictionary = _ability_at.get(id, {})
	if _now - float(used.get(ability, -100.0)) < cd - ABILITY_SLACK:
		return false
	used[ability] = _now
	_ability_at[id] = used
	return true


## A player's addons are ready again (Player.respawn resets them too).


func _reset_abilities(id: int) -> void:
	_ability_at.erase(id)
	_bubble.erase(id)
	_phantom_until.erase(id)
	_phantom_stuck.erase(id)
	if links.has(id):
		_unlink(id)


## Warp: the warper has already moved; everyone else jumps them to pos.


@rpc("any_peer", "call_local", "reliable")
func report_warp(pos: Vector3) -> void:
	if not multiplayer.is_server() or world == null or not pos.is_finite():
		return
	var id: int = Net.sender()
	if not world.players.has(id) or world.players[id].global_position.distance_to(pos) > Addons.WARP.dist + WARP_POS_SLACK:
		return
	if _ability_ok(id, "active", "warp", Addons.WARP.cd):
		_teleport.rpc(id, pos)


@rpc("authority", "call_local", "reliable")
func _teleport(id: int, pos: Vector3) -> void:
	if world and world.players.has(id) and pos.is_finite():
		world.players[id].net_teleport(pos)


# ---- Bubble: hits drain the shield before your health, and nothing can push you.


@rpc("any_peer", "call_local", "reliable")
func request_bubble() -> void:
	if not multiplayer.is_server():
		return
	var id: int = Net.sender()
	if _ability_ok(id, "active", "bubble", Addons.BUBBLE.cd):
		_bubble[id] = [_now + Addons.BUBBLE.time + BUBBLE_LATENCY, Addons.BUBBLE.health]
		_bubble_fx.rpc(id)


func _bubble_up(id: int) -> bool:
	return _bubble.has(id) and float(_bubble[id][0]) > _now


## What's left of a hit after the victim's Bubble has taken its share.


func _soak(id: int, amount: float) -> float:
	if not _bubble_up(id):
		return amount
	var taken := minf(float(_bubble[id][1]), amount)
	var left := float(_bubble[id][1]) - taken
	_bubble[id][1] = left
	if left <= 0.0:
		_bubble.erase(id)
	_bubble_hit.rpc(id, left / Addons.BUBBLE.health)
	return amount - taken


@rpc("authority", "call_local", "reliable")
func _bubble_fx(id: int) -> void:
	if world and world.players.has(id) and not world.players[id].is_local:
		world.players[id].show_bubble()
		Sfx.play_at("parry", world.players[id].global_position, -3.0, 40.0)


@rpc("authority", "call_local", "reliable")
func _bubble_hit(id: int, health_left: float) -> void:
	if world and world.players.has(id):
		world.players[id].bubble_damaged(health_left)


# ---- Phantom: if the phase ends inside something, the damage doubles every second.


@rpc("any_peer", "call_local", "reliable")
func request_phantom() -> void:
	if not multiplayer.is_server():
		return
	var id: int = Net.sender()
	if _ability_ok(id, "active", "phantom", Addons.PHANTOM.cd):
		_phantom_until[id] = _now + Addons.PHANTOM.time + BUBBLE_LATENCY
		_phantom_stuck.erase(id)


## Pressed again: the phase ends early.


@rpc("any_peer", "call_local", "reliable")
func end_phantom() -> void:
	if multiplayer.is_server() and _phantom_until.has(Net.sender()):
		_phantom_until[Net.sender()] = minf(_phantom_until[Net.sender()], _now)


func _teammate_ok(id: int, target: int, reach: float) -> bool:
	if world == null or id == target or not world.players.has(id) or not world.players.has(target):
		return false
	if not alive_ids.get(target, false) or Net.team_of(id) != Net.team_of(target):
		return false
	var a: Player = world.players[id]
	var b: Player = world.players[target]
	if a.global_position.distance_to(b.global_position) > reach + AIM_RANGE_SLACK:
		return false
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	return in_sight(space, a.eye_pos(), b.global_position + Vector3(0, 1.1, 0), false)


@rpc("any_peer", "call_local", "reliable")
func request_magnet(target: int) -> void:
	if not multiplayer.is_server():
		return
	var id: int = Net.sender()
	if not _teammate_ok(id, target, Addons.MAGNET.reach) or _bubble_up(target) or not _ability_ok(id, "active", "magnet", Addons.MAGNET.cd):
		_ability_msg.rpc_id(id, "Magnet missed", true)
		return
	var me: Vector3 = world.players[id].global_position
	var to: Vector3 = world.players[target].global_position - me
	to.y = 0.0
	var dir := to.normalized() if to.length() > 0.1 else Vector3.FORWARD
	_magnet.rpc(target, me + dir * Addons.MAGNET.stop_distance)


@rpc("authority", "call_local", "reliable")
func _magnet(target: int, pos: Vector3) -> void:
	if world and world.players.has(target):
		world.players[target].magnet_to(pos)


@rpc("any_peer", "call_local", "reliable")
func request_link(target: int) -> void:
	if not multiplayer.is_server():
		return
	var id: int = Net.sender()
	if links.has(id) or links.has(target) or not _teammate_ok(id, target, Addons.INTERLINK.pick_reach) or not _ability_ok(id, "active", "interlink", Addons.INTERLINK.cd):
		_ability_msg.rpc_id(id, "Can't link with them", false)
		return
	links[id] = target
	links[target] = id
	_link_owner[id] = target
	_sync_links.rpc(links)


@rpc("any_peer", "call_local", "reliable")
func request_unlink() -> void:
	if multiplayer.is_server() and links.has(Net.sender()) and _link_owner.has(Net.sender()):
		_unlink(Net.sender())


func _unlink(id: int) -> void:
	var mate: int = links.get(id, 0)
	links.erase(id)
	links.erase(mate)
	var user := id if _link_owner.has(id) else mate
	_link_owner.erase(user)
	_sync_links.rpc(links)
	if Net.players.has(user):
		_link_broken.rpc_id(user)


## The partner sharing damage and healing with id right now: 0 if not linked, or too far apart.


func _linked_mate(id: int) -> int:
	if not links.has(id) or world == null:
		return 0
	var mate: int = links[id]
	if not alive_ids.get(mate, false) or not world.players.has(id) or not world.players.has(mate):
		return 0
	return mate if world.players[id].global_position.distance_to(world.players[mate].global_position) <= Addons.INTERLINK.reach else 0


@rpc("authority", "call_local", "reliable")
func _sync_links(l: Dictionary) -> void:
	links = l


@rpc("authority", "call_local", "reliable")
func _link_broken() -> void:
	var me := multiplayer.get_unique_id()
	if world and world.players.has(me) and world.players[me].active == "interlink":
		world.players[me].addon_cd[Player.ACTIVE_SLOT] = Addons.INTERLINK.cd


## An addon didn't work: say why, and with refund the cooldown is given back.


@rpc("authority", "call_local", "reliable")
func _ability_msg(text: String, refund: bool) -> void:
	var me := multiplayer.get_unique_id()
	if refund and world and world.players.has(me):
		world.players[me].addon_cd[Player.ACTIVE_SLOT] = 0.0
	announce.emit(text, Color("ff5cc6"))


# ---- Grenades: the shooter asks, the host checks it and decides when they blow.


static func in_sight(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, pierce: bool) -> bool:
	var mask := MapBuilder.L_FLOOR | MapBuilder.L_WALL | MapBuilder.L_SOLID
	var r := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, mask))
	if r.is_empty():
		return true
	if not pierce:
		return false
	var dir := (to - from).normalized()
	var exit := space.intersect_ray(PhysicsRayQueryParameters3D.create(r.position + dir * 1.0, r.position, mask))
	if exit.is_empty():
		return false  # thicker than a wall
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(exit.position + dir * 0.02, to, mask)).is_empty()
