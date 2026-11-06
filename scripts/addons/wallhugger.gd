class_name WallhuggerAddon
extends Addon

## Extra wall jumps before the extra gravity starts.
@export var extra_jumps := 2


func describe() -> String:
	return "%d more wall jumps before gravity pulls harder." % extra_jumps


func extra_wall_jumps() -> int:
	return extra_jumps
