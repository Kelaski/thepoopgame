class_name JoinCode
## Join codes: the host's IPv4 address (plus the port, if it isn't the default)
## packed into a short code in Crockford base32. The alphabet has no I, L, O or U,
## so codes are easy to read out, and typing O / I / L by mistake still works.
## Every time you host, a new random salt scrambles the address, so each lobby
## gets a different code (the salt travels in the code's first two characters).
##   default port: 9 characters, shown as "ABCD-EFGHJ"
##   other ports:  12 characters, shown as "ABCDEF-GHJKMN"
## A code is just an encoded address, not a password: share it with friends only.

const ALPHABET := "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
const SALT_BITS := 10


## A fresh salt for a new lobby.
static func new_salt() -> int:
	return randi() % (1 << SALT_BITS)


static func encode(ip: String, port: int, salt := 0) -> String:
	var parts := ip.split(".")
	if parts.size() != 4:
		return ""
	var n := 0
	for p in parts:
		if not p.is_valid_int() or int(p) < 0 or int(p) > 255:
			return ""
		n = (n << 8) | int(p)
	salt = salt & ((1 << SALT_BITS) - 1)
	n ^= _mask(salt, 32)
	var digits := 7
	if port != Net.DEFAULT_PORT:
		n = (n << 16) | ((port & 0xFFFF) ^ _mask(salt + 7919, 16))
		digits = 10
	n |= salt << (digits * 5)
	digits += 2
	var s := ""
	for i in digits:
		s = ALPHABET[n & 31] + s
		n >>= 5
	var half := 4 if digits == 9 else 6
	return s.left(half) + "-" + s.substr(half)


## Turns a join code (or a plain "IP" / "IP:PORT") into {"ip", "port"}.
## Returns an empty dictionary if it isn't valid.
static func parse(text: String) -> Dictionary:
	text = text.strip_edges()
	if text.contains("."):
		var bits := text.split(":")
		var port := int(bits[1]) if bits.size() > 1 else Net.DEFAULT_PORT
		if encode(bits[0], port) == "" or port <= 0 or port > 65535:
			return {}
		return {"ip": bits[0], "port": port}
	var s := text.to_upper().replace("-", "").replace(" ", "").replace("O", "0").replace("I", "1").replace("L", "1")
	if s.length() != 9 and s.length() != 12:
		return {}
	var n := 0
	for ch in s:
		var v := ALPHABET.find(ch)
		if v < 0:
			return {}
		n = (n << 5) | v
	var body_bits := (s.length() - 2) * 5
	var salt := n >> body_bits
	n &= (1 << body_bits) - 1
	var port := Net.DEFAULT_PORT
	if s.length() == 12:
		port = (n & 0xFFFF) ^ _mask(salt + 7919, 16)
		n >>= 16
	if n >> 32 != 0 or port <= 0:
		return {}
	n ^= _mask(salt, 32)
	var ip := "%d.%d.%d.%d" % [(n >> 24) & 255, (n >> 16) & 255, (n >> 8) & 255, n & 255]
	return {"ip": ip, "port": port}


## A fixed pseudo-random bit pattern for a salt, the same on every machine.
static func _mask(salt: int, bits: int) -> int:
	var x := (salt * 2654435761 + 0x9E3779B9) & 0xFFFFFFFF
	x ^= x >> 15
	x = (x * 0x2C1B3C6D) & 0xFFFFFFFF
	x ^= x >> 12
	return x & ((1 << bits) - 1)
