extends RefCounted
## Translate templates before substituting values; saved IDs stay untouched.
static func format(source: String, values: Array = []) -> String:
	var translated := prompt(source)
	if values.is_empty(): return translated
	var arguments: Array = []
	for value in values:
		arguments.append(String(TranslationServer.translate(value)) if value is String else value)
	return translated % arguments

static func prompt(source: String) -> String:
	return String(TranslationServer.translate(source))

static func credits() -> String:
	# Keep the UI to attributions; source and license details stay in CREDITS.txt.
	return "\n\n".join([
		"Godot Engine — Godot contributors",
		"Framewright Lite — Cabin Circuit",
		"Fusion Pixel Font — TakWolf & contributors",
		"JRPG Pack 4 Calm — Juhani Junkala / SubspaceAudio",
		"Forest Whisper Theme — Cleyton Kauffman",
		"Ambient Bird Sounds — isaiah658",
		"Crickets Ambient Noise — Wolfgang_ / Ted Kerr",
		"Fireplace Sound Loop — PagDev",
		"Boiling Water Loops — TinyWorlds",
		"Super Dialogue Audio Pack — Dillon Becker\nCC BY 4.0 · https://creativecommons.org/licenses/by/4.0/",
		"UI SFX Set — Kenney Vleugels",
		"Interface Sounds 1.0 — Kenney",
		"RPG Audio — Kenney Vleugels",
		"Impact Sounds — Kenney",
		"40 CC0 water / splash / slime SFX — rubberduck",
		"Rain (loopable) — Ylmir",
		"Wind — IgnasD",
		"Different steps on wood, stone, leaves, gravel and mud — TinyWorlds",
		"42 Snow and Gravel Footsteps — Corsica_S / Iwan Gabovitch (qubodup)",
	])
