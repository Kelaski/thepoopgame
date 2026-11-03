class_name LoadoutPanel
extends VBoxContainer
## Weapon + addon picker. Used in the lobby and on the death screen.

var _weapon_btns := {}
var _addon_btns := {}
var _wdesc: Label
var _adesc: Label


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	add_child(UiKit.label("WEAPON", 16, UiKit.ACCENT))
	var wrow := UiKit.hbox(6)
	add_child(wrow)
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
	_wdesc = UiKit.label("", 15, UiKit.MUTED)
	_wdesc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_wdesc.custom_minimum_size = Vector2(600, 40)
	add_child(_wdesc)
	add_child(UiKit.label("ADDON", 16, UiKit.ACCENT))
	var arow := UiKit.hbox(6)
	add_child(arow)
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
	_adesc = UiKit.label("", 15, UiKit.MUTED)
	_adesc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_adesc.custom_minimum_size = Vector2(600, 40)
	add_child(_adesc)
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
