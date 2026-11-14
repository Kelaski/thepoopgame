class_name PlayerAddons
extends PlayerNet
## The player's side of addons. What each addon does is in scripts/addons/; this is what they
## share: the key, timers, the HUD bar, plus the grapple's physics, Magnet and Bubble.

const YANK_MIN_GAP := 2.0          # s between grapple yanks from enemies
const BUBBLE_SCENE := preload("res://assets/models/parry_bubble.tscn")
## What you see of your own Bubble: a glow round the screen's edges, since you stand inside the sphere.
const BUBBLE_EDGE_SCENE := preload("res://assets/ui/hud/bubble_edge.tscn")
const ROCKET_SCENE := preload("res://assets/models/rocket_flame.tscn")


func _use_addon(slot: int) -> void:
	var a := Addons.of(addon_in(slot))
	if not a.switch_off(self) and addon_cd[slot] <= 0.0:
		a.use(self)


## The living teammate nearest your crosshair, in sight and within reach, or null
## (and a message saying so).


func _aimed_teammate(reach: float, cone_deg: float) -> PlayerState:
	var best: PlayerState = null
	var best_angle := deg_to_rad(cone_deg)
	if Game.world:
		for p: PlayerState in Game.world.players.values():
			if p == self or p.team != team or not p.alive:
				continue
			var to := p.global_position + Vector3(0, 1.1, 0) - cam.global_position
			var angle := aim_dir().angle_to(to)
			if to.length() <= reach and angle < best_angle and not _ray_hits(cam.global_position, to):
				best = p
				best_angle = angle
	if best == null:
		Game.announce.emit("Aim at a teammate in sight", UiKit.MUTED)
	return best


## Magnet: a teammate pulled us. Everyone else just lets the fast move through.


func magnet_to(pos: Vector3) -> void:
	if not is_local:
		_net_free_until = Time.get_ticks_msec() / 1000.0 + Addons.MAGNET.pull_time + TELEPORT_GRACE
		return
	_magnet_t = Addons.MAGNET.pull_time
	_magnet_from = global_position
	_magnet_to = pos
	velocity = Vector3.ZERO
	sliding = false
	if wallrunning:
		_end_wallrun()
	_mantle_t = 0.0
	_end_grapple()
	_on_moved()


## True while being pulled: you fly straight to the teammate and do nothing else.


func _tick_magnet(delta: float) -> bool:
	if _magnet_t <= 0.0:
		return false
	_magnet_t = maxf(0.0, _magnet_t - delta)
	global_position = _magnet_from.lerp(_magnet_to, 1.0 - _magnet_t / Addons.MAGNET.pull_time)
	_prev_pos = _cur_pos
	_cur_pos = global_position
	Net.to_all(self, "_net_state", [global_position, yaw, pitch, velocity, _flags(), Time.get_ticks_msec() / 1000.0], false)
	return true


## A blast launched us (the host decides; Bubble has already blocked it there).


func push(v: Vector3) -> void:
	if is_local and alive:
		velocity += v
		sliding = false
		if wallrunning:
			_end_wallrun()
		_on_moved()


## A copy of this player's body where they stand now (Warp's afterimage, UAV's still).


func body_copy() -> Node3D:
	var copy: Node3D = body_root.duplicate()
	copy.visible = true
	copy.top_level = true
	return copy


## The host says a warp happened: everyone else moves them (the warper already has).


func net_teleport(pos: Vector3) -> void:
	if is_local:
		return
	if Game.world:
		Game.world.add_afterimage(self)
		Game.world.add_warp_trail(global_position, pos)
	Sfx.play_at("warp", pos + Vector3(0, 1.2, 0), -2.0, 50.0)  # once, where they reappear
	global_position = pos
	net_pos = pos
	_anchor_t = -1.0
	_jump_votes = 0
	_net_free_until = Time.get_ticks_msec() / 1000.0 + TELEPORT_GRACE


## The host confirmed a kill of ours. A reload we already predicted (see _predict_kill) isn't done twice.


func on_kill(victim := 0) -> void:
	var a := Addons.of(passive)
	a.on_kill(self)
	if _predicted_kills.has(victim):
		_predicted_kills.erase(victim)
	elif a is ReloaderAddon:
		a.refill(self)


## Reload on Kill: a shot that does at least the victim's health kills them, so
## refill now instead of a round trip later when the host confirms it.


func _predict_kill(hits: Dictionary) -> void:
	var a := Addons.of(passive)
	if not a is ReloaderAddon or weapon == "bat":
		return
	for t in _predicted_kills.keys():
		if _now - float(_predicted_kills[t]) > 2.0:
			_predicted_kills.erase(t)  # the host never confirmed that one
	for id in hits:
		var v: PlayerState = Game.world.players.get(id)
		if v and v.alive and not v.is_protected() and v._bubble_t <= 0.0 and hits[id][0] >= float(Game.hp.get(id, 100.0)):
			a.refill(self)
			_predicted_kills[id] = _now
			return


## True while this player's Bubble is up: nothing can push them.


func bubbled() -> bool:
	return _bubble_t > 0.0


## Shows the Bubble (everyone sees it; the host says when).


func show_bubble() -> void:
	_bubble_t = Addons.BUBBLE.time
	bubble_damaged(1.0)


## The Bubble took a hit: it fades with its remaining health, and breaks at none.


func bubble_damaged(health_left: float) -> void:
	if health_left <= 0.0:
		_bubble_t = 0.0
		if is_local and addon_active[ACTIVE_SLOT] > 0.0 and active == "bubble":
			addon_active[ACTIVE_SLOT] = 0.0
			addon_cd[ACTIVE_SLOT] = Addons.BUBBLE.cd
		return
	if _bubble_node == null:
		_bubble_node = (BUBBLE_EDGE_SCENE if is_local else BUBBLE_SCENE).instantiate()
		add_child(_bubble_node)
	for c in _bubble_node.get_children():
		if c is GeometryInstance3D:
			c.transparency = 0.7 * (1.0 - health_left)
		elif c is CanvasItem:
			c.modulate.a = 1.0 - 0.7 * (1.0 - health_left)


func _tick_bubble(delta: float) -> void:
	_bubble_t = maxf(0.0, _bubble_t - delta)
	if _bubble_node:
		_bubble_node.visible = _bubble_t > 0.0 and alive


func _show_rocket_flame(on: bool) -> void:
	if on and _rocket_flame == null:
		_rocket_flame = ROCKET_SCENE.instantiate()
		add_child(_rocket_flame)
	if _rocket_flame:
		_rocket_flame.visible = on


# A momentum grappling hook: the hook flies out (it isn't instant), latches onto
# whatever it hits, then reels you in while you keep steering. The rope only ever
# gets shorter, so hooking something above you swings you under it, and you get a
# small upward pop at the end so you can climb onto ledges. It only lasts while the
# ability key is held: releasing it (or jumping) lets go with your momentum.
# Hooking an enemy also yanks them towards you.


func _fire_grapple() -> void:
	_hook_pos = cam.global_position
	_hook_dir = aim_dir()
	_hook_dist = 0.0
	grapple_state = Hook.FLYING
	Sfx.play("addon", -4.0, 1.6)
	Net.to_all(self, "_grapple_net", [Hook.FLYING, _hook_pos, _hook_dir], true)
	_on_moved()


func _tick_hook(delta: float) -> void:
	var step := minf(Addons.GRAPPLE.hook_speed * delta, Addons.GRAPPLE.reach - _hook_dist)
	var from := _hook_pos + _hook_dir * _hook_dist
	var to := from + _hook_dir * step
	var q := PhysicsRayQueryParameters3D.create(from, to, MASK_AIM | MapBuilder.L_PLAYER, [get_rid()])
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty():
		_attach_grapple(r.position, r.collider)
		return
	_hook_dist += step
	if _hook_dist >= Addons.GRAPPLE.reach - 0.01:
		# Missed: the hook reels back in and only a short cooldown applies.
		grapple_state = Hook.NONE
		addon_cd[ACTIVE_SLOT] = Addons.GRAPPLE.miss_cd
		Sfx.play("addon_end", -6.0, 1.6)
		Net.to_all(self, "_grapple_net", [Hook.NONE, Vector3.ZERO, Vector3.ZERO], true)


func _attach_grapple(point: Vector3, collider: Object) -> void:
	grapple_state = Hook.ATTACHED
	grapple_point = point
	grapple_t = Addons.GRAPPLE.max_time
	addon_cd[ACTIVE_SLOT] = Addons.GRAPPLE.cd
	_rope_len = point.distance_to(global_position + Vector3(0, 1.0, 0))
	_grapple_target = collider as PlayerState
	if _grapple_target:
		_grapple_offset = point - _grapple_target.global_position
		if _grapple_target.team != team:
			Net.to_peer(_grapple_target.peer_id, _grapple_target, "_grapple_yank", [])
	Sfx.play("door", -6.0, 1.8)
	Net.to_all(self, "_grapple_net", [Hook.ATTACHED, point, Vector3.ZERO], true)


## Reels you towards the hook. Returns the new horizontal velocity (vertical is
## written to velocity.y).


func _apply_grapple(delta: float, hvel: Vector3, wish: Vector3, jump_tap: bool, on_floor: bool) -> Vector3:
	grapple_t -= delta
	if _grapple_target:
		if not is_instance_valid(_grapple_target) or not _grapple_target.alive:
			_end_grapple()
			return hvel
		grapple_point = _grapple_target.global_position + _grapple_offset
	var chest := global_position + Vector3(0, 1.0, 0)
	var to := grapple_point - chest
	var d := to.length()
	if jump_tap or grapple_t <= 0.0 or d < 0.1:
		_end_grapple()
		return hvel
	var n := to / d
	var v := Vector3(hvel.x, velocity.y, hvel.z)
	if d < Addons.GRAPPLE.arrive:
		# Arrived: pop up and over the edge you hooked, keeping your momentum.
		v.y = maxf(v.y, Addons.GRAPPLE.end_pop)
		v += Vector3(n.x, 0.0, n.z) * 2.0
		if v.length() > Addons.GRAPPLE.max_speed:
			v = v.normalized() * Addons.GRAPPLE.max_speed
		velocity.y = v.y
		_end_grapple()
		return Vector3(v.x, 0.0, v.z)
	# The rope snaps if a building gets between you and the hook; it slides past props.
	if _rope_blocked(chest, grapple_point - n * 0.35):
		_end_grapple()
		return hvel
	if on_floor and v.y < 2.5:
		v.y = 2.5  # unstick from the ground
	v += n * Addons.GRAPPLE.pull * delta
	v += wish * Addons.GRAPPLE.steer * delta
	# Rope constraint: it only gets shorter, so outward speed is cancelled (swing).
	_rope_len = minf(_rope_len, d)
	if d > _rope_len + 0.05:
		var outward := -v.dot(n)
		if outward > 0.0:
			v += n * outward
	if v.length() > Addons.GRAPPLE.max_speed:
		v = v.normalized() * Addons.GRAPPLE.max_speed
	velocity.y = v.y
	sliding = false
	if wallrunning:
		_end_wallrun()
	_on_moved()
	return Vector3(v.x, 0.0, v.z)


## True if something other than a prop (furniture, cars, trees) lies on the rope.
func _rope_blocked(from: Vector3, to: Vector3) -> bool:
	var skip: Array[RID] = [get_rid()]
	for i in 8:
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, MASK_AIM, skip))
		if hit.is_empty():
			return false
		var body := hit.collider as CollisionObject3D
		if body == null or not (body.collision_layer & GeoMask.PROP):
			return true
		skip.append(hit.rid)
	return false


func _end_grapple() -> void:
	if grapple_state == Hook.NONE:
		return
	if grapple_state == Hook.FLYING:
		addon_cd[ACTIVE_SLOT] = maxf(addon_cd[ACTIVE_SLOT], Addons.GRAPPLE.miss_cd)
	grapple_state = Hook.NONE
	_grapple_target = null
	Net.to_all(self, "_grapple_net", [Hook.NONE, Vector3.ZERO, Vector3.ZERO], true)


## Lets everyone else see the hook and rope. FLYING sends the throw origin and
## direction (remotes fly the hook themselves); ATTACHED sends the anchor point.


func _grapple_net(state: int, point: Vector3, dir: Vector3) -> void:
	if state < Hook.NONE or state > Hook.ATTACHED or not (point.is_finite() and dir.is_finite()):
		return
	if state != Hook.NONE and point.distance_to(global_position) > Addons.GRAPPLE.reach + 10.0:
		return
	if state == Hook.FLYING:
		dir = dir.normalized()
	grapple_state = state
	if state == Hook.FLYING:
		_hook_pos = point
		_hook_dir = dir
		_hook_dist = 0.0
	elif state == Hook.ATTACHED:
		grapple_point = point


## An enemy hooked us: we get yanked towards them. Only honoured from a player
## who is actually within grapple range.


func _grapple_yank() -> void:
	if not is_local or not alive or Game.world == null or bubbled():
		return
	var from: PlayerState = Game.world.players.get(Net.remote_sender())
	if from == null or not from.alive or from.team == team or from.active != "grapple":
		return
	# One yank per hook: a hooked enemy can't be flung again until the grapple could
	# have come off cooldown (stops a modified client spamming yanks).
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_yank < YANK_MIN_GAP:
		return
	var to := from.global_position - global_position
	if to.length() > Addons.GRAPPLE.reach + 6.0:
		return
	_last_yank = now
	velocity += to.normalized() * Addons.GRAPPLE.yank + Vector3.UP * 3.0
	sliding = false


func _grapple_end_point() -> Vector3:
	if grapple_state == Hook.FLYING:
		return _hook_pos + _hook_dir * _hook_dist
	return grapple_point


func _update_rope() -> void:
	if grapple_state == Hook.NONE or not alive:
		if _rope:
			_rope.visible = false
			_hook_mesh.visible = false
		return
	if _rope == null:
		_hook_mesh = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.09
		sm.height = 0.18
		_hook_mesh.mesh = sm
		_hook_mesh.material_override = Mats.toon(Color(0.75, 0.75, 0.8))
		_hook_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_hook_mesh.top_level = true
		add_child(_hook_mesh)
		_rope = MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.035, 0.035, 1.0)
		_rope.mesh = bm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.16, 0.13, 0.1)
		_rope.material_override = m
		_rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_rope.top_level = true
		add_child(_rope)
	var from := global_position + Vector3(0, 1.3, 0)
	if is_local and cam:
		from = cam.global_position + cam.global_basis * Vector3(0.22, -0.22, -0.35)
	var end := _grapple_end_point()
	_hook_mesh.global_position = end
	_hook_mesh.visible = true
	var dir := end - from
	var d := dir.length()
	if d < 0.05:
		_rope.visible = false
		return
	var up := Vector3.RIGHT if absf(dir.normalized().dot(Vector3.UP)) > 0.99 else Vector3.UP
	_rope.global_transform = Transform3D(Basis.looking_at(dir, up) * Basis.from_scale(Vector3(1.0, 1.0, d)), from + dir * 0.5)
	_rope.visible = true


func _tick_addon(delta: float) -> void:
	for slot in 2:
		# Remember the length of the cooldown in progress, however it was started.
		_cd_full[slot] = maxf(_cd_full[slot], addon_cd[slot]) if addon_cd[slot] > 0.0 else 0.0
		var id := addon_in(slot)
		if alive or not Addons.is_support(id):  # Support cooldowns only run while you're alive
			Addons.of(id).tick(self, slot, delta)
	_rocket_t = maxf(0.0, _rocket_t - delta)
	if floor_phase > 0.0:
		floor_phase -= delta
		if floor_phase <= 0.0 and alive and _overlaps(MapBuilder.L_FLOOR, probe_shape, STAND_H * 0.5 + 0.1):
			floor_phase = 0.05


func _end_invis() -> void:
	if not invisible:
		return
	invisible = false
	addon_active[ACTIVE_SLOT] = 0.0
	addon_cd[ACTIVE_SLOT] = Addons.HIDER.cd
	Sfx.play("addon_end", -4.0)


## [label, fraction (0..1), state] for the HUD bar of an addon slot.


func addon_status(slot: int) -> Array:
	var shown := Addons.of(addon_in(slot)).status(self, slot)
	if not shown.is_empty():
		return shown
	if addon_cd[slot] > 0.0:
		return _cooling(slot)
	if slot == PASSIVE_SLOT:
		return ["PASSIVE", 1.0, "passive"]
	return ["READY [%s]" % Settings.bind_text("addon"), 1.0, "ready"]


func _cooling(slot: int) -> Array:
	var cd: float = addon_cd[slot]
	return ["%.1fs" % cd, 1.0 - cd / maxf(_cd_full[slot], cd), "cooldown"]
