class_name GameDamage
extends GameAddons
## The host's checks on hits, plus damage, kills, healing and grenades.

const RUNNER_KILL_REWARD := 5.0
const KILL_HEAL := 30.0       # health a kill gives back to the killer...
const KILL_HEAL_TIME := 2.5   # ...over this long...
const KILL_HEAL_DELAY := 0.3  # ...starting this long after the kill
var _kill_heals := {}  # server: id -> [[start time, health still to give], ...] (kills stack)
const HIT_RATE_SLACK := 1.6
const HIT_RANGE_SLACK := 12.0   # m over the weapon's range (latency, interpolation)
const THROWN_WINDOW := 4.0      # s after a bat kill that its thrown gun can hit
const THROWN_HITS := 2
var _hit_tokens := {}           # shooter -> [tokens, time]
var _thrown := {}               # shooter -> [hits left, until]
const STUCK_TICK := 0.25        # s between Phantom's stuck-in-a-wall damage hits
const GRENADE_REACH := 20.0     # m a grenade's start may be from where the host sees the shooter
var _grenade_seq := 0     # server


func _tick_kill_heals(delta: float) -> void:
	for id in _kill_heals.keys():
		if not alive_ids.get(id, false):
			_kill_heals.erase(id)
			continue
		var left := []
		for h: Array in _kill_heals[id]:
			if _now < float(h[0]):
				left.append(h)
				continue
			var amount := minf(float(h[1]), KILL_HEAL / KILL_HEAL_TIME * delta)
			_heal(id, amount)
			if float(h[1]) - amount > 0.001:
				left.append([h[0], float(h[1]) - amount])
		if left.is_empty():
			_kill_heals.erase(id)
		else:
			_kill_heals[id] = left


func _server_drop(pos: Vector3) -> void:
	holder = 0
	tag_pos = world.snap_to_floor(pos)
	phase = Phase.DROPPED
	_tag_event.rpc("drop", 0, holding_team, tag_pos)
	_push_state()


func _respawn_time_for(id: int) -> float:
	if holder != 0 and Net.team_of(id) == Net.team_of(holder):
		return RESPAWN_TIME + HOLDER_RESPAWN_PENALTY
	return RESPAWN_TIME


func _server_kill(victim: int, killer: int, weapon: String, head: bool, noscope := false, shared := false) -> void:
	# Interlink: a death within range takes the partner too, and both wait longer.
	var mate := _linked_mate(victim)
	if links.has(victim):
		_unlink(victim)
	var respawn: float = Addons.INTERLINK.respawn_time if mate != 0 or shared else _respawn_time_for(victim)
	_streaks.erase(victim)
	_bubble.erase(victim)
	_phantom_until.erase(victim)
	_phantom_stuck.erase(victim)
	alive_ids[victim] = false
	hp[victim] = 0.0
	respawn_left[victim] = respawn
	_respawn_hold.erase(victim)
	if Net.players.has(victim):
		Net.players[victim].deaths += 1
	if weapon == "bat" and killer != victim:
		_thrown[killer] = [THROWN_HITS, _now + THROWN_WINDOW]  # the victim's gun goes flying
	if Net.players.has(killer) and killer != victim:
		Net.players[killer].kills += 1
		if Net.players[killer].get("passive", "") == "killstreak":
			_streaks[killer] = mini(_streaks.get(killer, 0) + 1, Addons.KILLSTREAK.max_stacks)
		elif Net.players[killer].get("passive", "") == "cooldownkill":
			# The killer's own timer just got shorter: the host's has to agree, or it refuses the ability.
			var used: Dictionary = _ability_at.get(killer, {})
			for ability: String in used:
				used[ability] -= Addons.COOLDOWNKILL.per_kill
		# Kill reward: the killer regenerates KILL_HEAL over KILL_HEAL_TIME (see _tick_kill_heals).
		if alive_ids.get(killer, false):
			if not _kill_heals.has(killer):
				_kill_heals[killer] = []
			_kill_heals[killer].append([_now + KILL_HEAL_DELAY, KILL_HEAL])
	var victim_pos := Vector3.ZERO
	if world.players.has(victim):
		victim_pos = world.players[victim].global_position
	_on_death.rpc(victim, killer, weapon, head, victim_pos, respawn, noscope)
	if holder == victim:
		_server_drop(victim_pos)
	elif holder == killer and killer != victim and phase == Phase.HELD:
		# Reward the Runner for defending themselves.
		timer = maxf(0.0, timer - RUNNER_KILL_REWARD)
		_announce.rpc("Runner kill! -%ds on the timer" % int(RUNNER_KILL_REWARD), Mats.TAG_COLOR)
	if mate != 0 and alive_ids.get(mate, false):
		_server_kill(mate, mate if killer == victim else killer, weapon, false, false, true)
	Net.broadcast_roster()
	_push_state()


## /kill: the player eliminates themselves. Returns a reply for the chat.


func server_suicide(id: int) -> String:
	if not multiplayer.is_server():
		return ""
	if not in_match or world == null:
		return "You can only use /kill during a match."
	if not alive_ids.get(id, false):
		return "You're already dead."
	if not (phase in [Phase.RUSH, Phase.HELD, Phase.DROPPED]):
		return "You can't use /kill right now."
	_server_kill(id, id, "suicide", false)
	return "You eliminated yourself."


## Host picks the map size (lobby dropdown or /map). Takes effect when the next
## match starts; during a match the match restarts on the new map.


@rpc("any_peer", "call_local", "reliable")
## noscope: a sniper shot fired without the scope, as the shooter saw it (only
## shown in the kill feed, so it's taken on trust).
func report_hit(victim: int, damage: float, head: bool, weapon: String, noscope := false) -> void:
	if not multiplayer.is_server() or not in_match or world == null:
		return
	var shooter: int = Net.sender()
	if not (phase in [Phase.RUSH, Phase.HELD, Phase.DROPPED]):
		return
	if not alive_ids.get(victim, false) or not Net.players.has(shooter) or not is_finite(damage):
		return
	if weapon == "thrown":
		if not _take_thrown_hit(shooter):
			return
	elif not alive_ids.get(shooter, false) or Net.players[shooter].weapon != weapon:
		return
	if Net.team_of(shooter) == Net.team_of(victim) or shooter == victim:
		return
	if world.players.has(victim) and world.players[victim].is_protected():
		return
	if weapon != "thrown" and not _hit_in_range(shooter, victim, weapon):
		return
	if weapon != "thrown" and not _take_hit_token(shooter, weapon):
		return
	var head_mult: float = Addons.of(Net.players[shooter].passive).head_mult() if head else 1.0
	damage = clampf(damage, 0.0, Weapons.max_damage(weapon) * head_mult)
	if weapon == "bat" and world.players.has(shooter):
		# Momentum damage is checked against the attacker's last known speed (with
		# some slack for latency). The lowest possible sprint speed is assumed, which
		# only ever allows more damage, never less.
		var sp: Player = world.players[shooter]
		var v: Vector3 = sp.velocity if sp.is_local else sp.net_vel
		var spd := Vector2(v.x, v.z).length()
		if not sp.is_local:
			# Don't trust a claimed speed the server didn't see them move at.
			spd = minf(spd, sp.observed_speed())
		spd += Weapons.DATA.bat.speed_slack
		damage = minf(damage, Weapons.bat_damage(spd, Player.SPRINT * Weapons.DATA.bat.speed_mult) * head_mult)
	_hurt(victim, shooter, damage, head, weapon, noscope and weapon == "sniper")


## All damage ends up here: Interlink shares it, then a Bubble soaks it first.


func _hurt(victim: int, attacker: int, amount: float, head: bool, weapon: String, noscope := false) -> void:
	var mate := _linked_mate(victim)
	if mate != 0:
		amount *= 0.5
		_hurt_one(mate, attacker, amount, false, weapon, false)
		if not alive_ids.get(victim, false):
			return  # the shared death took us both
	_hurt_one(victim, attacker, amount, head, weapon, noscope)


func _hurt_one(victim: int, attacker: int, amount: float, head: bool, weapon: String, noscope: bool) -> void:
	var through := _soak(victim, amount)
	if through > 0.0:
		hp[victim] = hp.get(victim, 100.0) - through
		_last_hit[victim] = _now
	if hp.get(victim, 0.0) <= 0.0:
		_server_kill(victim, attacker, weapon, head, noscope)
	else:
		_on_damage.rpc(victim, attacker, hp[victim], through, head)


## Healing: Interlink shares this too, each up to their own max health.


func _heal(id: int, amount: float) -> void:
	var mate := _linked_mate(id)
	if mate != 0:
		amount *= 0.5
		hp[mate] = minf(max_hp_of(mate), float(hp.get(mate, 0.0)) + amount)
	hp[id] = minf(max_hp_of(id), float(hp.get(id, 0.0)) + amount)


# Hit validation (server). Each weapon gets a budget of hits that refills as fast
# as it can fire (with slack for latency and for hitting several people with one
# shot). The gun a bat kill throws gets a couple of hits for a few seconds.


func _take_hit_token(shooter: int, weapon: String) -> bool:
	var d: WeaponStats = Weapons.DATA.get(weapon)
	var per_shot := 4.0 if weapon in ["shotgun", "sniper"] else (2.0 if weapon == "bat" else 1.0)
	var rate := (d.rps if d else 1.0) * per_shot * HIT_RATE_SLACK
	if Net.players.has(shooter) and weapon in Addons.RECHAMBER_WEAPONS:
		rate /= Addons.of(Net.players[shooter].passive).rechamber_mult(weapon)  # Trackstar re-chambers the pump / bolt guns faster
	var cap := per_shot * 2.0 + 2.0
	var b: Array = _hit_tokens.get(shooter, [cap, _now])
	var tokens := minf(cap, float(b[0]) + (_now - float(b[1])) * rate)
	if tokens < 1.0:
		_hit_tokens[shooter] = [tokens, _now]
		return false
	_hit_tokens[shooter] = [tokens - 1.0, _now]
	return true


func _hit_in_range(shooter: int, victim: int, weapon: String) -> bool:
	if not world.players.has(shooter) or not world.players.has(victim):
		return false
	var d: WeaponStats = Weapons.DATA.get(weapon)
	var reach := (d.max_range if d else 300.0) + (4.0 if weapon == "bat" else HIT_RANGE_SLACK)
	var sp: Player = world.players[shooter]
	var vp: Player = world.players[victim]
	if sp.global_position.distance_to(vp.global_position) > reach:
		return false
	# No hits through walls: at least one of head, chest or knees must be in sight
	# (three points give slack for players lagging round a corner).
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	for h in [1.6, 1.1, 0.5]:
		if in_sight(space, sp.eye_pos(), vp.global_position + Vector3(0, h, 0), weapon == "sniper"):
			return true
	return false


## True if nothing solid is between from and to. With pierce, one wall (up to
## 1 m thick, as in Player._hitscan) may be in the way, never more.


func _take_thrown_hit(shooter: int) -> bool:
	var t: Array = _thrown.get(shooter, [0, 0.0])
	if int(t[0]) <= 0 or _now > float(t[1]):
		return false
	_thrown[shooter] = [int(t[0]) - 1, t[1]]
	return true


# Addons that change what other players see, or what happens to them, are checked
# by the host (the right addon, alive, mid-round, off cooldown), which tells
# everyone. Cooldowns get ABILITY_SLACK for latency. A Support addon's entry
# survives respawning, like its cooldown does.


func _tick_phantom_stuck(delta: float) -> void:
	for id: int in _phantom_until.keys():
		if _now < float(_phantom_until[id]):
			continue
		var p: Player = world.players.get(id)
		if p == null or not alive_ids.get(id, false) or not p._overlaps(MapBuilder.L_WALL | MapBuilder.L_DOOR, p.probe_shape, Player.STAND_H * 0.5 + 0.1):
			_phantom_until.erase(id)
			_phantom_stuck.erase(id)
			continue
		var s: Array = _phantom_stuck.get(id, [0.0, 0.0])
		s[1] = float(s[1]) + Addons.PHANTOM.stuck_dps * pow(2.0, floorf(float(s[0]))) * delta
		s[0] = float(s[0]) + delta
		_phantom_stuck[id] = s
		if float(s[1]) >= Addons.PHANTOM.stuck_dps * STUCK_TICK:
			var owed := float(s[1])
			s[1] = 0.0
			_hurt(id, id, owed, false, "stuck")


# ---- Magnet and Interlink: aimed at a teammate.


@rpc("any_peer", "call_local", "reliable")
func request_grenade(start: Vector3, vel: Vector3) -> void:
	if not multiplayer.is_server() or world == null or not (phase in [Phase.RUSH, Phase.HELD, Phase.DROPPED]):
		return
	var id: int = Net.sender()
	if not alive_ids.get(id, false) or not Net.players.has(id) or Net.players[id].weapon != "gl" or not world.players.has(id):
		return
	if not start.is_finite() or not vel.is_finite() or vel.length() > Weapons.grenade_speed(Player.NET_MAX_SPEED):
		return
	if world.players[id].global_position.distance_to(start) > GRENADE_REACH or not _take_hit_token(id, "gl"):
		return
	_grenade_seq += 1
	_grenade.rpc(_grenade_seq, id, start, vel)


@rpc("authority", "call_local", "reliable")
func _grenade(gid: int, shooter: int, start: Vector3, vel: Vector3) -> void:
	if world:
		world.add_grenade(gid, shooter, start, vel)


## The host's grenade went off. Walls stop the blast. Enemies are hurt, and everyone
## it reaches (the shooter and their team too) is launched, unless a Bubble blocks it.


func server_blast(gid: int, shooter: int, pos: Vector3) -> void:
	_blast.rpc(gid, pos)
	if not (phase in [Phase.RUSH, Phase.HELD, Phase.DROPPED]):
		return  # it can still go off after the round ended, but it can't score
	var w: LauncherStats = Weapons.DATA.gl
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	for id: int in world.players.keys():
		var p: Player = world.players[id]
		if not alive_ids.get(id, false) or p.is_protected():
			continue
		var c: Vector3 = p.body_point_near(pos)
		if c.distance_to(pos) - Player.RADIUS > w.blast_radius:
			continue
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(pos, c, MapBuilder.MASK_WORLD)).is_empty():
			continue
		var shielded := _bubble_up(id)
		if Net.team_of(id) != Net.team_of(shooter):
			_hurt(id, shooter, w.dmg * Addons.of(Net.players[id].passive).blast_mult(), false, "gl")
		if not shielded and alive_ids.get(id, false):
			var away := (c - pos).normalized() if c.distance_to(pos) > 0.05 else Vector3.UP
			_push.rpc_id(id, away * w.knockback_speed + Vector3.UP * w.knockback_lift)


@rpc("authority", "call_local", "reliable")
func _blast(gid: int, pos: Vector3) -> void:
	if world:
		world.grenade_blast(gid, pos)


@rpc("authority", "call_local", "reliable")
func _push(v: Vector3) -> void:
	var me := multiplayer.get_unique_id()
	if world and world.players.has(me):
		world.players[me].push(v)
