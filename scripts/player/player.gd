class_name Player
extends PlayerWeapons
## First-person player. The owning peer simulates movement and shooting locally
## (client-authoritative movement, server-validated damage) and streams its state
## to everyone else at 30 Hz. Remote copies interpolate.
## This layer sets the player up, draws it, and runs each tick. See PlayerState for the other layers.

const VM_HIP := Vector3(0.24, -0.24, -0.5)
const VM_ADS := Vector3(0.0, -0.135, -0.36)
const GLINT_MIN_DOT := 0.6  # sniper glint shows when they aim within ~53 degrees of you
const NAMEPLATE_SCALE := 0.9  # teammate name size vs the original (0.15, then six times bigger)
# Teammate names fade while you aim near them, so they never cover a fight:
# fully faded within NAMEPLATE_FADE_NEAR degrees of the crosshair, back to full
# beyond NAMEPLATE_FADE_FAR.
const NAMEPLATE_FADE_NEAR := 10.0
const NAMEPLATE_FADE_FAR := 18.0
const NAMEPLATE_MIN_ALPHA := 0.12
var _vm_ads := VM_ADS
const WEAPON_SCENES := {
	"ar": preload("res://assets/models/weapons/ar.tscn"),
	"shotgun": preload("res://assets/models/weapons/shotgun.tscn"),
	"sniper": preload("res://assets/models/weapons/sniper.tscn"),
	"gl": preload("res://assets/models/weapons/grenade_launcher.tscn"),
	"bat": preload("res://assets/models/weapons/bat.tscn"),
}
const MUZZLE_FLASH_SCENE := preload("res://assets/models/muzzle_flash.tscn")
const GLINT_SCENE := preload("res://assets/models/glint.tscn")
const SCAN_OUTLINE := preload("res://assets/materials/scan_outline.tres")  # UAV: enemies outlined through walls
const TEAM_OUTLINE := preload("res://assets/materials/team_outline.tres")
const TEAM_OUTLINE_MASK := preload("res://assets/materials/team_outline_mask.tres")  # its first pass only
const SPRAY_COOLDOWN := 5.0
const SPRAY_REACH := 4.0
var _spray_ready_at := 0.0


## Places your custom spray on the surface you're looking at (5 s cooldown).
const PING_RANGE := 300.0


func setup(id: int, info: Dictionary) -> void:
	peer_id = id
	name = str(id)
	team = info.get("team", 0)
	weapon = info.get("weapon", "ar")
	active = info.get("active", Addons.DEFAULT_ACTIVE)
	passive = info.get("passive", Addons.DEFAULT_PASSIVE)


func _ready() -> void:
	set_multiplayer_authority(peer_id)
	is_local = peer_id == multiplayer.get_unique_id()
	add_to_group("players")
	collision_layer = MapBuilder.L_PLAYER
	collision_mask = MASK_FULL
	floor_max_angle = deg_to_rad(55.0)  # car windscreens (about 52 degrees) count as floor, so you can jump off them
	floor_snap_length = 0.45
	floor_constant_speed = true

	# The model is assets/models/player.tscn; these are its nodes.
	col_shape = $BodyShape
	capsule = col_shape.shape as CapsuleShape3D  # local to each player (crouching changes its height)
	head_col = $HeadHitbox
	head = $Head
	body_root = $BodyRoot
	tp_pivot = $BodyRoot/TpPivot
	tp_gun = $BodyRoot/TpPivot/TpGun
	nameplate = $Nameplate
	probe_shape = CapsuleShape3D.new()
	probe_shape.radius = RADIUS - 0.06
	probe_shape.height = STAND_H - 0.25
	_apply_team_look()
	_rebuild_tp_gun()
	if is_local:
		cam = Camera3D.new()
		cam.top_level = true  # positioned every frame with physics interpolation
		cam.keep_aspect = Camera3D.KEEP_WIDTH
		cam.near = 0.05
		cam.far = float(Settings.g("view_distance"))
		cam.fov = float(Settings.g("fov"))
		head.add_child(cam)
		cam.current = true
		_build_viewmodel()
		body_root.visible = false
		Settings.changed.connect(_on_settings_changed)
	set_alive(false)


func _on_settings_changed() -> void:
	if cam:
		cam.far = float(Settings.g("view_distance"))


## Team colours on the model: anything in the "team_color" group gets the team
## colour, "team_color_dark" a darker shade (add parts to these groups in the
## editor to colour them too). Also the nameplate.


func _apply_team_look() -> void:
	var tc := Mats.team_color(team)
	for n in WeaponModel._in_group(self, "team_color"):
		n.material_override = Mats.toon(tc)
	for n in WeaponModel._in_group(self, "team_color_dark"):
		n.material_override = Mats.toon(tc.darkened(0.3))
	nameplate.pixel_size = 0.0015 * NAMEPLATE_SCALE
	nameplate.modulate = tc.lightened(0.55)
	nameplate.text = Net.name_of(peer_id)
	_apply_overlay()


# Outlines, as a material overlay on every body part:
# * teammates: a hollow white outline, through walls too (assets/materials/
#   team_outline.tres: the body marks its shape in the stencil buffer, and a
#   slightly grown copy is drawn in white only outside that shape)


func _apply_overlay() -> void:
	var mine := Net.team_of(multiplayer.get_unique_id())
	var overlay: Material = null
	if not is_local and mine >= 0 and team == mine:
		overlay = TEAM_OUTLINE
	for mi: MeshInstance3D in _meshes_under(body_root, []):
		# The teammate outline only shows where something hides them. The feet stand on
		# the ground, which would "hide" their outline's lower edge, so they only mark
		# the body (keeping the outline hollow) without an outline of their own.
		mi.material_overlay = TEAM_OUTLINE_MASK if overlay == TEAM_OUTLINE and mi.name.begins_with("Foot") else overlay


static func _meshes_under(n: Node, out: Array) -> Array:
	for c in n.get_children():
		if c is MeshInstance3D:
			out.append(c)
		_meshes_under(c, out)
	return out


## Bounce pads (umbrella and awning tops) launch you up whenever you hit one in
## the air: landing on the top, or jumping into its rim or side. They have no
## solid collision for you (you pass up through them), so you can never get
## wedged in one; coming down onto the top always bounces. A head bump while
## you're standing underneath doesn't count.


func _fade_nameplate(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var to := nameplate.global_position - cam.global_position
	var ang := rad_to_deg((-cam.global_basis.z).angle_to(to))
	var k := clampf((ang - NAMEPLATE_FADE_NEAR) / (NAMEPLATE_FADE_FAR - NAMEPLATE_FADE_NEAR), 0.0, 1.0)
	var target := lerpf(NAMEPLATE_MIN_ALPHA, 1.0, k)
	nameplate.modulate.a = lerpf(nameplate.modulate.a, target, clampf(delta * 12.0, 0.0, 1.0))
	nameplate.outline_modulate.a = 0.9 * nameplate.modulate.a


func _build_viewmodel() -> void:
	viewmodel = Node3D.new()
	viewmodel.position = VM_HIP
	cam.add_child(viewmodel)
	_rebuild_viewmodel()


## First-person viewmodel: the weapon's scene, without shadows, plus a muzzle flash.


func _rebuild_viewmodel() -> void:
	if viewmodel == null:
		return
	for c in viewmodel.get_children():
		c.queue_free()
	var wm: WeaponModel = WEAPON_SCENES[weapon].instantiate()
	wm.make_first_person()
	viewmodel.add_child(wm)
	vm_gun = wm
	vm_muzzle = wm.muzzle()
	_vm_ads = wm.ads_offset
	vm_flash = MUZZLE_FLASH_SCENE.instantiate()
	vm_muzzle.add_child(vm_flash)


## The gun other players see you holding: the same scene as the viewmodel, held
## at the shoulder and pitched with where you're looking. The sniper gets a scope glint.


func _rebuild_tp_gun() -> void:
	if tp_gun == null:
		return
	for c in tp_gun.get_children():
		c.queue_free()
	_glint = null
	_body_alpha = -1.0
	var wm: WeaponModel = WEAPON_SCENES[weapon].instantiate()
	wm.make_third_person()
	tp_gun.add_child(wm)
	_tp_muzzle = wm.muzzle()
	var gp := wm.glint_point()
	if gp:
		_glint = GLINT_SCENE.instantiate()
		_glint.visible = false
		gp.add_child(_glint)
	if body_root:
		_apply_overlay()  # the new gun gets the outline too


## Where this player's shots start for everyone else: the muzzle of their
## third-person gun (which follows where they aim), or fallback without one.


func tp_muzzle_pos(fallback: Vector3) -> Vector3:
	return _tp_muzzle.global_position if is_instance_valid(_tp_muzzle) else fallback


## Body transparency (Hider / Phantom / spawn protection), applied to every part
## including the held gun. Only touches the meshes when the value changes.


func _set_body_alpha(alpha_transparency: float, vis: bool) -> void:
	body_root.visible = vis
	if is_equal_approx(alpha_transparency, _body_alpha):
		return
	_body_alpha = alpha_transparency
	_set_alpha_in(body_root, alpha_transparency)


func _set_alpha_in(n: Node, a: float) -> void:
	for c in n.get_children():
		if c == _glint:
			continue
		if c is GeometryInstance3D:
			c.transparency = a
		_set_alpha_in(c, a)


## Sniper glint: a flare on the scope while this player is scoped in with the
## sniper, brightest when they're looking straight at you. Hidden behind walls.


func _update_glint() -> void:
	if _glint == null:
		return
	var strength := 0.0
	var view := get_viewport().get_camera_3d()
	if view and alive and body_root.visible and (net_flags & F_ADS) != 0:
		var gp := _glint.global_position
		var to_cam := view.global_position - gp
		var look := -(Basis(Vector3.UP, net_yaw) * Basis(Vector3.RIGHT, net_pitch)).z
		strength = clampf((look.dot(to_cam.normalized()) - GLINT_MIN_DOT) / (1.0 - GLINT_MIN_DOT), 0.0, 1.0)
		if strength > 0.0:
			var q := PhysicsRayQueryParameters3D.create(view.global_position, gp, MapBuilder.MASK_WORLD)
			if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
				strength = 0.0
	_glint.visible = strength > 0.0
	if _glint.visible:
		var pulse := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.012)
		_glint.scale = Vector3.ONE * lerpf(0.45, 1.0, strength) * pulse


func refresh_loadout() -> void:
	var old_weapon := weapon
	var old_addons := [active, passive]
	if Net.players.has(peer_id):
		var info: Dictionary = Net.players[peer_id]
		team = info.team
		weapon = info.weapon
		active = info.active
		passive = info.get("passive", passive)
	if weapon != old_weapon:
		_rebuild_tp_gun()
		# A new gun comes loaded (matters when you swap during the countdown).
		ammo = int(Weapons.DATA[weapon].mag)
		reloading = 0.0
		fire_cd = 0.0
	for slot in 2:
		if addon_in(slot) != old_addons[slot]:
			if Addons.is_support(old_addons[slot]):
				_support_cd[old_addons[slot]] = addon_cd[slot]  # swapping away and back can't skip it
			addon_active[slot] = 0.0
			addon_cd[slot] = float(_support_cd.get(addon_in(slot), 0.0))
	rocket_armed = rocket_armed and active == "rocketjump"
	if nameplate:
		_apply_team_look()
	if is_local:
		_rebuild_viewmodel()


func set_alive(a: bool) -> void:
	alive = a
	collision_layer = MapBuilder.L_PLAYER if a else 0
	if not a:
		sliding = false
		wallrunning = false
		if invisible:
			invisible = false
		phasing = 0.0
		floor_phase = 0.0
		velocity = Vector3.ZERO
		_rocket_t = 0.0
		_streak = 0
		_magnet_t = 0.0
		if _uav_left > 0:  # the pulses stop, and the cooldown starts
			_uav_left = 0
			addon_cd[ACTIVE_SLOT] = Addons.UAV.cd
		if is_local:
			_end_grapple()
		grapple_state = Hook.NONE
	if body_root:
		body_root.visible = a and not is_local
	if viewmodel:
		viewmodel.visible = a


func respawn(pos: Vector3, protect: bool) -> void:
	refresh_loadout()
	global_position = pos
	net_pos = pos
	_anchor_t = -1.0  # a new speed window from the spawn point
	_prev_pos = pos
	_cur_pos = pos
	velocity = Vector3.ZERO
	sliding = false
	crouching = false
	_crouch_toggle = false
	_aim_toggle = false
	ammo = int(Weapons.DATA[weapon].mag)
	reloading = 0.0
	fire_cd = 0.0
	invisible = false
	phasing = 0.0
	floor_phase = 0.0
	addon_active = [0.0, 0.0]
	addon_cd = [addon_cd[ACTIVE_SLOT] if Addons.is_support(active) else 0.0, 0.0]  # Support cooldowns carry on through death
	rocket_armed = false
	_rocket_t = 0.0
	_bubble_t = 0.0
	_uav_left = 0
	_magnet_t = 0.0
	grapple_state = Hook.NONE
	_grapple_target = null
	dj_ready = true
	wallrunning = false
	wallrun_cd = 0.0
	wall_jumps = 0
	_last_wall_normal = Vector3.ZERO
	_slide_boost_cd = 0.0
	_slide_pending_boost = false
	_jump_buffer_t = 0.0
	_land_grace = 0.0
	_mantle_t = 0.0
	prot_pending = false
	# Protection runs for 3 s from the moment you spawn, and ends early as soon
	# as you move or shoot.
	prot_left = SPAWN_PROTECTION if protect else 0.0
	_set_crouch_shape(false)
	if is_local:
		# Face the Tag when spawning in.
		var d: Vector3 = Game.tag_pos - pos
		if Vector2(d.x, d.z).length() > 1.0:
			yaw = atan2(-d.x, -d.z)
		pitch = 0.0
		rotation.y = yaw
	set_alive(true)


func on_damaged(_head_hit: bool) -> void:
	damage_flash = 1.0  # Hider invisibility is no longer broken by damage.


func _input(event: InputEvent) -> void:
	if not is_local or not alive:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not Game.ui_open:
		var sens: float = Settings.g("sensitivity")
		var zoom: float = Weapons.DATA[weapon].zoom
		sens *= lerpf(1.0, float(Settings.g("ads_sens_mult")) / zoom, ads_t)
		var rel: Vector2 = event.screen_relative
		yaw -= deg_to_rad(rel.x * sens)
		var dy := rel.y * sens
		if Settings.g("invert_y"):
			dy = -dy
		pitch = clampf(pitch - deg_to_rad(dy), deg_to_rad(-89.0), deg_to_rad(89.0))
		if rel.length() > 0.5:
			_on_moved()  # looking around ends spawn protection too


func _physics_process(delta: float) -> void:
	if not is_local:
		return
	_now += delta
	_tick_timers(delta)
	if not alive or _tick_magnet(delta):
		return
	_read_input(delta)
	_update_ground(delta)
	_update_wall_contact(delta)
	_try_start_mantle()
	_try_start_wallrun()
	_try_start_slide()
	if wallrunning:
		_run_on_wall(delta)
	elif sliding:
		_slide_along(delta)
	else:
		_walk_or_steer(delta)
	_set_crouch_shape(crouching)
	_climb_mantle(delta)
	if not _on_floor and not wallrunning and not _mantling:
		velocity.y -= GRAVITY * _gravity_mult() * delta
	_try_jump()
	if grapple_state == Hook.FLYING:
		_tick_hook(delta)
	if grapple_state == Hook.ATTACHED:
		_hvel = _apply_grapple(delta, _hvel, _wish, _jump_tap, _on_floor)
	_move_body(delta)
	_read_actions()
	_send_state(delta)


## Shooting, the addon key, and the other buttons.
func _read_actions() -> void:
	if _can_input and not _frozen:
		if Input.is_action_just_pressed("reload"):
			_start_reload()
		if _fresh_click and not Input.is_action_pressed("fire"):
			_fresh_click = false
		if Input.is_action_pressed("fire") and not _fresh_click:
			_try_fire()
		if Input.is_action_just_pressed("addon"):
			_use_addon(ACTIVE_SLOT)
		if Input.is_action_just_pressed("interact"):
			_interact()
		if Input.is_action_just_pressed("spray"):
			_try_spray()
		if Input.is_action_just_pressed("ping"):
			_try_ping()
	# The grapple is held: letting go of the ability key (or opening a menu / chat)
	# lets go of the rope, or reels a flying hook back in.
	if grapple_state != Hook.NONE and not (_can_input and Input.is_action_pressed("addon")):
		_end_grapple()


func _tick_timers(delta: float) -> void:
	fire_cd = maxf(0.0, fire_cd - delta)
	slide_cd = maxf(0.0, slide_cd - delta)
	wallrun_cd = maxf(0.0, wallrun_cd - delta)
	prot_left = maxf(0.0, prot_left - delta)
	damage_flash = maxf(0.0, damage_flash - delta * 2.0)
	if reloading > 0.0:
		reloading -= delta
		if reloading <= 0.0:
			reloading = 0.0
			var w: WeaponStats = Weapons.DATA[weapon]
			ammo = mini(ammo + 1, w.mag) if w.reload_per_round > 0.0 else w.mag
			if ammo < w.mag:
				_start_reload()  # the next shell
	for b in _door_exceptions.keys():
		_door_exceptions[b] -= delta
		if _door_exceptions[b] <= 0.0:
			_door_exceptions.erase(b)
			if is_instance_valid(b):
				remove_collision_exception_with(b)
	_tick_addon(delta)


func _process(delta: float) -> void:
	_tick_bubble(delta)
	if not is_local and grapple_state == Hook.FLYING:
		_hook_dist = minf(_hook_dist + Addons.GRAPPLE.hook_speed * delta, Addons.GRAPPLE.reach)
	_update_rope()
	if is_local:
		_local_visuals(delta)
	else:
		_remote_update(delta)


func _remote_update(delta: float) -> void:
	if global_position.distance_to(net_pos) > 6.0:
		global_position = net_pos
	else:
		global_position = global_position.lerp(net_pos + net_vel * 0.03, clampf(delta * 16.0, 0.0, 1.0))
	rotation.y = lerp_angle(rotation.y, net_yaw, clampf(delta * 18.0, 0.0, 1.0))
	head.rotation.x = net_pitch
	_set_crouch_shape((net_flags & (F_CROUCH | F_SLIDE)) != 0)
	var me := multiplayer.get_unique_id()
	nameplate.visible = alive and Game.in_match and Net.team_of(me) == team
	if nameplate.visible:
		nameplate.text = ("[TAG] " if Game.holder == peer_id else "") + Net.name_of(peer_id)
		_fade_nameplate(delta)
	if not alive:
		body_root.visible = false
		return
	# Footsteps
	var hs := Vector2(net_vel.x, net_vel.z).length()
	if (net_flags & (F_GROUND | F_WALLRUN)) and not (net_flags & F_SLIDE) and hs > 1.5:
		_step_t -= delta
		if _step_t <= 0.0:
			_step_t = clampf(1.7 / hs, 0.26, 0.6)
			var crouched := (net_flags & F_CROUCH) != 0
			Sfx.play_at("step", global_position, -10.0 if crouched else (-2.0 if hs > 6.0 else -5.0), 14.0 if crouched else 36.0, randf_range(0.85, 1.15))
	var vis := true
	var transparency := 0.0
	var hiding := (net_flags & F_INVIS) != 0
	if hiding:
		var moving := (net_flags & F_MOVING) != 0 and not (net_flags & (F_CROUCH | F_SLIDE))
		transparency = 1.0 - (Addons.HIDER.moving_opacity if moving else Addons.HIDER.still_opacity)
	elif net_flags & F_PHASE:
		transparency = 0.45
	elif net_flags & F_PROT:
		transparency = 0.35 + 0.25 * sin(Time.get_ticks_msec() * 0.02)
	_set_body_alpha(transparency, vis)
	_show_rocket_flame((net_flags & F_ROCKET) != 0 and vis)
	tp_pivot.rotation.x = net_pitch
	_update_glint()


func _local_visuals(delta: float) -> void:
	if cam == null:
		return
	var base_fov := float(Settings.g("fov"))
	var zoom: float = Weapons.DATA[weapon].zoom
	ads_t = move_toward(ads_t, 1.0 if (aiming and alive) else 0.0, delta * 7.0)
	var target_fov := base_fov
	if sprinting or sliding:
		target_fov += 6.0
	var zf := lerpf(1.0, zoom, ads_t)
	var fov := rad_to_deg(2.0 * atan(tan(deg_to_rad(target_fov) * 0.5) / zf)) + float(Settings.g("ads_fov_offset")) * ads_t
	cam.fov = lerpf(cam.fov, fov, clampf(delta * 14.0, 0.0, 1.0))
	var eye := EYE_CROUCH if (crouching or sliding) else EYE_STAND
	head.position.y = move_toward(head.position.y, eye, delta * 6.0)
	var roll_target := 0.0
	if sliding:
		roll_target = deg_to_rad(4.0)
	elif wallrunning:
		var right_v := Basis(Vector3.UP, yaw).x
		roll_target = -signf(wall_normal.dot(right_v)) * deg_to_rad(10.0)
	cam_roll = lerpf(cam_roll, roll_target, clampf(delta * 10.0, 0.0, 1.0))
	recoil = maxf(0.0, recoil - delta * 10.0)
	rotation.y = yaw
	head.rotation.x = pitch
	var f := Engine.get_physics_interpolation_fraction()
	var p := _prev_pos.lerp(_cur_pos, f) if alive else global_position
	cam.global_transform = Transform3D(Basis.from_euler(Vector3(pitch + deg_to_rad(recoil * 1.2), yaw, cam_roll)), p + Vector3(0, head.position.y, 0))
	if viewmodel == null:
		return
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and not sliding:
		bob += delta * hspeed * 1.6
	# Just fired: the gun stays up as if standing still (no sprint pose, no bob).
	_shot_pose = maxf(0.0, _shot_pose - delta)
	var held_up := _shot_pose > 0.0
	var bob_amt := 0.0 if held_up else (1.0 - ads_t) * clampf(hspeed / SPRINT, 0.0, 1.0)
	var pos := (VM_HIP + Settings.viewmodel_offset()).lerp(_vm_ads, ads_t)  # hip only, so aiming still lines up
	pos += Vector3(sin(bob) * 0.014, absf(cos(bob)) * 0.014, 0.0) * bob_amt
	pos.z += recoil * 0.035
	if sprinting and not held_up:
		pos += Vector3(-0.04, -0.03, 0.02)
	viewmodel.position = viewmodel.position.lerp(pos, clampf(delta * 20.0, 0.0, 1.0))
	var rot := Vector3.ZERO
	if sprinting and not held_up:
		rot = Vector3(deg_to_rad(-10.0), deg_to_rad(25.0), 0.0)
	if reloading > 0.0:
		rot.x += deg_to_rad(-30.0)
	if swing_t > 0.0:
		swing_t = maxf(0.0, swing_t - delta * 5.0)
		rot += Vector3(deg_to_rad(-40.0) * sin(swing_t * PI), deg_to_rad(70.0) * sin(swing_t * PI), 0.0)
	viewmodel.rotation = viewmodel.rotation.lerp(rot, clampf(delta * 14.0, 0.0, 1.0))
	viewmodel.visible = alive and not (weapon == "sniper" and ads_t > 0.85)
	if flash_t > 0.0:
		flash_t -= delta
		vm_flash.visible = flash_t > 0.0
	for c in vm_gun.get_children():
		if c is GeometryInstance3D and c != vm_flash:
			c.transparency = 0.6 if invisible else 0.0


func _try_spray() -> void:
	if Game.world == null:
		return
	if not UserImages.exists(UserImages.SPRAY):
		Game.announce.emit("No spray yet - add one in Settings > Spray", UiKit.MUTED)
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now < _spray_ready_at:
		Game.announce.emit("Spray ready in %.1fs" % (_spray_ready_at - now), UiKit.MUTED)
		return
	var from := cam.global_position
	var dir := aim_dir()
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * SPRAY_REACH, MASK_AIM, [get_rid()])
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return
	var normal: Vector3 = r.normal
	var up := Vector3.UP
	if absf(normal.dot(Vector3.UP)) > 0.8:
		up = Vector3(dir.x, 0.0, dir.z).normalized()
		if up == Vector3.ZERO:
			up = Vector3.FORWARD
	_spray_ready_at = now + SPRAY_COOLDOWN
	Game.world.request_spray.rpc_id(1, r.position, normal, up)


# Pings: the ping key marks where you aim, for your team.


func _try_ping() -> void:
	if Game.world == null:
		return
	var from := cam.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from + aim_dir() * PING_RANGE, MASK_AIM, [get_rid()])
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty():
		Game.world.request_ping.rpc_id(1, r.position)


func _interact() -> void:
	var space := get_world_3d().direct_space_state
	var from := cam.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from + aim_dir() * 2.8, MapBuilder.L_DOOR | MapBuilder.L_WALL)
	var r := space.intersect_ray(q)
	if r.is_empty():
		return
	var door = r.collider.get_parent()
	if door is Door:
		var t: float = 0.0 if door.is_open() else door.away_from(global_position)
		Net.to_all(Game.world, "door_rpc", [door.idx, t, false], true, true)
