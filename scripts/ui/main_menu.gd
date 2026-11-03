class_name MainMenu
extends Control

var main
var message := ""
var _name: LineEdit
var _ip: LineEdit
var _port: LineEdit


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UiKit.MENU_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var stripe := ColorRect.new()
	stripe.color = Color(1.0, 0.82, 0.25, 0.08)
	stripe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stripe.offset_top = 260
	stripe.offset_bottom = -420
	add_child(stripe)

	var v := UiKit.centered_panel(self, Vector2(520, 0))
	var title := UiKit.label("TAG RUSH", 64, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(title)
	v.add_child(UiKit.label("Grab the Tag. Protect your Runner. First to 4 rounds.", 18, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(HSeparator.new())

	v.add_child(UiKit.label("Player name"))
	_name = LineEdit.new()
	_name.text = str(Settings.g("player_name"))
	_name.max_length = 20
	_name.text_changed.connect(func(t: String): Settings.s("player_name", t))
	v.add_child(_name)

	var row := UiKit.hbox(8)
	var ipcol := UiKit.vbox(4)
	ipcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ipcol.add_child(UiKit.label("Host IP address"))
	_ip = LineEdit.new()
	_ip.text = str(Settings.g("last_ip"))
	_ip.placeholder_text = "e.g. 192.168.1.20"
	ipcol.add_child(_ip)
	row.add_child(ipcol)
	var portcol := UiKit.vbox(4)
	portcol.add_child(UiKit.label("Port"))
	_port = LineEdit.new()
	_port.text = str(Settings.g("port"))
	_port.custom_minimum_size.x = 110
	portcol.add_child(_port)
	row.add_child(portcol)
	v.add_child(row)

	var btns := UiKit.hbox(10)
	var host := UiKit.button("Host Game", _on_host, 200)
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var join := UiKit.button("Join Game", _on_join, 200)
	join.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btns.add_child(host)
	btns.add_child(join)
	v.add_child(btns)
	var b2 := UiKit.hbox(10)
	var st := UiKit.button("Settings", func(): main.open_settings(false), 200)
	st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var quit := UiKit.button("Quit", func(): get_tree().quit(), 200)
	quit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b2.add_child(st)
	b2.add_child(quit)
	var b3 := UiKit.hbox(10)
	var mus := UiKit.button("Music & Playlist", func(): main.open_music(false), 200)
	mus.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := UiKit.button("Customize Colours", func(): main.open_colors(false), 200)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b3.add_child(mus)
	b3.add_child(col)
	v.add_child(b3)
	v.add_child(b2)

	if message != "":
		v.add_child(UiKit.label(message, 18, Color("ff7a6a"), HORIZONTAL_ALIGNMENT_CENTER))
	var help := UiKit.label("Hosting: share your LAN IP (shown in the lobby). Over the internet, forward UDP port %s." % _port.text, 14, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size.x = 480
	v.add_child(help)


func _port_value() -> int:
	var p := int(_port.text)
	return p if p > 0 and p < 65536 else Net.DEFAULT_PORT


func _on_host() -> void:
	main.host_game(_port_value())


func _on_join() -> void:
	var ip := _ip.text.strip_edges()
	if ip == "":
		ip = "127.0.0.1"
	main.join_game(ip, _port_value())
