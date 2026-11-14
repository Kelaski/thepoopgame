extends GameDamage
## Server-authoritative "Tag" game mode.
##
## Round flow:
##   PREROUND  - teams frozen at their spawn zones, objective revealed.
##   RUSH      - first player to touch the Tag becomes the Runner; their team defends.
##               The clock doesn't run until that first pickup.
##   HELD      - the timer counts down while a Runner carries the Tag.
##   DROPPED   - Runner died; the timer keeps running. Enemy pickup: +10s,
##               teammate pickup: +15s. If the timer hits 0 with the Tag on the
##               ground it's overtime: whoever picks it up first wins the round.
##   ROUND_END - the Runner's team wins when the timer hits 0 while they hold it.
##               First to 3 wins the match.
## This layer runs the match: rounds, the Tag, joining and leaving, and chat commands.

const TAG_EVEN_DIST := 10.0  # m: in a new round both teams start this close to the same distance from the Tag
const SPAWN_TRIES := 300     # zone / Tag pairings checked for line of sight each round (the evenest first)
var _used_dots := []  # server: spawn zones used this match
var _used_objs := []  # server: Tag spots used this match
var _last_team_dots := []  # server: last round's [team 0 zone, team 1 zone]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## The clock ran out with the Tag on the ground: the next pickup wins the round.


func server_start_match() -> void:
	if not multiplayer.is_server() or in_match:
		return
	for id in Net.players:
		Net.players[id].kills = 0
		Net.players[id].deaths = 0
	Net.broadcast_roster()
	_used_dots.clear()
	_used_objs.clear()
	_last_team_dots.clear()
	map_seed = 0 if Level.handmade(map_size) else randi_range(1, 2000000000)
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
	_late_sync.rpc_id(id, alive_ids, objective, scores, round_num, world.open_doors())
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
	_reset_abilities(id)
	_push_state()


func _server_begin_round() -> void:
	if not multiplayer.is_server() or not in_match or world == null:
		return
	round_num += 1
	holder = 0
	holding_team = -1
	timer = ROUND_TIME
	match_winner = -1
	# Pick two spawn zones and a Tag spot together: the zones well apart, both
	# teams within TAG_EVEN_DIST of the same distance to the Tag, and no spawn spot
	# of one team in sight of the other's. Rounds move around: a team never starts
	# where it did last round if anything else works, and zones and Tag spots this
	# match hasn't used yet come first.
	var dots: Array = world.builder.spawn_dots
	var min_dist: float = world.builder.min_spawn_dist
	var objs: Array = world.builder.objectives
	if _used_dots.size() >= dots.size():
		_used_dots = _used_dots.slice(-2)  # all used: start over
	if _used_objs.size() >= objs.size():
		_used_objs = _used_objs.slice(-1) if objs.size() > 1 else []  # start over, but not on last round's spot
	var teams := [[], []]
	for id in Net.players:
		teams[Net.players[id].team].append(id)
	var cands := []  # [score, team 0 zone, team 1 zone, Tag spot]
	for i in dots.size():
		for j in dots.size():
			if i == j or dots[i].distance_to(dots[j]) < min_dist:
				continue
			var score := float(i in _used_dots) + float(j in _used_dots) + randf() * 0.5
			if _last_team_dots.size() == 2 and (i == _last_team_dots[0] or j == _last_team_dots[1]):
				score += 4.0
			for o in objs.size():
				if objs.size() > 1 and o == objective:
					continue  # the Tag always moves
				var uneven := absf(objs[o].pos.distance_to(dots[i]) - objs[o].pos.distance_to(dots[j]))
				# Uneven pairs only as a last resort, the most even first.
				cands.append([score + (2.0 if o in _used_objs else 0.0) + (100.0 + uneven if uneven > TAG_EVEN_DIST else 0.0), i, j, o])
	cands.sort_custom(func(a, b): return a[0] < b[0])
	var pick: Array = cands[0] if not cands.is_empty() else [0.0, 0, 1 % dots.size(), 0]
	var spawns := {}
	for c in cands.slice(0, SPAWN_TRIES):
		# At least 4 spots each, so the area round a zone is out of sight, not just its middle.
		var spots := [world.find_spawn_cluster(dots[c[1]], maxi(teams[0].size(), 4)), world.find_spawn_cluster(dots[c[2]], maxi(teams[1].size(), 4))]
		if not _teams_see_each_other(spots[0], spots[1]):
			pick = c
			break
	var team_dots := [pick[1], pick[2]]
	objective = pick[3]
	_used_dots.append_array(team_dots)
	_last_team_dots = team_dots
	_used_objs.append(objective)
	tag_pos = objs[objective].pos
	for team in 2:
		var spots: Array = world.find_spawn_cluster(dots[team_dots[team]], teams[team].size())
		for k in teams[team].size():
			spawns[teams[team][k]] = spots[k]
	alive_ids.clear()
	_respawn_hold.clear()
	for id in Net.players:
		alive_ids[id] = true
		hp[id] = max_hp_of(id)
		respawn_left.erase(id)
		_last_hit[id] = -100.0
		_reset_abilities(id)
	_streaks.clear()
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
		# The countdown runs out at the same moment for everyone: start moving
		# straight away rather than waiting for the server's next update.
		if phase == Phase.PREROUND and phase_time <= 0.0:
			phase = Phase.RUSH
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
		Phase.RUSH:
			_check_pickups()  # the clock only starts at the first pickup
		Phase.DROPPED:
			# The clock keeps running while the Tag is on the ground; if it runs out,
			# it's overtime and whoever grabs the Tag first wins the round.
			if timer > 0.0:
				timer -= delta
				if timer <= 0.0:
					timer = 0.0
					_announce.rpc("OVERTIME! First to grab the Tag wins!", Mats.TAG_COLOR)
					_push_state()
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
			# Players respawn as soon as the timer is done, unless they're changing
			# their loadout: then they respawn when they close that screen.
			if respawn_left[id] <= 0.0 and not _respawn_hold.get(id, false) and Net.players.has(id):
				respawn_left.erase(id)
				_respawn_hold.erase(id)
				var pos: Vector3 = world.find_respawn(id)
				if not Addons.is_support(Net.players[id].active):
					_reset_abilities(id)
				alive_ids[id] = true
				hp[id] = max_hp_of(id)
				_last_hit[id] = -100.0
				_on_respawn.rpc(id, pos)
	_tick_kill_heals(delta)
	if phase in [Phase.RUSH, Phase.HELD, Phase.DROPPED]:
		_tick_phantom_stuck(delta)
	# Health regeneration
	for id in hp.keys():
		if alive_ids.get(id, false) and hp[id] < max_hp_of(id) and _now - _last_hit.get(id, -100.0) >= REGEN_DELAY + Addons.of(Net.players[id].passive).regen_delay(_streaks.get(id, 0)):
			_heal(id, REGEN_RATE * delta)
	_hp_acc += delta
	if _hp_acc >= 0.1:
		_hp_acc = 0.0
		_sync_hp.rpc(hp)
	_sync_acc += delta
	if _sync_acc >= 0.5:
		_sync_acc = 0.0
		_push_state()


## Kill rewards in progress: each heals KILL_HEAL / KILL_HEAL_TIME per second
## once it starts, up to max health. Dying ends them.


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
	if is_overtime():
		holder = id
		holding_team = team
		_tag_event.rpc("pickup", id, team, tag_pos)
		_server_round_won(team)
		return
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
		_round_sound.rpc(team, true)
	else:
		phase = Phase.ROUND_END
		phase_time = ROUND_END_TIME
		_announce.rpc("%s team wins round %d" % [Mats.team_name(team), round_num], Mats.team_color(team))
		_round_sound.rpc(team, false)
		# A new time of day for the next round (always a different one).
		var next := (time_of_day + 1 + randi() % (TIMES_OF_DAY.size() - 1)) % TIMES_OF_DAY.size()
		_set_time_of_day.rpc(next)
	_push_state()


## The round (or the match) is over: a horn for the round, and for the match a
## fanfare if your team won it or a falling tune if it didn't.


func _teams_see_each_other(a: Array, b: Array) -> bool:
	var eyes := []
	for p: Vector3 in a:
		eyes.append(p + Vector3(0, 1.6, 0))
	for p: Vector3 in b:
		if world._seen_by(p, eyes):
			return true
	return false


## Respawn time for a player who just died: the team holding the Tag waits longer
## (the Runner included, since their team had it when they died).


func server_set_map_size(size: String) -> void:
	if not multiplayer.is_server() or not Level.valid_size(size):
		return
	Settings.s("map_size", size)
	_sync_map_size.rpc(size)
	Net.publish_lobby_info.call_deferred()


## /map command (host only). Returns a reply for the chat.


func server_map_command(sender: int, args: PackedStringArray) -> String:
	var options := " | ".join(PackedStringArray(Level.SIZE_ORDER))
	if args.is_empty():
		return "Current map: %s. Usage: /map <%s>" % [Level.size_name(map_size), options]
	if sender != 1:
		return "Only the host can change the map."
	var size := args[0].to_lower()
	if not Level.valid_size(size):
		return "Unknown map size \"%s\". Use one of: %s" % [size.left(16), options]
	if size == map_size and not in_match:
		return "The map is already %s." % Level.size_name(size)
	server_set_map_size(size)
	if in_match:
		_announce.rpc("Host changed the map to %s - restarting the match" % Level.size_name(size), Color.WHITE)
		_end_match.rpc()
		server_start_match()
		return "Restarting on the %s map." % Level.size_name(size)
	return "Map set to %s." % Level.size_name(size)


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


@rpc("any_peer", "call_local", "reliable")
func set_respawn_hold(hold: bool) -> void:
	if not multiplayer.is_server() or not in_match:
		return
	var id: int = Net.sender()
	if hold and not alive_ids.get(id, false):
		_respawn_hold[id] = true
	else:
		_respawn_hold.erase(id)
