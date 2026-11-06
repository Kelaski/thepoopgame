class_name ServerRow
extends HBoxContainer
## One game in the server browser. A game running another version of Tag Rush can't be joined.


func fill(lobby: Dictionary, on_join: Callable) -> void:
	%Host.text = str(lobby.name) if str(lobby.name) != "" else "Tag Rush lobby"
	%Map.text = str(lobby.map)
	%State.text = str(lobby.status)
	%Players.text = "%d / %d" % [lobby.players, lobby.max]
	var same_version: bool = lobby.version == GameVersion.CURRENT
	var full: bool = lobby.players >= lobby.max
	%Join.disabled = not same_version or full
	%Join.text = "Join" if same_version and not full else ("Full" if same_version else "Other version")
	%Join.pressed.connect(on_join)
