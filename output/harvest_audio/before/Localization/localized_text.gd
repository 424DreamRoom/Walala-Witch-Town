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
		"UI SFX Set — Kenney Vleugels",
		"Interface Sounds 1.0 — Kenney",
		"RPG Audio — Kenney Vleugels",
		"Rain (loopable) — Ylmir",
		"Wind — IgnasD",
		"Different steps on wood, stone, leaves, gravel and mud — TinyWorlds",
		"42 Snow and Gravel Footsteps — Corsica_S / Iwan Gabovitch (qubodup)",
	])
