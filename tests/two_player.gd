extends Node
## Two-player smoke test over a local (debug-only) ENet match. Checks joining,
## unique names and that movement updates get through the teleport filter.
## Run the host and the joiner at once (see DEVELOPMENT.md); the host exits 0 on pass.

func _fail(why: String) -> void:
	printerr("TEST FAIL: ", why)
	get_tree().quit(1)


func _ready() -> void:
	add_child((load("res://scenes/main.tscn") as PackedScene).instantiate())
	var t := 0.0
	while Net.players.size() < 2 and t < 40.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	if not multiplayer.is_server():
		await get_tree().create_timer(25.0).timeout  # stay connected while the host checks
		get_tree().quit()
		return
	if Net.players.size() != 2:
		return _fail("the joiner never registered")
	var names: Array = Net.players.values().map(func(p): return p.name)
	if names[0] == names[1]:
		return _fail("duplicate names %s" % [names])
	Game.server_start_match()
	while Game.phase != Game.Phase.RUSH and t < 60.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	await get_tree().create_timer(2.0).timeout
	for id in Game.world.players:
		var p: Player = Game.world.players[id]
		if not p.is_local and (not p._has_net or p._jump_votes != 0):
			return _fail("movement from %d was dropped" % id)
	if not await _check_addons():
		return
	print("TEST PASS")
	get_tree().quit(0)


## Parry, Swap and Warp, refereed by the host (us), against the joiner.
func _check_addons() -> bool:
	var jid: int = Net.players.keys().filter(func(i): return i != 1)[0]
	var me: Player = Game.world.players[1]
	var them: Player = Game.world.players[jid]
	# Parry: a hit on a parrying player does nothing; the same hit lands without it.
	Game._thrown[1] = [2, Game._now + 4.0]  # two hits from a thrown gun skip the range check
	var hp0: float = Game.hp[jid]
	Game._parry_until[jid] = Game._now + 5.0
	Game.report_hit(jid, 30.0, false, "thrown")
	if Game.hp[jid] != hp0:
		_fail("a parried hit did damage")
		return false
	Game._parry_until.erase(jid)
	Game.report_hit(jid, 30.0, false, "thrown")
	if Game.hp[jid] >= hp0:
		_fail("a hit without parry did no damage (%s)" % Game.hp[jid])
		return false
	# Swap: after the beam, we stand where they stood and they stand where we stood,
	# on both screens (their own client moves them; their updates aren't refused).
	Net.players[1].addon = "swap"
	me.addon = "swap"
	# Too far (they spawn at opposite ends): nothing happens, and the swap is refunded.
	Game.request_swap()
	await get_tree().create_timer(Addons.SWAP_CHARGE + 0.3).timeout
	if me.global_position.distance_to(them.global_position) < Addons.SWAP_RANGE or Game._ability_at.get(1, {}).has("swap"):
		_fail("swap: an enemy out of range was swapped, or the swap wasn't refunded")
		return false
	# Within 20 m: we stand where they stood and they stand where we stood.
	me.global_position = them.global_position + Vector3(8, 0, 0)
	me.velocity = Vector3.ZERO
	await get_tree().physics_frame
	var a := me.global_position
	var b := them.global_position
	Game.request_swap()
	await get_tree().create_timer(Addons.SWAP_CHARGE + 0.5).timeout
	if me.global_position.distance_to(b) > 2.0 or them.global_position.distance_to(a) > 2.0:
		_fail("swap: we're %.1f m and they're %.1f m from the other's spot" % [me.global_position.distance_to(b), them.global_position.distance_to(a)])
		return false
	await get_tree().create_timer(1.5).timeout
	if them.global_position.distance_to(a) > 2.0 or them._jump_votes != 0:
		_fail("swap: the joiner's own updates didn't follow (%.1f m off, %d refused)" % [them.global_position.distance_to(a), them._jump_votes])
		return false
	# Warp: up to 15 m the way we look, on a cooldown, and the host accepts it.
	Net.players[1].addon = "warp"
	me.addon = "warp"
	var w0 := me.global_position
	me._warp()
	var moved := me.global_position.distance_to(w0)
	if moved > Addons.WARP_DIST + 0.1 or (moved > 0.5 and me.addon_cd[Player.PRI] <= 0.0):
		_fail("warp moved %.1f m, cooldown %.1f" % [moved, me.addon_cd[Player.PRI]])
		return false
	# ...and never through a wall: put one 5 m ahead, high above the city.
	me.global_position = Vector3(0, 400, 0)
	me.velocity = Vector3.ZERO
	var fwd := me.aim_dir()
	var wall := StaticBody3D.new()
	wall.collision_layer = MapBuilder.L_WALL
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(6, 6, 0.3)
	wall.add_child(shape)
	Game.world.add_child(wall)
	wall.global_transform = Transform3D(Basis.looking_at(fwd), me.eye_pos() + fwd * 5.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	me.addon_cd[Player.PRI] = 0.0
	var w1 := me.global_position
	me._warp()
	var blocked := me.global_position.distance_to(w1)
	wall.queue_free()
	if blocked > 5.0:
		_fail("warp went %.1f m, through a wall 5 m away" % blocked)
		return false
	print("ADDONS parry ok, swap ok, warp %.1f m in the open, %.1f m at a wall" % [moved, blocked])
	return true
