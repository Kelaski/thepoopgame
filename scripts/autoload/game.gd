extends Node
## Server-authoritative "Tag" game mode.
##
## Round flow:
##   PREROUND  - teams frozen at their spawn zones, objective revealed.
##   RUSH      - first player to touch the Tag becomes the Runner; their team defends.
##   HELD      - the timer counts down while a Runner carries the Tag.
##   DROPPED   - Runner died; timer paused. Enemy pickup: +10s, teammate pickup: +15s.
##   ROUND_END - holding team wins when the timer hits 0. First to 4 wins the match.

signal match_started
signal match_ended
signal state_changed
signal kill_event(killer: int, victim: int, weapon: String, head: bool)
signal announce(text: String, color: Color)
signal local_hit(damage: float, head: bool, killed: bool)
signal local_damaged(hp: float)

enum Phase { LOBBY, PREROUND, RUSH, HELD, DROPPED, ROUND_END, MATCH_END }

const ROUND_TIME := 120.0
const ROUNDS_TO_WIN := 4
const RESPAWN_TIME := 6.0
const PREROUND_TIME := 5.0
const ROUND_END_TIME := 6.0
const MATCH_END_TIME := 10.0
const REGEN_DELAY := 8.0
const REGEN_RATE := 50.0
const PICKUP_RADIUS := 1.7
const ENEMY_PICKUP_BONUS := 10.0
const TEAM_PICKUP_BONUS := 15.0
const RUNNER_KILL_REWARD := 5.0

var world = null  # World node while a match is loaded
var in_match := false
var ui_open := false

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


# ===================================================================== server

func server_start_match() -> void:
	if not multiplayer.is_server() or in_match:
		return
	for id in Net.players:
		Net.players[id].kills = 0
		Net.players[id].deaths = 0
	Net.broadcast_roster()
	_start_match.rpc()
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
	_start_match.rpc_id(id)
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
	while (b == a or dots[a].distance_to(dots[b]) < 70.0) and tries < 50:
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
		if phase == Phase.HELD:
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
		Phase.RUSH, Phase.DROPPED:
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
	_push_state()


func _server_kill(victim: int, killer: int, weapon: String, head: bool) -> void:
	alive_ids[victim] = false
	hp[victim] = 0.0
	respawn_left[victim] = RESPAWN_TIME
	_respawn_ready.erase(victim)
	if Net.players.has(victim):
		Net.players[victim].deaths += 1
	if Net.players.has(killer) and killer != victim:
		Net.players[killer].kills += 1
	var victim_pos := Vector3.ZERO
	if world.players.has(victim):
		victim_pos = world.players[victim].global_position
	_on_death.rpc(victim, killer, weapon, head, victim_pos)
	if holder == victim:
		_server_drop(victim_pos)
	elif holder == killer and killer != victim and phase == Phase.HELD:
		# Reward the Runner for defending themselves.
		timer = maxf(0.0, timer - RUNNER_KILL_REWARD)
		_announce.rpc("Runner kill! -%ds on the timer" % int(RUNNER_KILL_REWARD), Mats.TAG_COLOR)
	Net.broadcast_roster()
	_push_state()


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

## Called by a shooter after their local hitscan. The server validates and applies it.
@rpc("any_peer", "call_local", "reliable")
func report_hit(victim: int, damage: float, head: bool, weapon: String) -> void:
	if not multiplayer.is_server() or not in_match or world == null:
		return
	var shooter: int = Net.sender()
	if not (phase in [Phase.RUSH, Phase.HELD, Phase.DROPPED]):
		return
	if not alive_ids.get(victim, false):
		return
	if weapon != "thrown" and not alive_ids.get(shooter, false):
		return
	if Net.team_of(shooter) == Net.team_of(victim) or shooter == victim:
		return
	if world.players.has(victim) and world.players[victim].is_protected():
		return
	damage = clampf(damage, 0.0, Weapons.MAX_DAMAGE.get(weapon, 50.0))
	hp[victim] = hp.get(victim, 100.0) - damage
	_last_hit[victim] = _now
	if hp[victim] <= 0.0:
		_server_kill(victim, shooter, weapon, head)
	else:
		_on_damage.rpc(victim, shooter, hp[victim], damage, head)


# ==================================================================== broadcasts

@rpc("authority", "call_local", "reliable")
func _start_match() -> void:
	in_match = true
	phase = Phase.LOBBY
	scores = [0, 0]
	round_num = 0
	match_started.emit()


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
	if shooter == me:
		local_hit.emit(damage, head, false)


@rpc("authority", "call_local", "reliable")
func _on_death(victim: int, killer: int, weapon: String, head: bool, victim_pos: Vector3) -> void:
	alive_ids[victim] = false
	hp[victim] = 0.0
	respawn_left[victim] = RESPAWN_TIME
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
