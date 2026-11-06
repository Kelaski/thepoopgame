extends Node
## Three-player test: client B walks, client A must see it move. Movement
## between clients goes through the host (Net.to_all), so this checks the relay.
## Start the host, then B, then A; A exits 0 on a pass, 1 on a failure:
##   godot --headless --path . res://tests/three_player.tscn -- --host --port=27197 --name=H
##   godot --headless --path . res://tests/three_player.tscn -- --join=127.0.0.1:27197 --name=B
##   godot --headless --path . res://tests/three_player.tscn -- --join=127.0.0.1:27197 --name=A

var role := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--name="):
			role = a.substr(7)
	add_child((load("res://assets/main.tscn") as PackedScene).instantiate())
	var t := 0.0
	while Net.players.size() < 3 and t < 40.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	if Net.players.size() < 3:
		return _done(false, "only %d players joined" % Net.players.size())
	if multiplayer.is_server():
		Game.server_start_match()
	while Game.phase != Game.Phase.RUSH:
		await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	var b: Player = null
	for id in Net.players:
		if Net.players[id].name == "B":
			b = Game.world.players[id]
	if role == "B":
		for i in 120:  # 2 s at 4 m/s, up in the air so nothing is in the way
			await get_tree().physics_frame
			b.global_position = Vector3(0, 60, 0) + Vector3(4.0 * i / 60.0, 0, 0)
			b.velocity = Vector3.ZERO
		await get_tree().create_timer(1.5).timeout
		get_tree().quit()
		return
	if role != "A":
		await get_tree().create_timer(5.0).timeout
		get_tree().quit()
		return
	while b.global_position.y < 50.0:  # B has started its walk up in the air
		await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout
	var x0 := b.global_position.x
	await get_tree().create_timer(0.6).timeout
	var moved := b.global_position.x - x0
	_done(moved > 1.2 and b._jump_votes == 0, "A saw B move %.1f m (%d updates refused)" % [moved, b._jump_votes])


func _done(ok: bool, what: String) -> void:
	print("TEST %s: %s" % ["PASS" if ok else "FAIL", what])
	get_tree().quit(0 if ok else 1)
