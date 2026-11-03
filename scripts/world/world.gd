class_name World
extends Node3D
## The in-match world: map, players, Tag, effects and spawn logic.
## Lives at /root/Main/World on every peer so RPC paths match.

const HEARTBEAT_RANGE := 25.0
const TRACER_LIFE := 0.07
const MAX_TRAIL_POINTS := 64

var builder: MapBuilder
var players := {}  # peer id -> Player
var players_node: Node3D
var env: WorldEnvironment
var sun: DirectionalLight3D

var tag_node: Node3D
var tag_beam: MeshInstance3D
var tag_gem: MeshInstance3D

var _fx_mesh: ImmediateMesh
var _fx_inst: MeshInstance3D
var _tracers: Array = []   # [from, to, life, color]
var _impacts: Array = []   # [pos, life]
var _trail_mesh: ImmediateMesh
var _trail_inst: MeshInstance3D
var _trails := {}          # id -> PackedVector3Array
var _projectiles: Array = []
var _hb_timer := 0.0


func _ready() -> void:
	name = "World"
	_build_environment()
	builder = MapBuilder.new()
	builder.build(self)
	players_node = Node3D.new()
	players_node.name = "Players"
	add_child(players_node)
	_build_tag()
	_build_fx()
	Game.world = self
	Net.roster_changed.connect(sync_players)
	Settings.changed.connect(_apply_settings)
	sync_players()
	_apply_settings()


func _exit_tree() -> void:
	if Game.world == self:
		Game.world = null


# ================================================================ setup

func _build_environment() -> void:
	env = WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("5b8fd0")
	sm.sky_horizon_color = Color("cfe3f2")
	sm.ground_bottom_color = Color("6f7f5a")
	sm.ground_horizon_color = Color("cfe3f2")
	sm.sun_angle_max = 20.0
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.75
	e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_white = 6.0
	e.fog_enabled = true
	e.fog_light_color = Color("cfe3f2")
	e.fog_density = 0.0025
	e.fog_aerial_perspective = 0.3
	e.adjustment_enabled = true
	env.environment = e
	add_child(env)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	sun.light_energy = 1.25
	sun.light_color = Color("fff1dc")
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 70.0
	sun.shadow_blur = 1.0
	add_child(sun)


func _apply_settings() -> void:
	if env and env.environment:
		env.environment.adjustment_brightness = float(Settings.g("brightness"))
	if sun:
		sun.shadow_enabled = bool(Settings.g("shadows"))


func _build_tag() -> void:
	tag_node = Node3D.new()
	tag_node.name = "Tag"
	add_child(tag_node)
	tag_gem = MeshInstance3D.new()
	var gm := SphereMesh.new()
	gm.radius = 0.45
	gm.height = 0.9
	gm.radial_segments = 4
	gm.rings = 2
	tag_gem.mesh = gm
	tag_gem.material_override = Mats.glow(Mats.TAG_COLOR)
	tag_gem.position.y = 1.0
	tag_node.add_child(tag_gem)
	var base := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = Game.PICKUP_RADIUS
	bm.bottom_radius = Game.PICKUP_RADIUS
	bm.height = 0.04
	bm.radial_segments = 24
	base.mesh = bm
	base.material_override = Mats.glow(Mats.TAG_COLOR, 0.35)
	base.position.y = 0.06
	tag_node.add_child(base)
	tag_beam = MeshInstance3D.new()
	var beam := CylinderMesh.new()
	beam.top_radius = 0.25
	beam.bottom_radius = 0.25
	beam.height = 60.0
	beam.radial_segments = 8
	beam.cap_top = false
	beam.cap_bottom = false
	tag_beam.mesh = beam
	tag_beam.material_override = Mats.glow(Mats.TAG_COLOR, 0.25)
	tag_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tag_beam.position.y = 30.0
	tag_node.add_child(tag_beam)
	tag_node.visible = false


func _build_fx() -> void:
	_fx_mesh = ImmediateMesh.new()
	_fx_inst = MeshInstance3D.new()
	_fx_inst.mesh = _fx_mesh
	_fx_inst.material_override = Mats.vertex_unshaded(false)
	_fx_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_fx_inst)
	_trail_mesh = ImmediateMesh.new()
	_trail_inst = MeshInstance3D.new()
	_trail_inst.mesh = _trail_mesh
	_trail_inst.material_override = Mats.vertex_unshaded(false)  # depth-tested: hidden behind geometry
	_trail_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_trail_inst)


# ================================================================ players

func sync_players() -> void:
	for id in Net.players:
		if not players.has(id):
			var p := Player.new()
			p.setup(id, Net.players[id])
			players_node.add_child(p)
			players[id] = p
			p.set_alive(Game.is_alive(id))
		else:
			var p: Player = players[id]
			if not p.alive:
				p.refresh_loadout()
	for id in players.keys():
		if not Net.players.has(id):
			players[id].queue_free()
			players.erase(id)
			_trails.erase(id)


func local_player() -> Player:
	return players.get(multiplayer.get_unique_id())


func on_round_begin(_obj: int) -> void:
	_trails.clear()
	for p in _projectiles:
		p.node.queue_free()
	_projectiles.clear()
	update_tag()


func update_tag() -> void:
	var show_tag: bool = Game.holder == 0 and Game.objective >= 0 and Game.phase in [Game.Phase.PREROUND, Game.Phase.RUSH, Game.Phase.DROPPED]
	tag_node.visible = show_tag
	if show_tag:
		tag_node.global_position = Game.tag_pos


# ================================================================ spawning (server)

func is_free(pos: Vector3) -> bool:
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

@rpc("any_peer", "call_local", "reliable")
func door_rpc(idx: int, target: float, fast: bool) -> void:
	if idx < 0 or idx >= builder.doors.size():
		return
	var d: Door = builder.doors[idx]
	d.set_target(target, fast)
	Sfx.play_at("door", d.global_position + Vector3(0, 1.2, 0), -2.0 if fast else -8.0, 40.0, 0.8 if fast else 1.0)


@rpc("any_peer", "call_remote", "unreliable")
func fx_shot(origin: Vector3, ends: PackedVector3Array, weapon: String) -> void:
	Sfx.play_at(weapon, origin, 0.0, 140.0 if weapon == "sniper" else 90.0, randf_range(0.95, 1.05))
	add_tracers(origin, ends, weapon)


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
	_fx_projectile.rpc(multiplayer.get_unique_id(), start, dir * 32.0, victim)


@rpc("any_peer", "call_local", "reliable")
func _fx_projectile(owner_id: int, start: Vector3, vel: Vector3, victim: int) -> void:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(0.12, 0.16, 0.7)
	mi.mesh = m
	mi.material_override = Mats.toon(Color("2f3236"))
	add_child(mi)
	mi.global_position = start
	_projectiles.append({"node": mi, "pos": start, "vel": vel, "owner": owner_id, "life": 3.0, "victim": victim})
	Sfx.play_at("thrown", start, 0.0, 50.0)


# ================================================================ per-frame

func _process(delta: float) -> void:
	_update_tag_visual(delta)
	_update_projectiles(delta)
	_draw_fx(delta)
	_update_trails()
	_update_heartbeat(delta)


func _update_tag_visual(delta: float) -> void:
	update_tag()
	if tag_node.visible:
		tag_gem.rotation.y += delta * 2.0
		tag_gem.position.y = 1.0 + sin(Time.get_ticks_msec() * 0.003) * 0.15
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
					Game.report_hit.rpc_id(1, victim.peer_id, Weapons.THROWN_DAMAGE, false, "thrown")
			Sfx.play_at("bat_hit", r.position, 0.0, 40.0)
		pr["pos"] = nxt
		var node: MeshInstance3D = pr.node
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
	if _tracers.is_empty() and _impacts.is_empty():
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


## Stalker addon: red ground trails behind every enemy, fading 15 m behind them.
func _update_trails() -> void:
	_trail_mesh.clear_surfaces()
	var lp := local_player()
	if lp == null:
		return
	for id in players:
		var p: Player = players[id]
		if p.team == lp.team or not p.alive:
			_trails.erase(id)
			continue
		var pos := p.global_position + Vector3(0, 0.08, 0)
		var tr: PackedVector3Array = _trails.get(id, PackedVector3Array())
		if tr.size() > 0 and tr[tr.size() - 1].distance_to(pos) > 6.0:
			tr = PackedVector3Array()  # teleported (respawn)
		if tr.is_empty() or tr[tr.size() - 1].distance_to(pos) > 0.35:
			tr.append(pos)
		# Trim to the configured length.
		var total := 0.0
		var keep_from := 0
		for i in range(tr.size() - 1, 0, -1):
			total += tr[i].distance_to(tr[i - 1])
			if total > Addons.STALKER_TRAIL:
				keep_from = i
				break
		if keep_from > 0:
			tr = tr.slice(keep_from)
		if tr.size() > MAX_TRAIL_POINTS:
			tr = tr.slice(tr.size() - MAX_TRAIL_POINTS)
		_trails[id] = tr
	if lp.addon != "stalker" or not lp.alive:
		return
	var any := false
	for id in _trails:
		if (_trails[id] as PackedVector3Array).size() >= 2:
			any = true
	if not any:
		return
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for id in _trails:
		var tr: PackedVector3Array = _trails[id]
		var n := tr.size()
		for i in range(1, n):
			var a := tr[i - 1]
			var b := tr[i]
			var d := b - a
			d.y = 0.0
			if d.length() < 0.01:
				continue
			var side := Vector3(-d.z, 0.0, d.x).normalized() * 0.22
			var alpha_a := float(i - 1) / n * 0.8
			var alpha_b := float(i) / n * 0.8
			var ca := Color(1.0, 0.15, 0.1, alpha_a)
			var cb := Color(1.0, 0.15, 0.1, alpha_b)
			_trail_mesh.surface_set_color(ca)
			_trail_mesh.surface_add_vertex(a - side)
			_trail_mesh.surface_set_color(ca)
			_trail_mesh.surface_add_vertex(a + side)
			_trail_mesh.surface_set_color(cb)
			_trail_mesh.surface_add_vertex(b + side)
			_trail_mesh.surface_set_color(ca)
			_trail_mesh.surface_add_vertex(a - side)
			_trail_mesh.surface_set_color(cb)
			_trail_mesh.surface_add_vertex(b + side)
			_trail_mesh.surface_set_color(cb)
			_trail_mesh.surface_add_vertex(b - side)
	_trail_mesh.surface_end()


## Hunters near the Runner hear a heartbeat that speeds up as they close in.
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
