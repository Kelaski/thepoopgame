# Tag Rush

**Grab the Tag. Protect your Runner. Outrun everyone.**

Tag Rush is a fast, team-based first-person shooter for up to 16 players. Two teams race across a city to a single objective, the **Tag**. Whoever grabs it becomes the **Runner**, and their team has to keep them alive while the clock runs down. Everyone else hunts them. Slide, wall-run, grapple and bunny-hop your way across rooftops, through windows and over traffic to get there first.

**[Download the latest release](https://github.com/Kelaski/thepoopgame/releases)** for Windows or Linux. Patch notes are in the [CHANGELOG](CHANGELOG.md).

## Features

- **One objective, constant action.** Every round is a race to the same spot, then a fight over it. The Tag can change hands many times before the clock runs out.
- **Momentum movement.** Slides that keep your speed, slide-hops, bunny hops, air strafing, wall runs, wall kicks and mantling, all chaining into each other. Easy to pick up, with a lot of room to master.
- **Five weapons, eleven addons.** Pick a weapon, a primary addon (like a grappling hook, a blink or a swap) and a secondary addon (like phasing through walls, a parry or seeing enemies through walls).
- **A new city every match.** Random cities with avenues, side streets and alleys, lined with offices, a mall, a casino, a school, apartments, a park and more, in three sizes. Every building can be explored, from the ground floor to the roof.
- **Changing time of day.** Matches start in the morning, afternoon, evening or at night, and the sky shifts between rounds.
- **Make it yours.** Recolour the menus, teams and sky, design your crosshair and holo sight, upload a spray, set your own skybox and bring your own music.
- **Play with friends on Steam.** One player hosts a lobby and invites friends, or anyone can join a public lobby. No ports to open.

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
| **SMG** | Close to mid range | 22 dmg (30 headshot) up to 25 m, as strong as the AR there but weaker beyond. 14 rounds/s, tight hip fire, 40-round magazine |
| **Shotgun** | Point blank | 13 pellets of 15 dmg up close, 1 shot/s, 6 shells |
| **Sniper** | Long range | 100 dmg, headshots always kill, pierces a wall and every player in line, 5 rounds. Its scope glints when it's aimed at you |
| **Spiked Bat** | Speed | 35 dmg, more the faster you're moving (up to 300). 150 HP and +10% speed while held. A killing swing launches your victim's gun |

## Addons

You pick one **primary** and one **secondary** addon. Each has its own ability key: **E** for the primary, **Q** for the secondary.

**Primary**

| Addon | What it does |
|---|---|
| **Grapple** | Hold to throw a grappling hook (27 m), reel in and swing. Hooking an enemy pulls them to you. 6.5 s cooldown. |
| **Hider** | 15 s of invisibility. Fully hidden while still or crouch-walking, faint while moving. Firing ends it. 12 s cooldown. |
| **Warp** | Blink 15 m the way you're looking. It stops at walls, and all your speed carries on in the direction you warped. 8 s cooldown. |
| **Swap** | A sci-fi beam charges for 0.8 s, then you swap places with the nearest enemy within 20 m. If nobody is in range by then, you get the cooldown back. 18 s cooldown. |
| **Moonwalker** | 20% less gravity and 15% better air control. Ability: your next jump fires your rocket boots and launches you 8 m up. 10 s cooldown. |

**Secondary**

| Addon | What it does |
|---|---|
| **Trackstar** | Always 15% faster with quicker reloads. Ability: +35% speed for 6 s. 24 s cooldown. |
| **Stalker** | See red trails behind every enemy. Ability: see every player through walls for 4 s. 14 s cooldown. |
| **Skywalker** | A double jump that keeps your momentum. |
| **Phantom** | Phase through walls and doors for 2 s, and double-tap crouch to drop through a floor. 23 s cooldown. |
| **Reload on Kill** | Every kill refills your magazine and chambers a round, so the shotgun and sniper can fire again straight away. |
| **Parry** | 0.4 s of invulnerability inside a pink bubble: bullets, swings, grapple pulls and swaps all bounce off. 10 s cooldown. |

## Movement

Tag Rush plays fast. Moving forward is always a sprint, and every move keeps your momentum:

- **Slide** while sprinting for a burst of speed. Slides follow the way you're moving, speed up downhill and slow down uphill. The boost comes back every 2 s.
- **Slide-hop and bunny hop:** jump out of a slide and keep all your speed. Time your next jump as you land to keep it going.
- **Air strafe:** hold A or D and turn with the mouse to steer and pick up speed in the air.
- **Wall run** along walls to speed up, then **kick off** to chain into the next wall, a slide or a hop. A run starts when you hold forward, hold a movement key towards the wall, or hug the wall, and lasts while you hold a movement key.
- **Mantle** onto ledges by jumping at them.
- **Bounce pads:** jump into or onto an umbrella or kiosk awning and it launches you twice as high as a jump.
- **Doors** fly open when you sprint or slide into them.
- Top speed is capped at 30 m/s, so even the fastest chains stay readable.

## The city

- **Three sizes:** Small, Medium and Large, chosen by the host in the lobby.
- **Random or classic:** a freshly generated city every match, or the hand-made Classic city.
- **A real street grid:** a wide avenue, side streets that end in T-junctions, and blocks of different sizes. Buildings line the pavement with narrow alleys between them, and taller buildings stand in the middle of the city. Service lanes and car parks sit behind the buildings.
- **Rounds move around:** each round both teams start somewhere new and the Tag appears in a different spot. Inside a building it can be on any floor, like the 3rd floor of a tower, so look up.
- **Every building can be explored**, with stairs up to an open roof. Shops, offices, a bank vault, a casino floor, a cinema, a school, apartments, a motel, a warehouse and more, each furnished like the real thing.
- **Busy streets:** stopped traffic you can slide between, traffic lights and street signs on the corners, bus stops, parking meters, bike racks, planters, kiosks and street lamps that light up at night.
- **Interiors like the real thing:** a bank with teller counters, queue posts and ATMs; offices with a reception desk and meeting tables; a casino with carpet, chandeliers, slots and roulette; a nightclub with a DJ booth and booths; motel rooms with twin beds; school corridors lined with lockers; and more.
- **Busy rooftops:** air conditioning units and ducts to take cover behind, skylights, antennas, satellite dishes, billboards and roof terraces.
- **A park** with a fountain, a basketball court, a pond, a playground and picnic umbrellas to bounce off.
- **Rooftop routes:** tower cranes hang bridges between rooftops.
- **Windows** are open gaps you can shoot, jump and grapple through.

## Make it yours

Open **Customization** from the main menu, the lobby or the pause menu:

- **Player:** your name (you can also type it on the main menu).
- **Music:** play the Tag Rush Theme, your own playlist, or both. Add songs from your computer (OGG, MP3 and WAV work out of the box; more formats with [ffmpeg](https://ffmpeg.org) installed).
- **Colours:** recolour the menus, the teams, the Tag and the sky, or pick a preset (Default, Midnight, Neon, Pastel, Desert). Your colours only change your own screen.
- **Crosshair:** a full crosshair editor with a live preview and share codes, custom crosshair and sniper scope images, and holo sight reticle options for the AR and SMG.
- **Spray:** pick an image and press **T** in a match to spray it on a wall.
- **Skybox:** use any 360° panorama as your sky.

## Playing with friends

Online play runs through **Steam**, so Steam has to be running and signed in. Your name starts as your Steam name; you can change it in Customization.

- **Host:** click **Host Game**. In the lobby, choose who can join:
  - **Public:** listed in Join Game for everyone.
  - **Friends only:** your Steam friends can join.
  - **Invite only:** only players you invite.

  Press **Invite Friends** to invite people, pick the teams and the map, then press **START MATCH**.
- **Join:** click **Join Game** and pick a lobby from the list. You can also accept a Steam invite, or right-click a friend in your Steam friends list and choose **Join Game**. That even starts Tag Rush for you if it isn't running.
- No ports, router settings or firewall prompts. Everything goes through Steam's network, which also keeps your IP address private.
- Everyone needs the same version of the game. Lobbies on other versions show their version in the list and can't be joined.
- **Automatic updates:** when you start the game it checks for a newer version, downloads it, and restarts into it. If the game folder can't be written to (for example under Program Files), it offers the download page instead.
- **Teammates** have a white outline, so you can see them through walls.

## Controls

All controls can be rebound in **Settings > Keybinds**.

| Action | Default |
|---|---|
| Move | W A S D |
| Jump (double jump with Skywalker, rocket jump with Moonwalker) | Space |
| Crouch / slide | Ctrl |
| Crouch only | C |
| Primary addon ability | E |
| Secondary addon ability | Q |
| Fire / aim | Left / right mouse |
| Reload | R |
| Interact (doors) | F |
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
