class_name World
extends Node3D
## The in-match world: map, players, Tag, effects and spawn logic.
## Lives at /root/Main/World on every peer so RPC paths match.

const HEARTBEAT_RANGE := 25.0
const TRACER_LIFE := 0.07

const PLAYER_SCENE := preload("res://assets/models/player.tscn")
const TAG_SCENE := preload("res://assets/models/tag.tscn")
const TAG_MESH_HEIGHT := 1.0   # the Tag's mesh, above its scene's origin
const TAG_BACK_HEIGHT := 1.25  # worn: this high above the runner's feet...
const TAG_BACK_OFFSET := 0.32  # ...and this far behind them
const TAG_LIGHT_ENERGY := 1.5
const TAG_HIGHLIGHT := preload("res://assets/materials/tag_highlight.tres")
const SPRAY_SCENE := preload("res://assets/models/spray_decal.tscn")
const PING_SECONDS := 7.0      # how long a ping shows
const PING_BURST := 3           # this many pings...
const PING_BURST_TIME := 4.0    # ...within this many seconds (server side)...
const PING_COOLDOWN := 15.0     # ...puts you on this cooldown
const DOOR_REACH := 9.0         # a remote player must be this close to move a door
const MAX_SHOT_TRACERS := 16    # shotgun pellets are 13
const MAX_PROJECTILES := 12
const FX_TRACERS_MAT := preload("res://assets/materials/fx_tracers.tres")  # bullet tracers + impacts
const GRENADE_SCENE := preload("res://assets/models/grenade.tscn")
const WARP_TRAIL_SCENE := preload("res://assets/models/warp_trail.tscn")
const EXPLOSION_SCENE := preload("res://assets/models/explosion.tscn")
const UAV_RING_SEGMENTS := 48
const SKY_ENV_SCENE := preload("res://assets/world/sky_env.tscn")
const TOD_BLEND_TIME := 10.0  # seconds to blend into a new time of day
var builder: Level
var pings: Array = []   # [{pos, until}] from your team (the HUD and minimap draw them)
var _ping_locks := {}   # server: id -> when their ping cooldown ends
var _ping_times := {}   # server: id -> recent ping times
var players := {}  # peer id -> Player
var players_node: Node3D
var sky_env: SkyEnv

var tag_node: Node3D
var tag_beam: MeshInstance3D
var tag_light: OmniLight3D
var tag_gem: MeshInstance3D
var _tag_highlit := false  # the countdown's see-through-walls highlight is on

var _fx_mesh: ImmediateMesh
var _fx_inst: MeshInstance3D
var _tracers: Array = []   # [from, to, life, color]
var _impacts: Array = []   # [pos, life]

var _grenades := {}        # id -> {owner, pos, vel, life, node}
var _uav_pulses := []      # [{origin, r, last, done}]: pulses from your team, still growing
var _uav_stills := {}      # enemy id -> {node, pos, until} (until < 0: until the next pulse)
var _uav_pulse_at := {}    # sender -> when their last pulse came
var _projectiles: Array = []
var _hb_timer := 0.0


func _ready() -> void:
	name = "World"
	sky_env = SKY_ENV_SCENE.instantiate()
	add_child(sky_env)
	builder = Level.new()
	builder.build(self, Game.map_size, Game.map_seed)
	builder.settle_objectives()
	sky_env.blend_to(clampi(Game.time_of_day, 0, SkyEnv.TIMES.size() - 1), 0.0)  # with the street lights and skyline in place
	players_node = Node3D.new()
	players_node.name = "Players"
	add_child(players_node)
	_build_tag()
	_build_fx()
	Game.world = self
	Net.roster_changed.connect(sync_players)
	Settings.changed.connect(_apply_settings)
	Game.time_of_day_changed.connect(func() -> void: sky_env.blend_to(Game.time_of_day, TOD_BLEND_TIME))
	Net.spray_updated.connect(_on_spray_updated)
	sync_players()
	_apply_settings()


func _exit_tree() -> void:
	if Game.world == self:
		Game.world = null


# ================================================================ setup

func _apply_settings() -> void:
	_apply_lights()


## Interior lights: Off hides them, Low keeps every other lamp lit, High lights them all.
func _apply_lights() -> void:
	if builder == null:
		return
	var q := int(Settings.g("interior_lights"))
	for i in builder.lights.size():
		builder.lights[i].visible = q == 2 or (q == 1 and i % 2 == 0)


## The Tag (assets/models/tag.tscn): Gem and Beam, tinted with the
## Tag colour (which players can customize) at load.
func _build_tag() -> void:
	tag_node = TAG_SCENE.instantiate()
	tag_node.name = "Tag"
	add_child(tag_node)
	tag_gem = tag_node.get_node("Mesh")
	tag_beam = tag_node.get_node("Beacon")
	tag_light = tag_node.get_node("Light")
	# The Tag's colour can be customized: the glow and the beacon follow it.
	var gem_mat: StandardMaterial3D = tag_gem.material_override.duplicate()
	gem_mat.albedo_color = Mats.TAG_COLOR
	gem_mat.emission = Mats.TAG_COLOR
	tag_gem.material_override = gem_mat
	var beacon_mat: StandardMaterial3D = tag_beam.material_override.duplicate()
	beacon_mat.albedo_color = Color(Mats.TAG_COLOR, beacon_mat.albedo_color.a)
	tag_beam.material_override = beacon_mat
	tag_light.light_color = Mats.TAG_COLOR
	tag_node.visible = false


func _build_fx() -> void:
	_fx_mesh = ImmediateMesh.new()
	_fx_inst = MeshInstance3D.new()
	_fx_inst.mesh = _fx_mesh
	_fx_inst.material_override = FX_TRACERS_MAT
	_fx_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_fx_inst)


# ================================================================ players

func sync_players() -> void:
	for id in Net.players:
		if not players.has(id):
			var p: Player = PLAYER_SCENE.instantiate()
			p.setup(id, Net.players[id])
			players_node.add_child(p)
			players[id] = p
			p.set_alive(Game.is_alive(id))
		else:
			var p: Player = players[id]
			if not p.alive or Game.phase == Game.Phase.PREROUND:
				p.refresh_loadout()  # a loadout picked in the countdown applies at once
	for id in players.keys():
		if not Net.players.has(id):
			players[id].queue_free()
			players.erase(id)


func local_player() -> Player:
	return players.get(multiplayer.get_unique_id())


func on_round_begin(_obj: int) -> void:
	pings.clear()
	for p in _projectiles:
		p.node.queue_free()
	_projectiles.clear()
	for g: Dictionary in _grenades.values():
		g.node.queue_free()
	_grenades.clear()
	_uav_pulses.clear()
	_clear_uav_stills()
	update_tag()


func update_tag() -> void:
	var on_ground: bool = Game.holder == 0 and Game.objective >= 0 and Game.phase in [Game.Phase.PREROUND, Game.Phase.RUSH, Game.Phase.DROPPED]
	var carrier: Player = players.get(Game.holder)
	tag_node.visible = on_ground or (carrier != null and carrier.alive)
	if carrier:
		tag_node.global_position = carrier.global_position + Vector3.UP * (TAG_BACK_HEIGHT - TAG_MESH_HEIGHT) + carrier.global_basis.z * TAG_BACK_OFFSET
	elif on_ground:
		tag_node.global_position = Game.tag_pos


# ================================================================ spawning (server)

func is_free(pos: Vector3) -> bool:
	# Never spawn outside the fence (the ground extends a little past it).
	if not builder.bounds.grow(-0.8).has_point(Vector2(pos.x, pos.z)):
		return false
	var q := PhysicsShapeQueryParameters3D.new()
	var s := CapsuleShape3D.new()
	s.radius = 0.42
	s.height = 1.75
	q.shape = s
	q.transform = Transform3D(Basis.IDENTITY, pos + Vector3(0, 0.95, 0))
	q.collision_mask = MapBuilder.MASK_WORLD
	if not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty():
		return false
	# Must have floor right below.
	var rq := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.5, 0), pos + Vector3(0, -0.6, 0), MapBuilder.MASK_WORLD)
	return not get_world_3d().direct_space_state.intersect_ray(rq).is_empty()


func snap_to_floor(pos: Vector3) -> Vector3:
	var rq := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 1.0, 0), pos + Vector3(0, -40.0, 0), MapBuilder.MASK_WORLD)
	var r := get_world_3d().direct_space_state.intersect_ray(rq)
	if r.is_empty():
		return Vector3(pos.x, 0.0, pos.z)
	var hit: Vector3 = r.position
	return hit


func find_spawn_cluster(center: Vector3, count: int) -> Array:
	var out := []
	var ring := 0
	while out.size() < count and ring < 8:
		var n := maxi(1, ring * 6)
		for i in n:
			var a := TAU * i / n
			var p := center + Vector3(cos(a), 0.0, sin(a)) * ring * 1.3
			p.y = 0.05
			if is_free(p):
				out.append(p)
				if out.size() >= count:
					break
		ring += 1
	while out.size() < count:
		out.append(center + Vector3(randf_range(-2, 2), 0.05, randf_range(-2, 2)))
	return out


func _enemy_eyes(team: int) -> Array:
	var eyes := []
	for id in players:
		var p: Player = players[id]
		if p.team != team and Game.is_alive(id):
			eyes.append(p.global_position + Vector3(0, 1.6, 0))
	return eyes


func _seen_by(pos: Vector3, eyes: Array) -> bool:
	var space := get_world_3d().direct_space_state
	for eye: Vector3 in eyes:
		if eye.distance_to(pos) < 12.0:
			return true
		for h in [1.0, 1.7]:
			var q := PhysicsRayQueryParameters3D.create(eye, pos + Vector3(0, h, 0), MapBuilder.MASK_WORLD)
			if space.intersect_ray(q).is_empty():
				return true
	return false


## Respawn location: near the Runner for the runner's team, near the hunter closest
## to the Runner for hunters - but never in line of sight of an enemy.
func find_respawn(id: int) -> Vector3:
	var team: int = Net.team_of(id)
	var anchor: Vector3 = Game.tag_pos
	var min_d := 6.0
	if Game.holder != 0 and players.has(Game.holder):
		var runner_pos: Vector3 = players[Game.holder].global_position
		if team == Game.holding_team:
			anchor = runner_pos
		else:
			var best := INF
			anchor = runner_pos
			min_d = 25.0
			for pid in players:
				var p: Player = players[pid]
				if pid != id and p.team == team and Game.is_alive(pid):
					var d := p.global_position.distance_to(runner_pos)
					if d < best:
						best = d
						anchor = p.global_position
						min_d = 6.0
	elif Game.phase == Game.Phase.RUSH:
		# Before anyone holds the Tag, respawn near living teammates (or at random).
		for pid in players:
			var p: Player = players[pid]
			if pid != id and p.team == team and Game.is_alive(pid):
				anchor = p.global_position
				break
		min_d = 8.0
	var eyes := _enemy_eyes(team)
	var cands := []
	for sp: Vector3 in builder.spawn_points:
		var d := sp.distance_to(anchor)
		if d >= min_d:
			cands.append([d, sp])
	cands.sort_custom(func(a, b): return a[0] < b[0])
	var checked := 0
	for c in cands:
		var sp: Vector3 = c[1]
		checked += 1
		if checked > 160:
			break
		if not is_free(sp):
			continue
		if _seen_by(sp, eyes):
			continue
		return sp
	# Fallback: the free spawn point furthest from every enemy.
	var best_p: Vector3 = builder.spawn_dots[randi() % builder.spawn_dots.size()]
	var best_score := -1.0
	for sp: Vector3 in builder.spawn_points:
		var nearest := INF
		for e: Vector3 in eyes:
			nearest = minf(nearest, e.distance_to(sp))
		if nearest > best_score and is_free(sp):
			best_score = nearest
			best_p = sp
	return best_p


# ================================================================ RPC: doors & effects

## The player who sent the RPC being handled, or null if it came from this machine.
func _remote_sender() -> Player:
	if not _is_remote_call():
		return null
	return players.get(Net.remote_sender())


func _is_remote_call() -> bool:
	var sid := Net.remote_sender()  # through the host: who really sent it (Net.to_all)
	return sid != 0 and sid != multiplayer.get_unique_id()


## Sent with Net.to_all (runs here too).
func door_rpc(idx: int, target: float, fast: bool) -> void:
	if idx < 0 or idx >= builder.doors.size() or not is_finite(target):
		return
	var d: Door = builder.doors[idx]
	if _is_remote_call():
		var p := _remote_sender()
		if p == null or not p.alive or p.global_position.distance_to(d.global_position) > DOOR_REACH:
			return
		# Per-sender limit: door spam would take over every sound voice.
		var now := Time.get_ticks_msec() / 1000.0
		var key := Vector2i(p.peer_id, idx)  # per door too: a slam can open a double door at once
		if now - float(_door_at.get(key, -100.0)) < DOOR_MIN_GAP:
			return
		_door_at[key] = now
	d.set_target(clampf(target, -Door.OPEN_ANGLE, Door.OPEN_ANGLE), fast)
	Sfx.play_at("door", d.global_position + Vector3(0, 1.2, 0), -2.0 if fast else -8.0, 40.0, 0.8 if fast else 1.0)


## [door index, angle] of every open door, for someone joining mid-match.
func open_doors() -> Array:
	var out := []
	for d: Door in builder.doors:
		if d.is_open():
			out.append([d.idx, d.target])
	return out


func apply_open_doors(doors: Array) -> void:
	for pair: Array in doors:
		if int(pair[0]) >= 0 and int(pair[0]) < builder.doors.size():
			builder.doors[int(pair[0])].set_target(clampf(float(pair[1]), -Door.OPEN_ANGLE, Door.OPEN_ANGLE), true)


## Sent with Net.to_all.
func fx_shot(origin: Vector3, ends: PackedVector3Array, weapon: String) -> void:
	# Only real weapons, a handful of tracers, from where the shooter actually is.
	if not Weapons.DATA.has(weapon) or ends.size() > MAX_SHOT_TRACERS or not origin.is_finite():
		return
	# Near where we see the shooter: their position here lags behind theirs, by a
	# good few metres at full speed (a tighter check made real shots go silent).
	var p := _remote_sender()
	if p == null or not p.alive or p.global_position.distance_to(origin) > FX_SHOT_REACH:
		return
	# No more shot effects than the fastest gun fires (with slack), per shooter: a
	# token bucket, so shots that arrive bunched up after a lag spike all play.
	var sid := p.peer_id
	var now := Time.get_ticks_msec() / 1000.0
	var b: Array = _fx_shot_at.get(sid, [FX_SHOT_BURST, now])
	var tokens := minf(FX_SHOT_BURST, float(b[0]) + (now - float(b[1])) * FX_SHOT_RATE)
	if tokens < 1.0:
		return
	_fx_shot_at[sid] = [tokens - 1.0, now]
	for e in ends:
		if not e.is_finite() or e.distance_to(origin) > 450.0:
			return
	var stats: WeaponStats = Weapons.DATA[weapon]
	if stats.sound_fade_distance > 0.0:
		Sfx.play_loud(weapon, origin, stats.sound_near_db, stats.sound_far_db, stats.sound_fade_distance)
	else:
		Sfx.play_at(weapon, origin, 0.0, FX_SHOT_HEARING, randf_range(0.95, 1.05))
	add_tracers(p.tp_muzzle_pos(origin), ends, weapon)  # from their gun, not the middle of their body


func add_tracers(origin: Vector3, ends: PackedVector3Array, weapon: String) -> void:
	var col := Color(1.0, 0.92, 0.6, 0.9)
	if weapon == "sniper":
		col = Color(1.0, 1.0, 1.0, 1.0)
	for e in ends:
		_tracers.append([origin, e, TRACER_LIFE * (2.5 if weapon == "sniper" else 1.0), col])


func add_impact(pos: Vector3) -> void:
	if _impacts.size() < 64:
		_impacts.append([pos, 0.25])


## Bat finisher: the victim's gun flies where the batter is looking.
func launch_thrown_gun(start: Vector3, dir: Vector3, victim: int) -> void:
	Net.to_all(self, "_fx_projectile", [multiplayer.get_unique_id(), start, dir * 32.0, victim], true, true)


## Sent with Net.to_all (runs here too).
func _fx_projectile(owner_id: int, start: Vector3, vel: Vector3, victim: int) -> void:
	# Only the thrower can launch their own gun, and only a sensible one.
	if _is_remote_call() and Net.remote_sender() != owner_id:
		return
	if not (start.is_finite() and vel.is_finite()) or vel.length() > 60.0 or _projectiles.size() >= MAX_PROJECTILES:
		return
	var thrower := _remote_sender()
	if _is_remote_call() and (thrower == null or not thrower.alive or thrower.global_position.distance_to(start) > 8.0):
		return  # only from a live thrower, near where they are
	# The victim's actual gun (its held, third-person model) tumbles through the air.
	var w: String = Net.players[victim].weapon if Net.players.has(victim) else "ar"
	if not Player.WEAPON_SCENES.has(w) or w == "bat":
		w = "ar"
	var mi: WeaponModel = Player.WEAPON_SCENES[w].instantiate()
	mi.make_third_person()
	mi.rotation = Vector3.ZERO
	add_child(mi)
	mi.global_position = start
	if absf(vel.normalized().y) < 0.99:
		mi.look_at(start + vel, Vector3.UP)
	_projectiles.append({"node": mi, "pos": start, "vel": vel, "owner": owner_id, "life": 3.0, "victim": victim})
	Sfx.play_at("thrown", start, 0.0, 50.0)


# ================================================================ per-frame

func _process(delta: float) -> void:
	_update_tag_visual(delta)
	_update_projectiles(delta)
	_update_grenades(delta)
	_update_uav(delta)
	_draw_fx(delta)
	_update_heartbeat(delta)


# ---- Grenades. Every machine flies them the same way; only the host sets them off.

func add_grenade(gid: int, shooter: int, start: Vector3, vel: Vector3) -> void:
	var node: Node3D = GRENADE_SCENE.instantiate()
	add_child(node)
	node.global_position = start
	_grenades[gid] = {"owner": shooter, "pos": start, "vel": vel, "life": Weapons.DATA.gl.max_life, "node": node}


func _update_grenades(delta: float) -> void:
	var host := multiplayer.is_server()
	var stats: LauncherStats = Weapons.DATA.gl
	var space := get_world_3d().direct_space_state
	for gid: int in _grenades.keys():
		var g: Dictionary = _grenades[gid]
		g.life -= delta
		var old: Vector3 = g.pos
		g.vel += Vector3.DOWN * stats.grenade_gravity * delta
		var nxt: Vector3 = old + g.vel * delta
		# Inside something counts as a hit too: a ray starting there would otherwise see nothing and fly on through.
		var ray := PhysicsRayQueryParameters3D.create(old, nxt, MapBuilder.MASK_WORLD | MapBuilder.L_BOUNCE)
		ray.hit_from_inside = true
		var hit := space.intersect_ray(ray)
		if not hit.is_empty():
			nxt = hit.position + hit.normal * 0.1  # just off the surface, so walls don't block its own blast
			g.vel = Vector3.ZERO
		g.pos = nxt
		g.node.global_position = nxt
		if host and (not hit.is_empty() or g.life <= 0.0 or _enemy_near_grenade(g.owner, nxt, stats.proximity_radius)):
			Game.server_blast(gid, g.owner, nxt)
		elif g.life <= -2.0:  # a client that never heard the blast
			g.node.queue_free()
			_grenades.erase(gid)


func _enemy_near_grenade(shooter: int, pos: Vector3, radius: float) -> bool:
	var team := Net.team_of(shooter)
	for p: Player in players.values():
		if p.alive and p.team != team:
			var c: Vector3 = p.body_point_near(pos)
			if c.distance_to(pos) - Player.RADIUS <= radius:
				return true
	return false


## The host says this grenade went off.
func grenade_blast(gid: int, pos: Vector3) -> void:
	if _grenades.has(gid):
		_grenades[gid].node.queue_free()
		_grenades.erase(gid)
	Sfx.play_at("explosion", pos, 2.0, 160.0)
	var fx: Node3D = EXPLOSION_SCENE.instantiate()
	add_child(fx)
	fx.global_position = pos
	var size: float = Weapons.DATA.gl.blast_radius
	var t := fx.create_tween()
	# Grows to the blast's exact reach and stays there: a player it touches is a player it hit.
	t.tween_property(fx, "scale", Vector3.ONE * size, 0.08).from(Vector3.ONE * size * 0.3)
	t.tween_method(func(a: float) -> void: _fade_fx(fx, a), 0.0, 1.0, 0.25)
	t.tween_callback(fx.queue_free)


func _fade_fx(fx: Node3D, a: float) -> void:
	for c in fx.get_children():
		if c is GeometryInstance3D:
			c.transparency = a


# ---- Warp's afterimage: a light-blue copy of the warper fades where they left.

func add_afterimage(p: Player) -> void:
	var copy := p.body_copy()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Addons.WARP.afterimage_color
	add_child(copy)
	copy.global_transform = p.body_root.global_transform
	_style_copy(copy, mat, null)
	var t := copy.create_tween()
	t.tween_property(mat, "albedo_color:a", 0.0, Addons.WARP.afterimage_time)
	t.tween_callback(copy.queue_free)


## Warp's trail: a streak from where the warper was to where they went.
func add_warp_trail(from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	if length < 0.5:
		return
	var trail: MeshInstance3D = WARP_TRAIL_SCENE.instantiate()
	add_child(trail)
	var along := Basis.looking_at(to - from) * Basis(Vector3.RIGHT, PI * 0.5)
	trail.global_transform = Transform3D(along, (from + to) * 0.5 + Vector3.UP).scaled_local(Vector3(1, length, 1))
	var mat: StandardMaterial3D = trail.material_override.duplicate()  # each trail fades on its own
	mat.albedo_color = Addons.WARP.afterimage_color
	trail.material_override = mat
	var t := trail.create_tween()
	t.tween_property(mat, "albedo_color:a", 0.0, Addons.WARP.afterimage_time)
	t.tween_callback(trail.queue_free)


func _style_copy(n: Node, override_mat: Material, overlay: Material) -> void:
	for c in n.get_children():
		if c is GeometryInstance3D:
			c.transparency = 0.0
			c.material_override = override_mat if override_mat else c.material_override
			c.material_overlay = overlay
		_style_copy(c, override_mat, overlay)


# ---- UAV: pulses from your team reveal enemies where the ring reaches them.

## Sent with Net.to_all. Only the UAV player's team takes any notice.
func uav_pulse(origin: Vector3, last: bool) -> void:
	var p := _remote_sender() if _is_remote_call() else local_player()
	var lp := local_player()
	if p == null or lp == null or p.team != lp.team or p.active != "uav" or not p.alive or not origin.is_finite():
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_uav_pulse_at.get(p.peer_id, -100.0)) < Addons.UAV.pulse_interval * 0.5:
		return  # faster than a real UAV pulses
	_uav_pulse_at[p.peer_id] = now
	_clear_uav_stills()  # outlines last until the next pulse is sent
	_uav_pulses.append({"origin": origin, "r": 0.0, "last": last, "done": {}})
	Sfx.play_at("addon", origin, -2.0, 60.0, 0.7)


func _update_uav(delta: float) -> void:
	var lp := local_player()
	var now := Time.get_ticks_msec() / 1000.0
	for i in range(_uav_pulses.size() - 1, -1, -1):
		var pulse: Dictionary = _uav_pulses[i]
		pulse.r += Addons.UAV.pulse_speed * delta
		for id: int in players:
			var e: Player = players[id]
			if lp == null or e.team == lp.team or not e.alive or pulse.done.has(id):
				continue
			var d: Vector3 = e.global_position - pulse.origin
			if Vector2(d.x, d.z).length() <= pulse.r:
				pulse.done[id] = true
				_uav_reveal(e, pulse.last)
		if pulse.r >= Addons.UAV.max_radius:
			_uav_pulses.remove_at(i)
	for id: int in _uav_stills.keys():
		var until: float = _uav_stills[id].until
		if until >= 0.0 and now > until:
			_uav_stills[id].node.queue_free()
			_uav_stills.erase(id)


func _uav_reveal(e: Player, last: bool) -> void:
	if _uav_stills.has(e.peer_id):
		_uav_stills[e.peer_id].node.queue_free()
	var copy := e.body_copy()
	add_child(copy)
	copy.global_transform = e.body_root.global_transform
	_style_copy(copy, null, Player.SCAN_OUTLINE)
	var until: float = Time.get_ticks_msec() / 1000.0 + Addons.UAV.last_linger if last else -1.0
	_uav_stills[e.peer_id] = {"node": copy, "pos": e.global_position, "until": until}


func _clear_uav_stills() -> void:
	for s: Dictionary in _uav_stills.values():
		s.node.queue_free()
	_uav_stills.clear()


## Where the UAV last saw enemies (the minimap's red dots).
func uav_dots() -> Array:
	return _uav_stills.values().map(func(s: Dictionary) -> Vector3: return s.pos)


func _update_tag_visual(delta: float) -> void:
	update_tag()
	# During the countdown the Tag itself (not its beam) shows through walls, so
	# everyone sees where to go.
	var hl: bool = Game.phase == Game.Phase.PREROUND
	if hl != _tag_highlit:
		_tag_highlit = hl
		var mat: Material = null
		if hl:
			mat = TAG_HIGHLIGHT.duplicate()
			(mat as StandardMaterial3D).albedo_color = Color(Mats.TAG_COLOR, 0.8)
		tag_gem.material_overlay = mat
	if not tag_node.visible:
		return
	var carrier: Player = players.get(Game.holder)
	if carrier:
		# Worn on the back like a backpack (the wearer doesn't see it), fading with a Hider.
		tag_gem.visible = not carrier.is_local
		tag_gem.position.y = TAG_MESH_HEIGHT
		tag_gem.global_rotation = carrier.global_rotation
		tag_gem.transparency = carrier._body_alpha
		tag_light.light_energy = TAG_LIGHT_ENERGY * (1.0 - carrier._body_alpha)
		tag_beam.visible = false
	else:
		tag_gem.visible = true
		tag_gem.rotation.y += delta * 2.0
		tag_gem.position.y = TAG_MESH_HEIGHT + sin(Time.get_ticks_msec() * 0.003) * 0.15
		tag_gem.transparency = 0.0
		tag_light.light_energy = TAG_LIGHT_ENERGY
		tag_beam.visible = Game.phase in [Game.Phase.PREROUND, Game.Phase.RUSH, Game.Phase.DROPPED]


func _update_projectiles(delta: float) -> void:
	if _projectiles.is_empty():
		return
	var space := get_world_3d().direct_space_state
	var me := multiplayer.get_unique_id()
	for i in range(_projectiles.size() - 1, -1, -1):
		var pr: Dictionary = _projectiles[i]
		pr["life"] = float(pr["life"]) - delta
		var old: Vector3 = pr["pos"]
		var vel: Vector3 = pr["vel"] + Vector3(0, -4.0, 0) * delta
		pr["vel"] = vel
		var nxt: Vector3 = old + vel * delta
		var exclude: Array[RID] = []
		if players.has(pr.owner):
			exclude.append(players[pr.owner].get_rid())
		if players.has(pr.victim):
			exclude.append(players[pr.victim].get_rid())
		var q := PhysicsRayQueryParameters3D.create(old, nxt, MapBuilder.MASK_WORLD | MapBuilder.L_PLAYER, exclude)
		var r := space.intersect_ray(q)
		var done: bool = pr.life <= 0.0
		if not r.is_empty():
			done = true
			if r.collider is Player and pr.owner == me:
				var victim: Player = r.collider
				if victim.team != Net.team_of(me):
					Game.report_hit.rpc_id(1, victim.peer_id, Weapons.DATA.bat.thrown_damage, false, "thrown")
			Sfx.play_at("bat_hit", r.position, 0.0, 40.0)
		pr["pos"] = nxt
		var node: Node3D = pr.node
		node.global_position = nxt
		node.rotate_x(delta * 18.0)
		if done:
			node.queue_free()
			_projectiles.remove_at(i)


func _draw_fx(delta: float) -> void:
	_fx_mesh.clear_surfaces()
	for i in range(_tracers.size() - 1, -1, -1):
		_tracers[i][2] -= delta
		if _tracers[i][2] <= 0.0:
			_tracers.remove_at(i)
	for i in range(_impacts.size() - 1, -1, -1):
		_impacts[i][1] -= delta
		if _impacts[i][1] <= 0.0:
			_impacts.remove_at(i)
	if _tracers.is_empty() and _impacts.is_empty() and _uav_pulses.is_empty() and Game.links.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	var cam_pos := cam.global_position if cam else Vector3.ZERO
	_fx_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for t: Array in _tracers:
		_ribbon(t[0], t[1], 0.035, t[3], cam_pos)
	for im: Array in _impacts:
		var p: Vector3 = im[0]
		var s := 0.12
		_ribbon(p - Vector3(0, s, 0), p + Vector3(0, s, 0), s, Color(0.95, 0.85, 0.6, im[1] * 3.0), cam_pos)
	for pulse: Dictionary in _uav_pulses:
		_uav_ring(pulse, cam_pos)
	_draw_links(cam_pos)
	_fx_mesh.surface_end()


func _ribbon(a: Vector3, b: Vector3, w: float, col: Color, cam_pos: Vector3) -> void:
	var dir := (b - a)
	if dir.length() < 0.001:
		return
	var to_cam := (cam_pos - a).normalized()
	var side := dir.cross(to_cam).normalized() * w
	if side == Vector3.ZERO:
		side = Vector3(w, 0, 0)
	_fx_mesh.surface_set_color(col)
	_fx_mesh.surface_add_vertex(a - side)
	_fx_mesh.surface_add_vertex(a + side)
	_fx_mesh.surface_add_vertex(b + side)
	_fx_mesh.surface_add_vertex(a - side)
	_fx_mesh.surface_add_vertex(b + side)
	_fx_mesh.surface_add_vertex(b - side)


## A UAV pulse's growing ring, fading as it reaches its full size.
func _uav_ring(pulse: Dictionary, cam_pos: Vector3) -> void:
	var col := Color(1.0, 0.25, 0.2, 0.7 * (1.0 - pulse.r / Addons.UAV.max_radius))
	var c: Vector3 = pulse.origin + Vector3(0, 0.3, 0)
	for i in UAV_RING_SEGMENTS:
		var a := TAU * i / UAV_RING_SEGMENTS
		var b := TAU * (i + 1) / UAV_RING_SEGMENTS
		_ribbon(c + Vector3(cos(a), 0, sin(a)) * pulse.r, c + Vector3(cos(b), 0, sin(b)) * pulse.r, 0.12, col, cam_pos)


## Interlink: a thin line between linked teammates (only their team sees it).
func _draw_links(cam_pos: Vector3) -> void:
	var lp := local_player()
	if lp == null:
		return
	for a: int in Game.links:
		var b: int = Game.links[a]
		if a < b and players.has(a) and players.has(b) and players[a].team == lp.team:
			var chest := Vector3(0, 1.2, 0)
			var col := Mats.team_color(lp.team).lightened(0.3)
			col.a = 0.8
			_ribbon(players[a].global_position + chest, players[b].global_position + chest, 0.025, col, cam_pos)


func _update_heartbeat(delta: float) -> void:
	var lp := local_player()
	if lp == null or not lp.alive or Game.holder == 0 or not players.has(Game.holder):
		return
	var runner: Player = players[Game.holder]
	if runner.team == lp.team:
		return
	var d := runner.global_position.distance_to(lp.global_position)
	if d > HEARTBEAT_RANGE:
		return
	_hb_timer -= delta
	if _hb_timer <= 0.0:
		var k := d / HEARTBEAT_RANGE
		_hb_timer = lerpf(0.45, 1.15, k)
		Sfx.play_at("heartbeat", runner.global_position + Vector3(0, 1.2, 0), lerpf(6.0, -6.0, k), HEARTBEAT_RANGE + 5.0)


# ================================================================ sprays

const SPRAY_SIZE := 1.3
const FX_SHOT_RATE := 30.0     # shot effects a second per shooter (the fastest gun fires 14)...
const FX_SHOT_BURST := 10.0    # ...and how many may arrive at once
const FX_SHOT_REACH := 20.0    # m between where a shot starts and where we see the shooter
const FX_SHOT_HEARING := 220.0 # m gunfire carries (the sniper 40% further): you hear what can kill you
var _fx_shot_at := {}    # shooter id -> [tokens, time] for shot effects
const DOOR_MIN_GAP := 0.1
var _door_at := {}       # (peer id, door) -> time of the last update
var _spray_nodes := {}   # peer id -> MeshInstance3D (one spray per player)
var _spray_last := {}    # server: peer id -> time of last spray


@rpc("any_peer", "call_local", "reliable")
func request_spray(pos: Vector3, normal: Vector3, up: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var id: int = Net.sender()
	var now := Time.get_ticks_msec() / 1000.0
	if not Net.sprays.has(id) or not Game.is_alive(id) or not players.has(id):
		return
	if now - float(_spray_last.get(id, -100.0)) < Player.SPRAY_COOLDOWN - 0.25:
		return
	if not (pos.is_finite() and normal.is_finite() and up.is_finite()) or normal.length() < 0.5:
		return
	if players[id].global_position.distance_to(pos) > Player.SPRAY_REACH + 3.0:
		return
	_spray_last[id] = now
	_spray_placed.rpc(id, pos, normal.normalized(), up.normalized())


# ================================================================ pings

@rpc("any_peer", "call_local", "reliable")
func request_ping(pos: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var id: int = Net.sender()
	if not pos.is_finite() or not Game.is_alive(id) or not players.has(id):
		return
	if players[id].global_position.distance_to(pos) > Player.PING_RANGE + 5.0:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if float(_ping_locks.get(id, 0.0)) > now:
		_ping_refused.rpc_id(id, float(_ping_locks[id]) - now)
		return
	var recent: Array = _ping_times.get(id, []).filter(func(t: float) -> bool: return now - t < PING_BURST_TIME)
	if recent.size() >= PING_BURST:
		_ping_locks[id] = now + PING_COOLDOWN
		_ping_times[id] = []
		_ping_refused.rpc_id(id, PING_COOLDOWN)
		return
	recent.append(now)
	_ping_times[id] = recent
	var team := Net.team_of(id)
	for pid in Net.players:
		if Net.team_of(pid) == team:
			_show_ping.rpc_id(pid, pos)


@rpc("authority", "call_local", "reliable")
func _show_ping(pos: Vector3) -> void:
	pings.append({"pos": pos, "until": Time.get_ticks_msec() / 1000.0 + PING_SECONDS})
	Sfx.play("ping", -4.0)


@rpc("authority", "call_local", "reliable")
func _ping_refused(seconds: float) -> void:
	Game.announce.emit("Ping on cooldown: %d s" % ceili(seconds), UiKit.MUTED)



## A player's spray was cleared (they left): remove the one they placed.
func _on_spray_updated(id: int) -> void:
	if Net.sprays.has(id):
		return
	var mi: MeshInstance3D = _spray_nodes.get(id)
	_spray_nodes.erase(id)
	if mi and is_instance_valid(mi):
		mi.queue_free()


@rpc("authority", "call_local", "reliable")
func _spray_placed(id: int, pos: Vector3, normal: Vector3, up: Vector3) -> void:
	var tex: Texture2D = Net.spray_texture(id)
	if tex == null:
		return
	var mi: MeshInstance3D = _spray_nodes.get(id)
	if mi == null or not is_instance_valid(mi):
		# assets/models/spray_decal.tscn: a quad (its own copy, resized below) with
		# the decal material from the scene, copied so each player has their image.
		mi = SPRAY_SCENE.instantiate()
		mi.material_override = mi.material_override.duplicate()
		add_child(mi)
		_spray_nodes[id] = mi
	var aspect := float(tex.get_width()) / maxf(1.0, tex.get_height())
	(mi.mesh as QuadMesh).size = Vector2(SPRAY_SIZE * minf(aspect, 1.0) if aspect < 1.0 else SPRAY_SIZE, SPRAY_SIZE / aspect if aspect > 1.0 else SPRAY_SIZE)
	(mi.material_override as StandardMaterial3D).albedo_texture = tex
	var z := normal
	var x := up.cross(z)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	var y := z.cross(x).normalized()
	mi.global_transform = Transform3D(Basis(x, y, z), pos + normal * 0.02)
	Sfx.play_at("spray", pos, -2.0, 25.0)
