# Tag Rush

**Grab the Tag. Protect your Runner. Outrun everyone.**

Tag Rush is a fast, team-based first-person shooter for up to 16 players. Two teams race across a city to a single objective, the **Tag**. Whoever grabs it becomes the **Runner**, and their team has to keep them alive while the clock runs down. Everyone else hunts them. Slide, wall-run, grapple and bunny-hop your way across rooftops, through windows and over traffic to get there first.

**[Download the latest release](https://github.com/Kelaski/thepoopgame/releases)** for Windows or Linux. Patch notes are in the [CHANGELOG](CHANGELOG.md).

## Features

- **One objective, constant action.** Every round is a race to the same spot, then a fight over it. The Tag can change hands many times before the clock runs out.
- **Momentum movement.** Slides that keep your speed, slide-hops, bunny hops, air strafing, wall runs, wall kicks and mantling, all chaining into each other. Easy to pick up, with a lot of room to master.
- **Five weapons, six addons.** Mix an Assault Rifle, SMG, Shotgun, Sniper or Spiked Bat with abilities like invisibility, phasing through walls, a grappling hook or seeing enemies through walls.
- **A new city every match.** Random cities with offices, a mall, a casino, a school, apartments, a park and more, in three sizes. Every building can be explored, from the ground floor to the roof.
- **Changing time of day.** Matches start in the morning, afternoon, evening or at night, and the sky shifts between rounds.
- **Make it yours.** Recolour the menus, teams and sky, design your crosshair and holo sight, upload a spray, set your own skybox and bring your own music.
- **Play with friends, no accounts.** One player hosts and shares a short join code.

## How a round works

1. **Countdown.** Both teams start at opposite ends of the map, frozen for a quick **3, 2, 1, GO!** The Tag shows through walls so you can see where to go, and you can press **B** to change your loadout before GO.
2. **The rush.** Everyone races to the Tag. The first player to touch it becomes the **Runner** and the 2:00 clock starts.
3. **Defend or hunt.** The Runner's team protects them. Everyone sees the Runner on the minimap, and hunters nearby hear a heartbeat. Each kill the Runner gets takes 5 s off their team's clock.
4. **Drops.** If the Runner dies, the Tag drops where they fell and the clock keeps running. An enemy who grabs it adds 10 s for their team; a teammate who grabs it adds 15 s.
5. **Winning.** When the clock hits 0, the team holding the Tag wins the round. If it's lying on the ground, it's **overtime**: whoever grabs it first wins. First to 3 rounds wins the match.

**Staying in the fight:**
- **Respawn:** 6 s after you're eliminated (7 s if your team has the Tag), near your team. You get 3 s of spawn protection, which ends early if you move or shoot.
- **Health:** 100 HP (150 with the Spiked Bat). It regenerates quickly after 8 s without taking damage, and every kill gives you 30 HP back.
- **No friendly fire.** Bullets pass through teammates.
- **Damage direction:** a red arc around your crosshair points at whoever is shooting you.

## Weapons

| Weapon | Best at | Details |
|---|---|---|
| **Assault Rifle** | Mid range | 33 dmg (45 headshot), 9.5 rounds/s, 30-round magazine, 1.5x holo sight |
| **SMG** | Close range | 22 dmg (30 headshot), 14 rounds/s, tight hip fire, 40-round magazine |
| **Shotgun** | Point blank | 13 pellets of 15 dmg up close, 1 shot/s, 6 shells |
| **Sniper** | Long range | 100 dmg, headshots always kill, pierces a wall and every player in line, 5 rounds. Its scope glints when it's aimed at you |
| **Spiked Bat** | Speed | 35 dmg, more the faster you're moving (up to 300). 150 HP and +10% speed while held. A killing swing launches your victim's gun |

## Addons

| Addon | What it does |
|---|---|
| **Hider** | 15 s of invisibility. Fully hidden while still or crouch-walking, faint while moving. Firing ends it. |
| **Trackstar** | Always 15% faster with quicker reloads. Ability: +35% speed for 6 s. |
| **Skywalker** | A double jump that keeps your momentum. |
| **Stalker** | See red trails behind every enemy. Ability: see every player through walls for 4 s. |
| **Phantom** | Phase through walls and doors for 2 s, and double-tap crouch to drop through a floor. |
| **Grapple** | Hold to throw a grappling hook (27 m), reel in and swing. Hooking an enemy pulls them to you. |

## Movement

Tag Rush plays fast. Moving forward is always a sprint, and every move keeps your momentum:

- **Slide** while sprinting for a burst of speed. Slides follow the way you're moving, speed up downhill and slow down uphill. The boost comes back every 2 s.
- **Slide-hop and bunny hop:** jump out of a slide and keep all your speed. Time your next jump as you land to keep it going.
- **Air strafe:** hold A or D and turn with the mouse to steer and pick up speed in the air.
- **Wall run** along walls to speed up, then **kick off** to chain into the next wall, a slide or a hop.
- **Mantle** onto ledges by jumping at them.
- **Bounce pads:** jump into or onto an umbrella or kiosk awning and it launches you twice as high as a jump.
- **Doors** fly open when you sprint or slide into them.
- Top speed is capped at 30 m/s, so even the fastest chains stay readable.

## The city

- **Three sizes:** Small, Medium and Large, chosen by the host in the lobby.
- **Random or classic:** a freshly generated city every match, or the hand-made Classic city.
- **Every building can be explored**, with stairs up to an open roof. Shops, offices, a bank vault, a casino floor, a cinema, a school, apartments, a motel, a warehouse and more, each furnished like the real thing.
- **Busy streets:** stopped traffic you can slide between, bus stops, kiosks and street lamps that light up at night.
- **A park** with a fountain, a basketball court, a pond, a playground and picnic umbrellas to bounce off.
- **Rooftop routes:** tower cranes hang bridges between rooftops.
- **Windows** are open gaps you can shoot, jump and grapple through.

## Make it yours

Open **Customization** from the main menu, the lobby or the pause menu:

- **Player:** your name.
- **Music:** play the Tag Rush Theme, your own playlist, or both. Add songs from your computer (OGG, MP3 and WAV work out of the box; more formats with [ffmpeg](https://ffmpeg.org) installed).
- **Colours:** recolour the menus, the teams, the Tag and the sky, or pick a preset (Default, Midnight, Neon, Pastel, Desert). Your colours only change your own screen.
- **Crosshair:** a full crosshair editor with a live preview and share codes, custom crosshair and sniper scope images, and holo sight reticle options for the AR and SMG.
- **Spray:** pick an image and press **T** in a match to spray it on a wall.
- **Skybox:** use any 360° panorama as your sky.

## Playing with friends

- **Host:** click **Host Game**. The lobby shows a **join code** with a **Copy Code** button. Pick the teams and the map, then press **START MATCH**.
- **Join:** click **Join Game**, type the code and press **Join**.
- **Firewall:** on Windows, hosting asks once for permission to let players connect. Players who only join are never asked.
- **Router:** the game opens its port (UDP 27015) automatically when your router allows it. The lobby tells you if something is still in the way, such as a router that needs the port forwarding by hand, or an internet provider that shares your address with other customers.
- Everyone needs the same version of the game.
- You can't join your own code from the same network that's hosting. Test with a friend on another network.
- Each lobby gets a new code. A code is your address in short form, so only share it with people you want to play with.

## Controls

All controls can be rebound in **Settings > Keybinds**.

| Action | Default |
|---|---|
| Move | W A S D |
| Jump (double jump with Skywalker) | Space |
| Crouch / slide | Ctrl |
| Crouch only | C |
| Addon ability | Left Shift |
| Fire / aim | Left / right mouse |
| Reload | R |
| Interact (doors) | E |
| Ping (double tap: danger) | Middle mouse |
| Change loadout (countdown or while dead) | B |
| Spray | T |
| Scoreboard | Tab |
| Chat (all / team) | Enter / Right Shift + Enter |
| Pause | Esc |

**Pings** mark a spot for you and your team, with a beam of light and a minimap marker. Aim at an enemy to mark them, or double-tap for a red danger ping.

**Chat commands:** `/help` lists them. `/kill` eliminates yourself. The host can use `/map <small|medium|large>` to change the map and `/time <morning|afternoon|evening|night>` to change the time of day.

## Settings

Mouse and aim sensitivity, invert Y, hold or toggle aim and crouch, field of view (90–120), brightness, fullscreen, V-Sync, an FPS cap, render scale, anti-aliasing, shadows and shadow distance, interior lights, bloom, view distance, volume for effects, UI and music, a hitmarker sound, and HUD options: minimap size and labels, an FPS counter and a speedometer.

**Running slowly?** Lower **Render scale**, turn **Shadows** down or off, set **Interior lights** to Low, and shorten **View distance**.

## Download

Get the latest build from the **[Releases page](https://github.com/Kelaski/thepoopgame/releases)**:
- **Windows (64-bit):** download the `.zip`, extract it and run the `.exe` inside.
- **Linux (x86_64):** download the `.x86_64` file, make it executable and run it.

Want to look under the hood or run it from source? See [DEVELOPMENT.md](DEVELOPMENT.md).
