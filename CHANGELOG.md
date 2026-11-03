# Changelog

Versions use **major.minor.patch**:
- **major:** big overhauls.
- **minor:** new features and gameplay changes.
- **patch:** fixes and small tweaks.

The current version is set in `scripts/data/game_version.gd` and shown on the main menu. Players must be on the same version to play together.

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
