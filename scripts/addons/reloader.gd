class_name ReloaderAddon
extends Addon

## After it refills, the next kill within this long doesn't.
@export var cd := 3.0


func describe() -> String:
	return "Kills reload your weapon instantly. %.0fs cooldown." % cd


## Refills the magazine and cancels any reload or re-chamber, so you can fire again straight
## away. Guns that fire one click at a time wait for a new click, so holding fire doesn't waste the shot.
func refill(p) -> void:
	if p.weapon == "bat" or not p.alive or p.addon_cd[p.PASSIVE_SLOT] > 0.0:
		return
	p.addon_cd[p.PASSIVE_SLOT] = cd
	p.ammo = int(Weapons.DATA[p.weapon].mag)
	p.reloading = 0.0
	p.fire_cd = 0.0
	p._fresh_click = p.weapon != "ar" and Input.is_action_pressed("fire")
	Sfx.play("reload", -4.0, 1.4)
