class_name TimeOfDay extends Resource
## One lighting preset. The pre-round countdown blends to one of these.

@export var display_name := "Day"
@export var sun_color := Color.WHITE
@export var sun_energy := 1.2
@export var sun_pitch_deg := -55.0
@export var sun_yaw_deg := 40.0
@export var sky_top := Color(0.25, 0.48, 0.85)
@export var sky_horizon := Color(0.72, 0.82, 0.92)
@export var ground_color := Color(0.3, 0.3, 0.3)
@export var ambient_color := Color(0.7, 0.75, 0.85)
@export var ambient_energy := 0.6
@export var fog_color := Color(0.75, 0.82, 0.9)
@export var fog_density := 0.0012
## 0 = city windows and lamps off, 1 = fully on.
@export_range(0.0, 1.0) var night := 0.0
