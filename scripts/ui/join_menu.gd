class_name JoinMenu
extends Control
## "Join Game" (assets/ui/join_menu.tscn): a browser for public Tag Rush lobbies
## on Steam. Each row is an assets/ui/lobby_row.tscn.

const ROW := preload("res://assets/ui/lobby_row.tscn")

var main
var message := ""


func _ready() -> void:
	%Message.text = message
	%Message.visible = message != ""
	Net.lobby_list_received.connect(_on_lobbies)
	_refresh()


func _refresh() -> void:
	if not Net.steam_ok:
		_show_empty(Net.steam_error)
		return
	_show_empty("Looking for lobbies...")
	%RefreshButton.disabled = true
	Net.find_lobbies()


func _show_empty(text: String) -> void:
	for c in %Lobbies.get_children():
		if c != %Empty:
			c.queue_free()
	%Empty.text = text
	%Empty.visible = true


func _on_lobbies(lobbies: Array) -> void:
	%RefreshButton.disabled = false
	_show_empty("No public lobbies right now. Host one, or ask a friend to invite you.")
	# Lobbies on this version first, then the fullest.
	lobbies.sort_custom(func(a, b):
		var av: bool = a.version == GameVersion.CURRENT
		var bv: bool = b.version == GameVersion.CURRENT
		return av if av != bv else a.players > b.players)
	for l: Dictionary in lobbies:
		var row: Control = ROW.instantiate()
		var same: bool = l.version == GameVersion.CURRENT
		var host: String = l.name if l.name != "" else "Tag Rush lobby"
		(row.get_node("Row/Host") as Label).text = host if same else "%s  (v%s)" % [host, l.version]
		(row.get_node("Row/Players") as Label).text = "%d / %d" % [l.players, l.max]
		var b: Button = row.get_node("Row/JoinButton")
		b.disabled = not same or l.players >= l.max
		b.tooltip_text = "" if same else "This lobby is on version %s; you're on %s." % [l.version, GameVersion.CURRENT]
		b.pressed.connect(main.join_lobby.bind(l.id))
		%Lobbies.add_child(row)
	%Empty.visible = lobbies.is_empty()


func _on_back_pressed() -> void:
	main.show_main_menu()
