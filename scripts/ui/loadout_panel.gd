class_name LoadoutPanel
extends VBoxContainer
## Weapon + addon picker (assets/ui/loadout_panel.tscn). Used in the lobby and on
## the death screen. The buttons are listed from Weapons.ORDER / Addons.ORDER.

const SCENE := "res://assets/ui/loadout_panel.tscn"

var _weapon_btns := {}
var _addon_btns := {}
@onready var _wdesc: Label = %WeaponDesc
@onready var _adesc: Label = %AddonDesc


func _ready() -> void:
	var wrow: HBoxContainer = %WeaponRow
	var wg := ButtonGroup.new()
	for id in Weapons.ORDER:
		var b := Button.new()
		b.text = Weapons.display_name(id)
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE  # so Space (respawn) never presses a button
		b.button_group = wg
		b.custom_minimum_size = Vector2(118, 40)
		b.pressed.connect(_pick_weapon.bind(id))
		wrow.add_child(b)
		_weapon_btns[id] = b
	var arow: HBoxContainer = %AddonRow
	var ag := ButtonGroup.new()
	for id in Addons.ORDER:
		var b := Button.new()
		b.text = Addons.display_name(id)
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.button_group = ag
		b.custom_minimum_size = Vector2(118, 40)
		b.pressed.connect(_pick_addon.bind(id))
		arow.add_child(b)
		_addon_btns[id] = b
	refresh()
	Net.roster_changed.connect(refresh)


func _current() -> Array:
	var me := multiplayer.get_unique_id()
	if Net.players.has(me):
		return [Net.players[me].weapon, Net.players[me].addon]
	return [Settings.g("weapon"), Settings.g("addon")]


func refresh() -> void:
	var cur := _current()
	if _weapon_btns.has(cur[0]):
		_weapon_btns[cur[0]].set_pressed_no_signal(true)
	if _addon_btns.has(cur[1]):
		_addon_btns[cur[1]].set_pressed_no_signal(true)
	_wdesc.text = Weapons.DATA.get(cur[0], {}).get("desc", "")
	_adesc.text = Addons.DATA.get(cur[1], {}).get("desc", "")


func _pick_weapon(id: String) -> void:
	Settings.s("weapon", id)
	_send(id, _current()[1])


func _pick_addon(id: String) -> void:
	Settings.s("addon", id)
	_send(_current()[0], id)


func _send(w: String, a: String) -> void:
	_wdesc.text = Weapons.DATA.get(w, {}).get("desc", "")
	_adesc.text = Addons.DATA.get(a, {}).get("desc", "")
	if Net.online:
		Net.request_loadout.rpc_id(1, w, a)
