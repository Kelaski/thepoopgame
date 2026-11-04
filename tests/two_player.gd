extends Node
## Two-player smoke test over a local (debug-only) ENet match. Checks joining,
## unique names and that movement updates get through the teleport filter.
## Run the host and the joiner at once (see DEVELOPMENT.md); the host exits 0 on pass.

func _fail(why: String) -> void:
	printerr("TEST FAIL: ", why)
	get_tree().quit(1)


func _ready() -> void:
	add_child((load("res://scenes/main.tscn") as PackedScene).instantiate())
	var t := 0.0
	while Net.players.size() < 2 and t < 40.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	if not multiplayer.is_server():
		await get_tree().create_timer(25.0).timeout  # stay connected while the host checks
		get_tree().quit()
		return
	if Net.players.size() != 2:
		return _fail("the joiner never registered")
	var names: Array = Net.players.values().map(func(p): return p.name)
	if names[0] == names[1]:
		return _fail("duplicate names %s" % [names])
	Game.server_start_match()
	while Game.phase != Game.Phase.RUSH and t < 60.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	await get_tree().create_timer(2.0).timeout
	for id in Game.world.players:
		var p: Player = Game.world.players[id]
		if not p.is_local and (not p._has_net or p._jump_votes != 0):
			return _fail("movement from %d was dropped" % id)
	print("TEST PASS")
	get_tree().quit(0)
