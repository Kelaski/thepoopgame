class_name Countdown
extends Control
## Round start countdown (assets/ui/countdown.tscn, part of the HUD): a big 3, 2,
## 1 in the middle of the screen during the pre-round, each shrinking and fading
## with a deep beep, then a big "GO!" with a punchier sound and a quick, subtle
## screen pulse the moment the round starts.

const NUMBER_TIME := 0.85  # how long each number takes to shrink and fade
const GO_TIME := 0.7       # how long "GO!" stays before it's gone
const PULSE_ALPHA := 0.10

@onready var _label: Label = %CountLabel
@onready var _pulse: ColorRect = %Pulse
var _shown := 0       # the number on screen (0 = none)
var _t := 0.0         # time since it appeared
var _go_t := -1.0     # time since "GO!" appeared (-1 = not showing)
var _was_pre := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.modulate.a = 0.0
	_pulse.color = Color(1, 1, 1, 0)


func _process(delta: float) -> void:
	var pre: bool = Game.phase == Game.Phase.PREROUND
	if pre:
		var n := clampi(int(ceil(Game.phase_time)), 1, 3)
		if n != _shown:
			_shown = n
			_t = 0.0
			_label.text = str(n)
			_label.add_theme_color_override("font_color", Color.WHITE)
			Sfx.play("count", -2.0, 1.0, "UI")
		_t += delta
		var k := clampf(_t / NUMBER_TIME, 0.0, 1.0)
		_set_look(lerpf(1.25, 0.75, k), 1.0 - k * k)
	elif _was_pre and Game.phase == Game.Phase.RUSH:
		# The round just started
		_shown = 0
		_go_t = 0.0
		_label.text = "GO!"
		_label.add_theme_color_override("font_color", Mats.TAG_COLOR)
		Sfx.play("go", 0.0, 1.0, "UI")
	if _go_t >= 0.0:
		_go_t += delta
		var g := clampf(_go_t / GO_TIME, 0.0, 1.0)
		_set_look(lerpf(1.45, 1.0, minf(g * 2.5, 1.0)), 1.0 - g * g)
		_pulse.color.a = PULSE_ALPHA * maxf(0.0, 1.0 - _go_t / 0.25)
		if g >= 1.0:
			_go_t = -1.0
			_pulse.color.a = 0.0
	elif not pre:
		_shown = 0
		_label.modulate.a = 0.0
	_was_pre = pre


func _set_look(s: float, alpha: float) -> void:
	_label.pivot_offset = _label.size * 0.5
	_label.scale = Vector2(s, s)
	_label.modulate.a = clampf(alpha, 0.0, 1.0)
