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
const AIR_ACCEL := 16.0
const GRAVITY := 16.0
const JUMP_V := 6.4
const DJUMP_V := 7.0
const WALLJUMP_BOOST := 2.5
const SLOPE_ACCEL_RAMP := 0.6  # extra downhill acceleration per second spent on the slope
const MAX_SLIDE_SPEED := 22.0
const SPAWN_PROTECTION := 3.0
const WALLRUN_MIN_SPEED := 4.5
const WALLRUN_TIME := 1.6
const WALLRUN_GRAVITY := 3.0
const WALLJUMP_OUT := 6.0
const WALLJUMP_UP := 6.2
const LEAN_DIST := 0.45
const LEAN_ROLL := 12.0
const SLIDE_START_MIN := 5.5
const SLIDE_FRICTION := 4.6
const SLIDE_END := 3.6
const SLIDE_CD := 0.6
const MAX_GROUND_SPEED := 14.0
const NET_INTERVAL := 1.0 / 30.0
const DOOR_SLAM_SPEED := 5.5

const MASK_FULL := 1 | 2 | 8 | 16
const MASK_PHASE := 1 | 16
const MASK_PHASE_DOWN := 16
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

const VM_HIP := Vector3(0.24, -0.24, -0.5)
const VM_ADS := Vector3(0.0, -0.135, -0.36)
const VM_ADS_HOLO := Vector3(0.0, -0.118, -0.3)
const VM_ADS_IRONS := Vector3(0.0, -0.08, -0.3)

static var _mesh_cache := {}

var peer_id := 0
var is_local := false
var team := 0
var weapon := "ar"
var addon := "trackstar"
var alive := false

# Nodes
var head: Node3D
var cam: Camera3D
var col_shape: CollisionShape3D
var capsule: CapsuleShape3D
var probe_shape: CapsuleShape3D
var body_root: Node3D
var tag_mesh: MeshInstance3D
var tp_gun: MeshInstance3D
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

# Wall running & leaning
var wallrunning := false
var wall_normal := Vector3.ZERO
var wallrun_t := 0.0
var wallrun_cd := 0.0
var _last_wall_normal := Vector3.ZERO
var _wall_touch_t := 0.0          # coyote: recently touched a wall in the air
var _wall_touch_n := Vector3.ZERO
var _wall_jump_t := 0.0           # coyote: recently left a wall run
var _wall_jump_n := Vector3.ZERO
var lean := 0.0          # -1 (left) .. 1 (right), smoothed
var lean_offset := 0.0   # metres, clamped against walls
var _step_t := 0.0

# Addon state
var addon_active := 0.0
var addon_cd := 0.0
var invisible := false
var phasing := 0.0
var floor_phase := 0.0
var _last_crouch_tap := -10.0

# Spawn protection
var prot_pending := false  # kept for compatibility; protection is now a plain timer
var _vm_ads := VM_ADS
var _slope_t := 0.0
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
var net_lean := 0.0
var _has_net := false


func setup(id: int, info: Dictionary) -> void:
	peer_id = id
	name = str(id)
	team = info.get("team", 0)
	weapon = info.get("weapon", "ar")
	addon = info.get("addon", "trackstar")


func _ready() -> void:
	set_multiplayer_authority(peer_id)
	is_local = peer_id == multiplayer.get_unique_id()
	add_to_group("players")
	collision_layer = MapBuilder.L_PLAYER
	collision_mask = MASK_FULL
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.45
	floor_constant_speed = true

	capsule = CapsuleShape3D.new()
	capsule.radius = RADIUS
	capsule.height = STAND_H
	col_shape = CollisionShape3D.new()
	col_shape.shape = capsule
	col_shape.position.y = STAND_H * 0.5
	add_child(col_shape)
	probe_shape = CapsuleShape3D.new()
	probe_shape.radius = RADIUS - 0.06
	probe_shape.height = STAND_H - 0.25
	# Separate head hitbox so leaning out actually exposes your head.
	head_col = CollisionShape3D.new()
	var hs := SphereShape3D.new()
	hs.radius = 0.24
	head_col.shape = hs
	head_col.position.y = EYE_STAND - 0.05
	add_child(head_col)

	head = Node3D.new()
	head.position.y = EYE_STAND
	add_child(head)

	_build_body()
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

static func _box(s: Vector3) -> Mesh:
	var key := "box_%s" % s
	if not _mesh_cache.has(key):
		var m := BoxMesh.new()
		m.size = s
		_mesh_cache[key] = m
	return _mesh_cache[key]


static func _capsule_mesh() -> Mesh:
	if not _mesh_cache.has("capsule"):
		var m := CapsuleMesh.new()
		m.radius = 0.36
		m.height = 1.5
		m.radial_segments = 10
		m.rings = 3
		_mesh_cache["capsule"] = m
	return _mesh_cache["capsule"]


static func _sphere_mesh(key: String, r: float, segs: int, rings: int) -> Mesh:
	if not _mesh_cache.has(key):
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * 2.0
		m.radial_segments = segs
		m.rings = rings
		_mesh_cache[key] = m
	return _mesh_cache[key]


func _add_part(parent: Node3D, mesh: Mesh, pos: Vector3, col: Color, shadows := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = Mats.toon(col)
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _build_body() -> void:
	body_root = Node3D.new()
	add_child(body_root)
	var tc := Mats.team_color(team)
	_add_part(body_root, _capsule_mesh(), Vector3(0, 0.78, 0), tc)
	_add_part(body_root, _sphere_mesh("head", 0.24, 10, 5), Vector3(0, 1.62, 0), Color("e8b48a"))
	_add_part(body_root, _box(Vector3(0.5, 0.12, 0.5)), Vector3(0, 1.84, 0), tc.darkened(0.3))
	_add_part(body_root, _box(Vector3(0.32, 0.08, 0.06)), Vector3(0, 1.66, -0.22), Color("2a2a2e"))
	_add_part(body_root, _box(Vector3(0.22, 0.2, 0.3)), Vector3(-0.15, 0.1, -0.03), Color("3a3030"))
	_add_part(body_root, _box(Vector3(0.22, 0.2, 0.3)), Vector3(0.15, 0.1, -0.03), Color("3a3030"))
	tp_gun = _add_part(body_root, _box(Vector3(0.09, 0.12, 0.65)), Vector3(0.24, 1.22, -0.42), Color("2f3236"))
	tag_mesh = MeshInstance3D.new()
	tag_mesh.mesh = _sphere_mesh("tag", 0.28, 4, 2)
	tag_mesh.material_override = Mats.glow(Mats.TAG_COLOR)
	tag_mesh.position = Vector3(0, 2.45, 0)
	tag_mesh.visible = false
	body_root.add_child(tag_mesh)
	nameplate = Label3D.new()
	nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nameplate.fixed_size = true
	nameplate.no_depth_test = true
	nameplate.render_priority = 10
	nameplate.outline_render_priority = 9
	nameplate.font_size = 30
	nameplate.outline_size = 10
	nameplate.pixel_size = 0.0015
	nameplate.modulate = Mats.team_color(team).lightened(0.55)
	nameplate.outline_modulate = Color(0, 0, 0, 0.9)
	nameplate.position = Vector3(0, 2.2, 0)
	nameplate.text = Net.name_of(peer_id)
	nameplate.visible = false
	add_child(nameplate)


func _build_viewmodel() -> void:
	viewmodel = Node3D.new()
	viewmodel.position = VM_HIP
	cam.add_child(viewmodel)
	_rebuild_viewmodel()


func _rebuild_viewmodel() -> void:
	if viewmodel == null:
		return
	for c in viewmodel.get_children():
		c.queue_free()
	vm_gun = Node3D.new()
	viewmodel.add_child(vm_gun)
	vm_muzzle = Node3D.new()
	vm_gun.add_child(vm_muzzle)
	var dark := Color("2f3236")
	match weapon:
		"ar":
			_add_part(vm_gun, _box(Vector3(0.09, 0.13, 0.62)), Vector3(0, 0, -0.1), Color("4b5320"), false)
			_add_part(vm_gun, _box(Vector3(0.07, 0.12, 0.22)), Vector3(0, -0.02, 0.28), dark, false)
			_add_part(vm_gun, _box(Vector3(0.06, 0.2, 0.09)), Vector3(0, -0.15, -0.1), dark, false)
			_add_part(vm_gun, _box(Vector3(0.035, 0.035, 0.3)), Vector3(0, 0.02, -0.55), dark, false)
			_build_holo(0.07, 1.5)
			vm_muzzle.position = Vector3(0, 0.02, -0.72)
		"smg":
			_add_part(vm_gun, _box(Vector3(0.08, 0.12, 0.42)), Vector3(0, 0, -0.05), Color("3a3a40"), false)
			_add_part(vm_gun, _box(Vector3(0.05, 0.26, 0.07)), Vector3(0, -0.18, -0.08), dark, false)
			_add_part(vm_gun, _box(Vector3(0.03, 0.03, 0.14)), Vector3(0, 0.02, -0.33), dark, false)
			_build_holo(0.06, 1.2)
			vm_muzzle.position = Vector3(0, 0.02, -0.42)
		"shotgun":
			_add_part(vm_gun, _box(Vector3(0.07, 0.07, 0.78)), Vector3(0, 0.03, -0.25), dark, false)
			_add_part(vm_gun, _box(Vector3(0.09, 0.08, 0.24)), Vector3(0, -0.04, -0.3), Color("8a5a3c"), false)
			_add_part(vm_gun, _box(Vector3(0.08, 0.12, 0.3)), Vector3(0, -0.02, 0.2), Color("8a5a3c"), false)
			_add_part(vm_gun, _box(Vector3(0.02, 0.03, 0.02)), Vector3(0, 0.08, -0.6), Color("d6a83a"), false)
			vm_muzzle.position = Vector3(0, 0.03, -0.66)
		"sniper":
			_add_part(vm_gun, _box(Vector3(0.07, 0.1, 0.95)), Vector3(0, 0, -0.2), Color("2f4f3a"), false)
			_add_part(vm_gun, _box(Vector3(0.07, 0.07, 0.34)), Vector3(0, 0.1, -0.08), Color("1a1a1e"), false)
			_add_part(vm_gun, _box(Vector3(0.07, 0.13, 0.26)), Vector3(0, -0.03, 0.35), Color("5b3a29"), false)
			_add_part(vm_gun, _box(Vector3(0.03, 0.03, 0.3)), Vector3(0, 0.0, -0.8), dark, false)
			vm_muzzle.position = Vector3(0, 0.0, -0.95)
		"bat":
			vm_gun.rotation_degrees = Vector3(-25, 0, -18)
			_add_part(vm_gun, _box(Vector3(0.05, 0.05, 0.4)), Vector3(0, 0, 0.05), Color("3a2a20"), false)
			_add_part(vm_gun, _box(Vector3(0.1, 0.1, 0.55)), Vector3(0, 0, -0.4), Color("b48a5a"), false)
			for i in 6:
				var z := -0.25 - i * 0.07
				var side := 1.0 if i % 2 == 0 else -1.0
				_add_part(vm_gun, _box(Vector3(0.14, 0.02, 0.02)), Vector3(side * 0.02, 0.0, z), Color("c0c4c8"), false)
				_add_part(vm_gun, _box(Vector3(0.02, 0.14, 0.02)), Vector3(0.0, side * 0.02, z - 0.03), Color("c0c4c8"), false)
			vm_muzzle.position = Vector3(0, 0, -0.7)
	match weapon:
		"ar", "smg":
			_vm_ads = VM_ADS_HOLO
		"shotgun":
			_vm_ads = VM_ADS_IRONS
		_:
			_vm_ads = VM_ADS
	vm_flash = MeshInstance3D.new()
	vm_flash.mesh = _sphere_mesh("flash", 0.06, 6, 3)
	vm_flash.material_override = Mats.glow(Color("ffd27a"))
	vm_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vm_flash.visible = false
	vm_muzzle.add_child(vm_flash)


## Holographic sight on top of the gun. The window size and reticle reflect its
## magnification (AR 1.5x: larger window, ring + dot; SMG 1.2x: compact, dot only).
## Its centre sits at y = 0.118 so it lines up with the camera when aiming.
func _build_holo(window: float, zoom: float) -> void:
	var cy := 0.118
	var z := -0.06
	var frame := Color("1a1a1e")
	var h := window * 0.8
	_add_part(vm_gun, _box(Vector3(0.05, 0.03, 0.11)), Vector3(0, 0.075, z), frame, false)
	for sx: float in [-1.0, 1.0]:
		_add_part(vm_gun, _box(Vector3(0.008, h + 0.012, 0.012)), Vector3(sx * window * 0.5, cy, z), frame, false)
	_add_part(vm_gun, _box(Vector3(window + 0.008, 0.008, 0.012)), Vector3(0, cy + h * 0.5 + 0.004, z), frame, false)
	var glass := MeshInstance3D.new()
	glass.mesh = _box(Vector3(window, h, 0.002))
	glass.material_override = Mats.glow(Color("9fe6ff"), 0.12)
	glass.position = Vector3(0, cy, z)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vm_gun.add_child(glass)
	var red := Mats.glow(Color("ff3b30"))
	var dot := MeshInstance3D.new()
	dot.mesh = _sphere_mesh("holo_dot", 0.0016, 6, 3)
	dot.material_override = red
	dot.position = Vector3(0, cy, z - 0.002)
	vm_gun.add_child(dot)
	if zoom >= 1.4:
		# Ring reticle made of small segments.
		var r := 0.011
		for i in 12:
			var a := TAU * i / 12.0
			var seg := MeshInstance3D.new()
			seg.mesh = _box(Vector3(0.0035, 0.0012, 0.001))
			seg.material_override = red
			seg.position = Vector3(cos(a) * r, cy + sin(a) * r, z - 0.002)
			seg.rotation.z = a + PI * 0.5
			vm_gun.add_child(seg)


func _set_body_alpha(alpha_transparency: float, vis: bool) -> void:
	body_root.visible = vis
	for c in body_root.get_children():
		if c is GeometryInstance3D and c != tag_mesh:
			c.transparency = alpha_transparency


# ================================================================ state changes

func refresh_loadout() -> void:
	if Net.players.has(peer_id):
		var info: Dictionary = Net.players[peer_id]
		team = info.team
		weapon = info.weapon
		addon = info.addon
	if nameplate:
		nameplate.text = Net.name_of(peer_id)
	if is_local:
		_rebuild_viewmodel()


func set_alive(a: bool) -> void:
	alive = a
	collision_layer = MapBuilder.L_PLAYER if a else 0
	if not a:
		sliding = false
		wallrunning = false
		lean = 0.0
		lean_offset = 0.0
		if invisible:
			invisible = false
		phasing = 0.0
		floor_phase = 0.0
		velocity = Vector3.ZERO
	if body_root:
		body_root.visible = a and not is_local
	if viewmodel:
		viewmodel.visible = a


func respawn(pos: Vector3, protect: bool) -> void:
	refresh_loadout()
	global_position = pos
	net_pos = pos
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
	addon_active = 0.0
	addon_cd = 0.0
	dj_ready = true
	wallrunning = false
	wallrun_cd = 0.0
	_last_wall_normal = Vector3.ZERO
	lean = 0.0
	lean_offset = 0.0
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
	if is_local:
		BirdEvent.roll()  # 1% chance on every spawn / respawn


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

	# --- Crouch input
	var crouch_tap := can_input and not frozen and Input.is_action_just_pressed("crouch")
	var want_crouch: bool
	if Settings.g("toggle_crouch"):
		if crouch_tap:
			_crouch_toggle = not _crouch_toggle
		want_crouch = _crouch_toggle
	else:
		want_crouch = can_input and Input.is_action_pressed("crouch")
	if crouch_tap:
		if phasing > 0.0 and _now - _last_crouch_tap < 0.35:
			floor_phase = 0.4  # Phantom: drop through the floor
		_last_crouch_tap = _now

	var on_floor := is_on_floor()
	if on_floor:
		coyote = 0.1
		_last_wall_normal = Vector3.ZERO
		if wallrunning:
			_end_wallrun()
		dj_ready = true  # Skywalker double jump resets on landing
	else:
		coyote -= delta

	var hvel := Vector3(velocity.x, 0.0, velocity.z)
	var speed_now := hvel.length()
	var forward_in := move_in.y < -0.3
	var sprint_in := can_input and (Input.is_action_pressed("sprint") or bool(Settings.g("auto_sprint")))
	if sprint_in and forward_in and crouching and not sliding and Settings.g("toggle_crouch"):
		want_crouch = false
		_crouch_toggle = false
	sprinting = sprint_in and forward_in and not aiming and not sliding and not want_crouch
	if aiming and _aim_toggle and sprint_in and forward_in:
		# Sprinting cancels toggled ADS.
		_aim_toggle = false
		aiming = false

	# --- Wall contact coyote time (0.1 s)
	_wall_touch_t -= delta
	_wall_jump_t -= delta
	if not on_floor and is_on_wall():
		_wall_touch_t = 0.1
		_wall_touch_n = get_wall_normal()

	# --- Wall run start: airborne, moving fast along a wall, holding forward.
	# No limit on how many walls you can chain before landing.
	if not on_floor and not wallrunning and phasing <= 0.0 and wallrun_cd <= 0.0 and forward_in and _wall_touch_t > 0.0:
		var n := _wall_touch_n
		var along := hvel.normalized().dot(n)
		if absf(n.y) < 0.3 and speed_now > WALLRUN_MIN_SPEED and velocity.y > -8.0 and absf(along) < 0.85:
			wallrunning = true
			wall_normal = Vector3(n.x, 0.0, n.z).normalized()
			wallrun_t = WALLRUN_TIME
			velocity.y = maxf(velocity.y, 2.0)
			sliding = false
			_on_moved()

	# --- Slide start
	if crouch_tap and not sliding and not wallrunning and slide_cd <= 0.0 and speed_now > SLIDE_START_MIN and (sprint_in or speed_now > SPRINT or not on_floor):
		sliding = true
		_slope_t = 0.0
		slide_dir = hvel.normalized()
		if on_floor:
			var boosted := maxf(speed_now + 2.2, SPRINT * 1.35 * _speed_mult())
			hvel = slide_dir * minf(boosted, MAX_GROUND_SPEED)
		_on_moved()

	if wallrunning:
		wallrun_t -= delta
		var tangent := Vector3.UP.cross(wall_normal).normalized()
		if tangent.dot(hvel) < 0.0:
			tangent = -tangent
		hvel = tangent * maxf(hvel.length(), SPRINT * _speed_mult() * 0.95) - wall_normal * 1.0
		velocity.y = maxf(velocity.y - WALLRUN_GRAVITY * delta, -1.5)
		var still_on_wall := _ray_hits(global_position + Vector3(0, 1.0, 0), -wall_normal * (RADIUS + 0.4))
		if wallrun_t <= 0.0 or not still_on_wall or not forward_in or crouch_tap:
			_end_wallrun()
		crouching = false
	elif sliding:
		var spd := hvel.length()
		if on_floor:
			var n := get_floor_normal()
			var downhill := Vector3(n.x, 0.0, n.z).dot(slide_dir)
			if downhill > 0.05:
				# Sliding downhill: accelerate, and keep accelerating the longer you stay on the slope.
				_slope_t += delta
				spd += GRAVITY * downhill * (1.0 + _slope_t * SLOPE_ACCEL_RAMP) * delta
			else:
				_slope_t = 0.0
				spd += GRAVITY * downhill * delta
				spd -= SLIDE_FRICTION * delta
		if wish != Vector3.ZERO:
			slide_dir = (slide_dir + wish * delta * 1.2).normalized()
		hvel = slide_dir * clampf(spd, 0.0, MAX_SLIDE_SPEED)
		# Midair slides carry on until you land; on the ground they run until momentum is gone.
		var end_slide: bool = (on_floor and spd < SLIDE_END) or (not bool(Settings.g("toggle_crouch")) and not want_crouch)
		if end_slide:
			sliding = false
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
			if wish != Vector3.ZERO and speed_now > base + 0.2 and hvel.normalized().dot(wish) > 0.5:
				# Keep some slide-jump momentum when landing.
				hvel = hvel.move_toward(target, 14.0 * delta)
			else:
				hvel = hvel.move_toward(target, (ACCEL if wish != Vector3.ZERO else DECEL) * delta)
		else:
			var cap := maxf(speed_now, base)
			hvel += wish * AIR_ACCEL * delta
			if hvel.length() > cap:
				hvel = hvel.normalized() * cap
	_set_crouch_shape(crouching)

	# --- Gravity & jumping
	if not on_floor and not wallrunning:
		velocity.y -= GRAVITY * delta
	var jump_tap := can_input and not frozen and Input.is_action_just_pressed("jump")
	if jump_tap:
		if wallrunning or (_wall_jump_t > 0.0 and not on_floor):
			# Kick off the wall, keeping (and adding to) the speed along it so it chains
			# into the next wall run, a slide, or a slide-jump. Also works up to 0.1 s
			# after leaving the wall.
			var n := wall_normal if wallrunning else _wall_jump_n
			velocity.y = WALLJUMP_UP
			var along_wall := hvel - n * hvel.dot(n)
			if along_wall.length() > 0.5:
				along_wall += along_wall.normalized() * WALLJUMP_BOOST
			hvel = along_wall + n * WALLJUMP_OUT
			_end_wallrun()
			_wall_jump_t = 0.0
			_wall_touch_t = 0.0
			_on_moved()
		elif coyote > 0.0:
			if crouching and not sliding and _can_stand():
				crouching = false
				_crouch_toggle = false
				_set_crouch_shape(false)
			velocity.y = JUMP_V
			coyote = 0.0
			if sliding:
				sliding = false
				slide_cd = SLIDE_CD
				crouching = false
				_crouch_toggle = false
				_set_crouch_shape(false)
			_on_moved()
		elif addon == "skywalker" and dj_ready:
			# Extra height, current momentum kept as-is (no added speed).
			dj_ready = false
			velocity.y = DJUMP_V
			if sliding:
				sliding = false
				slide_cd = SLIDE_CD
			Sfx.play("jump", -4.0, 1.4)
			_on_moved()
	velocity.x = hvel.x
	velocity.z = hvel.z
	if move_in != Vector2.ZERO:
		_on_moved()

	# --- Doors fly open when sprinting / sliding into them
	if hvel.length() > DOOR_SLAM_SPEED:
		_check_door_slam(hvel.normalized())

	# --- Leaning (not while sprinting, sliding or wall running)
	var lean_in := 0.0
	if can_input and not frozen and not sprinting and not sliding and not wallrunning:
		if Input.is_action_pressed("lean_left"):
			lean_in -= 1.0
		if Input.is_action_pressed("lean_right"):
			lean_in += 1.0
	lean = move_toward(lean, lean_in, delta * 6.0)
	var want_off := lean * LEAN_DIST
	if absf(want_off) > 0.01:
		var right := Basis(Vector3.UP, yaw).x
		var eye := global_position + Vector3(0, head.position.y, 0)
		var space := get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(eye, eye + right * signf(want_off) * (absf(want_off) + 0.3), MASK_FULL, [get_rid()])
		var r := space.intersect_ray(q)
		if not r.is_empty():
			var hit: Vector3 = r.position
			want_off = signf(want_off) * maxf(0.0, eye.distance_to(hit) - 0.3)
	lean_offset = want_off
	head_col.position.x = lean_offset

	# --- Phantom collision masks
	if floor_phase > 0.0:
		collision_mask = MASK_PHASE_DOWN
	elif phasing > 0.0:
		collision_mask = MASK_PHASE
	else:
		collision_mask = MASK_FULL

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
			_use_addon()
		if Input.is_action_just_pressed("interact"):
			_interact()
		if Input.is_action_just_pressed("spray"):
			_try_spray()

	_net_acc += delta
	if _net_acc >= NET_INTERVAL:
		_net_acc = 0.0
		_net_state.rpc(global_position, yaw, pitch, velocity, _flags(), lean_offset)


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
	if addon == "trackstar":
		m *= Addons.TRACK_ACTIVE if addon_active > 0.0 else Addons.TRACK_PASSIVE
	return m


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
	if is_on_floor():
		f |= F_GROUND
	return f


@rpc("authority", "call_remote", "unreliable_ordered")
func _net_state(pos: Vector3, y: float, p: float, vel: Vector3, f: int, ln: float) -> void:
	net_lean = ln
	net_pos = pos
	net_yaw = y
	net_pitch = p
	net_vel = vel
	net_flags = f
	if not _has_net:
		_has_net = true
		global_position = pos


# ================================================================ per-frame visuals

func _process(delta: float) -> void:
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
	head_col.position.x = net_lean
	body_root.rotation.z = -net_lean / LEAN_DIST * deg_to_rad(15.0)
	var me := multiplayer.get_unique_id()
	nameplate.visible = alive and Game.in_match and Net.team_of(me) == team
	if nameplate.visible:
		nameplate.text = ("[TAG] " if Game.holder == peer_id else "") + Net.name_of(peer_id)
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
	tp_gun.visible = true


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
	roll_target += -lean * deg_to_rad(LEAN_ROLL)
	cam_roll = lerpf(cam_roll, roll_target, clampf(delta * 10.0, 0.0, 1.0))
	recoil = maxf(0.0, recoil - delta * 10.0)
	rotation.y = yaw
	head.rotation.x = pitch
	var f := Engine.get_physics_interpolation_fraction()
	var p := _prev_pos.lerp(_cur_pos, f) if alive else global_position
	var lean_v := Basis(Vector3.UP, yaw).x * lean_offset
	cam.global_transform = Transform3D(Basis.from_euler(Vector3(pitch + deg_to_rad(recoil * 1.2), yaw, cam_roll)), p + Vector3(0, head.position.y, 0) + lean_v)
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
	reloading = float(Weapons.DATA[weapon].reload)
	Sfx.play("reload", -6.0)


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
	fire_cd = 1.0 / float(w.rps)
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
			for off: Vector2 in [Vector2.ZERO, Vector2(0.06, 0.0), Vector2(-0.06, 0.0), Vector2(0.0, -0.08)]:
				var dir := (-b.z + b.x * off.x + b.y * off.y).normalized()
				var res := _hitscan(origin, dir, w.reach, 0, false)
				if not res.hits.is_empty():
					var h: Dictionary = res.hits[0]
					_acc(hits, h.id, w.dmg, h.head)
					Sfx.play("bat_hit", -2.0)
					break
	for id in hits:
		Game.report_hit.rpc_id(1, id, hits[id][0], hits[id][1], weapon)
	if weapon != "bat":
		ammo -= 1
		flash_t = 0.05
		recoil = float(w.kick)
		pitch = clampf(pitch + deg_to_rad(float(w.kick) * 0.35), deg_to_rad(-89.0), deg_to_rad(89.0))
		if ammo <= 0:
			_start_reload()
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
			var q2 := PhysicsRayQueryParameters3D.create(probe, hit_pos, MASK_FULL)
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

func _use_addon() -> void:
	match addon:
		"hider":
			if addon_cd <= 0.0 and not invisible:
				invisible = true
				addon_active = Addons.HIDER_TIME
				Sfx.play("addon", -4.0)
		"trackstar":
			if addon_cd <= 0.0:
				addon_active = Addons.TRACK_TIME
				addon_cd = Addons.TRACK_CD
				Sfx.play("addon", -4.0, 1.3)
		"phantom":
			if addon_cd <= 0.0 and phasing <= 0.0:
				phasing = Addons.PHANTOM_TIME
				Sfx.play("addon", -4.0, 0.7)


func _tick_addon(delta: float) -> void:
	match addon:
		"hider":
			if invisible:
				addon_active -= delta
				if addon_active <= 0.0:
					_end_invis()
			else:
				addon_cd = maxf(0.0, addon_cd - delta)
		"trackstar":
			addon_active = maxf(0.0, addon_active - delta)
			addon_cd = maxf(0.0, addon_cd - delta)
		"phantom":
			if phasing > 0.0:
				phasing -= delta
				if phasing <= 0.0:
					if alive and _overlaps(MapBuilder.L_WALL | MapBuilder.L_DOOR, probe_shape, STAND_H * 0.5 + 0.1):
						phasing = 0.05  # Still inside a wall: stay phased until clear.
					else:
						phasing = 0.0
						addon_cd = Addons.PHANTOM_CD
						Sfx.play("addon_end", -4.0)
			else:
				addon_cd = maxf(0.0, addon_cd - delta)
		_:
			addon_cd = maxf(0.0, addon_cd - delta)
	if floor_phase > 0.0:
		floor_phase -= delta
		if floor_phase <= 0.0 and alive and _overlaps(MapBuilder.L_FLOOR, probe_shape, STAND_H * 0.5 + 0.1):
			floor_phase = 0.05


func _end_invis() -> void:
	if not invisible:
		return
	invisible = false
	addon_active = 0.0
	addon_cd = Addons.HIDER_CD
	Sfx.play("addon_end", -4.0)


## [label, fraction (0..1), state] for the HUD.
func addon_status() -> Array:
	match addon:
		"hider":
			if invisible:
				return ["INVISIBLE %.0fs" % addon_active, addon_active / Addons.HIDER_TIME, "active"]
			if addon_cd > 0.0:
				return ["%.1fs" % addon_cd, 1.0 - addon_cd / Addons.HIDER_CD, "cooldown"]
		"trackstar":
			if addon_active > 0.0:
				return ["SPRINTING %.0fs" % addon_active, addon_active / Addons.TRACK_TIME, "active"]
			if addon_cd > 0.0:
				return ["%.1fs" % addon_cd, 1.0 - addon_cd / Addons.TRACK_CD, "cooldown"]
		"phantom":
			if phasing > 0.0:
				return ["PHASING", phasing / Addons.PHANTOM_TIME, "active"]
			if addon_cd > 0.0:
				return ["%.1fs" % addon_cd, 1.0 - addon_cd / Addons.PHANTOM_CD, "cooldown"]
		"skywalker":
			return ["DOUBLE JUMP READY" if dj_ready else "LAND TO RECHARGE", 1.0 if dj_ready else 0.0, "passive"]
		"stalker":
			return ["TRACKING", 1.0, "passive"]
	return ["READY [%s]" % Settings.bind_text("addon"), 1.0, "ready"]


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
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * SPRAY_REACH, MASK_FULL, [get_rid()])
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
