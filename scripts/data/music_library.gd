class_name MusicLibrary
## Custom music: importing files into user://music and loading them at runtime.
##
## * OGG Vorbis, MP3 and WAV load natively.
## * WAV files that aren't 16-bit PCM (24/32-bit, float) are converted on import.
## * FLAC, M4A/AAC, Opus, WMA, AIFF, WebM/MKA, ALAC, etc. are converted to OGG on
##   import with ffmpeg (https://ffmpeg.org) if it is installed and on the PATH.
## Imported copies live in user://music, so the playlist keeps working even if
## the originals are moved or deleted.

const DIR := "user://music"
const NATIVE := ["ogg", "mp3", "wav"]
const CONVERTIBLE := ["flac", "m4a", "aac", "opus", "wma", "aiff", "aif", "aifc", "webm", "mka", "alac", "oga", "mp2", "ac3", "caf", "wv", "ape", "mp4"]

static var _ffmpeg_checked := false
static var _ffmpeg_ok := false


static func file_filters() -> PackedStringArray:
	var exts: Array = NATIVE + CONVERTIBLE
	var pats := PackedStringArray()
	for e in exts:
		pats.append("*." + e)
	return PackedStringArray([", ".join(pats) + " ; Audio files"])


static func has_ffmpeg() -> bool:
	if not _ffmpeg_checked:
		_ffmpeg_checked = true
		var out := []
		_ffmpeg_ok = OS.execute("ffmpeg", ["-version"], out, true) == 0
	return _ffmpeg_ok


static func folder_path() -> String:
	DirAccess.make_dir_recursive_absolute(DIR)
	return ProjectSettings.globalize_path(DIR)


## Copies / converts a file into the library. Returns {ok, error, track}.
static func import_file(src: String) -> Dictionary:
	folder_path()
	var ext := src.get_extension().to_lower()
	var title := src.get_file().get_basename()
	if not FileAccess.file_exists(src):
		return {"ok": false, "error": "File not found: %s" % src}
	var base := _unique_name(title.validate_filename())
	var dest := ""
	if ext == "ogg" or ext == "mp3":
		dest = "%s/%s.%s" % [DIR, base, ext]
		if DirAccess.copy_absolute(src, ProjectSettings.globalize_path(dest)) != OK:
			return {"ok": false, "error": "Could not copy %s" % src.get_file()}
	elif ext == "wav":
		dest = "%s/%s.wav" % [DIR, base]
		var res := _import_wav(src, dest)
		if not res.ok:
			if has_ffmpeg():
				dest = "%s/%s.ogg" % [DIR, base]
				if not _ffmpeg_convert(src, dest):
					return {"ok": false, "error": "ffmpeg could not convert %s" % src.get_file()}
			else:
				return res
	elif ext in CONVERTIBLE or not (ext in NATIVE):
		if not has_ffmpeg():
			return {"ok": false, "error": "%s needs ffmpeg to import. Install ffmpeg (ffmpeg.org) and make sure it is on your PATH, or convert the file to OGG/MP3/WAV." % ext.to_upper()}
		dest = "%s/%s.ogg" % [DIR, base]
		if not _ffmpeg_convert(src, dest):
			return {"ok": false, "error": "ffmpeg could not convert %s" % src.get_file()}
	var stream := load_stream(dest)
	if stream == null or stream.get_length() <= 0.0:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dest))
		return {"ok": false, "error": "%s could not be read as audio." % src.get_file()}
	return {"ok": true, "error": "", "track": {"name": title, "file": dest, "enabled": true}}


static func remove_file(file: String) -> void:
	if file.begins_with(DIR):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(file))


static func load_stream(file: String) -> AudioStream:
	if not FileAccess.file_exists(file):
		return null
	match file.get_extension().to_lower():
		"ogg":
			var o := AudioStreamOggVorbis.load_from_file(file)
			if o:
				o.loop = false
			return o
		"mp3":
			var m := AudioStreamMP3.new()
			m.data = FileAccess.get_file_as_bytes(file)
			m.loop = false
			return m
		"wav":
			return _load_wav16(file)
	return null


static func _unique_name(base: String) -> String:
	if base == "":
		base = "track"
	var name := base
	var i := 2
	while FileAccess.file_exists("%s/%s.ogg" % [DIR, name]) or FileAccess.file_exists("%s/%s.mp3" % [DIR, name]) or FileAccess.file_exists("%s/%s.wav" % [DIR, name]):
		name = "%s (%d)" % [base, i]
		i += 1
	return name


static func _ffmpeg_convert(src: String, dest: String) -> bool:
	var out := []
	var args := ["-y", "-loglevel", "error", "-i", src, "-vn", "-c:a", "libvorbis", "-q:a", "6", ProjectSettings.globalize_path(dest)]
	return OS.execute("ffmpeg", args, out, true) == 0 and FileAccess.file_exists(dest)


# ------------------------------------------------------------------ WAV

## Reads a WAV and stores it in the library as 16-bit PCM (converting 8/24/32-bit
## integer and 32/64-bit float data). Returns {ok, error}.
static func _import_wav(src: String, dest: String) -> Dictionary:
	var info := _parse_wav(FileAccess.get_file_as_bytes(src))
	if not info.ok:
		return info
	if int(info.channels) < 1 or int(info.channels) > 2:
		return {"ok": false, "error": "Only mono or stereo WAV files can be imported without ffmpeg."}
	var pcm16: PackedByteArray
	var bits: int = info.bits
	var fmt: int = info.format
	var data: PackedByteArray = info.data
	var supported := (fmt == 1 and bits in [8, 16, 24, 32]) or (fmt == 3 and bits in [32, 64])
	if not supported:
		return {"ok": false, "error": "Unsupported WAV encoding (format %d, %d-bit)." % [fmt, bits]}
	if fmt == 1 and bits == 16:
		pcm16 = data
	else:
		var bytes_per := bits / 8
		var count := data.size() / bytes_per
		pcm16 = PackedByteArray()
		pcm16.resize(count * 2)
		for i in count:
			var o := i * bytes_per
			var v := 0.0
			if fmt == 3 and bits == 32:
				v = data.decode_float(o)
			elif fmt == 3 and bits == 64:
				v = data.decode_double(o)
			elif fmt == 1 and bits == 8:
				v = (data[o] - 128) / 128.0
			elif fmt == 1 and bits == 24:
				var x := data[o] | (data[o + 1] << 8) | (data[o + 2] << 16)
				if x & 0x800000:
					x -= 0x1000000
				v = x / 8388608.0
			elif fmt == 1 and bits == 32:
				v = data.decode_s32(o) / 2147483648.0
			else:
				return {"ok": false, "error": "Unsupported WAV encoding (format %d, %d-bit)." % [fmt, bits]}
			pcm16.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var f := FileAccess.open(dest, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "error": "Could not write %s" % dest}
	var ch: int = info.channels
	var rate: int = info.rate
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + pcm16.size())
	f.store_buffer("WAVEfmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(1)
	f.store_16(ch)
	f.store_32(rate)
	f.store_32(rate * ch * 2)
	f.store_16(ch * 2)
	f.store_16(16)
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(pcm16.size())
	f.store_buffer(pcm16)
	f.close()
	return {"ok": true, "error": ""}


static func _parse_wav(b: PackedByteArray) -> Dictionary:
	if b.size() < 44 or b.slice(0, 4).get_string_from_ascii() != "RIFF" or b.slice(8, 12).get_string_from_ascii() != "WAVE":
		return {"ok": false, "error": "Not a valid WAV file."}
	var pos := 12
	var info := {"ok": false, "error": "WAV file has no audio data."}
	var got_fmt := false
	while pos + 8 <= b.size():
		var id := b.slice(pos, pos + 4).get_string_from_ascii()
		var size := b.decode_u32(pos + 4)
		var body := pos + 8
		if id == "fmt ":
			var fmt := b.decode_u16(body)
			info.channels = b.decode_u16(body + 2)
			info.rate = b.decode_u32(body + 4)
			info.bits = b.decode_u16(body + 14)
			if fmt == 0xFFFE and size >= 26:
				fmt = b.decode_u16(body + 24)  # WAVE_FORMAT_EXTENSIBLE sub-format
			info.format = fmt
			got_fmt = true
		elif id == "data" and got_fmt:
			var end := mini(body + size, b.size())
			info.data = b.slice(body, end)
			info.ok = true
			info.error = ""
			return info
		pos = body + size + (size & 1)
	return info


static func _load_wav16(file: String) -> AudioStreamWAV:
	var info := _parse_wav(FileAccess.get_file_as_bytes(file))
	if not info.ok or info.format != 1 or info.bits != 16:
		return null
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = info.rate
	w.stereo = info.channels == 2
	w.data = info.data
	return w
