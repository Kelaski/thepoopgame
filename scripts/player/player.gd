class_name Player
extends CharacterBody3D
## First-person player. The owning peer simulates movement and shooting locally
## (client-authoritative movement, server-validated damage) and streams its state
## to everyone else at 30 Hz. Remote copies interpolate.

const STAND_H := 1.8
const CROUCH_H := 1.15
const RADIUS := 0.38
const EYE_STAND := 1.62
const EYE_CROUCH := 1.02
const WALK := 5.0
const SPRINT := 7.4
const CROUCH_SPEED := 2.8
const ADS_MULT := 0.62
const ACCEL := 60.0
const DECEL := 45.0
const AIR_ACCEL := 19.2  # air control below your run speed (was 16, +20%)
# Air strafing works like Titanfall / Source: above your run speed, strafing while
# you turn adds speed (up to AIR_SPEED_LIMIT); pushing straight on adds nothing.
const AIR_STRAFE_ACCEL := 40.0
const AIR_WISH_CAP := 0.8
const AIR_SPEED_LIMIT := 17.0
const SPEED_CAP := 30.0         # global top speed (m/s, horizontal), whatever you're doing
const JUMP_BUFFER := 0.1        # a jump pressed this long before landing still happens
const LAND_GRACE := 0.12        # no ground friction for this long after landing, so hops keep speed
const OVERSPEED_FRICTION := 8.0 # how fast speed above your run speed bleeds off on the ground
const MANTLE_MIN := -0.2        # ledges from about level with your feet...
const MANTLE_MAX := 1.9         # ...up to this high can be mantled onto
const MANTLE_MAX_UP := 4.0      # only while not still shooting upwards faster than this
const MANTLE_PUSH := 3.5        # forward speed over the ledge
const MANTLE_RISE := 6.0        # climbing speed up the face
const MANTLE_TIME := 0.6        # longest a mantle can take
const GRAVITY := 16.0
const JUMP_V := 6.4
const DJUMP_V := 7.0
const BOUNCE_V := JUMP_V * 1.4142  # bounce pads: sqrt(2) x jump speed = 2x the jump height
const WALLJUMP_BOOST := 2.5
const SLOPE_ACCEL_RAMP := 0.6  # extra downhill acceleration per second spent on the slope
const MAX_SLIDE_SPEED := 20.0
const SPAWN_PROTECTION := 3.0
const WALLRUN_MIN_SPEED := 3.0
const WALLRUN_TIME := 1.75       # longest a single wall run lasts
const WALLRUN_GRAVITY := 2.5     # gravity on the wall at the start of a run...
const WALLRUN_GRAVITY_END := 9.0 # ...building to this, so a run slowly sinks
const WALLRUN_START := 7.0       # a run starts at least this fast
const WALLRUN_SPEED := 10.5      # and speeds you up towards this
const WALLRUN_ACCEL := 4.0
const WALLRUN_LIFT := 1.4        # a little upward pop when a run starts
const WALLJUMP_OUT := 6.0
const WALLJUMP_UP := 6.2
const WALLJUMP_FREE := 3           # wall jumps before fatigue sets in
const WALLJUMP_FATIGUE := 0.75     # each later wall jump keeps 75% of the previous one's speed
const FATIGUE_GRAVITY_STEP := 0.5  # ...and adds +50% gravity
const FATIGUE_GRAVITY_MAX := 6.0   # up to 600%
const SLIDE_START_MIN := 5.5
const SLIDE_FRICTION := 3.2
const SLIDE_DRAG := 0.12          # extra slowdown per m/s above sprint speed, so fast slides bleed off sooner
const SLIDE_BOOST := 3.6          # speed a slide adds when it starts...
const SLIDE_BOOST_CD := 2.0       # ...at most once every this many seconds (no stacking from slide spam)
const LAND_SLIDE_MIN_FALL := 7.0  # landing in a slide faster than this (m/s down)...
const LAND_SLIDE_GAIN := 0.45     # ...turns this share of the extra fall speed into slide speed
const SLIDE_END := 3.6
const SLIDE_CD := 0.6
const MAX_GROUND_SPEED := 14.0
const NET_INTERVAL := 1.0 / 30.0
const YANK_MIN_GAP := 2.0          # s between grapple yanks from enemies
const NET_MAX_SPEED := 70.0        # m/s in total (falls are fast): faster movement updates are ignored
const NET_MAX_HSPEED := SPEED_CAP * 1.25  # m/s along the ground (speed hacks)
const NET_WINDOW := 1.0            # s: speeds are measured over this long, so per-update slack can't add up
const DOOR_SLAM_SPEED := 5.5

# Bounce pads (32) aren't in your movement masks: they're one-way, handled by
# _check_bounce_pad, so you pass up through them and bounce off the top.
const MASK_FULL := 1 | 2 | 8 | 16 | 64   # 64 = the sky barrier: it stops you...
const MASK_PHASE := 1 | 16 | 64
const MASK_PHASE_DOWN := 16 | 64
const MASK_AIM := (MASK_FULL | 32) & ~64        # ...but grapples, sprays, pings and shots go through it (and can hit pads)
const MASK_SHOT := 1 | 2 | 4 | 8 | 16

const F_CROUCH := 1
const F_SLIDE := 2
const F_INVIS := 4
const F_PHASE := 8
const F_PROT := 16
const F_ADS := 32
const F_MOVING := 64
const F_WALLRUN := 128
const F_GROUND := 256
const F_ROCKET := 512  # Moonwalker rocket boots firing

const VM_HIP := Vector3(0.24, -0.24, -0.5)
const VM_ADS := Vector3(0.0, -0.135, -0.36)
const VM_ADS_HOLO := Vector3(0.0, -0.118, -0.3)
const VM_ADS_IRONS := Vector3(0.0, -0.08, -0.3)
const GLINT_MIN_DOT := 0.6  # sniper glint shows when they aim within ~53 degrees of you
const NAMEPLATE_SCALE := 0.9  # teammate name size vs the original (0.15, then six times bigger)
# Teammate names fade while you aim near them, so they never cover a fight:
# fully faded within NAMEPLATE_FADE_NEAR degrees of the crosshair, back to full
# beyond NAMEPLATE_FADE_FAR.
const NAMEPLATE_FADE_NEAR := 10.0
const NAMEPLATE_FADE_FAR := 18.0
const NAMEPLATE_MIN_ALPHA := 0.12

const WEAPON_SCENES := {
	"ar": preload("res://assets/models/weapons/ar.tscn"),
	"smg": preload("res://assets/models/weapons/smg.tscn"),
	"shotgun": preload("res://assets/models/weapons/shotgun.tscn"),
	"sniper": preload("res://assets/models/weapons/sniper.tscn"),
	"bat": preload("res://assets/models/weapons/bat.tscn"),
}
const MUZZLE_FLASH_SCENE := preload("res://assets/models/muzzle_flash.tscn")
const GLINT_SCENE := preload("res://assets/models/glint.tscn")
const PARRY_SCENE := preload("res://assets/models/parry_bubble.tscn")
const ROCKET_SCENE := preload("res://assets/models/rocket_flame.tscn")
const PRI := 0  # addon slots: primary (Use Primary key)...
const SEC := 1  # ...and secondary (Use Secondary key)
const ROCKET_FLAME_TIME := 0.6
const TELEPORT_GRACE := 0.6  # s after the host moves someone (Warp, Swap) that their updates skip the movement check

var peer_id := 0
var is_local := false
var team := 0
var weapon := "ar"
var addon := Addons.DEFAULT_PRIMARY
var addon2 := Addons.DEFAULT_SECONDARY
var alive := false

# Nodes
var head: Node3D
var cam: Camera3D
var col_shape: CollisionShape3D
var capsule: CapsuleShape3D
var probe_shape: CapsuleShape3D
var body_root: Node3D
var tag_mesh: MeshInstance3D
var tp_pivot: Node3D     # shoulder; pitched with where the player looks
var tp_gun: Node3D       # the weapon everyone else sees you holding
var _glint: Node3D       # sniper scope glint
var _body_alpha := -1.0
var nameplate: Label3D
var head_col: CollisionShape3D
var viewmodel: Node3D
var vm_gun: Node3D
var vm_muzzle: Node3D
var vm_flash: MeshInstance3D

# Local simulation state
var yaw := 0.0
var pitch := 0.0
var crouching := false
var sliding := false
var sprinting := false
var slide_dir := Vector3.ZERO
var slide_cd := 0.0
var coyote := 0.0
var _bounce_cd := 0.0  # stops a bounce pad firing again while you leave it
var dj_ready := true
var aiming := false
var ads_t := 0.0
var _aim_toggle := false
var _crouch_toggle := false
var fire_cd := 0.0
var ammo := 30
var reloading := 0.0
var recoil := 0.0
var swing_t := 0.0
var flash_t := 0.0
var bob := 0.0
var cam_roll := 0.0
var damage_flash := 0.0

# Wall running
var wallrunning := false
var wall_normal := Vector3.ZERO
var wallrun_t := 0.0
var wallrun_cd := 0.0
var _last_wall_normal := Vector3.ZERO
var _wall_touch_t := 0.0          # coyote: recently touched a wall in the air
var _wall_touch_n := Vector3.ZERO
var _wall_jump_t := 0.0           # coyote: recently left a wall run
var _wall_jump_n := Vector3.ZERO
var wall_jumps := 0               # wall jumps since you last touched the floor
var _step_t := 0.0

# Addon state
var addon_active: Array[float] = [0.0, 0.0]  # per slot: time left on the ability
var addon_cd: Array[float] = [0.0, 0.0]      # per slot: cooldown left
var _cd_full: Array[float] = [0.0, 0.0]      # per slot: what that cooldown started at (for the HUD bar)
var rocket_armed := false  # Moonwalker: the next jump is a rocket jump
var _rocket_t := 0.0       # flame showing (local: time left; sent as F_ROCKET)
var swap_t := 0.0          # Swap: beam charging (the host does the swap)
var _parry_t := 0.0        # pink bubble showing (everyone)
var _parry_bubble: Node3D
var _rocket_flame: Node3D
var invisible := false
var phasing := 0.0
var floor_phase := 0.0
var _last_crouch_tap := -10.0
enum Hook { NONE, FLYING, ATTACHED }
var grapple_state: int = Hook.NONE
var grapple_point := Vector3.ZERO    # where the hook is attached
var grapple_t := 0.0                 # time left on the rope
var _grapple_target: Player = null   # hooked player (the hook follows them)
var _grapple_offset := Vector3.ZERO
var _hook_pos := Vector3.ZERO        # flying hook
var _hook_dir := Vector3.ZERO
var _hook_dist := 0.0
var _rope_len := 0.0                 # only ever shortens, so you swing below the anchor
var _rope: MeshInstance3D
var _hook_mesh: MeshInstance3D

# Spawn protection
var prot_pending := false  # kept for compatibility; protection is now a plain timer
var _vm_ads := VM_ADS
var _slope_t := 0.0
var _air_fall := 0.0  # fastest you were falling since you left the ground (m/s)
var _recent_fall := 0.0    # how hard you last landed, for a slide started just after
var _recent_fall_t := 0.0  # ...and how long that still counts
var _jump_buffer_t := 0.0  # a jump press waiting for you to land
var _land_grace := 0.0     # time left without ground friction after landing
var _slide_boost_cd := 0.0
var _slide_pending_boost := false  # a slide started in the air gets its boost when it lands
var _mantle_cd := 0.0
var _air_side := Vector3.ZERO  # the A / D part of your input this frame (air strafing)
var _mantle_t := 0.0       # time left in a mantle
var _mantle_dir := Vector3.ZERO
var _mantle_top := 0.0     # height of the ledge being climbed
var _mantle_speed := 0.0
var prot_left := 0.0

var _door_exceptions := {}
var _net_acc := 0.0
var _now := 0.0
var _prev_pos := Vector3.ZERO
var _cur_pos := Vector3.ZERO

# Remote state
var net_pos := Vector3.ZERO
var net_vel := Vector3.ZERO
var net_yaw := 0.0
var net_pitch := 0.0
var net_flags := 0
var _has_net := false
var _last_yank := -100.0  # when an enemy grapple last yanked us
var _anchor_pos := Vector3.ZERO  # accepted position the current speed window started at
var _anchor_t := -1.0            # ...and when (s); -1 = start a new window
var _jump_votes := 0     # updates in a row that put this player somewhere it couldn't have moved to
var _jump_pos := Vector3.ZERO    # where that run of updates started...
var _jump_t := 0.0               # ...and when
var _last_sent := -INF           # sender's clock time of the last update used
var _clock_off := INF            # quickest (arrival - sent) seen: maps their clock onto ours
var _net_free_until := -1.0      # the host moved this player: accept their updates until then


func setup(id: int, info: Dictionary) -> void:
	peer_id = id
	name = str(id)
	team = info.get("team", 0)
	weapon = info.get("weapon", "ar")
	addon = info.get("addon", Addons.DEFAULT_PRIMARY)
	addon2 = info.get("addon2", Addons.DEFAULT_SECONDARY)


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
	tag_mesh = $BodyRoot/TagMarker
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


# ================================================================ visuals

## Team colours on the model: anything in the "team_color" group gets the team
## colour, "team_color_dark" a darker shade (add parts to these groups in the
## editor to colour them too). Also the nameplate.
func _apply_team_look() -> void:
	var tc := Mats.team_color(team)
	for n in WeaponModel._in_group(self, "team_color"):
		n.material_override = Mats.toon(tc)
	for n in WeaponModel._in_group(self, "team_color_dark"):
		n.material_override = Mats.toon(tc.darkened(0.3))
	tag_mesh.material_override = Mats.glow(Mats.TAG_COLOR)
	nameplate.pixel_size = 0.0015 * NAMEPLATE_SCALE
	nameplate.modulate = tc.lightened(0.55)
	nameplate.text = Net.name_of(peer_id)
	_apply_overlay()


# Outlines, as a material overlay on every body part:
# * teammates: a hollow white outline, through walls too (assets/materials/
#   team_outline.tres: the body marks its shape in the stencil buffer, and a
#   slightly grown copy is drawn in white only outside that shape)
# * Stalker scan: while the local Stalker's ability runs, other players get a red
#   outline drawn through walls (assets/materials/scan_outline.tres)
const SCAN_OUTLINE := preload("res://assets/materials/scan_outline.tres")
const TEAM_OUTLINE := preload("res://assets/materials/team_outline.tres")
var _scan_shown := false


func set_scan_outline(on: bool) -> void:
	if on == _scan_shown:
		return
	_scan_shown = on
	_apply_overlay()


func _apply_overlay() -> void:
	var mine := Net.team_of(multiplayer.get_unique_id())
	var overlay: Material = null
	if _scan_shown:
		overlay = SCAN_OUTLINE
	elif not is_local and mine >= 0 and team == mine:
		overlay = TEAM_OUTLINE
	for mi: MeshInstance3D in _meshes_under(body_root, []):
		mi.material_overlay = overlay


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
func _check_bounce_pad(delta: float) -> void:
	if velocity.y > 0.5 or _bounce_cd > 0.0 or is_on_floor():
		return
	var space := get_world_3d().direct_space_state
	var hit := false
	# Coming down onto the top this frame: the centre of your feet, plus a ring at
	# your capsule's edge so landing on a rim counts too.
	var drop := maxf(-velocity.y * delta, 0.0) + 0.06
	var step := Vector3(velocity.x, 0.0, velocity.z) * delta
	for off: Vector3 in [Vector3.ZERO, Vector3(RADIUS * 0.7, 0, 0), Vector3(-RADIUS * 0.7, 0, 0), Vector3(0, 0, RADIUS * 0.7), Vector3(0, 0, -RADIUS * 0.7)]:
		var from := global_position + off + step + Vector3(0, 0.35, 0)
		var q := PhysicsRayQueryParameters3D.create(from, from - Vector3(0, 0.35 + drop, 0), MapBuilder.L_BOUNCE, [get_rid()])
		var r := space.intersect_ray(q)
		if not r.is_empty() and (r.normal as Vector3).y >= 0.5 and (r.position as Vector3).y <= global_position.y + 0.3:
			global_position.y = maxf(global_position.y, (r.position as Vector3).y)
			hit = true
			break
	if not hit:
		# Anywhere else on your body touching the pad (its rim or side) counts as
		# hitting it too, so jumping into an umbrella launches you.
		var q2 := PhysicsShapeQueryParameters3D.new()
		q2.shape = capsule
		q2.transform = global_transform * col_shape.transform
		q2.collision_mask = MapBuilder.L_BOUNCE
		q2.exclude = [get_rid()]
		hit = not space.intersect_shape(q2, 1).is_empty()
	if not hit:
		return
	_bounce_cd = 0.25
	velocity.y = BOUNCE_V
	coyote = 0.0
	dj_ready = true
	Sfx.play("jump", -2.0, 1.25)
	_on_moved()


## Fades this teammate's name out while it's near your crosshair.
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
	var gp := wm.glint_point()
	if gp:
		_glint = GLINT_SCENE.instantiate()
		_glint.visible = false
		gp.add_child(_glint)
	if body_root:
		_apply_overlay()  # the new gun gets the outline too


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
		if c == tag_mesh or c == _glint:
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


# ================================================================ state changes

func refresh_loadout() -> void:
	var old_weapon := weapon
	var old_addons := [addon, addon2]
	if Net.players.has(peer_id):
		var info: Dictionary = Net.players[peer_id]
		team = info.team
		weapon = info.weapon
		addon = info.addon
		addon2 = info.get("addon2", addon2)
	if weapon != old_weapon:
		_rebuild_tp_gun()
		# A new gun comes loaded (matters when you swap during the countdown).
		ammo = int(Weapons.DATA[weapon].mag)
		reloading = 0.0
		fire_cd = 0.0
	for slot in 2:
		if addon_in(slot) != old_addons[slot]:
			addon_active[slot] = 0.0
			addon_cd[slot] = 0.0
	rocket_armed = rocket_armed and addon == "moonwalker"
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
		swap_t = 0.0
		_rocket_t = 0.0
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
	addon_cd = [0.0, 0.0]
	rocket_armed = false
	_rocket_t = 0.0
	swap_t = 0.0
	_parry_t = 0.0
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


func is_protected() -> bool:
	if is_local:
		return prot_left > 0.0
	return (net_flags & F_PROT) != 0


func is_crouched() -> bool:
	if is_local:
		return crouching or sliding
	return (net_flags & (F_CROUCH | F_SLIDE)) != 0


func is_head_hit(p: Vector3) -> bool:
	return p.y > global_position.y + (0.82 if is_crouched() else 1.4)


## Below the halfway mark of the body.
func is_lower_hit(p: Vector3) -> bool:
	return p.y < global_position.y + (CROUCH_H if is_crouched() else STAND_H) * 0.5


func aim_dir() -> Vector3:
	if cam:
		return -cam.global_basis.z
	return -(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)).z


func eye_pos() -> Vector3:
	return global_position + Vector3(0, head.position.y if head else EYE_STAND, 0)


func _set_crouch_shape(c: bool) -> void:
	var h := CROUCH_H if c else STAND_H
	if not is_equal_approx(capsule.height, h):
		capsule.height = h
		col_shape.position.y = h * 0.5
		head_col.position.y = (EYE_CROUCH if c else EYE_STAND) - 0.05
	if body_root:
		body_root.scale.y = 0.66 if c else 1.0


# ================================================================ input

func _input_ok() -> bool:
	return is_local and not Game.ui_open and not Game.typing and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


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


# ================================================================ simulation

func _physics_process(delta: float) -> void:
	if not is_local:
		return
	_now += delta
	_tick_timers(delta)
	if not alive:
		return
	var can_input := _input_ok()
	var frozen: bool = Game.phase == Game.Phase.PREROUND
	var move_in := Vector2.ZERO
	if can_input and not frozen:
		move_in = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	rotation.y = yaw
	head.rotation.x = pitch
	var wish := Basis(Vector3.UP, yaw) * Vector3(move_in.x, 0.0, move_in.y)
	_air_side = Basis(Vector3.UP, yaw) * Vector3(move_in.x, 0.0, 0.0)
	if wish.length() > 1.0:
		wish = wish.normalized()

	# --- Aim
	if weapon == "bat":
		aiming = false
	elif Settings.g("toggle_aim"):
		if can_input and Input.is_action_just_pressed("aim"):
			_aim_toggle = not _aim_toggle
		aiming = _aim_toggle
	else:
		aiming = can_input and Input.is_action_pressed("aim")

	# --- Crouch input. Crouch / Slide (crouch_tap) also starts slides; Crouch
	# (crouch_only) only ever crouches.
	var crouch_tap := can_input and not frozen and Input.is_action_just_pressed("crouch")
	var any_crouch_tap := crouch_tap or (can_input and not frozen and Input.is_action_just_pressed("crouch_only"))
	var want_crouch: bool
	if Settings.g("toggle_crouch"):
		if any_crouch_tap:
			_crouch_toggle = not _crouch_toggle
		want_crouch = _crouch_toggle
	else:
		want_crouch = can_input and (Input.is_action_pressed("crouch") or Input.is_action_pressed("crouch_only"))
	if any_crouch_tap:
		if phasing > 0.0 and _now - _last_crouch_tap < 0.35:
			floor_phase = 0.4  # Phantom: drop through the floor
		_last_crouch_tap = _now
	var jump_tap := can_input and not frozen and Input.is_action_just_pressed("jump")
	# A jump pressed just before you land happens the moment you touch down.
	_jump_buffer_t = JUMP_BUFFER if jump_tap else _jump_buffer_t - delta

	var on_floor := is_on_floor()
	var landed_fall := 0.0  # how hard you just landed (m/s), 0 if you didn't
	_recent_fall_t -= delta
	if on_floor:
		landed_fall = _air_fall
		_air_fall = 0.0
		if landed_fall > 0.0:
			_recent_fall = landed_fall
			_recent_fall_t = 0.3
			_land_grace = LAND_GRACE  # no ground friction for a moment: time a hop to keep your speed
	else:
		_air_fall = maxf(_air_fall, -velocity.y)
	_land_grace -= delta
	if on_floor:
		coyote = 0.12
		_last_wall_normal = Vector3.ZERO
		if wallrunning:
			_end_wallrun()
		dj_ready = true  # Skywalker double jump resets on landing
		wall_jumps = 0   # ...and so does wall-jump fatigue
	else:
		coyote -= delta
	_slide_boost_cd -= delta
	_mantle_cd -= delta

	var hvel := Vector3(velocity.x, 0.0, velocity.z)
	var speed_now := hvel.length()
	var forward_in := move_in.y < -0.3
	# Sprint is the default pace: moving forward is always a sprint, except while
	# aiming, crouching or sliding.
	var sprint_in := can_input
	sprinting = sprint_in and forward_in and not aiming and not sliding and not want_crouch

	# --- Wall contact coyote time (0.1 s)
	_wall_touch_t -= delta
	_wall_jump_t -= delta
	if not on_floor and is_on_wall():
		_wall_touch_t = 0.1
		_wall_touch_n = get_wall_normal()
	elif not on_floor and not wallrunning and speed_now > WALLRUN_MIN_SPEED:
		# A wall just beside you counts too, so running alongside one (without
		# steering into it) still starts a wall run.
		var side_n := _side_wall(Basis(Vector3.UP, yaw).x)
		if side_n != Vector3.ZERO:
			_wall_touch_t = 0.1
			_wall_touch_n = side_n

	# --- Mantle: jump at a ledge (or fall past one) while pushing into it and you
	# climb straight up onto it, keeping some of your speed.
	var facing := Basis(Vector3.UP, yaw) * Vector3.FORWARD
	if not on_floor and not wallrunning and forward_in and _mantle_cd <= 0.0 and _wall_touch_t > 0.0 and velocity.y < MANTLE_MAX_UP and facing.dot(-_wall_touch_n) > 0.5:
		var mh := _mantle_height(-Vector3(_wall_touch_n.x, 0.0, _wall_touch_n.z).normalized())
		if mh > -1.0:
			_mantle_t = MANTLE_TIME
			_mantle_dir = -Vector3(_wall_touch_n.x, 0.0, _wall_touch_n.z).normalized()
			_mantle_top = global_position.y + maxf(mh, 0.0)
			_mantle_speed = maxf(speed_now * 0.6, MANTLE_PUSH)
			_mantle_cd = 0.5
			_wall_touch_t = 0.0
			Sfx.play("jump", -6.0, 0.8)
			_on_moved()

	# --- Wall run start: airborne, moving along a wall, and either holding forward,
	# holding a movement key into the wall, or hugging it (touching it). A run
	# starts at least at WALLRUN_START, lifts you a little, and can't go straight
	# back onto the wall you just left (another wall, or the floor, resets that).
	if not on_floor and not wallrunning and phasing <= 0.0 and wallrun_cd <= 0.0 and _wall_touch_t > 0.0:
		var n := _wall_touch_n
		var n_flat := Vector3(n.x, 0.0, n.z).normalized()
		var into_wall := wish.length() > 0.3 and wish.normalized().dot(-n_flat) > 0.25
		var hugging := is_on_wall() and get_wall_normal().dot(n_flat) > 0.9
		var along := hvel.normalized().dot(n)
		var same_wall := _last_wall_normal != Vector3.ZERO and n_flat.dot(_last_wall_normal) > 0.9
		if (forward_in or into_wall or hugging) and absf(n.y) < 0.3 and speed_now > WALLRUN_MIN_SPEED and velocity.y > -9.0 and absf(along) < 0.9 and not same_wall:
			wallrunning = true
			wall_normal = Vector3(n.x, 0.0, n.z).normalized()
			wallrun_t = 0.0
			# Entering a run catches your fall and gives a small lift (Titanfall-style:
			# runs stay roughly level and sink slowly at the end).
			velocity.y = clampf(velocity.y, WALLRUN_LIFT, WALLRUN_LIFT * 1.6)
			sliding = false
			_on_moved()

	# --- Slide start: Crouch / Slide while sprinting (or fast, or in the air: then
	# it starts when you land). Momentum carries straight in, and the boost only
	# comes back after SLIDE_BOOST_CD, so slide-hopping keeps speed without
	# stacking boosts.
	if crouch_tap and not sliding and not wallrunning and slide_cd <= 0.0 and speed_now > SLIDE_START_MIN and (sprint_in or speed_now > SPRINT or not on_floor):
		sliding = true
		_slope_t = 0.0
		slide_dir = hvel.normalized()
		_slide_pending_boost = _slide_boost_cd <= 0.0
		_on_moved()
	if sliding and on_floor and _slide_pending_boost:
		_slide_pending_boost = false
		_slide_boost_cd = SLIDE_BOOST_CD
		var fall := _recent_fall if _recent_fall_t > 0.0 else 0.0
		hvel = slide_dir * minf(hvel.length() + SLIDE_BOOST * _speed_mult() + _landing_bonus(fall), MAX_SLIDE_SPEED * _speed_mult())
		_recent_fall_t = 0.0
		landed_fall = 0.0  # already used

	if wallrunning:
		wallrun_t += delta
		var tangent := Vector3.UP.cross(wall_normal).normalized()
		if tangent.dot(hvel) < 0.0:
			tangent = -tangent
		# Wall runs speed you up towards WALLRUN_SPEED (never slowing you if you came
		# in faster), but not once wall-jump fatigue sets in.
		var run_speed := maxf(hvel.length(), WALLRUN_START * _speed_mult() * _wall_fatigue())
		var top := WALLRUN_SPEED * _speed_mult() * _wall_fatigue()
		if run_speed < top:
			run_speed = minf(top, run_speed + WALLRUN_ACCEL * delta)
		hvel = tangent * run_speed - wall_normal * 1.0
		# Gravity on the wall starts light and builds, so a run slowly sinks.
		var fg := _fatigue_gravity()
		var g := lerpf(WALLRUN_GRAVITY, WALLRUN_GRAVITY_END, clampf(wallrun_t / WALLRUN_TIME, 0.0, 1.0))
		velocity.y = maxf(velocity.y - g * fg * delta, -3.0 * fg)
		var still_on_wall := _ray_hits(global_position + Vector3(0, 1.0, 0), -wall_normal * (RADIUS + 0.4))
		# A run lasts while you hold any movement key (forward, or along / into the wall).
		if wallrun_t >= WALLRUN_TIME or not still_on_wall or wish.length() < 0.3 or any_crouch_tap:
			_end_wallrun()
		crouching = false
	elif sliding:
		var spd := hvel.length()
		if on_floor:
			# Landing hard in a slide turns some of the fall into speed.
			spd += _landing_bonus(landed_fall)
			var n := get_floor_normal()
			var downhill := Vector3(n.x, 0.0, n.z).dot(slide_dir)
			if downhill > 0.05:
				# Sliding downhill: accelerate (more on steeper slopes), and keep
				# accelerating the longer you stay on the slope.
				_slope_t += delta
				spd += GRAVITY * downhill * (1.0 + _slope_t * SLOPE_ACCEL_RAMP) * delta
			else:
				# Flat or uphill: gravity slows you going up, plus friction, plus drag
				# above sprint speed so a big boost still falls off.
				_slope_t = 0.0
				spd += GRAVITY * downhill * delta
				var over := maxf(0.0, spd - SPRINT * _speed_mult())
				spd -= (SLIDE_FRICTION + over * SLIDE_DRAG * SLIDE_FRICTION) * delta
		# A slide keeps going the way you were moving; steering only bends it a little.
		if wish != Vector3.ZERO:
			slide_dir = (slide_dir + wish * delta * 1.0).normalized()
		hvel = slide_dir * clampf(spd, 0.0, MAX_SLIDE_SPEED * _speed_mult())
		# Midair slides carry on until you land; on the ground they run until momentum is gone.
		var end_slide: bool = (on_floor and spd < SLIDE_END) or (not bool(Settings.g("toggle_crouch")) and not want_crouch)
		if end_slide:
			sliding = false
			_slide_pending_boost = false
			slide_cd = SLIDE_CD
		crouching = sliding or want_crouch
	else:
		crouching = want_crouch or (crouching and not _can_stand())
		var base := WALK
		if crouching:
			base = CROUCH_SPEED
		elif sprinting:
			base = SPRINT
		if aiming:
			base *= lerpf(1.0, ADS_MULT, ads_t)
		base *= _speed_mult()
		var target := wish * base
		if on_floor:
			if _land_grace > 0.0 and speed_now > base:
				# Just landed faster than you run: no friction yet, so a hop now keeps it all.
				hvel = _air_strafe(hvel, wish, base, delta)
			elif speed_now > base + 0.2:
				# Faster than you run (after a slide or hops): bleed it off quickly,
				# while you can still steer.
				var spd := maxf(base, speed_now - OVERSPEED_FRICTION * delta)
				var dir := (hvel / speed_now).lerp(wish if wish != Vector3.ZERO else hvel / speed_now, clampf(6.0 * delta, 0.0, 1.0)).normalized()
				hvel = dir * spd
			else:
				hvel = hvel.move_toward(target, (ACCEL if wish != Vector3.ZERO else DECEL) * delta)
		else:
			hvel = _air_strafe(hvel, wish, base, delta)
	_set_crouch_shape(crouching)

	# --- Mantling: rise up the face until your feet clear the ledge, then carry
	# over the top (so it works even on narrow ledges like a car roof).
	var mantling := _mantle_t > 0.0
	if mantling:
		_mantle_t -= delta
		if is_on_ceiling() or (_mantle_t < MANTLE_TIME - 0.4 and global_position.y < _mantle_top + 0.08):
			# Blocked overhead, or not clearing it: give up and fall back.
			_mantle_t = 0.0
			mantling = false
		elif global_position.y < _mantle_top + 0.08:
			velocity.y = MANTLE_RISE
			hvel = Vector3.ZERO  # straight up the face (pushing in would catch on lips)
		else:
			velocity.y = minf(velocity.y, 1.0)
			hvel = _mantle_dir * _mantle_speed
			_mantle_t = minf(_mantle_t, 0.12)  # a moment over the top, then you're free

	# --- Gravity & jumping
	if not on_floor and not wallrunning and not mantling:
		velocity.y -= GRAVITY * _gravity_mult() * delta
	if _jump_buffer_t > 0.0:
		if wallrunning or (_wall_jump_t > 0.0 and not on_floor):
			# Kick off the wall: out, up, and along it, keeping (and adding to) your
			# speed so it chains into the next wall run, a slide, or a slide-hop.
			# Also works up to 0.1 s after leaving the wall. Fatigue: from the 4th
			# wall jump without touching the floor, each kick loses speed instead.
			var n := wall_normal if wallrunning else _wall_jump_n
			wall_jumps += 1
			var fatigue := _wall_fatigue()
			velocity.y = _jump_speed(WALLJUMP_UP * lerpf(0.5, 1.0, fatigue))
			var along_wall := hvel - n * hvel.dot(n)
			if fatigue < 1.0:
				along_wall *= fatigue
			elif along_wall.length() > 0.5:
				along_wall += along_wall.normalized() * WALLJUMP_BOOST
			hvel = along_wall + n * WALLJUMP_OUT * fatigue
			_end_wallrun()
			_wall_jump_t = 0.0
			_wall_touch_t = 0.0
			_jump_buffer_t = 0.0
			_on_moved()
		elif coyote > 0.0:
			# Jumping keeps all your speed: slide-hops and bunny hops chain.
			if crouching and not sliding and _can_stand():
				crouching = false
				_crouch_toggle = false
				_set_crouch_shape(false)
			velocity.y = _jump_speed(JUMP_V)
			coyote = 0.0
			_jump_buffer_t = 0.0
			_land_grace = 0.0
			if sliding:
				sliding = false
				_slide_pending_boost = false
				slide_cd = SLIDE_CD
				crouching = false
				_crouch_toggle = false
				_set_crouch_shape(false)
			_on_moved()
		elif jump_tap and addon2 == "skywalker" and dj_ready:
			# Extra height, current momentum kept as-is (no added speed).
			dj_ready = false
			velocity.y = _jump_speed(DJUMP_V)
			_jump_buffer_t = 0.0
			if sliding:
				sliding = false
				slide_cd = SLIDE_CD
			Sfx.play("jump", -4.0, 1.4)
			_on_moved()
	if grapple_state == Hook.FLYING:
		_tick_hook(delta)
	if grapple_state == Hook.ATTACHED:
		hvel = _apply_grapple(delta, hvel, wish, jump_tap, on_floor)
	# One global speed cap over everything (slides, hops, wall kicks, grapples,
	# speed bonuses included).
	if hvel.length() > SPEED_CAP:
		hvel = hvel.normalized() * SPEED_CAP
	velocity.x = hvel.x
	velocity.z = hvel.z
	if move_in != Vector2.ZERO:
		_on_moved()

	# --- Doors fly open when sprinting / sliding into them
	if hvel.length() > DOOR_SLAM_SPEED:
		_check_door_slam(hvel.normalized())

	# --- Phantom collision masks
	if floor_phase > 0.0:
		collision_mask = MASK_PHASE_DOWN
	elif phasing > 0.0:
		collision_mask = MASK_PHASE
	else:
		collision_mask = MASK_FULL

	_bounce_cd -= delta
	_check_bounce_pad(delta)
	move_and_slide()
	if global_position.y < -25.0:
		global_position = Vector3(global_position.x, 2.0, global_position.z)
		velocity = Vector3.ZERO
		_cur_pos = global_position
	_prev_pos = _cur_pos
	_cur_pos = global_position

	# --- Actions
	if can_input and not frozen:
		if Input.is_action_just_pressed("reload"):
			_start_reload()
		if Input.is_action_pressed("fire"):
			_try_fire()
		if Input.is_action_just_pressed("addon"):
			_use_addon(PRI)
		if Input.is_action_just_pressed("addon2"):
			_use_addon(SEC)
		if Input.is_action_just_pressed("interact"):
			_interact()
		if Input.is_action_just_pressed("spray"):
			_try_spray()
		if Input.is_action_just_pressed("ping"):
			_try_ping()
	# The grapple is held: letting go of the ability key (or opening a menu / chat)
	# lets go of the rope, or reels a flying hook back in.
	if grapple_state != Hook.NONE and not (can_input and Input.is_action_pressed("addon")):
		_end_grapple()

	_net_acc += delta
	if _net_acc >= NET_INTERVAL:
		_net_acc = 0.0
		_net_state.rpc(global_position, yaw, pitch, velocity, _flags(), Time.get_ticks_msec() / 1000.0)


## Extra slide speed from landing hard: a share of the fall speed beyond
## LAND_SLIDE_MIN_FALL.
func _landing_bonus(fall: float) -> float:
	return maxf(0.0, fall - LAND_SLIDE_MIN_FALL) * LAND_SLIDE_GAIN


## Air movement. Below your run speed you speed up and steer freely; above it,
## it works like Titanfall / Source air strafing: strafing while you turn adds a
## little speed (up to AIR_SPEED_LIMIT), pushing straight on adds nothing, and
## holding back brakes.
func _air_strafe(hvel: Vector3, wish: Vector3, base: float, delta: float) -> Vector3:
	if wish == Vector3.ZERO:
		return hvel
	var speed := hvel.length()
	if speed < base:
		hvel += wish * AIR_ACCEL * _air_mult() * delta
		if hvel.length() > base:
			hvel = hvel.normalized() * base
		return hvel
	# Holding W while you strafe doesn't get in the way: when A or D is held, only
	# the sideways part of your input counts. (It's your input's sideways part, not
	# one relative to your velocity, so A / D alone steer you only a little; the
	# speed comes from turning with the mouse as you strafe.)
	var wd := _air_side if _air_side.length() > 0.1 else wish
	wd = wd.normalized()
	var add := AIR_WISH_CAP - hvel.dot(wd)
	if add <= 0.0:
		return hvel
	var out := hvel + wd * minf(AIR_STRAFE_ACCEL * _air_mult() * delta, add)
	var limit := maxf(speed, AIR_SPEED_LIMIT * _speed_mult())
	if out.length() > limit:
		out = out.normalized() * limit
	return out


## Normal of a wall right beside you (to your left or right, within reach), or ZERO.
func _side_wall(right: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0, 1.0, 0)
	for side: float in [1.0, -1.0]:
		var q := PhysicsRayQueryParameters3D.create(from, from + right * side * (RADIUS + 0.45), MapBuilder.L_WALL | MapBuilder.L_SOLID, [get_rid()])
		var r := space.intersect_ray(q)
		if not r.is_empty() and absf((r.normal as Vector3).y) < 0.3:
			return r.normal
	return Vector3.ZERO


## How high (above your feet) the top of a ledge just ahead in dir is, if you can
## mantle onto it (a flat top MANTLE_MIN..MANTLE_MAX up, with room to stand), or -1.
func _mantle_height(dir: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	var mask := MASK_FULL & ~MapBuilder.L_PLAYER & ~64
	var from := global_position + Vector3(0, MANTLE_MAX + 0.3, 0) + dir * (RADIUS + 0.45)
	var q := PhysicsRayQueryParameters3D.create(from, from - Vector3(0, MANTLE_MAX + 0.3 - MANTLE_MIN, 0), mask, [get_rid()])
	var r := space.intersect_ray(q)
	if r.is_empty() or (r.normal as Vector3).y < 0.7:
		return -1.0
	var top: Vector3 = r.position
	var room := PhysicsShapeQueryParameters3D.new()
	room.shape = probe_shape
	room.transform = Transform3D(Basis.IDENTITY, top + Vector3(0, STAND_H * 0.5 + 0.1, 0))
	room.collision_mask = mask
	room.exclude = [get_rid()]
	if not space.intersect_shape(room, 1).is_empty():
		return -1.0
	return top.y - global_position.y


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
			ammo = int(Weapons.DATA[weapon].mag)
	for b in _door_exceptions.keys():
		_door_exceptions[b] -= delta
		if _door_exceptions[b] <= 0.0:
			_door_exceptions.erase(b)
			if is_instance_valid(b):
				remove_collision_exception_with(b)
	_tick_addon(delta)


func _speed_mult() -> float:
	var m := 1.0
	if weapon == "bat":
		m *= Weapons.BAT_SPEED_MULT
	if addon2 == "trackstar":
		m *= Addons.TRACK_ACTIVE if addon_active[SEC] > 0.0 else Addons.TRACK_PASSIVE
	return m


## Moonwalker: 20% less gravity. Wall-jump fatigue adds on top.
func _gravity_mult() -> float:
	return _fatigue_gravity() * (Addons.MOON_GRAVITY if addon == "moonwalker" else 1.0)


## Moonwalker: 15% better air control.
func _air_mult() -> float:
	return Addons.MOON_AIR if addon == "moonwalker" else 1.0


## Upward speed for a jump: normally v, but an armed Moonwalker rocket launches
## you MOON_ROCKET_H up instead (and its cooldown starts).
func _jump_speed(v: float) -> float:
	if not rocket_armed:
		return v
	rocket_armed = false
	addon_cd[PRI] = Addons.MOON_CD
	_rocket_t = ROCKET_FLAME_TIME
	Sfx.play("rocket", -3.0)
	return maxf(v, sqrt(2.0 * GRAVITY * _gravity_mult() * Addons.MOON_ROCKET_H))


## 1.0 for your first WALLJUMP_FREE wall jumps, then 0.75, 0.56, 0.42... for each
## extra one until you touch the floor.
func _wall_fatigue() -> float:
	return pow(WALLJUMP_FATIGUE, maxi(0, wall_jumps - WALLJUMP_FREE))


## Gravity multiplier from wall-jump fatigue: 1.0 for your first WALLJUMP_FREE wall
## jumps, then +50% per extra one (1.5, 2.0, 2.5...) up to 6x, until you touch the floor.
func _fatigue_gravity() -> float:
	return minf(1.0 + FATIGUE_GRAVITY_STEP * maxi(0, wall_jumps - WALLJUMP_FREE), FATIGUE_GRAVITY_MAX)


func _end_wallrun() -> void:
	if wallrunning:
		_last_wall_normal = wall_normal
		_wall_jump_t = 0.1
		_wall_jump_n = wall_normal
	wallrunning = false
	wallrun_cd = 0.3


func _ray_hits(from: Vector3, offset: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, from + offset, MapBuilder.L_WALL | MapBuilder.L_FLOOR | MapBuilder.L_SOLID | MapBuilder.L_DOOR, [get_rid()])
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _on_moved() -> void:
	prot_left = 0.0  # moving or shooting ends spawn protection


func _overlaps(mask: int, shape: Shape3D, center_y: float) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0, center_y, 0))
	q.collision_mask = mask
	q.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func _can_stand() -> bool:
	return not _overlaps(collision_mask & ~MapBuilder.L_PLAYER, probe_shape, STAND_H * 0.5 + 0.1)


func _flags() -> int:
	var f := 0
	if crouching:
		f |= F_CROUCH
	if sliding:
		f |= F_SLIDE
	if invisible:
		f |= F_INVIS
	if phasing > 0.0:
		f |= F_PHASE
	if is_protected():
		f |= F_PROT
	if aiming:
		f |= F_ADS
	if Vector3(velocity.x, 0, velocity.z).length() > 0.4 or absf(velocity.y) > 1.0:
		f |= F_MOVING
	if wallrunning:
		f |= F_WALLRUN
	if _rocket_t > 0.0:
		f |= F_ROCKET
	if is_on_floor():
		f |= F_GROUND
	return f


@rpc("authority", "call_remote", "unreliable_ordered")
func _net_state(pos: Vector3, y: float, p: float, vel: Vector3, f: int, sent: float) -> void:
	if not (pos.is_finite() and vel.is_finite() and is_finite(y) and is_finite(p) and is_finite(sent)):
		return
	if not _net_filter(pos, sent, Time.get_ticks_msec() / 1000.0):
		return
	_observe_speed(pos, sent)
	net_pos = pos
	net_yaw = y
	net_pitch = clampf(p, -PI * 0.5, PI * 0.5)
	net_vel = vel
	net_flags = f
	if not _has_net:
		_has_net = true
		global_position = pos


# How fast this remote player has actually been moving, from the positions they
# sent (the server checks claimed speeds, like the bat's momentum damage, against it).
var _obs_pos := Vector3.ZERO
var _obs_t := -1.0
var _obs_speed := 0.0


## Movement check for one update (sent at the sender's clock time `sent`, arriving
## at `now`). Returns false to ignore it. Updates further than anyone can move
## since the window began (teleports, speed hacks) are ignored, and so are updates
## older than the last one (they arrive out of order). Respawns start a new window.
##
## Speeds are timed by when an update was *sent*, mapped onto our clock with the
## quickest delivery seen so far: over the internet updates often arrive in bursts
## after a stall, and timing them by arrival made players freeze. A sender whose
## clock runs fast gains nothing: the estimate never runs ahead of arrival.
func _net_filter(pos: Vector3, sent: float, now: float) -> bool:
	if sent <= _last_sent:
		return false
	_last_sent = sent
	_clock_off = minf(_clock_off, now - sent)
	var t := sent + _clock_off
	if now < _net_free_until:
		_anchor_t = -1.0  # the host just moved them (Warp, Swap): start again from here
	if _has_net and _anchor_t >= 0.0 and not _reachable(_anchor_pos, _anchor_t, pos, t):
		# A second of updates moving on from one new spot at legal speed (the
		# out-of-bounds reset) is accepted, so a player can't get stuck unseen.
		if _jump_votes == 0 or not _reachable(_jump_pos, _jump_t, pos, t):
			_jump_votes = 0
			_jump_pos = pos
			_jump_t = t
		_jump_votes += 1
		if _jump_votes < 30:
			return false
		_anchor_t = -1.0
	_jump_votes = 0
	if _anchor_t < 0.0 or t - _anchor_t >= NET_WINDOW:
		_anchor_pos = pos
		_anchor_t = t
	return true


## True if a player could get from `from` (at time t0) to `to` (at now) legally.
static func _reachable(from: Vector3, t0: float, to: Vector3, now: float) -> bool:
	var dt := maxf(now - t0, NET_INTERVAL)
	var d := to - from
	return d.length() <= NET_MAX_SPEED * dt + 3.0 and Vector2(d.x, d.z).length() <= NET_MAX_HSPEED * dt + 3.0


## Timed by the sender's clock, not arrival: a client that holds its updates and
## sends them in a burst would otherwise look many times faster. Gaps count as at
## least one send interval, so squeezing the timestamps doesn't help either.
func _observe_speed(pos: Vector3, now: float) -> void:
	if _obs_t > 0.0 and now > _obs_t:
		var d := Vector2(pos.x - _obs_pos.x, pos.z - _obs_pos.z).length()
		var inst := d / maxf(now - _obs_t, NET_INTERVAL)
		# Peak speed that decays over about half a second.
		_obs_speed = maxf(inst, _obs_speed * exp(-(now - _obs_t) * 2.0))
	_obs_pos = pos
	_obs_t = now


func observed_speed() -> float:
	return _obs_speed


# ================================================================ per-frame visuals

func _process(delta: float) -> void:
	_tick_parry_bubble(delta)
	if not is_local and grapple_state == Hook.FLYING:
		_hook_dist = minf(_hook_dist + Addons.GRAPPLE_HOOK_SPEED * delta, Addons.GRAPPLE_RANGE)
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
	if net_flags & F_INVIS:
		if (net_flags & F_MOVING) and not (net_flags & F_CROUCH):
			transparency = 0.9
		else:
			vis = false
	elif net_flags & F_PHASE:
		transparency = 0.45
	elif net_flags & F_PROT:
		transparency = 0.35 + 0.25 * sin(Time.get_ticks_msec() * 0.02)
	_set_body_alpha(transparency, vis)
	tag_mesh.visible = Game.holder == peer_id
	if tag_mesh.visible:
		tag_mesh.rotation.y += delta * 3.0
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
	var fov := rad_to_deg(2.0 * atan(tan(deg_to_rad(target_fov) * 0.5) / zf))
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
	var bob_amt := (1.0 - ads_t) * clampf(hspeed / SPRINT, 0.0, 1.0)
	var pos := VM_HIP.lerp(_vm_ads, ads_t)
	pos += Vector3(sin(bob) * 0.014, absf(cos(bob)) * 0.014, 0.0) * bob_amt
	pos.z += recoil * 0.035
	if sprinting:
		pos += Vector3(-0.04, -0.03, 0.02)
	viewmodel.position = viewmodel.position.lerp(pos, clampf(delta * 20.0, 0.0, 1.0))
	var rot := Vector3.ZERO
	if sprinting:
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


# ================================================================ weapons

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
	if addon2 == "trackstar" and weapon in Addons.RECHAMBER_WEAPONS:
		t *= Addons.track_mult(weapon)
	return t


## Trackstar reloads 35% faster (30% with the sniper).
func reload_time() -> float:
	return float(Weapons.DATA[weapon].reload) * (Addons.track_mult(weapon) if addon2 == "trackstar" else 1.0)


func _spread_dir(b: Basis, deg: float) -> Vector3:
	var fwd := -b.z
	if deg <= 0.0:
		return fwd
	var a := randf() * TAU
	var rr := sqrt(randf()) * tan(deg_to_rad(deg))
	return (fwd + b.x * cos(a) * rr + b.y * sin(a) * rr).normalized()


func _try_fire() -> void:
	if fire_cd > 0.0 or reloading > 0.0 or Game.world == null:
		return
	var w: Dictionary = Weapons.DATA[weapon]
	if weapon != "bat" and ammo <= 0:
		_start_reload()
		return
	fire_cd = shot_interval()
	_on_moved()
	if invisible:
		_end_invis()  # Firing breaks Hider invisibility.
	var origin := cam.global_position
	var b := cam.global_basis
	var ends := PackedVector3Array()
	var hits := {}
	match weapon:
		"ar", "smg":
			var spread := lerpf(float(w.hip), float(w.ads), ads_t)
			if sliding or not is_on_floor():
				spread *= 1.6
			var res := _hitscan(origin, _spread_dir(b, spread), w.range, 0, false)
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
				var res := _hitscan(origin, _spread_dir(b, float(w.cone) * 0.5), w.range, 0, false)
				if i % 3 == 0:
					ends.append(res.end)
				for h in res.hits:
					_acc(hits, h.id, Weapons.shotgun_pellet_damage(h.dist), h.head)
		"sniper":
			var spread := lerpf(float(w.hip), float(w.ads), ads_t)
			var res := _hitscan(origin, _spread_dir(b, spread), w.range, 1, true)
			ends.append(res.end)
			for h in res.hits:
				# Headshots always kill; lower body takes slightly less.
				var dmg: float = w.dmg_head if h.head else (w.dmg_low if h.low else w.dmg)
				_acc(hits, h.id, dmg, h.head)
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
	for id in hits:
		Game.report_hit.rpc_id(1, id, hits[id][0], hits[id][1], weapon)
	Sfx.play(weapon, -3.0, randf_range(0.95, 1.05))
	if weapon != "bat":
		var muzzle := vm_muzzle.global_position if vm_muzzle else origin
		Game.world.add_tracers(muzzle, ends, weapon)
		Game.world.fx_shot.rpc(global_position + Vector3(0, 1.25, 0), ends, weapon)
	else:
		Game.world.fx_shot.rpc(global_position + Vector3(0, 1.25, 0), PackedVector3Array(), weapon)


func _acc(hits: Dictionary, id: int, dmg: float, head_hit: bool) -> void:
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
		if col is Player:
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
		Game.world.add_impact(r.position)
		return {"hits": hits, "end": r.position}
	return {"hits": hits, "end": end}


# ================================================================ addons
# Two slots: the primary addon (Addons.PRIMARY, on Use Primary) and the secondary
# (Addons.SECONDARY, on Use Secondary). addon_active / addon_cd are per slot.
# Warp, Swap and Parry are refereed by the host (Game.report_warp, request_swap,
# request_parry): it moves players for everyone and decides who a parry protects.

func addon_in(slot: int) -> String:
	return addon if slot == PRI else addon2


func has_addon(id: String) -> bool:
	return id == addon or id == addon2


func _use_addon(slot: int) -> void:
	if addon_cd[slot] > 0.0:
		return
	match addon_in(slot):
		"hider":
			if not invisible:
				invisible = true
				addon_active[slot] = Addons.HIDER_TIME
				Sfx.play("addon", -4.0)
		"grapple":
			if grapple_state == Hook.NONE:
				_fire_grapple()
		"warp":
			_warp()
		"swap":
			if swap_t <= 0.0 and _enemy_in_swap_range():
				swap_t = Addons.SWAP_CHARGE
				addon_cd[slot] = Addons.SWAP_CD
				Sfx.play("swap_beam", -3.0)
				Game.request_swap.rpc_id(1)
		"moonwalker":
			if not rocket_armed:
				rocket_armed = true
				Sfx.play("addon", -4.0, 1.5)
		"trackstar":
			addon_active[slot] = Addons.TRACK_TIME
			addon_cd[slot] = Addons.TRACK_CD
			Sfx.play("addon", -4.0, 1.3)
		"phantom":
			if phasing <= 0.0:
				phasing = Addons.PHANTOM_TIME
				Sfx.play("addon", -4.0, 0.7)
		"stalker":
			addon_active[slot] = Addons.STALKER_SCAN_TIME
			addon_cd[slot] = Addons.STALKER_SCAN_CD
			Sfx.play("addon", -4.0, 0.85)
		"parry":
			addon_active[slot] = Addons.PARRY_TIME
			addon_cd[slot] = Addons.PARRY_TIME + Addons.PARRY_CD
			show_parry()
			Sfx.play("parry", -3.0)
			Game.request_parry.rpc_id(1)


## Warp: blink WARP_DIST the way you're looking, stopping just short of anything
## solid (even while Phantom is phasing you), with all your speed turned that way.
func _warp() -> void:
	var dir := aim_dir()
	if is_on_floor() and dir.y < 0.0:
		dir = Vector3(dir.x, 0.0, dir.z).normalized()  # aiming down on the ground: along it
	var mask := collision_mask
	collision_mask = MASK_FULL
	var hit := move_and_collide(dir * Addons.WARP_DIST, true, 0.05)
	collision_mask = mask
	var travel := dir * Addons.WARP_DIST if hit == null else hit.get_travel()
	if travel.length() < 0.5:
		return  # right up against a wall: nothing happens, no cooldown
	global_position += travel
	_prev_pos = global_position
	_cur_pos = global_position
	velocity = dir * velocity.length()
	if wallrunning:
		_end_wallrun()
	_mantle_t = 0.0
	_end_grapple()
	addon_cd[PRI] = Addons.WARP_CD
	Sfx.play("warp", -3.0)
	Game.report_warp.rpc_id(1, global_position)
	_on_moved()


## Swap only starts if an enemy is in range here (the host checks again at the end).
func _enemy_in_swap_range() -> bool:
	if Game.world == null:
		return false
	for p: Player in Game.world.players.values():
		if p.team != team and p.alive and p.global_position.distance_to(global_position) <= Addons.SWAP_RANGE:
			return true
	Game.announce.emit("No enemy within %dm to swap with" % int(Addons.SWAP_RANGE), Color("ff5cc6"))
	return false


## The host moved this player (Warp, Swap). With move_self the local player is
## moved too (Swap); a warp has already moved them.
func net_teleport(pos: Vector3, move_self: bool) -> void:
	if is_local:
		if not move_self:
			return
		global_position = pos
		_prev_pos = pos
		_cur_pos = pos
		if wallrunning:
			_end_wallrun()
		_mantle_t = 0.0
		_end_grapple()
		swap_t = 0.0
		Sfx.play("warp", -2.0, 0.8)
		return
	global_position = pos
	net_pos = pos
	_anchor_t = -1.0
	_jump_votes = 0
	_net_free_until = Time.get_ticks_msec() / 1000.0 + TELEPORT_GRACE


## Reload on Kill: a kill refills the magazine and chambers a round.
func on_kill() -> void:
	if addon2 != "reloader" or weapon == "bat" or not alive:
		return
	ammo = int(Weapons.DATA[weapon].mag)
	reloading = 0.0
	fire_cd = 0.0
	Sfx.play("reload", -4.0, 1.4)


## Parry: true while this (local) player's parry is up.
func parrying() -> bool:
	return addon2 == "parry" and addon_active[SEC] > 0.0


## Shows the pink parry bubble (everyone sees it; the host says when).
func show_parry() -> void:
	_parry_t = Addons.PARRY_TIME


func _tick_parry_bubble(delta: float) -> void:
	_parry_t = maxf(0.0, _parry_t - delta)
	var on := _parry_t > 0.0 and alive
	if on and _parry_bubble == null:
		_parry_bubble = PARRY_SCENE.instantiate()
		add_child(_parry_bubble)
	if _parry_bubble:
		_parry_bubble.visible = on


func _show_rocket_flame(on: bool) -> void:
	if on and _rocket_flame == null:
		_rocket_flame = ROCKET_SCENE.instantiate()
		add_child(_rocket_flame)
	if _rocket_flame:
		_rocket_flame.visible = on


# ---------------------------------------------------------------- grapple
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
	_grapple_net.rpc(Hook.FLYING, _hook_pos, _hook_dir)
	_on_moved()


func _tick_hook(delta: float) -> void:
	var step := minf(Addons.GRAPPLE_HOOK_SPEED * delta, Addons.GRAPPLE_RANGE - _hook_dist)
	var from := _hook_pos + _hook_dir * _hook_dist
	var to := from + _hook_dir * step
	var q := PhysicsRayQueryParameters3D.create(from, to, MASK_AIM | MapBuilder.L_PLAYER, [get_rid()])
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty():
		_attach_grapple(r.position, r.collider)
		return
	_hook_dist += step
	if _hook_dist >= Addons.GRAPPLE_RANGE - 0.01:
		# Missed: the hook reels back in and only a short cooldown applies.
		grapple_state = Hook.NONE
		addon_cd[PRI] = Addons.GRAPPLE_MISS_CD
		Sfx.play("addon_end", -6.0, 1.6)
		_grapple_net.rpc(Hook.NONE, Vector3.ZERO, Vector3.ZERO)


func _attach_grapple(point: Vector3, collider: Object) -> void:
	grapple_state = Hook.ATTACHED
	grapple_point = point
	grapple_t = Addons.GRAPPLE_MAX_TIME
	addon_cd[PRI] = Addons.GRAPPLE_CD
	_rope_len = point.distance_to(global_position + Vector3(0, 1.0, 0))
	_grapple_target = collider as Player
	if _grapple_target:
		_grapple_offset = point - _grapple_target.global_position
		if _grapple_target.team != team:
			_grapple_target._grapple_yank.rpc_id(_grapple_target.peer_id)
	Sfx.play("door", -6.0, 1.8)
	_grapple_net.rpc(Hook.ATTACHED, point, Vector3.ZERO)


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
	if d < Addons.GRAPPLE_ARRIVE:
		# Arrived: pop up and over the edge you hooked, keeping your momentum.
		v.y = maxf(v.y, Addons.GRAPPLE_END_POP)
		v += Vector3(n.x, 0.0, n.z) * 2.0
		if v.length() > Addons.GRAPPLE_MAX_SPEED:
			v = v.normalized() * Addons.GRAPPLE_MAX_SPEED
		velocity.y = v.y
		_end_grapple()
		return Vector3(v.x, 0.0, v.z)
	# The rope snaps if something gets between you and the hook.
	var q := PhysicsRayQueryParameters3D.create(chest, grapple_point - n * 0.35, MASK_AIM, [get_rid()])
	if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
		_end_grapple()
		return hvel
	if on_floor and v.y < 2.5:
		v.y = 2.5  # unstick from the ground
	v += n * Addons.GRAPPLE_PULL * delta
	v += wish * Addons.GRAPPLE_STEER * delta
	# Rope constraint: it only gets shorter, so outward speed is cancelled (swing).
	_rope_len = minf(_rope_len, d)
	if d > _rope_len + 0.05:
		var outward := -v.dot(n)
		if outward > 0.0:
			v += n * outward
	if v.length() > Addons.GRAPPLE_MAX_SPEED:
		v = v.normalized() * Addons.GRAPPLE_MAX_SPEED
	velocity.y = v.y
	sliding = false
	if wallrunning:
		_end_wallrun()
	_on_moved()
	return Vector3(v.x, 0.0, v.z)


func _end_grapple() -> void:
	if grapple_state == Hook.NONE:
		return
	if grapple_state == Hook.FLYING:
		addon_cd[PRI] = maxf(addon_cd[PRI], Addons.GRAPPLE_MISS_CD)
	grapple_state = Hook.NONE
	_grapple_target = null
	_grapple_net.rpc(Hook.NONE, Vector3.ZERO, Vector3.ZERO)


## Lets everyone else see the hook and rope. FLYING sends the throw origin and
## direction (remotes fly the hook themselves); ATTACHED sends the anchor point.
@rpc("authority", "call_remote", "reliable")
func _grapple_net(state: int, point: Vector3, dir: Vector3) -> void:
	if state < Hook.NONE or state > Hook.ATTACHED or not (point.is_finite() and dir.is_finite()):
		return
	if state != Hook.NONE and point.distance_to(global_position) > Addons.GRAPPLE_RANGE + 10.0:
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
@rpc("any_peer", "call_remote", "reliable")
func _grapple_yank() -> void:
	if not is_local or not alive or Game.world == null or parrying():
		return
	var from: Player = Game.world.players.get(multiplayer.get_remote_sender_id())
	if from == null or not from.alive or from.team == team or from.addon != "grapple":
		return
	# One yank per hook: a hooked enemy can't be flung again until the grapple could
	# have come off cooldown (stops a modified client spamming yanks).
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_yank < YANK_MIN_GAP:
		return
	var to := from.global_position - global_position
	if to.length() > Addons.GRAPPLE_RANGE + 6.0:
		return
	_last_yank = now
	velocity += to.normalized() * Addons.GRAPPLE_YANK + Vector3.UP * 3.0
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
		match addon_in(slot):
			"hider":
				if invisible:
					addon_active[slot] -= delta
					if addon_active[slot] <= 0.0:
						_end_invis()
				else:
					addon_cd[slot] = maxf(0.0, addon_cd[slot] - delta)
			"phantom":
				if phasing > 0.0:
					phasing -= delta
					if phasing <= 0.0:
						if alive and _overlaps(MapBuilder.L_WALL | MapBuilder.L_DOOR, probe_shape, STAND_H * 0.5 + 0.1):
							phasing = 0.05  # Still inside a wall: stay phased until clear.
						else:
							phasing = 0.0
							addon_cd[slot] = Addons.PHANTOM_CD
							Sfx.play("addon_end", -4.0)
				else:
					addon_cd[slot] = maxf(0.0, addon_cd[slot] - delta)
			_:
				addon_active[slot] = maxf(0.0, addon_active[slot] - delta)
				addon_cd[slot] = maxf(0.0, addon_cd[slot] - delta)
	swap_t = maxf(0.0, swap_t - delta)
	_rocket_t = maxf(0.0, _rocket_t - delta)
	if floor_phase > 0.0:
		floor_phase -= delta
		if floor_phase <= 0.0 and alive and _overlaps(MapBuilder.L_FLOOR, probe_shape, STAND_H * 0.5 + 0.1):
			floor_phase = 0.05


func _end_invis() -> void:
	if not invisible:
		return
	invisible = false
	addon_active[PRI] = 0.0
	addon_cd[PRI] = Addons.HIDER_CD
	Sfx.play("addon_end", -4.0)


## [label, fraction (0..1), state] for the HUD bar of an addon slot.
func addon_status(slot: int) -> Array:
	var act: float = addon_active[slot]
	var cd: float = addon_cd[slot]
	match addon_in(slot):
		"hider":
			if invisible:
				return ["INVISIBLE %.0fs" % act, act / Addons.HIDER_TIME, "active"]
			if cd > 0.0:
				return _cooling(slot)
		"grapple":
			if grapple_state == Hook.FLYING:
				return ["HOOK OUT", 1.0 - _hook_dist / Addons.GRAPPLE_RANGE, "active"]
			if grapple_state == Hook.ATTACHED:
				return ["GRAPPLING", grapple_t / Addons.GRAPPLE_MAX_TIME, "active"]
			if cd > 0.0:
				return _cooling(slot)
		"warp":
			if cd > 0.0:
				return _cooling(slot)
		"swap":
			if swap_t > 0.0:
				return ["SWAPPING", 1.0 - swap_t / Addons.SWAP_CHARGE, "active"]
			if cd > 0.0:
				return _cooling(slot)
		"moonwalker":
			if rocket_armed:
				return ["ROCKET: JUMP!", 1.0, "active"]
			if cd > 0.0:
				return _cooling(slot)
		"trackstar":
			if act > 0.0:
				return ["SPRINTING %.0fs" % act, act / Addons.TRACK_TIME, "active"]
			if cd > 0.0:
				return _cooling(slot)
		"phantom":
			if phasing > 0.0:
				return ["PHASING", phasing / Addons.PHANTOM_TIME, "active"]
			if cd > 0.0:
				return _cooling(slot)
		"stalker":
			if act > 0.0:
				return ["SCANNING %.0fs" % act, act / Addons.STALKER_SCAN_TIME, "active"]
			if cd > 0.0:
				return _cooling(slot)
		"parry":
			if act > 0.0:
				return ["PARRYING", act / Addons.PARRY_TIME, "active"]
			if cd > 0.0:
				return _cooling(slot)
		"skywalker":
			return ["DOUBLE JUMP READY" if dj_ready else "LAND TO RECHARGE", 1.0 if dj_ready else 0.0, "passive"]
		"reloader":
			return ["REFILLS ON KILL", 1.0, "passive"]
	return ["READY [%s]" % Settings.bind_text("addon" if slot == PRI else "addon2"), 1.0, "ready"]


func _cooling(slot: int) -> Array:
	var cd: float = addon_cd[slot]
	return ["%.1fs" % cd, 1.0 - cd / maxf(_cd_full[slot], cd), "cooldown"]


# ================================================================ doors

func _check_door_slam(dir: Vector3) -> void:
	var space := get_world_3d().direct_space_state
	for h: float in [0.5, 1.2]:
		var from := global_position + Vector3(0, h, 0)
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * (RADIUS + 0.7), MapBuilder.L_DOOR)
		var r := space.intersect_ray(q)
		if r.is_empty():
			continue
		var door = r.collider.get_parent()
		if door is Door and not _door_exceptions.has(r.collider):
			add_collision_exception_with(r.collider)
			_door_exceptions[r.collider] = 0.7
			if not door.is_open():
				Game.world.door_rpc.rpc(door.idx, door.away_from(global_position), true)
			return


const SPRAY_COOLDOWN := 5.0
const SPRAY_REACH := 4.0
var _spray_ready_at := 0.0


## Places your custom spray on the surface you're looking at (5 s cooldown).
func _try_spray() -> void:
	if Game.world == null:
		return
	if not UserImages.exists(UserImages.SPRAY):
		Game.announce.emit("No spray yet - add one in Customize > Spray", UiKit.MUTED)
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


# Pings (Fortnite style): middle mouse marks where you aim for your team. Aiming
# at an enemy marks them, aiming near the Tag marks it, and a quick double tap
# turns your ping into a danger warning.
const PING_RANGE := 300.0
const PING_DOUBLE_TAP := 0.3
var _last_ping_at := -10.0


func _try_ping() -> void:
	if Game.world == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var from := cam.global_position
	var dir := aim_dir()
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * PING_RANGE, MASK_AIM | MapBuilder.L_PLAYER, [get_rid()])
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	var pos: Vector3 = r.position if not r.is_empty() else from + dir * PING_RANGE * 0.5
	var kind := "spot"
	if not r.is_empty() and r.collider is Player and (r.collider as Player).team != team:
		kind = "enemy"
		pos = (r.collider as Player).global_position + Vector3(0, 1.0, 0)
	elif Game.holder == 0 and Game.objective >= 0:
		# Close to the line of sight to the Tag (within ~2 m of it)?
		var to_tag := Game.tag_pos + Vector3(0, 1.0, 0) - from
		if to_tag.length() < PING_RANGE and to_tag.normalized().dot(dir) > cos(atan2(2.0, to_tag.length())):
			kind = "tag"
			pos = Game.tag_pos + Vector3(0, 1.0, 0)
	if now - _last_ping_at < PING_DOUBLE_TAP:
		kind = "danger"
	_last_ping_at = now
	Game.world.request_ping.rpc_id(1, pos, kind)


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
		Game.world.door_rpc.rpc(door.idx, t, false)
