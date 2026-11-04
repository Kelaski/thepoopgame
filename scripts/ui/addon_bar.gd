class_name AddonBar
extends PanelContainer
## One addon's name, state and charge bar in the bottom-right HUD
## (assets/ui/addon_bar.tscn). The HUD has one for each addon slot.

const COLORS := {"active": Color("49d6e0"), "cooldown": Color("5a5f6a"), "ready": Color("e0b13c")}

@onready var _name: Label = %AddonName
@onready var _text: Label = %AddonText
@onready var _fill: ColorRect = %AddonFill
@onready var _track: ColorRect = %Track


## status: [label, fraction 0..1, state] from Player.addon_status().
func show_status(addon_name: String, status: Array) -> void:
	_name.text = addon_name.to_upper()
	_text.text = status[0]
	# The bar stretches with long names, so the fill is a share of its real width.
	_fill.size.x = maxf(0.0, _track.size.x - 2.0) * clampf(status[1], 0.0, 1.0)
	if status[2] == "passive":
		_fill.color = Color("6a8a5a") if status[1] > 0.5 else COLORS.cooldown
	else:
		_fill.color = COLORS.get(status[2], COLORS.ready)
