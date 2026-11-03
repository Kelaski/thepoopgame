# Tag Rush

A team-based, first-person objective shooter built in **Godot 4.7 (GDScript only, no extra plugins)**.
Two teams of up to 8 race to a randomly chosen objective, grab **the Tag**, and the team holding it
has to keep its **Runner** alive for 2 minutes. Best of 7 (first to 4 round wins).

Everything (map, furniture, sounds, UI) is generated in code, so the repository has no binary assets. The one exception is the easter egg's image and sound in `assets/` (see Easter egg below).

## Running it

1. Install [Godot 4.7 or newer](https://godotengine.org/download) (standard build, not .NET). The project file is saved with 4.7; older 4.x editors warn when opening it.
2. Open Godot, choose **Import**, and select this folder's `project.godot`.
3. Press **F5** (Run Project).

### Hosting / joining

- **Host:** type a name, then click **Host Game**. The lobby shows your LAN IP address(es). The default port is `7777`.
- **Join:** enter the host's IP and port, then click **Join Game**.
- For play over the internet, the host must forward **UDP port 7777** (or whatever port they chose) on their router.
- The host chooses teams (or shuffles them) and clicks **START MATCH**. Players who join mid-match spawn in after the respawn timer.

To test multiplayer on one machine, run two instances and join `127.0.0.1`.
Optional command-line flags (after `--`):

```
--host  --join=IP[:PORT]  --name=NAME  --port=PORT  --autostart=N
```

## Controls (all rebindable in Settings > Keybinds)

| Action | Default |
|---|---|
| Move | W A S D |
| Jump / double jump (Skywalker) | Space |
| Crouch / slide (crouch while sprinting) | Ctrl |
| Lean left / right | Q / E |
| Addon ability | Shift |
| Interact (doors) | F |
| Fire / Aim | Mouse 1 / Mouse 2 |
| Reload | R |
| Scoreboard | Tab |
| Loadout (while dead) | B |
| Spray | T |
| Chat (all / team) | Enter / Y |
| Pause / settings | Esc |

There is no sprint key: moving forward is always a sprint. Aiming, crouching or holding a lean key slows you to a walk.
If you played an older version, the old default binds for lean right (C), addon (F) and interact (E) move to the new defaults automatically. Binds you changed yourself are kept.

A fast, punchy 160 BPM beat plays during matches. It is synthesized in code and has its own volume slider.

### Custom music & playlist (Main menu → Music & Playlist, also in the lobby and pause menu)

- **Add Songs...** opens your system file picker. You can pick several songs at once.
- Imported songs are copied into the game's own music folder (`user://music`), so the playlist keeps working even if you move or delete the originals. **Open Music Folder** shows that folder.
- Importing runs in the background, so the game keeps running (important when you're the host) and you can close the menu while it works.
- **Formats:** OGG, MP3 and WAV (8/16/24/32-bit integer or 32/64-bit float PCM) work out of the box; other WAV encodings fall back to ffmpeg. FLAC, M4A/AAC, Opus, WMA, AIFF, WebM/MKA, ALAC and more are converted on import, which needs [ffmpeg](https://ffmpeg.org) installed and on your PATH.
- In the playlist you can turn songs on and off, reorder them, preview them and remove them.
- **Play during matches** chooses between the built-in beat, your playlist, or both. There's also a shuffle option. Use **Skip Song** in the pause menu to move on, and a "Now playing" toast shows each new song. Editing the playlist mid-match keeps the current song playing unless you disable or remove it.

### Colour customization (Main menu → Customize Colours, also in the lobby and pause menu)

You can recolour:
- The menus: accent, panels, buttons, text and backdrop.
- Team and Tag colours.
- The sky: top colour and horizon / fog colour. For a picture skybox, use Customize → Skybox.

The map itself (ground, roads, grass and buildings) always uses its built-in colours.

Presets are Default, Midnight, Neon, Pastel and Desert, and every colour has its own Reset. Menu and sky colours change instantly. Team colours apply when the next match loads. Colours are personal and don't affect other players.

Settings also cover mouse and ADS sensitivity, invert Y, hold/toggle aim and crouch,
FOV (90–120, horizontal), brightness, fullscreen, V-Sync, FPS cap, render scale, MSAA, shadows,
view distance, master/effects/UI volume, hitmarker sound, minimap size (0.6x–2x) and location names, and an FPS counter.

## Rules

- **Spawning:** at round start each team spawns at a random purple-dot spawn zone (the two zones are at least 70 m apart).
  The objective is the red-dot location whose distance to the two teams is most even, with some randomness.
  Players are frozen for a 5 s countdown, then everyone rushes.
- **The Tag:** the first player to touch it becomes the **Runner**. Their team defends and the timer starts at 2:00.
- **Dropping:** when the Runner dies, the Tag drops where they died and the timer pauses.
  - An enemy picks it up: their team becomes the defenders, and the timer resumes from the value at the drop **+10 s**.
  - A teammate picks it up: the timer resumes **+15 s**.
  - The timer is capped at 2:00.
- **Winning a round:** the timer reaches 0 while the Tag is held. The holding team wins. First to 4 wins the match.
- **Runner self-defence:** every kill the Runner gets takes 5 s off their team's timer.
- **Runner visibility:** everyone sees the Runner on the minimap at all times. Hunters within 25 m hear a heartbeat that speeds up as they get closer.
- **Health:** 100 HP (150 HP with the Spiked Bat). After 8 s without taking damage, health regenerates quickly (50 HP/s). Every kill gives you back 30 HP (up to your max).
- **Minimap:** shows location names on the buildings and park. Its size is adjustable in Settings > HUD.
- **Respawn:** after a 6 s timer, press **Jump (Space)** to respawn. Use the wait to change loadouts. Runners' teammates spawn near the Runner. Hunters spawn near the hunter closest to the Runner.
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
| Sniper | 100 body, 90 lower body, headshots always kill | 0.4 rps | 2.5x | Pierces 1 wall and every player in line, 5 rounds. A ring around the crosshair shows when the next shot is ready |
| Spiked Bat | 45 per swing | 2.25 swings/s | none | 7 m reach, +10% move speed and 150 HP while equipped. A killing swing launches the victim's gun where you look (70 dmg) |

### Addons

| Addon | Effect |
|---|---|
| Hider | Shift: 15 s of invisibility. Fully invisible while still or crouch-walking, 10% visible while moving. Taking damage does not end it; firing does. 12 s cooldown after it ends. |
| Trackstar | Passive +15% speed. Shift: +35% for 6 s. 30 s cooldown from activation. |
| Skywalker | Double jump with extra height that keeps your current momentum (no added speed). Recharges when you land. |
| Stalker | See wide red ground trails behind every enemy. Each part of a trail lingers for 6 s, fading as it ages. Walls and floors hide the trails. The trails are identical, so you can't tell which one is the Runner. |
| Phantom | Shift: 2 s of phasing. Run through walls and doors. Double-tap crouch to drop through a floor. 23 s cooldown. |
| Grapple | Hold Shift: throw a grappling hook up to 30 m (it flies out over about 0.3 s). It latches onto whatever it hits (walls, floors, doors, props or players) and reels you in while you keep steering, up to 24 m/s for at most 2.5 s. The rope only ever shortens, so hooking something above you swings you underneath it. Reaching the hook pops you upwards so you can climb onto ledges. The grapple only lasts while you hold Shift: releasing it (or pressing Jump) lets go with your momentum, and releasing while the hook is still flying reels it back in (counts as a miss). The rope also snaps if something gets in the way. Hooking an enemy yanks them towards you. 9 s cooldown after a hit; a miss only costs 1 s. Everyone sees the hook and rope. |

### Movement

Snappy ground acceleration, sprinting by default, crouch, and a momentum slide (crouch while sprinting). You can start a slide in mid-air and it carries on after you land until your momentum runs out. Sliding downhill keeps accelerating the longer you stay on the slope.
Slide-jumping keeps your speed. Turning is quick: in the air your momentum swings towards the direction you're pressing (about 260°/s) without losing speed, slides steer at about 170°/s, and extra speed carried onto the ground turns at about 515°/s. Pulling backwards in the air brakes instead of turning.
**Wall running:** jump into a wall at speed while holding forward to run along it for up to 1.6 s.
Press Jump to kick off the wall. The kick keeps your speed and adds a little, so you can chain it into another wall run, a slide or a slide-jump. Crouch drops you off. Jumping and wall jumps both have 0.1 s of coyote time, so you can still jump just after running off a ledge or a wall.
**Wall-jump fatigue:** your first 3 wall jumps before touching the floor are free. From the 4th on, each kick keeps only 75% of your speed (then 56%, 42%...) and adds less height, and wall runs stop holding you at running speed, so long chains run out of momentum. Touching the floor resets it.
**Leaning** (Q / E) peeks around corners and slows you to a walk. Your head hitbox moves with the lean, and walls limit how far you can lean.
Doors fill their doorways exactly and swing open, away from you and at full speed, when you sprint or slide into them. **F** opens and closes them normally.

## Map sizes

The host picks **Small**, **Medium** or **Large** before hosting (the main menu dropdown), in the lobby, or with the chat command `/map <small|medium|large>`. Using `/map` during a match restarts the match on the new map. The choice is shared with everyone, including players who join later. `/map` with no size shows the current one.

| Size | Area | Buildings | Spawn zones | Tag spots | Rooftop bridges |
|---|---|---|---|---|---|
| Small | ~81 × 102 m | Bank, Meridian Tower + park | 3 | 3 (Park, Bank, Tower) | none |
| Medium | ~130 × 136 m | School, Bank, Diner, Arcade, Meridian Tower, Casino + park | 5 | 4 (Park, Bank, Tower, Casino) | Tower–Casino |
| Large | 200 × 170 m | the whole city (all 18) + park | 10 | 8 | all 6 |

Smaller sizes are cut-outs of the full city. Buildings that fit fully inside are kept and the fence moves in. Empty lots where a building was cut get street clutter, and the minimap zooms to fit. Defined in `MapData.SIZES` (`scripts/map/map_data.gd`).

## The map

The map is laid out from the design sketch at a scale of 1 px = 0.1 m, so the city is 200 m × 170 m.
A fence with tall invisible collision surrounds it.

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

Buildings are at most 5 storeys. Each has a two-lane ramp stairwell from the ground floor to an accessible roof, and longer buildings have a second one at the far end.
Exterior doors are on the ground floor, open windows of varied size and position are spread out on every floor (leaving long stretches of wall for wall running), and residential and school floors have corridors with rooms behind doors.
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

ENet with the host as the authoritative server (peer 1, also a player).
Each client simulates its own movement and streams its position at 30 Hz. Remote players are interpolated.
Shooting is resolved on the shooter's client, and the server validates every hit (alive, enemy team, not spawn-protected, damage clamped to the weapon maximum) before applying damage.
Round state, the timer, respawns, the Tag and health regeneration all run on the server.

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
  map/map_data.gd           # layout transcribed from the sketch
  map/map_builder.gd        # procedural city, interiors, furniture, spawn points
  world/world.gd            # environment, players, Tag, FX, trails, heartbeat, respawn search
  world/door.gd             # hinged doors
  world/mats.gd             # shared materials / team colours
  player/player.gd          # FPS controller, weapons, addons, netcode
  ui/*.gd                   # menus, lobby, settings, HUD, minimap, crosshair
```

## Chat & commands

- Press **Enter** for all chat or **Y** for team chat (both rebindable). Chat works in the lobby and in matches; while you type, gameplay keys are ignored.
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
- **Wall running** starts automatically, and its controls are Jump and Crouch, so all of it is rebindable. Bushes block sight but not bullets.
- **Dropped-Tag timer:** the timer pauses while the Tag is on the ground. On pickup it resumes from the value at the drop +10 s (enemy) or +15 s (teammate), capped at 2:00.
- **Phantom's** 23 s cooldown starts when the phase ends. Trackstar's 30 s cooldown starts at activation, as specified.
- Skywalker's double jump and Stalker's trails are passive, so the ability key does nothing for them.
- **Grapple's** cooldown starts when the hook hits (like Trackstar's, from activation). A miss only costs 1 s so you can try again.
