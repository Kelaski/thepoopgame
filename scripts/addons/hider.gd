class_name HiderAddon
extends Addon

@export var time := 15.0
@export var cd := 12.0
## How visible you are while moving (0.1 = 10% opaque).
@export var moving_opacity := 0.1
## How visible you are standing still, crouching or sliding.
@export var still_opacity := 0.05


func describe() -> String:
	return "%.0fs nearly invisible. Firing ends it. %.0fs cooldown." % [time, cd]


func use(p) -> void:
	if not p.invisible:
		p.invisible = true
		p.addon_active[p.ACTIVE_SLOT] = time
		Sfx.play("addon", -4.0)


func tick(p, slot: int, delta: float) -> void:
	if p.invisible:
		p.addon_active[slot] -= delta
		if p.addon_active[slot] <= 0.0:
			p._end_invis()
	else:
		p.addon_cd[slot] = maxf(0.0, p.addon_cd[slot] - delta)


func status(p, slot: int) -> Array:
	return ["HIDDEN %.0fs" % p.addon_active[slot], p.addon_active[slot] / time, "active"] if p.invisible else []
