class_name AddonTuning
extends Resource
## Every addon number. Open assets/tuning/addons.tres in Godot and edit the values
## in the Inspector: there's one section per addon. Times are in seconds, distances
## in metres, speeds in m/s. Loadout descriptions update themselves from these.

@export_group("Grapple")
@export var grapple_range := 27.0
## Starts when the hook latches on.
@export var grapple_cd := 6.5
## Cooldown after a throw that hits nothing.
@export var grapple_miss_cd := 1.0
@export var grapple_hook_speed := 110.0
## Reel-in acceleration.
@export var grapple_pull := 42.0
## Air steering on the rope.
@export var grapple_steer := 14.0
## The most speed the grapple can give you.
@export var grapple_max_speed := 22.0
## The rope lets go after this long.
@export var grapple_max_time := 2.5
## Within this distance you pop off the end.
@export var grapple_arrive := 2.0
## Upward speed at the end, to clear ledges.
@export var grapple_end_pop := 6.5
## Speed a hooked enemy is pulled towards you.
@export var grapple_yank := 11.0

@export_group("Warp")
@export var warp_dist := 15.0
@export var warp_cd := 8.0
## How long the afterimage stays where you left.
@export var warp_afterimage_time := 1.0
@export var warp_afterimage_color := Color(0.5, 0.85, 1.0, 0.6)

@export_group("Rocket jump")
## How high your next jump lifts you.
@export var rocket_height := 8.0
@export var rocket_cd := 10.0

@export_group("Hider")
@export var hider_time := 15.0
@export var hider_cd := 12.0
## How visible you are while moving (0.1 = 10% opaque).
@export var hider_moving_opacity := 0.1
## How visible you are standing still, crouching or sliding.
@export var hider_still_opacity := 0.05

@export_group("Phantom")
@export var phantom_time := 3.0
## Starts when the phase ends.
@export var phantom_cd := 10.0
## Damage per second if the phase ends inside something. Doubles every second until you're out.
@export var phantom_stuck_dps := 10.0

@export_group("Bubble")
@export var bubble_time := 4.0
@export var bubble_health := 75.0
## Starts when the bubble ends or breaks.
@export var bubble_cd := 10.0

@export_group("UAV")
@export var uav_pulses := 5
## How fast each pulse's ring grows.
@export var uav_pulse_speed := 9.0
## Time between pulses.
@export var uav_pulse_interval := 1.5
## A pulse stops growing at this radius.
@export var uav_max_radius := 60.0
## How long the last pulse's outlines stay.
@export var uav_last_linger := 1.5
## Starts after the last pulse. Support: runs only while you're alive, and carries on through death.
@export var uav_cd := 25.0

@export_group("Magnet")
@export var magnet_range := 40.0
## How close to your crosshair (degrees) a teammate must be.
@export var magnet_aim_cone := 8.0
## The most time the pull takes.
@export var magnet_pull_time := 0.5
## Where the teammate stops, this far in front of you.
@export var magnet_stop_distance := 1.5
## Support: runs only while you're alive, and carries on through death.
@export var magnet_cd := 15.0

@export_group("Interlink")
## Damage and healing are shared while you're this close.
@export var interlink_range := 25.0
## How far away you can aim at a teammate to link.
@export var interlink_pick_range := 40.0
## How close to your crosshair (degrees) a teammate must be.
@export var interlink_aim_cone := 8.0
## Respawn time for both of you after a shared death.
@export var interlink_respawn_time := 10.0
## Starts whenever the link breaks. Support: runs only while you're alive, and carries on through death.
@export var interlink_cd := 25.0

@export_group("Moonwalker")
## Gravity multiplier.
@export var moon_gravity := 0.7
## Air control multiplier.
@export var moon_air := 1.2

@export_group("Trackstar")
## Move speed multiplier (1.25 = 25% faster).
@export var track_speed := 1.25
## Reload and re-chamber time multiplier (0.65 = 35% faster).
@export var track_reload_mult := 0.65
## The same, for the sniper.
@export var track_sniper_mult := 0.7

@export_group("Double jump")
## Upward speed of the second jump.
@export var doublejump_speed := 7.0

@export_group("Wallhugger")
## Extra wall jumps before the extra gravity starts.
@export var wallhugger_extra_jumps := 2

@export_group("Aerodynamic")
## Multiplier on steering with A and D below running speed.
@export var aero_air_mult := 1.6
## Multiplier on air strafing while turning the camera.
@export var aero_strafe_mult := 1.6

@export_group("Unstoppable")
## Added to the speed cap.
@export var unstoppable_cap_bonus := 10.0

@export_group("Reload on Kill")
## After it refills, the next kill within this long doesn't.
@export var reloader_cd := 3.0

@export_group("Cooldown on Kill")
## Taken off your active addon's cooldown per kill.
@export var cooldown_per_kill := 5.0

@export_group("Juggernaut")
@export var juggernaut_hp := 25.0

@export_group("Sharpshooter")
## Headshot damage multiplier.
@export var sharpshooter_mult := 1.2

@export_group("Killstreak")
## Added to your speed per kill (0.04 = 4%).
@export var streak_speed := 0.04
## Taken off your reload time per kill (0.05 = 5%).
@export var streak_reload := 0.05
## Added to the delay before health regen per kill.
@export var streak_regen_delay := 1.0
## Kills past this many add nothing.
@export var streak_max_stacks := 5

@export_group("Blast Shield")
## Explosive damage multiplier (0.5 = half).
@export var blast_shield_mult := 0.5
