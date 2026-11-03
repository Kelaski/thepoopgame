# Changelog

Versions use **major.minor.patch**:
- **major:** big overhauls.
- **minor:** new features and gameplay changes.
- **patch:** fixes and small tweaks.

The current version is set in `scripts/data/game_version.gd` and shown on the main menu. Players must be on the same version to play together.

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
