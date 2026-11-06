class_name PlayerState
extends CharacterBody3D
## What a player is: its nodes, shared numbers and simple questions about it. The player is
## built in layers, each adding one job: PlayerState, PlayerMovement, PlayerNet, PlayerAddons,
## PlayerWeapons, then Player. A layer can only use the ones before it.


const STAND_H := 1.8
const CROUCH_H := 1.15
const RADIUS := 0.38
const EYE_STAND := 1.62
const EYE_CROUCH := 1.02
const SPAWN_PROTECTION := 3.0
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
const ACTIVE_SLOT := 0  # addon slots: the active addon (Use Active Addon key)...
const PASSIVE_SLOT := 1  # ...and the passive one (no key)
const SHOT_POSE_TIME := 0.45  # s the gun is held up (the standing pose) after each shot
var peer_id := 0
var is_local := false
var team := 0
var weapon := "ar"
var active := Addons.DEFAULT_ACTIVE
var passive := Addons.DEFAULT_PASSIVE
var alive := false

# Nodes
var head: Node3D
var cam: Camera3D
var col_shape: CollisionShape3D
var capsule: CapsuleShape3D
var probe_shape: CapsuleShape3D
var body_root: Node3D
var tp_pivot: Node3D     # shoulder; pitched with where the player looks
var tp_gun: Node3D       # the weapon everyone else sees you holding
var _glint: Node3D       # sniper scope glint
var _body_alpha := -1.0
var nameplate: Label3D
var head_col: CollisionShape3D
var viewmodel: Node3D
var vm_gun: Node3D
var vm_muzzle: Node3D
var _tp_muzzle: Node3D   # muzzle of the gun everyone else sees (their tracers start here)
var _shot_pose := 0.0    # time left holding the gun up after a shot (no sprint pose, no bob)
var vm_flash: MeshInstance3D

# Local simulation state
var yaw := 0.0
var pitch := 0.0
var crouching := false
var sliding := false
var sprinting := false
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
var _step_t := 0.0

# Addon state
var addon_active: Array[float] = [0.0, 0.0]  # per slot: time left on the ability
var addon_cd: Array[float] = [0.0, 0.0]      # per slot: cooldown left
var _cd_full: Array[float] = [0.0, 0.0]      # per slot: what that cooldown started at (for the HUD bar)
var rocket_armed := false  # Moonwalker: the next jump is a rocket jump
var _rocket_t := 0.0       # flame showing (local: time left; sent as F_ROCKET)
var _support_cd := {}       # Support addon -> cooldown left when you swapped away from it
var _bubble_t := 0.0       # Bubble showing (everyone sees it)
var _bubble_node: Node3D
var _streak := 0           # Killstreak: kills since you last died
var _uav_left := 0         # UAV: pulses still to send
var _uav_next := 0.0       # ...and how long until the next one
var _magnet_t := 0.0       # Magnet: being pulled to a teammate for this much longer
var _magnet_from := Vector3.ZERO
var _magnet_to := Vector3.ZERO
var _fresh_click := false  # Reload on Kill re-chambered the gun: the next shot waits for a new click
var _predicted_kills := {}  # Reload on Kill: victim id -> when we refilled for their kill ahead of the host
var _rocket_flame: Node3D
var invisible := false
var phasing := 0.0
var floor_phase := 0.0
var _last_crouch_tap := -10.0
enum Hook { NONE, FLYING, ATTACHED }
var grapple_state: int = Hook.NONE
var grapple_point := Vector3.ZERO    # where the hook is attached
var grapple_t := 0.0                 # time left on the rope
var _grapple_target: PlayerState = null   # hooked player (the hook follows them)
var _grapple_offset := Vector3.ZERO
var _hook_pos := Vector3.ZERO        # flying hook
var _hook_dir := Vector3.ZERO
var _hook_dist := 0.0
var _rope_len := 0.0                 # only ever shortens, so you swing below the anchor
var _rope: MeshInstance3D
var _hook_mesh: MeshInstance3D

# Spawn protection
var prot_pending := false  # kept for compatibility; protection is now a plain timer
var prot_left := 0.0
var _now := 0.0
var _prev_pos := Vector3.ZERO
var _cur_pos := Vector3.ZERO

# Remote state
var net_flags := 0
var _last_yank := -100.0  # when an enemy grapple last yanked us


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


## The point of this player's body nearest p: what a blast or a grenade has to reach.


func body_point_near(p: Vector3) -> Vector3:
	var h := CROUCH_H if is_crouched() else STAND_H
	return global_position + Vector3.UP * clampf(p.y - global_position.y, RADIUS, h - RADIUS)


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


func _input_ok() -> bool:
	return is_local and not Game.ui_open and not Game.typing and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or DisplayServer.get_name() == "headless")  # no mouse to capture in headless tests


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


func addon_in(slot: int) -> String:
	return active if slot == ACTIVE_SLOT else passive
