extends Node
## Quick server-safety checks, no network needed. Exits 0 if all pass, 1 if not:
##   godot --headless --path . res://tests/checks.tscn

var _failed := 0


func _check(ok: bool, what: String) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failed += 1


func _ready() -> void:
	# Hit rate: 60 SMG hits claimed in one second, it fires 14 rounds/s.
	Game._hit_tokens.clear()
	var got := 0
	for i in 60:
		Game._now = 1000.0 + i / 60.0
		if Game._take_hit_token(999, "smg"):
			got += 1
	_check(got >= 14 and got <= 30, "SMG hit rate limited (%d of 60 accepted)" % got)

	# Movement: legal top speed passes, a speed hack over one second doesn't.
	_check(Player._reachable(Vector3.ZERO, 0.0, Vector3(30, 0, 0), 1.0), "30 m/s accepted")
	_check(not Player._reachable(Vector3.ZERO, 0.0, Vector3(65, 0, 0), 1.0), "65 m/s along the ground rejected")
	_check(Player._reachable(Vector3.ZERO, 0.0, Vector3(0, -60, 0), 1.0), "60 m/s fall accepted")

	# Movement over a bumpy connection: updates delayed 50-400 ms, with stalls.
	_check(_longest_freeze(12.0, 1.0) < 0.6, "jittery 12 m/s runner never freezes (longest gap %.2f s)" % _longest_freeze(12.0, 1.0))
	_check(_accepted_share(60.0, 1.0) < 0.6, "60 m/s speed hack mostly refused (%.0f%% accepted)" % (100 * _accepted_share(60.0, 1.0)))
	_check(_accepted_share(60.0, 2.0) < 0.6, "speed hack with a fast clock mostly refused (%.0f%% accepted)" % (100 * _accepted_share(60.0, 2.0)))
	_simulate(12.0, 1.0)
	_check(_peak_speed < 14.0, "bursty 12 m/s runner isn't seen as faster (peak %.1f m/s)" % _peak_speed)

	# Updater: version order and the right download for each platform.
	_check(UpdateScreen.is_newer("0.21.0a", "0.20.0") and UpdateScreen.is_newer("1.0.0", "0.99.9"), "newer versions detected")
	_check(not UpdateScreen.is_newer("0.20.0a", "0.20.0") and not UpdateScreen.is_newer("0.9.0", "0.20.0"), "same or older versions ignored")
	var assets := [{"name": "Tag.Rush.0.21.0a.Linux.zip"}, {"name": "Tag.Rush.0.21.0a.zip"}]
	_check(UpdateScreen.pick_asset(assets, "Windows").name == "Tag.Rush.0.21.0a.zip" and UpdateScreen.pick_asset(assets, "Linux").name == "Tag.Rush.0.21.0a.Linux.zip", "right download per platform")
	_check_unzip()

	# Addons: every one is in exactly one slot; an old single-slot save moves over.
	var both: Array = Addons.PRIMARY + Addons.SECONDARY
	_check(both.size() == Addons.DATA.size() and both.all(func(id): return Addons.DATA.has(id)), "every addon is primary or secondary")
	var saved := Settings.values.duplicate()
	Settings.values["addon"] = "stalker"
	Settings._migrate_addons()
	_check(Settings.values.addon == Addons.DEFAULT_PRIMARY and Settings.values.addon2 == "stalker", "old save: secondary addon moves to the secondary slot")
	Settings.values = saved
	# Moonwalker: the rocket jump reaches 8 m under its lighter gravity, then cools down.
	var mw := Player.new()
	mw.addon = "moonwalker"
	mw.rocket_armed = true
	var v := mw._jump_speed(Player.JUMP_V)
	var apex := v * v / (2.0 * Player.GRAVITY * Addons.MOON_GRAVITY)
	_check(absf(apex - Addons.MOON_ROCKET_H) < 0.05 and not mw.rocket_armed and mw.addon_cd[Player.PRI] == Addons.MOON_CD, "rocket jump %.2f m, then cooldown" % apex)
	_check(is_equal_approx(mw._jump_speed(Player.JUMP_V), Player.JUMP_V), "next jump is a normal one")
	mw.free()
	# Reload on Kill: a sniper that just fired and is empty can shoot again at once.
	var rk := Player.new()
	rk.addon2 = "reloader"
	rk.weapon = "sniper"
	rk.alive = true
	rk.ammo = 0
	rk.fire_cd = 1.0
	rk.reloading = 2.0
	rk.on_kill()
	_check(rk.ammo == int(Weapons.DATA.sniper.mag) and rk.fire_cd == 0.0 and rk.reloading == 0.0, "Reload on Kill refills and re-chambers")
	rk.free()

	# Sprays: a small PNG is fine, one whose header claims 4096x4096 is refused before decoding.
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var png := img.save_png_to_buffer()
	_check(UserImages.valid_spray_bytes(png), "64x64 spray accepted")
	var big := Image.create(300, 8, false, Image.FORMAT_RGBA8).save_png_to_buffer()
	_check(not UserImages.valid_spray_bytes(big), "300 px wide spray refused by its header")

	get_tree().quit(1 if _failed else 0)


## Feeds 8 s of movement updates (30 per second, moving at `speed`, the sender's
## clock running `clock` times real time) through Player._net_filter in arrival
## order. Returns [accepted send times].
var _peak_speed := 0.0  # fastest observed_speed() in the last _simulate


func _simulate(speed: float, clock: float) -> Array:
	_peak_speed = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var p := Player.new()
	var updates := []
	for i in 240:
		var t := i / 30.0
		var delay := rng.randf_range(0.05, 0.4) + (0.5 if i % 50 > 44 else 0.0)  # every 50th packet starts a stall
		updates.append([t + delay, t, Vector3(speed * t, 0, 0)])
	updates.sort_custom(func(a, b): return a[0] < b[0])
	var got := []
	for u in updates:
		if p._net_filter(u[2], 100.0 + u[1] * clock, 100.0 + u[0]):
			p._has_net = true
			p._observe_speed(u[2], 100.0 + u[1] * clock)
			_peak_speed = maxf(_peak_speed, p.observed_speed())
			got.append(u[1])
	p.free()
	return got


func _longest_freeze(speed: float, clock: float) -> float:
	var got := _simulate(speed, clock)
	var gap := 0.0
	for i in range(1, got.size()):
		gap = maxf(gap, got[i] - got[i - 1])
	return gap


func _accepted_share(speed: float, clock: float) -> float:
	return _simulate(speed, clock).size() / 240.0


## The updater unpacks a release: files land in the folder, the game exe is
## found, and an entry that tries to climb out of the folder ("zip slip") is skipped.
func _check_unzip() -> void:
	var root := ProjectSettings.globalize_path("user://test_unzip")
	DirAccess.make_dir_recursive_absolute(root)
	var zip := root.path_join("t.zip")
	var z := ZIPPacker.new()
	z.open(zip)
	for entry in ["game.exe", "sub/data.txt", "../evil.txt"]:
		z.start_file(entry)
		z.write_file("x".to_utf8_buffer())
		z.close_file()
	z.close()
	var out := root.path_join("new")
	var exe := UpdateScreen._unzip(zip, out)
	_check(exe == "game.exe" and FileAccess.file_exists(out.path_join("sub/data.txt")), "update unpacked, game found")
	_check(not FileAccess.file_exists(root.path_join("evil.txt")), "update entry outside its folder refused")
	UpdateScreen._remove_tree(root)
