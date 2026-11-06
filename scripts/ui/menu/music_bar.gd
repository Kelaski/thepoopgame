class_name MusicBar
extends PanelContainer
## Music controls (assets/ui/music_bar.tscn), on the main menu and in the pause menu:
## what's playing, previous, play or pause, next and volume. The music itself is Sfx's.


func _ready() -> void:
	%Previous.pressed.connect(Sfx.prev_track)
	%Next.pressed.connect(Sfx.skip_track)
	%Play.pressed.connect(Sfx.toggle_pause)
	%Volume.set_value_no_signal(float(Settings.g("music_volume")))
	%Volume.value_changed.connect(func(v: float) -> void: Settings.s("music_volume", v))


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		%Title.text = Sfx.current_title if Sfx.music_active() else "No music playing"
		%Play.text = "Play" if Sfx.is_paused() else "Pause"
