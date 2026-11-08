extends Node
## Two-player smoke test over a local (debug-only) ENet match. Checks joining,
## unique names and that movement updates get through the teleport filter.
## Run the host and the joiner at once (see DEVELOPMENT.md); the host exits 0 on pass.

func _fail(why: String) -> void:
	printerr("TEST FAIL: ", why)
	get_tree().quit(1)


var _joiner_door := ""


func _on_chat(_from: int, text: String, _team: bool) -> void:
	if text.begins_with("DOOR "):
		_joiner_door = text


## Waits up to 8 s for something to become true.
func _wait(done: Callable) -> bool:
	var t := 0.0
	while not done.call() and t < 8.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	return done.call()


## The joiner: reconnects once after being kicked, reports the door it sees, leaves when the host goes.
func _run_joiner() -> void:
	var rejoined := [false]
	Net.disconnected.connect(func(_why: String) -> void:
		if rejoined[0]:
			get_tree().quit()
			return
		rejoined[0] = true
		await get_tree().create_timer(0.3).timeout
		var bits: PackedStringArray = Array(OS.get_cmdline_user_args()).filter(func(a): return a.begins_with("--join="))[0].substr(7).split(":")
		Net.join_local(bits[0], int(bits[1]))
		while Game.world == null or Game.world.builder == null:
			await get_tree().process_frame
		await get_tree().create_timer(0.5).timeout
		Net.send_chat("DOOR OPEN" if Game.world.builder.doors[0].is_open() else "DOOR SHUT", false))


func _ready() -> void:
	add_child((load("res://assets/main.tscn") as PackedScene).instantiate())
	var t := 0.0
	while Net.players.size() < 2 and t < 40.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	if not multiplayer.is_server():
		_run_joiner()
		return
	if Net.players.size() != 2:
		return _fail("the joiner never registered")
	var names: Array = Net.players.values().map(func(p): return p.name)
	if names[0] == names[1]:
		return _fail("duplicate names %s" % [names])
	# Ping: the host measures the joiner's round trip within a couple of seconds.
	var jid0: int = Net.players.keys().filter(func(i): return i != 1)[0]
	var wait := 0.0
	while not Net.pings.has(jid0) and wait < 20.0:
		await get_tree().process_frame
		wait += get_process_delta_time()
	if not Net.pings.has(jid0) or Net.pings[jid0] < 0 or Net.pings[jid0] > 1000:
		return _fail("no sensible ping for the joiner (%s)" % Net.pings)
	print("PING joiner %s after %.1f s" % [Net.ping_text(jid0), wait])
	Game.server_start_match()
	Engine.time_scale = 6.0  # through the countdown quickly
	while Game.phase != Game.Phase.RUSH and t < 60.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	Engine.time_scale = 1.0
	await get_tree().create_timer(0.5).timeout
	for id in Game.world.players:
		var p: Player = Game.world.players[id]
		if not p.is_local and (not p._has_net or p._jump_votes != 0):
			return _fail("movement from %d was dropped" % id)
	if not await _check_addons():
		return
	# Kick: they leave, and can come back. They rejoin mid-match and must see the open door.
	var jid: int = Net.players.keys().filter(func(i): return i != 1)[0]
	var jname: String = Net.players[jid].name
	Game.world.door_rpc(0, Door.OPEN_ANGLE, true)
	Net.chat_message.connect(_on_chat)
	Commands.run(jid, "/kick %s" % Net.players[1].name)
	Commands.run(1, "/kick %s" % jname)
	if not await _wait(func() -> bool: return not Net.players.has(jid)):
		return _fail("/kick didn't remove them")
	if not await _wait(func() -> bool: return Net.players.size() == 2):
		return _fail("a kicked player couldn't come back")
	if not await _wait(func() -> bool: return _joiner_door != ""):
		return _fail("the rejoined player never reported the door")
	if _joiner_door != "DOOR OPEN":
		return _fail("a late joiner sees an open door as %s" % _joiner_door)
	# Ban: only the host can, and they can't come back.
	jid = Net.players.keys().filter(func(i): return i != 1)[0]
	jname = Net.players[jid].name
	Commands.run(jid, "/ban %s" % Net.players[1].name)
	if Net._bans.size() != 0:
		return _fail("a non-host could ban")
	Commands.run(1, "/ban %s" % jname)
	if Net._bans.size() != 1 or not await _wait(func() -> bool: return not Net.players.has(jid)):
		return _fail("/ban didn't remove them")
	await get_tree().create_timer(1.5).timeout
	if Net.players.size() != 1:
		return _fail("a banned player got back in")
	print("TEST PASS")
	get_tree().quit(0)


## The refereed addons and the grenade blast, on the host (us), against the joiner.
func _check_addons() -> bool:
	var jid: int = Net.players.keys().filter(func(i): return i != 1)[0]
	var me: Player = Game.world.players[1]
	var them: Player = Game.world.players[jid]
	# A shot's tracer flies to where it lands, then leaves sparks there.
	var from := me.global_position + Vector3.UP
	Game.world.add_tracers(from, PackedVector3Array([from + Vector3(0, 0, -3)]))
	await get_tree().create_timer(0.1).timeout
	if Game.world.get_children().filter(func(n): return n is CPUParticles3D).is_empty():
		_fail("no sparks from a tracer")
		return false
	Net.players[1].passive = "sharpshooter"
	me.passive = "sharpshooter"
	# Bubble: a hit on a Bubble drains it, not their health; the same hit lands without it.
	Game._thrown[1] = [2, Game._now + 4.0]  # two hits from a thrown gun skip the range check
	var hp0: float = Game.hp[jid]
	Game._bubble[jid] = [Game._now + 5.0, Addons.BUBBLE.health]
	Game.report_hit(jid, 30.0, false, "thrown")
	if Game.hp[jid] != hp0 or Game._bubble[jid][1] != Addons.BUBBLE.health - 30.0:
		_fail("a hit on a Bubble did damage, or didn't drain it")
		return false
	Game._bubble.erase(jid)
	Game.report_hit(jid, 30.0, false, "thrown")
	if Game.hp[jid] >= hp0:
		_fail("a hit without a Bubble did no damage (%s)" % Game.hp[jid])
		return false
	Game.hp[jid] = Game.max_hp_of(jid)
	# Firing cancels a round-by-round reload.
	me.weapon = "shotgun"
	me.ammo = 2
	me._start_reload()
	me._try_fire()
	if me.reloading != 0.0 or me.ammo != 1:
		_fail("firing didn't cancel the shell reload (%.1f s left, %d rounds)" % [me.reloading, me.ammo])
		return false
	me.weapon = Net.players[1].weapon
	me.fire_cd = 0.0
	# Magnet: the joiner (on our team for now) is pulled to us, on their own client.
	Net.players[1].active = "magnet"
	me.active = "magnet"
	var team_was: int = Net.players[jid].team
	Net.players[jid].team = Net.players[1].team
	me.velocity = Vector3.ZERO
	# Random maps: stand 6 m away on whichever side a wall doesn't block the view, as Magnet needs it.
	for side: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		me.global_position = them.global_position + side * 6.0
		await get_tree().physics_frame
		if Game._teammate_ok(1, jid, Addons.MAGNET.reach):
			break
	var near_before := me.global_position.distance_to(them.global_position)
	Game.request_magnet(jid)
	await get_tree().create_timer(Addons.MAGNET.pull_time + 0.6).timeout
	if me.global_position.distance_to(them.global_position) > Addons.MAGNET.stop_distance + 1.5 or them._jump_votes != 0:
		_fail("magnet: they ended %.1f m away, from %.1f m (%d refused)" % [me.global_position.distance_to(them.global_position), near_before, them._jump_votes])
		return false
	# Interlink: within range, damage is split, and a death takes both, respawning later.
	Net.players[1].active = "interlink"
	me.active = "interlink"
	Game.request_link(jid)
	if Game.links.get(1, 0) != jid or Game.links.get(jid, 0) != 1:
		_fail("interlink: no link formed")
		return false
	Net.players[jid].team = team_was
	var my_hp: float = Game.hp[1]
	var their_hp: float = Game.hp[jid]
	Game._hurt(jid, jid, 40.0, false, "thrown")
	if not is_equal_approx(Game.hp[1], my_hp - 20.0) or not is_equal_approx(Game.hp[jid], their_hp - 20.0):
		_fail("interlink: 40 damage became %.0f and %.0f" % [my_hp - Game.hp[1], their_hp - Game.hp[jid]])
		return false
	Game._heal(1, 10.0)
	if not is_equal_approx(Game.hp[1], my_hp - 15.0) or not is_equal_approx(Game.hp[jid], their_hp - 15.0):
		_fail("interlink: healing wasn't shared")
		return false
	Game._hurt(jid, jid, 1000.0, false, "stuck")
	if Game.is_alive(1) or Game.is_alive(jid) or Game.links.has(1) or not is_equal_approx(Game.respawn_left.get(1, 0.0), Addons.INTERLINK.respawn_time):
		_fail("interlink: a death didn't take both (alive %s %s, respawn %.1f)" % [Game.is_alive(1), Game.is_alive(jid), Game.respawn_left.get(1, 0.0)])
		return false
	Game.respawn_left[1] = 0.01
	Game.respawn_left[jid] = 0.01
	await get_tree().create_timer(0.5).timeout
	if me.addon_cd[Player.ACTIVE_SLOT] <= 0.0:
		_fail("interlink: breaking the link started no cooldown")
		return false
	me.addon_cd[Player.ACTIVE_SLOT] = 0.0
	# High above the city from here on: grenades, then Phantom.
	me.set_physics_process(false)
	me.prot_left = 0.0  # just respawned
	me.global_position = Vector3(0, 400, 0)
	await get_tree().physics_frame
	# A blast: our own doesn't hurt us but launches us...
	Game.hp[1] = Game.max_hp_of(1)
	me.velocity = Vector3.ZERO
	var at := me.global_position + Vector3(1.0, 1.0, 0)
	Game.server_blast(0, 1, at)
	if Game.hp[1] != Game.max_hp_of(1) or me.velocity.length() < Weapons.DATA.gl.knockback_speed * 0.5:
		_fail("own blast: health %.0f, launched at %.1f m/s" % [Game.hp[1], me.velocity.length()])
		return false
	# ...the blast reaches exactly its radius from your body, as its sphere shows...
	var reach: float = Weapons.DATA.gl.blast_radius + Player.RADIUS
	var chest := me.global_position + Vector3.UP
	me.velocity = Vector3.ZERO
	Game.server_blast(0, 1, chest + Vector3(reach - 0.05, 0, 0))
	if me.velocity.length() < 1.0:
		_fail("a blast just touching you didn't reach you")
		return false
	me.velocity = Vector3.ZERO
	Game.server_blast(0, 1, chest + Vector3(reach + 0.05, 0, 0))
	if me.velocity.length() > 0.01:
		_fail("a blast just short of you still launched you")
		return false
	# ...an enemy's hurts as well...
	me.velocity = Vector3.ZERO
	Game.server_blast(0, jid, at)
	if not is_equal_approx(Game.hp[1], Game.max_hp_of(1) - Weapons.DATA.gl.dmg):
		_fail("enemy blast: health %.0f" % Game.hp[1])
		return false
	# ...Blast Shield halves it...
	Game.hp[1] = Game.max_hp_of(1)
	Net.players[1].passive = "blastshield"
	Game.server_blast(0, jid, at)
	Net.players[1].passive = me.passive
	if not is_equal_approx(Game.hp[1], Game.max_hp_of(1) - Weapons.DATA.gl.dmg * Addons.BLASTSHIELD.mult):
		_fail("Blast Shield: health %.0f" % Game.hp[1])
		return false
	# ...a Bubble stops the damage and the push...
	Game.hp[1] = Game.max_hp_of(1)
	me.velocity = Vector3.ZERO
	Game._bubble[1] = [Game._now + 5.0, Addons.BUBBLE.health + 500.0]
	Game.server_blast(0, jid, at)
	Game._bubble.erase(1)
	if Game.hp[1] != Game.max_hp_of(1) or me.velocity.length() > 0.01:
		_fail("Bubble: health %.0f, launched at %.1f m/s" % [Game.hp[1], me.velocity.length()])
		return false
	# ...a wall stops all of it...
	var cover := StaticBody3D.new()
	cover.collision_layer = MapBuilder.L_WALL
	var cover_shape := CollisionShape3D.new()
	cover_shape.shape = BoxShape3D.new()
	cover_shape.shape.size = Vector3(0.2, 6, 6)
	cover.add_child(cover_shape)
	Game.world.add_child(cover)
	cover.global_position = me.global_position + Vector3(0.7, 1, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Game.server_blast(0, jid, at)
	if Game.hp[1] != Game.max_hp_of(1) or me.velocity.length() > 0.01:
		_fail("blast through a wall: health %.0f, launched at %.1f m/s" % [Game.hp[1], me.velocity.length()])
		return false
	# Phantom: ending inside something hurts, 10 then 20 per second.
	cover.global_position = me.global_position + Vector3(0, 1, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Game._phantom_until[1] = Game._now
	await get_tree().create_timer(1.8).timeout
	var stuck_dmg: float = Game.max_hp_of(1) - Game.hp[1]
	var stuck_want: float = Addons.PHANTOM.stuck_dps * 2.0  # 10 in the first second, about 10 in the next 0.8 s
	if stuck_dmg < stuck_want * 0.6 or stuck_dmg > stuck_want * 1.5:
		_fail("Phantom stuck: %.1f damage in 1.8 s, wanted about %.1f" % [stuck_dmg, stuck_want])
		return false
	cover.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var hp_clear: float = Game.hp[1]
	await get_tree().create_timer(0.5).timeout
	if Game.hp[1] < hp_clear or Game._phantom_until.has(1):
		_fail("Phantom: still hurt after leaving the wall")
		return false
	Game.hp[1] = Game.max_hp_of(1)
	me.set_physics_process(true)
	# Warp: up to 15 m the way we look, on a cooldown, and the host accepts it.
	Net.players[1].active = "warp"
	me.active = "warp"
	var w0 := me.global_position
	Addons.WARP.use(me)
	var moved := me.global_position.distance_to(w0)
	if moved > Addons.WARP.dist + 0.1 or (moved > 0.5 and me.addon_cd[Player.ACTIVE_SLOT] <= 0.0):
		_fail("warp moved %.1f m, cooldown %.1f" % [moved, me.addon_cd[Player.ACTIVE_SLOT]])
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
	me.addon_cd[Player.ACTIVE_SLOT] = 0.0
	var w1 := me.global_position
	Addons.WARP.use(me)
	var blocked := me.global_position.distance_to(w1)
	wall.queue_free()
	if blocked > 5.0:
		_fail("warp went %.1f m, through a wall 5 m away" % blocked)
		return false
	print("ADDONS bubble, shell reload, magnet, interlink, blasts and phantom ok, warp %.1f m in the open, %.1f m at a wall" % [moved, blocked])
	return true
