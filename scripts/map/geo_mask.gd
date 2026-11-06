class_name GeoMask
## Collision masks. Walls and floors are separate layers so Phantom can pass one and not the other.

const WALL := 2
const FLOOR := 1
const DOOR := 8
const BOUNDARY := 16
## Awning and umbrella tops. No movement mask includes it: PlayerMovement checks for them itself.
const BOUNCE := 32
## Permanent world geometry: same on every peer at all times, so safe for movement and spawn checks.
const SOLID := WALL | FLOOR | BOUNDARY
