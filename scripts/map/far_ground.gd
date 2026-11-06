extends MeshInstance3D
## Grass to the horizon, in the level's shared grass material.


func _ready() -> void:
	material_override = MapMats.get_mat("grass_far")
