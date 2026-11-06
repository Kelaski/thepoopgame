# Tag Rush: development notes

How the game is built and how to work on it. For what the game is and how to play, see the [README](README.md); patch notes are in [CHANGELOG.md](CHANGELOG.md).

Tag Rush is built in **Godot 4.7** with GDScript. Its one plugin is [GodotSteam](https://godotsteam.com) (GDExtension, in `addons/godotsteam/`, Windows and Linux x86_64 only), used for online play. Almost everything is a Godot scene you can open and edit: the player, the five weapons, doors, the Tag and the spray decal (`assets/models/`), every map prop, furniture item and decor piece (`assets/props/`, `assets/furniture/`), the modular building pieces (`assets/building/`), and every menu and the HUD (`assets/ui/`). The ground, roads, road markings and boundary fence are generated from the layout, and the UI builds lists that depend on game data (rosters, keybinds, the playlist) at runtime. Sounds and music are synthesized in code, so there are no binary assets.

## Running from source

Run every test at once, each with a time limit: `powershell -File tests/run_all.ps1`. It takes well under a minute. The commands below run one on its own.

1. Install [Godot 4.7 or newer](https://godotengine.org/download) (standard build, not .NET). The project file is saved with 4.7; older 4.x editors warn when opening it.
2. Open Godot, choose **Import**, and select this folder's `project.godot`.
3. Press **F5** (Run Project).

Online play needs the Steam client running and signed in. The game uses App ID **480** (Valve's shared "Spacewar" test app) until Tag Rush has its own; `Net.APP_ID` in `scripts/autoload/net.gd` sets it. With 480, Steam shows you as playing Spacewar.

Steam only allows one copy of a game per account, so two copies on one PC can't both use Steam. For testing, **debug builds** (the editor, or a debug export) can run a local match over ENet from the command line. Release builds ignore `--port` and `--join`.

Optional command-line flags (after `--`):

```
--host                    host a Steam lobby
--host --port=PORT        debug only: host a local match on PORT
--join=IP[:PORT]          debug only: join a local match (default port 27015)
--name=NAME  --autostart=N (the host starts the match once N players are in)
```

When Steam starts the game from an invite, it passes `+connect_lobby <id>`, and the game joins that lobby.

**Safety checks** (`tests/checks.tscn`) cover the hit rate limit, the movement speed filter and the spray size check, with no network needed: `godot --headless --path . res://tests/checks.tscn` (exits 0 on a pass).

**City test** (`tests/city.tscn`) builds every map once, plans 30 random cities of each size against the layout rules, and checks that spawn zones are open and that the ground and fence hold.

**Movement test** (`tests/movement.tscn`) checks repeat wall jumps, the arc on landing, and grenades starting inside walls.

**Rounds test** (`tests/rounds.tscn`) plays 10 rounds and checks that no team starts where it did last round, the Tag spot moves, and spawn zones stay apart: `godot --headless --path . res://tests/rounds.tscn -- --host --port=27203 --autostart=1 --size=small` (add `--classic` for the Classic city).

**Two-player test** (`tests/two_player.tscn`) checks joining, unique names and movement sync. Start both copies at once; the host exits with code 0 on a pass and 1 on a failure:

```
godot --headless --path . res://tests/two_player.tscn -- --host --port=27199 --name=Same
godot --headless --path . res://tests/two_player.tscn -- --join=127.0.0.1:27199 --name=Same
```

**Three-player test** (`tests/three_player.tscn`) checks that one client sees another client move, through the host's relay. Start the host, then B, then A; A exits with 0 on a pass:

```
godot --headless --path . res://tests/three_player.tscn -- --host --port=27197 --name=H
godot --headless --path . res://tests/three_player.tscn -- --join=127.0.0.1:27197 --name=B
godot --headless --path . res://tests/three_player.tscn -- --join=127.0.0.1:27197 --name=A
```

## Default controls

**Changing the default controls:** the defaults are the game's actions in **Project Settings → Input Map** in the Godot editor (`move_forward`, `jump`, `addon` and `addon2` for the two addon slots, `chat` and so on).
- **Changing a default:** change an action's key there and every player who hasn't rebound it gets the new key.
- **Adding inputs:** you can give an action more than one input, such as a second key or a gamepad button. They all keep working until a player rebinds that action in game.
- **Player rebinds:** a rebind in Settings → Keybinds replaces the action's inputs with the player's key or button. It's saved in their settings file, and **Reset Keybinds** brings the Input Map's inputs back.
- **Labels and order:** the names and order shown in the Keybinds tab are in `Settings.ACTIONS` (`scripts/autoload/settings.gd`).
- **Left Shift:** the ability key is set to *Left* Shift in the Input Map, because Right Shift + Enter is team chat.

## Chat commands and safety

- Commands: `/help` lists commands; `/kill` eliminates yourself (the normal respawn timer applies); `/map <size>` (host) changes the map; `/time <morning|afternoon|evening|night|next>` (host) changes the time of day, blending over 10 s. New commands are added in `scripts/data/commands.gd`.
- **Safety:** the server rate-limits chat (5 messages per 4 s) and caps messages at 200 characters. It strips control, zero-width and bidirectional-override characters, both before sending and when receiving. Player names get the same cleaning. Messages are displayed as plain text in Labels (never BBCode). Commands are matched against a fixed whitelist and run on the server; nothing anyone types is ever evaluated as code.

## Performance notes

- All static geometry for a building is drawn with a few `MultiMeshInstance3D`s (one draw call each) and one shared toon material.
- Furniture and small details are in a separate MultiMesh with a 140 m visibility range.
- Collision uses shape owners on one `StaticBody3D` per layer per building instead of thousands of nodes. Box shapes are shared by size.
- There are no textures and no imported assets. Sounds are synthesized at startup.
- The renderer is kept simple: toon shading, one directional light with 4-split shadows reaching up to 320 m (**Shadow quality** sets the reach and shadow map size), no SSAO/SSR/GI.
- **Interior lights:** lamps are real `OmniLight3D`s without shadows that fade out beyond about 60 m (30 m on Low), so only nearby ones are drawn. A large map has about 450 to 650. The **Interior lights** setting (Off / Low / High) thins them.
- **Glowing parts:** these are drawn unshaded and over-bright in their own MultiMeshes, so the **Bloom** setting only picks them up, not sunlit walls.
- The **Render scale**, **Shadows**, **MSAA** and **View distance** settings are the main performance controls.

## Networking model

**Connecting:**
- Steam lobbies with GodotSteam's `SteamMultiplayerPeer`, relayed through Steam's network. No ports, UPnP or firewall rules are needed.
- The host creates the lobby and tags it with `game=tagrush`, its version and the host's name, since app 480 is shared by many games.
- Clients find lobbies with a lobby-list search filtered on that tag. They enter the lobby, then connect a peer to the lobby owner.

**Roles:** the host is the authoritative server (peer 1, also a player).

**Host relay:** anything a client sends to everyone (its movement, shots, doors, grapple) goes to the host with `Net.to_all`, and the host passes it on. Over Steam, clients aren't guaranteed a working connection to each other: in lobbies of 3 or more, players saw other clients frozen while the host saw everyone. Handlers find out who really sent a message with `Net.remote_sender()`, and only the methods listed in `Net.RELAYED` can be relayed.

**Who gets in:**
- A joining player sends their version number. The host turns away anyone on a different version, and anyone who doesn't register within 5 s (older builds).
- The host also turns away any Steam connection whose account isn't a member of its lobby, so the lobby's Public / Friends only / Invite only rule holds.
- Lobby data (names, versions) comes from other players, so it's cleaned like chat before it's shown.
Each client simulates its own movement and streams its position at 30 Hz. Remote players are interpolated.

**Movement check:** every receiver ignores updates that move further than anyone can, measured over a one-second window so the per-update slack can't add up: 70 m/s overall and 37.5 m/s along the ground. Updates are timed by the sender's own clock, mapped onto the receiver's clock using the quickest delivery seen so far. Over the internet updates arrive in bursts, and timing them by arrival froze players in 0.20.0. A sender whose clock runs fast gains nothing, because the estimate never runs ahead of arrival. Out-of-order updates are dropped. After a real teleport (the out-of-bounds reset), a second of updates moving on from the new spot is accepted.
Shooting is resolved on the shooter's client, and the server validates every hit before applying damage:
- The shooter is alive, the victim is an enemy, and the victim isn't spawn-protected.
- The weapon is the one the shooter actually holds. A thrown gun only counts for a few seconds after a bat kill, for 2 hits at most.
- The victim is within the weapon's range (plus slack for lag).
- Hits can't arrive faster than the weapon fires (with slack for lag and multi-hit shots).
- Damage is clamped to the weapon's maximum. The bat's momentum damage uses the speed the server actually saw the attacker move at.

Every peer also checks what other players send:
- Doors only move for a living player standing near them.
- Shot effects must be a real weapon, fired from where the shooter is, with at most 16 tracers.
- A thrown gun can only be launched by its thrower.
- Movement updates with broken numbers are dropped, and look angles are clamped.
- A player can't register twice, and pings are rate-limited.
Round state, the timer, respawns, the Tag and health regeneration all run on the server.

## Editing models

Open these in the Godot editor. Changes show up in game the next time a match loads.
- **`assets/models/player.tscn`:** the player.
  - Parts in the `team_color` group get the team colour, and parts in `team_color_dark` a darker shade. Add your own parts to these groups to colour them too.
  - `BodyShape` and `HeadHitbox` are the hitboxes, and `BodyRoot/TpPivot/TpGun` is where the held weapon goes.
  - Keep the node names: the code finds them by name.
- **`assets/models/weapons/*.tscn`:** one scene per weapon, used for both your first-person view and the gun other players see you holding.
  - `Muzzle` marks where shots and the muzzle flash come from. On the sniper, `GlintPoint` marks where the scope glint shows.
  - Nodes in the `first_person_only` group (the holo-sight reticles) only appear in first person.
  - The root's **Ads Offset** setting is where the gun sits while aiming. **Viewmodel Rotation** and **Held Rotation** tilt it in first person and in other players' hands (the bat uses both).
- **`assets/models/muzzle_flash.tscn` and `glint.tscn`:** the muzzle flash and the sniper glint, whose material is `assets/materials/sniper_glint.tres`.
- **`assets/models/door.tscn`:** the door, with the hinge at the origin, built for a 1.7 × 2.45 m doorway.
  - In game, `Panel` is stretched to each doorway, the collision `Shape` is resized, and other parts under `Body` (the `Knob`) move to match.
  - The panel takes each building's door colour.
- **`assets/models/tag.tscn`:** the Tag: `Gem` and `Beam`. They're tinted with the Tag colour from Settings → Colours.
  - The ring shows the pickup radius (1.7 m, `Game.PICKUP_RADIUS`), so change both together.
- **`assets/models/spray_decal.tscn`:** the spray decal. Its material is `assets/materials/spray_decal.tres`, and each player's image and aspect ratio are filled in at runtime.
- **Thrown gun:** the gun a killing bat swing launches is now the victim's actual weapon model.
- **Effect materials:** bullet tracers, impacts, UAV rings and Interlink lines use `assets/materials/fx_tracers.tres`.

## Editing props

Every prop and piece of furniture is a template scene in `assets/props/` or `assets/furniture/`. Open one, change it in the editor and save.

**How they're used:** the map places thousands of these, so they aren't added as nodes. `scripts/map/prop_library.gd` reads each scene once into plain mesh and collision data, and `Clutter` and `GeoBatch` bake them into one mesh per material. `Clutter.IMPORTS` lists the scenes the map uses.

- **Meshes:** the parts' colours and their glow flag are kept. Everything is drawn with `assets/world/toon_world.gdshader`.
- **Collision:** `CollisionShape3D` boxes, cylinders and spheres (round shapes become boxes). Every shape becomes a wall, or a bounce pad if its body is on layer 32.

## Tuning

Every weapon and addon number is a named field you can edit in Godot's Inspector. Double-click a file in the FileSystem dock, change a value and save: hover over a field to see what it does.

- **Weapons:** `assets/tuning/weapons/*.tres`, one file per weapon (the fields are in `scripts/data/weapon_stats.gd` and `scripts/data/weapons/`). Grenade flight is under the Grenade section of `grenade_launcher.tres`: `launch_speed`, `shooter_speed_scale`, `grenade_gravity` and so on. The sniper's loudness is under Sound in `sniper.tres`.
- **Addons:** `assets/tuning/addons/*.tres`, one file per addon. Its script in `scripts/addons/` lists the fields and holds what the addon does.

The loadout descriptions are built from these values, so they stay correct. If you raise a weapon's damage, raise its `max_damage` too: the host refuses anything above it. In multiplayer, the host's values decide damage and everyone's own copy decides their own movement and timers, so all players need the same build.

## Editing maps

`ClassicMap` and `ProcGen` plan a map (`MapLayout`), `MapBuilder` builds it, and `Level` is what the rest of the game reads. The same kind and seed give the same map on every peer. Structural numbers (storey heights, doors, windows, how many of everything) are in `assets/tuning/map_rules.tres`. Buildings are generated as boxes by `scripts/map/building_builder.gd`, and level colours and patterns are in the `TABLE` in `scripts/map/map_mats.gd` (`MapMats`).

**Collision layers:** floors 1, walls and furniture 2, player 4, doors 8, ground and boundary 16, bounce pads 32, sky cap 64. Phantom passes walls and doors but not floors, and drops through floors but not the ground, so the ground must stay on 16.

**Doors** are this game's `Door` (`assets/models/door.tscn`), hung from the plan's doorway centres. **Lighting** is `assets/world/sky_env.tscn` with presets in `assets/tuning/times/`.

## Editing the UI

Every screen is a scene under `assets/ui/` (`menu/`, `hud/`, `rows/`), with its script in the same place under `scripts/ui/`:
- **Menus:** `main_menu`, `server_browser`, `lobby`, `pause_menu`, `settings_menu` (which holds `colors_menu`, `crosshair_editor`, `music_menu` and `spray_menu` as tabs), `music_bar` and `viewmodel_preview`.
- **Menu theme:** `MenuKit` (`scripts/ui/menu_kit.gd`), set on each screen by `main.gd`. Menus are laid out for 1920 x 1080 and scaled to the 1600 x 900 canvas. The HUD keeps `UiKit`'s theme.
- **In-match:** `hud`, `chat_box` and `loadout_panel`.
- **Smaller pieces:** `crosshair`, `minimap`, `damage_indicator`, `connecting` and `version_label`.

**What's where:**
- **Layout:** each scene holds the layout. Its script (`scripts/ui/`) holds the behaviour and finds nodes by their unique name (`%Name`), so keep the names the scripts use. You can move, resize, restyle or reorder anything else.
- **Buttons:** they're wired to the script's methods as saved signal connections (Node → Signals in the editor).
- **Colours:** labels use the theme type variations from `UiKit.make_theme()`, so the colours in Settings → Colours reach every screen:
  - `TitleLabel`, `AccentLabel` and `MutedLabel` for menus.
  - `HudLabel`, `HudAccentLabel` and `HudMutedLabel` for outlined HUD text.
  - `MenuBackground` for menu backdrops.

**Setting rows:** these are instances of three reusable row scenes in `assets/ui/rows/`: `setting_slider`, `setting_check` and `setting_option`.
- Set a row's **Setting** (the `Settings` key, such as `fov`), **Label Text** and range or choices in the Inspector. The row then shows that setting and saves changes to it, with no code needed.
- To add a setting to the settings menu, duplicate a row and change those fields.

**Still built in code:** lists that come from game data, such as the keybinds, colour slots, playlist, team rosters, weapon and addon buttons, kill feed and scoreboard rows.

## Project layout

```
project.godot
scripts/
  main.gd                   # screen flow, overlays, mouse capture, cmdline flags
  autoload/settings.gd      # settings + rebindable input map (user://settings.cfg)
  autoload/sfx.gd           # procedural sounds
  autoload/net.gd           # Steam lobbies (host/join/invites), roster, team/loadout requests
  autoload/game.gd          # the Tag game mode, in layers, each adding one job:
                            #   game_state.gd (what everyone knows), game_addons.gd (host checks on addons),
                            #   game_damage.gd (hits, kills, grenades), game.gd (rounds, joining, commands)
  data/weapons.gd           # weapon stats
  data/addons.gd            # which addons are active / passive, and their descriptions (each addon is in addons/)
  addons/*.gd               # one per addon: its numbers (shown in the Inspector) and what it does
  data/weapon_stats.gd, data/weapons/   # weapon numbers, shown in the Inspector
  data/game_version.gd      # version number (major.minor.patch)
  map/level.gd              # a built map, as the game reads it; the map list
  map/map_layout.gd         # the plan of a map; classic_map.gd and proc_gen.gd make one
  map/map_builder.gd        # the 3D level: ground, roads, buildings, parks, props, cranes, fence
  map/building_builder.gd   # buildings; interiors.gd furnishes them, park_builder.gd builds parks
  map/geo_batch.gd          # batched meshes and collision; prop_library.gd and clutter.gd place props
  map/skyline.gd            # the distant city
  world/world.gd            # players, Tag, FX, heartbeat, respawn search
  world/sky_env.gd          # sun, sky, fog and ambient light; time of day
  world/door.gd             # hinged doors
  world/mats.gd             # shared materials / team colours
  player/player.gd          # the player, in layers, each adding one job:
                            #   player_state.gd, player_movement.gd, player_net.gd, player_addons.gd,
                            #   player_weapons.gd, player.gd (setup, drawing, the tick)
  player/weapon_model.gd    # weapon scene root: muzzle, glint point, first/third-person setup
  ui/menu/, ui/hud/, ui/rows/   # behaviour for the screens in assets/ui
assets/models/              # player, weapon, door, Tag, spray decal, muzzle flash and glint scenes
assets/materials/           # shared materials (.tres)
assets/props/, assets/furniture/   # map prop and furniture template scenes
assets/world/               # the sky and light, street and interior lights, skyline and map shaders
assets/ui/                  # every menu (menu/), the HUD (hud/) and reusable setting rows (rows/)
assets/main.tscn            # the scene the game starts from (just runs scripts/main.gd)
```

## Design choices

- **Sprint is the default pace** (no sprint key). Aiming and crouching drop you to walking speed.
- **Reloading and magazine sizes** were added (R key), with the values above.
- **Sniper:** inaccurate unless aimed. **Shotgun and sniper** pellets and rounds deal the same damage to the head (headshots still break Hider invisibility).
- **Shotgun falloff** keeps the same 10 m / 15 m ranges and the same ratios as before (100% / 70% / 40%), so 15 / 10.5 / 6 damage per pellet.
- **Wall running** starts automatically, and its controls are Jump and Crouch, so all of it is rebindable. Foliage blocks sight but not bullets.
- **Dropped-Tag timer:** the timer keeps running while the Tag is on the ground (it only waits for the first pickup of a round). A pickup adds +10 s (enemy) or +15 s (teammate), capped at 2:00. If it runs out while the Tag is down, the round goes to overtime and the next pickup wins it.
- **Phantom's** cooldown starts when the phase ends.
- **Grapple's** cooldown starts when the hook hits . A miss only costs 1 s so you can try again.
