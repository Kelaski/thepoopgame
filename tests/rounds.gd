extends Node
## Rounds move around: neither team starts where it did last round, the Tag spot
## changes, and the two spawn zones stay apart. Exits 0 on a pass:
##   godot --headless --path . res://tests/rounds.tscn -- --host --port=27203 --autostart=1 --size=small

var _size_before = null


func _fail(why: String) -> void:
	printerr("TEST FAIL: ", why)
	_quit(1)


func _quit(code: int) -> void:
	if _size_before != null:
		Settings.values["map_size"] = _size_before  # in memory only; don't change the player's pick
	get_tree().quit(code)


func _ready() -> void:
	get_tree().create_timer(180.0).timeout.connect(_fail.bind("timed out"))  # never hang a test run
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--size="):
			_size_before = Settings.g("map_size")
			Settings.values["map_size"] = a.substr(7)
		elif a == "--classic":
			Settings.values["map_size"] = "classic"  # in memory only
	add_child((load("res://assets/main.tscn") as PackedScene).instantiate())
	var t := 0.0
	while Game.round_num < 1 and t < 40.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	if Game.round_num < 1:
		return _fail("the match never started")
	var b: Level = Game.world.builder
	var last_obj := Game.objective
	var last: Array = Game._last_team_dots.duplicate()
	var even := 0
	var hidden := 0
	for r in 10:
		Game._server_begin_round()
		var now: Array = Game._last_team_dots
		var tag: Vector3 = b.objectives[Game.objective].pos
		if absf(tag.distance_to(b.spawn_dots[now[0]]) - tag.distance_to(b.spawn_dots[now[1]])) <= Game.TAG_EVEN_DIST:
			even += 1
		var spots := [Game.world.find_spawn_cluster(b.spawn_dots[now[0]], 4), Game.world.find_spawn_cluster(b.spawn_dots[now[1]], 4)]
		if not Game._teams_see_each_other(spots[0], spots[1]):
			hidden += 1
		if b.spawn_dots[now[0]].distance_to(b.spawn_dots[now[1]]) < b.min_spawn_dist:
			return _fail("round %d: spawn zones too close" % r)
		if now[0] == last[0] or now[1] == last[1]:
			return _fail("round %d: a team starts where it did last round (%s after %s)" % [r, now, last])
		if b.objectives.size() > 1 and Game.objective == last_obj:
			return _fail("round %d: the Tag spot didn't move" % r)
		last = now.duplicate()
		last_obj = Game.objective
	print("TEST PASS (%s: %d spawn zones, %d Tag spots; Tag within 10 m of even in %d/10 rounds, teams out of sight in %d/10)" % [Game.map_size, b.spawn_dots.size(), b.objectives.size(), even, hidden])
	_quit(0)
