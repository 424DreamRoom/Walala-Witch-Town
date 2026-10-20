extends RefCounted
## CC0 JRPG Pack 4 Calm and Forest Whisper Theme; manifests retain attribution.
## Stable gameplay keys keep existing phase transitions and saves compatible.
const TRACKS := {
	"title": preload("res://Sounds/Walala/Music/title.ogg"),
	"day_town": preload("res://Sounds/Walala/Music/day.ogg"),
	"night_town3": preload("res://Sounds/Walala/Music/night.ogg"),
	"home": preload("res://Sounds/Walala/World/Music/home.ogg"),
	"dock": preload("res://Sounds/Walala/World/Music/dock.ogg"),
	"forest": preload("res://Sounds/Walala/World/Music/forest.ogg"),
}

static func context_key(phase: String, location: String, region: String = "field") -> String:
	if phase != "day": return "night_town3"
	if location in ["home", "dock"]: return location
	if location == "field" and region in ["grove", "marsh"]: return "forest"
	return "day_town"

static func gain_db(key: String) -> float:
	# The forest recording is about 12 dB quieter than the JRPG pack.
	return 5.0 if key == "forest" else -6.0

static func looped(key: String) -> AudioStreamOggVorbis:
	var stream := TRACKS[key].duplicate() as AudioStreamOggVorbis
	stream.set_meta("fmod_source_path", TRACKS[key].resource_path)
	stream.loop = true
	return stream
