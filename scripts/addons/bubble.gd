class_name BubbleAddon
extends Addon

@export var time := 4.0
@export var health := 75.0
## Starts when the bubble ends or breaks.
@export var cd := 10.0


func describe() -> String:
	return "%.0fs, %.0f HP shield that stops pushes. %.0fs cooldown." % [time, health, cd]


func use(p) -> void:
	if p.addon_active[p.ACTIVE_SLOT] <= 0.0:
		p.addon_active[p.ACTIVE_SLOT] = time
		p.show_bubble()
		Sfx.play("parry", -3.0)
		Game.request_bubble.rpc_id(1)


func tick(p, slot: int, delta: float) -> void:
	if p.addon_active[slot] > 0.0:
		p.addon_active[slot] -= delta
		if p.addon_active[slot] <= 0.0:
			p.addon_active[slot] = 0.0
			p.addon_cd[slot] = cd
	else:
		p.addon_cd[slot] = maxf(0.0, p.addon_cd[slot] - delta)


func status(p, slot: int) -> Array:
	return ["BUBBLE %.0fs" % p.addon_active[slot], p.addon_active[slot] / time, "active"] if p.addon_active[slot] > 0.0 else []
