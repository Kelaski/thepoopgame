class_name PlayerNet
extends PlayerMovement
## Sending our state to everyone, and checking the updates other players send.

const NET_INTERVAL := 1.0 / 30.0
const NET_INTERVAL_FULL := 1.0 / 15.0  # with more than NET_FULL_LOBBY players
const NET_FULL_LOBBY := 8
const NET_MAX_SPEED := 70.0        # m/s in total (falls are fast): faster movement updates are ignored
const NET_MAX_HSPEED := SPEED_CAP * 1.25  # m/s along the ground (speed hacks)
const NET_WINDOW := 1.0            # s: speeds are measured over this long, so per-update slack can't add up
const TELEPORT_GRACE := 0.6  # s after the host moves someone (Warp, Magnet) that their updates skip the movement check
var _net_acc := 0.0
var net_pos := Vector3.ZERO
var net_vel := Vector3.ZERO
var net_yaw := 0.0
var net_pitch := 0.0
var _has_net := false
var _anchor_pos := Vector3.ZERO  # accepted position the current speed window started at
var _anchor_t := -1.0            # ...and when (s); -1 = start a new window
var _jump_votes := 0     # updates in a row that put this player somewhere it couldn't have moved to
var _jump_pos := Vector3.ZERO    # where that run of updates started...
var _jump_t := 0.0               # ...and when
var _last_sent := -INF           # sender's clock time of the last update used
var _clock_off := INF            # quickest (arrival - sent) seen: maps their clock onto ours
var _net_free_until := -1.0      # the host moved this player: accept their updates until then
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


## From the player's owner, through the host (Net.to_all).


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


func _net_filter(pos: Vector3, sent: float, now: float) -> bool:
	if sent <= _last_sent:
		return false
	_last_sent = sent
	_clock_off = minf(_clock_off, now - sent)
	var t := sent + _clock_off
	if now < _net_free_until:
		_anchor_t = -1.0  # the host just moved them (Warp, Magnet): start again from here
	if _has_net and _anchor_t >= 0.0 and not _reachable(_anchor_pos, _anchor_t, pos, t, _net_hspeed()):
		# A second of updates moving on from one new spot at legal speed (the
		# out-of-bounds reset) is accepted, so a player can't get stuck unseen.
		if _jump_votes == 0 or not _reachable(_jump_pos, _jump_t, pos, t, _net_hspeed()):
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


static func _reachable(from: Vector3, t0: float, to: Vector3, now: float, hspeed := NET_MAX_HSPEED) -> bool:
	var dt := maxf(now - t0, NET_INTERVAL)
	var d := to - from
	return d.length() <= NET_MAX_SPEED * dt + 3.0 and Vector2(d.x, d.z).length() <= hspeed * dt + 3.0


## The most ground speed this player's updates may show (Unstoppable goes faster).


func _net_hspeed() -> float:
	return _speed_cap() * NET_MAX_HSPEED / SPEED_CAP


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


## Sends where we are to everyone.
func _send_state(delta: float) -> void:
	_net_acc += delta
	# The host passes every update on to everyone, so its upload grows with players squared.
	if _net_acc >= (NET_INTERVAL_FULL if Net.players.size() > NET_FULL_LOBBY else NET_INTERVAL):
		_net_acc = 0.0
		Net.to_all(self, "_net_state", [global_position, yaw, pitch, velocity, _flags(), Time.get_ticks_msec() / 1000.0], false)
