class_name LobbyRow
extends PanelContainer
## One slot in a lobby team list. Fixed size: long text ends in an ellipsis.


func _ready() -> void:
	add_theme_stylebox_override("panel", MenuKit.box(Color(1, 1, 1, 0.04), 10))


func fill(player_name: String, loadout: String, ping: String) -> void:
	%PlayerName.text = player_name
	%Loadout.text = loadout
	%Ping.text = ping
