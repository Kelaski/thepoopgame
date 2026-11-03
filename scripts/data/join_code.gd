class_name JoinCode
## Join codes: the host's IPv4 address (plus the port, if it isn't the default)
## packed into a short code in Crockford base32. The alphabet has no I, L, O or U,
## so codes are easy to read out, and typing O / I / L by mistake still works.
##   default port: 7 characters, shown as "ABC-DEFG"
##   other ports:  10 characters, shown as "ABCDE-FGHJK"
## A code is just an encoded address, not a password: share it with friends only.

const ALPHABET := "0123456789ABCDEFGHJKMNPQRSTVWXYZ"


static func encode(ip: String, port: int) -> String:
	var parts := ip.split(".")
	if parts.size() != 4:
		return ""
	var n := 0
	for p in parts:
		if not p.is_valid_int() or int(p) < 0 or int(p) > 255:
			return ""
		n = (n << 8) | int(p)
	var digits := 7
	if port != Net.DEFAULT_PORT:
		n = (n << 16) | (port & 0xFFFF)
		digits = 10
	var s := ""
	for i in digits:
		s = ALPHABET[n & 31] + s
		n >>= 5
	var half := 3 if digits == 7 else 5
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
	if s.length() != 7 and s.length() != 10:
		return {}
	var n := 0
	for ch in s:
		var v := ALPHABET.find(ch)
		if v < 0:
			return {}
		n = (n << 5) | v
	var port := Net.DEFAULT_PORT
	if s.length() == 10:
		port = n & 0xFFFF
		n >>= 16
	if n >> 32 != 0 or port <= 0:
		return {}
	var ip := "%d.%d.%d.%d" % [(n >> 24) & 255, (n >> 16) & 255, (n >> 8) & 255, n & 255]
	return {"ip": ip, "port": port}
