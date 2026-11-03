class_name Lobby
extends Control

var main
var _teams: Array = []
var _start: Button
var _status: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("1b2430")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var v := UiKit.centered_panel(self, Vector2(820, 0))
	v.add_child(UiKit.label("LOBBY", 40, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	if multiplayer.is_server():
		var ips: Array = Net.local_ips()
		var txt := "Hosting on port %d. Friends join with: %s" % [int(Settings.g("port")), ", ".join(PackedStringArray(ips)) if not ips.is_empty() else "your IP address"]
		var l := UiKit.label(txt, 16, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	else:
		v.add_child(UiKit.label("Connected. Waiting for the host to start the match.", 16, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	var cols := UiKit.hbox(16)
	v.add_child(cols)
	for team in 2:
		var pc := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Mats.team_color(team).darkened(0.55)
		sb.set_corner_radius_all(10)
		sb.set_content_margin_all(14)
		pc.add_theme_stylebox_override("panel", sb)
		pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pc.custom_minimum_size = Vector2(0, 260)
		cols.add_child(pc)
		var tv := UiKit.vbox(6)
		pc.add_child(tv)
		tv.add_child(UiKit.label("%s TEAM" % Mats.team_name(team).to_upper(), 22, Mats.team_color(team).lightened(0.3)))
		var list := UiKit.vbox(4)
		list.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tv.add_child(list)
		tv.add_child(UiKit.button("Join %s" % Mats.team_name(team), func(): Net.request_team.rpc_id(1, team), 160))
		_teams.append(list)

	v.add_child(HSeparator.new())
	v.add_child(LoadoutPanel.new())
	v.add_child(HSeparator.new())
	var row := UiKit.hbox(10)
	v.add_child(row)
	if multiplayer.is_server():
		_start = UiKit.button("START MATCH", func(): Game.server_start_match(), 220)
		row.add_child(_start)
		row.add_child(UiKit.button("Shuffle Teams", func(): Net.request_shuffle.rpc_id(1), 180))
	row.add_child(UiKit.button("Settings", func(): main.open_settings(false), 150))
	row.add_child(UiKit.button("Leave", func(): main.leave_to_menu(), 140))
	_status = UiKit.label("", 15, UiKit.MUTED)
	v.add_child(_status)
	Net.roster_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	for team in 2:
		var list: VBoxContainer = _teams[team]
		for c in list.get_children():
			c.queue_free()
		for id in Net.players:
			var p: Dictionary = Net.players[id]
			if p.team != team:
				continue
			var tag := " (host)" if id == 1 else ""
			var me := "  < you" if id == multiplayer.get_unique_id() else ""
			list.add_child(UiKit.label("%s%s   %s / %s%s" % [p.name, tag, Weapons.display_name(p.weapon), Addons.display_name(p.addon), me], 17))
	_status.text = "%d / %d players" % [Net.players.size(), Net.MAX_PLAYERS]
