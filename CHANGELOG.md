# Changelog

Versions use **major.minor.patch**:
- **major:** big overhauls.
- **minor:** new features and gameplay changes.
- **patch:** fixes and small tweaks.

The current version is set in `scripts/data/game_version.gd` and shown on the main menu. Players must be on the same version to play together.

## 0.17.4

### Fixed
- **Firewall prompt:** the Windows administrator (UAC) prompt for the firewall rule now appears only when you host a game. Players who only join no longer get it at launch, and their firewall is left alone. The lobby's **Allow Through Firewall** button still works for hosts.
- **Firewall rule for some install folders:** the rule is now set up correctly when the game sits in a folder whose name contains `%`.

## 0.17.3

### Changed
- **Pond:** the rippling water effect is gone, so the pond is plain, still water like the fountain.

## 0.17.2

### Changed
- **Basketball court lines** now follow a standard court diagram:
  - three hash marks down each side of the key
  - free-throw circles solid outside the key and dashed inside it
  - wider three-point arcs and a tick on each sideline in both halves
  - the restricted-area arcs are gone
- **Benches** beside the basketball court (the team benches and any along the paths next to it) face the court.
- **Fountain:** the water jets and the moving-water effect are gone. The bottom basin is now filled with water, which used to be hidden under its rim. The droplet spray stays.
- **Picnic umbrellas** tilt 15°, so the low edge of the top is easier to land on.

## 0.17.1

### Added
- **Real water:** the pond and the fountain's basins now ripple, with light glinting off the moving waves. The fountain's jets flow, with streaks pouring down each one.
- **Fountain spray:** droplets spurt from the statue's spout and splash round the basin.

### Changed
- **Basketball court lines** are smooth and laid out like a real court:
  - boundary lines and a centre circle
  - painted keys with free-throw lines and circles
  - a restricted-area arc under each basket
  - three-point lines with straight corners and a smooth arc
- **Cars and taxis:** the little lips above the wheels no longer have collision.

## 0.17.0

### Added
- **Stalker ability:** the trails are now Stalker's passive. Press the ability key to see a red outline of every player through walls for 4 s (only on your screen). 14 s cooldown from activation.
- **The park, developed:**
  - **Basketball court:** painted boundary lines, keys, free-throw circles and three-point arcs. Team benches, a ball rack and two floodlights (lit in the evening and at night) line the side facing the path.
  - **Fountain:** a stone coping lip, a middle tier, a statue on top and arcing water jets. Four benches face it round the plaza.
  - **Pond:** lily pads with flowers, three ducks and a wooden dock you can walk out on.

### Changed
- **Grapple:** range is now 27 m (from 30 m), and it never gives you more than 20 m/s of momentum (from 24 m/s), including the pop at the end.
- **Trackstar:** reloads and re-chambering are now 35% faster instead of twice as fast (30% faster with the sniper). The ability cooldown is now 24 s (from 30 s).
- **Car side mirrors** no longer have collision: you can't snag on or be shielded by them.

## 0.16.2

### Changed
- **Trackstar:** reloads now take half the time with every weapon except the Spiked Bat, which never reloads. The shotgun and sniper also re-chamber between shots in half the time, so they fire twice as fast.
- **Shoot through gaps:** collision now matches what you see, so bullets go through any gap you can see through:
  - between bench slats and under benches
  - through warehouse racks
  - under picnic tables
  - over car bonnets and boots, and around car cabins

### Fixed
- **Car windscreens:** the gaps around the front and rear windows are closed.
- **Fountain plaza flicker:** the paving round the fountain fought with the path under it. It now sits clearly on top.
- **Pond on the path:** on small maps the pond could land across a path. It now moves clear of the paths and the plaza, and shrinks if the park is too small.
- **Fountain inside the court:** the fountain plaza could overlap the basketball court. It now moves along the path to a spot clear of the court and the sandpit.

## 0.16.1

### Changed
- **No more A/C units on outside walls:** they're gone from building walls. The ones on rooftops stay.

### Fixed
- **Cars missing the top of their body:** cars and taxis now have a solid upper body, with pillars and window frames, instead of windows floating over a hollow middle.

### Releases
- Every version is now published on GitHub as a pre-release, with its patch notes and Windows and Linux downloads.

## 0.16.0

### Added
- **/time command (host):** `/time morning`, `afternoon`, `evening`, `night` or `next` changes the time of day for everyone, blending over 10 s. `/time` on its own shows the current one.
- **Tag arrow at the first spawn:** the on-screen Tag arrow now also shows at the start of every round, while the Tag waits at its spawn for the first pickup.
- **Exterior decoration:** awnings over street doors, A/C units and vents on rooftops, water towers on tall buildings, and window A/C units on upper floors.
- **Wall TVs** in bars, diners and the nightclub.

### Changed
- **Revamped vehicles,** in the same cartoony style:
  - **Cars and taxis:** bonnet and boot, a sloped windscreen and rear window, side windows, round wheels with hubcaps, wheel arches, door seams and handles, mirrors, bumpers, a grille and lights.
  - **Vans:** a proper cab with a sloped windscreen, a sliding door and rubbing strips.
  - **Buses:** a row of windows, two doors, a white roof with an A/C pod and a livery stripe.
- **Benches:** wooden slats on metal legs, with armrests.
- **Doors:** buildings usually have one street door, sometimes two, on the sides facing a street, instead of a door on every side.
- **Building names** are back to being centred on the wall, and only on walls that have a door.

### Fixed
- **Floor flicker:** roads overlapping at junctions, car parks overlapping roads, and the park's crossing paths drew on top of each other and flickered. They're now drawn once.
- **Windows split by walls:** an inside room wall could run through the middle of a window on the end walls. Those spots are always solid wall now.
- **Stair guard catching players:** the sloped wall between the stair lanes overhung the bottom landing. Its ends are now vertical and flush with the stairs.
- **Corner posts** no longer flicker with the parapet.

## 0.15.0

### Added
- **Real-life interior layouts:** every building is furnished like the real thing, without cluttering it:
  - **Stores:** aisles of shelves and rails, with checkouts by the door.
  - **Motels:** rooms have a bed, bedside table, TV dresser and rug.
  - **Apartments:** bedrooms, living rooms and kitchens.
  - **Schools:** classrooms with a board and rows of desks.
  - **Banks:** teller counters and the vault.
  - **Diners:** a counter and booths.
  - **Cinemas:** a screen and rows of seats.
  - **Libraries:** book stacks and reading tables.
  - **Offices:** cubicles.
  - **Casinos:** slot rows and card tables.
  - **Arcades, bars, the nightclub and the warehouse** get their own layouts too.
  - Walkways, doorways, stairs and the Tag spot stay clear.
- **New furniture scenes:** a store checkout, a reception desk and a cinema screen.
- **Tag arrow:** while the Tag lies on the ground after being dropped, an arrow on screen points to it. On screen, it bobs over the Tag with the distance; off screen, it sits at the edge pointing the way to turn.
- **Ping light beams:** every ping sends up a dim beam of light in its colour.

### Changed
- **Building names** are centred over each street door instead of the middle of the wall.
- **Windows** are evenly spaced in the same columns on every floor, singly or in pairs, with about the same number per floor as before. They also have frames now.
- **Pings:** a single ping is now yellow (danger and enemy pings stay red). Pings only fade when you look straight at them.
- **Bus shelters:** the glowing ad panel is now set in a solid side wall with collision.
- **Road junctions** have no yellow centre lines.
- **Minimap names** are smaller, and each shrinks to fit inside its building, so they never overlap.
- **More detail:** fuller tree crowns, framed windows, and furniture and decor drawn up to 140 m away.

### Fixed
- **Flickering corners:** the corner posts of buildings sat exactly on the wall surfaces and flickered. They now stand slightly proud of the walls.
- **Rugs** no longer flicker into the ground floor.

## 0.14.2

### Fixed (security)
- **Damage cheats:** a modified client could claim hits with any weapon (sniper or bat damage while holding an SMG), from any distance, as fast as it liked, and could claim thrown-gun hits at any time. The server now checks:
  - that you're holding the weapon you claim
  - that the victim is within that weapon's range
  - that hits don't arrive faster than the weapon fires
  - that a thrown gun only follows a bat kill (2 hits within 4 s)
- **Bat momentum:** bat damage now uses the speed the server actually saw you moving at, not the speed your client claims.
- **Doors:** any player could open or slam any door on the map, and push it past its hinges. A door now only moves for a living player near it, and only through its normal swing.
- **Fake shot effects:** a client could play any sound to everyone or flood clients with huge tracer lists. Shot effects must now be a real weapon, fired from the shooter's position, with at most 16 tracers.
- **Thrown guns:** a client could launch thrown guns on another player's behalf, which made that player's game report hits. Only the thrower can launch their gun now, and at most 12 can be in flight.
- **Movement updates:** broken numbers (NaN or infinity) are dropped, and lean and look angles are clamped. A huge lean could move a head hitbox far from the body.
- **Re-registering:** a connected player could register again to reset their team mid-match. Extra registrations are ignored.
- **Ping spam:** double-tap danger pings skipped the ping rate limit. They now count toward it.
- **Standing on the fence:** you could stand on top of the map's fence posts and rail. The invisible boundary walls are now flush with the inside of the fence.

### Added
- **Sky barrier:** an invisible ceiling 35 m above the tallest building or crane stops players from flying off the top of the map. Grapples, shots, sprays and pings pass straight through it.

### Changed
- **Umbrellas:** much easier to land on. The top is now 2.05 m up instead of 2.65 m, it's wider, and landing on the rim counts. They bounce you **twice** as high as a jump, up from 1.5 times (so do kiosk awnings).
- **Pings:** half the size, the text under them is gone, and they fade while you aim right at them, like teammate names.
- **Leaning:** twice as fast (about 0.1 s), and swapping from one side to the other is now smooth and snappy. The pause in the middle is gone, and the camera no longer steps between physics updates on high-refresh screens. Other players' leans look smoother too.
- **Stairs:** the full wall between the two lanes is now a sloped wall that follows each flight, 1.3 m above the steps. It covers your body but not your head.
- **Lobby:** the join code and Copy Code button sit on the same row as the map settings, so the top of the lobby no longer has an empty gap.

## 0.14.1

### Changed
- **Park ground pieces are scenes now:** the lawn, paths, fountain plaza paving, sandpit and pond are in `assets/props/park/` (`lawn`, `path`, `plaza`, `sandpit`, `pond`), so you can reshape them in the editor. They look the same as before.
- **Sandpit:** has a low wooden border.
- **Pond:** has a few rocks and reeds round it.

## 0.14.0

### Added
- **Pings** (middle mouse, rebindable), like Fortnite's:
  - Ping where you're aiming to put a marker there for you and your team. It shows its distance, through walls and on the minimap, with a sound.
  - Aim at an enemy to mark them with a red **ENEMY** ping, or at the Tag to mark it.
  - Double tap for a red **DANGER** ping.
  - Pings fade after 4.5–6 s. Each player can have 3 at once, and new rounds clear them.
- **Toggle lean setting** (Settings > Controls, on by default).

### Changed
- **Leaning works like Rainbow Six Siege:**
  - Tap Q / E to lean and stay leaned. Tap the same key to stand up, or the other one to swap sides. With Toggle lean off, you lean while holding the key.
  - You lean from the waist: your head swings out in an arc, drops slightly and the view tilts 15°. Leaning eases in and out over about 0.2 s.
  - You walk while leaned and can aim and shoot. Sliding or wall running stands you back up.
  - Other players see your body tilt so your head is where you're leaning.

## 0.13.0

### Added
- **Bounce pads:** landing on a picnic umbrella or a kiosk awning throws you up 1.5 times as high as a normal jump.
- **Shadow quality setting** (Settings > Video): Low (70 m), Medium (130 m), High (220 m, the default) or Ultra (320 m with an 8K shadow map).

### Changed
- **Wider way onto the stairs:** the landings at each end of a flight are 2.6 m deep instead of 1.6 m. The stairs themselves are the same width.
- **Graphics reach further:**
  - Shadows use 4 splits and reach 220 m by default, up from 70 m, so distant shadows stay sharp.
  - Furniture and small details show up to 140 m away instead of 75 m.
  - Lamps light up to 60 m away instead of 40 m.
  - The view distance slider now goes to 800 m.
- **Cranes:** you can shoot (and see) through the crane mast's lattice. Only the bars themselves block you and your shots, instead of one solid block.
- **The park** is laid out like a real park:
  - two paved paths cross at a plaza with a fountain and flower beds
  - benches, bins and lamp posts line the paths (the lamps light up at night)
  - a row of trees runs round the edge, and trees and bushes are dotted over the lawns
  - picnic tables with umbrellas on the open lawns
  - the playground sits on a sandpit; the court and pond are where they were
- **Lobby:** the Port box and Change Port button are gone, and so is the "port opened automatically" message. The lobby still warns you if players probably can't reach you.

## 0.12.1

### Changed
- **Teammate names:** six times bigger, so they're easy to read at a distance.
- **Names fade at the crosshair:** a teammate's name fades almost completely while you aim near it (within about 10°), and comes back as you look away. It never covers a fight.

## 0.12.0

### Added
- **Time of day:** every match starts at a random time of day: **Morning**, **Afternoon**, **Evening** or **Night**. After each round, the host picks a different one, and over 10 seconds everyone's sun, sky, fog and ambient light blend smoothly into it.
  - **Morning:** low, warm sun from the east and a soft sky.
  - **Afternoon:** the classic bright look.
  - **Evening:** an orange sunset from the west. The street lamps start to come on.
  - **Night:** dim moonlight and a dark blue sky, with street lamps lighting the sidewalks. Bulbs, screens and neon stand out.
  - Your sky colours from Customization are tinted to match. Picture skyboxes get dimmer at night.
- **Street lamp lights:** street lamps cast real light in the evening and at night. They follow the **Interior lights** setting: Off turns them off, and Low keeps every other one.

### Changed
- **Wider stairs:** each stair lane is 2.85 m wide instead of 2.45 m (the whole stairwell is 5.8 m instead of 5 m), and the landings at the bottom and top of every flight are 1.6 m deep instead of 1.2 m.
- **Rooms moved back:** rooms on residential and school floors start 0.8 m further from the wall to keep the corridor past the wider stairwell clear. A building now needs to be 0.8 m deeper to get rooms.
- **Tag spots inside buildings:** these now need a building at least 14 m wide, so the Tag never lands on the stairwell.

## 0.11.0

### Added
- **Real interior lights:** ceiling panels, hanging lamps, industrial lamps and wall lamps now cast actual light, so rooms get warm pools of light on the floors, walls and ceilings. Lights have no shadows and fade out beyond about 40 m to stay fast.
- **Glowing parts with bloom:** bulbs, street lamp heads, neon signs, exit signs, screens (arcade cabinets, slot machines, monitors, TVs, teller screens), the vending machine and jukebox fronts, the dance floor, the scoreboard, bus shelter ads, the taxi roof sign and vehicle headlights and taillights all glow.
- **More detail:**
  - **Vehicles:** headlights, taillights, bumpers, number plates, side mirrors, hubcaps and a grille. Taxis get a checker stripe, vans get side windows and rear doors, and buses get a windscreen, doors and a lit destination sign.
  - **Street:** street lamps get a base, an arm and a hood. Kiosks get serving windows and counters.
  - **Buildings:** windows get sills and headers, and street doors get a frame on both sides.
  - **Furniture:** keyboards, mugs and papers on desks; plates and chair backs at tables; sofa armrests and cushions; a sink, tap and hob in kitchens; bedside lamps; bottles and stool seats at bars; books on school desks; arcade control panels and marquees; slot machine lights; a claw machine sign and prizes.
  - The jukebox has a rounded top.
- **Video settings:** **Interior lights** (Off / Low / High; Low lights every other lamp with a shorter reach) and **Bloom** (on/off).

## 0.10.0

### Added
- **Interior decoration:** every building's inside is now decorated to match what it is.
  - **Ceiling lights** on every storey: panel lights in offices, schools, banks, arcades and the mall; hanging lamps in homes, the diner, bar, theater, casino and library; long industrial lamps in the tall warehouse, arena and water treatment halls. The nightclub gets a disco ball.
  - **Wall decor** on the solid wall sections, themed per building: posters and movie posters, picture frames, wall clocks, neon signs, bulletin boards, whiteboards, bottle shelves and a dartboard in the bar, curtains, wall lamps, banners, safety signs, pipes, valve panels and graffiti.
  - **Floor pieces** against the walls where no furniture stands: vending machines, water coolers, jukeboxes, speaker stacks, mannequins, trash cans and pallet stacks.
  - **Rugs** in the bank, apartments, motel, casino and library, **exit signs** over every street door, and the odd **fire extinguisher**.
- Lights are light fixtures you can see, not real light sources, so performance stays the same.
- Flat pieces (lights, signs, frames, posters, pipes, rugs) have no collision, so they never snag wall runs or jumps. Floor pieces, curtains, shelves, valve panels and extinguishers are solid.
- Decor is never placed on stairs, in doorways, on room walls, in the corridor, or on a Tag spot.

## 0.9.2
### Changed
- **Music:** removed the built-in songs Rooftop Run, Neon Chase and Last Stand. The **Tag Rush Theme** is the only built-in music again, and it loops for the whole match. Your own playlist works as before.
- **Music menu:** the options are now "Tag Rush Theme", "My playlist" and "My playlist + Tag Rush Theme".

## 0.9.1

### Changed
- **Keybinds in the Input Map:** the default controls now live in Godot's own **Project Settings → Input Map** instead of a list in the code. Edit an action's key there to change its default.
- **Extra inputs:** an action can have several inputs (such as a second key or a gamepad button), and they all work until a player rebinds that action.
- **Rebinding unchanged:** rebinding in Settings → Keybinds works as before and is saved per player. **Reset Keybinds** restores the Input Map's inputs, and existing saved binds carry over.

## 0.9.0

Last step of moving the game into editable scenes: the UI.

### Changed
- **Every screen is a scene:** the menus, lobby, pause menu, settings, all the customization screens, the HUD, chat and loadout picker are now scenes in `assets/ui/`. Open them in Godot to move, resize or restyle anything.
- **Signal connections:** buttons are wired to their actions as saved connections, so you can see them in the editor's Node → Signals tab.
- **Setting rows:** these are now reusable row scenes (`assets/ui/rows/`): slider, checkbox and dropdown. Set a row's setting name in the Inspector and it reads and saves that setting by itself. The settings menu, crosshair editor, skybox and music screens are built from them.
- **Colours:** menu text and backdrops use theme styles (`TitleLabel`, `AccentLabel`, `MutedLabel`, `HudLabel` and so on), so your Customize → Colours choices apply to every screen.
- **Music menu:** the built-in music option now says "Built-in songs" instead of "Built-in Tag Rush beat", since there are four songs now.
- **FPS cap:** a saved "Unlimited" FPS cap from older versions now shows as 500 on the slider.

## 0.8.0

Fourth step of moving the game's models into editable scenes: buildings.

### Changed
- **Modular buildings:** buildings are now assembled from 16 pieces in `assets/building/`: wall modules (solid, three window styles, door), fillers, corner posts, trim bands, parapets, floor slabs, stair segments, stair dividers, rails and interior walls. Edit a piece and every building uses it.
- **2 m grid:** every building snaps to it around its centre, so walls move by at most 0.5 m.
- **Windows:** each building has one window style (small, wide or tall) in whole 2 m slots, instead of random widths. They're still kept off wall ends and away from doors, with long solid stretches for wall running.
- **Stairs:** ramps are made of 0.8 m × 0.5 m segments at the same slope as before. A player-sized test body climbed the first flight in every multi-storey building on three test maps (34 stairwells).
- **Rooms:** apartment, motel, school and tenement rooms are now 6 m wide (three modules), with the door in the middle module.

## 0.7.0

Third step of moving the game's models into editable scenes.

### Changed
- **Map props and furniture:** all 82 are now template scenes you can edit in Godot, in `assets/props/` (vehicles, street furniture, trees, park, arena, water works, cranes) and `assets/furniture/`.
- **How they load:** when a map loads, each scene is read once and batched into the map exactly as before, so performance doesn't change.
- **Same map:** checked against the old code on all three sizes with four seeds each. Every mesh is identical, and the collision shapes match to within 1 cm.
- **Random colours:** colour slots and random colour choices (car paint, awnings, arcade cabinets, books and so on) are set in the scenes as metadata.

## 0.6.0

Second step of moving the game's models into editable scenes.

### Changed
- **Doors:** now a scene, `assets/models/door.tscn`. In game it's stretched to fit each doorway, with the same size, hinge, knob and colour as before.
- **The Tag:** its gem, pickup ring and beam are now `assets/models/tag.tscn`, still tinted with your Tag colour.
- **Sprays:** the decal is now `assets/models/spray_decal.tscn`, using `assets/materials/spray_decal.tres`.
- **Thrown gun:** the gun a killing bat swing launches is now the victim's actual weapon model instead of a grey block. It's aimed along its flight.
- **Effect materials:** bullet tracers, impacts and Stalker trails use editable materials, `assets/materials/fx_tracers.tres` and `fx_trails.tres`.

## 0.5.0

First step of moving the game's models from code into scenes you can edit in the Godot editor.

### Changed
- **Player model:** now a scene, `assets/models/player.tscn`. It has the same parts, hitboxes, nameplate and Tag marker as before. Team colours are applied to any part in the `team_color` / `team_color_dark` groups.
- **Weapons:** the five weapons are now scenes in `assets/models/weapons/`. The same scene is used for your first-person view and for the gun others see you holding. The holo-sight reticles only appear in first person, and the muzzle and sniper glint points are markers you can move.
- **Muzzle flash and sniper glint:** now scenes too, with the glint material in `assets/materials/sniper_glint.tres`.
- Everything looks and plays the same: the scenes were generated from the old code, so the parts, sizes and colours match.
- Team colours are now applied again when a player respawns, not only when they first spawn in.

## 0.4.3

### Changed
- **Fewer cars:** a bit under half as many cars on the roads and in car parks. Every road still has traffic: for example, a Large map now has about 57-96 vehicles, down from 129-212.

### Fixed
- **Sliding between cars:** you can now slide between any two cars without getting stuck. Every vehicle is at least 1.4 m from every other one, front, back and side to side. A crouched player is 0.76 m wide. Side-by-side cars in the two lanes used to leave only 0.25-0.6 m, and parked cars about 0.5 m. Traffic in the two lanes is now staggered, and car park bays are wider (3.6 m) with 1.5 m between back-to-back rows.

## 0.4.2

### Fixed
- **Louder guns, for real:** the AR, SMG and Shotgun are now about 35% louder to the ear (+4 to +5 dB). In 0.4.1 the extra volume pushed the shots past full scale, so it was clipped off and you couldn't hear it. The shots are now shaped to be louder while staying under full scale. The sniper is unchanged.

## 0.4.1

### Changed
- **Gunshots:** the AR, SMG and Shotgun are 35% louder. The sniper is unchanged.
- **Leaning:** switching straight from one side to the other is about three times faster (roughly 0.1 s instead of 0.33 s). Leaning out from upright is unchanged.
- **FPS cap:** Settings > Video now has a slider from 30 to 500 instead of a list. If you had it on Unlimited, it's now 500.

## 0.4.0

### New
- **Random cities:** a new city is generated for every match, at any map size.
  - Roads form a grid of uneven blocks, and blocks hold buildings, plazas and car parks with alleys between them.
  - Each city has a park, crane bridges between rooftops, and spread-out spawn zones and Tag spots.
  - Every player gets the same city, generated from the same seed.
  - The lobby has a **Random city / Classic city** choice. Classic is the old hand-made map.
- **More music:** three new built-in songs, **Rooftop Run** (174 BPM), **Neon Chase** (128 BPM) and **Last Stand** (140 BPM), alongside the Tag Rush Theme. They play one after another, about a minute each.
- **Music player:** the pause menu has one in its bottom-right corner, with previous, play/pause, next and a volume slider.

### Changed
- **Timer:** it now keeps running while the Tag is on the ground. It still doesn't start until the Tag's first pickup. If time runs out while the Tag is down, the team that held it last wins the round.
- **Pause menu:** now just Resume, Settings, Customization, End Match (host only) and Quit (Close Server for the host).
- **Sniper:** its shot is 60% louder.
- **Teammate names:** 50% bigger.
- **Foliage:** tree crowns, potted plants and bushes no longer have collision. Tree trunks still do.

### Fixed
- **Router port:** leaving a lobby now actually closes the port that UPnP opened. Before, it stayed open on the router.

## 0.3.1

### Fixed
- **Lobby fits on screen again:** the Start Match row had been pushed off the bottom. The top of the lobby is now much shorter:
  - The title and join code share one line.
  - The port box and the **Map** size dropdown share one line. Hover over the map size for the full description.
  - The connection help text is smaller.
  - The team boxes start shorter, and grow as players join.

## 0.3.0

### New
- **Firewall permission:** on Windows the game now asks for firewall access through an administrator (UAC) prompt when it opens, if its rule is missing. Accepting it also removes any block rule Windows left behind from a dismissed prompt. The lobby has an **Allow Through Firewall** button if you said no.
- **Port setting:** the lobby has a **Port** box with a **Change Port** button. The port is remembered, and changing it restarts the lobby.
- **Public address lookup:** the join code now always uses your public address, looked up online, even when your router won't open the port automatically.
- **Connection help:** the lobby explains what's in the way: port not opened (forward it by hand), shared internet address (CGNAT, so someone else has to host), or no internet connection.
- **Busier streets:**
  - Stopped traffic (cars, taxis, vans and buses) in both lanes, with gaps to cross through.
  - Zebra crossings at clear junctions.
  - Sidewalks lined with lamps and trees, plus benches, bins, hydrants, newspaper boxes, mailboxes and bus shelters.
  - Tidy squares with planters, benches and kiosks.
  - Car parks in empty lots on the smaller maps.
  - Nothing is placed in front of doors.

### Changed
- **Online only:** the LAN code is gone, and the join code is the only code.
- **Street props:** the random clutter is gone (crates, barriers, roadworks, booths and scattered props).
- **Tall buildings:** the 5-storey buildings (Riverside Apartments, Meridian Tower, Golden Rapids Casino) are now 75% as wide and 75% as long. Their rooftop bridges are longer to match.

## 0.2.1

### Changed
- **Team chat:** now **Right Shift + Enter**. Left Shift + Enter opens all chat.
- **Ability key:** a Shift bind now means Left Shift only, so opening team chat no longer fires your addon.
- **Version label:** the version is now shown in the bottom-left corner of every screen, including the menus, the lobby and matches. It used to be on the main menu only, in the bottom-right.
- **Same version only:** the version check now also catches builds from before 0.2.0, which can't report a version:
  - A player who hasn't registered within 5 s is told the host's version and disconnected.
  - If you join a host on an older build, you get a message after about 6 s instead of an empty lobby.

## 0.2.0

### New
- **Damage direction indicator:** when you're shot, a red arc around the crosshair points at the shooter. It keeps tracking them while it fades, over about 2 s.
- **Visible weapons:** every player now holds a model of their actual weapon, and it aims up and down with where they're looking. It's the same model you see in first person.
- **Sniper glint:** a scoped-in sniper's scope flashes. The flash is brightest when they're aiming right at you, and walls hide it.
- **Join codes:** hosting shows a short code like `6C8-4HKQ`. Players click **Play Game** and type it in. There's a **Copy Code** button, plus a separate LAN code for players on the same network.
- **Automatic port opening:** hosting asks your router to open the port with UPnP, and the lobby says whether it worked.
- **Firewall prompt at launch:** on Windows the game asks for firewall access when it opens, not the first time you host.
- **Version check:** joining a host on a different version shows both version numbers instead of failing silently.

### Changed
- **Main menu:** now just Host Game, Play Game, Settings, Customization and Quit. Your player name moved to Customization, and the host picks the map size in the lobby.
- **Game port:** now **27015** (was 7777).
- **Team chat:** Shift + Enter (was Y).
- **Respawn:** the team holding the Tag waits 1 s longer, so 7 s instead of 6 s. This includes the Runner.
- **Trackstar:** now also reloads 25% faster.
- **Air strafing:** 20% stronger air acceleration (19.2, was 16).
- **Teammate names:** 90% smaller.

### Fixed
- **Collision:** lots of objects you could walk through now have collision: chairs, beds, sofas, screens, signs, lamp heads, the crane frames and cables, trees, potted plants, the park bench backs and more. Bushes are still walk-through, on purpose.

## 0.1.0

Everything before version numbers were tracked: the full game as of commit `86fffa9` (Tag mode, 5 weapons, 6 addons, momentum movement with wall running and wall-jump fatigue, the procedural city in three sizes, customization, sprays, chat and commands).
