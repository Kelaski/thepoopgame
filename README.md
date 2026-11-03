# Tag Rush

A team-based, first-person objective shooter built in **Godot 4.7 (GDScript only, no extra plugins)**.
Two teams of up to 8 race to a randomly chosen objective, grab **the Tag**, and the team holding it
has to keep its **Runner** alive for 2 minutes. Best of 7 (first to 4 round wins).

Models are being moved from code into Godot scenes you can open and edit in the editor:
- **Done:** the player, the five weapons, doors, the Tag and the spray decal (`assets/models/`), all 82 map props and furniture items plus 30 interior decor pieces (`assets/props/`, `assets/furniture/`), the 16 modular building pieces (`assets/building/`), and every menu and the HUD (`assets/ui/`). See **Editing models**, **Editing props**, **Editing buildings** and **Editing the UI** below.
- **Still built in code:** the ground, roads, road markings and boundary fence, which are generated from the layout. The UI also builds lists that depend on game data, such as rosters, keybinds and the playlist, at runtime.
- **Always in code:** sounds and music are synthesized.

The only binary files are the easter egg's image and sound in `assets/` (see Easter egg below).

## Running it

1. Install [Godot 4.7 or newer](https://godotengine.org/download) (standard build, not .NET). The project file is saved with 4.7; older 4.x editors warn when opening it.
2. Open Godot, choose **Import**, and select this folder's `project.godot`.
3. Press **F5** (Run Project).

The main menu has **Host Game**, **Play Game**, **Settings**, **Customization** and **Quit**. In a match, **Esc** opens the pause menu: **Resume**, **Settings**, **Customization**, **End Match** (host only) and **Quit**, which leaves to the main menu (the host's button is **Close Server**). A music player sits in its bottom-right corner. Your player name is set in Customization. The game version is shown in the bottom-left corner of every screen (patch notes are in [CHANGELOG.md](CHANGELOG.md)).

### Hosting / joining

- The game is online only.
- **Host:** click **Host Game**. The lobby shows your **join code** with a **Copy Code** button, and explains anything that still stands in the way of players connecting:
  - It looks up your public address (from `api.ipify.org`) to build the code.
  - It asks your router to open the port automatically with UPnP. If that isn't possible, forward the UDP port to your PC in your router's settings.
  - It warns you if your internet provider shares your address with other customers (CGNAT). Then nobody can reach you no matter what you forward, so someone else should host.
- **Port:** UDP **27015** by default. You can change it in the lobby (the **Port** box and **Change Port**), for example to a port you've already forwarded. The game remembers it. Changing it restarts the lobby, so anyone already in has to rejoin with the new code.
- **Firewall:** on Windows the game checks for its firewall rule when it opens. If the rule is missing, it asks for permission through a Windows administrator (UAC) prompt. Saying yes removes any old rule Windows made for the game (a dismissed "allow access" prompt leaves a *block* rule behind, which overrides allow rules) and allows incoming connections on every network type. If you said no, the lobby has an **Allow Through Firewall** button.
- **Join:** click **Play Game**, type the code and press **Join**. A plain IP address (or `IP:PORT`) also works in the code box.
- You can't join your own code from the PC or network that's hosting, because most home routers don't loop the connection back. Test with a friend on another network.
- A code is just the host's address written in a short form, not a password, so only share it with people you want to play with.
- Only players on the same version can play together. A player on a different version is told the host's version and sent back to the menu. This also covers builds from before 0.2.0, which can't report a version: the host drops anyone who hasn't registered within 5 s, and a client whose host never accepts it gives up after about 6 s.
- The host chooses teams (or shuffles them) and clicks **START MATCH**. Players who join mid-match spawn in after the respawn timer.

To test two copies on one machine, run two instances and enter `127.0.0.1` as the code.
Optional command-line flags (after `--`):

```
--host  --join=CODE (or IP[:PORT])  --name=NAME  --port=PORT  --autostart=N
```

## Controls (all rebindable in Settings > Keybinds)

| Action | Default |
|---|---|
| Move | W A S D |
| Jump / double jump (Skywalker) | Space |
| Crouch / slide (crouch while sprinting) | Ctrl |
| Lean left / right | Q / E |
| Addon ability | Left Shift |
| Interact (doors) | F |
| Fire / Aim | Mouse 1 / Mouse 2 |
| Reload | R |
| Scoreboard | Tab |
| Loadout (while dead) | B |
| Spray | T |
| Chat (all / team) | Enter / Right Shift + Enter |
| Pause / settings | Esc |

There is no sprint key: moving forward is always a sprint. Aiming, crouching or holding a lean key slows you to a walk.
If you played an older version, the old default binds for lean right (C), addon (F) and interact (E) move to the new defaults automatically. Binds you changed yourself are kept.

**Changing the default controls:** the defaults are the game's actions in **Project Settings → Input Map** in the Godot editor (`move_forward`, `jump`, `addon`, `chat` and so on).
- **Changing a default:** change an action's key there and every player who hasn't rebound it gets the new key.
- **Adding inputs:** you can give an action more than one input, such as a second key or a gamepad button. They all keep working until a player rebinds that action in game.
- **Player rebinds:** a rebind in Settings → Keybinds replaces the action's inputs with the player's key or button. It's saved in their settings file, and **Reset Keybinds** brings the Input Map's inputs back.
- **Labels and order:** the names and order shown in the Keybinds tab are in `Settings.ACTIONS` (`scripts/autoload/settings.gd`).
- **Left Shift:** the ability key is set to *Left* Shift in the Input Map, because Right Shift + Enter is team chat.

The **Tag Rush Theme**, a fast 160 BPM loop, plays during matches. It's synthesized in code on a background thread when the game starts and has its own volume slider.

### Custom music & playlist (Customization → Music & Playlist, from the main menu, lobby or pause menu)

- **Add Songs...** opens your system file picker. You can pick several songs at once.
- Imported songs are copied into the game's own music folder (`user://music`), so the playlist keeps working even if you move or delete the originals. **Open Music Folder** shows that folder.
- Importing runs in the background, so the game keeps running (important when you're the host) and you can close the menu while it works.
- **Formats:** OGG, MP3 and WAV (8/16/24/32-bit integer or 32/64-bit float PCM) work out of the box; other WAV encodings fall back to ffmpeg. FLAC, M4A/AAC, Opus, WMA, AIFF, WebM/MKA, ALAC and more are converted on import, which needs [ffmpeg](https://ffmpeg.org) installed and on your PATH.
- In the playlist you can turn songs on and off, reorder them, preview them and remove them.
- **Play during matches** chooses between the Tag Rush Theme, your playlist, or both. With both, the theme takes a one-minute turn in the playlist. There's also a shuffle option. The pause menu has a music player in the bottom-right corner (previous, play/pause, next and volume), and a "Now playing" toast shows each new song. Editing the playlist mid-match keeps the current song playing unless you disable or remove it.

### Colour customization (Customization → Colours, from the main menu, lobby or pause menu)

You can recolour:
- The menus: accent, panels, buttons, text and backdrop.
- Team and Tag colours.
- The sky: top colour and horizon / fog colour. For a picture skybox, use Customize → Skybox.

The map itself (ground, roads, grass and buildings) always uses its built-in colours.

Presets are Default, Midnight, Neon, Pastel and Desert, and every colour has its own Reset. Menu and sky colours change instantly. Team colours apply when the next match loads. Colours are personal and don't affect other players.

Settings also cover mouse and ADS sensitivity, invert Y, hold/toggle aim and crouch,
FOV (90–120, horizontal), brightness, fullscreen, V-Sync, an FPS cap slider (30–500), render scale, MSAA, shadows,
view distance, master/effects/UI volume, hitmarker sound, minimap size (0.6x–2x) and location names, and an FPS counter.

## Rules

- **Spawning:** at round start each team spawns at a random purple-dot spawn zone (the two zones are at least 70 m apart).
  The objective is the red-dot location whose distance to the two teams is most even, with some randomness.
  Players are frozen for a 5 s countdown, then everyone rushes.
- **The Tag:** the first player to touch it becomes the **Runner**. Their team defends and the timer starts at 2:00.
- **Dropping:** when the Runner dies, the Tag drops where they died and **the timer keeps running**. The clock only waits at the start of a round: it doesn't run until the Tag is picked up for the first time.
  - An enemy picks it up: their team becomes the defenders, and the timer resumes from the value at the drop **+10 s**.
  - A teammate picks it up: the timer resumes **+15 s**.
  - The timer is capped at 2:00.
- **Winning a round:** the timer reaches 0. The team holding the Tag wins, or, if it's on the ground, the team that held it last. First to 4 wins the match.
- **Runner self-defence:** every kill the Runner gets takes 5 s off their team's timer.
- **Runner visibility:** everyone sees the Runner on the minimap at all times. Hunters within 25 m hear a heartbeat that speeds up as they get closer.
- **Health:** 100 HP (150 HP with the Spiked Bat). After 8 s without taking damage, health regenerates quickly (50 HP/s). Every kill gives you back 30 HP (up to your max).
- **Minimap:** shows location names on the buildings and park. Its size is adjustable in Settings > HUD.
- **Damage direction:** when you're shot, a red arc around the crosshair points at the shooter (up = in front of you, down = behind). It follows them as they move and fades after about 2 s.
- **Respawn:** after a 6 s timer (7 s if your team is holding the Tag, the Runner included), press **Jump (Space)** to respawn. Use the wait to change loadouts. Runners' teammates spawn near the Runner. Hunters spawn near the hunter closest to the Runner.
  A spawn point is rejected if any living enemy has line of sight to it (or is within 12 m).
  You get 3 s of spawn protection from the moment you spawn. Moving or shooting ends it early.
- **Loadouts** (weapon and addon) can be changed in the lobby, or while dead (press **B**). Changes apply on respawn.
- Friendly fire is off. Bullets pass through teammates.

### Weapons (all hitscan)

| Weapon | Damage | Rate | Sight | Notes |
|---|---|---|---|---|
| Assault Rifle | 33 body / 45 head, 22 / 30 beyond 25 m | 9.5 rps | 1.5x holo | 30-round magazine |
| SMG | 19 / 26, 12 / 19 beyond 18 m | 13 rps | 1.2x holo | 40-round magazine |
| Shotgun | 13 pellets × 15 (≤10 m) / 10.5 (≤15 m) / 6 | 1 rps | 1.15x irons | 12° cone, 6 shells |
| Sniper | 100 body, 90 lower body, headshots always kill | 0.4 rps | 2.5x | Pierces 1 wall and every player in line, 5 rounds. A ring around the crosshair shows when the next shot is ready. Its shot is 60% louder than before. The AR, SMG and Shotgun are 35% louder |
| Spiked Bat | 35 per swing, ×1.1 for every m/s you're moving above your own sprint speed (compounding: +1 m/s 38.5, +2 42, +3 47, +5 56, +10 91, +14 133; capped at 300). Measured from your horizontal speed when you swing | 2.25 swings/s | none | 7 m reach, +10% move speed and 150 HP while equipped. A killing swing launches the victim's gun where you look (70 dmg) |

Every player holds a visible model of their weapon (the same model as your own first-person view), aimed up and down with where they're looking. When someone scopes in with the Sniper, their scope **glints**. The glint is brightest when they're aiming straight at you, shows only when they're looking within about 53° of you, and walls hide it.

### Addons

| Addon | Effect |
|---|---|
| Hider | Shift: 15 s of invisibility. Fully invisible while still or crouch-walking, 10% visible while moving. Taking damage does not end it; firing does. 12 s cooldown after it ends. |
| Trackstar | Passive +15% speed and 25% faster reloads (reload time × 0.8). Shift: +35% for 6 s. 30 s cooldown from activation. |
| Skywalker | Double jump with extra height that keeps your current momentum (no added speed). Recharges when you land. |
| Stalker | See wide red ground trails behind every enemy. Each part of a trail lingers for 6 s, fading as it ages. Walls and floors hide the trails. The trails are identical, so you can't tell which one is the Runner. |
| Phantom | Shift: 2 s of phasing. Run through walls and doors. Double-tap crouch to drop through a floor. 23 s cooldown. |
| Grapple | Hold Shift: throw a grappling hook up to 30 m (it flies out over about 0.3 s). It latches onto whatever it hits (walls, floors, doors, props or players) and reels you in while you keep steering, up to 24 m/s for at most 2.5 s. The rope only ever shortens, so hooking something above you swings you underneath it. Reaching the hook pops you upwards so you can climb onto ledges. The grapple only lasts while you hold Shift: releasing it (or pressing Jump) lets go with your momentum, and releasing while the hook is still flying reels it back in (counts as a miss). The rope also snaps if something gets in the way. Hooking an enemy yanks them towards you. 9 s cooldown after a hit; a miss only costs 1 s. Everyone sees the hook and rope. |

### Movement

Snappy ground acceleration, sprinting by default (9 m/s forward; 5 m/s strafing, backwards or leaning; 2.8 m/s crouched), crouch, and a momentum slide (crouch while sprinting). You can start a slide in mid-air and it carries on after you land until your momentum runs out. Sliding downhill keeps accelerating the longer you stay on the slope.
Slide-jumping keeps your speed, and air strafing is limited while momentum is preserved (air acceleration 19.2 m/s², which steers you in the air without going past your current speed).
**Wall running:** jump into a wall at speed while holding forward to run along it for up to 1.6 s.
Press Jump to kick off the wall. The kick keeps your speed and adds a little, so you can chain it into another wall run, a slide or a slide-jump. Crouch drops you off. Jumping and wall jumps both have 0.1 s of coyote time, so you can still jump just after running off a ledge or a wall.
**Wall-jump fatigue:** your first 3 wall jumps before touching the floor are free. From the 4th on, each kick keeps only 75% of your speed (then 56%, 42%...) and adds less height, and wall runs stop holding you at running speed, so long chains run out of momentum. Each of those jumps also adds +50% gravity (150%, 200%, 250%...), up to 600%, which applies in the air and makes wall runs sink faster. Touching the floor resets all of it.
**Leaning** (Q / E) peeks around corners and slows you to a walk. Switching straight from one side to the other is three times faster than leaning out (about 0.1 s). Your head hitbox moves with the lean, and walls limit how far you can lean.
Doors fill their doorways exactly and swing open, away from you and at full speed, when you sprint or slide into them. **F** opens and closes them normally.

## Map sizes

The host picks **Small**, **Medium** or **Large** in the lobby (the last choice is remembered), or with the chat command `/map <small|medium|large>`. Using `/map` during a match restarts the match on the new map. The choice is shared with everyone, including players who join later. `/map` with no size shows the current one.

| Size | Area | Buildings | Spawn zones | Tag spots | Rooftop bridges |
|---|---|---|---|---|---|
| Small | ~81 × 102 m | Bank, Meridian Tower + park | 3 | 3 (Park, Bank, Tower) | none |
| Medium | ~130 × 136 m | School, Bank, Diner, Arcade, Meridian Tower, Casino + park | 5 | 4 (Park, Bank, Tower, Casino) | Tower–Casino |
| Large | 200 × 170 m | the whole city (all 18) + park | 10 | 8 | all 6 |

The lobby also chooses the city:
- **Random city** (the default): a new city is generated for every match, at the chosen size. The host picks the seed and every player builds the same city from it (`scripts/map/city_gen.gd`).
  - Roads form a grid of uneven blocks, and each block is split into lots with alleys between them.
  - A lot holds a building (16 types with random names, height and footprint), a plaza or a car park. Buildings of 4 storeys or more are capped at 30 × 25 m.
  - One block near the middle becomes the park.
  - Spawn zones are spread out over the junctions and plazas, and Tag spots over the park, open-plan buildings and plazas, away from the spawns.
  - Cranes bridge the roofs of buildings facing each other across a road.
  - Large maps get about 15–25 buildings, Medium 8–13 and Small 3–4.
- **Classic city:** the hand-made city described below. Smaller sizes are cut-outs of it: buildings that fit fully inside are kept, the fence moves in, and empty lots where a building was cut become car parks.

The minimap zooms to fit either way. Sizes are defined in `MapData.SIZES` (`scripts/map/map_data.gd`).

## The map

The map is laid out from the design sketch at a scale of 1 px = 0.1 m, so the city is 200 m × 170 m.
A fence with tall invisible collision surrounds it.
Every object has collision (furniture, props, tree trunks, lamps, the crane parts and so on) except anything leafy. Tree crowns, potted plants and bushes are visual only: you can walk and shoot through them, but they block sight. Flat floor markings and the bleacher steps (a smooth ramp covers them) have no collision either.
Teammates' names float above their heads in small text (`NAMEPLATE_SCALE` in `scripts/player/player.gd`).

| # | Building | Floors |
|---|---|---|
| 1 | Warehouse (racks, crates, forklifts, mezzanine offices) | 2 × 6 m |
| 2 | Swiftcurrent K-12 School (classrooms, desks, lockers, chalkboards) | 3 |
| 3 | Rapids Arena, home of the Swiftcurrent Rapids (court, hoops, bleachers, scoreboard) | 1 × 11 m |
| 4 | Movie Theater (seat rows, concessions) | 2 |
| 5 | Bank (teller counters, desks, vault) | 2 |
| 6–9 | Entertainment strip: Diner, Arcade, Nightclub, Bar | 1–2 |
| 10 | Riverside Apartments (nice: beds, sofas, kitchens) | 5 |
| 11 | Mall (shelving, clothes racks, kiosks) | 3 |
| 12 | Motel 6 (rooms with beds, TVs) | 2 |
| 13 | Eastside Tenements (run-down, gang A) | 4 |
| 14 | Southside Tenements (run-down, rival gang) | 3 |
| 15 | Meridian Tower (office cubicles) | 5 |
| 16 | Golden Rapids Casino (slots, card tables, bars) | 5 |
| 17 | Water Treatment Center (tanks, pipes, pumps) | 1 × 7 m |
| 18 | Public Library (bookshelves, reading tables) | 2 |
| 19 | Park (basketball court, pond, playground tower, trees) | outdoor |

Buildings are at most 5 storeys. The three 5-storey buildings (Riverside Apartments, Meridian Tower, Golden Rapids Casino) are 75% of their sketch width and length, centred on the sketch footprint, so their height does the work. Each building has a two-lane stairwell of ramps from the ground floor to an accessible roof, and longer buildings have a second one at the far end.
Buildings are built from modular pieces on a 2 m grid (see **Editing buildings**):
- **Grid:** every building's footprint snaps to the grid around its centre, moving each wall by at most 0.5 m.
- **Walls:** each storey's walls are a row of 2 m modules. A module is solid, has the building's window style (small, wide or tall), or is a door on the ground floor.
- **Windows:** never at the ends of a wall or next to a door, and less likely right after another window, which leaves long solid stretches for wall running. Windows are open gaps you can shoot and jump through.
- **Rooms:** residential and school floors have a corridor with 6 m rooms behind doors.
- **Decor:** every storey has ceiling lights, and the walls get decor that fits the building: posters and clocks in the school, neon signs and a jukebox in the diner and bar, bottle shelves and a dartboard in the bar, picture frames and rugs in the bank, apartments, motel and library, pipes and safety signs in the warehouse and water treatment centre, and so on. Exit signs hang over the street doors. Lights are fixtures only, not real light sources.**Streets** look like a busy city:
- **Traffic:** both lanes of every road hold stopped traffic (cars, yellow taxis, vans and buses), with about half the spots taken. Every vehicle, on the road or in a car park, is at least 1.4 m from every other one (front, back and side to side), so you can always slide between two cars. The two lanes are staggered rather than side by side.
- **Junctions:** kept clear, with zebra crossings.
- **Sidewalks:** along every curb, a lamp post and street trees alternate every 6 m. In between there are benches, bins, fire hydrants with newspaper boxes, mailboxes and the odd bus shelter.
- **Open squares:** a few big tree planters, bench pairs, kiosks and dumpsters.
- **Kept clear:** nothing is placed in front of a building door, on a spawn zone or on a Tag spot.

Six tower cranes hang planks or sheet metal between rooftops as bridges: Warehouse–School, Apartments–Meridian Tower, Meridian Tower–Casino, the two Tenements, Theater–Bank, and Water Treatment–Library. Crates on each roof help you climb onto them.
The **purple dots** in the sketch are the 10 spawn zones. The **red dots** are the 8 possible Tag locations (`scripts/map/map_data.gd`).

## Performance notes

- All static geometry for a building is drawn with a few `MultiMeshInstance3D`s (one draw call each) and one shared toon material.
- Furniture is in a separate MultiMesh with a 75 m visibility range.
- Collision uses shape owners on one `StaticBody3D` per layer per building instead of thousands of nodes. Box shapes are shared by size.
- There are no textures and no imported assets. Sounds are synthesized at startup.
- The renderer is kept simple: toon shading, one directional light with 2-split shadows (can be turned off), no SSAO/SSR/GI.
- The **Render scale**, **Shadows**, **MSAA** and **View distance** settings are the main performance controls.

## Networking model

ENet with the host as the authoritative server (peer 1, also a player), on UDP port 27015 by default (the host can change it). The host opens the port with UPnP when it can.
A joining player sends their version number, and the host turns away anyone on a different version, or anyone who doesn't register within 5 s (older builds).
Each client simulates its own movement and streams its position at 30 Hz. Remote players are interpolated.
Shooting is resolved on the shooter's client, and the server validates every hit (alive, enemy team, not spawn-protected, damage clamped to the weapon maximum) before applying damage.
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
- **`assets/models/tag.tscn`:** the Tag: `Gem`, `PickupRing` and `Beam`. They're tinted with the Tag colour from Customization.
  - The ring shows the pickup radius (1.7 m, `Game.PICKUP_RADIUS`), so change both together.
- **`assets/models/spray_decal.tscn`:** the spray decal. Its material is `assets/materials/spray_decal.tres`, and each player's image and aspect ratio are filled in at runtime.
- **Thrown gun:** the gun a killing bat swing launches is now the victim's actual weapon model.
- **Effect materials:** bullet tracers and impacts use `assets/materials/fx_tracers.tres`, and the Stalker trails use `fx_trails.tres`.

## Editing props

Every prop and piece of furniture on the map is a template scene:
- `assets/props/vehicles/`: car, taxi, van, bus.
- `assets/props/street/`: lamp, trees, benches, bins, hydrant, mailbox, bus shelter, kiosk, dumpster.
- `assets/props/nature/`: tree crown, trunk, bush.
- `assets/props/park/`, `arena/`, `water/`: the basketball court, playground, bleachers, scoreboard, tanks and pumps.
- `assets/props/crane/`: footing, mast, braces, the crane top, hook and loads, and `beam`, the stretched piece used for cables, jibs and bridge decks.
- `assets/furniture/`: 40 items, from desks and beds to slot machines.
- `assets/furniture/decor/`: 30 interior decor pieces: ceiling lights, wall decor, floor pieces, a rug and the exit sign.
Edit them in the Godot editor. The next match uses your changes.

**How they're used:** the map places thousands of these, so they aren't added as nodes. When a map loads, each scene is read once and stamped into the same batched meshes and collision as before, so performance doesn't change (`scripts/map/prefabs.gd`). That puts some limits on what a template can contain:
- **Meshes:** `BoxMesh`, `CylinderMesh` and `SphereMesh` parts. A part's colour is its material's albedo colour.
- **Collision:** `CollisionShape3D` boxes and cylinders inside a `StaticBody3D`. The body's collision layer decides how a shape collides:
  - `Collision` (layer 2): walls and furniture. Phantom can pass through, and the sniper can pierce one.
  - `FloorCollision` (layer 1): floors.
  - `SolidCollision` (layer 16): solid ground.
  - A part with no shape is decoration you can walk through.
- **Metadata** (shown in the Inspector under Metadata):
  - `slot`: a colour filled in by the game, such as `body` on cars, `leaf` on tree crowns, `main` on sofas and tables, or `blanket` on beds. `slot_darken` / `slot_lighten` shade it.
  - `slot_choices`: a list of colours. One is picked at random for each placement, as with kiosk awnings, arcade cabinets and books.
  - `batch`: `static` or `detail`. Detail parts are hidden beyond 75 m, like the furniture.
- **Placement:**
  - Props are placed on the ground at their origin.
  - Street props face their local +Z away from the road.
  - Furniture is sometimes turned 90°.
  - **Decor:** wall pieces have their origin on the wall face at floor level and stick out along +Z into the room. Floor pieces against a wall have their back at Z = 0. Ceiling lights hang down from their origin on the ceiling. The rug is centred on its origin.
  - Which pieces each building type gets is the `THEME_DECOR` table in `scripts/map/map_builder.gd`.  - Some pieces are stretched to fit: the crane mast is built 10 m tall, a tree trunk 1 m tall, and a water pipe and `beam` 1 m long.
- **Code-side randomness:** sizes such as crates, bushes and tree heights are still random in code.

The parts are named `Part0`, `Part1` and so on, in build order. Rename them freely. Only the meshes, shapes, colours and metadata matter.

## Editing buildings

Buildings are put together from the pieces in `assets/building/`. Each piece's colours come from the building's style through colour slots: `wall`, `trim`, or `color` for floors, stairs and interior walls.

**Wall modules:** these are 2 m wide (local X, centred), 4 m tall from their base and 0.3 m thick.
- `wall_solid`: a plain wall.
- `wall_window_small`, `wall_window_wide`, `wall_window_tall`: the three window styles. Each building uses one of them.
- `wall_door`: a 1.7 × 2.45 m gap that a door fills in game.
- `wall_filler`: 1 m tall, stretched on top of the module for storeys taller than 4 m.
- `corner_post`, `trim_band`, `parapet`: corners, the band along each storey, and the roof edge.

**Floors and stairs:**
- `floor_slab` and `floor_finish`: 1 × 1 m pieces, stretched to each floor slab and the ground-floor finish.
- `stair_segment`: one step of the ramp, rising 0.5 m over 0.8 m. A storey is its height ÷ 0.5 segments.
- `stair_divider` and `rail_section`: the wall between the two stair lanes and the railing round the stair hole.

**Interior walls:** `wall_interior` (a 1 × 1 m piece, stretched) and `wall_interior_door` (the door jambs of a 2 m partition module).

You can reshape the inside of a module freely: move the jambs, change the window shape, or add trim. Keep its outer size, because the pieces are placed edge to edge. The grid size, storey module height and stair step are constants at the top of `scripts/map/map_builder.gd` (`MODULE`, `MODULE_H`, `STAIR_RUN`, `STAIR_RISE`). Building pieces are always drawn, unlike furniture, which fades out beyond 75 m.

## Editing the UI

Every screen is a scene in `assets/ui/`:
- **Menus:** `main_menu`, `join_menu`, `lobby`, `pause_menu`, `settings_menu`, `customize_hub`, `colors_menu`, `crosshair_editor`, `music_menu`, `spray_menu` and `skybox_menu`.
- **In-match:** `hud`, `chat_box` and `loadout_panel`.
- **Smaller pieces:** `crosshair`, `minimap`, `damage_indicator`, `connecting`, `bird_event` and `version_label`.

**What's where:**
- **Layout:** each scene holds the layout. Its script (`scripts/ui/`) holds the behaviour and finds nodes by their unique name (`%Name`), so keep the names the scripts use. You can move, resize, restyle or reorder anything else.
- **Buttons:** they're wired to the script's methods as saved signal connections (Node → Signals in the editor).
- **Colours:** labels use the theme type variations from `UiKit.make_theme()`, so the colours in Customize → Colours reach every screen:
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
scenes/main.tscn            # root scene (just runs scripts/main.gd)
scripts/
  main.gd                   # screen flow, overlays, mouse capture, cmdline flags
  autoload/settings.gd      # settings + rebindable input map (user://settings.cfg)
  autoload/sfx.gd           # procedural sounds
  autoload/net.gd           # ENet host/join, roster, team/loadout requests
  autoload/game.gd          # server-authoritative Tag game mode
  data/weapons.gd           # weapon stats
  data/addons.gd            # addon stats
  data/game_version.gd      # version number (major.minor.patch)
  data/join_code.gd         # join codes <-> IP address and port
  map/map_data.gd           # classic layout transcribed from the sketch, map sizes
  map/city_gen.gd           # random city layouts (one per match, from a seed)
  map/map_builder.gd        # procedural city, interiors, where props and furniture go, spawn points
  map/prefabs.gd            # reads prop / furniture scenes and batches them into the map
  world/world.gd            # environment, players, Tag, FX, trails, heartbeat, respawn search
  world/door.gd             # hinged doors
  world/mats.gd             # shared materials / team colours
  player/player.gd          # FPS controller, weapons, addons, netcode
  player/weapon_model.gd    # weapon scene root: muzzle, glint point, first/third-person setup
assets/models/              # player, weapon, door, Tag, spray decal, muzzle flash and glint scenes
assets/materials/           # shared materials (.tres)
assets/props/, assets/furniture/   # map prop and furniture template scenes
assets/building/            # modular building pieces
assets/ui/                  # every menu, the HUD and reusable setting rows (rows/)
  ui/*.gd                   # behaviour for the screens in assets/ui (menus, lobby, settings, HUD, minimap, crosshair)
```

## Chat & commands

- Press **Enter** for all chat or **Right Shift + Enter** for team chat. The chat key is rebindable, and team chat is always Right Shift + that key. A Shift bind (the ability key by default) only uses Left Shift, so team chat never fires your addon. Chat works in the lobby and in matches; while you type, gameplay keys are ignored.
- Typing **/** at the start of a message opens command autocomplete: **Tab** completes, **Up/Down** choose, **Enter** sends, **Esc** cancels.
- Commands: `/help` lists commands; `/kill` eliminates yourself (the normal respawn timer applies). New commands are added in `scripts/data/commands.gd`.
- **Safety:** the server rate-limits chat (5 messages per 4 s) and caps messages at 200 characters. It strips control, zero-width and bidirectional-override characters, both before sending and when receiving. Player names get the same cleaning. Messages are displayed as plain text in Labels (never BBCode). Commands are matched against a fixed whitelist and run on the server; nothing anyone types is ever evaluated as code.

## Sprays

Customize → **Spray** lets you choose an image (PNG, JPG, WebP, BMP, TGA or SVG). It's resized to fit 128 px and re-saved as a clean PNG. In a match, press **T** to spray it on the surface you're looking at (within 4 m), with a 5 s cooldown. Everyone sees it, and your newest spray replaces your previous one. The server only accepts PNG data under 64 KB, at most one new spray image per player every 3 s, re-checks the cooldown and distance, and every client decodes sprays as PNG only (at most 256×256). A player's spray disappears when they leave.

## Custom skybox

Customize → **Skybox** replaces the sky with your own 360° panorama: an equirectangular image about twice as wide as it is tall, such as the HDRIs from Poly Haven. PNG, JPG, WebP, BMP, TGA, HDR and EXR are supported. The image is resized to fit 4096 px and saved as `user://skybox.png`.

The menu has a preview, a toggle, rotation and brightness. Changes apply instantly, even mid-match. The sky also provides the world's ambient light, so darker skies make the map darker. Your skybox only shows for you.

## Crosshair editor

Customize → **Crosshair Editor** has Counter-Strike-style options:
- Style: classic, circle, dot, or a custom image.
- Colour (presets or any colour), opacity, length, thickness, gap.
- Outline and outline thickness, centre dot and dot size.
- T-style (no top line) and dynamic spread.

It has a live preview and copy/paste **share codes**. Pasted codes are parsed as data only: unknown keys are ignored and every value is checked and clamped.

You can also upload a **custom crosshair image** (with a scale slider) and a **custom sniper scope** image. The scope is fitted to the screen height and the rest is blacked out, so a transparent PNG with a see-through centre works best.

## Assumptions and choices not covered by the spec

- **Sprint is the default pace** (no sprint key). Leaning, aiming and crouching drop you to walking speed.
- **Reloading and magazine sizes** were added (R key), with the values above.
- **Sniper:** inaccurate unless aimed. **Shotgun and sniper** pellets and rounds deal the same damage to the head (headshots still break Hider invisibility).
- **Shotgun falloff** keeps the same 10 m / 15 m ranges and the same ratios as before (100% / 70% / 40%), so 15 / 10.5 / 6 damage per pellet.
- **Wall running** starts automatically, and its controls are Jump and Crouch, so all of it is rebindable. Foliage blocks sight but not bullets.
- **Dropped-Tag timer:** the timer keeps running while the Tag is on the ground (it only waits for the first pickup of a round). A pickup adds +10 s (enemy) or +15 s (teammate), capped at 2:00. If it runs out while the Tag is down, the team that held it last wins.
- **Phantom's** 23 s cooldown starts when the phase ends. Trackstar's 30 s cooldown starts at activation, as specified.
- Skywalker's double jump and Stalker's trails are passive, so the ability key does nothing for them.
- **Grapple's** cooldown starts when the hook hits (like Trackstar's, from activation). A miss only costs 1 s so you can try again.
