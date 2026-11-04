class_name LoadoutPanel
extends VBoxContainer
## Weapon + addon picker (assets/ui/loadout_panel.tscn). Used in the lobby and on
## the death screen. The buttons are listed from Weapons.ORDER and Addons.PRIMARY /
## Addons.SECONDARY: one weapon, one primary addon and one secondary addon.

var _weapon_btns := {}
var _addon_btns := [{}, {}]  # [primary id -> button, secondary id -> button]
@onready var _wdesc: Label = %WeaponDesc
@onready var _descs: Array[Label] = [%AddonDesc, %Addon2Desc]


func _ready() -> void:
	var wg := ButtonGroup.new()
	for id in Weapons.ORDER:
		_weapon_btns[id] = _button(%WeaponRow, wg, Weapons.display_name(id), _pick_weapon.bind(id))
	for slot in 2:
		var g := ButtonGroup.new()
		var row: HBoxContainer = %AddonRow if slot == 0 else %Addon2Row
		for id in (Addons.PRIMARY if slot == 0 else Addons.SECONDARY):
			_addon_btns[slot][id] = _button(row, g, Addons.display_name(id), _pick_addon.bind(slot, id))
	%AddonTitle.text = "PRIMARY ADDON  [%s]" % Settings.bind_text("addon")
	%Addon2Title.text = "SECONDARY ADDON  [%s]" % Settings.bind_text("addon2")
	refresh()
	Net.roster_changed.connect(refresh)


func _button(row: HBoxContainer, group: ButtonGroup, text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE  # so Space (respawn) never presses a button
	b.button_group = group
	b.custom_minimum_size = Vector2(112, 40)
	b.pressed.connect(on_press)
	row.add_child(b)
	return b


## [weapon, primary addon, secondary addon]
func _current() -> Array:
	var me := multiplayer.get_unique_id()
	if Net.players.has(me):
		var p: Dictionary = Net.players[me]
		return [p.weapon, p.addon, p.get("addon2", Settings.g("addon2"))]
	return [Settings.g("weapon"), Settings.g("addon"), Settings.g("addon2")]


func refresh() -> void:
	_show(_current())


func _show(cur: Array) -> void:
	if _weapon_btns.has(cur[0]):
		_weapon_btns[cur[0]].set_pressed_no_signal(true)
	_wdesc.text = Weapons.DATA.get(cur[0], {}).get("desc", "")
	for slot in 2:
		if _addon_btns[slot].has(cur[slot + 1]):
			_addon_btns[slot][cur[slot + 1]].set_pressed_no_signal(true)
		_descs[slot].text = Addons.DATA.get(cur[slot + 1], {}).get("desc", "")


func _pick_weapon(id: String) -> void:
	Settings.s("weapon", id)
	var cur := _current()
	cur[0] = id
	_send(cur)


func _pick_addon(slot: int, id: String) -> void:
	Settings.s("addon" if slot == 0 else "addon2", id)
	var cur := _current()
	cur[slot + 1] = id
	_send(cur)


func _send(cur: Array) -> void:
	_show(cur)
	if Net.online:
		Net.request_loadout.rpc_id(1, cur[0], cur[1], cur[2])
