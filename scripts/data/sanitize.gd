class_name Sanitize
## Text sanitization for anything typed by players (chat, names).
##
## Chat text is only ever displayed as plain text in Label nodes (never parsed as
## BBCode or evaluated), commands are matched against a fixed whitelist, and the
## server re-sanitizes everything it receives. This strips characters that could be
## used to spoof or disrupt the UI: control characters, C1 controls, zero-width
## characters and bidirectional-override characters.

const MAX_CHAT := 200
const MAX_NAME := 20


static func text(s: String, max_len := MAX_CHAT) -> String:
	s = s.left(max_len * 2)
	var out := PackedStringArray()
	var count := 0
	for i in s.length():
		var c := s.unicode_at(i)
		if c == 9 or c == 10 or c == 13:
			c = 32  # tabs / newlines become spaces
		if c < 32 or c == 127:
			continue
		if c >= 0x80 and c <= 0x9F:
			continue  # C1 control characters
		if (c >= 0x200B and c <= 0x200F) or (c >= 0x202A and c <= 0x202E) or (c >= 0x2060 and c <= 0x2069) or c == 0xFEFF:
			continue  # zero-width and bidirectional override characters
		if c >= 0xD800 and c <= 0xDFFF:
			continue  # stray surrogates
		out.append(String.chr(c))
		count += 1
		if count >= max_len:
			break
	# Collapse runs of whitespace and trim.
	return " ".join("".join(out).split(" ", false)).strip_edges()


static func player_name(s: String) -> String:
	return text(s, MAX_NAME)
