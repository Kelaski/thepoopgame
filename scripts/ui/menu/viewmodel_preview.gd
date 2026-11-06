class_name ViewmodelPreview
extends Control
## Live preview for the view model settings: the real gun in a small world of its own, under the
## same sun as a day round, so it works from the main menu as well as in a match.

var _model: WeaponModel


func _ready() -> void:
	var day: TimeOfDay = SkyEnv.TIMES[0]
	var env: Environment = %WorldEnvironment.environment
	env.background_color = day.sky_top.lerp(day.sky_horizon, 0.5)
	env.ambient_light_color = day.ambient_color
	env.ambient_light_energy = day.ambient_energy
	%Sun.light_color = day.sun_color
	%Sun.light_energy = day.sun_energy
	%Sun.rotation_degrees = Vector3(day.sun_pitch_deg, day.sun_yaw_deg, 0)
	%Ground.material_override = MapMats.get_mat("pavement")
	Settings.changed.connect(_refresh)
	show_weapon(Weapons.ORDER[0])


func show_weapon(weapon_id: String) -> void:
	if _model:
		_model.queue_free()
	_model = Player.WEAPON_SCENES[weapon_id].instantiate()
	%Holder.add_child(_model)
	_model.make_first_person()
	_refresh()


func _refresh() -> void:
	%Camera.fov = float(Settings.g("fov"))
	%Holder.position = Player.VM_HIP + Settings.viewmodel_offset()
