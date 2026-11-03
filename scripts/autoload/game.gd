extends Node
## Server-authoritative "Tag" game mode.
##
## Round flow:
##   PREROUND  - teams frozen at their spawn zones, objective revealed.
##   RUSH      - first player to touch the Tag becomes the Runner; their team defends.
##               The clock doesn't run until that first pickup.
##   HELD      - the timer counts down while a Runner carries the Tag.
##   DROPPED   - Runner died; the timer keeps running. Enemy pickup: +10s,
##               teammate pickup: +15s.
##   ROUND_END - the team that held the Tag last wins when the timer hits 0.
##               First to 4 wins the match.

signal match_started
signal match_ended
signal map_size_changed(size: String)
signal state_changed
signal kill_event(killer: int, victim: int, weapon: String, head: bool)
signal announce(text: String, color: Color)
signal local_hit(damage: float, head: bool, killed: bool)
signal local_damaged(hp: float)
signal local_damaged_by(shooter: int, pos: Vector3)  # for the damage direction indicator
signal time_of_day_changed  # World blends to the new time of day

enum Phase { LOBBY, PREROUND, RUSH, HELD, DROPPED, ROUND_END, MATCH_END }

const ROUND_TIME := 120.0
const ROUNDS_TO_WIN := 4
const RESPAWN_TIME := 6.0
const HOLDER_RESPAWN_PENALTY := 1.0  # extra respawn time for the team carrying the Tag
const PREROUND_TIME := 5.0
const ROUND_END_TIME := 6.0
const MATCH_END_TIME := 10.0
const REGEN_DELAY := 8.0
const REGEN_RATE := 50.0
const PICKUP_RADIUS := 1.7
const ENEMY_PICKUP_BONUS := 10.0
const TEAM_PICKUP_BONUS := 15.0
const RUNNER_KILL_REWARD := 5.0
const KILL_HEAL := 30.0  # health given back to the killer

const TIMES_OF_DAY := ["Morning", "Afternoon", "Evening", "Night"]

var world = null  # World node while a match is loaded
var map_size := MapData.DEFAULT_SIZE  # chosen by the host; replicated to everyone
var map_seed := 0  # 0 = classic city, otherwise the random city's seed (new every match)
var time_of_day := 1  # index into TIMES_OF_DAY; the host picks a new one after every round
var in_match := false
var ui_open := false
var typing := false  # chat box has focus: gameplay keys are ignored

# Replicated state
var phase: int = Phase.LOBBY
var phase_time := 0.0
var timer := ROUND_TIME
var scores := [0, 0]
var round_num := 0
var objective := -1
var holder := 0
var holding_team := -1
var tag_pos := Vector3.ZERO
var match_winner := -1
var alive_ids := {}       # id -> bool (replicated to everyone)
var hp := {}              # id -> float (replicated to everyone)
var respawn_left := {}    # id -> seconds (replicated)
var _respawn_ready := {}  # server: id -> true once the player pressed Respawn

# Server only
var _last_hit := {}
var _sync_acc := 0.0
var _hp_acc := 0.0
var _now := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_alive(id: int) -> bool:
	return alive_ids.get(id, false)


## Max health depends on the weapon you spawned with (the bat gives 150).
func max_hp_of(id: int) -> float:
	if Net.players.has(id):
		return Weapons.max_hp(Net.players[id].weapon)
	return Weapons.DEFAULT_MAX_HP


func my_max_hp() -> float:
	return max_hp_of(multiplayer.get_unique_id())


func my_hp() -> float:
	return hp.get(multiplayer.get_unique_id(), 100.0)


func reset_local() -> void:
	in_match = false
	ui_open = false
	typing = false
	phase = Phase.LOBBY
	scores = [0, 0]
	round_num = 0
	holder = 0
	holding_team = -1
	objective = -1
	alive_ids.clear()
	hp.clear()
	respawn_left.clear()
	world = null
	_set_map_size_local(MapData.DEFAULT_SIZE)


# ===================================================================== server

func server_start_match() -> void:
	if not multiplayer.is_server() or in_match:
		return
	for id in Net.players:
		Net.players[id].kills = 0
		Net.players[id].deaths = 0
	Net.broadcast_roster()
	map_seed = randi_range(1, 2000000000) if Settings.g("map_random") else 0
	time_of_day = randi() % TIMES_OF_DAY.size()
	_start_match.rpc(map_size, map_seed, time_of_day)
	get_tree().create_timer(1.0).timeout.connect(_server_begin_round)


func server_end_match() -> void:
	if multiplayer.is_server() and in_match:
		_end_match.rpc()


func on_player_joined(id: int) -> void:
	if not in_match:
		return
	alive_ids[id] = false
	hp[id] = max_hp_of(id)
	respawn_left[id] = RESPAWN_TIME
	_start_match.rpc_id(id, map_size, map_seed, time_of_day)
	_late_sync.rpc_id(id, alive_ids, objective, scores, round_num)
	_push_state()


func on_player_left(id: int) -> void:
	if not in_match:
		return
	if holder == id:
		var pos := tag_pos
		if world and world.players.has(id):
			pos = world.players[id].global_position
		_server_drop(pos)
	alive_ids.erase(id)
	hp.erase(id)
	respawn_left.erase(id)
	_push_state()


func _server_begin_round() -> void:
	if not multiplayer.is_server() or not in_match or world == null:
		return
	round_num += 1
	holder = 0
	holding_team = -1
	timer = ROUND_TIME
	match_winner = -1
	# Pick two spawn zones that are well apart, then the most "between" objective.
	var dots: Array = world.builder.spawn_dots
	var a := randi() % dots.size()
	var b := a
	var tries := 0
	var min_dist: float = world.builder.min_spawn_dist
	while (b == a or dots[a].distance_to(dots[b]) < min_dist) and tries < 50:
		b = randi() % dots.size()
		tries += 1
	if b == a:
		b = (a + 1) % dots.size()
	var team_dots := [a, b]
	if randf() < 0.5:
		team_dots = [b, a]
	var objs: Array = world.builder.objectives
	var ranked := []
	for i in objs.size():
		var da: float = objs[i].pos.distance_to(dots[team_dots[0]])
		var db: float = objs[i].pos.distance_to(dots[team_dots[1]])
		ranked.append([absf(da - db) + randf() * 12.0, i])
	ranked.sort_custom(func(x, y): return x[0] < y[0])
	objective = ranked[0][1]
	tag_pos = objs[objective].pos
	# Spawn positions for each team around its dot.
	var spawns := {}
	for team in 2:
		var ids := []
		for id in Net.players:
			if Net.players[id].team == team:
				ids.append(id)
		var spots: Array = world.find_spawn_cluster(dots[team_dots[team]], ids.size())
		for i in ids.size():
			spawns[ids[i]] = spots[i]
	alive_ids.clear()
	_respawn_ready.clear()
	for id in Net.players:
		alive_ids[id] = true
		hp[id] = max_hp_of(id)
		respawn_left.erase(id)
		_last_hit[id] = -100.0
	_begin_round.rpc(round_num, objective, team_dots, spawns, scores)


func _physics_process(delta: float) -> void:
	if not in_match or world == null:
		return
	_now += delta
	if not multiplayer.is_server():
		# Clients just run the clocks locally between syncs.
		if phase == Phase.HELD or phase == Phase.DROPPED:
			timer = maxf(0.0, timer - delta)
		if phase in [Phase.PREROUND, Phase.ROUND_END, Phase.MATCH_END]:
			phase_time = maxf(0.0, phase_time - delta)
		for id in respawn_left.keys():
			respawn_left[id] = maxf(0.0, respawn_left[id] - delta)
		return
	_server_tick(delta)


func _server_tick(delta: float) -> void:
	match phase:
		Phase.PREROUND:
			phase_time -= delta
			if phase_time <= 0.0:
				phase = Phase.RUSH
				_push_state()
				_announce.rpc("GO! Grab the Tag!", Color.WHITE)
		Phase.RUSH:
			_check_pickups()  # the clock only starts at the first pickup
		Phase.DROPPED:
			# The clock keeps running while the Tag is on the ground; if it runs out,
			# the team that held it last wins the round.
			timer -= delta
			if timer <= 0.0:
				timer = 0.0
				_server_round_won(holding_team)
			else:
				_check_pickups()
		Phase.HELD:
			if world.players.has(holder):
				tag_pos = world.players[holder].global_position
			timer -= delta
			if timer <= 0.0:
				timer = 0.0
				_server_round_won(holding_team)
		Phase.ROUND_END:
			phase_time -= delta
			if phase_time <= 0.0:
				_server_begin_round()
		Phase.MATCH_END:
			phase_time -= delta
			if phase_time <= 0.0:
				_end_match.rpc()
				return
	# Respawns
	if phase in [Phase.RUSH, Phase.HELD, Phase.DROPPED]:
		for id in respawn_left.keys():
			respawn_left[id] = maxf(0.0, respawn_left[id] - delta)
			# Players respawn manually (Jump key) once the timer is done, so they
			# have time to change loadouts.
			if respawn_left[id] <= 0.0 and _respawn_ready.get(id, false) and Net.players.has(id):
				respawn_left.erase(id)
				_respawn_ready.erase(id)
				var pos: Vector3 = world.find_respawn(id)
				alive_ids[id] = true
				hp[id] = max_hp_of(id)
				_last_hit[id] = -100.0
				_on_respawn.rpc(id, pos)
	# Health regeneration
	for id in hp.keys():
		if alive_ids.get(id, false) and hp[id] < max_hp_of(id) and _now - _last_hit.get(id, -100.0) >= REGEN_DELAY:
			hp[id] = minf(max_hp_of(id), hp[id] + REGEN_RATE * delta)
	_hp_acc += delta
	if _hp_acc >= 0.1:
		_hp_acc = 0.0
		_sync_hp.rpc(hp)
	_sync_acc += delta
	if _sync_acc >= 0.5:
		_sync_acc = 0.0
		_push_state()


func _check_pickups() -> void:
	for id in alive_ids.keys():
		if not alive_ids[id] or not world.players.has(id):
			continue
		var p: Vector3 = world.players[id].global_position
		var flat := Vector2(p.x - tag_pos.x, p.z - tag_pos.z).length()
		if flat <= PICKUP_RADIUS and absf(p.y - tag_pos.y) < 2.2:
			_server_pickup(id)
			return


func _server_pickup(id: int) -> void:
	var team: int = Net.team_of(id)
	if phase == Phase.RUSH:
		timer = ROUND_TIME
	elif phase == Phase.DROPPED:
		timer += TEAM_PICKUP_BONUS if team == holding_team else ENEMY_PICKUP_BONUS
		timer = minf(timer, ROUND_TIME)
	holder = id
	holding_team = team
	phase = Phase.HELD
	_tag_event.rpc("pickup", id, team, tag_pos)
	_push_state()


func _server_drop(pos: Vector3) -> void:
	holder = 0
	tag_pos = world.snap_to_floor(pos)
	phase = Phase.DROPPED
	_tag_event.rpc("drop", 0, holding_team, tag_pos)
	_push_state()


func _server_round_won(team: int) -> void:
	if team < 0:
		return
	scores[team] += 1
	holder = 0
	if scores[team] >= ROUNDS_TO_WIN:
		match_winner = team
		phase = Phase.MATCH_END
		phase_time = MATCH_END_TIME
		_announce.rpc("%s TEAM WINS THE MATCH!" % Mats.team_name(team).to_upper(), Mats.team_color(team))
	else:
		phase = Phase.ROUND_END
		phase_time = ROUND_END_TIME
		_announce.rpc("%s team wins round %d" % [Mats.team_name(team), round_num], Mats.team_color(team))
		# A new time of day for the next round (always a different one).
		var next := (time_of_day + 1 + randi() % (TIMES_OF_DAY.size() - 1)) % TIMES_OF_DAY.size()
		_set_time_of_day.rpc(next)
	_push_state()


## Respawn time for a player who just died: the team holding the Tag waits longer
## (the Runner included, since their team had it when they died).
func _respawn_time_for(id: int) -> float:
	if holder != 0 and Net.team_of(id) == Net.team_of(holder):
		return RESPAWN_TIME + HOLDER_RESPAWN_PENALTY
	return RESPAWN_TIME


func _server_kill(victim: int, killer: int, weapon: String, head: bool) -> void:
	var respawn := _respawn_time_for(victim)
	alive_ids[victim] = false
	hp[victim] = 0.0
	respawn_left[victim] = respawn
	_respawn_ready.erase(victim)
	if Net.players.has(victim):
		Net.players[victim].deaths += 1
	if weapon == "bat" and killer != victim:
		_thrown[killer] = [THROWN_HITS, _now + THROWN_WINDOW]  # the victim's gun goes flying
	if Net.players.has(killer) and killer != victim:
		Net.players[killer].kills += 1
		# Kill reward: heal the killer (capped at their max health).
		if alive_ids.get(killer, false):
			hp[killer] = minf(max_hp_of(killer), float(hp.get(killer, 0.0)) + KILL_HEAL)
			_sync_hp.rpc(hp)
	var victim_pos := Vector3.ZERO
	if world.players.has(victim):
		victim_pos = world.players[victim].global_position
	_on_death.rpc(victim, killer, weapon, head, victim_pos, respawn)
	if holder == victim:
		_server_drop(victim_pos)
	elif holder == killer and killer != victim and phase == Phase.HELD:
		# Reward the Runner for defending themselves.
		timer = maxf(0.0, timer - RUNNER_KILL_REWARD)
		_announce.rpc("Runner kill! -%ds on the timer" % int(RUNNER_KILL_REWARD), Mats.TAG_COLOR)
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


# ==================================================================== map size

## Host picks the map size (lobby dropdown or /map). Takes effect when the next
## match starts; during a match the match restarts on the new map.
func server_set_map_size(size: String) -> void:
	if not multiplayer.is_server() or not MapData.valid_size(size):
		return
	Settings.s("map_size", size)
	_sync_map_size.rpc(size)


## /map command (host only). Returns a reply for the chat.
func server_map_command(sender: int, args: PackedStringArray) -> String:
	var options := " | ".join(PackedStringArray(MapData.SIZE_ORDER))
	if args.is_empty():
		return "Current map: %s. Usage: /map <%s>" % [MapData.size_name(map_size), options]
	if sender != 1:
		return "Only the host can change the map."
	var size := args[0].to_lower()
	if not MapData.valid_size(size):
		return "Unknown map size \"%s\". Use one of: %s" % [size.left(16), options]
	if size == map_size and not in_match:
		return "The map is already %s." % MapData.size_name(size)
	server_set_map_size(size)
	if in_match:
		_announce.rpc("Host changed the map to %s - restarting the match" % MapData.size_name(size), Color.WHITE)
		_end_match.rpc()
		server_start_match()
		return "Restarting on the %s map." % MapData.size_name(size)
	return "Map set to %s." % MapData.size_name(size)


## /time command (host only). Returns a reply for the chat.
func server_time_command(sender: int, args: PackedStringArray) -> String:
	var names := PackedStringArray()
	for t: String in TIMES_OF_DAY:
		names.append(t.to_lower())
	var usage := "Usage: /time <%s|next>" % "|".join(names)
	if args.is_empty():
		return "Time of day: %s. %s" % [TIMES_OF_DAY[time_of_day], usage]
	if sender != 1:
		return "Only the host can change the time of day."
	if not in_match:
		return "Start a match first."
	var arg := args[0].to_lower()
	var idx := (time_of_day + 1) % TIMES_OF_DAY.size() if arg == "next" else names.find(arg)
	if idx < 0:
		return "Unknown time \"%s\". %s" % [arg.left(16), usage]
	if idx == time_of_day:
		return "It's already %s." % TIMES_OF_DAY[idx].to_lower()
	_set_time_of_day.rpc(idx)
	return "Time of day set to %s." % TIMES_OF_DAY[idx].to_lower()


func send_map_size_to(id: int) -> void:
	if multiplayer.is_server():
		_sync_map_size.rpc_id(id, map_size)


@rpc("authority", "call_local", "reliable")
func _sync_map_size(size: String) -> void:
	_set_map_size_local(size)


func _set_map_size_local(size: String) -> void:
	if not MapData.valid_size(size):
		size = MapData.DEFAULT_SIZE
	if size != map_size:
		map_size = size
		map_size_changed.emit(size)


## Dead player asks to respawn. Honoured once their respawn timer has run out.
@rpc("any_peer", "call_local", "reliable")
func request_respawn() -> void:
	if not multiplayer.is_server() or not in_match:
		return
	var id: int = Net.sender()
	if not alive_ids.get(id, false) and respawn_left.has(id) and respawn_left[id] <= 0.3:
		_respawn_ready[id] = true


func _push_state() -> void:
	_sync_state.rpc(phase, phase_time, timer, scores, round_num, holder, holding_team, tag_pos, objective, alive_ids, respawn_left)


# ==================================================================== client-callable

## Called by a shooter after their local hitscan. The server validates and applies it:
## the weapon must be the one they're holding (or the gun a bat kill just threw),
## the victim must be in that weapon's range, and hits can't come faster than the
## weapon can fire.
@rpc("any_peer", "call_local", "reliable")
func report_hit(victim: int, damage: float, head: bool, weapon: String) -> void:
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
	damage = clampf(damage, 0.0, Weapons.MAX_DAMAGE.get(weapon, 50.0))
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
		spd += Weapons.BAT_SPEED_SLACK
		damage = minf(damage, Weapons.bat_damage(spd, Player.SPRINT * Weapons.BAT_SPEED_MULT))
	hp[victim] = hp.get(victim, 100.0) - damage
	_last_hit[victim] = _now
	if hp[victim] <= 0.0:
		_server_kill(victim, shooter, weapon, head)
	else:
		_on_damage.rpc(victim, shooter, hp[victim], damage, head)


# Hit validation (server). Each weapon gets a budget of hits that refills as fast
# as it can fire (with slack for latency and for hitting several people with one
# shot). The gun a bat kill throws gets a couple of hits for a few seconds.
const HIT_RATE_SLACK := 1.6
const HIT_RANGE_SLACK := 12.0   # m over the weapon's range (latency, interpolation)
const THROWN_WINDOW := 4.0      # s after a bat kill that its thrown gun can hit
const THROWN_HITS := 2
var _hit_tokens := {}           # shooter -> [tokens, time]
var _thrown := {}               # shooter -> [hits left, until]


func _take_hit_token(shooter: int, weapon: String) -> bool:
	var d: Dictionary = Weapons.DATA.get(weapon, {})
	var per_shot := 4.0 if weapon in ["shotgun", "sniper"] else (2.0 if weapon == "bat" else 1.0)
	var rate := float(d.get("rps", 1.0)) * per_shot * HIT_RATE_SLACK
	if Net.players.has(shooter) and Net.players[shooter].addon == "trackstar" and weapon in Addons.RECHAMBER_WEAPONS:
		rate /= Addons.track_mult(weapon)  # Trackstar re-chambers the pump / bolt guns faster
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
	var d: Dictionary = Weapons.DATA.get(weapon, {})
	var reach := float(d.get("range", 300.0)) + (4.0 if weapon == "bat" else HIT_RANGE_SLACK)
	return world.players[shooter].global_position.distance_to(world.players[victim].global_position) <= reach


func _take_thrown_hit(shooter: int) -> bool:
	var t: Array = _thrown.get(shooter, [0, 0.0])
	if int(t[0]) <= 0 or _now > float(t[1]):
		return false
	_thrown[shooter] = [int(t[0]) - 1, t[1]]
	return true


# ==================================================================== broadcasts

@rpc("authority", "call_local", "reliable")
func _start_match(size: String, seed: int, tod: int) -> void:
	_set_map_size_local(size)
	map_seed = seed
	time_of_day = tod
	in_match = true
	phase = Phase.LOBBY
	scores = [0, 0]
	round_num = 0
	match_started.emit()


@rpc("authority", "call_local", "reliable")
func _set_time_of_day(tod: int) -> void:
	time_of_day = clampi(tod, 0, TIMES_OF_DAY.size() - 1)
	time_of_day_changed.emit()


@rpc("authority", "call_local", "reliable")
func _end_match() -> void:
	in_match = false
	phase = Phase.LOBBY
	match_ended.emit()


@rpc("authority", "reliable")
func _late_sync(alive: Dictionary, obj: int, sc: Array, rnd: int) -> void:
	alive_ids = alive
	objective = obj
	scores = sc
	round_num = rnd
	if world:
		world.on_round_begin(objective)
		for id in world.players:
			world.players[id].set_alive(alive_ids.get(id, false))


@rpc("authority", "call_local", "reliable")
func _begin_round(rnd: int, obj: int, _team_dots: Array, spawns: Dictionary, sc: Array) -> void:
	round_num = rnd
	objective = obj
	scores = sc
	phase = Phase.PREROUND
	phase_time = PREROUND_TIME
	timer = ROUND_TIME
	holder = 0
	holding_team = -1
	respawn_left.clear()
	for id in Net.players:
		alive_ids[id] = true
		hp[id] = max_hp_of(id)
	if world:
		tag_pos = world.builder.objectives[obj].pos
		world.on_round_begin(obj)
		for id in world.players:
			var p = world.players[id]
			if spawns.has(id):
				p.respawn(spawns[id], false)
			else:
				p.set_alive(false)
	Sfx.play("round", -4.0)
	announce.emit("Round %d - Get to the %s!" % [rnd, world.builder.objectives[obj].name if world else "Tag"], Color.WHITE)
	state_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _sync_state(ph: int, pt: float, t: float, sc: Array, rnd: int, h: int, ht: int, tp: Vector3, obj: int, alive: Dictionary, resp: Dictionary) -> void:
	phase = ph
	phase_time = pt
	timer = t
	scores = sc
	round_num = rnd
	holder = h
	holding_team = ht
	tag_pos = tp
	objective = obj
	alive_ids = alive
	respawn_left = resp
	state_changed.emit()


@rpc("authority", "call_remote", "unreliable_ordered")
func _sync_hp(h: Dictionary) -> void:
	var me := multiplayer.get_unique_id()
	var before: float = hp.get(me, 100.0)
	hp = h
	if hp.get(me, 100.0) != before:
		local_damaged.emit(hp.get(me, 100.0))


@rpc("authority", "call_local", "reliable")
func _tag_event(kind: String, id: int, team: int, pos: Vector3) -> void:
	if kind == "pickup":
		holder = id
		holding_team = team
		phase = Phase.HELD
		Sfx.play("pickup", -2.0)
		var me := multiplayer.get_unique_id()
		if id == me:
			announce.emit("YOU ARE THE RUNNER! Survive!", Mats.TAG_COLOR)
		elif team == Net.team_of(me):
			announce.emit("%s has the Tag - protect them!" % Net.name_of(id), Mats.team_color(team))
		else:
			announce.emit("%s has the Tag - hunt them down!" % Net.name_of(id), Mats.team_color(team))
	else:
		holder = 0
		tag_pos = pos
		phase = Phase.DROPPED
		Sfx.play("drop", -2.0)
		announce.emit("The Tag was dropped!", Mats.TAG_COLOR)
	if world:
		world.update_tag()
	state_changed.emit()


@rpc("authority", "call_local", "reliable")
func _announce(text: String, color: Color) -> void:
	announce.emit(text, color)
	state_changed.emit()


@rpc("authority", "call_local", "reliable")
func _on_damage(victim: int, shooter: int, new_hp: float, damage: float, head: bool) -> void:
	hp[victim] = new_hp
	var me := multiplayer.get_unique_id()
	if victim == me:
		local_damaged.emit(new_hp)
		Sfx.play("hurt", -6.0)
		if world and world.players.has(me):
			world.players[me].on_damaged(head)
		if world and world.players.has(shooter):
			local_damaged_by.emit(shooter, world.players[shooter].global_position)
	if shooter == me:
		local_hit.emit(damage, head, false)


@rpc("authority", "call_local", "reliable")
func _on_death(victim: int, killer: int, weapon: String, head: bool, victim_pos: Vector3, respawn: float) -> void:
	alive_ids[victim] = false
	hp[victim] = 0.0
	respawn_left[victim] = respawn
	var me := multiplayer.get_unique_id()
	if world and world.players.has(victim):
		world.players[victim].set_alive(false)
	if killer == me and victim != me:
		local_hit.emit(0.0, head, true)
		# A killing bat swing launches the victim's gun where the batter is looking.
		if weapon == "bat" and world and world.players.has(me) and Net.players.has(victim):
			var vw: String = Net.players[victim].weapon
			if vw != "bat":
				world.launch_thrown_gun(victim_pos + Vector3(0, 1.3, 0), world.players[me].aim_dir(), victim)
	if victim == me:
		local_damaged.emit(0.0)
	kill_event.emit(killer, victim, weapon, head)
	state_changed.emit()


@rpc("authority", "call_local", "reliable")
func _on_respawn(id: int, pos: Vector3) -> void:
	alive_ids[id] = true
	hp[id] = max_hp_of(id)
	respawn_left.erase(id)
	if world and world.players.has(id):
		world.players[id].respawn(pos, true)
	state_changed.emit()
