extends Node
## Procedurally generated sound effects (no audio asset files needed).
## Sounds are synthesized once at startup into AudioStreamWAV buffers.

const RATE := 22050

var streams := {}
var _players: Array[AudioStreamPlayer] = []
var _players3d: Array[AudioStreamPlayer3D] = []
var _i2 := 0
var _i3 := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	streams["ar"] = _gunshot(rng, 0.16, 0.55, 140.0, 1.0)
	streams["smg"] = _gunshot(rng, 0.10, 0.75, 220.0, 0.85)
	streams["shotgun"] = _gunshot(rng, 0.34, 0.35, 90.0, 1.0)
	streams["sniper"] = _gunshot(rng, 0.5, 0.25, 70.0, 1.0)
	streams["bat"] = _whoosh(rng, 0.18)
	streams["bat_hit"] = _thud(rng, 0.12, 180.0)
	streams["thrown"] = _whoosh(rng, 0.3)
	streams["reload"] = _clicks(rng)
	streams["hit"] = _tap(rng, 1100.0, 0.05, 0.45)
	streams["head"] = _tap(rng, 1700.0, 0.06, 0.5)
	streams["kill"] = _bell(1250.0, 1.1, 0.5)
	streams["step"] = _step(rng)
	streams["heartbeat"] = _heartbeat()
	streams["door"] = _thud(rng, 0.22, 90.0)
	streams["pickup"] = _chirp(500.0, 1200.0, 0.35, 0.5)
	streams["drop"] = _chirp(900.0, 300.0, 0.4, 0.5)
	streams["addon"] = _chirp(400.0, 800.0, 0.18, 0.35)
	streams["addon_end"] = _chirp(700.0, 350.0, 0.18, 0.3)
	streams["jump"] = _thud(rng, 0.08, 120.0)
	streams["round"] = _chirp(300.0, 600.0, 0.6, 0.5)
	streams["tick"] = _tone(1000.0, 0.03, 0.35)
	streams["hurt"] = _thud(rng, 0.15, 60.0)
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	for i in 24:
		var p3 := AudioStreamPlayer3D.new()
		p3.bus = "SFX"
		p3.unit_size = 8.0
		p3.max_distance = 120.0
		p3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p3)
		_players3d.append(p3)


func play(sound: String, vol_db := 0.0, pitch := 1.0, bus := "SFX") -> void:
	if not streams.has(sound):
		return
	var p := _players[_i2]
	_i2 = (_i2 + 1) % _players.size()
	p.stream = streams[sound]
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.bus = bus
	p.play()


func play_at(sound: String, pos: Vector3, vol_db := 0.0, max_dist := 120.0, pitch := 1.0) -> void:
	if not streams.has(sound):
		return
	var p := _players3d[_i3]
	_i3 = (_i3 + 1) % _players3d.size()
	p.stream = streams[sound]
	p.volume_db = vol_db
	p.max_distance = max_dist
	p.pitch_scale = pitch
	p.global_position = pos
	p.play()


# --------------------------------------------------------------- synthesis

func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


func _gunshot(rng: RandomNumberGenerator, length: float, brightness: float, thump_hz: float, vol: float) -> AudioStreamWAV:
	var n := int(length * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * (9.0 / length))
		var noise := rng.randf_range(-1.0, 1.0)
		lp = lerpf(lp, noise, brightness)
		var thump := sin(TAU * thump_hz * t * (1.0 - t)) * exp(-t * 30.0)
		s[i] = (lp * 0.8 + thump * 0.7) * env * vol
	return _wav(s)


func _whoosh(rng: RandomNumberGenerator, length: float) -> AudioStreamWAV:
	var n := int(length * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / n
		var env := sin(PI * t)
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.08 + 0.2 * t)
		s[i] = lp * env * 1.6
	return _wav(s)


func _thud(rng: RandomNumberGenerator, length: float, hz: float) -> AudioStreamWAV:
	var n := int(length * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * (7.0 / length))
		s[i] = (sin(TAU * hz * t) * 0.8 + rng.randf_range(-0.3, 0.3)) * env
	return _wav(s)


func _tone(hz: float, length: float, vol: float) -> AudioStreamWAV:
	var n := int(length * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		s[i] = sin(TAU * hz * t) * vol * (1.0 - float(i) / n)
	return _wav(s)


func _chirp(f0: float, f1: float, length: float, vol: float) -> AudioStreamWAV:
	var n := int(length * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		phase += TAU * lerpf(f0, f1, t) / RATE
		s[i] = sin(phase) * vol * sin(PI * t)
	return _wav(s)


## Soft "tap": a very short, damped knock with a little noise.
func _tap(rng: RandomNumberGenerator, hz: float, length: float, vol: float) -> AudioStreamWAV:
	var n := int(length * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * 90.0)
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.25)
		s[i] = (sin(TAU * hz * t) * 0.7 + lp * 0.5) * env * vol
	return _wav(s)


## Bell ping: inharmonic partials with a long ring-out.
func _bell(hz: float, length: float, vol: float) -> AudioStreamWAV:
	var partials := [[1.0, 1.0, 3.0], [2.0, 0.6, 4.0], [2.76, 0.45, 5.0], [5.4, 0.25, 8.0], [8.93, 0.12, 11.0]]
	var n := int(length * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for p in partials:
			v += sin(TAU * hz * float(p[0]) * t) * float(p[1]) * exp(-t * float(p[2]))
		var attack := minf(1.0, t * 400.0)
		s[i] = v * vol * 0.45 * attack
	return _wav(s)


func _step(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var n := int(0.09 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * 45.0)
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.12)
		s[i] = (lp * 1.4 + sin(TAU * 85.0 * t) * 0.6) * env
	return _wav(s)


func _clicks(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var n := int(0.35 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var c1 := exp(-maxf(t - 0.0, 0.0) * 120.0) if t >= 0.0 else 0.0
		var c2 := exp(-maxf(t - 0.22, 0.0) * 120.0) if t >= 0.22 else 0.0
		s[i] = rng.randf_range(-1.0, 1.0) * (c1 + c2) * 0.6
	return _wav(s)


func _heartbeat() -> AudioStreamWAV:
	var n := int(0.55 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var b1 := sin(TAU * 55.0 * t) * exp(-t * 22.0)
		var t2 := t - 0.22
		var b2 := 0.0
		if t2 > 0.0:
			b2 = sin(TAU * 48.0 * t2) * exp(-t2 * 20.0) * 0.8
		s[i] = (b1 + b2) * 1.2
	return _wav(s)
