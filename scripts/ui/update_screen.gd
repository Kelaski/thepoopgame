class_name UpdateScreen
extends Control
## Start-up update check (assets/ui/update_screen.tscn). In exported builds it asks
## GitHub for the newest release; if it's newer than this build it downloads the
## zip for this platform, checks its SHA-256 against the one GitHub publishes,
## unpacks it, and hands over to a small script that waits for the game to close,
## copies the new files over the old ones and starts the new version.
## Any failure just carries on to the main menu. The editor and debug builds skip it.

signal finished  # carry on to the main menu

const REPO := "Kelaski/thepoopgame"
const API := "https://api.github.com/repos/%s/releases/latest" % REPO
const DIR := "user://update"

var _http: HTTPRequest
var _release_url := ""
var _digest := ""   # "sha256:<hex>" from GitHub, if it gives one
var _zip := ""
# For trying a full install by hand: pretend to be this version, install here, don't relaunch.
var local_version := GameVersion.CURRENT
var install_dir := ""   # "" = the folder the game runs from
var relaunch := true


static func applies() -> bool:
	return OS.has_feature("template") and not OS.is_debug_build() and DisplayServer.get_name() != "headless" \
		and OS.get_name() in ["Windows", "Linux"]


func _ready() -> void:
	%SkipButton.pressed.connect(_done)
	%DownloadButton.pressed.connect(func(): OS.shell_open(_release_url))
	%DownloadButton.visible = false
	%Bar.visible = false
	_http = HTTPRequest.new()
	_http.timeout = 8.0
	add_child(_http)
	_status("Checking for updates...")
	_http.request_completed.connect(_on_release, CONNECT_ONE_SHOT)
	if _http.request(API, ["User-Agent: TagRush-Updater", "Accept: application/vnd.github+json"]) != OK:
		_done()


func _process(_delta: float) -> void:
	if %Bar.visible and _http.get_body_size() > 0:
		%Bar.value = 100.0 * _http.get_downloaded_bytes() / _http.get_body_size()


func _status(t: String) -> void:
	%Status.text = t


func _done() -> void:
	set_process(false)
	if _http:
		_http.cancel_request()
	finished.emit()


## "0.20.0a" -> [0, 20, 0]
static func parse_version(v: String) -> Array:
	var out := []
	for part in v.strip_edges().split("."):
		var digits := ""
		for ch in part:
			if ch >= "0" and ch <= "9":
				digits += ch
			else:
				break
		out.append(int(digits) if digits != "" else 0)
	while out.size() < 3:
		out.append(0)
	return out


static func is_newer(remote: String, local: String) -> bool:
	var a := parse_version(remote)
	var b := parse_version(local)
	for i in 3:
		if a[i] != b[i]:
			return a[i] > b[i]
	return false


## The release file for this platform: the Linux zip on Linux, the other zip on Windows.
static func pick_asset(assets: Array, os_name: String) -> Dictionary:
	for a: Dictionary in assets:
		var n := str(a.get("name", "")).to_lower()
		if n.ends_with(".zip") and (("linux" in n) == (os_name == "Linux")):
			return a
	return {}


func _on_release(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_done()
		return
	var rel = JSON.parse_string(body.get_string_from_utf8())
	if not rel is Dictionary or not is_newer(str(rel.get("tag_name", "")), local_version):
		_done()
		return
	var version := ".".join(parse_version(str(rel.tag_name)).map(func(x): return str(x)))
	_release_url = str(rel.get("html_url", "https://github.com/%s/releases/latest" % REPO))
	var asset := pick_asset(rel.get("assets", []), OS.get_name())
	var url := str(asset.get("browser_download_url", ""))
	if not url.begins_with("https://github.com/%s/releases/download/" % REPO):
		_offer("Version %s is out, but there's no download for this computer." % version)
		return
	if not _game_dir_writable():
		_offer("Version %s is out. The game folder can't be written to, so download it yourself:" % version)
		return
	_digest = str(asset.get("digest", ""))
	DirAccess.make_dir_recursive_absolute(DIR)
	_zip = ProjectSettings.globalize_path(DIR + "/download.zip")
	_status("Downloading version %s..." % version)
	%Bar.visible = true
	%Bar.value = 0.0
	_http.timeout = 0.0  # big file: no overall timeout
	_http.download_file = _zip
	_http.request_completed.connect(_on_download.bind(version), CONNECT_ONE_SHOT)
	if _http.request(url, ["User-Agent: TagRush-Updater"]) != OK:
		_offer("Couldn't download version %s." % version)


## No automatic update possible: say so, with a link to the release page.
func _offer(text: String) -> void:
	_status(text)
	%Bar.visible = false
	%DownloadButton.visible = true
	%SkipButton.text = "Continue"


func _game_dir() -> String:
	return install_dir if install_dir != "" else OS.get_executable_path().get_base_dir()


func _game_dir_writable() -> bool:
	var probe := _game_dir().path_join(".update_check")
	var f := FileAccess.open(probe, FileAccess.WRITE)
	if f == null:
		return false
	f.close()
	DirAccess.remove_absolute(probe)
	return true


func _on_download(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray, version: String) -> void:
	_http.download_file = ""
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_offer("Couldn't download version %s." % version)
		return
	_status("Checking the download...")
	if _digest.begins_with("sha256:") and _sha256(_zip) != _digest.substr(7).to_lower():
		DirAccess.remove_absolute(_zip)
		_offer("The download for version %s was damaged." % version)
		return
	var new_dir := ProjectSettings.globalize_path(DIR + "/new")
	var exe := _unzip(_zip, new_dir)
	DirAccess.remove_absolute(_zip)
	if exe == "":
		_offer("The download for version %s didn't contain the game." % version)
		return
	_status("Installing version %s..." % version)
	if not _launch_installer(new_dir, exe):
		_offer("Couldn't install version %s." % version)
		return
	get_tree().quit()


static func _sha256(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	while f.get_position() < f.get_length():
		h.update(f.get_buffer(1 << 20))
	return h.finish().hex_encode()


## Unpacks the release into dir (emptied first). Returns the game executable's
## file name, or "" if it isn't there. Paths that would leave dir are refused.
static func _unzip(zip_path: String, dir: String) -> String:
	_remove_tree(dir)
	DirAccess.make_dir_recursive_absolute(dir)
	var z := ZIPReader.new()
	if z.open(zip_path) != OK:
		return ""
	var exe := ""
	for entry in z.get_files():
		if entry.ends_with("/") or ".." in entry or entry.begins_with("/") or ":" in entry:
			continue
		var out := dir.path_join(entry)
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		var f := FileAccess.open(out, FileAccess.WRITE)
		if f == null:
			z.close()
			return ""
		f.store_buffer(z.read_file(entry))
		f.close()
		if "/" not in entry and (entry.ends_with(".exe") or entry.ends_with(".x86_64")):
			exe = entry
	z.close()
	return exe


static func _remove_tree(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)
	for sub in d.get_directories():
		_remove_tree(dir.path_join(sub))
	DirAccess.remove_absolute(dir)


## Writes and starts the script that swaps the files once this process exits.
func _launch_installer(new_dir: String, exe: String) -> bool:
	var game_dir := _game_dir()
	var old_exe := OS.get_executable_path() if install_dir == "" else game_dir.path_join("old.exe")
	var pid := OS.get_process_id()
	if OS.get_name() == "Windows":
		var w := func(p: String) -> String: return p.replace("/", "\\").replace("%", "%%")
		var s := "@echo off\r\n"
		s += ":wait\r\ntasklist /FI \"PID eq %d\" 2>nul | find \"%d\" >nul && (timeout /t 1 /nobreak >nul & goto wait)\r\n" % [pid, pid]
		s += "xcopy \"%s\\*\" \"%s\\\" /E /Y /Q /I >nul\r\n" % [w.call(new_dir), w.call(game_dir)]
		if old_exe.get_file() != exe:
			s += "del \"%s\"\r\n" % w.call(old_exe)
		s += "rmdir /S /Q \"%s\"\r\n" % w.call(new_dir)
		if relaunch:
			s += "start \"\" \"%s\"\r\n" % w.call(game_dir.path_join(exe))
		var path := ProjectSettings.globalize_path(DIR + "/install.cmd")
		if not _write(path, s):
			return false
		var ps := "Start-Process -FilePath '%s' -WindowStyle Hidden" % path.replace("/", "\\").replace("'", "''")
		return OS.create_process("powershell.exe", ["-NoProfile", "-WindowStyle", "Hidden", "-Command", ps]) > 0
	var q := func(p: String) -> String: return "'" + p.replace("'", "'\\''") + "'"
	var sh := "#!/bin/sh\n"
	sh += "while kill -0 %d 2>/dev/null; do sleep 0.3; done\n" % pid
	sh += "cp -rf %s/. %s/\n" % [q.call(new_dir), q.call(game_dir)]
	sh += "chmod +x %s\n" % q.call(game_dir.path_join(exe))
	if old_exe.get_file() != exe:
		sh += "rm -f %s\n" % q.call(old_exe)
	sh += "rm -rf %s\n" % q.call(new_dir)
	if relaunch:
		sh += "cd %s && exec %s\n" % [q.call(game_dir), q.call("./" + exe)]
	var path := ProjectSettings.globalize_path(DIR + "/install.sh")
	if not _write(path, sh):
		return false
	return OS.create_process("/bin/sh", [path]) > 0


static func _write(path: String, text: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	return true
