class_name PlayerMovement
extends PlayerState
## How the local player moves: running, sliding, wall runs, mantling and jumping.
## Player._physics_process calls these steps in order.

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
const MANTLE_KEEP := 0.92       # share of your speed you carry over the ledge
const MANTLE_RISE_MAX := 14.0   # fastest climb up the face (m/s): reaching the top takes about MANTLE_RISE_TIME
const MANTLE_RISE_TIME := 0.12
const MANTLE_SLIDE_BOOST := 4.0  # extra speed for a slide started just after a mantle...
const MANTLE_SLIDE_WINDOW := 0.6 # ...within this long
const SLIDE_STEP_MAX := 0.65    # a slide rides up over anything this low (a tree's planter box)
const MANTLE_REACH := [0.15, 0.45]  # m past the wall's face to look for the top: inside a 0.3 m wall, and just past it
const GRAVITY := 16.0
const JUMP_V := 6.4
const BOUNCE_V := JUMP_V * 1.4142  # bounce pads: sqrt(2) x jump speed = 2x the jump height
const WALLJUMP_BOOST := 2.5
const SLOPE_ACCEL_RAMP := 0.6  # extra downhill acceleration per second spent on the slope
const MAX_SLIDE_SPEED := 20.0
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
const DOOR_SLAM_SPEED := 5.5

# Bounce pads (32) aren't in your movement masks: they're one-way, handled by
# _check_bounce_pad, so you pass up through them and bounce off the top.
const LAND_ARC_TIME := 0.5      # after landing, a new direction (A or D held, say) arcs round...
const LAND_TURN_RATE := 5.0     # ...at up to this many radians a second, instead of snapping sideways
const ROCKET_FLAME_TIME := 0.6
var slide_dir := Vector3.ZERO
var slide_cd := 0.0
var coyote := 0.0
var _bounce_cd := 0.0  # stops a bounce pad firing again while you leave it
var dj_ready := true
var wall_normal := Vector3.ZERO
var wallrun_t := 0.0
var wallrun_cd := 0.0
var _last_wall_normal := Vector3.ZERO
var _wall_touch_t := 0.0          # coyote: recently touched a wall in the air
var _wall_touch_n := Vector3.ZERO
var _wall_jump_t := 0.0           # coyote: recently left a wall run
var _wall_jump_n := Vector3.ZERO
var wall_jumps := 0               # wall jumps since you last touched the floor
var _land_arc := 0.0       # time left in which turning arcs (see LAND_ARC_TIME)
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
var _mantle_slide_t := 0.0  # a slide now gets MANTLE_SLIDE_BOOST
var _door_exceptions := {}

# Worked out at the start of each physics tick, and used by the steps below.
var _can_input := false
var _frozen := false
var _move_in := Vector2.ZERO
var _wish := Vector3.ZERO
var _crouch_tap := false
var _any_crouch_tap := false
var _want_crouch := false
var _jump_tap := false
var _on_floor := false
var _landed_fall := 0.0  # how hard you just landed (m/s), 0 if you didn't
var _hvel := Vector3.ZERO
var _speed_now := 0.0
var _forward_in := false
var _sprint_in := false
var _mantling := false


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


func _slide_step(hvel: Vector3, delta: float) -> void:
	if hvel.length() < 1.0:
		return
	var dir := hvel.normalized()
	if not test_move(global_transform, hvel * delta + dir * 0.15):
		return  # nothing in the way
	var h := _mantle_height(dir, SLIDE_STEP_MAX)
	if h > 0.05:
		global_position.y += h + 0.02


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
		hvel += wish * AIR_ACCEL * Addons.of(passive).air_accel_mult() * delta
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
	var out := hvel + wd * minf(AIR_STRAFE_ACCEL * Addons.of(passive).air_strafe_mult() * delta, add)
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
## It looks inside the wall's thickness and just past it, and takes the highest
## top with room: a window sill or a roof parapet is thin, and just past it is
## the floor behind, too low to climb over the sill.


func _mantle_height(dir: Vector3, max_h := MANTLE_MAX) -> float:
	var space := get_world_3d().direct_space_state
	var mask := MASK_FULL & ~MapBuilder.L_PLAYER & ~64
	var best := -1.0
	for reach: float in MANTLE_REACH:
		var from := global_position + Vector3(0, max_h + 0.3, 0) + dir * (RADIUS + reach)
		var q := PhysicsRayQueryParameters3D.create(from, from - Vector3(0, max_h + 0.3 - MANTLE_MIN, 0), mask, [get_rid()])
		var r := space.intersect_ray(q)
		if r.is_empty() or (r.normal as Vector3).y < 0.7:
			continue
		var top: Vector3 = r.position
		var h := top.y - global_position.y
		if h > max_h or h <= best:
			continue
		var room := PhysicsShapeQueryParameters3D.new()
		room.shape = probe_shape
		room.transform = Transform3D(Basis.IDENTITY, top + Vector3(0, STAND_H * 0.5 + 0.1, 0))
		room.collision_mask = mask
		room.exclude = [get_rid()]
		if space.intersect_shape(room, 1).is_empty():
			best = h
	return best


func _speed_mult() -> float:
	return Weapons.DATA[weapon].speed_mult * Addons.of(passive).speed_mult(self)


## The global top speed; Unstoppable raises it.


func _speed_cap() -> float:
	return SPEED_CAP + Addons.of(passive).speed_cap_bonus()


## Wall-jump fatigue, and Moonwalker on top.


func _gravity_mult() -> float:
	return _fatigue_gravity() * Addons.of(passive).gravity_mult()


## Double jump: all your horizontal speed turns the way the camera faces.


func _double_jump_redirect(hvel: Vector3) -> Vector3:
	return Basis(Vector3.UP, yaw) * Vector3.FORWARD * hvel.length()


## Upward speed for a jump: normally v, but an armed Rocket Jump launches you
## rocket_height up instead (and its cooldown starts).


func _jump_speed(v: float) -> float:
	if not rocket_armed:
		return v
	rocket_armed = false
	addon_cd[ACTIVE_SLOT] = Addons.ROCKETJUMP.cd
	_rocket_t = ROCKET_FLAME_TIME
	Sfx.play("rocket", -3.0)
	return maxf(v, sqrt(2.0 * GRAVITY * _gravity_mult() * Addons.ROCKETJUMP.height))


## Wall jumps before fatigue sets in; Wallhugger adds some.


func _free_wall_jumps() -> int:
	return WALLJUMP_FREE + Addons.of(passive).extra_wall_jumps()


## 1.0 for your free wall jumps, then 0.75, 0.56, 0.42... for each extra one until
## you touch the floor.


func _wall_fatigue() -> float:
	return pow(WALLJUMP_FATIGUE, maxi(0, wall_jumps - _free_wall_jumps()))


## Gravity multiplier from wall-jump fatigue: 1.0 for your free wall jumps, then +50% per extra one (1.5, 2.0, 2.5...) up to 6x, until you touch the floor.


func _fatigue_gravity() -> float:
	return minf(1.0 + FATIGUE_GRAVITY_STEP * maxi(0, wall_jumps - _free_wall_jumps()), FATIGUE_GRAVITY_MAX)


func _end_wallrun() -> void:
	if wallrunning:
		_last_wall_normal = wall_normal
		_wall_jump_t = 0.1
		_wall_jump_n = wall_normal
	wallrunning = false
	wallrun_cd = 0.3


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
				Net.to_all(Game.world, "door_rpc", [door.idx, door.away_from(global_position), true], true, true)
			return


## Reads the keys for this tick: movement, aim, crouch and jump.
func _read_input(delta: float) -> void:
	_can_input = _input_ok()
	var _frozen: bool = Game.phase == Game.Phase.PREROUND
	_move_in = Vector2.ZERO
	if _can_input and not _frozen:
		_move_in = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	rotation.y = yaw
	head.rotation.x = pitch
	_wish = Basis(Vector3.UP, yaw) * Vector3(_move_in.x, 0.0, _move_in.y)
	_air_side = Basis(Vector3.UP, yaw) * Vector3(_move_in.x, 0.0, 0.0)
	if _wish.length() > 1.0:
		_wish = _wish.normalized()

	# --- Aim
	if weapon == "bat":
		aiming = false
	elif Settings.g("toggle_aim"):
		if _can_input and Input.is_action_just_pressed("aim"):
			_aim_toggle = not _aim_toggle
		aiming = _aim_toggle
	else:
		aiming = _can_input and Input.is_action_pressed("aim")

	# --- Crouch input. Crouch / Slide (crouch_tap) also starts slides; Crouch
	# (crouch_only) only ever crouches.
	_crouch_tap = _can_input and not _frozen and Input.is_action_just_pressed("crouch")
	_any_crouch_tap = _crouch_tap or (_can_input and not _frozen and Input.is_action_just_pressed("crouch_only"))
	if Settings.g("toggle_crouch"):
		if _any_crouch_tap:
			_crouch_toggle = not _crouch_toggle
		_want_crouch = _crouch_toggle
	else:
		_want_crouch = _can_input and (Input.is_action_pressed("crouch") or Input.is_action_pressed("crouch_only"))
	if _any_crouch_tap:
		if phasing > 0.0 and _now - _last_crouch_tap < 0.35:
			floor_phase = 0.4  # Phantom: drop through the floor
		_last_crouch_tap = _now
	_jump_tap = _can_input and not _frozen and Input.is_action_just_pressed("jump")
	# A jump pressed just before you land happens the moment you touch down.
	_jump_buffer_t = JUMP_BUFFER if _jump_tap else _jump_buffer_t - delta


## Landing, leaving the ground, and the timers that depend on them.
func _update_ground(delta: float) -> void:
	_on_floor = is_on_floor()
	_landed_fall = 0.0  # how hard you just landed (m/s), 0 if you didn't
	_recent_fall_t -= delta
	if _on_floor:
		_landed_fall = _air_fall
		_air_fall = 0.0
		if _landed_fall > 0.0:
			_recent_fall = _landed_fall
			_recent_fall_t = 0.3
			_land_arc = LAND_ARC_TIME
			_land_grace = LAND_GRACE  # no ground friction for a moment: time a hop to keep your speed
	else:
		_air_fall = maxf(_air_fall, -velocity.y)
	_land_grace -= delta
	_land_arc -= delta
	if _on_floor:
		coyote = 0.12
		_last_wall_normal = Vector3.ZERO
		if wallrunning:
			_end_wallrun()
		dj_ready = true  # Double Jump resets on landing
		wall_jumps = 0   # ...and so does wall-jump fatigue
	else:
		coyote -= delta
	_slide_boost_cd -= delta
	_mantle_cd -= delta
	_mantle_slide_t -= delta

	_hvel = Vector3(velocity.x, 0.0, velocity.z)
	_speed_now = _hvel.length()
	_forward_in = _move_in.y < -0.3
	# Sprint is the default pace: moving forward is always a sprint, except while
	# aiming, crouching or sliding.
	_sprint_in = _can_input
	sprinting = _sprint_in and _forward_in and not aiming and not sliding and not _want_crouch


## Wall contact, remembered for 0.1 s.
func _update_wall_contact(delta: float) -> void:
	_wall_touch_t -= delta
	_wall_jump_t -= delta
	if not _on_floor and is_on_wall():
		_wall_touch_t = 0.1
		_wall_touch_n = get_wall_normal()
	elif not _on_floor and not wallrunning and _speed_now > WALLRUN_MIN_SPEED:
		# A wall just beside you counts too, so running alongside one (without
		# steering into it) still starts a wall run.
		var side_n := _side_wall(Basis(Vector3.UP, yaw).x)
		if side_n != Vector3.ZERO:
			_wall_touch_t = 0.1
			_wall_touch_n = side_n


## Hold Space while you jump at a ledge (or fall past one), pushing into it, and you climb
## straight up onto it, keeping some of your speed. Works on window sills and roof parapets too.
func _try_start_mantle() -> void:
	var facing := Basis(Vector3.UP, yaw) * Vector3.FORWARD
	var holding_jump := _can_input and not _frozen and Input.is_action_pressed("jump")
	if not _on_floor and not wallrunning and _forward_in and holding_jump and _mantle_cd <= 0.0 and _wall_touch_t > 0.0 and velocity.y < MANTLE_MAX_UP and facing.dot(-_wall_touch_n) > 0.5:
		var mh := _mantle_height(-Vector3(_wall_touch_n.x, 0.0, _wall_touch_n.z).normalized())
		if mh > -1.0:
			_mantle_t = MANTLE_TIME
			_mantle_dir = -Vector3(_wall_touch_n.x, 0.0, _wall_touch_n.z).normalized()
			_mantle_top = global_position.y + maxf(mh, 0.0)
			_mantle_speed = maxf(_speed_now * MANTLE_KEEP, MANTLE_PUSH)
			_mantle_cd = 0.5
			_wall_touch_t = 0.0
			Sfx.play("jump", -6.0, 0.8)
			_on_moved()


## Airborne, moving along a wall, and either holding forward, holding a movement key into the
## wall, or hugging it. A run starts at least at WALLRUN_START, lifts you a little, and can't go
## straight back onto the wall you just left (another wall, or the floor, resets that).
func _try_start_wallrun() -> void:
	if not _on_floor and not wallrunning and phasing <= 0.0 and wallrun_cd <= 0.0 and _wall_touch_t > 0.0:
		var n := _wall_touch_n
		var n_flat := Vector3(n.x, 0.0, n.z).normalized()
		var into_wall := _wish.length() > 0.3 and _wish.normalized().dot(-n_flat) > 0.25
		var hugging := is_on_wall() and get_wall_normal().dot(n_flat) > 0.9
		var along := _hvel.normalized().dot(n)
		var same_wall := _last_wall_normal != Vector3.ZERO and n_flat.dot(_last_wall_normal) > 0.9
		if (_forward_in or into_wall or hugging) and absf(n.y) < 0.3 and _speed_now > WALLRUN_MIN_SPEED and velocity.y > -9.0 and absf(along) < 0.9 and not same_wall:
			wallrunning = true
			wall_normal = Vector3(n.x, 0.0, n.z).normalized()
			wallrun_t = 0.0
			# Entering a run catches your fall and gives a small lift (Titanfall-style:
			# runs stay roughly level and sink slowly at the end).
			velocity.y = clampf(velocity.y, WALLRUN_LIFT, WALLRUN_LIFT * 1.6)
			sliding = false
			_on_moved()


## Crouch / Slide while sprinting (or fast, or in the air: then it starts when you land).
## Momentum carries straight in, and the boost only comes back after SLIDE_BOOST_CD, so
## slide-hopping keeps speed without stacking boosts.
func _try_start_slide() -> void:
	if _crouch_tap and not sliding and not wallrunning and slide_cd <= 0.0 and _speed_now > SLIDE_START_MIN and (_sprint_in or _speed_now > SPRINT or not _on_floor):
		sliding = true
		_slope_t = 0.0
		slide_dir = _hvel.normalized()
		_slide_pending_boost = _slide_boost_cd <= 0.0
		if _mantle_slide_t > 0.0:
			_hvel += slide_dir * MANTLE_SLIDE_BOOST  # sliding out of a mantle
			_mantle_slide_t = 0.0
		_on_moved()
	if sliding and _on_floor and _slide_pending_boost:
		_slide_pending_boost = false
		_slide_boost_cd = SLIDE_BOOST_CD
		var fall := _recent_fall if _recent_fall_t > 0.0 else 0.0
		# The boost tops out at MAX_SLIDE_SPEED, but never takes speed away from a faster entry.
		_hvel = slide_dir * maxf(_hvel.length(), minf(_hvel.length() + SLIDE_BOOST * _speed_mult() + _landing_bonus(fall), MAX_SLIDE_SPEED * _speed_mult()))
		_recent_fall_t = 0.0
		_landed_fall = 0.0  # already used


func _run_on_wall(delta: float) -> void:
	wallrun_t += delta
	var tangent := Vector3.UP.cross(wall_normal).normalized()
	if tangent.dot(_hvel) < 0.0:
		tangent = -tangent
	# Wall runs speed you up towards WALLRUN_SPEED (never slowing you if you came
	# in faster), but not once wall-jump fatigue sets in.
	var run_speed := maxf(_hvel.length(), WALLRUN_START * _speed_mult() * _wall_fatigue())
	var top := WALLRUN_SPEED * _speed_mult() * _wall_fatigue()
	if run_speed < top:
		run_speed = minf(top, run_speed + WALLRUN_ACCEL * delta)
	_hvel = tangent * run_speed - wall_normal * 1.0
	# Gravity on the wall starts light and builds, so a run slowly sinks.
	var fg := _fatigue_gravity()
	var g := lerpf(WALLRUN_GRAVITY, WALLRUN_GRAVITY_END, clampf(wallrun_t / WALLRUN_TIME, 0.0, 1.0))
	velocity.y = maxf(velocity.y - g * fg * delta, -3.0 * fg)
	# A little further than _side_wall looks, or a run started by that check ends at once.
	var still_on_wall := _ray_hits(global_position + Vector3(0, 1.0, 0), -wall_normal * (RADIUS + 0.5))
	# A run lasts while you hold any movement key (forward, or along / into the wall).
	if wallrun_t >= WALLRUN_TIME or not still_on_wall or _wish.length() < 0.3 or _any_crouch_tap:
		_end_wallrun()
	crouching = false


func _slide_along(delta: float) -> void:
	var spd := _hvel.length()
	if _on_floor:
		# Landing hard in a slide turns some of the fall into speed.
		spd += _landing_bonus(_landed_fall)
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
	if _wish != Vector3.ZERO:
		slide_dir = (slide_dir + _wish * delta * 1.0).normalized()
	# Slopes and landings can't take a slide past MAX_SLIDE_SPEED, but a faster
	# slide (from a fall, a grapple, a wall kick) isn't cut down to it either:
	# friction slows it just like a slower one.
	_hvel = slide_dir * clampf(spd, 0.0, maxf(MAX_SLIDE_SPEED * _speed_mult(), _speed_now))
	# Midair slides carry on until you land; on the ground they run until momentum is gone.
	var end_slide: bool = (_on_floor and spd < SLIDE_END) or (not bool(Settings.g("toggle_crouch")) and not _want_crouch)
	if end_slide:
		sliding = false
		_slide_pending_boost = false
		slide_cd = SLIDE_CD
	crouching = sliding or _want_crouch


## Normal movement: on the ground, and steering in the air.
func _walk_or_steer(delta: float) -> void:
	crouching = _want_crouch or (crouching and not _can_stand())
	var base := WALK
	if crouching:
		base = CROUCH_SPEED
	elif sprinting:
		base = SPRINT
	if aiming:
		base *= lerpf(1.0, ADS_MULT, ads_t)
	base *= _speed_mult()
	var target := _wish * base
	if _on_floor:
		if _land_grace > 0.0 and _speed_now > base and _wish != Vector3.ZERO:
			# Just landed faster than you run: no friction yet, so a hop now keeps it
			# all. Only while you hold a movement key: with none you stop (below).
			_hvel = _air_strafe(_hvel, _wish, base, delta)
		elif _land_arc > 0.0 and _wish != Vector3.ZERO and _speed_now > 0.5:
			# Just landed and steering somewhere new: swing round towards it at
			# LAND_TURN_RATE, easing to your run speed, rather than sliding on
			# and then lurching sideways. Normal control once you face it.
			var old := _hvel / _speed_now
			var ang := old.signed_angle_to(_wish.normalized(), Vector3.UP)
			var turn := LAND_TURN_RATE * delta
			if absf(ang) <= turn:
				_land_arc = 0.0
			var spd := move_toward(_speed_now, base * minf(_wish.length(), 1.0), (OVERSPEED_FRICTION if _speed_now > base else ACCEL) * delta)
			_hvel = old.rotated(Vector3.UP, clampf(ang, -turn, turn)) * spd
		elif _wish == Vector3.ZERO:
			# No movement keys: stop as quickly as from a walk, whatever your speed
			# (letting go of W used to glide you on while sprint speed bled off).
			_hvel = _hvel.move_toward(Vector3.ZERO, DECEL * delta)
		elif _speed_now > base + 0.2:
			# Faster than you run (after a slide or hops): bleed it off quickly,
			# while you can still steer.
			var spd := maxf(base, _speed_now - OVERSPEED_FRICTION * delta)
			var dir := (_hvel / _speed_now).lerp(_wish if _wish != Vector3.ZERO else _hvel / _speed_now, clampf(6.0 * delta, 0.0, 1.0)).normalized()
			_hvel = dir * spd
		else:
			_hvel = _hvel.move_toward(target, (ACCEL if _wish != Vector3.ZERO else DECEL) * delta)
	else:
		_hvel = _air_strafe(_hvel, _wish, base, delta)


## Rise up the face until your feet clear the ledge, then carry over the top
## (so it works even on narrow ledges like a car roof).
func _climb_mantle(delta: float) -> void:
	_mantling = _mantle_t > 0.0
	if _mantling:
		_mantle_t -= delta
		if is_on_ceiling() or (_mantle_t < MANTLE_TIME - 0.4 and global_position.y < _mantle_top + 0.08):
			# Blocked overhead, or not clearing it: give up and fall back.
			_mantle_t = 0.0
			_mantling = false
		elif global_position.y < _mantle_top + 0.08:
			# Up the face quickly; speed along the wall carries on, only the push into
			# it waits (pushing in would catch on the lip).
			velocity.y = clampf((_mantle_top + 0.12 - global_position.y) / MANTLE_RISE_TIME, MANTLE_RISE, MANTLE_RISE_MAX)
			_hvel -= _mantle_dir * _hvel.dot(_mantle_dir)
		else:
			velocity.y = minf(velocity.y, 1.0)
			_hvel = _mantle_dir * _mantle_speed + (_hvel - _mantle_dir * _hvel.dot(_mantle_dir))
			_mantle_t = minf(_mantle_t, 0.12)  # a moment over the top, then you're free
			_mantle_slide_t = MANTLE_SLIDE_WINDOW


## A wall kick, a jump, or a Double Jump, whichever applies.
func _try_jump() -> void:
	if _jump_buffer_t > 0.0:
		if wallrunning or (_wall_jump_t > 0.0 and not _on_floor):
			# Kick off the wall: out, up, and along it, keeping (and adding to) your
			# speed so it chains into the next wall run, a slide, or a slide-hop.
			# Also works up to 0.1 s after leaving the wall. Fatigue: from the 4th
			# wall jump without touching the floor, each kick loses speed instead.
			var n := wall_normal if wallrunning else _wall_jump_n
			wall_jumps += 1
			var fatigue := _wall_fatigue()
			velocity.y = _jump_speed(WALLJUMP_UP * lerpf(0.5, 1.0, fatigue))
			var along_wall := _hvel - n * _hvel.dot(n)
			if fatigue < 1.0:
				along_wall *= fatigue
			elif along_wall.length() > 0.5:
				along_wall += along_wall.normalized() * WALLJUMP_BOOST
			_hvel = along_wall + n * WALLJUMP_OUT * fatigue
			_end_wallrun()
			_last_wall_normal = Vector3.ZERO  # a kick can be followed by another off the same wall
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
		elif _jump_tap and passive == "doublejump" and dj_ready:
			# Extra height, and all your speed turns the way the camera faces.
			dj_ready = false
			_hvel = _double_jump_redirect(_hvel)
			velocity.y = _jump_speed(Addons.DOUBLEJUMP.speed)
			_jump_buffer_t = 0.0
			if sliding:
				sliding = false
				slide_cd = SLIDE_CD
			Sfx.play("jump", -4.0, 1.4)
			_on_moved()


## Applies the speed worked out above and moves the body.
func _move_body(delta: float) -> void:
	if _hvel.length() > _speed_cap():
		_hvel = _hvel.normalized() * _speed_cap()
	velocity.x = _hvel.x
	velocity.z = _hvel.z
	if _move_in != Vector2.ZERO:
		_on_moved()

	# --- Doors fly open when sprinting / sliding into them
	if _hvel.length() > DOOR_SLAM_SPEED:
		_check_door_slam(_hvel.normalized())

	# --- Phantom collision masks
	if floor_phase > 0.0:
		collision_mask = MASK_PHASE_DOWN
	elif phasing > 0.0:
		collision_mask = MASK_PHASE
	else:
		collision_mask = MASK_FULL

	_bounce_cd -= delta
	_check_bounce_pad(delta)
	if sliding and _on_floor:
		_slide_step(_hvel, delta)
	move_and_slide()
	if global_position.y < -25.0:
		global_position = Vector3(global_position.x, 2.0, global_position.z)
		velocity = Vector3.ZERO
		_cur_pos = global_position
	_prev_pos = _cur_pos
	_cur_pos = global_position
