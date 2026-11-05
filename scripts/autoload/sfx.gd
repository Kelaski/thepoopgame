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
	# Drive 2.2: about +4.3 dB of loudness (35% louder to the ear) with no clipping.
	streams["ar"] = _gunshot(rng, 0.16, 0.55, 140.0, 1.0, GUN_DRIVE)
	streams["smg"] = _gunshot(rng, 0.10, 0.75, 220.0, 0.85, GUN_DRIVE)
	streams["shotgun"] = _gunshot(rng, 0.34, 0.35, 90.0, 1.0, GUN_DRIVE)
	streams["sniper"] = _gunshot(rng, 0.5, 0.25, 70.0, 1.0)
	streams["bat"] = _whoosh(rng, 0.18)
	streams["bat_hit"] = _thud(rng, 0.12, 180.0)
	streams["thrown"] = _whoosh(rng, 0.3)
	streams["reload"] = _clicks(rng)
	streams["hit"] = _tap(rng, 1100.0, 0.05, 0.45)
	streams["head"] = _tap(rng, 1700.0, 0.06, 0.5)
	streams["kill"] = _bell(1250.0, 1.1, 0.5)
	streams["step"] = _step(rng)
	streams["spray"] = _whoosh(rng, 0.45)
	streams["heartbeat"] = _heartbeat()
	streams["door"] = _thud(rng, 0.22, 90.0)
	streams["pickup"] = _chirp(500.0, 1200.0, 0.35, 0.5)
	streams["drop"] = _chirp(900.0, 300.0, 0.4, 0.5)
	streams["addon"] = _chirp(400.0, 800.0, 0.18, 0.35)
	streams["addon_end"] = _chirp(700.0, 350.0, 0.18, 0.3)
	streams["jump"] = _thud(rng, 0.08, 120.0)
	# Round over: a two-note horn. Match over: a rising fanfare, or a falling one.
	streams["round_end"] = _notes([392.0, 523.25], [0.22, 0.55], 0.42, 0.35)
	streams["match_win"] = _notes([523.25, 659.25, 783.99, 1046.5], [0.14, 0.14, 0.14, 0.9], 0.4, 0.25)
	streams["match_lose"] = _notes([440.0, 349.23, 293.66, 220.0], [0.24, 0.24, 0.24, 1.0], 0.4, 0.5)
	streams["tick"] = _tone(1000.0, 0.03, 0.35)
	streams["count"] = _beep(196.0, 0.3, 0.55)
	streams["go"] = _go(rng)
	streams["ping"] = _bell(1760.0, 0.35, 0.4)
	streams["ping_danger"] = _chirp(1500.0, 950.0, 0.22, 0.45)
	streams["hurt"] = _thud(rng, 0.15, 60.0)
	streams["swap_beam"] = _beam(Addons.SWAP_CHARGE)
	streams["warp"] = _chirp(1600.0, 260.0, 0.22, 0.45)
	streams["rocket"] = _whoosh(rng, 0.55)
	streams["parry"] = _bell(2350.0, 0.4, 0.45)
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
	_render_thread = Thread.new()
	_render_thread.start(_render_all_songs)


func _exit_tree() -> void:
	if _render_thread:
		_render_thread.wait_to_finish()
		_render_thread = null


## Per-sound volume boosts, applied everywhere the sound plays (your own shots and
## other players'). The sniper is 60% louder (x1.6 = +4.08 dB). The other guns get
## their extra loudness from GUN_DRIVE in the synthesis instead: a playback boost
## just pushed them past full scale, where it got clipped off and wasn't heard.
const GAIN_DB := {"sniper": 4.08}
const GUN_DRIVE := 2.2


func play(sound: String, vol_db := 0.0, pitch := 1.0, bus := "SFX") -> void:
	if not streams.has(sound):
		return
	var p := _players[_i2]
	_i2 = (_i2 + 1) % _players.size()
	p.stream = streams[sound]
	p.volume_db = vol_db + float(GAIN_DB.get(sound, 0.0))
	p.pitch_scale = pitch
	p.bus = bus
	p.play()


func play_at(sound: String, pos: Vector3, vol_db := 0.0, max_dist := 120.0, pitch := 1.0) -> void:
	if not streams.has(sound):
		return
	var p := _players3d[_i3]
	_i3 = (_i3 + 1) % _players3d.size()
	p.stream = streams[sound]
	p.volume_db = vol_db + float(GAIN_DB.get(sound, 0.0))
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


## drive > 0 soft-clips the shot (tanh): the quieter body of the bang comes up while
## the peak stays under full scale, so it sounds louder without clipping.
## drive 0 keeps the plain hard clip (the sniper's original sound).
func _gunshot(rng: RandomNumberGenerator, length: float, brightness: float, thump_hz: float, vol: float, drive := 0.0) -> AudioStreamWAV:
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
		var raw := (lp * 0.8 + thump * 0.7) * env * vol
		s[i] = tanh(raw * drive) if drive > 0.0 else raw
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


## Deep countdown beep: a low tone with its octave, a quick attack and a short decay.
func _beep(hz: float, length: float, vol: float) -> AudioStreamWAV:
	var n := int(length * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := minf(t / 0.006, 1.0) * exp(-t * (5.0 / length))
		s[i] = (sin(TAU * hz * t) * 0.7 + sin(TAU * hz * 2.0 * t) * 0.3) * env * vol
	return _wav(s)


## "GO": a bright two-note stab over a low punch, a little brighter and longer
## than the countdown beeps.
func _go(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var length := 0.55
	var n := int(length * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := minf(t / 0.004, 1.0) * exp(-t * 6.0)
		var stab := sin(TAU * 392.0 * t) * 0.45 + sin(TAU * 587.3 * t) * 0.35 + sin(TAU * 784.0 * t) * 0.2
		var punch := sin(TAU * 70.0 * t * (1.0 - t)) * exp(-t * 18.0)
		var air := rng.randf_range(-1.0, 1.0) * exp(-t * 40.0) * 0.25
		s[i] = tanh((stab * env + punch * 0.9 + air) * 1.4) * 0.8
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


## Sci-fi beam (Swap): a warbling tone that climbs as it charges, with a buzzy
## octave on top, fading in and cutting off at the end.
func _beam(length: float) -> AudioStreamWAV:
	var n := int(length * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		var hz := lerpf(260.0, 980.0, t * t) * (1.0 + 0.06 * sin(TAU * 14.0 * i / RATE))
		phase += TAU * hz / RATE
		var env := minf(1.0, t * 8.0) * minf(1.0, (1.0 - t) * 20.0)
		s[i] = (sin(phase) * 0.6 + signf(sin(phase * 2.0)) * 0.12) * env * 0.45
	return _wav(s)


## A short tune: each note (hz) for its length (s), a bright horn-like tone
## (fundamental, octave and fifth) that rings on a little. buzz adds some edge.
func _notes(hz: Array, lengths: Array, vol: float, buzz: float) -> AudioStreamWAV:
	var total := 0.0
	for l: float in lengths:
		total += l
	var s := PackedFloat32Array()
	s.resize(int((total + 0.15) * RATE))
	var start := 0
	for i in hz.size():
		var n := int((float(lengths[i]) + 0.15) * RATE)
		for j in n:
			if start + j >= s.size():
				break
			var t := float(j) / RATE
			var env := minf(1.0, t * 60.0) * exp(-t * (2.0 if i == hz.size() - 1 else 5.0))
			var ph := TAU * float(hz[i]) * t
			var tone := sin(ph) + 0.35 * sin(ph * 2.0) + 0.2 * sin(ph * 1.5) + buzz * 0.15 * signf(sin(ph))
			s[start + j] += tone * env * vol * 0.6
		start += int(float(lengths[i]) * RATE)
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


# ================================================================ music
# Built-in music, synthesized: kick + clap snare, hats, a side-chained saw bass
# with off-beat octave jumps and a square-wave arpeggio over a 4-chord loop (one
# chord per 2 bars). Rendered on a background thread at startup. There's one
# song, the Tag Rush Theme; more can be added here in the same format.
#   roots: bass note per chord (Hz); minor: chord quality per chord
#   kick / snare: 16th steps in a bar; kick_odd: extra kicks on odd bars
#   hats: 16 (sixteenths) or 8 (eighths); arp_from: bar the arpeggio comes in
#   roll: snare roll on the last bar; break: bars with no drums (breakdown)
const SONGS := [
	{"title": "Tag Rush Theme", "bpm": 160.0, "bars": 8, "roots": [55.0, 43.65, 65.41, 49.0],
		"minor": [true, false, false, false], "kick": [0, 4, 8, 12, 14], "kick_odd": [7],
		"snare": [4, 12], "hats": 16, "arp_from": 2, "roll": true, "break": [], "seed": 160},
]

var _music: AudioStreamPlayer
var _song_streams: Array = []  # AudioStreamWAV per SONGS entry
var _render_thread: Thread
var _music_tween: Tween


signal now_playing(title: String)

const BUILTIN_ID := "__builtin__"  # queue key prefix; song i is BUILTIN_ID + str(i)
const BUILTIN_PLAY_TIME := 60.0  # how long a looping built-in song plays before the next

var current_title := ""
var _current_key := ""  # file path of the playing track, or BUILTIN_ID + index
var _queue: Array = []
var _qi := -1
var _music_active := false
var _builtin_left := -1.0


## Starts match music using the player's music settings (built-in songs, their
## custom playlist, or both; optionally shuffled).
func start_music() -> void:
	_ensure_music_player()
	_music_active = true
	_music.stream_paused = false
	_build_queue()
	_qi = -1
	if _music_tween:
		_music_tween.kill()
	_music.volume_db = -30.0
	_next_track()
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", -4.0, 1.5)


func stop_music() -> void:
	_music_active = false
	_builtin_left = -1.0
	if _music == null or not _music.playing:
		return
	_music.stream_paused = false
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", -40.0, 0.8)
	_music_tween.tween_callback(_music.stop)


# ---------------------------------------------------- player controls (pause menu)

func music_active() -> bool:
	return _music_active


func skip_track() -> void:
	if _music_active:
		_music.stream_paused = false
		_next_track()


func prev_track() -> void:
	if not _music_active or _queue.is_empty():
		return
	_music.stream_paused = false
	for _attempt in _queue.size():
		_qi = posmod(_qi - 1, _queue.size())
		if _start_entry(_queue[_qi]):
			return


func toggle_pause() -> void:
	if _music_active and _music:
		_music.stream_paused = not _music.stream_paused


func is_paused() -> bool:
	return _music != null and _music.stream_paused


func _ensure_music_player() -> void:
	if _music == null:
		_music = AudioStreamPlayer.new()
		_music.bus = "Music"
		add_child(_music)
		_music.finished.connect(_on_music_finished)
		Settings.music_changed.connect(_on_music_settings_changed)


## Playlist edits keep the current song playing if it is still in the new queue;
## otherwise the music restarts with the new settings.
func _on_music_settings_changed() -> void:
	if not _music_active:
		return
	_build_queue()
	var idx := -1
	for i in _queue.size():
		if _entry_key(_queue[i]) == _current_key:
			idx = i
			break
	if idx < 0 or not _music.playing:
		start_music()
		return
	_qi = idx
	if _current_key.begins_with(BUILTIN_ID):
		if _queue.size() == 1:
			_builtin_left = -1.0
		elif _builtin_left < 0.0:
			_builtin_left = BUILTIN_PLAY_TIME


func _entry_key(entry) -> String:
	if entry is String:
		return entry
	return str(entry.get("file", ""))


func _build_queue() -> void:
	var mode := str(Settings.g("music_mode"))
	var tracks: Array = []
	if mode != "builtin":
		for t in Settings.music_tracks():
			if t.get("enabled", true) and FileAccess.file_exists(str(t.get("file", ""))):
				tracks.append(t)
	var builtin := []
	for i in SONGS.size():
		builtin.append(BUILTIN_ID + str(i))
	if mode == "builtin" or (mode == "custom" and tracks.is_empty()):
		_queue = builtin
	else:
		_queue = tracks
		if mode == "both":
			_queue.append_array(builtin)
	if Settings.g("music_shuffle"):
		_queue.shuffle()


func _next_track() -> void:
	if _queue.is_empty():
		return
	for _attempt in _queue.size():
		_qi += 1
		if _qi >= _queue.size():
			_qi = 0
			if Settings.g("music_shuffle") and _queue.size() > 2:
				_queue.shuffle()
		if _start_entry(_queue[_qi]):
			return


## Plays one queue entry. Built-in songs loop, so they move on after
## BUILTIN_PLAY_TIME (unless they're the only thing in the queue).
func _start_entry(entry) -> bool:
	var stream: AudioStream = null
	var key := _entry_key(entry)
	if key.begins_with(BUILTIN_ID):
		var i := int(key.substr(BUILTIN_ID.length()))
		stream = _song_stream(i)
		current_title = str(SONGS[i].title)
		_builtin_left = BUILTIN_PLAY_TIME if _queue.size() > 1 else -1.0
	else:
		stream = MusicLibrary.load_stream(str(entry.file))
		current_title = str(entry.name)
		_builtin_left = -1.0
	if stream == null:
		return false
	_current_key = key
	_music.stream = stream
	_music.play()
	now_playing.emit(current_title)
	return true


func _song_stream(i: int) -> AudioStream:
	if _render_thread:
		_song_streams = _render_thread.wait_to_finish()  # only blocks if a match starts right after launch
		_render_thread = null
	return _song_streams[i] if i >= 0 and i < _song_streams.size() else null


func _render_all_songs() -> Array:
	var out := []
	for song: Dictionary in SONGS:
		out.append(_render_music(song))
	return out


func _on_music_finished() -> void:
	if _music_active:
		_next_track()


# ------------------------------------------------------------ song import

signal import_finished(added: int, errors: Array, mode_switched: bool)

var _import_thread: Thread


func importing() -> bool:
	return _import_thread != null


## Imports songs into the music library on a background thread: ffmpeg conversion
## and WAV re-encoding can take seconds, and on the host a blocked main thread would
## stall the match for everyone. Returns false if an import is already running.
func import_songs(paths: PackedStringArray) -> bool:
	if _import_thread:
		return false
	MusicLibrary.has_ffmpeg()  # cache the ffmpeg check on the main thread
	_import_thread = Thread.new()
	_import_thread.start(_import_worker.bind(paths))
	return true


func _import_worker(paths: PackedStringArray) -> Array:
	var results: Array = []
	for p in paths:
		results.append(MusicLibrary.import_file(p))
	return results


func _finish_import() -> void:
	var results: Array = _import_thread.wait_to_finish()
	_import_thread = null
	var tracks: Array = Settings.music_tracks()
	var added := 0
	var errors: Array = []
	for res: Dictionary in results:
		if res.ok:
			tracks.append(res.track)
			added += 1
		else:
			errors.append(res.error)
	var switched := added > 0 and str(Settings.g("music_mode")) == "builtin"
	if switched:
		Settings.s("music_mode", "custom", false)
	Settings.set_music_tracks(tracks)
	import_finished.emit(added, errors, switched)


func _process(delta: float) -> void:
	if _import_thread and not _import_thread.is_alive():
		_finish_import()
	if _music_active and _builtin_left > 0.0 and not is_paused():
		_builtin_left -= delta
		if _builtin_left <= 0.0:
			_next_track()


## Renders one SONGS entry as a seamless loop. Runs on the render thread, so it
## only touches its own data.
func _render_music(song: Dictionary) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(song.seed)
	var bpm := float(song.bpm)
	var bars := int(song.bars)
	var breaks: Array = song["break"]
	var sixteenth := 60.0 / bpm / 4.0
	var steps := bars * 16
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
		var drums: bool = not (bar in breaks)
		# Kick: the pattern, plus pushes on odd bars
		if drums and (s in song.kick or (bar % 2 == 1 and s in song.kick_odd)):
			_mix(buf, kick, at, 1.0 if s % 4 == 0 else 0.75)
		# Snare/clap, with a roll on the last bar
		if drums and s in song.snare:
			_mix(buf, snare, at, 0.8)
		if song.roll and bar == bars - 1 and s >= 8:
			_mix(buf, snare, at, 0.25 + 0.05 * (s - 8))
		# Hats: open hat on the off-beat "and"; closed 16ths or 8ths in between
		if s % 4 == 2:
			_mix(buf, open_hat, at, 0.32)
		elif int(song.hats) == 16 or s % 2 == 0:
			_mix(buf, hat, at, 0.18 if s % 2 == 0 else 0.26)
	# Bass + arp, one chord per 2 bars
	var roots: Array = song.roots
	var chords := []
	for m: bool in song.minor:
		chords.append([0, 3, 7, 12] if m else [0, 4, 7, 12])
	var arp_from := int(song.arp_from)
	var beat := 60.0 / bpm
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
		if bar in breaks:
			duck = 0.6  # breakdown: no kick to pump against, bass sits back
		var note_t := fmod(t, sixteenth * 2.0)
		var bass := lp * exp(-note_t * 6.0) * duck * 0.55
		# Arp: 16th notes over the chord, two octaves up, enters on bar arp_from + 1
		var arp := 0.0
		if bar >= arp_from:
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
