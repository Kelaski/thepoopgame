class_name SkyEnv extends Node3D
## Sun, sky, fog and ambient light. Blends between TimeOfDay presets for the pre-round sequence.

const TIMES: Array[TimeOfDay] = [
	preload("res://assets/tuning/times/day.tres"), preload("res://assets/tuning/times/afternoon.tres"),
	preload("res://assets/tuning/times/evening.tres"), preload("res://assets/tuning/times/night.tres"),
]
## Shadow quality (Settings > Video): [splits, max distance in m, shadow map size].
const SHADOW_QUALITY := [
	[2, 70.0, 2048],    # Low
	[4, 130.0, 4096],   # Medium
	[4, 220.0, 4096],   # High
	[4, 320.0, 8192],   # Ultra
]

var current_index := 0

@onready var _env_node: WorldEnvironment = $WorldEnvironment
@onready var _sun: DirectionalLight3D = $Sun
@onready var _outline: MeshInstance3D = $Outline

var _env: Environment
var _sky_mat: ProceduralSkyMaterial
var _from: TimeOfDay
var _to: TimeOfDay
var _t := 1.0
var _length := 0.0
var _night := 0.0


func _ready() -> void:
	_env = _env_node.environment
	_sky_mat = _env.sky.sky_material
	_from = TIMES[0]
	_to = _from
	_apply(1.0)
	Settings.changed.connect(_apply_settings)
	_apply_settings()


## Blend to a preset over this many seconds (0 = instantly).
func blend_to(index: int, seconds: float) -> void:
	current_index = index
	_from = _snapshot()
	_to = TIMES[index]
	_length = seconds
	_t = 0.0 if seconds > 0.0 else 1.0
	_apply(_t)


func _process(delta: float) -> void:
	if _t < 1.0:
		_t = minf(_t + delta / _length, 1.0)
		_apply(smoothstep(0.0, 1.0, _t))


func _snapshot() -> TimeOfDay:
	var s := TimeOfDay.new()
	s.sun_color = _sun.light_color
	s.sun_energy = _sun.light_energy
	s.sun_pitch_deg = rad_to_deg(_sun.rotation.x)
	s.sun_yaw_deg = rad_to_deg(_sun.rotation.y)
	s.sky_top = _sky_mat.sky_top_color
	s.sky_horizon = _sky_mat.sky_horizon_color
	s.ground_color = _sky_mat.ground_bottom_color
	s.ambient_color = _env.ambient_light_color
	s.ambient_energy = _env.ambient_light_energy
	s.fog_color = _env.fog_light_color
	s.fog_density = _env.fog_density
	s.night = _night
	return s


func _apply(t: float) -> void:
	_sun.light_color = _from.sun_color.lerp(_to.sun_color, t)
	_sun.light_energy = lerpf(_from.sun_energy, _to.sun_energy, t)
	_sun.rotation = Vector3(deg_to_rad(lerpf(_from.sun_pitch_deg, _to.sun_pitch_deg, t)), deg_to_rad(lerpf(_from.sun_yaw_deg, _to.sun_yaw_deg, t)), 0)
	_sky_mat.sky_top_color = _from.sky_top.lerp(_to.sky_top, t)
	_sky_mat.sky_horizon_color = _from.sky_horizon.lerp(_to.sky_horizon, t)
	_sky_mat.ground_horizon_color = _sky_mat.sky_horizon_color
	_sky_mat.ground_bottom_color = _from.ground_color.lerp(_to.ground_color, t)
	_env.ambient_light_color = _from.ambient_color.lerp(_to.ambient_color, t)
	_env.ambient_light_energy = lerpf(_from.ambient_energy, _to.ambient_energy, t)
	_env.fog_light_color = _from.fog_color.lerp(_to.fog_color, t)
	_env.fog_density = lerpf(_from.fog_density, _to.fog_density, t)
	_night = lerpf(_from.night, _to.night, t)
	MapMats.set_night(_night)
	for light in get_tree().get_nodes_in_group("street_lights"):
		light.visible = _night > 0.3
	for skyline in get_tree().get_nodes_in_group("skyline"):
		(skyline.multimesh.mesh.material as ShaderMaterial).set_shader_parameter("night", _night)


func _apply_settings() -> void:
	_env.adjustment_brightness = float(Settings.g("brightness"))
	_env.ssao_enabled = bool(Settings.g("ssao"))
	_env.glow_enabled = bool(Settings.g("bloom"))
	_outline.visible = bool(Settings.g("outlines"))
	_sun.shadow_enabled = bool(Settings.g("shadows"))
	var sq: Array = SHADOW_QUALITY[clampi(int(Settings.g("shadow_quality")), 0, SHADOW_QUALITY.size() - 1)]
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if sq[0] == 4 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_sun.directional_shadow_max_distance = sq[1]
	RenderingServer.directional_shadow_atlas_set_size(sq[2], true)
