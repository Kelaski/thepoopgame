class_name ServerBrowser
extends Control
## Every open game (assets/ui/server_browser.tscn): who's hosting, what map, how full.
## Asks Steam each time it opens or you refresh.

const ROW := preload("res://assets/ui/menu/server_row.tscn")

var _main


func _ready() -> void:
	%Refresh.pressed.connect(refresh)
	%Close.pressed.connect(hide)
	Net.lobby_list_received.connect(show_lobbies)


func open(main) -> void:
	_main = main
	show()
	refresh()


func refresh() -> void:
	if not Net.steam_ok:
		%Status.text = Net.steam_error
		return
	%Status.text = "Looking for games..."
	Net.find_lobbies()


## This version first, then the fullest, since those games are about to start.
func show_lobbies(lobbies: Array) -> void:
	for child in %Rows.get_children():
		child.free()
	lobbies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var av: bool = a.version == GameVersion.CURRENT
		var bv: bool = b.version == GameVersion.CURRENT
		return av if av != bv else a.players > b.players)
	for lobby: Dictionary in lobbies:
		var row: ServerRow = ROW.instantiate()
		%Rows.add_child(row)
		row.fill(lobby, _main.join_lobby.bind(lobby.id))
	%Status.text = "No games found. Host one, or ask a friend to invite you." if lobbies.is_empty() else "%d games" % lobbies.size()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		hide()
		get_viewport().set_input_as_handled()
