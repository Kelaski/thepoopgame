# Tag Rush

**Grab the Tag. Protect your Runner. Outrun everyone.**

Tag Rush is a fast, team-based first-person shooter for up to 16 players. Two teams race across a city to a single objective, the **Tag**. Whoever grabs it becomes the **Runner**, and their team has to keep them alive while the clock runs down. Everyone else hunts them. Slide, wall-run, grapple and bunny-hop your way across rooftops, through windows and over traffic to get there first.

**[Download the latest release](https://github.com/Kelaski/thepoopgame/releases)** for Windows or Linux. Patch notes are in the [CHANGELOG](CHANGELOG.md).

## Features

- **One objective, constant action.** Every round is a race to the same spot, then a fight over it. The Tag can change hands many times before the clock runs out.
- **Momentum movement.** Slides that keep your speed, slide-hops, bunny hops, air strafing, wall runs, wall kicks and mantling, all chaining into each other. Easy to pick up, with a lot of room to master.
- **Five weapons, twenty-one addons.** Pick a weapon, an active addon (like a grappling hook, a blink or a shield) and a passive addon (like a double jump, extra health or faster reloads).
- **A new ruined town every match.** A round, long-abandoned city with avenues and side streets, lined with crumbling offices, malls, casinos, schools, gyms, parks and more, in three sizes, or the hand-made Classic map. Every building can be explored, from the ground floor to the roof, and holes knocked through the walls give you extra ways in.
- **Changing time of day.** Matches start by day, in the afternoon, in the evening or at night, and the sky shifts between rounds.
- **Make it yours.** Recolour the menus and teams, design your crosshair and holo sight, move your gun on screen, upload a spray and bring your own music.
- **Play with friends on Steam.** One player hosts a lobby and invites friends, or anyone can join a public lobby. No ports to open.

## How a round works

1. **Countdown.** Both teams start at opposite ends of the map, frozen for a quick **3, 2, 1, GO!** The Tag shows through walls so you can see where to go, and you can press **B** to change your loadout before GO.
2. **The rush.** Everyone races to the Tag. The first player to touch it becomes the **Runner** and the 2:00 clock starts.
3. **Defend or hunt.** The Runner's team protects them. Everyone sees the Runner on the minimap, and hunters nearby hear a heartbeat. Each kill the Runner gets takes 5 s off their team's clock.
4. **Drops.** If the Runner dies, the Tag drops where they fell and the clock keeps running. An enemy who grabs it adds 10 s for their team; a teammate who grabs it adds 15 s.
5. **Winning.** When the clock hits 0, the team holding the Tag wins the round. If it's lying on the ground, it's **overtime**: whoever grabs it first wins. First to 3 rounds wins the match.

**Staying in the fight:**
- **Respawn:** 6 s after you're eliminated (7 s if your team has the Tag), near your team. You get 3 s of spawn protection, which ends early if you move, look around or shoot.
- **Health:** 100 HP (150 with the Spiked Bat). It regenerates quickly after 8 s without taking damage, and every kill heals you 30 HP over 2.5 s.
- **No friendly fire.** Bullets pass through teammates.
- **Damage direction:** a red arc around your crosshair points at whoever is shooting you.

## Weapons

| Weapon | Best at | Details |
|---|---|---|
| **Assault Rifle** | Mid range | 20 dmg (25 headshot): 5 body shots or 4 headshots kill. 9.5 rounds/s, 20-round magazine, 1.5x holo sight |
| **Shotgun** | Point blank | 13 pellets of 15 dmg up close, 1 shot/s, 6 shells. Loads one shell every 0.8 s, and firing stops the reload |
| **Sniper** | Long range | 100 dmg, headshots always kill, pierces a wall and every player in line. One round: it reloads after every shot (2.5 s). Its scope glints when it's aimed at you |
| **Grenade Launcher** | Area denial | 6 arcing grenades, 2 s between shots, one shell every 1.2 s. They fly at 25 m/s plus your own speed, and explode on hitting anything solid or within 0.5 m of an enemy. 75 damage to enemies, never to you or your team, and the 2.25 m blast launches every player it reaches. Walls stop it |
| **Spiked Bat** | Speed | 35 dmg, more the faster you're moving (up to 300). 150 HP and +10% speed while held. A killing swing launches your victim's gun |

## Addons

You pick one **Active** addon, used with **E**, and one **Passive** addon, which has no key. Every addon's numbers are in its own file in `assets/tuning/addons/`.

### Active: Mobility

| Addon | What it does |
|---|---|
| **Grapple** | Hold to throw a grappling hook (27 m), reel in and swing. The rope only snaps if a building gets in the way; it slides past props. Hooking an enemy pulls them to you. 6.5 s cooldown. |
| **Warp** | Blink 15 m the way you're looking. It stops at walls, and all your speed carries on in the direction you warped. A light-blue afterimage stays where you left for 1 s. 8 s cooldown. |
| **Rocket Jump** | Your next jump fires your rocket boots and launches you 8 m up. 10 s cooldown. |

### Active: Tactical

| Addon | What it does |
|---|---|
| **Hider** | 15 s nearly invisible: 10% visible while moving, 5% while still, crouching or sliding. A Tag you carry fades with you. Firing ends it. 12 s cooldown. |
| **Phantom** | Phase through walls and doors for 3 s, and double-tap crouch to drop through a floor. Press E again to end it early. If it ends inside something, you take 10 damage per second, doubling every second until you're out. 10 s cooldown. |
| **Bubble** | A 4 s shield with 75 health. Hits drain it before your health, and nothing can push you while it's up. 10 s cooldown. |

### Active: Support

Support cooldowns carry on through death, and only count down while you're alive.

| Addon | What it does |
|---|---|
| **UAV** | Sends 5 pulses that grow at 9 m/s. Your team sees enemies through walls as a red outline, and on the minimap, where a pulse reached them. Outlines last until the next pulse, and the last pulse's for 1.5 s. 25 s cooldown. |
| **Magnet** | Aim at a teammate in sight to pull them to you in at most 0.5 s. 15 s cooldown. |
| **Interlink** | Aim at a teammate to link. Within 25 m you share all damage and healing evenly, and if one of you dies you both do, with a 10 s respawn. Press E again to break the link. Any break starts a 25 s cooldown. |

### Passive: Movement

| Addon | What it does |
|---|---|
| **Moonwalker** | 30% less gravity and 20% more air control. |
| **Trackstar** | 25% faster, with quicker reloads. |
| **Double Jump** | Jump again in the air. All your speed turns the way you're looking. |
| **Wallhugger** | 2 more wall jumps before gravity starts pulling harder. |
| **Aerodynamic** | Much more air control, with both the camera and A / D. |
| **Unstoppable** | The speed cap goes up by 10 m/s. |

### Passive: Perks

| Addon | What it does |
|---|---|
| **Reload on Kill** | A kill reloads your weapon and cancels any reload or re-chamber, so you can fire straight away. Then 3 s until it can work again. |
| **Cooldown on Kill** | A kill takes 5 s off your active addon's cooldown. |
| **Juggernaut** | +25 max health. |
| **Sharpshooter** | Headshots do 1.2x damage. |
| **Killstreak** | Each kill until you die: 4% more speed and 5% faster reloads, but health regen starts 1 s later. Up to 5 kills. |
| **Blast Shield** | Explosive damage is halved. |

## Movement

Tag Rush plays fast. Moving forward is always a sprint, and every move keeps your momentum:

- **Slide** while sprinting for a burst of speed. A slide rides up over low things like the planters under trees, keeping its speed. Slides follow the way you're moving, speed up downhill and slow down uphill. The boost comes back every 2 s.
- **Slide-hop and bunny hop:** jump out of a slide and keep all your speed. Time your next jump as you land to keep it going.
- **Air strafe:** hold A or D and turn with the mouse to steer and pick up speed in the air.
- **Wall run** along walls to speed up, then **kick off** to chain into the next wall, a slide or a hop. A run starts when you're moving along a wall and holding forward, holding a key towards it, or touching it, and lasts while you hold a movement key.
- **Mantle** onto ledges, through windows and over rooftop ledges: jump at them and keep holding **Space** while you push into them. You keep most of your speed, and a slide straight after a mantle gets an extra boost.
- **Bounce pads:** jump into or onto an umbrella or kiosk awning and it launches you twice as high as a jump.
- **Doors** fly open when you sprint or slide into them.
- Top speed is capped at 30 m/s, so even the fastest chains stay readable.

## The city

- **Four maps:** Classic, or a random city in Small, Medium or Large, chosen by the host in the lobby.
- **Streets that meet properly:** roads with kerbs and dashes, crossings and stop signs where they join, and bends, not just a grid.
- **Rounds move around:** each round both teams start somewhere new, out of each other's sight where the map allows and about the same distance from the Tag, and the Tag appears in a different spot. Inside a building it can be on any floor, so look up.
- **Every building can be explored**, up to seven floors high, with stairs up to an open roof. Each has the rooms it would really have, furnished for what they are: classrooms and a cafeteria in schools, homes with their own bedroom and bathroom in apartments, a cinema behind the snack counter, restrooms, offices, kitchens and more.
- **Parks** with tree-lined paths, ponds with a dock, playgrounds, basketball courts, benches and hedges.
- **Busy streets and rooftops:** parked cars, lamps that light up at night, water towers, air conditioning units and antennas.
- **Rooftop routes:** tower cranes hold beams between rooftops.
- **Ruins:** broken walls, rubble, rusted wrecks and dead trees fill the streets and open ground, top floors have fallen in, and many street lights are out.
- **Beyond the round fence:** roads run off across open grass, towards a city skyline all around the map.
- **Warm, cartoony light** that shifts between day, afternoon, evening and night.
- **Windows** are open gaps you can shoot, jump and grapple through.

## Make it yours

Open **Settings** from the main menu, the lobby or the pause menu. As well as controls, keybinds, video, audio and HUD options, it has:

- **View model:** move your gun left, right, up, down, forward and back, with a live preview.
- **Music:** play the Tag Rush Theme, your own playlist, or both. Add songs from your computer (OGG, MP3 and WAV work out of the box; more formats with [ffmpeg](https://ffmpeg.org) installed). Music plays from the moment you start the game, with controls on the main menu and in the pause menu. Press **M** in a match to open this tab.
- **Colours:** recolour the menus, the teams and the Tag, or pick a preset (Default, Midnight, Neon, Pastel, Desert). Your colours only change your own screen.
- **Crosshair:** a full crosshair editor with a live preview and share codes, custom crosshair and sniper scope images, and holo sight reticle options for the AR.
- **Spray:** pick an image and press **T** in a match to spray it on a wall.

## Playing with friends

Online play runs through **Steam**, so Steam has to be running and signed in. Your name is your Steam name.

- **Host:** click **Host Lobby**. In the lobby, choose who can join:
  - **Public:** listed in the Server Browser for everyone.
  - **Friends only:** your Steam friends can join.
  - **Invite only:** only players you invite.

  Press **Invite Friends** to invite people, pick the teams and the map, then press **Start match**.
- **Join:** click **Server Browser** and pick a game from the list. You can also accept a Steam invite, or right-click a friend in your Steam friends list and choose Steam's **Join Game**. That even starts Tag Rush for you if it isn't running.
- No ports, router settings or firewall prompts. Everything goes through Steam's network, which also keeps your IP address private.
- Everyone needs the same version of the game. Games on other versions show as Other version in the list and can't be joined.
- **Automatic updates:** when you start the game it checks for a newer version and asks you. **Update** downloads it and restarts into it; **Cancel** keeps playing on the version you have. If the game folder can't be written to (for example under Program Files), it offers the download page instead.
- **Teammates** have a white outline, so you can see them through walls.

## Controls

All controls can be rebound in **Settings > Keybinds**.

| Action | Default |
|---|---|
| Move | W A S D |
| Jump (double jump with Double Jump, rocket jump with Rocket Jump) | Space |
| Crouch / slide | Ctrl |
| Crouch only | C |
| Active addon | E |
| Fire / aim | Left / right mouse |
| Reload | R |
| Interact (doors) | F |
| Ping (double tap: danger) | Middle mouse |
| Change loadout (countdown or while dead) | B |
| Spray | T |
| Scoreboard (with everyone's ping) | Tab |
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
