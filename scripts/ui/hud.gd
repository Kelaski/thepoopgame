class_name Hud
extends Control
## In-match HUD (assets/ui/hud.tscn).
##
## Layout rule: every element is pinned to an anchor point on the screen (a corner,
## an edge centre or the centre) with a zero-size rect, and grows away from that
## point as its content needs. Nothing depends on the window resolution or
## aspect ratio, so elements stay centred / in their corners at any size.

const FEED_MAX := 6
const KILL_ROW := preload("res://assets/ui/kill_feed_row.tscn")
const HP_FILL_W := 258.0     # inner width of the health bar
const ADDON_FILL_W := 218.0  # inner width of the addon bar
const HP_SEGMENT := 25.0     # the health bar is marked off every 25 HP
const FEED_TIME := 7.0

var main
var loadout_open := false

# The layout is assets/ui/hud.tscn; these are its nodes.
@onready var _crosshair: Crosshair = %Crosshair
@onready var _minimap: Minimap = %Minimap
@onready var _score_red: Label = %ScoreRed
@onready var _score_blue: Label = %ScoreBlue
@onready var _timer: Label = %Timer
@onready var _clock_fill: ColorRect = %ClockFill  # the bar under the top HUD that empties with the round clock
@onready var _phase: Label = %Phase
@onready var _round: Label = %Round
@onready var _hp_fill: ColorRect = %HpFill
@onready var _hp_label: Label = %HpLabel
@onready var _hp_max: Label = %HpMax
@onready var _hp_ticks: Control = %HpTicks
var _ticks_for := 0.0  # max health the segment marks were laid out for
@onready var _speed: Label = %Speed
@onready var _ammo: Label = %Ammo
@onready var _ammo_max: Label = %AmmoMax
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
@onready var _pre_loadout: PanelContainer = %PreLoadout   # loadout picker during the countdown
@onready var _loadout_hint: Label = %LoadoutHint
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
		# Team-tinted ends of the top bar, with a team-coloured edge on the outside
		# (the bottom panels have theirs on the screen-edge side too).
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(Mats.team_color(team).darkened(0.45), 0.85)
		sb.border_color = Mats.team_color(team)
		if team == 0:
			sb.border_width_left = 4
			sb.corner_radius_bottom_left = 3
		else:
			sb.border_width_right = 4
			sb.corner_radius_bottom_right = 3
		sb.content_margin_left = 12
		sb.content_margin_right = 12
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
	if o != loadout_open and Game.in_match:
		Game.set_respawn_hold.rpc_id(1, o)  # no respawning while you pick a loadout
	loadout_open = o
	# Alive in the countdown: the picker sits above the hint; dead: on the death screen.
	var w = Game.world
	var lp = w.local_player() if w else null
	var pre: bool = o and Game.phase == Game.Phase.PREROUND and lp != null and lp.alive
	_loadout_panel.visible = o and not pre
	_pre_loadout.visible = pre
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
	# One row per kill, laid out in assets/ui/kill_feed_row.tscn.
	var pc: PanelContainer = KILL_ROW.instantiate()
	if killer == me or victim == me:
		var mine: StyleBoxFlat = (pc.get_meta("mine_style") as StyleBoxFlat).duplicate()
		mine.border_color = UiKit.ACCENT  # follows the menu accent colour
		pc.add_theme_stylebox_override("panel", mine)
	var killer_l: Label = pc.get_node("Row/Killer")
	killer_l.visible = killer != victim and Net.players.has(killer)
	killer_l.text = Net.name_of(killer)
	killer_l.add_theme_color_override("font_color", Mats.team_color(Net.team_of(killer)).lightened(0.35))
	(pc.get_node("Row/Weapon") as Label).text = "[%s%s]" % [Weapons.display_name(weapon), " HEADSHOT" if head else ""]
	var victim_l: Label = pc.get_node("Row/Victim")
	victim_l.text = Net.name_of(victim)
	victim_l.add_theme_color_override("font_color", Mats.team_color(Net.team_of(victim)).lightened(0.35))
	var runner_l: Label = pc.get_node("Row/Runner")
	runner_l.visible = victim == Game.holder
	runner_l.add_theme_color_override("font_color", Mats.TAG_COLOR)
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
	_round.text = "ROUND %d  ·  FIRST TO %d" % [maxi(Game.round_num, 1), Game.ROUNDS_TO_WIN]
	var phase_txt := ""
	var timer_col := Color.WHITE
	match Game.phase:
		Game.Phase.LOBBY:
			phase_txt = "Waiting for the round to start..."
		Game.Phase.PREROUND:
			phase_txt = "GET READY"
		Game.Phase.RUSH:
			phase_txt = "RUSH TO THE TAG!"
		Game.Phase.HELD:
			timer_col = Mats.team_color(Game.holding_team).lightened(0.4)
			if Game.holder == me:
				phase_txt = "DEFEND YOURSELF"
			else:
				phase_txt = "DEFEND YOUR RUNNER" if Game.holding_team == my_team else "HUNT THE RUNNER"
		Game.Phase.DROPPED:
			if Game.is_overtime():
				timer_col = Mats.TAG_COLOR
				phase_txt = "OVERTIME - FIRST TO GRAB THE TAG WINS THE ROUND!"
			else:
				timer_col = Color(0.75, 0.75, 0.75)
				phase_txt = "TAG DROPPED - GRAB IT!  (enemy +%ds / team +%ds)" % [int(Game.ENEMY_PICKUP_BONUS), int(Game.TEAM_PICKUP_BONUS)]
		Game.Phase.ROUND_END:
			phase_txt = "Next round in %d" % int(ceil(Game.phase_time))
		Game.Phase.MATCH_END:
			var winner: int = Game.match_winner if Game.match_winner >= 0 else (0 if Game.scores[0] > Game.scores[1] else 1)
			phase_txt = "%s TEAM WINS! Returning to lobby in %d" % [Mats.team_name(winner).to_upper(), int(ceil(Game.phase_time))]
	_phase.text = phase_txt
	_timer.text = "OVERTIME" if Game.is_overtime() else UiKit.format_time(Game.timer)
	_timer.add_theme_color_override("font_color", timer_col)
	# The bar along the bottom of the top HUD is a second clock: it empties as the
	# round timer runs down (full until the Tag is first picked up).
	var track := _clock_fill.get_parent() as Control
	var frac := 1.0
	if Game.phase in [Game.Phase.HELD, Game.Phase.DROPPED]:
		frac = clampf(Game.timer / Game.ROUND_TIME, 0.0, 1.0)
	_clock_fill.size = Vector2(track.size.x * frac, track.size.y)
	_clock_fill.position.x = (track.size.x - _clock_fill.size.x) * 0.5  # shrinks in from both ends
	_clock_fill.color = Mats.TAG_COLOR if Game.is_overtime() else (timer_col if Game.phase == Game.Phase.HELD else Color(0.95, 0.95, 0.95, 0.95))
	if Game.holder != 0:
		_runner_label.text = "" if Game.holder == me else "Runner: %s" % Net.name_of(Game.holder)
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

	# Countdown: B opens the loadout picker; it closes by itself when the round starts.
	var pre_round: bool = Game.phase == Game.Phase.PREROUND and lp != null and lp.alive
	_loadout_hint.visible = pre_round and not loadout_open
	_loadout_hint.text = "Press %s to change loadout" % Settings.bind_text("loadout").to_upper()
	if pre_round and not loadout_open and Input.is_action_just_pressed("loadout") and main and main.overlay == null and not Game.typing:
		set_loadout_open(true)
	elif _pre_loadout.visible and not pre_round:
		set_loadout_open(false)

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
	_hp_max.text = "/ %d  HP" % int(max_hp)
	_hp_fill.size.x = HP_FILL_W * clampf(hp / max_hp, 0.0, 1.0)
	if max_hp != _ticks_for:
		_layout_hp_ticks(max_hp)
	_hp_fill.color = Color("7ad16a").lerp(Color("e0503a"), clampf(1.0 - hp / max_hp, 0.0, 1.0))
	var low := clampf((45.0 - hp) / 45.0, 0.0, 1.0) if alive else 0.0
	_vignette.color.a = maxf(lp.damage_flash * 0.28, low * (0.12 + 0.06 * sin(Time.get_ticks_msec() * 0.008)))
	# Speedometer: how fast you're moving across the ground
	_speed.visible = Settings.g("show_speed") and alive
	if _speed.visible:
		_speed.text = "%.1f M/S" % Vector2(lp.velocity.x, lp.velocity.z).length()

	# Weapon
	var wd: Dictionary = Weapons.DATA[lp.weapon]
	_weapon.text = String(wd.name).to_upper()
	if lp.weapon == "bat":
		_ammo.text = "-"
		_ammo_max.text = "MELEE"
	else:
		_ammo.text = str(lp.ammo)
		_ammo_max.text = "RELOADING  %.1fs" % lp.reloading if lp.reloading > 0.0 else "/ %d" % wd.mag
	# Running low: the count turns red
	_ammo.modulate = Color(1, 0.55, 0.45) if lp.weapon != "bat" and lp.ammo <= maxi(1, int(wd.mag) / 4) else Color.WHITE
	var st: Array = lp.addon_status()
	_addon_name.text = Addons.display_name(lp.addon).to_upper()
	_addon_text.text = st[0]
	_addon_fill.size.x = ADDON_FILL_W * clampf(st[1], 0.0, 1.0)
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
		var period: float = lp.shot_interval()
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
			_death_timer.text = "Respawning in %.1f" % left
		elif loadout_open:
			_death_timer.text = "Close the loadout to respawn"
		else:
			_death_timer.text = "Respawning..."
		_death_hint.text = "Press %s to change your weapon / addon (you respawn when you close it)" % Settings.bind_text("loadout") if not loadout_open else "Changes apply when you respawn. Esc to close and respawn."
		if Input.is_action_just_pressed("loadout") and not loadout_open and main and main.overlay == null and not Game.typing:
			set_loadout_open(true)
	if alive and not _was_alive:
		_killer_id = 0
		if loadout_open:
			set_loadout_open(false)
	_was_alive = alive


## Marks across the health bar every HP_SEGMENT, so it reads at a glance.
func _layout_hp_ticks(max_hp: float) -> void:
	_ticks_for = max_hp
	for c in _hp_ticks.get_children():
		c.queue_free()
	var n := int(ceil(max_hp / HP_SEGMENT))
	for i in range(1, n):
		var tick := ColorRect.new()
		tick.color = Color(0, 0, 0, 0.7)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tick.position = Vector2(HP_FILL_W * i * HP_SEGMENT / max_hp, 0)
		tick.size = Vector2(2, 10)
		_hp_ticks.add_child(tick)


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
