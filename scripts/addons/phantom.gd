class_name PhantomAddon
extends Addon

@export var time := 3.0
## Starts when the phase ends.
@export var cd := 10.0
## Damage per second if the phase ends inside something. Doubles every second until you're out.
@export var stuck_dps := 10.0


func describe() -> String:
	return "Phase through walls for %.0fs. Ending inside something hurts. %.0fs cooldown." % [time, cd]


func use(p) -> void:
	p.phasing = time
	Sfx.play("addon", -4.0, 0.7)
	Game.request_phantom.rpc_id(1)


func switch_off(p) -> bool:
	if p.phasing <= 0.0:
		return false
	p.phasing = minf(p.phasing, 0.001)
	Game.end_phantom.rpc_id(1)
	return true


func tick(p, slot: int, delta: float) -> void:
	if p.phasing <= 0.0:
		p.addon_cd[slot] = maxf(0.0, p.addon_cd[slot] - delta)
		return
	p.phasing -= delta
	if p.phasing > 0.0:
		return
	# Still inside something: stay phased until clear (the host hurts you for it).
	if p.alive and p._overlaps(MapBuilder.L_WALL | MapBuilder.L_DOOR, p.probe_shape, p.STAND_H * 0.5 + 0.1):
		p.phasing = 0.05
	else:
		p.phasing = 0.0
		p.addon_cd[slot] = cd
		Sfx.play("addon_end", -4.0)


func status(p, _slot: int) -> Array:
	return ["PHASING", p.phasing / time, "active"] if p.phasing > 0.0 else []
