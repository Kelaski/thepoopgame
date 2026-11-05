extends Label
## "Loading (XXs)" in the bottom-left corner while the host picks the city for a
## new match (assets/ui/loading_label.tscn): XX is how long it may still take.

func _process(_delta: float) -> void:
	var left := Game.loading_left()
	visible = left >= 0.0
	if visible:
		text = "Loading (%ds)" % ceili(left)
