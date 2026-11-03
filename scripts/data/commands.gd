class_name Commands
## Chat commands ("/name args"). Commands are looked up in a fixed whitelist and run
## on the server only; the text after the command is never evaluated as code.

const LIST := {
	"help": {"usage": "/help", "desc": "List the available commands."},
	"kill": {"usage": "/kill", "desc": "Eliminate yourself (the respawn timer still applies)."},
}


## Commands whose name starts with prefix (without the slash), sorted.
static func matching(prefix: String) -> Array:
	prefix = prefix.to_lower()
	var out := []
	for k in LIST.keys():
		if k.begins_with(prefix):
			out.append(k)
	out.sort()
	return out


## Runs a command for a player on the server. Returns reply lines for that player.
static func run(sender: int, text: String) -> Array:
	var parts := text.substr(1).strip_edges().split(" ", false)
	if parts.is_empty():
		return ["Type /help to see the commands."]
	var cmd := parts[0].to_lower()
	if not LIST.has(cmd):
		return ["Unknown command \"/%s\". Type /help to see the commands." % cmd.left(24)]
	match cmd:
		"help":
			var lines := ["Commands:"]
			var keys := LIST.keys()
			keys.sort()
			for k in keys:
				lines.append("  %s  -  %s" % [LIST[k].usage, LIST[k].desc])
			return lines
		"kill":
			return [Game.server_suicide(sender)]
	return []
