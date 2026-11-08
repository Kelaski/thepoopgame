class_name PlayerWeapons
extends PlayerAddons
## Reloading, firing and working out what a shot hits.

const GRENADE_MUZZLE := 0.6


func _start_reload() -> void:
	if weapon == "bat" or reloading > 0.0:
		return
	var mag := int(Weapons.DATA[weapon].mag)
	if ammo >= mag:
		return
	reloading = reload_time()
	Sfx.play("reload", -6.0)


## Time between shots. Trackstar re-chambers the shotgun (35%) and sniper (30%) faster.


func shot_interval() -> float:
	var t := 1.0 / float(Weapons.DATA[weapon].rps)
	if weapon in Addons.RECHAMBER_WEAPONS:
		t *= Addons.of(passive).rechamber_mult(weapon)
	return t


## Time for a reload (or for one round, on weapons that load round by round).
## Trackstar and Killstreak make it shorter.


func reload_time() -> float:
	var w: WeaponStats = Weapons.DATA[weapon]
	var t: float = w.reload_per_round if w.reload_per_round > 0.0 else w.reload
	return t * Addons.of(passive).reload_mult(self, weapon)


func _spread_dir(b: Basis, deg: float) -> Vector3:
	var fwd := -b.z
	if deg <= 0.0:
		return fwd
	var a := randf() * TAU
	var rr := sqrt(randf()) * tan(deg_to_rad(deg))
	return (fwd + b.x * cos(a) * rr + b.y * sin(a) * rr).normalized()


func _try_fire() -> void:
	if fire_cd > 0.0 or Game.world == null:
		return
	var w = Weapons.DATA[weapon]
	if reloading > 0.0:
		if w.reload_per_round <= 0.0 or ammo <= 0:
			return
		reloading = 0.0  # firing cancels a round-by-round reload
	if weapon != "bat" and ammo <= 0:
		_start_reload()
		return
	fire_cd = shot_interval()
	if weapon != "bat":
		_shot_pose = SHOT_POSE_TIME
	_on_moved()
	if invisible:
		_end_invis()  # Firing breaks Hider invisibility.
	var origin := cam.global_position
	var b := cam.global_basis
	var ends := PackedVector3Array()
	var hits := {}
	match weapon:
		"ar":
			var spread := lerpf(float(w.hip), float(w.ads), ads_t)
			if sliding or not is_on_floor():
				spread *= 1.6
			var res := _hitscan(origin, _spread_dir(b, spread), w.max_range, 0, false)
			ends.append(res.end)
			for h in res.hits:
				var far: bool = h.dist > float(w.falloff)
				var dmg: float
				if h.head:
					dmg = w.head_far if far else w.head
				else:
					dmg = w.body_far if far else w.body
				_acc(hits, h.id, dmg, h.head)
		"shotgun":
			for i in int(w.pellets):
				var res := _hitscan(origin, _spread_dir(b, float(w.cone) * 0.5), w.max_range, 0, false)
				if i % 3 == 0:
					ends.append(res.end)
				for h in res.hits:
					_acc(hits, h.id, Weapons.shotgun_pellet_damage(h.dist), h.head)
		"sniper":
			var spread := lerpf(float(w.hip), float(w.ads), ads_t)
			var res := _hitscan(origin, _spread_dir(b, spread), w.max_range, 1, true)
			ends.append(res.end)
			for h in res.hits:
				# Headshots always kill; lower body takes slightly less.
				var dmg: float = w.dmg_head if h.head else (w.dmg_low if h.low else w.dmg)
				_acc(hits, h.id, dmg, h.head)
		"gl":
			var dir := aim_dir()
			Game.request_grenade.rpc_id(1, _grenade_start(origin, dir), dir * Weapons.grenade_speed(velocity.length()))
		"bat":
			swing_t = 1.0
			# Momentum damage: faster than your sprint speed hits harder.
			var bat_dmg := Weapons.bat_damage(Vector2(velocity.x, velocity.z).length(), SPRINT * _speed_mult())
			for off: Vector2 in [Vector2.ZERO, Vector2(0.06, 0.0), Vector2(-0.06, 0.0), Vector2(0.0, -0.08)]:
				var dir := (-b.z + b.x * off.x + b.y * off.y).normalized()
				var res := _hitscan(origin, dir, w.reach, 0, false)
				if not res.hits.is_empty():
					var h: Dictionary = res.hits[0]
					_acc(hits, h.id, bat_dmg, h.head)
					Sfx.play("bat_hit", -2.0)
					break
	# The shot is finished (round used, reload started) before its hits are sent:
	# on the host a kill comes straight back, and Reload on Kill must refill after.
	if weapon != "bat":
		ammo -= 1
		flash_t = 0.05
		recoil = float(w.kick)
		pitch = clampf(pitch + deg_to_rad(float(w.kick) * 0.35), deg_to_rad(-89.0), deg_to_rad(89.0))
		if ammo <= 0:
			_start_reload()
	_predict_kill(hits)
	for id in hits:
		Game.report_hit.rpc_id(1, id, hits[id][0], hits[id][1], weapon, weapon == "sniper" and ads_t < 0.85)
	Sfx.play(weapon, -3.0, randf_range(0.95, 1.05))
	if weapon != "bat":
		var muzzle := vm_muzzle.global_position if vm_muzzle else origin
		Game.world.add_tracers(muzzle, ends)
		Net.to_all(Game.world, "fx_shot", [global_position + Vector3(0, 1.25, 0), ends, weapon], true)  # reliable: a hit must never be silent
	else:
		Net.to_all(Game.world, "fx_shot", [global_position + Vector3(0, 1.25, 0), PackedVector3Array(), weapon], true)


## A grenade leaves just ahead of you, but never from the far side of a wall you're up against.


func _grenade_start(origin: Vector3, dir: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * GRENADE_MUZZLE, MapBuilder.MASK_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return origin + dir * GRENADE_MUZZLE if hit.is_empty() else hit.position - dir * 0.05


func _acc(hits: Dictionary, id: int, dmg: float, head_hit: bool) -> void:
	if head_hit:
		dmg *= Addons.of(passive).head_mult()
	if not hits.has(id):
		hits[id] = [0.0, false]
	hits[id][0] += dmg
	hits[id][1] = hits[id][1] or head_hit


## Hitscan ray. Passes through teammates; optionally pierces walls/players.


func _hitscan(from: Vector3, dir: Vector3, max_dist: float, wall_pierce: int, pierce_players: bool) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = [get_rid()]
	for p in Game.world.players.values():
		if p != self and p.team == team:
			exclude.append(p.get_rid())
	var hits := []
	var walls := 0
	var start := from
	var end := from + dir * max_dist
	for _i in 24:
		var q := PhysicsRayQueryParameters3D.create(start, end, MASK_SHOT, exclude)
		var r := space.intersect_ray(q)
		if r.is_empty():
			return {"hits": hits, "end": end}
		var col = r.collider
		if col is PlayerState:
			hits.append({"id": col.peer_id, "head": col.is_head_hit(r.position), "low": col.is_lower_hit(r.position), "dist": from.distance_to(r.position)})
			if not pierce_players:
				return {"hits": hits, "end": r.position}
			exclude.append(col.get_rid())
			start = r.position
			continue
		var hit_pos: Vector3 = r.position
		if walls < wall_pierce:
			# Find where the ray exits this obstacle (walls are thin; >1m is too thick).
			var probe := hit_pos + dir * 1.0
			var q2 := PhysicsRayQueryParameters3D.create(probe, hit_pos, MASK_AIM)
			var r2 := space.intersect_ray(q2)
			if r2.is_empty():
				return {"hits": hits, "end": r.position}
			walls += 1
			Game.world.add_impact(r.position)
			start = r2.position + dir * 0.02
			continue
		if weapon == "bat":  # a gun's tracer makes its own sparks when it lands
			Game.world.add_impact(r.position)
		return {"hits": hits, "end": r.position}
	return {"hits": hits, "end": end}


# Two slots: the active addon (Addons.ACTIVE, on Use Addon) and the passive one
# (Addons.PASSIVE, no key). addon_active / addon_cd are per slot.
