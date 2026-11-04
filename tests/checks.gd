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

	# Sprays: a small PNG is fine, one whose header claims 4096x4096 is refused before decoding.
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var png := img.save_png_to_buffer()
	_check(UserImages.valid_spray_bytes(png), "64x64 spray accepted")
	var big := Image.create(300, 8, false, Image.FORMAT_RGBA8).save_png_to_buffer()
	_check(not UserImages.valid_spray_bytes(big), "300 px wide spray refused by its header")

	get_tree().quit(1 if _failed else 0)
