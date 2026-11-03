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
	streams["birds"] = _birds(rng, 2.0)
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


## Birdsong: bursts of fast, warbling high-pitched chirps from a few "birds".
func _birds(rng: RandomNumberGenerator, length: float) -> AudioStreamWAV:
	var n := int(length * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for bird in 3:
		var base := rng.randf_range(2600.0, 4200.0)
		var t := rng.randf_range(0.0, 0.25)
		while t < length - 0.1:
			# A phrase of 2-5 quick chirps
			var count := rng.randi_range(2, 5)
			for c in count:
				var dur := rng.randf_range(0.04, 0.09)
				var f0 := base * rng.randf_range(0.9, 1.15)
				var f1 := f0 * rng.randf_range(1.2, 1.7) if rng.randf() < 0.6 else f0 * rng.randf_range(0.6, 0.85)
				var start := int(t * RATE)
				var cnt := int(dur * RATE)
				var phase := 0.0
				for i in cnt:
					if start + i >= n:
						break
					var u := float(i) / cnt
					var f := lerpf(f0, f1, u) * (1.0 + 0.04 * sin(TAU * 60.0 * u * dur))
					phase += TAU * f / RATE
					s[start + i] += sin(phase) * sin(PI * u) * 0.32
				t += dur + rng.randf_range(0.02, 0.06)
			t += rng.randf_range(0.12, 0.4)
	# Gentle fade in / out
	for i in n:
		var edge := minf(float(i), float(n - i)) / (0.05 * RATE)
		s[i] *= minf(1.0, edge)
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


# ================================================================ music
# A fast, punchy 160 BPM loop (8 bars, ~12 s): four-on-the-floor kick with
# off-beat kicks, snare + clap, rolling hats, a side-chained saw bass and a
# square-wave arpeggio, with a snare-roll fill on the last bar. Rendered once
# the first time a match starts.

const BPM := 160.0
const BARS := 8

var _music: AudioStreamPlayer
var _music_stream: AudioStreamWAV
var _music_tween: Tween


func start_music() -> void:
	if _music_stream == null:
		_music_stream = _render_music()
	if _music == null:
		_music = AudioStreamPlayer.new()
		_music.bus = "Music"
		add_child(_music)
	if _music_tween:
		_music_tween.kill()
	_music.stream = _music_stream
	_music.volume_db = -30.0
	_music.play()
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", -4.0, 1.5)


func stop_music() -> void:
	if _music == null or not _music.playing:
		return
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", -40.0, 0.8)
	_music_tween.tween_callback(_music.stop)


func _render_music() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 160
	var sixteenth := 60.0 / BPM / 4.0
	var steps := BARS * 16
	var n := int(steps * sixteenth * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var kick := _m_kick()
	var snare := _m_snare(rng)
	var hat := _m_hat(rng, 0.035)
	var open_hat := _m_hat(rng, 0.16)
	for step in steps:
		var bar := step / 16
		var s := step % 16
		var at := int(step * sixteenth * RATE)
		# Kick: every beat plus syncopated pushes
		if s % 4 == 0 or s == 14 or (s == 7 and bar % 2 == 1):
			_mix(buf, kick, at, 1.0 if s % 4 == 0 else 0.75)
		# Snare/clap on 2 and 4, with a roll on the last bar
		if s == 4 or s == 12:
			_mix(buf, snare, at, 0.8)
		if bar == BARS - 1 and s >= 8:
			_mix(buf, snare, at, 0.25 + 0.05 * (s - 8))
		# Hats: 16ths, open hat on the off-beat "and"
		if s % 4 == 2:
			_mix(buf, open_hat, at, 0.32)
		else:
			_mix(buf, hat, at, 0.18 if s % 2 == 0 else 0.26)
	# Bass + arp, chord per 2 bars: Am, F, C, G
	var roots := [55.0, 43.65, 65.41, 49.0]
	var chords := [[0, 3, 7, 12], [0, 4, 7, 12], [0, 4, 7, 12], [0, 4, 7, 12]]
	var beat := 60.0 / BPM
	var lp := 0.0
	var arp_lp := 0.0
	var phase := 0.0
	var arp_phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var step_f := t / sixteenth
		var step := int(step_f)
		var bar := step / 16
		var chord := (bar / 2) % 4
		var root: float = roots[chord]
		# Bass: 8th-note pulse with an octave jump on off-beats
		var eighth := step / 2
		var f := root * (2.0 if eighth % 2 == 1 else 1.0)
		phase = fmod(phase + f / RATE, 1.0)
		var saw := phase * 2.0 - 1.0
		lp = lerpf(lp, saw, 0.09)
		var since_beat := fmod(t, beat)
		var duck := clampf(since_beat / 0.13, 0.25, 1.0)  # side-chain from the kick
		var note_t := fmod(t, sixteenth * 2.0)
		var bass := lp * exp(-note_t * 6.0) * duck * 0.55
		# Arp: 16th notes over the chord, two octaves up, enters on bar 3
		var arp := 0.0
		if bar >= 2:
			var semis: int = chords[chord][step % 4]
			var af: float = root * 4.0 * pow(2.0, semis / 12.0)
			arp_phase = fmod(arp_phase + af / RATE, 1.0)
			var sq := 1.0 if arp_phase < 0.5 else -1.0
			arp_lp = lerpf(arp_lp, sq, 0.25)
			var at16 := fmod(t, sixteenth)
			arp = arp_lp * exp(-at16 * 18.0) * 0.12 * duck
		buf[i] += bass + arp
	# Glue: soft clip
	for i in n:
		buf[i] = tanh(buf[i] * 1.3) * 0.85
	var w := _wav(buf)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w


func _mix(buf: PackedFloat32Array, smp: PackedFloat32Array, at: int, gain: float) -> void:
	var m := mini(smp.size(), buf.size() - at)
	for j in m:
		buf[at + j] += smp[j] * gain


func _m_kick() -> PackedFloat32Array:
	var n := int(0.28 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 45.0 + 110.0 * exp(-t * 30.0)
		ph += TAU * f / RATE
		var click := exp(-t * 400.0) * 0.6
		s[i] = tanh((sin(ph) * exp(-t * 9.0) + click) * 2.2) * 0.9
	return s


func _m_snare(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(0.2 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var prev := 0.0
	for i in n:
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		var hp := noise - prev
		prev = noise
		var body := sin(TAU * 190.0 * t) * exp(-t * 30.0)
		var clap := 0.0
		for k in 3:
			var ct := t - k * 0.008
			if ct >= 0.0:
				clap += exp(-ct * 70.0)
		s[i] = (hp * 0.5 * exp(-t * 16.0) + body * 0.6 + noise * clap * 0.25)
	return s


func _m_hat(rng: RandomNumberGenerator, decay: float) -> PackedFloat32Array:
	var n := int((decay * 3.0 + 0.01) * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var prev := 0.0
	for i in n:
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		s[i] = (noise - prev) * exp(-t / decay)
		prev = noise
	return s
