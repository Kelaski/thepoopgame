class_name LoadoutPanel
extends VBoxContainer
## Weapon + addon picker (assets/ui/loadout_panel.tscn). Used in the lobby and on
## the death screen. The buttons are listed from Weapons.ORDER and Addons.ACTIVE /
## Addons.PASSIVE: one weapon, one active addon and one passive addon.

var _weapon_btns := {}
var _addon_btns := [{}, {}]  # [active id -> button, passive id -> button]
@onready var _wdesc: Label = %WeaponDesc
@onready var _descs: Array[Label] = [%AddonDesc, %Addon2Desc]


func _ready() -> void:
	theme = MenuKit.theme()  # the death screen sits inside the HUD
	var wg := ButtonGroup.new()
	for id in Weapons.ORDER:
		_weapon_btns[id] = _button(%WeaponRow, wg, Weapons.display_name(id), _pick_weapon.bind(id))
	for slot in 2:
		var g := ButtonGroup.new()
		var rows: VBoxContainer = %AddonRow if slot == 0 else %Addon2Row
		var groups: Dictionary = Addons.ACTIVE if slot == 0 else Addons.PASSIVE
		for sub: String in groups:
			var row := HBoxContainer.new()
			rows.add_child(row)
			var heading := Label.new()
			heading.text = sub
			heading.theme_type_variation = &"MutedLabel"
			heading.custom_minimum_size.x = 76.0
			heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(heading)
			for id: String in groups[sub]:
				_addon_btns[slot][id] = _button(row, g, Addons.display_name(id), _pick_addon.bind(slot, id))
	%AddonTitle.text = "ACTIVE ADDON  [%s]" % Settings.bind_text("addon")
	%Addon2Title.text = "PASSIVE ADDON"
	refresh()
	Net.roster_changed.connect(refresh)


func _button(row: HBoxContainer, group: ButtonGroup, text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE  # so Space (respawn) never presses a button
	b.button_group = group
	b.custom_minimum_size = Vector2(112, 32)
	b.pressed.connect(on_press)
	row.add_child(b)
	return b


## [weapon, active addon, passive addon]
func _current() -> Array:
	var me := multiplayer.get_unique_id()
	if Net.players.has(me):
		var p: Dictionary = Net.players[me]
		return [p.weapon, p.active, p.get("passive", Settings.g("passive"))]
	return [Settings.g("weapon"), Settings.g("active"), Settings.g("passive")]


func refresh() -> void:
	_show(_current())


func _show(cur: Array) -> void:
	if _weapon_btns.has(cur[0]):
		_weapon_btns[cur[0]].set_pressed_no_signal(true)
	_wdesc.text = Weapons.describe(cur[0])
	for slot in 2:
		if _addon_btns[slot].has(cur[slot + 1]):
			_addon_btns[slot][cur[slot + 1]].set_pressed_no_signal(true)
		_descs[slot].text = Addons.describe(cur[slot + 1])


func _pick_weapon(id: String) -> void:
	Settings.s("weapon", id)
	var cur := _current()
	cur[0] = id
	_send(cur)


func _pick_addon(slot: int, id: String) -> void:
	Settings.s("active" if slot == 0 else "passive", id)
	var cur := _current()
	cur[slot + 1] = id
	_send(cur)


func _send(cur: Array) -> void:
	_show(cur)
	if Net.online:
		Net.request_loadout.rpc_id(1, cur[0], cur[1], cur[2])
