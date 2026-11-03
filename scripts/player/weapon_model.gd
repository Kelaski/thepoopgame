class_name WeaponModel
extends Node3D
## A weapon model (assets/models/weapons/*.tscn). The same scene is used for the
## first-person viewmodel and for the gun other players see you holding:
##   * nodes in the "first_person_only" group (the holo sight reticle) are removed
##     from the third-person copy,
##   * Muzzle marks where shots and the muzzle flash come from,
##   * GlintPoint (sniper only) marks where the scope glint shows.

## Where the viewmodel sits while aiming down sights, so the sight lines up with
## the centre of the screen.
@export var ads_offset := Vector3(0.0, -0.135, -0.36)
## Extra rotation (degrees) for the first-person viewmodel (the bat is held at an angle).
@export var viewmodel_rotation := Vector3.ZERO
## Rotation (degrees) while held by other players (the bat rests on the shoulder).
@export var held_rotation := Vector3.ZERO


## Turns this copy into the third-person (held) model.
func make_third_person() -> void:
	for n in _in_group(self, "first_person_only"):
		n.free()
	rotation_degrees = held_rotation


## Turns this copy into the first-person viewmodel: no shadows, and the
## viewmodel angle.
func make_first_person() -> void:
	_no_shadows(self)
	rotation_degrees = viewmodel_rotation


func muzzle() -> Node3D:
	return get_node_or_null("Muzzle")


func glint_point() -> Node3D:
	return get_node_or_null("GlintPoint")


static func _in_group(root: Node, group: String) -> Array:
	var out := []
	for c in root.get_children():
		if c.is_in_group(group):
			out.append(c)
		out.append_array(_in_group(c, group))
	return out


static func _no_shadows(n: Node) -> void:
	for c in n.get_children():
		if c is GeometryInstance3D:
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_no_shadows(c)
