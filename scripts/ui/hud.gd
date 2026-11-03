class_name Hud
extends Control
## In-match HUD (assets/ui/hud.tscn).
##
## Layout rule: every element is pinned to an anchor point on the screen (a corner,
## an edge centre or the centre) with a zero-size rect, and grows away from that
## point as its content needs. Nothing depends on the window resolution or
## aspect ratio, so elements stay centred / in their corners at any size.

const FEED_MAX := 6
const FEED_TIME := 7.0

var main
var loadout_open := false

# The layout is assets/ui/hud.tscn; these are its nodes.
@onready var _crosshair: Crosshair = %Crosshair
@onready var _minimap: Minimap = %Minimap
@onready var _score_red: Label = %ScoreRed
@onready var _score_blue: Label = %ScoreBlue
@onready var _timer: Label = %Timer
@onready var _phase: Label = %Phase
@onready var _round: Label = %Round
@onready var _hp_fill: ColorRect = %HpFill
@onready var _hp_label: Label = %HpLabel
@onready var _ammo: Label = %Ammo
@onready var _weapon: Label = %Weapon
@onready var _addon_name: Label = %AddonName
@onready var _addon_fill: ColorRect = %AddonFill
@onready var _addon_text: Label = %AddonText
@onready var _banner: Label = %Banner
var _banner_t := 0.0
@onready var _feed: VBoxContainer = %Feed
@onready var _fps: Label = %Fps
@onready var _status: Label = %Status
@onready var _runner_label: Label = %RunnerLabel
@onready var _vignette: ColorRect = %Vignette
@onready var _tint: ColorRect = %Tint
@onready var _death_dim: ColorRect = %DeathDim
@onready var _death: PanelContainer = %Death
@onready var _death_title: Label = %DeathTitle
@onready var _death_name: Label = %DeathName
@onready var _death_detail: Label = %DeathDetail
@onready var _death_timer: Label = %DeathTimer
@onready var _death_hint: Label = %DeathHint
@onready var _loadout_panel: PanelContainer = %LoadoutHolder
@onready var _scoreboard: PanelContainer = %Scoreboard
@onready var _sb_cols: Array = [%ScoreboardRed, %ScoreboardBlue]
var _sb_acc := 0.0
var _was_alive := true

@onready var _np: Label = %NowPlaying
var _np_t := 0.0
var _killer_id := 0
var _killer_weapon := ""
var _killer_head := false
var _killer_hp := -1.0


func _ready() -> void:
	# Team colours on the score boxes and the Tag colour on the runner label.
	for team in 2:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Mats.team_color(team)
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(8)
		(%ScoreBoxRed if team == 0 else %ScoreBoxBlue).add_theme_stylebox_override("panel", sb)
	_runner_label.add_theme_color_override("font_color", Mats.TAG_COLOR)
	_np.modulate.a = 0.0
	Sfx.now_playing.connect(_on_now_playing)
	if Sfx.current_title != "":
		_on_now_playing(Sfx.current_title)
	Game.announce.connect(_on_announce)
	Game.kill_event.connect(_on_kill)
	Game.local_hit.connect(_on_local_hit)

func _ignore_mouse(c: Control) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for ch in c.get_children():
		if ch is Control:
			_ignore_mouse(ch)


func set_loadout_open(o: bool) -> void:
	loadout_open = o
	_loadout_panel.visible = o
	if main:
		main._update_mouse()


# ================================================================ events

func _on_now_playing(title: String) -> void:
	_np.text = "Now playing: %s" % title
	_np_t = 4.0


func _on_announce(text: String, color: Color) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner_t = 3.0


func _on_kill(killer: int, victim: int, weapon: String, head: bool) -> void:
	var me := multiplayer.get_unique_id()
	if victim == me:
		_killer_id = killer
		_killer_weapon = weapon
		_killer_head = head
		_killer_hp = Game.hp.get(killer, -1.0)
	var involved := killer == me or victim == me
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.07, 0.72)
	if involved:
		sb.border_color = UiKit.ACCENT
		sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	pc.add_theme_stylebox_override("panel", sb)
	pc.size_flags_horizontal = Control.SIZE_SHRINK_END
	var row := UiKit.hbox(8)
	pc.add_child(row)
	var kc := Mats.team_color(Net.team_of(killer)).lightened(0.35)
	var vc := Mats.team_color(Net.team_of(victim)).lightened(0.35)
	if killer != victim and Net.players.has(killer):
		row.add_child(UiKit.outlined(Net.name_of(killer), 16, kc))
	var wtxt := "[%s%s]" % [Weapons.display_name(weapon), " HEADSHOT" if head else ""]
	row.add_child(UiKit.outlined(wtxt, 14, Color.WHITE))
	row.add_child(UiKit.outlined(Net.name_of(victim), 16, vc))
	if victim == Game.holder:
		row.add_child(UiKit.outlined("(Runner)", 14, Mats.TAG_COLOR))
	_ignore_mouse(pc)
	pc.set_meta("t", FEED_TIME)
	_feed.add_child(pc)
	while _feed.get_child_count() > FEED_MAX:
		var old := _feed.get_child(0)
		_feed.remove_child(old)
		old.queue_free()


func _on_local_hit(_dmg: float, head: bool, killed: bool) -> void:
	_crosshair.hit(head, killed)
	if Settings.g("hitmarker_sound"):
		if killed:
			Sfx.play("kill", -3.0, 1.0, "UI")
		else:
			Sfx.play("head" if head else "hit", -8.0, randf_range(0.95, 1.05), "UI")


# ================================================================ per-frame

func _process(delta: float) -> void:
	var w = Game.world
	var lp = w.local_player() if w else null
	var me := multiplayer.get_unique_id()
	var my_team: int = Net.team_of(me)

	# Scores, timer, phase
	_score_red.text = str(Game.scores[0])
	_score_blue.text = str(Game.scores[1])
	_round.text = "ROUND %d   -   FIRST TO %d" % [maxi(Game.round_num, 1), Game.ROUNDS_TO_WIN]
	var phase_txt := ""
	var timer_col := Color.WHITE
	match Game.phase:
		Game.Phase.LOBBY:
			phase_txt = "Waiting for the round to start..."
		Game.Phase.PREROUND:
			phase_txt = "Get ready! Round starts in %d" % int(ceil(Game.phase_time))
		Game.Phase.RUSH:
			phase_txt = "RUSH TO THE TAG!"
		Game.Phase.HELD:
			timer_col = Mats.team_color(Game.holding_team).lightened(0.4)
			phase_txt = "DEFEND YOUR RUNNER" if Game.holding_team == my_team else "HUNT THE RUNNER"
		Game.Phase.DROPPED:
			timer_col = Color(0.75, 0.75, 0.75)
			phase_txt = "TAG DROPPED - GRAB IT!  (enemy +%ds / team +%ds)" % [int(Game.ENEMY_PICKUP_BONUS), int(Game.TEAM_PICKUP_BONUS)]
		Game.Phase.ROUND_END:
			phase_txt = "Next round in %d" % int(ceil(Game.phase_time))
		Game.Phase.MATCH_END:
			var winner: int = Game.match_winner if Game.match_winner >= 0 else (0 if Game.scores[0] > Game.scores[1] else 1)
			phase_txt = "%s TEAM WINS! Returning to lobby in %d" % [Mats.team_name(winner).to_upper(), int(ceil(Game.phase_time))]
	_phase.text = phase_txt
	_timer.text = UiKit.format_time(Game.timer)
	_timer.add_theme_color_override("font_color", timer_col)
	if Game.holder != 0:
		_runner_label.text = "YOU ARE THE RUNNER" if Game.holder == me else "Runner: %s" % Net.name_of(Game.holder)
	else:
		_runner_label.text = ""

	# Now-playing toast
	_np_t = maxf(0.0, _np_t - delta)
	_np.modulate.a = clampf(_np_t, 0.0, 1.0)

	# Banner fade
	_banner_t = maxf(0.0, _banner_t - delta)
	_banner.modulate.a = clampf(_banner_t, 0.0, 1.0)

	# Kill feed fade
	for row in _feed.get_children():
		var t: float = row.get_meta("t", 0.0) - delta
		row.set_meta("t", t)
		row.modulate.a = clampf(t, 0.0, 1.0)
		if t <= 0.0:
			row.queue_free()

	_fps.visible = Settings.g("show_fps")
	_fps.text = "%d FPS" % Engine.get_frames_per_second()
	_scoreboard.visible = Input.is_action_pressed("scoreboard") and not Game.ui_open and not Game.typing
	if _scoreboard.visible:
		_sb_acc -= delta
		if _sb_acc <= 0.0:
			_sb_acc = 0.25
			_refresh_scoreboard()
	else:
		_sb_acc = 0.0

	if lp == null:
		return
	var alive: bool = lp.alive
	# Health
	var hp: float = Game.my_hp() if alive else 0.0
	_hp_label.text = str(int(ceil(hp)))
	var max_hp: float = Game.my_max_hp()
	_hp_fill.size.x = 276.0 * clampf(hp / max_hp, 0.0, 1.0)
	_hp_fill.color = Color("7ad16a").lerp(Color("e0503a"), clampf(1.0 - hp / max_hp, 0.0, 1.0))
	var low := clampf((45.0 - hp) / 45.0, 0.0, 1.0) if alive else 0.0
	_vignette.color.a = maxf(lp.damage_flash * 0.28, low * (0.12 + 0.06 * sin(Time.get_ticks_msec() * 0.008)))

	# Weapon
	var wd: Dictionary = Weapons.DATA[lp.weapon]
	_weapon.text = wd.name
	if lp.weapon == "bat":
		_ammo.text = "MELEE"
	elif lp.reloading > 0.0:
		_ammo.text = "RELOADING"
	else:
		_ammo.text = "%d / %d" % [lp.ammo, wd.mag]
	var st: Array = lp.addon_status()
	_addon_name.text = Addons.display_name(lp.addon)
	_addon_text.text = st[0]
	_addon_fill.size.x = 302.0 * clampf(st[1], 0.0, 1.0)
	match st[2]:
		"active":
			_addon_fill.color = Color("49d6e0")
		"cooldown":
			_addon_fill.color = Color("5a5f6a")
		"passive":
			_addon_fill.color = Color("6a8a5a") if st[1] > 0.5 else Color("5a5f6a")
		_:
			_addon_fill.color = Color("e0b13c")

	# Crosshair mode
	if not alive or Game.ui_open:
		_crosshair.mode = "none"
	elif lp.weapon == "bat":
		_crosshair.mode = "bat"
	elif lp.weapon == "sniper" and lp.ads_t > 0.85:
		_crosshair.mode = "scope"
	elif lp.ads_t > 0.6:
		# The AR and SMG holo sights provide their own reticle.
		_crosshair.mode = "none" if lp.weapon in ["ar", "smg"] else "dot"
	else:
		_crosshair.mode = "normal"
		var spread: float = lerpf(float(wd.hip), float(wd.ads), lp.ads_t) if lp.weapon != "shotgun" else float(wd.cone) * 0.5
		_crosshair.spread = spread
	# Sniper: ring showing when the next shot is ready.
	if alive and lp.weapon == "sniper" and not Game.ui_open:
		var period := 1.0 / float(wd.rps)
		_crosshair.cooldown = clampf(lp.fire_cd / period, 0.0, 1.0)
		if lp.reloading > 0.0:
			_crosshair.cooldown = clampf(lp.reloading / lp.reload_time(), 0.0, 1.0)
	else:
		_crosshair.cooldown = 0.0

	# Status line + screen tint
	var status := ""
	_tint.color = Color(0, 0, 0, 0)
	if alive:
		if lp.prot_left > 0.0:
			status = "SPAWN PROTECTED %.1fs  (ends when you move or shoot)" % lp.prot_left
		if lp.invisible:
			var moving: bool = Vector2(lp.velocity.x, lp.velocity.z).length() > 0.4
			status = "INVISIBLE" + (" (10% visible - crouch-walk to stay hidden)" if moving and not lp.crouching else "")
			_tint.color = Color(0.3, 0.5, 1.0, 0.10)
		elif lp.phasing > 0.0:
			status = "PHASING - run through walls, double-tap %s to drop a floor" % Settings.bind_text("crouch")
			_tint.color = Color(0.6, 0.3, 1.0, 0.12)
	_status.text = status

	# Death screen: who killed you, with what, and when you respawn
	var round_live: bool = Game.phase in [Game.Phase.RUSH, Game.Phase.HELD, Game.Phase.DROPPED]
	var dead_now: bool = not alive and Game.in_match and Game.phase != Game.Phase.LOBBY
	_death.visible = dead_now
	_death_dim.visible = dead_now and round_live
	if dead_now:
		if _killer_id != 0 and _killer_id != me and Net.players.has(_killer_id):
			_death_title.text = "ELIMINATED BY"
			_death_name.text = Net.name_of(_killer_id)
			_death_name.add_theme_color_override("font_color", Mats.team_color(Net.team_of(_killer_id)).lightened(0.35))
			var detail := Weapons.display_name(_killer_weapon)
			if _killer_head:
				detail += "  -  HEADSHOT"
			if _killer_hp >= 0.0:
				detail += "  -  they had %d HP left" % int(ceil(_killer_hp))
			_death_detail.text = detail
		else:
			_death_title.text = ""
			_death_name.text = "ELIMINATED"
			_death_name.add_theme_color_override("font_color", Color("ff7a6a"))
			_death_detail.text = ""
		var left: float = Game.respawn_left.get(me, 0.0)
		if not round_live:
			_death_timer.text = "Waiting for the next round"
		elif left > 0.0:
			_death_timer.text = "Respawn available in %.1f" % left
		else:
			_death_timer.text = "Press %s to respawn" % Settings.bind_text("jump").to_upper()
			if Input.is_action_just_pressed("jump") and main and main.overlay == null and not Game.typing:
				Game.request_respawn.rpc_id(1)
		_death_hint.text = "Press %s to change your weapon / addon" % Settings.bind_text("loadout") if not loadout_open else "Changes apply when you respawn. Esc to close."
		if Input.is_action_just_pressed("loadout") and not loadout_open and main and main.overlay == null and not Game.typing:
			set_loadout_open(true)
	if alive and not _was_alive:
		_killer_id = 0
		if loadout_open:
			set_loadout_open(false)
	_was_alive = alive


func _refresh_scoreboard() -> void:
	for team in 2:
		var col: VBoxContainer = _sb_cols[team]
		for c in col.get_children():
			c.queue_free()
		col.add_child(UiKit.label("%s  -  %d" % [Mats.team_name(team).to_upper(), Game.scores[team]], 22, Mats.team_color(team).lightened(0.35)))
		col.add_child(UiKit.label("Name                      K / D", 14, UiKit.MUTED))
		for id in Net.players:
			var p: Dictionary = Net.players[id]
			if p.team != team:
				continue
			var mark := "  [TAG]" if id == Game.holder else ""
			var dead := "" if Game.is_alive(id) else "  (dead)"
			col.add_child(UiKit.label("%-24s  %d / %d%s%s" % [p.name, p.kills, p.deaths, mark, dead], 16))
