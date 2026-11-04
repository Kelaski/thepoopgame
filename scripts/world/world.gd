class_name World
extends Node3D
## The in-match world: map, players, Tag, effects and spawn logic.
## Lives at /root/Main/World on every peer so RPC paths match.

const HEARTBEAT_RANGE := 25.0
const TRACER_LIFE := 0.07
const MAX_TRAIL_POINTS := 400  # ~6 s of points even at full slide speed
const TRAIL_WIDTH := 0.34      # half-width in metres

const PLAYER_SCENE := preload("res://assets/models/player.tscn")
const TAG_SCENE := preload("res://assets/models/tag.tscn")
const TAG_HIGHLIGHT := preload("res://assets/materials/tag_highlight.tres")
const SPRAY_SCENE := preload("res://assets/models/spray_decal.tscn")
const PING_SCENE := preload("res://assets/models/ping_marker.tscn")
## Ping kinds: [title shown on the marker, lifetime in seconds]
const PING_KINDS := {
	"spot": ["", 6.0],
	"enemy": ["ENEMY", 4.5],
	"danger": ["DANGER", 6.0],
	"tag": ["TAG", 6.0],
}
const PING_DANGER := Color("ff4a3a")
const PING_SPOT := Color("ffe14a")   # a plain (single tap) ping is yellow
const PINGS_PER_PLAYER := 3     # older pings from the same player disappear
const PING_BURST := 5           # at most this many pings...
const PING_BURST_TIME := 3.0    # ...per this many seconds (server-side spam limit)
const DOOR_REACH := 9.0         # a remote player must be this close to move a door
const MAX_SHOT_TRACERS := 16    # shotgun pellets are 13
const MAX_PROJECTILES := 12
const FX_TRACERS_MAT := preload("res://assets/materials/fx_tracers.tres")  # bullet tracers + impacts
const FX_TRAILS_MAT := preload("res://assets/materials/fx_trails.tres")    # Stalker trails
## Times of day (same order as Game.TIMES_OF_DAY). top / horizon tint the sky
## colours from Customization; sky scales the sky's brightness; night turns on the
## street lamps' lights (0 = off, 1 = full).
const TIMES := [
	{"pitch": -16.0, "yaw": -115.0, "sun": Color("ffd2a0"), "energy": 0.95, "ambient": 0.6,
		"top": Color(0.85, 0.9, 1.0), "horizon": Color(1.12, 0.95, 0.85), "sky": 0.85, "night": 0.0},
	{"pitch": -52.0, "yaw": -38.0, "sun": Color("fff1dc"), "energy": 1.25, "ambient": 0.75,
		"top": Color(1, 1, 1), "horizon": Color(1, 1, 1), "sky": 1.0, "night": 0.0},
	{"pitch": -9.0, "yaw": 65.0, "sun": Color("ff9a5a"), "energy": 0.8, "ambient": 0.5,
		"top": Color(0.62, 0.55, 0.85), "horizon": Color(1.3, 0.78, 0.55), "sky": 0.7, "night": 0.6},
	{"pitch": -40.0, "yaw": 150.0, "sun": Color("9fb2ff"), "energy": 0.3, "ambient": 0.32,
		"top": Color(0.1, 0.12, 0.26), "horizon": Color(0.2, 0.22, 0.36), "sky": 0.3, "night": 1.0},
]
const TOD_BLEND_TIME := 10.0  # seconds to blend into a new time of day
const GROUND_BOTTOM := Color("6f7f5a")
## Shadow quality (Settings > Video): [splits, max distance in m, shadow map size].
## More splits keep near shadows sharp while the far edge reaches further out.
const SHADOW_QUALITY := [
	[2, 70.0, 2048],    # Low
	[4, 130.0, 4096],   # Medium
	[4, 220.0, 4096],   # High
	[4, 320.0, 8192],   # Ultra
]
var builder: MapBuilder
var pings: Array = []   # [owner id, kind, PingMarker] for your team, oldest first
var _ping_times := {}   # server: id -> recent ping times
var players := {}  # peer id -> Player
var players_node: Node3D
var env: WorldEnvironment
var sun: DirectionalLight3D
var _proc_sky: ProceduralSkyMaterial
var _pano_sky: PanoramaSkyMaterial
var _tod := {}       # current (blended) time-of-day values
var _tod_from := {}
var _tod_t := 1.0     # 0..1 through the blend

var tag_node: Node3D
var tag_beam: MeshInstance3D
var tag_gem: MeshInstance3D
var _tag_highlit := false  # the countdown's see-through-walls highlight is on

var _fx_mesh: ImmediateMesh
var _fx_inst: MeshInstance3D
var _tracers: Array = []   # [from, to, life, color]
var _impacts: Array = []   # [pos, life]
var _trail_mesh: ImmediateMesh
var _trail_inst: MeshInstance3D
var _trails := {}          # id -> PackedVector3Array
var _trail_times := {}     # id -> PackedFloat64Array (when each trail point was laid)
var _projectiles: Array = []
var _hb_timer := 0.0


func _ready() -> void:
	name = "World"
	_build_environment()
	builder = MapBuilder.new()
	builder.build(self, Game.map_size, Game.map_seed)
	players_node = Node3D.new()
	players_node.name = "Players"
	add_child(players_node)
	_build_tag()
	_build_fx()
	Game.world = self
	Net.roster_changed.connect(sync_players)
	Settings.changed.connect(_apply_settings)
	Settings.colors_changed.connect(_apply_colors)
	Game.time_of_day_changed.connect(_on_time_of_day_changed)
	Net.spray_updated.connect(_on_spray_updated)
	sync_players()
	_apply_settings()
	_apply_colors()


func _exit_tree() -> void:
	if Game.world == self:
		Game.world = null


# ================================================================ setup

func _build_environment() -> void:
	env = WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.ground_bottom_color = Color("6f7f5a")
	sm.sun_angle_max = 20.0
	sky.sky_material = sm
	_proc_sky = sm
	_pano_sky = PanoramaSkyMaterial.new()
	_pano_sky.filter = true
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.75
	e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_white = 6.0
	e.fog_enabled = true

	e.fog_density = 0.0025
	e.fog_aerial_perspective = 0.3
	e.adjustment_enabled = true
	# Bloom only catches the over-bright glowing parts (bulbs, screens, neon).
	e.glow_intensity = 0.7
	e.glow_bloom = 0.0
	e.glow_hdr_threshold = 2.0
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.environment = e
	add_child(env)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	sun.light_energy = 1.25
	sun.light_color = Color("fff1dc")
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_fade_start = 0.9
	sun.shadow_blur = 1.0
	add_child(sun)
	_tod = TIMES[clampi(Game.time_of_day, 0, TIMES.size() - 1)].duplicate()
	_tod_from = _tod.duplicate()
	_apply_time_of_day()


## Sky and fog colours follow the colour customization live.
func _apply_colors() -> void:
	var top := _tinted(Palette.get_color("sky_top"), _tod.get("top", Color.WHITE))
	var horizon := _tinted(Palette.get_color("sky_horizon"), _tod.get("horizon", Color.WHITE))
	var sky: float = _tod.get("sky", 1.0)
	if _proc_sky:
		_proc_sky.sky_top_color = top
		_proc_sky.sky_horizon_color = horizon
		_proc_sky.ground_horizon_color = horizon
		_proc_sky.ground_bottom_color = GROUND_BOTTOM * sky
		_proc_sky.energy_multiplier = sky
	if _pano_sky:
		_pano_sky.energy_multiplier = float(Settings.g("sky_energy")) * sky
	if env and env.environment:
		env.environment.fog_light_color = horizon


static func _tinted(c: Color, t: Color) -> Color:
	return Color(c.r * t.r, c.g * t.g, c.b * t.b)


func _on_time_of_day_changed() -> void:
	_tod_from = _tod.duplicate()
	_tod_t = 0.0


func _update_time_of_day(delta: float) -> void:
	if _tod_t >= 1.0:
		return
	_tod_t = minf(1.0, _tod_t + delta / TOD_BLEND_TIME)
	var k := smoothstep(0.0, 1.0, _tod_t)
	var target: Dictionary = TIMES[clampi(Game.time_of_day, 0, TIMES.size() - 1)]
	for key: String in target:
		var a: Variant = _tod_from[key]
		var b: Variant = target[key]
		if key == "yaw":
			_tod[key] = rad_to_deg(lerp_angle(deg_to_rad(a), deg_to_rad(b), k))
		else:
			_tod[key] = lerp(a, b, k)
	_apply_time_of_day()


## Sun, ambient light, sky and street lamps for the current blended time of day.
func _apply_time_of_day() -> void:
	if sun:
		sun.rotation_degrees = Vector3(_tod.pitch, _tod.yaw, 0.0)
		sun.light_color = _tod.sun
		sun.light_energy = _tod.energy
	if env and env.environment:
		env.environment.ambient_light_energy = _tod.ambient
	_apply_colors()
	_apply_night_lights()

## Uses the player's custom skybox (an equirectangular panorama) when enabled and
## present, otherwise the generated sky. Updates live from the Skybox menu.
func _apply_sky() -> void:
	if env == null or env.environment == null or env.environment.sky == null:
		return
	var tex: Texture2D = null
	if Settings.g("sky_custom"):
		tex = UserImages.texture(UserImages.SKYBOX)
	var e := env.environment
	if tex:
		_pano_sky.panorama = tex
		_pano_sky.energy_multiplier = float(Settings.g("sky_energy"))
		e.sky.sky_material = _pano_sky
		_pano_sky.energy_multiplier *= float(_tod.get("sky", 1.0))
		e.sky_rotation = Vector3(0.0, deg_to_rad(float(Settings.g("sky_rotation"))), 0.0)
	else:
		e.sky.sky_material = _proc_sky
		e.sky_rotation = Vector3.ZERO


func _apply_settings() -> void:
	_apply_sky()
	if env and env.environment:
		env.environment.adjustment_brightness = float(Settings.g("brightness"))
		env.environment.glow_enabled = bool(Settings.g("bloom"))
	if sun:
		sun.shadow_enabled = bool(Settings.g("shadows"))
		var sq: Array = SHADOW_QUALITY[clampi(int(Settings.g("shadow_quality")), 0, SHADOW_QUALITY.size() - 1)]
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if sq[0] == 4 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_max_distance = sq[1]
		RenderingServer.directional_shadow_atlas_set_size(sq[2], true)
	_apply_lights()


## Interior lights: Off hides them, Low keeps every other lamp lit with a shorter
## reach, High lights them all. Lights fade out with distance either way.
func _apply_lights() -> void:
	if builder == null:
		return
	var q := int(Settings.g("interior_lights"))
	for i in builder.lights.size():
		var l: OmniLight3D = builder.lights[i]
		l.visible = q == 2 or (q == 1 and i % 2 == 0)
		l.distance_fade_begin = 60.0 if q == 2 else 30.0
	_apply_night_lights()


## Street lamps light up in the evening and at night (they follow the Interior
## lights setting too: Off turns them off, Low keeps every other one).
func _apply_night_lights() -> void:
	if builder == null:
		return
	var q := int(Settings.g("interior_lights"))
	var night: float = _tod.get("night", 0.0)
	for i in builder.night_lights.size():
		var l: OmniLight3D = builder.night_lights[i]
		l.visible = night > 0.02 and (q == 2 or (q == 1 and i % 2 == 0))
		l.light_energy = float(l.get_meta("energy", 1.0)) * night

## The Tag (assets/models/tag.tscn): Gem, PickupRing and Beam, tinted with the
## Tag colour (which players can customize) at load.
func _build_tag() -> void:
	tag_node = TAG_SCENE.instantiate()
	tag_node.name = "Tag"
	add_child(tag_node)
	tag_gem = tag_node.get_node("Gem")
	tag_beam = tag_node.get_node("Beam")
	tag_gem.material_override = Mats.glow(Mats.TAG_COLOR)
	var ring := tag_node.get_node_or_null("PickupRing") as GeometryInstance3D
	if ring:
		ring.material_override = Mats.glow(Mats.TAG_COLOR, 0.35)
	tag_beam.material_override = Mats.glow(Mats.TAG_COLOR, 0.25)
	tag_node.visible = false


func _build_fx() -> void:
	_fx_mesh = ImmediateMesh.new()
	_fx_inst = MeshInstance3D.new()
	_fx_inst.mesh = _fx_mesh
	_fx_inst.material_override = FX_TRACERS_MAT
	_fx_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_fx_inst)
	_trail_mesh = ImmediateMesh.new()
	_trail_inst = MeshInstance3D.new()
	_trail_inst.mesh = _trail_mesh
	_trail_inst.material_override = FX_TRAILS_MAT  # depth-tested: hidden behind geometry
	_trail_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_trail_inst)


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
			_trails.erase(id)
			_trail_times.erase(id)


func local_player() -> Player:
	return players.get(multiplayer.get_unique_id())


func on_round_begin(_obj: int) -> void:
	for p in pings.duplicate():
		_remove_ping(p)
	_trails.clear()
	_trail_times.clear()
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
	return players.get(multiplayer.get_remote_sender_id())


func _is_remote_call() -> bool:
	var sid := multiplayer.get_remote_sender_id()
	return sid != 0 and sid != multiplayer.get_unique_id()


@rpc("any_peer", "call_local", "reliable")
func door_rpc(idx: int, target: float, fast: bool) -> void:
	if idx < 0 or idx >= builder.doors.size() or not is_finite(target):
		return
	var d: Door = builder.doors[idx]
	if _is_remote_call():
		var p := _remote_sender()
		if p == null or not p.alive or p.global_position.distance_to(d.global_position) > DOOR_REACH:
			return
	d.set_target(clampf(target, -Door.OPEN_ANGLE, Door.OPEN_ANGLE), fast)
	Sfx.play_at("door", d.global_position + Vector3(0, 1.2, 0), -2.0 if fast else -8.0, 40.0, 0.8 if fast else 1.0)


@rpc("any_peer", "call_remote", "unreliable")
func fx_shot(origin: Vector3, ends: PackedVector3Array, weapon: String) -> void:
	# Only real weapons, a handful of tracers, from where the shooter actually is.
	if not Weapons.DATA.has(weapon) or ends.size() > MAX_SHOT_TRACERS or not origin.is_finite():
		return
	var p := _remote_sender()
	if p == null or not p.alive or p.global_position.distance_to(origin) > 6.0:
		return
	for e in ends:
		if not e.is_finite() or e.distance_to(origin) > 450.0:
			return
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
	# Only the thrower can launch their own gun, and only a sensible one.
	if _is_remote_call() and multiplayer.get_remote_sender_id() != owner_id:
		return
	if not (start.is_finite() and vel.is_finite()) or vel.length() > 60.0 or _projectiles.size() >= MAX_PROJECTILES:
		return
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
	_update_time_of_day(delta)
	_update_tag_visual(delta)
	_update_projectiles(delta)
	_draw_fx(delta)
	_update_trails()
	_update_heartbeat(delta)
	_update_stalker_scan()


## Stalker's ability: while it runs, every other player is outlined through walls
## (only on the Stalker's own screen).
func _update_stalker_scan() -> void:
	var lp := local_player()
	var scanning := lp != null and lp.alive and lp.addon == "stalker" and lp.addon_active > 0.0
	for id in players:
		var p: Player = players[id]
		if p != lp:
			p.set_scan_outline(scanning and p.alive)


func _update_tag_visual(delta: float) -> void:
	update_tag()
	# During the countdown the Tag shows through walls, so everyone sees where to go.
	var hl: bool = Game.phase == Game.Phase.PREROUND
	if hl != _tag_highlit:
		_tag_highlit = hl
		var mat: Material = null
		if hl:
			mat = TAG_HIGHLIGHT.duplicate()
			(mat as StandardMaterial3D).albedo_color = Color(Mats.TAG_COLOR, 0.8)
		tag_gem.material_overlay = mat
		tag_beam.material_overlay = mat
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


## Stalker addon: wide red ground trails behind every enemy. Each piece of trail
## lingers for Addons.STALKER_TRAIL_TIME seconds, fading as it ages.
func _update_trails() -> void:
	_trail_mesh.clear_surfaces()
	var lp := local_player()
	if lp == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	for id in players:
		var p: Player = players[id]
		if p.team == lp.team or not p.alive:
			_trails.erase(id)
			_trail_times.erase(id)
			continue
		var pos := p.global_position + Vector3(0, 0.08, 0)
		var tr: PackedVector3Array = _trails.get(id, PackedVector3Array())
		var times: PackedFloat64Array = _trail_times.get(id, PackedFloat64Array())
		if tr.size() > 0 and tr[tr.size() - 1].distance_to(pos) > 6.0:
			tr = PackedVector3Array()  # teleported (respawn)
			times = PackedFloat64Array()
		if tr.is_empty() or tr[tr.size() - 1].distance_to(pos) > 0.35:
			tr.append(pos)
			times.append(now)
		# Drop points older than the linger time (and cap the point count).
		var keep_from := 0
		while keep_from < times.size() and now - times[keep_from] > Addons.STALKER_TRAIL_TIME:
			keep_from += 1
		keep_from = maxi(keep_from, tr.size() - MAX_TRAIL_POINTS)
		if keep_from > 0:
			tr = tr.slice(keep_from)
			times = times.slice(keep_from)
		_trails[id] = tr
		_trail_times[id] = times
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
		var times: PackedFloat64Array = _trail_times[id]
		var n := tr.size()
		for i in range(1, n):
			var a := tr[i - 1]
			var b := tr[i]
			var d := b - a
			d.y = 0.0
			if d.length() < 0.01:
				continue
			var side := Vector3(-d.z, 0.0, d.x).normalized() * TRAIL_WIDTH
			var alpha_a := clampf(1.0 - (now - times[i - 1]) / Addons.STALKER_TRAIL_TIME, 0.0, 1.0) * 0.85
			var alpha_b := clampf(1.0 - (now - times[i]) / Addons.STALKER_TRAIL_TIME, 0.0, 1.0) * 0.85
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


# ================================================================ sprays

const SPRAY_SIZE := 1.3
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
func request_ping(pos: Vector3, kind: String) -> void:
	if not multiplayer.is_server():
		return
	var id: int = Net.sender()
	if not PING_KINDS.has(kind) or not pos.is_finite() or not Game.is_alive(id) or not players.has(id):
		return
	if players[id].global_position.distance_to(pos) > Player.PING_RANGE + 5.0:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var recent: Array = _ping_times.get(id, [])
	recent = recent.filter(func(t: float) -> bool: return now - t < PING_BURST_TIME)
	if recent.size() >= PING_BURST + (1 if kind == "danger" else 0):
		return  # one extra slot so a double tap's danger ping still gets through
	recent.append(now)
	_ping_times[id] = recent
	var team := Net.team_of(id)
	for pid in Net.players:
		if Net.team_of(pid) == team:
			_show_ping.rpc_id(pid, id, pos, kind)


@rpc("authority", "call_local", "reliable")
func _show_ping(owner_id: int, pos: Vector3, kind: String) -> void:
	_prune_pings()
	# A danger ping (double tap) replaces the ping its owner just placed.
	var mine := pings.filter(func(p: Array) -> bool: return p[0] == owner_id)
	if kind == "danger" and not mine.is_empty():
		var last: Array = mine[-1]
		if (last[2] as PingMarker).age < 0.6:
			_remove_ping(last)
			mine.pop_back()
	while mine.size() >= PINGS_PER_PLAYER:
		_remove_ping(mine.pop_front())
	var info: Array = PING_KINDS.get(kind, PING_KINDS.spot)
	var col := PING_SPOT
	if kind == "enemy" or kind == "danger":
		col = PING_DANGER
	elif kind == "tag":
		col = Mats.TAG_COLOR
	var m: PingMarker = PING_SCENE.instantiate()
	m.setup(col, info[0], info[1])
	add_child(m)
	m.global_position = pos
	pings.append([owner_id, kind, m])
	Sfx.play("ping_danger" if col == PING_DANGER else "ping", -6.0)


func _remove_ping(p: Array) -> void:
	if is_instance_valid(p[2]):
		(p[2] as PingMarker).queue_free()
	pings.erase(p)


func _prune_pings() -> void:
	pings = pings.filter(func(p: Array) -> bool: return is_instance_valid(p[2]) and not (p[2] as Node).is_queued_for_deletion())


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
