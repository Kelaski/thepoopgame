class_name UavAddon
extends Addon

@export var pulses := 5
## How fast each pulse's ring grows.
@export var pulse_speed := 9.0
## Time between pulses.
@export var pulse_interval := 1.5
## Fallback reach when the map has no bounds; pulses normally grow to the far edge of the map.
@export var max_radius := 60.0
## How long the last pulse's outlines stay.
@export var last_linger := 1.5
## Starts after the last pulse.
@export var cd := 25.0


func describe() -> String:
	return "%d pulses reveal enemies to your team. %.0fs cooldown." % [pulses, cd]


func use(p) -> void:
	if p._uav_left <= 0:
		p._uav_left = pulses
		p._uav_next = 0.0
		Sfx.play("addon", -4.0, 0.85)


## Sends a pulse to your team every pulse_interval, then the cooldown starts.
func tick(p, slot: int, delta: float) -> void:
	if p._uav_left <= 0:
		p.addon_cd[slot] = maxf(0.0, p.addon_cd[slot] - delta)
		return
	p._uav_next -= delta
	if p._uav_next > 0.0:
		return
	p._uav_left -= 1
	p._uav_next = pulse_interval
	if p._uav_left == 0:
		p.addon_cd[slot] = cd
	if Game.world:
		Net.to_all(Game.world, "uav_pulse", [p.global_position, p._uav_left == 0], true, true)


func status(p, _slot: int) -> Array:
	return ["PULSES LEFT %d" % p._uav_left, float(p._uav_left) / pulses, "active"] if p._uav_left > 0 else []
