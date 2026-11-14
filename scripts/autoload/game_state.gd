class_name GameState
extends Node
## What everyone knows about the match, and the messages the host sends to change it. Game is
## built in layers, each adding one job: GameState, GameAddons, GameDamage, then Game
## (game.gd, the autoload). A layer can only use the ones before it.


signal match_started
signal match_ended
signal map_size_changed(size: String)
signal state_changed
signal kill_event(killer: int, victim: int, weapon: String, head: bool, noscope: bool)
signal announce(text: String, color: Color)
signal local_hit(damage: float, head: bool, killed: bool)
signal local_damaged(hp: float)
signal local_damaged_by(shooter: int, pos: Vector3)  # for the damage direction indicator
signal time_of_day_changed  # World blends to the new time of day
enum Phase { LOBBY, PREROUND, RUSH, HELD, DROPPED, ROUND_END, MATCH_END }
const ROUND_TIME := 120.0
const ROUNDS_TO_WIN := 3
const RESPAWN_TIME := 6.0
const HOLDER_RESPAWN_PENALTY := 1.0  # extra respawn time for the team carrying the Tag
const PREROUND_TIME := 3.0  # the 3, 2, 1 countdown
const ROUND_END_TIME := 6.0
const MATCH_END_TIME := 10.0
const REGEN_DELAY := 8.0
const REGEN_RATE := 50.0
const PICKUP_RADIUS := 1.7
const ENEMY_PICKUP_BONUS := 10.0
const TEAM_PICKUP_BONUS := 15.0
const TIMES_OF_DAY := ["Day", "Afternoon", "Evening", "Night"]
var world = null  # World node while a match is loaded
var map_size := Level.DEFAULT_SIZE  # chosen by the host; replicated to everyone
var map_seed := 0  # 0 = a hand-made map, otherwise the random city's seed (new every match)
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
var _respawn_hold := {}  # server: id -> true while the player has the loadout screen open

# Server only
var _last_hit := {}
var _sync_acc := 0.0
var _hp_acc := 0.0
var _now := 0.0
var _streaks := {}        # server: id -> Killstreak kills


func is_overtime() -> bool:
	return phase == Phase.DROPPED and timer <= 0.0


func is_alive(id: int) -> bool:
	return alive_ids.get(id, false)


## Max health depends on the weapon you spawned with (the bat gives more) and Juggernaut.


func max_hp_of(id: int) -> float:
	if Net.players.has(id):
		return Weapons.max_hp(Net.players[id].weapon) + Addons.of(Net.players[id].passive).bonus_hp()
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
	_set_map_size_local(Level.DEFAULT_SIZE)


@rpc("authority", "call_local", "reliable")
func _round_sound(winner: int, match_over: bool) -> void:
	if not match_over:
		Sfx.play("round_end", -2.0, 1.0, "UI")
		return
	var mine := Net.team_of(multiplayer.get_unique_id())
	Sfx.play("match_win" if mine == winner or mine < 0 else "match_lose", -1.0, 1.0, "UI")


## True if any spawn spot of one team can see any of the other team's.


@rpc("authority", "call_local", "reliable")
func _sync_map_size(size: String) -> void:
	_set_map_size_local(size)


func _set_map_size_local(size: String) -> void:
	if not Level.valid_size(size):
		size = Level.DEFAULT_SIZE
	if size != map_size:
		map_size = size
		map_size_changed.emit(size)


## A dead player opened (true) or closed (false) the loadout screen. While it's
## open they aren't respawned; closing it respawns them if their timer is done.


func _push_state() -> void:
	_sync_state.rpc(phase, phase_time, timer, scores, round_num, holder, holding_team, tag_pos, objective, alive_ids, respawn_left)


## Called by a shooter after their local hitscan. The server validates and applies it:
## the weapon must be the one they're holding (or the gun a bat kill just threw),
## the victim must be in that weapon's range, and hits can't come faster than the
## weapon can fire.


@rpc("authority", "call_local", "reliable")
func _start_match(size: String, seed: int, tod: int) -> void:
	Net.publish_lobby_info.call_deferred()
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
	Net.publish_lobby_info.call_deferred()
	in_match = false
	phase = Phase.LOBBY
	match_ended.emit()


@rpc("authority", "reliable")
func _late_sync(alive: Dictionary, obj: int, sc: Array, rnd: int, doors: Array) -> void:
	alive_ids = alive
	objective = obj
	scores = sc
	round_num = rnd
	if world:
		world.on_round_begin(objective)
		for id in world.players:
			world.players[id].set_alive(alive_ids.get(id, false))
		world.apply_open_doors(doors)


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
				p.addon_cd[Player.ACTIVE_SLOT] = 0.0  # a new round: Support cooldowns too
				p._support_cd.clear()
				p._streak = 0
			else:
				p.set_alive(false)
	state_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _sync_state(ph: int, pt: float, t: float, sc: Array, rnd: int, h: int, ht: int, tp: Vector3, obj: int, alive: Dictionary, resp: Dictionary) -> void:
	phase = ph
	phase_time = pt
	# Clients run the clock themselves; the server's (slightly older) time only
	# replaces it when they've drifted apart, so the clock bar never jumps back.
	if absf(t - timer) > 0.4:  # pickups, bonuses and new rounds are always bigger jumps
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
func _on_death(victim: int, killer: int, weapon: String, head: bool, victim_pos: Vector3, respawn: float, noscope := false) -> void:
	alive_ids[victim] = false
	hp[victim] = 0.0
	respawn_left[victim] = respawn
	var me := multiplayer.get_unique_id()
	if world and world.players.has(victim):
		world.players[victim].set_alive(false)
	if killer == me and victim != me:
		local_hit.emit(0.0, head, true)
		if world and world.players.has(me):
			world.players[me].on_kill(victim)  # Reload on Kill
		# A killing bat swing launches the victim's gun where the batter is looking.
		if weapon == "bat" and world and world.players.has(me) and Net.players.has(victim):
			var vw: String = Net.players[victim].weapon
			if vw != "bat":
				world.launch_thrown_gun(victim_pos + Vector3(0, 1.3, 0), world.players[me].aim_dir(), victim)
	if victim == me:
		local_damaged.emit(0.0)
	kill_event.emit(killer, victim, weapon, head, noscope)
	state_changed.emit()


@rpc("authority", "call_local", "reliable")
func _on_respawn(id: int, pos: Vector3) -> void:
	alive_ids[id] = true
	hp[id] = max_hp_of(id)
	respawn_left.erase(id)
	if world and world.players.has(id):
		world.players[id].respawn(pos, true)
	state_changed.emit()
